--!strict
-- Testes unitários F0 — CooldownService, CombatService, ResourceService,
-- AbilityService, CatalogService, PlayerSessionService + dados.
-- Uso: lune run tests/run.luau
-- Contrato da fatia: docs/13-F0-SLICE.md §19.

require("./harness")

-- ── Miniaframework de teste ─────────────────────────────────────────────────
local tests = {}
local passed = 0
local failed = 0

local function test(name: string, fn: () -> ())
	table.insert(tests, { name = name, fn = fn })
end

local function assertEq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(("%s — esperado %s, obtido %s"):format(msg or "assertEq", tostring(expected), tostring(actual)))
	end
end

local function assertTrue(cond: boolean, msg: string?)
	if not cond then
		error(msg or "assertTrue falhou")
	end
end

local function assertFalse(cond: boolean, msg: string?)
	if cond then
		error(msg or "assertFalse falhou")
	end
end

-- ── Carga dos módulos reais ─────────────────────────────────────────────────
local Abilities = require("../src/shared/Data/Abilities")
local Characters = require("../src/shared/Data/Characters")
local EnergyFamilies = require("../src/shared/Data/EnergyFamilies")
local Npcs = require("../src/shared/Data/Npcs")
local Remotes = require("../src/shared/Remotes")
local Zones = require("../src/shared/Data/Zones")
local CooldownService = require("../src/server/Services/CooldownService")
local CombatService = require("../src/server/Services/CombatService")
local ResourceService = require("../src/server/Services/ResourceService")
local AbilityService = require("../src/server/Services/AbilityService")
local CatalogService = require("../src/server/Services/CatalogService")
local PlayerSessionService = require("../src/server/Services/PlayerSessionService")
local ZoneService = require("../src/server/Services/ZoneService")
local ProgressionService = require("../src/server/Services/ProgressionService")

-- ── Relógio injetável (janela de reentrada / cap de Fluxo) ──────────────────
local fakeNow = 1000
local function clockNow(): number
	return fakeNow
end

-- taskImpl de teste: defer síncrono; spawn = noop (o loop de regen roda
-- apenas no Roblox com task real — aqui não queremos loop infinito)
local testTask = {
	spawn = function(_fn: () -> ())
		-- noop: não roda o loop de regen em testes
	end,
	defer = function(fn: () -> ())
		fn()
	end,
	wait = function(seconds: number): number
		return seconds
	end,
	delay = function(seconds: number, fn: () -> ())
		task.wait(seconds)
		fn()
	end,
}

local function makePlayerState(userId: number, resource: number, health: number?): any
	return {
		userId = userId,
		characterId = "eclipse_fist",
		health = health or 100,
		resource = resource,
		familyId = "umbral_aether",
		combat = false,
		lastCombatAt = 0,
	}
end

-- ══ Testes: dados ───────────────────────────────────────────────────────────
test("dados: Punho do Eclipse tem 3 skills ligadas e 1 ultimate desligada", function()
	local char = Characters.get("eclipse_fist")
	assertTrue(char ~= nil, "eclipse_fist deveria existir")
	if not char then
		return
	end
	assertEq(#char.abilityIds, 4, "quantidade de habilidades")
	assertEq(char.energyFamilyId, "umbral_aether", "família")
	local enabled = 0
	local disabled = 0
	for _, abilityId in char.abilityIds do
		local ab = Abilities.get(abilityId)
		assertTrue(ab ~= nil, "abilityIds referencia " .. abilityId)
		if ab and ab.enabled then
			enabled += 1
		else
			disabled += 1
		end
	end
	assertEq(enabled, 3, "skills ligadas")
	assertEq(disabled, 1, "ultimate desligada")
end)

test("dados: comet_shoulder é o molde com custo/cooldown", function()
	local ab = Abilities.get("comet_shoulder")
	assertTrue(ab ~= nil, "comet_shoulder deveria existir")
	if ab then
		assertEq(ab.kind, "Skill", "kind")
		assertEq(ab.resourceCost.amount, 18, "custo de recurso")
		assertEq(ab.cooldown.baseSeconds, 7, "cooldown")
		assertEq(ab.serverRunnerId, "comet_shoulder_runner", "runner")
		assertEq(ab.enabled, true, "enabled")
	end
end)

test("dados: Umbral segue o baseline da fatia", function()
	local fam = EnergyFamilies.get("umbral_aether")
	assertTrue(fam ~= nil, "umbral_aether deveria existir")
	if fam then
		assertEq(fam.poolBase, 100, "pool")
		assertEq(fam.regenInCombatPerSec, 2, "regen combate")
		assertEq(fam.regenOutOfCombatPerSec, 6, "regen fora")
		assertEq(fam.outOfCombatDelaySeconds, 3, "atraso OOC")
		assertEq(fam.flowTimingWindowMs, 120, "janela")
		assertEq(fam.flowGainOnTimedHit, 6, "fluxo")
		assertEq(fam.flowGainCapSeconds, 1.5, "cap")
		assertEq(fam.flowBonusAmount, 3, "bônus")
	end
end)

test("dados: 4 famílias de energia", function()
	assertEq(#EnergyFamilies.all(), 4, "número de famílias")
end)

test("dados: remotes registrados com contrato", function()
	local c = Remotes.Contracts.get(Remotes.Names.AbilityActivate)
	assertTrue(c ~= nil, "AbilityActivate deveria ter contrato")
	if c then
		assertEq(c.direction, "ClientToServer", "direção")
		assertEq(c.version, 1, "versão")
	end
	local snap = Remotes.Contracts.get(Remotes.Names.SessionSnapshot)
	assertTrue(snap ~= nil, "SessionSnapshot deveria ter contrato")
	if snap then
		assertEq(snap.direction, "ServerToClient", "snapshot S→C")
	end
end)

test("dados: dummy de treino no catálogo", function()
	local dummy = Npcs.get("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy deveria existir")
	if dummy then
		assertEq(dummy.maxHealth, 10000, "vida")
		assertEq(dummy.attackDamage, 4, "dano")
		assertEq(dummy.attackRange, 8, "alcance")
		assertEq(dummy.grantsXp, false, "sem XP")
	end
end)

-- ══ Testes: CooldownService ─────────────────────────────────────────────────
test("cooldown: começa zerado", function()
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "cooldown inicial")
end)

test("cooldown: start aplica e expira", function()
	CooldownService.clear(1)
	CooldownService.start(1, "comet_shoulder", 0.05)
	local remaining = CooldownService.getRemaining(1, "comet_shoulder")
	assertTrue(remaining > 0 and remaining <= 0.06, "cooldown ativo")
	local start = os.clock()
	while os.clock() - start < 0.06 do
	end
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "cooldown expirado")
end)

test("cooldown: clear zera", function()
	CooldownService.start(1, "comet_shoulder", 10)
	CooldownService.clear(1)
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "após clear")
end)

-- ══ Testes: CombatService ───────────────────────────────────────────────────
test("combate: dano reduz vida", function()
	local target = makePlayerState(2, 100)
	CombatService.applyDamage(target, 30, 1)
	assertEq(target.health, 70, "vida após dano")
	assertTrue(CombatService.isAlive(target), "deveria estar vivo")
end)

test("combate: dano letal mata", function()
	local target = makePlayerState(2, 100)
	local dead = CombatService.applyDamage(target, 100, 1)
	assertTrue(dead, "dano 100 deveria matar")
	assertEq(target.health, 0, "vida em 0")
	assertFalse(CombatService.isAlive(target), "morto")
end)

test("combate: dano negativo não cura", function()
	local target = makePlayerState(2, 100, 50)
	CombatService.applyDamage(target, -10, 1)
	assertEq(target.health, 50, "vida inalterada")
end)

test("combate: cadeia leve 5+5+6+10", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	assertEq(CombatService.tryLight(atk, tgt, 1.0, "front").damage, 5, "hit 1")
	assertEq(CombatService.tryLight(atk, tgt, 1.2, "front").damage, 5, "hit 2")
	assertEq(CombatService.tryLight(atk, tgt, 1.4, "front").damage, 6, "hit 3")
	assertEq(CombatService.tryLight(atk, tgt, 1.6, "front").damage, 10, "hit 4")
	assertEq(tgt.health, 74, "26 de dano")
end)

test("combate: janela 0,65 s reinicia a cadeia", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.tryLight(atk, tgt, 1.0, "front")
	local result = CombatService.tryLight(atk, tgt, 1.7, "front")
	assertEq(result.step, 1, "reset")
	assertEq(result.damage, 5, "primeiro golpe de novo")
end)

test("combate: guarda frontal reduz HP a 40%", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 10.0)
	local result = CombatService.tryLight(atk, tgt, 10.2, "front")
	assertEq(result.damage, 2, "floor(5*0.4)")
	assertEq(tgt.guard, 95, "guarda perde o dano cheio")
	assertEq(tgt.health, 98, "HP reduzido")
end)

test("combate: aparo nos 120 ms zera dano e guarda", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 20.0)
	local result = CombatService.tryLight(atk, tgt, 20.1, "front")
	assertEq(result.parried, true, "aparo")
	assertEq(result.damage, 0, "sem HP")
	assertEq(tgt.guard, 100, "guarda intacta")
	assertEq(tgt.health, 100, "HP intacto")
end)

test("combate: costas ignoram guarda", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 30.0)
	local result = CombatService.tryLight(atk, tgt, 30.2, "back")
	assertEq(result.damage, 5, "dano cheio")
	assertEq(tgt.guard, 100, "guarda não consome")
end)

test("combate: pesado 10 HP, 28 guarda, 2 se bloqueado", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local open = CombatService.createFighter("p:b", "player", 100, 100)
	assertEq(CombatService.tryHeavy(atk, open, 1.0, "front").damage, 10, "sem guarda")
	local guarded = CombatService.createFighter("p:c", "player", 100, 100)
	CombatService.setGuard(guarded, true, 2.0)
	local blocked = CombatService.tryHeavy(atk, guarded, 2.2, "front")
	assertEq(blocked.damage, 2, "HP bloqueado")
	assertEq(guarded.guard, 72, "28 de guarda")
end)

test("combate: quebra de guarda aplica overflow", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 20)
	CombatService.setGuard(tgt, true, 3.0)
	local result = CombatService.tryHeavy(atk, tgt, 3.2, "front")
	assertEq(result.broken, true, "quebra")
	assertEq(tgt.guard, 0, "guarda zerada")
	assertEq(tgt.health, 94, "2 bloqueado + floor(8*0.5)=4")
	local refused = CombatService.setGuard(tgt, true, 3.3)
	assertEq(refused, false, "não guarda durante break")
end)

test("combate: pesado que erra bloqueia leve por 0,5 s", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	local miss = CombatService.tryHeavy(atk, nil, 4.0, "front")
	assertEq(miss.ok, false, "miss")
	assertEq(miss.reason, "miss", "motivo")
	local locked = CombatService.tryLight(atk, tgt, 4.4, "front")
	assertEq(locked.ok, false, "leve bloqueado")
	assertEq(locked.reason, "heavy_miss", "motivo")
	local ok = CombatService.tryLight(atk, tgt, 4.5, "front")
	assertEq(ok.ok, true, "após 0,5 s")
end)

test("combate: dash aplica i-frame e cooldown", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	local ok, reason = CombatService.tryDash(tgt, 5.0)
	assertEq(ok, true, "dash " .. tostring(reason))
	local iframe = CombatService.tryLight(atk, tgt, 5.05, "front")
	assertEq(iframe.iframe, true, "i-frame")
	assertEq(iframe.damage, 0, "sem dano")
	assertEq(tgt.health, 100, "HP intacto")
	local cd = CombatService.tryDash(tgt, 5.5)
	assertEq(cd, false, "cooldown")
	local after = CombatService.tryLight(atk, tgt, 8.1, "front")
	assertEq(after.damage, 5, "depois do i-frame")
end)

test("combate: dummy ataca a 8 studs e recusa longe", function()
	CombatService.clear()
	local dummy = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local far = CombatService.tryDummyAttack(dummy, player, 1.0, 9, 2.5, 4, 8)
	assertEq(far.ok, false, "fora de alcance")
	local hit = CombatService.tryDummyAttack(dummy, player, 1.0, 8, 2.5, 4, 8)
	assertEq(hit.ok, true, "no alcance")
	assertEq(hit.damage, 4, "dano do dummy")
	assertEq(player.health, 96, "HP")
	local wait = CombatService.tryDummyAttack(dummy, player, 2.0, 8, 2.5, 4, 8)
	assertEq(wait.reason, "cooldown", "período 2,5 s")
	assertEq(dummy.health, 10000, "dummy não morre no próprio ataque")
end)

test("combate: comet 9 HP aberto", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local result = CombatService.tryCometShoulder(atk, tgt, 1.0, "front")
	assertEq(result.ok, true, "hit")
	assertEq(result.damage, 9, "dano aberto")
	assertEq(tgt.health, 9991, "HP dummy")
	assertEq(result.stoppedOnGuard, nil, "sem guarda")
end)

test("combate: comet na guarda para o avanço", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 10.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 10.2, "front")
	assertEq(result.damage, 4, "HP bloqueado")
	assertEq(tgt.guard, 91, "9 de guarda")
	assertEq(tgt.health, 96, "HP")
	assertEq(result.stoppedOnGuard, true, "avanço interrompe")
end)

test("combate: comet aparo zera dano", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 20.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 20.1, "front")
	assertEq(result.parried, true, "aparo")
	assertEq(result.damage, 0, "sem HP")
	assertEq(tgt.health, 100, "HP intacto")
	assertEq(tgt.guard, 100, "guarda intacta")
	assertEq(result.stoppedOnGuard, true, "para o avanço")
end)

test("combate: comet i-frame zera dano", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.tryDash(tgt, 5.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 5.05, "front")
	assertEq(result.iframe, true, "i-frame")
	assertEq(result.damage, 0, "sem dano")
	assertEq(tgt.health, 100, "HP intacto")
	assertEq(result.stoppedOnGuard, nil, "não é guarda")
end)

-- ══ Testes: ResourceService ─────────────────────────────────────────────────
local function makeResourceDeps()
	return {
		getFamily = function(familyId: string): any
			return EnergyFamilies.get(familyId)
		end,
		onResourceChanged = nil,
		taskImpl = testTask,
		now = clockNow,
	}
end

test("recurso: cria estado com pool da família", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(10, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if state then
		assertEq(state.resource, 100, "pool inicial")
	end
end)

test("recurso: trySpend deduz e nega sem saldo", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(11, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	assertTrue(ResourceService.trySpend(11, 15), "gasto 15 ok")
	assertEq(state.resource, 85, "pool após gasto")
	assertFalse(ResourceService.trySpend(11, 999), "gasto impossível negado")
	assertEq(state.resource, 85, "pool inalterado após negação")
end)

test("recurso: grantFlowGain respeita o cap", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(12, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	ResourceService.grantFlowGain(12, 500)
	assertEq(state.resource, 100, "cap no teto")
end)

test("recurso: cria estado em família desconhecida retorna nil", function()
	ResourceService.init(makeResourceDeps())
	assertEq(ResourceService.createState(13, "nao_existe"), nil, "nil esperado")
end)

test("recurso: tryGrantFlow aplica 6+3 e respeita cap de 1,5 s", function()
	fakeNow = 2000
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(14, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	state.resource = 50
	assertEq(ResourceService.tryGrantFlow(14), 9, "primeira: 6+3")
	assertEq(state.resource, 59, "pool após primeiro fluxo")
	assertEq(ResourceService.tryGrantFlow(14), 0, "cap 1,5 s")
	assertEq(state.resource, 59, "pool inalterado no cap")
	fakeNow = 2001.5
	assertEq(ResourceService.tryGrantFlow(14), 6, "após cap, sem bônus de 8 s")
	assertEq(state.resource, 65, "pool após segundo fluxo")
end)

test("recurso: regen 2 em combate, 0 na janela, 6 fora", function()
	fakeNow = 3000
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(15, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	assertEq(ResourceService.getRegenRate(15), 6, "nunca combateu")
	ResourceService.setCombat(15, true)
	assertEq(ResourceService.getRegenRate(15), 2, "em combate")
	ResourceService.setCombat(15, false)
	assertEq(ResourceService.getRegenRate(15), 0, "atraso de 3 s")
	fakeNow = 3003
	assertEq(ResourceService.getRegenRate(15), 6, "fora de combate")
end)

-- ══ Testes: AbilityService (fluxo completo com deps reais) ──────────────────
local function makeAbilityDeps(unlock: ((number, string) -> boolean)?)
	return {
		getAbility = function(abilityId: string): any
			return Abilities.get(abilityId)
		end,
		getCooldownRemaining = function(userId: number, abilityId: string)
			return CooldownService.getRemaining(userId, abilityId)
		end,
		startCooldown = function(userId: number, abilityId: string, seconds: number)
			CooldownService.start(userId, abilityId, seconds)
		end,
		trySpendResource = function(userId: number, amount: number)
			return ResourceService.trySpend(userId, amount)
		end,
		grantFlowGain = function(userId: number, amount: number)
			ResourceService.grantFlowGain(userId, amount)
		end,
		tryGrantFlow = function(userId: number)
			return ResourceService.tryGrantFlow(userId)
		end,
		isAlive = function(state: any)
			return CombatService.isAlive(state)
		end,
		applyDamage = function(target: any, damage: number, sourceUserId: number?)
			return CombatService.applyDamage(target, damage, sourceUserId)
		end,
		now = clockNow,
		isAbilityUnlocked = unlock,
	}
end

test("ability: comet_shoulder aplica dano 9 sem Fluxo", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(20)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(20, "umbral_aether")
	local target = makePlayerState(21, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", target)
	assertTrue(ok, "deveria ativar: " .. tostring(reason))
	assertEq(target.health, 91, "dano 9")
	assertEq(attacker.resource, 82, "custo 18, sem fluxo")
end)

test("ability: recusa sem recurso suficiente", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(30)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(30, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	attacker.resource = 5
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "deveria recusar")
	assertEq(reason, "no_resource", "motivo")
end)

test("ability: recusa em cooldown", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(40)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(40, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "segunda ativação deveria recusar")
	if reason then
		assertTrue(reason:match("^cooldown"), "motivo cooldown: " .. reason)
	end
end)

test("ability: habilidade desconhecida", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(50)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(50, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "nao_existe", nil)
	assertFalse(ok, "deveria recusar")
	assertEq(reason, "unknown_ability", "motivo")
end)

test("ability: morto não ativa", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(60)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(60, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	attacker.health = 0
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "morto não ativa")
	assertEq(reason, "dead", "motivo")
end)

test("ability: eclipse_beat desligada", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(70)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(70, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "eclipse_beat", nil)
	assertFalse(ok, "ultimate F0 desligada")
	assertEq(reason, "disabled", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
end)

test("ability: técnica locked rejeita", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(71)
	AbilityService.init(makeAbilityDeps(function(_userId: number, _abilityId: string)
		return false
	end))
	local attacker = ResourceService.createState(71, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "locked")
	assertEq(reason, "locked", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
end)

test("ability: cadência acerta 5+6 e eco 4 com Fluxo", function()
	fakeNow = 4000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(80)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(80, "umbral_aether")
	local target = makePlayerState(81, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", target)
	assertTrue(ok, "cadência: " .. tostring(reason))
	assertEq(target.health, 89, "5+6")
	assertEq(attacker.resource, 84, "custo 16")
	local reOk, reReason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertTrue(reOk, "reentrada: " .. tostring(reReason))
	assertEq(target.health, 85, "eco 4")
	assertEq(attacker.resource, 93, "fluxo 6+3")
end)

test("ability: cadência recusa reentrada fora da janela", function()
	fakeNow = 5000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(82)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(82, "umbral_aether")
	local target = makePlayerState(83, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "broken_cadence", target)
	fakeNow = 5000.2
	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertFalse(ok, "fora da janela")
	assertEq(reason, "reentry_window", "motivo")
	assertEq(target.health, 89, "sem eco")
	assertEq(attacker.resource, 84, "sem fluxo extra")
end)

test("ability: pulse_return sem golpe não contra-ataca", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(90)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(90, "umbral_aether")
	local target = makePlayerState(91, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "pulse_return", target)
	assertTrue(ok, "postura: " .. tostring(reason))
	assertEq(target.health, 100, "sem contra")
	assertEq(attacker.resource, 80, "custo 20")
end)

test("ability: pulse_return com golpe contra-ataca 8", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(92)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(92, "umbral_aether")
	local target = makePlayerState(93, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "pulse_return", target, { incomingHit = true })
	assertTrue(ok, "contra: " .. tostring(reason))
	assertEq(target.health, 92, "dano 8")
end)

test("ability: comet no fighter dummy via deps", function()
	CombatService.clear()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(94)
	local hits: { any } = {}
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string)
		table.insert(hits, {
			userId = userId,
			targetId = targetId,
			damage = damage,
			abilityId = abilityId,
		})
	end
	AbilityService.init(deps)
	CombatService.createFighter(CombatService.playerFighterId(94), "player", 100, 100)
	local dummy = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local attacker = ResourceService.createState(94, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "deveria ativar: " .. tostring(reason))
	assertEq(dummy.health, 9991, "dummy HP")
	assertEq(attacker.resource, 82, "custo 18")
	assertEq(#hits, 1, "CombatHit")
	assertEq(hits[1].targetId, "npc_training_dummy", "alvo")
	assertEq(hits[1].damage, 9, "dano")
	assertEq(hits[1].abilityId, "comet_shoulder", "ability")
end)

-- ══ Testes: CatalogService (validação) ──────────────────────────────────────
test("catálogo: dados reais passam na validação", function()
	CatalogService.init({
		Abilities = Abilities,
		Characters = Characters,
		EnergyFamilies = EnergyFamilies,
		Npcs = Npcs,
		Zones = Zones,
	})
	assertEq(CatalogService.getAbility("comet_shoulder") ~= nil, true, "habilidade acessível")
	assertEq(CatalogService.getAbility("eclipse_beat") ~= nil, true, "ultimate no catálogo")
	assertEq(CatalogService.getNpc("npc_training_dummy") ~= nil, true, "dummy no catálogo")
	assertEq(CatalogService.getZone("zone_bastion_safe") ~= nil, true, "zona segura")
	assertEq(CatalogService.getAnchor("anchor_bastion_spawn") ~= nil, true, "âncora de spawn")
end)

test("catálogo: personagem sem habilidade falha", function()
	local badChars = {
		get = function()
			return nil
		end,
		all = function()
			return {
				{
					id = "x",
					contentVersion = 1,
					displayNameKey = "k",
					descriptionKey = "k",
					energyFamilyId = "umbral_aether",
					combatArchetype = "a",
					baseHealth = 100,
					abilityIds = {},
					enabled = true,
				},
			}
		end,
	}
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = badChars,
			EnergyFamilies = EnergyFamilies,
		})
	end)
	assertFalse(ok, "validação deveria falhar")
end)

-- ══ Testes: PlayerSessionService ────────────────────────────────────────────
test("sessão: join cria estado com personagem padrão", function()
	ResourceService.init(makeResourceDeps())
	local joined: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function(userId: number)
			table.insert(joined, userId)
		end,
	})
	local fakePlayer = { UserId = 70, Name = "Teste" }
	PlayerSessionService.onPlayerJoined(fakePlayer)
	local state = ResourceService.getState(70)
	assertTrue(state ~= nil, "estado criado no join")
	if state then
		assertEq(state.characterId, "eclipse_fist", "personagem")
		assertEq(state.health, 100, "vida base")
	end
	PlayerSessionService.onPlayerLeft(fakePlayer)
	assertEq(ResourceService.getState(70), nil, "estado limpo no leave")
	assertEq(#joined, 1, "release chamado no leave")
end)

test("sessão: snapshot Ready na zona segura com dummy", function()
	CombatService.clear()
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	local snapshots: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function(_player: any, snap: { any })
			table.insert(snapshots, snap)
		end,
		getUnlocks = ProgressionService.listUnlocks,
	})
	assertEq(PlayerSessionService.isReady(80), false, "antes do join")
	ProgressionService.registerPlayer(80)
	PlayerSessionService.onPlayerJoined({ UserId = 80, Name = "Snap" })
	assertEq(PlayerSessionService.isReady(80), true, "ready após snapshot")
	assertEq(#snapshots, 1, "um snapshot")
	local snap = snapshots[1]
	assertEq(snap.zoneId, "zone_bastion_safe", "zona")
	assertEq(snap.health, 100, "HP")
	assertEq(snap.guard, 100, "guarda")
	assertEq(snap.familyId, "umbral_aether", "família")
	assertEq(snap.dummyId, "npc_training_dummy", "dummy")
	assertEq(#snap.unlocks, 0, "sem técnicas no spawn")
	assertEq(ProgressionService.grantUnlock(80, "unlock_comet_shoulder"), true, "primeira grant")
	local after = PlayerSessionService.buildSnapshot(80, "eclipse_fist", "umbral_aether")
	assertTrue(after ~= nil, "snapshot após grant")
	if after then
		assertEq(#after.unlocks, 1, "uma flag")
		assertEq(after.unlocks[1], "unlock_comet_shoulder", "comet")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 80, Name = "Snap" })
	ProgressionService.unregisterPlayer(80)
	assertEq(PlayerSessionService.isReady(80), false, "ready limpo")
	assertEq(CombatService.getFighter(CombatService.playerFighterId(80)), nil, "fighter removido")
end)

test("fatia: ready + comet locked no spawn; grant libera 9 HP no dummy", function()
	CombatService.clear()
	CooldownService.clear(100)
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function() end,
		getUnlocks = ProgressionService.listUnlocks,
	})
	assertEq(PlayerSessionService.isReady(100), false, "antes do join")
	ProgressionService.registerPlayer(100)
	PlayerSessionService.onPlayerJoined({ UserId = 100, Name = "Comet" })
	assertEq(PlayerSessionService.isReady(100), true, "ready")
	local attacker = ResourceService.getState(100)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "spawn sem técnica")
	assertEq(lockedReason, "locked", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
	assertEq(ProgressionService.grantUnlock(100, "unlock_comet_shoulder"), true, "grant")
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "comet após unlock: " .. tostring(reason))
	assertEq(attacker.resource, 82, "custo 18, sem fluxo")
	local dummy = CombatService.getFighter("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy existe")
	if dummy then
		assertEq(dummy.health, 9991, "9 de dano")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 100, Name = "Comet" })
	ProgressionService.unregisterPlayer(100)
end)

test("unlock: cadência e pulso também locked no spawn", function()
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(101)
	local deps = makeAbilityDeps()
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	ProgressionService.registerPlayer(101)
	local attacker = ResourceService.createState(101, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker")
	if not attacker then
		return
	end
	local cadOk, cadReason = AbilityService.tryActivate(attacker, "broken_cadence", nil)
	assertFalse(cadOk, "cadência locked")
	assertEq(cadReason, "locked", "motivo cadência")
	local pulseOk, pulseReason = AbilityService.tryActivate(attacker, "pulse_return", nil)
	assertFalse(pulseOk, "pulso locked")
	assertEq(pulseReason, "locked", "motivo pulso")
	assertEq(attacker.resource, 100, "não gasta")
	ProgressionService.unregisterPlayer(101)
end)

test("unlock: grant comet é idempotente; flag desconhecida recusa", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(102)
	assertEq(ProgressionService.grantUnlock(102, "unlock_comet_shoulder"), true, "primeira")
	assertEq(ProgressionService.grantUnlock(102, "unlock_comet_shoulder"), false, "segunda")
	assertEq(ProgressionService.grantUnlock(102, "nao_existe"), false, "flag desconhecida")
	assertEq(ProgressionService.hasUnlock(102, "unlock_comet_shoulder"), true, "permanece")
	assertEq(#ProgressionService.listUnlocks(102), 1, "uma flag")
	ProgressionService.unregisterPlayer(102)
end)

test("unlock: leave limpa as flags", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(103)
	ProgressionService.grantUnlock(103, "unlock_comet_shoulder")
	ProgressionService.unregisterPlayer(103)
	assertEq(ProgressionService.isAbilityUnlocked(103, "comet_shoulder"), false, "após leave")
	ProgressionService.registerPlayer(103)
	assertEq(ProgressionService.isAbilityUnlocked(103, "comet_shoulder"), false, "rejoin sem persistência")
	ProgressionService.unregisterPlayer(103)
end)

-- ══ Testes: zonas e fronteira PvP ───────────────────────────────────────────
local function makeZoneDeps(events: { any }?)
	return {
		getZone = function(zoneId: string): any
			return Zones.get(zoneId)
		end,
		getAnchor = function(anchorId: string): any
			return Zones.getAnchor(anchorId)
		end,
		now = clockNow,
		onZoneEvent = function(userId: number, event: { any })
			if events then
				table.insert(events, { userId = userId, event = event })
			end
		end,
	}
end

test("dados: 3 zonas, PvP só na livre, 6 âncoras, spawn no bastião", function()
	assertEq(#Zones.all(), 3, "3 zonas")
	for _, zone in Zones.all() do
		if zone.pvp then
			assertEq(zone.id, "zone_plain_free", "PvP só na planície")
		end
	end
	assertEq(#Zones.allAnchors(), 6, "6 âncoras")
	local spawn = Zones.getAnchor("anchor_bastion_spawn")
	assertTrue(spawn ~= nil, "anchor_bastion_spawn existe")
	if spawn then
		assertEq(spawn.zoneId, "zone_bastion_safe", "spawn na zona segura")
	end
end)

test("catálogo: zona ou âncora inválida falha validação", function()
	local function withZones(zones: any)
		return pcall(function()
			CatalogService.init({
				Abilities = Abilities,
				Characters = Characters,
				EnergyFamilies = EnergyFamilies,
				Zones = zones,
			})
		end)
	end
	-- âncora aponta para zona inexistente
	local badAnchor = withZones({
		get = Zones.get,
		all = Zones.all,
		getAnchor = Zones.getAnchor,
		allAnchors = function()
			return {
				{ id = "anchor_bad", zoneId = "zona_que_nao_existe", position = { x = 0, y = 0, z = 0 } },
			}
		end,
	})
	assertFalse(badAnchor, "âncora com zona desconhecida deveria falhar")
	-- spawn default ausente
	local noSpawn = withZones({
		get = Zones.get,
		all = Zones.all,
		getAnchor = function()
			return nil
		end,
		allAnchors = function()
			return {
				{ id = "anchor_elite", zoneId = "zone_plain_free", position = { x = 0, y = 0, z = 0 } },
			}
		end,
	})
	assertFalse(noSpawn, "sem anchor_bastion_spawn deveria falhar")
	-- zona com PvP fora da planície
	local wrongPvp = withZones({
		get = Zones.get,
		all = function()
			return {
				{ id = "zone_bastion_safe", displayNameKey = "k", kind = "safe", pvp = false },
				{ id = "zone_threshold_transition", displayNameKey = "k", kind = "transition", pvp = false },
				{ id = "zone_plain_free", displayNameKey = "k", kind = "free", pvp = true },
				{ id = "zone_bad", displayNameKey = "k", kind = "free", pvp = true },
			}
		end,
		getAnchor = Zones.getAnchor,
		allAnchors = Zones.allAnchors,
	})
	assertFalse(wrongPvp, "zona extra com PvP deveria falhar")
end)

test("zona: join começa na zona segura e sem PvP", function()
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(200)
	ZoneService.registerPlayer(201)
	assertEq(ZoneService.getPlayerZone(200), "zone_bastion_safe", "zona inicial")
	assertEq(ZoneService.canPvp(200), false, "sem PvP na segura")
	assertEq(ZoneService.canPvpBetween(200, 201), false, "sem PvP entre jogadores na segura")
end)

test("zona: sem holdConfirmed recusa a primeira ida à livre", function()
	fakeNow = 6000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(210)
	local res = ZoneService.tryEnterZone(210, "zone_threshold_transition", fakeNow, {})
	assertEq(res.ok, false, "recusa")
	assertEq(res.reason, "hold_required", "motivo")
	assertEq(ZoneService.getPlayerZone(210), "zone_bastion_safe", "continua na segura")
	assertEq(ZoneService.canPvp(210), false, "sem PvP")
end)

test("zona: com hold entra em transição 5 s e canPvp false", function()
	fakeNow = 7000
	local events: { any } = {}
	ZoneService.init(makeZoneDeps(events))
	ZoneService.registerPlayer(220)
	local res = ZoneService.tryEnterZone(220, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(res.ok, true, "aceita com hold: " .. tostring(res.reason))
	assertEq(ZoneService.getPlayerZone(220), "zone_threshold_transition", "em transição")
	assertEq(ZoneService.canPvp(220), false, "sem PvP durante a transição")
	local crossed = ZoneService.tryEnterZone(220, "zone_plain_free", fakeNow + 1, {})
	assertEq(crossed.ok, true, "cruza para a livre: " .. tostring(crossed.reason))
	assertEq(ZoneService.getPlayerZone(220), "zone_plain_free", "na livre")
	assertEq(ZoneService.canPvp(220), false, "proteção de 5 s ainda ativa")
	fakeNow = 7000 + 5
	assertEq(ZoneService.canPvp(220), true, "PvP ligado após 5 s")
	ZoneService.registerPlayer(221)
	assertEq(ZoneService.canPvpBetween(220, 221), false, "parceiro ainda na segura")
	ZoneService.tryEnterZone(221, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	ZoneService.tryEnterZone(221, "zone_plain_free", fakeNow + 1, {})
	fakeNow = 7011
	assertEq(ZoneService.canPvpBetween(220, 221), true, "ambos na livre: PvP")
	assertEq(#events, 4, "um evento por travessia")
end)

test("zona: ação hostil na transição encerra a proteção na hora", function()
	fakeNow = 8000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(230)
	ZoneService.tryEnterZone(230, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(ZoneService.canPvp(230), false, "protegido na transição")
	ZoneService.markHostileAction(230, fakeNow + 1)
	assertEq(ZoneService.getPlayerZone(230), "zone_plain_free", "ativa PvP indo à livre")
	assertEq(ZoneService.canPvp(230), true, "ação hostil encerra a proteção")
end)

test("zona: ação hostil na segura não marca lockout PvP", function()
	fakeNow = 8500
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(232)
	ZoneService.markHostileAction(232, fakeNow)
	local res = ZoneService.tryEnterZone(232, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(res.ok, true, "treino no dummy não bloqueia a fronteira: " .. tostring(res.reason))
	assertEq(ZoneService.getPlayerZone(232), "zone_threshold_transition", "entrou na transição")
end)

test("zona: voltar da transição sem hostil é livre", function()
	fakeNow = 8600
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(233)
	ZoneService.tryEnterZone(233, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	local back = ZoneService.tryEnterZone(233, "zone_bastion_safe", fakeNow + 1, {})
	assertEq(back.ok, true, "voltar é livre: " .. tostring(back.reason))
	assertEq(ZoneService.getPlayerZone(233), "zone_bastion_safe", "de volta")
	assertEq(ZoneService.canPvp(233), false, "sem PvP")
end)

test("zona: sinais da fronteira retornam os 5 IDs juntos", function()
	local SIGNAL_IDS: { [string]: boolean } = {
		physical_gate = true,
		lighting_material = true,
		ui_banner = true,
		audio_haptic = true,
		persistent_indicator = true,
	}
	local forward = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free")
	assertTrue(forward ~= nil, "segura→livre tem sinais")
	if forward then
		assertEq(#forward, 5, "5 sinais")
		for _, s in forward do
			assertTrue(SIGNAL_IDS[s] == true, "sinal " .. s)
		end
	end
	local back = ZoneService.getFrontierSignals("zone_plain_free", "zone_bastion_safe")
	assertTrue(back ~= nil and #back == 5, "volta também tem 5 sinais")
	assertEq(ZoneService.getFrontierSignals("zone_bastion_safe", "zone_bastion_safe"), nil, "sem sinais na mesma zona")
end)

test("zona: evento da travessia carrega payload completo", function()
	fakeNow = 9000
	local events: { any } = {}
	ZoneService.init(makeZoneDeps(events))
	ZoneService.registerPlayer(235)
	ZoneService.tryEnterZone(235, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(#events, 1, "evento emitido")
	local first = events[1].event
	assertEq(first.from, "zone_bastion_safe", "de")
	assertEq(first.to, "zone_threshold_transition", "para")
	assertEq(first.pvp, false, "transição não é PvP")
	assertEq(#first.signals, 5, "sinais no evento")
	assertEq(first.holdConfirmed, true, "hold confirmado")
	assertEq(first.instant, 9000, "instante")
	local crossed = ZoneService.tryEnterZone(235, "zone_plain_free", fakeNow + 1, {})
	assertEq(crossed.event.pvp, true, "destino livre marca PvP")
end)

test("zona: combate PvP recente bloqueia reentrada na segura por 15 s", function()
	fakeNow = 10000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(240)
	ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	ZoneService.tryEnterZone(240, "zone_plain_free", fakeNow + 1, {})
	fakeNow = 10000 + 6
	ZoneService.markPvpCombat(240, fakeNow)
	local blocked = ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, {})
	assertEq(blocked.ok, false, "bloqueado")
	assertEq(blocked.reason, "combat_lockout", "motivo")
	assertTrue(blocked.event ~= nil and blocked.event.lockoutRemaining ~= nil, "evento com timer")
	assertTrue(
		blocked.lockoutRemaining ~= nil and blocked.lockoutRemaining > 0 and blocked.lockoutRemaining <= 15,
		"timer visível"
	)
	fakeNow = 10000 + 6 + 15
	local free = ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, {})
	assertEq(free.ok, true, "após 15 s libera: " .. tostring(free.reason))
	ZoneService.tryEnterZone(240, "zone_bastion_safe", fakeNow + 1, {})
	assertEq(ZoneService.getPlayerZone(240), "zone_bastion_safe", "de volta à segura")
	assertEq(ZoneService.canPvp(240), false, "sem PvP na segura")
end)

test("zona: projétil/área não cruza a fronteira com dano", function()
	ZoneService.init(makeZoneDeps())
	assertEq(ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_bastion_safe"), false, "livre→segura")
	assertEq(
		ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_threshold_transition"),
		false,
		"livre→transição"
	)
	assertEq(
		ZoneService.canDamageCrossBoundary("zone_bastion_safe", "zone_threshold_transition"),
		true,
		"dentro do lado seguro"
	)
	assertEq(ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_plain_free"), true, "mesma zona livre")
	assertEq(ZoneService.canDamageCrossBoundary("zone_bastion_safe", "zone_bastion_safe"), true, "mesma zona segura")
end)

test("dados: ZoneEvent registrado como remote S→C", function()
	local zc = Remotes.Contracts.get(Remotes.Names.ZoneEvent)
	assertTrue(zc ~= nil, "ZoneEvent deveria ter contrato")
	if zc then
		assertEq(zc.direction, "ServerToClient", "direção")
		assertEq(zc.version, 1, "versão")
		assertTrue(zc.payload:find("signals") ~= nil, "payload com signals")
		assertTrue(zc.payload:find("holdConfirmed") ~= nil, "payload com holdConfirmed")
	end
end)

test("dados: ZoneCrossingIntent registrado como remote C→S", function()
	local zc = Remotes.Contracts.get(Remotes.Names.ZoneCrossingIntent)
	assertTrue(zc ~= nil, "ZoneCrossingIntent deveria ter contrato")
	if zc then
		assertEq(zc.direction, "ClientToServer", "direção")
		assertEq(zc.version, 1, "versão")
		assertTrue(zc.payload:find("toZoneId") ~= nil, "payload com toZoneId")
		assertTrue(zc.payload:find("holdConfirmed") ~= nil, "payload com holdConfirmed")
	end
end)

test("fatia: sessão Ready com ZoneService e comet intacto", function()
	CombatService.clear()
	CooldownService.clear(250)
	fakeNow = 11000
	ProgressionService.init()
	ZoneService.init(makeZoneDeps())
	ResourceService.init(makeResourceDeps())
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	local snapshots: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function(_player: any, snap: { any })
			table.insert(snapshots, snap)
		end,
		getPlayerZone = ZoneService.getPlayerZone,
		getUnlocks = ProgressionService.listUnlocks,
	})
	ProgressionService.registerPlayer(250)
	ZoneService.registerPlayer(250)
	PlayerSessionService.onPlayerJoined({ UserId = 250, Name = "Zona" })
	assertEq(PlayerSessionService.isReady(250), true, "ready")
	assertEq(#snapshots, 1, "snapshot")
	local snap = snapshots[1]
	assertEq(snap.zoneId, "zone_bastion_safe", "zona do snapshot via ZoneService")
	assertEq(#snap.unlocks, 0, "sem técnicas no spawn")
	local attacker = ResourceService.getState(250)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "locked no spawn")
	assertEq(lockedReason, "locked", "motivo")
	assertEq(ProgressionService.grantUnlock(250, "unlock_comet_shoulder"), true, "grant")
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "comet após unlock: " .. tostring(reason))
	local dummy = CombatService.getFighter("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy existe")
	if dummy then
		assertEq(dummy.health, 9991, "dummy intacto")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 250, Name = "Zona" })
	ZoneService.unregisterPlayer(250)
	ProgressionService.unregisterPlayer(250)
end)

-- ══ Runner ─────────────────────────────────────────────────────────────────
print("")
print("== Testes F0 — Anime Verse Battlegrounds ==")
print("")

local function runAll()
	for _, t in tests do
		local ok, err = pcall(t.fn)
		if ok then
			passed += 1
			print(("  ✅ %s"):format(t.name))
		else
			failed += 1
			print(("  ❌ %s"):format(t.name))
			print(("     %s"):format(tostring(err):gsub("\n", "\n     ")))
		end
	end
	print("")
	print(("Resultado: %d passaram, %d falharam"):format(passed, failed))
	if failed > 0 then
		error("Há testes falhando")
	end
end

runAll()

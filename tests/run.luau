--!strict
-- Testes unitários F0 — CooldownService, CombatService, ResourceService,
-- AbilityService, CatalogService, PlayerSessionService + dados.
-- Uso: lune run tests/run.luau

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
local Remotes = require("../src/shared/Remotes")
local CooldownService = require("../src/server/Services/CooldownService")
local CombatService = require("../src/server/Services/CombatService")
local ResourceService = require("../src/server/Services/ResourceService")
local AbilityService = require("../src/server/Services/AbilityService")
local CatalogService = require("../src/server/Services/CatalogService")
local PlayerSessionService = require("../src/server/Services/PlayerSessionService")

-- ── Helpers de estado ───────────────────────────────────────────────────────
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
test("dados: roster tem o Punho do Eclipse com 4 habilidades", function()
	local char = Characters.get("eclipse_fist")
	assertTrue(char ~= nil, "eclipse_fist deveria existir")
	if char then
		assertEq(#char.abilityIds, 4, "quantidade de habilidades")
		assertEq(char.energyFamilyId, "umbral_aether", "família")
	end
end)

test("dados: dash_strike é o molde com custo/cooldown", function()
	local ab = Abilities.get("dash_strike")
	assertTrue(ab ~= nil, "dash_strike deveria existir")
	if ab then
		assertEq(ab.kind, "Skill", "kind")
		assertEq(ab.resourceCost.amount, 15, "custo de recurso")
		assertEq(ab.cooldown.baseSeconds, 4, "cooldown")
		assertEq(ab.serverRunnerId, "dash_strike_runner", "runner")
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
end)

-- ══ Testes: CooldownService ─────────────────────────────────────────────────
test("cooldown: começa zerado", function()
	assertEq(CooldownService.getRemaining(1, "dash_strike"), 0, "cooldown inicial")
end)

test("cooldown: start aplica e expira", function()
	CooldownService.clear(1)
	CooldownService.start(1, "dash_strike", 0.05)
	local remaining = CooldownService.getRemaining(1, "dash_strike")
	assertTrue(remaining > 0 and remaining <= 0.06, "cooldown ativo")
	-- espera real (busy-wait curto; task global é nil no Lune)
	local start = os.clock()
	while os.clock() - start < 0.06 do
	end
	assertEq(CooldownService.getRemaining(1, "dash_strike"), 0, "cooldown expirado")
end)

test("cooldown: clear zera", function()
	CooldownService.start(1, "dash_strike", 10)
	CooldownService.clear(1)
	assertEq(CooldownService.getRemaining(1, "dash_strike"), 0, "após clear")
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

-- ══ Testes: ResourceService ─────────────────────────────────────────────────
local function makeResourceDeps()
	return {
		getFamily = function(familyId: string): any
			return EnergyFamilies.get(familyId)
		end,
		onResourceChanged = nil,
		taskImpl = testTask,
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

-- ══ Testes: AbilityService (fluxo completo com deps reais) ──────────────────
local function makeAbilityDeps()
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
		isAlive = function(state: any)
			return CombatService.isAlive(state)
		end,
		applyDamage = function(target: any, damage: number, sourceUserId: number?)
			return CombatService.applyDamage(target, damage, sourceUserId)
		end,
	}
end

test("ability: ativação válida com alvo (dash_strike)", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(20)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(20, "umbral_aether")
	local target = makePlayerState(21, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "dash_strike", target)
	assertTrue(ok, "deveria ativar: " .. tostring(reason))
	assertEq(target.health, 88, "dano 12 aplicado")
	-- custo 15, mas o runner concede prêmio de fluxo +6 (acerto confirmado)
	assertEq(attacker.resource, 91, "custo 15 − fluxo +6 = 91")
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
	local ok, reason = AbilityService.tryActivate(attacker, "dash_strike", nil)
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
	AbilityService.tryActivate(attacker, "dash_strike", nil)
	local ok, reason = AbilityService.tryActivate(attacker, "dash_strike", nil)
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
	local ok, reason = AbilityService.tryActivate(attacker, "dash_strike", nil)
	assertFalse(ok, "morto não ativa")
	assertEq(reason, "dead", "motivo")
end)

-- ══ Testes: CatalogService (validação) ──────────────────────────────────────
test("catálogo: dados reais passam na validação", function()
	CatalogService.init({
		Abilities = Abilities,
		Characters = Characters,
		EnergyFamilies = EnergyFamilies,
	})
	assertEq(CatalogService.getAbility("dash_strike") ~= nil, true, "habilidade acessível")
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

--!strict
-- Testes unitários F0 — CooldownService, CombatService, ResourceService,
-- AbilityService, CatalogService, PlayerSessionService + dados.
-- Uso: lune run tests/run.luau
-- Contrato da fatia: docs/13-F0-SLICE.md §19.

require("./harness")
local fs = require("@lune/fs")

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
local RemoteEnvelope = require("../src/shared/RemoteEnvelope")
local Zones = require("../src/shared/Data/Zones")
local CooldownService = require("../src/server/Services/CooldownService")
local CombatService = require("../src/server/Services/CombatService")
local ResourceService = require("../src/server/Services/ResourceService")
local AbilityService = require("../src/server/Services/AbilityService")
local CatalogService = require("../src/server/Services/CatalogService")
local PlayerSessionService = require("../src/server/Services/PlayerSessionService")
local ZoneService = require("../src/server/Services/ZoneService")
local ProgressionService = require("../src/server/Services/ProgressionService")
local QuestService = require("../src/server/Services/QuestService")
local Quests = require("../src/shared/Data/Quests")
local Locale = require("../src/shared/Data/Locale")
local Geometry = require("../src/shared/Geometry")
local SpatialService = require("../src/server/Services/SpatialService")
local EnemyService = require("../src/server/Services/EnemyService")
local ClientState = require("../src/client/Controllers/ClientState")
local InputController = require("../src/client/Controllers/InputController")
local CharacterController = require("../src/client/Controllers/CharacterController")
local AbilityController = require("../src/client/Controllers/AbilityController")
local CombatFeedbackController = require("../src/client/Controllers/CombatFeedbackController")
local ResourceController = require("../src/client/Controllers/ResourceController")
local ZoneController = require("../src/client/Controllers/ZoneController")

test("bootstrap: serviços são filhos do Script Server gerado pelo Rojo", function()
	local source = fs.readFile("src/server/init.server.lua")
	assertTrue(source:find('local Services = script:WaitForChild("Services")', 1, true) ~= nil, "raiz de Services")
	assertTrue(source:find("script.Parent.Services", 1, true) == nil, "não procura Services em ServerScriptService")
end)

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
	local c = Remotes.Contracts.get(Remotes.Names.AbilityIntent)
	assertTrue(c ~= nil, "AbilityIntent deveria ter contrato")
	if c then
		assertEq(c.direction, "ClientToServer", "direção")
		assertEq(c.version, 2, "versão")
	end
	local snap = Remotes.Contracts.get(Remotes.Names.SessionSnapshot)
	assertTrue(snap ~= nil, "SessionSnapshot deveria ter contrato")
	if snap then
		assertEq(snap.direction, "ServerToClient", "snapshot S→C")
	end
end)

test("dados: envelope v2 aceita somente contrato completo", function()
	local envelope = RemoteEnvelope.create("AbilityIntent", { abilityId = "comet_shoulder" }, "req-1", 1)
	local payload, reason = RemoteEnvelope.decode(envelope, "AbilityIntent")
	assertTrue(payload ~= nil, "envelope válido")
	assertEq(reason, nil, "sem rejeição")
	assertEq(payload and payload.abilityId, "comet_shoulder", "payload preservado")
	assertEq(RemoteEnvelope.version(), 2, "versão canônica")
end)

test("dados: envelope v2 rejeita versão, sequência e ação inválidas", function()
	local wrongVersion = RemoteEnvelope.create("AbilityIntent", {}, "req-1", 1)
	wrongVersion.protocolVersion = 1
	local payload, reason = RemoteEnvelope.decode(wrongVersion, "AbilityIntent")
	assertEq(payload, nil, "versão antiga rejeitada")
	assertEq(reason, "protocol_version", "motivo versão")

	local wrongSequence = RemoteEnvelope.create("AbilityIntent", {}, "req-2", 0)
	local sequencePayload, sequenceReason = RemoteEnvelope.decode(wrongSequence, "AbilityIntent")
	assertEq(sequencePayload, nil, "sequência zero rejeitada")
	assertEq(sequenceReason, "client_sequence", "motivo sequência")

	local wrongAction = RemoteEnvelope.create("DashIntent", {}, "req-3", 2)
	local actionPayload, actionReason = RemoteEnvelope.decode(wrongAction, "AbilityIntent")
	assertEq(actionPayload, nil, "ação trocada rejeitada")
	assertEq(actionReason, "action_mismatch", "motivo ação")
end)

test("cliente: input não emite antes do SessionSnapshot ready", function()
	local state = ClientState.new(clockNow)
	local input = InputController.new(state, clockNow)
	local emitted = 0
	InputController.subscribe(input, function(_action: any, _payload: any)
		emitted += 1
	end)
	local ok, reason = InputController.dispatch(input, "BasicLight", {})
	assertFalse(ok, "boot não emite")
	assertEq(reason, "not_ready", "motivo")
	assertEq(emitted, 0, "nenhuma intenção")
end)

test("cliente: input limita combate a 8 intenções por segundo", function()
	fakeNow = 2000
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local emitted = 0
	InputController.subscribe(input, function(_action: any, _payload: any)
		emitted += 1
	end)
	for _ = 1, 8 do
		assertTrue(InputController.dispatch(input, "BasicLight", {}), "primeiras oito")
	end
	local ninth, reason = InputController.dispatch(input, "Dash", {})
	assertFalse(ninth, "nona descartada")
	assertEq(reason, "rate_limited", "motivo")
	assertEq(emitted, 8, "oito emitidas")
	fakeNow += 1.01
	assertTrue(InputController.dispatch(input, "Dash", {}), "nova janela")
end)

test("cliente: toque recusa terceiro botão simultâneo", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	assertTrue(InputController.touchBegin(input, "a", "GuardDown", {}), "primeiro")
	assertTrue(InputController.touchBegin(input, "b", "Ability1", {}), "segundo")
	local ok, reason = InputController.touchBegin(input, "c", "Dash", {})
	assertFalse(ok, "terceiro recusado")
	assertEq(reason, "touch_chord_limit", "motivo")
	InputController.touchEnd(input, "a", "GuardUp", {})
	assertTrue(InputController.touchBegin(input, "c", "Dash", {}), "libera após soltar")
end)

test("cliente: CharacterController envia somente intenção sem alvo ou dano", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
	})
	InputController.dispatch(input, "BasicLight", {})
	InputController.dispatch(input, "GuardDown", {})
	InputController.dispatch(input, "Dash", {})
	assertEq(#sent, 3, "três intenções")
	assertEq(sent[1].payload.kind, "light", "ataque sem alvo")
	assertEq(sent[1].payload.targetId, nil, "sem alvo")
	assertEq(sent[1].payload.damage, nil, "sem dano")
	assertEq(sent[2].payload.phase, "down", "guarda sem sucesso inventado")
	assertEq(sent[3].payload.direction.z, -1, "direção unitária fallback")
end)

test("cliente: AbilityController mantém 3 slots, oculta ultimate e exige unlock", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local controller = AbilityController.new({
		state = state,
		stateApi = ClientState,
		input = input,
		inputSubscribe = InputController.subscribe,
		abilities = Abilities,
		characters = Characters,
		send = function(_remoteName: string, _action: string, payload: { [string]: any })
			table.insert(sent, payload)
		end,
		guid = function()
			return "execution-1"
		end,
	})
	assertEq(#controller.slotIds, 3, "três slots")
	for _, abilityId in controller.slotIds do
		assertFalse(abilityId == "eclipse_beat", "ultimate desligada oculta")
	end
	local locked, reason = AbilityController.activateSlot(controller, 1)
	assertFalse(locked, "locked não envia")
	assertEq(reason, "locked", "motivo")
	assertEq(#sent, 0, "sem remote")
	state.unlocks.unlock_comet_shoulder = true
	local ok, executionId = AbilityController.activateSlot(controller, 1)
	assertTrue(ok, "destravada envia")
	assertEq(executionId, "execution-1", "correlação")
	assertEq(sent[1].abilityId, "comet_shoulder", "ID sem nome público")
	assertEq(sent[1].executionId, "execution-1", "executionId no payload")
	assertEq(sent[1].damage, nil, "sem dano")
	assertTrue(ClientState.cooldownRemaining(state, "comet_shoulder") > 0, "cooldown radial recebe estado")
end)

test("cliente: rejeição reconcilia cooldown e feedback nunca mostra código", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	ClientState.setCooldown(state, "comet_shoulder", 7)
	local input = InputController.new(state, clockNow)
	local ability = AbilityController.new({
		state = state,
		stateApi = ClientState,
		input = input,
		inputSubscribe = InputController.subscribe,
		abilities = Abilities,
		characters = Characters,
		send = function() end,
		guid = function()
			return "execution-2"
		end,
	})
	local feedback = CombatFeedbackController.new(state, ClientState)
	local payload = { abilityId = "comet_shoulder", reason = "no_resource" }
	AbilityController.onRejected(ability, payload)
	CombatFeedbackController.onRejected(feedback, payload)
	assertEq(ClientState.cooldownRemaining(state, "comet_shoulder"), 0, "predição desfeita")
	assertEq(ClientState.feedback(state), "hud.feedback_no_resource", "chave localizada")
	assertFalse(ClientState.feedback(state) == payload.reason, "código não vai para a tela")
end)

test("cliente: recurso, zona e perda só mudam após ready", function()
	local state = ClientState.new(clockNow)
	local resource = ResourceController.new(state, ClientState)
	local zone = ZoneController.new(state, ClientState)
	ResourceController.onChanged(resource, { current = 0, max = 100, depleted = true })
	ZoneController.onZoneEvent(zone, { to = "zone_plain_free", pvp = true })
	assertEq(state.resource, 0, "pré-ready permanece inicial")
	assertEq(state.zoneId, "", "pré-ready sem zona")
	ClientState.applySnapshot(state, { ready = true, resource = 50, zoneId = "zone_bastion_safe" })
	ResourceController.onChanged(resource, { current = 0, max = 100, depleted = true })
	ZoneController.onZoneEvent(zone, { to = "zone_plain_free", pvp = true })
	ZoneController.onDelta(zone, { deathPenalty = 15 })
	assertEq(state.resource, 0, "recurso autoritativo")
	assertTrue(state.depleted, "esgotado visível")
	assertEq(state.zoneId, "zone_plain_free", "zona autoritativa")
	assertTrue(state.pvp, "PvP ativo")
	assertEq(ClientState.feedback(state), "hud.feedback_death_loss", "perda resumida localizada")
end)

test("cliente: hold de fronteira exige 0,6 s e usa apenas destino oferecido pelo servidor", function()
	fakeNow = 2100
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true, zoneId = "zone_bastion_safe" })
	local sent: { any } = {}
	local zone = ZoneController.new(
		state,
		ClientState,
		nil,
		nil,
		function(remoteName: string, action: string, payload: any)
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
		clockNow
	)
	ZoneController.onZoneEvent(zone, {
		from = "zone_bastion_safe",
		to = "zone_threshold_transition",
		pvp = false,
		signals = { "physical_gate" },
		holdConfirmed = false,
		rejectedReason = "hold_required",
	})
	assertEq(state.zoneId, "zone_bastion_safe", "rejeição não falsifica zona")
	assertTrue(state.zoneHoldRequired, "prompt visível")
	ZoneController.onAction(zone, "ZoneHoldDown")
	fakeNow += 0.59
	ZoneController.onAction(zone, "ZoneHoldUp")
	assertEq(#sent, 0, "hold curto não cruza")
	ZoneController.onAction(zone, "ZoneHoldDown")
	fakeNow += 0.61
	ZoneController.onAction(zone, "ZoneHoldUp")
	assertEq(#sent, 1, "hold confirmado")
	assertEq(sent[1].payload.toZoneId, "zone_threshold_transition", "destino do evento autoritativo")
	assertEq(sent[1].payload.position, nil, "sem posição declarada pelo cliente")
end)

test("cliente: Locale cobre todo texto do HUD F0 em PT-BR e EN", function()
	local keys = {
		"hud.health",
		"hud.guard",
		"hud.resource",
		"hud.resource_depleted",
		"hud.ability_locked",
		"hud.feedback_hit",
		"hud.feedback_guard",
		"hud.feedback_no_resource",
		"hud.feedback_cooldown",
		"hud.feedback_rejected",
		"hud.feedback_death_loss",
		"hud.control_attack",
		"hud.control_guard",
		"hud.control_dash",
	}
	for _, key in keys do
		assertTrue(Locale.hasKey(key), key .. " existe")
		assertFalse(Locale.get(key, "pt-br") == key, key .. " PT-BR")
		assertFalse(Locale.get(key, "en") == key, key .. " EN")
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

test("dados: estilhaço errante segue o baseline da fatia", function()
	local shard = Npcs.get("enemy_wandering_shard")
	assertTrue(shard ~= nil, "estilhaço deveria existir")
	if shard then
		assertEq(shard.kind, "enemy", "kind")
		assertEq(shard.maxHealth, 40, "vida")
		assertEq(shard.attackDamage, 6, "dano")
		assertEq(shard.attackRange, 4, "esfera 4 studs")
		assertEq(shard.telegraphMs, 400, "telegraph")
		assertEq(shard.moveSpeed, 12, "velocidade")
		assertEq(shard.respawnSeconds, 45, "respawn")
		assertEq(shard.xpUnconsolidated, 25, "XP")
		assertEq(shard.maxAlive, 4, "população")
		assertEq(shard.zoneId, "zone_plain_free", "zona")
		assertEq(shard.grantsXp, true, "concede XP")
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

test("combate: estilhaço telegraph depois dano 6", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 40, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local windup = CombatService.tryShardCycle(shard, player, 1.0, 4, true, 6, 4, 0.4, 0.6)
	assertEq(windup.phase, "telegraph", "telegraph")
	assertEq(windup.damage, 0, "ainda sem dano")
	assertEq(player.health, 100, "HP intacto")
	local early = CombatService.tryShardCycle(shard, player, 1.2, 4, true, 6, 4, 0.4, 0.6)
	assertEq(early.reason, "telegraph", "ainda no telegraph")
	local hit = CombatService.tryShardCycle(shard, player, 1.4, 4, true, 6, 4, 0.4, 0.6)
	assertEq(hit.ok, true, "acerto")
	assertEq(hit.damage, 6, "dano")
	assertEq(hit.phase, "attack", "fase")
	assertEq(player.health, 94, "HP")
end)

test("combate: estilhaço sem aggro através da fronteira", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 40, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local denied = CombatService.tryShardCycle(shard, player, 1.0, 2, false, 6, 4, 0.4, 0.6)
	assertEq(denied.reason, "no_aggro", "sem aggro")
	assertEq(player.health, 100, "HP intacto")
	assertEq(shard.aiPhase, "idle", "volta a idle")
end)

test("combate: estilhaço recusa fora da esfera de 4 studs", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 40, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local far = CombatService.tryShardCycle(shard, player, 1.0, 5, true, 6, 4, 0.4, 0.6)
	assertEq(far.reason, "out_of_range", "fora")
end)

test("combate: estilhaço recovery bloqueia o próximo golpe", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 40, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	CombatService.tryShardCycle(shard, player, 1.0, 4, true, 6, 4, 0.4, 0.6)
	CombatService.tryShardCycle(shard, player, 1.4, 4, true, 6, 4, 0.4, 0.6)
	local blocked = CombatService.tryShardCycle(shard, player, 1.5, 4, true, 6, 4, 0.4, 0.6)
	assertEq(blocked.reason, "recovery", "recovery")
	assertEq(player.health, 94, "um único acerto")
end)

test("combate: estilhaço respawn 45 s e bloqueia com combate perto", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 40, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	CombatService.tryLight(player, shard, 1.0, "front")
	-- 5+5+6+10 = 26, precisa de mais para matar 40
	CombatService.tryLight(player, shard, 1.2, "front")
	CombatService.tryLight(player, shard, 1.4, "front")
	CombatService.tryLight(player, shard, 1.6, "front")
	CombatService.tryLight(player, shard, 2.3, "front")
	CombatService.tryLight(player, shard, 2.5, "front")
	CombatService.tryLight(player, shard, 2.7, "front")
	assertEq(shard.health, 0, "morto")
	assertTrue(shard.diedAt > 0, "diedAt")
	local tooSoon = CombatService.tryRespawn(shard, 20, 45, false)
	assertEq(tooSoon, false, "antes de 45 s")
	local nearby = CombatService.tryRespawn(shard, 50, 45, true)
	assertEq(nearby, false, "combate perto")
	local ok = CombatService.tryRespawn(shard, 50, 45, false)
	assertEq(ok, true, "respawn")
	assertEq(shard.health, 40, "vida cheia")
	assertEq(shard.aiPhase, "idle", "idle")
end)

test("combate: no máximo 4 estilhaços vivos", function()
	CombatService.clear()
	for i = 1, 4 do
		CombatService.createFighter("enemy_wandering_shard:" .. tostring(i), "npc", 40, 0)
	end
	assertEq(CombatService.countAliveNpcs("enemy_wandering_shard"), 4, "4 vivos")
	assertEq(CombatService.canSpawnNpc("enemy_wandering_shard", 4), false, "cap")
	local one = CombatService.getFighter("enemy_wandering_shard:1")
	assertTrue(one ~= nil, "existe")
	if one then
		one.health = 0
	end
	assertEq(CombatService.canSpawnNpc("enemy_wandering_shard", 4), true, "vaga após morte")
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

test("ability: cadência acerta 5+6 e eco 4 com Fluxo no tick", function()
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
	-- A reentrada só abre 120 ms após o fim do active do golpe 2 (400 ms).
	local early, earlyReason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertFalse(early, "antes da janela não reentra")
	assertEq(earlyReason, "reentry_window", "motivo")
	fakeNow = 4000.45
	local reOk, reReason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertTrue(reOk, "reentrada na janela: " .. tostring(reReason))
	assertEq(target.health, 89, "reentrada não aplica dano (eco agendado)")
	assertEq(attacker.resource, 84, "reentrada não gasta")
	-- Eco sai 350 ms depois, no tick.
	AbilityService.tick(4000.8)
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

test("ability: pulse_return abre postura sem dano; erro vira recovery 600 ms", function()
	fakeNow = 9000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(90)
	CombatService.clear()
	CombatService.createFighter("player:90", "player", 100, 100)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getFighterById = CombatService.getFighter
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	AbilityService.init(deps)
	local attacker = ResourceService.createState(90, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "pulse_return")
	assertTrue(ok, "postura: " .. tostring(reason))
	assertEq(attacker.resource, 80, "custo 20")
	local fighter = CombatService.getFighter("player:90")
	assertTrue(fighter ~= nil, "fighter existe")
	if fighter then
		assertTrue(fighter.pulseStanceUntil > 0, "postura ativa")
		-- Postura sem golpe: expira e entra em recovery 600 ms.
		local expired = CombatService.pulseTick(fighter, 9000.26)
		assertEq(expired, true, "postura expirou sem golpe")
		assertTrue(CombatService.isPulseRecovery(fighter, 9000.3), "em recovery")
		assertEq(
			CombatService.tryLight(
				fighter,
				CombatService.createFighter("player:90b", "player", 100, 100),
				9000.3,
				"front"
			).reason,
			"recovery",
			"recovery bloqueia ataque"
		)
		assertFalse(CombatService.isPulseRecovery(fighter, 9000.9), "após 600 ms libera")
	end
end)

test("ability: pulse_return reduz 50% de um golpe frontal e contra-ataca 8", function()
	fakeNow = 9100
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(92)
	CombatService.clear()
	CombatService.createFighter("player:92", "player", 100, 100)
	CombatService.createFighter("player:93", "player", 100, 100)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getFighterById = CombatService.getFighter
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	AbilityService.init(deps)
	local attacker = ResourceService.createState(92, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "pulse_return")
	local defender = CombatService.getFighter("player:92")
	local striker = CombatService.getFighter("player:93")
	assertTrue(defender ~= nil and striker ~= nil, "fighters")
	if not defender or not striker then
		return
	end
	-- Golpe frontal de 10 (pesado) durante a postura: reduz 50% → 5.
	local hit = CombatService.tryHeavy(striker, defender, 9100.1, "front")
	assertTrue(hit.ok, "golpe conecta")
	assertEq(hit.pulseCounter, true, "contra disparado")
	assertEq(defender.health, 95, "dano reduzido a 50% (5 de 10)")
	-- O contra: 8 de dano no atacante (empurrão é espacial, fora do serviço).
	local counter = CombatService.tryPulseCounter(striker, 9100.1)
	assertEq(counter.damage, 8, "contra 8")
	assertEq(striker.health, 92, "atacante tomou 8")
	-- Segundo golpe na mesma postura: já foi usado, dano cheio.
	local second = CombatService.tryHeavy(striker, defender, 9100.2, "front")
	assertEq(second.pulseCounter, nil, "postura consumida (um golpe por postura)")
	assertEq(defender.health, 85, "dano cheio no segundo golpe")
end)

test("ability: pulse_return costas e slam do elite vencem a postura", function()
	fakeNow = 9200
	CombatService.clear()
	local defender = CombatService.createFighter("player:94", "player", 100, 100)
	local striker = CombatService.createFighter("player:95", "player", 100, 100)
	CombatService.setPulseStance(defender, 9200)
	-- Costas ignoram a postura (docs/13 §6.3: agarrão/costas vencem).
	local backHit = CombatService.tryHeavy(striker, defender, 9200.05, "back")
	assertEq(backHit.pulseCounter, nil, "costas não reduzem")
	assertEq(defender.health, 90, "dano cheio 10")
	-- Slam do elite é unblockable para o Pulso.
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 80, 0)
	CombatService.setPulseStance(striker, 9200.1)
	local slam = CombatService.tryEliteCycle(elite, striker, 9200.2, 5, true, {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 5,
		comboTelegraphSeconds = 0.3,
		slamDamage = 12,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	})
	-- Ciclo começa em combo; forçamos o padrão para slam.
	elite.elitePattern = "slam"
	slam = CombatService.tryEliteCycle(elite, striker, 9200.9, 5, true, {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 5,
		comboTelegraphSeconds = 0.3,
		slamDamage = 12,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	})
	assertEq(slam.ok, true, "slam conecta")
	assertEq(slam.damage, 12, "slam não é reduzido pela postura")
	assertEq(striker.health, 88, "dano cheio do slam")
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
		Quests = Quests,
		Locale = Locale,
	})
	assertEq(CatalogService.getQuest("quest_hunt") ~= nil, true, "objetivo 1 no catálogo")
	assertEq(CatalogService.getQuest("quest_elite") ~= nil, true, "objetivo 2 no catálogo")
	assertEq(CatalogService.getQuest("quest_flow") ~= nil, true, "objetivo 3 no catálogo")
	assertEq(#CatalogService.questChain(), 3, "cadeia com os 3 objetivos")
	assertEq(CatalogService.getNpc("npc_threshold_instructor") ~= nil, true, "instrutor no catálogo")
	assertEq(CatalogService.getAbility("comet_shoulder") ~= nil, true, "habilidade acessível")
	assertEq(CatalogService.getAbility("eclipse_beat") ~= nil, true, "ultimate no catálogo")
	assertEq(CatalogService.getNpc("npc_training_dummy") ~= nil, true, "dummy no catálogo")
	assertEq(CatalogService.getNpc("enemy_wandering_shard") ~= nil, true, "estilhaço no catálogo")
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

test("dados: 3 zonas, PvP só na livre, âncoras da spec, spawn no bastião", function()
	assertEq(#Zones.all(), 3, "3 zonas")
	for _, zone in Zones.all() do
		if zone.pvp then
			assertEq(zone.id, "zone_plain_free", "PvP só na planície")
		end
	end
	-- 6 âncoras persistidas de §8.3 + os 6 pontos de Estilhaço de §8.1.
	local required = {
		"anchor_bastion_spawn",
		"anchor_bastion_return",
		"anchor_training",
		"anchor_gate_north",
		"anchor_gate_west",
		"anchor_elite",
	}
	for _, anchorId in required do
		assertTrue(Zones.getAnchor(anchorId) ~= nil, "âncora obrigatória " .. anchorId)
	end
	assertEq(#Zones.allAnchors(), #required + #Zones.shardAnchors(), "âncoras persistidas + pontos de Estilhaço")
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
		assertEq(zc.version, 2, "versão")
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

-- ══ Testes: item 7 — Locale, XP e objetivo 1 ────────────────────────────────
local function makeQuestDeps(events: { any }?): any
	return {
		getQuest = Quests.get,
		chain = Quests.chain,
		awardXp = ProgressionService.awardXp,
		grantUnlock = ProgressionService.grantUnlock,
		now = clockNow,
		onQuestEvent = function(userId: number, event: any)
			if events then
				table.insert(events, { userId = userId, event = event })
			end
		end,
	}
end

test("dados: Locale cobre as chaves da fatia em PT-BR e EN", function()
	local required = {
		"character.eclipse_fist.name",
		"family.umbral_aether.name",
		"ability.comet_shoulder.name",
		"ability.broken_cadence.name",
		"ability.pulse_return.name",
		"zone.bastion.name",
		"zone.plain.name",
		"hud.zone_safe",
		"hud.pvp_active",
		"hud.pvp_hold",
		"ftue.dummy_hint",
		"quest.hunt.tracker",
		"npc.threshold_instructor.name",
	}
	for _, key in required do
		assertTrue(Locale.hasKey(key), "chave ausente: " .. key)
		assertTrue(Locale.get(key, "en") ~= key, "sem tradução EN: " .. key)
	end
	assertEq(Locale.defaultLocale(), "pt-br", "default PT-BR")
	assertEq(Locale.get("character.eclipse_fist.name"), "Punho do Eclipse", "nome público")
	assertEq(Locale.get("chave.inexistente"), "chave.inexistente", "chave desconhecida devolve a própria chave")
end)

test("dados: tracker formata {n} com o progresso", function()
	assertEq(Locale.format("quest.hunt.tracker", { n = 0 }), "Derrote Estilhaços: 0/3", "0/3")
	assertEq(Locale.format("quest.hunt.tracker", { n = 2 }), "Derrote Estilhaços: 2/3", "2/3")
end)

test("dados: objetivo 1 é 3 Estilhaços, +40 XP e unlock do Cometa", function()
	local def = Quests.get("quest_hunt")
	assertTrue(def ~= nil, "quest_hunt deveria existir")
	if not def then
		return
	end
	assertEq(def.kind, "kill", "kind")
	assertEq(def.targetId, "enemy_wandering_shard", "alvo")
	assertEq(def.requiredCount, 3, "3 kills")
	assertEq(def.xpReward, 40, "+40 XP")
	assertEq(def.unlockFlag, "unlock_comet_shoulder", "unlock")
	assertEq(def.acceptFlag, "quest_hunt_accepted", "flag de aceite")
	assertEq(def.giverNpcId, "npc_threshold_instructor", "ofertante")
	assertEq(def.autoAcceptAfterSeconds, 90, "aceite forçado em 90 s")
end)

test("catálogo: objetivo com alvo ou ofertante desconhecido falha validação", function()
	local function withQuests(all: any)
		return pcall(function()
			CatalogService.init({
				Abilities = Abilities,
				Characters = Characters,
				EnergyFamilies = EnergyFamilies,
				Npcs = Npcs,
				Zones = Zones,
				Quests = {
					get = Quests.get,
					all = all,
					chain = Quests.chain,
				},
			})
		end)
	end
	local base = {
		id = "quest_bad",
		trackerKey = "quest.hunt.tracker",
		kind = "kill",
		targetId = "enemy_wandering_shard",
		requiredCount = 3,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 90,
		xpReward = 40,
		unlockFlag = "unlock_comet_shoulder",
		acceptFlag = "quest_hunt_accepted",
		enabled = true,
	}
	local function variant(overrides: { [string]: any }): any
		local copy: { [string]: any } = table.clone(base)
		for k, v in overrides do
			copy[k] = v
		end
		return function()
			return { copy }
		end
	end
	assertFalse(withQuests(variant({ targetId = "enemy_que_nao_existe" })), "alvo desconhecido deveria falhar")
	assertFalse(withQuests(variant({ giverNpcId = "npc_fantasma" })), "ofertante desconhecido deveria falhar")
	assertFalse(withQuests(variant({ requiredCount = 0 })), "requiredCount 0 deveria falhar")
	assertFalse(withQuests(variant({ acceptFlag = "" })), "acceptFlag vazia deveria falhar")
end)

test("catálogo: chave de UI sem entrada no Locale falha validação", function()
	local badNpcs = {
		get = Npcs.get,
		all = function()
			local out: { any } = {}
			for _, npc in Npcs.all() do
				table.insert(out, npc)
			end
			table.insert(out, {
				id = "npc_sem_locale",
				displayNameKey = "npc.sem_locale.name",
				kind = "instructor",
				maxHealth = 1,
				maxGuard = 0,
				attackDamage = 0,
				attackRange = 0,
				attackPeriodSeconds = 0,
				telegraphMs = 0,
				grantsXp = false,
				enabled = true,
			})
			return out
		end,
	}
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = badNpcs,
			Zones = Zones,
			Locale = Locale,
		})
	end)
	assertFalse(ok, "displayNameKey sem tradução deveria falhar")
end)

test("XP: kill do Estilhaço credita 25 não consolidado", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(300)
	local shard = Npcs.get("enemy_wandering_shard")
	assertTrue(shard ~= nil, "estilhaço no catálogo")
	local award = ProgressionService.creditNpcKill(300, shard, "anchor_gate_north")
	assertEq(award.granted, 25, "XP do kill")
	assertEq(ProgressionService.getUnconsolidatedXp(300), 25, "não consolidado")
	assertEq(ProgressionService.getAnchorKills(300, "anchor_gate_north"), 1, "kills na âncora")
	-- Dummy não dá XP
	local dummy = Npcs.get("npc_training_dummy")
	local none = ProgressionService.creditNpcKill(300, dummy, "anchor_training")
	assertEq(none.granted, 0, "dummy não credita")
	assertEq(none.reason, "no_xp_source", "motivo")
end)

test("XP: retorno decrescente por âncora — 6×25, depois 12, depois 0", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(301)
	local shard = Npcs.get("enemy_wandering_shard")
	for i = 1, 6 do
		local award = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
		assertEq(award.granted, 25, ("kill %d ainda paga cheio"):format(i))
	end
	assertEq(ProgressionService.getUnconsolidatedXp(301), 150, "6 kills = 150")
	for i = 7, 12 do
		local award = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
		assertEq(award.granted, 12, ("kill %d paga reduzido"):format(i))
	end
	assertEq(ProgressionService.getUnconsolidatedXp(301), 222, "12 kills = 150 + 72")
	local zeroed = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
	assertEq(zeroed.granted, 0, "13º kill não paga")
	assertEq(zeroed.reason, "diminished", "motivo")
	assertEq(ProgressionService.getUnconsolidatedXp(301), 222, "saldo intacto")
end)

test("XP: o decréscimo é por âncora, não global", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(302)
	local shard = Npcs.get("enemy_wandering_shard")
	for _ = 1, 6 do
		ProgressionService.creditNpcKill(302, shard, "anchor_gate_north")
	end
	local other = ProgressionService.creditNpcKill(302, shard, "anchor_gate_west")
	assertEq(other.granted, 25, "outra âncora paga cheio")
	local same = ProgressionService.creditNpcKill(302, shard, "anchor_gate_north")
	assertEq(same.granted, 12, "âncora esgotada continua reduzida")
end)

test("XP: teto de emissão da sessão é 800", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(303)
	assertEq(ProgressionService.sessionXpCap(), 800, "teto")
	local first = ProgressionService.awardXp(303, 790)
	assertEq(first.granted, 790, "primeira emissão")
	local partial = ProgressionService.awardXp(303, 40)
	assertEq(partial.granted, 10, "corta no teto")
	assertEq(partial.withheld, 30, "recusado")
	assertEq(partial.reason, "session_cap", "motivo")
	local blocked = ProgressionService.awardXp(303, 25)
	assertEq(blocked.granted, 0, "nada além do teto")
	assertEq(ProgressionService.getUnconsolidatedXp(303), 800, "saldo no teto")
	assertEq(ProgressionService.awardXp(303, -5).granted, 0, "valor negativo não credita")
	assertEq(ProgressionService.awardXp(999, 25).reason, "unknown_player", "jogador desconhecido")
end)

test("objetivo: aceite no Instrutor marca a flag e abre o tracker", function()
	fakeNow = 20000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(310)
	QuestService.registerPlayer(310, fakeNow)
	assertEq(QuestService.getTracker(310), nil, "sem tracker antes do aceite")
	local ok, reason = QuestService.tryAcceptFromNpc(310, "npc_threshold_instructor", fakeNow)
	assertTrue(ok, "aceite: " .. tostring(reason))
	assertTrue(ProgressionService.hasUnlock(310, "quest_hunt_accepted"), "flag de aceite")
	local tracker = QuestService.getTracker(310)
	assertTrue(tracker ~= nil, "tracker visível")
	if tracker then
		assertEq(tracker.trackerKey, "quest.hunt.tracker", "chave do tracker")
		assertEq(tracker.progress, 0, "0/3")
		assertEq(tracker.required, 3, "3 kills")
	end
	assertEq(#events, 1, "um evento de aceite")
	assertEq(events[1].event.acceptSource, "npc", "aceite pelo NPC")
	-- A cadeia é sequencial: com o objetivo 1 ativo, o NPC não oferece o 2.
	local again, againReason = QuestService.tryAcceptFromNpc(310, "npc_threshold_instructor", fakeNow)
	assertFalse(again, "segundo aceite não repete")
	assertEq(againReason, "already_active", "objetivo 1 ainda ativo")
	assertFalse(QuestService.tryAcceptFromNpc(310, "npc_desconhecido", fakeNow), "NPC errado não oferta")
end)

test("objetivo: kill antes do aceite não conta", function()
	fakeNow = 21000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(311)
	QuestService.registerPlayer(311, fakeNow)
	local events = QuestService.creditKill(311, "enemy_wandering_shard", fakeNow + 1)
	assertEq(#events, 0, "sem progresso sem objetivo ativo")
	local progress = QuestService.getProgress(311, "quest_hunt")
	assertTrue(progress ~= nil, "estado existe")
	if progress then
		assertEq(progress.state, "offered", "ainda ofertado")
		assertEq(progress.progress, 0, "sem progresso")
	end
end)

test("objetivo: tracker aparece sozinho 90 s depois de ignorar o NPC", function()
	fakeNow = 22000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(312)
	QuestService.registerPlayer(312, fakeNow)
	QuestService.tick(312, fakeNow + 89)
	assertEq(QuestService.getTracker(312), nil, "antes de 90 s o tracker não aparece")
	QuestService.tick(312, fakeNow + 90)
	local tracker = QuestService.getTracker(312)
	assertTrue(tracker ~= nil, "tracker forçado após 90 s")
	assertTrue(ProgressionService.hasUnlock(312, "quest_hunt_accepted"), "flag do aceite forçado")
	assertEq(#events, 1, "um evento")
	assertEq(events[1].event.acceptSource, "timeout", "origem timeout")
	QuestService.tick(312, fakeNow + 200)
	assertEq(#events, 1, "tick é idempotente")
end)

test("objetivo: 3º kill completa, dá +40 XP e destrava o Ombro Cometa", function()
	fakeNow = 23000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(313)
	QuestService.registerPlayer(313, fakeNow)
	QuestService.tryAcceptFromNpc(313, "npc_threshold_instructor", fakeNow)

	local first = QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 1)
	assertEq(#first, 1, "evento de progresso")
	assertEq(first[1].progress, 1, "1/3")
	assertEq(first[1].state, "active", "ainda ativo")
	assertFalse(ProgressionService.hasUnlock(313, "unlock_comet_shoulder"), "sem unlock em 1/3")

	QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 2)
	local third = QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 3)
	assertEq(#third, 1, "evento de conclusão")
	assertEq(third[1].state, "completed", "completo")
	assertEq(third[1].progress, 3, "3/3")
	assertEq(third[1].xpGranted, 40, "+40 XP do objetivo")
	assertEq(third[1].unlockFlag, "unlock_comet_shoulder", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(313, "unlock_comet_shoulder"), "Cometa destravado")
	assertEq(ProgressionService.getUnconsolidatedXp(313), 40, "só o XP do objetivo (kills entram pelo NPC)")
	assertEq(QuestService.getTracker(313), nil, "tracker some ao completar")
end)

test("objetivo: kill depois de completo não repete prêmio", function()
	fakeNow = 24000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(314)
	QuestService.registerPlayer(314, fakeNow)
	QuestService.tryAcceptFromNpc(314, "npc_threshold_instructor", fakeNow)
	for i = 1, 3 do
		QuestService.creditKill(314, "enemy_wandering_shard", fakeNow + i)
	end
	assertEq(ProgressionService.getUnconsolidatedXp(314), 40, "prêmio pago uma vez")
	local extra = QuestService.creditKill(314, "enemy_wandering_shard", fakeNow + 10)
	assertEq(#extra, 0, "sem evento novo")
	assertEq(ProgressionService.getUnconsolidatedXp(314), 40, "XP não dobra")
	local progress = QuestService.getProgress(314, "quest_hunt")
	if progress then
		assertEq(progress.progress, 3, "progresso não passa do requerido")
	end
	-- Alvo fora do objetivo não conta
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(315)
	QuestService.registerPlayer(315, fakeNow)
	QuestService.tryAcceptFromNpc(315, "npc_threshold_instructor", fakeNow)
	assertEq(#QuestService.creditKill(315, "npc_training_dummy", fakeNow + 1), 0, "dummy não conta no objetivo")
end)

test("combate: killed só na transição vivo → morto", function()
	CombatService.clear()
	local attacker = CombatService.createFighter("player:400", "player", 100, 100)
	local shard = CombatService.createFighter("enemy_wandering_shard@anchor_gate_north#1", "npc", 10, 0)
	local hit = CombatService.tryLight(attacker, shard, 100, "front")
	assertEq(hit.damage, 5, "primeiro golpe")
	assertEq(hit.killed, nil, "ainda vivo")
	local kill = CombatService.tryLight(attacker, shard, 100.2, "front")
	assertEq(shard.health, 0, "morto")
	assertEq(kill.killed, true, "kill sinalizado")
	assertEq(shard.diedAt, 100.2, "instante da morte")
	local corpse = CombatService.tryLight(attacker, shard, 100.4, "front")
	assertEq(corpse.killed, nil, "golpe em morto não repete o kill")
	assertEq(shard.diedAt, 100.2, "diedAt não é re-carimbado (não empurra o respawn)")
end)

test("dados: InteractionIntent C→S e StateDelta S→C", function()
	local interaction = Remotes.Contracts.get(Remotes.Names.InteractionIntent)
	assertTrue(interaction ~= nil, "InteractionIntent deveria ter contrato")
	if interaction then
		assertEq(interaction.direction, "ClientToServer", "direção")
		assertEq(interaction.version, 2, "versão")
		assertTrue(interaction.payload:find("npcId") ~= nil, "payload com npcId")
		assertFalse(interaction.payload:find("reward") ~= nil, "cliente não informa recompensa")
	end
	local delta = Remotes.Contracts.get(Remotes.Names.StateDelta)
	assertTrue(delta ~= nil, "StateDelta deveria ter contrato")
	if delta then
		assertEq(delta.direction, "ServerToClient", "direção")
		assertTrue(delta.payload:find("objective") ~= nil, "payload com objective")
		assertTrue(delta.payload:find("unconsolidatedXp") ~= nil, "payload com XP")
	end
	local snapshot = Remotes.Contracts.get(Remotes.Names.SessionSnapshot)
	assertTrue(snapshot ~= nil and snapshot.payload:find("objective") ~= nil, "snapshot carrega objetivo")
end)

test("fatia: roteiro 0–5 min — spawn locked, objetivo, 3 kills e Cometa liberado", function()
	CombatService.clear()
	CooldownService.clear(320)
	fakeNow = 25000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
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
		getObjective = QuestService.getTracker,
		getUnconsolidatedXp = ProgressionService.getUnconsolidatedXp,
	})

	-- 0–15 s: spawn na segura, sem técnicas e sem objetivo aceito
	ProgressionService.registerPlayer(320)
	ZoneService.registerPlayer(320)
	QuestService.registerPlayer(320, fakeNow)
	ProgressionService.grantUnlock(320, "ftue_spawned")
	PlayerSessionService.onPlayerJoined({ UserId = 320, Name = "Roteiro" })
	assertEq(#snapshots, 1, "snapshot")
	assertEq(snapshots[1].objective, nil, "sem objetivo no spawn")
	assertEq(snapshots[1].unconsolidatedXp, 0, "sem XP no spawn")
	local attacker = ResourceService.getState(320)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "Cometa locked no spawn")
	assertEq(lockedReason, "locked", "motivo")

	-- ~60 s–3 min: NPC oferece o objetivo 1
	assertTrue(QuestService.tryAcceptFromNpc(320, "npc_threshold_instructor", fakeNow + 60), "aceite no NPC")

	-- 3–5 min: cruzar a fronteira e matar 3 Estilhaços
	ZoneService.tryEnterZone(320, "zone_threshold_transition", fakeNow + 70, { holdConfirmed = true })
	ZoneService.tryEnterZone(320, "zone_plain_free", fakeNow + 71, {})
	assertEq(ZoneService.getPlayerZone(320), "zone_plain_free", "na planície")
	local shardDef = Npcs.get("enemy_wandering_shard")
	for i = 1, 3 do
		ProgressionService.creditNpcKill(320, shardDef, "anchor_gate_north")
		QuestService.creditKill(320, "enemy_wandering_shard", fakeNow + 100 + i)
	end
	-- 3 × 25 (kills) + 40 (objetivo)
	assertEq(ProgressionService.getUnconsolidatedXp(320), 115, "XP dos kills + objetivo")
	assertTrue(ProgressionService.hasUnlock(320, "unlock_comet_shoulder"), "Cometa destravado no 3º kill")
	assertEq(QuestService.getTracker(320), nil, "tracker some")

	-- 5 min: Cometa utilizável e cobrado
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "Cometa após o objetivo: " .. tostring(reason))
	assertEq(attacker.resource, 82, "custo 18")
	local dummy = CombatService.getFighter("npc_training_dummy")
	if dummy then
		assertEq(dummy.health, 9991, "dano 9 no alvo")
	end
	-- As outras duas técnicas continuam trancadas
	assertFalse(ProgressionService.hasUnlock(320, "unlock_broken_cadence"), "Cadência ainda locked (item 9)")
	assertFalse(ProgressionService.hasUnlock(320, "unlock_pulse_return"), "Pulso ainda locked (item 10)")

	-- leave: XP da sessão some (persistência é o item 11)
	PlayerSessionService.onPlayerLeft({ UserId = 320, Name = "Roteiro" })
	QuestService.unregisterPlayer(320)
	ZoneService.unregisterPlayer(320)
	ProgressionService.unregisterPlayer(320)
	assertEq(ProgressionService.getUnconsolidatedXp(320), 0, "sem persistência ainda")
	assertEq(QuestService.getProgress(320, "quest_hunt"), nil, "estado do objetivo limpo")
end)

-- ══ Testes: camada espacial (greybox, hitbox, lunge, AI) ────────────────────
local function vec(x: number, y: number, z: number): any
	return { x = x, y = y, z = z }
end

test("geometria: distância, distância horizontal e normalize", function()
	assertEq(Geometry.distance(vec(0, 0, 0), vec(3, 4, 0)), 5, "distância 3-4-5")
	assertEq(Geometry.horizontalDistance(vec(0, 0, 0), vec(3, 99, 4)), 5, "altura é ignorada no plano")
	local unit = Geometry.normalize(vec(0, 0, -8))
	assertEq(unit.z, -1, "unitário aponta ao norte")
	local zero = Geometry.normalize(vec(0, 0, 0))
	assertEq(zero.x, 0, "vetor nulo não vira NaN")
	assertEq(zero.z, 0, "vetor nulo não vira NaN")
end)

test("geometria: costas ignoram guarda, frente não", function()
	local targetPos = vec(0, 0, 0)
	local look = vec(0, 0, -1) -- olhando para o norte
	assertEq(Geometry.facing(targetPos, look, vec(0, 0, -5)), "front", "atacante ao norte está de frente")
	assertEq(Geometry.facing(targetPos, look, vec(0, 0, 5)), "back", "atacante ao sul está pelas costas")
	assertEq(Geometry.facing(targetPos, look, vec(5, 0, 0)), "front", "perpendicular conta como frente")
	assertEq(Geometry.facing(targetPos, vec(0, 0, 0), vec(0, 0, 5)), "front", "sem olhar conhecido assume frente")
end)

test("geometria: cápsula do trajeto acerta no meio e erra fora do raio", function()
	local from = vec(0, 0, 0)
	local to = vec(0, 0, -8)
	assertTrue(Geometry.capsuleContains(from, to, 2, vec(0, 0, -4)), "no eixo do trajeto")
	assertTrue(Geometry.capsuleContains(from, to, 2, vec(1.9, 0, -4)), "dentro do raio")
	assertFalse(Geometry.capsuleContains(from, to, 2, vec(2.5, 0, -4)), "fora do raio")
	assertFalse(Geometry.capsuleContains(from, to, 2, vec(0, 0, -11)), "além do fim do trajeto")
	assertEq(Geometry.distanceToSegment(from, from, vec(0, 0, -3)), 3, "segmento degenerado vira ponto")
end)

test("geometria: lunge anda 7, respeita o cap 8 e para no bloqueio", function()
	local origin = vec(0, 0, 0)
	local north = vec(0, 0, -1)
	local free = Geometry.resolveLunge(origin, north, 7, 8, {})
	assertEq(free.traveled, 7, "anda os 7 studs")
	assertEq(free.blocked, false, "sem bloqueio")
	assertTrue(math.abs(free.position.z + 7) < 1e-6, "para em z = -7")

	local capped = Geometry.resolveLunge(origin, north, 20, 8, {})
	assertEq(capped.traveled, 8, "cap absoluto de 8 studs")

	local wall = { { id = "wall", position = vec(0, 0, -5), radius = 2 } }
	local blocked = Geometry.resolveLunge(origin, north, 7, 8, wall)
	assertEq(blocked.blocked, true, "bloqueado")
	assertEq(blocked.blockedBy, "wall", "quem bloqueou")
	assertTrue(blocked.traveled < 3.1, "para antes do contato: " .. tostring(blocked.traveled))
	assertTrue(blocked.traveled > 0, "mas avança até encostar")
end)

test("geometria: moveToward respeita a velocidade e para no alcance", function()
	local from = vec(0, 0, 0)
	local to = vec(0, 0, -30)
	local step = Geometry.moveToward(from, to, 12, 0.5, 4)
	assertTrue(math.abs(step.z + 6) < 1e-6, "12 studs/s por 0,5 s = 6 studs")
	local arrived = Geometry.moveToward(vec(0, 0, -25), to, 12, 1, 4)
	assertTrue(math.abs(arrived.z + 26) < 1e-6, "para a 4 studs do alvo, sem ultrapassar")
	local touching = Geometry.moveToward(vec(0, 0, -27), to, 12, 1, 4)
	assertEq(touching.z, -27, "já dentro do alcance não anda")
end)

test("greybox: volumes resolvem a zona de cada âncora", function()
	for _, anchor in Zones.allAnchors() do
		local resolved = Zones.zoneAtPosition(anchor.position)
		assertEq(resolved, anchor.zoneId, "âncora " .. anchor.id)
	end
	assertEq(Zones.zoneAtPosition(vec(0, 0, 0)), "zone_bastion_safe", "centro do Bastião")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -36)), "zone_threshold_transition", "vão do Portão Norte")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -80)), "zone_plain_free", "planície")
	assertEq(Zones.zoneAtPosition(vec(0, 0, 500)), nil, "fora de todo volume")
	-- A transição vence a borda compartilhada: no plano do portão o jogador
	-- já está na fronteira, não mais na zona segura.
	assertEq(Zones.zoneAtPosition(vec(0, 0, -32)), "zone_threshold_transition", "plano exato do portão")
end)

test("greybox: 6 pontos de Estilhaço, 24 studs entre si e 20 do portão", function()
	local shardIds = Zones.shardAnchors()
	assertEq(#shardIds, 6, "6 pontos")
	for i = 1, #shardIds do
		local a = Zones.getAnchor(shardIds[i])
		assertTrue(a ~= nil, "ponto existe: " .. shardIds[i])
		if a then
			assertEq(a.zoneId, "zone_plain_free", "ponto na planície: " .. shardIds[i])
			for j = i + 1, #shardIds do
				local b = Zones.getAnchor(shardIds[j])
				if b then
					local d = Geometry.horizontalDistance(a.position, b.position)
					assertTrue(d >= 24, ("%s→%s = %.1f studs"):format(shardIds[i], shardIds[j], d))
				end
			end
			for _, gateId in Zones.gateAnchors() do
				local gate = Zones.getAnchor(gateId)
				if gate then
					local d = Geometry.horizontalDistance(a.position, gate.position)
					assertTrue(d >= 20, ("%s a %.1f do portão %s"):format(shardIds[i], d, gateId))
				end
			end
		end
	end
end)

test("catálogo: âncora fora do volume da zona declarada falha validação", function()
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = Npcs,
			Zones = {
				get = Zones.get,
				all = Zones.all,
				getAnchor = Zones.getAnchor,
				allAnchors = function()
					local out: { any } = {}
					for _, anchor in Zones.allAnchors() do
						table.insert(out, anchor)
					end
					-- Declara zona segura mas fica no meio da planície.
					table.insert(out, {
						id = "anchor_mentiroso",
						zoneId = "zone_bastion_safe",
						position = { x = 0, y = 0, z = -90 },
					})
					return out
				end,
				zoneAtPosition = Zones.zoneAtPosition,
				shardAnchors = Zones.shardAnchors,
				gateAnchors = Zones.gateAnchors,
			},
		})
	end)
	assertFalse(ok, "âncora incoerente com a geometria deveria falhar")
end)

test("espaço: hitbox à frente acerta o alvo e ignora quem está atrás", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:900", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("alvo_frente", vec(0, 0, -3), vec(0, 0, 1))
	-- Está ao sul do atacante e olha para o sul (+z): de costas para ele.
	SpatialService.setTransform("alvo_atras", vec(0, 0, 6), vec(0, 0, 1))
	SpatialService.setTransform("alvo_longe", vec(0, 0, -30), vec(0, 0, 1))

	local hits = SpatialService.overlapInFront("player:900", 2, 4, nil, 1)
	assertEq(#hits, 1, "máx. 1 alvo")
	assertEq(hits[1], "alvo_frente", "acerta quem está à frente")

	local todos = SpatialService.overlapInFront("player:900", 2, 4, nil)
	assertEq(#todos, 1, "quem está atrás e longe fica fora")

	assertEq(SpatialService.facingOf("alvo_frente", "player:900"), "front", "alvo encara o atacante")
	assertEq(SpatialService.facingOf("alvo_atras", "player:900"), "back", "atacante pelas costas")
	assertEq(SpatialService.distanceBetween("player:900", "alvo_frente"), 3, "distância")
	assertEq(SpatialService.distanceBetween("player:900", "fantasma"), nil, "sem transform devolve nil")
end)

test("espaço: Ombro Cometa avança 7, commita a posição e acerta 1 alvo", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:901", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("inimigo", vec(0, 0, -6), vec(0, 0, 1))

	local resolution = SpatialService.resolveCometShoulder("player:901", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
		blocks = function(): boolean
			return false
		end,
	})
	assertEq(resolution.traveled, 7, "avanço de 7 studs")
	assertEq(resolution.targetId, "inimigo", "alvo na cápsula do trajeto")
	-- O alvo encara a origem do avanço. Medir na posição final diria "back",
	-- porque o lunge de 7 ultrapassa quem está a 6 — e furaria a guarda.
	assertEq(resolution.facing, "front", "lado do golpe medido da origem")
	local committed = SpatialService.getPosition("player:901")
	assertTrue(committed ~= nil, "posição commitada")
	if committed then
		assertTrue(math.abs(committed.z + 7) < 1e-6, "servidor moveu o atacante")
	end
end)

test("espaço: guarda inimiga para o avanço do Cometa", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:902", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("guardiao", vec(0, 0, -5), vec(0, 0, 1))

	local resolution = SpatialService.resolveCometShoulder("player:902", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
		blocks = function(fighterId: string): boolean
			return fighterId == "guardiao"
		end,
	})
	assertEq(resolution.blocked, true, "avanço travado")
	assertEq(resolution.blockedBy, "guardiao", "quem travou")
	assertTrue(resolution.traveled < 7, "não completou os 7 studs")
	local committed = SpatialService.getPosition("player:902")
	if committed then
		assertTrue(committed.z > -7, "parou antes do destino")
	end
end)

test("espaço: Cometa sem ninguém no trajeto avança e não acerta", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:903", vec(0, 0, 0), vec(0, 0, -1))
	local resolution = SpatialService.resolveCometShoulder("player:903", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
	})
	assertEq(resolution.traveled, 7, "avança")
	assertEq(resolution.targetId, nil, "sem alvo")
	assertEq(resolution.blocked, false, "sem bloqueio")
end)

-- Monta EnemyService + CombatService + SpatialService reais.
local function makeEnemyWorld(targets: { any }): ()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return targets
		end,
	})
end

test("inimigo: spawn respeita o teto de 4 vivos e usa as âncoras", function()
	makeEnemyWorld({})
	local spawned = EnemyService.spawnInitial()
	assertEq(spawned, 4, "spawna até o teto de 4")
	assertEq(#EnemyService.list(), 4, "4 registrados")
	assertEq(EnemyService.spawnInitial(), 0, "segunda chamada não duplica")
	local first = EnemyService.list()[1]
	assertEq(first.fighterId, "enemy_wandering_shard@anchor_shard_1#1", "id carrega a âncora")
	assertEq(first.zoneId, "zone_plain_free", "vive na planície")
	local position = SpatialService.getPosition(first.fighterId)
	local anchor = Zones.getAnchor("anchor_shard_1")
	assertTrue(position ~= nil and anchor ~= nil, "posicionado na âncora")
	if position and anchor then
		assertEq(position.x, anchor.position.x, "x da âncora")
		assertEq(position.z, anchor.position.z, "z da âncora")
	end
end)

test("inimigo: persegue a 12 studs/s e ataca só depois do telegraph", function()
	local playerId = "player:910"
	local targets = { { fighterId = playerId, userId = 910, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()

	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	assertTrue(anchor ~= nil, "âncora")
	if not anchor then
		return
	end
	-- Jogador 10 studs ao norte da âncora, na planície.
	local playerPos = vec(anchor.position.x, anchor.position.y, anchor.position.z - 10)
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, playerPos, vec(0, 0, 1))

	-- 1º tick: 12 studs/s por 0,5 s = 6 studs, parando a 4 (o alcance).
	-- Chegando ao alcance no mesmo tick, o ciclo abre o telegraph.
	EnemyService.tick(1000, 0.5)
	local afterMove = SpatialService.getPosition(shardId)
	assertTrue(afterMove ~= nil, "moveu")
	if afterMove then
		local d = Geometry.horizontalDistance(afterMove, playerPos)
		assertTrue(math.abs(d - 4) < 1e-6, "parou no alcance de 4: " .. tostring(d))
	end
	local player = CombatService.getFighter(playerId)
	local shard = CombatService.getFighter(shardId)
	assertTrue(player ~= nil and shard ~= nil, "fighters")
	if not player or not shard then
		return
	end
	assertEq(shard.aiPhase, "telegraph", "abre o telegraph ao alcançar")
	assertEq(player.health, 100, "telegraph não causa dano")

	-- Dentro dos 400 ms o golpe ainda não sai.
	EnemyService.tick(1000.2, 0.1)
	assertEq(player.health, 100, "telegraph de 400 ms ainda correndo")

	-- Passados os 400 ms, o golpe conecta com 6 de dano.
	EnemyService.tick(1000.5, 0.1)
	assertEq(player.health, 94, "dano 6 após o telegraph")
	assertEq(shard.aiPhase, "recovery", "entra em recovery")
end)

test("inimigo: sem aggro através da fronteira", function()
	local playerId = "player:911"
	-- Mesmo perto, um jogador na zona segura não é alvo.
	local targets = { { fighterId = playerId, userId = 911, zoneId = "zone_bastion_safe" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z - 2),
		vec(0, 0, 1)
	)

	EnemyService.tick(2000, 0.5)
	EnemyService.tick(2001, 0.5)
	local player = CombatService.getFighter(playerId)
	assertTrue(player ~= nil and player.health == 100, "jogador na segura não leva dano")
	local shard = CombatService.getFighter(shardId)
	assertTrue(shard ~= nil and shard.aiPhase == "idle", "Estilhaço fica em idle")
	local moved = SpatialService.getPosition(shardId)
	if moved then
		assertEq(moved.z, anchor.position.z, "nem persegue")
	end
end)

test("inimigo: respawn de 45 s bloqueia com jogador perto da âncora", function()
	local playerId = "player:912"
	local targets = { { fighterId = playerId, userId = 912, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	CombatService.createFighter(playerId, "player", 100, 100)
	-- Jogador a 5 studs da âncora: dentro do raio de 20.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x + 5, anchor.position.y, anchor.position.z),
		vec(0, 0, 1)
	)

	local shard = CombatService.getFighter(shardId)
	assertTrue(shard ~= nil, "estilhaço")
	if not shard then
		return
	end
	shard.health = 0
	shard.diedAt = 3000

	EnemyService.tick(3000 + 50, 0.5)
	assertEq(shard.health, 0, "combate perto bloqueia o respawn")

	-- Jogador se afasta para além dos 20 studs.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x + 40, anchor.position.y, anchor.position.z),
		vec(0, 0, 1)
	)
	EnemyService.tick(3000 + 51, 0.5)
	assertEq(shard.health, 40, "respawn com a área limpa")
	local back = SpatialService.getPosition(shardId)
	if back then
		assertEq(back.z, anchor.position.z, "volta para a mesma âncora")
	end
end)

test("inimigo: kill reporta a âncora para o crédito de XP", function()
	local kills: { any } = {}
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, fighterId: string)
			table.insert(kills, { userId = userId, fighterId = fighterId })
		end,
	})
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	assertTrue(EnemyService.isEnemy(shardId), "registrado como inimigo")
	assertEq(EnemyService.reportKill(920, shardId), true, "kill reportado")
	assertEq(#kills, 1, "callback disparado")
	assertEq(kills[1].userId, 920, "autor")
	assertEq(kills[1].fighterId, shardId, "fighter")
	assertFalse(EnemyService.reportKill(920, "fighter_inexistente"), "id desconhecido não reporta")
	EnemyService.despawnAll()
	assertEq(#EnemyService.list(), 0, "despawn limpa")
end)

test("dados: EnemyEvent registrado como remote S→C", function()
	local contract = Remotes.Contracts.get(Remotes.Names.EnemyEvent)
	assertTrue(contract ~= nil, "EnemyEvent deveria ter contrato")
	if contract then
		assertEq(contract.direction, "ServerToClient", "direção")
		assertEq(contract.version, 1, "versão")
		assertTrue(contract.payload:find("telegraph") ~= nil, "payload com telegraph")
	end
end)

-- ══ Testes: item 9 — elite, leeching e cooldown de XP ───────────────────────
test("dados: Estilhaço Ancorado é o baseline da spec §9.3", function()
	local elite = Npcs.get("enemy_anchored_shard")
	assertTrue(elite ~= nil, "enemy_anchored_shard deveria existir")
	if not elite then
		return
	end
	assertEq(elite.kind, "enemy", "kind")
	assertEq(elite.maxHealth, 80, "vida 80")
	assertEq(elite.attackPattern, "elite", "padrão")
	assertEq(elite.eliteSlamDamage, 12, "slam 12")
	assertEq(elite.eliteSlamTelegraphMs, 700, "slam telegraph 700 ms")
	assertEq(elite.eliteComboDamage, 5, "combo 5")
	assertEq(elite.eliteComboTelegraphMs, 300, "combo telegraph 300 ms")
	assertEq(elite.respawnSeconds, 180, "respawn 180 s")
	assertEq(elite.xpUnconsolidated, 80, "XP 80")
	assertEq(elite.xpCooldownSeconds, 180, "cooldown 180 s por jogador")
	assertEq(elite.leechDamagePct, 0.01, "leeching ≥ 1% da vida")
	assertEq(elite.leechStaySeconds, 8, "leeching 8 s no raio")
	assertEq(elite.maxAlive, 1, "um único vivo")
	assertEq(elite.zoneId, "zone_plain_free", "vive na planície")
end)

test("dados: quest_elite derrota o Ancorado e destrava a Cadência", function()
	local quest = Quests.get("quest_elite")
	assertTrue(quest ~= nil, "quest_elite deveria existir")
	if not quest then
		return
	end
	assertEq(quest.kind, "kill", "kind")
	assertEq(quest.targetId, "enemy_anchored_shard", "alvo")
	assertEq(quest.requiredCount, 1, "um kill")
	assertEq(quest.xpReward, 60, "+60 XP")
	assertEq(quest.unlockFlag, "unlock_broken_cadence", "unlock da Cadência")
	assertEq(quest.acceptFlag, "quest_elite_accepted", "flag de aceite")
	assertEq(quest.autoAcceptAfterSeconds, 900, "aceite forçado só após 15 min")
end)

test("dados: quest_flow pede um eco da Cadência e destrava o Pulso", function()
	local quest = Quests.get("quest_flow")
	assertTrue(quest ~= nil, "quest_flow deveria existir")
	if not quest then
		return
	end
	assertEq(quest.kind, "flow_echo", "kind de timing")
	assertEq(quest.targetId, "broken_cadence", "habilidade que gera o eco")
	assertEq(quest.requiredCount, 1, "um eco")
	assertEq(quest.xpReward, 40, "+40 XP")
	assertEq(quest.unlockFlag, "unlock_pulse_return", "unlock do Pulso")
	assertEq(quest.acceptFlag, "quest_flow_accepted", "flag de aceite")
	assertEq(quest.autoAcceptAfterSeconds, 2700, "aceite forçado só após 45 min")
end)

test("catálogo: dados reais validam com elite e os 3 objetivos", function()
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = Npcs,
			Zones = Zones,
			Quests = Quests,
			Locale = Locale,
		})
	end)
	assertTrue(ok, "catálogo completo deveria validar")
end)

test("combate: elite alterna combo 5+5 e slam 12, com guarda cortada em 30%", function()
	CombatService.clear()
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 80, 0)
	local player = CombatService.createFighter("player:950", "player", 100, 100)
	local params = {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 5,
		comboTelegraphSeconds = 0.3,
		slamDamage = 12,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	}
	-- Ciclo 1: combo (5+5) após o telegraph de 300 ms.
	local combo = CombatService.tryEliteCycle(elite, player, 1000, 5, true, params)
	assertEq(combo.ok, true, "ciclo abre")
	assertEq(combo.phase, "telegraph", "telegraph primeiro")
	assertEq(combo.damage, 0, "telegraph sem dano")
	local comboHit = CombatService.tryEliteCycle(elite, player, 1000.31, 5, true, params)
	assertEq(comboHit.ok, true, "combo conecta")
	assertEq(comboHit.phase, "attack", "ataque")
	assertEq(comboHit.damage, 10, "5+5")
	assertEq(player.health, 90, "HP após o combo")
	-- Recovery: golpe dentro do recovery não sai.
	local during = CombatService.tryEliteCycle(elite, player, 1000.5, 5, true, params)
	assertEq(during.ok, false, "em recovery")
	assertEq(during.reason, "recovery", "motivo")
	-- Ciclo 2: slam (12) após o telegraph de 700 ms. Recovery termina em
	-- 1000.31 + 0.8 = 1001.11; o próximo ciclo abre depois disso.
	local slamTelegraph = CombatService.tryEliteCycle(elite, player, 1001.2, 5, true, params)
	assertEq(slamTelegraph.phase, "telegraph", "slam em telegraph")
	assertEq(slamTelegraph.damage, 0, "sem dano")
	local slamHit = CombatService.tryEliteCycle(elite, player, 1001.91, 5, true, params)
	assertEq(slamHit.ok, true, "slam conecta")
	assertEq(slamHit.damage, 12, "dano 12")
	assertEq(player.health, 78, "HP após o slam")
end)

test("combate: slam do elite atravessa a guarda (reduz só 30%)", function()
	CombatService.clear()
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 80, 0)
	local guard = CombatService.createFighter("player:951", "player", 100, 100)
	CombatService.setGuard(guard, true, 1100)
	local params = {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 5,
		comboTelegraphSeconds = 0.3,
		slamDamage = 12,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	}
	elite.elitePattern = "slam"
	CombatService.tryEliteCycle(elite, guard, 1100, 5, true, params)
	local slam = CombatService.tryEliteCycle(elite, guard, 1100.71, 5, true, params)
	assertEq(slam.ok, true, "slam conecta")
	-- Guarda reduz 30% → 70% do dano passa: ceil(12 * 0.7) = 9.
	assertEq(slam.damage, 9, "dano bloqueado 70%")
	assertEq(guard.health, 91, "HP após slam na guarda")
	assertEq(guard.guard, 88, "guarda sofre o dano cheio (12)")
end)

test("XP: elite paga 80 com cooldown de 3 min por jogador", function()
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	fakeNow = 30000
	ProgressionService.registerPlayer(960)
	local elite = Npcs.get("enemy_anchored_shard")
	assertTrue(elite ~= nil, "elite no catálogo")
	local first = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(first.granted, 80, "primeiro crédito paga 80")
	assertEq(ProgressionService.getUnconsolidatedXp(960), 80, "XP não consolidado")
	-- Mesmo jogador, outro kill dentro de 180 s: recusa.
	fakeNow = 30000 + 100
	local blocked = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(blocked.granted, 0, "dentro do cooldown não paga")
	assertEq(blocked.reason, "xp_cooldown", "motivo")
	-- Depois de 180 s do primeiro: paga de novo.
	fakeNow = 30000 + 181
	local again = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(again.granted, 80, "após 180 s paga de novo")
	assertEq(ProgressionService.getUnconsolidatedXp(960), 160, "80 + 80")
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(960)
end)

test("inimigo: elite spawna único na âncora da cratera", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
	})
	assertEq(EnemyService.spawnElite(), true, "spawna o elite")
	assertEq(EnemyService.spawnElite(), false, "segunda chamada não duplica")
	local elite = CombatService.getFighter("enemy_anchored_shard@anchor_elite#1")
	assertTrue(elite ~= nil, "fighter do elite existe")
	if elite then
		assertEq(elite.maxHealth, 80, "80 de vida")
		local position = SpatialService.getPosition("enemy_anchored_shard@anchor_elite#1")
		local anchor = Zones.getAnchor("anchor_elite")
		assertTrue(position ~= nil and anchor ~= nil, "posicionado")
		if position and anchor then
			assertEq(position.x, anchor.position.x, "x da cratera")
			assertEq(position.z, anchor.position.z, "z da cratera")
		end
	end
	EnemyService.despawnAll()
end)

test("inimigo: leeching credita dano ≥ 1% da vida na morte do elite", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	local kills: { any } = {}
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, fighterId: string)
			table.insert(kills, { userId = userId, fighterId = fighterId })
		end,
	})
	EnemyService.spawnElite()
	local fighterId = "enemy_anchored_shard@anchor_elite#1"
	local elite = CombatService.getFighter(fighterId)
	assertTrue(elite ~= nil, "elite existe")
	if not elite then
		return
	end
	-- Jogador 970 causa 1 de dano (≥ 1% de 80); jogador 971 causa 0.5 (abaixo).
	EnemyService.registerEliteDamage(fighterId, 970, 1)
	EnemyService.registerEliteDamage(fighterId, 971, 0.5)
	elite.health = 0
	local credited = EnemyService.resolveEliteDeath(fighterId, 4000)
	assertEq(#credited, 1, "só o elegível")
	assertEq(credited[1], 970, "970 creditado")
	assertEq(#kills, 1, "um onKill")
	assertEq(kills[1].userId, 970, "autor")
	assertEq(kills[1].fighterId, fighterId, "fighter")
	-- Resolver de novo não repete (eliteDeathResolved guarda).
	EnemyService.resolveEliteDeath(fighterId, 4001)
	assertEq(#kills, 1, "idempotente")
	EnemyService.despawnAll()
end)

test("inimigo: leeching credita 8 s no raio mesmo sem causar dano", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	local kills: { any } = {}
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, killedFighterId: string)
			table.insert(kills, { userId = userId, fighterId = killedFighterId })
		end,
	})
	EnemyService.spawnElite()
	local fighterId = "enemy_anchored_shard@anchor_elite#1"
	local elite = CombatService.getFighter(fighterId)
	assertTrue(elite ~= nil, "elite existe")
	if not elite then
		return
	end
	-- Jogador 972 fica 8 s no raio (sem dano): elegível por tempo.
	local elitePos = SpatialService.getPosition(fighterId)
	local playerId = "player:972"
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, { x = elitePos.x + 5, y = 0, z = elitePos.z }, { x = 0, y = 0, z = 1 })
	local targets = { { fighterId = playerId, userId = 972, zoneId = "zone_plain_free" } }
	-- Reinit com o alvo elegível a aggro.
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return targets
		end,
		onKill = function(userId: number, killedFighterId: string)
			table.insert(kills, { userId = userId, fighterId = killedFighterId })
		end,
	})
	EnemyService.spawnElite()
	-- 8 ticks de 1 s dentro do raio.
	for i = 1, 8 do
		EnemyService.tickElite(5000 + i, 1)
	end
	elite.health = 0
	local credited = EnemyService.resolveEliteDeath(fighterId, 5009)
	assertEq(#credited, 1, "tempo no raio credita")
	assertEq(credited[1], 972, "972 creditado")
	assertEq(#kills, 1, "onKill disparado")
	EnemyService.despawnAll()
end)

-- ══ Testes: item 10 — objetivo Fluxo e unlock do Pulso ──────────────────────
test("objetivo: cadeia sequencial — elite só é oferecido após a caça", function()
	fakeNow = 40000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(980)
	QuestService.registerPlayer(980, fakeNow)
	-- Objetivo 1 ainda oferecido: fala com o NPC → aceita a caça.
	assertTrue(QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow), "aceita a caça")
	-- Com a caça ativa, o elite NÃO é oferecido.
	local ok, reason = QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 1)
	assertFalse(ok, "elite bloqueado enquanto a caça está ativa")
	assertEq(reason, "already_active", "motivo")
	-- Completa a caça (3 shards) e o elite é oferecido.
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 3)
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 4)
	assertTrue(
		QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 5),
		"elite oferecido após a caça"
	)
	assertEq(QuestService.getProgress(980, "quest_elite").state, "active", "elite ativo")
	-- Fluxo ainda bloqueado (elite ativo).
	local flowOk, flowReason = QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 6)
	assertFalse(flowOk, "fluxo bloqueado enquanto o elite está ativo")
	assertEq(flowReason, "already_active", "motivo")
	ProgressionService.unregisterPlayer(980)
end)

test("objetivo: kill do elite completa, dá +60 XP e destrava a Cadência", function()
	fakeNow = 41000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(981)
	QuestService.registerPlayer(981, fakeNow)
	QuestService.tryAcceptFromNpc(981, "npc_threshold_instructor", fakeNow) -- caça
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 1)
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 3)
	QuestService.tryAcceptFromNpc(981, "npc_threshold_instructor", fakeNow + 4) -- elite
	local events = QuestService.creditKill(981, "enemy_anchored_shard", fakeNow + 5)
	assertEq(#events, 1, "evento de conclusão")
	assertEq(events[1].state, "completed", "completo")
	assertEq(events[1].xpGranted, 60, "+60 XP do objetivo")
	assertEq(events[1].unlockFlag, "unlock_broken_cadence", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(981, "unlock_broken_cadence"), "Cadência destravada")
	assertEq(QuestService.getTracker(981), nil, "tracker some")
	ProgressionService.unregisterPlayer(981)
end)

test("objetivo: eco da Cadência completa o objetivo Fluxo e destrava o Pulso", function()
	fakeNow = 42000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(982)
	QuestService.registerPlayer(982, fakeNow)
	-- Pula a caça e o elite via aceite forçado por tempo.
	QuestService.tick(982, fakeNow + 90) -- caça (90 s)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 91)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 92)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 93)
	QuestService.tryAcceptFromNpc(982, "npc_threshold_instructor", fakeNow + 94) -- elite
	QuestService.creditKill(982, "enemy_anchored_shard", fakeNow + 95)
	QuestService.tryAcceptFromNpc(982, "npc_threshold_instructor", fakeNow + 96) -- fluxo
	-- Eco da Cadência: kind flow_echo, alvo broken_cadence.
	local events = QuestService.creditFlowEcho(982, "broken_cadence", fakeNow + 97)
	assertEq(#events, 1, "evento de conclusão")
	assertEq(events[1].state, "completed", "completo")
	assertEq(events[1].xpGranted, 40, "+40 XP do objetivo")
	assertEq(events[1].unlockFlag, "unlock_pulse_return", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(982, "unlock_pulse_return"), "Pulso destravado")
	-- Eco de outra habilidade não conta.
	assertEq(#QuestService.creditFlowEcho(982, "comet_shoulder", fakeNow + 98), 0, "habilidade errada ignora")
	ProgressionService.unregisterPlayer(982)
end)

test("fatia: roteiro 0–60 min — caça, elite, eco e as 3 técnicas liberadas", function()
	fakeNow = 50000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	QuestService.init(makeQuestDeps())
	ResourceService.init(makeResourceDeps())
	CombatService.clear()
	CooldownService.clear(990)
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	deps.getFighterById = CombatService.getFighter
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	ProgressionService.registerPlayer(990)
	QuestService.registerPlayer(990, fakeNow)
	CombatService.createFighter("player:990", "player", 100, 100)

	-- 0–5 min: caça (aceite no NPC, 3 shards).
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 1)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 3)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_comet_shoulder"), "Cometa destravado")
	-- 15–20 min: elite → Cadência.
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow + 4)
	QuestService.creditKill(990, "enemy_anchored_shard", fakeNow + 5)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_broken_cadence"), "Cadência destravada")
	-- 45–60 min: eco → Pulso.
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow + 6)
	QuestService.creditFlowEcho(990, "broken_cadence", fakeNow + 7)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_pulse_return"), "Pulso destravado")

	-- As 3 técnicas agora ativam contra o dummy (cadência com eco agendado).
	local attacker = ResourceService.createState(990, "umbral_aether")
	assertTrue(attacker ~= nil, "estado de recurso")
	if attacker then
		attacker.resource = 100
		local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence")
		assertTrue(ok, "cadência ativa: " .. tostring(reason))
		AbilityService.tick(fakeNow + 8)
	end
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(990)
end)

-- ══ Testes: item 11 — consolidação, morte e ProfileStore ───────────────────
local SaveService = require("../src/server/Services/SaveService")

-- Mock do adaptador ProfileStore: DataStore em memória com session lock.
local function makeMockStore()
	local stored = {} -- key → dados persistidos
	local locked = {} -- key → true (lock ativo)
	local saves = 0
	-- store declarado antes: a closure do startSession referencia a variável
	-- (quirk do Lune/MLua com closure auto-referente).
	local store: any = nil
	store = {
		stored = stored,
		saves = function()
			return saves
		end,
		startSession = function(profileKey: string): any?
			if locked[profileKey] then
				return nil -- lock de outro servidor (§11.2 item 4)
			end
			locked[profileKey] = true
			-- handle declarado antes para o closure do Save enxergar a tabela
			-- (quirk do Lune/MLua com closure auto-referente).
			local handle: any = nil
			handle = {
				Save = function()
					stored[profileKey] = table.clone(handle.Data)
					saves += 1
				end,
				EndSession = function()
					locked[profileKey] = nil
				end,
			}
			-- ProfileStore hard-copia: jogador novo recebe nil (o SaveService
			-- aplica o template); jogador existente recebe o save.
			handle.Data = if stored[profileKey] then table.clone(stored[profileKey]) else nil
			store.lastHandle = handle
			return handle
		end,
	}
	return store
end

local function makeSaveDeps(store: any): any
	return {
		store = store,
		getSessionId = function()
			return "job-test-1"
		end,
		now = clockNow,
		getSnapshot = function(userId: number)
			return ProgressionService.snapshotForSave(userId)
		end,
		applySnapshot = function(userId: number, snapshot: any)
			ProgressionService.restoreFromSave(userId, snapshot)
		end,
		autosaveBaseSeconds = 60,
	}
end

test("consolidação: move todo não consolidado e emite recibo idempotente", function()
	fakeNow = 60000
	ProgressionService.init()
	ProgressionService.registerPlayer(1000)
	ProgressionService.awardXp(1000, 130)
	assertEq(ProgressionService.getUnconsolidatedXp(1000), 130, "não consolidado antes")
	assertEq(ProgressionService.getLedger(1000).consolidated, 0, "consolidado antes")
	local receipt = ProgressionService.consolidate(1000, fakeNow)
	assertTrue(receipt ~= nil, "recibo emitido")
	if receipt then
		assertEq(receipt.consolidated, 130, "moveu 130")
		assertEq(receipt.operationId, "cons_1000_60000", "operationId determinístico")
	end
	assertEq(ProgressionService.getUnconsolidatedXp(1000), 0, "zerou o não consolidado")
	assertEq(ProgressionService.getLedger(1000).consolidated, 130, "consolidado 130")
	assertEq(ProgressionService.getLedger(1000).lastConsolidationAt, 60000, "timestamp")
	-- Consolidar de novo com saldo zero: recibo sem movimento.
	local empty = ProgressionService.consolidate(1000, fakeNow + 1)
	if empty then
		assertEq(empty.consolidated, 0, "nada a consolidar")
	end
	assertEq(ProgressionService.getLedger(1000).consolidated, 130, "não duplica")
	ProgressionService.unregisterPlayer(1000)
end)

test("morte: segura/treino não perde; livre PvE 10% e PvP 15% com cap 200", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1001)
	ProgressionService.awardXp(1001, 500)
	local safe = ProgressionService.applyDeathPenalty(1001, "safe", false)
	assertEq(safe.lost, 0, "segura não perde")
	assertEq(safe.reason, "safe_zone", "motivo")
	local transition = ProgressionService.applyDeathPenalty(1001, "transition", true)
	assertEq(transition.lost, 0, "transição não perde")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 500, "saldo intacto")
	local pve = ProgressionService.applyDeathPenalty(1001, "free", false)
	assertEq(pve.lost, 50, "10% de 500 = 50")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 450, "perdeu 50")
	local pvp = ProgressionService.applyDeathPenalty(1001, "free", true)
	assertEq(pvp.lost, 67, "15% de 450 = 67 (floor)")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 383, "perdeu 67")
	assertEq(ProgressionService.getLedger(1001).consolidated, 0, "consolidado nunca é perdido")
	ProgressionService.unregisterPlayer(1001)
end)

test("morte: cap de 200 aplica em saldo grande", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1002)
	-- Saldo alto (acima do teto de emissão da sessão, via restore simulado).
	ProgressionService.restoreFromSave(1002, {
		consolidatedXp = 0,
		unconsolidatedXp = 3000,
		lastConsolidationAt = 0,
		tutorialFlags = {},
		unlockedAbilities = {},
	})
	local pvp = ProgressionService.applyDeathPenalty(1002, "free", true)
	assertEq(pvp.lost, 200, "cap 200 (15% de 3000 = 450)")
	assertEq(pvp.capped, true, "cap sinalizado")
	assertEq(ProgressionService.getUnconsolidatedXp(1002), 2800, "3000 - 200")
	-- PvE também respeita o cap.
	local pve = ProgressionService.applyDeathPenalty(1002, "free", false)
	assertEq(pve.lost, 200, "cap 200 no PvE (10% de 2800 = 280)")
	assertEq(ProgressionService.getUnconsolidatedXp(1002), 2600, "2800 - 200")
	-- Jogador desconhecido não quebra.
	local ghost = ProgressionService.applyDeathPenalty(999, "free", true)
	assertEq(ghost.lost, 0, "desconhecido 0")
	ProgressionService.unregisterPlayer(1002)
end)

test("save: leave persiste flags e XP (item 1 da §11.2)", function()
	fakeNow = 61000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1010)
	local profile = SaveService.loadProfile(1010)
	assertTrue(profile ~= nil, "perfil aberto")
	-- Joga: ganha XP, desbloqueia, suja o perfil.
	ProgressionService.awardXp(1010, 90)
	ProgressionService.grantUnlock(1010, "unlock_comet_shoulder")
	SaveService.markDirty(1010)
	SaveService.releaseProfile(1010) -- leave: salva se sujo e libera o lock
	assertFalse(SaveService.hasOpenProfile(1010), "lock liberado")
	assertTrue(store.stored["player:1010"] ~= nil, "save escrito")
	-- Rejoin (novo servidor): o save restaura flags e XP.
	ProgressionService.unregisterPlayer(1010)
	ProgressionService.registerPlayer(1010)
	local restored = SaveService.loadProfile(1010)
	assertTrue(restored ~= nil, "reabre")
	assertEq(ProgressionService.getUnconsolidatedXp(1010), 90, "XP restaurado")
	assertTrue(ProgressionService.hasUnlock(1010, "unlock_comet_shoulder"), "flag restaurada")
	SaveService.releaseProfile(1010)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1010)
end)

test("save: crash no autosave não duplica unlock (item 2 da §11.2)", function()
	fakeNow = 62000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1011)
	SaveService.loadProfile(1011)
	ProgressionService.grantUnlock(1011, "unlock_broken_cadence")
	SaveService.markDirty(1011)
	SaveService.saveProfile(1011) -- autosave 1
	SaveService.saveProfile(1011) -- sem dirty: não reescreve
	assertEq(store.saves(), 1, "um save para um dirty")
	assertEq(#ProgressionService.listUnlocks(1011), 1, "uma flag na sessão")
	-- Restaura do save: flag não duplica (grantUnlock idempotente).
	local saved = store.stored["player:1011"]
	assertEq(#saved.progression.tutorialFlags, 1, "uma flag persistida")
	-- Reaplica o snapshot salvo (como um crash que religa e reconstrói a
	-- sessão a partir do último save): a flag continua única.
	SaveService.releaseProfile(1011)
	ProgressionService.unregisterPlayer(1011)
	ProgressionService.registerPlayer(1011)
	SaveService.loadProfile(1011)
	assertEq(#ProgressionService.listUnlocks(1011), 1, "sem duplicar no rejoin")
	SaveService.releaseProfile(1011)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1011)
end)

test("save: rejoin no mesmo servidor devolve a sessão aberta (item 3)", function()
	fakeNow = 63000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1012)
	local first = SaveService.loadProfile(1012)
	ProgressionService.awardXp(1012, 25)
	SaveService.markDirty(1012)
	local second = SaveService.loadProfile(1012)
	assertTrue(second ~= nil, "rejoin abre")
	assertTrue(first == second, "mesma sessão (mesma tabela)")
	assertEq(ProgressionService.getUnconsolidatedXp(1012), 25, "estado da sessão mantido")
	SaveService.releaseProfile(1012)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1012)
end)

test("save: segundo servidor recusa sessão concorrente (item 4)", function()
	fakeNow = 64000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1013)
	-- Servidor A abre o lock.
	local serverA = SaveService.loadProfile(1013)
	assertTrue(serverA ~= nil, "servidor A abriu")
	-- Servidor B (mesmo store) não consegue: startSession devolve nil.
	SaveService.init(makeSaveDeps(store))
	ProgressionService.unregisterPlayer(1013)
	ProgressionService.registerPlayer(1013)
	local serverB = SaveService.loadProfile(1013)
	assertTrue(serverB == nil, "servidor B recusado (lock)")
	assertFalse(SaveService.hasOpenProfile(1013), "sem sessão aberta")
	-- Servidor A sai (EndSession) → o lock libera → B consegue abrir.
	store.lastHandle.EndSession()
	local reopened = SaveService.loadProfile(1013)
	assertTrue(reopened ~= nil, "após o A liberar, B abre")
	SaveService.releaseProfile(1013)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1013)
end)

test("save: falha injetada no load não entra com default por cima (item 5)", function()
	fakeNow = 65000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1014)
	SaveService.loadProfile(1014)
	ProgressionService.awardXp(1014, 50)
	SaveService.markDirty(1014)
	SaveService.releaseProfile(1014) -- save existe: 50 XP não consolidado
	assertTrue(store.stored["player:1014"] ~= nil, "save existente")
	-- Próximo load falha (startSession devolve nil por erro de rede simulado).
	local failing = {
		stored = store.stored,
		startSession = function()
			return nil
		end,
	}
	SaveService.init({
		store = failing,
		getSessionId = function()
			return "job-fail"
		end,
		now = clockNow,
	})
	ProgressionService.unregisterPlayer(1014)
	ProgressionService.registerPlayer(1014)
	local profile = SaveService.loadProfile(1014)
	assertTrue(profile == nil, "load falho → nil")
	assertFalse(SaveService.hasOpenProfile(1014), "sem sessão")
	assertTrue(store.stored["player:1014"] ~= nil, "save NÃO foi sobrescrito por default")
	-- O save original continua intacto (50 XP).
	assertEq(store.stored["player:1014"].progression.unconsolidatedXp, 50, "save intacto")
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1014)
end)

test("save: anel de recentOperations limita a 32 recibos", function()
	fakeNow = 66000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1015)
	local profile = SaveService.loadProfile(1015)
	assertTrue(profile ~= nil, "perfil")
	for i = 1, 40 do
		SaveService.appendOperation(1015, { operationId = ("op_%d"):format(i), kind = "test", at = fakeNow + i })
	end
	assertEq(#profile.recentOperations, 32, "anel limitado a 32")
	assertEq(profile.recentOperations[1].operationId, "op_9", "mais antigo descartado")
	assertEq(profile.recentOperations[32].operationId, "op_40", "mais recente presente")
	SaveService.releaseProfile(1015)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1015)
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

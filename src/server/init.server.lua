--!strict
-- Bootstrap do servidor — F0
-- Valida catálogo → init RemoteGateway → init ZoneService/ResourceService →
-- conecta intenções de habilidade/combate → ciclo join/leave.
-- Ordem importa (grafo acíclico); falha de catálogo derruba o boot.
--
-- F0 usa injeção de dependências: o bootstrap monta o grafo e cada service
-- recebe as dependências no init() (docs/04 §2.3 — testabilidade).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityService = require(script.Parent.Services.AbilityService)
local CatalogService = require(script.Parent.Services.CatalogService)
local CooldownService = require(script.Parent.Services.CooldownService)
local CombatService = require(script.Parent.Services.CombatService)
local PlayerSessionService = require(script.Parent.Services.PlayerSessionService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local QuestService = require(script.Parent.Services.QuestService)
local RemoteGateway = require(script.Parent.Services.RemoteGateway)
local ResourceService = require(script.Parent.Services.ResourceService)
local SaveService = require(script.Parent.Services.SaveService)
local ZoneService = require(script.Parent.Services.ZoneService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Abilities = require(ReplicatedStorage.Shared.Data.Abilities)
local Characters = require(ReplicatedStorage.Shared.Data.Characters)
local EnergyFamilies = require(ReplicatedStorage.Shared.Data.EnergyFamilies)
local Locale = require(ReplicatedStorage.Shared.Data.Locale)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Zones = require(ReplicatedStorage.Shared.Data.Zones)

-- 1. Catálogo — validação em fail-fast
CatalogService.init({
	Abilities = Abilities,
	Characters = Characters,
	EnergyFamilies = EnergyFamilies,
	Npcs = Npcs,
	Zones = Zones,
	Quests = Quests,
	Locale = Locale,
})
print("[Bootstrap] catálogo validado")

ProgressionService.init()

-- 2. Persistência (stub seguro até ProfileStore entrar no build)
SaveService.init()

-- 3. Gateway de rede — cria remotes registrados ANTES de qualquer fireClient
RemoteGateway.init()
print("[Bootstrap] RemoteGateway iniciado")

-- 4. Zonas/fronteira — regras PvP e eventos de travessia
ZoneService.init({
	getZone = CatalogService.getZone,
	getAnchor = CatalogService.getAnchor,
	now = os.clock,
	onZoneEvent = function(userId: number, event: { any })
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.ZoneEvent, event)
	end,
})
print("[Bootstrap] ZoneService iniciado")

-- 4.1. Objetivos — cadeia dirigida por dados; tracker vai no StateDelta
QuestService.init({
	getQuest = CatalogService.getQuest,
	chain = CatalogService.questChain,
	awardXp = ProgressionService.awardXp,
	grantUnlock = ProgressionService.grantUnlock,
	now = os.clock,
	onQuestEvent = function(userId: number, event: any)
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
			objective = event,
			unlocks = ProgressionService.listUnlocks(userId),
			unconsolidatedXp = ProgressionService.getUnconsolidatedXp(userId),
		})
	end,
})
print("[Bootstrap] QuestService iniciado")

-- 5. Recurso — inicia regen loop com broadcast real via gateway
ResourceService.init({
	getFamily = CatalogService.getFamily,
	taskImpl = task,
	onResourceChanged = function(playerUserId: number, current: number, max: number, depleted: boolean)
		local player = game.Players:GetPlayerByUserId(playerUserId)
		if not player then
			return
		end
		local resourceState = ResourceService.getState(playerUserId)
		RemoteGateway.fireClient(player, Remotes.Names.ResourceChanged, {
			familyId = if resourceState then resourceState.familyId else "umbral_aether",
			current = current,
			max = max,
			depleted = depleted,
		})
	end,
})

-- 6. Combate/Cooldown/Ability — grafo de dependências
CombatService.clear()
local dummyDef = CatalogService.getNpc("npc_training_dummy")
if dummyDef then
	CombatService.createFighter(dummyDef.id, "npc", dummyDef.maxHealth, dummyDef.maxGuard)
end

AbilityService.init({
	getAbility = CatalogService.getAbility,
	getCooldownRemaining = CooldownService.getRemaining,
	startCooldown = CooldownService.start,
	trySpendResource = function(userId: number, amount: number)
		local state = ResourceService.getState(userId)
		if not state then
			return false
		end
		return ResourceService.trySpend(userId, amount)
	end,
	grantFlowGain = ResourceService.grantFlowGain,
	tryGrantFlow = ResourceService.tryGrantFlow,
	isAlive = function(state: any)
		return CombatService.isAlive(state)
	end,
	applyDamage = CombatService.applyDamage,
	getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end,
	getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end,
	tryCometShoulder = CombatService.tryCometShoulder,
	onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string)
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatHit, {
			targetId = targetId,
			damage = damage,
			abilityId = abilityId,
		})
	end,
	isAbilityUnlocked = ProgressionService.isAbilityUnlocked,
})

-- 7. Ciclo de sessão — injeta o grafo
PlayerSessionService.init({
	getCharacter = CatalogService.getCharacter,
	getFamily = CatalogService.getFamily,
	createResourceState = function(userId: number, familyId: string)
		return ResourceService.createState(userId, familyId)
	end,
	removeResourceState = ResourceService.removeState,
	getResourceState = ResourceService.getState,
	clearCooldowns = CooldownService.clear,
	releaseProfile = SaveService.releaseProfile,
	createFighter = CombatService.createFighter,
	removeFighter = CombatService.removeFighter,
	getFighter = CombatService.getFighter,
	playerFighterId = CombatService.playerFighterId,
	onSnapshot = function(player: Player, snapshot: { any })
		RemoteGateway.fireClient(player, Remotes.Names.SessionSnapshot, snapshot)
	end,
	getPlayerZone = ZoneService.getPlayerZone,
	getUnlocks = ProgressionService.listUnlocks,
	getObjective = QuestService.getTracker,
	getUnconsolidatedXp = ProgressionService.getUnconsolidatedXp,
})

local function requireReady(player: Player): boolean
	return PlayerSessionService.isReady(player.UserId)
end

-- Convenção de id do fighter de inimigo: "<npcId>@<anchorId>#<n>".
-- A âncora vem no id porque o retorno decrescente de XP é por ponto de spawn
-- (docs/13 §9.2). A camada de spawn/AI no Studio cria os fighters com este
-- formato e chama `creditKill` no mesmo ponto que o combate headless.
local function parseEnemyFighterId(fighterId: string): (string?, string?)
	return string.match(fighterId, "^([^@#]+)@([^@#]+)#%d+$")
end

-- Crédito de um kill: XP da âncora + progresso do objetivo. Idempotente por
-- construção — só é chamado na transição vivo → morto (`result.killed`).
local function creditKill(player: Player, fighterId: string, now: number): ()
	local npcId, anchorId = parseEnemyFighterId(fighterId)
	if not npcId or not anchorId then
		return
	end
	local npcDef = CatalogService.getNpc(npcId)
	if not npcDef then
		return
	end
	local award = ProgressionService.creditNpcKill(player.UserId, npcDef, anchorId)
	local events = QuestService.creditKill(player.UserId, npcId, now)
	-- QuestService já emitiu StateDelta com o XP atualizado; sem evento de
	-- objetivo, o XP do kill ainda precisa chegar ao HUD.
	if #events == 0 and award.granted > 0 then
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
			unconsolidatedXp = ProgressionService.getUnconsolidatedXp(player.UserId),
		})
	end
end

-- 7. Intenção de habilidade (cliente → servidor)
RemoteGateway.onClientIntent(Remotes.Names.AbilityActivate, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local abilityId = payload.abilityId
	if type(abilityId) ~= "string" then
		return
	end

	local attacker = ResourceService.getState(player.UserId)
	if not attacker then
		return
	end

	local ok, reason = AbilityService.tryActivate(attacker, abilityId, nil, payload)
	if not ok then
		RemoteGateway.fireClient(player, Remotes.Names.AbilityRejected, {
			abilityId = abilityId,
			reason = reason or "unknown",
		})
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.BasicAttackIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local attacker = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	local dummy = CombatService.getFighter("npc_training_dummy")
	if not attacker or not dummy then
		return
	end
	local kind = payload.kind
	local now = os.clock()
	local result = if kind == "heavy"
		then CombatService.tryHeavy(attacker, dummy, now, "front")
		else CombatService.tryLight(attacker, dummy, now, "front")
	if result.ok then
		RemoteGateway.fireClient(player, Remotes.Names.CombatHit, {
			targetId = dummy.id,
			damage = result.damage,
			abilityId = if kind == "heavy" then "heavy" else "light",
		})
		if result.killed then
			creditKill(player, dummy.id, now)
		end
	end
end)

-- Aceite do objetivo no Instrutor do Limiar (docs/13 §10, §13).
RemoteGateway.onClientIntent(Remotes.Names.InteractionIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local npcId = payload.npcId
	if type(npcId) ~= "string" then
		return
	end
	QuestService.tryAcceptFromNpc(player.UserId, npcId, os.clock())
end)

RemoteGateway.onClientIntent(Remotes.Names.GuardIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	if not fighter then
		return
	end
	CombatService.setGuard(fighter, payload.down == true, os.clock())
end)

RemoteGateway.onClientIntent(Remotes.Names.DashIntent, function(player: Player, _payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	if not fighter then
		return
	end
	CombatService.tryDash(fighter, os.clock())
end)

RemoteGateway.onClientIntent(Remotes.Names.ZoneCrossingIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local toZoneId = payload.toZoneId
	if type(toZoneId) ~= "string" then
		return
	end
	ZoneService.tryEnterZone(player.UserId, toZoneId, os.clock(), {
		holdConfirmed = payload.holdConfirmed == true,
	})
end)

-- 8. Ciclo de sessão
game.Players.PlayerAdded:Connect(function(player: Player)
	ProgressionService.registerPlayer(player.UserId)
	ZoneService.registerPlayer(player.UserId)
	QuestService.registerPlayer(player.UserId, os.clock())
	ProgressionService.grantUnlock(player.UserId, "ftue_spawned")
	PlayerSessionService.onPlayerJoined(player)
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
	PlayerSessionService.onPlayerLeft(player)
	QuestService.unregisterPlayer(player.UserId)
	ZoneService.unregisterPlayer(player.UserId)
	ProgressionService.unregisterPlayer(player.UserId)
end)

-- Aceite forçado do objetivo após 90 s (docs/13 §10). Heartbeat barato: o
-- QuestService é idempotente e só age em objetivo ainda "offered".
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for _, player in game.Players:GetPlayers() do
			if PlayerSessionService.isReady(player.UserId) then
				QuestService.tick(player.UserId, now)
			end
		end
	end
end)

print("[Bootstrap] servidor pronto (F0)")

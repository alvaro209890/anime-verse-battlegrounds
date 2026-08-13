--!strict
-- Bootstrap do servidor — F0
-- Valida catálogo → init RemoteGateway → init ZoneService/ResourceService →
-- conecta intenções de habilidade/combate → ciclo join/leave.
-- Ordem importa (grafo acíclico); falha de catálogo derruba o boot.
--
-- F0 usa injeção de dependências: o bootstrap monta o grafo e cada service
-- recebe as dependências no init() (docs/04 §2.3 — testabilidade).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- `src/server` vira um Script chamado `Server` no Rojo; a pasta Services fica
-- como filha desse Script (ver default.project.json/sourcemap), não como irmã
-- dentro de ServerScriptService.
local Services = script:WaitForChild("Services")
local AbilityService = require(Services.AbilityService)
local CatalogService = require(Services.CatalogService)
local CooldownService = require(Services.CooldownService)
local CombatService = require(Services.CombatService)
local EnemyService = require(Services.EnemyService)
local InteractionService = require(Services.InteractionService)
local PlayerMotionGuard = require(Services.PlayerMotionGuard)
local PlayerSessionService = require(Services.PlayerSessionService)
local SpatialService = require(Services.SpatialService)
local StudioDebug = require(Services.StudioDebug)
local WorldService = require(Services.WorldService)
local ProgressionService = require(Services.ProgressionService)
local QuestService = require(Services.QuestService)
local RemoteGateway = require(Services.RemoteGateway)
local ResourceService = require(Services.ResourceService)
local SaveService = require(Services.SaveService)
local SecurityService = require(Services.SecurityService)
local TelemetryService = require(Services.TelemetryService)
local ZoneService = require(Services.ZoneService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Abilities = require(ReplicatedStorage.Shared.Data.Abilities)
local Characters = require(ReplicatedStorage.Shared.Data.Characters)
local EnergyFamilies = require(ReplicatedStorage.Shared.Data.EnergyFamilies)
local Geometry = require(ReplicatedStorage.Shared.Geometry)
local Interactions = require(ReplicatedStorage.Shared.Data.Interactions)
local Locale = require(ReplicatedStorage.Shared.Data.Locale)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local RemoteEnvelope = require(ReplicatedStorage.Shared.RemoteEnvelope)
local WorldPresentation = require(ReplicatedStorage.Shared.Data.WorldPresentation)
local SpawnDecorations = require(ReplicatedStorage.Shared.Data.SpawnDecorations)
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

local presentationOk, presentationReason = WorldPresentation.validate()
if not presentationOk then
	error("catálogo de apresentação inválido: " .. (presentationReason or "unknown"))
end
local interactionsOk, interactionsReason = Interactions.validate()
if not interactionsOk then
	error("catálogo de interações inválido: " .. (interactionsReason or "unknown"))
end

ProgressionService.init()

-- 1.1. Mundo — greybox, collision groups e marcadores de âncora (§8).
-- Constrói a partir dos mesmos números que `zoneAtPosition` usa.
WorldService.init({
	zones = Zones,
	greybox = Zones.greybox,
	presentation = WorldPresentation,
	spawnDecorations = SpawnDecorations,
})
print("[Bootstrap] greybox construído")

-- 1.2. Espaço — produz distância, costas e hitbox para o combate.
SpatialService.init({ geometry = Geometry })
PlayerMotionGuard.init()

-- 1.3. Observabilidade/segurança — somente campos allowlisted chegam ao log.
-- O sink F0 é o log estruturado do servidor; backend/dashboards entram após
-- o place privado existir. O buffer interno mantém os últimos 200 eventos.
local sessionStartedAt: { [number]: number } = {}
TelemetryService.init({
	sessionId = if game.JobId ~= "" then game.JobId else "studio",
	releaseId = ("place-%d"):format(game.PlaceVersion),
	now = os.time,
	emit = function(event: any)
		print("[Telemetry] " .. HttpService:JSONEncode(event))
	end,
})
SecurityService.init({
	decode = RemoteEnvelope.decode,
	now = os.clock,
	onRejected = function(userId: number, contract: string, reason: string, weight: number)
		TelemetryService.record("RemoteRejected", userId, {
			contract = contract,
			reason = reason,
			weight = weight,
		})
	end,
})

-- 2. Persistência — ProfileRoot v1 com ProfileStore (docs/13 §11)
-- lib/ProfileStore.luau entra no build via ReplicatedStorage.Shared.vendor
-- (default.project.json); o adaptador injetado mantém o serviço testável.
local ProfileStore = require(ReplicatedStorage.Shared.vendor.ProfileStore)
local profileStoreInstance = ProfileStore.New("avb_f0_v1_profiles", nil)
SaveService.init({
	store = {
		startSession = function(profileKey: string)
			local profile = profileStoreInstance:StartSessionAsync(profileKey)
			return if profile
				then {
					Data = profile.Data,
					Save = function()
						profile:Save()
					end,
					EndSession = function()
						profile:EndSession()
					end,
				}
				else nil
		end,
	},
	getSessionId = function()
		return game.JobId
	end,
	getSnapshot = function(userId: number)
		return ProgressionService.snapshotForSave(userId)
	end,
	applySnapshot = function(userId: number, snapshot: any)
		ProgressionService.restoreFromSave(userId, snapshot)
	end,
	onSaved = function(userId: number, result: { any })
		TelemetryService.record("SaveAttempt", userId, {
			dirty = result.dirty == true,
			bytes = result.bytes or 0,
			result = "success",
		})
		local player = game.Players:GetPlayerByUserId(userId)
		if player then
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				unconsolidatedXp = ProgressionService.getUnconsolidatedXp(userId),
				consolidatedXp = ProgressionService.getLedger(userId)
						and ProgressionService.getLedger(userId).consolidated
					or 0,
			})
		end
	end,
})
print("[Bootstrap] SaveService iniciado (ProfileStore)")

-- 3. Gateway de rede — cria remotes registrados ANTES de qualquer fireClient
RemoteGateway.init({
	authorize = SecurityService.inspect,
})
print("[Bootstrap] RemoteGateway iniciado")

-- 4. Zonas/fronteira — regras PvP e eventos de travessia
ZoneService.init({
	getZone = CatalogService.getZone,
	getAnchor = CatalogService.getAnchor,
	now = os.clock,
	onZoneEvent = function(userId: number, event: { any })
		if event.rejectedReason == nil then
			TelemetryService.record("ZoneTransition", userId, {
				from = event.from,
				to = event.to,
				holdConfirmed = event.holdConfirmed == true,
			})
		end
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
		if event.state == "completed" and type(event.unlockFlag) == "string" then
			TelemetryService.record("FtueBeat", userId, {
				flag = event.unlockFlag,
				elapsedMs = math.floor((os.clock() - (sessionStartedAt[userId] or os.clock())) * 1000),
			})
		end
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
			objective = event,
			unlocks = ProgressionService.listUnlocks(userId),
			unconsolidatedXp = ProgressionService.getUnconsolidatedXp(userId),
		})
		-- Item 11: recompensa/unlock de objetivo muda o perfil.
		if event.state == "completed" then
			SaveService.markDirty(userId)
		end
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
	local trainingAnchor = CatalogService.getAnchor("anchor_training")
	if trainingAnchor then
		SpatialService.setTransform(dummyDef.id, {
			x = trainingAnchor.position.x,
			y = trainingAnchor.position.y,
			z = trainingAnchor.position.z,
		}, { x = 0, y = 0, z = 1 })
	end
end

local function fireVitalsForFighter(fighterId: string, viewerUserId: number?): ()
	local fighter = CombatService.getFighter(fighterId)
	if not fighter then
		return
	end
	local userIdText = string.match(fighterId, "^player:(%d+)$")
	if userIdText then
		local player = game.Players:GetPlayerByUserId(tonumber(userIdText) :: number)
		if player then
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				health = fighter.health,
				maxHealth = fighter.maxHealth,
				guard = fighter.guard,
				maxGuard = fighter.maxGuard,
			})
		end
		return
	end
	-- NPC: o delta carrega fighterId e vai para quem causou/observou o dano.
	-- O cliente usa isso para desenhar a barra de vida do inimigo.
	if viewerUserId then
		local player = game.Players:GetPlayerByUserId(viewerUserId)
		if player then
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				fighterId = fighterId,
				health = fighter.health,
				maxHealth = fighter.maxHealth,
			})
		end
	end
end

-- O contra do Retorno de Pulso é o único desfecho em que quem apanha devolve
-- dano. Ele já era resolvido no servidor, mas não chegava ao cliente do
-- defensor: quem usou a técnica via só "levei um golpe" e nunca o resultado
-- dela. Este evento é o que liga o contra à apresentação (pose, som, câmera).
local function notifyPulseCounter(defenderFighterId: string, attackerFighterId: string, damage: number): ()
	local userIdText = string.match(defenderFighterId, "^player:(%d+)$")
	if not userIdText then
		return
	end
	local player = game.Players:GetPlayerByUserId(tonumber(userIdText) :: number)
	if not player then
		return
	end
	RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
		targetId = attackerFighterId,
		abilityId = "pulse_return",
		outcome = "counter",
		damage = damage,
	})
end

local PLAYER_TRAVEL_CLEARANCE = 0.25

local function playerRoot(userId: number): BasePart?
	local player = game.Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- O Blockcast usa somente o greybox colidível construído pelo servidor. Ele
-- limita o deslocamento antes da resolução pura; direção e distância final
-- nunca vêm do cliente.
local function clearWorldTravelFrom(
	origin: Vector3,
	castSize: Vector3,
	direction: { [string]: number },
	requested: number
): number
	local world = Workspace:FindFirstChild("GreyboxF0")
	if not world or requested <= 0 then
		return 0
	end
	local flat = Vector3.new(direction.x or 0, 0, direction.z or 0)
	if flat.Magnitude <= 1e-6 then
		return 0
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local acceptedCFrame = CFrame.lookAt(origin, origin + flat.Unit)
	local hit = Workspace:Blockcast(acceptedCFrame, castSize, flat.Unit * requested, params)
	if not hit then
		return requested
	end
	return math.max(0, math.min(requested, hit.Distance - PLAYER_TRAVEL_CLEARANCE))
end

local function clearWorldTravel(userId: number, direction: { [string]: number }, requested: number): number
	local root = playerRoot(userId)
	local accepted = SpatialService.getPosition(CombatService.playerFighterId(userId))
	local acceptedPhysical = PlayerMotionGuard.getAcceptedPosition(userId)
	if not root or not accepted or not acceptedPhysical then
		return 0
	end
	local castSize = Vector3.new(
		math.max(0.5, root.Size.X * 0.8),
		math.max(0.5, root.Size.Y * 0.8),
		math.max(0.5, root.Size.Z * 0.8)
	)
	return clearWorldTravelFrom(Vector3.new(accepted.x, acceptedPhysical.y, accepted.z), castSize, direction, requested)
end

local function clearNpcWorldTravel(fighterId: string, direction: { [string]: number }, requested: number): number
	local position = SpatialService.getPosition(fighterId)
	if not position then
		return 0
	end
	-- Os inimigos F0 são rigs greybox ancorados com base lógica em y=0.
	-- O volume cobre o corpo sem depender de Motor6D ou da pose do cliente.
	return clearWorldTravelFrom(
		Vector3.new(position.x, position.y + 3, position.z),
		Vector3.new(2, 4, 2),
		direction,
		requested
	)
end

-- Commita o resultado espacial no assembly real do jogador. Sem esta ponte o
-- Heartbeat seguinte releria a posição antiga do avatar e desfaria dash,
-- lunge ou empurrão apesar de o domínio ter aceitado a ação.
local function applyPlayerSpatialPosition(userId: number, position: { [string]: number }, now: number): boolean
	local root = playerRoot(userId)
	if not root then
		return false
	end
	local geometric = CatalogService.zoneAtPosition(position)
	if not geometric then
		return false
	end
	local currentZone = ZoneService.getPlayerZone(userId)
	if geometric ~= currentZone then
		local entered = ZoneService.tryEnterZone(userId, geometric, now, {})
		if not entered.ok then
			return false
		end
	end
	local acceptedPhysical = PlayerMotionGuard.getAcceptedPosition(userId)
	local targetY = if acceptedPhysical then acceptedPhysical.y else root.Position.Y
	local target = Vector3.new(position.x, targetY, position.z)
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude <= 1e-6 then
		flatLook = Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(target, target + flatLook.Unit)
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	SpatialService.setTransform(
		CombatService.playerFighterId(userId),
		{ x = target.X, y = 0, z = target.Z },
		{ x = flatLook.X, y = 0, z = flatLook.Z }
	)
	PlayerMotionGuard.commitServerMove(userId, { x = target.X, y = target.Y, z = target.Z }, now)
	return true
end

-- Declarada antes do grafo de habilidades porque o callback da Cadência a
-- captura; a implementação fica junto dos demais helpers de zona abaixo.
local zoneOfFighter: (string, number?) -> string

local function canPlayerDamageFighter(userId: number, fighterId: string): boolean
	local targetUserIdText = string.match(fighterId, "^player:(%d+)$")
	if targetUserIdText then
		return ZoneService.canPvpBetween(userId, tonumber(targetUserIdText) :: number)
	end
	return ZoneService.canDamageCrossBoundary(ZoneService.getPlayerZone(userId), zoneOfFighter(fighterId, userId))
end

local function cloneTransform(transform: any): any
	return {
		position = { x = transform.position.x, y = transform.position.y, z = transform.position.z },
		look = { x = transform.look.x, y = transform.look.y, z = transform.look.z },
	}
end

local function restoreTransform(fighterId: string, transform: any): ()
	SpatialService.setTransform(fighterId, transform.position, transform.look)
end

local resolveAbilityKill: ((number, string, string) -> ())? = nil
local resolvePlayerPvpDeath: ((number) -> ())? = nil
local promoteHostileTransition: ((number, number) -> ())? = nil

local function applyPulseCounterToPlayer(userId: number, defender: any, currentNow: number): boolean
	local attackerId = CombatService.playerFighterId(userId)
	local attacker = CombatService.getFighter(attackerId)
	if not attacker then
		return false
	end
	local counter = CombatService.tryPulseCounter(attacker, currentNow)
	if not counter.ok then
		return false
	end

	-- PvP: quem levou o contra é `userId`; quem apara é o dono da postura.
	if type(defender.id) == "string" then
		notifyPulseCounter(defender.id, attackerId, counter.damage)
	end

	local defenderPosition = if type(defender.id) == "string" then SpatialService.getPosition(defender.id) else nil
	local attackerTransform = SpatialService.getTransform(attackerId)
	local before = if attackerTransform then cloneTransform(attackerTransform) else nil
	local pushDistance = 0
	if defenderPosition and attackerTransform then
		local away = {
			x = attackerTransform.position.x - defenderPosition.x,
			y = 0,
			z = attackerTransform.position.z - defenderPosition.z,
		}
		pushDistance = clearWorldTravel(userId, away, 8)
	end
	if
		defenderPosition
		and pushDistance > 0
		and SpatialService.pushBack(attackerId, defenderPosition, pushDistance)
	then
		local pushedPosition = SpatialService.getPosition(attackerId)
		if pushedPosition and not applyPlayerSpatialPosition(userId, pushedPosition, currentNow) and before then
			restoreTransform(attackerId, before)
		end
	end

	fireVitalsForFighter(attackerId)
	if counter.killed and resolvePlayerPvpDeath then
		resolvePlayerPvpDeath(userId)
	end
	return counter.killed == true
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
		local fighter = CombatService.getFighter(CombatService.playerFighterId(state.userId))
		return CombatService.isAlive(state) and fighter ~= nil and CombatService.isAlive(fighter)
	end,
	applyDamage = CombatService.applyDamage,
	tryCadenceHit = function(attacker: any, target: any, currentNow: number, damage: number, _facing: string)
		local facing = SpatialService.facingOf(target.id, attacker.id) or "front"
		return CombatService.tryCadenceHit(attacker, target, currentNow, damage, facing)
	end,
	onPulseCounter = applyPulseCounterToPlayer,
	getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end,
	getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end,
	tryCometShoulder = CombatService.tryCometShoulder,
	onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string, outcome: string?)
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		local hitAt = os.clock()
		if ZoneService.markHostileAction(userId, hitAt) and promoteHostileTransition then
			promoteHostileTransition(userId, hitAt)
		end
		local targetUserIdText = string.match(targetId, "^player:(%d+)$")
		if targetUserIdText then
			ZoneService.markPvpCombat(userId, hitAt)
			ZoneService.markPvpCombat(tonumber(targetUserIdText) :: number, hitAt)
		elseif damage > 0 and EnemyService.isElite(targetId) then
			EnemyService.registerEliteDamage(targetId, userId, damage)
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
			targetId = targetId,
			abilityId = abilityId,
			outcome = outcome or "hit",
			damage = damage,
		})
		fireVitalsForFighter(targetId, userId)
	end,
	onCombatKill = function(userId: number, targetId: string, abilityId: string)
		if resolveAbilityKill then
			resolveAbilityKill(userId, targetId, abilityId)
		end
	end,
	isAbilityUnlocked = ProgressionService.isAbilityUnlocked,
	getFighterById = CombatService.getFighter,
	-- Retorno de Pulso (item 10): abre a postura de 250 ms no FighterState.
	setPulseStance = CombatService.setPulseStance,
	-- Postura sem golpe → recovery 600 ms (erro do Pulso, §6.3).
	expirePulseStance = function(fighter: any, currentNow: number)
		CombatService.pulseTick(fighter, currentNow)
	end,
	-- Eco da Cadência acertou (item 10 — objetivo quest_flow). O QuestService
	-- já emite o StateDelta pelo onQuestEvent; aqui só credita o objetivo.
	onFlowEcho = function(userId: number, abilityId: string, flowGranted: number)
		QuestService.creditFlowEcho(userId, abilityId, os.clock())
		TelemetryService.record("AbilityResolved", userId, {
			abilityId = abilityId,
			result = "echo_hit",
			latencyMs = 0,
			flowGranted = flowGranted,
		})
	end,
	-- Ombro Cometa espacial (§6.1): 7 studs, cap 8, para em parede e em guarda
	-- inimiga, cápsula 4×4×8 no trajeto e no máximo 1 alvo.
	resolveCometShoulder = function(userId: number)
		local attackerId = CombatService.playerFighterId(userId)
		local transform = SpatialService.getTransform(attackerId)
		if not transform then
			return nil
		end
		local before = cloneTransform(transform)
		local distance = clearWorldTravel(userId, transform.look, 7)
		local resolution = SpatialService.resolveCometShoulder(attackerId, {
			distance = distance,
			hardCap = 8,
			capsuleRadius = 2,
			blockerRadius = 2,
			blocks = function(fighterId: string): boolean
				local fighter = CombatService.getFighter(fighterId)
				-- Guarda ativa para o avanço; corpo morto não bloqueia.
				return fighter ~= nil
					and fighter.health > 0
					and fighter.guarding == true
					and canPlayerDamageFighter(userId, fighterId)
			end,
			targets = function(fighterId: string): boolean
				local fighter = CombatService.getFighter(fighterId)
				return fighter ~= nil and fighter.health > 0 and canPlayerDamageFighter(userId, fighterId)
			end,
		})
		if not applyPlayerSpatialPosition(userId, resolution.position, os.clock()) then
			restoreTransform(attackerId, before)
			resolution.position = before.position
			resolution.traveled = 0
			resolution.blocked = true
			resolution.blockedBy = "zone_boundary"
			resolution.targetId = nil
		end
		return resolution
	end,
	-- Cadência resolve uma única vítima na esfera frontal e preserva essa
	-- referência para a reentrada/eco. O cliente não informa target nem hit.
	resolveCadenceTarget = function(userId: number)
		local attackerId = CombatService.playerFighterId(userId)
		local hits = SpatialService.overlapInFront(attackerId, 2, 4.5, function(fighterId: string): boolean
			local other = CombatService.getFighter(fighterId)
			if not other or other.health <= 0 then
				return false
			end
			return canPlayerDamageFighter(userId, fighterId)
		end, 1)
		local targetId = hits[1]
		return if targetId then CombatService.getFighter(targetId) else nil
	end,
	revalidateCadenceTarget = function(userId: number, target: any): boolean
		if type(target.id) ~= "string" or CombatService.getFighter(target.id) ~= target then
			return false
		end
		if not canPlayerDamageFighter(userId, target.id) then
			return false
		end
		local attackerId = CombatService.playerFighterId(userId)
		local matches = SpatialService.overlapInFront(attackerId, 2, 4.5, function(fighterId: string): boolean
			return fighterId == target.id
		end, 1)
		return matches[1] == target.id
	end,
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

-- Zona de um fighter qualquer. Jogador: ZoneService. Inimigo: a âncora onde
-- nasceu. Dummy e instrutor: a zona segura. Usado para a regra de dano que não
-- atravessa a fronteira (§8.2).
zoneOfFighter = function(fighterId: string, selfUserId: number?): string
	if selfUserId and fighterId == CombatService.playerFighterId(selfUserId) then
		return ZoneService.getPlayerZone(selfUserId)
	end
	local userIdText = string.match(fighterId, "^player:(%d+)$")
	if userIdText then
		return ZoneService.getPlayerZone(tonumber(userIdText) :: number)
	end
	local npcId, anchorId = string.match(fighterId, "^([^@#]+)@([^@#]+)#%d+$")
	if npcId and anchorId then
		local anchor = CatalogService.getAnchor(anchorId)
		if anchor then
			return anchor.zoneId
		end
	end
	local npcDef = CatalogService.getNpc(fighterId)
	if npcDef and npcDef.zoneId then
		return npcDef.zoneId
	end
	return "zone_bastion_safe"
end

-- Atacar durante a proteção encerra a faixa e leva o avatar para o primeiro
-- ponto livre do mesmo portão. Estado lógico/físico avançam juntos.
promoteHostileTransition = function(userId: number, currentNow: number): ()
	local fighterId = CombatService.playerFighterId(userId)
	local transform = SpatialService.getTransform(fighterId)
	if not transform then
		return
	end
	local position = cloneTransform(transform).position
	if CatalogService.zoneAtPosition(position) ~= "zone_threshold_transition" then
		return
	end
	if position.x <= -40 and position.x >= -48 then
		position.x = -49.5
	elseif position.z <= -32 and position.z >= -40 then
		position.z = -41.5
	end
	if applyPlayerSpatialPosition(userId, position, currentNow) then
		ZoneService.notifyHostileTransition(userId, currentNow)
	end
end

-- Jogadores elegíveis a aggro: prontos, vivos e com posição conhecida.
local function listAggroTargets(): { any }
	local out: { any } = {}
	for _, player in game.Players:GetPlayers() do
		local userId = player.UserId
		if PlayerSessionService.isReady(userId) then
			local fighterId = CombatService.playerFighterId(userId)
			local fighter = CombatService.getFighter(fighterId)
			if fighter and fighter.health > 0 and SpatialService.getPosition(fighterId) then
				table.insert(out, {
					fighterId = fighterId,
					userId = userId,
					zoneId = ZoneService.getPlayerZone(userId),
				})
			end
		end
	end
	return out
end

-- Convenção de id do fighter de inimigo: "<npcId>@<anchorId>#<n>".
-- A âncora vem no id porque o retorno decrescente de XP é por ponto de spawn
-- (docs/13 §9.2). A camada de spawn/AI no Studio cria os fighters com este
-- formato e chama `creditKill` no mesmo ponto que o combate headless.
local function parseEnemyFighterId(fighterId: string): (string?, string?)
	return string.match(fighterId, "^([^@#]+)@([^@#]+)#%d+$")
end

-- Crédito de um kill: XP da âncora + progresso do objetivo. Idempotente por
-- construção — só é chamado na transição vivo → morto (`result.killed`) ou
-- pelo leeching do elite (resolveEliteDeath). Não reporta o died (quem
-- chamou já emitiu o evento).
local function grantKillCredit(player: Player, fighterId: string, now: number): number
	local npcId, anchorId = parseEnemyFighterId(fighterId)
	if not npcId or not anchorId then
		return 0
	end
	local npcDef = CatalogService.getNpc(npcId)
	if not npcDef then
		return 0
	end
	local award = ProgressionService.creditNpcKill(player.UserId, npcDef, anchorId)
	local events = QuestService.creditKill(player.UserId, npcId, now)
	-- Item 11: XP/flags mudaram — o autosave precisa persistir.
	SaveService.markDirty(player.UserId)
	-- QuestService já emitiu StateDelta com o XP atualizado; sem evento de
	-- objetivo, o XP do kill ainda precisa chegar ao HUD.
	if #events == 0 and award.granted > 0 then
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
			unconsolidatedXp = ProgressionService.getUnconsolidatedXp(player.UserId),
		})
	end
	return award.granted
end

-- Kill direto (BasicAttackIntent): reporta o died e credita. O elite NÃO
-- passa por aqui — a morte dele resolve o leeching no tick.
local function creditKill(player: Player, fighterId: string, now: number): ()
	EnemyService.reportKill(player.UserId, fighterId)
	grantKillCredit(player, fighterId, now)
end

-- userId → diedAt já penalizado (evita aplicar a perda duas vezes na mesma
-- morte: PvP no BasicAttackIntent + PvE no Heartbeat).
local deathPenalized: { [number]: number } = {}
local deathPresented: { [number]: number } = {}

-- Item 11: perda de XP na morte (docs/13 §11.1, Q-018). Aplica a penalidade
-- da zona do morto; o XP perdido sai da economia (não vai ao agressor).
local function applyDeathPenalty(userId: number, pvp: boolean): ()
	local fighter = CombatService.getFighter(CombatService.playerFighterId(userId))
	if not fighter or fighter.health > 0 then
		return
	end
	if deathPenalized[userId] == fighter.diedAt then
		return
	end
	deathPenalized[userId] = fighter.diedAt
	local zoneId = ZoneService.getPlayerZone(userId)
	local zone = CatalogService.getZone(zoneId)
	local zoneKind = if zone then zone.kind else "safe"
	local penalty = ProgressionService.applyDeathPenalty(userId, zoneKind, pvp)
	TelemetryService.record("KillResolved", userId, {
		zoneId = zoneId,
		combatType = if pvp then "pvp" else "pve",
		xpLost = penalty.lost,
	})
	if penalty.lost > 0 then
		SaveService.markDirty(userId)
		local player = game.Players:GetPlayerByUserId(userId)
		if player then
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				unconsolidatedXp = ProgressionService.getUnconsolidatedXp(userId),
				consolidatedXp = ProgressionService.getLedger(userId).consolidated,
				deathPenalty = penalty.lost,
			})
		end
	end
end

resolvePlayerPvpDeath = function(userId: number): ()
	applyDeathPenalty(userId, true)
end

-- 6.1. Inimigos — spawn nas 6 âncoras, perseguição e respawn (§9.2).
resolveAbilityKill = function(userId: number, targetId: string, _abilityId: string): ()
	local player = game.Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local targetUserIdText = string.match(targetId, "^player:(%d+)$")
	if targetUserIdText then
		applyDeathPenalty(tonumber(targetUserIdText) :: number, true)
	elseif not EnemyService.isElite(targetId) then
		creditKill(player, targetId, os.clock())
	end
end

-- Um inimigo que acerta a postura do Retorno de Pulso recebe o mesmo contra
-- autoritativo (8 de dano + até 8 studs de empurrão) que um jogador agressor.
-- EnemyService apenas propaga o resultado do golpe; dano, parede, zona, morte
-- e crédito continuam resolvidos no servidor.
local function applyPulseCounterToNpc(defenderUserId: number, attackerId: string, currentNow: number): ()
	local attacker = CombatService.getFighter(attackerId)
	local defenderId = CombatService.playerFighterId(defenderUserId)
	local defenderPosition = SpatialService.getPosition(defenderId)
	local before = SpatialService.getTransform(attackerId)
	if not attacker then
		return
	end
	local counter = CombatService.tryPulseCounter(attacker, currentNow)
	if not counter.ok then
		return
	end

	-- PvE (caso comum da F0): o jogador aparou um Estilhaço. Este é o momento em
	-- que o Retorno de Pulso "acontece" para quem o usou.
	notifyPulseCounter(defenderId, attackerId, counter.damage)

	if before and defenderPosition then
		local snapshot = cloneTransform(before)
		local away = {
			x = before.position.x - defenderPosition.x,
			y = 0,
			z = before.position.z - defenderPosition.z,
		}
		local distance = clearNpcWorldTravel(attackerId, away, 8)
		if distance > 0 and SpatialService.pushBack(attackerId, defenderPosition, distance) then
			local pushed = SpatialService.getPosition(attackerId)
			local originZone = zoneOfFighter(attackerId, defenderUserId)
			local pushedZone = if pushed then CatalogService.zoneAtPosition(pushed) else nil
			if not pushed or not pushedZone or not ZoneService.canDamageCrossBoundary(originZone, pushedZone) then
				restoreTransform(attackerId, snapshot)
			else
				local pushedTransform = SpatialService.getTransform(attackerId)
				if pushedTransform then
					WorldService.syncActor(attackerId, pushedTransform)
				end
			end
		end
	end

	if EnemyService.isElite(attackerId) then
		EnemyService.registerEliteDamage(attackerId, defenderUserId, counter.damage)
	end
	if counter.killed and resolveAbilityKill then
		resolveAbilityKill(defenderUserId, attackerId, "pulse_return")
	end
end

EnemyService.init({
	getNpc = CatalogService.getNpc,
	getAnchor = CatalogService.getAnchor,
	shardAnchors = CatalogService.shardAnchors,
	spatial = SpatialService,
	combat = CombatService,
	geometry = Geometry,
	listTargets = listAggroTargets,
	-- Item 9: leeching do elite — cada jogador elegível recebe o crédito
	-- completo (XP + objetivo), sem último golpe (§9.3). O died já foi
	-- emitido pelo resolveEliteDeath; aqui só credita.
	onKill = function(userId: number, fighterId: string)
		local player = game.Players:GetPlayerByUserId(userId)
		if player then
			grantKillCredit(player, fighterId, os.clock())
		end
	end,
	onEnemyEvent = function(fighterId: string, event: { any })
		WorldService.presentEnemyEvent(fighterId, event)
		-- Telegraph precisa chegar ao cliente para o contorno branco (§17).
		for _, player in game.Players:GetPlayers() do
			if PlayerSessionService.isReady(player.UserId) then
				RemoteGateway.fireClient(player, Remotes.Names.EnemyEvent, {
					fighterId = fighterId,
					kind = event.kind,
					targetId = event.targetId,
					damage = event.damage,
					outcome = event.outcome,
					iframe = event.iframe,
					pulseCounter = event.pulseCounter,
					durationSeconds = event.durationSeconds,
					visualPattern = event.visualPattern,
				})
			end
		end
		if event.kind == "attack" and type(event.targetId) == "string" and event.iframe ~= true then
			fireVitalsForFighter(event.targetId)
			local targetUserId = string.match(event.targetId, "^player:(%d+)$")
			local targetPlayer = if targetUserId
				then game.Players:GetPlayerByUserId(tonumber(targetUserId) :: number)
				else nil
			local targetFighter = CombatService.getFighter(event.targetId)
			if targetUserId and event.pulseCounter == true then
				applyPulseCounterToNpc(tonumber(targetUserId) :: number, fighterId, os.clock())
			end
			if targetPlayer and targetFighter then
				local outcome = event.outcome
				if outcome == "hit" or outcome == "guard" then
					RemoteGateway.fireClient(targetPlayer, Remotes.Names.CombatEvent, {
						abilityId = "basic_enemy",
						outcome = outcome,
					})
				end
			end
		end
	end,
})
EnemyService.spawnInitial()
-- Item 9: o elite da cratera entra no mundo junto (docs/13 §9.3).
EnemyService.spawnElite()
print("[Bootstrap] Estilhaços no mundo")

-- 7. Intenção de habilidade (cliente → servidor)
RemoteGateway.onClientIntent(Remotes.Names.AbilityIntent, function(player: Player, payload: { any })
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

	local resolveStartedAt = os.clock()
	local ok, reason = AbilityService.tryActivate(attacker, abilityId, nil, payload)
	TelemetryService.record("AbilityResolved", player.UserId, {
		abilityId = abilityId,
		result = if ok then "success" else reason or "rejected",
		latencyMs = math.floor((os.clock() - resolveStartedAt) * 1000),
		flowGranted = 0,
	})
	if not ok then
		RemoteGateway.fireClient(player, Remotes.Names.AbilityRejected, {
			abilityId = abilityId,
			reason = reason or "unknown",
			executionId = payload.executionId,
			phase = payload.phase or "press",
		})
	else
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
			cooldowns = {
				[abilityId] = CooldownService.getRemaining(player.UserId, abilityId),
			},
		})
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.BasicAttackIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local attackerId = CombatService.playerFighterId(player.UserId)
	local attacker = CombatService.getFighter(attackerId)
	if not attacker then
		return
	end
	local kind = payload.kind
	local now = os.clock()

	-- Hitbox de verdade (§5.1/§5.2): esfera à frente para a cadeia leve,
	-- cápsula mais longa para o pesado. Máx. 1 alvo por golpe.
	local isHeavy = kind == "heavy"
	local step = math.clamp(attacker.lightStep + 1, 1, 4)
	local radius = if isHeavy then 2.5 else ({ 4, 4, 4.5, 5 })[step]
	local forward = if isHeavy then 3.5 else 2
	local hits = SpatialService.overlapInFront(attackerId, forward, radius, function(fighterId: string): boolean
		local other = CombatService.getFighter(fighterId)
		if not other or other.health <= 0 then
			return false
		end
		-- Dano não atravessa a fronteira (§8.2).
		return canPlayerDamageFighter(player.UserId, fighterId)
	end, 1)

	local targetId = hits[1]
	local target = if targetId then CombatService.getFighter(targetId) else nil
	local facing = if targetId then SpatialService.facingOf(targetId, attackerId) else "front"

	local result = if isHeavy
		then CombatService.tryHeavy(attacker, target, now, facing)
		else (if target then CombatService.tryLight(attacker, target, now, facing) else nil)

	if result and result.ok and target then
		if ZoneService.markHostileAction(player.UserId, now) and promoteHostileTransition then
			promoteHostileTransition(player.UserId, now)
		end
		local targetUserIdText = string.match(target.id, "^player:(%d+)$")
		if targetUserIdText then
			local targetUserId = tonumber(targetUserIdText) :: number
			ZoneService.markPvpCombat(player.UserId, now)
			ZoneService.markPvpCombat(targetUserId, now)
		end
		-- Retorno de Pulso (item 10): o golpe foi reduzido pela postura do
		-- alvo — o atacante toma o contra (dano 8) e é empurrado 8 studs.
		if result.pulseCounter then
			applyPulseCounterToPlayer(player.UserId, target, now)
		end
		if not result.iframe then
			RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
				targetId = target.id,
				abilityId = if isHeavy then "heavy" else "light",
				outcome = if result.parried
						or result.stoppedOnGuard
						or result.broken
						or result.pulseCounter
						or target.guarding
					then "guard"
					else "hit",
				-- Degrau autoritativo da cadeia leve: o cliente sincroniza a
				-- pose com o servidor (docs/14 §4.3 — correção da divergência).
				step = if isHeavy then 0 else (result.step or 0),
			})
			fireVitalsForFighter(target.id)
		end
		if result.killed then
			-- Item 11: se o alvo é um jogador, a morte dele aplica a perda
			-- de XP PvP (15% da não consolidado na zona livre, cap 200).
			if target.id:match("^player:") then
				applyDeathPenalty(tonumber(target.id:match("^player:(%d+)$")) :: number, true)
			elseif EnemyService.isElite(target.id) then
				-- Elite (item 9): o crédito é do leeching (resolveEliteDeath no
				-- tick) — sem último golpe, para todos os elegíveis. Aqui só
				-- registramos o dano; nunca creditamos direto (evita duplicar).
				EnemyService.registerEliteDamage(target.id, player.UserId, result.damage)
			else
				creditKill(player, target.id, now)
			end
		elseif EnemyService.isElite(target.id) and result.damage > 0 then
			EnemyService.registerEliteDamage(target.id, player.UserId, result.damage)
		end
	else
		-- Golpe errou (whiff, recovery ou fora da hitbox): a cadeia leve zera
		-- no servidor e o cliente precisa saber, senão exibe um degrau que o
		-- servidor não confirmou (docs/14 §4.3 — pose travada no chute).
		if not isHeavy then
			attacker.lightStep = 0
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
			abilityId = if isHeavy then "heavy" else "light",
			outcome = "miss",
			step = 0,
		})
	end
end)

-- Interação contextual F0: catálogo, posição e duração do hold são validados no
-- servidor. O cliente não informa distância, recompensa ou quantidade de XP.
InteractionService.init({
	catalog = Interactions,
	getAnchor = CatalogService.getAnchor,
	getPlayerPosition = function(userId: number)
		return SpatialService.getPosition(CombatService.playerFighterId(userId))
	end,
	onNpc = function(userId: number, npcId: string, now: number)
		return QuestService.tryAcceptFromNpc(userId, npcId, now)
	end,
	onAnchor = function(userId: number, anchorId: string, now: number)
		if anchorId ~= "anchor_bastion_return" then
			return false, "unknown_target", nil
		end
		local resource = ResourceService.getState(userId)
		if resource and resource.combat then
			return false, "in_combat", nil
		end
		local receipt = ProgressionService.consolidate(userId, now)
		if not receipt then
			return false, "unknown_player", nil
		end
		SaveService.appendOperation(userId, {
			operationId = receipt.operationId,
			kind = "consolidate",
			amount = receipt.consolidated,
			at = receipt.at,
		})
		SaveService.markDirty(userId)
		local player = game.Players:GetPlayerByUserId(userId)
		local ledger = ProgressionService.getLedger(userId)
		if player and ledger then
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				unconsolidatedXp = ProgressionService.getUnconsolidatedXp(userId),
				consolidatedXp = ledger.consolidated,
			})
		end
		return true, nil, receipt
	end,
})

RemoteGateway.onClientIntent(Remotes.Names.InteractionIntent, function(player: Player, payload: { any })
	if requireReady(player) then
		InteractionService.tryInteract(player.UserId, payload, os.clock())
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.GuardIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	if not fighter then
		return
	end
	CombatService.setGuard(fighter, payload.phase == "down", os.clock())
	fireVitalsForFighter(fighter.id)
end)

local function dashGuardBlockers(userId: number, attackerId: string): { any }
	local blockers: { any } = {}
	local seen: { [string]: boolean } = {}
	local function add(fighterId: string)
		if fighterId == attackerId or seen[fighterId] or not canPlayerDamageFighter(userId, fighterId) then
			return
		end
		local fighter = CombatService.getFighter(fighterId)
		local position = SpatialService.getPosition(fighterId)
		if fighter and fighter.health > 0 and fighter.guarding and position then
			seen[fighterId] = true
			table.insert(blockers, { id = fighterId, position = position, radius = 2 })
		end
	end
	for _, other in game.Players:GetPlayers() do
		add(CombatService.playerFighterId(other.UserId))
	end
	for _, record in EnemyService.list() do
		add(record.fighterId)
	end
	return blockers
end

RemoteGateway.onClientIntent(Remotes.Names.DashIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	local direction = payload.direction
	local transform = if fighter then SpatialService.getTransform(fighter.id) else nil
	local magnitudeSquared = if type(direction) == "table"
		then (direction.x or 0) * (direction.x or 0) + (direction.z or 0) * (direction.z or 0)
		else 0
	-- Defesa em profundidade além do schema: vetor neutro ou estado espacial
	-- ausente não consomem cooldown nem concedem i-frame.
	if not fighter or not transform or magnitudeSquared < 0.01 then
		return
	end
	local dashAt = os.clock()
	local accepted = CombatService.canDash(fighter, dashAt)
	if not accepted then
		return
	end
	local distance = clearWorldTravel(player.UserId, direction, 12)
	local before = cloneTransform(transform)
	local resolution =
		SpatialService.resolveDash(fighter.id, direction, distance, 12, dashGuardBlockers(player.UserId, fighter.id))
	if resolution.traveled <= 0 then
		restoreTransform(fighter.id, before)
		return
	end
	if not applyPlayerSpatialPosition(player.UserId, resolution.position, os.clock()) then
		restoreTransform(fighter.id, before)
		return
	end
	CombatService.commitDash(fighter, dashAt)
end)

RemoteGateway.onClientIntent(Remotes.Names.ZoneCrossingIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local toZoneId = payload.toZoneId
	if type(toZoneId) ~= "string" then
		return
	end
	local root = playerRoot(player.UserId)
	local acceptedPosition = SpatialService.getPosition(CombatService.playerFighterId(player.UserId))
	if not root or not acceptedPosition then
		return
	end
	local currentNow = os.clock()
	-- Usa a última posição aceita pelo MotionGuard, nunca a HRP network-owned
	-- ainda não reconciliada deste frame.
	local hold = ZoneService.handleCrossingHold(player.UserId, toZoneId, payload.phase, currentNow, acceptedPosition)
	if not hold.ok then
		if payload.phase ~= "cancel" then
			ZoneService.notifyCrossingRejection(player.UserId, toZoneId, currentNow, hold.reason or "rejected")
		end
		return
	end
	if payload.phase ~= "complete" or not hold.anchorId then
		return
	end

	-- O complete autoriza a mudança e põe o avatar alguns studs para dentro do
	-- volume correspondente. Isso evita que o Heartbeat reclassifique a posição
	-- antiga como segura no frame seguinte.
	local anchor = CatalogService.getAnchor(hold.anchorId)
	if not anchor then
		ZoneService.notifyCrossingRejection(player.UserId, toZoneId, currentNow, "unknown_gate")
		return
	end
	local position = {
		x = anchor.position.x,
		y = anchor.position.y,
		z = anchor.position.z,
	}
	if hold.anchorId == "anchor_gate_north" then
		position.z -= 1.5
	else
		position.x -= 1.5
	end
	if CatalogService.zoneAtPosition(position) ~= toZoneId then
		ZoneService.notifyCrossingRejection(player.UserId, toZoneId, currentNow, "invalid_gate")
		return
	end

	local entered = ZoneService.tryEnterZone(player.UserId, toZoneId, currentNow, { holdConfirmed = true })
	if entered.ok and not applyPlayerSpatialPosition(player.UserId, position, currentNow) then
		-- Falha improvável após o preflight (sem yield), mas o rollback evita
		-- deixar zona lógica e avatar em lados diferentes.
		ZoneService.tryEnterZone(player.UserId, "zone_bastion_safe", currentNow, {})
	end
end)

-- 8. Ciclo de sessão
game.Players.PlayerAdded:Connect(function(player: Player)
	local loadStartedAt = os.clock()
	sessionStartedAt[player.UserId] = loadStartedAt
	ProgressionService.registerPlayer(player.UserId)
	-- Item 11: restaura o perfil salvo (flags + XP consolidado). Se o load
	-- falhar (lock de outro servidor ou falha de rede), a sessão segue em
	-- memória SEM criar default por cima do save existente (§11.2 itens 4/5).
	local profile = SaveService.loadProfile(player.UserId)
	if not profile then
		warn(("[Bootstrap] save indisponível para %d — sessão em memória"):format(player.UserId))
	end
	-- Recorte adicional da §18: playtest pode receber as três técnicas sem
	-- remote de cheat. O override é de sessão e nunca entra no ProfileRoot.
	if StudioDebug.isEnabled(RunService:IsStudio(), game:GetAttribute("F0Debug")) then
		for _, flag in StudioDebug.unlockFlags() do
			ProgressionService.grantSessionUnlock(player.UserId, flag)
		end
	end
	TelemetryService.record("SessionLoad", player.UserId, {
		durationMs = math.floor((os.clock() - loadStartedAt) * 1000),
		schemaFrom = if profile then profile.schemaVersion or 1 else 0,
		schemaTo = 1,
		result = if profile then "success" else "memory_fallback",
	})
	ZoneService.registerPlayer(player.UserId)
	QuestService.registerPlayer(player.UserId, os.clock())
	ProgressionService.grantUnlock(player.UserId, "ftue_spawned")
	TelemetryService.record("FtueBeat", player.UserId, {
		flag = "ftue_spawned",
		elapsedMs = math.floor((os.clock() - loadStartedAt) * 1000),
	})
	PlayerSessionService.onPlayerJoined(player)
	-- Snapshot S→C reemitido após o StarterPlayerScripts existir. Isso evita a
	-- corrida de boot sem criar uma intenção C→S proibida pela SLICE-DEC-005.
	local function resendSnapshot()
		if not PlayerSessionService.isReady(player.UserId) then
			return
		end
		local snapshot = PlayerSessionService.buildSnapshot(player.UserId, "eclipse_fist", "umbral_aether")
		if snapshot then
			RemoteGateway.fireClient(player, Remotes.Names.SessionSnapshot, snapshot)
		end
	end
	local function setupCharacter(character: Model)
		task.defer(function()
			local fighterId = CombatService.playerFighterId(player.UserId)
			local fighter = CombatService.getFighter(fighterId)
			local respawning = fighter ~= nil and fighter.health <= 0
			if not fighter or fighter.health <= 0 then
				fighter = CombatService.createFighter(fighterId, "player", 100, 100)
			end
			deathPresented[player.UserId] = nil
			local spawnPosition =
				WorldService.getAnchorPosition(if respawning then "anchor_bastion_return" else "anchor_bastion_spawn")
			if spawnPosition and character.Parent then
				if respawning then
					ZoneService.forceRespawnSafe(player.UserId)
				end
				character:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 3, 0)))
				SpatialService.setTransform(
					fighterId,
					{ x = spawnPosition.X, y = 0, z = spawnPosition.Z },
					{ x = 0, y = 0, z = -1 }
				)
				PlayerMotionGuard.register(player.UserId, {
					x = spawnPosition.X,
					y = spawnPosition.Y + 3,
					z = spawnPosition.Z,
				}, os.clock())
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					local current = CombatService.getFighter(fighterId)
					if current and current.health > 0 then
						current.health = 0
						current.diedAt = os.clock()
					end
				end)
			end
			fireVitalsForFighter(fighterId)
		end)
		task.delay(0.5, resendSnapshot)
	end
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end
	-- Posição inicial na âncora de spawn até o Heartbeat ler o personagem.
	local spawnAnchor = CatalogService.getAnchor("anchor_bastion_spawn")
	if spawnAnchor then
		local initialPosition = {
			x = spawnAnchor.position.x,
			y = spawnAnchor.position.y,
			z = spawnAnchor.position.z,
		}
		SpatialService.setTransform(
			CombatService.playerFighterId(player.UserId),
			initialPosition,
			{ x = 0, y = 0, z = -1 }
		)
		PlayerMotionGuard.register(player.UserId, initialPosition, os.clock())
	end
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
	SecurityService.clearPlayer(player.UserId)
	InteractionService.clearPlayer(player.UserId)
	AbilityService.clearPlayer(player.UserId)
	PlayerMotionGuard.clearPlayer(player.UserId)
	sessionStartedAt[player.UserId] = nil
	SpatialService.remove(CombatService.playerFighterId(player.UserId))
	PlayerSessionService.onPlayerLeft(player)
	QuestService.unregisterPlayer(player.UserId)
	ZoneService.unregisterPlayer(player.UserId)
	ProgressionService.unregisterPlayer(player.UserId)
	-- Item 11: libera o lock do perfil (salva se sujo) — §11.2 item 1.
	SaveService.releaseProfile(player.UserId)
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

-- Heartbeat espacial: lê a posição autoritativa do personagem, reconcilia a
-- zona pela geometria e roda a AI dos Estilhaços.
--
-- O cliente NUNCA informa posição para efeito de dano — o que se lê aqui é o
-- HumanoidRootPart replicado, e a fronteira é decidida pelo mesmo
-- `zoneAtPosition` que gerou os volumes no Studio.
local lastTick = os.clock()

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local delta = now - lastTick
	lastTick = now

	for _, player in game.Players:GetPlayers() do
		local userId = player.UserId
		if PlayerSessionService.isReady(userId) then
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				-- Combate usa projeção no plano do chão; o MotionGuard preserva o Y
				-- físico real separado. Assim a HRP (~3 studs) e NPCs (y=0) compartilham
				-- a mesma convenção para esferas/cápsulas.
				local physicalPosition = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
				local position = { x = root.Position.X, y = 0, z = root.Position.Z }
				local fighterId = CombatService.playerFighterId(userId)
				local previous = SpatialService.getTransform(fighterId)
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local walkSpeed = if humanoid then humanoid.WalkSpeed else 16
				local motionOk = select(1, PlayerMotionGuard.authorize(userId, physicalPosition, now, walkSpeed))
				if not motionOk and previous then
					applyPlayerSpatialPosition(userId, previous.position, now)
					continue
				elseif not motionOk then
					PlayerMotionGuard.register(userId, physicalPosition, now)
				end
				local look = root.CFrame.LookVector
				SpatialService.setTransform(fighterId, position, { x = look.X, y = look.Y, z = look.Z })

				-- Reconciliação de zona. Fora de qualquer volume mantém a zona
				-- anterior; recusa (hold ou lockout) já emite ZoneEvent, e
				-- empurrar o jogador de volta fisicamente é trabalho de Studio.
				local geometric = CatalogService.zoneAtPosition(position)
				if geometric and geometric ~= ZoneService.getPlayerZone(userId) then
					local entered = ZoneService.tryEnterZone(userId, geometric, now, {})
					if not entered.ok and previous then
						restoreTransform(fighterId, previous)
						applyPlayerSpatialPosition(userId, previous.position, now)
					end
				end
			end
		end
	end

	EnemyService.tick(now, delta)
	-- Item 9: ciclo do elite (combo/slam + leeching + respawn 180 s).
	EnemyService.tickElite(now, delta)
	for _, record in EnemyService.list() do
		local transform = SpatialService.getTransform(record.fighterId)
		if transform then
			WorldService.syncActor(record.fighterId, transform)
		end
	end
	-- Item 8/10: ecos pendentes da Cadência (350 ms) e posturas do Pulso.
	AbilityService.tick(now)
	-- Item 11: morte PvE (inimigo) aplica a perda; autosave 60–120 s com
	-- jitter persiste o perfil sujo.
	for _, player in game.Players:GetPlayers() do
		local userId = player.UserId
		if PlayerSessionService.isReady(userId) then
			local fighter = CombatService.getFighter(CombatService.playerFighterId(userId))
			if fighter and fighter.health <= 0 then
				if deathPresented[userId] ~= fighter.diedAt then
					deathPresented[userId] = fighter.diedAt
					fireVitalsForFighter(fighter.id)
					RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
						abilityId = "death",
						outcome = "death",
					})
				end
				applyDeathPenalty(userId, false)
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if humanoid and humanoid.Health > 0 then
					humanoid.Health = 0
				end
			end
			SaveService.tick(userId, now)
		end
	end
end)

print("[Bootstrap] servidor pronto (F0)")

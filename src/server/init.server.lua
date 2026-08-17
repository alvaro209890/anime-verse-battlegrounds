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
local HitContact = require(ReplicatedStorage.Shared.HitContact)
local Interactions = require(ReplicatedStorage.Shared.Data.Interactions)
local Locale = require(ReplicatedStorage.Shared.Data.Locale)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local InventoryService = require(Services.InventoryService)
local CareerService = require(Services.CareerService)
local RemoteEnvelope = require(ReplicatedStorage.Shared.RemoteEnvelope)
local WorldPresentation = require(ReplicatedStorage.Shared.Data.WorldPresentation)
local SpawnDecorations = require(ReplicatedStorage.Shared.Data.SpawnDecorations)
local WildDecorations = require(ReplicatedStorage.Shared.Data.WildDecorations)
local BiomeDecorations = require(ReplicatedStorage.Shared.Data.BiomeDecorations)
local Locomotion = require(ReplicatedStorage.Shared.Data.Locomotion)
local SceneryPresentation = require(ReplicatedStorage.Shared.Data.SceneryPresentation)
local DayNightCycle = require(ReplicatedStorage.Shared.Data.DayNightCycle)
local Zones = require(ReplicatedStorage.Shared.Data.Zones)

-- 1. Catálogo — validação em fail-fast
CatalogService.init({
	Abilities = Abilities,
	Characters = Characters,
	EnergyFamilies = EnergyFamilies,
	Npcs = Npcs,
	Zones = Zones,
	Quests = Quests,
	Items = Items,
	Locale = Locale,
})
InventoryService.init({
	getItem = CatalogService.getItem,
	capacity = Items.CAPACITY,
})
CareerService.init()
print("[Bootstrap] catálogo validado")

local locomotionOk, locomotionReason = Locomotion.validate()
if not locomotionOk then
	error("catálogo de locomoção inválido: " .. (locomotionReason or "unknown"))
end
local presentationOk, presentationReason = WorldPresentation.validate()
if not presentationOk then
	error("catálogo de apresentação inválido: " .. (presentationReason or "unknown"))
end
local interactionsOk, interactionsReason = Interactions.validate()
if not interactionsOk then
	error("catálogo de interações inválido: " .. (interactionsReason or "unknown"))
end
local sceneryOk, sceneryReason = SceneryPresentation.validate()
if not sceneryOk then
	error("catálogo de cenário inválido: " .. (sceneryReason or "unknown"))
end
local dayNightOk, dayNightReason = DayNightCycle.validate()
if not dayNightOk then
	error("catálogo de ciclo dia/noite inválido: " .. (dayNightReason or "unknown"))
end
-- Honestidade visual (docs/17): aqui os dois catálogos existem, então a skin do
-- inimigo é conferida contra o alcance REAL do golpe dele. Uma lâmina que passa
-- do `attackRange` ensina o jogador a recuar de menos.
local shardSkinOk, shardSkinReason = WorldPresentation.validateShardSkins(Npcs)
if not shardSkinOk then
	error("skin de estilhaço inválida: " .. (shardSkinReason or "unknown"))
end
local biomeVolumes = {}
for _, zoneId in { "zone_lumen_safe", "zone_echo_woods", "zone_iron_port", "zone_grey_sector", "zone_academy_safe" } do
	local zone = Zones.get(zoneId)
	if zone then
		for _, volume in zone.volumes do
			table.insert(biomeVolumes, volume)
		end
	end
end
local shardPositions = {}
for _, anchorId in Zones.shardAnchors() do
	local anchor = Zones.getAnchor(anchorId)
	if anchor then
		table.insert(shardPositions, anchor.position)
	end
end
local biomeErrors = BiomeDecorations.validate(BiomeDecorations.all(), biomeVolumes, shardPositions, {
	x = 0,
	z = -102,
	radius = 20,
})
if #biomeErrors > 0 then
	error("decoração de bioma inválida: " .. biomeErrors[1])
end

ProgressionService.init()

-- 1.1. Mundo — greybox, collision groups e marcadores de âncora (§8).
-- Constrói a partir dos mesmos números que `zoneAtPosition` usa.
WorldService.init({
	zones = Zones,
	greybox = Zones.greybox,
	presentation = WorldPresentation,
	scenery = SceneryPresentation,
	spawnDecorations = SpawnDecorations,
	wildDecorations = WildDecorations,
	biomeDecorations = BiomeDecorations,
	npcs = Npcs,
	dayNight = DayNightCycle,
})
-- Ciclo dia/noite: sample puro → Lighting no Heartbeat (~10 Hz interno).
WorldService.startDayNight(RunService)
print("[Bootstrap] greybox construído + ciclo dia/noite")

-- 1.2. Espaço — produz distância, costas e hitbox para o combate.
SpatialService.init({ geometry = Geometry })

-- Alcance e abertura do golpe (docs/13 §5.1, medido no Studio em 13/08).
--
-- A distância é medida de CENTRO a CENTRO. O alcance declarado do golpe (6
-- studs na spec) é distância entre corpos, então a aquisição precisa somar o
-- raio dos dois: ~1,5 stud do jogador + ~1,5 stud do alvo (torso 2,2 × escala
-- 0,9 do Estilhaço). Sem essa folga, encostar no inimigo ainda media mais que
-- o alcance e o golpe passava reto — foi o que o playtest das 15h mostrou.
local BODY_ALLOWANCE_STUDS = 5
local BASIC_RANGE_STUDS = 6
-- Cresce com o degrau da cadeia, como a amplitude da pose.
local BASIC_LIGHT_REACH_STUDS: { number } = {
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 1,
}
local BASIC_HEAVY_REACH_STUDS = BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5
-- Cadência Quebrada declara range 6 no catálogo: mesma folga de corpo.
local CADENCE_REACH_STUDS = BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS
-- Abertura horizontal (meio-ângulo). O pesado é mais preciso que a cadeia.
local BASIC_LIGHT_HALF_ANGLE_DEGREES = 78
local BASIC_HEAVY_HALF_ANGLE_DEGREES = 68
-- Intervalo mínimo do servidor entre golpes básicos (alerta 14/08): alinhado
-- ao LIGHT_WINDOW do CombatService (0,65 s). A cadeia leve continua dentro da
-- janela; uma NOVA cadeia (ou um pesado) só sai depois da pausa. Sem isto, um
-- macro de cliente no teto do rate limit (8 intents/s) executava todo intent
-- e atingia ~64-96 DPS.
local BASIC_MIN_INTERVAL = 0.65

-- Log de combate só no Studio com F0Debug (mesmo gate das técnicas de teste).
local combatDebugEnabled = StudioDebug.isEnabled(
	RunService:IsStudio(),
	StudioDebug.resolveAttribute(game:GetAttribute("F0Debug"), script:GetAttribute("F0Debug"))
)
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
		local snapshot = ProgressionService.snapshotForSave(userId)
		if snapshot then
			local payload = snapshot :: any
			payload.inventory = InventoryService.snapshot(userId)
			payload.career = CareerService.snapshot(userId, os.clock())
		end
		return snapshot
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
CareerService.onPersist = SaveService.markDirty

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
		if event.state == "completed" then
			InventoryService.grant(userId, "umbral_dust", 1)
			CareerService.creditQuest(userId)
		end
		local view = ProgressionService.viewFor(userId)
		local payload: { [string]: any } = {
			objective = event,
			unlocks = ProgressionService.listUnlocks(userId),
			unconsolidatedXp = if view then view.unconsolidatedXp else ProgressionService.getUnconsolidatedXp(userId),
			accountLevel = if view then view.accountLevel else 1,
			xpIntoLevel = if view then view.xpIntoLevel else 0,
			xpToNext = if view then view.xpToNext else 0,
			unspentPoints = if view then view.unspentPoints else 0,
			pendingLevels = if view then view.pendingLevels else 0,
			spent = if view then view.spent else nil,
			inventory = if InventoryService.snapshot(userId) then InventoryService.snapshot(userId).stackables else {},
		}
		if event.xpGranted and event.xpGranted > 0 then
			payload.xpPopup = { amount = event.xpGranted }
		end
		RemoteGateway.fireClient(player, Remotes.Names.StateDelta, payload)
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

local function copyCombatEvent(payload: { [string]: any }, view: string): { [string]: any }
	local event = table.clone(payload)
	event.view = view
	return event
end

local function fireCombatEvent(player: Player, payload: { [string]: any }, view: string): ()
	RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, copyCombatEvent(payload, view))
end

-- HP/número continuam autoritativos; o defensor precisa do feeling no mesmo frame.
local function fireDealtAndTaken(attackerPlayer: Player, targetId: string?, payload: { [string]: any }): ()
	fireCombatEvent(attackerPlayer, payload, "dealt")
	if type(targetId) ~= "string" then
		return
	end
	local targetUserIdText = string.match(targetId, "^player:(%d+)$")
	if not targetUserIdText then
		return
	end
	local targetPlayer = game.Players:GetPlayerByUserId(tonumber(targetUserIdText) :: number)
	if targetPlayer and targetPlayer ~= attackerPlayer then
		fireCombatEvent(targetPlayer, payload, "taken")
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
	if type(defender.id) == "string" and counter.damage and counter.damage > 0 then
		CareerService.creditFromFighterId(defender.id, counter.damage)
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
	getResourceCostMul = ProgressionService.resourceCostMul,
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
	creditCareerDamage = CareerService.creditDamage,
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
		fireDealtAndTaken(player, targetId, {
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
		-- Mesma aquisição em cone do golpe básico: a esfera antiga fazia a
		-- técnica errar mesmo com o inimigo na cara do jogador.
		local targetId = SpatialService.acquireTarget(
			attackerId,
			CADENCE_REACH_STUDS,
			BASIC_LIGHT_HALF_ANGLE_DEGREES,
			function(fighterId: string): boolean
				local other = CombatService.getFighter(fighterId)
				if not other or other.health <= 0 then
					return false
				end
				return canPlayerDamageFighter(userId, fighterId)
			end
		)
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
		local match = SpatialService.acquireTarget(
			attackerId,
			CADENCE_REACH_STUDS,
			BASIC_LIGHT_HALF_ANGLE_DEGREES,
			function(fighterId: string): boolean
				return fighterId == target.id
			end
		)
		return match == target.id
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
		snapshot.career = CareerService.viewFor(player.UserId, os.clock())
		RemoteGateway.fireClient(player, Remotes.Names.SessionSnapshot, snapshot)
	end,
	getPlayerZone = ZoneService.getPlayerZone,
	getUnlocks = ProgressionService.listUnlocks,
	getObjective = QuestService.getTracker,
	getUnconsolidatedXp = ProgressionService.getUnconsolidatedXp,
	getProgression = ProgressionService.viewFor,
	getInventory = function(userId: number)
		local bag = InventoryService.snapshot(userId)
		return if bag then bag.stackables else {}
	end,
})

local function progressionPayload(userId: number): { [string]: any }
	local view = ProgressionService.viewFor(userId)
	if not view then
		return { unconsolidatedXp = 0, accountLevel = 1 }
	end
	return {
		unconsolidatedXp = view.unconsolidatedXp,
		consolidatedXp = view.consolidatedXp,
		accountLevel = view.accountLevel,
		xpIntoLevel = view.xpIntoLevel,
		xpToNext = view.xpToNext,
		unspentPoints = view.unspentPoints,
		pendingLevels = view.pendingLevels,
		previewLevel = view.previewLevel,
		spent = view.spent,
		vitals = view.vitals,
		inventory = if InventoryService.snapshot(userId) then InventoryService.snapshot(userId).stackables else {},
		career = CareerService.viewFor(userId, os.clock()),
	}
end

local function applyProgressionVitals(userId: number): ()
	local view = ProgressionService.viewFor(userId)
	if not view then
		return
	end
	CombatService.applyVitals(
		CombatService.playerFighterId(userId),
		view.vitals.maxHealth,
		view.vitals.maxGuard,
		view.vitals.damageBonus
	)
	ResourceService.setPoolBonus(userId, view.vitals.maxResource - 100)
end

local function pushProgression(userId: number, extra: { [string]: any }?): ()
	local player = game.Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	applyProgressionVitals(userId)
	local payload = progressionPayload(userId)
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(userId))
	if fighter then
		payload.health = fighter.health
		payload.maxHealth = fighter.maxHealth
		payload.guard = fighter.guard
		payload.maxGuard = fighter.maxGuard
	end
	local resource = ResourceService.getState(userId)
	if resource then
		payload.resource = resource.resource
		payload.maxResource = ResourceService.poolCapFor(resource)
	end
	RemoteGateway.fireClient(player, Remotes.Names.StateDelta, payload)
end

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
	QuestService.creditKill(player.UserId, npcId, now)
	for _, drop in Items.lootForNpc(npcId) do
		InventoryService.grant(player.UserId, drop.itemId, drop.amount)
	end
	CareerService.creditKill(player.UserId, npcId, npcDef.attackPattern == "elite")
	-- Item 11: XP/flags mudaram — o autosave precisa persistir.
	SaveService.markDirty(player.UserId)
	-- Sempre empurra o popup de XP do kill. Se o objetivo também avançou,
	-- o onQuestEvent já mandou o tracker (e o XP da task, se completou).
	local extra: { [string]: any } = {}
	if award.granted > 0 then
		extra.xpPopup = { amount = award.granted, targetId = fighterId }
	end
	pushProgression(player.UserId, extra)
	return award.granted
end

-- Kill direto (BasicAttackIntent): reporta o died. O crédito (XP + objetivo)
-- vem do `onKill` amarrado no EnemyService.init — o mesmo caminho usado pelo
-- leeching do elite. Chamar `grantKillCredit` aqui de novo duplicava XP e
-- progresso de quest a cada kill (bug do tracker preso/adiantado). O elite
-- NÃO passa por aqui — a morte dele resolve o leeching no tick.
local function creditKill(player: Player, fighterId: string, _now: number): ()
	EnemyService.reportKill(player.UserId, fighterId)
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
	CareerService.creditDeath(userId)
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
			pushProgression(userId, { deathPenalty = penalty.lost })
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
	if counter.damage and counter.damage > 0 then
		CareerService.creditDamage(defenderUserId, counter.damage)
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
					abilityId = event.abilityId,
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

-- Mira declarada pelo cliente (golpe e técnica).
--
-- Até 14/08 o cliente girava a própria HumanoidRootPart antes de mandar a
-- intenção e o heartbeat copiava esse look para o SpatialService — era assim
-- que o cone e o lunge sabiam para onde apontar. O efeito colateral era o corpo
-- estalar para a direção da câmera a cada ação, de costas para ela, mesmo com o
-- jogador parado. Agora a direção chega declarada e o corpo fica onde está.
--
-- A autoridade não mudou de lado: aquela rotação já era escrita pelo cliente.
-- O schema valida o vetor (SecurityService) e aqui há a segunda barreira, como
-- no dash. Alcance, abertura, alvo, dano e posição continuam do servidor.
local function applyDeclaredAim(fighterId: string, aim: any): boolean
	local look = SpatialService.aimLook(aim)
	if not look then
		return false
	end
	local transform = SpatialService.getTransform(fighterId)
	if not transform then
		return false
	end
	SpatialService.setTransform(fighterId, transform.position, look)
	return true
end

-- 7. Intenção de habilidade (cliente → servidor)
RemoteGateway.onClientIntent(Remotes.Names.AbilityIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	applyDeclaredAim(CombatService.playerFighterId(player.UserId), payload.aim)
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
	if ok then
		CareerService.creditTechnique(player.UserId)
	end
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
	-- Antes de adquirir alvo: o cone sai da mira declarada, não da rotação do
	-- corpo, que desde 14/08 não acompanha mais a câmera no golpe.
	applyDeclaredAim(attackerId, payload.aim)
	local kind = payload.kind
	local now = os.clock()

	-- Gate de cadência (alerta 14/08): o SecurityService valida `phase` mas o
	-- handler executava TODO intent. Só "press" executa; "release" é no-op. E
	-- o servidor impõe o intervalo mínimo entre golpes básicos: a cadeia leve
	-- em andamento (lightStep 1..3 dentro da janela) segue sem esperar, mas
	-- uma nova cadeia/pesado exige BASIC_MIN_INTERVAL desde o último golpe.
	if payload.phase ~= "press" then
		return
	end
	local chainAlive = attacker.lightStep > 0
		and attacker.lightStep < 4
		and (now - attacker.lastLightAt) <= BASIC_MIN_INTERVAL
	if not chainAlive and (now - attacker.lastBasicAt) < BASIC_MIN_INTERVAL then
		return
	end
	attacker.lastBasicAt = now

	-- Aquisição em cone (§5.1, corrigido em 13/08 15h). A esfera à frente
	-- media centro-a-centro e alcançava ~6 studs: no Studio, o jogador
	-- "colado" no Estilhaço estava a 11 studs e nenhum golpe conectava.
	-- Agora: o alvo válido mais próximo dentro do alcance e da abertura.
	-- Máx. 1 alvo por golpe, como a spec exige.
	local isHeavy = kind == "heavy"
	local step = math.clamp(attacker.lightStep + 1, 1, 4)
	local reach = if isHeavy then BASIC_HEAVY_REACH_STUDS else BASIC_LIGHT_REACH_STUDS[step]
	local halfAngle = if isHeavy then BASIC_HEAVY_HALF_ANGLE_DEGREES else BASIC_LIGHT_HALF_ANGLE_DEGREES
	-- Diagnóstico de Studio: quando o golpe não conecta, o Output diz por quê
	-- (fora do alcance? fora do cone? bloqueado pela fronteira?). Sem isto, a
	-- única evidência era "não acertou nada" (docs/18 §8).
	local blockedByFrontier = 0
	local function canAcquire(fighterId: string): boolean
		local other = CombatService.getFighter(fighterId)
		if not other or other.health <= 0 then
			return false
		end
		-- Dano não atravessa a fronteira (§8.2).
		local allowed = canPlayerDamageFighter(player.UserId, fighterId)
		if not allowed then
			blockedByFrontier += 1
		end
		return allowed
	end
	local acquiredId = SpatialService.acquireTarget(attackerId, reach, halfAngle, canAcquire)
	local claimedId = payload.claimedTargetId
	local claimedOk = type(claimedId) == "string" and canAcquire(claimedId)
	local attackerTransform = SpatialService.getTransform(attackerId)
	local claimedTransform = if claimedOk then SpatialService.getTransform(claimedId :: string) else nil
	local targetId = HitContact.resolveTarget(
		acquiredId,
		if claimedOk then claimedId :: string else nil,
		if attackerTransform then attackerTransform.position else nil,
		if attackerTransform then attackerTransform.look else nil,
		if claimedTransform then claimedTransform.position else nil,
		reach,
		halfAngle
	)
	if combatDebugEnabled and not targetId then
		local nearest = SpatialService.acquireTarget(attackerId, reach * 3, 180, function(fighterId: string): boolean
			local other = CombatService.getFighter(fighterId)
			return other ~= nil and other.health > 0 and fighterId ~= attackerId
		end)
		print(
			("[Combat] %s errou: alcance %.1f, cone %d° — %s%s"):format(
				kind or "light",
				reach,
				halfAngle,
				if nearest
					then ("mais próximo: %s a %.1f studs"):format(
						nearest,
						SpatialService.distanceBetween(attackerId, nearest) or -1
					)
					else "nenhum fighter vivo por perto",
				if blockedByFrontier > 0
					then (" | %d recusado(s) pela fronteira: você está em %s"):format(
						blockedByFrontier,
						ZoneService.getPlayerZone(player.UserId)
					)
					else ""
			)
		)
	end
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
		if result.damage and result.damage > 0 then
			CareerService.creditDamage(player.UserId, result.damage)
		end
		if not result.iframe then
			fireDealtAndTaken(
				player,
				target.id,
				CombatService.basicCombatEvent(result, kind, target.id, target.guarding == true)
			)
			fireVitalsForFighter(target.id, player.UserId)
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
		fireCombatEvent(player, CombatService.basicCombatEvent(result, kind, nil, false), "dealt")
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
		local extra: { [string]: any } = {}
		if receipt.consolidated > 0 then
			CareerService.creditConsolidation(userId)
		end
		if (receipt.levelsGained or 0) > 0 then
			extra.levelsGained = receipt.levelsGained
			extra.pointsGranted = receipt.pointsGranted
			InventoryService.grant(userId, "umbral_dust", receipt.levelsGained or 1)
		end
		pushProgression(userId, extra)
		return true, nil, receipt
	end,
})

RemoteGateway.onClientIntent(Remotes.Names.InteractionIntent, function(player: Player, payload: { any })
	if requireReady(player) then
		InteractionService.tryInteract(player.UserId, payload, os.clock())
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.SpendProgressionIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local userId = player.UserId
	local result
	if payload.trackId == "respec" then
		local zone = CatalogService.getZone(ZoneService.getPlayerZone(userId))
		local inSafe = zone ~= nil and zone.kind == "safe"
		result = ProgressionService.respecPoints(userId, inSafe)
	else
		result = ProgressionService.spendPoints(userId, payload.trackId, payload.amount or 1)
	end
	if not result.ok then
		local key = if result.reason == "not_safe"
			then "hud.feedback_not_safe"
			elseif result.reason == "no_points" then "hud.feedback_no_points"
			else "hud.feedback_rejected"
		pushProgression(userId, { feedbackKey = key })
		return
	end
	SaveService.markDirty(userId)
	pushProgression(userId, {
		feedbackKey = if payload.trackId == "respec" then "hud.feedback_respec" else "hud.feedback_spent",
	})
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
	InventoryService.registerPlayer(player.UserId)
	-- Item 11: restaura o perfil salvo (flags + XP consolidado). Se o load
	-- falhar (lock de outro servidor ou falha de rede), a sessão segue em
	-- memória SEM criar default por cima do save existente (§11.2 itens 4/5).
	local profile = SaveService.loadProfile(player.UserId)
	if not profile then
		warn(("[Bootstrap] save indisponível para %d — sessão em memória"):format(player.UserId))
	end
	if profile and type(profile.inventory) == "table" then
		InventoryService.restore(player.UserId, profile.inventory)
	end
	CareerService.registerPlayer(player.UserId, os.clock())
	if profile and type(profile.career) == "table" then
		CareerService.restore(player.UserId, profile.career, os.clock())
	end
	if InventoryService.count(player.UserId, "traveler_wrap") <= 0 then
		if InventoryService.grant(player.UserId, "traveler_wrap", 1).granted > 0 then
			SaveService.markDirty(player.UserId)
		end
	end
	-- Recorte adicional da §18: playtest pode receber as três técnicas sem
	-- remote de cheat. O override é de sessão e nunca entra no ProfileRoot.
	-- `F0Debug` é lido do DataModel e do Script Server: o Rojo às vezes não
	-- carimba atributo na raiz do place.
	local debugAttribute = StudioDebug.resolveAttribute(game:GetAttribute("F0Debug"), script:GetAttribute("F0Debug"))
	local debugGranted = StudioDebug.applySessionUnlocks(
		RunService:IsStudio(),
		debugAttribute,
		function(flag: string): boolean
			return ProgressionService.grantSessionUnlock(player.UserId, flag)
		end
	)
	if debugGranted > 0 then
		print(("[Bootstrap] StudioDebug: %d técnicas de sessão para %d"):format(debugGranted, player.UserId))
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
	applyProgressionVitals(player.UserId)
	-- Snapshot S→C reemitido após o StarterPlayerScripts existir. Isso evita a
	-- corrida de boot sem criar uma intenção C→S proibida pela SLICE-DEC-005.
	local function resendSnapshot()
		if not PlayerSessionService.isReady(player.UserId) then
			return
		end
		local snapshot = PlayerSessionService.buildSnapshot(player.UserId, "eclipse_fist", "umbral_aether")
		if snapshot then
			local payload = snapshot :: any
			payload.career = CareerService.viewFor(player.UserId, os.clock())
			RemoteGateway.fireClient(player, Remotes.Names.SessionSnapshot, payload)
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
			applyProgressionVitals(player.UserId)
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
	InventoryService.unregisterPlayer(player.UserId)
	CareerService.unregisterPlayer(player.UserId, os.clock())
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
				local career = CareerService.viewFor(player.UserId, now)
				if career then
					RemoteGateway.fireClient(player, Remotes.Names.StateDelta, { career = career })
				end
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
				-- Cliente controla WalkSpeed para caminhar/correr (16/22), mas o
				-- envelope NUNCA aceita valor acima do teto de corrida — senão
				-- um exploit de WalkSpeed inflaria o budget de movimento.
				local claimedSpeed = if humanoid then humanoid.WalkSpeed else Locomotion.walkSpeed
				local walkSpeed = Locomotion.clampAuthorizedSpeed(claimedSpeed)
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
					-- Reconcilia em vez de só tentar entrar: quem já está na
					-- planície é da planície (docs/18 §8).
					local entered = ZoneService.reconcile(userId, geometric, now)
					-- `hold_required` não é invasão: é o jogador parado no vão do
					-- portão esperando confirmar a travessia. Puxá-lo de volta a
					-- cada Heartbeat criava uma parede invisível — do lado de
					-- dentro do Bastião não havia como sair (docs/18 §7). Ele fica
					-- onde está, a zona lógica continua segura e o HUD pede o
					-- SEGURE E. Qualquer outra recusa (lockout, travessia
					-- inválida) continua devolvendo a posição.
					if not entered.ok and ZoneService.shouldRestorePosition(entered.reason) and previous then
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
		-- Morto: não atualiza pose de locomoção (evita "andar" fantasma com vida 0).
		local enemyFighter = CombatService.getFighter(record.fighterId)
		if enemyFighter and enemyFighter.health <= 0 then
			continue
		end
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

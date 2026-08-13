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
local EnemyService = require(script.Parent.Services.EnemyService)
local PlayerSessionService = require(script.Parent.Services.PlayerSessionService)
local SpatialService = require(script.Parent.Services.SpatialService)
local WorldService = require(script.Parent.Services.WorldService)
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
local Geometry = require(ReplicatedStorage.Shared.Geometry)
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

-- 1.1. Mundo — greybox, collision groups e marcadores de âncora (§8).
-- Constrói a partir dos mesmos números que `zoneAtPosition` usa.
WorldService.init({
	zones = Zones,
	greybox = Zones.greybox,
})
print("[Bootstrap] greybox construído")

-- 1.2. Espaço — produz distância, costas e hitbox para o combate.
SpatialService.init({ geometry = Geometry })

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
	onSaved = function(userId: number, _result: { any })
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
	onCombatHit = function(userId: number, targetId: string, _damage: number, abilityId: string)
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
			targetId = targetId,
			abilityId = abilityId,
			outcome = "hit",
		})
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
	onFlowEcho = function(userId: number, abilityId: string)
		QuestService.creditFlowEcho(userId, abilityId, os.clock())
	end,
	-- Ombro Cometa espacial (§6.1): 7 studs, cap 8, para em parede e em guarda
	-- inimiga, cápsula 4×4×8 no trajeto e no máximo 1 alvo.
	resolveCometShoulder = function(userId: number)
		local attackerId = CombatService.playerFighterId(userId)
		return SpatialService.resolveCometShoulder(attackerId, {
			distance = 7,
			hardCap = 8,
			capsuleRadius = 2,
			blockerRadius = 2,
			blocks = function(fighterId: string): boolean
				local fighter = CombatService.getFighter(fighterId)
				-- Guarda ativa para o avanço; corpo morto não bloqueia.
				return fighter ~= nil and fighter.health > 0 and fighter.guarding == true
			end,
			targets = function(fighterId: string): boolean
				local fighter = CombatService.getFighter(fighterId)
				return fighter ~= nil and fighter.health > 0
			end,
		})
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
local function zoneOfFighter(fighterId: string, selfUserId: number?): string
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

-- 6.1. Inimigos — spawn nas 6 âncoras, perseguição e respawn (§9.2).
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
		-- Telegraph precisa chegar ao cliente para o contorno branco (§17).
		for _, player in game.Players:GetPlayers() do
			if PlayerSessionService.isReady(player.UserId) then
				RemoteGateway.fireClient(player, Remotes.Names.EnemyEvent, {
					fighterId = fighterId,
					kind = event.kind,
					targetId = event.targetId,
					damage = event.damage,
				})
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

	local ok, reason = AbilityService.tryActivate(attacker, abilityId, nil, payload)
	if not ok then
		RemoteGateway.fireClient(player, Remotes.Names.AbilityRejected, {
			abilityId = abilityId,
			reason = reason or "unknown",
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
		return ZoneService.canDamageCrossBoundary(
			ZoneService.getPlayerZone(player.UserId),
			zoneOfFighter(fighterId, player.UserId)
		)
	end, 1)

	local targetId = hits[1]
	local target = if targetId then CombatService.getFighter(targetId) else nil
	local facing = if targetId then SpatialService.facingOf(targetId, attackerId) else "front"

	local result = if isHeavy
		then CombatService.tryHeavy(attacker, target, now, facing)
		else (if target then CombatService.tryLight(attacker, target, now, facing) else nil)

	if result and result.ok and target then
		ZoneService.markHostileAction(player.UserId, now)
		-- Retorno de Pulso (item 10): o golpe foi reduzido pela postura do
		-- alvo — o atacante toma o contra (dano 8) e é empurrado 8 studs.
		if result.pulseCounter then
			CombatService.tryPulseCounter(attacker, now)
			local targetPosition = SpatialService.getPosition(target.id)
			if targetPosition then
				SpatialService.pushBack(attackerId, targetPosition, 8)
			end
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatEvent, {
			targetId = target.id,
			abilityId = if isHeavy then "heavy" else "light",
			outcome = if result.parried or result.stoppedOnGuard or target.guarding then "guard" else "hit",
		})
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
	end
end)

-- Aceite do objetivo no Instrutor do Limiar (docs/13 §10, §13).
RemoteGateway.onClientIntent(Remotes.Names.InteractionIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local npcId = payload.npcId
	if type(npcId) == "string" then
		QuestService.tryAcceptFromNpc(player.UserId, npcId, os.clock())
		return
	end
	-- Item 11: consolidação no Marco de Retorno (docs/13 §11.1) — interagir
	-- 1,5 s com `anchor_bastion_return` fora de combate move todo o XP não
	-- consolidado para consolidado, com recibo idempotente.
	local anchorId = payload.anchorId
	if type(anchorId) == "string" and anchorId == "anchor_bastion_return" then
		local resource = ResourceService.getState(player.UserId)
		if resource and resource.combat then
			return
		end
		local receipt = ProgressionService.consolidate(player.UserId, os.clock())
		if receipt then
			SaveService.appendOperation(player.UserId, {
				operationId = receipt.operationId,
				kind = "consolidate",
				amount = receipt.consolidated,
				at = receipt.at,
			})
			SaveService.markDirty(player.UserId)
			RemoteGateway.fireClient(player, Remotes.Names.StateDelta, {
				unconsolidatedXp = ProgressionService.getUnconsolidatedXp(player.UserId),
				consolidatedXp = ProgressionService.getLedger(player.UserId).consolidated,
			})
		end
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
	-- Item 11: restaura o perfil salvo (flags + XP consolidado). Se o load
	-- falhar (lock de outro servidor ou falha de rede), a sessão segue em
	-- memória SEM criar default por cima do save existente (§11.2 itens 4/5).
	local profile = SaveService.loadProfile(player.UserId)
	if not profile then
		warn(("[Bootstrap] save indisponível para %d — sessão em memória"):format(player.UserId))
	end
	ZoneService.registerPlayer(player.UserId)
	QuestService.registerPlayer(player.UserId, os.clock())
	ProgressionService.grantUnlock(player.UserId, "ftue_spawned")
	PlayerSessionService.onPlayerJoined(player)
	-- Posição inicial na âncora de spawn até o Heartbeat ler o personagem.
	local spawnAnchor = CatalogService.getAnchor("anchor_bastion_spawn")
	if spawnAnchor then
		SpatialService.setTransform(CombatService.playerFighterId(player.UserId), {
			x = spawnAnchor.position.x,
			y = spawnAnchor.position.y,
			z = spawnAnchor.position.z,
		}, { x = 0, y = 0, z = -1 })
	end
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
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
local RunService = game:GetService("RunService")
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
				local position = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
				local look = root.CFrame.LookVector
				SpatialService.setTransform(
					CombatService.playerFighterId(userId),
					position,
					{ x = look.X, y = look.Y, z = look.Z }
				)

				-- Reconciliação de zona. Fora de qualquer volume mantém a zona
				-- anterior; recusa (hold ou lockout) já emite ZoneEvent, e
				-- empurrar o jogador de volta fisicamente é trabalho de Studio.
				local geometric = CatalogService.zoneAtPosition(position)
				if geometric and geometric ~= ZoneService.getPlayerZone(userId) then
					ZoneService.tryEnterZone(userId, geometric, now, {})
				end
			end
		end
	end

	EnemyService.tick(now, delta)
	-- Item 9: ciclo do elite (combo/slam + leeching + respawn 180 s).
	EnemyService.tickElite(now, delta)
	-- Item 8/10: ecos pendentes da Cadência (350 ms) e posturas do Pulso.
	AbilityService.tick(now)
	-- Item 11: morte PvE (inimigo) aplica a perda; autosave 60–120 s com
	-- jitter persiste o perfil sujo.
	for _, player in game.Players:GetPlayers() do
		local userId = player.UserId
		if PlayerSessionService.isReady(userId) then
			local fighter = CombatService.getFighter(CombatService.playerFighterId(userId))
			if fighter and fighter.health <= 0 then
				applyDeathPenalty(userId, false)
			end
			SaveService.tick(userId, now)
		end
	end
end)

print("[Bootstrap] servidor pronto (F0)")

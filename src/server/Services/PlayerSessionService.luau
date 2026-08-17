--!strict
-- PlayerSessionService (server) — F0 (docs/04 §4.1, docs/13-F0-SLICE.md §12)
-- Ciclo join/leave: recurso, fighter, snapshot Ready. Sem snapshot o cliente
-- não envia intenção (SLICE-DEC-005).
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type SessionDeps = {
	getCharacter: (string) -> any?,
	getFamily: ((string) -> any?)?,
	createResourceState: (number, string) -> any?,
	removeResourceState: (number) -> (),
	getResourceState: ((number) -> any?)?,
	clearCooldowns: (number) -> (),
	releaseProfile: (number) -> (),
	createFighter: ((string, "player" | "npc", number, number) -> any)?,
	removeFighter: ((string) -> ())?,
	getFighter: ((string) -> any?)?,
	playerFighterId: ((number) -> string)?,
	onSnapshot: ((any, { any }) -> ())?,
	getPlayerZone: ((number) -> string)?,
	getUnlocks: ((number) -> { string })?,
	-- Tracker do objetivo ativo (docs/13 §13 — SessionSnapshot carrega objetivo).
	getObjective: ((number) -> any?)?,
	getUnconsolidatedXp: ((number) -> number)?,
	getProgression: ((number) -> any?)?,
}

export type SessionSnapshot = {
	protocolVersion: number,
	ready: boolean,
	zoneId: string,
	characterId: string,
	health: number,
	maxHealth: number,
	guard: number,
	maxGuard: number,
	resource: number,
	maxResource: number,
	familyId: string,
	unlocks: { string },
	dummyId: string,
	-- nil quando não há objetivo aceito (HUD esconde a linha).
	objective: any?,
	unconsolidatedXp: number,
	accountLevel: number?,
	xpIntoLevel: number?,
	xpToNext: number?,
	unspentPoints: number?,
	pendingLevels: number?,
	previewLevel: number?,
	spent: any?,
	vitals: any?,
}

local PlayerSessionService = {
	deps = nil :: SessionDeps?,
	ready = {} :: { [number]: boolean },
}

local DEFAULT_CHARACTER_ID = "eclipse_fist"
local DEFAULT_ZONE_ID = "zone_bastion_safe"
local DUMMY_ID = "npc_training_dummy"

function PlayerSessionService.init(deps: SessionDeps): ()
	PlayerSessionService.deps = deps
	table.clear(PlayerSessionService.ready)
end

function PlayerSessionService.isReady(userId: number): boolean
	return PlayerSessionService.ready[userId] == true
end

function PlayerSessionService.buildSnapshot(userId: number, characterId: string, familyId: string): SessionSnapshot?
	local deps = PlayerSessionService.deps
	if not deps then
		return nil
	end
	local resourceState = if deps.getResourceState then deps.getResourceState(userId) else nil
	local fighterId = if deps.playerFighterId then deps.playerFighterId(userId) else nil
	local fighter = if fighterId and deps.getFighter then deps.getFighter(fighterId) else nil
	local family = if deps.getFamily then deps.getFamily(familyId) else nil
	local health = 100
	local maxHealth = 100
	local guard = 100
	local maxGuard = 100
	if fighter then
		health = fighter.health
		maxHealth = fighter.maxHealth
		guard = fighter.guard
		maxGuard = fighter.maxGuard
	end
	local resource = 100
	local maxResource = 100
	if resourceState then
		resource = resourceState.resource
	end
	if family then
		maxResource = family.poolCap
	end
	local zoneId = DEFAULT_ZONE_ID
	if deps.getPlayerZone then
		zoneId = deps.getPlayerZone(userId) or DEFAULT_ZONE_ID
	end
	local unlocks: { string } = {}
	if deps.getUnlocks then
		unlocks = deps.getUnlocks(userId)
	end
	local objective = if deps.getObjective then deps.getObjective(userId) else nil
	local unconsolidatedXp = if deps.getUnconsolidatedXp then deps.getUnconsolidatedXp(userId) else 0
	local progression = if deps.getProgression then deps.getProgression(userId) else nil
	if progression and type(progression.vitals) == "table" then
		maxHealth = progression.vitals.maxHealth or maxHealth
		maxGuard = progression.vitals.maxGuard or maxGuard
		maxResource = progression.vitals.maxResource or maxResource
		if not fighter then
			health = maxHealth
			guard = maxGuard
		end
	end
	return {
		protocolVersion = 1,
		ready = true,
		zoneId = zoneId,
		characterId = characterId,
		health = health,
		maxHealth = maxHealth,
		guard = guard,
		maxGuard = maxGuard,
		resource = resource,
		maxResource = maxResource,
		familyId = familyId,
		unlocks = unlocks,
		dummyId = DUMMY_ID,
		objective = objective,
		unconsolidatedXp = unconsolidatedXp,
		accountLevel = if progression then progression.accountLevel else 1,
		xpIntoLevel = if progression then progression.xpIntoLevel else 0,
		xpToNext = if progression then progression.xpToNext else 0,
		unspentPoints = if progression then progression.unspentPoints else 0,
		pendingLevels = if progression then progression.pendingLevels else 0,
		previewLevel = if progression then progression.previewLevel else 1,
		spent = if progression then progression.spent else nil,
		vitals = if progression then progression.vitals else nil,
	}
end

function PlayerSessionService.onPlayerJoined(player: Player): ()
	local deps = PlayerSessionService.deps
	if not deps then
		return
	end
	local characterDef = deps.getCharacter(DEFAULT_CHARACTER_ID)
	if not characterDef then
		warn(("[PlayerSessionService] personagem padrão %s ausente"):format(DEFAULT_CHARACTER_ID))
		return
	end

	local state = deps.createResourceState(player.UserId, characterDef.energyFamilyId)
	if not state then
		warn(("[PlayerSessionService] falha ao criar estado de recurso para %d"):format(player.UserId))
		return
	end

	state.characterId = characterDef.id
	state.health = characterDef.baseHealth

	if deps.createFighter and deps.playerFighterId then
		deps.createFighter(deps.playerFighterId(player.UserId), "player", characterDef.baseHealth, 100)
	end

	local snapshot = PlayerSessionService.buildSnapshot(player.UserId, characterDef.id, characterDef.energyFamilyId)
	if snapshot then
		PlayerSessionService.ready[player.UserId] = true
		if deps.onSnapshot then
			deps.onSnapshot(player, snapshot)
		end
	end
end

function PlayerSessionService.onPlayerLeft(player: Player): ()
	local deps = PlayerSessionService.deps
	if not deps then
		return
	end
	PlayerSessionService.ready[player.UserId] = nil
	if deps.removeFighter and deps.playerFighterId then
		deps.removeFighter(deps.playerFighterId(player.UserId))
	end
	deps.removeResourceState(player.UserId)
	deps.clearCooldowns(player.UserId)
	deps.releaseProfile(player.UserId)
end

return PlayerSessionService

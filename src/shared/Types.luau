--!strict
-- Tipos compartilhados do núcleo — F0
-- Contratos de dados seguem docs/05-DATA-SCHEMA.md.

export type EnergyFamilyId = string
export type CharacterId = string
export type AbilityId = string
export type ModifierId = string
export type OperationId = string
export type PlayerUserId = number

-- Família de energia (docs/05 §5.2)
export type EnergyFamilyDefinition = {
	id: EnergyFamilyId,
	displayNameKey: string,
	poolBase: number,
	poolCap: number,
	regenInCombatPerSec: number,
	regenOutOfCombatPerSec: number,
	outOfCombatDelaySeconds: number,
	-- gainTrigger: "flow" premia timing correto (Éter Umbral)
	flowTimingWindowMs: number,
	flowGainOnTimedHit: number,
	flowGainCapSeconds: number,
	flowBonusAmount: number,
	flowBonusIntervalSeconds: number,
	-- TODO: depletionEffects e modifierCaps (F2)
}

-- Habilidade (docs/05 §5.3) — F0: subconjunto mínimo
export type ResourceCost = {
	amount: number,
	-- refundPolicy: "none" | "partial" | "full" (TODO F1)
}

export type CooldownDef = {
	baseSeconds: number,
	-- group: string (TODO F1 — cooldowns por grupo)
}

export type AbilityDefinition = {
	id: AbilityId,
	contentVersion: number,
	displayNameKey: string,
	descriptionKey: string,
	sourceCharacterId: CharacterId,
	energyFamilyId: EnergyFamilyId,
	kind: "Basic" | "Skill" | "Ultimate",
	slotCost: number,
	impactCost: number,
	tags: { string },
	inputMode: "Press" | "Hold" | "Release",
	startupMs: number,
	activeMs: number,
	recoveryMs: number,
	resourceCost: ResourceCost,
	cooldown: CooldownDef,
	range: number,
	maxTargets: number,
	-- serverRunnerId: implementação server-side permitida (registry em AbilityService)
	serverRunnerId: string,
	enabled: boolean,
}

export type CharacterDefinition = {
	id: CharacterId,
	contentVersion: number,
	displayNameKey: string,
	descriptionKey: string,
	energyFamilyId: EnergyFamilyId,
	combatArchetype: string,
	baseHealth: number,
	abilityIds: { AbilityId },
	enabled: boolean,
}

-- Estado de sessão do servidor (não persistido)
export type ServerPlayerState = {
	userId: PlayerUserId,
	characterId: CharacterId,
	health: number,
	resource: number,
	combat: boolean,
	lastCombatAt: number,
}

export type SessionSnapshot = {
	protocolVersion: number,
	ready: boolean,
	zoneId: string,
	characterId: CharacterId,
	health: number,
	maxHealth: number,
	guard: number,
	maxGuard: number,
	resource: number,
	maxResource: number,
	familyId: EnergyFamilyId,
	unlocks: { string },
	dummyId: string,
	objective: QuestTracker?,
	unconsolidatedXp: number,
	accountLevel: number?,
	xpIntoLevel: number?,
	xpToNext: number?,
	unspentPoints: number?,
	pendingLevels: number?,
	spent: any?,
	vitals: any?,
}

-- Objetivos da fatia (docs/13-F0-SLICE.md §10)
export type QuestId = string

export type QuestDefinition = {
	id: QuestId,
	trackerKey: string,
	kind: "kill",
	targetId: string,
	requiredCount: number,
	giverNpcId: string,
	autoAcceptAfterSeconds: number,
	xpReward: number,
	unlockFlag: string?,
	acceptFlag: string,
	enabled: boolean,
}

export type QuestState = "offered" | "active" | "completed"

-- Tracker enviado no SessionSnapshot e no StateDelta. O cliente resolve o
-- texto pela `trackerKey`; nunca calcula progresso nem recompensa.
export type QuestTracker = {
	questId: QuestId,
	state: QuestState,
	trackerKey: string,
	progress: number,
	required: number,
	xpReward: number?,
	xpGranted: number?,
	unlockFlag: string?,
	acceptSource: string?,
}

-- Contratos de rede (docs/04 §6) — payloads com versão
export type NetworkContract = {
	name: string,
	direction: "ClientToServer" | "ServerToClient",
	version: number,
	payload: string,
}

-- Zonas e âncoras (docs/13-F0-SLICE.md §4, §8)
export type ZoneId = string
export type AnchorId = string
export type InteractionId = string
export type Vec3 = { x: number, y: number, z: number }
export type Box = { min: Vec3, max: Vec3 }

export type ZoneDefinition = {
	id: ZoneId,
	displayNameKey: string,
	kind: "safe" | "transition" | "free",
	pvp: boolean,
	volumes: { Box },
}

export type AnchorDefinition = {
	id: AnchorId,
	zoneId: ZoneId,
	position: Vec3,
}

export type InteractionDefinition = {
	id: InteractionId,
	kind: "npc" | "anchor",
	targetId: string,
	anchorId: AnchorId,
	actionTextKey: string,
	objectTextKey: string,
	holdDuration: number,
	maxDistance: number,
	requiresLineOfSight: boolean,
}

-- Evento S→C de fronteira (docs/13-F0-SLICE.md §13 — ZoneEvent)
export type ZoneEventPayload = {
	from: ZoneId,
	to: ZoneId,
	pvp: boolean,
	signals: { string },
	holdConfirmed: boolean,
	lockoutRemaining: number?,
	instant: number,
	rejectedReason: string?,
}

return {}

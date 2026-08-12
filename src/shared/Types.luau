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

-- Contratos de rede (docs/04 §6) — payloads com versão
export type NetworkContract = {
	name: string,
	direction: "ClientToServer" | "ServerToClient",
	version: number,
	payload: string,
}

return {}

--!strict
-- NPCs da fatia F0 (docs/13-F0-SLICE.md §9)
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.

export type NpcDefinition = {
	id: string,
	displayNameKey: string,
	kind: "dummy" | "enemy" | "instructor",
	maxHealth: number,
	maxGuard: number,
	attackDamage: number,
	attackRange: number,
	attackPeriodSeconds: number,
	telegraphMs: number,
	grantsXp: boolean,
	enabled: boolean,
	moveSpeed: number?,
	respawnSeconds: number?,
	recoverySeconds: number?,
	xpUnconsolidated: number?,
	-- Retorno decrescente por âncora na sessão (docs/13 §9.2): os primeiros
	-- `xpFullKills` pagam `xpUnconsolidated`, os `xpReducedKills` seguintes
	-- pagam `xpReducedValue`, e o resto paga 0. Ausentes = sem decréscimo.
	xpFullKills: number?,
	xpReducedKills: number?,
	xpReducedValue: number?,
	maxAlive: number?,
	zoneId: string?,
	combatClearRadius: number?,
}

local Npcs: { [string]: NpcDefinition } = {
	-- Instrutor do Limiar — oferece o objetivo 1 (docs/13 §10). Não combate:
	-- alvo de InteractionIntent, nunca de hitbox.
	npc_threshold_instructor = {
		id = "npc_threshold_instructor",
		displayNameKey = "npc.threshold_instructor.name",
		kind = "instructor",
		maxHealth = 1,
		maxGuard = 0,
		attackDamage = 0,
		attackRange = 0,
		attackPeriodSeconds = 0,
		telegraphMs = 0,
		grantsXp = false,
		enabled = true,
		zoneId = "zone_bastion_safe",
	},
	npc_training_dummy = {
		id = "npc_training_dummy",
		displayNameKey = "npc.training_dummy.name",
		kind = "dummy",
		maxHealth = 10000,
		maxGuard = 0,
		attackDamage = 4,
		attackRange = 8,
		attackPeriodSeconds = 2.5,
		telegraphMs = 400,
		grantsXp = false,
		enabled = true,
	},
	enemy_wandering_shard = {
		id = "enemy_wandering_shard",
		displayNameKey = "enemy.wandering_shard.name",
		kind = "enemy",
		maxHealth = 40,
		maxGuard = 0,
		attackDamage = 6,
		attackRange = 4,
		attackPeriodSeconds = 1.0,
		telegraphMs = 400,
		grantsXp = true,
		enabled = true,
		moveSpeed = 12,
		respawnSeconds = 45,
		recoverySeconds = 0.6,
		xpUnconsolidated = 25,
		xpFullKills = 6,
		xpReducedKills = 6,
		xpReducedValue = 12,
		maxAlive = 4,
		zoneId = "zone_plain_free",
		combatClearRadius = 20,
	},
}

local NpcCatalog = {}

function NpcCatalog.get(npcId: string): NpcDefinition?
	return Npcs[npcId]
end

function NpcCatalog.all(): { NpcDefinition }
	local out: { NpcDefinition } = {}
	for _, def in Npcs do
		table.insert(out, def)
	end
	return out
end

return NpcCatalog

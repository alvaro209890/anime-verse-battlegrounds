--!strict
-- NPCs da fatia F0 (docs/13-F0-SLICE.md §9)
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.

export type NpcDefinition = {
	id: string,
	displayNameKey: string,
	kind: "dummy" | "enemy",
	maxHealth: number,
	maxGuard: number,
	attackDamage: number,
	attackRange: number,
	attackPeriodSeconds: number,
	telegraphMs: number,
	grantsXp: boolean,
	enabled: boolean,
}

local Npcs: { [string]: NpcDefinition } = {
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

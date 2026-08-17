--!strict
-- Itens da mochila F0 (docs/05 §5.5, §6.5). Materiais e um cosmético de
-- entrada — NENHUM concede dano, vida, guarda ou recurso (GDD-DEC-006).
-- Tipos inline para o harness Lune.

export type ItemType = "Material" | "Cosmetic"

export type ItemDefinition = {
	id: string,
	contentVersion: number,
	displayNameKey: string,
	descriptionKey: string,
	itemType: ItemType,
	stackLimit: number,
	enabled: boolean,
}

export type LootDrop = {
	itemId: string,
	amount: number,
}

local Items: { [string]: ItemDefinition } = {
	shard_fragment = {
		id = "shard_fragment",
		contentVersion = 1,
		displayNameKey = "item.shard_fragment.name",
		descriptionKey = "item.shard_fragment.desc",
		itemType = "Material",
		stackLimit = 99,
		enabled = true,
	},
	void_splinter = {
		id = "void_splinter",
		contentVersion = 1,
		displayNameKey = "item.void_splinter.name",
		descriptionKey = "item.void_splinter.desc",
		itemType = "Material",
		stackLimit = 20,
		enabled = true,
	},
	umbral_dust = {
		id = "umbral_dust",
		contentVersion = 1,
		displayNameKey = "item.umbral_dust.name",
		descriptionKey = "item.umbral_dust.desc",
		itemType = "Material",
		stackLimit = 99,
		enabled = true,
	},
	traveler_wrap = {
		id = "traveler_wrap",
		contentVersion = 1,
		displayNameKey = "item.traveler_wrap.name",
		descriptionKey = "item.traveler_wrap.desc",
		itemType = "Cosmetic",
		stackLimit = 1,
		enabled = true,
	},
}

-- Loot por NPC. Dummy e instrutor não drogam. Sem roll — quantidade fixa.
local LOOT_BY_NPC: { [string]: { LootDrop } } = {
	enemy_wandering_shard = { { itemId = "shard_fragment", amount = 1 } },
	enemy_anchored_shard = { { itemId = "void_splinter", amount = 1 } },
}

local ItemCatalog = {}

ItemCatalog.CAPACITY = 30

function ItemCatalog.get(itemId: string): ItemDefinition?
	return Items[itemId]
end

function ItemCatalog.all(): { ItemDefinition }
	local out: { ItemDefinition } = {}
	for _, def in Items do
		table.insert(out, def)
	end
	return out
end

function ItemCatalog.lootForNpc(npcId: string): { LootDrop }
	local drops = LOOT_BY_NPC[npcId]
	if not drops then
		return {}
	end
	return drops
end

return ItemCatalog

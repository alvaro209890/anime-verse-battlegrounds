--!strict
-- Personagens — F0 (docs/08-ROSTER.md)
-- Codinomes canônicos APENAS em comentário (referência de balanceamento).

local Types = require(script.Parent.Parent.Types)

export type CharacterDefinition = Types.CharacterDefinition

local Characters: { [Types.CharacterId]: Types.CharacterDefinition } = {
	-- codinome interno: yuji (inspiração: bruiser de combos rápidos)
	eclipse_fist = {
		id = "eclipse_fist",
		contentVersion = 1,
		displayNameKey = "character.eclipse_fist.name",
		descriptionKey = "character.eclipse_fist.desc",
		energyFamilyId = "umbral_aether",
		combatArchetype = "bruiser_timing",
		baseHealth = 100,
		abilityIds = { "dash_strike", "eclipse_barrier", "void_rupture", "eclipse_judgement" },
		enabled = true,
	},
}

local CharacterCatalog = {}

function CharacterCatalog.get(characterId: Types.CharacterId): Types.CharacterDefinition?
	return Characters[characterId]
end

function CharacterCatalog.all(): { Types.CharacterDefinition }
	local out: { Types.CharacterDefinition } = {}
	for _, def in Characters do
		table.insert(out, def)
	end
	return out
end

return CharacterCatalog

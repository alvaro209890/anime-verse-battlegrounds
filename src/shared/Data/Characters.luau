--!strict
-- Personagens — F0 (docs/08-ROSTER.md)
-- Codinomes canônicos APENAS em comentário (referência de balanceamento).
--
-- Tipos declarados inline (export type é compile-time) para manter o módulo
-- carregável em testes Lune (que não resolvem require(script.Parent.X)).
-- Contrato canônico: src/shared/Types.luau.

export type CharacterDefinition = {
	id: string,
	contentVersion: number,
	displayNameKey: string,
	descriptionKey: string,
	energyFamilyId: string,
	combatArchetype: string,
	baseHealth: number,
	abilityIds: { string },
	enabled: boolean,
}

local Characters: { [string]: CharacterDefinition } = {
	-- codinome interno: yuji (inspiração: bruiser de combos rápidos)
	eclipse_fist = {
		id = "eclipse_fist",
		contentVersion = 1,
		displayNameKey = "character.eclipse_fist.name",
		descriptionKey = "character.eclipse_fist.desc",
		energyFamilyId = "umbral_aether",
		combatArchetype = "bruiser_timing",
		baseHealth = 100,
		abilityIds = { "comet_shoulder", "broken_cadence", "pulse_return", "eclipse_beat" },
		enabled = true,
	},

	-- F1-early: Tecelão de Ecos (docs/08). Mesmas três técnicas do F0
	-- (importáveis) + família Fluxo Vital. Desbloqueio in-world (quest_grove).
	echo_weaver = {
		id = "echo_weaver",
		contentVersion = 1,
		displayNameKey = "character.echo_weaver.name",
		descriptionKey = "character.echo_weaver.desc",
		energyFamilyId = "vital_flow",
		combatArchetype = "pressure_echo",
		baseHealth = 120,
		abilityIds = { "comet_shoulder", "broken_cadence", "pulse_return", "eclipse_beat" },
		enabled = true,
	},
}

local CharacterCatalog = {}

function CharacterCatalog.get(characterId: string): CharacterDefinition?
	return Characters[characterId]
end

function CharacterCatalog.all(): { CharacterDefinition }
	local out: { CharacterDefinition } = {}
	for _, def in Characters do
		table.insert(out, def)
	end
	return out
end

return CharacterCatalog

--!strict
-- Habilidades — F0 (docs/13-F0-SLICE.md §6, docs/05 §5.3)
-- Spec do formato: ver docs/11-ABILITY-SPEC.md
-- TODO: masteryLevels, rangePolicy completo, securityLimits (F2)
--
-- Tipos declarados inline (export type é compile-time) para manter o módulo
-- carregável em testes Lune (que não resolvem require(script.Parent.X)).
-- Contrato canônico: src/shared/Types.luau.

export type AbilityDefinition = {
	id: string,
	contentVersion: number,
	displayNameKey: string,
	descriptionKey: string,
	sourceCharacterId: string,
	energyFamilyId: string,
	kind: "Basic" | "Skill" | "Ultimate",
	slotCost: number,
	impactCost: number,
	tags: { string },
	inputMode: "Press" | "Hold" | "Release",
	startupMs: number,
	activeMs: number,
	recoveryMs: number,
	resourceCost: { amount: number },
	cooldown: { baseSeconds: number },
	range: number,
	maxTargets: number,
	serverRunnerId: string,
	enabled: boolean,
}

local Abilities: { [string]: AbilityDefinition } = {
	-- Ombro Cometa — avanço curto; para na guarda (docs/13 §6.1)
	comet_shoulder = {
		id = "comet_shoulder",
		contentVersion = 1,
		displayNameKey = "ability.comet_shoulder.name",
		descriptionKey = "ability.comet_shoulder.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 1,
		impactCost = 2,
		tags = { "movement", "melee", "cancelable" },
		inputMode = "Press",
		startupMs = 180,
		activeMs = 220,
		recoveryMs = 350,
		resourceCost = { amount = 18 },
		cooldown = { baseSeconds = 7 },
		range = 8,
		maxTargets = 1,
		serverRunnerId = "comet_shoulder_runner",
		enabled = true,
	},

	-- Cadência Quebrada — dois golpes; reentrada 120 ms gera eco e Fluxo
	broken_cadence = {
		id = "broken_cadence",
		contentVersion = 1,
		displayNameKey = "ability.broken_cadence.name",
		descriptionKey = "ability.broken_cadence.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 1,
		impactCost = 2,
		tags = { "melee", "cancelable" },
		inputMode = "Press",
		startupMs = 140,
		activeMs = 260,
		recoveryMs = 280,
		resourceCost = { amount = 16 },
		cooldown = { baseSeconds = 8 },
		range = 6,
		maxTargets = 1,
		serverRunnerId = "broken_cadence_runner",
		enabled = true,
	},

	-- Retorno de Pulso — postura 250 ms; contra só se reduzir um golpe
	pulse_return = {
		id = "pulse_return",
		contentVersion = 1,
		displayNameKey = "ability.pulse_return.name",
		descriptionKey = "ability.pulse_return.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 1,
		impactCost = 2,
		tags = { "defense", "melee" },
		inputMode = "Press",
		startupMs = 250,
		activeMs = 180,
		recoveryMs = 300,
		resourceCost = { amount = 20 },
		cooldown = { baseSeconds = 12 },
		range = 6,
		maxTargets = 1,
		serverRunnerId = "pulse_return_runner",
		enabled = true,
	},

	-- Batimento Eclipse — stretch F0; catálogo presente, kill switch ligado
	eclipse_beat = {
		id = "eclipse_beat",
		contentVersion = 1,
		displayNameKey = "ability.eclipse_beat.name",
		descriptionKey = "ability.eclipse_beat.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Ultimate",
		slotCost = 0,
		impactCost = 5,
		tags = { "ultimate" },
		inputMode = "Press",
		startupMs = 400,
		activeMs = 800,
		recoveryMs = 900,
		resourceCost = { amount = 55 },
		cooldown = { baseSeconds = 90 },
		range = 8,
		maxTargets = 1,
		serverRunnerId = "eclipse_beat_runner",
		enabled = false,
	},
}

local AbilityCatalog = {}

function AbilityCatalog.get(abilityId: string): AbilityDefinition?
	return Abilities[abilityId]
end

function AbilityCatalog.all(): { AbilityDefinition }
	local out: { AbilityDefinition } = {}
	for _, def in Abilities do
		table.insert(out, def)
	end
	return out
end

return AbilityCatalog

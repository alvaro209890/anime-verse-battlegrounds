--!strict
-- Habilidades — F0 (docs/05 §5.3)
-- Spec do formato: ver docs/11-ABILITY-SPEC.md
-- TODO: masteryTiers, rangePolicy completo, securityLimits (F2)
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
	-- dash-strike — habilidade de exemplo completa (molde das demais)
	-- codinome interno: yuji dash-strike (soco avançado com timing)
	dash_strike = {
		id = "dash_strike",
		contentVersion = 1,
		displayNameKey = "ability.dash_strike.name",
		descriptionKey = "ability.dash_strike.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 1,
		tags = { "movement", "melee", "cancelable" },
		inputMode = "Press",
		startupMs = 120,
		activeMs = 200,
		recoveryMs = 300,
		resourceCost = { amount = 15 },
		cooldown = { baseSeconds = 4 },
		range = 24,
		maxTargets = 1,
		serverRunnerId = "dash_strike_runner",
		enabled = true,
	},

	-- eclipse_barrier — barreira que nega contato (zoner/controle)
	eclipse_barrier = {
		id = "eclipse_barrier",
		contentVersion = 1,
		displayNameKey = "ability.eclipse_barrier.name",
		descriptionKey = "ability.eclipse_barrier.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 2,
		tags = { "defense", "control", "barrier" },
		inputMode = "Press",
		startupMs = 200,
		activeMs = 1500,
		recoveryMs = 400,
		resourceCost = { amount = 30 },
		cooldown = { baseSeconds = 10 },
		range = 0,
		maxTargets = 0,
		serverRunnerId = "eclipse_barrier_runner",
		enabled = true,
	},

	-- void_rupture — corte à distância (área)
	void_rupture = {
		id = "void_rupture",
		contentVersion = 1,
		displayNameKey = "ability.void_rupture.name",
		descriptionKey = "ability.void_rupture.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Skill",
		slotCost = 1,
		tags = { "projectile", "aoe" },
		inputMode = "Press",
		startupMs = 250,
		activeMs = 400,
		recoveryMs = 500,
		resourceCost = { amount = 25 },
		cooldown = { baseSeconds = 7 },
		range = 60,
		maxTargets = 5,
		serverRunnerId = "void_rupture_runner",
		enabled = true,
	},

	-- eclipse_judgement — ultimate devastadora
	eclipse_judgement = {
		id = "eclipse_judgement",
		contentVersion = 1,
		displayNameKey = "ability.eclipse_judgement.name",
		descriptionKey = "ability.eclipse_judgement.desc",
		sourceCharacterId = "eclipse_fist",
		energyFamilyId = "umbral_aether",
		kind = "Ultimate",
		slotCost = 1,
		tags = { "ultimate", "aoe", "burst" },
		inputMode = "Press",
		startupMs = 400,
		activeMs = 800,
		recoveryMs = 900,
		resourceCost = { amount = 60 },
		cooldown = { baseSeconds = 60 },
		range = 40,
		maxTargets = 10,
		serverRunnerId = "eclipse_judgement_runner",
		enabled = true,
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

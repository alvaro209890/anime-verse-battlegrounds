--!strict
-- Famílias de energia — F0 (docs/05 §2.1, docs/13-F0-SLICE.md §7)
-- Conteúdo dirigido por dados: sistemas nunca fazem `if` por família.
--
-- Tipos declarados inline (export type é compile-time) para manter o módulo
-- carregável em testes Lune (que não resolvem require(script.Parent.X)).
-- Contrato canônico: src/shared/Types.luau.

export type EnergyFamilyDefinition = {
	id: string,
	displayNameKey: string,
	poolBase: number,
	poolCap: number,
	regenInCombatPerSec: number,
	regenOutOfCombatPerSec: number,
	outOfCombatDelaySeconds: number,
	flowTimingWindowMs: number,
	flowGainOnTimedHit: number,
	flowGainCapSeconds: number,
	flowBonusAmount: number,
	flowBonusIntervalSeconds: number,
}

local EnergyFamilies: { [string]: EnergyFamilyDefinition } = {
	-- Éter Umbral — F0-BASELINE (docs/01 §4.2, docs/13 §7)
	umbral_aether = {
		id = "umbral_aether",
		displayNameKey = "family.umbral_aether.name",
		poolBase = 100,
		poolCap = 100,
		regenInCombatPerSec = 2,
		regenOutOfCombatPerSec = 6,
		outOfCombatDelaySeconds = 3,
		flowTimingWindowMs = 120,
		flowGainOnTimedHit = 6,
		flowGainCapSeconds = 1.5,
		flowBonusAmount = 3,
		flowBonusIntervalSeconds = 8,
	},

	-- Fluxo Vital — catálogo F1; não selecionável na fatia
	vital_flow = {
		id = "vital_flow",
		displayNameKey = "family.vital_flow.name",
		poolBase = 150,
		poolCap = 150,
		regenInCombatPerSec = 10,
		regenOutOfCombatPerSec = 14,
		outOfCombatDelaySeconds = 0,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
		flowGainCapSeconds = 0,
		flowBonusAmount = 0,
		flowBonusIntervalSeconds = 0,
	},

	-- Contrafluxo — catálogo F1; não selecionável na fatia
	counterflow = {
		id = "counterflow",
		displayNameKey = "family.counterflow.name",
		poolBase = 100,
		poolCap = 100,
		regenInCombatPerSec = 0,
		regenOutOfCombatPerSec = 0,
		outOfCombatDelaySeconds = 0,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
		flowGainCapSeconds = 0,
		flowBonusAmount = 0,
		flowBonusIntervalSeconds = 0,
	},

	-- Ímpeto Metamórfico — catálogo pós-lançamento; não selecionável na fatia
	metamorphic_drive = {
		id = "metamorphic_drive",
		displayNameKey = "family.metamorphic_drive.name",
		poolBase = 80,
		poolCap = 80,
		regenInCombatPerSec = 0,
		regenOutOfCombatPerSec = 0,
		outOfCombatDelaySeconds = 0,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
		flowGainCapSeconds = 0,
		flowBonusAmount = 0,
		flowBonusIntervalSeconds = 0,
	},
}

local EnergyFamilyCatalog = {}

function EnergyFamilyCatalog.get(familyId: string): EnergyFamilyDefinition?
	return EnergyFamilies[familyId]
end

function EnergyFamilyCatalog.all(): { EnergyFamilyDefinition }
	local out: { EnergyFamilyDefinition } = {}
	for _, def in EnergyFamilies do
		table.insert(out, def)
	end
	return out
end

return EnergyFamilyCatalog

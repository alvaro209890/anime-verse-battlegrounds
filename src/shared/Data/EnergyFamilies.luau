--!strict
-- Famílias de energia — F0 (docs/05 §2.1)
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
	flowTimingWindowMs: number,
	flowGainOnTimedHit: number,
}

local EnergyFamilies: { [string]: EnergyFamilyDefinition } = {
	-- Éter Umbral (inspiração: energia amaldiçoada) — pool menor, regen lenta em
	-- combate e rápida fora. Fluxo: acertar no timing devolve energia (premia
	-- jogador bom, pune spam).
	umbral_aether = {
		id = "umbral_aether",
		displayNameKey = "family.umbral_aether.name",
		poolBase = 100,
		poolCap = 100,
		regenInCombatPerSec = 4,
		regenOutOfCombatPerSec = 18,
		flowTimingWindowMs = 250,
		flowGainOnTimedHit = 8,
	},

	-- Fluxo Vital (inspiração: chakra) — pool grande, regen constante e moderada.
	vital_flow = {
		id = "vital_flow",
		displayNameKey = "family.vital_flow.name",
		poolBase = 150,
		poolCap = 150,
		regenInCombatPerSec = 10,
		regenOutOfCombatPerSec = 14,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
	},

	-- Contrafluxo (inspiração: mana inversa/antimagia) — não regenera; enche ao anular.
	counterflow = {
		id = "counterflow",
		displayNameKey = "family.counterflow.name",
		poolBase = 100,
		poolCap = 100,
		regenInCombatPerSec = 0,
		regenOutOfCombatPerSec = 0,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
	},

	-- Ímpeto Metamórfico (inspiração: vigor/transformação) — drena em transformação.
	metamorphic_drive = {
		id = "metamorphic_drive",
		displayNameKey = "family.metamorphic_drive.name",
		poolBase = 80,
		poolCap = 80,
		regenInCombatPerSec = 0,
		regenOutOfCombatPerSec = 0,
		flowTimingWindowMs = 0,
		flowGainOnTimedHit = 0,
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

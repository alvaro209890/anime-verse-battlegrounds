--!strict
-- Curva de nível da conta e gasto de pontos (docs/01 §7.1, docs/05 §4.1).
--
-- O loop é o do Blox Fruits: cada nível concede 3 pontos, gastos em cinco
-- trilhas. A curva de XP é a documentada na wiki (2 × nível^2,3 + 84). O
-- teto numérico segue o GDD: Impacto e Ressonância não passam de 6%; a
-- progressão geral não é ATK/DEF infinito (GDD-DEC-005/006, §7.1, §9).
--
-- Módulo puro — sem Instances, sem require. Testável no Lune.

export type TrackId = "vitality" | "umbral" | "impact" | "guard" | "resonance"

export type SpentTracks = {
	vitality: number,
	umbral: number,
	impact: number,
	guard: number,
	resonance: number,
}

export type LevelProgress = {
	level: number,
	intoLevel: number,
	toNext: number,
	cumulative: number,
}

export type Vitals = {
	maxHealth: number,
	maxGuard: number,
	maxResource: number,
	-- 0..0.06 — GDD §7.2 teto de bônus numérico.
	damageBonus: number,
	-- 1.0 no piso; 0.94 no teto (Ressonância).
	resourceCostMul: number,
}

export type SpendError = "unknown_track" | "no_points" | "track_cap" | "invalid_amount"

local ProgressionCatalog = {}

ProgressionCatalog.POINTS_PER_LEVEL = 3
ProgressionCatalog.MAX_LEVEL = 100
ProgressionCatalog.BASE_HEALTH = 100
ProgressionCatalog.BASE_GUARD = 100
ProgressionCatalog.BASE_RESOURCE = 100
-- Metade do Blox Fruits (+5): o GDD não quer corrida de atributo, mas o
-- ponto precisa mover a barra o suficiente para o jogador sentir o gasto.
ProgressionCatalog.HP_PER_POINT = 2
ProgressionCatalog.RESOURCE_PER_POINT = 2
ProgressionCatalog.GUARD_PER_POINT = 2
-- 100 pontos × 0,0006 = 6% (GDD-DEC-005).
ProgressionCatalog.DAMAGE_PCT_PER_POINT = 0.0006
ProgressionCatalog.COST_PCT_PER_POINT = 0.0006
ProgressionCatalog.NUMERIC_BONUS_CAP = 0.06

ProgressionCatalog.TRACK_IDS = { "vitality", "umbral", "impact", "guard", "resonance" } :: { TrackId }

local TRACK_SET: { [string]: boolean } = {
	vitality = true,
	umbral = true,
	impact = true,
	guard = true,
	resonance = true,
}

function ProgressionCatalog.emptySpent(): SpentTracks
	return {
		vitality = 0,
		umbral = 0,
		impact = 0,
		guard = 0,
		resonance = 0,
	}
end

function ProgressionCatalog.isTrackId(value: string): boolean
	return TRACK_SET[value] == true
end

-- Blox Fruits wiki: EXP para o próximo nível = 2 × (nível ^ 2,3) + 84.
function ProgressionCatalog.xpToNextLevel(level: number): number
	if level < 1 or level >= ProgressionCatalog.MAX_LEVEL then
		return 0
	end
	return math.floor(2 * (level ^ 2.3) + 84)
end

function ProgressionCatalog.cumulativeXpForLevel(level: number): number
	local total = 0
	local cap = math.clamp(math.floor(level), 1, ProgressionCatalog.MAX_LEVEL)
	for current = 1, cap - 1 do
		total += ProgressionCatalog.xpToNextLevel(current)
	end
	return total
end

function ProgressionCatalog.progressFromXp(xp: number): LevelProgress
	local remaining = math.max(0, math.floor(xp))
	local level = 1
	local spent = 0
	while level < ProgressionCatalog.MAX_LEVEL do
		local need = ProgressionCatalog.xpToNextLevel(level)
		if remaining < need then
			return {
				level = level,
				intoLevel = remaining,
				toNext = need,
				cumulative = spent,
			}
		end
		remaining -= need
		spent += need
		level += 1
	end
	return {
		level = ProgressionCatalog.MAX_LEVEL,
		intoLevel = 0,
		toNext = 0,
		cumulative = spent,
	}
end

function ProgressionCatalog.earnedPoints(level: number): number
	return math.max(0, math.floor(level) - 1) * ProgressionCatalog.POINTS_PER_LEVEL
end

function ProgressionCatalog.spentTotal(spent: SpentTracks): number
	return spent.vitality + spent.umbral + spent.impact + spent.guard + spent.resonance
end

-- Invariante: pontos ganhos no nível = gastos + não gastos. Sem isto o HUD
-- e o respec podem mentir depois de um restore podre.
function ProgressionCatalog.pointsBalance(level: number, spent: SpentTracks, unspent: number): (boolean, string?)
	if type(unspent) ~= "number" or unspent ~= unspent or unspent < 0 or unspent ~= math.floor(unspent) then
		return false, "unspent_invalid"
	end
	local earned = ProgressionCatalog.earnedPoints(level)
	local used = ProgressionCatalog.spentTotal(spent)
	if used < 0 then
		return false, "spent_negative"
	end
	if used + unspent ~= earned then
		return false, "imbalance"
	end
	return true, nil
end

function ProgressionCatalog.maxPointsInTrack(): number
	return ProgressionCatalog.MAX_LEVEL
end

function ProgressionCatalog.canSpend(spent: SpentTracks, unspent: number, trackId: string, amount: number): SpendError?
	if not ProgressionCatalog.isTrackId(trackId) then
		return "unknown_track"
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount ~= math.floor(amount) or amount > 3 then
		return "invalid_amount"
	end
	if unspent < amount then
		return "no_points"
	end
	local current = (spent :: { [string]: number })[trackId] or 0
	if current + amount > ProgressionCatalog.maxPointsInTrack() then
		return "track_cap"
	end
	return nil
end

function ProgressionCatalog.applySpend(spent: SpentTracks, trackId: TrackId, amount: number): SpentTracks
	local nextSpent = {
		vitality = spent.vitality,
		umbral = spent.umbral,
		impact = spent.impact,
		guard = spent.guard,
		resonance = spent.resonance,
	}
	nextSpent[trackId] = nextSpent[trackId] + amount
	return nextSpent
end

function ProgressionCatalog.vitalsFor(spent: SpentTracks): Vitals
	local damageBonus =
		math.min(ProgressionCatalog.NUMERIC_BONUS_CAP, spent.impact * ProgressionCatalog.DAMAGE_PCT_PER_POINT)
	local costCut =
		math.min(ProgressionCatalog.NUMERIC_BONUS_CAP, spent.resonance * ProgressionCatalog.COST_PCT_PER_POINT)
	return {
		maxHealth = ProgressionCatalog.BASE_HEALTH + spent.vitality * ProgressionCatalog.HP_PER_POINT,
		maxGuard = ProgressionCatalog.BASE_GUARD + spent.guard * ProgressionCatalog.GUARD_PER_POINT,
		maxResource = ProgressionCatalog.BASE_RESOURCE + spent.umbral * ProgressionCatalog.RESOURCE_PER_POINT,
		damageBonus = damageBonus,
		resourceCostMul = 1 - costCut,
	}
end

function ProgressionCatalog.scaleDamage(raw: number, damageBonus: number): number
	if raw <= 0 then
		return 0
	end
	if damageBonus <= 0 then
		return raw
	end
	local bonus = math.min(ProgressionCatalog.NUMERIC_BONUS_CAP, damageBonus)
	return math.max(1, math.floor(raw * (1 + bonus) + 0.5))
end

function ProgressionCatalog.scaleResourceCost(raw: number, costMul: number): number
	if raw <= 0 then
		return 0
	end
	local mul = math.clamp(costMul, 1 - ProgressionCatalog.NUMERIC_BONUS_CAP, 1)
	if mul >= 1 then
		return raw
	end
	return math.max(1, math.floor(raw * mul + 0.5))
end

-- Texto da trilha no painel STATUS: impacto/ressonância em % (duas casas);
-- as outras em pontos de barra (+2 por ponto).
function ProgressionCatalog.trackEffectAmount(trackId: string, points: number): number
	local amount = math.max(0, math.floor(points))
	if trackId == "impact" or trackId == "resonance" then
		return math.floor(amount * ProgressionCatalog.DAMAGE_PCT_PER_POINT * 10000 + 0.5) / 100
	end
	return amount * ProgressionCatalog.HP_PER_POINT
end

-- Regeneração automática de vida/guarda/Umbral (docs/01 §7.1.1).
-- Fora de combate preenche a barra; em combate só pinga. O nível da conta
-- acelera o ritmo — não o teto de dano (GDD-DEC-005).
ProgressionCatalog.COMBAT_LINGER_SECONDS = 4
ProgressionCatalog.VITAL_REGEN_DELAY_SECONDS = 3
ProgressionCatalog.HP_REGEN_OUT_BASE = 4
ProgressionCatalog.HP_REGEN_OUT_PER_LEVEL = 0.2
ProgressionCatalog.HP_REGEN_IN_BASE = 0.5
ProgressionCatalog.HP_REGEN_IN_PER_LEVEL = 0.04
ProgressionCatalog.GUARD_REGEN_OUT_BASE = 12
ProgressionCatalog.GUARD_REGEN_OUT_PER_LEVEL = 0.3
ProgressionCatalog.GUARD_REGEN_IN_BASE = 2
ProgressionCatalog.GUARD_REGEN_IN_PER_LEVEL = 0.08
ProgressionCatalog.RESOURCE_REGEN_PER_LEVEL = 0.015

export type RegenRates = {
	healthPerSec: number,
	guardPerSec: number,
	resourceMul: number,
}

function ProgressionCatalog.resourceRegenMul(level: number): number
	local lvl = math.clamp(math.floor(level), 1, ProgressionCatalog.MAX_LEVEL)
	return 1 + (lvl - 1) * ProgressionCatalog.RESOURCE_REGEN_PER_LEVEL
end

function ProgressionCatalog.regenRates(level: number, inCombat: boolean, secondsSinceCombat: number): RegenRates
	local lvl = math.clamp(math.floor(level), 1, ProgressionCatalog.MAX_LEVEL)
	local mul = ProgressionCatalog.resourceRegenMul(lvl)
	if inCombat then
		return {
			healthPerSec = ProgressionCatalog.HP_REGEN_IN_BASE + (lvl - 1) * ProgressionCatalog.HP_REGEN_IN_PER_LEVEL,
			guardPerSec = ProgressionCatalog.GUARD_REGEN_IN_BASE
				+ (lvl - 1) * ProgressionCatalog.GUARD_REGEN_IN_PER_LEVEL,
			resourceMul = mul,
		}
	end
	local since = secondsSinceCombat
	if type(since) ~= "number" or since ~= since or since < 0 then
		since = math.huge
	end
	if since < ProgressionCatalog.VITAL_REGEN_DELAY_SECONDS then
		return {
			healthPerSec = 0,
			guardPerSec = 0,
			resourceMul = mul,
		}
	end
	return {
		healthPerSec = ProgressionCatalog.HP_REGEN_OUT_BASE + (lvl - 1) * ProgressionCatalog.HP_REGEN_OUT_PER_LEVEL,
		guardPerSec = ProgressionCatalog.GUARD_REGEN_OUT_BASE
			+ (lvl - 1) * ProgressionCatalog.GUARD_REGEN_OUT_PER_LEVEL,
		resourceMul = mul,
	}
end

return ProgressionCatalog

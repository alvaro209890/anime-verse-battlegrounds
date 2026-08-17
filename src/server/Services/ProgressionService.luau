--!strict
-- ProgressionService (server) — F0 mínimo (docs/04 §4.1, docs/13-F0-SLICE.md §10, §11.1)
-- Flags de unlock + ledger de XP não consolidado da sessão.
-- Spawn sem técnicas; grant é idempotente.
--
-- FORA deste serviço (item 11 do backlog): consolidação em
-- `anchor_bastion_return`, perda de XP na morte e ProfileStore. O XP aqui vive
-- na sessão e some no leave — nada é persistido ainda.
--
-- Item 11 (2026-08-12): consolidação (move unconsolidated → consolidated com
-- recibo idempotente), perda na morte por zona (docs/13 §11.1) e snapshot
-- para o SaveService (ProfileRoot v1). O relógio é injetável (setNow).
--
-- Puro (sem Instances) — testável.

local ProgressionCatalog
do
	local ok, catalog = pcall(function()
		return require("../../shared/Data/ProgressionCatalog")
	end)
	if ok and type(catalog) == "table" and catalog.progressFromXp then
		ProgressionCatalog = catalog
	else
		ProgressionCatalog = require(game:GetService("ReplicatedStorage").Shared.Data.ProgressionCatalog)
	end
end

local ABILITY_UNLOCK_FLAG: { [string]: string } = {
	comet_shoulder = "unlock_comet_shoulder",
	broken_cadence = "unlock_broken_cadence",
	pulse_return = "unlock_pulse_return",
}

local KNOWN_FLAGS: { [string]: boolean } = {
	unlock_comet_shoulder = true,
	unlock_broken_cadence = true,
	unlock_pulse_return = true,
	quest_hunt_accepted = true,
	quest_elite_accepted = true,
	quest_flow_accepted = true,
	quest_grove_accepted = true,
	quest_remnant_accepted = true,
	unlock_echo_weaver = true,
	ftue_spawned = true,
	ftue_dummy_hit = true,
}

-- Teto de emissão por sessão (docs/13 §11.1).
local SESSION_XP_CAP = 800
-- Perda na morte (docs/13 §11.1): 10% PvE / 15% PvP da não consolidado,
-- cap 200 XP (5 min × 40/min). Segura/treino: 0.
local DEATH_LOSS_PVE_PCT = 0.10
local DEATH_LOSS_PVP_PCT = 0.15
local DEATH_LOSS_CAP = 200

export type SpentTracks = {
	vitality: number,
	umbral: number,
	impact: number,
	guard: number,
	resonance: number,
}

export type XpLedger = {
	unconsolidated: number,
	consolidated: number,
	-- Total já emitido nesta sessão; o teto conta emissão, não saldo.
	emitted: number,
	-- anchorId → kills desta sessão (retorno decrescente por âncora).
	killsByAnchor: { [string]: number },
	-- Última consolidação (docs/13 §11.1); 0 = nunca consolidou na sessão.
	lastConsolidationAt: number,
	-- operationId do último recibo de consolidação (idempotência §11.1).
	lastOperationId: string?,
	-- Nível da conta derivado do XP consolidado (docs/05 §4.1).
	accountLevel: number,
	unspentPoints: number,
	spent: SpentTracks,
}

export type XpAward = {
	granted: number,
	-- Quanto foi recusado por teto de sessão ou retorno decrescente.
	withheld: number,
	reason: string?,
}

local ProgressionService = {
	-- userId → flag → true (durável; entra no ProfileRoot).
	flags = {} :: { [number]: { [string]: boolean } },
	-- Overrides da sessão (ex.: loadout de teste em Studio); nunca persistem.
	sessionFlags = {} :: { [number]: { [string]: boolean } },
	-- userId → ledger
	xp = {} :: { [number]: XpLedger },
	-- userId → npcId → instante do último XP (cooldown por NPC, §9.3)
	lastXpAt = {} :: { [number]: { [string]: number } },
}

-- Relógio injetável (os testes usam o fakeNow; o servidor usa os.clock).
local injectedNow: (() -> number)? = nil

function ProgressionService.setNow(fn: (() -> number)?): ()
	injectedNow = fn
end

local function now(): number
	if injectedNow then
		return injectedNow()
	end
	return os.clock()
end

function ProgressionService.init(): ()
	table.clear(ProgressionService.flags)
	table.clear(ProgressionService.sessionFlags)
	table.clear(ProgressionService.xp)
	table.clear(ProgressionService.lastXpAt)
end

function ProgressionService.registerPlayer(userId: number): ()
	ProgressionService.flags[userId] = {}
	ProgressionService.sessionFlags[userId] = {}
	ProgressionService.xp[userId] = {
		unconsolidated = 0,
		consolidated = 0,
		emitted = 0,
		killsByAnchor = {},
		lastConsolidationAt = 0,
		lastOperationId = nil,
		accountLevel = 1,
		unspentPoints = 0,
		spent = ProgressionCatalog.emptySpent(),
	}
end

function ProgressionService.unregisterPlayer(userId: number): ()
	ProgressionService.flags[userId] = nil
	ProgressionService.sessionFlags[userId] = nil
	ProgressionService.xp[userId] = nil
	ProgressionService.lastXpAt[userId] = nil
end

function ProgressionService.hasUnlock(userId: number, flag: string): boolean
	local userFlags = ProgressionService.flags[userId]
	local sessionFlags = ProgressionService.sessionFlags[userId]
	return (userFlags ~= nil and userFlags[flag] == true) or (sessionFlags ~= nil and sessionFlags[flag] == true)
end

-- Concede a flag. Retorna true só na primeira vez (idempotente).
function ProgressionService.grantUnlock(userId: number, flag: string): boolean
	if not KNOWN_FLAGS[flag] then
		return false
	end
	local userFlags = ProgressionService.flags[userId]
	if not userFlags then
		return false
	end
	if userFlags[flag] then
		return false
	end
	userFlags[flag] = true
	return true
end

-- Concede um override não durável. Usado apenas pelo gate StudioDebug; a
-- mesma flag pode existir depois no progresso real sem ser contaminada pelo
-- playtest. Retorna true só na primeira concessão efetiva da sessão.
function ProgressionService.grantSessionUnlock(userId: number, flag: string): boolean
	if not KNOWN_FLAGS[flag] then
		return false
	end
	local sessionFlags = ProgressionService.sessionFlags[userId]
	if not sessionFlags or ProgressionService.hasUnlock(userId, flag) then
		return false
	end
	sessionFlags[flag] = true
	return true
end

function ProgressionService.listUnlocks(userId: number): { string }
	local userFlags = ProgressionService.flags[userId]
	local sessionFlags = ProgressionService.sessionFlags[userId]
	local out: { string } = {}
	if not userFlags and not sessionFlags then
		return out
	end
	local seen: { [string]: boolean } = {}
	if userFlags then
		for flag in userFlags do
			seen[flag] = true
		end
	end
	if sessionFlags then
		for flag in sessionFlags do
			seen[flag] = true
		end
	end
	for flag in seen do
		table.insert(out, flag)
	end
	table.sort(out)
	return out
end

function ProgressionService.listPersistentUnlocks(userId: number): { string }
	local userFlags = ProgressionService.flags[userId]
	local out: { string } = {}
	if not userFlags then
		return out
	end
	for flag in userFlags do
		table.insert(out, flag)
	end
	table.sort(out)
	return out
end

function ProgressionService.isAbilityUnlocked(userId: number, abilityId: string): boolean
	local flag = ABILITY_UNLOCK_FLAG[abilityId]
	if not flag then
		return false
	end
	return ProgressionService.hasUnlock(userId, flag)
end

-- ── XP ─────────────────────────────────────────────────────────────────────

function ProgressionService.getLedger(userId: number): XpLedger?
	return ProgressionService.xp[userId]
end

function ProgressionService.getUnconsolidatedXp(userId: number): number
	local ledger = ProgressionService.xp[userId]
	return if ledger then ledger.unconsolidated else 0
end

-- Emite XP não consolidado respeitando o teto de sessão. Valor negativo ou
-- jogador desconhecido não credita nada.
function ProgressionService.awardXp(userId: number, amount: number): XpAward
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return { granted = 0, withheld = 0, reason = "unknown_player" }
	end
	if amount <= 0 then
		return { granted = 0, withheld = 0, reason = "invalid_amount" }
	end
	local room = SESSION_XP_CAP - ledger.emitted
	if room <= 0 then
		return { granted = 0, withheld = amount, reason = "session_cap" }
	end
	local granted = math.min(amount, room)
	ledger.emitted += granted
	ledger.unconsolidated += granted
	local withheld = amount - granted
	return {
		granted = granted,
		withheld = withheld,
		reason = if withheld > 0 then "session_cap" else nil,
	}
end

-- XP de um kill, aplicando o retorno decrescente por âncora antes do teto.
-- `npcDef` vem do catálogo; `anchorId` identifica o ponto de spawn.
-- Cooldown por NPC (`npcDef.xpCooldownSeconds`, §9.3): o elite paga 80 XP
-- uma vez por 3 min por jogador — dentro do cooldown, recusa "xp_cooldown".
function ProgressionService.creditNpcKill(userId: number, npcDef: any, anchorId: string): XpAward
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return { granted = 0, withheld = 0, reason = "unknown_player" }
	end
	if not npcDef or not npcDef.grantsXp then
		return { granted = 0, withheld = 0, reason = "no_xp_source" }
	end
	local base = npcDef.xpUnconsolidated or 0
	if base <= 0 then
		return { granted = 0, withheld = 0, reason = "no_xp_source" }
	end

	-- Cooldown por NPC (elite §9.3): uma vez por xpCooldownSeconds por jogador.
	local cooldown = npcDef.xpCooldownSeconds
	if cooldown and cooldown > 0 then
		local last = (ProgressionService.lastXpAt[userId] or {})[npcDef.id]
		if last and (now() - last) < cooldown then
			return { granted = 0, withheld = base, reason = "xp_cooldown" }
		end
	end

	local kills = (ledger.killsByAnchor[anchorId] or 0) + 1
	ledger.killsByAnchor[anchorId] = kills

	local value = base
	local fullKills = npcDef.xpFullKills
	if fullKills and kills > fullKills then
		local reducedKills = npcDef.xpReducedKills or 0
		if kills <= fullKills + reducedKills then
			value = npcDef.xpReducedValue or 0
		else
			value = 0
		end
	end

	if value <= 0 then
		return { granted = 0, withheld = base, reason = "diminished" }
	end
	local award = ProgressionService.awardXp(userId, value)
	if award.granted < base then
		award.withheld = base - award.granted
		award.reason = award.reason or "diminished"
	end
	-- Marca o cooldown só quando o XP saiu (elite com cooldown).
	if cooldown and cooldown > 0 and award.granted > 0 then
		local userTimes = ProgressionService.lastXpAt[userId]
		if not userTimes then
			userTimes = {}
			ProgressionService.lastXpAt[userId] = userTimes
		end
		userTimes[npcDef.id] = now()
	end
	return award
end

-- Kills desta sessão na âncora (telemetria e testes).
function ProgressionService.getAnchorKills(userId: number, anchorId: string): number
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return 0
	end
	return ledger.killsByAnchor[anchorId] or 0
end

function ProgressionService.sessionXpCap(): number
	return SESSION_XP_CAP
end

local function syncLevel(ledger: XpLedger): number
	local progress = ProgressionCatalog.progressFromXp(ledger.consolidated)
	local gained = progress.level - ledger.accountLevel
	if gained > 0 then
		ledger.unspentPoints += gained * ProgressionCatalog.POINTS_PER_LEVEL
		ledger.accountLevel = progress.level
		return gained
	end
	if ledger.accountLevel < 1 then
		ledger.accountLevel = 1
	end
	return 0
end

local function reconcilePoints(ledger: XpLedger): ()
	local earned = ProgressionCatalog.earnedPoints(ledger.accountLevel)
	local spent = ProgressionCatalog.spentTotal(ledger.spent)
	if spent > earned then
		ledger.spent = ProgressionCatalog.emptySpent()
		ledger.unspentPoints = earned
		return
	end
	ledger.unspentPoints = earned - spent
end

export type ProgressionView = {
	accountLevel: number,
	consolidatedXp: number,
	unconsolidatedXp: number,
	xpIntoLevel: number,
	xpToNext: number,
	previewLevel: number,
	pendingLevels: number,
	unspentPoints: number,
	spent: SpentTracks,
	vitals: {
		maxHealth: number,
		maxGuard: number,
		maxResource: number,
		damageBonus: number,
		resourceCostMul: number,
	},
}

function ProgressionService.viewFor(userId: number): ProgressionView?
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return nil
	end
	local banked = ProgressionCatalog.progressFromXp(ledger.consolidated)
	local preview = ProgressionCatalog.progressFromXp(ledger.consolidated + ledger.unconsolidated)
	local pending = math.max(0, preview.level - ledger.accountLevel)
	-- A barra mostra o XP do campo enchendo o próximo nível (feel Blox Fruits);
	-- os pontos só caem na consolidação.
	local visualInto = banked.intoLevel + ledger.unconsolidated
	if banked.toNext > 0 then
		visualInto = math.min(visualInto, banked.toNext)
	end
	if pending > 0 and banked.toNext > 0 then
		visualInto = banked.toNext
	end
	return {
		accountLevel = ledger.accountLevel,
		consolidatedXp = ledger.consolidated,
		unconsolidatedXp = ledger.unconsolidated,
		xpIntoLevel = visualInto,
		xpToNext = banked.toNext,
		previewLevel = preview.level,
		pendingLevels = pending,
		unspentPoints = ledger.unspentPoints,
		spent = {
			vitality = ledger.spent.vitality,
			umbral = ledger.spent.umbral,
			impact = ledger.spent.impact,
			guard = ledger.spent.guard,
			resonance = ledger.spent.resonance,
		},
		vitals = ProgressionCatalog.vitalsFor(ledger.spent),
	}
end

export type SpendResult = {
	ok: boolean,
	reason: string?,
	spent: SpentTracks?,
	unspentPoints: number?,
	vitals: {
		maxHealth: number,
		maxGuard: number,
		maxResource: number,
		damageBonus: number,
		resourceCostMul: number,
	}?,
}

function ProgressionService.spendPoints(userId: number, trackId: string, amount: number): SpendResult
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return { ok = false, reason = "unknown_player" }
	end
	local err = ProgressionCatalog.canSpend(ledger.spent, ledger.unspentPoints, trackId, amount)
	if err then
		return { ok = false, reason = err }
	end
	ledger.spent = ProgressionCatalog.applySpend(ledger.spent, trackId :: any, amount)
	ledger.unspentPoints -= amount
	return {
		ok = true,
		spent = ledger.spent,
		unspentPoints = ledger.unspentPoints,
		vitals = ProgressionCatalog.vitalsFor(ledger.spent),
	}
end

function ProgressionService.respecPoints(userId: number, inSafeZone: boolean): SpendResult
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return { ok = false, reason = "unknown_player" }
	end
	if not inSafeZone then
		return { ok = false, reason = "not_safe" }
	end
	local returned = ProgressionCatalog.spentTotal(ledger.spent)
	ledger.spent = ProgressionCatalog.emptySpent()
	ledger.unspentPoints += returned
	return {
		ok = true,
		spent = ledger.spent,
		unspentPoints = ledger.unspentPoints,
		vitals = ProgressionCatalog.vitalsFor(ledger.spent),
	}
end

function ProgressionService.resourceCostMul(userId: number): number
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return 1
	end
	return ProgressionCatalog.vitalsFor(ledger.spent).resourceCostMul
end

function ProgressionService.damageBonus(userId: number): number
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return 0
	end
	return ProgressionCatalog.vitalsFor(ledger.spent).damageBonus
end

-- ── Consolidação e morte (docs/13 §11.1) ───────────────────────────────────

export type ConsolidationReceipt = {
	operationId: string,
	consolidated: number,
	-- Saldo não consolidado restante (sempre 0 — consolida tudo).
	unconsolidatedAfter: number,
	at: number,
	levelsGained: number?,
	pointsGranted: number?,
	accountLevel: number?,
}

-- Consolida todo o XP não consolidado (interagir 1,5 s com
-- `anchor_bastion_return` fora de combate — o hold é validação do chamador).
-- Retorna recibo com `operationId` idempotente: repetir a mesma operação não
-- move nada de novo.
function ProgressionService.consolidate(userId: number, at: number): ConsolidationReceipt?
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return nil
	end
	if ledger.unconsolidated <= 0 then
		return {
			operationId = ("cons_%d_%d"):format(userId, at),
			consolidated = 0,
			unconsolidatedAfter = 0,
			at = at,
			levelsGained = 0,
			pointsGranted = 0,
			accountLevel = ledger.accountLevel,
		}
	end
	ledger.consolidated += ledger.unconsolidated
	ledger.lastConsolidationAt = at
	ledger.lastOperationId = ("cons_%d_%d"):format(userId, at)
	local moved = ledger.unconsolidated
	ledger.unconsolidated = 0
	local levelsGained = syncLevel(ledger)
	return {
		operationId = ledger.lastOperationId,
		consolidated = moved,
		unconsolidatedAfter = 0,
		at = at,
		levelsGained = levelsGained,
		pointsGranted = levelsGained * ProgressionCatalog.POINTS_PER_LEVEL,
		accountLevel = ledger.accountLevel,
	}
end

export type DeathPenalty = {
	lost: number,
	reason: string?,
	-- cap aplicado (200) ou nil se não houve perda.
	capped: boolean?,
}

-- Perda de XP na morte (docs/13 §11.1, Q-018 — sem materiais na fatia):
-- segura/treino 0; livre PvE 10% do não consolidado; livre PvP 15%; cap 200.
-- O XP perdido sai da economia — não vai ao agressor.
function ProgressionService.applyDeathPenalty(userId: number, zoneKind: string, pvp: boolean): DeathPenalty
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return { lost = 0, reason = "unknown_player" }
	end
	if zoneKind == "safe" or zoneKind == "transition" then
		return { lost = 0, reason = "safe_zone" }
	end
	local pct = if pvp then DEATH_LOSS_PVP_PCT else DEATH_LOSS_PVE_PCT
	local raw = math.floor(ledger.unconsolidated * pct)
	local lost = math.min(raw, DEATH_LOSS_CAP)
	if lost <= 0 then
		return { lost = 0, reason = "nothing_to_lose" }
	end
	ledger.unconsolidated -= lost
	return { lost = lost, capped = raw > DEATH_LOSS_CAP }
end

-- ── Snapshot para o SaveService (ProfileRoot v1, docs/05 §4) ───────────────

export type ProgressionSnapshot = {
	consolidatedXp: number,
	unconsolidatedXp: number,
	lastConsolidationAt: number,
	tutorialFlags: { string },
	-- Habilidades desbloqueadas (abilities.{id}.unlockedAt no perfil).
	unlockedAbilities: { string },
	accountLevel: number?,
	unspentProgressionPoints: number?,
	spentTracks: SpentTracks?,
}

-- O que o perfil persiste. Sessão (emitted/killsByAnchor/combate) não entra:
-- "combate não persiste" (docs/13 §11.2).
function ProgressionService.snapshotForSave(userId: number): ProgressionSnapshot?
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return nil
	end
	local unlocked: { string } = {}
	local persistentFlags = ProgressionService.flags[userId]
	for abilityId in ABILITY_UNLOCK_FLAG do
		local flag = ABILITY_UNLOCK_FLAG[abilityId]
		if persistentFlags and persistentFlags[flag] then
			table.insert(unlocked, abilityId)
		end
	end
	table.sort(unlocked)
	return {
		consolidatedXp = ledger.consolidated,
		unconsolidatedXp = ledger.unconsolidated,
		lastConsolidationAt = ledger.lastConsolidationAt,
		tutorialFlags = ProgressionService.listPersistentUnlocks(userId),
		unlockedAbilities = unlocked,
		accountLevel = ledger.accountLevel,
		unspentProgressionPoints = ledger.unspentPoints,
		spentTracks = {
			vitality = ledger.spent.vitality,
			umbral = ledger.spent.umbral,
			impact = ledger.spent.impact,
			guard = ledger.spent.guard,
			resonance = ledger.spent.resonance,
		},
	}
end

-- Restaura o perfil salvo na sessão (rejoin no mesmo servidor, §11.2 item 3).
-- Só aplica o que é durável; o teto de emissão da sessão recomeça do zero.
function ProgressionService.restoreFromSave(userId: number, snapshot: ProgressionSnapshot): ()
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return
	end
	ledger.consolidated = snapshot.consolidatedXp or 0
	ledger.unconsolidated = snapshot.unconsolidatedXp or 0
	ledger.lastConsolidationAt = snapshot.lastConsolidationAt or 0
	ledger.emitted = 0
	ledger.killsByAnchor = {}
	local spent = ProgressionCatalog.emptySpent()
	local savedSpent = snapshot.spentTracks
	if type(savedSpent) == "table" then
		for _, trackId in ProgressionCatalog.TRACK_IDS do
			local value = (savedSpent :: { [string]: any })[trackId]
			if type(value) == "number" and value == value and value >= 0 then
				spent[trackId] = math.floor(value)
			end
		end
	end
	ledger.spent = spent
	syncLevel(ledger)
	if type(snapshot.unspentProgressionPoints) == "number" and snapshot.unspentProgressionPoints >= 0 then
		ledger.unspentPoints = math.floor(snapshot.unspentProgressionPoints)
	end
	reconcilePoints(ledger)
	for _, flag in (snapshot.tutorialFlags or {}) do
		if KNOWN_FLAGS[flag] then
			ProgressionService.grantUnlock(userId, flag)
		end
	end
	for _, abilityId in (snapshot.unlockedAbilities or {}) do
		local flag = ABILITY_UNLOCK_FLAG[abilityId]
		if flag then
			ProgressionService.grantUnlock(userId, flag)
		end
	end
end

return ProgressionService

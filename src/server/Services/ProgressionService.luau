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
}

export type XpAward = {
	granted: number,
	-- Quanto foi recusado por teto de sessão ou retorno decrescente.
	withheld: number,
	reason: string?,
}

local ProgressionService = {
	-- userId → flag → true
	flags = {} :: { [number]: { [string]: boolean } },
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
	table.clear(ProgressionService.xp)
	table.clear(ProgressionService.lastXpAt)
end

function ProgressionService.registerPlayer(userId: number): ()
	ProgressionService.flags[userId] = {}
	ProgressionService.xp[userId] = {
		unconsolidated = 0,
		consolidated = 0,
		emitted = 0,
		killsByAnchor = {},
		lastConsolidationAt = 0,
		lastOperationId = nil,
	}
end

function ProgressionService.unregisterPlayer(userId: number): ()
	ProgressionService.flags[userId] = nil
	ProgressionService.xp[userId] = nil
	ProgressionService.lastXpAt[userId] = nil
end

function ProgressionService.hasUnlock(userId: number, flag: string): boolean
	local userFlags = ProgressionService.flags[userId]
	return userFlags ~= nil and userFlags[flag] == true
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

function ProgressionService.listUnlocks(userId: number): { string }
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

-- ── Consolidação e morte (docs/13 §11.1) ───────────────────────────────────

export type ConsolidationReceipt = {
	operationId: string,
	consolidated: number,
	-- Saldo não consolidado restante (sempre 0 — consolida tudo).
	unconsolidatedAfter: number,
	at: number,
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
		}
	end
	ledger.consolidated += ledger.unconsolidated
	ledger.lastConsolidationAt = at
	ledger.lastOperationId = ("cons_%d_%d"):format(userId, at)
	local moved = ledger.unconsolidated
	ledger.unconsolidated = 0
	return {
		operationId = ledger.lastOperationId,
		consolidated = moved,
		unconsolidatedAfter = 0,
		at = at,
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
}

-- O que o perfil persiste. Sessão (emitted/killsByAnchor/combate) não entra:
-- "combate não persiste" (docs/13 §11.2).
function ProgressionService.snapshotForSave(userId: number): ProgressionSnapshot?
	local ledger = ProgressionService.xp[userId]
	if not ledger then
		return nil
	end
	local unlocked: { string } = {}
	for abilityId in ABILITY_UNLOCK_FLAG do
		if ProgressionService.hasUnlock(userId, ABILITY_UNLOCK_FLAG[abilityId]) then
			table.insert(unlocked, abilityId)
		end
	end
	table.sort(unlocked)
	return {
		consolidatedXp = ledger.consolidated,
		unconsolidatedXp = ledger.unconsolidated,
		lastConsolidationAt = ledger.lastConsolidationAt,
		tutorialFlags = ProgressionService.listUnlocks(userId),
		unlockedAbilities = unlocked,
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

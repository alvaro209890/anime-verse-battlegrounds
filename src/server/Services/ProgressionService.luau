--!strict
-- ProgressionService (server) — F0 mínimo (docs/04 §4.1, docs/13-F0-SLICE.md §10, §11.1)
-- Flags de unlock + ledger de XP não consolidado da sessão.
-- Spawn sem técnicas; grant é idempotente.
--
-- FORA deste serviço (item 11 do backlog): consolidação em
-- `anchor_bastion_return`, perda de XP na morte e ProfileStore. O XP aqui vive
-- na sessão e some no leave — nada é persistido ainda.
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

export type XpLedger = {
	unconsolidated: number,
	consolidated: number,
	-- Total já emitido nesta sessão; o teto conta emissão, não saldo.
	emitted: number,
	-- anchorId → kills desta sessão (retorno decrescente por âncora).
	killsByAnchor: { [string]: number },
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

return ProgressionService

--!strict
-- ProgressionService (server) — F0 mínimo (docs/04 §4.1, docs/13-F0-SLICE.md §10)
-- Flags de unlock da fatia. Spawn sem técnicas; grant é idempotente.
-- XP, objetivo 1 e Estilhaços entram no restante do item 7. Sem ProfileStore.
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
}

local ProgressionService = {
	-- userId → flag → true
	flags = {} :: { [number]: { [string]: boolean } },
}

function ProgressionService.init(): ()
	table.clear(ProgressionService.flags)
end

function ProgressionService.registerPlayer(userId: number): ()
	ProgressionService.flags[userId] = {}
end

function ProgressionService.unregisterPlayer(userId: number): ()
	ProgressionService.flags[userId] = nil
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

return ProgressionService

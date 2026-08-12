--!strict
-- CooldownService (server) — F0
-- Cooldowns por habilidade, autoridade do servidor.
-- Puro (sem Instances) — testável.
-- TODO F1: cooldowns por grupo e por personagem.

local CooldownService = {}

-- userId → abilityId → timestamp (os.clock) em que libera
local readyAt: { [number]: { [string]: number } } = {}

function CooldownService.getRemaining(playerUserId: number, abilityId: string): number
	local now = os.clock()
	local userCd = readyAt[playerUserId]
	if not userCd then
		return 0
	end
	local releaseAt = userCd[abilityId]
	if not releaseAt then
		return 0
	end
	return math.max(0, releaseAt - now)
end

function CooldownService.start(playerUserId: number, abilityId: string, seconds: number): ()
	if seconds <= 0 then
		return
	end
	local userCd = readyAt[playerUserId]
	if not userCd then
		userCd = {}
		readyAt[playerUserId] = userCd
	end
	userCd[abilityId] = os.clock() + seconds
end

function CooldownService.clear(playerUserId: number): ()
	readyAt[playerUserId] = nil
end

return CooldownService

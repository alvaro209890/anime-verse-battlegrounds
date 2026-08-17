--!strict
-- CareerService (server) — totais de perfil estilo Anime Fighters.
-- Só o servidor incrementa. O cliente recebe a réplica e não inventa número.
-- Dummy de treino NÃO conta como monstro (docs/13). Puro — testável no Lune.

export type CareerTotals = {
	monsterKills: number,
	bossKills: number,
	damageDealt: number,
	playTimeSeconds: number,
	deaths: number,
	techniquesUsed: number,
	consolidations: number,
	questsCompleted: number,
}

local CareerService = {
	totals = {} :: { [number]: CareerTotals },
	sessionStartedAt = {} :: { [number]: number },
	-- Bootstrap liga a SaveService.markDirty. Sem isso, leave/autosave
	-- perdem dano, técnicas, tempo e quedas se ninguém mais sujou o perfil.
	onPersist = nil :: ((number) -> ())?,
}

local function empty(): CareerTotals
	return {
		monsterKills = 0,
		bossKills = 0,
		damageDealt = 0,
		playTimeSeconds = 0,
		deaths = 0,
		techniquesUsed = 0,
		consolidations = 0,
		questsCompleted = 0,
	}
end

function CareerService.init(): ()
	table.clear(CareerService.totals)
	table.clear(CareerService.sessionStartedAt)
	CareerService.onPersist = nil
end

local function persist(userId: number): ()
	local hook = CareerService.onPersist
	if type(hook) == "function" then
		hook(userId)
	end
end

function CareerService.registerPlayer(userId: number, now: number): ()
	if not CareerService.totals[userId] then
		CareerService.totals[userId] = empty()
	end
	CareerService.sessionStartedAt[userId] = now
end

function CareerService.unregisterPlayer(userId: number, now: number): ()
	CareerService.flushPlayTime(userId, now)
	CareerService.totals[userId] = nil
	CareerService.sessionStartedAt[userId] = nil
end

function CareerService.flushPlayTime(userId: number, now: number): ()
	local started = CareerService.sessionStartedAt[userId]
	local totals = CareerService.totals[userId]
	if not started or not totals then
		return
	end
	local elapsed = now - started
	if elapsed > 0 then
		totals.playTimeSeconds += elapsed
		persist(userId)
	end
	CareerService.sessionStartedAt[userId] = now
end

function CareerService.viewFor(userId: number, now: number): CareerTotals?
	local totals = CareerService.totals[userId]
	if not totals then
		return nil
	end
	local started = CareerService.sessionStartedAt[userId] or now
	local live = math.max(0, now - started)
	return {
		monsterKills = totals.monsterKills,
		bossKills = totals.bossKills,
		damageDealt = totals.damageDealt,
		playTimeSeconds = math.floor(totals.playTimeSeconds + live),
		deaths = totals.deaths,
		techniquesUsed = totals.techniquesUsed,
		consolidations = totals.consolidations,
		questsCompleted = totals.questsCompleted,
	}
end

function CareerService.creditKill(userId: number, npcId: string, isBoss: boolean): ()
	local totals = CareerService.totals[userId]
	if not totals then
		return
	end
	if npcId == "npc_training_dummy" or npcId == "npc_threshold_instructor" then
		return
	end
	if isBoss then
		totals.bossKills += 1
	else
		totals.monsterKills += 1
	end
	persist(userId)
end

function CareerService.creditDamage(userId: number, amount: number): ()
	local totals = CareerService.totals[userId]
	if not totals or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	totals.damageDealt += math.floor(amount)
	persist(userId)
end

function CareerService.creditFromFighterId(fighterId: string, amount: number): ()
	local userIdText = string.match(fighterId, "^player:(%d+)$")
	if not userIdText then
		return
	end
	local userId = tonumber(userIdText)
	if userId then
		CareerService.creditDamage(userId, amount)
	end
end

function CareerService.creditDeath(userId: number): ()
	local totals = CareerService.totals[userId]
	if totals then
		totals.deaths += 1
		persist(userId)
	end
end

function CareerService.creditTechnique(userId: number): ()
	local totals = CareerService.totals[userId]
	if totals then
		totals.techniquesUsed += 1
		persist(userId)
	end
end

function CareerService.creditConsolidation(userId: number): ()
	local totals = CareerService.totals[userId]
	if totals then
		totals.consolidations += 1
		persist(userId)
	end
end

function CareerService.creditQuest(userId: number): ()
	local totals = CareerService.totals[userId]
	if totals then
		totals.questsCompleted += 1
		persist(userId)
	end
end

function CareerService.snapshot(userId: number, now: number): CareerTotals?
	CareerService.flushPlayTime(userId, now)
	local totals = CareerService.totals[userId]
	if not totals then
		return nil
	end
	return {
		monsterKills = totals.monsterKills,
		bossKills = totals.bossKills,
		damageDealt = totals.damageDealt,
		playTimeSeconds = math.floor(totals.playTimeSeconds),
		deaths = totals.deaths,
		techniquesUsed = totals.techniquesUsed,
		consolidations = totals.consolidations,
		questsCompleted = totals.questsCompleted,
	}
end

function CareerService.formatPlayTime(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	if hours > 0 then
		return ("%dh %02dm"):format(hours, minutes)
	end
	if minutes > 0 then
		return ("%dm %02ds"):format(minutes, secs)
	end
	return ("%ds"):format(secs)
end

function CareerService.restore(userId: number, snapshot: any, now: number): ()
	CareerService.registerPlayer(userId, now)
	local totals = CareerService.totals[userId]
	if not totals or type(snapshot) ~= "table" then
		return
	end
	local function take(key: string): number
		local value = snapshot[key]
		if type(value) == "number" and value == value and value >= 0 then
			return math.floor(value)
		end
		return 0
	end
	totals.monsterKills = take("monsterKills")
	totals.bossKills = take("bossKills")
	totals.damageDealt = take("damageDealt")
	totals.playTimeSeconds = take("playTimeSeconds")
	totals.deaths = take("deaths")
	totals.techniquesUsed = take("techniquesUsed")
	totals.consolidations = take("consolidations")
	totals.questsCompleted = take("questsCompleted")
end

return CareerService

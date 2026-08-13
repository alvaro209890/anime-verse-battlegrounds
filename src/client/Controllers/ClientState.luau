--!strict
-- Estado de apresentação do cliente. Só recebe snapshot/deltas autoritativos;
-- nenhuma fórmula de combate, custo ou distância vive aqui.

export type Model = {
	ready: boolean,
	locale: string,
	platform: "KeyboardMouse" | "Touch" | "Gamepad",
	characterId: string,
	health: number,
	maxHealth: number,
	guard: number,
	maxGuard: number,
	resource: number,
	maxResource: number,
	depleted: boolean,
	zoneId: string,
	pvp: boolean,
	zoneHoldRequired: boolean,
	pendingZoneId: string?,
	unlocks: { [string]: boolean },
	objective: { [string]: any }?,
	unconsolidatedXp: number,
	deathPenalty: number,
	cooldowns: { [string]: { startedAt: number, duration: number } },
	feedbackKey: string?,
	feedbackUntil: number,
	now: () -> number,
	listeners: { (Model) -> () },
}

local ClientState = {}

local function numberOr(value: any, fallback: number): number
	return if type(value) == "number" then value else fallback
end

local function rebuildUnlocks(values: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(values) == "table" then
		for _, value in values do
			if type(value) == "string" then
				out[value] = true
			end
		end
	end
	return out
end

function ClientState.new(now: (() -> number)?): Model
	return {
		ready = false,
		locale = "pt-br",
		platform = "KeyboardMouse",
		characterId = "",
		health = 0,
		maxHealth = 100,
		guard = 0,
		maxGuard = 100,
		resource = 0,
		maxResource = 100,
		depleted = false,
		zoneId = "",
		pvp = false,
		zoneHoldRequired = false,
		pendingZoneId = nil,
		unlocks = {},
		objective = nil,
		unconsolidatedXp = 0,
		deathPenalty = 0,
		cooldowns = {},
		feedbackKey = nil,
		feedbackUntil = 0,
		now = now or os.clock,
		listeners = {},
	}
end

function ClientState.subscribe(model: Model, listener: (Model) -> ()): () -> ()
	table.insert(model.listeners, listener)
	return function()
		local index = table.find(model.listeners, listener)
		if index then
			table.remove(model.listeners, index)
		end
	end
end

function ClientState.notify(model: Model): ()
	for _, listener in model.listeners do
		listener(model)
	end
end

function ClientState.applySnapshot(model: Model, payload: { [string]: any }): boolean
	if payload.ready ~= true then
		return false
	end
	model.ready = true
	model.locale = if payload.locale == "en" then "en" else "pt-br"
	model.characterId = if type(payload.characterId) == "string" then payload.characterId else model.characterId
	model.health = numberOr(payload.health, model.health)
	model.maxHealth = numberOr(payload.maxHealth, model.maxHealth)
	model.guard = numberOr(payload.guard, model.guard)
	model.maxGuard = numberOr(payload.maxGuard, model.maxGuard)
	model.resource = numberOr(payload.resource, model.resource)
	model.maxResource = numberOr(payload.maxResource, model.maxResource)
	model.depleted = model.resource <= 0
	model.zoneId = if type(payload.zoneId) == "string" then payload.zoneId else model.zoneId
	model.pvp = payload.pvp == true
	model.unlocks = rebuildUnlocks(payload.unlocks)
	model.objective = if type(payload.objective) == "table" then payload.objective else nil
	model.unconsolidatedXp = numberOr(payload.unconsolidatedXp, model.unconsolidatedXp)
	ClientState.notify(model)
	return true
end

function ClientState.applyDelta(model: Model, payload: { [string]: any }): boolean
	if not model.ready then
		return false
	end
	model.health = numberOr(payload.health, model.health)
	model.maxHealth = numberOr(payload.maxHealth, model.maxHealth)
	model.guard = numberOr(payload.guard, model.guard)
	model.maxGuard = numberOr(payload.maxGuard, model.maxGuard)
	model.resource = numberOr(payload.resource, model.resource)
	model.maxResource = numberOr(payload.maxResource, model.maxResource)
	model.depleted = model.resource <= 0
	if payload.unlocks ~= nil then
		model.unlocks = rebuildUnlocks(payload.unlocks)
	end
	if payload.objective ~= nil then
		model.objective = if type(payload.objective) == "table" and payload.objective.state ~= "completed"
			then payload.objective
			else nil
	end
	model.unconsolidatedXp = numberOr(payload.unconsolidatedXp, model.unconsolidatedXp)
	model.deathPenalty = numberOr(payload.deathPenalty, model.deathPenalty)
	if type(payload.cooldowns) == "table" then
		for abilityId, remaining in payload.cooldowns do
			if type(abilityId) == "string" and type(remaining) == "number" then
				ClientState.setCooldown(model, abilityId, remaining)
			end
		end
	end
	ClientState.notify(model)
	return true
end

function ClientState.setResource(model: Model, current: number, max: number, depleted: boolean): ()
	if not model.ready then
		return
	end
	model.resource = current
	model.maxResource = max
	model.depleted = depleted or current <= 0
	ClientState.notify(model)
end

function ClientState.setZone(model: Model, zoneId: string, pvp: boolean): ()
	if not model.ready then
		return
	end
	model.zoneId = zoneId
	model.pvp = pvp
	ClientState.notify(model)
end

function ClientState.setCooldown(model: Model, abilityId: string, duration: number): ()
	if duration <= 0 then
		model.cooldowns[abilityId] = nil
		return
	end
	model.cooldowns[abilityId] = {
		startedAt = model.now(),
		duration = duration,
	}
end

function ClientState.cooldownRemaining(model: Model, abilityId: string): number
	local cooldown = model.cooldowns[abilityId]
	if not cooldown then
		return 0
	end
	return math.max(0, cooldown.duration - (model.now() - cooldown.startedAt))
end

function ClientState.setFeedback(model: Model, key: string, duration: number): ()
	model.feedbackKey = key
	model.feedbackUntil = model.now() + duration
	ClientState.notify(model)
end

function ClientState.feedback(model: Model): string?
	if model.feedbackKey and model.now() <= model.feedbackUntil then
		return model.feedbackKey
	end
	model.feedbackKey = nil
	return nil
end

return ClientState

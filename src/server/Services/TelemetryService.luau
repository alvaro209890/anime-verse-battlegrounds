--!strict
-- Telemetria mínima F0 (docs/13 §15). Só aceita eventos e campos declarados;
-- payload bruto, chat, IP e campos arbitrários nunca chegam ao sink.

export type Event = {
	eventName: string,
	sessionId: string,
	releaseId: string,
	userId: number,
	recordedAt: number,
	fields: { [string]: string | number | boolean },
}

export type Deps = {
	sessionId: string,
	releaseId: string,
	now: (() -> number)?,
	emit: ((Event) -> ())?,
	bufferCapacity: number?,
}

local FIELD_SCHEMAS: { [string]: { [string]: string } } = {
	SessionLoad = { durationMs = "number", schemaFrom = "number", schemaTo = "number", result = "string" },
	FtueBeat = { flag = "string", elapsedMs = "number" },
	AbilityResolved = { abilityId = "string", result = "string", latencyMs = "number", flowGranted = "number" },
	KillResolved = { zoneId = "string", combatType = "string", powerDelta = "number", xpLost = "number" },
	SaveAttempt = { dirty = "boolean", bytes = "number", result = "string" },
	RemoteRejected = { contract = "string", reason = "string", weight = "number" },
	ZoneTransition = { from = "string", to = "string", holdConfirmed = "boolean" },
}

local TelemetryService = {
	deps = nil :: Deps?,
	buffer = {} :: { Event },
}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function copyEvent(event: Event): Event
	local fields = table.clone(event.fields)
	return {
		eventName = event.eventName,
		sessionId = event.sessionId,
		releaseId = event.releaseId,
		userId = event.userId,
		recordedAt = event.recordedAt,
		fields = fields,
	}
end

function TelemetryService.init(deps: Deps): ()
	TelemetryService.deps = deps
	table.clear(TelemetryService.buffer)
end

function TelemetryService.record(eventName: string, userId: number, fields: { [string]: any }): (boolean, string?)
	local deps = TelemetryService.deps
	local schema = FIELD_SCHEMAS[eventName]
	if not deps then
		return false, "not_initialized"
	end
	if not schema then
		return false, "event_not_allowed"
	end
	if userId % 1 ~= 0 or userId < 0 then
		return false, "user_id"
	end

	local sanitized: { [string]: string | number | boolean } = {}
	for fieldName, expectedType in schema do
		local value = fields[fieldName]
		if value ~= nil then
			if type(value) ~= expectedType then
				return false, "field_type"
			end
			if expectedType == "string" then
				if #value > 80 then
					return false, "field_length"
				end
			elseif expectedType == "number" and not isFinite(value) then
				return false, "field_number"
			end
			sanitized[fieldName] = value
		end
	end

	local event: Event = {
		eventName = eventName,
		sessionId = deps.sessionId,
		releaseId = deps.releaseId,
		userId = userId,
		recordedAt = if deps.now then deps.now() else os.time(),
		fields = sanitized,
	}
	local capacity = math.max(1, deps.bufferCapacity or 200)
	table.insert(TelemetryService.buffer, event)
	while #TelemetryService.buffer > capacity do
		table.remove(TelemetryService.buffer, 1)
	end
	if deps.emit then
		deps.emit(copyEvent(event))
	end
	return true, nil
end

function TelemetryService.snapshot(): { Event }
	local out: { Event } = {}
	for _, event in TelemetryService.buffer do
		table.insert(out, copyEvent(event))
	end
	return out
end

return TelemetryService

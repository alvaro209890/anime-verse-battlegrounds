--!strict
-- Segurança mínima dos remotes F0 (docs/07, docs/13 §13/§15). Valida o
-- envelope e o payload por contrato, descarta replay e aplica orçamento por
-- jogador. Nenhum valor aceito aqui autoriza dano, alcance, custo ou janela.

export type Deps = {
	decode: (any, string?) -> ({ [string]: any }?, string?),
	now: (() -> number)?,
	onRejected: ((number, string, string, number) -> ())?,
}

type PlayerState = {
	lastSequence: number,
	requestIds: { [string]: boolean },
	requestOrder: { string },
	windows: { [string]: { windowStart: number, count: number } },
}

local COMBAT_LIMIT = 8
local DEFAULT_LIMIT = 15
local REQUEST_ID_CAP = 64
local MAX_SEQUENCE = 9007199254740991

local COMBAT_CONTRACTS: { [string]: boolean } = {
	AbilityIntent = true,
	BasicAttackIntent = true,
	GuardIntent = true,
	DashIntent = true,
}

local REJECTION_WEIGHTS: { [string]: number } = {
	rate_limited = 2,
	replay_request = 4,
	replay_sequence = 4,
	payload_schema = 3,
	envelope_size = 3,
	envelope_schema = 3,
}

local SecurityService = {
	deps = nil :: Deps?,
	players = {} :: { [number]: PlayerState },
	rejectionReports = {} :: { [number]: { [string]: number } },
}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function reject(userId: number, contract: string, reason: string): (nil, string)
	local deps = SecurityService.deps
	if deps and deps.onRejected then
		local currentNow = if deps.now then deps.now() else os.clock()
		local reports = SecurityService.rejectionReports[userId]
		if not reports then
			reports = {}
			SecurityService.rejectionReports[userId] = reports
		end
		local reportKey = contract .. ":" .. reason
		local lastReportedAt = reports[reportKey]
		if not lastReportedAt or currentNow - lastReportedAt >= 1 then
			reports[reportKey] = currentNow
			deps.onRejected(userId, contract, reason, REJECTION_WEIGHTS[reason] or 1)
		end
	end
	return nil, reason
end

local function hasOnlyKeys(payload: { [string]: any }, allowed: { [string]: boolean }): boolean
	local count = 0
	for key, _ in payload do
		count += 1
		if type(key) ~= "string" or not allowed[key] or count > 8 then
			return false
		end
	end
	return true
end

local function validId(value: any): boolean
	return type(value) == "string" and #value >= 1 and #value <= 64 and string.match(value, "^[%w_:%-]+$") ~= nil
end

-- Vetor plano no chão: finito, componentes em [-1,1] e magnitude entre 0,1 e 1
-- (com folga de arredondamento). O dash sempre usou esta regra como direção;
-- desde 14/08 o golpe e a técnica a usam como MIRA — o corpo do jogador não
-- gira mais no ataque, então a direção chega declarada em vez de ser lida da
-- rotação replicada. Não é autoridade nova: aquela rotação era escrita pelo
-- próprio cliente antes de mandar a intenção.
local function validAimVector(value: any): boolean
	if type(value) ~= "table" or not hasOnlyKeys(value, { x = true, z = true }) then
		return false
	end
	local x = value.x
	local z = value.z
	if type(x) ~= "number" or type(z) ~= "number" or not isFinite(x) or not isFinite(z) then
		return false
	end
	local magnitudeSquared = x * x + z * z
	return math.abs(x) <= 1 and math.abs(z) <= 1 and magnitudeSquared >= 0.01 and magnitudeSquared <= 1.01
end

local function validateAbility(payload: { [string]: any }): boolean
	if
		not hasOnlyKeys(payload, { abilityId = true, inputMode = true, executionId = true, phase = true, aim = true })
	then
		return false
	end
	if payload.aim ~= nil and not validAimVector(payload.aim) then
		return false
	end
	local phase = payload.phase
	return validId(payload.abilityId)
		and validId(payload.executionId)
		and (payload.inputMode == "Press" or payload.inputMode == "Hold" or payload.inputMode == "Release")
		and (phase == nil or phase == "press" or phase == "release" or phase == "reentry")
end

local function validateBasic(payload: { [string]: any }): boolean
	if not hasOnlyKeys(payload, { kind = true, phase = true, aim = true, claimedTargetId = true }) then
		return false
	end
	if payload.aim ~= nil and not validAimVector(payload.aim) then
		return false
	end
	if payload.claimedTargetId ~= nil and not validId(payload.claimedTargetId) then
		return false
	end
	return (payload.kind == "light" or payload.kind == "heavy")
		and (payload.phase == "press" or payload.phase == "release")
end

local function validateGuard(payload: { [string]: any }): boolean
	return hasOnlyKeys(payload, { phase = true }) and (payload.phase == "down" or payload.phase == "up")
end

local function validateDash(payload: { [string]: any }): boolean
	if not hasOnlyKeys(payload, { direction = true }) or type(payload.direction) ~= "table" then
		return false
	end
	local direction = payload.direction
	if not hasOnlyKeys(direction, { x = true, z = true }) then
		return false
	end
	local x = direction.x
	local z = direction.z
	if type(x) ~= "number" or type(z) ~= "number" or not isFinite(x) or not isFinite(z) then
		return false
	end
	local magnitudeSquared = x * x + z * z
	return math.abs(x) <= 1 and math.abs(z) <= 1 and magnitudeSquared >= 0.01 and magnitudeSquared <= 1.01
end

local function validateZone(payload: { [string]: any }): boolean
	return hasOnlyKeys(payload, { toZoneId = true, phase = true })
		and validId(payload.toZoneId)
		and (payload.phase == "begin" or payload.phase == "complete" or payload.phase == "cancel")
end

local function validateInteraction(payload: { [string]: any }): boolean
	if not hasOnlyKeys(payload, { npcId = true, anchorId = true, phase = true }) then
		return false
	end
	local npcValid = payload.npcId ~= nil and validId(payload.npcId)
	local anchorValid = payload.anchorId ~= nil and validId(payload.anchorId)
	local phaseValid = payload.phase == "begin" or payload.phase == "complete" or payload.phase == "cancel"
	return npcValid ~= anchorValid and phaseValid
end

local SPEND_TRACKS: { [string]: boolean } = {
	vitality = true,
	umbral = true,
	impact = true,
	guard = true,
	resonance = true,
	respec = true,
}

local function validateSpend(payload: { [string]: any }): boolean
	if not hasOnlyKeys(payload, { trackId = true, amount = true }) then
		return false
	end
	if type(payload.trackId) ~= "string" or not SPEND_TRACKS[payload.trackId] then
		return false
	end
	if payload.amount == nil then
		return true
	end
	return type(payload.amount) == "number"
		and payload.amount == payload.amount
		and payload.amount >= 1
		and payload.amount <= 3
		and payload.amount == math.floor(payload.amount)
end

local VALIDATORS: { [string]: ({ [string]: any }) -> boolean } = {
	AbilityIntent = validateAbility,
	BasicAttackIntent = validateBasic,
	GuardIntent = validateGuard,
	DashIntent = validateDash,
	ZoneCrossingIntent = validateZone,
	InteractionIntent = validateInteraction,
	SpendProgressionIntent = validateSpend,
}

function SecurityService.init(deps: Deps): ()
	SecurityService.deps = deps
	table.clear(SecurityService.players)
	table.clear(SecurityService.rejectionReports)
end

function SecurityService.inspect(userId: number, contract: string, envelope: any): ({ [string]: any }?, string?)
	local deps = SecurityService.deps
	if not deps then
		return reject(userId, contract, "not_initialized")
	end
	local validator = VALIDATORS[contract]
	if not validator then
		return reject(userId, contract, "contract_direction")
	end
	if
		type(envelope) ~= "table"
		or not hasOnlyKeys(envelope, {
			protocolVersion = true,
			requestId = true,
			clientSequence = true,
			action = true,
			payload = true,
		})
	then
		return reject(userId, contract, "envelope_schema")
	end
	local payload, decodeReason = deps.decode(envelope, contract)
	if not payload then
		return reject(userId, contract, decodeReason or "envelope")
	end
	if
		type(envelope.requestId) ~= "string"
		or #envelope.requestId > 80
		or type(envelope.clientSequence) ~= "number"
		or not isFinite(envelope.clientSequence)
		or envelope.clientSequence > MAX_SEQUENCE
	then
		return reject(userId, contract, "envelope_size")
	end
	if not validator(payload) then
		return reject(userId, contract, "payload_schema")
	end

	local state = SecurityService.players[userId]
	if not state then
		state = { lastSequence = 0, requestIds = {}, requestOrder = {}, windows = {} }
		SecurityService.players[userId] = state
	end
	if state.requestIds[envelope.requestId] then
		return reject(userId, contract, "replay_request")
	end
	if envelope.clientSequence <= state.lastSequence then
		return reject(userId, contract, "replay_sequence")
	end

	state.lastSequence = envelope.clientSequence
	state.requestIds[envelope.requestId] = true
	table.insert(state.requestOrder, envelope.requestId)
	while #state.requestOrder > REQUEST_ID_CAP do
		local oldest = table.remove(state.requestOrder, 1)
		state.requestIds[oldest] = nil
	end

	local currentNow = if deps.now then deps.now() else os.clock()
	local class = if COMBAT_CONTRACTS[contract] then "combat" else "default"
	local window = state.windows[class]
	if not window or currentNow - window.windowStart >= 1 then
		window = { windowStart = currentNow, count = 0 }
		state.windows[class] = window
	end
	window.count += 1
	local limit = if class == "combat" then COMBAT_LIMIT else DEFAULT_LIMIT
	if window.count > limit then
		return reject(userId, contract, "rate_limited")
	end
	return payload, nil
end

function SecurityService.clearPlayer(userId: number): ()
	SecurityService.players[userId] = nil
	SecurityService.rejectionReports[userId] = nil
end

return SecurityService

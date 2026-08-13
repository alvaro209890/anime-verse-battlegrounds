--!strict
-- Limite puro para reconciliar movimento horizontal replicado pelo personagem.
-- Movimento autorizado pelo servidor deve usar `commitServerMove`; a posição
-- replicada comum consome um token bucket proporcional ao WalkSpeed.

export type Position = {
	x: number,
	y: number,
	z: number,
}

export type Config = {
	burstStuds: number?,
	maxRefillElapsedSeconds: number?,
	speedToleranceMultiplier: number?,
	maxVerticalDeltaStuds: number?,
	verticalBurstStuds: number?,
}

type ResolvedConfig = {
	burstStuds: number,
	maxRefillElapsedSeconds: number,
	speedToleranceMultiplier: number,
	maxVerticalDeltaStuds: number,
	verticalBurstStuds: number,
}

type PlayerState = {
	position: Position,
	budget: number,
	verticalBudget: number,
	lastAt: number,
}

local DEFAULT_BURST_STUDS = 8
local DEFAULT_MAX_REFILL_ELAPSED_SECONDS = 0.25
-- Margem para jitter de replicação/física. O burst e o clamp temporal continuam
-- limitando teleporte; a margem evita rollback em caminhada legítima irregular.
local DEFAULT_SPEED_TOLERANCE_MULTIPLIER = 1.15
local DEFAULT_MAX_VERTICAL_DELTA_STUDS = 12
-- Um salto normal cabe no orçamento, mas subida monotônica não pode somar um
-- delta permitido a cada Heartbeat. Descer repõe apenas a altura devolvida.
local DEFAULT_VERTICAL_BURST_STUDS = 10
local MIN_WORLD_Y = -12
local MAX_WORLD_Y = 32
local BUDGET_EPSILON = 1e-6

local PlayerMotionGuard = {
	config = {
		burstStuds = DEFAULT_BURST_STUDS,
		maxRefillElapsedSeconds = DEFAULT_MAX_REFILL_ELAPSED_SECONDS,
		speedToleranceMultiplier = DEFAULT_SPEED_TOLERANCE_MULTIPLIER,
		maxVerticalDeltaStuds = DEFAULT_MAX_VERTICAL_DELTA_STUDS,
		verticalBurstStuds = DEFAULT_VERTICAL_BURST_STUDS,
	} :: ResolvedConfig,
	players = {} :: { [number]: PlayerState },
}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isValidPosition(position: Position): boolean
	return type(position) == "table"
		and type(position.x) == "number"
		and type(position.y) == "number"
		and type(position.z) == "number"
		and isFinite(position.x)
		and isFinite(position.y)
		and isFinite(position.z)
end

local function clonePosition(position: Position): Position
	return {
		x = position.x,
		y = position.y,
		z = position.z,
	}
end

local function horizontalDistance(from: Position, to: Position): number
	local dx = to.x - from.x
	local dz = to.z - from.z
	return math.sqrt(dx * dx + dz * dz)
end

local function positiveFiniteOrDefault(value: number?, defaultValue: number, fieldName: string): number
	if value == nil then
		return defaultValue
	end
	if not isFinite(value) or value <= 0 then
		error(("PlayerMotionGuard.init: %s deve ser positivo e finito"):format(fieldName))
	end
	return value
end

function PlayerMotionGuard.init(config: Config?): ()
	local resolved = config or {}
	PlayerMotionGuard.config = {
		burstStuds = positiveFiniteOrDefault(resolved.burstStuds, DEFAULT_BURST_STUDS, "burstStuds"),
		maxRefillElapsedSeconds = positiveFiniteOrDefault(
			resolved.maxRefillElapsedSeconds,
			DEFAULT_MAX_REFILL_ELAPSED_SECONDS,
			"maxRefillElapsedSeconds"
		),
		speedToleranceMultiplier = positiveFiniteOrDefault(
			resolved.speedToleranceMultiplier,
			DEFAULT_SPEED_TOLERANCE_MULTIPLIER,
			"speedToleranceMultiplier"
		),
		maxVerticalDeltaStuds = positiveFiniteOrDefault(
			resolved.maxVerticalDeltaStuds,
			DEFAULT_MAX_VERTICAL_DELTA_STUDS,
			"maxVerticalDeltaStuds"
		),
		verticalBurstStuds = positiveFiniteOrDefault(
			resolved.verticalBurstStuds,
			DEFAULT_VERTICAL_BURST_STUDS,
			"verticalBurstStuds"
		),
	}
	table.clear(PlayerMotionGuard.players)
end

function PlayerMotionGuard.register(userId: number, position: Position, now: number): (boolean, string?)
	if not isValidPosition(position) then
		return false, "invalid_position"
	end
	if not isFinite(now) then
		return false, "invalid_time"
	end
	PlayerMotionGuard.players[userId] = {
		position = clonePosition(position),
		budget = PlayerMotionGuard.config.burstStuds,
		verticalBudget = PlayerMotionGuard.config.verticalBurstStuds,
		lastAt = now,
	}
	return true, nil
end

function PlayerMotionGuard.authorize(
	userId: number,
	position: Position,
	now: number,
	walkSpeed: number
): (boolean, Position | string)
	if not isValidPosition(position) then
		return false, "invalid_position"
	end
	if not isFinite(now) then
		return false, "invalid_time"
	end
	if not isFinite(walkSpeed) or walkSpeed < 0 then
		return false, "invalid_walk_speed"
	end

	local state = PlayerMotionGuard.players[userId]
	if not state then
		return false, "unregistered"
	end

	local elapsed = math.clamp(now - state.lastAt, 0, PlayerMotionGuard.config.maxRefillElapsedSeconds)
	state.budget = math.min(
		PlayerMotionGuard.config.burstStuds,
		state.budget + walkSpeed * PlayerMotionGuard.config.speedToleranceMultiplier * elapsed
	)
	-- Mesmo uma tentativa recusada consome o intervalo de refill. Sem isso, um
	-- cliente poderia repetir o mesmo timestamp lógico e creditar o tempo várias vezes.
	state.lastAt = math.max(state.lastAt, now)

	local distance = horizontalDistance(state.position, position)
	local verticalDelta = position.y - state.position.y
	if
		position.y < MIN_WORLD_Y
		or position.y > MAX_WORLD_Y
		or math.abs(position.y - state.position.y) > PlayerMotionGuard.config.maxVerticalDeltaStuds
	then
		return false, "vertical_movement"
	end
	if verticalDelta > state.verticalBudget + BUDGET_EPSILON then
		return false, "vertical_movement"
	end
	if distance > state.budget + BUDGET_EPSILON then
		return false, "movement_budget"
	end

	state.budget = math.max(0, state.budget - distance)
	if verticalDelta > 0 then
		state.verticalBudget = math.max(0, state.verticalBudget - verticalDelta)
	elseif verticalDelta < 0 then
		state.verticalBudget =
			math.min(PlayerMotionGuard.config.verticalBurstStuds, state.verticalBudget - verticalDelta)
	end
	state.position = clonePosition(position)
	return true, clonePosition(state.position)
end

function PlayerMotionGuard.commitServerMove(userId: number, position: Position, now: number): (boolean, string?)
	if not isValidPosition(position) then
		return false, "invalid_position"
	end
	if not isFinite(now) then
		return false, "invalid_time"
	end

	local state = PlayerMotionGuard.players[userId]
	if not state then
		PlayerMotionGuard.players[userId] = {
			position = clonePosition(position),
			budget = PlayerMotionGuard.config.burstStuds,
			verticalBudget = PlayerMotionGuard.config.verticalBurstStuds,
			lastAt = now,
		}
		return true, nil
	end

	-- Dash/lunge/empurrão já foram autorizados pelo servidor: realinham a base
	-- sem consumir nem restaurar o orçamento de caminhada replicada.
	state.position = clonePosition(position)
	state.lastAt = math.max(state.lastAt, now)
	return true, nil
end

function PlayerMotionGuard.getAcceptedPosition(userId: number): Position?
	local state = PlayerMotionGuard.players[userId]
	return if state then clonePosition(state.position) else nil
end

function PlayerMotionGuard.clearPlayer(userId: number): ()
	PlayerMotionGuard.players[userId] = nil
end

return PlayerMotionGuard

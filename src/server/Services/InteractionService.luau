--!strict
-- Validação autoritativa das interações F0. O cliente escolhe somente a
-- intenção semântica; o servidor resolve o alvo allowlisted, lê a posição do
-- jogador e executa o callback de domínio correspondente.

export type Vec3 = { x: number, y: number, z: number }

export type InteractionResult = {
	ok: boolean,
	reason: string?,
	phase: ("begin" | "complete" | "cancel")?,
	interactionId: string?,
	targetId: string?,
	value: any?,
}

export type PendingInteraction = {
	interactionId: string,
	startedAt: number,
}

export type InteractionDeps = {
	catalog: any,
	getAnchor: (string) -> any?,
	getPlayerPosition: (number) -> Vec3?,
	onNpc: ((number, string, number) -> (boolean, string?, any?))?,
	onAnchor: ((number, string, number) -> (boolean, string?, any?))?,
}

local InteractionService = {
	deps = nil :: InteractionDeps?,
	pending = {} :: { [number]: PendingInteraction },
}

local HOLD_EXPIRY_GRACE_SECONDS = 3

local function reject(reason: string): InteractionResult
	return {
		ok = false,
		reason = reason,
		phase = nil,
		interactionId = nil,
		targetId = nil,
		value = nil,
	}
end

local function distanceBetween(a: Vec3, b: Vec3): number
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isFinitePosition(value: any): boolean
	return type(value) == "table" and isFiniteNumber(value.x) and isFiniteNumber(value.y) and isFiniteNumber(value.z)
end

function InteractionService.init(deps: InteractionDeps): ()
	local valid, reason = deps.catalog.validate()
	if not valid then
		error("catálogo de interação inválido: " .. (reason or "unknown"))
	end
	InteractionService.deps = deps
	table.clear(InteractionService.pending)
end

function InteractionService.tryInteract(userId: number, payload: { [string]: any }, now: number): InteractionResult
	local deps = InteractionService.deps
	if not deps then
		return reject("not_initialized")
	end

	local definition, resolveReason = deps.catalog.resolve(payload.npcId, payload.anchorId)
	if not definition then
		return reject(resolveReason or "unknown_target")
	end
	local phase = payload.phase
	if phase ~= "begin" and phase ~= "complete" and phase ~= "cancel" then
		return reject("invalid_phase")
	end
	if phase == "cancel" then
		local pending = InteractionService.pending[userId]
		if pending and pending.interactionId == definition.id then
			InteractionService.pending[userId] = nil
		end
		return {
			ok = true,
			reason = nil,
			phase = "cancel",
			interactionId = definition.id,
			targetId = definition.targetId,
			value = nil,
		}
	end
	local anchor = deps.getAnchor(definition.anchorId)
	if not anchor or not isFinitePosition(anchor.position) then
		return reject("target_unavailable")
	end
	local playerPosition = deps.getPlayerPosition(userId)
	if not isFinitePosition(playerPosition) then
		return reject("position_unavailable")
	end
	local targetPosition = anchor.position :: Vec3
	local authoritativePosition = playerPosition :: Vec3
	if distanceBetween(authoritativePosition, targetPosition) > definition.maxDistance then
		InteractionService.pending[userId] = nil
		return reject("too_far")
	end
	if phase == "begin" then
		if definition.holdDuration <= 0 then
			return reject("hold_not_required")
		end
		InteractionService.pending[userId] = {
			interactionId = definition.id,
			startedAt = now,
		}
		return {
			ok = true,
			reason = nil,
			phase = "begin",
			interactionId = definition.id,
			targetId = definition.targetId,
			value = nil,
		}
	end

	if definition.holdDuration > 0 then
		local pending = InteractionService.pending[userId]
		if not pending or pending.interactionId ~= definition.id then
			return reject("hold_required")
		end
		local elapsed = now - pending.startedAt
		if elapsed < definition.holdDuration then
			InteractionService.pending[userId] = nil
			return reject("hold_incomplete")
		end
		InteractionService.pending[userId] = nil
		if elapsed > definition.holdDuration + HOLD_EXPIRY_GRACE_SECONDS then
			return reject("hold_expired")
		end
	end

	local callback = if definition.kind == "npc" then deps.onNpc else deps.onAnchor
	if not callback then
		return reject("handler_unavailable")
	end
	local ok, callbackReason, value = callback(userId, definition.targetId, now)
	if not ok then
		return reject(callbackReason or "rejected")
	end
	return {
		ok = true,
		reason = nil,
		phase = "complete",
		interactionId = definition.id,
		targetId = definition.targetId,
		value = value,
	}
end

function InteractionService.clearPlayer(userId: number): ()
	InteractionService.pending[userId] = nil
end

return InteractionService

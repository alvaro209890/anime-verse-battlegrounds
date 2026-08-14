--!strict
-- Três slots F0, execução correlacionada e cooldown de apresentação. O servidor
-- continua sendo a única autoridade de custo, cooldown final e resultado.

export type CadenceReentry = {
	executionId: string,
	opensAt: number,
	expiresAt: number,
	sent: boolean,
}

export type Controller = {
	state: any,
	stateApi: any,
	abilities: any,
	characters: any,
	send: (string, string, { [string]: any }) -> (),
	guid: () -> string,
	slotIds: { string },
	executions: { [string]: string },
	cadenceReentry: CadenceReentry?,
	onActivated: ((number, string, string) -> ())?,
	-- Mira declarada da técnica. Vem do CharacterController porque é ele quem
	-- conhece câmera e alvo travado; sem isto a técnica sairia na direção do
	-- corpo, que desde 14/08 não gira mais no golpe.
	aim: (() -> { x: number, z: number }?)?,
}

local AbilityController = {}

local BROKEN_CADENCE_ID = "broken_cadence"
-- O servidor usa 120 ms de janela + até 80 ms de compensação. O cliente mantém
-- 220 ms apenas como buffer/predição de input (§6.2).
local CADENCE_CLIENT_BUFFER_SECONDS = 0.22

local function buildSlots(abilities: any, characters: any): { string }
	local slots: { string } = {}
	local character = characters.get("eclipse_fist")
	if not character then
		return slots
	end
	for _, abilityId in character.abilityIds do
		local ability = abilities.get(abilityId)
		-- A ultimate permanece ausente enquanto enabled=false (§12).
		if ability and ability.kind == "Skill" and ability.enabled == true and #slots < 3 then
			table.insert(slots, abilityId)
		end
	end
	return slots
end

function AbilityController.new(deps: {
	state: any,
	stateApi: any,
	input: any,
	inputSubscribe: (any, (string, { [string]: any }) -> ()) -> (),
	abilities: any,
	characters: any,
	send: (string, string, { [string]: any }) -> (),
	guid: () -> string,
	onActivated: ((number, string, string) -> ())?,
	aim: (() -> { x: number, z: number }?)?,
}): Controller
	local controller: Controller = {
		state = deps.state,
		stateApi = deps.stateApi,
		abilities = deps.abilities,
		characters = deps.characters,
		send = deps.send,
		guid = deps.guid,
		slotIds = buildSlots(deps.abilities, deps.characters),
		executions = {},
		cadenceReentry = nil,
		onActivated = deps.onActivated,
		aim = deps.aim,
	}
	deps.inputSubscribe(deps.input, function(action: string, _payload: { [string]: any })
		local slot = string.match(action, "^Ability(%d)$")
		if slot then
			AbilityController.activateSlot(controller, tonumber(slot) :: number)
		end
	end)
	return controller
end

local function currentTime(controller: Controller): number
	local stateNow = controller.state.now
	return if type(stateNow) == "function" then stateNow() else os.clock()
end

local function tryCadenceReentry(controller: Controller, ability: any, slot: number): (boolean, string?)
	local reentry = controller.cadenceReentry
	if not reentry then
		return false, "cooldown"
	end
	local current = currentTime(controller)
	if reentry.sent or current < reentry.opensAt or current > reentry.expiresAt then
		if current > reentry.expiresAt then
			controller.cadenceReentry = nil
		end
		return false, "reentry_window"
	end

	-- Este gate local é só buffer: o servidor mede a janela real e pode rejeitar.
	reentry.sent = true
	controller.send("AbilityIntent", "AbilityIntent", {
		abilityId = BROKEN_CADENCE_ID,
		inputMode = ability.inputMode,
		executionId = reentry.executionId,
		phase = "reentry",
		aim = if controller.aim then controller.aim() else nil,
	})
	if controller.onActivated then
		controller.onActivated(slot, BROKEN_CADENCE_ID, "reentry")
	end
	return true, reentry.executionId
end

function AbilityController.isUnlocked(controller: Controller, abilityId: string): boolean
	return controller.state.unlocks["unlock_" .. abilityId] == true
end

function AbilityController.activateSlot(controller: Controller, slot: number): (boolean, string?)
	if controller.state.ready ~= true then
		return false, "not_ready"
	end
	local abilityId = controller.slotIds[slot]
	local ability = if abilityId then controller.abilities.get(abilityId) else nil
	if not ability or ability.enabled ~= true or ability.kind == "Ultimate" then
		return false, "unavailable"
	end
	if not AbilityController.isUnlocked(controller, abilityId) then
		return false, "locked"
	end
	if controller.stateApi.cooldownRemaining(controller.state, abilityId) > 0 then
		if abilityId == BROKEN_CADENCE_ID then
			return tryCadenceReentry(controller, ability, slot)
		end
		return false, "cooldown"
	end

	local executionId = controller.guid()
	controller.executions[abilityId] = executionId
	local activatedAt = currentTime(controller)
	-- Resposta visual imediata; StateDelta/rejeição reconciliam este valor.
	controller.stateApi.setCooldown(controller.state, abilityId, ability.cooldown.baseSeconds)
	if abilityId == BROKEN_CADENCE_ID then
		local opensAt = activatedAt + (ability.startupMs + ability.activeMs) / 1000
		controller.cadenceReentry = {
			executionId = executionId,
			opensAt = opensAt,
			expiresAt = opensAt + CADENCE_CLIENT_BUFFER_SECONDS,
			sent = false,
		}
	end
	controller.send("AbilityIntent", "AbilityIntent", {
		abilityId = abilityId,
		inputMode = ability.inputMode,
		executionId = executionId,
		phase = "press",
		aim = if controller.aim then controller.aim() else nil,
	})
	if controller.onActivated then
		controller.onActivated(slot, abilityId, "press")
	end
	return true, executionId
end

function AbilityController.onRejected(controller: Controller, payload: { [string]: any }): ()
	local abilityId = payload.abilityId
	if type(abilityId) ~= "string" then
		return
	end
	local rejectedExecutionId = payload.executionId
	local currentExecutionId = controller.executions[abilityId]
	if
		type(rejectedExecutionId) == "string"
		and type(currentExecutionId) == "string"
		and rejectedExecutionId ~= currentExecutionId
	then
		return
	end
	if abilityId == BROKEN_CADENCE_ID then
		local reentry = controller.cadenceReentry
		if reentry and type(rejectedExecutionId) == "string" and rejectedExecutionId ~= reentry.executionId then
			return
		end
		local sameExecution = type(rejectedExecutionId) ~= "string" or reentry ~= nil
		local isReentry = reentry
			and reentry.sent
			and sameExecution
			and (payload.phase == nil or payload.phase == "reentry")
		controller.cadenceReentry = nil
		if isReentry then
			-- Rejeição da predição não desfaz o cooldown autoritativo já iniciado.
			return
		end
	end
	controller.stateApi.setCooldown(controller.state, abilityId, 0)
end

return AbilityController

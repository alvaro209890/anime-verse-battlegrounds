--!strict
-- Três slots F0, execução correlacionada e cooldown de apresentação. O servidor
-- continua sendo a única autoridade de custo, cooldown final e resultado.

export type Controller = {
	state: any,
	stateApi: any,
	abilities: any,
	characters: any,
	send: (string, string, { [string]: any }) -> (),
	guid: () -> string,
	slotIds: { string },
}

local AbilityController = {}

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
}): Controller
	local controller: Controller = {
		state = deps.state,
		stateApi = deps.stateApi,
		abilities = deps.abilities,
		characters = deps.characters,
		send = deps.send,
		guid = deps.guid,
		slotIds = buildSlots(deps.abilities, deps.characters),
	}
	deps.inputSubscribe(deps.input, function(action: string, _payload: { [string]: any })
		local slot = string.match(action, "^Ability(%d)$")
		if slot then
			AbilityController.activateSlot(controller, tonumber(slot) :: number)
		end
	end)
	return controller
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
		return false, "cooldown"
	end

	local executionId = controller.guid()
	-- Resposta visual imediata; StateDelta/rejeição reconciliam este valor.
	controller.stateApi.setCooldown(controller.state, abilityId, ability.cooldown.baseSeconds)
	controller.send("AbilityIntent", "AbilityIntent", {
		abilityId = abilityId,
		inputMode = ability.inputMode,
		executionId = executionId,
		phase = "press",
	})
	return true, executionId
end

function AbilityController.onRejected(controller: Controller, payload: { [string]: any }): ()
	local abilityId = payload.abilityId
	if type(abilityId) == "string" then
		controller.stateApi.setCooldown(controller.state, abilityId, 0)
	end
end

return AbilityController

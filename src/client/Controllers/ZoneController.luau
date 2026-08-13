--!strict
-- Zona persistente e resumo de perda. Só apresenta a zona efetiva informada
-- pelo servidor; a geometria do cliente não autoriza travessia.

export type Controller = {
	state: any,
	stateApi: any,
	send: ((string, string, { [string]: any }) -> ())?,
	now: () -> number,
	holdStartedAt: number?,
}

local ZoneController = {}

function ZoneController.new(
	state: any,
	stateApi: any,
	input: any?,
	inputSubscribe: ((any, (string, { [string]: any }) -> ()) -> ())?,
	send: ((string, string, { [string]: any }) -> ())?,
	now: (() -> number)?
): Controller
	local controller: Controller = {
		state = state,
		stateApi = stateApi,
		send = send,
		now = now or os.clock,
		holdStartedAt = nil,
	}
	if input and inputSubscribe then
		inputSubscribe(input, function(action: string, _payload: { [string]: any })
			ZoneController.onAction(controller, action)
		end)
	end
	return controller
end

function ZoneController.onZoneEvent(controller: Controller, payload: { [string]: any }): ()
	if controller.state.ready ~= true or type(payload.to) ~= "string" then
		return
	end
	local rejected = payload.rejectedReason ~= nil
	if payload.rejectedReason == "hold_required" then
		controller.state.zoneHoldRequired = true
		controller.state.pendingZoneId = payload.to
	elseif not rejected then
		controller.state.zoneHoldRequired = false
		controller.state.pendingZoneId = nil
	end
	if not rejected then
		controller.stateApi.setZone(controller.state, payload.to, payload.pvp == true)
	end
	if type(payload.lockoutRemaining) == "number" and payload.lockoutRemaining > 0 then
		controller.stateApi.setFeedback(controller.state, "hud.feedback_zone_lockout", 1)
	end
end

function ZoneController.onAction(controller: Controller, action: string): ()
	if action == "ZoneHoldDown" and controller.state.zoneHoldRequired then
		controller.holdStartedAt = controller.now()
	elseif action == "ZoneHoldUp" then
		local startedAt = controller.holdStartedAt
		controller.holdStartedAt = nil
		if
			startedAt
			and controller.now() - startedAt >= 0.6
			and controller.state.zoneHoldRequired
			and controller.state.pendingZoneId
			and controller.send
		then
			controller.send("ZoneCrossingIntent", "ZoneCrossingIntent", {
				toZoneId = controller.state.pendingZoneId,
				holdConfirmed = true,
			})
		end
	end
end

function ZoneController.onDelta(controller: Controller, payload: { [string]: any }): ()
	if type(payload.deathPenalty) == "number" and payload.deathPenalty > 0 then
		controller.stateApi.setFeedback(controller.state, "hud.feedback_death_loss", 1)
	end
end

return ZoneController

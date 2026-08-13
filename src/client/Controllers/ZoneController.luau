--!strict
-- Zona persistente e resumo de perda. Só apresenta a zona efetiva informada
-- pelo servidor; a geometria do cliente não autoriza travessia.

export type Controller = {
	state: any,
	stateApi: any,
}

local ZoneController = {}

function ZoneController.new(state: any, stateApi: any): Controller
	return { state = state, stateApi = stateApi }
end

function ZoneController.onZoneEvent(controller: Controller, payload: { [string]: any }): ()
	if controller.state.ready ~= true or type(payload.to) ~= "string" then
		return
	end
	controller.stateApi.setZone(controller.state, payload.to, payload.pvp == true)
	if type(payload.lockoutRemaining) == "number" and payload.lockoutRemaining > 0 then
		controller.stateApi.setFeedback(controller.state, "hud.feedback_zone_lockout", 1)
	end
end

function ZoneController.onDelta(controller: Controller, payload: { [string]: any }): ()
	if type(payload.deathPenalty) == "number" and payload.deathPenalty > 0 then
		controller.stateApi.setFeedback(controller.state, "hud.feedback_death_loss", 1)
	end
end

return ZoneController

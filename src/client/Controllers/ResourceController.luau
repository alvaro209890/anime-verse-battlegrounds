--!strict
-- Projeta Umbral autoritativo. Não calcula regen nem antecipa custo.

export type Controller = {
	state: any,
	stateApi: any,
}

local ResourceController = {}

function ResourceController.new(state: any, stateApi: any): Controller
	return { state = state, stateApi = stateApi }
end

function ResourceController.onChanged(controller: Controller, payload: { [string]: any }): ()
	if controller.state.ready ~= true then
		return
	end
	if type(payload.current) ~= "number" or type(payload.max) ~= "number" then
		return
	end
	controller.stateApi.setResource(controller.state, payload.current, payload.max, payload.depleted == true)
end

return ResourceController

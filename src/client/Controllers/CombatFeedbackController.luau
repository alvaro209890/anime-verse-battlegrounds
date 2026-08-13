--!strict
-- Feedback efêmero confirmado pelo servidor. A UI recebe apenas chaves de
-- Locale; razões internas nunca são exibidas diretamente.

export type Controller = {
	state: any,
	stateApi: any,
}

local REJECTION_KEYS: { [string]: string } = {
	no_resource = "hud.feedback_no_resource",
	cooldown = "hud.feedback_cooldown",
	locked = "hud.feedback_locked",
}

local OUTCOME_KEYS: { [string]: string } = {
	hit = "hud.feedback_hit",
	guard = "hud.feedback_guard",
	death = "hud.feedback_death",
}

local CombatFeedbackController = {}

function CombatFeedbackController.new(state: any, stateApi: any): Controller
	return { state = state, stateApi = stateApi }
end

function CombatFeedbackController.onCombatEvent(controller: Controller, payload: { [string]: any }): ()
	if controller.state.ready ~= true then
		return
	end
	local key = OUTCOME_KEYS[payload.outcome]
	if key then
		controller.stateApi.setFeedback(controller.state, key, 1)
	end
end

function CombatFeedbackController.onRejected(controller: Controller, payload: { [string]: any }): ()
	if controller.state.ready ~= true then
		return
	end
	local key = REJECTION_KEYS[payload.reason] or "hud.feedback_rejected"
	controller.stateApi.setFeedback(controller.state, key, 1)
end

return CombatFeedbackController

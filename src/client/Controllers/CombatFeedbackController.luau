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
	-- Contra do Retorno de Pulso: o defensor devolveu dano. Precisa de rótulo
	-- próprio — ler "ACERTO" ao aparar não distingue defesa de ataque.
	counter = "hud.feedback_counter",
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
	local reason = payload.reason
	local key = REJECTION_KEYS[reason]
	if not key and type(reason) == "string" and string.sub(reason, 1, 8) == "cooldown" then
		key = "hud.feedback_cooldown"
	end
	key = key or "hud.feedback_rejected"
	controller.stateApi.setFeedback(controller.state, key, 1)
end

return CombatFeedbackController

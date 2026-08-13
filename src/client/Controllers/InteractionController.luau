--!strict
-- ProximityPrompt nativo para teclado, toque e gamepad. O prompt apenas emite
-- uma intenção allowlisted depois do SessionSnapshot; o servidor revalida
-- alvo, posição, distância e todas as regras de missão/consolidação.

export type Controller = {
	state: any,
	input: any,
	inputApi: any,
	send: (string, string, { [string]: any }) -> (),
	workspace: any,
	locale: any,
	catalog: any,
	prompts: { [any]: any },
	holding: { [any]: boolean },
	connections: { any },
	started: boolean,
}

local InteractionController = {}

local PROMPT_NAME = "F0InteractionPrompt"

function InteractionController.onAction(controller: Controller, action: string, payload: { [string]: any }): ()
	if action ~= "Interact" or controller.state.ready ~= true then
		return
	end
	local definition = controller.catalog.resolve(payload.npcId, payload.anchorId)
	if not definition then
		return
	end
	local phase = payload.phase
	if phase ~= "begin" and phase ~= "complete" then
		return
	end
	controller.send("InteractionIntent", "InteractionIntent", {
		npcId = if definition.kind == "npc" then definition.targetId else nil,
		anchorId = if definition.kind == "anchor" then definition.targetId else nil,
		phase = phase,
	})
end

function InteractionController.new(deps: {
	state: any,
	input: any,
	inputSubscribe: (any, (string, { [string]: any }) -> ()) -> (),
	inputApi: any,
	send: (string, string, { [string]: any }) -> (),
	workspace: any,
	locale: any,
	catalog: any,
}): Controller
	local controller: Controller = {
		state = deps.state,
		input = deps.input,
		inputApi = deps.inputApi,
		send = deps.send,
		workspace = deps.workspace,
		locale = deps.locale,
		catalog = deps.catalog,
		prompts = {},
		holding = {},
		connections = {},
		started = false,
	}
	deps.inputSubscribe(deps.input, function(action: string, payload: { [string]: any })
		InteractionController.onAction(controller, action, payload)
	end)
	return controller
end

local function definitionForTarget(controller: Controller, target: BasePart): any?
	return select(
		1,
		controller.catalog.resolve(target:GetAttribute("InteractionNpcId"), target:GetAttribute("InteractionAnchorId"))
	)
end

local function updateText(controller: Controller, prompt: ProximityPrompt, definition: any): ()
	local localeId = controller.state.locale
	prompt.ActionText = controller.locale.get(definition.actionTextKey, localeId)
	prompt.ObjectText = controller.locale.get(definition.objectTextKey, localeId)
end

local function attachPrompt(controller: Controller, candidate: Instance): ()
	if not candidate:IsA("BasePart") or controller.prompts[candidate] then
		return
	end
	local definition = definitionForTarget(controller, candidate)
	if not definition then
		return
	end

	local previous = candidate:FindFirstChild(PROMPT_NAME)
	if previous then
		previous:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.AutoLocalize = false
	prompt.HoldDuration = definition.holdDuration
	prompt.MaxActivationDistance = definition.maxDistance
	prompt.MaxIndicatorDistance = definition.maxDistance
	prompt.RequiresLineOfSight = definition.requiresLineOfSight
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	updateText(controller, prompt, definition)
	prompt.Parent = candidate
	controller.prompts[candidate] = prompt

	table.insert(
		controller.connections,
		prompt.PromptShown:Connect(function()
			updateText(controller, prompt, definition)
		end)
	)
	table.insert(
		controller.connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			if definition.holdDuration > 0 then
				controller.holding[candidate] = true
				controller.inputApi.dispatch(controller.input, "Interact", {
					npcId = if definition.kind == "npc" then definition.targetId else nil,
					anchorId = if definition.kind == "anchor" then definition.targetId else nil,
					phase = "begin",
				})
			end
		end)
	)
	table.insert(
		controller.connections,
		prompt.Triggered:Connect(function()
			-- O servidor exige um `begin` correspondente para holds. Não dependemos
			-- da ordem entre HoldEnded/Triggered para concluir um hold legítimo.
			controller.holding[candidate] = nil
			controller.inputApi.dispatch(controller.input, "Interact", {
				npcId = if definition.kind == "npc" then definition.targetId else nil,
				anchorId = if definition.kind == "anchor" then definition.targetId else nil,
				phase = "complete",
			})
		end)
	)
	table.insert(
		controller.connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			controller.holding[candidate] = nil
		end)
	)
	table.insert(
		controller.connections,
		candidate.AncestryChanged:Connect(function(_, parent: Instance?)
			if parent == nil then
				controller.prompts[candidate] = nil
				controller.holding[candidate] = nil
			end
		end)
	)
end

function InteractionController.start(controller: Controller): ()
	if controller.started then
		return
	end
	controller.started = true
	for _, descendant in controller.workspace:GetDescendants() do
		attachPrompt(controller, descendant)
	end
	table.insert(
		controller.connections,
		controller.workspace.DescendantAdded:Connect(function(descendant: Instance)
			attachPrompt(controller, descendant)
		end)
	)
end

function InteractionController.stop(controller: Controller): ()
	for _, connection in controller.connections do
		connection:Disconnect()
	end
	for _, prompt in controller.prompts do
		if prompt.Parent then
			prompt:Destroy()
		end
	end
	table.clear(controller.connections)
	table.clear(controller.prompts)
	table.clear(controller.holding)
	controller.started = false
end

return InteractionController

--!strict
-- Teclado/mouse, toque e gamepad → intenção semântica. Não conhece remotes e
-- nunca emite antes do SessionSnapshot ready (SLICE-DEC-005).

export type SemanticAction =
	"BasicLight"
	| "BasicHeavy"
	| "GuardDown"
	| "GuardUp"
	| "Dash"
	| "Ability1"
	| "Ability2"
	| "Ability3"
	| "ZoneHoldDown"
	| "ZoneHoldUp"
	| "Interact"
	| "ToggleLock"
	| "ToggleHelp"

export type Controller = {
	state: any,
	now: () -> number,
	listeners: { (SemanticAction, { [string]: any }) -> () },
	windowStart: number,
	combatCount: number,
	gamepadModifier: boolean,
	touchPressed: { [string]: boolean },
	touchCount: number,
	connections: { any },
}

local COMBAT_LIMIT_PER_SECOND = 8
local NON_COMBAT: { [string]: boolean } = {
	ToggleLock = true,
	ToggleHelp = true,
	ZoneHoldDown = true,
	ZoneHoldUp = true,
	Interact = true,
}

local InputController = {}

function InputController.new(state: any, now: (() -> number)?): Controller
	return {
		state = state,
		now = now or os.clock,
		listeners = {},
		windowStart = 0,
		combatCount = 0,
		gamepadModifier = false,
		touchPressed = {},
		touchCount = 0,
		connections = {},
	}
end

function InputController.subscribe(controller: Controller, listener: (SemanticAction, { [string]: any }) -> ()): ()
	table.insert(controller.listeners, listener)
end

-- Clique de combate não pode morrer na HUD. No Studio, InputBegan chega com
-- processed=true sobre Frame/TextLabel do ScreenGui — o playtest clicava e
-- nem o golpe nem a animação saíam. Teclado ainda respeita chat/TextBox.
-- Clique em GuiButton ativo fica com o botão (MENU, ATACAR, técnicas).
function InputController.shouldAcceptInput(
	processed: boolean,
	typing: boolean,
	isMouseCombat: boolean,
	onGuiButton: boolean
): boolean
	if typing then
		return false
	end
	if not processed then
		return true
	end
	return isMouseCombat and not onGuiButton
end

function InputController.dispatch(
	controller: Controller,
	action: SemanticAction,
	payload: { [string]: any }?
): (boolean, string?)
	if controller.state.ready ~= true then
		return false, "not_ready"
	end
	if not NON_COMBAT[action] then
		local now = controller.now()
		if now - controller.windowStart >= 1 then
			controller.windowStart = now
			controller.combatCount = 0
		end
		if controller.combatCount >= COMBAT_LIMIT_PER_SECOND then
			return false, "rate_limited"
		end
		controller.combatCount += 1
	end
	for _, listener in controller.listeners do
		listener(action, payload or {})
	end
	return true, nil
end

-- Touch nunca exige mais de dois botões ao mesmo tempo (§3.2). O terceiro
-- ponteiro é ignorado localmente; o servidor ainda aplica o rate limit.
function InputController.touchBegin(
	controller: Controller,
	token: string,
	action: SemanticAction?,
	payload: { [string]: any }?
): (boolean, string?)
	if not controller.touchPressed[token] then
		if controller.touchCount >= 2 then
			return false, "touch_chord_limit"
		end
		controller.touchPressed[token] = true
		controller.touchCount += 1
	end
	if action then
		return InputController.dispatch(controller, action, payload)
	end
	return true, nil
end

function InputController.touchEnd(
	controller: Controller,
	token: string,
	action: SemanticAction?,
	payload: { [string]: any }?
): (boolean, string?)
	if controller.touchPressed[token] then
		controller.touchPressed[token] = nil
		controller.touchCount = math.max(0, controller.touchCount - 1)
	end
	if action then
		return InputController.dispatch(controller, action, payload)
	end
	return true, nil
end

local function platformFromInputType(inputType: any): "KeyboardMouse" | "Touch" | "Gamepad"
	local name = tostring(inputType)
	if string.find(name, "Touch", 1, true) then
		return "Touch"
	end
	if string.find(name, "Gamepad", 1, true) then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

function InputController.start(
	controller: Controller,
	userInputService: any,
	opts: { mouseOnButton: (() -> boolean)? }?
): ()
	controller.state.platform = if userInputService.TouchEnabled and not userInputService.KeyboardEnabled
		then "Touch"
		else "KeyboardMouse"

	local mouseOnButton = if opts then opts.mouseOnButton else nil

	local function dispatch(action: SemanticAction)
		InputController.dispatch(controller, action, {})
	end

	table.insert(
		controller.connections,
		userInputService.LastInputTypeChanged:Connect(function(inputType: any)
			controller.state.platform = platformFromInputType(inputType)
		end)
	)
	table.insert(
		controller.connections,
		userInputService.InputBegan:Connect(function(input: any, processed: boolean)
			local key = input.KeyCode
			local inputType = input.UserInputType
			local isMouseCombat = inputType == Enum.UserInputType.MouseButton1
				or inputType == Enum.UserInputType.MouseButton2
				or inputType == Enum.UserInputType.MouseButton3
			local typing = false
			if userInputService.GetFocusedTextBox then
				typing = userInputService:GetFocusedTextBox() ~= nil
			end
			local onButton = if mouseOnButton then mouseOnButton() else false
			if not InputController.shouldAcceptInput(processed, typing, isMouseCombat, onButton) then
				return
			end
			if inputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
				dispatch("BasicLight")
			elseif inputType == Enum.UserInputType.MouseButton2 or key == Enum.KeyCode.ButtonR1 then
				dispatch("BasicHeavy")
			elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonL2 then
				dispatch("GuardDown")
			elseif key == Enum.KeyCode.Q or (key == Enum.KeyCode.ButtonB and not controller.gamepadModifier) then
				dispatch("Dash")
			elseif key == Enum.KeyCode.One or (key == Enum.KeyCode.ButtonA and controller.gamepadModifier) then
				dispatch("Ability1")
			elseif key == Enum.KeyCode.Two or (key == Enum.KeyCode.ButtonB and controller.gamepadModifier) then
				dispatch("Ability2")
			elseif key == Enum.KeyCode.Three or (key == Enum.KeyCode.ButtonX and controller.gamepadModifier) then
				dispatch("Ability3")
			elseif key == Enum.KeyCode.ButtonL1 then
				controller.gamepadModifier = true
			elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonY then
				dispatch("ZoneHoldDown")
			elseif
				key == Enum.KeyCode.Tab
				or inputType == Enum.UserInputType.MouseButton3
				or key == Enum.KeyCode.ButtonR3
			then
				dispatch("ToggleLock")
			elseif key == Enum.KeyCode.H or key == Enum.KeyCode.F1 or key == Enum.KeyCode.ButtonSelect then
				dispatch("ToggleHelp")
			end
		end)
	)
	table.insert(
		controller.connections,
		userInputService.InputEnded:Connect(function(input: any, processed: boolean)
			local key = input.KeyCode
			-- Uma ação que começou fora da UI precisa sempre poder terminar; caso
			-- contrário guarda/modificador podem ficar presos se outra interface
			-- consumir o release. E/Y é a exceção compartilhada com prompts: quando
			-- processado, não deve emitir ZoneHoldUp colateral.
			if key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonL2 then
				dispatch("GuardUp")
			elseif key == Enum.KeyCode.ButtonL1 then
				controller.gamepadModifier = false
			elseif not processed and (key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonY) then
				dispatch("ZoneHoldUp")
			end
		end)
	)
end

return InputController

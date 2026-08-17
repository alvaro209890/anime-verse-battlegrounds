--!strict
-- HUD F0 retangular, neutro e sem arte. Renderiza o estado dos controllers em
-- até 10 Hz; não chama remotes e não conhece regras de domínio.

local UIController = {}

local BG = Color3.fromRGB(28, 30, 34)
local PANEL = Color3.fromRGB(45, 48, 54)
local TEXT = Color3.fromRGB(240, 240, 236)
local MUTED = Color3.fromRGB(155, 160, 168)
local HEALTH = Color3.fromRGB(188, 198, 190)
local GUARD = Color3.fromRGB(125, 158, 180)
local RESOURCE = Color3.fromRGB(142, 118, 176)

local function frame(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local value = Instance.new("Frame")
	value.Name = name
	value.Size = size
	value.Position = position
	value.BackgroundColor3 = BG
	value.BackgroundTransparency = 0.12
	value.BorderSizePixel = 0
	value.Active = false
	value.Parent = parent
	return value
end

local function label(name: string, parent: Instance, size: UDim2, position: UDim2): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.Size = size
	value.Position = position
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamMedium
	value.TextColor3 = TEXT
	value.TextSize = 14
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = ""
	value.Active = false
	value.Interactable = false
	value.Parent = parent
	return value
end

local function button(name: string, parent: Instance, size: UDim2, position: UDim2): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.Size = size
	value.Position = position
	value.BackgroundColor3 = PANEL
	value.BackgroundTransparency = 0.18
	value.BorderSizePixel = 0
	value.Font = Enum.Font.GothamBold
	value.TextColor3 = TEXT
	value.TextSize = 13
	value.TextWrapped = true
	value.AutoButtonColor = true
	value.Parent = parent
	return value
end

local function makeBar(name: string, parent: Instance, y: number, color: Color3): { [string]: any }
	local track = frame(name, parent, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, y))
	track.BackgroundColor3 = PANEL
	local fill = frame("Fill", track, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0.05
	local text = label("Value", track, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = 3
	return { track = track, fill = fill, text = text }
end

local function truncate48(text: string): string
	local length = utf8.len(text)
	if not length or length <= 48 then
		return text
	end
	local byte = utf8.offset(text, 48)
	return string.sub(text, 1, (byte or #text + 1) - 1) .. "…"
end

function UIController.new(deps: { [string]: any }): any
	local playerGui = deps.player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "F0HUD"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = playerGui

	local status = frame("Vitals", gui, UDim2.fromOffset(310, 86), UDim2.new(0, 18, 1, -104))
	local healthBar = makeBar("Health", status, 7, HEALTH)
	local guardBar = makeBar("Guard", status, 32, GUARD)
	local resourceBar = makeBar("Resource", status, 57, RESOURCE)

	local zone = label("Zone", gui, UDim2.fromOffset(520, 30), UDim2.new(0.5, -260, 0, 16))
	zone.BackgroundColor3 = BG
	zone.BackgroundTransparency = 0.15
	zone.TextXAlignment = Enum.TextXAlignment.Center
	zone.TextSize = 16
	local objective = label("Objective", gui, UDim2.fromOffset(520, 26), UDim2.new(0.5, -260, 0, 50))
	objective.BackgroundColor3 = BG
	objective.BackgroundTransparency = 0.25
	objective.TextXAlignment = Enum.TextXAlignment.Center
	local feedback = label("Feedback", gui, UDim2.fromOffset(420, 36), UDim2.new(0.5, -210, 0.38, 0))
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextSize = 20
	feedback.Visible = false

	local abilityCluster = frame("Abilities", gui, UDim2.fromOffset(360, 84), UDim2.new(1, -378, 1, -102))
	abilityCluster.BackgroundTransparency = 1
	local abilityViews: { any } = {}
	for slot, abilityId in deps.abilityController.slotIds do
		local slotButton =
			button("Ability" .. slot, abilityCluster, UDim2.fromOffset(112, 78), UDim2.fromOffset((slot - 1) * 120, 3))
		local cooldown = frame("CooldownRadial", slotButton, UDim2.fromOffset(38, 38), UDim2.new(1, -43, 0, 5))
		cooldown.BackgroundColor3 = BG
		cooldown.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = cooldown
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.501, 0.75),
			NumberSequenceKeypoint.new(1, 0.75),
		})
		gradient.Parent = cooldown
		local countdown = label("Seconds", cooldown, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
		countdown.TextXAlignment = Enum.TextXAlignment.Center
		countdown.TextSize = 12
		local locked = label("Locked", slotButton, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -19))
		locked.TextXAlignment = Enum.TextXAlignment.Center
		locked.TextColor3 = MUTED
		locked.TextSize = 10
		slotButton.Activated:Connect(function()
			deps.inputApi.dispatch(deps.input, ("Ability%d"):format(slot), {})
		end)
		table.insert(abilityViews, {
			abilityId = abilityId,
			button = slotButton,
			cooldown = cooldown,
			gradient = gradient,
			countdown = countdown,
			locked = locked,
		})
	end

	local touch = frame("TouchControls", gui, UDim2.fromOffset(250, 80), UDim2.new(1, -268, 1, -194))
	touch.BackgroundTransparency = 1
	-- Sem botão de atacar (decisão do Álvaro, 13/08): ataque simples é o clique
	-- do mouse / toque no mundo (InputController dispara BasicLight). A tela
	-- fica limpa; Guard e Dash continuam como botões de apoio no toque.
	local guard = button("Guard", touch, UDim2.fromOffset(76, 58), UDim2.fromOffset(88, 18))
	local dash = button("Dash", touch, UDim2.fromOffset(76, 58), UDim2.fromOffset(4, 18))
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	guard.InputBegan:Connect(function(input: InputObject)
		if not isPointer(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchBegin(deps.input, "guard", "GuardDown", {})
		else
			deps.inputApi.dispatch(deps.input, "GuardDown", {})
		end
	end)
	guard.InputEnded:Connect(function(input: InputObject)
		if not isPointer(input) then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchEnd(deps.input, "guard", "GuardUp", {})
		else
			deps.inputApi.dispatch(deps.input, "GuardUp", {})
		end
	end)
	dash.Activated:Connect(function()
		deps.inputApi.dispatch(deps.input, "Dash", {})
	end)

	local zoneHold = button("ZoneHold", gui, UDim2.fromOffset(300, 42), UDim2.new(0.5, -150, 1, -58))
	zoneHold.Visible = false
	-- Toque e mouse: segurar o botão vale como segurar E. Antes só Touch
	-- disparava, então no PC o botão era decorativo.
	zoneHold.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchBegin(deps.input, "zone", "ZoneHoldDown", {})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			deps.inputApi.dispatch(deps.input, "ZoneHoldDown", {})
		end
	end)
	zoneHold.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchEnd(deps.input, "zone", "ZoneHoldUp", {})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			deps.inputApi.dispatch(deps.input, "ZoneHoldUp", {})
		end
	end)

	local hint = label("Hint", gui, UDim2.fromOffset(520, 22), UDim2.new(0.5, -260, 1, -24))
	hint.BackgroundColor3 = BG
	hint.BackgroundTransparency = 0.25
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextSize = 12
	hint.TextColor3 = MUTED

	local unlockAim = button("UnlockAim", gui, UDim2.fromOffset(220, 40), UDim2.new(0.5, -110, 0, 78))
	unlockAim.Visible = false
	unlockAim.TextSize = 14

	local debugKit = label("DebugKit", gui, UDim2.fromOffset(140, 22), UDim2.fromOffset(18, 16))
	debugKit.BackgroundColor3 = BG
	debugKit.BackgroundTransparency = 0.2
	debugKit.TextXAlignment = Enum.TextXAlignment.Center
	debugKit.TextSize = 11
	debugKit.TextColor3 = MUTED
	debugKit.Visible = false

	local helpButton = button("Help", gui, UDim2.fromOffset(88, 40), UDim2.new(1, -106, 0, 14))
	helpButton.TextSize = 16
	local helpPanel = frame("HelpPanel", gui, UDim2.fromOffset(460, 470), UDim2.new(0.5, -230, 0.5, -235))
	helpPanel.Visible = false
	helpPanel.ZIndex = 20
	local helpTitle = label("Title", helpPanel, UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 8))
	helpTitle.TextSize = 16
	helpTitle.TextXAlignment = Enum.TextXAlignment.Center
	helpTitle.ZIndex = 21
	local HELP_LINE_KEYS = {
		"hud.help_light",
		"hud.help_heavy",
		"hud.help_guard",
		"hud.help_sprint",
		"hud.help_dash",
		"hud.help_ability",
		"hud.help_lock",
		"hud.help_interact",
		"hud.help_gate",
		"hud.settings_where",
	}
	local helpLines: { TextLabel } = {}
	for index, _ in HELP_LINE_KEYS do
		local line =
			label("Line" .. index, helpPanel, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 40 + (index - 1) * 24))
		line.TextSize = 13
		line.ZIndex = 21
		table.insert(helpLines, line)
	end
	-- 10 linhas de ajuda × 24 px + título → botões a partir de y≈280.
	local lockInPanel = button("LockInPanel", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 284))
	lockInPanel.ZIndex = 21
	local shakeToggle = button("ShakeToggle", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 328))
	shakeToggle.ZIndex = 21
	local closeButton = button("Close", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 416))
	closeButton.ZIndex = 21

	local controller = {
		gui = gui,
		state = deps.state,
		stateApi = deps.stateApi,
		locale = deps.locale,
		abilities = deps.abilities,
		abilityController = deps.abilityController,
		abilityApi = deps.abilityApi,
		characterController = deps.characterController,
		characterApi = deps.characterApi,
		combatCamera = deps.combatCamera,
		input = deps.input,
		inputApi = deps.inputApi,
		healthBar = healthBar,
		guardBar = guardBar,
		resourceBar = resourceBar,
		zone = zone,
		objective = objective,
		feedback = feedback,
		abilityViews = abilityViews,
		touch = touch,
		guard = guard,
		dash = dash,
		zoneHold = zoneHold,
		hint = hint,
		unlockAim = unlockAim,
		debugKit = debugKit,
		helpButton = helpButton,
		helpPanel = helpPanel,
		helpTitle = helpTitle,
		helpLines = helpLines,
		helpLineKeys = HELP_LINE_KEYS,
		lockInPanel = lockInPanel,
		shakeToggle = shakeToggle,
		closeButton = closeButton,
		helpVisible = false,
		displayedHealth = 0,
		displayedGuard = 0,
		displayedResource = 0,
		accumulator = 0,
	}

	local function toggleHelp()
		controller.helpVisible = not controller.helpVisible
	end
	local function releaseAim()
		local characterApi = deps.characterApi
		if characterApi and deps.characterController then
			characterApi.clearLock(deps.characterController)
		elseif deps.characterController then
			deps.characterController.lockTarget = nil
		end
	end
	local function toggleShake()
		local camera = deps.combatCamera
		if camera then
			camera.shakeEnabled = camera.shakeEnabled ~= true
		end
	end
	helpButton.Activated:Connect(toggleHelp)
	closeButton.Activated:Connect(function()
		controller.helpVisible = false
	end)
	unlockAim.Activated:Connect(releaseAim)
	lockInPanel.Activated:Connect(function()
		if deps.characterApi and deps.characterController and deps.characterApi.isLocked(deps.characterController) then
			releaseAim()
		elseif deps.inputApi and deps.input then
			deps.inputApi.dispatch(deps.input, "ToggleLock", {})
		end
	end)
	shakeToggle.Activated:Connect(toggleShake)
	if deps.inputApi and deps.input then
		deps.inputApi.subscribe(deps.input, function(action: string, _payload: { [string]: any })
			if action == "ToggleHelp" then
				toggleHelp()
			elseif action == "BasicLight" or action == "BasicHeavy" or action == "Dash" then
				controller.helpVisible = false
			end
		end)
	end

	deps.runService.RenderStepped:Connect(function(delta: number)
		controller.accumulator += delta
		if controller.accumulator < 0.1 then
			return
		end
		local elapsed = controller.accumulator
		controller.accumulator = 0
		UIController.render(controller, elapsed)
	end)
	return controller
end

local function renderBar(view: any, value: number, max: number, text: string): ()
	view.fill.Size = UDim2.fromScale(math.clamp(if max > 0 then value / max else 0, 0, 1), 1)
	view.text.Text = text
end

function UIController.render(controller: any, elapsed: number): ()
	local state = controller.state
	controller.gui.Enabled = state.ready == true
	if not state.ready then
		return
	end
	local localeId = state.locale
	local alpha = math.clamp(elapsed * 8, 0, 1)
	controller.displayedHealth += (state.health - controller.displayedHealth) * alpha
	controller.displayedGuard += (state.guard - controller.displayedGuard) * alpha
	controller.displayedResource += (state.resource - controller.displayedResource) * alpha
	local health = math.floor(controller.displayedHealth + 0.5)
	local guard = math.floor(controller.displayedGuard + 0.5)
	local resource = math.floor(controller.displayedResource + 0.5)
	renderBar(
		controller.healthBar,
		health,
		state.maxHealth,
		controller.locale.format("hud.health", { current = health, max = state.maxHealth }, localeId)
	)
	renderBar(
		controller.guardBar,
		guard,
		state.maxGuard,
		controller.locale.format("hud.guard", { current = guard, max = state.maxGuard }, localeId)
	)
	local resourceText = if state.depleted
		then controller.locale.get("hud.resource_depleted", localeId)
		else controller.locale.format("hud.resource", { current = resource, max = state.maxResource }, localeId)
	renderBar(controller.resourceBar, resource, state.maxResource, resourceText)

	controller.zone.Text = controller.locale.get(if state.pvp then "hud.pvp_active" else "hud.zone_safe", localeId)
	local objective = state.objective
	if objective and objective.state ~= "completed" then
		controller.objective.Text =
			truncate48(controller.locale.format(objective.trackerKey, { n = objective.progress }, localeId))
		controller.objective.Visible = true
	else
		controller.objective.Visible = false
	end
	local feedbackKey = controller.stateApi.feedback(state)
	controller.feedback.Visible = feedbackKey ~= nil
	if feedbackKey then
		controller.feedback.Text = if feedbackKey == "hud.feedback_death_loss"
			then controller.locale.format(feedbackKey, { amount = state.deathPenalty }, localeId)
			else controller.locale.get(feedbackKey, localeId)
	end

	for _, view in controller.abilityViews do
		local ability = controller.abilities.get(view.abilityId)
		local unlocked = controller.abilityApi.isUnlocked(controller.abilityController, view.abilityId)
		view.button.Text = if ability then controller.locale.get(ability.displayNameKey, localeId) else ""
		view.locked.Visible = not unlocked
		view.locked.Text = if unlocked then "" else controller.locale.get("hud.ability_locked", localeId)
		view.button.Active = unlocked
		local remaining = controller.stateApi.cooldownRemaining(state, view.abilityId)
		view.cooldown.Visible = remaining > 0
		if remaining > 0 and ability then
			view.gradient.Rotation = (remaining / ability.cooldown.baseSeconds) * 360
			view.countdown.Text = tostring(math.ceil(remaining))
		end
	end

	controller.touch.Visible = true
	controller.guard.Text = controller.locale.get("hud.control_guard", localeId)
	controller.dash.Text = controller.locale.get("hud.control_dash", localeId)
	-- O prompt de travessia vale em qualquer plataforma. Enquanto era só Touch,
	-- o jogador de PC batia num portão invisível sem nenhuma explicação
	-- (docs/18 §7): o servidor recusava a entrada e ele voltava andando.
	controller.zoneHold.Visible = state.zoneHoldRequired == true
	controller.zoneHold.Text =
		controller.locale.get(if state.platform == "Touch" then "hud.pvp_hold" else "hud.pvp_hold_key", localeId)

	controller.hint.Text = controller.locale.get("hud.help_hint", localeId)
	controller.helpButton.Text = controller.locale.get("hud.menu_button", localeId)
	controller.helpTitle.Text = controller.locale.get("hud.help_title", localeId)
	controller.closeButton.Text = controller.locale.get("hud.settings_close", localeId)
	controller.helpPanel.Visible = controller.helpVisible == true
	for index, key in controller.helpLineKeys do
		controller.helpLines[index].Text = controller.locale.get(key, localeId)
	end

	local lockedOn = false
	if controller.characterApi and controller.characterController then
		lockedOn = controller.characterApi.isLocked(controller.characterController)
	elseif controller.characterController ~= nil then
		lockedOn = controller.characterController.lockTarget ~= nil
	end
	controller.unlockAim.Visible = lockedOn
	controller.unlockAim.Text = controller.locale.get("hud.lock_release", localeId)
	controller.lockInPanel.Text =
		controller.locale.get(if lockedOn then "hud.lock_release" else "hud.lock_engage", localeId)

	local shakeOn = controller.combatCamera == nil or controller.combatCamera.shakeEnabled ~= false
	controller.shakeToggle.Text =
		controller.locale.get(if shakeOn then "hud.settings_shake_on" else "hud.settings_shake_off", localeId)

	local debugKit = controller.abilityApi.isUnlocked(controller.abilityController, "comet_shoulder")
		and controller.abilityApi.isUnlocked(controller.abilityController, "broken_cadence")
		and controller.abilityApi.isUnlocked(controller.abilityController, "pulse_return")
	controller.debugKit.Visible = debugKit
	if debugKit then
		controller.debugKit.Text = controller.locale.get("hud.debug_kit", localeId)
	end
end

return UIController

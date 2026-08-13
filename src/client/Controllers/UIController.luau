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
	local attack = button("Attack", touch, UDim2.fromOffset(78, 68), UDim2.fromOffset(172, 8))
	local guard = button("Guard", touch, UDim2.fromOffset(76, 58), UDim2.fromOffset(88, 18))
	local dash = button("Dash", touch, UDim2.fromOffset(76, 58), UDim2.fromOffset(4, 18))
	local attackStartedAt = 0
	attack.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			attackStartedAt = os.clock()
			deps.inputApi.touchBegin(deps.input, "attack", nil, {})
		end
	end)
	attack.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			local action = if os.clock() - attackStartedAt >= 0.35 then "BasicHeavy" else "BasicLight"
			deps.inputApi.touchEnd(deps.input, "attack", action, {})
		end
	end)
	guard.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchBegin(deps.input, "guard", "GuardDown", {})
		end
	end)
	guard.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchEnd(deps.input, "guard", "GuardUp", {})
		end
	end)
	dash.Activated:Connect(function()
		deps.inputApi.dispatch(deps.input, "Dash", {})
	end)

	local zoneHold = button("ZoneHold", gui, UDim2.fromOffset(280, 42), UDim2.new(0.5, -140, 1, -58))
	zoneHold.Visible = false
	zoneHold.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchBegin(deps.input, "zone", "ZoneHoldDown", {})
		end
	end)
	zoneHold.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			deps.inputApi.touchEnd(deps.input, "zone", "ZoneHoldUp", {})
		end
	end)

	local controller = {
		gui = gui,
		state = deps.state,
		stateApi = deps.stateApi,
		locale = deps.locale,
		abilities = deps.abilities,
		abilityController = deps.abilityController,
		abilityApi = deps.abilityApi,
		healthBar = healthBar,
		guardBar = guardBar,
		resourceBar = resourceBar,
		zone = zone,
		objective = objective,
		feedback = feedback,
		abilityViews = abilityViews,
		touch = touch,
		attack = attack,
		guard = guard,
		dash = dash,
		zoneHold = zoneHold,
		displayedHealth = 0,
		displayedGuard = 0,
		displayedResource = 0,
		accumulator = 0,
	}

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

	local touchVisible = state.platform == "Touch"
	controller.touch.Visible = touchVisible
	controller.attack.Text = controller.locale.get("hud.control_attack", localeId)
	controller.guard.Text = controller.locale.get("hud.control_guard", localeId)
	controller.dash.Text = controller.locale.get("hud.control_dash", localeId)
	controller.zoneHold.Visible = touchVisible and state.zoneHoldRequired
	controller.zoneHold.Text = controller.locale.get("hud.pvp_hold", localeId)
end

return UIController

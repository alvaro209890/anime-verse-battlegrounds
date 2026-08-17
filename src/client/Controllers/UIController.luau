--!strict
-- HUD F0 retangular, neutro e sem arte. Renderiza o estado dos controllers em
-- até 10 Hz; não chama remotes e não conhece regras de domínio.

local LevelUpPlayer = require(script.Parent.Parent.Presentation.LevelUpPlayer)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiPalette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("UiPalette"))

local UIController = {}

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local BG = rgb(UiPalette.ink)
local PANEL = rgb(UiPalette.panel)
local TEXT = rgb(UiPalette.text)
local MUTED = rgb(UiPalette.muted)
local HEALTH = rgb(UiPalette.health)
local GUARD = rgb(UiPalette.guard)
local RESOURCE = rgb(UiPalette.resource)

local function corner(parent: Instance, px: number): UICorner
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, px)
	value.Parent = parent
	return value
end

local function stroke(parent: Instance, color: { number }, thickness: number): UIStroke
	local value = Instance.new("UIStroke")
	value.Color = rgb(color)
	value.Thickness = thickness
	value.Transparency = 0.28
	value.Parent = parent
	return value
end

local function frame(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local value = Instance.new("Frame")
	value.Name = name
	value.Size = size
	value.Position = position
	value.BackgroundColor3 = BG
	value.BackgroundTransparency = 0.08
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
	value.BackgroundTransparency = 0.08
	value.BorderSizePixel = 0
	value.Font = Enum.Font.GothamBold
	value.TextColor3 = TEXT
	value.TextSize = 13
	value.TextWrapped = true
	value.AutoButtonColor = true
	value.Parent = parent
	corner(value, 8)
	stroke(value, UiPalette.strokeAccent, 1)
	return value
end

local function makeBar(name: string, parent: Instance, y: number, color: Color3, ghostColor: Color3?): { [string]: any }
	local track = frame(name, parent, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, y))
	track.BackgroundColor3 = rgb(UiPalette.panelRaised)
	corner(track, 7)
	stroke(track, UiPalette.stroke, 1)
	local ghost = frame("Ghost", track, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	ghost.BackgroundColor3 = ghostColor or rgb(UiPalette.healthGhost)
	ghost.BackgroundTransparency = 0.35
	ghost.ZIndex = 1
	corner(ghost, 7)
	local fill = frame("Fill", track, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0
	fill.ZIndex = 2
	corner(fill, 7)
	local text = label("Value", track, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextStrokeTransparency = 0.35
	text.TextStrokeColor3 = rgb(UiPalette.ink)
	text.ZIndex = 3
	return { track = track, fill = fill, ghost = ghost, ghostFrac = 1, text = text }
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

	local status = frame("Vitals", gui, UDim2.fromOffset(318, 96), UDim2.new(0, 18, 1, -112))
	corner(status, 10)
	stroke(status, UiPalette.strokeAccent, 1.5)
	local healthBar = makeBar("Health", status, 8, HEALTH, rgb(UiPalette.healthGhost))
	local guardBar = makeBar("Guard", status, 36, GUARD, rgb(UiPalette.guardGhost))
	local resourceBar = makeBar("Resource", status, 64, RESOURCE, rgb(UiPalette.strokeAccent))

	local zone = label("Zone", gui, UDim2.fromOffset(520, 32), UDim2.new(0.5, -260, 0, 16))
	zone.BackgroundColor3 = rgb(UiPalette.safe)
	zone.BackgroundTransparency = 0.12
	zone.TextXAlignment = Enum.TextXAlignment.Center
	zone.TextSize = 16
	zone.TextStrokeTransparency = 0.4
	zone.TextStrokeColor3 = rgb(UiPalette.ink)
	corner(zone, 8)
	stroke(zone, UiPalette.stroke, 1)
	local xpBar = makeBar("Xp", gui, 0, rgb(UiPalette.xp), rgb(UiPalette.warning))
	xpBar.track.Size = UDim2.fromOffset(360, 20)
	xpBar.track.Position = UDim2.new(0.5, -180, 0, 48)
	xpBar.track.Parent = gui
	local objective = label("Objective", gui, UDim2.fromOffset(520, 26), UDim2.new(0.5, -260, 0, 72))
	objective.BackgroundColor3 = rgb(UiPalette.panel)
	objective.BackgroundTransparency = 0.12
	objective.TextXAlignment = Enum.TextXAlignment.Center
	corner(objective, 8)
	stroke(objective, UiPalette.strokeAccent, 1)
	local feedback = label("Feedback", gui, UDim2.fromOffset(420, 40), UDim2.new(0.5, -210, 0.38, 0))
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextSize = 20
	feedback.BackgroundColor3 = rgb(UiPalette.panelRaised)
	feedback.BackgroundTransparency = 0.1
	feedback.TextStrokeTransparency = 0.3
	feedback.TextStrokeColor3 = rgb(UiPalette.ink)
	feedback.Visible = false
	corner(feedback, 10)
	stroke(feedback, UiPalette.highlight, 1.5)

	-- Hotbar estilo inventário padrão do Roblox (decisão do Álvaro, 17/08):
	-- slots QUADRADOS numerados, centralizados no rodapé — como nos demais
	-- jogos. As teclas 1/2/3 correspondem aos slots; clicar no slot também
	-- dispara a técnica (e o InputController consome o clique, não o HUD).
	local SLOT_SIZE = 58
	local SLOT_GAP = 8
	local slotCount = #deps.abilityController.slotIds
	local hotbarWidth = slotCount * SLOT_SIZE + (slotCount - 1) * SLOT_GAP
	local abilityCluster =
		frame("Abilities", gui, UDim2.fromOffset(hotbarWidth, SLOT_SIZE), UDim2.new(0.5, -hotbarWidth / 2, 1, -128))
	abilityCluster.BackgroundTransparency = 1
	local abilityViews: { any } = {}
	for slot, abilityId in deps.abilityController.slotIds do
		local slotButton = button(
			"Ability" .. slot,
			abilityCluster,
			UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
			UDim2.fromOffset((slot - 1) * (SLOT_SIZE + SLOT_GAP), 0)
		)
		slotButton.TextSize = 10
		slotButton.BackgroundColor3 = rgb(UiPalette.slot)
		local slotNumber = label("SlotNumber", slotButton, UDim2.fromOffset(18, 16), UDim2.fromOffset(3, 2))
		slotNumber.Text = tostring(slot)
		slotNumber.TextSize = 12
		slotNumber.TextXAlignment = Enum.TextXAlignment.Center
		slotNumber.TextColor3 = MUTED
		local cooldown = frame("CooldownRadial", slotButton, UDim2.fromOffset(42, 42), UDim2.new(0.5, -21, 0.5, -21))
		cooldown.BackgroundColor3 = BG
		cooldown.Visible = false
		local cooldownCorner = Instance.new("UICorner")
		cooldownCorner.CornerRadius = UDim.new(1, 0)
		cooldownCorner.Parent = cooldown
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
		local locked = label("Locked", slotButton, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -13))
		locked.TextXAlignment = Enum.TextXAlignment.Center
		locked.TextColor3 = MUTED
		locked.TextSize = 8
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

	local zoneHold = button("ZoneHold", gui, UDim2.fromOffset(300, 42), UDim2.new(0.5, -150, 1, -178))
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
	hint.BackgroundColor3 = rgb(UiPalette.panel)
	hint.BackgroundTransparency = 0.15
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextSize = 12
	hint.TextColor3 = MUTED
	corner(hint, 8)
	stroke(hint, UiPalette.strokeAccent, 1)

	local unlockAim = button("UnlockAim", gui, UDim2.fromOffset(220, 40), UDim2.new(0.5, -110, 0, 78))
	unlockAim.Visible = false
	unlockAim.TextSize = 14

	local debugKit = label("DebugKit", gui, UDim2.fromOffset(140, 22), UDim2.fromOffset(18, 16))
	debugKit.BackgroundColor3 = rgb(UiPalette.panelRaised)
	debugKit.BackgroundTransparency = 0.1
	debugKit.TextXAlignment = Enum.TextXAlignment.Center
	debugKit.TextSize = 11
	debugKit.TextColor3 = MUTED
	debugKit.Visible = false
	corner(debugKit, 6)

	local careerButton = button("Career", gui, UDim2.fromOffset(88, 40), UDim2.new(1, -388, 0, 14))
	careerButton.TextSize = 13
	local careerPanel = frame("CareerPanel", gui, UDim2.fromOffset(360, 320), UDim2.new(0.5, -180, 0.5, -160))
	careerPanel.Visible = false
	careerPanel.ZIndex = 18
	careerPanel.BackgroundColor3 = rgb(UiPalette.panel)
	corner(careerPanel, 12)
	stroke(careerPanel, UiPalette.stroke, 1.5)
	local careerTitle = label("Title", careerPanel, UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 8))
	careerTitle.TextXAlignment = Enum.TextXAlignment.Center
	careerTitle.ZIndex = 19
	local CAREER_KEYS = {
		{ key = "monsterKills", locale = "hud.career.monsters" },
		{ key = "bossKills", locale = "hud.career.bosses" },
		{ key = "damageDealt", locale = "hud.career.damage" },
		{ key = "playTimeSeconds", locale = "hud.career.time" },
		{ key = "deaths", locale = "hud.career.deaths" },
		{ key = "techniquesUsed", locale = "hud.career.techniques" },
		{ key = "consolidations", locale = "hud.career.consolidations" },
		{ key = "questsCompleted", locale = "hud.career.quests" },
	}
	local careerLines: { TextLabel } = {}
	for index, _ in CAREER_KEYS do
		local line =
			label("C" .. index, careerPanel, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 38 + (index - 1) * 24))
		line.ZIndex = 19
		table.insert(careerLines, line)
	end
	local careerClose = button("CloseCareer", careerPanel, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 280))
	careerClose.ZIndex = 19
	local bagButton = button("Bag", gui, UDim2.fromOffset(88, 40), UDim2.new(1, -294, 0, 14))
	bagButton.TextSize = 14
	local statusButton = button("Status", gui, UDim2.fromOffset(88, 40), UDim2.new(1, -200, 0, 14))
	statusButton.TextSize = 14
	local helpButton = button("Help", gui, UDim2.fromOffset(88, 40), UDim2.new(1, -106, 0, 14))
	local levelFlash = frame("LevelFlash", gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	levelFlash.BackgroundColor3 = rgb(UiPalette.levelFlash)
	levelFlash.BackgroundTransparency = 1
	levelFlash.ZIndex = 40
	levelFlash.Visible = false
	local levelFlashTitle = label("LevelTitle", levelFlash, UDim2.new(1, -40, 0, 64), UDim2.new(0, 20, 0.38, 0))
	levelFlashTitle.TextXAlignment = Enum.TextXAlignment.Center
	levelFlashTitle.TextSize = 42
	levelFlashTitle.TextColor3 = rgb(UiPalette.levelTitle)
	levelFlashTitle.ZIndex = 41
	local bagPanel = frame("BagPanel", gui, UDim2.fromOffset(440, 360), UDim2.new(0.5, -220, 0.5, -180))
	bagPanel.Visible = false
	bagPanel.ZIndex = 18
	bagPanel.BackgroundColor3 = rgb(UiPalette.panel)
	corner(bagPanel, 12)
	stroke(bagPanel, UiPalette.strokeAccent, 1.5)
	local bagTitle = label("Title", bagPanel, UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 8))
	bagTitle.TextXAlignment = Enum.TextXAlignment.Center
	bagTitle.ZIndex = 19
	local bagAbilitiesTitle = label("AbiTitle", bagPanel, UDim2.new(0.5, -16, 0, 20), UDim2.fromOffset(12, 38))
	bagAbilitiesTitle.ZIndex = 19
	local bagItemsTitle = label("ItemTitle", bagPanel, UDim2.new(0.5, -16, 0, 20), UDim2.new(0.5, 4, 0, 38))
	bagItemsTitle.ZIndex = 19
	local bagAbilityLines: { TextLabel } = {}
	for index = 1, 4 do
		local line =
			label("Abi" .. index, bagPanel, UDim2.new(0.5, -20, 0, 22), UDim2.fromOffset(12, 60 + (index - 1) * 24))
		line.TextSize = 13
		line.ZIndex = 19
		table.insert(bagAbilityLines, line)
	end
	local bagItemLines: { TextLabel } = {}
	for index = 1, 8 do
		local line =
			label("It" .. index, bagPanel, UDim2.new(0.5, -20, 0, 20), UDim2.new(0.5, 4, 0, 60 + (index - 1) * 22))
		line.TextSize = 13
		line.ZIndex = 19
		table.insert(bagItemLines, line)
	end
	local bagClose = button("CloseBag", bagPanel, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 318))
	bagClose.ZIndex = 19
	helpButton.TextSize = 16
	local statusPanel = frame("StatusPanel", gui, UDim2.fromOffset(420, 430), UDim2.new(0.5, -210, 0.5, -215))
	statusPanel.Visible = false
	statusPanel.ZIndex = 18
	statusPanel.BackgroundColor3 = rgb(UiPalette.panel)
	corner(statusPanel, 12)
	stroke(statusPanel, UiPalette.highlight, 1.5)
	local statusTitle = label("Title", statusPanel, UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 8))
	statusTitle.TextXAlignment = Enum.TextXAlignment.Center
	statusTitle.TextSize = 16
	statusTitle.ZIndex = 19
	local statusPoints = label("Points", statusPanel, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 34))
	statusPoints.TextXAlignment = Enum.TextXAlignment.Center
	statusPoints.TextSize = 13
	statusPoints.TextColor3 = MUTED
	statusPoints.ZIndex = 19
	local TRACKS = { "vitality", "umbral", "impact", "guard", "resonance" }
	local trackViews = {}
	for index, trackId in TRACKS do
		local y = 60 + (index - 1) * 52
		local row = frame("Track_" .. trackId, statusPanel, UDim2.new(1, -20, 0, 46), UDim2.fromOffset(10, y))
		row.BackgroundColor3 = rgb(UiPalette.panelRaised)
		row.ZIndex = 19
		corner(row, 8)
		local name = label("Name", row, UDim2.new(0.42, 0, 0, 20), UDim2.fromOffset(8, 4))
		name.ZIndex = 20
		local fx = label("Fx", row, UDim2.new(0.42, 0, 0, 16), UDim2.fromOffset(8, 24))
		fx.TextSize = 12
		fx.TextColor3 = MUTED
		fx.ZIndex = 20
		local value = label("Value", row, UDim2.fromOffset(36, 28), UDim2.new(1, -92, 0, 8))
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.TextSize = 18
		value.ZIndex = 20
		local plus = button("Plus", row, UDim2.fromOffset(36, 32), UDim2.new(1, -48, 0, 7))
		plus.Text = "+"
		plus.TextSize = 20
		plus.ZIndex = 20
		plus.Activated:Connect(function()
			if deps.onSpend then
				deps.onSpend(trackId)
			end
		end)
		table.insert(trackViews, {
			id = trackId,
			name = name,
			fx = fx,
			value = value,
			plus = plus,
		})
	end
	local respecButton = button("Respec", statusPanel, UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 328))
	respecButton.ZIndex = 19
	respecButton.Activated:Connect(function()
		if deps.onSpend then
			deps.onSpend("respec")
		end
	end)
	local statusHint = label("Hint", statusPanel, UDim2.new(1, -16, 0, 48), UDim2.fromOffset(8, 366))
	statusHint.TextWrapped = true
	statusHint.TextSize = 12
	statusHint.TextColor3 = MUTED
	statusHint.ZIndex = 19
	local statusClose = button("CloseStatus", statusPanel, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 390))
	statusClose.ZIndex = 19
	local helpPanel = frame("HelpPanel", gui, UDim2.fromOffset(460, 500), UDim2.new(0.5, -230, 0.5, -250))
	helpPanel.Visible = false
	helpPanel.ZIndex = 20
	helpPanel.BackgroundColor3 = rgb(UiPalette.panel)
	corner(helpPanel, 12)
	stroke(helpPanel, UiPalette.stroke, 1.5)
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
		"hud.help_status",
		"hud.help_bag",
		"hud.help_career",
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
	local lockInPanel = button("LockInPanel", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 308))
	lockInPanel.ZIndex = 21
	local shakeToggle = button("ShakeToggle", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 352))
	shakeToggle.ZIndex = 21
	local closeButton = button("Close", helpPanel, UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 440))
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
		xpBar = xpBar,
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
		careerButton = careerButton,
		careerPanel = careerPanel,
		careerTitle = careerTitle,
		careerLines = careerLines,
		careerKeys = CAREER_KEYS,
		careerClose = careerClose,
		careerVisible = false,
		bagButton = bagButton,
		bagPanel = bagPanel,
		bagTitle = bagTitle,
		bagAbilitiesTitle = bagAbilitiesTitle,
		bagItemsTitle = bagItemsTitle,
		bagAbilityLines = bagAbilityLines,
		bagItemLines = bagItemLines,
		bagClose = bagClose,
		bagVisible = false,
		levelFlash = levelFlash,
		levelFlashTitle = levelFlashTitle,
		items = deps.items,
		statusButton = statusButton,
		statusPanel = statusPanel,
		statusTitle = statusTitle,
		statusPoints = statusPoints,
		trackViews = trackViews,
		respecButton = respecButton,
		statusHint = statusHint,
		statusClose = statusClose,
		statusVisible = false,
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
		if controller.helpVisible then
			controller.statusVisible = false
		end
	end
	local function toggleStatus()
		controller.statusVisible = not controller.statusVisible
		if controller.statusVisible then
			controller.helpVisible = false
			controller.bagVisible = false
		end
	end
	local function toggleBag()
		controller.bagVisible = not controller.bagVisible
		if controller.bagVisible then
			controller.helpVisible = false
			controller.statusVisible = false
			controller.careerVisible = false
		end
	end
	local function toggleCareer()
		controller.careerVisible = not controller.careerVisible
		if controller.careerVisible then
			controller.helpVisible = false
			controller.statusVisible = false
			controller.bagVisible = false
		end
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
	statusButton.Activated:Connect(toggleStatus)
	statusClose.Activated:Connect(function()
		controller.statusVisible = false
	end)
	bagButton.Activated:Connect(toggleBag)
	careerButton.Activated:Connect(toggleCareer)
	careerClose.Activated:Connect(function()
		controller.careerVisible = false
	end)
	bagClose.Activated:Connect(function()
		controller.bagVisible = false
	end)
	if deps.inputApi and deps.input then
		deps.inputApi.subscribe(deps.input, function(action: string, _payload: { [string]: any })
			if action == "ToggleHelp" then
				toggleHelp()
			elseif action == "ToggleProgression" then
				toggleStatus()
			elseif action == "ToggleBag" then
				toggleBag()
			elseif action == "ToggleCareer" then
				toggleCareer()
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

local function renderBar(view: any, value: number, max: number, text: string, dt: number): ()
	local current = math.clamp(if max > 0 then value / max else 0, 0, 1)
	view.fill.Size = UDim2.fromScale(current, 1)
	if view.ghost then
		view.ghostFrac = UiPalette.ghostFraction(current, view.ghostFrac or current, dt, 1.35)
		view.ghost.Size = UDim2.fromScale(view.ghostFrac, 1)
	end
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
		controller.locale.format("hud.health", { current = health, max = state.maxHealth }, localeId),
		elapsed
	)
	renderBar(
		controller.guardBar,
		guard,
		state.maxGuard,
		controller.locale.format("hud.guard", { current = guard, max = state.maxGuard }, localeId),
		elapsed
	)
	local resourceText = if state.depleted
		then controller.locale.get("hud.resource_depleted", localeId)
		else controller.locale.format("hud.resource", { current = resource, max = state.maxResource }, localeId)
	renderBar(controller.resourceBar, resource, state.maxResource, resourceText, elapsed)

	controller.zone.Text = controller.locale.get(if state.pvp then "hud.pvp_active" else "hud.zone_safe", localeId)
	local zoneRgb = UiPalette.zoneFill(state.pvp == true)
	controller.zone.BackgroundColor3 = rgb(zoneRgb)
	local into = state.xpIntoLevel or 0
	local need = state.xpToNext or 0
	local levelText = controller.locale.format("hud.level", { level = state.accountLevel or 1 }, localeId)
	local xpText = if need > 0
		then levelText .. "  " .. controller.locale.format("hud.xp_bar", { into = into, need = need }, localeId)
		else levelText
	if (state.unconsolidatedXp or 0) > 0 then
		xpText = xpText
			.. "  "
			.. controller.locale.format("hud.xp_field", { amount = state.unconsolidatedXp }, localeId)
	end
	renderBar(controller.xpBar, into, math.max(need, 1), xpText, elapsed)
	controller.statusButton.Text = controller.locale.get("hud.status_button", localeId)
	controller.statusButton.BackgroundColor3 = if (state.unspentPoints or 0) > 0
			or (state.pendingLevels or 0) > 0
		then rgb(UiPalette.xp)
		else PANEL
	controller.statusPanel.Visible = controller.statusVisible == true
	if controller.statusVisible then
		controller.statusTitle.Text = controller.locale.get("hud.status_title", localeId)
		controller.statusPoints.Text = if (state.unspentPoints or 0) > 0
			then controller.locale.format("hud.status_points", { n = state.unspentPoints }, localeId)
			else controller.locale.get("hud.status_no_points", localeId)
		local spent = state.spent or {}
		for _, view in controller.trackViews do
			local points = spent[view.id] or 0
			view.name.Text = controller.locale.get("hud.track." .. view.id, localeId)
			view.value.Text = tostring(points)
			local fxAmount = if view.id == "impact" or view.id == "resonance"
				then math.floor(points * 0.06 * 10 + 0.5) / 10
				else points * 2
			view.fx.Text = controller.locale.format("hud.track." .. view.id .. ".fx", { n = fxAmount }, localeId)
			view.plus.Visible = (state.unspentPoints or 0) > 0
		end
		controller.respecButton.Text = controller.locale.get("hud.status_respec", localeId)
		controller.statusClose.Text = controller.locale.get("hud.settings_close", localeId)
		local pending = state.pendingLevels or 0
		if pending > 1 then
			controller.statusHint.Text = controller.locale.format("hud.xp_ready_many", { levels = pending }, localeId)
		elseif pending == 1 then
			controller.statusHint.Text = controller.locale.format("hud.xp_ready", { levels = 1 }, localeId)
		else
			controller.statusHint.Text = controller.locale.get("hud.help_status", localeId)
		end
	end
	local objective = state.objective
	if objective and objective.state ~= "completed" then
		controller.objective.Text = truncate48(controller.locale.format(objective.trackerKey, {
			n = objective.progress,
			req = objective.required,
			xp = objective.xpReward or 0,
		}, localeId))
		controller.objective.Visible = true
	else
		controller.objective.Visible = false
	end
	controller.careerButton.Text = controller.locale.get("hud.career_button", localeId)
	controller.careerPanel.Visible = controller.careerVisible == true
	if controller.careerVisible then
		controller.careerTitle.Text = controller.locale.get("hud.career_title", localeId)
		controller.careerClose.Text = controller.locale.get("hud.settings_close", localeId)
		local career = state.career or {}
		for index, spec in controller.careerKeys do
			local value = career[spec.key] or 0
			local shown = tostring(value)
			if spec.key == "playTimeSeconds" then
				local total = math.max(0, math.floor(value))
				local hours = math.floor(total / 3600)
				local minutes = math.floor((total % 3600) / 60)
				local secs = total % 60
				shown = if hours > 0
					then ("%dh %02dm"):format(hours, minutes)
					elseif minutes > 0 then ("%dm %02ds"):format(minutes, secs)
					else ("%ds"):format(secs)
			end
			controller.careerLines[index].Text = controller.locale.get(spec.locale, localeId) .. "  " .. shown
		end
	end
	controller.bagButton.Text = controller.locale.get("hud.bag_button", localeId)
	controller.bagPanel.Visible = controller.bagVisible == true
	if controller.bagVisible then
		controller.bagTitle.Text = controller.locale.get("hud.bag_title", localeId)
		controller.bagAbilitiesTitle.Text = controller.locale.get("hud.bag_abilities", localeId)
		controller.bagItemsTitle.Text = controller.locale.get("hud.bag_items", localeId)
		controller.bagClose.Text = controller.locale.get("hud.settings_close", localeId)
		for index, line in controller.bagAbilityLines do
			local view = controller.abilityViews[index]
			if view then
				local ability = controller.abilities.get(view.abilityId)
				local unlocked = controller.abilityApi.isUnlocked(controller.abilityController, view.abilityId)
				local name = if ability then controller.locale.get(ability.displayNameKey, localeId) else view.abilityId
				line.Text = if unlocked
					then name
					else (name .. " — " .. controller.locale.get("hud.bag_locked", localeId))
				line.Visible = true
			else
				line.Visible = false
			end
		end
		local stacks: { { id: string, count: number } } = {}
		for itemId, count in state.inventory or {} do
			table.insert(stacks, { id = itemId, count = count })
		end
		table.sort(stacks, function(a, b)
			return a.id < b.id
		end)
		if #stacks == 0 then
			controller.bagItemLines[1].Text = controller.locale.get("hud.bag_empty", localeId)
			controller.bagItemLines[1].Visible = true
			for index = 2, #controller.bagItemLines do
				controller.bagItemLines[index].Visible = false
			end
		else
			for index, line in controller.bagItemLines do
				local stack = stacks[index]
				if stack then
					local itemName = stack.id
					if controller.items and controller.items.get then
						local def = controller.items.get(stack.id)
						if def then
							itemName = controller.locale.get(def.displayNameKey, localeId)
						end
					end
					line.Text = ("%s  ×%d"):format(itemName, stack.count)
					line.Visible = true
				else
					line.Visible = false
				end
			end
		end
	end
	local flashLeft = (state.levelUpUntil or 0) - state.now()
	if flashLeft > 0 then
		local flashElapsed = LevelUpPlayer.DURATION - flashLeft
		local flashAlpha = LevelUpPlayer.flashAlpha(flashElapsed, LevelUpPlayer.DURATION)
		controller.levelFlash.Visible = true
		controller.levelFlash.BackgroundTransparency = 1 - flashAlpha * 0.55
		controller.levelFlashTitle.Text = controller.locale.format(
			"hud.feedback_level_up",
			{ level = state.accountLevel, points = state.pointsGranted },
			localeId
		)
		controller.levelFlashTitle.TextTransparency = 1 - flashAlpha
	else
		controller.levelFlash.Visible = false
	end
	local feedbackKey = controller.stateApi.feedback(state)
	controller.feedback.Visible = feedbackKey ~= nil
	if feedbackKey then
		controller.feedback.Text = if feedbackKey == "hud.feedback_death_loss"
			then controller.locale.format(feedbackKey, { amount = state.deathPenalty }, localeId)
			elseif feedbackKey == "hud.feedback_level_up" then controller.locale.format(
				feedbackKey,
				{ level = state.accountLevel, points = state.pointsGranted },
				localeId
			)
			else controller.locale.get(feedbackKey, localeId)
	end

	for _, view in controller.abilityViews do
		local ability = controller.abilities.get(view.abilityId)
		local unlocked = controller.abilityApi.isUnlocked(controller.abilityController, view.abilityId)
		view.button.Text = if ability then controller.locale.get(ability.displayNameKey, localeId) else ""
		view.locked.Visible = not unlocked
		view.locked.Text = if unlocked then "" else controller.locale.get("hud.ability_locked", localeId)
		view.button.Active = unlocked
		view.button.BackgroundColor3 = if unlocked then rgb(UiPalette.slot) else rgb(UiPalette.slotLocked)
		local slotStroke = view.button:FindFirstChildOfClass("UIStroke")
		if slotStroke then
			local ready = unlocked and controller.stateApi.cooldownRemaining(state, view.abilityId) <= 0
			local accent = if ready then UiPalette.slotReady else UiPalette.strokeAccent
			slotStroke.Color = rgb(accent)
			slotStroke.Transparency = if ready then 0.05 else 0.4
		end
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

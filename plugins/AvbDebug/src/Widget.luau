--!nonstrict
-- Painel do plugin: estado da ponte, últimos comandos e cauda do Output.
-- Serve pro humano ver o que o agente está fazendo (e usar sem agente nenhum).

local Widget = {}
Widget.__index = Widget

local COLORS = {
	background = Color3.fromRGB(30, 32, 38),
	panel = Color3.fromRGB(40, 43, 50),
	text = Color3.fromRGB(225, 228, 235),
	muted = Color3.fromRGB(150, 156, 168),
	ok = Color3.fromRGB(120, 210, 140),
	off = Color3.fromRGB(215, 120, 120),
	warning = Color3.fromRGB(235, 200, 110),
	error = Color3.fromRGB(240, 130, 130),
}

local function makeButton(parent: Instance, text: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Button_" .. text
	button.Size = UDim2.new(1, 0, 0, 24)
	button.BackgroundColor3 = COLORS.panel
	button.BorderSizePixel = 0
	button.TextColor3 = COLORS.text
	button.TextSize = 13
	button.Font = Enum.Font.SourceSans
	button.Text = text
	button.LayoutOrder = order
	button.Parent = parent
	return button
end

function Widget.new(plugin: Plugin, actions: { [string]: () -> () })
	local self = setmetatable({}, Widget)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 460, 260, 320)
	local gui = plugin:CreateDockWidgetPluginGui("AvbDebugPanel", info)
	gui.Title = "AVB Debug"
	gui.Name = "AvbDebugPanel"
	self.gui = gui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = COLORS.background
	root.BorderSizePixel = 0
	root.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = root

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 34)
	status.BackgroundTransparency = 1
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.Font = Enum.Font.SourceSansBold
	status.TextSize = 14
	status.TextColor3 = COLORS.muted
	status.Text = "Ponte: iniciando..."
	status.LayoutOrder = 1
	status.Parent = root
	self.status = status

	local order = 2
	for _, entry in
		{
			{ label = "Ligar/desligar ponte", action = "toggleBridge" },
			{ label = "Validar greybox", action = "greybox" },
			{ label = "Checar sourcemap", action = "sourcemap" },
			{ label = "Limpar log do painel", action = "clear" },
		}
	do
		local button = makeButton(root, entry.label, order)
		local handler = actions[entry.action]
		if handler then
			button.Activated:Connect(handler)
		end
		order += 1
	end

	local logTitle = Instance.new("TextLabel")
	logTitle.Size = UDim2.new(1, 0, 0, 18)
	logTitle.BackgroundTransparency = 1
	logTitle.TextXAlignment = Enum.TextXAlignment.Left
	logTitle.Font = Enum.Font.SourceSansBold
	logTitle.TextSize = 13
	logTitle.TextColor3 = COLORS.muted
	logTitle.Text = "Output capturado"
	logTitle.LayoutOrder = order
	logTitle.Parent = root
	order += 1

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -160)
	scroll.BackgroundColor3 = COLORS.panel
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.LayoutOrder = order
	scroll.Parent = root
	self.scroll = scroll

	local logLayout = Instance.new("UIListLayout")
	logLayout.Padding = UDim.new(0, 2)
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Parent = scroll

	self.logCount = 0
	return self
end

function Widget:setStatus(text: string, online: boolean)
	self.status.Text = text
	self.status.TextColor3 = if online then COLORS.ok else COLORS.off
end

function Widget:appendLog(level: string, message: string)
	self.logCount += 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextColor3 = COLORS[level] or COLORS.text
	label.Text = message
	label.LayoutOrder = self.logCount
	label.Parent = self.scroll

	-- Mantém o painel leve: 120 linhas.
	local children = self.scroll:GetChildren()
	if #children > 122 then
		for _, child in children do
			if child:IsA("TextLabel") and child.LayoutOrder <= self.logCount - 120 then
				child:Destroy()
			end
		end
	end
end

function Widget:clear()
	for _, child in self.scroll:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	self.logCount = 0
end

function Widget:toggle()
	self.gui.Enabled = not self.gui.Enabled
end

return Widget

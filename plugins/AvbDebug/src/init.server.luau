--!nonstrict
-- AVB Debug Bridge — plugin de debug do Anime Verse Battlegrounds.
--
-- Objetivo: qualquer agente (Claude, Cursor, Codex, Grok) consegue inspecionar
-- o Studio sem o humano copiar texto do Output. O plugin conversa só com o
-- bridge local (scripts/debug-bridge.luau em 127.0.0.1) — nunca com a rede.
--
-- Fluxo: agente -> CLI (scripts/avb-debug.luau) -> bridge -> plugin (poll)
--        plugin -> resultado + Output capturado -> bridge -> agente.
--
-- Doc: docs/19-DEBUG-BRIDGE.md

local RunService = game:GetService("RunService")

local Bridge = require(script.Bridge)
local Commands = require(script.Commands)
local Config = require(script.Config)
local LogTap = require(script.LogTap)
local Widget = require(script.Widget)

local SESSION_ID = string.format("%d-%d", os.time(), math.random(1000, 9999))

local state = {
	running = true,
	bridgeEnabled = plugin:GetSetting("BridgeEnabled") ~= false,
	lastCommand = "—",
	commandsHandled = 0,
}

local panel

local function log(message: string)
	print("[AvbDebug] " .. message)
end

local function refreshStatus()
	if not panel then
		return
	end
	local line
	if not state.bridgeEnabled then
		line = "Ponte: DESLIGADA (clique para ligar)"
	elseif Bridge.online then
		line = string.format(
			"Ponte: ON %s\nComandos: %d | último: %s",
			Config.bridgeUrl,
			state.commandsHandled,
			state.lastCommand
		)
	else
		line = string.format("Ponte: sem contato com %s\nRode: lune run scripts/debug-bridge.luau", Config.bridgeUrl)
	end
	panel:setStatus(line, state.bridgeEnabled and Bridge.online)
end

-- Executa um comando e devolve o envelope de resultado.
local function execute(command)
	local name = command.command
	local handler = Commands[name]
	state.lastCommand = tostring(name)
	state.commandsHandled += 1

	if type(handler) ~= "function" then
		return {
			id = command.id,
			ok = false,
			error = string.format("comando desconhecido: %s", tostring(name)),
			available = Commands.list().commands,
		}
	end

	local ok, result = pcall(handler, command.args)
	if not ok then
		return { id = command.id, ok = false, error = tostring(result) }
	end
	return { id = command.id, ok = true, command = name, data = result }
end

-- ── UI ──────────────────────────────────────────────────────────────────────

local toolbar = plugin:CreateToolbar("AVB Debug")

local panelButton =
	toolbar:CreateButton("Painel", "Abre o painel do AVB Debug", "rbxasset://textures/ui/GuiImagePlaceholder.png")
panelButton.ClickableWhenViewportHidden = true

local bridgeButton = toolbar:CreateButton(
	"Ponte",
	"Liga/desliga a ponte local com os agentes",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)
bridgeButton.ClickableWhenViewportHidden = true

local greyboxButton = toolbar:CreateButton(
	"Greybox",
	"Valida decoração/âncoras do spawn contra os dados",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)
greyboxButton.ClickableWhenViewportHidden = true

local function runLocal(name: string)
	local ok, result = pcall(Commands[name], {})
	if not ok then
		warn(string.format("[AvbDebug] %s falhou: %s", name, tostring(result)))
		return
	end
	local HttpService = game:GetService("HttpService")
	local encoded = select(
		2,
		pcall(function()
			return HttpService:JSONEncode(result)
		end)
	)
	log(string.format("%s => %s", name, tostring(encoded)))
end

local function toggleBridge()
	state.bridgeEnabled = not state.bridgeEnabled
	plugin:SetSetting("BridgeEnabled", state.bridgeEnabled)
	bridgeButton:SetActive(state.bridgeEnabled)
	log("ponte " .. (state.bridgeEnabled and "ligada" or "desligada"))
	refreshStatus()
end

panel = Widget.new(plugin, {
	toggleBridge = toggleBridge,
	greybox = function()
		runLocal("greybox")
	end,
	sourcemap = function()
		runLocal("sourcemap")
	end,
	clear = function()
		panel:clear()
	end,
})

panelButton.Click:Connect(function()
	panel:toggle()
	panelButton:SetActive(panel.gui.Enabled)
end)
bridgeButton.Click:Connect(toggleBridge)
greyboxButton.Click:Connect(function()
	runLocal("greybox")
end)
bridgeButton:SetActive(state.bridgeEnabled)

-- ── loops ───────────────────────────────────────────────────────────────────

LogTap.start()

task.spawn(function()
	while state.running do
		if state.bridgeEnabled then
			local ok, payload = Bridge.poll()
			if ok and type(payload) == "table" and type(payload.commands) == "table" then
				for _, command in payload.commands do
					local envelope = execute(command)
					Bridge.result(envelope)
				end
			end
			refreshStatus()
			task.wait(if Bridge.online then Config.pollIntervalSeconds else Config.offlineIntervalSeconds)
		else
			refreshStatus()
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while state.running do
		if state.bridgeEnabled and Bridge.online then
			local batch = LogTap.drain(Config.logBatchSize)
			if #batch > 0 then
				Bridge.logs(batch)
			end
		end
		task.wait(Config.logFlushIntervalSeconds)
	end
end)

-- Espelha o Output no painel (independente da ponte).
game:GetService("LogService").MessageOut:Connect(function(message, messageType)
	if not panel then
		return
	end
	local level = "text"
	if messageType == Enum.MessageType.MessageWarning then
		level = "warning"
	elseif messageType == Enum.MessageType.MessageError then
		level = "error"
	end
	panel:appendLog(level, message)
end)

plugin.Unloading:Connect(function()
	state.running = false
	LogTap.stop()
end)

task.spawn(function()
	Bridge.hello({
		sessionId = SESSION_ID,
		version = Config.version,
		placeName = workspace.Name,
		isEdit = RunService:IsEdit(),
		isRunning = RunService:IsRunning(),
	})
	refreshStatus()
end)

log(string.format("v%s carregado (sessão %s). Ponte: %s", Config.version, SESSION_ID, Config.bridgeUrl))

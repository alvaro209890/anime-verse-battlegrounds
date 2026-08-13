--!nonstrict
-- Captura do Output do Studio (edit + playtest) em ring buffer.
-- O plugin continua rodando durante o playtest, então erros de runtime
-- (server e client) caem aqui e chegam ao agente sem ninguém copiar texto.

local LogService = game:GetService("LogService")

local Config = require(script.Parent.Config)

local LEVEL_BY_ENUM = {
	[Enum.MessageType.MessageOutput] = "output",
	[Enum.MessageType.MessageInfo] = "info",
	[Enum.MessageType.MessageWarning] = "warning",
	[Enum.MessageType.MessageError] = "error",
}

local LogTap = {}

LogTap.entries = {} :: { any }
LogTap.pending = {} :: { any }
LogTap.sequence = 0
LogTap.connection = nil :: RBXScriptConnection?

local function push(message: string, level: string)
	LogTap.sequence += 1
	local entry = {
		seq = LogTap.sequence,
		at = os.time(),
		clock = math.round(os.clock() * 1000) / 1000,
		level = level,
		message = message,
	}

	table.insert(LogTap.entries, entry)
	if #LogTap.entries > Config.logBufferSize then
		table.remove(LogTap.entries, 1)
	end

	table.insert(LogTap.pending, entry)
	if #LogTap.pending > Config.logBufferSize then
		table.remove(LogTap.pending, 1)
	end
end

function LogTap.start()
	if LogTap.connection then
		return
	end

	-- Histórico já presente no Output quando o plugin sobe.
	local ok, history = pcall(function()
		return LogService:GetLogHistory()
	end)
	if ok and history then
		local start = math.max(1, #history - Config.logBufferSize + 1)
		for index = start, #history do
			local item = history[index]
			push(item.message, LEVEL_BY_ENUM[item.messageType] or "output")
		end
	end

	LogTap.connection = LogService.MessageOut:Connect(function(message, messageType)
		push(message, LEVEL_BY_ENUM[messageType] or "output")
	end)
end

function LogTap.stop()
	if LogTap.connection then
		LogTap.connection:Disconnect()
		LogTap.connection = nil
	end
end

-- Lote para envio ao bridge; o que sai daqui não volta.
function LogTap.drain(maxItems: number): { any }
	local batch = {}
	local limit = math.min(maxItems, #LogTap.pending)
	for _ = 1, limit do
		table.insert(batch, table.remove(LogTap.pending, 1))
	end
	return batch
end

-- Consulta sem consumir (comando `logs`).
function LogTap.tail(limit: number, level: string?): { any }
	local out = {}
	for index = #LogTap.entries, 1, -1 do
		local entry = LogTap.entries[index]
		if level == nil or level == "all" or entry.level == level then
			table.insert(out, 1, entry)
			if #out >= limit then
				break
			end
		end
	end
	return out
end

return LogTap

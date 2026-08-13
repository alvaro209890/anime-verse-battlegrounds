--!nonstrict
-- Bridge local entre o plugin do Studio e os agentes (docs/19-DEBUG-BRIDGE.md).
--
--   agente -> scripts/avb-debug.luau -> [este servidor] -> plugin AvbDebug
--
-- Escuta só em 127.0.0.1. Não fala com a internet, não guarda credencial.
-- Rodar:  lune run scripts/debug-bridge.luau           (porta padrão 34873)
--         lune run scripts/debug-bridge.luau --port 40000 --no-eval

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local DEFAULT_PORT = 34873
local LOG_DIR = ".avb-debug"
local LOG_FILE = LOG_DIR .. "/studio-log.jsonl"
local STATE_FILE = LOG_DIR .. "/bridge.json"
local MAX_LOG_ENTRIES = 3000
local STUDIO_TIMEOUT_SECONDS = 12

local options = {
	port = DEFAULT_PORT,
	allowEval = true,
	quiet = false,
}

do
	local args = process.args
	local index = 1
	while index <= #args do
		local arg = args[index]
		if arg == "--port" then
			index += 1
			options.port = tonumber(args[index]) or DEFAULT_PORT
		elseif arg == "--no-eval" then
			options.allowEval = false
		elseif arg == "--quiet" then
			options.quiet = true
		end
		index += 1
	end
end

local state = {
	nextId = 1,
	queue = {},
	results = {},
	logs = {},
	logsDirty = false,
	studio = nil,
	studioLastSeen = 0,
	startedAt = os.time(),
}

local function now(): number
	return os.clock()
end

local function say(message: string)
	if not options.quiet then
		print("[bridge] " .. message)
	end
end

local function studioConnected(): boolean
	return state.studio ~= nil and (now() - state.studioLastSeen) < STUDIO_TIMEOUT_SECONDS
end

local function json(value: any, status: number?)
	return {
		status = status or 200,
		headers = { ["Content-Type"] = "application/json" },
		body = serde.encode("json", value),
	}
end

local function decodeBody(body: string?): any
	if body == nil or body == "" then
		return {}
	end
	local ok, decoded = pcall(serde.decode, "json", body)
	if not ok then
		return {}
	end
	return decoded
end

-- ── log em disco ────────────────────────────────────────────────────────────

local function ensureLogDir()
	if not fs.isDir(LOG_DIR) then
		fs.writeDir(LOG_DIR)
	end
end

local function flushLogs()
	if not state.logsDirty then
		return
	end
	state.logsDirty = false
	ensureLogDir()
	local lines = {}
	for _, entry in state.logs do
		table.insert(lines, serde.encode("json", entry))
	end
	fs.writeFile(LOG_FILE, table.concat(lines, "\n") .. "\n")
end

local function writeState()
	ensureLogDir()
	fs.writeFile(
		STATE_FILE,
		serde.encode("json", {
			port = options.port,
			startedAt = state.startedAt,
			studio = state.studio,
			studioConnected = studioConnected(),
			allowEval = options.allowEval,
		}, true)
	)
end

-- ── fila de comandos ────────────────────────────────────────────────────────

local function enqueue(command: string, args: any): number
	local id = state.nextId
	state.nextId += 1
	table.insert(state.queue, { id = id, command = command, args = args })
	return id
end

local function takeQueue(): { any }
	local batch = state.queue
	state.queue = {}
	return batch
end

-- Espera o plugin devolver o resultado (o handler do Lune pode ceder).
local function awaitResult(id: number, timeoutSeconds: number): any?
	local deadline = now() + timeoutSeconds
	while now() < deadline do
		local result = state.results[id]
		if result ~= nil then
			state.results[id] = nil
			return result
		end
		task.wait(0.05)
	end
	return nil
end

-- ── rotas ───────────────────────────────────────────────────────────────────

local routes = {}

routes["GET /health"] = function()
	return json({
		ok = true,
		port = options.port,
		studioConnected = studioConnected(),
		studio = state.studio,
		pending = #state.queue,
		logEntries = #state.logs,
		allowEval = options.allowEval,
		uptimeSeconds = os.time() - state.startedAt,
	})
end

routes["POST /studio/hello"] = function(body)
	state.studio = body
	state.studioLastSeen = now()
	say(string.format("Studio conectado (sessão %s, place %s)", tostring(body.sessionId), tostring(body.placeName)))
	writeState()
	return json({ ok = true, allowEval = options.allowEval })
end

routes["GET /studio/poll"] = function()
	state.studioLastSeen = now()
	if state.studio == nil then
		state.studio = { sessionId = "desconhecida" }
		say("Studio conectado (via poll)")
	end
	return json({ commands = takeQueue() })
end

routes["POST /studio/result"] = function(body)
	state.studioLastSeen = now()
	if body.id ~= nil then
		state.results[body.id] = body
	end
	return json({ ok = true })
end

routes["POST /studio/logs"] = function(body)
	state.studioLastSeen = now()
	local entries = body.entries
	if type(entries) == "table" then
		for _, entry in entries do
			table.insert(state.logs, entry)
		end
		while #state.logs > MAX_LOG_ENTRIES do
			table.remove(state.logs, 1)
		end
		state.logsDirty = true
	end
	return json({ ok = true, stored = #state.logs })
end

-- Chamado pelo CLI: enfileira e espera a resposta do plugin.
routes["POST /command"] = function(body)
	local command = body.command
	if type(command) ~= "string" or command == "" then
		return json({ ok = false, error = "campo 'command' obrigatório" }, 400)
	end
	if command == "eval" and not options.allowEval then
		return json({ ok = false, error = "eval desabilitado neste bridge (--no-eval)" }, 403)
	end
	if not studioConnected() then
		return json({
			ok = false,
			error = "plugin do Studio não conectado: abra o Studio com o plugin AvbDebug instalado e a ponte ligada",
		}, 503)
	end

	local id = enqueue(command, body.args)
	local timeout = tonumber(body.timeoutSeconds) or 15
	local result = awaitResult(id, timeout)
	if result == nil then
		return json({ ok = false, error = string.format("timeout de %ds esperando o Studio responder", timeout) }, 504)
	end
	return json(result)
end

routes["GET /logs"] = function(_body, query)
	local limit = math.min(tonumber(query.limit) or 100, MAX_LOG_ENTRIES)
	local level = query.level
	local out = {}
	for index = #state.logs, 1, -1 do
		local entry = state.logs[index]
		if level == nil or level == "all" or entry.level == level then
			table.insert(out, 1, entry)
			if #out >= limit then
				break
			end
		end
	end
	return json({ entries = out, total = #state.logs, file = LOG_FILE })
end

routes["POST /logs/clear"] = function()
	state.logs = {}
	state.logsDirty = true
	flushLogs()
	return json({ ok = true })
end

local function handle(request)
	local path = request.path
	local key = request.method .. " " .. path
	local route = routes[key]
	if route == nil then
		return json({
			ok = false,
			error = "rota desconhecida: " .. key,
			routes = (function()
				local names = {}
				for name in routes do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end)(),
		}, 404)
	end
	local ok, response = pcall(route, decodeBody(request.body), request.query or {})
	if not ok then
		return json({ ok = false, error = tostring(response) }, 500)
	end
	return response
end

ensureLogDir()
writeState()

local serveOk, serveError = pcall(function()
	net.serve(options.port, {
		address = "http://127.0.0.1",
		handleRequest = handle,
	})
end)
if not serveOk then
	-- Versões antigas do Lune não aceitam `address`; cai para a forma simples.
	net.serve(options.port, handle)
	say("aviso: bind explícito em 127.0.0.1 não suportado por este Lune (" .. tostring(serveError) .. ")")
end

say(string.format("ouvindo em http://127.0.0.1:%d (eval: %s)", options.port, options.allowEval and "on" or "off"))
say("logs do Studio em " .. LOG_FILE .. " — Ctrl+C encerra")

while true do
	task.wait(1)
	flushLogs()
	writeState()
end

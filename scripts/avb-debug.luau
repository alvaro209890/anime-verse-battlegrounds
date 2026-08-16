--!nonstrict
-- CLI de debug do Studio para agentes (docs/19-DEBUG-BRIDGE.md).
-- Fala com o bridge local (scripts/debug-bridge.luau), que fala com o plugin.
--
--   lune run scripts/avb-debug.luau health
--   lune run scripts/avb-debug.luau ping
--   lune run scripts/avb-debug.luau tree Workspace.GreyboxF0 --depth 2
--   lune run scripts/avb-debug.luau props Workspace.GreyboxF0.Anchors.spawn
--   lune run scripts/avb-debug.luau find Workspace --class Humanoid
--   lune run scripts/avb-debug.luau logs --limit 80 --level error
--   lune run scripts/avb-debug.luau eval "return #workspace:GetChildren()"
--   lune run scripts/avb-debug.luau sync
--   lune run scripts/avb-debug.luau evidence          (folha de evidência W1/A1/W2)
--   lune run scripts/avb-debug.luau runbook --gate W1 (só o roteiro, sem Studio)
--   lune run scripts/avb-debug.luau home              (3 passos para quando chegar em casa)
--
-- Saída: JSON no stdout. Exit code 1 quando o comando falha; exit 2 quando o
-- Studio está fora de sync (nada medido nesse estado vale — docs/32 §1).

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Roteiro e critérios do playtest como dado puro (docs/32). Require sem efeito
-- colateral: o módulo é catálogo + decisão, não fala com o Studio.
local StudioEvidence = require("./StudioEvidence")

local DEFAULT_PORT = 34873
local LOG_FILE = ".avb-debug/studio-log.jsonl"

-- Comandos que rodam no plugin (repassados ao Studio).
local STUDIO_COMMANDS = {
	ping = "",
	tree = "path",
	find = "path",
	props = "path",
	select = "path",
	source = "path",
	sourcemap = "",
	-- Buffer do próprio plugin (inclui o Output anterior à conexão da ponte).
	studiologs = "",
	studioerrors = "",
	players = "",
	perf = "",
	greybox = "",
	remotes = "",
	eval = "source",
	list = "",
}

-- Nome no CLI -> nome do comando no plugin.
local STUDIO_ALIASES = {
	studiologs = "logs",
	studioerrors = "errors",
}

local FLAG_ALIASES = {
	class = "className",
	attr = "attribute",
	nodes = "maxNodes",
	from = "fromLine",
	to = "toLine",
}

local BOOL_FLAGS = {
	attributes = true,
	enableLoadstring = true,
	raw = true,
	studio = true,
}

local SOURCE_ROOTS = {
	{ instancePath = "ReplicatedStorage.Shared", repoDir = "src/shared" },
	{ instancePath = "ReplicatedStorage.Shared.vendor", repoDir = "lib/vendor" },
	{ instancePath = "ServerScriptService.Server", repoDir = "src/server" },
	{ instancePath = "StarterPlayer.StarterPlayerScripts.Client", repoDir = "src/client" },
}

-- ── argumentos ──────────────────────────────────────────────────────────────

local function parseArgs()
	local args = process.args
	local parsed = { command = args[1], positional = {}, flags = {} }
	local index = 2
	while index <= #args do
		local arg = args[index]
		if string.sub(arg, 1, 2) == "--" then
			local key = string.sub(arg, 3)
			key = FLAG_ALIASES[key] or key
			local nextArg = args[index + 1]
			if BOOL_FLAGS[key] or nextArg == nil or string.sub(nextArg, 1, 2) == "--" then
				parsed.flags[key] = true
			else
				parsed.flags[key] = tonumber(nextArg) or nextArg
				index += 1
			end
		else
			table.insert(parsed.positional, arg)
		end
		index += 1
	end
	return parsed
end

local function fail(message: string, extra: any?)
	local payload = { ok = false, error = message }
	if extra ~= nil then
		payload.detail = extra
	end
	print(serde.encode("json", payload, true))
	process.exit(1)
end

local function emit(value: any)
	print(serde.encode("json", value, true))
end

-- ── hash (idêntico ao do plugin: Commands.hashSource) ───────────────────────

local function hashSource(source: string): string
	local normalized = string.gsub(source, "\r\n", "\n")
	normalized = string.gsub(normalized, "%s+$", "")
	local hash = 2166136261
	for index = 1, #normalized do
		hash = bit32.bxor(hash, string.byte(normalized, index))
		hash = bit32.band(hash * 16777619, 0xFFFFFFFF)
	end
	return string.format("%08x", hash)
end

-- ── transporte ──────────────────────────────────────────────────────────────

local parsed = parseArgs()
local port = parsed.flags.port or DEFAULT_PORT
local baseUrl = string.format("http://127.0.0.1:%d", port)

-- Token local (alerta 14/08): o bridge gera um token por boot e escreve em
-- .avb-debug/bridge.json; toda rota exige o header X-Avb-Token.
local STATE_FILE = ".avb-debug/bridge.json"

local function readBridgeToken(): string?
	local ok, raw = pcall(fs.readFile, STATE_FILE)
	if not ok then
		return nil
	end
	local decodeOk, decoded = pcall(serde.decode, "json", raw)
	if not decodeOk or type(decoded) ~= "table" then
		return nil
	end
	if type(decoded.token) ~= "string" or decoded.token == "" then
		return nil
	end
	return decoded.token
end

-- Exigido SOB DEMANDA, não no carregamento: `runbook` e `tail` não falam com o
-- Studio e precisam funcionar com o bridge desligado — o runbook existe
-- justamente para preparar a sessão ANTES de abrir o Studio.
local function requireBridgeToken(): string
	local token = readBridgeToken()
	if token == nil then
		fail(
			"bridge sem token: suba o bridge (lune run scripts/debug-bridge.luau) para gerar "
				.. STATE_FILE
				.. " com o X-Avb-Token"
		)
	end
	return token :: string
end

local function call(method: string, path: string, body: any?): (boolean, any)
	local request = {
		url = baseUrl .. path,
		method = method,
		headers = {
			["Content-Type"] = "application/json",
			["X-Avb-Token"] = requireBridgeToken(),
		},
	}
	if body ~= nil then
		request.body = serde.encode("json", body)
	end
	local ok, response = pcall(net.request, request)
	if not ok then
		return false,
			string.format(
				"não consegui falar com o bridge em %s (%s). Suba com: lune run scripts/debug-bridge.luau",
				baseUrl,
				tostring(response)
			)
	end
	local decoded
	local decodeOk, decodeResult = pcall(serde.decode, "json", response.body)
	if decodeOk then
		decoded = decodeResult
	else
		decoded = { raw = response.body }
	end
	if not response.ok then
		return false, decoded
	end
	return true, decoded
end

local function runStudioCommand(command: string, args: any, timeoutSeconds: number?): any
	local ok, response = call("POST", "/command", {
		command = command,
		args = args,
		timeoutSeconds = timeoutSeconds or parsed.flags.timeout or 15,
	})
	if not ok then
		fail("comando falhou", response)
	end
	if response.ok == false then
		fail(tostring(response.error), response)
	end
	return response
end

-- ── comandos locais do CLI ──────────────────────────────────────────────────

local function cmdHealth()
	local ok, response = call("GET", "/health")
	if not ok then
		fail(type(response) == "string" and response or "bridge indisponível", response)
	end
	emit(response)
end

-- Output que o plugin já empurrou para a ponte (não passa pelo Studio, então
-- responde mesmo com o Studio ocupado no meio de um playtest).
local function cmdLogs(level: string?)
	local limit = parsed.flags.limit or 100
	local wanted = level or parsed.flags.level
	local path = string.format("/logs?limit=%d", limit)
	if wanted ~= nil and wanted ~= true then
		path ..= "&level=" .. tostring(wanted)
	end
	local ok, response = call("GET", path)
	if not ok then
		fail(type(response) == "string" and response or "bridge indisponível", response)
	end
	emit(response)
end

local function cmdTail()
	if not fs.isFile(LOG_FILE) then
		fail("sem log em disco ainda: " .. LOG_FILE)
	end
	local limit = parsed.flags.limit or 80
	local lines = string.split(fs.readFile(LOG_FILE), "\n")
	local entries = {}
	for index = #lines, 1, -1 do
		local line = lines[index]
		if line ~= "" then
			local ok, entry = pcall(serde.decode, "json", line)
			if ok then
				table.insert(entries, 1, entry)
			end
		end
		if #entries >= limit then
			break
		end
	end
	emit({ ok = true, file = LOG_FILE, entries = entries })
end

-- Lista arquivos .luau/.lua do repo e o nome de Instance correspondente.
local function collectRepoScripts(dir: string, instancePath: string, out: { [string]: any })
	if not fs.isDir(dir) then
		return
	end
	for _, entry in fs.readDir(dir) do
		local childPath = dir .. "/" .. entry
		if fs.isDir(childPath) then
			collectRepoScripts(childPath, instancePath .. "." .. entry, out)
		elseif fs.isFile(childPath) then
			local name = string.match(entry, "^(.+)%.luau?$")
			if name then
				local targetPath
				if name == "init" or name == "init.server" or name == "init.client" then
					targetPath = instancePath
				else
					targetPath = instancePath .. "." .. name
				end
				out[targetPath] = {
					file = childPath,
					hash = hashSource(fs.readFile(childPath)),
				}
			end
		end
	end
end

local function syncReport()
	local response = runStudioCommand("sourcemap", {}, parsed.flags.timeout or 30)
	local studioScripts = response.data and response.data.scripts or {}

	local repoScripts = {}
	for _, root in SOURCE_ROOTS do
		collectRepoScripts(root.repoDir, root.instancePath, repoScripts)
	end

	local missingInStudio = {}
	local mismatched = {}
	local matched = 0
	for path, repoEntry in repoScripts do
		local studioEntry = studioScripts[path]
		if studioEntry == nil then
			table.insert(missingInStudio, { path = path, file = repoEntry.file })
		elseif studioEntry.hash ~= repoEntry.hash then
			table.insert(mismatched, {
				path = path,
				file = repoEntry.file,
				repoHash = repoEntry.hash,
				studioHash = studioEntry.hash,
				studioLines = studioEntry.lines,
			})
		else
			matched += 1
		end
	end

	local extraInStudio = {}
	for path in studioScripts do
		if repoScripts[path] == nil then
			table.insert(extraInStudio, path)
		end
	end

	table.sort(extraInStudio)
	local inSync = #missingInStudio == 0 and #mismatched == 0
	return {
		ok = true,
		inSync = inSync,
		matched = matched,
		mismatched = mismatched,
		missingInStudio = missingInStudio,
		extraInStudio = extraInStudio,
		hint = if inSync
			then "Studio está rodando exatamente o código do repo."
			else "Rode scripts/build-studio.ps1 (ou rojo serve) e reabra o place — o Studio está com código diferente do repo.",
	}
end

local function cmdSync()
	local report = syncReport()
	emit(report)
	if not report.inSync then
		process.exit(2)
	end
end

-- Atalho de três passos para o PC de casa. Roda com o Studio fechado, de
-- propósito: é o que se cola no PowerShell antes de qualquer medição.
local function cmdHome()
	local ok, reason = StudioEvidence.validate()
	if not ok then
		fail("roteiro inválido: " .. tostring(reason))
	end
	emit({
		ok = true,
		steps = StudioEvidence.homePrep(),
		note = "Uma janela do Studio. O único place é anime-verse-battlegrounds.rbxl. Isto não é evidência de Play.",
		source = "docs/32-STUDIO-PLAYTEST-RUNBOOK.md",
	})
end

-- Roteiro sem Studio: imprime os passos e os limites para preparar a sessão
-- (ou revisar o runbook) sem abrir nada.
local function cmdRunbook()
	local gate = parsed.flags.gate
	local steps = if type(gate) == "string" then StudioEvidence.stepsForGate(gate) else StudioEvidence.steps()
	local ok, reason = StudioEvidence.validate()
	if not ok then
		fail("roteiro inválido: " .. tostring(reason))
	end
	emit({
		ok = true,
		gate = if type(gate) == "string" then gate else "todos",
		steps = steps,
		thresholds = StudioEvidence.thresholds(),
		source = "docs/32-STUDIO-PLAYTEST-RUNBOOK.md",
	})
end

-- Folha de evidência de uma sessão: confere a sincronia PRIMEIRO e só então
-- coleta. Fora de sync sai com exit 2 sem medir nada — a regra que faltava em
-- 14/08, quando três commits ficaram invisíveis porque o Play rodava outro
-- place (docs/12 §2, docs/32 §1).
local function cmdEvidence()
	local sync = syncReport()
	local allowed, syncReason = StudioEvidence.syncGate(sync)
	if not allowed then
		emit({
			ok = false,
			blocked = true,
			reason = syncReason,
			sync = sync,
			hint = "Nada medido nesta sessão vale. Rebuilde o place, reabra e rode de novo.",
		})
		process.exit(2)
	end

	local function collect(command: string): any
		local okCall, response = pcall(runStudioCommand, command, {}, parsed.flags.timeout or 30)
		if not okCall then
			return { ok = false, error = tostring(response) }
		end
		return response.data
	end

	local perf = collect("perf")
	local perfOk, breaches = StudioEvidence.evaluatePerf(perf)
	emit({
		ok = true,
		sync = { inSync = true, matched = sync.matched, reason = syncReason },
		perf = perf,
		perfWithinBudget = perfOk,
		perfBreaches = breaches,
		errors = collect("errors"),
		players = collect("players"),
		greybox = collect("greybox"),
		steps = StudioEvidence.steps(),
		thresholds = StudioEvidence.thresholds(),
		note = "Coleta automatizada NÃO substitui a captura visual de cada passo (docs/32).",
	})
end

local function usage()
	local names = {}
	for name in STUDIO_COMMANDS do
		table.insert(names, name)
	end
	table.sort(names)
	emit({
		ok = false,
		error = "informe um comando",
		studioCommands = names,
		localCommands = { "health", "logs", "errors", "tail", "sync", "runbook", "evidence", "home" },
		examples = {
			"lune run scripts/avb-debug.luau ping",
			"lune run scripts/avb-debug.luau home",
			"lune run scripts/avb-debug.luau runbook --gate W1",
			"lune run scripts/avb-debug.luau evidence",
			"lune run scripts/avb-debug.luau tree Workspace.GreyboxF0 --depth 2",
			"lune run scripts/avb-debug.luau logs --level error --limit 50",
			"lune run scripts/avb-debug.luau sync",
		},
	})
	process.exit(1)
end

-- ── dispatch ────────────────────────────────────────────────────────────────

local command = parsed.command
if command == nil or command == "help" or command == "--help" then
	usage()
elseif command == "health" then
	cmdHealth()
elseif command == "logs" then
	cmdLogs(nil)
elseif command == "errors" then
	cmdLogs("error")
elseif command == "tail" then
	cmdTail()
elseif command == "sync" then
	cmdSync()
elseif command == "runbook" then
	cmdRunbook()
elseif command == "home" then
	cmdHome()
elseif command == "evidence" then
	cmdEvidence()
elseif STUDIO_COMMANDS[command] ~= nil then
	local args = {}
	for key, value in parsed.flags do
		if key ~= "port" and key ~= "timeout" and key ~= "raw" then
			args[key] = value
		end
	end
	local positionalKey = STUDIO_COMMANDS[command]
	if positionalKey ~= "" and parsed.positional[1] ~= nil then
		args[positionalKey] = parsed.positional[1]
	end
	local response = runStudioCommand(STUDIO_ALIASES[command] or command, args)
	emit(if parsed.flags.raw then response else { ok = true, command = command, data = response.data })
else
	fail("comando desconhecido: " .. tostring(command))
end

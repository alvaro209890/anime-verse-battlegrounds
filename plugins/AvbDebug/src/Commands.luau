--!nonstrict
-- Comandos que o agente dispara pelo bridge.
-- Cada comando recebe `args` (tabela vinda do JSON) e devolve uma tabela
-- serializável. Erro = `error("mensagem")`; quem chama embrulha em pcall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local LogTap = require(script.Parent.LogTap)
local Resolve = require(script.Parent.Resolve)
local Serialize = require(script.Parent.Serialize)

local Commands = {}

-- Propriedades tentadas por classe. Ler `instance[prop]` é genérico; o pcall
-- descarta o que não existe naquela classe (não há reflection em runtime).
local PROPERTY_CANDIDATES = {
	"Name",
	"ClassName",
	"Archivable",
	-- BasePart
	"Position",
	"Size",
	"Orientation",
	"Anchored",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"Transparency",
	"Color",
	"Material",
	"CastShadow",
	"CollisionGroup",
	"Massless",
	"AssemblyLinearVelocity",
	-- Model
	"PrimaryPart",
	"WorldPivot",
	-- Humanoid
	"Health",
	"MaxHealth",
	"WalkSpeed",
	"JumpPower",
	"JumpHeight",
	"HipHeight",
	"PlatformStand",
	"AutoRotate",
	-- Valores / GUI
	"Value",
	"Text",
	"Visible",
	"ZIndex",
	"BackgroundTransparency",
	"TextColor3",
	"Enabled",
	"Active",
	-- Luz/efeitos
	"Brightness",
	"Range",
	"Adornee",
	"FillColor",
	"OutlineColor",
	-- Sons
	"SoundId",
	"Volume",
	"Playing",
	"TimePosition",
}

local SOURCE_ROOTS = {
	{ path = "ReplicatedStorage.Shared", repoDir = "src/shared" },
	{ path = "ServerScriptService.Server", repoDir = "src/server" },
	{ path = "StarterPlayer.StarterPlayerScripts.Client", repoDir = "src/client" },
}

-- FNV-1a 32 bits. O CLI (scripts/avb-debug.luau) repete byte a byte a mesma
-- conta sobre o arquivo do repo: hash igual = Studio rodando o código atual.
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

local function countLines(source: string): number
	local _, count = string.gsub(source, "\n", "")
	return count + 1
end

local function mustResolve(path: string?): Instance
	local instance, err = Resolve.instance(path)
	if not instance then
		error(err or ("caminho inválido: " .. tostring(path)))
	end
	return instance
end

local function describe(instance: Instance, includeAttributes: boolean?)
	local node = {
		name = instance.Name,
		className = instance.ClassName,
		path = instance:GetFullName(),
		children = #instance:GetChildren(),
	}
	if instance:IsA("BasePart") then
		node.position = Serialize.vector3(instance.Position)
		node.size = Serialize.vector3(instance.Size)
	elseif instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok then
			node.pivot = Serialize.vector3(pivot.Position)
		end
	end
	if includeAttributes then
		local attributes = instance:GetAttributes()
		if next(attributes) ~= nil then
			node.attributes = Serialize.value(attributes)
		end
	end
	return node
end

-- ── contexto ────────────────────────────────────────────────────────────────

function Commands.ping(_args)
	return {
		plugin = "AvbDebug",
		version = Config.version,
		placeName = Workspace.Name,
		placeId = game.PlaceId,
		studioRunning = RunService:IsRunning(),
		isClient = RunService:IsClient(),
		isServer = RunService:IsServer(),
		isEdit = RunService:IsEdit(),
		f0Debug = game:GetAttribute("F0Debug"),
		greyboxBuilt = Workspace:FindFirstChild("GreyboxF0") ~= nil,
		playerCount = #Players:GetPlayers(),
		serverTime = os.time(),
	}
end

-- ── árvore e propriedades ───────────────────────────────────────────────────

function Commands.tree(args)
	args = args or {}
	local root = mustResolve(args.path)
	local maxDepth = math.min(tonumber(args.depth) or 3, Config.maxDepth)
	local maxNodes = math.min(tonumber(args.maxNodes) or 600, Config.maxTreeNodes)
	local classFilter = args.className
	local visited = 0
	local truncated = false

	local function walk(instance: Instance, depth: number)
		visited += 1
		if visited > maxNodes then
			truncated = true
			return nil
		end
		local node = describe(instance, args.attributes == true)
		if depth < maxDepth then
			local children = {}
			for _, child in instance:GetChildren() do
				if classFilter == nil or child:IsA(classFilter) then
					local built = walk(child, depth + 1)
					if built then
						table.insert(children, built)
					end
				end
			end
			if #children > 0 then
				node.childNodes = children
			end
		end
		return node
	end

	return {
		root = walk(root, 0),
		nodesVisited = visited,
		truncated = truncated,
	}
end

function Commands.find(args)
	args = args or {}
	local root = mustResolve(args.path)
	local limit = math.min(tonumber(args.limit) or 50, 500)
	local namePattern = args.name
	local className = args.className
	local attribute = args.attribute
	local matches = {}

	for _, descendant in root:GetDescendants() do
		if #matches >= limit then
			break
		end
		local ok = true
		if namePattern then
			ok = string.find(string.lower(descendant.Name), string.lower(namePattern), 1, true) ~= nil
		end
		if ok and className then
			local isA = false
			pcall(function()
				isA = descendant:IsA(className)
			end)
			ok = isA
		end
		if ok and attribute then
			ok = descendant:GetAttribute(attribute) ~= nil
		end
		if ok then
			table.insert(matches, describe(descendant, true))
		end
	end

	return { matches = matches, count = #matches, limitReached = #matches >= limit }
end

function Commands.props(args)
	args = args or {}
	local instance = mustResolve(args.path)
	local properties = {}
	local requested = args.keys

	local candidates = PROPERTY_CANDIDATES
	if type(requested) == "table" and #requested > 0 then
		candidates = requested
	end

	for _, key in candidates do
		local ok, value = pcall(function()
			return (instance :: any)[key]
		end)
		if ok and typeof(value) ~= "function" then
			properties[key] = Serialize.value(value)
		end
	end

	local children = {}
	for _, child in instance:GetChildren() do
		table.insert(children, { name = child.Name, className = child.ClassName })
		if #children >= 100 then
			break
		end
	end

	return {
		path = instance:GetFullName(),
		className = instance.ClassName,
		properties = properties,
		attributes = Serialize.value(instance:GetAttributes()),
		children = children,
	}
end

function Commands.select(args)
	args = args or {}
	local paths = args.paths or { args.path }
	local instances = {}
	for _, path in paths do
		table.insert(instances, mustResolve(path))
	end
	Selection:Set(instances)
	return { selected = #instances }
end

-- ── código carregado no Studio ──────────────────────────────────────────────

function Commands.source(args)
	args = args or {}
	local instance = mustResolve(args.path)
	if not instance:IsA("LuaSourceContainer") then
		error(("'%s' é %s, não um script"):format(instance:GetFullName(), instance.ClassName))
	end
	local ok, source = pcall(function()
		return (instance :: any).Source
	end)
	if not ok then
		error("Source indisponível (o plugin precisa de permissão de scripts): " .. tostring(source))
	end

	local fromLine = tonumber(args.fromLine)
	local toLine = tonumber(args.toLine)
	local lines = string.split(source, "\n")
	local slice = source
	if fromLine or toLine then
		local first = math.max(1, fromLine or 1)
		local last = math.min(#lines, toLine or #lines)
		local picked = {}
		for index = first, last do
			table.insert(picked, lines[index])
		end
		slice = table.concat(picked, "\n")
	end

	return {
		path = instance:GetFullName(),
		className = instance.ClassName,
		lines = #lines,
		hash = hashSource(source),
		source = slice,
	}
end

-- Mapa hash-por-script das três raízes do projeto. O CLI compara com o repo
-- e diz se o Studio está rodando código velho (a causa clássica de "corrigi
-- e não mudou nada").
function Commands.sourcemap(_args)
	local roots = {}
	local scripts = {}

	for _, entry in SOURCE_ROOTS do
		local instance = Resolve.instance(entry.path)
		roots[entry.path] = {
			repoDir = entry.repoDir,
			present = instance ~= nil,
		}
		if instance then
			local queue = { instance }
			if instance:IsA("LuaSourceContainer") then
				local ok, source = pcall(function()
					return (instance :: any).Source
				end)
				if ok then
					scripts[instance:GetFullName()] = {
						className = instance.ClassName,
						hash = hashSource(source),
						lines = countLines(source),
						root = entry.path,
					}
				end
			end
			while #queue > 0 do
				local current = table.remove(queue, 1)
				for _, child in current:GetChildren() do
					table.insert(queue, child)
					if child:IsA("LuaSourceContainer") then
						local ok, source = pcall(function()
							return (child :: any).Source
						end)
						if ok then
							scripts[child:GetFullName()] = {
								className = child.ClassName,
								hash = hashSource(source),
								lines = countLines(source),
								root = entry.path,
							}
						end
					end
				end
			end
		end
	end

	local count = 0
	for _ in scripts do
		count += 1
	end

	return { roots = roots, scripts = scripts, scriptCount = count }
end

-- ── output ──────────────────────────────────────────────────────────────────

function Commands.logs(args)
	args = args or {}
	local limit = math.min(tonumber(args.limit) or 100, Config.logBufferSize)
	return { entries = LogTap.tail(limit, args.level), buffered = #LogTap.entries }
end

function Commands.errors(args)
	args = args or {}
	local limit = math.min(tonumber(args.limit) or 40, Config.logBufferSize)
	local warnings = LogTap.tail(limit, "warning")
	local errors = LogTap.tail(limit, "error")
	return { errors = errors, warnings = warnings }
end

-- ── runtime ─────────────────────────────────────────────────────────────────

function Commands.players(_args)
	local out = {}
	for _, player in Players:GetPlayers() do
		local entry = {
			name = player.Name,
			userId = player.UserId,
			attributes = Serialize.value(player:GetAttributes()),
		}
		local character = player.Character
		if character then
			entry.characterAttributes = Serialize.value(character:GetAttributes())
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				entry.health = humanoid.Health
				entry.maxHealth = humanoid.MaxHealth
				entry.walkSpeed = humanoid.WalkSpeed
				entry.state = tostring(humanoid:GetState())
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				entry.position = Serialize.vector3(root.Position)
			end
		end
		table.insert(out, entry)
	end
	return { players = out, count = #out }
end

function Commands.perf(_args)
	local result = {
		running = RunService:IsRunning(),
		instanceCount = #game:GetDescendants(),
		workspaceParts = 0,
	}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") then
			result.workspaceParts += 1
		end
	end
	local ok, stats = pcall(function()
		return game:GetService("Stats")
	end)
	if ok and stats then
		pcall(function()
			result.totalMemoryMb = math.round((stats :: any):GetTotalMemoryUsageMb())
		end)
		pcall(function()
			result.heartbeatTimeMs = math.round((stats :: any).HeartbeatTimeMs * 100) / 100
		end)
		pcall(function()
			result.physicsStepTimeMs = math.round((stats :: any).PhysicsStepTimeMs * 100) / 100
		end)
	end
	return result
end

-- ── específicos do projeto ──────────────────────────────────────────────────

local function requireShared(moduleName: string): (any?, string?)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		return nil, "ReplicatedStorage.Shared não existe (place não buildado?)"
	end
	local data = shared:FindFirstChild("Data")
	local target = (data and data:FindFirstChild(moduleName)) or shared:FindFirstChild(moduleName)
	if not target then
		return nil, ("módulo '%s' não encontrado em Shared"):format(moduleName)
	end
	local ok, moduleOrError = pcall(require, target)
	if not ok then
		return nil, ("require(%s) falhou: %s"):format(moduleName, tostring(moduleOrError))
	end
	return moduleOrError, nil
end

-- Valida as receitas puras (mesma regra dos testes Lune) E confere se o que
-- está no Workspace bate com os dados. Drift entre dado e mundo = bug.
function Commands.greybox(_args)
	local report = { dataErrors = {}, drift = {}, missingParts = {}, notes = {} }

	local decorationsModule, decoError = requireShared("SpawnDecorations")
	local zonesModule, zoneError = requireShared("Zones")
	if not decorationsModule or not zonesModule then
		error(decoError or zoneError)
	end

	local bastion = zonesModule.get("zone_bastion_safe")
	local transition = zonesModule.get("zone_threshold_transition")
	if not bastion or not transition then
		error("zonas zone_bastion_safe/zone_threshold_transition ausentes")
	end

	local anchors = {}
	for _, anchor in zonesModule.allAnchors() do
		table.insert(anchors, anchor.position)
	end

	report.dataErrors =
		decorationsModule.validate(decorationsModule.all(), bastion.volumes[1], transition.volumes, anchors)
	report.decorationCount = #decorationsModule.all()
	report.anchorCount = #anchors

	local root = Workspace:FindFirstChild("GreyboxF0")
	if not root then
		table.insert(
			report.notes,
			"Workspace.GreyboxF0 não existe: o greybox é construído pelo WorldService no boot do servidor — rode um playtest (F5) e repita."
		)
		report.worldBuilt = false
		return report
	end
	report.worldBuilt = true

	local folders = {}
	for _, child in root:GetChildren() do
		folders[child.Name] = #child:GetChildren()
	end
	report.folders = folders

	local decorationFolder = root:FindFirstChild("SpawnDecorations")
	if decorationFolder then
		for _, recipe in decorationsModule.all() do
			local part = decorationFolder:FindFirstChild(recipe.name)
			if not part or not part:IsA("BasePart") then
				table.insert(report.missingParts, recipe.name)
			else
				local expectedPosition = Vector3.new(recipe.position.x, recipe.position.y, recipe.position.z)
				local expectedSize = Vector3.new(recipe.size.x, recipe.size.y, recipe.size.z)
				if
					(part.Position - expectedPosition).Magnitude > 0.05
					or (part.Size - expectedSize).Magnitude > 0.05
				then
					table.insert(report.drift, {
						name = recipe.name,
						expectedPosition = Serialize.vector3(expectedPosition),
						actualPosition = Serialize.vector3(part.Position),
						expectedSize = Serialize.vector3(expectedSize),
						actualSize = Serialize.vector3(part.Size),
					})
				end
			end
		end
	else
		table.insert(report.notes, "GreyboxF0.SpawnDecorations não existe")
	end

	local anchorFolder = root:FindFirstChild("Anchors")
	if anchorFolder then
		local missingAnchors = {}
		for _, anchor in zonesModule.allAnchors() do
			if not anchorFolder:FindFirstChild(anchor.id) then
				table.insert(missingAnchors, anchor.id)
			end
		end
		report.missingAnchors = missingAnchors
	end

	report.ok = #report.dataErrors == 0 and #report.drift == 0 and #report.missingParts == 0
	return report
end

-- Confere os RemoteEvents materializados contra o registro de contratos.
function Commands.remotes(_args)
	local contractsModule, err = requireShared("Remotes")
	if not contractsModule then
		error(err)
	end

	-- src/shared/Remotes.luau exporta { Names, Contracts }, com Contracts.all().
	local declared = {}
	local contracts = contractsModule.Contracts
	if type(contracts) ~= "table" or type(contracts.all) ~= "function" then
		error("Remotes.Contracts.all() não existe — contrato do módulo mudou?")
	end
	for _, contract in contracts.all() do
		declared[tostring(contract.name)] = Serialize.value(contract)
	end

	local live = {}
	for _, descendant in ReplicatedStorage:GetDescendants() do
		if
			descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction")
			or descendant:IsA("UnreliableRemoteEvent")
		then
			live[descendant.Name] = { className = descendant.ClassName, path = descendant:GetFullName() }
		end
	end

	local missingInStudio = {}
	for name in declared do
		if live[name] == nil then
			table.insert(missingInStudio, name)
		end
	end
	local undeclared = {}
	for name in live do
		if declared[name] == nil then
			table.insert(undeclared, name)
		end
	end

	return {
		declared = declared,
		live = live,
		missingInStudio = missingInStudio,
		undeclared = undeclared,
		note = "Remotes só existem depois do boot do servidor (playtest).",
	}
end

-- ── eval ────────────────────────────────────────────────────────────────────

-- Executa Luau no contexto do plugin. Depende de loadstring, que o Studio
-- só libera com ServerScriptService.LoadStringEnabled = true.
function Commands.eval(args)
	args = args or {}
	local source = args.source
	if type(source) ~= "string" or source == "" then
		error("eval exige args.source (string)")
	end

	if not ServerScriptService.LoadStringEnabled then
		if args.enableLoadstring == true and RunService:IsEdit() then
			local ok = pcall(function()
				ServerScriptService.LoadStringEnabled = true
			end)
			if not ok then
				error("LoadStringEnabled está desligado e não pôde ser ligado automaticamente")
			end
		else
			error(
				"ServerScriptService.LoadStringEnabled = false. Ligue a propriedade no Studio (ou mande enableLoadstring=true em modo edição) para usar eval."
			)
		end
	end

	local chunk, compileError = loadstring(source, "avb-eval")
	if not chunk then
		error("erro de compilação: " .. tostring(compileError))
	end

	local printed = {}
	local env = getfenv(chunk)
	local sandbox = setmetatable({
		print = function(...)
			local parts = {}
			for index = 1, select("#", ...) do
				table.insert(parts, tostring(select(index, ...)))
			end
			table.insert(printed, table.concat(parts, " "))
		end,
	}, { __index = env, __newindex = env })
	setfenv(chunk, sandbox)

	local results = table.pack(pcall(chunk))
	if not results[1] then
		error("erro em runtime: " .. tostring(results[2]))
	end

	local returned = {}
	for index = 2, results.n do
		table.insert(returned, Serialize.value(results[index]))
	end

	return { printed = printed, returned = returned }
end

function Commands.list(_args)
	local names = {}
	for name in Commands do
		table.insert(names, name)
	end
	table.sort(names)
	return { commands = names }
end

return Commands

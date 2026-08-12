--!strict
-- Harness de teste — F0
-- O Lune não injeta `script`/`game` em módulos. Este harness define:
--   * _G.script  → Parent com __index que resolve require(script.Parent.X)
--                  para caminho real no filesystem (src/shared)
--   * _G.game    → GetService mínimo (ReplicatedStorage/Players)
--   * _G.Instance → new/FindFirstChild/WaitForChild mínimos
--   * _G.require → wrapper que converte tabelas mock em require real
--
-- Uso: lune run tests/run.luau

local srcSharedDir = "./src/shared"

-- ── Folder mock: resolve script.Parent.X → caminho real ───────────────────
local FolderMT = {}
FolderMT.__index = function(self, key)
	local dir = rawget(self, "__dir")
	local function exists(p: string): boolean
		local f = io.open(p, "r")
		if f then
			f:close()
			return true
		end
		return false
	end
	local candidates = {
		dir .. "/" .. key .. ".lua",
		dir .. "/" .. key .. ".luau",
		dir .. "/" .. key .. "/init.lua",
		dir .. "/" .. key .. "/init.luau",
	}
	for _, p in candidates do
		if exists(p) then
			local isDir = p:match("%.lua$") == nil and p:match("%.luau$") == nil
			return {
				__script = true,
				__path = p,
				Parent = setmetatable({ __dir = isDir and p or (dir .. "/" .. key) }, FolderMT),
			}
		end
	end
	return nil
end

-- ── require wrapper ────────────────────────────────────────────────────────
local originalRequire = require

local function customRequire(arg: any): any
	if type(arg) == "table" and rawget(arg, "__path") then
		return originalRequire(rawget(arg, "__path"))
	end
	return originalRequire(arg)
end
_G.require = customRequire

-- script global: aponta Parent para src/shared (raiz dos módulos compartilhados)
_G.script = {
	Name = "Run",
	Parent = setmetatable({ __dir = srcSharedDir }, FolderMT),
}

-- ── game mock ──────────────────────────────────────────────────────────────
local PlayersMock = {
	GetPlayerByUserId = function(_userId: number): any
		return nil
	end,
	PlayerAdded = {
		Connect = function()
			return {}
		end,
	},
	PlayerRemoving = {
		Connect = function()
			return {}
		end,
	},
}

local ReplicatedStorageMock = {
	FindFirstChild = function()
		return nil
	end,
	WaitForChild = function(_self: any, name: string)
		return { Name = name }
	end,
}

_G.game = {
	GetService = function(_self: any, name: string): any
		if name == "ReplicatedStorage" then
			return ReplicatedStorageMock
		elseif name == "Players" then
			return PlayersMock
		end
		return nil
	end,
	Players = PlayersMock,
}

-- ── Instance mock ──────────────────────────────────────────────────────────
_G.Instance = {
	new = function(className: string): any
		return {
			ClassName = className,
			Name = className,
			Parent = nil,
			FindFirstChild = function()
				return nil
			end,
			WaitForChild = function(_self: any, name: string)
				return { Name = name }
			end,
		}
	end,
}

-- ── task polyfill (Lune não expõe task global) ─────────────────────────────
-- Suficiente para testes: defer/spawn executam no próximo passo, wait é
-- busy-wait curto. NÃO usar em produção (lá o Roblox fornece task nativo).
_G.task = {
	spawn = function(fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn(("[task.spawn] %s"):format(tostring(err)))
		end
		return nil
	end,
	defer = function(fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn(("[task.defer] %s"):format(tostring(err)))
		end
		return nil
	end,
	wait = function(seconds: number): number
		local start = os.clock()
		while os.clock() - start < seconds do
			-- busy-wait curto
		end
		return seconds
	end,
	delay = function(seconds: number, fn: () -> ())
		task.wait(seconds)
		fn()
	end,
}

-- Exports úteis para os testes
return {
	srcSharedDir = srcSharedDir,
	require = customRequire,
	game = _G.game,
	Instance = _G.Instance,
	task = _G.task,
}

--!nonstrict
-- Resolução de caminhos de Instance a partir de string.
-- Aceita "game.Workspace.GreyboxF0", "Workspace.GreyboxF0",
-- "Workspace/GreyboxF0" e nomes de serviço soltos ("ReplicatedStorage").

local Resolve = {}

local SERVICE_ALIASES = {
	workspace = "Workspace",
	rs = "ReplicatedStorage",
	replicatedstorage = "ReplicatedStorage",
	sss = "ServerScriptService",
	serverscriptservice = "ServerScriptService",
	ss = "ServerStorage",
	serverstorage = "ServerStorage",
	sp = "StarterPlayer",
	starterplayer = "StarterPlayer",
	sg = "StarterGui",
	startergui = "StarterGui",
	lighting = "Lighting",
	players = "Players",
	teams = "Teams",
	soundservice = "SoundService",
}

function Resolve.split(path: string): { string }
	local parts = {}
	for segment in string.gmatch(path, "[^%.%/]+") do
		if segment ~= "" then
			table.insert(parts, segment)
		end
	end
	return parts
end

-- Retorna (instance, erro). Erro descreve exatamente onde a cadeia quebrou.
function Resolve.instance(path: string?): (Instance?, string?)
	if path == nil or path == "" or path == "game" or path == "DataModel" then
		return game, nil
	end

	local parts = Resolve.split(path)
	if #parts == 0 then
		return game, nil
	end
	if string.lower(parts[1]) == "game" then
		table.remove(parts, 1)
		if #parts == 0 then
			return game, nil
		end
	end

	local serviceName = SERVICE_ALIASES[string.lower(parts[1])] or parts[1]
	local current: Instance? = nil
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		current = service
	else
		current = game:FindFirstChild(parts[1])
	end
	if current == nil then
		return nil, string.format("serviço/filho '%s' não existe em game", parts[1])
	end

	for index = 2, #parts do
		local child = current:FindFirstChild(parts[index])
		if child == nil then
			return nil, string.format("'%s' não tem filho '%s'", current:GetFullName(), parts[index])
		end
		current = child
	end

	return current, nil
end

return Resolve

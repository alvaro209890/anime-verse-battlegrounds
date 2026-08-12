--!strict
-- RemoteGateway (server) — F0 (docs/04 §4.1)
-- Cria os remotes registrados, decodifica contratos, limita taxa e despacha
-- intenções. Nenhum service expõe RemoteEvent solto.
-- TODO F1: session binding, rate limit por janela, assinatura/versão de contrato.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RemoteGateway = {}

-- Nome do remote → instância (criadas no boot)
local remoteInstances: { [string]: RemoteEvent } = {}

-- userId → { janela, contagem } — rate limit simples por segundo
local callWindows: { [number]: { windowStart: number, count: number } } = {}
local CALL_LIMIT_PER_SECOND = 15

function RemoteGateway.init(): ()
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	local remotesFolder = shared:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = shared
	end
	for _, contract in Remotes.Contracts.all() do
		local remote = Instance.new("RemoteEvent")
		remote.Name = contract.name
		remote.Parent = remotesFolder
		remoteInstances[contract.name] = remote
	end
end

function RemoteGateway.getRemote(name: string): RemoteEvent?
	return remoteInstances[name]
end

-- Conecta um handler de intenção do cliente (Cliente → Servidor).
function RemoteGateway.onClientIntent(name: string, handler: (player: Player, payload: { any }) -> ())
	local remote = remoteInstances[name]
	if not remote then
		error(("[RemoteGateway] remote não registrado: %s"):format(name))
	end
	remote.OnServerEvent:Connect(function(player: Player, payload: { any })
		if type(payload) ~= "table" then
			return
		end
		-- Rate limit simples por jogador (janela de 1 segundo)
		local now = os.clock()
		local window = callWindows[player.UserId]
		if not window or now - window.windowStart > 1 then
			window = { windowStart = now, count = 0 }
			callWindows[player.UserId] = window
		end
		window.count += 1
		if window.count > CALL_LIMIT_PER_SECOND then
			return
		end
		handler(player, payload)
	end)
end

function RemoteGateway.fireClient(player: Player, name: string, payload: { any }): ()
	local remote = remoteInstances[name]
	if not remote then
		error(("[RemoteGateway] remote não registrado: %s"):format(name))
	end
	remote:FireClient(player, payload)
end

function RemoteGateway.fireAllClients(name: string, payload: { any }): ()
	local remote = remoteInstances[name]
	if not remote then
		error(("[RemoteGateway] remote não registrado: %s"):format(name))
	end
	remote:FireAllClients(payload)
end

return RemoteGateway

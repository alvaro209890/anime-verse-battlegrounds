--!strict
-- RemoteGateway (server) — F0 (docs/04 §4.1)
-- Cria os remotes registrados, aplica SecurityService e despacha intenções.
-- Nenhum service expõe RemoteEvent solto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteEnvelope = require(ReplicatedStorage.Shared.RemoteEnvelope)

local RemoteGateway = {}

export type GatewayDeps = {
	authorize: ((number, string, any) -> ({ [string]: any }?, string?))?,
}

-- Nome do remote → instância (criadas no boot)
local remoteInstances: { [string]: RemoteEvent } = {}

local authorize: ((number, string, any) -> ({ [string]: any }?, string?))? = nil

function RemoteGateway.init(deps: GatewayDeps?): ()
	authorize = if deps then deps.authorize else nil
	table.clear(remoteInstances)
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	local remotesFolder = shared:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = shared
	end
	for _, contract in Remotes.Contracts.all() do
		local existing = remotesFolder:FindFirstChild(contract.name)
		if existing and not existing:IsA("RemoteEvent") then
			error(("[RemoteGateway] instância inválida para %s"):format(contract.name))
		end
		local remote = if existing then existing :: RemoteEvent else Instance.new("RemoteEvent")
		if not existing then
			remote.Name = contract.name
			remote.Parent = remotesFolder
		end
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
	local contract = Remotes.Contracts.get(name :: any)
	if not contract or contract.direction ~= "ClientToServer" then
		error(("[RemoteGateway] remote não aceita intenção: %s"):format(name))
	end
	remote.OnServerEvent:Connect(function(player: Player, envelope: { any })
		local payload = if authorize
			then select(1, authorize(player.UserId, name, envelope))
			else select(1, RemoteEnvelope.decode(envelope, name))
		if not payload then
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

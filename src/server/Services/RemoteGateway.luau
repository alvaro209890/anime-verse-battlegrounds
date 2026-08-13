--!strict
-- RemoteGateway (server) — F0 (docs/04 §4.1)
-- Cria os remotes registrados, decodifica contratos, limita taxa e despacha
-- intenções. Nenhum service expõe RemoteEvent solto.
-- TODO F1: session binding, rate limit por janela, assinatura/versão de contrato.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteEnvelope = require(ReplicatedStorage.Shared.RemoteEnvelope)

local RemoteGateway = {}

-- Nome do remote → instância (criadas no boot)
local remoteInstances: { [string]: RemoteEvent } = {}

-- userId → classe → { janela, contagem }. Intenções de combate têm orçamento
-- próprio para uma interação (ex.: objetivo) não consumir seus 8 slots.
local callWindows: { [number]: { [string]: { windowStart: number, count: number } } } = {}
local DEFAULT_CALL_LIMIT_PER_SECOND = 15
local COMBAT_CALL_LIMIT_PER_SECOND = 8
local COMBAT_INTENTS: { [string]: boolean } = {
	[Remotes.Names.AbilityIntent] = true,
	[Remotes.Names.BasicAttackIntent] = true,
	[Remotes.Names.GuardIntent] = true,
	[Remotes.Names.DashIntent] = true,
}

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
	remote.OnServerEvent:Connect(function(player: Player, envelope: { any })
		local payload = RemoteEnvelope.decode(envelope, name)
		if not payload then
			return
		end
		-- Rate limit simples por jogador (janela de 1 segundo)
		local now = os.clock()
		local class = if COMBAT_INTENTS[name] then "combat" else "default"
		local playerWindows = callWindows[player.UserId]
		if not playerWindows then
			playerWindows = {}
			callWindows[player.UserId] = playerWindows
		end
		local window = playerWindows[class]
		if not window or now - window.windowStart > 1 then
			window = { windowStart = now, count = 0 }
			playerWindows[class] = window
		end
		window.count += 1
		local limit = if COMBAT_INTENTS[name] then COMBAT_CALL_LIMIT_PER_SECOND else DEFAULT_CALL_LIMIT_PER_SECOND
		if window.count > limit then
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

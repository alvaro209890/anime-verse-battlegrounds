--!strict
-- Bootstrap do cliente — F0
-- Conecta aos remotes do servidor. Cliente NUNCA decide acerto/dano/custo;
-- apenas envia intenção e reproduz apresentação do que o servidor confirmar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Referências aos remotes (criados pelo RemoteGateway no servidor)
local function getRemote(name: string): RemoteEvent?
	local folder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	return folder:FindFirstChild(name)
end

-- Escuta rejeição de habilidade (mostrar motivo na UI)
local rejectedRemote = getRemote(Remotes.Names.AbilityRejected)
if rejectedRemote then
	rejectedRemote.OnClientEvent:Connect(function(payload: { any })
		warn(("[Client] habilidade recusada: %s (%s)"):format(tostring(payload.abilityId), tostring(payload.reason)))
	end)
end

-- Envia intenção de ativar habilidade (bindings reais no InputController, F1)
local activateRemote = getRemote(Remotes.Names.AbilityActivate)
if activateRemote then
	activateRemote:FireServer({
		abilityId = "dash_strike",
		timestamp = os.clock(),
	})
end

-- TODO F1: InputController (teclas/touch/gamepad → intenção semântica),
-- previsão visual de habilidade e reconciliação com o servidor.

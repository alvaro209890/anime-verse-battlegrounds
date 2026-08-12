--!strict
-- Bootstrap do cliente — F0 (docs/13-F0-SLICE.md SLICE-DEC-005)
-- Conecta aos remotes do servidor. Cliente NUNCA decide acerto/dano/custo.
-- Intenção só depois de SessionSnapshot (ready).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ready = false
local snapshot: { any }? = nil

local function getRemote(name: string): RemoteEvent?
	local folder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
	return folder:FindFirstChild(name)
end

local snapshotRemote = getRemote(Remotes.Names.SessionSnapshot)
if snapshotRemote then
	snapshotRemote.OnClientEvent:Connect(function(payload: { any })
		snapshot = payload
		ready = payload.ready == true
		print(("[Client] sessão pronta zona=%s ready=%s"):format(tostring(snapshot.zoneId), tostring(ready)))
	end)
end

local rejectedRemote = getRemote(Remotes.Names.AbilityRejected)
if rejectedRemote then
	rejectedRemote.OnClientEvent:Connect(function(payload: { any })
		warn(("[Client] habilidade recusada: %s (%s)"):format(tostring(payload.abilityId), tostring(payload.reason)))
	end)
end

-- TODO F0 item 10: InputController só dispara se ready == true.
-- Previsão visual e reconciliação com o servidor.

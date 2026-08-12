--!strict
-- Bootstrap do cliente — F0 (docs/13-F0-SLICE.md SLICE-DEC-005)
-- Conecta aos remotes do servidor. Cliente NUNCA decide acerto/dano/custo.
-- Intenção só depois de SessionSnapshot (ready).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage.Shared.Data.Locale)
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

local zoneRemote = getRemote(Remotes.Names.ZoneEvent)
if zoneRemote then
	zoneRemote.OnClientEvent:Connect(function(payload: { any })
		if not ready then
			return
		end
		print(
			("[Client] zona %s → %s pvp=%s lockout=%s"):format(
				tostring(payload.from),
				tostring(payload.to),
				tostring(payload.pvp),
				tostring(payload.lockoutRemaining)
			)
		)
	end)
end

-- Tracker do objetivo (docs/13 §12.2 — uma linha, some ao completar).
-- O servidor manda a chave e o progresso; o cliente só resolve o texto.
local stateDeltaRemote = getRemote(Remotes.Names.StateDelta)
if stateDeltaRemote then
	stateDeltaRemote.OnClientEvent:Connect(function(payload: { any })
		if not ready then
			return
		end
		local objective = payload.objective
		if objective then
			if objective.state == "completed" then
				print(("[Client] objetivo concluído: %s"):format(tostring(objective.questId)))
			else
				print(("[Client] %s"):format(Locale.format(objective.trackerKey, { n = objective.progress })))
			end
		end
		if payload.unconsolidatedXp then
			print(("[Client] XP não consolidado: %d"):format(payload.unconsolidatedXp))
		end
	end)
end

-- Telegraph de inimigo (docs/13 §17: contorno branco + ícone, não só vermelho).
-- Aqui só o log; o VFX entra com o CombatFeedbackController (item 12).
local enemyRemote = getRemote(Remotes.Names.EnemyEvent)
if enemyRemote then
	enemyRemote.OnClientEvent:Connect(function(payload: { any })
		if not ready or payload.kind ~= "telegraph" then
			return
		end
		print(("[Client] perigo: %s vai atacar"):format(tostring(payload.fighterId)))
	end)
end

-- TODO F0 item 12: InputController só dispara se ready == true.
-- Previsão visual e reconciliação com o servidor.

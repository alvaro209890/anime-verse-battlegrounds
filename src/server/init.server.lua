--!strict
-- Bootstrap do servidor — F0
-- Valida catálogo → init RemoteGateway → init ResourceService →
-- conecta intenções de habilidade → ciclo join/leave.
-- Ordem importa (grafo acíclico); falha de catálogo derruba o boot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityService = require(script.Parent.Services.AbilityService)
local CatalogService = require(script.Parent.Services.CatalogService)
local PlayerSessionService = require(script.Parent.Services.PlayerSessionService)
local RemoteGateway = require(script.Parent.Services.RemoteGateway)
local ResourceService = require(script.Parent.Services.ResourceService)
local SaveService = require(script.Parent.Services.SaveService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- 1. Catálogo — validação em fail-fast
CatalogService.validate()
print("[Bootstrap] catálogo validado")

-- 2. Persistência (stub seguro até ProfileStore entrar no build)
SaveService.init()

-- 3. Gateway de rede — cria remotes registrados
RemoteGateway.init()
print("[Bootstrap] RemoteGateway iniciado")

-- 4. Recurso — inicia regen loop
ResourceService.init()

-- 5. Intenção de habilidade (cliente → servidor)
RemoteGateway.onClientIntent(Remotes.Names.AbilityActivate, function(player: Player, payload: { any })
	local abilityId = payload.abilityId
	if type(abilityId) ~= "string" then
		return
	end

	local attacker = ResourceService.getState(player.UserId)
	if not attacker then
		return
	end

	-- TODO F1: resolução de alvo por range/targetPosition (CombatService +
	-- SpatialQuery). F0: alvo único hardcoded não existe — ver runner.
	local ok, reason = AbilityService.tryActivate(attacker, abilityId, nil, payload)
	if not ok then
		RemoteGateway.fireClient(player, Remotes.Names.AbilityRejected, {
			abilityId = abilityId,
			reason = reason or "unknown",
		})
	end
end)

-- 6. Ciclo de sessão
game.Players.PlayerAdded:Connect(function(player: Player)
	PlayerSessionService.onPlayerJoined(player)
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
	PlayerSessionService.onPlayerLeft(player)
end)

print("[Bootstrap] servidor pronto (F0)")

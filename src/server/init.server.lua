--!strict
-- Bootstrap do servidor — F0
-- Valida catálogo → init RemoteGateway → init ResourceService →
-- conecta intenções de habilidade → ciclo join/leave.
-- Ordem importa (grafo acíclico); falha de catálogo derruba o boot.
--
-- F0 usa injeção de dependências: o bootstrap monta o grafo e cada service
-- recebe as dependências no init() (docs/04 §2.3 — testabilidade).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityService = require(script.Parent.Services.AbilityService)
local CatalogService = require(script.Parent.Services.CatalogService)
local CooldownService = require(script.Parent.Services.CooldownService)
local CombatService = require(script.Parent.Services.CombatService)
local PlayerSessionService = require(script.Parent.Services.PlayerSessionService)
local RemoteGateway = require(script.Parent.Services.RemoteGateway)
local ResourceService = require(script.Parent.Services.ResourceService)
local SaveService = require(script.Parent.Services.SaveService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Abilities = require(ReplicatedStorage.Shared.Data.Abilities)
local Characters = require(ReplicatedStorage.Shared.Data.Characters)
local EnergyFamilies = require(ReplicatedStorage.Shared.Data.EnergyFamilies)

-- 1. Catálogo — validação em fail-fast
CatalogService.init({
	Abilities = Abilities,
	Characters = Characters,
	EnergyFamilies = EnergyFamilies,
})
print("[Bootstrap] catálogo validado")

-- 2. Persistência (stub seguro até ProfileStore entrar no build)
SaveService.init()

-- 3. Gateway de rede — cria remotes registrados
RemoteGateway.init()
print("[Bootstrap] RemoteGateway iniciado")

-- 4. Recurso — inicia regen loop com broadcast real via gateway
ResourceService.init({
	getFamily = CatalogService.getFamily,
	taskImpl = task,
	onResourceChanged = function(playerUserId: number, current: number, max: number, depleted: boolean)
		local player = game.Players:GetPlayerByUserId(playerUserId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.ResourceChanged, {
			familyId = "?",
			current = current,
			max = max,
			depleted = depleted,
		})
	end,
})

-- 5. Combate/Cooldown/Ability — grafo de dependências
AbilityService.init({
	getAbility = CatalogService.getAbility,
	getCooldownRemaining = CooldownService.getRemaining,
	startCooldown = CooldownService.start,
	trySpendResource = function(userId: number, amount: number)
		local state = ResourceService.getState(userId)
		if not state then
			return false
		end
		return ResourceService.trySpend(userId, amount)
	end,
	grantFlowGain = ResourceService.grantFlowGain,
	tryGrantFlow = ResourceService.tryGrantFlow,
	isAlive = function(state: any)
		return CombatService.isAlive(state)
	end,
	applyDamage = CombatService.applyDamage,
})

-- 6. Ciclo de sessão — injeta o grafo
PlayerSessionService.init({
	getCharacter = CatalogService.getCharacter,
	createResourceState = function(userId: number, familyId: string)
		return ResourceService.createState(userId, familyId)
	end,
	removeResourceState = ResourceService.removeState,
	clearCooldowns = CooldownService.clear,
	releaseProfile = SaveService.releaseProfile,
})

-- 7. Intenção de habilidade (cliente → servidor)
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

-- 7. Ciclo de sessão
game.Players.PlayerAdded:Connect(function(player: Player)
	PlayerSessionService.onPlayerJoined(player)
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
	PlayerSessionService.onPlayerLeft(player)
end)

print("[Bootstrap] servidor pronto (F0)")

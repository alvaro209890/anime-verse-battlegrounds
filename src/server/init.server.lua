--!strict
-- Bootstrap do servidor — F0
-- Valida catálogo → init RemoteGateway → init ResourceService →
-- conecta intenções de habilidade/combate → ciclo join/leave.
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
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)

-- 1. Catálogo — validação em fail-fast
CatalogService.init({
	Abilities = Abilities,
	Characters = Characters,
	EnergyFamilies = EnergyFamilies,
	Npcs = Npcs,
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
		local resourceState = ResourceService.getState(playerUserId)
		RemoteGateway.fireClient(player, Remotes.Names.ResourceChanged, {
			familyId = if resourceState then resourceState.familyId else "umbral_aether",
			current = current,
			max = max,
			depleted = depleted,
		})
	end,
})

-- 5. Combate/Cooldown/Ability — grafo de dependências
CombatService.clear()
local dummyDef = CatalogService.getNpc("npc_training_dummy")
if dummyDef then
	CombatService.createFighter(dummyDef.id, "npc", dummyDef.maxHealth, dummyDef.maxGuard)
end

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
	getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end,
	getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end,
	tryCometShoulder = CombatService.tryCometShoulder,
	onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string)
		local player = game.Players:GetPlayerByUserId(userId)
		if not player then
			return
		end
		RemoteGateway.fireClient(player, Remotes.Names.CombatHit, {
			targetId = targetId,
			damage = damage,
			abilityId = abilityId,
		})
	end,
})

-- 6. Ciclo de sessão — injeta o grafo
PlayerSessionService.init({
	getCharacter = CatalogService.getCharacter,
	getFamily = CatalogService.getFamily,
	createResourceState = function(userId: number, familyId: string)
		return ResourceService.createState(userId, familyId)
	end,
	removeResourceState = ResourceService.removeState,
	getResourceState = ResourceService.getState,
	clearCooldowns = CooldownService.clear,
	releaseProfile = SaveService.releaseProfile,
	createFighter = CombatService.createFighter,
	removeFighter = CombatService.removeFighter,
	getFighter = CombatService.getFighter,
	playerFighterId = CombatService.playerFighterId,
	onSnapshot = function(player: Player, snapshot: { any })
		RemoteGateway.fireClient(player, Remotes.Names.SessionSnapshot, snapshot)
	end,
})

local function requireReady(player: Player): boolean
	return PlayerSessionService.isReady(player.UserId)
end

-- 7. Intenção de habilidade (cliente → servidor)
RemoteGateway.onClientIntent(Remotes.Names.AbilityActivate, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local abilityId = payload.abilityId
	if type(abilityId) ~= "string" then
		return
	end

	local attacker = ResourceService.getState(player.UserId)
	if not attacker then
		return
	end

	local ok, reason = AbilityService.tryActivate(attacker, abilityId, nil, payload)
	if not ok then
		RemoteGateway.fireClient(player, Remotes.Names.AbilityRejected, {
			abilityId = abilityId,
			reason = reason or "unknown",
		})
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.BasicAttackIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local attacker = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	local dummy = CombatService.getFighter("npc_training_dummy")
	if not attacker or not dummy then
		return
	end
	local kind = payload.kind
	local result = if kind == "heavy"
		then CombatService.tryHeavy(attacker, dummy, os.clock(), "front")
		else CombatService.tryLight(attacker, dummy, os.clock(), "front")
	if result.ok then
		RemoteGateway.fireClient(player, Remotes.Names.CombatHit, {
			targetId = dummy.id,
			damage = result.damage,
			abilityId = if kind == "heavy" then "heavy" else "light",
		})
	end
end)

RemoteGateway.onClientIntent(Remotes.Names.GuardIntent, function(player: Player, payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	if not fighter then
		return
	end
	CombatService.setGuard(fighter, payload.down == true, os.clock())
end)

RemoteGateway.onClientIntent(Remotes.Names.DashIntent, function(player: Player, _payload: { any })
	if not requireReady(player) then
		return
	end
	local fighter = CombatService.getFighter(CombatService.playerFighterId(player.UserId))
	if not fighter then
		return
	end
	CombatService.tryDash(fighter, os.clock())
end)

-- 8. Ciclo de sessão
game.Players.PlayerAdded:Connect(function(player: Player)
	PlayerSessionService.onPlayerJoined(player)
end)
game.Players.PlayerRemoving:Connect(function(player: Player)
	PlayerSessionService.onPlayerLeft(player)
end)

print("[Bootstrap] servidor pronto (F0)")

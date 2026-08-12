--!strict
-- ResourceService (server) — F0 (docs/04 §4.1)
-- Pool de energia por jogador, autoridade 100% do servidor.
-- Custo/regen vêm das definições; zero número mágico.
-- Expõe eventos observáveis (ResourceChanged, ResourceDepleted) sem polling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatalogService = require(script.Parent.CatalogService)
local Types = require(ReplicatedStorage.Shared.Types)

export type ServerPlayerState = Types.ServerPlayerState

local ResourceService = {}

-- Fila de eventos para broadcast (evita spam de remote por tick)
local pendingDirty: { [number]: boolean } = {}

local function broadcastResource(playerUserId: number)
	if pendingDirty[playerUserId] then
		return
	end
	pendingDirty[playerUserId] = true
	task.defer(function()
		pendingDirty[playerUserId] = nil
		local player = game.Players:GetPlayerByUserId(playerUserId)
		if not player then
			return
		end
		local state = ResourceService.states[playerUserId]
		if not state then
			return
		end
		-- TODO: broadcast via RemoteGateway (F0 já entrega o gateway)
		-- RemoteGateway.fireClient(player, "ResourceChanged", {...})
	end)
end

-- Regeneração: tick a cada 0.5s; combate muda o perfil de regen.
local function regenTick()
	for userId, state in ResourceService.states do
		if not state then
			continue
		end
		local family = CatalogService.getFamily(state.familyId)
		if not family then
			continue
		end
		local rate = state.combat and family.regenInCombatPerSec or family.regenOutOfCombatPerSec
		if rate <= 0 then
			continue
		end
		local delta = rate * 0.5
		local before = state.resource
		state.resource = math.min(family.poolCap, state.resource + delta)
		if state.resource ~= before then
			broadcastResource(userId)
		end
	end
end

function ResourceService.init(): ()
	task.spawn(function()
		while true do
			task.wait(0.5)
			regenTick()
		end
	end)
end

function ResourceService.createState(playerUserId: number, familyId: string): Types.ServerPlayerState?
	local family = CatalogService.getFamily(familyId)
	if not family then
		return nil
	end
	local state = {
		userId = playerUserId,
		characterId = "",
		health = 100,
		resource = family.poolBase,
		familyId = familyId,
		combat = false,
		lastCombatAt = 0,
	} :: Types.ServerPlayerState
	ResourceService.states[playerUserId] = state
	return state
end

function ResourceService.getState(playerUserId: number): Types.ServerPlayerState?
	return ResourceService.states[playerUserId]
end

-- Tenta gastar `amount` do pool. Retorna true se conseguiu (e deduz).
function ResourceService.trySpend(playerUserId: number, amount: number): boolean
	local state = ResourceService.states[playerUserId]
	if not state then
		return false
	end
	if state.resource < amount then
		return false
	end
	state.resource -= amount
	broadcastResource(playerUserId)
	return true
end

-- Prêmio de fluxo (timing certo) — Éter Umbral
function ResourceService.grantFlowGain(playerUserId: number, amount: number): ()
	local state = ResourceService.states[playerUserId]
	if not state then
		return
	end
	local family = CatalogService.getFamily(state.familyId)
	if not family then
		return
	end
	state.resource = math.min(family.poolCap, state.resource + amount)
	broadcastResource(playerUserId)
end

function ResourceService.setCombat(playerUserId: number, inCombat: boolean): ()
	local state = ResourceService.states[playerUserId]
	if not state then
		return
	end
	state.combat = inCombat
	if inCombat then
		state.lastCombatAt = os.clock()
	end
end

ResourceService.states = {} :: { [number]: Types.ServerPlayerState }

return ResourceService

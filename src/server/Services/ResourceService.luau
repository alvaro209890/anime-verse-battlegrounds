--!strict
-- ResourceService (server) — F0 (docs/04 §4.1)
-- Pool de energia por jogador, autoridade 100% do servidor.
-- Custo/regen vêm das definições; zero número mágico.
-- Expõe eventos observáveis (ResourceChanged) sem polling.
--
-- Dependências injetadas no init() — sem require de Instances (testável).
-- task injetado via deps (Roblox nativo / polyfill Lune nos testes).

export type ServerPlayerState = {
	userId: number,
	characterId: string,
	health: number,
	resource: number,
	familyId: string,
	combat: boolean,
	lastCombatAt: number,
}

export type ResourceDeps = {
	getFamily: (string) -> any?,
	-- broadcast opcional (nil em testes unitários)
	onResourceChanged: ((number, number, number, boolean) -> ())?,
	-- task impl (Roblox nativo ou polyfill de teste)
	taskImpl: {
		spawn: ((() -> ()) -> ())?,
		defer: ((() -> ()) -> ())?,
		wait: ((number) -> number)?,
	},
}

local ResourceService = {
	states = {} :: { [number]: ServerPlayerState },
	deps = nil :: ResourceDeps?,
}

-- Fila de eventos para broadcast (evita spam de remote por tick)
local pendingDirty: { [number]: boolean } = {}

local function broadcastResource(playerUserId: number)
	if pendingDirty[playerUserId] then
		return
	end
	pendingDirty[playerUserId] = true
	local taskImpl = ResourceService.deps and ResourceService.deps.taskImpl or task
	local deferFn = taskImpl.defer or function(fn)
		fn()
	end
	deferFn(function()
		pendingDirty[playerUserId] = nil
		local state = ResourceService.states[playerUserId]
		if not state then
			return
		end
		local onChanged = ResourceService.deps and ResourceService.deps.onResourceChanged
		if onChanged then
			local family = ResourceService.deps and ResourceService.deps.getFamily(state.familyId)
			local poolCap = family and family.poolCap or 100
			onChanged(playerUserId, state.resource, poolCap, state.resource <= 0)
		end
	end)
end

-- Regeneração: tick a cada 0.5s; combate muda o perfil de regen.
local function regenTick()
	for userId, state in ResourceService.states do
		if not state then
			continue
		end
		local deps = ResourceService.deps
		local family = deps and deps.getFamily(state.familyId)
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

function ResourceService.init(deps: ResourceDeps): ()
	ResourceService.deps = deps
	local taskImpl = deps.taskImpl or task
	local spawnFn = taskImpl.spawn or function(fn)
		fn()
	end
	local waitFn = taskImpl.wait or function()
		return 0
	end
	spawnFn(function()
		while true do
			waitFn(0.5)
			regenTick()
		end
	end)
end

function ResourceService.createState(playerUserId: number, familyId: string): ServerPlayerState?
	local deps = ResourceService.deps
	local family = deps and deps.getFamily(familyId)
	if not family then
		return nil
	end
	local state: ServerPlayerState = {
		userId = playerUserId,
		characterId = "",
		health = 100,
		resource = family.poolBase,
		familyId = familyId,
		combat = false,
		lastCombatAt = 0,
	}
	ResourceService.states[playerUserId] = state
	return state
end

function ResourceService.getState(playerUserId: number): ServerPlayerState?
	return ResourceService.states[playerUserId]
end

-- Remove o estado no leave do jogador.
function ResourceService.removeState(playerUserId: number): ()
	ResourceService.states[playerUserId] = nil
	pendingDirty[playerUserId] = nil
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
	local deps = ResourceService.deps
	local family = deps and deps.getFamily(state.familyId)
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

return ResourceService

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
	poolBonus: number,
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
	now: (() -> number)?,
	-- Multiplicador de regen de Umbral pelo nível da conta. Ausente = 1.
	resourceMulFor: ((number) -> number)?,
}

local ResourceService = {
	states = {} :: { [number]: ServerPlayerState },
	deps = nil :: ResourceDeps?,
}

local lastFlowAt: { [number]: number } = {}
local lastFlowBonusAt: { [number]: number } = {}

local function now(): number
	local deps = ResourceService.deps
	if deps and deps.now then
		return deps.now()
	end
	return os.clock()
end

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
			local poolCap = ResourceService.poolCapFor(state)
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
		local rate = ResourceService.getRegenRate(userId)
		if rate <= 0 then
			continue
		end
		local delta = rate * 0.5
		local before = state.resource
		state.resource = math.min(ResourceService.poolCapFor(state), state.resource + delta)
		if state.resource ~= before then
			broadcastResource(userId)
		end
	end
end

function ResourceService.getRegenRate(playerUserId: number): number
	local state = ResourceService.states[playerUserId]
	if not state then
		return 0
	end
	local deps = ResourceService.deps
	local family = deps and deps.getFamily(state.familyId)
	if not family then
		return 0
	end
	local rate = family.regenOutOfCombatPerSec
	if state.combat then
		rate = family.regenInCombatPerSec
	elseif state.lastCombatAt > 0 then
		local delay = family.outOfCombatDelaySeconds
		if delay > 0 and (now() - state.lastCombatAt) < delay then
			rate = 0
		end
	end
	local mulFor = deps and deps.resourceMulFor
	if mulFor then
		local mul = mulFor(playerUserId)
		if type(mul) == "number" and mul == mul and mul > 0 then
			rate *= mul
		end
	end
	return rate
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
		poolBonus = 0,
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
	lastFlowAt[playerUserId] = nil
	lastFlowBonusAt[playerUserId] = nil
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
	state.resource = math.min(ResourceService.poolCapFor(state), state.resource + amount)
	broadcastResource(playerUserId)
end

-- Fluxo de timing (Cadência): +flowGainOnTimedHit, cap por flowGainCapSeconds,
-- bônus de +flowBonusAmount na primeira ativação a cada flowBonusIntervalSeconds.
function ResourceService.tryGrantFlow(playerUserId: number): number
	local state = ResourceService.states[playerUserId]
	if not state then
		return 0
	end
	local deps = ResourceService.deps
	local family = deps and deps.getFamily(state.familyId)
	if not family or family.flowGainOnTimedHit <= 0 then
		return 0
	end
	local t = now()
	local last = lastFlowAt[playerUserId]
	if last and family.flowGainCapSeconds > 0 and (t - last) < family.flowGainCapSeconds then
		return 0
	end
	local amount = family.flowGainOnTimedHit
	if family.flowBonusAmount > 0 then
		local lastBonus = lastFlowBonusAt[playerUserId]
		if not lastBonus or (t - lastBonus) >= family.flowBonusIntervalSeconds then
			amount += family.flowBonusAmount
			lastFlowBonusAt[playerUserId] = t
		end
	end
	lastFlowAt[playerUserId] = t
	ResourceService.grantFlowGain(playerUserId, amount)
	return amount
end

function ResourceService.setCombat(playerUserId: number, inCombat: boolean): ()
	local state = ResourceService.states[playerUserId]
	if not state then
		return
	end
	state.combat = inCombat
	state.lastCombatAt = now()
end

function ResourceService.poolCapFor(state: ServerPlayerState): number
	local deps = ResourceService.deps
	local family = deps and deps.getFamily(state.familyId)
	local base = if family then family.poolCap else 100
	return base + (state.poolBonus or 0)
end

function ResourceService.setPoolBonus(playerUserId: number, bonus: number): number
	local state = ResourceService.states[playerUserId]
	if not state then
		return 0
	end
	state.poolBonus = math.max(0, math.floor(bonus))
	local cap = ResourceService.poolCapFor(state)
	if state.resource > cap then
		state.resource = cap
		broadcastResource(playerUserId)
	end
	return cap
end

return ResourceService

--!strict
-- AbilityService (server) — F0 (docs/13-F0-SLICE.md §6)
-- Autoriza ativação (estado, unlock, cooldown, recurso) e despacha para o
-- runner registrado em serverRunnerId. Adicionar habilidade nova = 1 entrada
-- em Data/Abilities + 1 runner aqui.
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type ServerPlayerState = {
	userId: number,
	characterId: string,
	health: number,
	resource: number,
	familyId: string,
	combat: boolean,
	lastCombatAt: number,
}

export type AbilityPayload = {
	phase: string?,
	incomingHit: boolean?,
}

export type AbilityDeps = {
	getAbility: (string) -> any?,
	getCooldownRemaining: (number, string) -> number,
	startCooldown: (number, string, number) -> (),
	trySpendResource: (number, number) -> boolean,
	grantFlowGain: (number, number) -> (),
	tryGrantFlow: (number) -> number,
	isAlive: (ServerPlayerState) -> boolean,
	applyDamage: (ServerPlayerState, number, number?) -> boolean,
	now: (() -> number)?,
	isAbilityUnlocked: ((number, string) -> boolean)?,
}

local AbilityService = {
	runners = {} :: { [string]: (ServerPlayerState, ServerPlayerState?, AbilityPayload) -> () },
	deps = nil :: AbilityDeps?,
}

local reentryUntil: { [number]: { abilityId: string, expiresAt: number } } = {}

local function now(): number
	local deps = AbilityService.deps
	if deps and deps.now then
		return deps.now()
	end
	return os.clock()
end

local function cometShoulderRunner(attacker: ServerPlayerState, target: ServerPlayerState?, _payload: AbilityPayload)
	if not target then
		return
	end
	local deps = AbilityService.deps
	if not deps then
		return
	end
	deps.applyDamage(target, 9, attacker.userId)
end

local function brokenCadenceRunner(attacker: ServerPlayerState, target: ServerPlayerState?, payload: AbilityPayload)
	local deps = AbilityService.deps
	if not deps then
		return
	end
	if payload.phase == "reentry" then
		if target then
			local dead = deps.applyDamage(target, 4, attacker.userId)
			if not dead then
				deps.tryGrantFlow(attacker.userId)
			end
		end
		return
	end
	if target then
		deps.applyDamage(target, 5, attacker.userId)
		deps.applyDamage(target, 6, attacker.userId)
	end
	reentryUntil[attacker.userId] = {
		abilityId = "broken_cadence",
		expiresAt = now() + 0.12,
	}
end

local function pulseReturnRunner(attacker: ServerPlayerState, target: ServerPlayerState?, payload: AbilityPayload)
	if not payload.incomingHit or not target then
		return
	end
	local deps = AbilityService.deps
	if not deps then
		return
	end
	deps.applyDamage(target, 8, attacker.userId)
end

local function eclipseBeatRunner(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: AbilityPayload)
	-- Stretch F0: enabled = false; runner não deve ser chamado.
end

function AbilityService.init(deps: AbilityDeps): ()
	AbilityService.deps = deps
	table.clear(reentryUntil)
	AbilityService.runners = {
		comet_shoulder_runner = cometShoulderRunner,
		broken_cadence_runner = brokenCadenceRunner,
		pulse_return_runner = pulseReturnRunner,
		eclipse_beat_runner = eclipseBeatRunner,
	}
end

local function tryReentry(
	attacker: ServerPlayerState,
	abilityId: string,
	target: ServerPlayerState?,
	payload: AbilityPayload
): (boolean, string?)
	local deps = AbilityService.deps
	if not deps then
		return false, "not_initialized"
	end
	local window = reentryUntil[attacker.userId]
	if not window or window.abilityId ~= abilityId or now() > window.expiresAt then
		reentryUntil[attacker.userId] = nil
		return false, "reentry_window"
	end
	reentryUntil[attacker.userId] = nil
	local ability = deps.getAbility(abilityId)
	if not ability then
		return false, "unknown_ability"
	end
	local runner = AbilityService.runners[ability.serverRunnerId]
	if not runner then
		return false, "runner_not_found"
	end
	runner(attacker, target, payload)
	return true
end

-- Ativação de habilidade. Retorna (ok, motivo).
function AbilityService.tryActivate(
	attacker: ServerPlayerState,
	abilityId: string,
	target: ServerPlayerState?,
	payload: AbilityPayload?
): (boolean, string?)
	local deps = AbilityService.deps
	if not deps then
		return false, "not_initialized"
	end

	local ability = deps.getAbility(abilityId)
	if not ability then
		return false, "unknown_ability"
	end
	if not ability.enabled then
		return false, "disabled"
	end

	local runner = AbilityService.runners[ability.serverRunnerId]
	if not runner then
		return false, "runner_not_found"
	end

	if not deps.isAlive(attacker) then
		return false, "dead"
	end

	if deps.isAbilityUnlocked and not deps.isAbilityUnlocked(attacker.userId, abilityId) then
		return false, "locked"
	end

	local resolved: AbilityPayload = payload or {}
	if resolved.phase == "reentry" then
		return tryReentry(attacker, abilityId, target, resolved)
	end

	local remaining = deps.getCooldownRemaining(attacker.userId, abilityId)
	if remaining > 0 then
		return false, ("cooldown:%.1f"):format(remaining)
	end

	if not deps.trySpendResource(attacker.userId, ability.resourceCost.amount) then
		return false, "no_resource"
	end

	deps.startCooldown(attacker.userId, abilityId, ability.cooldown.baseSeconds)
	runner(attacker, target, resolved)
	return true
end

return AbilityService

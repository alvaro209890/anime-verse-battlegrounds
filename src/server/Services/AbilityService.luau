--!strict
-- AbilityService (server) — F0
-- Autoriza ativação (estado, cooldown, recurso) e despacha para o runner
-- registrado em serverRunnerId. É o molde de todas as habilidades:
-- adicionar habilidade nova = 1 entrada em Data/Abilities + 1 runner aqui.
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

export type AbilityDeps = {
	getAbility: (string) -> any?,
	getCooldownRemaining: (number, string) -> number,
	startCooldown: (number, string, number) -> (),
	trySpendResource: (number, number) -> boolean,
	grantFlowGain: (number, number) -> (),
	isAlive: (ServerPlayerState) -> boolean,
	applyDamage: (ServerPlayerState, number, number?) -> boolean,
}

local AbilityService = {
	runners = {} :: { [string]: (ServerPlayerState, ServerPlayerState?, { any }) -> () },
	deps = nil :: AbilityDeps?,
}

-- ── Runner de exemplo: dash_strike ─────────────────────────────────────────
-- Ataque de avanço com janela de timing: acertar dentro do startup dá prêmio
-- de fluxo (Éter Umbral) — premia jogador bom, pune spam (docs/01-GDD).
local function dashStrikeRunner(attacker: ServerPlayerState, target: ServerPlayerState?, _payload: { any })
	if not target then
		return
	end
	local deps = AbilityService.deps
	if not deps then
		return
	end

	-- Dano base do molde (balanceamento real: docs/01-GDD, fase F1)
	local damage = 12
	local dead = deps.applyDamage(target, damage, attacker.userId)
	if not dead then
		-- Prêmio de fluxo: acerto confirmado devolve energia
		deps.grantFlowGain(attacker.userId, 6)
	end
end

-- ── Runners stub das demais habilidades (F1: implementar) ──────────────────
local function eclipseBarrierRunner(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: { any })
	-- TODO F1: barreira que nega contato com duração de activeMs
end

local function voidRuptureRunner(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: { any })
	-- TODO F1: corte à distância (projétil server-side) com maxTargets
end

local function eclipseJudgementRunner(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: { any })
	-- TODO F1: ultimate em área, custo alto, cooldown longo
end

function AbilityService.init(deps: AbilityDeps): ()
	AbilityService.deps = deps
	AbilityService.runners = {
		dash_strike_runner = dashStrikeRunner,
		eclipse_barrier_runner = eclipseBarrierRunner,
		void_rupture_runner = voidRuptureRunner,
		eclipse_judgement_runner = eclipseJudgementRunner,
	}
end

-- Ativação de habilidade. Retorna (ok, motivo).
function AbilityService.tryActivate(
	attacker: ServerPlayerState,
	abilityId: string,
	target: ServerPlayerState?,
	_payload: { any }?
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

	local remaining = deps.getCooldownRemaining(attacker.userId, abilityId)
	if remaining > 0 then
		return false, ("cooldown:%.1f"):format(remaining)
	end

	if not deps.trySpendResource(attacker.userId, ability.resourceCost.amount) then
		return false, "no_resource"
	end

	deps.startCooldown(attacker.userId, abilityId, ability.cooldown.baseSeconds)
	runner(attacker, target, {})
	return true
end

return AbilityService

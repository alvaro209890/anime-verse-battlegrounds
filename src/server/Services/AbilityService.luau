--!strict
-- AbilityService (server) — F0 (docs/13-F0-SLICE.md §6)
-- Autoriza ativação (estado, unlock, cooldown, recurso) e despacha para o
-- runner registrado em serverRunnerId. Adicionar habilidade nova = 1 entrada
-- em Data/Abilities + 1 runner aqui.
--
-- Itens 8/10 do backlog (2026-08-12):
--   * Cadência Quebrada: janela de reentrada abre 120 ms após o fim do active
--     do golpe 2 (400 ms da ativação); a reentrada agenda o eco para 350 ms
--     depois (`AbilityService.tick` resolve ecos pendentes — o Heartbeat do
--     bootstrap chama o tick; nos testes, o relógio injetável faz o papel).
--   * Retorno de Pulso: a ativação abre a postura de 250 ms no FighterState
--     (CombatService.setPulseStance). O golpe frontal reduzido dispara o
--     contra (dano 8 + empurrão) por quem causou o golpe — o runner não
--     aplica dano na ativação (o cliente nunca informa "foi aparo").
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
	executionId: string?,
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
	tryCadenceHit: ((any, any, number, number, string) -> any)?,
	revalidateCadenceTarget: ((number, any) -> boolean)?,
	onPulseCounter: ((number, any, number) -> boolean?)?,
	now: (() -> number)?,
	isAbilityUnlocked: ((number, string) -> boolean)?,
	getAttackerFighter: ((number) -> any?)?,
	getAbilityTarget: ((number) -> any?)?,
	tryCometShoulder: ((any, any, number, string) -> any)?,
	onCombatHit: ((number, string, number, string, string?) -> ())?,
	onCombatKill: ((number, string, string) -> ())?,
	-- Camada espacial (item 5): resolve o avanço de 7 studs, commita a posição
	-- e devolve alvo + lado do golpe. Ausente = fatia headless usa
	-- `getAbilityTarget` (dummy fixo), que é o comportamento anterior.
	resolveCometShoulder: ((number) -> any)?,
	getFighterById: ((string) -> any?)?,
	-- Cadência Quebrada: o bootstrap resolve no espaço autoritativo um único
	-- alvo no início da execução. O runner guarda esse mesmo fighter para o eco;
	-- o segundo AbilityIntent não declara nem troca alvo.
	resolveCadenceTarget: ((number) -> any?)?,
	-- Retorno de Pulso (item 10): abre a postura no FighterState do jogador e
	-- expira a postura sem golpe (erro → recovery 600 ms).
	setPulseStance: ((any, number) -> (boolean, string?))?,
	expirePulseStance: ((any, number) -> ())?,
	-- Eco da Cadência acertou (item 10 — objetivo quest_flow): o bootstrap
	-- liga ao QuestService.creditFlowEcho. `abilityId` é quem gerou o eco.
	onFlowEcho: ((number, string, number) -> ())?,
}

local AbilityService = {
	runners = {} :: { [string]: (ServerPlayerState, ServerPlayerState?, AbilityPayload) -> () },
	deps = nil :: AbilityDeps?,
}

-- Janela de reentrada da Cadência: abre 120 ms após o fim do active do golpe 2
-- (docs/13 §6.2). Fim do active do golpe 2 = startup 140 + active 80 + intervalo
-- 100 + active 80 = 400 ms da ativação; janela de 120 ms.
local CADENCE_REENTRY_OPENS_MS = 400
-- Janela base de 120 ms + compensação máxima de 80 ms prevista pela spec.
local CADENCE_REENTRY_WINDOW_MS = 200
-- Eco: 350 ms após a reentrada (docs/13 §6.2).
local CADENCE_ECHO_DELAY_MS = 350
-- Postura do Retorno de Pulso: 250 ms (docs/13 §6.3).
local PULSE_STANCE_MS = 250

local reentryUntil: {
	[number]: { abilityId: string, opensAt: number, expiresAt: number, target: any?, executionId: string? },
} =
	{}
-- Os dois impactos da Cadência são resolvidos nos instantes autoritativos do
-- active (140 ms e 320 ms), não no recebimento do remote.
local pendingCadenceStrikes: {
	[number]: {
		abilityId: string,
		target: any,
		firstAt: number,
		secondAt: number,
		firstResolved: boolean,
	},
} =
	{}
-- userId → eco pendente da Cadência (resolvido no tick).
local pendingEchos: { [number]: { at: number, target: any, abilityId: string } } = {}
-- userId → postura ativa do Retorno de Pulso (expira no tick sem golpe).
local pulseStances: { [number]: { fighterId: string, expiresAt: number } } = {}

local function now(): number
	local deps = AbilityService.deps
	if deps and deps.now then
		return deps.now()
	end
	return os.clock()
end

local function notifyCombatHit(
	attackerUserId: number,
	target: any,
	damage: number,
	abilityId: string,
	killed: boolean?,
	outcome: string?
): ()
	local deps = AbilityService.deps
	if not deps or type(target.id) ~= "string" or damage < 0 then
		return
	end
	if killed and type(target.diedAt) == "number" and target.diedAt <= 0 then
		target.diedAt = now()
	end
	if deps.onCombatHit then
		deps.onCombatHit(attackerUserId, target.id, damage, abilityId, outcome)
	end
	if killed and deps.onCombatKill then
		deps.onCombatKill(attackerUserId, target.id, abilityId)
	end
end

-- Executa um impacto da Cadência por uma única porta. No runtime, essa porta
-- passa pelo CombatService (i-frame, guarda e Pulso); nos testes puros antigos,
-- o fallback preserva o adapter de dano mínimo. `connected` só é verdadeiro
-- quando HP foi realmente retirado, portanto iframe não concede Fluxo.
local function applyCadenceHit(
	attackerUserId: number,
	target: any,
	damage: number,
	abilityId: string,
	currentNow: number
): (boolean, boolean, boolean)
	local deps = AbilityService.deps
	if not deps then
		return false, false, false
	end
	if deps.tryCadenceHit then
		local attackerFighter = if deps.getAttackerFighter then deps.getAttackerFighter(attackerUserId) else nil
		if not attackerFighter then
			return false, false, false
		end
		local result = deps.tryCadenceHit(attackerFighter, target, currentNow, damage, "front")
		if not result or result.ok ~= true then
			return false, false, false
		end
		local attackerKilled = false
		if result.pulseCounter == true and deps.onPulseCounter then
			attackerKilled = deps.onPulseCounter(attackerUserId, target, currentNow) == true
		end
		local applied = if type(result.damage) == "number" then result.damage else 0
		local killed = result.killed == true
		if applied <= 0 then
			if result.parried == true then
				notifyCombatHit(attackerUserId, target, 0, abilityId, false, "guard")
			end
			return false, killed, attackerKilled
		end
		local outcome = if result.parried or result.stoppedOnGuard or result.pulseCounter then "guard" else "hit"
		notifyCombatHit(attackerUserId, target, applied, abilityId, killed, outcome)
		return true, killed, attackerKilled
	end

	local killed = deps.applyDamage(target, damage, attackerUserId)
	notifyCombatHit(attackerUserId, target, damage, abilityId, killed, "hit")
	return true, killed, false
end

-- Resolve ecos pendentes da Cadência (docs/13 §6.2): 350 ms após a reentrada,
-- dano 6 na mesma hitbox; o eco que acerta gera Fluxo e dispara onFlowEcho.
-- Também expira posturas do Pulso sem golpe (erro → recovery 600 ms, §6.3).
-- Chamado pelo Heartbeat do bootstrap (e pelos testes com relógio fake).
function AbilityService.tick(currentNow: number): ()
	local deps = AbilityService.deps
	if not deps then
		return
	end
	for userId, strikes in pendingCadenceStrikes do
		local target = strikes.target
		if not strikes.firstResolved and currentNow >= strikes.firstAt then
			strikes.firstResolved = true
			if
				target
				and target.health > 0
				and (not deps.revalidateCadenceTarget or deps.revalidateCadenceTarget(userId, target))
			then
				local _, targetKilled, attackerKilled =
					applyCadenceHit(userId, target, 7, strikes.abilityId, currentNow)
				if targetKilled or attackerKilled then
					pendingCadenceStrikes[userId] = nil
					reentryUntil[userId] = nil
					continue
				end
			end
		end
		if currentNow >= strikes.secondAt then
			pendingCadenceStrikes[userId] = nil
			if
				target
				and target.health > 0
				and (not deps.revalidateCadenceTarget or deps.revalidateCadenceTarget(userId, target))
			then
				local _, targetKilled, attackerKilled =
					applyCadenceHit(userId, target, 9, strikes.abilityId, currentNow)
				if targetKilled or attackerKilled then
					reentryUntil[userId] = nil
				end
			end
		end
	end
	for userId, echo in pendingEchos do
		if currentNow >= echo.at then
			pendingEchos[userId] = nil
			local target = echo.target
			if
				target
				and target.health > 0
				and (not deps.revalidateCadenceTarget or deps.revalidateCadenceTarget(userId, target))
			then
				local connected = select(1, applyCadenceHit(userId, target, 6, echo.abilityId, currentNow))
				if connected then
					local flowGranted = deps.tryGrantFlow(userId)
					if deps.onFlowEcho then
						deps.onFlowEcho(userId, echo.abilityId, flowGranted)
					end
				end
			end
		end
	end
	for userId, stance in pulseStances do
		if currentNow >= stance.expiresAt then
			pulseStances[userId] = nil
			if deps.expirePulseStance and deps.getFighterById then
				local fighter = deps.getFighterById(stance.fighterId)
				if fighter then
					deps.expirePulseStance(fighter, currentNow)
				end
			end
		end
	end
end

local function cometShoulderRunner(attacker: ServerPlayerState, target: ServerPlayerState?, _payload: AbilityPayload)
	local deps = AbilityService.deps
	if not deps then
		return
	end
	-- Caminho espacial: avança de fato e acerta quem estiver na cápsula.
	-- Avanço sem alvo é resultado válido (custo e cooldown já foram pagos).
	if deps.resolveCometShoulder and deps.tryCometShoulder and deps.getAttackerFighter and deps.getFighterById then
		local attackerFighter = deps.getAttackerFighter(attacker.userId)
		if attackerFighter then
			local resolution = deps.resolveCometShoulder(attacker.userId)
			if resolution and resolution.targetId then
				local targetFighter = deps.getFighterById(resolution.targetId)
				if targetFighter then
					local hitAt = now()
					local hit = deps.tryCometShoulder(attackerFighter, targetFighter, hitAt, resolution.facing)
					if hit and hit.ok and not hit.iframe then
						if hit.pulseCounter and deps.onPulseCounter then
							deps.onPulseCounter(attacker.userId, targetFighter, hitAt)
						end
						local outcome = if hit.parried or hit.stoppedOnGuard or hit.pulseCounter then "guard" else "hit"
						notifyCombatHit(
							attacker.userId,
							targetFighter,
							hit.damage,
							"comet_shoulder",
							hit.killed,
							outcome
						)
					end
				end
			end
			return
		end
	end
	if deps.tryCometShoulder and deps.getAttackerFighter and deps.getAbilityTarget then
		local attackerFighter = deps.getAttackerFighter(attacker.userId)
		local targetFighter = deps.getAbilityTarget(attacker.userId)
		if attackerFighter and targetFighter then
			local hitAt = now()
			local hit = deps.tryCometShoulder(attackerFighter, targetFighter, hitAt, "front")
			if hit and hit.ok and not hit.iframe then
				if hit.pulseCounter and deps.onPulseCounter then
					deps.onPulseCounter(attacker.userId, targetFighter, hitAt)
				end
				local outcome = if hit.parried or hit.stoppedOnGuard or hit.pulseCounter then "guard" else "hit"
				notifyCombatHit(attacker.userId, targetFighter, hit.damage, "comet_shoulder", hit.killed, outcome)
			end
			return
		end
	end
	if not target then
		return
	end
	deps.applyDamage(target, 14, attacker.userId)
end

local function brokenCadenceRunner(attacker: ServerPlayerState, target: ServerPlayerState?, payload: AbilityPayload)
	local deps = AbilityService.deps
	if not deps then
		return
	end
	local resolvedTarget: any = target
	if not resolvedTarget and deps.resolveCadenceTarget then
		resolvedTarget = deps.resolveCadenceTarget(attacker.userId)
	end
	local activatedAt = now()
	-- O alvo é preservado, mas cada active revalida hitbox/zona. O cliente nunca
	-- escolhe vítima nem antecipa o resultado pelo timestamp local.
	if resolvedTarget then
		pendingCadenceStrikes[attacker.userId] = {
			abilityId = "broken_cadence",
			target = resolvedTarget,
			firstAt = activatedAt + 0.14,
			secondAt = activatedAt + 0.32,
			firstResolved = false,
		}
	end
	-- Janela de reentrada: 120 ms após o fim do active do golpe 2.
	reentryUntil[attacker.userId] = {
		abilityId = "broken_cadence",
		opensAt = activatedAt + CADENCE_REENTRY_OPENS_MS / 1000,
		expiresAt = activatedAt + (CADENCE_REENTRY_OPENS_MS + CADENCE_REENTRY_WINDOW_MS) / 1000,
		target = resolvedTarget,
		executionId = payload.executionId,
	}
end

local function pulseReturnRunner(attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: AbilityPayload)
	local deps = AbilityService.deps
	if not deps then
		return
	end
	-- Ativação: abre a postura de 250 ms no FighterState do jogador. O golpe
	-- frontal reduzido (CombatService.applyHit) dispara o contra com dano 8 e
	-- empurrão — quem causou o golpe resolve o contra (docs/13 §6.3).
	if deps.getAttackerFighter and deps.setPulseStance then
		local fighter = deps.getAttackerFighter(attacker.userId)
		if fighter then
			local opened = deps.setPulseStance(fighter, now())
			if not opened then
				return
			end
			pulseStances[attacker.userId] = {
				fighterId = fighter.id,
				expiresAt = now() + PULSE_STANCE_MS / 1000,
			}
		end
	end
end

local function eclipseBeatRunner(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: AbilityPayload)
	-- Stretch F0: enabled = false; runner não deve ser chamado.
end

function AbilityService.init(deps: AbilityDeps): ()
	AbilityService.deps = deps
	table.clear(reentryUntil)
	table.clear(pendingCadenceStrikes)
	table.clear(pendingEchos)
	table.clear(pulseStances)
	AbilityService.runners = {
		comet_shoulder_runner = cometShoulderRunner,
		broken_cadence_runner = brokenCadenceRunner,
		pulse_return_runner = pulseReturnRunner,
		eclipse_beat_runner = eclipseBeatRunner,
	}
end

function AbilityService.clearPlayer(userId: number): ()
	reentryUntil[userId] = nil
	pendingCadenceStrikes[userId] = nil
	pendingEchos[userId] = nil
	pulseStances[userId] = nil
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
	if not window or window.abilityId ~= abilityId then
		reentryUntil[attacker.userId] = nil
		return false, "reentry_window"
	end
	if window.executionId ~= nil and payload.executionId ~= window.executionId then
		return false, "execution_mismatch"
	end
	if now() < window.opensAt then
		-- Ainda não abriu: clique prematuro NÃO destrói a janela (o jogador
		-- pode reentrar quando ela abrir).
		return false, "reentry_window"
	end
	if now() > window.expiresAt then
		reentryUntil[attacker.userId] = nil
		return false, "reentry_window"
	end
	reentryUntil[attacker.userId] = nil
	local ability = deps.getAbility(abilityId)
	if not ability then
		return false, "unknown_ability"
	end
	-- A reentrada não gasta recurso nem reinicia cooldown: só agenda o eco.
	pendingEchos[attacker.userId] = {
		at = now() + CADENCE_ECHO_DELAY_MS / 1000,
		-- O alvo da ativação inicial prevalece. O fallback preserva chamadas
		-- headless antigas que só fornecem alvo no segundo passo.
		target = window.target or target,
		abilityId = abilityId,
	}
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

	-- Preflight do Pulso antes de consumir recurso/cooldown. A tentativa real no
	-- runner usa o mesmo instante lógico e só materializa o estado.
	if abilityId == "pulse_return" and deps.getAttackerFighter and deps.setPulseStance then
		local fighter = deps.getAttackerFighter(attacker.userId)
		if not fighter then
			return false, "missing_fighter"
		end
		if fighter.pulseRecoveryUntil and now() < fighter.pulseRecoveryUntil then
			return false, "recovery"
		end
	end

	if not deps.trySpendResource(attacker.userId, ability.resourceCost.amount) then
		return false, "no_resource"
	end

	deps.startCooldown(attacker.userId, abilityId, ability.cooldown.baseSeconds)
	runner(attacker, target, resolved)
	return true
end

return AbilityService

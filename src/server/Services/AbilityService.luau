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
	getAttackerFighter: ((number) -> any?)?,
	getAbilityTarget: ((number) -> any?)?,
	tryCometShoulder: ((any, any, number, string) -> any)?,
	onCombatHit: ((number, string, number, string) -> ())?,
	-- Camada espacial (item 5): resolve o avanço de 7 studs, commita a posição
	-- e devolve alvo + lado do golpe. Ausente = fatia headless usa
	-- `getAbilityTarget` (dummy fixo), que é o comportamento anterior.
	resolveCometShoulder: ((number) -> any)?,
	getFighterById: ((string) -> any?)?,
	-- Retorno de Pulso (item 10): abre a postura no FighterState do jogador e
	-- expira a postura sem golpe (erro → recovery 600 ms).
	setPulseStance: ((any, number) -> ())?,
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
local CADENCE_REENTRY_WINDOW_MS = 120
-- Eco: 350 ms após a reentrada (docs/13 §6.2).
local CADENCE_ECHO_DELAY_MS = 350
-- Postura do Retorno de Pulso: 250 ms (docs/13 §6.3).
local PULSE_STANCE_MS = 250

local reentryUntil: { [number]: { abilityId: string, opensAt: number, expiresAt: number } } = {}
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

-- Resolve ecos pendentes da Cadência (docs/13 §6.2): 350 ms após a reentrada,
-- dano 4 na mesma hitbox; o eco que acerta gera Fluxo e dispara onFlowEcho.
-- Também expira posturas do Pulso sem golpe (erro → recovery 600 ms, §6.3).
-- Chamado pelo Heartbeat do bootstrap (e pelos testes com relógio fake).
function AbilityService.tick(currentNow: number): ()
	local deps = AbilityService.deps
	if not deps then
		return
	end
	for userId, echo in pendingEchos do
		if currentNow >= echo.at then
			pendingEchos[userId] = nil
			local target = echo.target
			if target and target.health > 0 then
				deps.applyDamage(target, 4, userId)
				local flowGranted = deps.tryGrantFlow(userId)
				if deps.onFlowEcho then
					deps.onFlowEcho(userId, echo.abilityId, flowGranted)
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
					local hit = deps.tryCometShoulder(attackerFighter, targetFighter, now(), resolution.facing)
					if deps.onCombatHit and hit and hit.ok then
						deps.onCombatHit(attacker.userId, targetFighter.id, hit.damage, "comet_shoulder")
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
			local hit = deps.tryCometShoulder(attackerFighter, targetFighter, now(), "front")
			if deps.onCombatHit and hit and hit.ok then
				deps.onCombatHit(attacker.userId, targetFighter.id, hit.damage, "comet_shoulder")
			end
			return
		end
	end
	if not target then
		return
	end
	deps.applyDamage(target, 9, attacker.userId)
end

local function brokenCadenceRunner(attacker: ServerPlayerState, target: ServerPlayerState?, _payload: AbilityPayload)
	local deps = AbilityService.deps
	if not deps then
		return
	end
	-- Golpe 1 (dano 5) e golpe 2 (dano 6) conectam na ativação; o timing de
	-- startup/active/recovery é executado no Studio (a fatia headless confirma
	-- o dano). O golpe 2 só sai se o golpe 1 não matou.
	if target then
		if deps.applyDamage(target, 5, attacker.userId) then
			return
		end
		deps.applyDamage(target, 6, attacker.userId)
	end
	-- Janela de reentrada: 120 ms após o fim do active do golpe 2.
	reentryUntil[attacker.userId] = {
		abilityId = "broken_cadence",
		opensAt = now() + CADENCE_REENTRY_OPENS_MS / 1000,
		expiresAt = now() + (CADENCE_REENTRY_OPENS_MS + CADENCE_REENTRY_WINDOW_MS) / 1000,
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
			deps.setPulseStance(fighter, now())
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
	table.clear(pendingEchos)
	table.clear(pulseStances)
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
	_payload: AbilityPayload
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
		target = target,
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

	if not deps.trySpendResource(attacker.userId, ability.resourceCost.amount) then
		return false, "no_resource"
	end

	deps.startCooldown(attacker.userId, abilityId, ability.cooldown.baseSeconds)
	runner(attacker, target, resolved)
	return true
end

return AbilityService

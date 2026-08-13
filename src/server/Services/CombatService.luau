--!strict
-- CombatService (server) — F0 (docs/13-F0-SLICE.md §5, §6.1 e §9)
-- Dano, guarda, aparo, cadeia leve, pesado, dash, dummy, Ombro Cometa e
-- Estilhaço Errante (idle → telegraph → ataque → recovery). Autoridade total;
-- cliente nunca informa dano. Puro (sem Instances) — testável.
-- applyDamage permanece para AbilityService (estado de recurso / Cadência / Pulso).

export type ServerPlayerState = {
	userId: number,
	characterId: string,
	health: number,
	resource: number,
	familyId: string,
	combat: boolean,
	lastCombatAt: number,
}

export type FighterState = {
	id: string,
	kind: "player" | "npc",
	health: number,
	maxHealth: number,
	guard: number,
	maxGuard: number,
	guarding: boolean,
	guardDownAt: number,
	cannotGuardUntil: number,
	lightStep: number,
	lastLightAt: number,
	heavyMissUntil: number,
	dashCooldownUntil: number,
	iframeUntil: number,
	lastDummyAttackAt: number,
	aiPhase: "idle" | "telegraph" | "recovery",
	aiPhaseUntil: number,
	diedAt: number,
	-- Retorno de Pulso (docs/13 §6.3): postura de 250 ms que reduz 50% de UM
	-- golpe frontal. `pulseStanceUsed` evita reduzir mais de um golpe por
	-- postura. `pulseRecoveryUntil` é o erro da postura (600 ms sem golpe).
	pulseStanceUntil: number,
	pulseStanceUsed: boolean,
	pulseRecoveryUntil: number,
	-- Padrão do ciclo do elite (docs/13 §9.3): alterna combo leve e slam.
	elitePattern: "combo" | "slam",
}

export type HitFacing = "front" | "back"

export type HitResult = {
	ok: boolean,
	reason: string?,
	damage: number,
	step: number?,
	parried: boolean?,
	broken: boolean?,
	iframe: boolean?,
	stoppedOnGuard: boolean?,
	pulseCounter: boolean?,
	phase: string?,
	-- true só na transição vivo → morto (crédito de XP/objetivo é idempotente).
	killed: boolean?,
}

local LIGHT_DAMAGE = { 6, 6, 8, 12 }
local LIGHT_WINDOW = 0.65
local PARRY_WINDOW = 0.12
local HEAVY_HP = 12
local HEAVY_GUARD = 28
local HEAVY_BLOCKED_HP = 2
local HEAVY_MISS_LOCK = 0.5
local BREAK_NO_GUARD = 1.2
local DASH_COOLDOWN = 3.0
local DASH_IFRAME = 0.08
-- Retorno de Pulso (docs/13 §6.3): postura 250 ms, contra 10, empurrão 8 studs
-- (espacial — fora deste serviço), erro 600 ms.
local PULSE_STANCE_MS = 250
local PULSE_COUNTER_DAMAGE = 10
local PULSE_MISS_RECOVERY_MS = 600

local CombatService = {
	fighters = {} :: { [string]: FighterState },
}

local function fail(reason: string): HitResult
	return { ok = false, reason = reason, damage = 0 }
end

function CombatService.playerFighterId(userId: number): string
	return "player:" .. tostring(userId)
end

function CombatService.clear(): ()
	table.clear(CombatService.fighters)
end

function CombatService.createFighter(
	id: string,
	kind: "player" | "npc",
	maxHealth: number,
	maxGuard: number
): FighterState
	local fighter: FighterState = {
		id = id,
		kind = kind,
		health = maxHealth,
		maxHealth = maxHealth,
		guard = maxGuard,
		maxGuard = maxGuard,
		guarding = false,
		guardDownAt = 0,
		cannotGuardUntil = 0,
		lightStep = 0,
		lastLightAt = 0,
		heavyMissUntil = 0,
		dashCooldownUntil = 0,
		iframeUntil = 0,
		lastDummyAttackAt = 0,
		aiPhase = "idle",
		aiPhaseUntil = 0,
		diedAt = 0,
		pulseStanceUntil = 0,
		pulseStanceUsed = false,
		pulseRecoveryUntil = 0,
		elitePattern = "combo",
	}
	CombatService.fighters[id] = fighter
	return fighter
end

function CombatService.getFighter(id: string): FighterState?
	return CombatService.fighters[id]
end

function CombatService.removeFighter(id: string): ()
	CombatService.fighters[id] = nil
end

function CombatService.isAlive(state: ServerPlayerState | FighterState): boolean
	return state.health > 0
end

-- Aplica dano confirmado no estado de recurso/sessão (AbilityService).
function CombatService.applyDamage(target: ServerPlayerState, damage: number, _sourceUserId: number?): boolean
	if damage < 0 then
		return false
	end
	target.health -= damage
	if target.health <= 0 then
		target.health = 0
		return true
	end
	return false
end

function CombatService.setGuard(fighter: FighterState, down: boolean, now: number): (boolean, string?)
	if down then
		if now < fighter.cannotGuardUntil then
			return false, "guard_broken"
		end
		-- A janela de aparo nasce apenas na borda false → true. Repetir o
		-- mesmo GuardIntent não pode renovar indefinidamente os 120 ms.
		if fighter.guarding then
			return true, nil
		end
		fighter.guarding = true
		fighter.guardDownAt = now
		return true, nil
	end
	fighter.guarding = false
	return true, nil
end

function CombatService.canDash(fighter: FighterState, now: number): (boolean, string?)
	if fighter.health <= 0 then
		return false, "dead"
	end
	if CombatService.isPulseRecovery(fighter, now) then
		return false, "recovery"
	end
	if now < fighter.dashCooldownUntil then
		return false, "cooldown"
	end
	return true, nil
end

function CombatService.commitDash(fighter: FighterState, now: number): ()
	fighter.dashCooldownUntil = now + DASH_COOLDOWN
	fighter.iframeUntil = now + DASH_IFRAME
	return
end

function CombatService.tryDash(fighter: FighterState, now: number): (boolean, string?)
	local allowed, reason = CombatService.canDash(fighter, now)
	if not allowed then
		return false, reason
	end
	CombatService.commitDash(fighter, now)
	return true, nil
end

local function applyHit(
	target: FighterState,
	now: number,
	rawHp: number,
	guardDamage: number,
	blockedHp: number,
	facing: HitFacing,
	parryable: boolean,
	unblockablePulse: boolean?
): HitResult
	if now < target.iframeUntil then
		return { ok = true, damage = 0, iframe = true }
	end
	-- Retorno de Pulso (docs/13 §6.3): a postura reduz 50% de UM golpe frontal.
	-- Não reduz golpe pelas costas, nem golpe `unblockable` (slam do elite), nem
	-- golpe contra um alvo já em quebra (pesado de break). Só o primeiro golpe
	-- da janela de 250 ms é reduzido (`pulseStanceUsed`).
	if
		now < target.pulseStanceUntil
		and not target.pulseStanceUsed
		and facing ~= "back"
		and not unblockablePulse
		and now >= target.cannotGuardUntil
	then
		local reduced = math.floor(rawHp * 0.5)
		target.pulseStanceUsed = true
		target.health = math.max(0, target.health - reduced)
		if target.health <= 0 then
			target.diedAt = now
			return { ok = true, damage = reduced, pulseCounter = true, killed = true }
		end
		return { ok = true, damage = reduced, pulseCounter = true }
	end
	-- Golpe em alvo já morto não re-carimba diedAt (não empurra o respawn).
	local wasAlive = target.health > 0
	local guarding = target.guarding and now >= target.cannotGuardUntil and facing ~= "back"
	if not guarding then
		target.health = math.max(0, target.health - rawHp)
		if target.health <= 0 and wasAlive then
			target.diedAt = now
			return { ok = true, damage = rawHp, killed = true }
		end
		return { ok = true, damage = rawHp }
	end
	if parryable and (now - target.guardDownAt) <= PARRY_WINDOW then
		return { ok = true, damage = 0, parried = true }
	end
	local hp = blockedHp
	local nextGuard = target.guard - guardDamage
	local broken = false
	if nextGuard <= 0 then
		hp += math.floor(-nextGuard * 0.5)
		target.guard = 0
		target.guarding = false
		target.cannotGuardUntil = now + BREAK_NO_GUARD
		broken = true
	else
		target.guard = nextGuard
	end
	target.health = math.max(0, target.health - hp)
	local killed = false
	if target.health <= 0 and wasAlive then
		target.diedAt = now
		killed = true
	end
	return { ok = true, damage = hp, broken = broken, killed = killed or nil }
end

-- Entra na postura do Retorno de Pulso (docs/13 §6.3): 250 ms, UM golpe frontal.
function CombatService.setPulseStance(fighter: FighterState, now: number): (boolean, string?)
	if now < fighter.pulseRecoveryUntil then
		return false, "recovery"
	end
	fighter.pulseStanceUntil = now + PULSE_STANCE_MS / 1000
	fighter.pulseStanceUsed = false
	return true, nil
end

-- Erro da postura (docs/13 §6.3): postura expira sem golpe → recovery 600 ms.
function CombatService.pulseTick(fighter: FighterState, now: number): (boolean, string?)
	if fighter.pulseStanceUntil <= 0 then
		return false, "no_stance"
	end
	if now >= fighter.pulseStanceUntil then
		fighter.pulseStanceUntil = 0
		if not fighter.pulseStanceUsed then
			fighter.pulseRecoveryUntil = now + PULSE_MISS_RECOVERY_MS / 1000
			return true, "miss"
		end
	end
	return false, "active"
end

function CombatService.isPulseRecovery(fighter: FighterState, now: number): boolean
	return now < fighter.pulseRecoveryUntil
end

-- Contra do Retorno de Pulso: 8 de dano no atacante (empurrão de 8 studs é
-- espacial — quem chama move o fighter; docs/13 §6.3).
function CombatService.tryPulseCounter(attacker: FighterState, now: number): HitResult
	if attacker.health <= 0 then
		return fail("dead")
	end
	attacker.health = math.max(0, attacker.health - PULSE_COUNTER_DAMAGE)
	local killed = false
	if attacker.health <= 0 then
		attacker.diedAt = now
		killed = true
	end
	return { ok = true, damage = PULSE_COUNTER_DAMAGE, killed = killed or nil }
end

function CombatService.tryLight(attacker: FighterState, target: FighterState, now: number, facing: HitFacing): HitResult
	if attacker.health <= 0 then
		return fail("dead")
	end
	if CombatService.isPulseRecovery(attacker, now) then
		return fail("recovery")
	end
	if now < attacker.heavyMissUntil then
		return fail("heavy_miss")
	end
	local step = 1
	if attacker.lightStep > 0 and attacker.lightStep < 4 and (now - attacker.lastLightAt) <= LIGHT_WINDOW then
		step = attacker.lightStep + 1
	end
	local raw = LIGHT_DAMAGE[step]
	local blocked = math.floor(raw * 0.4)
	local result = applyHit(target, now, raw, raw, blocked, facing, true)
	if not result.ok then
		return result
	end
	attacker.lightStep = step
	attacker.lastLightAt = now
	result.step = step
	return result
end

function CombatService.tryHeavy(
	attacker: FighterState,
	target: FighterState?,
	now: number,
	facing: HitFacing
): HitResult
	if attacker.health <= 0 then
		return fail("dead")
	end
	if CombatService.isPulseRecovery(attacker, now) then
		return fail("recovery")
	end
	if target == nil then
		attacker.heavyMissUntil = now + HEAVY_MISS_LOCK
		attacker.lightStep = 0
		return fail("miss")
	end
	local result = applyHit(target, now, HEAVY_HP, HEAVY_GUARD, HEAVY_BLOCKED_HP, facing, true)
	if result.ok then
		attacker.lightStep = 0
		attacker.lastLightAt = 0
	end
	return result
end

-- Evento S→C do básico. Sem `damage` o HUD não desenha o número; o cliente
-- nunca inventa esse valor (docs/18 — playtest 13/08).
function CombatService.basicCombatEvent(
	result: HitResult?,
	kind: string,
	targetId: string?,
	targetGuarding: boolean
): { [string]: any }
	local isHeavy = kind == "heavy"
	if not result or not result.ok then
		return {
			abilityId = if isHeavy then "heavy" else "light",
			outcome = "miss",
			damage = 0,
			step = 0,
		}
	end
	local outcome = if result.parried
			or result.stoppedOnGuard
			or result.broken
			or result.pulseCounter
			or targetGuarding
		then "guard"
		else "hit"
	return {
		targetId = targetId,
		abilityId = if isHeavy then "heavy" else "light",
		outcome = outcome,
		damage = result.damage,
		step = if isHeavy then 0 else (result.step or 0),
	}
end

function CombatService.tryCometShoulder(
	attacker: FighterState,
	target: FighterState,
	now: number,
	facing: HitFacing
): HitResult
	if attacker.health <= 0 then
		return fail("dead")
	end
	local wasGuarding = target.guarding and now >= target.cannotGuardUntil and facing ~= "back"
	local result = applyHit(target, now, 14, 14, 6, facing, true)
	if result.ok and wasGuarding and not result.iframe then
		result.stoppedOnGuard = true
	end
	return result
end

-- Impacto da Cadência/eco: respeita i-frame, guarda, aparo e Retorno de Pulso
-- como qualquer golpe frontal.
function CombatService.tryCadenceHit(
	attacker: FighterState,
	target: FighterState,
	now: number,
	damage: number,
	facing: HitFacing
): HitResult
	if attacker.health <= 0 then
		return fail("dead")
	end
	local wasGuarding = target.guarding and now >= target.cannotGuardUntil and facing ~= "back"
	local result = applyHit(target, now, damage, damage, math.floor(damage * 0.4), facing, true)
	if result.ok and wasGuarding and not result.iframe then
		result.stoppedOnGuard = true
	end
	return result
end

function CombatService.tryDummyAttack(
	dummy: FighterState,
	target: FighterState,
	now: number,
	distance: number,
	period: number,
	damage: number,
	range: number
): HitResult
	if dummy.health <= 0 then
		return fail("dead")
	end
	if distance > range then
		return fail("out_of_range")
	end
	if dummy.lastDummyAttackAt > 0 and (now - dummy.lastDummyAttackAt) < period then
		return fail("cooldown")
	end
	dummy.lastDummyAttackAt = now
	return applyHit(target, now, damage, damage, math.floor(damage * 0.4), "front", true)
end

function CombatService.countAliveNpcs(idPrefix: string): number
	local n = 0
	local prefixLen = #idPrefix
	for id, fighter in CombatService.fighters do
		if fighter.kind == "npc" and fighter.health > 0 and string.sub(id, 1, prefixLen) == idPrefix then
			n += 1
		end
	end
	return n
end

function CombatService.canSpawnNpc(idPrefix: string, maxAlive: number): boolean
	return CombatService.countAliveNpcs(idPrefix) < maxAlive
end

function CombatService.tryRespawn(
	fighter: FighterState,
	now: number,
	respawnSeconds: number,
	combatNearby: boolean
): (boolean, string?)
	if fighter.health > 0 then
		return false, "alive"
	end
	if combatNearby then
		return false, "combat_nearby"
	end
	if fighter.diedAt <= 0 or (now - fighter.diedAt) < respawnSeconds then
		return false, "respawn_wait"
	end
	fighter.health = fighter.maxHealth
	fighter.diedAt = 0
	fighter.aiPhase = "idle"
	fighter.aiPhaseUntil = 0
	return true, nil
end

-- Estilhaço Errante: idle → telegraph → ataque → recovery.
-- `canAggro` vem do ZoneService (sem aggro através da fronteira).
function CombatService.tryShardCycle(
	shard: FighterState,
	target: FighterState,
	now: number,
	distance: number,
	canAggro: boolean,
	damage: number,
	range: number,
	telegraphSeconds: number,
	recoverySeconds: number
): HitResult
	if shard.health <= 0 then
		return fail("dead")
	end
	if not canAggro then
		shard.aiPhase = "idle"
		shard.aiPhaseUntil = 0
		return fail("no_aggro")
	end
	if distance > range then
		shard.aiPhase = "idle"
		shard.aiPhaseUntil = 0
		return fail("out_of_range")
	end
	if shard.aiPhase == "recovery" then
		if now < shard.aiPhaseUntil then
			return fail("recovery")
		end
		shard.aiPhase = "idle"
	end
	if shard.aiPhase == "idle" then
		shard.aiPhase = "telegraph"
		shard.aiPhaseUntil = now + telegraphSeconds
		return { ok = true, damage = 0, phase = "telegraph" }
	end
	if shard.aiPhase == "telegraph" then
		if now < shard.aiPhaseUntil then
			return fail("telegraph")
		end
		local result = applyHit(target, now, damage, damage, math.floor(damage * 0.4), "front", true)
		shard.aiPhase = "recovery"
		shard.aiPhaseUntil = now + recoverySeconds
		if result.ok then
			result.phase = "attack"
		end
		return result
	end
	return fail("idle")
end

-- Estilhaço Ancorado — elite da cratera (docs/13 §9.3). Máquina igual à do
-- shard, mas com DOIS ataques alternados por ciclo: combo leve 5+5
-- (telegraph 300 ms) e slam (telegraph 700 ms, dano 12, `unblockable` para o
-- Retorno de Pulso, guarda reduz apenas 30% → 70% do dano passa).
-- `params` espelha as colunas do catálogo (Npcs.luau).
export type EliteCycleParams = {
	range: number,
	recoverySeconds: number,
	comboDamage: number,
	comboTelegraphSeconds: number,
	slamDamage: number,
	slamTelegraphSeconds: number,
	-- Guarda reduz 30%: o dano que passa bloqueado é 70% do slam (§9.3).
	slamBlockedPct: number,
}

function CombatService.tryEliteCycle(
	elite: FighterState,
	target: FighterState,
	now: number,
	distance: number,
	canAggro: boolean,
	params: EliteCycleParams
): HitResult
	if elite.health <= 0 then
		return fail("dead")
	end
	if not canAggro then
		elite.aiPhase = "idle"
		elite.aiPhaseUntil = 0
		return fail("no_aggro")
	end
	if distance > params.range then
		elite.aiPhase = "idle"
		elite.aiPhaseUntil = 0
		return fail("out_of_range")
	end
	if elite.aiPhase == "recovery" then
		if now < elite.aiPhaseUntil then
			return fail("recovery")
		end
		elite.aiPhase = "idle"
		-- Ciclo completo: alterna o padrão do próximo ataque.
		elite.elitePattern = if elite.elitePattern == "slam" then "combo" else "slam"
	end
	if elite.aiPhase == "idle" then
		elite.aiPhase = "telegraph"
		local telegraph = if elite.elitePattern == "slam"
			then params.slamTelegraphSeconds
			else params.comboTelegraphSeconds
		elite.aiPhaseUntil = now + telegraph
		return { ok = true, damage = 0, phase = "telegraph" }
	end
	if elite.aiPhase == "telegraph" then
		if now < elite.aiPhaseUntil then
			return fail("telegraph")
		end
		local result: HitResult
		if elite.elitePattern == "slam" then
			-- Slam: unblockable para o Pulso (a postura não reduz) e a guarda
			-- só corta 30% (blockedHp = 70% do dano). Parryable false: o slam
			-- não é um leve — sem janela de aparo (§9.3 não lista aparo).
			result = applyHit(
				target,
				now,
				params.slamDamage,
				params.slamDamage,
				math.ceil(params.slamDamage * params.slamBlockedPct),
				"front",
				false,
				true
			)
		else
			-- Combo leve 5+5: dois golpes no mesmo active; o segundo só sai
			-- se o primeiro não matou.
			local first = applyHit(
				target,
				now,
				params.comboDamage,
				params.comboDamage,
				math.floor(params.comboDamage * 0.4),
				"front",
				true
			)
			if not first.ok then
				return first
			end
			-- Aparo, i-frame ou Retorno de Pulso interrompem o combo no primeiro
			-- contato. O flag do Pulso precisa chegar ao EnemyService para que o
			-- contra de 8 e o empurrão sejam resolvidos no agressor.
			if first.killed or first.pulseCounter or first.parried or first.iframe then
				result = first
			else
				result = applyHit(
					target,
					now + 0.1,
					params.comboDamage,
					params.comboDamage,
					math.floor(params.comboDamage * 0.4),
					"front",
					true
				)
				result.damage += first.damage
				result.broken = result.broken or first.broken
			end
		end
		elite.aiPhase = "recovery"
		elite.aiPhaseUntil = now + params.recoverySeconds
		if result.ok then
			result.phase = "attack"
		end
		return result
	end
	return fail("idle")
end

return CombatService

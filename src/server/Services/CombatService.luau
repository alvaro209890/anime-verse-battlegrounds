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
	phase: string?,
}

local LIGHT_DAMAGE = { 5, 5, 6, 10 }
local LIGHT_WINDOW = 0.65
local PARRY_WINDOW = 0.12
local HEAVY_HP = 10
local HEAVY_GUARD = 28
local HEAVY_BLOCKED_HP = 2
local HEAVY_MISS_LOCK = 0.5
local BREAK_NO_GUARD = 1.2
local DASH_COOLDOWN = 3.0
local DASH_IFRAME = 0.08

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
		fighter.guarding = true
		fighter.guardDownAt = now
		return true, nil
	end
	fighter.guarding = false
	return true, nil
end

function CombatService.tryDash(fighter: FighterState, now: number): (boolean, string?)
	if now < fighter.dashCooldownUntil then
		return false, "cooldown"
	end
	fighter.dashCooldownUntil = now + DASH_COOLDOWN
	fighter.iframeUntil = now + DASH_IFRAME
	return true, nil
end

local function applyHit(
	target: FighterState,
	now: number,
	rawHp: number,
	guardDamage: number,
	blockedHp: number,
	facing: HitFacing,
	parryable: boolean
): HitResult
	if now < target.iframeUntil then
		return { ok = true, damage = 0, iframe = true }
	end
	local guarding = target.guarding and now >= target.cannotGuardUntil and facing ~= "back"
	if not guarding then
		target.health = math.max(0, target.health - rawHp)
		if target.health <= 0 then
			target.diedAt = now
		end
		return { ok = true, damage = rawHp }
	end
	if parryable and (now - target.guardDownAt) <= PARRY_WINDOW then
		return { ok = true, damage = 0, parried = true }
	end
	local hp = blockedHp
	local nextGuard = target.guard - guardDamage
	local broken = false
	if nextGuard < 0 then
		hp += math.floor(-nextGuard * 0.5)
		target.guard = 0
		target.guarding = false
		target.cannotGuardUntil = now + BREAK_NO_GUARD
		broken = true
	else
		target.guard = nextGuard
	end
	target.health = math.max(0, target.health - hp)
	if target.health <= 0 then
		target.diedAt = now
	end
	return { ok = true, damage = hp, broken = broken }
end

function CombatService.tryLight(attacker: FighterState, target: FighterState, now: number, facing: HitFacing): HitResult
	if attacker.health <= 0 then
		return fail("dead")
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
	local result = applyHit(target, now, 9, 9, 4, facing, true)
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

return CombatService

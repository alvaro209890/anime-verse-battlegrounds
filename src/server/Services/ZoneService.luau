--!strict
-- ZoneService (server) — F0 (docs/04 §4.1, docs/13-F0-SLICE.md §8, docs/02-WORLD.md §4)
-- Zona atual do jogador, regras PvP, transição de 5 s na saída da segura,
-- lockout de 15 s na entrada da segura e os 5 sinais da fronteira.
-- Domínio headless: sem Instances, relógio injetado (`now`). O bootstrap liga
-- `onZoneEvent` ao remote ZoneEvent (S→C). O volume físico no Studio só
-- decide QUANDO cruzar; a regra é toda aqui.
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type ZoneEventPayload = {
	from: string,
	to: string,
	pvp: boolean,
	signals: { string },
	holdConfirmed: boolean,
	lockoutRemaining: number?,
	instant: number,
}

export type EnterZoneResult = {
	ok: boolean,
	reason: string?,
	event: ZoneEventPayload?,
	lockoutRemaining: number?,
}

export type ZoneServiceDeps = {
	getZone: (string) -> any?,
	getAnchor: (string) -> any?,
	now: () -> number,
	onZoneEvent: ((number, ZoneEventPayload) -> ())?,
}

export type TransitionState = {
	to: string,
	protectionUntil: number,
}

local ZoneService = {
	deps = nil :: ZoneServiceDeps?,
	-- userId → zona atual (default após join: zone_bastion_safe)
	zones = {} :: { [number]: string },
	-- userId → proteção da transição de 5 s (não causa nem recebe PvP)
	transitions = {} :: { [number]: TransitionState },
	-- userId → último timestamp de combate PvP (lockout de reentrada)
	pvpCombatAt = {} :: { [number]: number },
	-- userId → hold confirmado nesta sessão (primeira travessia exige)
	holdConfirmed = {} :: { [number]: boolean },
}

local ZONE_SAFE = "zone_bastion_safe"
local ZONE_TRANSITION = "zone_threshold_transition"
local ZONE_FREE = "zone_plain_free"
local TRANSITION_SECONDS = 5
local COMBAT_LOCKOUT_SECONDS = 15

-- Os 5 sinais da fronteira (docs/02-WORLD.md §4.2, docs/13-F0-SLICE.md §8.2).
local FRONTIER_SIGNALS: { string } = {
	"physical_gate",
	"lighting_material",
	"ui_banner",
	"audio_haptic",
	"persistent_indicator",
}

-- Lado da fronteira para dano atravessando: segura+transição = "safe",
-- livre = "free". Projétil/área não cruza safe↔free.
local function damageSide(zoneId: string): string
	if zoneId == ZONE_FREE then
		return "free"
	end
	return "safe"
end

-- A faixa de transição é a própria fronteira PvP: qualquer travessia que a
-- envolva (ou que pule direto segura↔livre) carrega os 5 sinais. Movimentação
-- interna da mesma zona (rejeitada em tryEnterZone) não tem sinais.
local function isFrontierCrossing(fromZoneId: string, toZoneId: string): boolean
	if fromZoneId == toZoneId then
		return false
	end
	if fromZoneId == ZONE_TRANSITION or toZoneId == ZONE_TRANSITION then
		return true
	end
	return damageSide(fromZoneId) ~= damageSide(toZoneId)
end

function ZoneService.init(deps: ZoneServiceDeps): ()
	if not deps.getZone(ZONE_SAFE) then
		error(("[ZoneService] zona segura %s ausente do catálogo"):format(ZONE_SAFE))
	end
	if not deps.getZone(ZONE_TRANSITION) then
		error(("[ZoneService] zona de transição %s ausente do catálogo"):format(ZONE_TRANSITION))
	end
	if not deps.getZone(ZONE_FREE) then
		error(("[ZoneService] zona livre %s ausente do catálogo"):format(ZONE_FREE))
	end
	ZoneService.deps = deps
	table.clear(ZoneService.zones)
	table.clear(ZoneService.transitions)
	table.clear(ZoneService.pvpCombatAt)
	table.clear(ZoneService.holdConfirmed)
end

function ZoneService.registerPlayer(userId: number): ()
	ZoneService.zones[userId] = ZONE_SAFE
	ZoneService.holdConfirmed[userId] = false
end

function ZoneService.unregisterPlayer(userId: number): ()
	ZoneService.zones[userId] = nil
	ZoneService.transitions[userId] = nil
	ZoneService.pvpCombatAt[userId] = nil
	ZoneService.holdConfirmed[userId] = nil
end

function ZoneService.getZone(zoneId: string): any?
	local deps = ZoneService.deps
	if not deps then
		return nil
	end
	return deps.getZone(zoneId)
end

function ZoneService.getAnchor(anchorId: string): any?
	local deps = ZoneService.deps
	if not deps then
		return nil
	end
	return deps.getAnchor(anchorId)
end

function ZoneService.getPlayerZone(userId: number): string
	return ZoneService.zones[userId] or ZONE_SAFE
end

function ZoneService.isInTransition(userId: number, now: number): boolean
	local transition = ZoneService.transitions[userId]
	if not transition then
		return false
	end
	if now >= transition.protectionUntil then
		ZoneService.transitions[userId] = nil
		return false
	end
	return true
end

function ZoneService.canPvp(userId: number): boolean
	local deps = ZoneService.deps
	if not deps then
		return false
	end
	if ZoneService.getPlayerZone(userId) ~= ZONE_FREE then
		return false
	end
	return not ZoneService.isInTransition(userId, deps.now())
end

function ZoneService.canPvpBetween(userIdA: number, userIdB: number): boolean
	if userIdA == userIdB then
		return false
	end
	return ZoneService.canPvp(userIdA) and ZoneService.canPvp(userIdB)
end

-- Projétil/área não atravessa a fronteira causando dano (docs/02-WORLD.md §4.3).
-- Empurrão, puxão e teleporte hostil usam a mesma regra.
function ZoneService.canDamageCrossBoundary(fromZoneId: string, toZoneId: string): boolean
	return damageSide(fromZoneId) == damageSide(toZoneId)
end

-- Os 5 sinais da fronteira, sempre juntos ao cruzar segura↔livre.
-- Movimentação interna da mesma zona (ou entre zonas do mesmo lado) não tem sinais.
function ZoneService.getFrontierSignals(fromZoneId: string, toZoneId: string): { string }?
	if not isFrontierCrossing(fromZoneId, toZoneId) then
		return nil
	end
	return table.clone(FRONTIER_SIGNALS)
end

function ZoneService.markPvpCombat(userId: number, now: number): ()
	ZoneService.pvpCombatAt[userId] = now
end

-- Ação hostil durante a proteção de saída: encerra a transição na hora e
-- ativa PvP se o destino for a livre (docs/13-F0-SLICE.md §8.2).
-- Treino na segura (dummy) NÃO marca combate PvP — senão o lockout de 15 s
-- bloquearia o retorno ao Bastião depois de bater no boneco.
function ZoneService.markHostileAction(userId: number, now: number): ()
	local transition = ZoneService.transitions[userId]
	if transition then
		ZoneService.transitions[userId] = nil
		if transition.to == ZONE_FREE then
			ZoneService.zones[userId] = ZONE_FREE
			ZoneService.pvpCombatAt[userId] = now
		end
		return
	end
	if ZoneService.getPlayerZone(userId) == ZONE_FREE then
		ZoneService.pvpCombatAt[userId] = now
	end
end

local function lockoutRemaining(userId: number, now: number): number?
	local last = ZoneService.pvpCombatAt[userId]
	if not last then
		return nil
	end
	local remaining = COMBAT_LOCKOUT_SECONDS - (now - last)
	if remaining > 0 then
		return remaining
	end
	return nil
end

local function emit(
	userId: number,
	fromZoneId: string,
	toZoneId: string,
	now: number,
	opts: { holdConfirmed: boolean? }
): ZoneEventPayload
	local event: ZoneEventPayload = {
		from = fromZoneId,
		to = toZoneId,
		pvp = false,
		signals = {},
		holdConfirmed = opts.holdConfirmed == true,
		instant = now,
	}
	local target = ZoneService.getZone(toZoneId)
	if target then
		event.pvp = target.pvp == true
	end
	local signals = ZoneService.getFrontierSignals(fromZoneId, toZoneId)
	if signals then
		event.signals = signals
	end
	local deps = ZoneService.deps
	if deps and deps.onZoneEvent then
		deps.onZoneEvent(userId, event)
	end
	return event
end

local function rejectLockout(
	userId: number,
	fromZoneId: string,
	toZoneId: string,
	now: number,
	remaining: number
): EnterZoneResult
	local event: ZoneEventPayload = {
		from = fromZoneId,
		to = toZoneId,
		pvp = false,
		signals = {},
		holdConfirmed = false,
		lockoutRemaining = remaining,
		instant = now,
	}
	local deps = ZoneService.deps
	if deps and deps.onZoneEvent then
		deps.onZoneEvent(userId, event)
	end
	return { ok = false, reason = "combat_lockout", lockoutRemaining = remaining, event = event }
end

-- Cruzamento de zona. `opts.holdConfirmed` é o flag do prompt "manter
-- pressionado" (0,6 s é cliente; o servidor só aceita o flag — SLICE-DEC-005).
--
-- Fluxo físico: segura → transição → livre → transição → segura.
function ZoneService.tryEnterZone(
	userId: number,
	toZoneId: string,
	now: number,
	opts: { holdConfirmed: boolean? }
): EnterZoneResult
	local deps = ZoneService.deps
	if not deps then
		return { ok = false, reason = "not_initialized" }
	end
	if deps.getZone(toZoneId) == nil then
		return { ok = false, reason = "unknown_zone" }
	end
	local fromZoneId = ZoneService.getPlayerZone(userId)
	if fromZoneId == toZoneId then
		return { ok = false, reason = "already_in_zone" }
	end

	-- Saindo da segura em direção à livre (via volume de transição).
	if toZoneId == ZONE_TRANSITION and fromZoneId == ZONE_SAFE then
		if not ZoneService.holdConfirmed[userId] and opts.holdConfirmed ~= true then
			return { ok = false, reason = "hold_required" }
		end
		ZoneService.holdConfirmed[userId] = true
		ZoneService.zones[userId] = ZONE_TRANSITION
		ZoneService.transitions[userId] = {
			to = ZONE_FREE,
			protectionUntil = now + TRANSITION_SECONDS,
		}
		local event = emit(userId, fromZoneId, toZoneId, now, { holdConfirmed = true })
		return { ok = true, event = event }
	end

	-- Cruzando da transição para a livre: proteção restante continua valendo.
	if toZoneId == ZONE_FREE then
		if not ZoneService.holdConfirmed[userId] and opts.holdConfirmed ~= true then
			return { ok = false, reason = "hold_required" }
		end
		ZoneService.holdConfirmed[userId] = true
		local transition = ZoneService.transitions[userId]
		-- Defesa em profundidade: sem passar pelo volume de transição,
		-- a proteção de 5 s começa aqui.
		if not transition then
			ZoneService.transitions[userId] = {
				to = ZONE_FREE,
				protectionUntil = now + TRANSITION_SECONDS,
			}
		end
		ZoneService.zones[userId] = ZONE_FREE
		local event = emit(userId, fromZoneId, toZoneId, now, { holdConfirmed = true })
		return { ok = true, event = event }
	end

	-- Volta: barreira interna bloqueia combate PvP recente (15 s, timer visível).
	if toZoneId == ZONE_TRANSITION and fromZoneId == ZONE_FREE then
		local remaining = lockoutRemaining(userId, now)
		if remaining then
			return rejectLockout(userId, fromZoneId, toZoneId, now, remaining)
		end
		ZoneService.zones[userId] = ZONE_TRANSITION
		ZoneService.transitions[userId] = nil
		local event = emit(userId, fromZoneId, toZoneId, now, {})
		return { ok = true, event = event }
	end

	-- Entrada na segura: livre, mas com a mesma barreira de lockout.
	if toZoneId == ZONE_SAFE then
		local remaining = lockoutRemaining(userId, now)
		if remaining then
			return rejectLockout(userId, fromZoneId, toZoneId, now, remaining)
		end
		ZoneService.zones[userId] = ZONE_SAFE
		ZoneService.transitions[userId] = nil
		local event = emit(userId, fromZoneId, toZoneId, now, {})
		return { ok = true, event = event }
	end

	return { ok = false, reason = "invalid_crossing" }
end

return ZoneService

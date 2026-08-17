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
	rejectedReason: string?,
}

export type EnterZoneResult = {
	ok: boolean,
	reason: string?,
	event: ZoneEventPayload?,
	lockoutRemaining: number?,
}

export type CrossingHoldResult = {
	ok: boolean,
	reason: string?,
	anchorId: string?,
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
	-- Evita repetir o banner de hold a cada Heartbeat dentro do volume.
	holdPromptedTarget = {} :: { [number]: string },
	-- Hold remoto da primeira saída: o servidor mede o intervalo e vincula o
	-- begin ao mesmo portão físico usado no complete.
	crossingHolds = {} :: { [number]: { anchorId: string, startedAt: number, expiresAt: number } },
}

local ZONE_SAFE = "zone_bastion_safe"
local ZONE_TRANSITION = "zone_threshold_transition"
local ZONE_FREE = "zone_plain_free"
local TRANSITION_SECONDS = 5
local COMBAT_LOCKOUT_SECONDS = 15
local CROSSING_HOLD_SECONDS = 0.6
local CROSSING_HOLD_EXPIRES_SECONDS = 3
local CROSSING_HOLD_MAX_DISTANCE = 8
local GATE_ANCHORS: { string } = { "anchor_gate_north", "anchor_gate_west" }

-- Os 5 sinais da fronteira (docs/02-WORLD.md §4.2, docs/13-F0-SLICE.md §8.2).
local FRONTIER_SIGNALS: { string } = {
	"physical_gate",
	"lighting_material",
	"ui_banner",
	"audio_haptic",
	"persistent_indicator",
}

-- Lado da fronteira para dano atravessando: segura+transição = "safe",
-- livre (qualquer zona com pvp/kind free) = "free". Projétil/área não cruza.
local function zoneKindOf(zoneId: string): string
	local zone = ZoneService.getZone(zoneId)
	if zone and type(zone.kind) == "string" then
		return zone.kind
	end
	return "safe"
end

local function isSafeZone(zoneId: string): boolean
	return zoneKindOf(zoneId) == "safe"
end

local function isFreeZone(zoneId: string): boolean
	local zone = ZoneService.getZone(zoneId)
	if not zone then
		return zoneId == ZONE_FREE
	end
	return zone.kind == "free" or zone.pvp == true
end

local function isTransitionZone(zoneId: string): boolean
	return zoneKindOf(zoneId) == "transition"
end

local function damageSide(zoneId: string): string
	if isFreeZone(zoneId) then
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
	table.clear(ZoneService.holdPromptedTarget)
	table.clear(ZoneService.crossingHolds)
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
	ZoneService.holdPromptedTarget[userId] = nil
	ZoneService.crossingHolds[userId] = nil
end

-- Respawn é autoridade do servidor, não uma travessia voluntária. Volta ao
-- Bastião e limpa proteção/lockout/pending da vida anterior.
function ZoneService.forceRespawnSafe(userId: number): ()
	ZoneService.zones[userId] = ZONE_SAFE
	ZoneService.transitions[userId] = nil
	ZoneService.pvpCombatAt[userId] = nil
	ZoneService.crossingHolds[userId] = nil
	ZoneService.holdPromptedTarget[userId] = nil
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

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function nearestGate(position: { [string]: number }): string?
	local deps = ZoneService.deps
	if
		not deps
		or type(position.x) ~= "number"
		or type(position.y) ~= "number"
		or type(position.z) ~= "number"
		or not finite(position.x)
		or not finite(position.y)
		or not finite(position.z)
	then
		return nil
	end
	local nearest: string? = nil
	local nearestDistance = math.huge
	for _, anchorId in GATE_ANCHORS do
		local anchor = deps.getAnchor(anchorId)
		if anchor and anchor.position then
			local dx = position.x - anchor.position.x
			local dz = position.z - anchor.position.z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance < nearestDistance then
				nearest = anchorId
				nearestDistance = distance
			end
		end
	end
	return if nearestDistance <= CROSSING_HOLD_MAX_DISTANCE then nearest else nil
end

-- O cliente só declara a fase semântica. Posição, portão e relógio vêm do
-- servidor; complete sempre consome o pending, inclusive quando prematuro.
function ZoneService.handleCrossingHold(
	userId: number,
	toZoneId: string,
	phase: string,
	currentNow: number,
	position: { [string]: number }
): CrossingHoldResult
	if toZoneId ~= ZONE_TRANSITION or ZoneService.getPlayerZone(userId) ~= ZONE_SAFE then
		ZoneService.crossingHolds[userId] = nil
		return { ok = false, reason = "invalid_crossing" }
	end
	if phase == "cancel" then
		ZoneService.crossingHolds[userId] = nil
		return { ok = true }
	end
	local anchorId = nearestGate(position)
	if not anchorId then
		ZoneService.crossingHolds[userId] = nil
		return { ok = false, reason = "too_far" }
	end
	if phase == "begin" then
		ZoneService.crossingHolds[userId] = {
			anchorId = anchorId,
			startedAt = currentNow,
			expiresAt = currentNow + CROSSING_HOLD_EXPIRES_SECONDS,
		}
		return { ok = true, anchorId = anchorId }
	end
	if phase ~= "complete" then
		return { ok = false, reason = "invalid_phase" }
	end

	local pending = ZoneService.crossingHolds[userId]
	ZoneService.crossingHolds[userId] = nil
	if not pending then
		return { ok = false, reason = "hold_required" }
	end
	if pending.anchorId ~= anchorId then
		return { ok = false, reason = "target_mismatch" }
	end
	if currentNow > pending.expiresAt then
		return { ok = false, reason = "hold_expired" }
	end
	if currentNow - pending.startedAt < CROSSING_HOLD_SECONDS then
		return { ok = false, reason = "hold_incomplete" }
	end
	return { ok = true, anchorId = anchorId }
end

-- Reconciliação geométrica (docs/02 §4.3, docs/18 §8 — 13/08 15h30).
--
-- O servidor NÃO consegue segurar fisicamente um personagem cujo cliente tem a
-- network ownership: empurrar a HumanoidRootPart todo Heartbeat vira borracha,
-- e um cliente que insiste passa. O playtest com MCP provou o estrago: o
-- jogador andou até z = −100 (fundo da planície) com o HUD escrito SEGURO.
-- Nesse estado fantasma nada funciona — `canDamageCrossBoundary` recusa todo
-- dano nos dois sentidos, então os golpes "não acertam os bichos", os
-- Estilhaços não revidam e o objetivo nunca anda.
--
-- Regra: quem já está fisicamente na zona livre É da zona livre. O hold
-- continua sendo a porta da frente no portão (prompt + confirmação), mas
-- estado lógico e mundo nunca mais divergem. A proteção de 5 s da travessia
-- vale igual, então ninguém aparece na planície já vulnerável.
function ZoneService.reconcile(userId: number, geometricZoneId: string, now: number): EnterZoneResult
	local result = ZoneService.tryEnterZone(userId, geometricZoneId, now, {})
	if result.ok or not isFreeZone(geometricZoneId) then
		return result
	end
	-- Pulou o volume de transição (dash, queda, ou simplesmente andou):
	-- a travessia é registrada degrau a degrau para a proteção de 5 s valer.
	-- Lockout é barreira de VOLTA para a segura; não cai aqui.
	if isSafeZone(ZoneService.getPlayerZone(userId)) then
		ZoneService.tryEnterZone(userId, ZONE_TRANSITION, now, { holdConfirmed = true })
	end
	return ZoneService.tryEnterZone(userId, geometricZoneId, now, { holdConfirmed = true })
end

-- Uma recusa de travessia devolve o jogador à posição anterior? `hold_required`
-- não: ele está parado no vão do portão esperando confirmar o SEGURE E, e
-- empurrá-lo a cada Heartbeat vira parede invisível (docs/18 §7). Lockout e
-- travessia inválida continuam devolvendo.
function ZoneService.shouldRestorePosition(reason: string?): boolean
	return reason ~= nil and reason ~= "hold_required"
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
	if not isFreeZone(ZoneService.getPlayerZone(userId)) then
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
function ZoneService.markHostileAction(userId: number, _now: number): boolean
	local transition = ZoneService.transitions[userId]
	if transition then
		ZoneService.transitions[userId] = nil
		if isFreeZone(transition.to) then
			ZoneService.zones[userId] = transition.to
			return true
		end
		return false
	end
	-- O lockout de retorno é exclusivamente PvP e fica em markPvpCombat.
	return false
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
	opts: { holdConfirmed: boolean?, rejectedReason: string? }
): ZoneEventPayload
	local event: ZoneEventPayload = {
		from = fromZoneId,
		to = toZoneId,
		pvp = false,
		signals = {},
		holdConfirmed = opts.holdConfirmed == true,
		instant = now,
		rejectedReason = opts.rejectedReason,
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

function ZoneService.notifyCrossingRejection(userId: number, toZoneId: string, currentNow: number, reason: string): ()
	local fromZoneId = ZoneService.getPlayerZone(userId)
	emit(userId, fromZoneId, toZoneId, currentNow, { rejectedReason = reason })
end

-- Quando uma ação hostil encerra a proteção ainda dentro da faixa, o
-- bootstrap move o avatar para o primeiro ponto livre e confirma a mudança
-- visual ao cliente somente depois desse commit físico.
function ZoneService.notifyHostileTransition(userId: number, currentNow: number): ()
	emit(userId, ZONE_TRANSITION, ZONE_FREE, currentNow, { holdConfirmed = true })
end

-- Cruzamento de zona. O hold de 0,6 s é medido por handleCrossingHold; este
-- método recebe `holdConfirmed` apenas do próprio bootstrap após begin,
-- complete, proximidade e portão terem sido revalidados no servidor.
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

	-- Duas seguras vizinhas (Bastião → Academia, etc.): sem hold e sem lockout.
	if isSafeZone(toZoneId) and isSafeZone(fromZoneId) then
		ZoneService.zones[userId] = toZoneId
		ZoneService.transitions[userId] = nil
		local event = emit(userId, fromZoneId, toZoneId, now, {})
		return { ok = true, event = event }
	end

	-- Saindo da segura em direção à livre (via volume de transição).
	if isTransitionZone(toZoneId) and isSafeZone(fromZoneId) then
		if not ZoneService.holdConfirmed[userId] and opts.holdConfirmed ~= true then
			local event: ZoneEventPayload? = nil
			if ZoneService.holdPromptedTarget[userId] ~= toZoneId then
				event = emit(userId, fromZoneId, toZoneId, now, { rejectedReason = "hold_required" })
				ZoneService.holdPromptedTarget[userId] = toZoneId
			end
			return { ok = false, reason = "hold_required", event = event }
		end
		ZoneService.holdPromptedTarget[userId] = nil
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
	if isFreeZone(toZoneId) and isTransitionZone(fromZoneId) then
		if not ZoneService.holdConfirmed[userId] and opts.holdConfirmed ~= true then
			local event: ZoneEventPayload? = nil
			if ZoneService.holdPromptedTarget[userId] ~= toZoneId then
				event = emit(userId, fromZoneId, toZoneId, now, { rejectedReason = "hold_required" })
				ZoneService.holdPromptedTarget[userId] = toZoneId
			end
			return { ok = false, reason = "hold_required", event = event }
		end
		ZoneService.holdPromptedTarget[userId] = nil
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
		ZoneService.zones[userId] = toZoneId
		local event = emit(userId, fromZoneId, toZoneId, now, { holdConfirmed = true })
		return { ok = true, event = event }
	end

	-- Volta: barreira interna bloqueia combate PvP recente (15 s, timer visível).
	if isTransitionZone(toZoneId) and isFreeZone(fromZoneId) then
		local remaining = lockoutRemaining(userId, now)
		if remaining then
			return rejectLockout(userId, fromZoneId, toZoneId, now, remaining)
		end
		ZoneService.zones[userId] = ZONE_TRANSITION
		ZoneService.transitions[userId] = nil
		local event = emit(userId, fromZoneId, toZoneId, now, {})
		return { ok = true, event = event }
	end

	-- Entre duas livres (planície → bosque/porto): sem hold, PvP continua.
	if isFreeZone(toZoneId) and isFreeZone(fromZoneId) then
		ZoneService.zones[userId] = toZoneId
		local event = emit(userId, fromZoneId, toZoneId, now, {})
		return { ok = true, event = event }
	end

	-- Entrada na segura: livre, mas com a mesma barreira de lockout.
	if isSafeZone(toZoneId) then
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

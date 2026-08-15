--!strict
-- Apresentação local dos sinais de fronteira (docs/13 §8.2 / docs/02 §4.2).
--
-- O `ZoneService` já emitia os CINCO sinais no `ZoneEvent` desde o item 6, mas
-- só dois tinham apresentação: o portão físico (parts do `WorldService`) e a
-- faixa de UI. `lighting_material`, `audio_haptic` e `persistent_indicator`
-- eram string no payload e nada na tela — e a fronteira é justamente o
-- experimento obrigatório da F0 ("90% percebem que o PvP será ativado antes de
-- poderem sofrer dano", docs/06 §5).
--
-- ⚠️ Honestidade visual (docs/17):
--   * Nada acende por INTENÇÃO. O plano só nasce de um `ZoneEvent` aceito; um
--     evento recusado (`hold_required`, `combat_lockout`) devolve `nil`, porque
--     nada foi atravessado.
--   * O pulso é curto e fraco de propósito. Tinta forte e permanente vira
--     leitura de dano recebido, e mobile precisa reduzir efeito, não sofrer com
--     ele (docs/13 §17).
--   * `pvp` vem do servidor, nunca da geometria do cliente.

export type ZoneSignalPlan = {
	toZoneId: string,
	pvp: boolean,
	tintRgb: { number },
	tintIntensity: number,
	durationSeconds: number,
	hapticIntensity: number,
	hapticSeconds: number,
	bannerKey: string,
}

export type Player = {
	lighting: any,
	runService: any,
	haptics: ((intensity: number, seconds: number) -> ())?,
	now: () -> number,
	plan: ZoneSignalPlan?,
	startedAt: number,
	effect: any?,
}

local ZoneSignalPlayer = {}

-- Os cinco sinais de `02-WORLD.md` §4.2. A regra é "todos juntos": se o
-- servidor não mandou os cinco, aquilo não foi travessia de fronteira e a
-- apresentação não pode fingir que foi.
local REQUIRED_SIGNALS: { string } = {
	"physical_gate",
	"lighting_material",
	"ui_banner",
	"audio_haptic",
	"persistent_indicator",
}

-- Entrar na livre puxa para o âmbar de perigo; voltar para a segura puxa para o
-- ciano frio do Bastião. São as duas famílias já usadas no cenário.
local DANGER_RGB: { number } = { 236, 150, 88 }
local SAFE_RGB: { number } = { 144, 216, 255 }
local TINT_INTENSITY = 0.22
local PULSE_SECONDS = 0.9
local HAPTIC_INTENSITY = 0.45
local HAPTIC_SECONDS = 0.18

function ZoneSignalPlayer.hasAllSignals(signals: { string }?): boolean
	if type(signals) ~= "table" then
		return false
	end
	for _, required in REQUIRED_SIGNALS do
		local found = false
		for _, signal in signals do
			if signal == required then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

-- Puro: payload autoritativo → plano local. `nil` significa "não apresente
-- nada", que é o caso de recusa, de evento sem os cinco sinais e de transição
-- interna (segura ↔ transição não é fronteira).
function ZoneSignalPlayer.plan(payload: { [string]: any }?): ZoneSignalPlan?
	if type(payload) ~= "table" then
		return nil
	end
	if payload.rejectedReason ~= nil then
		return nil
	end
	if type(payload.to) ~= "string" or payload.to == "" then
		return nil
	end
	if not ZoneSignalPlayer.hasAllSignals(payload.signals) then
		return nil
	end
	local pvp = payload.pvp == true
	return {
		toZoneId = payload.to,
		pvp = pvp,
		tintRgb = if pvp then DANGER_RGB else SAFE_RGB,
		tintIntensity = TINT_INTENSITY,
		durationSeconds = PULSE_SECONDS,
		hapticIntensity = HAPTIC_INTENSITY,
		hapticSeconds = HAPTIC_SECONDS,
		bannerKey = if pvp then "hud.pvp_active" else "hud.zone_safe",
	}
end

-- Envelope do pulso: sobe rápido e volta ao neutro. Puro para o teste travar o
-- formato — o que não pode acontecer é a tinta ficar presa acesa.
function ZoneSignalPlayer.intensityAt(plan: ZoneSignalPlan?, elapsedSeconds: number): number
	if not plan or elapsedSeconds < 0 or elapsedSeconds >= plan.durationSeconds then
		return 0
	end
	local attack = 0.12
	if elapsedSeconds <= attack then
		return plan.tintIntensity * (elapsedSeconds / attack)
	end
	local release = (elapsedSeconds - attack) / (plan.durationSeconds - attack)
	return plan.tintIntensity * (1 - release)
end

function ZoneSignalPlayer.new(deps: {
	lighting: any,
	runService: any,
	haptics: ((intensity: number, seconds: number) -> ())?,
	now: (() -> number)?,
}): Player
	return {
		lighting = deps.lighting,
		runService = deps.runService,
		haptics = deps.haptics,
		now = deps.now or os.clock,
		plan = nil,
		startedAt = 0,
		effect = nil,
	}
end

local function ensureEffect(player: Player): any?
	if player.effect and player.effect.Parent then
		return player.effect
	end
	local lighting = player.lighting
	if not lighting then
		return nil
	end
	local existing = lighting:FindFirstChild("F0ZoneSignal")
	if existing then
		player.effect = existing
		return existing
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "F0ZoneSignal"
	effect.Brightness = 0
	effect.Contrast = 0
	effect.Saturation = 0
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Enabled = false
	effect.Parent = lighting
	player.effect = effect
	return effect
end

function ZoneSignalPlayer.onZoneEvent(player: Player, payload: { [string]: any }): boolean
	local plan = ZoneSignalPlayer.plan(payload)
	if not plan then
		return false
	end
	player.plan = plan
	player.startedAt = player.now()
	if player.haptics then
		player.haptics(plan.hapticIntensity, plan.hapticSeconds)
	end
	return true
end

function ZoneSignalPlayer.step(player: Player): ()
	local plan = player.plan
	if not plan then
		return
	end
	local intensity = ZoneSignalPlayer.intensityAt(plan, player.now() - player.startedAt)
	local effect = ensureEffect(player)
	if not effect then
		player.plan = nil
		return
	end
	if intensity <= 0 then
		effect.Enabled = false
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Saturation = 0
		player.plan = nil
		return
	end
	effect.Enabled = true
	-- Mistura a cor do sinal com o branco neutro na proporção da intensidade: a
	-- tela nunca fica com a cor cheia, só puxada na direção dela.
	effect.TintColor = Color3.new(
		1 - (1 - plan.tintRgb[1] / 255) * intensity,
		1 - (1 - plan.tintRgb[2] / 255) * intensity,
		1 - (1 - plan.tintRgb[3] / 255) * intensity
	)
	effect.Saturation = intensity * 0.5
end

return ZoneSignalPlayer

--!strict
-- Catálogo de efeito visual das três técnicas — dirigido por dados
-- (docs/18-ABILITY-TECHNIQUES.md §4). O módulo NÃO cria Instances: mantém
-- paleta, formas, raios e envelopes como número puro, testável fora do Studio.
-- Quem materializa é src/client/Presentation/AbilityVfxPlayer.luau.
--
-- Duas regras estruturais, ambas travadas por teste:
--
--   1. `radiusStuds` de qualquer camada nunca passa do `range` da habilidade no
--      catálogo autoritativo. docs/14 §6: "efeito percebido nunca sugere
--      alcance maior que a hitbox". Um brilho de 12 studs num golpe de 6 é
--      propaganda enganosa — o jogador aprende a distância errada.
--   2. Camada com `requiresConfirmation` só pode ser desenhada depois de um
--      desfecho autoritativo do servidor. Efeito de acerto disparado pela
--      intenção local mostraria "acertei" em golpe que errou.
--
-- Tipos inline (export type é compile-time) para o módulo carregar em teste
-- Lune. Contrato canônico: src/shared/Types.luau.

export type Rgb = { number }

export type VfxLayer = {
	id: string,
	-- Forma. A informação de qual técnica saiu está na FORMA, não na cor: o kit
	-- inteiro compartilha a paleta umbral e precisa ser legível sem cor.
	kind: "charge" | "trail" | "arc" | "shell" | "ring" | "burst",
	-- Papel no rig (resolvido para Attachment pelo player; ausente = ignorado).
	joint: string,
	startSeconds: number,
	durationSeconds: number,
	attackSeconds: number,
	releaseSeconds: number,
	radiusStuds: number,
	rgb: Rgb,
	-- Partículas por segundo no pico (0 para camadas de disparo único).
	rate: number,
	requiresConfirmation: boolean,
}

export type TechniqueVfx = {
	abilityId: string,
	-- Ação correspondente no PlayerCombatAnimator.
	action: string,
	-- Espelha PlayerCombatAnimator.Durations[action]; teste trava a igualdade.
	actionDurationSeconds: number,
	-- Espelha Abilities[abilityId].range; teto de qualquer raio de efeito.
	rangeStuds: number,
	coreRgb: Rgb,
	edgeRgb: Rgb,
	layers: { VfxLayer },
}

-- Paleta do Éter Umbral: núcleo pálido de cinza-violeta e borda violeta
-- profunda. Fica legível sobre o greybox dessaturado do mundo F0 sem depender
-- de bloom, e o contraste núcleo/borda sobrevive à redução de efeitos.
local UMBRAL_CORE: Rgb = { 214, 206, 232 }
local UMBRAL_EDGE: Rgb = { 88, 60, 138 }
-- Contra do Pulso devolve energia: âmbar frio para separar "eu apanhei" de
-- "eu devolvi" mesmo em quem joga sem som.
local RETURN_CORE: Rgb = { 236, 224, 196 }
local RETURN_EDGE: Rgb = { 168, 116, 52 }

local function layer(values: {
	id: string,
	kind: "charge" | "trail" | "arc" | "shell" | "ring" | "burst",
	joint: string,
	startSeconds: number,
	durationSeconds: number,
	attackSeconds: number?,
	releaseSeconds: number?,
	radiusStuds: number,
	rgb: Rgb,
	rate: number?,
	requiresConfirmation: boolean?,
}): VfxLayer
	return {
		id = values.id,
		kind = values.kind,
		joint = values.joint,
		startSeconds = values.startSeconds,
		durationSeconds = values.durationSeconds,
		attackSeconds = values.attackSeconds or 0.04,
		releaseSeconds = values.releaseSeconds or 0.10,
		radiusStuds = values.radiusStuds,
		rgb = values.rgb,
		rate = values.rate or 0,
		requiresConfirmation = values.requiresConfirmation == true,
	}
end

local Techniques: { [string]: TechniqueVfx } = {
	-- ── Ombro Cometa ────────────────────────────────────────────────────────
	-- Uma linha só, do ombro para a frente. O avanço de 7 studs já é a leitura;
	-- o efeito serve para dizer "isto viaja", não para inventar alcance.
	comet_shoulder = {
		abilityId = "comet_shoulder",
		action = "Ability1",
		actionDurationSeconds = 0.75,
		rangeStuds = 8,
		coreRgb = UMBRAL_CORE,
		edgeRgb = UMBRAL_EDGE,
		layers = {
			-- Carga no ombro durante a antecipação: telegrafa o compromisso para
			-- o oponente antes de o corpo sair do lugar.
			layer({
				id = "comet_charge",
				kind = "charge",
				joint = "rightUpperArm",
				startSeconds = 0.0,
				durationSeconds = 0.18,
				attackSeconds = 0.08,
				releaseSeconds = 0.04,
				radiusStuds = 1.5,
				rgb = UMBRAL_EDGE,
				rate = 34,
			}),
			-- Aura no peito durante a carga: a esfera de energia concentrando
			-- (referência de leitura do vídeo de referência — power-up antes do
			-- avanço). Enquanto ela cresce, o golpe ainda não saiu.
			layer({
				id = "comet_aura",
				kind = "charge",
				joint = "torso",
				startSeconds = 0.0,
				durationSeconds = 0.20,
				attackSeconds = 0.10,
				releaseSeconds = 0.05,
				radiusStuds = 1.6,
				rgb = UMBRAL_CORE,
				rate = 30,
			}),
			-- Rastro do tronco no avanço. 4,2 studs é pouco mais da metade do
			-- deslocamento real de 7: o rastro acompanha o corpo, não corre à
			-- frente dele.
			layer({
				id = "comet_trail",
				kind = "trail",
				joint = "torso",
				startSeconds = 0.18,
				durationSeconds = 0.34,
				attackSeconds = 0.03,
				releaseSeconds = 0.12,
				radiusStuds = 4.2,
				rgb = UMBRAL_CORE,
				rate = 0,
			}),
			-- Flash branco-violeta no contato — o estouro de luz do impacto.
			-- Só com desfecho confirmado pelo servidor.
			layer({
				id = "comet_flash",
				kind = "burst",
				joint = "rightUpperArm",
				startSeconds = 0.40,
				durationSeconds = 0.20,
				attackSeconds = 0.02,
				releaseSeconds = 0.12,
				radiusStuds = 3.2,
				rgb = { 240, 235, 250 },
				rate = 0,
				requiresConfirmation = true,
			}),
			-- Estouro no contato — só com desfecho confirmado pelo servidor.
			layer({
				id = "comet_burst",
				kind = "burst",
				joint = "rightUpperArm",
				startSeconds = 0.0,
				durationSeconds = 0.22,
				attackSeconds = 0.02,
				releaseSeconds = 0.14,
				radiusStuds = 2.6,
				rgb = UMBRAL_CORE,
				rate = 0,
				requiresConfirmation = true,
			}),
			-- Onda de choque no chão no impacto confirmado: expande até 5,5
			-- studs e some — a assinatura de "golpe pesado" de battlegrounds.
			layer({
				id = "comet_ring",
				kind = "ring",
				joint = "root",
				startSeconds = 0.40,
				durationSeconds = 0.30,
				attackSeconds = 0.05,
				releaseSeconds = 0.18,
				radiusStuds = 5.5,
				rgb = UMBRAL_CORE,
				rate = 0,
				requiresConfirmation = true,
			}),
		},
	},

	-- ── Cadência Quebrada ───────────────────────────────────────────────────
	-- Dois arcos curtos em instantes desiguais. O intervalo irregular é a
	-- assinatura da técnica; o efeito existe para tornar esse ritmo visível.
	broken_cadence = {
		abilityId = "broken_cadence",
		action = "Ability2",
		actionDurationSeconds = 0.68,
		rangeStuds = 6,
		coreRgb = UMBRAL_CORE,
		edgeRgb = UMBRAL_EDGE,
		layers = {
			-- Arco 1 fecha em 0,14 s, o instante do primeiro dano autoritativo.
			layer({
				id = "cadence_arc_first",
				kind = "arc",
				joint = "rightLowerArm",
				startSeconds = 0.08,
				durationSeconds = 0.12,
				attackSeconds = 0.03,
				releaseSeconds = 0.06,
				radiusStuds = 2.4,
				rgb = UMBRAL_CORE,
				rate = 0,
			}),
			-- Arco 2 fecha em 0,32 s. Maior que o primeiro: o revés é o golpe
			-- que fecha a frase.
			layer({
				id = "cadence_arc_second",
				kind = "arc",
				joint = "leftLowerArm",
				startSeconds = 0.25,
				durationSeconds = 0.14,
				attackSeconds = 0.03,
				releaseSeconds = 0.07,
				radiusStuds = 3.0,
				rgb = UMBRAL_CORE,
				rate = 0,
			}),
			layer({
				id = "cadence_burst",
				kind = "burst",
				joint = "torso",
				startSeconds = 0.0,
				durationSeconds = 0.18,
				attackSeconds = 0.02,
				releaseSeconds = 0.10,
				radiusStuds = 2.0,
				rgb = UMBRAL_CORE,
				rate = 0,
				requiresConfirmation = true,
			}),
		},
	},

	-- Eco da reentrada: o mesmo arco do golpe 2 refeito mais pálido e menor.
	-- Precisa ler como repetição, não como técnica nova.
	broken_cadence_echo = {
		abilityId = "broken_cadence",
		action = "Ability2Echo",
		actionDurationSeconds = 0.52,
		rangeStuds = 6,
		coreRgb = UMBRAL_CORE,
		edgeRgb = UMBRAL_EDGE,
		layers = {
			layer({
				id = "echo_arc",
				kind = "arc",
				joint = "leftLowerArm",
				startSeconds = 0.20,
				durationSeconds = 0.18,
				attackSeconds = 0.04,
				releaseSeconds = 0.09,
				radiusStuds = 2.6,
				rgb = UMBRAL_EDGE,
				rate = 0,
			}),
			layer({
				id = "echo_burst",
				kind = "burst",
				joint = "torso",
				startSeconds = 0.0,
				durationSeconds = 0.16,
				attackSeconds = 0.02,
				releaseSeconds = 0.09,
				radiusStuds = 1.8,
				rgb = UMBRAL_CORE,
				rate = 0,
				requiresConfirmation = true,
			}),
		},
	},

	-- ── Retorno de Pulso ────────────────────────────────────────────────────
	-- Casca simétrica sustentada enquanto a janela de aparo existe. O fim da
	-- casca é informação de regra: quando ela some, a postura acabou.
	pulse_return = {
		abilityId = "pulse_return",
		action = "Ability3",
		actionDurationSeconds = 0.73,
		rangeStuds = 6,
		coreRgb = UMBRAL_CORE,
		edgeRgb = UMBRAL_EDGE,
		layers = {
			-- Dura exatamente os 250 ms de postura do CombatService. Não é
			-- decoração: é o cronômetro do aparo desenhado no personagem.
			layer({
				id = "pulse_shell",
				kind = "shell",
				joint = "torso",
				startSeconds = 0.0,
				durationSeconds = 0.25,
				attackSeconds = 0.06,
				releaseSeconds = 0.05,
				radiusStuds = 2.2,
				rgb = UMBRAL_EDGE,
				rate = 34,
			}),
			-- Dispersão do pulso sem contato: a energia sai e nada volta.
			layer({
				id = "pulse_release",
				kind = "ring",
				joint = "root",
				startSeconds = 0.25,
				durationSeconds = 0.20,
				attackSeconds = 0.04,
				releaseSeconds = 0.14,
				radiusStuds = 3.4,
				rgb = UMBRAL_CORE,
				rate = 0,
			}),
		},
	},

	-- Contra confirmado: onda âmbar curta e um estouro. Só toca depois do
	-- CombatEvent com desfecho "counter" — nunca por intenção local.
	pulse_return_counter = {
		abilityId = "pulse_return",
		action = "Ability3Counter",
		actionDurationSeconds = 0.44,
		rangeStuds = 6,
		coreRgb = RETURN_CORE,
		edgeRgb = RETURN_EDGE,
		layers = {
			layer({
				id = "counter_ring",
				kind = "ring",
				joint = "root",
				startSeconds = 0.0,
				durationSeconds = 0.24,
				attackSeconds = 0.03,
				releaseSeconds = 0.16,
				radiusStuds = 4.2,
				rgb = RETURN_EDGE,
				rate = 0,
				requiresConfirmation = true,
			}),
			layer({
				id = "counter_burst",
				kind = "burst",
				joint = "rightHand",
				startSeconds = 0.16,
				durationSeconds = 0.20,
				attackSeconds = 0.02,
				releaseSeconds = 0.12,
				radiusStuds = 2.4,
				rgb = RETURN_CORE,
				rate = 0,
				requiresConfirmation = true,
			}),
		},
	},
}

local ByAction: { [string]: TechniqueVfx } = {}
for _, technique in Techniques do
	ByAction[technique.action] = technique
end

local AbilityVfx = {}

AbilityVfx.UmbralCoreRgb = UMBRAL_CORE
AbilityVfx.UmbralEdgeRgb = UMBRAL_EDGE

function AbilityVfx.get(recipeId: string): TechniqueVfx?
	return Techniques[recipeId]
end

function AbilityVfx.forAction(action: string): TechniqueVfx?
	return ByAction[action]
end

function AbilityVfx.all(): { TechniqueVfx }
	local out: { TechniqueVfx } = {}
	for _, def in Techniques do
		table.insert(out, def)
	end
	return out
end

-- Envelope da camada: sobe em `attackSeconds`, sustenta e cai em
-- `releaseSeconds`. Fora da janela é exatamente 0, para o player poder
-- desligar o emissor em vez de deixá-lo respirando a 0,001.
function AbilityVfx.intensityAt(entry: VfxLayer, elapsed: number): number
	local t = elapsed - entry.startSeconds
	if t < 0 or t > entry.durationSeconds then
		return 0
	end
	local attack = math.min(entry.attackSeconds, entry.durationSeconds)
	local release = math.min(entry.releaseSeconds, entry.durationSeconds - attack)
	if attack > 0 and t < attack then
		return t / attack
	end
	local releaseStart = entry.durationSeconds - release
	if release > 0 and t > releaseStart then
		return math.max(0, (entry.durationSeconds - t) / release)
	end
	return 1
end

-- Plano de desenho num instante: o que está aceso e com que intensidade.
-- Puro de propósito — é o que os testes conferem sem DataModel. `confirmed`
-- carrega o desfecho autoritativo; sem ele as camadas de acerto não entram.
export type PlannedLayer = { layer: VfxLayer, intensity: number }

function AbilityVfx.planAt(technique: TechniqueVfx, elapsed: number, confirmed: boolean): { PlannedLayer }
	local out: { PlannedLayer } = {}
	for _, entry in technique.layers do
		if entry.requiresConfirmation and not confirmed then
			continue
		end
		local intensity = AbilityVfx.intensityAt(entry, elapsed)
		if intensity > 0 then
			table.insert(out, { layer = entry, intensity = intensity })
		end
	end
	return out
end

local function validRgb(rgb: Rgb): boolean
	if #rgb ~= 3 then
		return false
	end
	for _, channel in rgb do
		if channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end

-- Roda em teste para o catálogo não apodrecer em silêncio.
function AbilityVfx.validate(): (boolean, string?)
	for id, technique in Techniques do
		if technique.rangeStuds <= 0 then
			return false, ("técnica %s declara alcance não positivo"):format(id)
		end
		if not validRgb(technique.coreRgb) or not validRgb(technique.edgeRgb) then
			return false, ("técnica %s tem paleta fora de 0..255"):format(id)
		end
		if #technique.layers == 0 then
			return false, ("técnica %s não declara camada"):format(id)
		end
		local seen: { [string]: boolean } = {}
		for _, entry in technique.layers do
			if seen[entry.id] then
				return false, ("técnica %s repete a camada %s"):format(id, entry.id)
			end
			seen[entry.id] = true
			if not validRgb(entry.rgb) then
				return false, ("camada %s tem cor fora de 0..255"):format(entry.id)
			end
			if entry.durationSeconds <= 0 then
				return false, ("camada %s tem duração não positiva"):format(entry.id)
			end
			if entry.startSeconds < 0 then
				return false, ("camada %s começa antes da ação"):format(entry.id)
			end
			-- O efeito nunca sobrevive à própria animação: sobra de partícula
			-- depois do fim da pose lê como técnica ainda ativa.
			if entry.startSeconds + entry.durationSeconds > technique.actionDurationSeconds + 1e-9 then
				return false, ("camada %s termina depois da ação %s"):format(entry.id, technique.action)
			end
			if entry.attackSeconds < 0 or entry.releaseSeconds < 0 then
				return false, ("camada %s tem envelope negativo"):format(entry.id)
			end
			if entry.attackSeconds + entry.releaseSeconds > entry.durationSeconds + 1e-9 then
				return false, ("camada %s tem envelope maior que a duração"):format(entry.id)
			end
			-- A regra que impede o efeito de mentir sobre alcance.
			if entry.radiusStuds > technique.rangeStuds then
				return false,
					("camada %s tem raio %.1f maior que o alcance %.1f da habilidade"):format(
						entry.id,
						entry.radiusStuds,
						technique.rangeStuds
					)
			end
			if entry.rate < 0 then
				return false, ("camada %s tem taxa negativa"):format(entry.id)
			end
		end
	end
	return true, nil
end

return AbilityVfx

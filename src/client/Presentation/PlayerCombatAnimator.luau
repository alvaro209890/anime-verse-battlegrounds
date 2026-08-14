--!strict
-- Resposta procedural local para intenções de combate do jogador. Esta camada
-- não decide acerto, alvo, dano, custo ou deslocamento autoritativo; ela apenas
-- aplica um overlay visual temporário sobre as juntas do personagem local.
--
-- ⚠️ Junta NÃO é sinônimo de Motor6D. O avatar R15 atual do Roblox monta o rig
-- com `AnimationConstraint` (Attachment→Attachment) e **zero** Motor6D — medido
-- no Studio em 2026-08-14: o personagem do jogador tinha 15 AnimationConstraint
-- (Root, Waist, Neck, LeftShoulder…) e nenhum Motor6D. Enquanto este arquivo
-- procurava só Motor6D, `animator.joints` ficava VAZIO e todo o overlay abaixo
-- — as quatro silhuetas da cadeia, as três técnicas, o hit-stop — não saía do
-- papel. O que o jogador via era apenas o clipe de espada acelerado. Era essa a
-- reclamação "as animações de golpes estão péssimas" (docs/18 §8).
-- As duas classes expõem `Transform: CFrame` com a mesma semântica, então o
-- overlay é idêntico: só a busca precisa aceitar as duas.

export type CombatAction =
	"BasicLight"
	| "BasicHeavy"
	| "GuardDown"
	| "GuardUp"
	| "Dash"
	| "Ability1"
	| "Ability2"
	| "Ability3"
	-- Eco da Cadência (reentrada) e contra do Pulso são momentos próprios da
	-- técnica: reusar a pose da ativação faria o jogador ler "de novo o mesmo
	-- golpe" onde a regra mudou (docs/18 §2.2 e §2.3).
	| "Ability2Echo"
	| "Ability3Counter"

export type PoseSample = {
	rootHeightStuds: number,
	rootPitchDegrees: number,
	rootYawDegrees: number,
	rootRollDegrees: number,
	waistPitchDegrees: number,
	waistYawDegrees: number,
	waistRollDegrees: number,
	neckPitchDegrees: number,
	neckYawDegrees: number,
	leftShoulderPitchDegrees: number,
	leftShoulderYawDegrees: number,
	leftShoulderRollDegrees: number,
	rightShoulderPitchDegrees: number,
	rightShoulderYawDegrees: number,
	rightShoulderRollDegrees: number,
	-- Cotovelo é o que transforma "braço girando" em soco: a extensão tardia
	-- da extremidade fecha o golpe depois do quadril e do tórax (docs/14 §3).
	leftElbowPitchDegrees: number,
	rightElbowPitchDegrees: number,
	leftHipPitchDegrees: number,
	leftHipYawDegrees: number,
	rightHipPitchDegrees: number,
	rightHipYawDegrees: number,
	-- Joelho permite chute: perna encaixa dobrada e estende no impacto.
	leftKneePitchDegrees: number,
	rightKneePitchDegrees: number,
	-- Punho permite o "estalo" no impacto: uma flexão curta fecha o soco no
	-- momento do contato (R15 tem junta de punho; R6 não — o overlay é ignorado).
	leftWristPitchDegrees: number,
	rightWristPitchDegrees: number,
}

-- Motor6D (rig clássico) ou AnimationConstraint (rig atual do avatar R15). O
-- overlay só depende de `Transform`, que as duas expõem; tipar como Instance
-- evita afirmar em `--!strict` uma classe que o personagem pode não ter.
type PoseJoint = Instance

type JointState = {
	joint: PoseJoint,
	baseTransform: CFrame,
	lastApplied: CFrame?,
}

export type Animator = {
	player: any,
	runService: any,
	now: () -> number,
	action: CombatAction?,
	actionStartedAt: number,
	-- Congelamento visual de impacto confirmado (hit-stop de docs/14 §6).
	hitStopUntil: number,
	guarding: boolean,
	-- Degrau visual da cadeia leve. Espelha lightStep do servidor por tempo, sem
	-- depender dele: divergir aqui custa uma pose, nunca um acerto.
	comboStep: number,
	lastLightAt: number,
	-- Deixa sonora do golpe em curso, disparada uma vez quando a antecipação
	-- termina. Opcional: sem ela o animador funciona igual, em silêncio.
	emitCue: ((string) -> ())?,
	pendingCue: string?,
	pendingCueAt: number,
	character: Model?,
	joints: { [string]: JointState },
	preSimulationConnection: any?,
	characterAddedConnection: any?,
}

local PlayerCombatAnimator = {}

-- As três técnicas duram exatamente startup + active + recovery do catálogo
-- (src/shared/Data/Abilities.luau). Antes a apresentação era mais curta que a
-- regra: a pose voltava ao neutro enquanto o servidor ainda resolvia impacto,
-- e o jogador lia "acabou" antes de acabar. Um teste trava essa igualdade.
local DURATIONS: { [string]: number } = {
	BasicLight = 0.28,
	BasicHeavy = 0.52,
	GuardDown = 0.16,
	GuardUp = 0.18,
	Dash = 0.32,
	-- Ombro Cometa: 180 + 220 + 350 ms.
	Ability1 = 0.75,
	-- Cadência Quebrada: 140 + 260 + 280 ms.
	Ability2 = 0.68,
	-- Retorno de Pulso: 250 + 180 + 300 ms.
	Ability3 = 0.73,
	-- Eco: o servidor resolve o dano 350 ms após a reentrada; o pico da pose cai
	-- nesse instante e sobra recuperação depois dele.
	Ability2Echo = 0.52,
	-- Contra: reação curta, só existe depois da confirmação do servidor.
	Ability3Counter = 0.44,
}

PlayerCombatAnimator.Durations = table.freeze({
	BasicLight = DURATIONS.BasicLight,
	BasicHeavy = DURATIONS.BasicHeavy,
	GuardDown = DURATIONS.GuardDown,
	GuardUp = DURATIONS.GuardUp,
	Dash = DURATIONS.Dash,
	Ability1 = DURATIONS.Ability1,
	Ability2 = DURATIONS.Ability2,
	Ability3 = DURATIONS.Ability3,
	Ability2Echo = DURATIONS.Ability2Echo,
	Ability3Counter = DURATIONS.Ability3Counter,
})

-- Instantes autoritativos espelhados da apresentação. O servidor resolve os
-- dois impactos da Cadência em +140 ms e +320 ms da ativação (AbilityService)
-- e a postura do Pulso dura 250 ms (CombatService.PULSE_STANCE_MS). A pose
-- precisa cravar nesses instantes, senão o hit-stop chega fora do golpe.
PlayerCombatAnimator.AuthoritativeBeats = table.freeze({
	cadenceFirstHit = 0.14,
	cadenceSecondHit = 0.32,
	cadenceEchoHit = 0.35,
	pulseStanceEnd = 0.25,
	cometImpact = 0.40,
})

-- Hit-stop por desfecho (docs/14 §6): milissegundos de congelamento visual no
-- impacto confirmado. Guarda só um clique; morte segura um pouco mais.
PlayerCombatAnimator.HitStopMs = table.freeze({
	hit = 40,
	death = 60,
	guard = 20,
	-- O contra do Retorno de Pulso é o momento mais raro do kit: segura um pouco
	-- mais que um acerto comum para que a leitura "eu aparei" seja inequívoca.
	counter = 55,
})

function PlayerCombatAnimator.hitStopActive(now: number, hitStopUntil: number?): boolean
	return hitStopUntil ~= nil and now < hitStopUntil
end

function PlayerCombatAnimator.confirmHit(animator: Animator, outcome: string): ()
	local ms = PlayerCombatAnimator.HitStopMs[outcome]
	if type(ms) ~= "number" or ms <= 0 then
		return
	end
	animator.hitStopUntil = animator.now() + ms / 1000
end

-- Uma lista única de chaves evita que um membro novo seja esquecido em pose()
-- ou blend() — o modo clássico de um braço "congelar" no meio de um golpe.
local POSE_KEYS: { string } = {
	"rootHeightStuds",
	"rootPitchDegrees",
	"rootYawDegrees",
	"rootRollDegrees",
	"waistPitchDegrees",
	"waistYawDegrees",
	"waistRollDegrees",
	"neckPitchDegrees",
	"neckYawDegrees",
	"leftShoulderPitchDegrees",
	"leftShoulderYawDegrees",
	"leftShoulderRollDegrees",
	"rightShoulderPitchDegrees",
	"rightShoulderYawDegrees",
	"rightShoulderRollDegrees",
	"leftElbowPitchDegrees",
	"rightElbowPitchDegrees",
	"leftHipPitchDegrees",
	"leftHipYawDegrees",
	"rightHipPitchDegrees",
	"rightHipYawDegrees",
	"leftKneePitchDegrees",
	"rightKneePitchDegrees",
	"leftWristPitchDegrees",
	"rightWristPitchDegrees",
}

-- Núcleo (quadril/tronco/pescoço) inicia o movimento; a extremidade fecha
-- depois. Amostrar esses dois grupos com fases distintas é o que produz o
-- "peso atrasado" de docs/14 §3 sem exigir keyframe.
local CORE_KEYS: { [string]: boolean } = {
	rootHeightStuds = true,
	rootPitchDegrees = true,
	rootYawDegrees = true,
	rootRollDegrees = true,
	waistPitchDegrees = true,
	waistYawDegrees = true,
	waistRollDegrees = true,
	neckPitchDegrees = true,
	neckYawDegrees = true,
}

local function pose(values: { [string]: number }?): PoseSample
	local source = values or {}
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		built[key] = source[key] or 0
	end
	return built :: any
end

local NEUTRAL = table.freeze(pose(nil))
local GUARD = table.freeze(pose({
	rootHeightStuds = -0.04,
	rootPitchDegrees = 4,
	rootYawDegrees = -4,
	waistPitchDegrees = -3,
	waistYawDegrees = 8,
	neckPitchDegrees = -2,
	neckYawDegrees = -4,
	leftShoulderPitchDegrees = -52,
	leftShoulderYawDegrees = -18,
	leftShoulderRollDegrees = -12,
	rightShoulderPitchDegrees = -48,
	rightShoulderYawDegrees = 20,
	rightShoulderRollDegrees = 14,
	leftHipPitchDegrees = -4,
	rightHipPitchDegrees = 4,
}))
local HEAVY_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.08,
	rootPitchDegrees = -9,
	rootYawDegrees = -27,
	rootRollDegrees = -6,
	waistPitchDegrees = -6,
	waistYawDegrees = -32,
	waistRollDegrees = -5,
	neckPitchDegrees = 5,
	neckYawDegrees = 14,
	leftShoulderPitchDegrees = -18,
	leftShoulderYawDegrees = -14,
	rightShoulderPitchDegrees = 48,
	rightShoulderYawDegrees = 31,
	rightShoulderRollDegrees = 16,
	rightElbowPitchDegrees = -96,
	leftElbowPitchDegrees = -74,
	leftHipPitchDegrees = -8,
	rightHipPitchDegrees = 8,
	leftKneePitchDegrees = -20,
	rightKneePitchDegrees = -12,
}))
local HEAVY_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.12,
	rootPitchDegrees = 16,
	rootYawDegrees = 31,
	rootRollDegrees = 8,
	waistPitchDegrees = 13,
	waistYawDegrees = 38,
	waistRollDegrees = 7,
	neckPitchDegrees = -7,
	neckYawDegrees = -16,
	leftShoulderPitchDegrees = 24,
	leftShoulderYawDegrees = -18,
	rightShoulderPitchDegrees = -112,
	rightShoulderYawDegrees = -18,
	rightShoulderRollDegrees = -15,
	rightElbowPitchDegrees = -8,
	rightWristPitchDegrees = -20,
	leftElbowPitchDegrees = -58,
	leftHipPitchDegrees = 10,
	rightHipPitchDegrees = -10,
	leftKneePitchDegrees = -14,
	rightKneePitchDegrees = -8,
}))
local DASH = table.freeze(pose({
	rootHeightStuds = -0.12,
	rootPitchDegrees = 18,
	waistPitchDegrees = 11,
	neckPitchDegrees = -9,
	leftShoulderPitchDegrees = 31,
	leftShoulderYawDegrees = -7,
	leftShoulderRollDegrees = -8,
	rightShoulderPitchDegrees = 35,
	rightShoulderYawDegrees = 7,
	rightShoulderRollDegrees = 8,
	leftHipPitchDegrees = -12,
	rightHipPitchDegrees = -12,
}))
-- ── Ombro Cometa — o corpo inteiro vira o projétil ──────────────────────────
-- A leitura obrigatória é "ombro primeiro". Os dois cotovelos ficam dobrados do
-- início ao fim: se a mão estender, o golpe vira soco e passa a competir com o
-- pesado na silhueta. O que viaja é o tronco, não o braço (docs/18 §2.1).

local COMET_COIL = table.freeze(pose({
	rootHeightStuds = -0.26,
	rootPitchDegrees = -16,
	rootYawDegrees = -16,
	rootRollDegrees = -4,
	waistPitchDegrees = -8,
	waistYawDegrees = -20,
	waistRollDegrees = -4,
	neckPitchDegrees = 6,
	neckYawDegrees = 12,
	leftShoulderPitchDegrees = -44,
	leftShoulderYawDegrees = -16,
	leftShoulderRollDegrees = -10,
	leftElbowPitchDegrees = -104,
	rightShoulderPitchDegrees = -30,
	rightShoulderYawDegrees = 26,
	rightShoulderRollDegrees = 18,
	-- Cotovelo colado às costelas: o ombro é a ponta do golpe.
	rightElbowPitchDegrees = -124,
	leftHipPitchDegrees = -14,
	leftKneePitchDegrees = -52,
	rightHipPitchDegrees = 10,
	rightKneePitchDegrees = -18,
	leftWristPitchDegrees = -14,
	rightWristPitchDegrees = -16,
}))
local COMET_DRIVE = table.freeze(pose({
	rootHeightStuds = -0.30,
	rootPitchDegrees = 38,
	rootYawDegrees = 20,
	rootRollDegrees = 7,
	waistPitchDegrees = 22,
	waistYawDegrees = 24,
	waistRollDegrees = 6,
	neckPitchDegrees = -14,
	neckYawDegrees = -10,
	-- Braço de trás varre para trás: é o que desenha a linha de velocidade.
	leftShoulderPitchDegrees = 40,
	leftShoulderYawDegrees = -30,
	leftShoulderRollDegrees = -16,
	leftElbowPitchDegrees = -34,
	rightShoulderPitchDegrees = -130,
	rightShoulderYawDegrees = -22,
	rightShoulderRollDegrees = -18,
	rightElbowPitchDegrees = -96,
	rightWristPitchDegrees = -20,
	leftWristPitchDegrees = -8,
	-- Perna de trás estende (empurra), perna da frente absorve (recebe).
	leftHipPitchDegrees = 26,
	leftKneePitchDegrees = -6,
	rightHipPitchDegrees = -22,
	rightKneePitchDegrees = -52,
}))

-- ── Cadência Quebrada — dois golpes que não compartilham o compasso ─────────
-- O nome é a mecânica: o intervalo entre os impactos é desigual de propósito.
-- O quadro CADENCE_BREAK existe só para o corpo puxar contra o próprio arco
-- entre os dois golpes; sem ele a técnica lê como um combo comum.

local CADENCE_COIL = table.freeze(pose({
	rootHeightStuds = -0.10,
	rootPitchDegrees = -4,
	rootYawDegrees = -22,
	waistYawDegrees = -22,
	waistRollDegrees = -3,
	neckYawDegrees = 10,
	leftShoulderPitchDegrees = -50,
	leftShoulderYawDegrees = -14,
	leftElbowPitchDegrees = -96,
	rightShoulderPitchDegrees = -30,
	rightShoulderYawDegrees = 24,
	rightShoulderRollDegrees = 16,
	rightElbowPitchDegrees = -128,
	leftHipPitchDegrees = -8,
	leftKneePitchDegrees = -14,
	rightHipPitchDegrees = 8,
	rightKneePitchDegrees = -20,
}))
local CADENCE_FIRST = table.freeze(pose({
	rootHeightStuds = -0.08,
	rootPitchDegrees = 9,
	rootYawDegrees = 30,
	rootRollDegrees = 6,
	waistPitchDegrees = 6,
	waistYawDegrees = 32,
	waistRollDegrees = 5,
	neckYawDegrees = -14,
	leftShoulderPitchDegrees = -46,
	leftShoulderYawDegrees = -12,
	leftElbowPitchDegrees = -92,
	rightShoulderPitchDegrees = -96,
	rightShoulderYawDegrees = -26,
	rightShoulderRollDegrees = -14,
	-- Golpe 1 é cotovelada curta: o cotovelo continua fechado no contato.
	rightElbowPitchDegrees = -70,
	rightWristPitchDegrees = -24,
	leftHipPitchDegrees = 10,
	leftKneePitchDegrees = -12,
	rightHipPitchDegrees = -10,
	rightKneePitchDegrees = -8,
}))
local CADENCE_BREAK = table.freeze(pose({
	rootHeightStuds = -0.20,
	rootPitchDegrees = -10,
	rootYawDegrees = -6,
	rootRollDegrees = -6,
	waistPitchDegrees = -6,
	waistYawDegrees = -12,
	neckYawDegrees = 6,
	leftShoulderPitchDegrees = -12,
	leftShoulderYawDegrees = -30,
	leftShoulderRollDegrees = -20,
	-- O lado esquerdo carrega enquanto o direito ainda está voltando.
	leftElbowPitchDegrees = -132,
	rightShoulderPitchDegrees = -24,
	rightShoulderYawDegrees = 20,
	rightElbowPitchDegrees = -58,
	leftHipPitchDegrees = -16,
	leftKneePitchDegrees = -38,
	rightHipPitchDegrees = 12,
	rightKneePitchDegrees = -18,
}))
local CADENCE_SECOND = table.freeze(pose({
	rootHeightStuds = -0.11,
	rootPitchDegrees = 13,
	rootYawDegrees = -40,
	rootRollDegrees = -8,
	waistPitchDegrees = 9,
	waistYawDegrees = -38,
	waistRollDegrees = -7,
	neckYawDegrees = 17,
	leftShoulderPitchDegrees = -104,
	leftShoulderYawDegrees = 24,
	leftShoulderRollDegrees = 16,
	-- Golpe 2 estende: é o revés que fecha a frase, oposto da cotovelada.
	leftElbowPitchDegrees = -14,
	leftWristPitchDegrees = -22,
	rightShoulderPitchDegrees = -36,
	rightShoulderYawDegrees = 18,
	rightElbowPitchDegrees = -88,
	leftHipPitchDegrees = -12,
	leftKneePitchDegrees = -10,
	rightHipPitchDegrees = 12,
	rightKneePitchDegrees = -16,
}))

-- Eco da reentrada: a mesma linha percorrida de novo, comprimida e com os dois
-- braços juntos. Não é um terceiro golpe novo — é o rastro do segundo voltando.
local CADENCE_ECHO_COIL = table.freeze(pose({
	rootHeightStuds = -0.12,
	rootPitchDegrees = -7,
	rootYawDegrees = -24,
	waistYawDegrees = -24,
	neckYawDegrees = 11,
	leftShoulderPitchDegrees = -58,
	leftShoulderYawDegrees = 18,
	leftElbowPitchDegrees = -108,
	rightShoulderPitchDegrees = -52,
	rightShoulderYawDegrees = 22,
	rightElbowPitchDegrees = -112,
	leftHipPitchDegrees = -10,
	leftKneePitchDegrees = -26,
	rightHipPitchDegrees = 10,
	rightKneePitchDegrees = -22,
}))
local CADENCE_ECHO_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.14,
	rootPitchDegrees = 16,
	rootYawDegrees = -46,
	rootRollDegrees = -9,
	waistPitchDegrees = 11,
	waistYawDegrees = -42,
	waistRollDegrees = -8,
	neckYawDegrees = 19,
	-- Os dois braços chegam juntos no mesmo plano: assinatura do eco.
	leftShoulderPitchDegrees = -112,
	leftShoulderYawDegrees = 28,
	leftShoulderRollDegrees = 18,
	leftElbowPitchDegrees = -14,
	leftWristPitchDegrees = -24,
	rightShoulderPitchDegrees = -88,
	rightShoulderYawDegrees = 32,
	rightShoulderRollDegrees = 14,
	rightElbowPitchDegrees = -26,
	rightWristPitchDegrees = -20,
	leftHipPitchDegrees = -14,
	leftKneePitchDegrees = -12,
	rightHipPitchDegrees = 14,
	rightKneePitchDegrees = -14,
}))

-- ── Retorno de Pulso — defesa simétrica, contra assimétrico ─────────────────
-- A postura é rigorosamente simétrica: nada nela pode sugerir para que lado o
-- jogador vai responder, porque na ativação ele ainda não sabe. Só o contra —
-- que existe apenas depois da confirmação do servidor — abre a pose.

local PULSE_GATHER = table.freeze(pose({
	rootHeightStuds = -0.24,
	rootPitchDegrees = 8,
	waistPitchDegrees = 7,
	neckPitchDegrees = -5,
	leftShoulderPitchDegrees = -76,
	leftShoulderYawDegrees = -26,
	leftShoulderRollDegrees = -22,
	leftElbowPitchDegrees = -118,
	rightShoulderPitchDegrees = -76,
	rightShoulderYawDegrees = 26,
	rightShoulderRollDegrees = 22,
	rightElbowPitchDegrees = -118,
	leftHipPitchDegrees = -12,
	leftKneePitchDegrees = -30,
	rightHipPitchDegrees = -12,
	rightKneePitchDegrees = -30,
	leftWristPitchDegrees = -18,
	rightWristPitchDegrees = -18,
}))
local PULSE_RELEASE = table.freeze(pose({
	rootHeightStuds = -0.06,
	rootPitchDegrees = -9,
	waistPitchDegrees = -7,
	neckPitchDegrees = 8,
	leftShoulderPitchDegrees = -34,
	leftShoulderYawDegrees = -76,
	leftShoulderRollDegrees = -28,
	leftElbowPitchDegrees = -22,
	rightShoulderPitchDegrees = -34,
	rightShoulderYawDegrees = 76,
	rightShoulderRollDegrees = 28,
	rightElbowPitchDegrees = -22,
	leftHipPitchDegrees = 6,
	leftKneePitchDegrees = -8,
	rightHipPitchDegrees = 6,
	rightKneePitchDegrees = -8,
}))
local PULSE_COUNTER_LOAD = table.freeze(pose({
	rootHeightStuds = -0.18,
	rootPitchDegrees = -6,
	rootYawDegrees = -18,
	waistYawDegrees = -18,
	neckYawDegrees = 9,
	leftShoulderPitchDegrees = -62,
	leftShoulderYawDegrees = -20,
	leftElbowPitchDegrees = -104,
	rightShoulderPitchDegrees = -58,
	rightShoulderYawDegrees = 24,
	rightShoulderRollDegrees = 14,
	rightElbowPitchDegrees = -118,
	leftHipPitchDegrees = -12,
	leftKneePitchDegrees = -28,
	rightHipPitchDegrees = 10,
	rightKneePitchDegrees = -22,
}))
local PULSE_COUNTER_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.09,
	rootPitchDegrees = 20,
	rootYawDegrees = 36,
	rootRollDegrees = 6,
	waistPitchDegrees = 14,
	waistYawDegrees = 34,
	waistRollDegrees = 6,
	neckPitchDegrees = -9,
	neckYawDegrees = -15,
	leftShoulderPitchDegrees = -40,
	leftShoulderYawDegrees = -18,
	leftElbowPitchDegrees = -86,
	-- Palma aberta e pulso travado: o contra devolve, não soca.
	rightShoulderPitchDegrees = -100,
	rightShoulderYawDegrees = -20,
	rightShoulderRollDegrees = -10,
	rightElbowPitchDegrees = -4,
	rightWristPitchDegrees = 26,
	leftHipPitchDegrees = 12,
	leftKneePitchDegrees = -10,
	rightHipPitchDegrees = -12,
	rightKneePitchDegrees = -18,
}))

-- ── Cadeia leve: quatro golpes de silhueta distinta ─────────────────────────
-- docs/14 §3: "ataques leves compartilham gramática, mas não a mesma silhueta".
-- Braço de apoio nunca cai — mantém guarda enquanto o outro lado trabalha.

-- 1. Jab de mão de frente: rápido, pouco compromisso, recuperação imediata.
local JAB_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.02,
	rootPitchDegrees = -2,
	rootYawDegrees = -8,
	waistYawDegrees = -9,
	neckYawDegrees = 4,
	leftShoulderPitchDegrees = -34,
	leftShoulderYawDegrees = -8,
	leftElbowPitchDegrees = -92,
	rightShoulderPitchDegrees = -46,
	rightShoulderYawDegrees = 16,
	rightElbowPitchDegrees = -98,
}))
local JAB_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.03,
	rootPitchDegrees = 5,
	rootYawDegrees = 11,
	rootRollDegrees = 2,
	waistYawDegrees = 15,
	neckYawDegrees = -6,
	leftShoulderPitchDegrees = -86,
	leftShoulderYawDegrees = -6,
	leftElbowPitchDegrees = -6,
	leftWristPitchDegrees = -22,
	rightShoulderPitchDegrees = -50,
	rightShoulderYawDegrees = 18,
	rightElbowPitchDegrees = -102,
	leftHipPitchDegrees = 4,
	rightHipPitchDegrees = -4,
	leftKneePitchDegrees = -6,
	rightKneePitchDegrees = -6,
}))

-- 2. Direto de mão de trás: o quadril entrega o golpe, não o braço.
local CROSS_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.05,
	rootPitchDegrees = -4,
	rootYawDegrees = -18,
	rootRollDegrees = -4,
	waistYawDegrees = -22,
	neckYawDegrees = 10,
	leftShoulderPitchDegrees = -52,
	leftShoulderYawDegrees = -14,
	leftElbowPitchDegrees = -88,
	rightShoulderPitchDegrees = 14,
	rightShoulderYawDegrees = 22,
	rightElbowPitchDegrees = -104,
	leftHipPitchDegrees = -6,
	rightHipPitchDegrees = 6,
}))
local CROSS_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.04,
	rootPitchDegrees = 9,
	rootYawDegrees = 28,
	rootRollDegrees = 5,
	waistPitchDegrees = 5,
	waistYawDegrees = 34,
	neckYawDegrees = -13,
	leftShoulderPitchDegrees = -38,
	leftShoulderYawDegrees = -16,
	leftElbowPitchDegrees = -80,
	rightShoulderPitchDegrees = -92,
	rightShoulderYawDegrees = -10,
	rightShoulderRollDegrees = -8,
	rightElbowPitchDegrees = -5,
	rightWristPitchDegrees = -22,
	leftHipPitchDegrees = 8,
	rightHipPitchDegrees = -8,
	leftKneePitchDegrees = -10,
	rightKneePitchDegrees = -4,
}))

-- 3. Chute circular: perna encaixa dobrada e estende; tronco contrabalança
-- para o lado oposto, senão o rig parece flutuar.
local KICK_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.10,
	rootPitchDegrees = -6,
	rootYawDegrees = -22,
	rootRollDegrees = -7,
	waistYawDegrees = -16,
	waistRollDegrees = -6,
	neckYawDegrees = 12,
	leftShoulderPitchDegrees = 26,
	leftShoulderYawDegrees = -20,
	leftElbowPitchDegrees = -70,
	rightShoulderPitchDegrees = -28,
	rightShoulderYawDegrees = 14,
	rightElbowPitchDegrees = -84,
	rightHipPitchDegrees = -38,
	rightHipYawDegrees = 12,
	rightKneePitchDegrees = -104,
	leftKneePitchDegrees = -16,
}))
local KICK_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.06,
	rootPitchDegrees = 4,
	rootYawDegrees = 32,
	rootRollDegrees = 14,
	waistYawDegrees = 27,
	waistRollDegrees = 12,
	neckYawDegrees = -16,
	leftShoulderPitchDegrees = 44,
	leftShoulderYawDegrees = -34,
	leftShoulderRollDegrees = -22,
	leftElbowPitchDegrees = -30,
	rightShoulderPitchDegrees = -20,
	rightShoulderYawDegrees = 26,
	rightElbowPitchDegrees = -60,
	rightHipPitchDegrees = -76,
	rightHipYawDegrees = 30,
	rightKneePitchDegrees = -20,
	leftHipPitchDegrees = 10,
	leftKneePitchDegrees = -10,
}))

-- 4. Finalizador giratório: maior amplitude, maior recuperação — é o golpe
-- que o oponente pune se errar.
local SPIN_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.14,
	rootPitchDegrees = -8,
	rootYawDegrees = -44,
	rootRollDegrees = -8,
	waistYawDegrees = -30,
	waistRollDegrees = -8,
	neckYawDegrees = 20,
	leftShoulderPitchDegrees = -58,
	leftShoulderYawDegrees = -24,
	leftElbowPitchDegrees = -110,
	rightShoulderPitchDegrees = -54,
	rightShoulderYawDegrees = 24,
	rightElbowPitchDegrees = -108,
	leftHipPitchDegrees = -18,
	leftKneePitchDegrees = -40,
	rightKneePitchDegrees = -22,
}))
local SPIN_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.10,
	rootPitchDegrees = 12,
	rootYawDegrees = 74,
	rootRollDegrees = -12,
	waistYawDegrees = 44,
	waistRollDegrees = -10,
	neckYawDegrees = -22,
	leftShoulderPitchDegrees = -30,
	leftShoulderYawDegrees = -40,
	leftElbowPitchDegrees = -50,
	rightShoulderPitchDegrees = 34,
	rightShoulderYawDegrees = 30,
	rightElbowPitchDegrees = -44,
	leftHipPitchDegrees = -84,
	leftHipYawDegrees = -18,
	leftKneePitchDegrees = -14,
	rightHipPitchDegrees = 12,
	rightKneePitchDegrees = -26,
}))

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function smooth(value: number): number
	local clamped = clamp01(value)
	return clamped * clamped * (3 - 2 * clamped)
end

-- Easing por fase: a antecipação "enrola" (easeIn) e o golpe "estala"
-- (easeOut). Antes, toda fase usava smoothstep e o arco inteiro lia igual.
local function easeInCubic(value: number): number
	local t = clamp01(value)
	return t * t * t
end

local function easeOutCubic(value: number): number
	local t = clamp01(value)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function blend(from: PoseSample, to: PoseSample, alpha: number): PoseSample
	local amount = clamp01(alpha)
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		local a = (from :: any)[key]
		built[key] = a + ((to :: any)[key] - a) * amount
	end
	return built :: any
end

-- Mesmo par de poses, duas fases: o núcleo já está adiantado quando a
-- extremidade ainda está a caminho. Sem isso, corpo inteiro chega junto e o
-- golpe parece um boneco girando de uma peça só.
local function phaseBlend(from: PoseSample, to: PoseSample, limbAlpha: number, coreAlpha: number): PoseSample
	local limb = clamp01(limbAlpha)
	local core = clamp01(coreAlpha)
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		local a = (from :: any)[key]
		local amount = if CORE_KEYS[key] then core else limb
		built[key] = a + ((to :: any)[key] - a) * amount
	end
	return built :: any
end

-- Saída elástica: passa levemente do alvo e assenta. easeOutBack(1) é
-- exatamente 1, então a pose termina em neutro cravado, sem resíduo.
local BACK_C1 = 1.70158
local function easeOutBack(value: number): number
	local t = clamp01(value) - 1
	return 1 + (BACK_C1 + 1) * t * t * t + BACK_C1 * t * t
end

-- Interpolação sem clamp: a saída elástica precisa passar de 1 para ultrapassar
-- o alvo antes de assentar. blend() continua limitado, para os demais usos.
local function lerpPose(from: PoseSample, to: PoseSample, amount: number): PoseSample
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		local a = (from :: any)[key]
		built[key] = a + ((to :: any)[key] - a) * amount
	end
	return built :: any
end

-- Quanto o núcleo se adianta à extremidade, como fração da fase. Proporcional,
-- não em segundos: numa antecipação de 50 ms um lead fixo faria o tronco
-- teleportar para a pose final antes de o braço sair do lugar.
local CORE_LEAD_FRACTION = 0.25

-- Follow-through: o membro continua além do ponto de impacto antes de o
-- retorno elástico trazê-lo de volta. FOLLOW_THROUGH é a fração extra sobre a
-- pose de impacto; FOLLOW_WINDOW é a porção da recuperação gasta nesse exagero.
local FOLLOW_THROUGH = 0.14
local FOLLOW_WINDOW = 0.32

-- Respiração do idle de combate: micro-oscilação no tronco/ombros quando não
-- há ação em curso, para que o neutro não pareça um boneco congelado.
local IDLE_BREATH_CYCLES = 0.4
local IDLE_BREATH_AMPLITUDE_DEG = 1.2

-- Sobrepõe a respiração ao neutro/guarda. `nowSeconds` é o relógio injetado;
-- com nil a fase vale 0 e a pose retorna exatamente o base (testes dependem
-- de `sample(nil, 0, true)` continuar devolvendo a guarda canônica).
local function idleBreathPose(base: PoseSample, nowSeconds: number?): PoseSample
	local t = nowSeconds or 0
	local amp = math.sin(t * math.pi * 2 * IDLE_BREATH_CYCLES) * IDLE_BREATH_AMPLITUDE_DEG
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		built[key] = (base :: any)[key]
	end
	built.rootPitchDegrees = built.rootPitchDegrees + amp * 0.4
	built.waistPitchDegrees = built.waistPitchDegrees + amp
	built.leftShoulderPitchDegrees = built.leftShoulderPitchDegrees + amp * 0.3
	built.rightShoulderPitchDegrees = built.rightShoulderPitchDegrees + amp * 0.3
	return built :: any
end

PlayerCombatAnimator.FollowThrough = FOLLOW_THROUGH
PlayerCombatAnimator.FollowWindow = FOLLOW_WINDOW
PlayerCombatAnimator.IdleBreathCycles = IDLE_BREATH_CYCLES
PlayerCombatAnimator.IdleBreathAmplitudeDeg = IDLE_BREATH_AMPLITUDE_DEG

-- Recuperação com follow-through: a pose continua além do último quadro forte
-- antes de o retorno elástico assentar. easeOutBack(1) == 1 garante o neutro
-- exato no fim, sem resíduo entre ações. Compartilhada por golpes básicos e
-- técnicas para que todas terminem com o mesmo peso.
local function recoverPose(from: PoseSample, elapsed: number, holdEnd: number, duration: number): PoseSample
	local span = duration - holdEnd
	if span <= 0 then
		return pose(NEUTRAL :: any)
	end
	local t = clamp01((elapsed - holdEnd) / span)
	local overextend = lerpPose(from, NEUTRAL, -FOLLOW_THROUGH)
	if t <= FOLLOW_WINDOW then
		return lerpPose(from, overextend, easeOutCubic(t / FOLLOW_WINDOW))
	end
	return lerpPose(overextend, NEUTRAL, easeOutBack((t - FOLLOW_WINDOW) / (1 - FOLLOW_WINDOW)))
end

-- Estrutura de qualquer golpe: antecipação → ataque → pausa curta de impacto →
-- retorno elástico. A pausa é o que dá peso; sem ela o golpe "atravessa" o alvo.
local function strikeSequence(
	elapsed: number,
	windupEnd: number,
	strikeEnd: number,
	holdEnd: number,
	duration: number,
	windup: PoseSample,
	strike: PoseSample
): PoseSample
	if elapsed <= windupEnd then
		local t = elapsed / windupEnd
		return phaseBlend(NEUTRAL, windup, easeInCubic(t), easeInCubic(t + CORE_LEAD_FRACTION))
	elseif elapsed <= strikeEnd then
		local t = (elapsed - windupEnd) / (strikeEnd - windupEnd)
		return phaseBlend(windup, strike, easeOutCubic(t), easeOutCubic(t + CORE_LEAD_FRACTION))
	elseif elapsed <= holdEnd then
		return pose(strike :: any)
	end
	return recoverPose(strike, elapsed, holdEnd, duration)
end

-- ── Trilha de quadros ───────────────────────────────────────────────────────
-- Um golpe de dois tempos cabe em `strikeSequence`. As técnicas não: a Cadência
-- tem quatro quadros fortes com intervalos desiguais e o Pulso tem uma
-- sustentação no meio. Declarar {instante, pose, curva} deixa o timing legível
-- ao lado do número autoritativo do servidor, em vez de escondido num if-chain.
--
-- O núcleo continua adiantado dentro de cada segmento (CORE_LEAD_FRACTION), de
-- modo que o "peso atrasado" vale para técnicas de muitos quadros também.
type PoseKey = { at: number, pose: PoseSample, ease: ((number) -> number)? }

local function trackPose(keys: { PoseKey }, elapsed: number): PoseSample
	local first = keys[1]
	if elapsed <= first.at then
		return pose(first.pose :: any)
	end
	for index = 2, #keys do
		local previous = keys[index - 1]
		local current = keys[index]
		if elapsed <= current.at then
			local span = current.at - previous.at
			if span <= 0 then
				return pose(current.pose :: any)
			end
			local t = (elapsed - previous.at) / span
			local ease = current.ease or smooth
			return phaseBlend(previous.pose, current.pose, ease(t), ease(t + CORE_LEAD_FRACTION))
		end
	end
	return pose(keys[#keys].pose :: any)
end

-- Trilha + recuperação elástica: os quadros levam até o último ponto forte e o
-- retorno assenta em neutro exato. `holdEnd` é onde a recuperação começa.
local function techniquePose(keys: { PoseKey }, elapsed: number, holdEnd: number, duration: number): PoseSample
	if elapsed <= holdEnd then
		return trackPose(keys, elapsed)
	end
	return recoverPose(keys[#keys].pose, elapsed, holdEnd, duration)
end

local function attackPose(
	elapsed: number,
	windupEnd: number,
	strikeEnd: number,
	duration: number,
	windup: PoseSample,
	strike: PoseSample
): PoseSample
	-- Pausa de impacto proporcional ao golpe, limitada para não comer toda a
	-- recuperação de técnicas curtas.
	local holdEnd = math.min(strikeEnd + 0.06, strikeEnd + (duration - strikeEnd) * 0.35)
	return strikeSequence(elapsed, windupEnd, strikeEnd, holdEnd, duration, windup, strike)
end

-- Timing por degrau da cadeia: {antecipação, impacto, fim da pausa, duração}.
-- O golpe fica progressivamente mais lento e mais punível — o 4 é compromisso.
local LIGHT_CHAIN: { { number } } = {
	-- O jab mantém a antecipação em 0.065 s: é o contrato de leitura que os
	-- testes de apresentação de run.luau já fixam para o golpe leve.
	{ 0.065, 0.115, 0.155, 0.240 },
	{ 0.070, 0.150, 0.200, 0.300 },
	{ 0.110, 0.215, 0.275, 0.380 },
	{ 0.135, 0.265, 0.335, 0.480 },
}
local LIGHT_CHAIN_POSES: { { PoseSample } } = {
	{ JAB_WINDUP, JAB_STRIKE },
	{ CROSS_WINDUP, CROSS_STRIKE },
	{ KICK_WINDUP, KICK_STRIKE },
	{ SPIN_WINDUP, SPIN_STRIKE },
}

-- A janela de encadeamento espelha LIGHT_WINDOW do CombatService. Divergir aqui
-- só desalinha a apresentação: quem decide o degrau real continua o servidor.
local LIGHT_CHAIN_WINDOW_SECONDS = 0.65
PlayerCombatAnimator.LightChainWindowSeconds = LIGHT_CHAIN_WINDOW_SECONDS
PlayerCombatAnimator.LightChainLength = #LIGHT_CHAIN

function PlayerCombatAnimator.lightChainDuration(step: number): number
	local timing = LIGHT_CHAIN[math.clamp(math.floor(step), 1, #LIGHT_CHAIN)]
	return timing[4]
end

local function chainPose(step: number, elapsed: number): PoseSample
	local index = math.clamp(math.floor(step), 1, #LIGHT_CHAIN)
	local timing = LIGHT_CHAIN[index]
	local poses = LIGHT_CHAIN_POSES[index]
	return strikeSequence(elapsed, timing[1], timing[2], timing[3], timing[4], poses[1], poses[2])
end

local BEATS = PlayerCombatAnimator.AuthoritativeBeats

-- Ombro Cometa: recolhe → dirige → crava. O quadro de impacto cai em 0,40 s,
-- que é o fim do active de 220 ms declarado no catálogo.
local COMET_KEYS: { PoseKey } = {
	{ at = 0, pose = NEUTRAL },
	{ at = 0.18, pose = COMET_COIL, ease = easeInCubic },
	{ at = BEATS.cometImpact, pose = COMET_DRIVE, ease = easeOutCubic },
	-- Pausa de impacto: o ombro fica enterrado alguns quadros. É aqui que a
	-- técnica ganha peso — sem a pausa o rig atravessa o alvo e não "bate".
	{ at = 0.46, pose = COMET_DRIVE },
}

-- Cadência Quebrada: os dois picos batem exatamente nos instantes em que o
-- AbilityService resolve dano (0,14 s e 0,32 s). O quadro do meio é a quebra
-- do compasso — o corpo puxa contra o próprio arco antes do segundo golpe.
local CADENCE_KEYS: { PoseKey } = {
	{ at = 0, pose = NEUTRAL },
	{ at = 0.07, pose = CADENCE_COIL, ease = easeInCubic },
	{ at = BEATS.cadenceFirstHit, pose = CADENCE_FIRST, ease = easeOutCubic },
	{ at = 0.18, pose = CADENCE_FIRST },
	{ at = 0.24, pose = CADENCE_BREAK, ease = easeInCubic },
	{ at = BEATS.cadenceSecondHit, pose = CADENCE_SECOND, ease = easeOutCubic },
	{ at = 0.38, pose = CADENCE_SECOND },
}

-- Eco: o pico cai em 0,35 s porque é quando o servidor resolve o dano do eco
-- (CADENCE_ECHO_DELAY_MS após a reentrada).
local CADENCE_ECHO_KEYS: { PoseKey } = {
	{ at = 0, pose = NEUTRAL },
	{ at = 0.12, pose = CADENCE_ECHO_COIL, ease = easeInCubic },
	{ at = BEATS.cadenceEchoHit, pose = CADENCE_ECHO_STRIKE, ease = easeOutCubic },
	{ at = 0.40, pose = CADENCE_ECHO_STRIKE },
}

-- Contra do Pulso: só é tocado depois de o servidor confirmar. Por isso pode
-- abrir a pose sem mentir — a informação já é certa quando a animação começa.
local PULSE_COUNTER_KEYS: { PoseKey } = {
	{ at = 0, pose = PULSE_GATHER },
	{ at = 0.07, pose = PULSE_COUNTER_LOAD, ease = easeInCubic },
	{ at = 0.20, pose = PULSE_COUNTER_STRIKE, ease = easeOutCubic },
	{ at = 0.26, pose = PULSE_COUNTER_STRIKE },
}

-- Micro-tensão da postura do Pulso: a guarda não pode ficar estática durante os
-- 250 ms, senão lê como pausa do jogo. A oscilação toca somente chaves
-- simétricas (altura, cintura e os dois cotovelos com o mesmo valor), o que
-- preserva a simetria exata exigida da postura.
local PULSE_TENSION_HZ = 9
local PULSE_TENSION_DEG = 2.4

local function pulseTension(base: PoseSample, elapsed: number): PoseSample
	local wave = math.sin(elapsed * math.pi * 2 * PULSE_TENSION_HZ)
	local built: { [string]: number } = {}
	for _, key in POSE_KEYS do
		built[key] = (base :: any)[key]
	end
	built.rootHeightStuds = built.rootHeightStuds + wave * 0.012
	built.waistPitchDegrees = built.waistPitchDegrees + wave * PULSE_TENSION_DEG * 0.5
	built.leftElbowPitchDegrees = built.leftElbowPitchDegrees - wave * PULSE_TENSION_DEG
	built.rightElbowPitchDegrees = built.rightElbowPitchDegrees - wave * PULSE_TENSION_DEG
	return built :: any
end

-- Retorno de Pulso: a guarda precisa estar formada muito antes do fim da
-- janela, porque o aparo vale de 0 a 250 ms. Por isso a coleta é rápida (90 ms)
-- e o resto do tempo é sustentação — a técnica é espera, não gesto.
local PULSE_GATHER_END = 0.09
local PULSE_RELEASE_PEAK = 0.43

local function pulsePose(elapsed: number): PoseSample
	if elapsed <= PULSE_GATHER_END then
		local t = elapsed / PULSE_GATHER_END
		return phaseBlend(NEUTRAL, PULSE_GATHER, easeOutCubic(t), easeOutCubic(t + CORE_LEAD_FRACTION))
	elseif elapsed <= BEATS.pulseStanceEnd then
		return pulseTension(PULSE_GATHER, elapsed - PULSE_GATHER_END)
	elseif elapsed <= PULSE_RELEASE_PEAK then
		local t = (elapsed - BEATS.pulseStanceEnd) / (PULSE_RELEASE_PEAK - BEATS.pulseStanceEnd)
		return phaseBlend(PULSE_GATHER, PULSE_RELEASE, easeOutCubic(t), easeOutCubic(t + CORE_LEAD_FRACTION))
	end
	return recoverPose(PULSE_RELEASE, elapsed, PULSE_RELEASE_PEAK, DURATIONS.Ability3)
end

-- Função pura: a mesma intenção e tempo sempre produzem a mesma pose numérica.
-- Isso permite validar timing e amplitudes sem DataModel, personagem ou assets.
function PlayerCombatAnimator.sample(
	action: CombatAction?,
	elapsed: number,
	guarding: boolean,
	comboStep: number?,
	nowSeconds: number?
): PoseSample
	local safeElapsed = math.max(0, elapsed)
	if action == "GuardDown" then
		return blend(NEUTRAL, GUARD, smooth(safeElapsed / DURATIONS.GuardDown))
	elseif action == "GuardUp" then
		return blend(GUARD, NEUTRAL, smooth(safeElapsed / DURATIONS.GuardUp))
	elseif action == "BasicLight" then
		return chainPose(comboStep or 1, safeElapsed)
	elseif action == "BasicHeavy" then
		return attackPose(safeElapsed, 0.17, 0.285, DURATIONS.BasicHeavy, HEAVY_WINDUP, HEAVY_STRIKE)
	elseif action == "Dash" then
		if safeElapsed <= 0.075 then
			return blend(NEUTRAL, DASH, smooth(safeElapsed / 0.075))
		elseif safeElapsed <= 0.18 then
			return pose(DASH :: any)
		end
		return blend(DASH, NEUTRAL, smooth((safeElapsed - 0.18) / (DURATIONS.Dash - 0.18)))
	elseif action == "Ability1" then
		-- A sensação de avanço vem da inclinação do rig; não há translação X/Z
		-- nem escrita no HumanoidRootPart. Quem move o jogador 7 studs é o
		-- SpatialService, e a pose apenas concorda com esse deslocamento.
		return techniquePose(COMET_KEYS, safeElapsed, 0.46, DURATIONS.Ability1)
	elseif action == "Ability2" then
		return techniquePose(CADENCE_KEYS, safeElapsed, 0.38, DURATIONS.Ability2)
	elseif action == "Ability2Echo" then
		return techniquePose(CADENCE_ECHO_KEYS, safeElapsed, 0.40, DURATIONS.Ability2Echo)
	elseif action == "Ability3" then
		return pulsePose(safeElapsed)
	elseif action == "Ability3Counter" then
		return techniquePose(PULSE_COUNTER_KEYS, safeElapsed, 0.26, DURATIONS.Ability3Counter)
	end
	local base = if guarding then pose(GUARD :: any) else pose(NEUTRAL :: any)
	return idleBreathPose(base, nowSeconds)
end

local function normalizedName(name: string): string
	return string.lower(string.gsub(name, "[^%w]", ""))
end

local JOINT_CANDIDATES: { [string]: { string } } = {
	root = { "root", "rootjoint" },
	waist = { "waist" },
	neck = { "neck" },
	leftShoulder = { "leftshoulder" },
	rightShoulder = { "rightshoulder" },
	-- R15 tem cotovelo e joelho; R6 não. Ausente, o overlay simplesmente não é
	-- aplicado àquele papel e o resto da pose continua legível.
	leftElbow = { "leftelbow" },
	rightElbow = { "rightelbow" },
	leftHip = { "lefthip" },
	rightHip = { "righthip" },
	leftKnee = { "leftknee" },
	rightKnee = { "rightknee" },
	leftWrist = { "leftwrist" },
	rightWrist = { "rightwrist" },
}

-- Nome da junta → papel da pose, já normalizado ("Left Shoulder" do R6 e
-- "LeftShoulder" do R15 caem no mesmo papel).
local JOINT_ROLE_BY_NAME: { [string]: string } = {}
for role, candidates in JOINT_CANDIDATES do
	for _, candidate in candidates do
		JOINT_ROLE_BY_NAME[candidate] = role
	end
end

-- Classes de junta que aceitam overlay. Motor6D é o rig clássico;
-- AnimationConstraint é como o avatar R15 atual é montado (ver cabeçalho) — o
-- personagem do jogador hoje só tem a segunda. Função pura para o teste Lune
-- travar as duas sem DataModel: se alguém restringir isso a Motor6D de novo, o
-- combate inteiro volta a ficar sem animação e o teste falha na hora.
local POSE_JOINT_CLASSES: { [string]: boolean } = {
	Motor6D = true,
	AnimationConstraint = true,
}

function PlayerCombatAnimator.isPoseJointClass(className: string): boolean
	return POSE_JOINT_CLASSES[className] == true
end

function PlayerCombatAnimator.jointRole(jointName: string): string?
	return JOINT_ROLE_BY_NAME[normalizedName(jointName)]
end

local function jointTransform(joint: PoseJoint): CFrame
	return (joint :: any).Transform
end

local function setJointTransform(joint: PoseJoint, value: CFrame): ()
	local target = joint :: any
	target.Transform = value
end

local function restoreJoints(animator: Animator): ()
	for _, state in animator.joints do
		local joint = state.joint
		if joint.Parent and state.lastApplied and jointTransform(joint) == state.lastApplied then
			setJointTransform(joint, state.baseTransform)
		end
	end
	table.clear(animator.joints)
end

local function attachCharacter(animator: Animator, character: Model?): ()
	if animator.character == character then
		return
	end
	restoreJoints(animator)
	animator.character = character
	if not character then
		return
	end

	-- Primeira junta encontrada por papel vence. O rig atual traz só
	-- AnimationConstraint, o clássico só Motor6D; aceitar as duas é o que faz o
	-- overlay existir nos dois mundos, sem ramo por versão de avatar.
	for _, descendant in character:GetDescendants() do
		if not PlayerCombatAnimator.isPoseJointClass(descendant.ClassName) then
			continue
		end
		local role = PlayerCombatAnimator.jointRole(descendant.Name)
		if role and not animator.joints[role] then
			animator.joints[role] = {
				joint = descendant,
				baseTransform = jointTransform(descendant),
				lastApplied = nil,
			}
		end
	end
end

local function overlay(pitchDegrees: number, yawDegrees: number, rollDegrees: number, heightStuds: number?): CFrame
	return CFrame.new(0, heightStuds or 0, 0)
		* CFrame.Angles(math.rad(pitchDegrees), math.rad(yawDegrees), math.rad(rollDegrees))
end

local function applyJoint(animator: Animator, role: string, value: CFrame): ()
	local state = animator.joints[role]
	if not state or not state.joint.Parent then
		return
	end
	local current = jointTransform(state.joint)
	-- Sem Animator ativo, Transform ainda contém nosso resultado anterior. Nesse
	-- caso recuperamos a base salva antes de compor o novo overlay. Se o Animator
	-- escreveu uma pose nova em PreAnimation, ela vira a nova base naturalmente.
	if state.lastApplied and current == state.lastApplied then
		current = state.baseTransform
	end
	state.baseTransform = current
	local applied = current * value
	setJointTransform(state.joint, applied)
	state.lastApplied = applied
end

local function applySample(animator: Animator, sample: PoseSample): ()
	applyJoint(
		animator,
		"root",
		overlay(sample.rootPitchDegrees, sample.rootYawDegrees, sample.rootRollDegrees, sample.rootHeightStuds)
	)
	applyJoint(animator, "waist", overlay(sample.waistPitchDegrees, sample.waistYawDegrees, sample.waistRollDegrees))
	applyJoint(animator, "neck", overlay(sample.neckPitchDegrees, sample.neckYawDegrees, 0))
	applyJoint(
		animator,
		"leftShoulder",
		overlay(sample.leftShoulderPitchDegrees, sample.leftShoulderYawDegrees, sample.leftShoulderRollDegrees)
	)
	applyJoint(
		animator,
		"rightShoulder",
		overlay(sample.rightShoulderPitchDegrees, sample.rightShoulderYawDegrees, sample.rightShoulderRollDegrees)
	)
	applyJoint(animator, "leftElbow", overlay(sample.leftElbowPitchDegrees, 0, 0))
	applyJoint(animator, "rightElbow", overlay(sample.rightElbowPitchDegrees, 0, 0))
	applyJoint(animator, "leftHip", overlay(sample.leftHipPitchDegrees, sample.leftHipYawDegrees, 0))
	applyJoint(animator, "rightHip", overlay(sample.rightHipPitchDegrees, sample.rightHipYawDegrees, 0))
	applyJoint(animator, "leftKnee", overlay(sample.leftKneePitchDegrees, 0, 0))
	applyJoint(animator, "rightKnee", overlay(sample.rightKneePitchDegrees, 0, 0))
	applyJoint(animator, "leftWrist", overlay(sample.leftWristPitchDegrees, 0, 0))
	applyJoint(animator, "rightWrist", overlay(sample.rightWristPitchDegrees, 0, 0))
end

function PlayerCombatAnimator.new(deps: {
	player: any,
	runService: any,
	now: (() -> number)?,
	emitCue: ((string) -> ())?,
}): Animator
	return {
		player = deps.player,
		runService = deps.runService,
		now = deps.now or os.clock,
		action = nil,
		actionStartedAt = 0,
		hitStopUntil = 0,
		guarding = false,
		comboStep = 0,
		lastLightAt = 0,
		emitCue = deps.emitCue,
		pendingCue = nil,
		pendingCueAt = 0,
		character = nil,
		joints = {},
		preSimulationConnection = nil,
		characterAddedConnection = nil,
	}
end

-- Deixa sonora por ação e o atraso até o corte de ar — que soa quando a
-- antecipação termina e o membro acelera, não no instante do input.
--
-- Os ids espelham src/shared/Data/CombatAudio.luau de propósito: o animador
-- não requer o catálogo (é apresentação pura e precisa carregar em teste sem
-- DataModel). Um teste garante que nenhum id aqui saia do catálogo.
local ACTION_CUE: { [string]: { id: string, delaySeconds: number } } = {
	BasicHeavy = { id = "swing_heavy", delaySeconds = 0.17 },
	Dash = { id = "dash", delaySeconds = 0 },
	GuardDown = { id = "guard_raise", delaySeconds = 0 },
	-- O atraso é o fim da antecipação de cada técnica, não o instante do input:
	-- o corte de ar sai quando o corpo acelera.
	Ability1 = { id = "ability_comet_shoulder", delaySeconds = 0.18 },
	Ability2 = { id = "ability_broken_cadence", delaySeconds = 0.07 },
	Ability3 = { id = "ability_pulse_return", delaySeconds = 0.0 },
	Ability2Echo = { id = "ability_cadence_echo", delaySeconds = 0.12 },
	Ability3Counter = { id = "ability_pulse_counter", delaySeconds = 0.07 },
}
local LIGHT_SWING_CUE: { string } = {
	"swing_light_1",
	"swing_light_2",
	"swing_light_3",
	"swing_light_4",
}

PlayerCombatAnimator.ActionCueIds = ACTION_CUE
PlayerCombatAnimator.LightSwingCueIds = LIGHT_SWING_CUE

-- Agenda o corte de ar da ação. Substitui qualquer deixa ainda pendente: se o
-- jogador encadeou, o som do golpe anterior não deve sair atrasado.
local function scheduleCue(animator: Animator, action: string, now: number): ()
	if not animator.emitCue then
		return
	end
	if action == "BasicLight" then
		local index = math.clamp(animator.comboStep, 1, #LIGHT_SWING_CUE)
		animator.pendingCue = LIGHT_SWING_CUE[index]
		animator.pendingCueAt = now + LIGHT_CHAIN[index][1]
		return
	end
	local entry = ACTION_CUE[action]
	if entry then
		animator.pendingCue = entry.id
		animator.pendingCueAt = now + entry.delaySeconds
	else
		animator.pendingCue = nil
	end
end

-- Avança o degrau da cadeia se o golpe veio dentro da janela; caso contrário
-- recomeça no jab. Depois do último, volta ao início.
local function advanceLightChain(animator: Animator, now: number): ()
	local withinWindow = animator.comboStep > 0
		and animator.comboStep < #LIGHT_CHAIN
		and (now - animator.lastLightAt) <= LIGHT_CHAIN_WINDOW_SECONDS
	animator.comboStep = if withinWindow then animator.comboStep + 1 else 1
	animator.lastLightAt = now
end

function PlayerCombatAnimator.play(animator: Animator, action: string): boolean
	if not DURATIONS[action] then
		return false
	end
	local now = animator.now()
	if action == "GuardDown" then
		animator.guarding = true
	elseif action == "GuardUp" then
		animator.guarding = false
	end
	if action == "BasicLight" then
		advanceLightChain(animator, now)
	else
		-- Qualquer outra ação quebra a cadeia, como no servidor.
		animator.comboStep = 0
	end
	animator.action = action :: CombatAction
	animator.actionStartedAt = now
	scheduleCue(animator, action, now)
	return true
end

-- Sincroniza o degrau da cadeia com o valor autoritativo do servidor
-- (docs/14 §4.3): acerto confirmado fixa o degrau; whiff (step 0) zera a
-- pose visual. Só ajusta o degrau — nunca decide acerto nem dano.
function PlayerCombatAnimator.syncStep(animator: Animator, step: number): ()
	animator.comboStep = if type(step) == "number" and step > 0
		then math.clamp(math.floor(step), 1, PlayerCombatAnimator.LightChainLength)
		else 0
end

-- Dispara a deixa agendada quando o relógio a alcança. Chamado pelo step e
-- exposto para teste sem DataModel.
function PlayerCombatAnimator.flushCue(animator: Animator, now: number): string?
	local cueId = animator.pendingCue
	if not cueId or now < animator.pendingCueAt then
		return nil
	end
	animator.pendingCue = nil
	local emit = animator.emitCue
	if emit then
		emit(cueId)
	end
	return cueId
end

-- A cadeia leve tem duração própria por degrau; as demais ações usam DURATIONS.
-- Isolado em função para que o refinamento de `action` fique contido aqui.
local function actionDuration(action: CombatAction?, comboStep: number): number
	if not action then
		return 0
	end
	if action == "BasicLight" then
		return PlayerCombatAnimator.lightChainDuration(comboStep)
	end
	return DURATIONS[action] or 0
end

function PlayerCombatAnimator.step(animator: Animator): ()
	-- Áudio antes do early return: o som da ação não depende de o rig já estar
	-- anexado, e perder o corte de ar por um frame sem personagem seria audível.
	PlayerCombatAnimator.flushCue(animator, animator.now())

	-- Hit-stop visual: segura a pose por alguns ms no impacto confirmado.
	if PlayerCombatAnimator.hitStopActive(animator.now(), animator.hitStopUntil) then
		return
	end

	local character = animator.player.Character
	if character ~= animator.character then
		attachCharacter(animator, character)
	end
	if not animator.character or not animator.character.Parent then
		return
	end

	local action: CombatAction? = animator.action
	local elapsed = if action then math.max(0, animator.now() - animator.actionStartedAt) else 0
	local duration = actionDuration(action, animator.comboStep)
	if action and elapsed >= duration then
		action = nil
		animator.action = nil
	end
	applySample(
		animator,
		PlayerCombatAnimator.sample(action, elapsed, animator.guarding, animator.comboStep, animator.now())
	)
end

function PlayerCombatAnimator.start(animator: Animator): ()
	if animator.preSimulationConnection then
		return
	end
	animator.characterAddedConnection = animator.player.CharacterAdded:Connect(function(character: Model)
		attachCharacter(animator, character)
	end)
	attachCharacter(animator, animator.player.Character)
	animator.preSimulationConnection = animator.runService.PreSimulation:Connect(function()
		PlayerCombatAnimator.step(animator)
	end)
end

function PlayerCombatAnimator.stop(animator: Animator): ()
	if animator.preSimulationConnection then
		animator.preSimulationConnection:Disconnect()
		animator.preSimulationConnection = nil
	end
	if animator.characterAddedConnection then
		animator.characterAddedConnection:Disconnect()
		animator.characterAddedConnection = nil
	end
	restoreJoints(animator)
	animator.character = nil
	animator.action = nil
	animator.guarding = false
end

return PlayerCombatAnimator

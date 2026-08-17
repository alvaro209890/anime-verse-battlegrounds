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
	-- Passo à frente do quadril, em studs, no eixo da frente do personagem.
	-- É o que transforma "soco" em "entrar no soco": sem deslocamento o rig
	-- gira no lugar e o golpe lê como braço mexendo. VISUAL — a raiz física
	-- (HumanoidRootPart) não sai do lugar, então alcance, hitbox e posição
	-- autoritativa não mudam em nada.
	rootForwardStuds: number,
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
	-- Tornozelo é o que faz o golpe ter CHÃO. Sem ele o pé de trás fica colado
	-- enquanto o quadril gira, e o soco lê como "braço mexendo" em cima de um
	-- boneco parado — que foi a reclamação de 14/08 à tarde.
	leftAnklePitchDegrees: number,
	rightAnklePitchDegrees: number,
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
	-- Contato previsto (docs/17 §2.11): dispara no instante da antecipação,
	-- o mesmo do corte de ar. O CombatEvent confirma HP; se chegar antes,
	-- clearPredictedHit evita o flash dobrado.
	predictedHitAbilityId: string?,
	predictedHitAt: number,
	onPredictedHit: ((string) -> ())?,
	character: Model?,
	joints: { [string]: JointState },
	preSimulationConnection: any?,
	characterAddedConnection: any?,
	descendantConnection: any?,
}

local PlayerCombatAnimator = {}

-- As três técnicas duram exatamente startup + active + recovery do catálogo
-- (src/shared/Data/Abilities.luau). Antes a apresentação era mais curta que a
-- regra: a pose voltava ao neutro enquanto o servidor ainda resolvia impacto,
-- e o jogador lia "acabou" antes de acabar. Um teste trava essa igualdade.
local DURATIONS: { [string]: number } = {
	BasicLight = 0.28,
	-- Pesado recalibrado em 17/08 junto com a cadeia leve (ver LIGHT_CHAIN): a
	-- carga é o dobro da do leve porque é a ferramenta de quebra de guarda, e
	-- precisa ler como tal antes de conectar.
	BasicHeavy = 0.68,
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
-- Fases do pesado. Existem como constante porque três lugares precisam do MESMO
-- número: a pose, o atraso do corte de ar e os testes. Quando isto era literal
-- em cada ponto, mudar o timing exigia lembrar dos três — e o som saía fora do
-- golpe se alguém esquecesse um.
PlayerCombatAnimator.HeavyBeats = table.freeze({
	windupEnd = 0.26,
	strikeEnd = 0.40,
})

PlayerCombatAnimator.AuthoritativeBeats = table.freeze({
	cadenceFirstHit = 0.14,
	cadenceSecondHit = 0.32,
	cadenceEchoHit = 0.35,
	pulseStanceEnd = 0.25,
	cometImpact = 0.40,
})

-- Hit-stop por desfecho (docs/14 §6): milissegundos de congelamento visual no
-- impacto confirmado. Guarda só um clique; morte segura um pouco mais.
-- Recalibrado em 14/08 junto com o shake: 40 ms são 2,4 quadros a 60 fps, curto
-- demais para o olho separar "bateu" de "passou perto". Continua curto de
-- propósito — hit-stop longo demais faz a cadeia leve parecer travada.
PlayerCombatAnimator.HitStopMs = table.freeze({
	hit = 70,
	death = 110,
	guard = 35,
	-- O contra do Retorno de Pulso é o momento mais raro do kit: segura um pouco
	-- mais que um acerto comum para que a leitura "eu aparei" seja inequívoca.
	counter = 90,
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
	"rootForwardStuds",
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
	"leftAnklePitchDegrees",
	"rightAnklePitchDegrees",
}

-- Núcleo (quadril/tronco/pescoço) inicia o movimento; a extremidade fecha
-- depois. Amostrar esses dois grupos com fases distintas é o que produz o
-- "peso atrasado" de docs/14 §3 sem exigir keyframe.
local CORE_KEYS: { [string]: boolean } = {
	rootHeightStuds = true,
	rootForwardStuds = true,
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
	-- ⚠️ SINAL DOS EIXOS — medido no rig real em 2026-08-17, não deduzido.
	-- Varredura no Studio (ombro esquerdo isolado, mão medida no referencial do
	-- UpperTorso) deu o mapa abaixo, e ele contradiz o que esta pose assumia:
	--
	--   ombro X +60 -> frente +1.46  (braço À FRENTE)
	--   ombro X -60 -> frente -1.55  (braço ATRÁS)
	--   ombro Z +60 -> lado  +0.35   (fecha, cotovelo para dentro)
	--   ombro Z -60 -> lado  -2.67   (abre, cotovelo para fora)
	--
	-- Até 17/08 a guarda usava pitch NEGATIVO (-52/-48) e roll de abertura
	-- (-12/+14): ela jogava os dois braços para TRÁS e para FORA do corpo. Não
	-- existia ajuste fino capaz de salvar isso — o sinal estava invertido. O
	-- mesmo valia para o cotovelo (-78/-82), que dobrava o antebraço para baixo.
	--
	-- Os valores abaixo saíram de busca em grade contra um alvo geométrico
	-- (punho na altura do rosto, à frente do peito, mãos juntas) e foram medidos:
	-- altura +1.27 com a cabeça em +1.41, frente +1.02, largura 1.37 contra 2.80
	-- de vão de ombro. Isso é guarda de boxe: punhos na bochecha, cotovelos
	-- recolhidos protegendo o tronco.
	leftShoulderPitchDegrees = 80,
	leftShoulderYawDegrees = 0,
	leftShoulderRollDegrees = 45,
	rightShoulderPitchDegrees = 80,
	rightShoulderYawDegrees = 0,
	rightShoulderRollDegrees = -45,
	leftElbowPitchDegrees = 75,
	rightElbowPitchDegrees = 75,
	leftWristPitchDegrees = -14,
	rightWristPitchDegrees = -14,
	leftKneePitchDegrees = -16,
	rightKneePitchDegrees = -16,
	leftAnklePitchDegrees = 5,
	rightAnklePitchDegrees = -5,
	leftHipPitchDegrees = -4,
	rightHipPitchDegrees = 4,
}))
local HEAVY_WINDUP = table.freeze(pose({
	rootForwardStuds = -0.24,
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
	rootForwardStuds = 0.48,
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
local DASH_PREP = table.freeze(pose({
	rootHeightStuds = -0.08,
	rootForwardStuds = -0.18,
	rootPitchDegrees = -8,
	rootYawDegrees = -8,
	waistPitchDegrees = -6,
	waistYawDegrees = -10,
	neckPitchDegrees = 5,
	neckYawDegrees = 8,
	leftShoulderPitchDegrees = -24,
	leftShoulderYawDegrees = -12,
	leftShoulderRollDegrees = -8,
	rightShoulderPitchDegrees = -18,
	rightShoulderYawDegrees = 18,
	rightShoulderRollDegrees = 10,
	leftElbowPitchDegrees = -74,
	rightElbowPitchDegrees = -82,
	leftHipPitchDegrees = -22,
	rightHipPitchDegrees = -28,
	leftKneePitchDegrees = -34,
	rightKneePitchDegrees = -42,
}))
local DASH_DRIVE = table.freeze(pose({
	rootHeightStuds = -0.14,
	rootForwardStuds = 0.16,
	rootPitchDegrees = 24,
	rootRollDegrees = -5,
	waistPitchDegrees = 15,
	waistRollDegrees = -5,
	neckPitchDegrees = -12,
	neckYawDegrees = -5,
	leftShoulderPitchDegrees = 38,
	leftShoulderYawDegrees = -18,
	leftShoulderRollDegrees = -16,
	rightShoulderPitchDegrees = 48,
	rightShoulderYawDegrees = 12,
	rightShoulderRollDegrees = 18,
	leftElbowPitchDegrees = -44,
	rightElbowPitchDegrees = -58,
	leftHipPitchDegrees = 34,
	rightHipPitchDegrees = -24,
	leftKneePitchDegrees = -12,
	rightKneePitchDegrees = -58,
	leftAnklePitchDegrees = 18,
	rightAnklePitchDegrees = -12,
}))
local DASH_RECOVER = table.freeze(pose({
	rootHeightStuds = -0.06,
	rootForwardStuds = 0.08,
	rootPitchDegrees = 8,
	waistPitchDegrees = 6,
	neckPitchDegrees = -4,
	leftShoulderPitchDegrees = 18,
	leftShoulderYawDegrees = -8,
	rightShoulderPitchDegrees = 21,
	rightShoulderYawDegrees = 8,
	leftHipPitchDegrees = 8,
	rightHipPitchDegrees = -8,
	leftKneePitchDegrees = -10,
	rightKneePitchDegrees = -8,
	leftAnklePitchDegrees = 8,
	rightAnklePitchDegrees = -4,
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
--
-- ⚠️ CADA DEGRAU TEM QUATRO QUADROS, não dois. A versão de dois quadros
-- (recolhe → bate) foi a que gerou "quando eu mando um ataque o personagem tá
-- só levantando o braço" em 14/08: com um quadro forte só, o corpo chegava
-- inteiro de uma vez e o que sobrava para o olho era a extremidade. Agora cada
-- golpe é RECOLHE → DIRIGE → IMPACTO → SUSTENTA: o quadro do meio é onde o
-- quadril já virou e o braço ainda não chegou, e é ele que faz o golpe ter
-- corpo. Quem interpola é `techniquePose`, o mesmo motor das três técnicas.
--
-- A outra metade da correção foi tirar o clipe de espada da cadeia: ele
-- balançava o braço DIREITO enquanto o jab soca com o ESQUERDO
-- (`CombatAnimations`, §4.6 de docs/14).

-- 1. Jab de mão de frente: rápido, pouco compromisso, recuperação imediata.
-- É o golpe que o jogador mais vê — todo ataque solto é o degrau 1 —, então
-- ele PRECISA ler como corpo inteiro mesmo sendo o menor da cadeia.
local JAB_COIL = table.freeze(pose({
	rootForwardStuds = -0.14,
	rootHeightStuds = -0.05,
	rootPitchDegrees = -4,
	rootYawDegrees = -14,
	rootRollDegrees = -3,
	waistYawDegrees = -14,
	neckYawDegrees = 7,
	leftShoulderPitchDegrees = -30,
	leftShoulderYawDegrees = -10,
	leftElbowPitchDegrees = -100,
	rightShoulderPitchDegrees = -44,
	rightShoulderYawDegrees = 18,
	rightElbowPitchDegrees = -96,
	leftHipPitchDegrees = -6,
	rightHipPitchDegrees = 6,
	leftKneePitchDegrees = -14,
	rightKneePitchDegrees = -8,
	leftAnklePitchDegrees = 6,
	rightAnklePitchDegrees = -4,
}))
local JAB_DRIVE = table.freeze(pose({
	rootForwardStuds = 0.16,
	rootHeightStuds = -0.06,
	rootPitchDegrees = 1,
	rootYawDegrees = 4,
	waistYawDegrees = 6,
	neckYawDegrees = 0,
	leftShoulderPitchDegrees = -62,
	leftShoulderYawDegrees = -8,
	leftElbowPitchDegrees = -46,
	rightShoulderPitchDegrees = -48,
	rightShoulderYawDegrees = 19,
	rightElbowPitchDegrees = -100,
	leftHipPitchDegrees = 2,
	rightHipPitchDegrees = -2,
	leftKneePitchDegrees = -10,
	rightKneePitchDegrees = -12,
	rightAnklePitchDegrees = -12,
}))
local JAB_STRIKE = table.freeze(pose({
	rootForwardStuds = 0.32,
	rootHeightStuds = -0.04,
	rootPitchDegrees = 6,
	rootYawDegrees = 20,
	rootRollDegrees = 3,
	waistPitchDegrees = 3,
	waistYawDegrees = 26,
	neckYawDegrees = -9,
	leftShoulderPitchDegrees = -92,
	leftShoulderYawDegrees = -4,
	leftElbowPitchDegrees = -4,
	leftWristPitchDegrees = -24,
	rightShoulderPitchDegrees = -52,
	rightShoulderYawDegrees = 20,
	rightElbowPitchDegrees = -104,
	leftHipPitchDegrees = 8,
	rightHipPitchDegrees = -8,
	leftKneePitchDegrees = -8,
	rightKneePitchDegrees = -16,
	leftAnklePitchDegrees = -6,
	rightAnklePitchDegrees = -18,
}))

-- 2. Direto de mão de trás: o quadril entrega o golpe, não o braço.
local CROSS_COIL = table.freeze(pose({
	rootForwardStuds = -0.2,
	rootHeightStuds = -0.07,
	rootPitchDegrees = -5,
	rootYawDegrees = -24,
	rootRollDegrees = -5,
	waistYawDegrees = -28,
	neckYawDegrees = 12,
	leftShoulderPitchDegrees = -50,
	leftShoulderYawDegrees = -14,
	leftElbowPitchDegrees = -86,
	rightShoulderPitchDegrees = 18,
	rightShoulderYawDegrees = 24,
	rightElbowPitchDegrees = -108,
	leftHipPitchDegrees = -8,
	rightHipPitchDegrees = 8,
	leftKneePitchDegrees = -12,
	rightKneePitchDegrees = -22,
	leftAnklePitchDegrees = 8,
	rightAnklePitchDegrees = 14,
}))
local CROSS_DRIVE = table.freeze(pose({
	rootForwardStuds = 0.2,
	rootHeightStuds = -0.08,
	rootPitchDegrees = 2,
	rootYawDegrees = 2,
	waistYawDegrees = 6,
	neckYawDegrees = 2,
	leftShoulderPitchDegrees = -44,
	leftShoulderYawDegrees = -16,
	leftElbowPitchDegrees = -82,
	rightShoulderPitchDegrees = -40,
	rightShoulderYawDegrees = 6,
	rightElbowPitchDegrees = -60,
	leftHipPitchDegrees = 0,
	rightHipPitchDegrees = 0,
	leftKneePitchDegrees = -12,
	rightKneePitchDegrees = -14,
	rightAnklePitchDegrees = -6,
}))
local CROSS_STRIKE = table.freeze(pose({
	rootForwardStuds = 0.42,
	rootHeightStuds = -0.05,
	rootPitchDegrees = 10,
	rootYawDegrees = 36,
	rootRollDegrees = 6,
	waistPitchDegrees = 6,
	waistYawDegrees = 42,
	neckYawDegrees = -16,
	leftShoulderPitchDegrees = -34,
	leftShoulderYawDegrees = -18,
	leftElbowPitchDegrees = -78,
	rightShoulderPitchDegrees = -100,
	rightShoulderYawDegrees = -12,
	rightShoulderRollDegrees = -10,
	rightElbowPitchDegrees = -4,
	rightWristPitchDegrees = -24,
	leftHipPitchDegrees = 10,
	rightHipPitchDegrees = -12,
	leftKneePitchDegrees = -12,
	rightKneePitchDegrees = -6,
	leftAnklePitchDegrees = -8,
	rightAnklePitchDegrees = -26,
}))

-- 3. Chute circular: perna encaixa dobrada e estende; tronco contrabalança
-- para o lado oposto, senão o rig parece flutuar.
local KICK_CHAMBER = table.freeze(pose({
	rootForwardStuds = -0.22,
	rootHeightStuds = -0.12,
	rootPitchDegrees = -6,
	rootYawDegrees = -24,
	rootRollDegrees = -8,
	waistYawDegrees = -18,
	waistRollDegrees = -7,
	neckYawDegrees = 13,
	leftShoulderPitchDegrees = 28,
	leftShoulderYawDegrees = -22,
	leftElbowPitchDegrees = -68,
	rightShoulderPitchDegrees = -30,
	rightShoulderYawDegrees = 16,
	rightElbowPitchDegrees = -86,
	rightHipPitchDegrees = -46,
	rightHipYawDegrees = 14,
	rightKneePitchDegrees = -112,
	leftKneePitchDegrees = -18,
	leftAnklePitchDegrees = 10,
	rightAnklePitchDegrees = 18,
}))
local KICK_EXTEND = table.freeze(pose({
	rootForwardStuds = 0.12,
	rootHeightStuds = -0.10,
	rootPitchDegrees = -1,
	rootYawDegrees = 12,
	rootRollDegrees = 4,
	waistYawDegrees = 10,
	waistRollDegrees = 3,
	neckYawDegrees = -6,
	leftShoulderPitchDegrees = 38,
	leftShoulderYawDegrees = -30,
	leftElbowPitchDegrees = -46,
	rightShoulderPitchDegrees = -26,
	rightShoulderYawDegrees = 22,
	rightElbowPitchDegrees = -70,
	rightHipPitchDegrees = -70,
	rightHipYawDegrees = 24,
	rightKneePitchDegrees = -52,
	leftKneePitchDegrees = -14,
	leftAnklePitchDegrees = 4,
	rightAnklePitchDegrees = -8,
}))
local KICK_STRIKE = table.freeze(pose({
	rootForwardStuds = 0.26,
	rootHeightStuds = -0.07,
	rootPitchDegrees = 4,
	rootYawDegrees = 36,
	rootRollDegrees = 16,
	waistYawDegrees = 30,
	waistRollDegrees = 13,
	neckYawDegrees = -18,
	leftShoulderPitchDegrees = 48,
	leftShoulderYawDegrees = -36,
	leftShoulderRollDegrees = -24,
	leftElbowPitchDegrees = -28,
	rightShoulderPitchDegrees = -22,
	rightShoulderYawDegrees = 28,
	rightElbowPitchDegrees = -58,
	rightHipPitchDegrees = -84,
	rightHipYawDegrees = 32,
	rightKneePitchDegrees = -14,
	rightAnklePitchDegrees = -22,
	leftHipPitchDegrees = 12,
	leftKneePitchDegrees = -12,
	leftAnklePitchDegrees = 12,
}))

-- 4. Finalizador giratório: maior amplitude, maior recuperação — é o golpe
-- que o oponente pune se errar.
local SPIN_LOAD = table.freeze(pose({
	rootForwardStuds = -0.26,
	rootHeightStuds = -0.16,
	rootPitchDegrees = -9,
	rootYawDegrees = -50,
	rootRollDegrees = -9,
	waistYawDegrees = -34,
	waistRollDegrees = -9,
	neckYawDegrees = 22,
	leftShoulderPitchDegrees = -56,
	leftShoulderYawDegrees = -26,
	leftElbowPitchDegrees = -112,
	rightShoulderPitchDegrees = -52,
	rightShoulderYawDegrees = 26,
	rightElbowPitchDegrees = -110,
	leftHipPitchDegrees = -22,
	leftKneePitchDegrees = -46,
	rightKneePitchDegrees = -26,
	leftAnklePitchDegrees = 14,
	rightAnklePitchDegrees = 10,
}))
local SPIN_SWEEP = table.freeze(pose({
	rootForwardStuds = 0.14,
	rootHeightStuds = -0.14,
	rootPitchDegrees = 2,
	rootYawDegrees = 10,
	rootRollDegrees = -6,
	waistYawDegrees = 6,
	waistRollDegrees = -5,
	neckYawDegrees = 4,
	leftShoulderPitchDegrees = -44,
	leftShoulderYawDegrees = -34,
	leftElbowPitchDegrees = -80,
	rightShoulderPitchDegrees = -10,
	rightShoulderYawDegrees = 30,
	rightElbowPitchDegrees = -76,
	leftHipPitchDegrees = -60,
	leftHipYawDegrees = -10,
	leftKneePitchDegrees = -30,
	rightKneePitchDegrees = -30,
	leftAnklePitchDegrees = 6,
	rightAnklePitchDegrees = 14,
}))
local SPIN_STRIKE = table.freeze(pose({
	rootForwardStuds = 0.38,
	rootHeightStuds = -0.11,
	rootPitchDegrees = 13,
	rootYawDegrees = 84,
	rootRollDegrees = -13,
	waistYawDegrees = 48,
	waistRollDegrees = -11,
	neckYawDegrees = -24,
	leftShoulderPitchDegrees = -28,
	leftShoulderYawDegrees = -44,
	leftElbowPitchDegrees = -46,
	rightShoulderPitchDegrees = 38,
	rightShoulderYawDegrees = 32,
	rightElbowPitchDegrees = -40,
	leftHipPitchDegrees = -92,
	leftHipYawDegrees = -20,
	leftKneePitchDegrees = -12,
	leftAnklePitchDegrees = -18,
	rightHipPitchDegrees = 14,
	rightKneePitchDegrees = -28,
	rightAnklePitchDegrees = 10,
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
--
-- Recalibrado em 17/08 para leitura de soco real. Os tempos anteriores
-- (jab 0.065/0.115/0.155/0.240) vinham de uma cadeia rápida demais para o olho:
-- a antecipação durava ~4 quadros a 60 fps, então o braço aparecia já estendido
-- e o golpe lia como teleporte da extremidade, sem carga.
--
-- O que mudou, e por quê:
--  · **antecipação ~40% maior** — é ela que mostra o corpo carregando o golpe;
--    sem carga visível não existe leitura de "vem força aí";
--  · **impacto continua rápido depois da carga** — a velocidade do trecho
--    antecipação→impacto é o que lê como potência, e ela foi preservada;
--  · **pausa e recuperação maiores** — o peso vem do que acontece DEPOIS do
--    contato; cortar a recuperação é o que fazia o golpe "atravessar" o alvo.
--
-- Teto: a duração de cada degrau fica abaixo de LIGHT_WINDOW (1,00 s), senão o
-- jogador precisaria interromper a própria animação para encadear.
-- 17/08: ~1,5× mais lento que a cadeia de 330–620 ms — o jab lê carga.
local LIGHT_CHAIN: { { number } } = {
	{ 0.135, 0.248, 0.323, 0.495 },
	{ 0.150, 0.315, 0.405, 0.600 },
	{ 0.218, 0.435, 0.548, 0.750 },
	{ 0.263, 0.525, 0.675, 0.930 },
}
-- Quadro do meio de cada degrau: o instante em que o quadril já virou e a
-- extremidade ainda está a caminho. É ele que dá corpo ao golpe — sem esse
-- quadro o rig chega inteiro de uma vez e sobra só a extremidade para o olho.
-- Fica entre a antecipação e o impacto, mais perto do impacto.
local DRIVE_FRACTION = 0.6

local function driveAt(timing: { number }): number
	return timing[1] + (timing[2] - timing[1]) * DRIVE_FRACTION
end

-- Trilha de quatro quadros por degrau: NEUTRO → recolhe → dirige → impacto,
-- e a recuperação elástica assume no fim da pausa. Mesmo motor das técnicas
-- (`techniquePose`), então o "peso atrasado" e o follow-through valem aqui.
local LIGHT_CHAIN_POSES: { { PoseSample } } = {
	{ JAB_COIL, JAB_DRIVE, JAB_STRIKE },
	{ CROSS_COIL, CROSS_DRIVE, CROSS_STRIKE },
	{ KICK_CHAMBER, KICK_EXTEND, KICK_STRIKE },
	{ SPIN_LOAD, SPIN_SWEEP, SPIN_STRIKE },
}

-- A janela de encadeamento espelha LIGHT_WINDOW do CombatService. Divergir aqui
-- só desalinha a apresentação: quem decide o degrau real continua o servidor.
local LIGHT_CHAIN_WINDOW_SECONDS = 1.00
PlayerCombatAnimator.LightChainWindowSeconds = LIGHT_CHAIN_WINDOW_SECONDS
PlayerCombatAnimator.LightChainLength = #LIGHT_CHAIN

local function chainTiming(step: number): { number }
	return LIGHT_CHAIN[math.clamp(math.floor(step), 1, #LIGHT_CHAIN)]
end

function PlayerCombatAnimator.lightChainDuration(step: number): number
	return chainTiming(step)[4]
end

-- Instante do impacto do degrau. Público porque é o quadro que interessa
-- inspecionar: é onde a silhueta do golpe existe.
function PlayerCombatAnimator.lightChainImpact(step: number): number
	return chainTiming(step)[2]
end

-- Fim da antecipação do degrau — o instante em que o corpo para de carregar e
-- a extremidade acelera. É quando o corte de ar soa. Público para que teste e
-- calibração leiam a MESMA fonte em vez de repetir o número à mão.
function PlayerCombatAnimator.lightChainAnticipation(step: number): number
	return chainTiming(step)[1]
end

-- Trilhas montadas uma vez no load: `chainPose` roda todo quadro e não pode
-- alocar uma tabela de quadros por chamada.
local LIGHT_CHAIN_KEYS: { { PoseKey } } = {}
for index, timing in LIGHT_CHAIN do
	local poses = LIGHT_CHAIN_POSES[index]
	LIGHT_CHAIN_KEYS[index] = {
		{ at = 0, pose = NEUTRAL },
		{ at = timing[1], pose = poses[1], ease = easeInCubic },
		{ at = driveAt(timing), pose = poses[2], ease = easeOutCubic },
		{ at = timing[2], pose = poses[3], ease = easeOutCubic },
		-- Pausa de impacto: a pose fica cravada até o fim da janela. É o que dá
		-- peso; sem ela o golpe atravessa o alvo e não "bate".
		{ at = timing[3], pose = poses[3] },
	}
end

local function chainPose(step: number, elapsed: number): PoseSample
	local timing = chainTiming(step)
	local index = math.clamp(math.floor(step), 1, #LIGHT_CHAIN)
	return techniquePose(LIGHT_CHAIN_KEYS[index], elapsed, timing[3], timing[4])
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
		return attackPose(
			safeElapsed,
			PlayerCombatAnimator.HeavyBeats.windupEnd,
			PlayerCombatAnimator.HeavyBeats.strikeEnd,
			DURATIONS.BasicHeavy,
			HEAVY_WINDUP,
			HEAVY_STRIKE
		)
	elseif action == "Dash" then
		if safeElapsed <= 0.06 then
			return blend(NEUTRAL, DASH_PREP, smooth(safeElapsed / 0.06))
		elseif safeElapsed <= 0.13 then
			return blend(DASH_PREP, DASH_DRIVE, smooth((safeElapsed - 0.06) / 0.07))
		elseif safeElapsed <= 0.22 then
			return blend(DASH_DRIVE, DASH_RECOVER, smooth((safeElapsed - 0.13) / 0.09))
		end
		return blend(DASH_RECOVER, NEUTRAL, smooth((safeElapsed - 0.22) / (DURATIONS.Dash - 0.22)))
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
	leftAnkle = { "leftankle" },
	rightAnkle = { "rightankle" },
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

-- Papel que uma junta recém-vista deve ocupar, ou nil se ela não serve (classe
-- errada, nome sem papel, ou papel já preenchido — primeira vista vence).
--
-- É a mesma regra na varredura inicial e na adoção tardia. Existe como função
-- pura porque a adoção tardia é o conserto de um bug que só aparece em runtime:
-- sem ela, um personagem que chega antes do rig ficava sem pose para sempre.
-- O teste Lune trava a regra sem precisar de DataModel.
function PlayerCombatAnimator.jointSlotFor(joints: { [string]: any }, className: string, jointName: string): string?
	if not PlayerCombatAnimator.isPoseJointClass(className) then
		return nil
	end
	local role = PlayerCombatAnimator.jointRole(jointName)
	if not role or joints[role] then
		return nil
	end
	return role
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

local function adoptJoint(animator: Animator, descendant: Instance): ()
	local role = PlayerCombatAnimator.jointSlotFor(animator.joints, descendant.ClassName, descendant.Name)
	if not role then
		return
	end
	local joint = descendant :: PoseJoint
	animator.joints[role] = {
		joint = joint,
		baseTransform = jointTransform(joint),
		lastApplied = nil,
	}
end

local function attachCharacter(animator: Animator, character: Model?): ()
	if animator.character == character then
		return
	end
	restoreJoints(animator)
	if animator.descendantConnection then
		animator.descendantConnection:Disconnect()
		animator.descendantConnection = nil
	end
	animator.character = character
	if not character then
		return
	end

	-- Primeira junta encontrada por papel vence. O rig atual traz só
	-- AnimationConstraint, o clássico só Motor6D; aceitar as duas é o que faz o
	-- overlay existir nos dois mundos, sem ramo por versão de avatar.
	for _, descendant in character:GetDescendants() do
		adoptJoint(animator, descendant)
	end

	-- O rig NÃO está montado quando o personagem chega. Medido no Studio em
	-- 2026-08-14, no personagem real: no instante do CharacterAdded o modelo tem
	-- 0 AnimationConstraint, 0 Motor6D e nem RightHand; meio segundo depois as 15
	-- juntas estão lá. Varrer uma única vez capturava zero junta, e como o anexo
	-- sai cedo quando o personagem é o mesmo, o overlay inteiro nascia morto — o
	-- combate ficava literalmente sem animação, que foi o defeito relatado.
	-- Adotar o que chega depois cobre a corrida sem polling e sem prender o
	-- bootstrap esperando o rig.
	animator.descendantConnection = character.DescendantAdded:Connect(function(descendant: Instance)
		adoptJoint(animator, descendant)
	end)
end

local function overlay(
	pitchDegrees: number,
	yawDegrees: number,
	rollDegrees: number,
	heightStuds: number?,
	forwardStuds: number?
): CFrame
	-- Frente do personagem é −Z, então o passo entra com sinal invertido.
	return CFrame.new(0, heightStuds or 0, -(forwardStuds or 0))
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
		overlay(
			sample.rootPitchDegrees,
			sample.rootYawDegrees,
			sample.rootRollDegrees,
			sample.rootHeightStuds,
			sample.rootForwardStuds
		)
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
	applyJoint(animator, "leftAnkle", overlay(sample.leftAnklePitchDegrees, 0, 0))
	applyJoint(animator, "rightAnkle", overlay(sample.rightAnklePitchDegrees, 0, 0))
end

function PlayerCombatAnimator.new(deps: {
	player: any,
	runService: any,
	now: (() -> number)?,
	emitCue: ((string) -> ())?,
	onPredictedHit: ((string) -> ())?,
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
		predictedHitAbilityId = nil,
		predictedHitAt = 0,
		onPredictedHit = deps.onPredictedHit,
		character = nil,
		joints = {},
		preSimulationConnection = nil,
		characterAddedConnection = nil,
		descendantConnection = nil,
	}
end

-- Deixa sonora por ação e o atraso até o corte de ar — que soa quando a
-- antecipação termina e o membro acelera, não no instante do input.
--
-- Os ids espelham src/shared/Data/CombatAudio.luau de propósito: o animador
-- não requer o catálogo (é apresentação pura e precisa carregar em teste sem
-- DataModel). Um teste garante que nenhum id aqui saia do catálogo.
local ACTION_CUE: { [string]: { id: string, delaySeconds: number } } = {
	BasicHeavy = { id = "swing_heavy", delaySeconds = PlayerCombatAnimator.HeavyBeats.windupEnd },
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
	PlayerCombatAnimator.clearPredictedHit(animator)
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

function PlayerCombatAnimator.armPredictedHit(animator: Animator, abilityId: string, delaySeconds: number): ()
	if type(abilityId) ~= "string" or abilityId == "" then
		return
	end
	animator.predictedHitAbilityId = abilityId
	animator.predictedHitAt = animator.now() + math.max(0, delaySeconds)
end

function PlayerCombatAnimator.clearPredictedHit(animator: Animator): ()
	animator.predictedHitAbilityId = nil
	animator.predictedHitAt = 0
end

function PlayerCombatAnimator.flushPredictedHit(animator: Animator, now: number): string?
	local abilityId = animator.predictedHitAbilityId
	if not abilityId or now < animator.predictedHitAt then
		return nil
	end
	animator.predictedHitAbilityId = nil
	local emit = animator.onPredictedHit
	if emit then
		emit(abilityId)
	end
	return abilityId
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
	PlayerCombatAnimator.flushPredictedHit(animator, animator.now())

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

	-- Rede de segurança: se a tabela de juntas está vazia com personagem vivo, o
	-- overlay inteiro está morto e NENHUMA pose de combate aparece — guarda,
	-- cadeia leve e técnicas, todas. É o defeito de corrida do rig (docs/14 §4.7)
	-- reaparecendo por um caminho que `attachCharacter` não cobre: o anexo sai
	-- cedo quando o personagem é o mesmo objeto, então uma varredura que pegou
	-- zero junta nunca é refeita e o `DescendantAdded` já passou. Revarrer aqui
	-- custa uma iteração só no estado quebrado e devolve a animação sozinho.
	if next(animator.joints) == nil then
		for _, descendant in animator.character:GetDescendants() do
			adoptJoint(animator, descendant)
		end
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
	if animator.descendantConnection then
		animator.descendantConnection:Disconnect()
		animator.descendantConnection = nil
	end
	restoreJoints(animator)
	animator.character = nil
	animator.action = nil
	animator.guarding = false
end

return PlayerCombatAnimator

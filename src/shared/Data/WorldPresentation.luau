--!strict
-- Receitas puras da apresentação F0. O módulo não cria Instances: mantém
-- proporções, paleta e amplitudes procedurais testáveis fora do Studio.
-- Os modelos continuam sendo greybox original em Parts até o Gate P1.

export type Rgb = { number }

export type ActorRecipe = {
	id: string,
	shape: "humanoid" | "shard",
	scale: number,
	bodyRgb: Rgb,
	accentRgb: Rgb,
	coreRgb: Rgb,
	skinNameKey: string,
	auraRgb: Rgb,
	auraScale: number,
	idleBobStuds: number,
	idleCyclesPerSecond: number,
	strideDegrees: number,
	telegraphLeanDegrees: number,
	attackLeanDegrees: number,
	deathTiltDegrees: number,
}

export type WorldStyle = {
	pathWidth: number,
	spawnPlazaRadius: number,
	craterSegments: number,
	boundaryPostCount: number,
	landmarkShardCount: number,
}

-- ── Skin sobre rig R15 (bots do spawn) ──────────────────────────────────────
-- Os dois bots do spawn deixaram de ser caixas com uma esfera na cabeça: o
-- corpo agora é o rig R15 oficial do Roblox (`Players:CreateHumanoidModel-
-- FromDescription`), montado pelo WorldService, e o que está aqui é a ROUPA —
-- peças posicionadas no referencial de cada parte do rig.
--
-- Por que dado puro: o WorldService não é coberto por teste Lune (Instances).
-- Tamanho, encaixe e paleta são decisão e ficam aqui, validados por
-- `Presentation.validate()`. Materializar é o que sobra para o servidor.
--
-- ⚠️ NADA DE CAIXA. Primeira versão desta skin (14/08 manhã) era gear todo em
-- `Block`, e a reclamação seguinte foi "ainda tá muito quadrado" — com razão:
-- caixa sobre caixa não vira personagem por mais bem posicionada que esteja. A
-- regra agora é: volume grande é `Ball` (com tamanho não uniforme o Roblox
-- renderiza elipsoide, que é o que dá ombro, capuz, saia e saco), anel/faixa é
-- `Cylinder`, e ponta é `WedgePart`. `Block` só sobra para detalhe reto.
-- `Presentation.validateRigs` recusa uma receita com excesso de blocos.
--
-- Referencial: `offsetStuds` e `sizeStuds` estão em STUDS, no espaço da parte
-- hospedeira, com a FRENTE em −Z (é onde fica o rosto do R15).
--
-- ⚠️ As medidas abaixo valem para AS ESCALAS DECLARADAS EM `RIG_SCALES`. O
-- corpo não é mais o R15 padrão: `bodyTypeScale = 1` puxa a proporção para o
-- Rthro (tronco alongado, membro afilado) em vez do boneco cúbico clássico, e é
-- metade da resposta ao "muito quadrado". Mexeu em escala, mede tudo de novo.
-- Colhido no Studio em 2026-08-14:
--   Head 1,253×1,292×1,255 @ +2,029 · UpperTorso 1,783×1,910×1,077 @ +0,445
--   LowerTorso 1,857×0,440×1,077 @ −0,730 · UpperArm 0,981×1,416×1,069 @ ±1,382
--   LowerArm 0,981×1,274×1,069 · LowerLeg 0,920×1,591×0,966 @ −2,590
--   altura total 6,282 · topo da cabeça +2,675 · sola 3,607 abaixo da HRP
export type RigGear = {
	name: string,
	class: "Part" | "WedgePart",
	shape: "Block" | "Ball" | "Cylinder",
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string,
}

export type RigScales = {
	bodyType: number,
	proportion: number,
	head: number,
	width: number,
	height: number,
}

export type RigRecipe = {
	npcId: string,
	skinRgb: Rgb,
	bodyRgb: Rgb,
	legRgb: Rgb,
	bodyMaterial: string,
	legMaterial: string,
	-- Textura embutida do cliente (`rbxasset://`), não asset de catálogo: não
	-- depende de download, não pode ser moderada e existe em qualquer lugar.
	-- `nil` = sem decal (o boneco de treino usa olhos de botão em Parts).
	faceTexture: string?,
	scales: RigScales,
	gear: { RigGear },
}

local Actors: { [string]: ActorRecipe } = {
	npc_training_dummy = {
		id = "npc_training_dummy",
		shape = "humanoid",
		scale = 1,
		-- Saco de treino: couro escuro, alvo pálido no peito (Target neon).
		bodyRgb = { 52, 50, 46 },
		accentRgb = { 150, 120, 90 },
		coreRgb = { 226, 214, 183 },
		skinNameKey = "skin.training_sack",
		auraRgb = { 226, 78, 78 },
		auraScale = 0.8,
		idleBobStuds = 0.03,
		idleCyclesPerSecond = 0.55,
		strideDegrees = 0,
		telegraphLeanDegrees = 4,
		attackLeanDegrees = 8,
		deathTiltDegrees = 20,
	},
	npc_threshold_instructor = {
		id = "npc_threshold_instructor",
		shape = "humanoid",
		scale = 1.05,
		-- Instrutora do Limiar (quest giver): casaco umbral, cabelo longo,
		-- energia só nas bordas e rosto legível — silhueta feminina de anime,
		-- não guarda andrógino de armadura.
		bodyRgb = { 74, 70, 104 },
		accentRgb = { 118, 84, 158 },
		coreRgb = { 206, 196, 224 },
		skinNameKey = "skin.threshold_warden",
		auraRgb = { 138, 96, 196 },
		auraScale = 1.05,
		idleBobStuds = 0.05,
		idleCyclesPerSecond = 0.32,
		strideDegrees = 6,
		telegraphLeanDegrees = 5,
		attackLeanDegrees = 10,
		deathTiltDegrees = 35,
	},
	enemy_wandering_shard = {
		id = "enemy_wandering_shard",
		shape = "shard",
		scale = 0.9,
		-- Estilhaço errante: corpo mineral frio, núcleo e halo quase brancos.
		bodyRgb = { 64, 70, 78 },
		accentRgb = { 172, 176, 166 },
		coreRgb = { 242, 240, 226 },
		skinNameKey = "skin.cyan_rift_shard",
		auraRgb = { 104, 220, 238 },
		auraScale = 0.9,
		idleBobStuds = 0.32,
		idleCyclesPerSecond = 0.8,
		strideDegrees = 18,
		telegraphLeanDegrees = 16,
		attackLeanDegrees = 34,
		deathTiltDegrees = 78,
	},
	enemy_port_scrapper = {
		id = "enemy_port_scrapper",
		shape = "shard",
		scale = 0.84,
		bodyRgb = { 88, 72, 58 },
		accentRgb = { 176, 112, 64 },
		coreRgb = { 240, 200, 140 },
		skinNameKey = "skin.port_scrapper",
		auraRgb = { 196, 120, 72 },
		auraScale = 0.88,
		idleBobStuds = 0.16,
		idleCyclesPerSecond = 0.55,
		strideDegrees = 12,
		telegraphLeanDegrees = 12,
		attackLeanDegrees = 28,
		deathTiltDegrees = 68,
	},
	enemy_grove_wisp = {
		id = "enemy_grove_wisp",
		shape = "shard",
		scale = 0.72,
		bodyRgb = { 48, 88, 62 },
		accentRgb = { 140, 220, 170 },
		coreRgb = { 210, 255, 220 },
		skinNameKey = "skin.grove_wisp",
		auraRgb = { 120, 220, 180 },
		auraScale = 0.82,
		idleBobStuds = 0.42,
		idleCyclesPerSecond = 1.05,
		strideDegrees = 16,
		telegraphLeanDegrees = 14,
		attackLeanDegrees = 30,
		deathTiltDegrees = 70,
	},
	enemy_anchored_shard = {
		id = "enemy_anchored_shard",
		shape = "shard",
		scale = 1.65,
		-- Elite da cratera: mineral mais escuro com energia umbral nos cristais
		-- e núcleo quente — a coroa o distingue à distância.
		bodyRgb = { 44, 48, 56 },
		accentRgb = { 168, 120, 200 },
		coreRgb = { 246, 240, 230 },
		skinNameKey = "skin.void_crown_boss",
		auraRgb = { 255, 118, 92 },
		auraScale = 1.35,
		idleBobStuds = 0.18,
		idleCyclesPerSecond = 0.45,
		strideDegrees = 8,
		telegraphLeanDegrees = 22,
		attackLeanDegrees = 42,
		deathTiltDegrees = 82,
	},
}

-- ⚠️ ESCADA DE VALOR (17/08). A silhueta feminina da Instrutora existia desde
-- 54836f9 e não aparecia na tela: cabelo (luminância 30), saia (27) e casaco
-- (41) estavam a menos de 15 pontos um do outro, num cenário noturno escuro.
-- Volume modelado e pintado tudo da mesma cor colapsa numa mancha preta — só o
-- neon lia, e a leitura era "boneco escuro com listras rosa". Modelar sem
-- separar valor é trabalho que não chega ao jogador.
--
-- Agora os tons sobem em degraus de no mínimo `PALETTE_MIN_STEP`, travado por
-- `Presentation.validatePalette`. Cabelo claro contra casaco médio é o que dá a
-- leitura de anime; o neon umbral continua SÓ nas bordas (docs/28).
local HAIR: Rgb = { 186, 166, 226 }
local HAIR_DEEP: Rgb = { 138, 120, 180 }
local HAIR_SHEEN: Rgb = { 238, 230, 255 }
local UMBRAL: Rgb = { 138, 96, 196 }
local UMBRAL_CORE: Rgb = { 226, 214, 250 }
local UMBRAL_SOFT: Rgb = { 168, 132, 214 }
local COAT: Rgb = { 74, 70, 104 }
local COAT_DARK: Rgb = { 44, 42, 66 }
local COAT_LINING: Rgb = { 126, 88, 172 }
local SKIN_TONE: Rgb = { 232, 208, 198 }
local BURLAP: Rgb = { 186, 156, 108 }
local BURLAP_DARK: Rgb = { 148, 120, 80 }
local ROPE: Rgb = { 122, 96, 58 }
local STITCH: Rgb = { 44, 36, 30 }
local WOOD: Rgb = { 104, 74, 42 }
local TARGET_PALE: Rgb = { 226, 214, 183 }
local TARGET_RED: Rgb = { 226, 78, 78 }
local TARGET_CORE: Rgb = { 244, 238, 220 }

-- Escalas da HumanoidDescription. Ver o aviso do cabeçalho: as medidas do
-- gear do dummy valem para `RIG_SCALES`; a instrutora usa `INSTRUCTOR_SCALES`
-- (ombros um pouco mais estreitos, proporção um pouco mais alongada).
local RIG_SCALES: RigScales = {
	bodyType = 1,
	proportion = 0.5,
	head = 1.14,
	width = 0.92,
	height = 0.95,
}

-- Silhueta feminina sem sair do Rthro: bodyType alto continua obrigatório
-- (validateScales recusa o boneco cúbico). Width menor e height levemente
-- maior dão ombro fino + linha de perna sem reescalar a roupa à mão.
local INSTRUCTOR_SCALES: RigScales = {
	bodyType = 1,
	proportion = 0.58,
	head = 1.10,
	width = 0.86,
	height = 0.98,
}

local function makeGear(
	shape: string,
	class: "Part" | "WedgePart",
	name: string,
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string
): RigGear
	return {
		name = name,
		class = class,
		shape = shape :: any,
		host = host,
		sizeStuds = sizeStuds,
		offsetStuds = offsetStuds,
		rotationDegrees = rotationDegrees,
		rgb = rgb,
		material = material,
	}
end

-- Volume orgânico. Com tamanho não uniforme o Roblox renderiza um ELIPSOIDE —
-- é daqui que saem ombro, capuz, saia e saco de estopa sem cara de caixa.
local function blob(
	name: string,
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string
): RigGear
	return makeGear("Ball", "Part", name, host, sizeStuds, offsetStuds, rotationDegrees, rgb, material)
end

-- Anel/faixa. O eixo do Cylinder é X: `rotation z = 90` deixa o eixo em pé
-- (anel em volta do pescoço, do braço ou da cintura) e `rotation y = 90` vira
-- a face para a frente (disco do alvo no peito).
local function band(
	name: string,
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string
): RigGear
	return makeGear("Cylinder", "Part", name, host, sizeStuds, offsetStuds, rotationDegrees, rgb, material)
end

-- Ponta: mecha de cabelo, palha, aba de casaco.
local function spike(
	name: string,
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string
): RigGear
	return makeGear("Block", "WedgePart", name, host, sizeStuds, offsetStuds, rotationDegrees, rgb, material)
end

-- Instrutora do Limiar (quest giver). Silhueta feminina de anime em volumes
-- redondos: cabelo longo com franja e rabo, capuz aberto no rosto, casaco com
-- cintura marcada e saia em camadas, ombreiras leves (não pauldron de tank).
-- Energia umbral só nas BORDAS — neon em tudo apaga a leitura de personagem.
--
-- ⚠️ O rosto ocupa a face −Z da cabeça (plano em z = −0,628) e os olhos sobem
-- até y ≈ +0,31. Peça que avança na frente desse plano TEM de ficar acima dos
-- olhos, senão a instrutora volta a ser um vulto encapuzado sem cara.
-- `Presentation.gearClearsFace` trava isso. Rosto = textura embutida
-- `rbxasset://textures/face.png` (sem rbxassetid de catálogo).
local INSTRUCTOR_GEAR: { RigGear } = {
	-- ── Cabelo ────────────────────────────────────────────────────────────
	-- Volume de cima + nuca; laterais curtos enquadram a face; mechas longas e
	-- rabo descem pelo tronco (presos ao UpperTorso) para ler como cabelo de
	-- anime e não capacete curto.
	blob("HairBack", "Head", { 1.42, 1.36, 1.40 }, { 0, 0.22, 0.18 }, { 0, 0, 0 }, HAIR, "Fabric"),
	blob("HairTop", "Head", { 1.28, 0.92, 1.28 }, { 0, 0.66, 0.04 }, { 0, 0, 0 }, HAIR, "Fabric"),
	blob("HairCrown", "Head", { 0.96, 0.48, 0.96 }, { 0, 0.88, 0.06 }, { 0, 0, 0 }, HAIR_DEEP, "Fabric"),
	blob("HairSideL", "Head", { 0.42, 1.05, 0.88 }, { -0.66, 0.00, 0.18 }, { 0, 0, -10 }, HAIR, "Fabric"),
	blob("HairSideR", "Head", { 0.42, 1.05, 0.88 }, { 0.66, 0.00, 0.18 }, { 0, 0, 10 }, HAIR, "Fabric"),
	-- Franja em mechas assimétricas (alturas/ângulos diferentes): cinco iguais
	-- lê como capacete; a mecha central fica um pouco mais alta.
	spike("Fringe", "Head", { 0.28, 0.40, 0.24 }, { -0.46, 0.60, -0.46 }, { -24, -24, -8 }, HAIR, "Fabric"),
	spike("Fringe", "Head", { 0.24, 0.36, 0.22 }, { -0.24, 0.62, -0.50 }, { -20, -12, 4 }, HAIR, "Fabric"),
	spike("Fringe", "Head", { 0.28, 0.42, 0.24 }, { 0.00, 0.64, -0.52 }, { -28, 2, -2 }, HAIR, "Fabric"),
	spike("Fringe", "Head", { 0.24, 0.36, 0.22 }, { 0.26, 0.62, -0.50 }, { -20, 14, 6 }, HAIR, "Fabric"),
	spike("Fringe", "Head", { 0.28, 0.40, 0.24 }, { 0.46, 0.60, -0.46 }, { -24, 26, 8 }, HAIR, "Fabric"),
	-- Mechas laterais longas (atrás do plano do rosto) + rabo de cavalo.
	blob("HairLockL", "Head", { 0.34, 1.20, 0.40 }, { -0.58, -0.42, 0.28 }, { 0, 0, -6 }, HAIR_DEEP, "Fabric"),
	blob("HairLockR", "Head", { 0.34, 1.20, 0.40 }, { 0.58, -0.42, 0.28 }, { 0, 0, 6 }, HAIR_DEEP, "Fabric"),
	blob("HairTail", "UpperTorso", { 0.52, 1.70, 0.48 }, { 0.08, 0.10, 0.72 }, { 12, 0, 4 }, HAIR, "Fabric"),
	blob("HairTailTip", "UpperTorso", { 0.40, 0.90, 0.38 }, { 0.10, -0.70, 0.86 }, { 18, 0, 4 }, HAIR_DEEP, "Fabric"),
	blob("HairSheen", "Head", { 0.70, 0.28, 0.50 }, { -0.18, 0.72, 0.20 }, { 0, 0, -12 }, HAIR_SHEEN, "Fabric"),
	band("HairTie", "Head", { 0.14, 0.48, 0.48 }, { 0.04, 0.28, 0.72 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	blob("HairOrnament", "Head", { 0.28, 0.28, 0.18 }, { -0.42, 0.56, -0.10 }, { 0, 0, 0 }, UMBRAL_SOFT, "Neon"),
	blob("HairOrnamentCore", "Head", { 0.12, 0.12, 0.10 }, { -0.42, 0.56, -0.16 }, { 0, 0, 0 }, UMBRAL_CORE, "Neon"),

	-- ── Capuz (aberto, emoldura sem tapar o rosto) ─────────────────────────
	blob("HoodShell", "Head", { 1.82, 1.58, 1.70 }, { 0, 0.22, 0.46 }, { 0, 0, 0 }, COAT, "Leather"),
	blob("HoodCheek", "Head", { 0.40, 1.22, 1.18 }, { -0.74, 0.08, 0.22 }, { 0, 0, 0 }, COAT, "Leather"),
	blob("HoodCheek", "Head", { 0.40, 1.22, 1.18 }, { 0.74, 0.08, 0.22 }, { 0, 0, 0 }, COAT, "Leather"),
	blob("HoodBrow", "Head", { 1.76, 0.18, 1.58 }, { 0, 0.74, 0.34 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	-- Brincos: laterais da cabeça, atrás o suficiente para não invadir o rosto.
	blob("EarringL", "Head", { 0.14, 0.28, 0.14 }, { -0.72, -0.18, 0.08 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	blob("EarringR", "Head", { 0.14, 0.28, 0.14 }, { 0.72, -0.18, 0.08 }, { 0, 0, 0 }, UMBRAL, "Neon"),

	-- ── Casaco / torso ─────────────────────────────────────────────────────
	-- Peito arredondado + cintura marcada (faixa + painel) + saia em camadas.
	blob("CoatChest", "UpperTorso", { 1.78, 1.92, 1.14 }, { 0, 0.04, 0.02 }, { 0, 0, 0 }, COAT, "Fabric"),
	blob("BustShape", "UpperTorso", { 1.48, 0.72, 0.92 }, { 0, 0.28, -0.12 }, { 0, 0, 0 }, COAT, "Fabric"),
	band("Collar", "UpperTorso", { 0.42, 1.18, 1.18 }, { 0, 0.88, 0.02 }, { 0, 0, 90 }, COAT, "Fabric"),
	band("CollarGlow", "UpperTorso", { 0.10, 1.24, 1.24 }, { 0, 1.06, 0.02 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	blob("Sash", "UpperTorso", { 0.32, 1.65, 1.10 }, { -0.28, 0.02, -0.04 }, { 0, 0, -16 }, COAT_LINING, "Fabric"),
	blob("WaistPanel", "LowerTorso", { 1.48, 1.00, 1.08 }, { 0, -0.14, 0.04 }, { 0, 0, 0 }, COAT, "Fabric"),
	band("WaistCinch", "LowerTorso", { 0.22, 1.42, 1.08 }, { 0, 0.10, 0.02 }, { 0, 0, 90 }, COAT_DARK, "Leather"),
	blob("CapePanelL", "UpperTorso", { 0.58, 1.80, 0.36 }, { -0.68, -0.70, 0.38 }, { 10, 0, -10 }, COAT, "Fabric"),
	blob("CapePanelR", "UpperTorso", { 0.58, 1.80, 0.36 }, { 0.68, -0.70, 0.38 }, { 10, 0, 10 }, COAT, "Fabric"),
	blob(
		"CapeLiningL",
		"UpperTorso",
		{ 0.40, 1.40, 0.22 },
		{ -0.62, -0.55, 0.28 },
		{ 8, 0, -8 },
		COAT_LINING,
		"Fabric"
	),
	blob("CapeLiningR", "UpperTorso", { 0.40, 1.40, 0.22 }, { 0.62, -0.55, 0.28 }, { 8, 0, 8 }, COAT_LINING, "Fabric"),
	blob("Emblem", "UpperTorso", { 0.34, 0.42, 0.18 }, { 0, 0.22, -0.58 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	blob("EmblemCore", "UpperTorso", { 0.14, 0.16, 0.12 }, { 0, 0.22, -0.62 }, { 0, 0, 0 }, UMBRAL_CORE, "Neon"),
	band("Belt", "UpperTorso", { 0.30, 1.42, 1.12 }, { 0, -0.82, 0.02 }, { 0, 0, 90 }, COAT_DARK, "Leather"),
	blob("Buckle", "UpperTorso", { 0.32, 0.36, 0.20 }, { 0, -0.82, -0.56 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	-- Saia em duas camadas: volume principal + overskirt mais largo/curto.
	blob("CoatSkirt", "UpperTorso", { 1.72, 1.55, 1.28 }, { 0, -1.58, 0.04 }, { 0, 0, 0 }, COAT, "Fabric"),
	blob("OverSkirt", "UpperTorso", { 1.95, 0.95, 1.42 }, { 0, -1.20, 0.06 }, { 0, 0, 0 }, COAT_DARK, "Fabric"),
	band("Hem", "UpperTorso", { 0.12, 1.90, 1.42 }, { 0, -2.28, 0.04 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	spike("CoatTail", "UpperTorso", { 0.70, 2.05, 0.40 }, { -0.36, -2.18, 0.50 }, { 12, 0, -6 }, COAT, "Fabric"),
	spike("CoatTail", "UpperTorso", { 0.70, 2.05, 0.40 }, { 0.36, -2.18, 0.50 }, { 12, 0, 6 }, COAT, "Fabric"),

	-- Cachecol leve no ombro (movimento sem tapar o peito).
	blob("ScarfKnot", "UpperTorso", { 0.40, 0.38, 0.32 }, { -0.18, 0.82, 0.28 }, { 0, 0, 0 }, UMBRAL_SOFT, "Neon"),
	spike(
		"ScarfTail",
		"UpperTorso",
		{ 0.32, 1.35, 0.26 },
		{ -0.24, 0.05, 0.50 },
		{ 16, 0, -12 },
		COAT_LINING,
		"Fabric"
	),
	blob("HipPouch", "LowerTorso", { 0.48, 0.52, 0.40 }, { 0.58, -0.18, 0.08 }, { 0, 0, -10 }, COAT_DARK, "Leather"),

	-- ── Braços: ombreira leve (não tanque) + punho + luva ───────────────────
	blob("Pauldron", "LeftUpperArm", { 1.10, 0.78, 1.12 }, { 0, 0.40, 0 }, { 0, 0, 6 }, COAT, "Fabric"),
	blob("Pauldron", "RightUpperArm", { 1.10, 0.78, 1.12 }, { 0, 0.40, 0 }, { 0, 0, -6 }, COAT, "Fabric"),
	band("PauldronGlow", "LeftUpperArm", { 0.08, 1.12, 1.14 }, { 0, 0.12, 0 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	band("PauldronGlow", "RightUpperArm", { 0.08, 1.12, 1.14 }, { 0, 0.12, 0 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	blob("Sleeve", "LeftUpperArm", { 0.95, 1.20, 0.95 }, { 0, -0.10, 0 }, { 0, 0, 0 }, COAT, "Fabric"),
	blob("Sleeve", "RightUpperArm", { 0.95, 1.20, 0.95 }, { 0, -0.10, 0 }, { 0, 0, 0 }, COAT, "Fabric"),
	band("Cuff", "LeftLowerArm", { 0.24, 1.02, 1.08 }, { 0, -0.48, 0 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	band("Cuff", "RightLowerArm", { 0.24, 1.02, 1.08 }, { 0, -0.48, 0 }, { 0, 0, 90 }, UMBRAL, "Neon"),
	blob("Glove", "LeftHand", { 0.98, 0.44, 1.16 }, { 0, -0.02, 0 }, { 0, 0, 0 }, COAT_DARK, "Leather"),
	blob("Glove", "RightHand", { 0.98, 0.44, 1.16 }, { 0, -0.02, 0 }, { 0, 0, 0 }, COAT_DARK, "Leather"),

	-- ── Pernas / botas ─────────────────────────────────────────────────────
	band("KneeGuard", "LeftLowerLeg", { 0.18, 1.06, 1.12 }, { 0, 0.40, 0 }, { 0, 0, 90 }, COAT, "Leather"),
	band("KneeGuard", "RightLowerLeg", { 0.18, 1.06, 1.12 }, { 0, 0.40, 0 }, { 0, 0, 90 }, COAT, "Leather"),
	blob("Boot", "LeftLowerLeg", { 1.00, 1.05, 1.14 }, { 0, -0.42, -0.02 }, { 0, 0, 0 }, COAT_DARK, "Leather"),
	blob("Boot", "RightLowerLeg", { 1.00, 1.05, 1.14 }, { 0, -0.42, -0.02 }, { 0, 0, 0 }, COAT_DARK, "Leather"),
	blob("BootCuff", "LeftFoot", { 1.00, 0.36, 1.10 }, { 0, 0.10, 0.02 }, { 0, 0, 0 }, COAT, "Leather"),
	blob("BootCuff", "RightFoot", { 1.00, 0.36, 1.10 }, { 0, 0.10, 0.02 }, { 0, 0, 0 }, COAT, "Leather"),
}

-- Boneco de treino: saco de estopa amarrado, palha saindo pelas costuras,
-- olhos de botão, alvo no peito e poste de madeira atrás. Cabeça e tronco viram
-- sacos por elipsoides — boneco de pancada não tem ombro reto. Nada de neon
-- além do anel vermelho do alvo: quem brilha aqui é onde se deve bater.
local DUMMY_GEAR: { RigGear } = {
	blob("SackCrown", "Head", { 1.40, 0.90, 1.40 }, { 0, 0.50, 0.02 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	band("TieBand", "Head", { 0.24, 1.34, 1.34 }, { 0, 0.30, 0.02 }, { 0, 0, 90 }, ROPE, "Fabric"),
	spike("Straw", "Head", { 0.28, 0.66, 0.24 }, { -0.40, 0.92, -0.10 }, { 0, -14, -26 }, ROPE, "Grass"),
	spike("Straw", "Head", { 0.26, 0.58, 0.22 }, { -0.14, 0.98, 0.08 }, { -10, -4, -12 }, ROPE, "Grass"),
	spike("Straw", "Head", { 0.26, 0.58, 0.22 }, { 0.16, 0.98, 0.06 }, { -8, 6, 14 }, ROPE, "Grass"),
	spike("Straw", "Head", { 0.28, 0.66, 0.24 }, { 0.40, 0.92, -0.10 }, { 0, 14, 26 }, ROPE, "Grass"),
	blob("EyeL", "Head", { 0.28, 0.28, 0.16 }, { -0.28, 0.10, -0.60 }, { 0, 0, 0 }, STITCH, "SmoothPlastic"),
	blob("EyeR", "Head", { 0.28, 0.28, 0.16 }, { 0.28, 0.10, -0.60 }, { 0, 0, 0 }, STITCH, "SmoothPlastic"),
	blob("Glint", "Head", { 0.10, 0.10, 0.08 }, { -0.32, 0.16, -0.66 }, { 0, 0, 0 }, UMBRAL_CORE, "SmoothPlastic"),
	blob("Glint", "Head", { 0.10, 0.10, 0.08 }, { 0.24, 0.16, -0.66 }, { 0, 0, 0 }, UMBRAL_CORE, "SmoothPlastic"),
	band("Mouth", "Head", { 0.46, 0.10, 0.10 }, { 0, -0.28, -0.62 }, { 0, 0, 0 }, STITCH, "Fabric"),
	band("CheekStitch", "Head", { 0.30, 0.07, 0.07 }, { -0.34, -0.10, -0.58 }, { 0, 0, 40 }, STITCH, "Fabric"),
	band("CheekStitch", "Head", { 0.30, 0.07, 0.07 }, { 0.34, -0.10, -0.58 }, { 0, 0, -40 }, STITCH, "Fabric"),

	blob("SackBody", "UpperTorso", { 2.00, 2.05, 1.22 }, { 0, -0.04, 0.02 }, { 0, 0, 0 }, BURLAP, "Fabric"),
	-- Alvo: o eixo do Cylinder é X, então o yaw de 90° é o que vira a face para a
	-- frente. Sem ele o disco fica de perfil e some.
	band("Target", "UpperTorso", { 0.16, 1.24, 1.24 }, { 0, 0.22, -0.62 }, { 0, 90, 0 }, TARGET_PALE, "SmoothPlastic"),
	band("TargetRing", "UpperTorso", { 0.14, 0.86, 0.86 }, { 0, 0.22, -0.68 }, { 0, 90, 0 }, TARGET_RED, "Neon"),
	band("TargetCore", "UpperTorso", { 0.14, 0.42, 0.42 }, { 0, 0.22, -0.72 }, { 0, 90, 0 }, TARGET_CORE, "Neon"),
	band("ChestRope", "UpperTorso", { 0.22, 1.46, 1.24 }, { 0, 0.62, 0.02 }, { 0, 0, 90 }, ROPE, "Fabric"),
	band("Belt", "UpperTorso", { 0.28, 1.50, 1.24 }, { 0, -0.84, 0.02 }, { 0, 0, 90 }, ROPE, "Leather"),
	blob("Buckle", "UpperTorso", { 0.32, 0.34, 0.20 }, { 0, -0.84, -0.60 }, { 0, 0, 0 }, WOOD, "Wood"),
	blob("Patch", "UpperTorso", { 0.60, 0.52, 0.24 }, { -0.42, -0.30, -0.56 }, { 0, 0, 20 }, BURLAP_DARK, "Fabric"),
	blob("Patch", "UpperTorso", { 0.52, 0.46, 0.22 }, { 0.44, 0.62, -0.54 }, { 0, 0, -16 }, BURLAP_DARK, "Fabric"),
	band("Stitch", "UpperTorso", { 1.05, 0.09, 0.09 }, { -0.36, 0.02, -0.58 }, { 0, 0, 74 }, STITCH, "Fabric"),
	band("Stitch", "UpperTorso", { 0.95, 0.09, 0.09 }, { 0.38, -0.34, -0.56 }, { 0, 0, -68 }, STITCH, "Fabric"),

	blob("ShoulderPatch", "LeftUpperArm", { 1.12, 0.70, 1.16 }, { 0, 0.44, 0 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	blob("ShoulderPatch", "RightUpperArm", { 1.12, 0.70, 1.16 }, { 0, 0.44, 0 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	band("Wrap", "LeftLowerArm", { 0.66, 1.06, 1.14 }, { 0, -0.30, 0 }, { 0, 0, 90 }, ROPE, "Fabric"),
	band("Wrap", "RightLowerArm", { 0.66, 1.06, 1.14 }, { 0, -0.30, 0 }, { 0, 0, 90 }, ROPE, "Fabric"),
	blob("HandKnot", "LeftHand", { 0.96, 0.42, 1.20 }, { 0, 0, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	blob("HandKnot", "RightHand", { 0.96, 0.42, 1.20 }, { 0, 0, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	band("LegWrap", "LeftLowerLeg", { 0.60, 1.02, 1.06 }, { 0, -0.34, 0 }, { 0, 0, 90 }, ROPE, "Fabric"),
	band("LegWrap", "RightLowerLeg", { 0.60, 1.02, 1.06 }, { 0, -0.34, 0 }, { 0, 0, 90 }, ROPE, "Fabric"),

	-- Poste e base: presos ao LowerTorso, que fica 2,877 studs acima da sola.
	-- Por isso os offsets em Y são negativos e grandes — é o chão visto de lá.
	-- O poste sobe do chão até acima do ombro (é o que segura um boneco de
	-- pancada); fica em z = 0,78, atrás da superfície do tronco, para não
	-- atravessar o corpo.
	band("Post", "LowerTorso", { 5.20, 0.44, 0.44 }, { 0, -0.28, 0.78 }, { 0, 0, 90 }, WOOD, "Wood"),
	band("Base", "LowerTorso", { 0.24, 3.10, 3.10 }, { 0, -2.76, 0.22 }, { 0, 0, 90 }, WOOD, "WoodPlanks"),

	-- 15/08: o saco estava bem resolvido de frente e vazio de perfil. A argola
	-- explica por que ele fica em pé, a palha na cintura repete a da cabeça
	-- (é o mesmo boneco, não duas ideias) e o remendo do joelho fecha a perna.
	band("HangRing", "Head", { 0.14, 0.52, 0.52 }, { 0, 0.96, 0.46 }, { 0, 0, 90 }, ROPE, "Fabric"),
	spike("StrawWaist", "UpperTorso", { 0.24, 0.56, 0.22 }, { -0.62, -0.72, -0.26 }, { 0, -30, -46 }, ROPE, "Grass"),
	spike("StrawWaist", "UpperTorso", { 0.24, 0.56, 0.22 }, { 0.62, -0.72, -0.26 }, { 0, 30, 46 }, ROPE, "Grass"),
	blob("KneePatch", "LeftLowerLeg", { 0.92, 0.62, 1.00 }, { 0, 0.34, -0.06 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	blob("KneePatch", "RightLowerLeg", { 0.92, 0.62, 1.00 }, { 0, 0.34, -0.06 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
}

-- ── Skin dos Estilhaços (corpo mineral, sem rig R15) ────────────────────────
-- Os dois inimigos não usam o rig R15: o corpo é um conjunto de peças presas a
-- um pivot visual que o `ActorAnimator` gira. Até 15/08 essas peças viviam
-- dentro do `WorldService`, com um `if npcId == "enemy_anchored_shard"` para a
-- coroa do elite — decisão de apresentação escrita na camada que deveria só
-- materializar (docs/13 §2: "se o WorldService precisar de um `if`, o `if` está
-- no lugar errado"). Agora são dados validados e o WorldService itera.
--
-- Unidades: STUDS na escala 1. O WorldService multiplica tamanho e offset por
-- `ActorRecipe.scale`; `auraScaled` multiplica AINDA por `ActorRecipe.auraScale`
-- (é o halo, que é a leitura da aura à distância).
--
-- ⚠️ HONESTIDADE VISUAL (docs/17). Nenhuma peça pode passar do alcance real do
-- golpe do NPC (`NpcDefinition.attackRange`) no plano XZ: um inimigo que PARECE
-- alcançar 6 studs mas só acerta a 4 ensina a distância errada e o jogador
-- aprende a recuar de menos. `Presentation.validateShardSkins(npcs)` trava isso
-- com o mesmo número que o `EnemyVfxPlayer.rangeFor` usa para a luz.
export type ShardPiece = {
	name: string,
	class: "Part" | "WedgePart",
	shape: "Block" | "Ball" | "Cylinder",
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	-- Papel na paleta do ator, não cor crua: a skin acompanha a receita.
	tint: "body" | "accent" | "core" | "aura",
	material: string,
	transparency: number,
	auraScaled: boolean,
}

local SHARD_TINTS: { [string]: boolean } = {
	body = true,
	accent = true,
	core = true,
	aura = true,
}

local function shard(
	name: string,
	class: "Part" | "WedgePart",
	shape: "Block" | "Ball" | "Cylinder",
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	tint: string,
	material: string,
	transparency: number,
	auraScaled: boolean
): ShardPiece
	return {
		name = name,
		class = class,
		shape = shape,
		sizeStuds = sizeStuds,
		offsetStuds = offsetStuds,
		rotationDegrees = rotationDegrees,
		tint = tint :: any,
		material = material,
		transparency = transparency,
		auraScaled = auraScaled,
	}
end

-- Corpo comum aos dois estilhaços. `MineralShell` e `CoreGlow` entraram em
-- 15/08 pelo mesmo motivo da regra anti-caixa dos rigs: lâmina sobre lâmina não
-- vira volume, e o núcleo sem halo próprio some contra a pedra escura.
local SHARD_BODY: { ShardPiece } = {
	shard("Torso", "Part", "Block", { 2.2, 2.8, 1.6 }, { 0, 0, 0 }, { 0, 0, 45 }, "body", "Slate", 0, false),
	shard("MineralShell", "Part", "Ball", { 2.34, 2.34, 1.94 }, { 0, 0, 0.14 }, { 0, 0, 0 }, "body", "Slate", 0, false),
	shard("Core", "Part", "Ball", { 1.25, 1.25, 1.25 }, { 0, 0, -0.75 }, { 0, 0, 0 }, "core", "Neon", 0, false),
	shard("CoreGlow", "Part", "Ball", { 1.74, 1.74, 1.74 }, { 0, 0, -0.7 }, { 0, 0, 0 }, "aura", "Neon", 0.72, false),
	shard(
		"ShardLeft",
		"WedgePart",
		"Block",
		{ 1.1, 2.7, 0.8 },
		{ -1.35, 0.11, 0 },
		{ 0, 0, 28 },
		"accent",
		"Slate",
		0,
		false
	),
	shard(
		"ShardRight",
		"WedgePart",
		"Block",
		{ 1.1, 2.7, 0.8 },
		{ 1.35, 0.11, 0 },
		{ 0, 180, -28 },
		"accent",
		"Slate",
		0,
		false
	),
	shard("ShardTop", "WedgePart", "Block", { 0.9, 2.2, 0.9 }, { 0, 2, 0 }, { 0, 0, 0 }, "accent", "Slate", 0, false),
	shard(
		"ShardFront",
		"WedgePart",
		"Block",
		{ 0.55, 1.5, 0.55 },
		{ 0, -0.3, -1.7 },
		{ 0, 0, 0 },
		"accent",
		"Slate",
		0,
		false
	),
	shard(
		"ShardBack",
		"WedgePart",
		"Block",
		{ 0.55, 1.5, 0.55 },
		{ 0, -0.3, 1.7 },
		{ 0, 180, 0 },
		"accent",
		"Slate",
		0,
		false
	),
	-- Disco horizontal da aura: o eixo do Cylinder é X, então `z = 90` deita o
	-- anel em volta do corpo. É a leitura de longe de que aquilo está vivo.
	shard("Halo", "Part", "Cylinder", { 0.14, 3.6, 3.6 }, { 0, 0.2, 0 }, { 0, 0, 90 }, "aura", "Neon", 0, true),
}

-- Fenda Ciano (comum): anel de fenda em volta do núcleo e duas lascas soltas
-- acompanhando o corpo. Nada toca o chão — anel no chão leria como área de
-- ataque, e o alcance real dele é 4 studs.
local WANDERING_SHARD_GEAR: { ShardPiece } = {
	shard(
		"RiftRing",
		"Part",
		"Cylinder",
		{ 0.14, 2.1, 2.1 },
		{ 0, 0, -0.56 },
		{ 0, 90, 0 },
		"aura",
		"Neon",
		0.1,
		false
	),
	shard(
		"SplinterLeft",
		"WedgePart",
		"Block",
		{ 0.4, 1.12, 0.4 },
		{ -0.95, 1.35, 0.34 },
		{ 0, -34, 20 },
		"accent",
		"Slate",
		0,
		false
	),
	shard(
		"SplinterRight",
		"WedgePart",
		"Block",
		{ 0.4, 1.12, 0.4 },
		{ 0.95, 1.35, 0.34 },
		{ 0, 34, -20 },
		"accent",
		"Slate",
		0,
		false
	),
}

-- Coroa do Vazio (elite): colar de ancoragem na base, quatro cravos apontando
-- para fora e cinco pontas de coroa. A coroa é a assinatura à distância — é por
-- ela que o jogador reconhece o breakpoint de 15–20 min antes de entrar na
-- cratera (docs/13 §9.3).
local ANCHORED_SHARD_GEAR: { ShardPiece } = {
	shard("Mantle", "Part", "Ball", { 2.6, 2.2, 2.3 }, { 0, -0.55, 0.28 }, { 0, 0, 0 }, "body", "Slate", 0, false),
	shard("AnchorCollar", "Part", "Cylinder", { 0.5, 3, 3 }, { 0, -1.5, 0 }, { 0, 0, 90 }, "body", "Basalt", 0, false),
	shard(
		"AnchorGlow",
		"Part",
		"Cylinder",
		{ 0.16, 3.2, 3.2 },
		{ 0, -1.78, 0 },
		{ 0, 0, 90 },
		"aura",
		"Neon",
		0.3,
		false
	),
}

-- Yaw em ±180°: a receita guarda graus e o validador recusa fora dessa faixa,
-- então 225° tem de virar −135° antes de entrar na tabela.
local function wrapDegrees(degrees: number): number
	return (degrees + 180) % 360 - 180
end

do
	for index = 1, 4 do
		local angle = (index - 1) / 4 * 360 + 45
		local radians = math.rad(angle)
		table.insert(
			ANCHORED_SHARD_GEAR,
			shard(
				("AnchorSpike_%d"):format(index),
				"WedgePart",
				"Block",
				{ 0.45, 1.6, 0.45 },
				{ math.cos(radians) * 1.5, -1.35, math.sin(radians) * 1.5 },
				{ 0, wrapDegrees(-angle), 118 },
				"accent",
				"Slate",
				0,
				false
			)
		)
	end
	-- Cinco pontas (eram três): número ímpar não fecha simetria de frente e
	-- alturas alternadas dão silhueta de coroa em vez de cerca.
	for index = 1, 5 do
		local angle = (index - 1) / 5 * 360
		local radians = math.rad(angle)
		local height = if index % 2 == 0 then 1.6 else 2.05
		table.insert(
			ANCHORED_SHARD_GEAR,
			shard(
				("Crown_%d"):format(index),
				"WedgePart",
				"Block",
				{ 0.5, height, 0.5 },
				{ math.cos(radians) * 0.95, 3.1, math.sin(radians) * 0.95 },
				{ 0, wrapDegrees(-angle), -28 },
				"accent",
				"Neon",
				0,
				false
			)
		)
	end
	table.insert(
		ANCHORED_SHARD_GEAR,
		shard("CrownCore", "Part", "Ball", { 0.7, 0.7, 0.7 }, { 0, 3.35, 0 }, { 0, 0, 0 }, "core", "Neon", 0, false)
	)
end

-- Véu do Bosque: dois fios de néon e um núcleo pequeno. Sem anel no chão
-- (não lê como área). Alcance do golpe é 6 — a silhueta fica bem abaixo.
local GROVE_WISP_GEAR: { ShardPiece } = {
	shard("WispVeil", "Part", "Cylinder", { 0.12, 1.8, 1.8 }, { 0, 0.4, 0 }, { 0, 0, 90 }, "aura", "Neon", 0.15, true),
	shard("WispCore", "Part", "Ball", { 0.7, 0.7, 0.7 }, { 0, 0.55, 0 }, { 0, 0, 0 }, "core", "Neon", 0.05, false),
	shard(
		"WispThreadA",
		"Part",
		"Block",
		{ 0.18, 1.4, 0.18 },
		{ -0.55, 1.15, 0.2 },
		{ 0, 0, 18 },
		"accent",
		"Glass",
		0.2,
		false
	),
	shard(
		"WispThreadB",
		"Part",
		"Block",
		{ 0.18, 1.2, 0.18 },
		{ 0.5, 1.05, -0.15 },
		{ 0, 0, -22 },
		"accent",
		"Glass",
		0.2,
		false
	),
}

local PORT_SCRAPPER_GEAR: { ShardPiece } = {
	shard(
		"ScrapPlate",
		"Part",
		"Block",
		{ 1.4, 0.28, 1.1 },
		{ 0, 0.85, 0.15 },
		{ 0, 12, 0 },
		"body",
		"CorrodedMetal",
		0,
		false
	),
	shard(
		"ScrapHook",
		"WedgePart",
		"Block",
		{ 0.35, 1.5, 0.45 },
		{ 0.85, 0.4, -0.7 },
		{ 0, 35, -18 },
		"accent",
		"Metal",
		0,
		false
	),
	shard("ScrapCore", "Part", "Ball", { 0.55, 0.55, 0.55 }, { 0, 0.35, 0 }, { 0, 0, 0 }, "core", "Neon", 0.08, false),
	shard("ScrapHalo", "Part", "Cylinder", { 0.1, 2.0, 2.0 }, { 0, 0.15, 0 }, { 0, 0, 90 }, "aura", "Neon", 0.2, true),
}

local ShardSkins: { [string]: { ShardPiece } } = {
	enemy_wandering_shard = WANDERING_SHARD_GEAR,
	enemy_anchored_shard = ANCHORED_SHARD_GEAR,
	enemy_grove_wisp = GROVE_WISP_GEAR,
	enemy_port_scrapper = PORT_SCRAPPER_GEAR,
}

-- Sem skin declarada o WorldService montaria um estilhaço sem corpo: os
-- inimigos jogáveis são obrigatórios, como os dois rigs do spawn.
local SHARD_REQUIRED: { string } =
	{ "enemy_wandering_shard", "enemy_anchored_shard", "enemy_grove_wisp", "enemy_port_scrapper" }

local Rigs: { [string]: RigRecipe } = {
	npc_threshold_instructor = {
		npcId = "npc_threshold_instructor",
		skinRgb = SKIN_TONE,
		bodyRgb = COAT,
		legRgb = COAT_DARK,
		bodyMaterial = "Fabric",
		legMaterial = "Leather",
		-- Rosto embutido do cliente: sem download, sem moderação de catálogo.
		faceTexture = "rbxasset://textures/face.png",
		scales = INSTRUCTOR_SCALES,
		gear = INSTRUCTOR_GEAR,
	},
	npc_training_dummy = {
		npcId = "npc_training_dummy",
		skinRgb = BURLAP,
		bodyRgb = BURLAP,
		legRgb = BURLAP_DARK,
		bodyMaterial = "Fabric",
		legMaterial = "Fabric",
		-- Sem decal: saco de estopa tem botão costurado, não rosto de avatar.
		faceTexture = nil,
		scales = RIG_SCALES,
		gear = DUMMY_GEAR,
	},
}

local STYLE: WorldStyle = {
	pathWidth = 8,
	spawnPlazaRadius = 10,
	craterSegments = 16,
	boundaryPostCount = 6,
	landmarkShardCount = 7,
}

local Presentation = {}

function Presentation.getActor(npcId: string): ActorRecipe?
	return Actors[npcId]
end

function Presentation.allActors(): { ActorRecipe }
	local ids: { string } = {}
	for npcId in Actors do
		table.insert(ids, npcId)
	end
	table.sort(ids)
	local out: { ActorRecipe } = {}
	for _, npcId in ids do
		table.insert(out, Actors[npcId])
	end
	return out
end

function Presentation.style(): WorldStyle
	return STYLE
end

-- Partes do rig R15 que aceitam gear. Lista fechada: um `host` com erro de
-- digitação viraria peça órfã no chão em vez de roupa no boneco.
local RIG_HOSTS: { [string]: boolean } = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	RightUpperArm = true,
	LeftLowerArm = true,
	RightLowerArm = true,
	LeftHand = true,
	RightHand = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	LeftLowerLeg = true,
	RightLowerLeg = true,
	LeftFoot = true,
	RightFoot = true,
}

-- Materiais liberados. O WorldService resolve por nome em `Enum.Material`;
-- um nome inválido lá é erro de runtime no boot do mundo, então trava aqui.
local RIG_MATERIALS: { [string]: boolean } = {
	Fabric = true,
	Leather = true,
	Neon = true,
	SmoothPlastic = true,
	Wood = true,
	WoodPlanks = true,
	Grass = true,
	Slate = true,
	Metal = true,
}

-- Materiais liberados para o corpo mineral. Lista própria: o estilhaço é pedra
-- e cristal, não tecido de rig, e `Basalt` só faz sentido aqui.
local SHARD_MATERIALS: { [string]: boolean } = {
	Slate = true,
	Basalt = true,
	Rock = true,
	Neon = true,
	Glass = true,
	Ice = true,
	Metal = true,
	SmoothPlastic = true,
	CorrodedMetal = true,
}

function Presentation.rigFor(npcId: string): RigRecipe?
	return Rigs[npcId]
end

-- Corpo comum + peças exclusivas do NPC, na ordem de montagem. Devolve tabela
-- nova a cada chamada: o WorldService materializa duas vezes em reconstrução e
-- não pode compartilhar estado com a receita.
function Presentation.shardGearFor(npcId: string): { ShardPiece }
	local out: { ShardPiece } = {}
	local recipe = Actors[npcId]
	if not recipe or recipe.shape ~= "shard" then
		return out
	end
	for _, piece in SHARD_BODY do
		table.insert(out, piece)
	end
	for _, piece in ShardSkins[npcId] or {} do
		table.insert(out, piece)
	end
	return out
end

-- Maior distância horizontal que a skin ocupa, já na escala do ator. O limite
-- superior é conservador de propósito: usa a maior dimensão da peça como raio,
-- então qualquer rotação continua coberta sem recalcular a caixa girada.
function Presentation.shardReachStuds(npcId: string): number
	local recipe = Actors[npcId]
	if not recipe then
		return 0
	end
	local reach = 0
	for _, piece in Presentation.shardGearFor(npcId) do
		local scale = recipe.scale * (if piece.auraScaled then recipe.auraScale else 1)
		local half = math.max(piece.sizeStuds[1], piece.sizeStuds[2], piece.sizeStuds[3]) / 2
		local offsetX = piece.offsetStuds[1]
		local offsetZ = piece.offsetStuds[3]
		local offsetXZ = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
		reach = math.max(reach, (offsetXZ + half) * scale)
	end
	return reach
end

function Presentation.validateShardPiece(piece: ShardPiece): (boolean, string?)
	if not SHARD_TINTS[piece.tint] then
		return false, ("%s: tint fora da paleta (%s)"):format(piece.name, tostring(piece.tint))
	end
	if not SHARD_MATERIALS[piece.material] then
		return false, ("%s: material fora da lista (%s)"):format(piece.name, piece.material)
	end
	if piece.class ~= "Part" and piece.class ~= "WedgePart" then
		return false, ("%s: classe inválida (%s)"):format(piece.name, piece.class)
	end
	if piece.shape ~= "Block" and piece.shape ~= "Ball" and piece.shape ~= "Cylinder" then
		return false, ("%s: shape inválido (%s)"):format(piece.name, piece.shape)
	end
	if piece.class == "WedgePart" and piece.shape ~= "Block" then
		return false, ("%s: WedgePart não aceita shape %s"):format(piece.name, piece.shape)
	end
	if piece.transparency < 0 or piece.transparency >= 1 then
		return false, ("%s: transparência %.2f fora de 0..1"):format(piece.name, piece.transparency)
	end
	if #piece.sizeStuds ~= 3 or #piece.offsetStuds ~= 3 or #piece.rotationDegrees ~= 3 then
		return false, ("%s: vetor precisa de 3 componentes"):format(piece.name)
	end
	for _, component in piece.sizeStuds do
		if component < 0.05 or component > 8 then
			return false, ("%s: tamanho %.3f fora de 0,05–8 studs"):format(piece.name, component)
		end
	end
	for _, component in piece.offsetStuds do
		if math.abs(component) > 4 then
			return false, ("%s: offset %.3f longe demais do pivot"):format(piece.name, component)
		end
	end
	for _, component in piece.rotationDegrees do
		if math.abs(component) > 180 then
			return false, ("%s: rotação %.1f fora de ±180°"):format(piece.name, component)
		end
	end
	return true, nil
end

-- Com `npcs`, aplica também a regra de honestidade visual do cabeçalho: a skin
-- não pode passar do alcance do golpe. Sem `npcs`, valida só a estrutura — é o
-- que o boot do catálogo consegue fazer antes de conhecer o NPC.
function Presentation.validateShardSkins(npcs: any?): (boolean, string?)
	for npcId in ShardSkins do
		local recipe = Actors[npcId]
		if not recipe then
			return false, "shard_without_actor:" .. npcId
		end
		if recipe.shape ~= "shard" then
			return false, "shard_skin_on_humanoid:" .. npcId
		end
	end
	for _, npcId in SHARD_REQUIRED do
		if not ShardSkins[npcId] then
			return false, "missing_shard_skin:" .. npcId
		end
		local seen: { [string]: boolean } = {}
		for _, piece in Presentation.shardGearFor(npcId) do
			if seen[piece.name] then
				return false, ("%s: peça duplicada %s"):format(npcId, piece.name)
			end
			seen[piece.name] = true
			local ok, reason = Presentation.validateShardPiece(piece)
			if not ok then
				return false, ("%s/%s"):format(npcId, reason or "?")
			end
		end
		if npcs ~= nil then
			local definition = npcs.get(npcId)
			if not definition then
				return false, "shard_npc_desconhecido:" .. npcId
			end
			local reach = Presentation.shardReachStuds(npcId)
			if reach > definition.attackRange then
				return false,
					("%s: skin alcança %.2f studs e o golpe alcança %.2f"):format(
						npcId,
						reach,
						definition.attackRange
					)
			end
		end
	end
	return true, nil
end

function Presentation.allRigs(): { RigRecipe }
	local ids: { string } = {}
	for npcId in Rigs do
		table.insert(ids, npcId)
	end
	table.sort(ids)
	local out: { RigRecipe } = {}
	for _, npcId in ids do
		table.insert(out, Rigs[npcId])
	end
	return out
end

function Presentation.rigHostExists(host: string): boolean
	return RIG_HOSTS[host] == true
end

local function validRgb(rgb: Rgb): boolean
	if #rgb ~= 3 then
		return false
	end
	for _, component in rgb do
		if component % 1 ~= 0 or component < 0 or component > 255 then
			return false
		end
	end
	return true
end

function Presentation.validate(): (boolean, string?)
	local expected = {
		"npc_training_dummy",
		"npc_threshold_instructor",
		"enemy_wandering_shard",
		"enemy_anchored_shard",
		"enemy_grove_wisp",
		"enemy_port_scrapper",
	}
	for _, npcId in expected do
		if not Actors[npcId] then
			return false, "missing_actor:" .. npcId
		end
	end
	for npcId, recipe in Actors do
		if recipe.id ~= npcId then
			return false, "actor_id_mismatch:" .. npcId
		end
		if recipe.scale <= 0 or recipe.idleBobStuds < 0 or recipe.idleCyclesPerSecond <= 0 then
			return false, "invalid_motion:" .. npcId
		end
		if
			recipe.strideDegrees < 0
			or recipe.telegraphLeanDegrees < 0
			or recipe.attackLeanDegrees < recipe.telegraphLeanDegrees
			or recipe.deathTiltDegrees <= 0
			or recipe.deathTiltDegrees > 90
		then
			return false, "invalid_pose_range:" .. npcId
		end
		if
			not validRgb(recipe.bodyRgb)
			or not validRgb(recipe.accentRgb)
			or not validRgb(recipe.coreRgb)
			or not validRgb(recipe.auraRgb)
			or type(recipe.skinNameKey) ~= "string"
			or recipe.skinNameKey == ""
			or recipe.auraScale <= 0
		then
			return false, "invalid_skin:" .. npcId
		end
	end
	if
		STYLE.pathWidth < 6
		or STYLE.spawnPlazaRadius < 8
		or STYLE.craterSegments < 12
		or STYLE.boundaryPostCount < 4
		or STYLE.landmarkShardCount < 5
	then
		return false, "invalid_world_style"
	end
	local rigsOk, rigsReason = Presentation.validateRigs()
	if not rigsOk then
		return false, rigsReason
	end
	-- Sem `npcs` aqui: a regra de alcance precisa do catálogo e é aplicada pelo
	-- bootstrap do servidor, que conhece os dois módulos.
	return Presentation.validateShardSkins(nil)
end

-- Os dois bots do spawn precisam de skin de rig; sem ela o WorldService cai no
-- corpo greybox de Parts e o jogador vê de novo a caixa com esfera na cabeça.
local RIG_REQUIRED: { string } = { "npc_threshold_instructor", "npc_training_dummy" }

-- Luminância relativa (Rec. 709) na escala 0..255. É o número que decide se
-- duas peças vizinhas leem como duas peças ou como uma mancha só: matiz
-- diferente com o MESMO valor some, principalmente à noite.
local function luminance(rgb: Rgb): number
	return 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
end

-- Degrau mínimo entre tons vizinhos da escada. 24 é o que separa a saia do
-- cabelo na cena noturna do Bastião; a paleta antiga tinha degraus de 3.
local PALETTE_MIN_STEP = 24

-- Ordem crescente de valor. Peça que muda de cor tem de continuar cabendo
-- entre a de baixo e a de cima, senão a silhueta volta a colapsar.
local INSTRUCTOR_LADDER: { { string | Rgb } } = {
	{ "COAT_DARK", COAT_DARK },
	{ "COAT", COAT },
	{ "COAT_LINING", COAT_LINING },
	{ "HAIR_DEEP", HAIR_DEEP },
	{ "HAIR", HAIR },
	{ "HAIR_SHEEN", HAIR_SHEEN },
}

function Presentation.validatePalette(): (boolean, string?)
	for index = 2, #INSTRUCTOR_LADDER do
		local lowerName = INSTRUCTOR_LADDER[index - 1][1] :: string
		local upperName = INSTRUCTOR_LADDER[index][1] :: string
		local lower = luminance(INSTRUCTOR_LADDER[index - 1][2] :: Rgb)
		local upper = luminance(INSTRUCTOR_LADDER[index][2] :: Rgb)
		local step = upper - lower
		if step < PALETTE_MIN_STEP then
			return false,
				("palette_flat:%s→%s (degrau %.1f, mínimo %.0f)"):format(
					lowerName,
					upperName,
					step,
					PALETTE_MIN_STEP
				)
		end
	end
	-- Cabelo colado no tom de pele apaga o rosto, que é justamente o que a
	-- textura embutida existe para mostrar.
	local hairVsSkin = math.abs(luminance(HAIR) - luminance(SKIN_TONE))
	if hairVsSkin < PALETTE_MIN_STEP then
		return false, ("palette_hair_vs_skin:%.1f (mínimo %.0f)"):format(hairVsSkin, PALETTE_MIN_STEP)
	end
	return true, nil
end

function Presentation.validateRigs(): (boolean, string?)
	local paletteOk, paletteReason = Presentation.validatePalette()
	if not paletteOk then
		return false, paletteReason
	end
	for _, npcId in RIG_REQUIRED do
		if not Rigs[npcId] then
			return false, "missing_rig:" .. npcId
		end
	end
	for npcId, rig in Rigs do
		if rig.npcId ~= npcId then
			return false, "rig_id_mismatch:" .. npcId
		end
		if not Actors[npcId] then
			return false, "rig_without_actor:" .. npcId
		end
		if not validRgb(rig.skinRgb) or not validRgb(rig.bodyRgb) or not validRgb(rig.legRgb) then
			return false, "rig_invalid_rgb:" .. npcId
		end
		if not RIG_MATERIALS[rig.bodyMaterial] or not RIG_MATERIALS[rig.legMaterial] then
			return false, "rig_invalid_material:" .. npcId
		end
		-- Textura de rosto só pode ser embutida do cliente: um rbxassetid de
		-- catálogo pode sumir por moderação e deixar o NPC sem cara.
		if rig.faceTexture ~= nil and string.sub(rig.faceTexture, 1, 11) ~= "rbxasset://" then
			return false, "rig_face_not_builtin:" .. npcId
		end
		if #rig.gear < 8 then
			return false, "rig_gear_too_sparse:" .. npcId
		end
		local scalesOk, scalesReason = Presentation.validateScales(rig.scales)
		if not scalesOk then
			return false, ("%s/%s"):format(npcId, scalesReason or "?")
		end
		-- Regra anti-caixa (ver cabeçalho): a reclamação "ainda tá muito
		-- quadrado" veio de uma receita 100% `Block`. Volume grande tem de ser
		-- elipsoide, faixa tem de ser cilindro; bloco só sobra para detalhe.
		local blocks = 0
		for _, gearPiece in rig.gear do
			if gearPiece.shape == "Block" and gearPiece.class == "Part" then
				blocks += 1
			end
		end
		if blocks > #rig.gear * 0.25 then
			return false, ("rig_too_boxy:%s (%d de %d peças são bloco)"):format(npcId, blocks, #rig.gear)
		end
		for _, piece in rig.gear do
			local ok, reason = Presentation.validateGear(piece)
			if not ok then
				return false, ("%s/%s"):format(npcId, reason or "?")
			end
			if rig.faceTexture ~= nil then
				local clear, why = Presentation.gearClearsFace(piece)
				if not clear then
					return false, ("%s/%s"):format(npcId, why or "?")
				end
			end
		end
	end
	return true, nil
end

-- Cabeça do rig nas escalas de `RIG_SCALES`, medida no Studio. Derivar as duas
-- constantes daqui em vez de fixá-las evita que uma mudança de escala deixe a
-- regra do rosto conferindo um plano que não existe mais.
local RIG_HEAD_SIZE: { number } = { 1.253, 1.292, 1.255 }
local FACE_PLANE_Z = -RIG_HEAD_SIZE[3] / 2
-- Na textura clássica os olhos terminam a ~23,7% da altura da cabeça acima do
-- centro (medido na face.png sobre a cabeça padrão).
local EYE_BAND_TOP = RIG_HEAD_SIZE[2] * 0.237

-- Cabelo e capuz não podem tapar os olhos. A regra é geométrica: se a peça
-- avança na frente do plano do rosto, ela TEM de ficar inteira acima da faixa
-- dos olhos. Peça que fica atrás do plano some dentro da malha da cabeça e não
-- ocluí nada, então está liberada.
--
-- Sem isto, a franja escorrega alguns centésimos para baixo numa edição de
-- ajuste fino e o instrutor volta a ser um vulto encapuzado sem cara — que é
-- metade da razão de o boneco antigo parecer feio.
-- Escalas da HumanoidDescription. Fora destas faixas o rig deixa de bater com
-- as medidas deste arquivo e todo o encaixe da roupa sai do lugar.
function Presentation.validateScales(scales: RigScales): (boolean, string?)
	local fields = {
		{ "bodyType", scales.bodyType },
		{ "proportion", scales.proportion },
		{ "head", scales.head },
		{ "width", scales.width },
		{ "height", scales.height },
	}
	for _, field in fields do
		local value = field[2]
		if type(value) ~= "number" or value ~= value or value < 0 or value > 2 then
			return false, ("escala %s inválida (%s)"):format(field[1], tostring(value))
		end
	end
	-- `bodyType = 0` é o boneco cúbico clássico. Foi o que gerou a reclamação
	-- de "muito quadrado": metade do problema era a proporção do corpo, não a
	-- roupa. Puxar para o Rthro é o que dá tronco alongado e membro afilado.
	if scales.bodyType < 0.5 then
		return false, ("bodyType %.2f volta ao corpo cúbico clássico"):format(scales.bodyType)
	end
	return true, nil
end

function Presentation.gearClearsFace(piece: RigGear): (boolean, string?)
	if piece.host ~= "Head" then
		return true, nil
	end
	local halfZ = piece.sizeStuds[3] / 2
	local frontZ = piece.offsetStuds[3] - halfZ
	if frontZ >= FACE_PLANE_Z then
		return true, nil
	end
	-- Extensão em Y de uma caixa girada em torno de X: a meia-diagonal do plano
	-- YZ é o limite conservador (giro em torno de Y não altera a altura).
	local halfY = piece.sizeStuds[2] / 2
	if piece.rotationDegrees[1] ~= 0 or piece.rotationDegrees[3] ~= 0 then
		halfY = math.sqrt(halfY * halfY + halfZ * halfZ)
	end
	local bottomY = piece.offsetStuds[2] - halfY
	if bottomY < EYE_BAND_TOP then
		return false,
			("%s: desce a %.3f na frente do rosto e tapa os olhos (mínimo %.2f)"):format(
				piece.name,
				bottomY,
				EYE_BAND_TOP
			)
	end
	return true, nil
end

function Presentation.validateGear(piece: RigGear): (boolean, string?)
	if not RIG_HOSTS[piece.host] then
		return false, ("%s: host desconhecido (%s)"):format(piece.name, piece.host)
	end
	if not RIG_MATERIALS[piece.material] then
		return false, ("%s: material fora da lista (%s)"):format(piece.name, piece.material)
	end
	if piece.class ~= "Part" and piece.class ~= "WedgePart" then
		return false, ("%s: classe inválida (%s)"):format(piece.name, piece.class)
	end
	if piece.shape ~= "Block" and piece.shape ~= "Ball" and piece.shape ~= "Cylinder" then
		return false, ("%s: shape inválido (%s)"):format(piece.name, piece.shape)
	end
	-- WedgePart não tem Shape: pedir Ball/Cylinder numa cunha é engano de quem
	-- escreveu a receita, e o resultado seria uma cunha silenciosamente comum.
	if piece.class == "WedgePart" and piece.shape ~= "Block" then
		return false, ("%s: WedgePart não aceita shape %s"):format(piece.name, piece.shape)
	end
	if not validRgb(piece.rgb) then
		return false, ("%s: rgb inválido"):format(piece.name)
	end
	if #piece.sizeStuds ~= 3 or #piece.offsetStuds ~= 3 or #piece.rotationDegrees ~= 3 then
		return false, ("%s: vetor precisa de 3 componentes"):format(piece.name)
	end
	for _, component in piece.sizeStuds do
		-- 0,05 é o mínimo de Part do engine; abaixo disso o Roblox arredonda e
		-- a peça deixa de ter a proporção declarada aqui.
		if component < 0.05 or component > 8 then
			return false, ("%s: tamanho %.3f fora de 0,05–8 studs"):format(piece.name, component)
		end
	end
	-- Uma peça a mais de 4 studs do centro da parte hospedeira não é roupa: é
	-- peça solta flutuando ao lado do boneco. A exceção é o poste/base do
	-- boneco de treino, que desce até o chão a partir do quadril (~2,3 studs).
	for _, component in piece.offsetStuds do
		if math.abs(component) > 4 then
			return false, ("%s: offset %.3f longe demais do host"):format(piece.name, component)
		end
	end
	for _, component in piece.rotationDegrees do
		if math.abs(component) > 180 then
			return false, ("%s: rotação %.1f fora de ±180°"):format(piece.name, component)
		end
	end
	return true, nil
end

return Presentation

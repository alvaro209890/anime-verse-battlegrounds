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
-- Referencial: `offsetStuds` e `sizeStuds` estão em STUDS, no espaço da parte
-- hospedeira, com a FRENTE em −Z (é onde fica o rosto do R15). Medidas do rig
-- padrão colhidas no Studio em 2026-08-14 (todas as escalas em 1):
--   Head 1,159×1,182×1,161 · UpperTorso 1,943×1,698×1,004
--   LowerTorso 1,991×0,401×1,004 · UpperArm 1,001×1,242×1,002
--   LowerArm 1,001×1,118×1,002 · LowerLeg 0,993×1,301×0,973
-- A sola fica 3,192 studs abaixo da HumanoidRootPart — é isso que faz o pé
-- encostar no chão em vez de o boneco flutuar.
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
		-- O mensageiro do Limiar: casaco escuro, energia umbral nas bordas
		-- (capuz, gola e faixa neon) e rosto pálido — a presença do anime.
		bodyRgb = { 38, 40, 48 },
		accentRgb = { 118, 84, 158 },
		coreRgb = { 206, 196, 224 },
		idleBobStuds = 0.04,
		idleCyclesPerSecond = 0.35,
		strideDegrees = 7,
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
		idleBobStuds = 0.32,
		idleCyclesPerSecond = 0.8,
		strideDegrees = 18,
		telegraphLeanDegrees = 16,
		attackLeanDegrees = 34,
		deathTiltDegrees = 78,
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
		idleBobStuds = 0.18,
		idleCyclesPerSecond = 0.45,
		strideDegrees = 8,
		telegraphLeanDegrees = 22,
		attackLeanDegrees = 42,
		deathTiltDegrees = 82,
	},
}

local HAIR: Rgb = { 26, 24, 38 }
local UMBRAL: Rgb = { 138, 96, 196 }
local UMBRAL_CORE: Rgb = { 226, 214, 250 }
local COAT: Rgb = { 40, 42, 54 }
local COAT_DARK: Rgb = { 26, 27, 36 }
local BURLAP: Rgb = { 186, 156, 108 }
local BURLAP_DARK: Rgb = { 148, 120, 80 }
local ROPE: Rgb = { 122, 96, 58 }
local STITCH: Rgb = { 44, 36, 30 }
local WOOD: Rgb = { 104, 74, 42 }

local function gear(
	name: string,
	host: string,
	sizeStuds: { number },
	offsetStuds: { number },
	rotationDegrees: { number },
	rgb: Rgb,
	material: string,
	class: ("Part" | "WedgePart")?,
	shape: string?
): RigGear
	return {
		name = name,
		class = class or "Part",
		shape = (shape or "Block") :: any,
		host = host,
		sizeStuds = sizeStuds,
		offsetStuds = offsetStuds,
		rotationDegrees = rotationDegrees,
		rgb = rgb,
		material = material,
	}
end

-- Instrutor do Limiar: casaco escuro de gola alta, capuz aberto para o rosto
-- aparecer, mecha de cabelo em cunhas e energia umbral só nas bordas (rim do
-- capuz, gola, emblema, cinto, punhos). O neon é assinatura, não uniforme: se
-- pintar tudo, some a silhueta.
local INSTRUCTOR_GEAR: { RigGear } = {
	-- ⚠️ A cabeça do R15 tem 1,182 de altura e o rosto ocupa a face −Z. Na
	-- textura clássica os olhos ficam por volta de y +0,05 a +0,28 no
	-- referencial da cabeça: TODA peça de cabelo/capuz precisa passar acima
	-- disso, e o cabelo precisa ficar atrás do plano do rosto (z > −0,581) ou
	-- ele tapa a cara do instrutor e volta o boneco sem expressão.
	gear("HairCap", "Head", { 1.22, 0.50, 1.10 }, { 0, 0.50, 0.08 }, { 0, 0, 0 }, HAIR, "Fabric"),
	gear("Bang", "Head", { 0.30, 0.36, 0.26 }, { -0.30, 0.52, -0.48 }, { -20, -16, 0 }, HAIR, "Fabric", "WedgePart"),
	gear("Bang", "Head", { 0.30, 0.36, 0.26 }, { 0.30, 0.52, -0.48 }, { -20, 16, 0 }, HAIR, "Fabric", "WedgePart"),
	gear("Bang", "Head", { 0.26, 0.32, 0.24 }, { 0, 0.54, -0.50 }, { -30, 0, 0 }, HAIR, "Fabric", "WedgePart"),
	gear("HoodBack", "Head", { 1.30, 1.05, 0.50 }, { 0, 0.14, 0.52 }, { 0, 0, 0 }, COAT, "Leather"),
	gear("HoodTop", "Head", { 1.26, 0.32, 1.05 }, { 0, 0.70, 0.12 }, { 0, 0, 0 }, COAT, "Leather"),
	gear("HoodSide", "Head", { 0.24, 1.00, 0.92 }, { -0.63, 0.10, 0.10 }, { 0, 0, 0 }, COAT, "Leather"),
	gear("HoodSide", "Head", { 0.24, 1.00, 0.92 }, { 0.63, 0.10, 0.10 }, { 0, 0, 0 }, COAT, "Leather"),
	gear("HoodRim", "Head", { 1.28, 0.09, 0.95 }, { 0, 0.60, -0.16 }, { 0, 0, 0 }, UMBRAL, "Neon"),

	gear("Collar", "UpperTorso", { 1.16, 0.34, 0.96 }, { 0, 0.72, 0 }, { 0, 0, 0 }, COAT, "Fabric"),
	gear("CollarTrim", "UpperTorso", { 1.22, 0.08, 1.02 }, { 0, 0.90, 0 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	gear("Sash", "UpperTorso", { 0.20, 1.30, 1.06 }, { -0.22, 0.02, 0 }, { 0, 0, -14 }, COAT_DARK, "Fabric"),
	gear("Emblem", "UpperTorso", { 0.26, 0.34, 0.10 }, { 0, 0.16, -0.52 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	gear("EmblemCore", "UpperTorso", { 0.12, 0.14, 0.12 }, { 0, 0.16, -0.56 }, { 0, 0, 0 }, UMBRAL_CORE, "Neon"),
	gear("Belt", "UpperTorso", { 1.42, 0.24, 1.06 }, { 0, -0.72, 0 }, { 0, 0, 0 }, COAT_DARK, "Leather"),
	gear("Buckle", "UpperTorso", { 0.30, 0.34, 0.14 }, { 0, -0.72, -0.54 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	-- Saia do casaco: nasce no tórax e desce por cima das coxas. Presa ao
	-- tronco de propósito — casaco não acompanha a perna.
	gear("CoatFront", "UpperTorso", { 1.56, 1.05, 1.10 }, { 0, -1.42, 0.02 }, { 0, 0, 0 }, COAT, "Fabric"),
	gear("Hem", "UpperTorso", { 1.62, 0.09, 1.16 }, { 0, -1.95, 0.02 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	gear("CoatTail", "UpperTorso", { 0.76, 1.95, 0.34 }, { -0.34, -1.85, 0.46 }, { 8, 0, -4 }, COAT, "Fabric"),
	gear("CoatTail", "UpperTorso", { 0.76, 1.95, 0.34 }, { 0.34, -1.85, 0.46 }, { 8, 0, 4 }, COAT, "Fabric"),

	gear("Pauldron", "LeftUpperArm", { 1.22, 0.44, 1.24 }, { 0, 0.44, 0 }, { 0, 0, 8 }, COAT, "Fabric"),
	gear("Pauldron", "RightUpperArm", { 1.22, 0.44, 1.24 }, { 0, 0.44, 0 }, { 0, 0, -8 }, COAT, "Fabric"),
	gear("PauldronTrim", "LeftUpperArm", { 1.26, 0.08, 1.28 }, { 0, 0.24, 0 }, { 0, 0, 8 }, UMBRAL, "Neon"),
	gear("PauldronTrim", "RightUpperArm", { 1.26, 0.08, 1.28 }, { 0, 0.24, 0 }, { 0, 0, -8 }, UMBRAL, "Neon"),
	gear("Cuff", "LeftLowerArm", { 1.10, 0.18, 1.10 }, { 0, -0.42, 0 }, { 0, 0, 0 }, UMBRAL, "Neon"),
	gear("Cuff", "RightLowerArm", { 1.10, 0.18, 1.10 }, { 0, -0.42, 0 }, { 0, 0, 0 }, UMBRAL, "Neon"),
}

-- Boneco de treino: saco de estopa amarrado, palha saindo pelas costuras,
-- olhos de botão, alvo no peito e poste de madeira atrás. Nada de neon além
-- do anel vermelho do alvo — quem brilha aqui é onde se deve bater.
local DUMMY_GEAR: { RigGear } = {
	gear("SackTop", "Head", { 1.24, 0.30, 1.24 }, { 0, 0.60, 0 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	gear("TieBand", "Head", { 1.28, 0.14, 1.28 }, { 0, 0.46, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	gear("Straw", "Head", { 0.28, 0.62, 0.24 }, { -0.36, 0.86, -0.10 }, { 0, -12, -24 }, ROPE, "Grass", "WedgePart"),
	gear("Straw", "Head", { 0.28, 0.62, 0.24 }, { 0.36, 0.86, -0.10 }, { 0, 12, 24 }, ROPE, "Grass", "WedgePart"),
	gear("Straw", "Head", { 0.26, 0.54, 0.22 }, { 0, 0.92, 0.06 }, { -8, 0, 0 }, ROPE, "Grass", "WedgePart"),
	gear(
		"EyeL",
		"Head",
		{ 0.26, 0.26, 0.14 },
		{ -0.26, 0.10, -0.56 },
		{ 0, 0, 0 },
		STITCH,
		"SmoothPlastic",
		"Part",
		"Ball"
	),
	gear(
		"EyeR",
		"Head",
		{ 0.26, 0.26, 0.14 },
		{ 0.26, 0.10, -0.56 },
		{ 0, 0, 0 },
		STITCH,
		"SmoothPlastic",
		"Part",
		"Ball"
	),
	gear("Mouth", "Head", { 0.42, 0.08, 0.08 }, { 0, -0.26, -0.58 }, { 0, 0, 0 }, STITCH, "Fabric"),
	gear("CheekStitch", "Head", { 0.30, 0.06, 0.06 }, { -0.30, -0.10, -0.56 }, { 0, 0, 40 }, STITCH, "Fabric"),

	-- Alvo: eixo do Cylinder é X, então o yaw de 90° é o que vira a face para
	-- a frente. Sem ele o disco fica de perfil e some.
	gear(
		"Target",
		"UpperTorso",
		{ 0.16, 1.20, 1.20 },
		{ 0, 0.18, -0.54 },
		{ 0, 90, 0 },
		{ 226, 214, 183 },
		"SmoothPlastic",
		"Part",
		"Cylinder"
	),
	gear(
		"TargetRing",
		"UpperTorso",
		{ 0.14, 0.84, 0.84 },
		{ 0, 0.18, -0.60 },
		{ 0, 90, 0 },
		{ 226, 78, 78 },
		"Neon",
		"Part",
		"Cylinder"
	),
	gear(
		"TargetCore",
		"UpperTorso",
		{ 0.14, 0.42, 0.42 },
		{ 0, 0.18, -0.64 },
		{ 0, 90, 0 },
		{ 244, 238, 220 },
		"Neon",
		"Part",
		"Cylinder"
	),
	gear("Stitch", "UpperTorso", { 0.10, 1.05, 0.10 }, { -0.34, 0.10, -0.52 }, { 0, 0, 16 }, STITCH, "Fabric"),
	gear("Stitch", "UpperTorso", { 0.10, 0.95, 0.10 }, { 0.34, 0.00, -0.52 }, { 0, 0, -14 }, STITCH, "Fabric"),
	gear("ChestStrap", "UpperTorso", { 1.50, 0.22, 1.08 }, { 0, 0.42, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	gear("Belt", "UpperTorso", { 1.44, 0.28, 1.08 }, { 0, -0.70, 0 }, { 0, 0, 0 }, ROPE, "Leather"),
	gear("Buckle", "UpperTorso", { 0.30, 0.32, 0.14 }, { 0, -0.70, -0.54 }, { 0, 0, 0 }, WOOD, "Wood"),

	gear("ShoulderPatch", "LeftUpperArm", { 1.10, 0.40, 1.12 }, { 0, 0.42, 0 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	gear("ShoulderPatch", "RightUpperArm", { 1.10, 0.40, 1.12 }, { 0, 0.42, 0 }, { 0, 0, 0 }, BURLAP_DARK, "Fabric"),
	gear("Wrap", "LeftLowerArm", { 1.08, 0.60, 1.08 }, { 0, -0.24, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	gear("Wrap", "RightLowerArm", { 1.08, 0.60, 1.08 }, { 0, -0.24, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	gear("LegWrap", "LeftLowerLeg", { 1.06, 0.50, 1.06 }, { 0, -0.30, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),
	gear("LegWrap", "RightLowerLeg", { 1.06, 0.50, 1.06 }, { 0, -0.30, 0 }, { 0, 0, 0 }, ROPE, "Fabric"),

	-- Poste e base: presos ao LowerTorso, que fica 2,392 studs acima da sola.
	-- Por isso os offsets em Y são negativos e grandes — é o chão visto de lá.
	gear(
		"Post",
		"LowerTorso",
		{ 3.40, 0.42, 0.42 },
		{ 0, -0.69, 0.75 },
		{ 0, 0, 90 },
		WOOD,
		"Wood",
		"Part",
		"Cylinder"
	),
	gear(
		"Base",
		"LowerTorso",
		{ 0.22, 3.00, 3.00 },
		{ 0, -2.28, 0.20 },
		{ 0, 0, 90 },
		WOOD,
		"WoodPlanks",
		"Part",
		"Cylinder"
	),
}

local Rigs: { [string]: RigRecipe } = {
	npc_threshold_instructor = {
		npcId = "npc_threshold_instructor",
		skinRgb = { 226, 205, 194 },
		bodyRgb = COAT,
		legRgb = COAT_DARK,
		bodyMaterial = "Fabric",
		legMaterial = "Leather",
		faceTexture = "rbxasset://textures/face.png",
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

function Presentation.rigFor(npcId: string): RigRecipe?
	return Rigs[npcId]
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
		if not validRgb(recipe.bodyRgb) or not validRgb(recipe.accentRgb) or not validRgb(recipe.coreRgb) then
			return false, "invalid_rgb:" .. npcId
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
	return Presentation.validateRigs()
end

-- Os dois bots do spawn precisam de skin de rig; sem ela o WorldService cai no
-- corpo greybox de Parts e o jogador vê de novo a caixa com esfera na cabeça.
local RIG_REQUIRED: { string } = { "npc_threshold_instructor", "npc_training_dummy" }

function Presentation.validateRigs(): (boolean, string?)
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

-- Plano do rosto da cabeça R15 (metade da profundidade de 1,161) e topo da
-- faixa dos olhos na textura clássica, ambos no referencial da cabeça.
local FACE_PLANE_Z = -0.581
local EYE_BAND_TOP = 0.28

-- Cabelo e capuz não podem tapar os olhos. A regra é geométrica: se a peça
-- avança na frente do plano do rosto, ela TEM de ficar inteira acima da faixa
-- dos olhos. Peça que fica atrás do plano some dentro da malha da cabeça e não
-- ocluí nada, então está liberada.
--
-- Sem isto, a franja escorrega alguns centésimos para baixo numa edição de
-- ajuste fino e o instrutor volta a ser um vulto encapuzado sem cara — que é
-- metade da razão de o boneco antigo parecer feio.
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

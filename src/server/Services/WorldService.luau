--!strict
-- WorldService (server) — F0 (docs/13-F0-SLICE.md §8)
-- Constrói o greybox no Studio a partir de `Zones.luau`: chão, rotas, muros,
-- portões, planície, cratera, marcos e atores low-poly funcionais, além dos
-- collision groups `Safe` / `Transition` / `Free` / `GateBlock`.
--
-- ATENÇÃO — esta é a ÚNICA camada da fatia que toca Instances, e por isso é a
-- única que os testes Lune não cobrem. Ela não tem regra de jogo: é tradução
-- de dados em parts. Toda decisão (qual zona, o que bloqueia, quanto anda)
-- vive em `Zones.luau`, `Geometry.luau` e `SpatialService`, que são testados.
-- Se algo aqui precisar de um `if` de gameplay, o `if` está no lugar errado.
--
-- Arte final proibida até P1 (§17): nenhuma silhueta/roupa/VFX copiada de obra
-- de referência, nada comprado, nada subido para o catálogo. O que mudou em
-- 2026-08-14: os dois bots do spawn deixaram de ser Parts empilhadas e passaram
-- a usar o RIG R15 OFICIAL do Roblox (`Players:CreateHumanoidModelFrom-
-- Description`) como corpo, com a roupa vindo de `WorldPresentation.rigFor`.
-- O rig padrão não é arte de referência nem asset de terceiro: é o boneco que
-- o engine já entrega a todo lugar. Um corpo com proporção de gente é o que
-- separa "personagem" de "caixa com uma esfera em cima" — e era essa a
-- reclamação do playtest. O caminho antigo em Parts continua aqui como
-- FALLBACK, para o mundo nunca nascer sem NPC se a criação do rig falhar.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

export type WorldDeps = {
	zones: any,
	greybox: any,
	presentation: any,
	spawnDecorations: any,
}

export type ActorVisual = {
	model: Model,
	lastPosition: Vector3?,
	lastLookVector: Vector3?,
	rootHeight: number,
	moving: boolean,
}

local WorldService = {
	deps = nil :: WorldDeps?,
	root = nil :: Folder?,
	actors = {} :: { [string]: ActorVisual },
}

local GROUND_Y = 0
local FLOOR_THICKNESS = 2

local COLORS = {
	bastion = Color3.fromRGB(196, 196, 188),
	plain = Color3.fromRGB(120, 110, 96),
	wall = Color3.fromRGB(150, 150, 145),
	transition = Color3.fromRGB(230, 190, 90),
	crater = Color3.fromRGB(100, 92, 84),
	anchor = Color3.fromRGB(90, 160, 220),
	path = Color3.fromRGB(168, 158, 139),
	darkStone = Color3.fromRGB(82, 85, 88),
	lightStone = Color3.fromRGB(205, 201, 187),
	boundary = Color3.fromRGB(232, 224, 196),
}

local function toColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function registerCollisionGroups(groups: { string }): ()
	for _, name in groups do
		local ok = pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
		if not ok then
			-- Grupo já registrado (reentrância do bootstrap em Studio).
			continue
		end
	end
end

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	collisionGroup: string,
	canCollide: boolean
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanTouch = not canCollide
	part.CanQuery = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CastShadow = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not canCollide then
		part.Transparency = 0.75
	end
	part.CollisionGroup = collisionGroup
	return part
end

local function makeVisualPart(
	className: "Part" | "WedgePart",
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function attach(root: BasePart, part: BasePart, offset: CFrame, jointName: string): ()
	part.CFrame = root.CFrame * offset
	part.Parent = root.Parent
	local joint = Instance.new("Motor6D")
	joint.Name = jointName
	joint.Part0 = root
	joint.Part1 = part
	joint.C0 = offset
	joint.Parent = root
end

local function actorRootHeight(recipe: any): number
	if recipe.shape == "humanoid" then
		-- A sola fica em -3,4 na receita humanoide: 2,2 de deslocamento mais
		-- metade da perna de 2,4. Derivar daqui evita enterrar pés no chão.
		return 3.4 * recipe.scale
	end
	return 3 * recipe.scale
end

-- `bodyTopOffset` é a altura do topo do corpo em relação à Root, quando ela é
-- conhecida (corpo de rig). Sem ela cai no orçamento antigo do greybox.
local function buildTelegraphPresentation(model: Model, root: BasePart, rootHeight: number, bodyTopOffset: number?): ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "TelegraphHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Enabled = false
	highlight.Parent = model

	-- O ponto de exclamação mantém o aviso reconhecível sem depender de cor.
	local symbol = Instance.new("BillboardGui")
	symbol.Name = "TelegraphSymbol"
	symbol.Adornee = root
	symbol.AlwaysOnTop = true
	symbol.LightInfluence = 0
	symbol.MaxDistance = 80
	symbol.Size = UDim2.fromOffset(48, 48)
	symbol.StudsOffsetWorldSpace = Vector3.new(0, (if bodyTopOffset then bodyTopOffset + 0.9 else rootHeight + 1.4), 0)
	symbol.Enabled = false
	symbol.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "Symbol"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "!"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(25, 25, 28)
	label.TextStrokeTransparency = 0
	label.Parent = symbol
end

local function setTelegraphVisible(model: Model, visible: boolean, visualPattern: string?): ()
	local highlight = model:FindFirstChild("TelegraphHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.Enabled = visible
	end
	local symbol = model:FindFirstChild("TelegraphSymbol")
	if symbol and symbol:IsA("BillboardGui") then
		symbol.Enabled = visible
		local label = symbol:FindFirstChild("Symbol")
		if label and label:IsA("TextLabel") then
			label.Text = if visualPattern == "slam" then "!!" else "!"
		end
	end
end

local function setActorVisible(model: Model, visible: boolean): ()
	for _, descendant in model:GetDescendants() do
		-- `AvbInvisible` é como a HumanoidRootPart do corpo de rig se declara:
		-- sem isso, "tornar visível" acenderia a caixa 2×2×1 dentro do peito.
		if
			descendant:IsA("BasePart")
			and descendant.Name ~= "Root"
			and descendant.Name ~= "VisualRoot"
			and descendant:GetAttribute("AvbInvisible") ~= true
		then
			descendant.Transparency = if visible then 0 else 1
		end
	end
	if not visible then
		setTelegraphVisible(model, false, nil)
	end
	local actorId = model:GetAttribute("ActorId")
	local root = model.PrimaryPart
	if root and type(actorId) == "string" and string.find(actorId, "@", 1, true) then
		root:SetAttribute("CombatTarget", visible)
	end
end

local HAIR_COLOR = Color3.fromRGB(24, 22, 34)
local EYE_WHITE = Color3.fromRGB(250, 248, 255)
local PUPIL_COLOR = Color3.fromRGB(16, 12, 24)
local STRAW_COLOR = Color3.fromRGB(201, 172, 92)
local WOOD_COLOR = Color3.fromRGB(96, 70, 40)
local STITCH_COLOR = Color3.fromRGB(42, 36, 32)
local PLAZA = Vector3.new(0, 0, 20)

local function makeBall(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = makeVisualPart("Part", name, size, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Humanoides estáticos olham para a praça: senão o jogador vê as costas e
-- o "peito" vira as costas do modelo (Front = −Z).
local function plazaLookCFrame(position: Vector3, rootHeight: number): CFrame
	local rootPos = position + Vector3.new(0, rootHeight, 0)
	local toPlaza = Vector3.new(PLAZA.X - position.X, 0, PLAZA.Z - position.Z)
	local look = if toPlaza.Magnitude > 1e-3 then toPlaza.Unit else Vector3.new(0, 0, 1)
	return CFrame.lookAt(rootPos, rootPos + look)
end

local function dressInstructorFace(head: BasePart, scale: number, irisColor: Color3): ()
	local function eye(name: string, x: number, joint: string)
		local white = makeBall(name, Vector3.new(0.36, 0.42, 0.18) * scale, EYE_WHITE, Enum.Material.SmoothPlastic)
		attach(head, white, CFrame.new(x * scale, 0.12 * scale, -0.66 * scale), joint)
		local iris = makeBall(name .. "Iris", Vector3.new(0.22, 0.28, 0.12) * scale, irisColor, Enum.Material.Neon)
		attach(white, iris, CFrame.new(0, 0, -0.06 * scale), joint .. "Iris")
		local pupil =
			makeBall(name .. "Pupil", Vector3.new(0.1, 0.14, 0.08) * scale, PUPIL_COLOR, Enum.Material.SmoothPlastic)
		attach(iris, pupil, CFrame.new(0, 0, -0.04 * scale), joint .. "Pupil")
	end
	eye("EyeL", -0.28, "Joint_EyeL")
	eye("EyeR", 0.28, "Joint_EyeR")

	local browL =
		makeVisualPart("Part", "Brow", Vector3.new(0.4, 0.08, 0.1) * scale, HAIR_COLOR, Enum.Material.SmoothPlastic)
	attach(
		head,
		browL,
		CFrame.new(-0.28 * scale, 0.38 * scale, -0.64 * scale) * CFrame.Angles(0, 0, math.rad(10)),
		"Joint_BrowL"
	)
	local browR = browL:Clone()
	browR.Name = "Brow"
	attach(
		head,
		browR,
		CFrame.new(0.28 * scale, 0.38 * scale, -0.64 * scale) * CFrame.Angles(0, 0, math.rad(-10)),
		"Joint_BrowR"
	)

	local mouth = makeVisualPart(
		"Part",
		"Mouth",
		Vector3.new(0.34, 0.07, 0.08) * scale,
		Color3.fromRGB(92, 72, 90),
		Enum.Material.SmoothPlastic
	)
	attach(head, mouth, CFrame.new(0, -0.3 * scale, -0.68 * scale), "Joint_Mouth")
end

local function dressDummyFace(head: BasePart, scale: number): ()
	local function button(name: string, x: number, joint: string)
		local eye = makeBall(name, Vector3.new(0.3, 0.3, 0.16) * scale, STITCH_COLOR, Enum.Material.SmoothPlastic)
		attach(head, eye, CFrame.new(x * scale, 0.12 * scale, -0.68 * scale), joint)
		local glint =
			makeBall(name .. "Glint", Vector3.new(0.1, 0.1, 0.06) * scale, EYE_WHITE, Enum.Material.SmoothPlastic)
		attach(eye, glint, CFrame.new(-0.05 * scale, 0.05 * scale, -0.06 * scale), joint .. "Glint")
	end
	button("EyeL", -0.3, "Joint_EyeL")
	button("EyeR", 0.3, "Joint_EyeR")

	local mouth =
		makeVisualPart("Part", "Mouth", Vector3.new(0.46, 0.09, 0.09) * scale, STITCH_COLOR, Enum.Material.Fabric)
	attach(head, mouth, CFrame.new(0, -0.3 * scale, -0.7 * scale), "Joint_Mouth")
end

local function dressThresholdInstructor(
	torso: BasePart,
	head: BasePart,
	leftArm: BasePart,
	rightArm: BasePart,
	leftLeg: BasePart,
	rightLeg: BasePart,
	scale: number,
	bodyColor: Color3,
	accentColor: Color3,
	coreColor: Color3
): ()
	torso.Material = Enum.Material.Fabric
	leftArm.Material = Enum.Material.Leather
	rightArm.Material = Enum.Material.Leather
	leftLeg.Material = Enum.Material.Leather
	rightLeg.Material = Enum.Material.Leather

	dressInstructorFace(head, scale, accentColor)

	local hairCap = makeBall("HairCap", Vector3.new(1.62, 1.05, 1.48) * scale, HAIR_COLOR, Enum.Material.Fabric)
	attach(head, hairCap, CFrame.new(0, 0.4 * scale, 0.1 * scale), "Joint_HairCap")
	local bangL =
		makeVisualPart("WedgePart", "Bang", Vector3.new(0.42, 0.55, 0.32) * scale, HAIR_COLOR, Enum.Material.Fabric)
	attach(
		head,
		bangL,
		CFrame.new(-0.38 * scale, 0.48 * scale, -0.52 * scale) * CFrame.Angles(math.rad(-22), math.rad(-20), 0),
		"Joint_BangL"
	)
	local bangR = bangL:Clone()
	bangR.Name = "Bang"
	attach(
		head,
		bangR,
		CFrame.new(0.38 * scale, 0.48 * scale, -0.52 * scale) * CFrame.Angles(math.rad(-22), math.rad(20), 0),
		"Joint_BangR"
	)
	local bangM =
		makeVisualPart("WedgePart", "Bang", Vector3.new(0.36, 0.4, 0.26) * scale, HAIR_COLOR, Enum.Material.Fabric)
	attach(head, bangM, CFrame.new(0, 0.55 * scale, -0.55 * scale) * CFrame.Angles(math.rad(-30), 0, 0), "Joint_BangM")

	-- Capuz em volta da cabeça, abertura na Frente (−Z) para o rosto aparecer.
	local hoodBack =
		makeVisualPart("Part", "HoodBack", Vector3.new(1.78, 1.6, 0.72) * scale, accentColor, Enum.Material.Leather)
	attach(head, hoodBack, CFrame.new(0, 0.22 * scale, 0.58 * scale), "Joint_HoodBack")
	local hoodTop =
		makeVisualPart("Part", "HoodTop", Vector3.new(1.72, 0.48, 1.58) * scale, accentColor, Enum.Material.Leather)
	attach(head, hoodTop, CFrame.new(0, 0.82 * scale, 0.14 * scale), "Joint_HoodTop")
	local hoodL =
		makeVisualPart("Part", "HoodSide", Vector3.new(0.36, 1.48, 1.32) * scale, accentColor, Enum.Material.Leather)
	attach(head, hoodL, CFrame.new(-0.86 * scale, 0.2 * scale, 0.1 * scale), "Joint_HoodL")
	local hoodR = hoodL:Clone()
	hoodR.Name = "HoodSide"
	attach(head, hoodR, CFrame.new(0.86 * scale, 0.2 * scale, 0.1 * scale), "Joint_HoodR")
	local hoodRim =
		makeVisualPart("Part", "HoodRim", Vector3.new(1.74, 0.12, 1.38) * scale, accentColor, Enum.Material.Neon)
	attach(head, hoodRim, CFrame.new(0, 0.74 * scale, -0.28 * scale), "Joint_HoodRim")

	local collar =
		makeVisualPart("Part", "Collar", Vector3.new(1.42, 0.36, 1.12) * scale, bodyColor, Enum.Material.Fabric)
	attach(torso, collar, CFrame.new(0, 1.22 * scale, 0), "Joint_Collar")
	local collarTrim =
		makeVisualPart("Part", "CollarTrim", Vector3.new(1.5, 0.1, 1.2) * scale, accentColor, Enum.Material.Neon)
	attach(collar, collarTrim, CFrame.new(0, 0.16 * scale, 0), "Joint_CollarTrim")

	local shoulderL =
		makeVisualPart("Part", "Shoulder", Vector3.new(1.18, 0.52, 1.42) * scale, bodyColor, Enum.Material.Fabric)
	attach(
		torso,
		shoulderL,
		CFrame.new(-1.22 * scale, 1.02 * scale, 0) * CFrame.Angles(0, 0, math.rad(14)),
		"Joint_ShoulderL"
	)
	local shoulderR = shoulderL:Clone()
	shoulderR.Name = "Shoulder"
	attach(
		torso,
		shoulderR,
		CFrame.new(1.22 * scale, 1.02 * scale, 0) * CFrame.Angles(0, 0, math.rad(-14)),
		"Joint_ShoulderR"
	)
	local pauldronL =
		makeVisualPart("Part", "Pauldron", Vector3.new(1.08, 0.18, 1.5) * scale, accentColor, Enum.Material.Neon)
	attach(shoulderL, pauldronL, CFrame.new(0, 0.3 * scale, 0), "Joint_PauldronL")
	local pauldronR = pauldronL:Clone()
	pauldronR.Name = "Pauldron"
	attach(shoulderR, pauldronR, CFrame.new(0, 0.3 * scale, 0), "Joint_PauldronR")

	local sleeveL =
		makeVisualPart("Part", "Sleeve", Vector3.new(0.98, 1.2, 0.98) * scale, bodyColor, Enum.Material.Fabric)
	attach(leftArm, sleeveL, CFrame.new(0, 0.42 * scale, 0), "Joint_SleeveL")
	local sleeveR = sleeveL:Clone()
	sleeveR.Name = "Sleeve"
	attach(rightArm, sleeveR, CFrame.new(0, 0.42 * scale, 0), "Joint_SleeveR")

	local coatBottom =
		makeVisualPart("Part", "CoatBottom", Vector3.new(2.55, 1.2, 1.4) * scale, bodyColor, Enum.Material.Fabric)
	attach(torso, coatBottom, CFrame.new(0, -1.35 * scale, 0.08 * scale), "Joint_CoatBottom")
	local hem = makeVisualPart("Part", "Hem", Vector3.new(2.62, 0.16, 1.46) * scale, accentColor, Enum.Material.Neon)
	attach(torso, hem, CFrame.new(0, -1.9 * scale, 0.08 * scale), "Joint_Hem")
	local tailL =
		makeVisualPart("Part", "CoatTail", Vector3.new(1.12, 1.95, 0.42) * scale, bodyColor, Enum.Material.Fabric)
	attach(
		torso,
		tailL,
		CFrame.new(-0.52 * scale, -1.78 * scale, 0.58 * scale) * CFrame.Angles(math.rad(16), 0, math.rad(-6)),
		"Joint_CoatTailL"
	)
	local tailR = tailL:Clone()
	tailR.Name = "CoatTail"
	attach(
		torso,
		tailR,
		CFrame.new(0.52 * scale, -1.78 * scale, 0.58 * scale) * CFrame.Angles(math.rad(16), 0, math.rad(6)),
		"Joint_CoatTailR"
	)

	local emblem =
		makeVisualPart("Part", "Emblem", Vector3.new(0.58, 0.72, 0.16) * scale, accentColor, Enum.Material.Neon)
	attach(torso, emblem, CFrame.new(0, 0.38 * scale, -0.64 * scale), "Joint_Emblem")
	local emblemCore =
		makeVisualPart("Part", "EmblemCore", Vector3.new(0.28, 0.28, 0.12) * scale, coreColor, Enum.Material.Neon)
	attach(emblem, emblemCore, CFrame.new(0, 0, -0.05 * scale), "Joint_EmblemCore")

	local belt = makeVisualPart("Part", "Belt", Vector3.new(1.78, 0.34, 1.28) * scale, accentColor, Enum.Material.Neon)
	attach(torso, belt, CFrame.new(0, -0.55 * scale, 0), "Joint_Belt")
	local buckle =
		makeVisualPart("Part", "Buckle", Vector3.new(0.42, 0.48, 0.18) * scale, coreColor, Enum.Material.Neon)
	attach(belt, buckle, CFrame.new(0, 0, -0.72 * scale), "Joint_Buckle")

	local cuffL = makeVisualPart("Part", "Cuff", Vector3.new(0.86, 0.22, 0.86) * scale, accentColor, Enum.Material.Neon)
	attach(leftArm, cuffL, CFrame.new(0, -0.82 * scale, 0), "Joint_CuffL")
	local cuffR = cuffL:Clone()
	cuffR.Name = "Cuff"
	attach(rightArm, cuffR, CFrame.new(0, -0.82 * scale, 0), "Joint_CuffR")
	local handL = makeVisualPart("Part", "Hand", Vector3.new(0.74, 0.36, 0.74) * scale, bodyColor, Enum.Material.Fabric)
	attach(leftArm, handL, CFrame.new(0, -1.08 * scale, 0), "Joint_HandL")
	local handR = handL:Clone()
	handR.Name = "Hand"
	attach(rightArm, handR, CFrame.new(0, -1.08 * scale, 0), "Joint_HandR")

	local bootL =
		makeVisualPart("Part", "Boot", Vector3.new(1.02, 0.62, 1.18) * scale, bodyColor, Enum.Material.Leather)
	attach(leftLeg, bootL, CFrame.new(0, -0.95 * scale, -0.08 * scale), "Joint_BootL")
	local bootR = bootL:Clone()
	bootR.Name = "Boot"
	attach(rightLeg, bootR, CFrame.new(0, -0.95 * scale, -0.08 * scale), "Joint_BootR")
end

local function dressTrainingDummy(
	root: BasePart,
	torso: BasePart,
	head: BasePart,
	leftArm: BasePart,
	rightArm: BasePart,
	leftLeg: BasePart,
	rightLeg: BasePart,
	scale: number,
	_bodyColor: Color3,
	accentColor: Color3,
	coreColor: Color3
): ()
	torso.Material = Enum.Material.Leather
	leftLeg.Material = Enum.Material.Leather
	rightLeg.Material = Enum.Material.Leather
	leftArm.Material = Enum.Material.Leather
	rightArm.Material = Enum.Material.Leather

	local model = root.Parent
	local neck = if model then model:FindFirstChild("Neck") else nil
	if neck and neck:IsA("BasePart") then
		neck.Material = Enum.Material.Wood
		neck.Color = WOOD_COLOR
	end

	dressDummyFace(head, scale)

	local tuftL =
		makeVisualPart("WedgePart", "Straw", Vector3.new(0.3, 0.72, 0.24) * scale, STRAW_COLOR, Enum.Material.Grass)
	attach(
		head,
		tuftL,
		CFrame.new(-0.4 * scale, 0.78 * scale, -0.12 * scale) * CFrame.Angles(0, math.rad(-12), math.rad(-22)),
		"Joint_StrawL"
	)
	local tuftR = tuftL:Clone()
	tuftR.Name = "Straw"
	attach(
		head,
		tuftR,
		CFrame.new(0.4 * scale, 0.78 * scale, -0.12 * scale) * CFrame.Angles(0, math.rad(12), math.rad(22)),
		"Joint_StrawR"
	)
	local tuftM =
		makeVisualPart("WedgePart", "Straw", Vector3.new(0.28, 0.62, 0.22) * scale, STRAW_COLOR, Enum.Material.Grass)
	attach(head, tuftM, CFrame.new(0, 0.88 * scale, 0.05 * scale) * CFrame.Angles(math.rad(-8), 0, 0), "Joint_StrawM")

	local stitchA =
		makeVisualPart("Part", "Stitch", Vector3.new(0.1, 1.15, 0.1) * scale, STITCH_COLOR, Enum.Material.Fabric)
	attach(
		torso,
		stitchA,
		CFrame.new(-0.35 * scale, 0.15 * scale, -0.56 * scale) * CFrame.Angles(0, 0, math.rad(18)),
		"Joint_StitchA"
	)
	local stitchB = stitchA:Clone()
	stitchB.Name = "Stitch"
	attach(
		torso,
		stitchB,
		CFrame.new(0.35 * scale, 0.05 * scale, -0.56 * scale) * CFrame.Angles(0, 0, math.rad(-16)),
		"Joint_StitchB"
	)

	local belt =
		makeVisualPart("Part", "Belt", Vector3.new(1.78, 0.36, 1.28) * scale, accentColor, Enum.Material.Leather)
	attach(torso, belt, CFrame.new(0, -0.75 * scale, 0), "Joint_Belt")
	local buckle =
		makeVisualPart("Part", "Buckle", Vector3.new(0.4, 0.44, 0.16) * scale, WOOD_COLOR, Enum.Material.Wood)
	attach(belt, buckle, CFrame.new(0, 0, -0.7 * scale), "Joint_Buckle")

	local wrapLeft =
		makeVisualPart("Part", "Wrap", Vector3.new(0.82, 0.72, 0.82) * scale, coreColor, Enum.Material.Fabric)
	attach(leftArm, wrapLeft, CFrame.new(0, -0.55 * scale, 0), "Joint_WrapLeft")
	local wrapRight = wrapLeft:Clone()
	wrapRight.Name = "Wrap"
	attach(rightArm, wrapRight, CFrame.new(0, -0.55 * scale, 0), "Joint_WrapRight")

	local bootLeft =
		makeVisualPart("Part", "Boot", Vector3.new(0.98, 0.58, 1.1) * scale, accentColor, Enum.Material.Leather)
	attach(leftLeg, bootLeft, CFrame.new(0, -0.85 * scale, -0.06 * scale), "Joint_BootLeft")
	local bootRight = bootLeft:Clone()
	bootRight.Name = "Boot"
	attach(rightLeg, bootRight, CFrame.new(0, -0.85 * scale, -0.06 * scale), "Joint_BootRight")

	-- Disco no peito (eixo do Cylinder = X; yaw 90° aponta a face para a Frente).
	local target =
		makeVisualPart("Part", "Target", Vector3.new(0.16, 1.2, 1.2) * scale, coreColor, Enum.Material.SmoothPlastic)
	target.Shape = Enum.PartType.Cylinder
	attach(
		torso,
		target,
		CFrame.new(0, 0.22 * scale, -0.64 * scale) * CFrame.Angles(0, math.rad(90), 0),
		"Joint_Target"
	)
	local ring = makeVisualPart(
		"Part",
		"Ring",
		Vector3.new(0.18, 0.82, 0.82) * scale,
		Color3.fromRGB(255, 82, 82),
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	attach(target, ring, CFrame.new(-0.02 * scale, 0, 0), "Joint_Ring")
	local core = makeVisualPart("Part", "Core", Vector3.new(0.2, 0.42, 0.42) * scale, coreColor, Enum.Material.Neon)
	core.Shape = Enum.PartType.Cylinder
	attach(ring, core, CFrame.new(-0.02 * scale, 0, 0), "Joint_Core")

	local base = makeVisualPart(
		"Part",
		"Base",
		Vector3.new(0.22, 3.0, 3.0) * scale,
		Color3.fromRGB(139, 105, 60),
		Enum.Material.WoodPlanks
	)
	base.Shape = Enum.PartType.Cylinder
	attach(root, base, CFrame.new(0, -3.3 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), "Joint_Base")
	local post = makeVisualPart("Part", "Post", Vector3.new(3.2, 0.42, 0.42) * scale, WOOD_COLOR, Enum.Material.Wood)
	post.Shape = Enum.PartType.Cylinder
	attach(root, post, CFrame.new(0, -1.55 * scale, 1.12 * scale) * CFrame.Angles(0, 0, math.rad(90)), "Joint_Post")
end

-- ── Corpo de rig R15 ────────────────────────────────────────────────────────
-- Materialização pura da receita de `WorldPresentation.rigFor`. Nenhuma decisão
-- de aparência mora aqui: tamanho, encaixe, cor e material vêm do dado, que é
-- validado por teste Lune. Aqui só há Instance.

local RIG_LIMBS: { string } = {
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
}

local RIG_LEGS: { string } = {
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot",
}

local RIG_SKIN: { string } = { "Head", "LeftHand", "RightHand" }

local function materialOf(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	return if typeof(material) == "EnumItem" then material else Enum.Material.SmoothPlastic
end

-- Peças do rig não participam de física nem de query: quem responde por
-- colisão, alvo e alcance continua sendo a Root ancorada do ator.
local function tameRigPart(part: BasePart): ()
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
end

local function paintRig(rig: Model, names: { string }, color: Color3, material: Enum.Material): ()
	for _, partName in names do
		local part = rig:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = color
			part.Material = material
			tameRigPart(part)
		end
	end
end

local function dressRig(rig: Model, rigRecipe: any): ()
	for _, piece in rigRecipe.gear do
		local host = rig:FindFirstChild(piece.host)
		if not host or not host:IsA("BasePart") then
			continue
		end
		local part = Instance.new(piece.class) :: BasePart
		part.Name = piece.name
		part.Size = Vector3.new(piece.sizeStuds[1], piece.sizeStuds[2], piece.sizeStuds[3])
		part.Color = toColor(piece.rgb)
		part.Material = materialOf(piece.material)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		tameRigPart(part)
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end

		local offset = CFrame.new(piece.offsetStuds[1], piece.offsetStuds[2], piece.offsetStuds[3])
			* CFrame.Angles(
				math.rad(piece.rotationDegrees[1]),
				math.rad(piece.rotationDegrees[2]),
				math.rad(piece.rotationDegrees[3])
			)
		part.CFrame = host.CFrame * offset
		part.Parent = rig

		-- Weld rígido, não Motor6D: roupa acompanha o membro, mas não é junta —
		-- o ActorAnimator não deve poder posar uma manga como se fosse braço.
		local weld = Instance.new("Weld")
		weld.Name = "GearWeld"
		weld.Part0 = host
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
	end
end

-- Distância entre a HumanoidRootPart e a sola. NÃO é `Humanoid.HipHeight`:
-- medido no Studio, com as escalas da receita o pé fica 3,607 studs abaixo da
-- HRP enquanto o HipHeight vale ~2,2. Usar o HipHeight enterraria o boneco mais
-- de um stud no chão. Derivar do rig real mantém isso certo quando a proporção
-- muda; o número fixo é só o último recurso.
local RIG_SOLE_DROP_FALLBACK = 3.607

local function rigSoleDrop(rig: Model): number
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return RIG_SOLE_DROP_FALLBACK
	end
	local lowest: number? = nil
	for _, footName in { "LeftFoot", "RightFoot" } do
		local foot = rig:FindFirstChild(footName)
		if foot and foot:IsA("BasePart") then
			local bottom = foot.Position.Y - foot.Size.Y / 2
			lowest = if lowest then math.min(lowest, bottom) else bottom
		end
	end
	if not lowest then
		return RIG_SOLE_DROP_FALLBACK
	end
	return hrp.Position.Y - lowest
end

-- Constrói o corpo de rig e o solda na Root ancorada. Devolve a altura do topo
-- do corpo em relação à Root (para o aviso de telegraph ficar logo acima da
-- cabeça), ou nil se o rig não pôde ser criado — aí o chamador usa o greybox.
local function buildRigBody(model: Model, root: BasePart, rigRecipe: any, rootHeight: number): number?
	local ok, rig = pcall(function()
		local description = Instance.new("HumanoidDescription")
		-- Proporção vem da receita. `BodyTypeScale = 1` puxa o corpo para o
		-- Rthro (tronco alongado, membro afilado) em vez do boneco cúbico
		-- clássico — é metade da resposta ao "muito quadrado" do playtest; a
		-- outra metade é a roupa em elipsoides e anéis.
		local scales = rigRecipe.scales
		description.BodyTypeScale = scales.bodyType
		description.ProportionScale = scales.proportion
		description.HeadScale = scales.head
		description.WidthScale = scales.width
		description.HeightScale = scales.height
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(rig) ~= "Instance" or not rig:IsA("Model") then
		warn(("[WorldService] rig R15 indisponível (%s) — corpo greybox assume"):format(tostring(rig)))
		return nil
	end

	rig.Name = "Body"
	local animate = rig:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- NPC de apresentação: sem nome flutuante, sem barra de vida, sem
		-- máquina de estados (que tentaria andar, cair e morrer sozinha).
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.EvaluateStateMachine = false
	end

	paintRig(rig, RIG_LIMBS, toColor(rigRecipe.bodyRgb), materialOf(rigRecipe.bodyMaterial))
	paintRig(rig, RIG_LEGS, toColor(rigRecipe.legRgb), materialOf(rigRecipe.legMaterial))
	paintRig(rig, RIG_SKIN, toColor(rigRecipe.skinRgb), Enum.Material.SmoothPlastic)

	local head = rig:FindFirstChild("Head")
	if head and head:IsA("BasePart") and rigRecipe.faceTexture then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = rigRecipe.faceTexture
		face.Parent = head
	end

	dressRig(rig, rigRecipe)

	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		rig:Destroy()
		return nil
	end
	hrp:SetAttribute("AvbInvisible", true)

	local yOffset = rigSoleDrop(rig) - rootHeight
	local anchorCFrame = CFrame.new(0, yOffset, 0)
	rig:PivotTo(root.CFrame * anchorCFrame)
	-- Alvo do assentamento (ver `settleRigBodies`): a sola tem de parar aqui.
	rig:SetAttribute("AvbGroundY", root.Position.Y - rootHeight)

	-- A Root ancorada continua sendo a única coisa que o servidor move; o rig
	-- inteiro é um assembly soldado nela, então não precisa de âncora própria
	-- e não briga com a física.
	local weld = Instance.new("Weld")
	weld.Name = "RigWeld"
	weld.Part0 = root
	weld.Part1 = hrp
	weld.C0 = anchorCFrame
	weld.Parent = hrp

	rig.Parent = model

	local bodyCFrame, bodySize = rig:GetBoundingBox()
	return (bodyCFrame.Position.Y + bodySize.Y / 2) - root.Position.Y
end

local function createActorModel(
	name: string,
	actorId: string,
	npcId: string,
	recipe: any,
	position: Vector3,
	rigRecipe: any?
): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("PresentationActor", true)
	model:SetAttribute("ActorId", actorId)
	model:SetAttribute("NpcId", npcId)
	model:SetAttribute("SkinId", recipe.skinNameKey or npcId)
	model:SetAttribute("PoseKind", "spawn")
	model:SetAttribute("Moving", false)

	local scale = recipe.scale
	local root = makeVisualPart("Part", "Root", Vector3.new(1, 1, 1), COLORS.darkStone, Enum.Material.SmoothPlastic)
	root.Anchored = true
	root.Transparency = 1
	local rootHeight = actorRootHeight(recipe)
	if recipe.shape == "humanoid" then
		root.CFrame = plazaLookCFrame(position, rootHeight)
	else
		root.CFrame = CFrame.new(position + Vector3.new(0, rootHeight, 0))
	end
	root.Parent = model
	model.PrimaryPart = root

	local bodyColor = toColor(recipe.bodyRgb)
	local accentColor = toColor(recipe.accentRgb)
	local coreColor = toColor(recipe.coreRgb)
	local auraColor = toColor(recipe.auraRgb or recipe.coreRgb)
	local auraScale = recipe.auraScale or 1
	-- Topo do corpo em relação à Root: com o rig R15 a cabeça termina bem mais
	-- baixo que a torre de Parts antiga, e o "!" de telegraph precisa saber
	-- disso para não ficar boiando três studs acima de ninguém.
	local bodyTopOffset: number? = nil
	if recipe.shape == "humanoid" and rigRecipe then
		bodyTopOffset = buildRigBody(model, root, rigRecipe, rootHeight)
	end
	if recipe.shape == "humanoid" and bodyTopOffset == nil then
		local torso =
			makeVisualPart("Part", "Torso", Vector3.new(2.25, 2.45, 1.2) * scale, bodyColor, Enum.Material.Slate)
		attach(root, torso, CFrame.new(0, 0.1, 0), "Joint_Torso")

		-- Cabeça = Part esférica. FileMesh com rbxassetid some se o asset não
		-- carrega — era isso que deixava os NPCs sem cabeça no Play.
		local head = makeBall("Head", Vector3.new(1.55, 1.55, 1.55) * scale, coreColor, Enum.Material.SmoothPlastic)
		attach(torso, head, CFrame.new(0, 2.08 * scale, 0), "Joint_Head")
		local neck =
			makeVisualPart("Part", "Neck", Vector3.new(0.62, 0.4, 0.62) * scale, coreColor, Enum.Material.SmoothPlastic)
		attach(torso, neck, CFrame.new(0, 1.38 * scale, 0), "Joint_Neck")

		local leftArm =
			makeVisualPart("Part", "LeftArm", Vector3.new(0.75, 2.2, 0.75) * scale, accentColor, Enum.Material.Slate)
		attach(torso, leftArm, CFrame.new(-1.5 * scale, -0.05 * scale, 0), "Joint_LeftArm")
		local rightArm = leftArm:Clone()
		rightArm.Name = "RightArm"
		attach(torso, rightArm, CFrame.new(1.5 * scale, -0.05 * scale, 0), "Joint_RightArm")

		local leftLeg =
			makeVisualPart("Part", "LeftLeg", Vector3.new(0.88, 2.4, 0.92) * scale, bodyColor, Enum.Material.Slate)
		attach(root, leftLeg, CFrame.new(-0.58 * scale, -2.2 * scale, 0), "Joint_LeftLeg")
		local rightLeg = leftLeg:Clone()
		rightLeg.Name = "RightLeg"
		attach(root, rightLeg, CFrame.new(0.58 * scale, -2.2 * scale, 0), "Joint_RightLeg")

		if npcId == "npc_threshold_instructor" then
			dressThresholdInstructor(
				torso,
				head,
				leftArm,
				rightArm,
				leftLeg,
				rightLeg,
				scale,
				bodyColor,
				accentColor,
				coreColor
			)
		elseif npcId == "npc_training_dummy" then
			dressTrainingDummy(
				root,
				torso,
				head,
				leftArm,
				rightArm,
				leftLeg,
				rightLeg,
				scale,
				bodyColor,
				accentColor,
				coreColor
			)
		end
	elseif recipe.shape ~= "humanoid" then
		-- Pivot visual comum: todas as peças do shard recebem bob/lean/spin sem
		-- deslocar o root autoritativo nem se separar umas das outras.
		local visualRoot = makeVisualPart(
			"Part",
			"VisualRoot",
			Vector3.new(0.2, 0.2, 0.2),
			COLORS.darkStone,
			Enum.Material.SmoothPlastic
		)
		visualRoot.Transparency = 1
		visualRoot.CastShadow = false
		attach(root, visualRoot, CFrame.identity, "Joint_VisualRoot")

		local torso =
			makeVisualPart("Part", "Torso", Vector3.new(2.2, 2.8, 1.6) * scale, bodyColor, Enum.Material.Slate)
		attach(visualRoot, torso, CFrame.Angles(0, 0, math.rad(45)), "Joint_Torso")
		local core =
			makeVisualPart("Part", "Core", Vector3.new(1.25, 1.25, 1.25) * scale, coreColor, Enum.Material.Neon)
		core.Shape = Enum.PartType.Ball
		attach(visualRoot, core, CFrame.new(0, 0, -0.75 * scale), "Joint_Core")
		local left = makeVisualPart(
			"WedgePart",
			"ShardLeft",
			Vector3.new(1.1, 2.7, 0.8) * scale,
			accentColor,
			Enum.Material.Slate
		)
		attach(
			visualRoot,
			left,
			CFrame.new(-1.35 * scale, 0.1, 0) * CFrame.Angles(0, 0, math.rad(28)),
			"Joint_ShardLeft"
		)
		local right = left:Clone()
		right.Name = "ShardRight"
		attach(
			visualRoot,
			right,
			CFrame.new(1.35 * scale, 0.1, 0) * CFrame.Angles(0, math.pi, math.rad(-28)),
			"Joint_ShardRight"
		)
		local top = makeVisualPart(
			"WedgePart",
			"ShardTop",
			Vector3.new(0.9, 2.2, 0.9) * scale,
			accentColor,
			Enum.Material.Slate
		)
		attach(visualRoot, top, CFrame.new(0, 2 * scale, 0), "Joint_ShardTop")

		-- ── Toques de skin dos estilhaços ──────────────────────────────────
		-- Halo de energia: anel Neon fino girando com o pivot visual (o
		-- ActorAnimator já roda o VisualRoot, então o anel "orbita" sozinho).
		local halo = makeVisualPart(
			"Part",
			"Halo",
			Vector3.new(0.14, 3.6 * scale * auraScale, 3.6 * scale * auraScale),
			auraColor,
			Enum.Material.Neon
		)
		halo.Shape = Enum.PartType.Cylinder
		attach(visualRoot, halo, CFrame.new(0, 0.2 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), "Joint_Halo")
		-- Cristais menores flanqueando o corpo: mais volume sem mudar a hitbox.
		local front = makeVisualPart(
			"WedgePart",
			"ShardFront",
			Vector3.new(0.55, 1.5, 0.55) * scale,
			accentColor,
			Enum.Material.Slate
		)
		attach(visualRoot, front, CFrame.new(0, -0.3 * scale, -1.7 * scale), "Joint_ShardFront")
		local back = front:Clone()
		back.Name = "ShardBack"
		attach(
			visualRoot,
			back,
			CFrame.new(0, -0.3 * scale, 1.7 * scale) * CFrame.Angles(0, math.pi, 0),
			"Joint_ShardBack"
		)
		-- Coroa do elite: três cunhas apontando para cima, a assinatura do
		-- Estilhaço Ancorado à distância.
		if npcId == "enemy_anchored_shard" then
			for crownIndex = 1, 3 do
				local angle = (crownIndex - 1) / 3 * math.pi * 2
				local crown = makeVisualPart(
					"WedgePart",
					("Crown_%d"):format(crownIndex),
					Vector3.new(0.5, 1.9, 0.5) * scale,
					accentColor,
					Enum.Material.Neon
				)
				attach(
					visualRoot,
					crown,
					CFrame.new(math.cos(angle) * 0.95 * scale, 3.1 * scale, math.sin(angle) * 0.95 * scale)
						* CFrame.Angles(0, -angle, math.rad(-28)),
					("Joint_Crown_%d"):format(crownIndex)
				)
			end
		end
	end

	buildTelegraphPresentation(model, root, rootHeight, bodyTopOffset)
	model:PivotTo(root.CFrame)
	return model
end

-- Volume de zona vira uma part de gatilho (sem colisão): o servidor lê a
-- posição no heartbeat, então a part existe para leitura visual no Studio e
-- para o cliente saber onde a fronteira está.
local function buildZoneVolumes(root: Folder, zones: any): ()
	local groupByKind: { [string]: string } = {
		safe = "Safe",
		transition = "Transition",
		free = "Free",
	}
	local folder = Instance.new("Folder")
	folder.Name = "ZoneVolumes"
	folder.Parent = root

	for _, zone in zones.all() do
		local group = groupByKind[zone.kind] or "Safe"
		local color = if zone.kind == "transition"
			then COLORS.transition
			else (if zone.kind == "free" then COLORS.plain else COLORS.bastion)
		for index, box in zone.volumes do
			local sizeX = box.max.x - box.min.x
			local sizeY = box.max.y - box.min.y
			local sizeZ = box.max.z - box.min.z
			local part = makePart(
				("%s_%d"):format(zone.id, index),
				Vector3.new(sizeX, sizeY, sizeZ),
				Vector3.new((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, (box.min.z + box.max.z) / 2),
				color,
				group,
				false
			)
			part:SetAttribute("ZoneId", zone.id)
			part.Transparency = 1
			part.Parent = folder
		end
	end
end

-- Chão do Bastião e da Planície, com material distinto (§8.1: pedra clara na
-- vila, areia/pedra na planície) — aqui só cor, porque arte é pós-P1.
local function buildFloors(root: Folder, greybox: any, style: any, zones: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Floors"
	folder.Parent = root

	-- Todo volume jogável gera piso na mesma caixa X/Z usada por zoneAtPosition.
	-- Assim as transições norte/oeste e o braço livre oeste não podem divergir
	-- do domínio e voltar a abrir buracos físicos entre zonas.
	local groupByKind = { safe = "Safe", transition = "Transition", free = "Free" }
	local colorByKind = { safe = COLORS.bastion, transition = COLORS.transition, free = COLORS.plain }
	for _, zone in zones.all() do
		for index, box in zone.volumes do
			local floorName = if zone.id == "zone_bastion_safe" and index == 1
				then "BastionFloor"
				else (if zone.id == "zone_plain_free" and index == 1
					then "PlainFloor"
					else ("ZoneFloor_%s_%d"):format(zone.id, index))
			local floor = makePart(
				floorName,
				Vector3.new(box.max.x - box.min.x, FLOOR_THICKNESS, box.max.z - box.min.z),
				Vector3.new((box.min.x + box.max.x) / 2, GROUND_Y - FLOOR_THICKNESS / 2, (box.min.z + box.max.z) / 2),
				colorByKind[zone.kind] or COLORS.bastion,
				groupByKind[zone.kind] or "Safe",
				true
			)
			floor:SetAttribute("ZoneId", zone.id)
			floor.Parent = folder
		end
	end

	local training = makePart(
		"TrainingPad",
		Vector3.new(greybox.trainingSize, FLOOR_THICKNESS / 2, greybox.trainingSize),
		Vector3.new(28, GROUND_Y, -20),
		COLORS.bastion,
		"Safe",
		true
	)
	training.Parent = folder

	-- Praça e rotas tornam spawn → treino → dois portões legíveis sem minimapa.
	local plaza = makePart(
		"SpawnPlaza",
		Vector3.new(0.35, style.spawnPlazaRadius * 2, style.spawnPlazaRadius * 2),
		Vector3.new(0, 0.18, 16),
		COLORS.lightStone,
		"Safe",
		true
	)
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CFrame = CFrame.new(plaza.Position) * CFrame.Angles(0, 0, math.pi / 2)
	plaza.Parent = folder

	local northPath = makePart(
		"PathNorthGate",
		Vector3.new(style.pathWidth, 0.3, 43),
		Vector3.new(0, 0.16, -10.5),
		COLORS.path,
		"Safe",
		true
	)
	northPath.Parent = folder
	local trainingPath = makePart(
		"PathTraining",
		Vector3.new(30, 0.3, style.pathWidth),
		Vector3.new(15, 0.16, -20),
		COLORS.path,
		"Safe",
		true
	)
	trainingPath.Parent = folder
	local westPath = makePart(
		"PathWestGate",
		Vector3.new(40, 0.3, style.pathWidth),
		Vector3.new(-20, 0.16, 0),
		COLORS.path,
		"Safe",
		true
	)
	westPath.Parent = folder
	local wildPath = makePart(
		"PathToCrater",
		Vector3.new(style.pathWidth, 0.24, 60),
		Vector3.new(0, 0.13, -70),
		COLORS.crater,
		"Free",
		true
	)
	wildPath.Parent = folder

	-- Cratera baixa com aro segmentado: reconhecível, atravessável e sem o
	-- bloco maciço que prendia o personagem no centro do encontro.
	local basin = makePart(
		"EliteCraterBasin",
		Vector3.new(0.25, greybox.eliteCraterRadius * 1.7, greybox.eliteCraterRadius * 1.7),
		Vector3.new(0, 0.12, -102),
		COLORS.darkStone,
		"Free",
		true
	)
	basin.Shape = Enum.PartType.Cylinder
	basin.CFrame = CFrame.new(basin.Position) * CFrame.Angles(0, 0, math.pi / 2)
	basin.Parent = folder
	for index = 1, style.craterSegments do
		local angle = (index - 1) / style.craterSegments * math.pi * 2
		local radius = greybox.eliteCraterRadius
		local stone = makePart(
			("EliteCraterRim_%02d"):format(index),
			Vector3.new(5.2, 1.6 + (index % 3) * 0.25, 2.4),
			Vector3.new(math.cos(angle) * radius, 0.8, -102 + math.sin(angle) * radius),
			COLORS.crater,
			"Free",
			true
		)
		stone.CFrame = CFrame.new(stone.Position) * CFrame.Angles(0, -angle, 0)
		stone.Parent = folder
	end
end

-- Muros do Bastião com as aberturas dos dois portões. O muro em L do Portão
-- Oeste quebra a linha de visão (§8.1) e o pilar central é a silhueta visível
-- da planície (§8.1).
local function buildWalls(root: Folder, greybox: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	folder.Parent = root

	local halfX = greybox.bastionSize.x / 2
	local halfZ = greybox.bastionSize.z / 2
	local height = greybox.bastionWallHeight
	local gateNorthHalf = greybox.gateNorthWidth / 2
	local gateWestHalf = greybox.gateWestWidth / 2

	local function wall(name: string, size: Vector3, position: Vector3): ()
		local part = makePart(name, size, position, COLORS.wall, "GateBlock", true)
		part.Parent = folder
	end

	-- Norte: dois trechos deixando o vão do portão no meio.
	local northSegment = halfX - gateNorthHalf
	wall(
		"WallNorthWest",
		Vector3.new(northSegment, height, 2),
		Vector3.new(-(gateNorthHalf + northSegment / 2), height / 2, -halfZ)
	)
	wall(
		"WallNorthEast",
		Vector3.new(northSegment, height, 2),
		Vector3.new(gateNorthHalf + northSegment / 2, height / 2, -halfZ)
	)
	wall("WallSouth", Vector3.new(greybox.bastionSize.x, height, 2), Vector3.new(0, height / 2, halfZ))
	wall("WallEast", Vector3.new(2, height, greybox.bastionSize.z), Vector3.new(halfX, height / 2, 0))

	-- Oeste: dois trechos deixando o vão do Portão Oeste.
	local westSegment = halfZ - gateWestHalf
	wall(
		"WallWestNorth",
		Vector3.new(2, height, westSegment),
		Vector3.new(-halfX, height / 2, -(gateWestHalf + westSegment / 2))
	)
	wall(
		"WallWestSouth",
		Vector3.new(2, height, westSegment),
		Vector3.new(-halfX, height / 2, gateWestHalf + westSegment / 2)
	)
	-- Muro em L que quebra a LOS de quem sai pelo Portão Oeste.
	wall("WallWestBaffle", Vector3.new(16, height, 2), Vector3.new(-halfX - 8, height / 2, -gateWestHalf - 1))

	-- Quatro pilares de 20 de altura como marco (§8.1).
	local pillarPositions = {
		Vector3.new(-20, 10, -16),
		Vector3.new(20, 10, -16),
		Vector3.new(-20, 10, 16),
		Vector3.new(20, 10, 16),
	}
	for index, position in pillarPositions do
		local pillar = makePart(("Pillar%d"):format(index), Vector3.new(4, 20, 4), position, COLORS.wall, "Safe", true)
		pillar.Parent = folder
	end
end

local function buildLandmarks(root: Folder, greybox: any, style: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	folder.Parent = root

	local function stone(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
		local part = makePart(name, size, position, color, "GateBlock", true)
		part.Material = Enum.Material.Slate
		part.Parent = folder
		return part
	end

	-- Portais físicos redundantes com a troca de solo/UI da fronteira.
	stone("NorthGateLeft", Vector3.new(2.5, 12, 3), Vector3.new(-7.25, 6, -32), COLORS.darkStone)
	stone("NorthGateRight", Vector3.new(2.5, 12, 3), Vector3.new(7.25, 6, -32), COLORS.darkStone)
	stone("NorthGateBeam", Vector3.new(17, 2.5, 3), Vector3.new(0, 11.5, -32), COLORS.lightStone)
	stone("WestGateNorth", Vector3.new(3, 12, 2.5), Vector3.new(-40, 6, -6.25), COLORS.darkStone)
	stone("WestGateSouth", Vector3.new(3, 12, 2.5), Vector3.new(-40, 6, 6.25), COLORS.darkStone)
	stone("WestGateBeam", Vector3.new(3, 2.5, 15), Vector3.new(-40, 11.5, 0), COLORS.lightStone)

	-- Postes claros fazem a zona de transição legível também sem cor.
	for index = 1, style.boundaryPostCount do
		local side = if index % 2 == 0 then 1 else -1
		local lane = math.ceil(index / 2)
		stone(
			("NorthBoundaryPost_%d"):format(index),
			Vector3.new(0.8, 4 + lane * 0.35, 0.8),
			Vector3.new(side * 8.5, 2, -32 - lane * 2),
			COLORS.boundary
		)
	end

	-- Marco de Retorno: obelisco simples, distinto das âncoras invisíveis.
	local returnBase = stone("ReturnBase", Vector3.new(6, 1, 6), Vector3.new(0, 0.5, 12), COLORS.darkStone)
	returnBase.CollisionGroup = "Safe"
	local returnSpire = stone("ReturnSpire", Vector3.new(2, 7, 2), Vector3.new(0, 4.5, 12), COLORS.lightStone)
	returnSpire.CollisionGroup = "Safe"
	local returnCore =
		makePart("ReturnCore", Vector3.new(1.15, 1.15, 1.15), Vector3.new(0, 7.5, 12), COLORS.boundary, "Safe", false)
	returnCore.Shape = Enum.PartType.Ball
	returnCore.Material = Enum.Material.Neon
	returnCore.Transparency = 0.12
	returnCore:SetAttribute("InteractionAnchorId", "anchor_bastion_return")
	returnCore.Parent = folder

	-- Silhuetas verticais na planície orientam as duas rotas e a cratera.
	for index = 1, style.landmarkShardCount do
		local angle = (index - 1) / style.landmarkShardCount * math.pi * 2
		local radius = 31 + (index % 2) * 8
		local height = 7 + (index % 3) * 2
		local shard = stone(
			("PlainShard_%02d"):format(index),
			Vector3.new(2.2, height, 2.2),
			Vector3.new(math.cos(angle) * radius, height / 2, -102 + math.sin(angle) * radius),
			if index % 2 == 0 then COLORS.darkStone else COLORS.crater
		)
		shard.CFrame = CFrame.new(shard.Position) * CFrame.Angles(math.rad(8), angle, math.rad(10 - index * 2))
	end

	-- Spawn real do Roblox dentro da praça; o bootstrap ainda reconcilia a
	-- posição na âncora canônica ao CharacterAdded.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BastionSpawn"
	spawn.Size = Vector3.new(math.min(12, greybox.spawnRadius * 2), 0.4, math.min(12, greybox.spawnRadius * 2))
	spawn.Position = Vector3.new(0, 0.25, 20)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 8
	spawn.Transparency = 0.65
	spawn.Color = COLORS.lightStone
	spawn.Material = Enum.Material.Slate
	spawn.CollisionGroup = "Safe"
	spawn.Parent = folder
end

local function anchorPosition(zones: any, anchorId: string): Vector3?
	local anchor = zones.getAnchor(anchorId)
	if not anchor then
		return nil
	end
	return Vector3.new(anchor.position.x, anchor.position.y, anchor.position.z)
end

local function setNpcInteraction(model: Model, npcId: string): ()
	-- Um único alvo visível evita dois prompts concorrentes para o mesmo NPC.
	local part = model:FindFirstChild("Head")
	if part and part:IsA("BasePart") then
		part:SetAttribute("InteractionNpcId", npcId)
	end
end

local function buildStaticActors(root: Folder, presentation: any, zones: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Actors"
	folder.Parent = root

	local dummyRecipe = presentation.getActor("npc_training_dummy")
	local dummyPosition = anchorPosition(zones, "anchor_training")
	if dummyRecipe and dummyPosition then
		local dummy = createActorModel(
			"TrainingDummy",
			"npc_training_dummy",
			"npc_training_dummy",
			dummyRecipe,
			-- O pad de treino tem topo 0,5 stud acima do chão canônico.
			dummyPosition + Vector3.new(0, 0.5, 0),
			presentation.rigFor("npc_training_dummy")
		)
		dummy:SetAttribute("PoseKind", "idle")
		local dummyRoot = dummy.PrimaryPart
		if dummyRoot then
			dummyRoot:SetAttribute("CombatTarget", true)
		end
		dummy.Parent = folder
	end

	local instructorRecipe = presentation.getActor("npc_threshold_instructor")
	local instructorPosition = anchorPosition(zones, "anchor_instructor")
	if instructorRecipe and instructorPosition then
		local instructor = createActorModel(
			"ThresholdInstructor",
			"npc_threshold_instructor",
			"npc_threshold_instructor",
			instructorRecipe,
			instructorPosition,
			presentation.rigFor("npc_threshold_instructor")
		)
		instructor:SetAttribute("PoseKind", "idle")
		setNpcInteraction(instructor, "npc_threshold_instructor")
		instructor.Parent = folder
	end
end

-- Marcadores de âncora: parts invisíveis com atributo, para o servidor
-- posicionar spawn, retorno, dummy, instrutor e Estilhaços sem CFrame cru.
local function buildAnchors(root: Folder, zones: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Anchors"
	folder.Parent = root

	for _, anchor in zones.allAnchors() do
		local part = Instance.new("Part")
		part.Name = anchor.id
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(2, 2, 2)
		part.Position = Vector3.new(anchor.position.x, anchor.position.y + part.Size.Y / 2, anchor.position.z)
		part.Color = COLORS.anchor
		part:SetAttribute("AnchorId", anchor.id)
		part:SetAttribute("ZoneId", anchor.zoneId)
		part:SetAttribute("CombatTarget", false)
		part:SetAttribute("GroundX", anchor.position.x)
		part:SetAttribute("GroundY", anchor.position.y)
		part:SetAttribute("GroundZ", anchor.position.z)
		part.Parent = folder
	end
end

local function buildLighting(): ()
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 15.25
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 136, 142)

	local oldAtmosphere = Lighting:FindFirstChild("F0Atmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "F0Atmosphere"
	atmosphere.Color = Color3.fromRGB(204, 211, 218)
	atmosphere.Decay = Color3.fromRGB(114, 105, 97)
	atmosphere.Density = 0.22
	atmosphere.Glare = 0.08
	atmosphere.Haze = 1.25
	atmosphere.Parent = Lighting
end

-- Decoração da área de spawn a partir das receitas puras de
-- `SpawnDecorations.luau` (mesmo contrato do resto do greybox: decisão nos
-- dados, esta camada só materializa Parts).
local function buildSpawnDecorations(root: Folder, spawnDecorations: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "SpawnDecorations"
	folder.Parent = root

	local materials = {
		SmoothPlastic = Enum.Material.SmoothPlastic,
		Slate = Enum.Material.Slate,
		Neon = Enum.Material.Neon,
	}
	for _, d in spawnDecorations.all() do
		local part = makePart(
			d.name,
			Vector3.new(d.size.x, d.size.y, d.size.z),
			Vector3.new(d.position.x, d.position.y, d.position.z),
			toColor(d.rgb),
			if d.canCollide then "GateBlock" else "Safe",
			d.canCollide
		)
		part.Material = materials[d.material] or Enum.Material.SmoothPlastic
		part.Transparency = d.transparency
		if not d.canCollide then
			part.CastShadow = false
		end
		part.Parent = folder
	end
end

-- Constrói o mundo. Idempotente: rodar de novo em Studio limpa e reconstrói.
function WorldService.init(deps: WorldDeps): ()
	WorldService.deps = deps
	table.clear(WorldService.actors)

	local existing = Workspace:FindFirstChild("GreyboxF0")
	if existing then
		existing:Destroy()
	end

	local greybox = deps.greybox()
	registerCollisionGroups(greybox.collisionGroups)

	local root = Instance.new("Folder")
	root.Name = "GreyboxF0"
	local style = deps.presentation.style()

	buildFloors(root, greybox, style, deps.zones)
	buildWalls(root, greybox)
	buildLandmarks(root, greybox, style)
	buildSpawnDecorations(root, deps.spawnDecorations)
	buildZoneVolumes(root, deps.zones)
	buildStaticActors(root, deps.presentation, deps.zones)
	buildAnchors(root, deps.zones)
	buildLighting()

	root.Parent = Workspace
	WorldService.root = root
	-- Em thread própria: `settleRigBodies` espera um passo de física, e o
	-- bootstrap não pode ceder o thread no meio — um jogador que entrasse
	-- nesse frame ainda não teria `PlayerAdded` conectado.
	task.spawn(WorldService.settleRigBodies)
end

-- Assenta os corpos de rig no chão.
--
-- O R15 sai de `CreateHumanoidModelFromDescription` com as pernas levemente
-- recolhidas e só estende quando entra na simulação: medido no Studio em
-- 2026-08-14, a sola desce 0,186 stud depois do primeiro passo de física. Quem
-- posiciona pela medida de antes enterra o boneco esse tanto no chão — e o
-- boneco de treino leva junto o poste e a base, que passam a nascer soterrados.
--
-- Em vez de fixar a constante (que muda no dia em que o Roblox mexer nas
-- proporções padrão), o mundo espera um passo de física, MEDE o corpo já
-- montado e corrige o C0 do weld uma única vez. Idempotente: rodar de novo com
-- o corpo já assentado não move nada.
function WorldService.settleRigBodies(): ()
	local root = WorldService.root
	local folder = if root then root:FindFirstChild("Actors") else nil
	if not folder then
		return
	end
	-- Um passo de física é o suficiente: a perna estende no primeiro Heartbeat.
	task.wait()
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local body = model:FindFirstChild("Body")
		if not body or not body:IsA("Model") then
			continue
		end
		local groundY = body:GetAttribute("AvbGroundY")
		local hrp = body:FindFirstChild("HumanoidRootPart")
		if type(groundY) ~= "number" or not hrp or not hrp:IsA("BasePart") then
			continue
		end
		local weld = hrp:FindFirstChild("RigWeld")
		if not weld or not weld:IsA("Weld") then
			continue
		end
		local lowest: number? = nil
		for _, footName in { "LeftFoot", "RightFoot" } do
			local foot = body:FindFirstChild(footName)
			if foot and foot:IsA("BasePart") then
				local bottom = foot.Position.Y - foot.Size.Y / 2
				lowest = if lowest then math.min(lowest, bottom) else bottom
			end
		end
		if not lowest then
			continue
		end
		local delta = groundY - lowest
		if math.abs(delta) > 0.005 then
			weld.C0 = weld.C0 * CFrame.new(0, delta, 0)
		end
	end
end

local function actorFolder(): Folder?
	local root = WorldService.root
	if not root then
		return nil
	end
	local folder = root:FindFirstChild("Actors")
	return if folder and folder:IsA("Folder") then folder else nil
end

local function spawnActor(fighterId: string, npcId: string, position: Vector3): ActorVisual?
	local existing = WorldService.actors[fighterId]
	if existing then
		setActorVisible(existing.model, true)
		return existing
	end
	local deps = WorldService.deps
	local folder = actorFolder()
	if not deps or not folder then
		return nil
	end
	local recipe = deps.presentation.getActor(npcId)
	if not recipe then
		return nil
	end
	local model = createActorModel(
		("Actor_%s"):format((fighterId:gsub("[^%w_%-]", "_"))),
		fighterId,
		npcId,
		recipe,
		position,
		deps.presentation.rigFor(npcId)
	)
	model:SetAttribute("SpawnPresentation", true)
	local modelRoot = model.PrimaryPart
	if modelRoot then
		modelRoot:SetAttribute("CombatTarget", true)
	end
	model.Parent = folder
	-- Ator dinâmico com corpo de rig também precisa assentar (hoje só os bots
	-- estáticos têm rig, mas o dia em que um inimigo humanoide entrar, ele
	-- nasceria enterrado). `settleRigBodies` é idempotente e varre a pasta.
	if deps.presentation.rigFor(npcId) then
		task.defer(WorldService.settleRigBodies)
	end
	local actor = {
		model = model,
		lastPosition = position,
		lastLookVector = nil,
		rootHeight = actorRootHeight(recipe),
		moving = false,
	}
	WorldService.actors[fighterId] = actor
	return actor
end

function WorldService.presentEnemyEvent(fighterId: string, event: { [string]: any }): ()
	local kind = event.kind
	if type(kind) ~= "string" then
		return
	end
	local actor = WorldService.actors[fighterId]
	if (kind == "spawn" or kind == "respawn") and not actor then
		local anchorId = event.anchorId
		local npcId = string.match(fighterId, "^([^@]+)@")
		local position = if type(anchorId) == "string" then WorldService.getAnchorPosition(anchorId) else nil
		if npcId and position then
			actor = spawnActor(fighterId, npcId, position)
		end
	end
	if not actor then
		return
	end
	if kind == "spawn" or kind == "respawn" then
		setActorVisible(actor.model, true)
	end
	local visualPattern = if type(event.visualPattern) == "string" then event.visualPattern else nil
	local defaultDuration = if kind == "spawn" or kind == "respawn"
		then 0.6
		else (if kind == "attack" then 0.35 else (if kind == "died" then 0.75 else 1))
	local durationSeconds = if type(event.durationSeconds) == "number"
		then math.clamp(event.durationSeconds, 0.1, 2)
		else defaultDuration
	local poseSerial = (actor.model:GetAttribute("PoseSerial") or 0) + 1
	actor.model:SetAttribute("PoseKind", kind)
	actor.model:SetAttribute("PoseSerial", poseSerial)
	actor.model:SetAttribute("PoseStartedAt", Workspace:GetServerTimeNow())
	actor.model:SetAttribute("PoseDuration", durationSeconds)
	actor.model:SetAttribute("VisualPattern", visualPattern)
	setTelegraphVisible(actor.model, kind == "telegraph", visualPattern)
	if kind == "died" then
		task.delay(0.75, function()
			if actor and actor.model.Parent and actor.model:GetAttribute("PoseKind") == "died" then
				setActorVisible(actor.model, false)
			end
		end)
	else
		task.delay(durationSeconds, function()
			if actor and actor.model.Parent and actor.model:GetAttribute("PoseSerial") == poseSerial then
				actor.model:SetAttribute("PoseKind", "idle")
				setTelegraphVisible(actor.model, false, nil)
			end
		end)
	end
end

function WorldService.syncActor(fighterId: string, transform: any): ()
	local actor = WorldService.actors[fighterId]
	if not actor or not transform or not transform.position then
		return
	end
	local position = Vector3.new(transform.position.x, transform.position.y, transform.position.z)
	local look = transform.look
	local lookVector = if look then Vector3.new(look.x, 0, look.z) else Vector3.new(0, 0, -1)
	if lookVector.Magnitude < 1e-4 then
		lookVector = Vector3.new(0, 0, -1)
	else
		lookVector = lookVector.Unit
	end
	local rootPosition = position + Vector3.new(0, actor.rootHeight, 0)
	local lastPosition = actor.lastPosition
	local movedDistance = if lastPosition then (position - lastPosition).Magnitude else math.huge
	local lastLookVector = actor.lastLookVector
	local turned = lastLookVector == nil or lastLookVector:Dot(lookVector) < 0.9999
	if movedDistance > 0.005 or turned then
		local root = actor.model.PrimaryPart
		if root then
			-- Só a raiz ancorada se move; Motor6D.Transform continua exclusivamente
			-- local. Evita PivotTo e replicação redundante em todo Heartbeat.
			root.CFrame = CFrame.lookAt(rootPosition, rootPosition + lookVector)
		end
	end
	local moving = movedDistance > 0.02
	if actor.moving ~= moving then
		actor.moving = moving
		actor.model:SetAttribute("Moving", moving)
	end
	actor.lastPosition = position
	actor.lastLookVector = lookVector
end

function WorldService.getAnchorPosition(anchorId: string): Vector3?
	local root = WorldService.root
	if not root then
		return nil
	end
	local anchors = root:FindFirstChild("Anchors")
	if not anchors then
		return nil
	end
	local part = anchors:FindFirstChild(anchorId)
	if part and part:IsA("BasePart") then
		local groundX = part:GetAttribute("GroundX")
		local groundY = part:GetAttribute("GroundY")
		local groundZ = part:GetAttribute("GroundZ")
		if type(groundX) == "number" and type(groundY) == "number" and type(groundZ) == "number" then
			return Vector3.new(groundX, groundY, groundZ)
		end
		return part.Position
	end
	return nil
end

return WorldService

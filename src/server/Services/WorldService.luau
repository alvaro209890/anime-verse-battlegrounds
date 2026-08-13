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
-- Arte final proibida até P1 (§17): só Parts, cores neutras, luz e animação
-- procedural genérica. Nenhuma silhueta/roupa/VFX de referência.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

export type WorldDeps = {
	zones: any,
	greybox: any,
	presentation: any,
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

local function buildTelegraphPresentation(model: Model, root: BasePart, rootHeight: number): ()
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
	symbol.StudsOffsetWorldSpace = Vector3.new(0, rootHeight + 1.4, 0)
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
		if descendant:IsA("BasePart") and descendant.Name ~= "Root" then
			descendant.Transparency = if visible then 0 else 1
		end
	end
	if not visible then
		setTelegraphVisible(model, false, nil)
	end
end

local function createActorModel(name: string, actorId: string, npcId: string, recipe: any, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("PresentationActor", true)
	model:SetAttribute("ActorId", actorId)
	model:SetAttribute("NpcId", npcId)
	model:SetAttribute("PoseKind", "spawn")
	model:SetAttribute("Moving", false)

	local scale = recipe.scale
	local root = makeVisualPart("Part", "Root", Vector3.new(1, 1, 1), COLORS.darkStone, Enum.Material.SmoothPlastic)
	root.Anchored = true
	root.Transparency = 1
	local rootHeight = actorRootHeight(recipe)
	root.CFrame = CFrame.new(position + Vector3.new(0, rootHeight, 0))
	root.Parent = model
	model.PrimaryPart = root

	local bodyColor = toColor(recipe.bodyRgb)
	local accentColor = toColor(recipe.accentRgb)
	local coreColor = toColor(recipe.coreRgb)
	if recipe.shape == "humanoid" then
		local torso =
			makeVisualPart("Part", "Torso", Vector3.new(2.2, 2.4, 1.1) * scale, bodyColor, Enum.Material.Slate)
		attach(root, torso, CFrame.new(0, 0.1, 0), "Joint_Torso")

		local head = makeVisualPart(
			"Part",
			"Head",
			Vector3.new(1.35, 1.35, 1.35) * scale,
			coreColor,
			Enum.Material.SmoothPlastic
		)
		head.Shape = Enum.PartType.Ball
		attach(torso, head, CFrame.new(0, 1.85 * scale, 0), "Joint_Head")

		local leftArm =
			makeVisualPart("Part", "LeftArm", Vector3.new(0.7, 2.2, 0.7) * scale, accentColor, Enum.Material.Slate)
		attach(torso, leftArm, CFrame.new(-1.45 * scale, -0.05 * scale, 0), "Joint_LeftArm")
		local rightArm = leftArm:Clone()
		rightArm.Name = "RightArm"
		attach(torso, rightArm, CFrame.new(1.45 * scale, -0.05 * scale, 0), "Joint_RightArm")

		local leftLeg =
			makeVisualPart("Part", "LeftLeg", Vector3.new(0.85, 2.4, 0.9) * scale, bodyColor, Enum.Material.Slate)
		attach(root, leftLeg, CFrame.new(-0.58 * scale, -2.2 * scale, 0), "Joint_LeftLeg")
		local rightLeg = leftLeg:Clone()
		rightLeg.Name = "RightLeg"
		attach(root, rightLeg, CFrame.new(0.58 * scale, -2.2 * scale, 0), "Joint_RightLeg")
	else
		local torso =
			makeVisualPart("Part", "Torso", Vector3.new(2.2, 2.8, 1.6) * scale, bodyColor, Enum.Material.Slate)
		attach(root, torso, CFrame.Angles(0, 0, math.rad(45)), "Joint_Torso")
		local core =
			makeVisualPart("Part", "Core", Vector3.new(1.25, 1.25, 1.25) * scale, coreColor, Enum.Material.Neon)
		core.Shape = Enum.PartType.Ball
		attach(root, core, CFrame.new(0, 0, -0.75 * scale), "Joint_Core")
		local left = makeVisualPart(
			"WedgePart",
			"ShardLeft",
			Vector3.new(1.1, 2.7, 0.8) * scale,
			accentColor,
			Enum.Material.Slate
		)
		attach(root, left, CFrame.new(-1.35 * scale, 0.1, 0) * CFrame.Angles(0, 0, math.rad(28)), "Joint_ShardLeft")
		local right = left:Clone()
		right.Name = "ShardRight"
		attach(
			root,
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
		attach(root, top, CFrame.new(0, 2 * scale, 0), "Joint_ShardTop")
	end

	buildTelegraphPresentation(model, root, rootHeight)
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
		Vector3.new(42, 0.3, style.pathWidth),
		Vector3.new(-21, 0.16, 0),
		COLORS.path,
		"Safe",
		true
	)
	westPath.Parent = folder
	local wildPath = makePart(
		"PathToCrater",
		Vector3.new(style.pathWidth, 0.24, 62),
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
			dummyPosition + Vector3.new(0, 0.5, 0)
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
			instructorPosition
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
	buildZoneVolumes(root, deps.zones)
	buildStaticActors(root, deps.presentation, deps.zones)
	buildAnchors(root, deps.zones)
	buildLighting()

	root.Parent = Workspace
	WorldService.root = root
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
	local model =
		createActorModel(("Actor_%s"):format((fighterId:gsub("[^%w_%-]", "_"))), fighterId, npcId, recipe, position)
	model:SetAttribute("SpawnPresentation", true)
	local modelRoot = model.PrimaryPart
	if modelRoot then
		modelRoot:SetAttribute("CombatTarget", true)
	end
	model.Parent = folder
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

--!strict
-- WorldService (server) — F0 (docs/13-F0-SLICE.md §8)
-- Constrói o greybox no Studio a partir de `Zones.luau`: chão, muros, portões,
-- volumes de transição, planície, cratera da elite e marcadores de âncora,
-- além dos collision groups `Safe` / `Transition` / `Free` / `GateBlock`.
--
-- ATENÇÃO — esta é a ÚNICA camada da fatia que toca Instances, e por isso é a
-- única que os testes Lune não cobrem. Ela não tem regra de jogo: é tradução
-- de dados em parts. Toda decisão (qual zona, o que bloqueia, quanto anda)
-- vive em `Zones.luau`, `Geometry.luau` e `SpatialService`, que são testados.
-- Se algo aqui precisar de um `if` de gameplay, o `if` está no lugar errado.
--
-- Arte proibida até P1 (§17): só parts, cores neutras e luz.

local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

export type WorldDeps = {
	zones: any,
	greybox: any,
}

local WorldService = {
	deps = nil :: WorldDeps?,
	root = nil :: Folder?,
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
}

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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not canCollide then
		part.Transparency = 0.75
	end
	part.CollisionGroup = collisionGroup
	return part
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
			part.Parent = folder
		end
	end
end

-- Chão do Bastião e da Planície, com material distinto (§8.1: pedra clara na
-- vila, areia/pedra na planície) — aqui só cor, porque arte é pós-P1.
local function buildFloors(root: Folder, greybox: any): ()
	local folder = Instance.new("Folder")
	folder.Name = "Floors"
	folder.Parent = root

	local bastion = makePart(
		"BastionFloor",
		Vector3.new(greybox.bastionSize.x, FLOOR_THICKNESS, greybox.bastionSize.z),
		Vector3.new(0, GROUND_Y - FLOOR_THICKNESS / 2, 0),
		COLORS.bastion,
		"Safe",
		true
	)
	bastion.Parent = folder

	-- Planície ao norte: começa depois dos 8 studs de transição do Portão Norte.
	local plainCenterZ = -(greybox.bastionSize.z / 2) - greybox.transitionDepth - greybox.plainSize.z / 2
	local plain = makePart(
		"PlainFloor",
		Vector3.new(greybox.plainSize.x, FLOOR_THICKNESS, greybox.plainSize.z),
		Vector3.new(0, GROUND_Y - FLOOR_THICKNESS / 2, plainCenterZ),
		COLORS.plain,
		"Free",
		true
	)
	plain.Parent = folder

	local training = makePart(
		"TrainingPad",
		Vector3.new(greybox.trainingSize, FLOOR_THICKNESS / 2, greybox.trainingSize),
		Vector3.new(28, GROUND_Y, -20),
		COLORS.bastion,
		"Safe",
		true
	)
	training.Parent = folder

	-- Cratera da elite: borda 2 studs mais alta (§8.1).
	local crater = makePart(
		"EliteCraterRim",
		Vector3.new(greybox.eliteCraterRadius * 2, 2, greybox.eliteCraterRadius * 2),
		Vector3.new(0, GROUND_Y + 1, -102),
		COLORS.crater,
		"Free",
		true
	)
	crater.Shape = Enum.PartType.Cylinder
	crater.Parent = folder
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
		part.Transparency = 0.6
		part.Size = Vector3.new(2, 2, 2)
		part.Position = Vector3.new(anchor.position.x, anchor.position.y + 1, anchor.position.z)
		part.Color = COLORS.anchor
		part:SetAttribute("AnchorId", anchor.id)
		part:SetAttribute("ZoneId", anchor.zoneId)
		part.Parent = folder
	end
end

-- Constrói o mundo. Idempotente: rodar de novo em Studio limpa e reconstrói.
function WorldService.init(deps: WorldDeps): ()
	WorldService.deps = deps

	local existing = Workspace:FindFirstChild("GreyboxF0")
	if existing then
		existing:Destroy()
	end

	local greybox = deps.greybox()
	registerCollisionGroups(greybox.collisionGroups)

	local root = Instance.new("Folder")
	root.Name = "GreyboxF0"

	buildFloors(root, greybox)
	buildWalls(root, greybox)
	buildZoneVolumes(root, deps.zones)
	buildAnchors(root, deps.zones)

	root.Parent = Workspace
	WorldService.root = root
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
		return part.Position
	end
	return nil
end

return WorldService

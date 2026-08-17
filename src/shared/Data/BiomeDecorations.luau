--!strict
-- Decoração das células de bioma (docs/02 §3.4, docs/24).
-- Dados puros: o WorldService só materializa. Nada colide, nada entra no
-- ringue do elite nem nas âncoras de Estilhaço, nada invade portão.

export type BiomeLight = {
	brightness: number,
	rangeStuds: number,
	rgb: { number },
	shadows: boolean,
}

export type BiomePiece = {
	name: string,
	shape: "Block" | "Ball" | "Cylinder",
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	yawDegrees: number,
	rgb: { number },
	material: string,
	transparency: number,
	canCollide: boolean,
	light: BiomeLight?,
}

local BiomeDecorations = {}

local NEON = { 80, 220, 255 }
local NEON_MAGENTA = { 220, 70, 180 }
local ASPHALT = { 32, 28, 46 }
local WOOD = { 62, 96, 58 }
local LEAF = { 48, 140, 72 }
local MOSS = { 36, 88, 52 }
local RUST = { 156, 92, 58 }
local IRON = { 88, 90, 96 }
local SEA = { 36, 92, 128 }
local CREAM = { 210, 198, 164 }
local GOLD = { 212, 168, 72 }
local SMOKE = { 72, 74, 80 }

local function piece(
	name: string,
	shape: "Block" | "Ball" | "Cylinder",
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	yawDegrees: number,
	rgb: { number },
	material: string,
	transparency: number,
	canCollide: boolean,
	light: BiomeLight?
): BiomePiece
	return {
		name = name,
		shape = shape,
		size = size,
		position = position,
		yawDegrees = yawDegrees,
		rgb = rgb,
		material = material,
		transparency = transparency,
		canCollide = canCollide,
		light = light,
	}
end

local PIECES: { BiomePiece } = {}

local function push(item: BiomePiece): ()
	table.insert(PIECES, item)
end

-- ── Distrito Lumen: rua, praça, marco neon ────────────────────────────────
push(
	piece(
		"LumenPlaza",
		"Cylinder",
		{ x = 0.3, y = 36, z = 36 },
		{ x = 0, y = 0.2, z = -580 },
		0,
		{ 48, 36, 72 },
		"Neon",
		0.15,
		false,
		nil
	)
)
push(
	piece(
		"LumenTower",
		"Block",
		{ x = 8, y = 42, z = 8 },
		{ x = 0, y = 21, z = -580 },
		0,
		ASPHALT,
		"SmoothPlastic",
		0,
		false,
		nil
	)
)
push(
	piece(
		"LumenCrown",
		"Block",
		{ x = 14, y = 3, z = 14 },
		{ x = 0, y = 43, z = -580 },
		0,
		NEON_MAGENTA,
		"Neon",
		0.05,
		false,
		{
			brightness = 1.4,
			rangeStuds = 28,
			rgb = NEON_MAGENTA,
			shadows = false,
		}
	)
)
push(
	piece(
		"LumenSignN",
		"Block",
		{ x = 18, y = 4, z = 0.6 },
		{ x = 0, y = 14, z = -548 },
		0,
		NEON,
		"Neon",
		0.08,
		false,
		nil
	)
)
push(
	piece(
		"LumenSignS",
		"Block",
		{ x = 18, y = 4, z = 0.6 },
		{ x = 0, y = 14, z = -612 },
		0,
		NEON_MAGENTA,
		"Neon",
		0.08,
		false,
		nil
	)
)
for i = 1, 6 do
	local x = -70 + (i - 1) * 28
	push(
		piece(
			("LumenLampW_%02d"):format(i),
			"Block",
			{ x = 0.5, y = 9, z = 0.5 },
			{ x = x, y = 4.5, z = -530 },
			0,
			ASPHALT,
			"SmoothPlastic",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			("LumenGlowW_%02d"):format(i),
			"Ball",
			{ x = 1.4, y = 1.4, z = 1.4 },
			{ x = x, y = 9.4, z = -530 },
			0,
			NEON,
			"Neon",
			0.1,
			false,
			{
				brightness = 0.9,
				rangeStuds = 12,
				rgb = NEON,
				shadows = false,
			}
		)
	)
	push(
		piece(
			("LumenLampE_%02d"):format(i),
			"Block",
			{ x = 0.5, y = 9, z = 0.5 },
			{ x = x, y = 4.5, z = -630 },
			0,
			ASPHALT,
			"SmoothPlastic",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			("LumenGlowE_%02d"):format(i),
			"Ball",
			{ x = 1.4, y = 1.4, z = 1.4 },
			{ x = x, y = 9.4, z = -630 },
			0,
			NEON_MAGENTA,
			"Neon",
			0.1,
			false,
			nil
		)
	)
end
for i = 1, 4 do
	push(
		piece(
			("LumenStall_%02d"):format(i),
			"Block",
			{ x = 6, y = 3.2, z = 4 },
			{ x = -40 + i * 18, y = 1.6, z = -560 },
			12 * i,
			{ 64, 40, 88 },
			"SmoothPlastic",
			0,
			false,
			nil
		)
	)
end

-- ── Bosque dos Ecos ────────────────────────────────────────────────────────
push(
	piece(
		"WoodsShrine",
		"Cylinder",
		{ x = 2, y = 8, z = 8 },
		{ x = 380, y = 1, z = -260 },
		0,
		MOSS,
		"Slate",
		0,
		false,
		nil
	)
)
push(
	piece(
		"WoodsHeart",
		"Ball",
		{ x = 3.2, y = 3.2, z = 3.2 },
		{ x = 380, y = 4.2, z = -260 },
		0,
		{ 120, 220, 180 },
		"Neon",
		0.2,
		false,
		{
			brightness = 1.1,
			rangeStuds = 16,
			rgb = { 120, 220, 180 },
			shadows = false,
		}
	)
)
for i = 1, 18 do
	local col = (i - 1) % 6
	local row = math.floor((i - 1) / 6)
	local x = 280 + col * 36 + (row % 2) * 10
	local z = -120 - row * 70
	push(
		piece(
			("WoodsTrunk_%02d"):format(i),
			"Cylinder",
			{ x = 10 + (i % 4) * 1.4, y = 2.2, z = 2.2 },
			{ x = x, y = 5 + (i % 4) * 0.7, z = z },
			0,
			WOOD,
			"Wood",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			("WoodsCanopy_%02d"):format(i),
			"Ball",
			{ x = 8 + (i % 3), y = 5, z = 8 + (i % 3) },
			{ x = x, y = 12 + (i % 3), z = z },
			0,
			LEAF,
			"Grass",
			0.05,
			false,
			nil
		)
	)
end
for i = 1, 10 do
	push(
		piece(
			("WoodsShroom_%02d"):format(i),
			"Ball",
			{ x = 1.6, y = 1.2, z = 1.6 },
			{ x = 300 + i * 18, y = 0.8, z = -200 - (i % 4) * 22 },
			0,
			{ 180, 80, 160 },
			"SmoothPlastic",
			0,
			false,
			nil
		)
	)
end

-- ── Porto Ferro ────────────────────────────────────────────────────────────
push(
	piece(
		"PortPier",
		"Block",
		{ x = 80, y = 0.6, z = 18 },
		{ x = -390, y = 0.4, z = -70 },
		0,
		RUST,
		"WoodPlanks",
		0,
		false,
		nil
	)
)
push(
	piece(
		"PortLighthouse",
		"Cylinder",
		{ x = 28, y = 6, z = 6 },
		{ x = -500, y = 14, z = 20 },
		0,
		IRON,
		"Metal",
		0,
		false,
		nil
	)
)
push(
	piece(
		"PortBeacon",
		"Ball",
		{ x = 3, y = 3, z = 3 },
		{ x = -500, y = 29, z = 20 },
		0,
		{ 255, 210, 120 },
		"Neon",
		0.05,
		false,
		{
			brightness = 1.5,
			rangeStuds = 30,
			rgb = { 255, 200, 110 },
			shadows = false,
		}
	)
)
for i = 1, 5 do
	push(
		piece(
			("PortCrate_%02d"):format(i),
			"Block",
			{ x = 3, y = 2.4, z = 3 },
			{ x = -420 + i * 10, y = 1.4, z = -62 },
			15 * i,
			RUST,
			"WoodPlanks",
			0,
			false,
			nil
		)
	)
end
for i = 1, 4 do
	push(
		piece(
			("PortMast_%02d"):format(i),
			"Cylinder",
			{ x = 16, y = 0.7, z = 0.7 },
			{ x = -360 - i * 22, y = 8, z = -20 },
			0,
			IRON,
			"Metal",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			("PortSail_%02d"):format(i),
			"Block",
			{ x = 8, y = 10, z = 0.3 },
			{ x = -360 - i * 22, y = 10, z = -20 },
			20,
			{ 220, 214, 200 },
			"Fabric",
			0.12,
			false,
			nil
		)
	)
end
for i = 1, 6 do
	push(
		piece(
			("PortWater_%02d"):format(i),
			"Block",
			{ x = 40, y = 0.4, z = 28 },
			{ x = -500 + (i % 3) * 42, y = -0.3, z = -140 + math.floor((i - 1) / 3) * 36 },
			0,
			SEA,
			"Glass",
			0.35,
			false,
			nil
		)
	)
end

-- ── Setor Cinza ────────────────────────────────────────────────────────────
push(
	piece(
		"GreyStack",
		"Cylinder",
		{ x = 36, y = 7, z = 7 },
		{ x = 320, y = 18, z = -570 },
		0,
		SMOKE,
		"Metal",
		0,
		false,
		nil
	)
)
push(
	piece(
		"GreyPlume",
		"Ball",
		{ x = 8, y = 5, z = 8 },
		{ x = 320, y = 38, z = -570 },
		0,
		{ 160, 160, 168 },
		"SmoothPlastic",
		0.45,
		false,
		nil
	)
)
for i = 1, 5 do
	push(
		piece(
			("GreyTank_%02d"):format(i),
			"Cylinder",
			{ x = 6, y = 8, z = 8 },
			{ x = 240 + i * 36, y = 3, z = -620 },
			0,
			IRON,
			"Metal",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			("GreyPipe_%02d"):format(i),
			"Block",
			{ x = 28, y = 1.2, z = 1.2 },
			{ x = 258 + i * 36, y = 6, z = -590 },
			20,
			SMOKE,
			"Metal",
			0,
			false,
			nil
		)
	)
end
for i = 1, 4 do
	push(
		piece(
			("GreyShed_%02d"):format(i),
			"Block",
			{ x = 14, y = 7, z = 10 },
			{ x = 220 + i * 40, y = 3.5, z = -500 },
			0,
			{ 84, 80, 78 },
			"CorrodedMetal",
			0,
			false,
			nil
		)
	)
end

-- ── Academia Alvorada ──────────────────────────────────────────────────────
push(
	piece(
		"AcademyRing",
		"Cylinder",
		{ x = 0.35, y = 28, z = 28 },
		{ x = 50, y = 0.22, z = 140 },
		0,
		GOLD,
		"Sandstone",
		0.05,
		false,
		nil
	)
)
push(
	piece(
		"AcademyClock",
		"Block",
		{ x = 6, y = 24, z = 6 },
		{ x = 50, y = 12, z = 140 },
		0,
		CREAM,
		"Sandstone",
		0,
		false,
		nil
	)
)
push(
	piece(
		"AcademyFace",
		"Block",
		{ x = 5, y = 5, z = 0.4 },
		{ x = 50, y = 22, z = 143.2 },
		0,
		GOLD,
		"Neon",
		0.1,
		false,
		{
			brightness = 0.8,
			rangeStuds = 14,
			rgb = GOLD,
			shadows = false,
		}
	)
)
for i = 1, 6 do
	local angle = (i - 1) / 6 * math.pi * 2
	push(
		piece(
			("AcademyCol_%02d"):format(i),
			"Cylinder",
			{ x = 10, y = 1.6, z = 1.6 },
			{ x = 50 + math.cos(angle) * 18, y = 5, z = 140 + math.sin(angle) * 18 },
			0,
			CREAM,
			"Marble",
			0,
			false,
			nil
		)
	)
end
for i = 1, 4 do
	push(
		piece(
			("AcademyBanner_%02d"):format(i),
			"Block",
			{ x = 0.3, y = 8, z = 3 },
			{ x = 10 + i * 22, y = 5, z = 80 },
			0,
			GOLD,
			"Fabric",
			0.08,
			false,
			nil
		)
	)
end

function BiomeDecorations.all(): { BiomePiece }
	return PIECES
end

function BiomeDecorations.lightCount(): number
	local count = 0
	for _, item in PIECES do
		if item.light then
			count += 1
		end
	end
	return count
end

local MAX_LIGHTS = 16

local function insideVolume(
	position: { x: number, y: number, z: number },
	volumes: { { min: { x: number, y: number, z: number }, max: { x: number, y: number, z: number } } }
): boolean
	for _, volume in volumes do
		if
			position.x >= volume.min.x
			and position.x <= volume.max.x
			and position.z >= volume.min.z
			and position.z <= volume.max.z
		then
			return true
		end
	end
	return false
end

function BiomeDecorations.validate(
	pieces: { BiomePiece },
	homeVolumes: {
		{
			min: { x: number, y: number, z: number },
			max: { x: number, y: number, z: number },
		}
	},
	shardAnchors: { { x: number, y: number, z: number } },
	crater: { x: number, z: number, radius: number }
): { string }
	local errors: { string } = {}
	local seen: { [string]: boolean } = {}
	local lights = 0
	for _, item in pieces do
		if seen[item.name] then
			table.insert(errors, "nome duplicado: " .. item.name)
		end
		seen[item.name] = true
		if item.canCollide then
			table.insert(errors, item.name .. " colide — decoração de bioma não pode ser parede")
		end
		if item.position.y < -1 then
			table.insert(errors, item.name .. " abaixo do chão")
		end
		if not insideVolume(item.position, homeVolumes) then
			table.insert(errors, item.name .. " fora de qualquer célula de bioma")
		end
		local dx = item.position.x - crater.x
		local dz = item.position.z - crater.z
		if math.sqrt(dx * dx + dz * dz) < crater.radius + 4 then
			table.insert(errors, item.name .. " invade o ringue do elite")
		end
		for _, anchor in shardAnchors do
			local adx = item.position.x - anchor.x
			local adz = item.position.z - anchor.z
			if math.sqrt(adx * adx + adz * adz) < 6 then
				table.insert(errors, item.name .. " encosta em âncora de Estilhaço")
			end
		end
		if item.light then
			lights += 1
		end
	end
	if lights > MAX_LIGHTS then
		table.insert(errors, ("luzes de bioma %d > teto %d"):format(lights, MAX_LIGHTS))
	end
	return errors
end

return BiomeDecorations

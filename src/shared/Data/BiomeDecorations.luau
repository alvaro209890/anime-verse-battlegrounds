--!strict
-- Decoração das células de bioma (docs/02 §3.4, docs/24).
-- Dados puros: o WorldService só materializa. Nada colide, nada entra no
-- ringue do elite nem nas âncoras de Estilhaço, nada invade portão.
-- F1: a célula do Distrito Lumen é urbana densa (rua, duas vielas, praça,
-- marco, dois serviços). Outros biomas continuam greybox + serra.

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

-- ── Distrito Lumen: célula urbana densa (F1, docs/24, docs/02 §3.4) ────────
-- Zona zone_lumen_safe: X −160..160, Z −700..−460. Rua principal no eixo
-- X=0 (livre |x|<13). Prédios ocos — fachada, lados, teto, janela, letreiro.
-- Nada colide. Letreiros são Neon emissivo; PointLight só na coroa e no
-- cristal da praça (docs/15: máx. 2 sombras por célula — aqui zero).
-- Disco da praça é asfalto, não anel neon (docs/17: não lê como alcance).

local CONCRETE_A = { 46, 42, 58 }
local CONCRETE_B = { 38, 34, 50 }
local CONCRETE_C = { 54, 48, 66 }
local WINDOW_WARM = { 255, 186, 110 }
local WINDOW_COOL = { 140, 220, 255 }
local AWNING = { 92, 36, 78 }
local EMBER = { 255, 140, 70 }

local function pushBlock(
	name: string,
	sx: number,
	sy: number,
	sz: number,
	px: number,
	py: number,
	pz: number,
	rgb: { number },
	material: string,
	transparency: number
): ()
	push(
		piece(
			name,
			"Block",
			{ x = sx, y = sy, z = sz },
			{ x = px, y = py, z = pz },
			0,
			rgb,
			material,
			transparency,
			false,
			nil
		)
	)
end

local function pushBall(
	name: string,
	diameter: number,
	px: number,
	py: number,
	pz: number,
	rgb: { number },
	transparency: number
): ()
	push(
		piece(
			name,
			"Ball",
			{ x = diameter, y = diameter, z = diameter },
			{ x = px, y = py, z = pz },
			0,
			rgb,
			"Neon",
			transparency,
			false,
			nil
		)
	)
end

-- Prédio oco. `frontX` é a face que olha a rua (|frontX| >= 18).
-- O lote cresce para longe do eixo X=0. Variantes mudam cor, acento e extra.
local function lumenBuilding(
	id: string,
	frontX: number,
	z: number,
	along: number,
	depth: number,
	height: number,
	variant: number
): ()
	local away = if frontX < 0 then -1 else 1
	local cx = frontX + away * (depth * 0.5)
	local body = if variant % 3 == 1 then CONCRETE_A elseif variant % 3 == 2 then CONCRETE_B else CONCRETE_C
	local bodyMat = if variant % 3 == 2 then "SmoothPlastic" elseif variant % 3 == 0 then "Slate" else "Concrete"
	local accent = if variant % 2 == 0 then NEON_MAGENTA else NEON
	local wall = 0.7
	local baseY = 0.16

	pushBlock(
		id .. "_Front",
		wall,
		height,
		along,
		frontX + away * (wall * 0.5),
		baseY + height * 0.5,
		z,
		body,
		bodyMat,
		0
	)
	pushBlock(
		id .. "_Back",
		wall,
		height * 0.98,
		along * 0.92,
		frontX + away * (depth - wall * 0.5),
		baseY + height * 0.49,
		z,
		body,
		"SmoothPlastic",
		0
	)
	pushBlock(
		id .. "_SideN",
		depth - wall,
		height * 0.96,
		wall,
		cx,
		baseY + height * 0.48,
		z - along * 0.5,
		body,
		"Concrete",
		0
	)
	pushBlock(
		id .. "_SideS",
		depth - wall,
		height * 0.94,
		wall,
		cx,
		baseY + height * 0.47 + 0.04,
		z + along * 0.5,
		body,
		bodyMat,
		0
	)
	pushBlock(id .. "_Roof", depth + 0.9, 0.65, along + 0.9, cx, baseY + height + 0.18, z, ASPHALT, "SmoothPlastic", 0)

	local winCount = math.floor(height / 5)
	if winCount < 1 then
		winCount = 1
	elseif winCount > 4 then
		winCount = 4
	end
	for w = 1, winCount do
		local wy = 2.5 + (w - 1) * ((height - 3.2) / winCount)
		local warm = (variant + w) % 2 == 0
		local winRgb = if warm then WINDOW_WARM else WINDOW_COOL
		local winMat = if (variant + w) % 3 == 0 then "Neon" else "SmoothPlastic"
		local zOff = if w % 2 == 0 then 2.1 else -2.1
		pushBlock(
			id .. "_Win" .. tostring(w),
			0.32,
			1.55,
			2.1,
			frontX - away * 0.22,
			wy,
			z + zOff,
			winRgb,
			winMat,
			0.12
		)
		if along > 15 then
			pushBlock(
				id .. "_WinB" .. tostring(w),
				0.32,
				1.35,
				1.8,
				frontX - away * 0.22,
				wy + 0.12,
				z - zOff * 1.35,
				winRgb,
				winMat,
				0.16
			)
		end
	end

	pushBlock(id .. "_Door", 0.28, 3.1, 1.9, frontX - away * 0.16, 1.7, z, ASPHALT, "SmoothPlastic", 0)
	pushBlock(id .. "_Sign", 0.38, 1.55, along * 0.52, frontX - away * 0.42, height * 0.70, z, accent, "Neon", 0.08)
	pushBlock(
		id .. "_Rib",
		0.34,
		height * 0.84,
		0.34,
		frontX + away * 0.45,
		baseY + height * 0.44,
		z - along * 0.42,
		accent,
		"Neon",
		0.12
	)

	if height <= 14 then
		pushBlock(id .. "_Awning", 3.1, 0.32, along * 0.68, frontX - away * 1.55, 3.55, z, AWNING, "SmoothPlastic", 0)
		pushBlock(id .. "_AwningTrim", 3.2, 0.14, along * 0.70, frontX - away * 1.55, 3.76, z, accent, "Neon", 0.14)
	end
	if height >= 20 then
		pushBlock(id .. "_Fin", 1.15, 3.8 + (variant % 3) * 0.7, 0.45, cx, baseY + height + 2.3, z, accent, "Neon", 0.1)
	end
end

-- Praça: piso de asfalto (não é anel de alcance). Torre + coroa no centro.
push(
	piece(
		"LumenPlaza",
		"Cylinder",
		{ x = 0.36, y = 40, z = 40 },
		{ x = 0, y = 0.22, z = -580 },
		0,
		ASPHALT,
		"SmoothPlastic",
		0,
		false,
		nil
	)
)
pushBlock("LumenPlazaRing", 22, 0.18, 22, 0, 0.34, -580, { 40, 32, 56 }, "SmoothPlastic", 0)
-- Inlays lineares (cruz), nunca um círculo neon.
pushBlock("LumenPlazaInlayN", 0.45, 0.16, 16, 0, 0.42, -590, NEON, "Neon", 0.2)
pushBlock("LumenPlazaInlayS", 0.45, 0.16, 16, 0, 0.42, -570, NEON, "Neon", 0.2)
pushBlock("LumenPlazaInlayW", 16, 0.16, 0.45, -8, 0.43, -580, NEON_MAGENTA, "Neon", 0.22)
pushBlock("LumenPlazaInlayE", 16, 0.16, 0.45, 8, 0.43, -580, NEON_MAGENTA, "Neon", 0.22)

-- Marco vertical: torre elevada + coroa + nervuras + flecha.
pushBlock("LumenPlinth", 16, 2.1, 16, 0, 1.1, -580, CONCRETE_B, "Concrete", 0)
pushBlock("LumenTower", 9, 50, 9, 0, 27.2, -580, ASPHALT, "SmoothPlastic", 0)
pushBlock("LumenBand", 12, 1.15, 12, 0, 28.4, -580, NEON, "Neon", 0.1)
pushBlock("LumenRibN", 0.55, 42, 0.55, 0, 24.2, -584.6, NEON, "Neon", 0.12)
pushBlock("LumenRibS", 0.55, 42, 0.55, 0, 24.2, -575.4, NEON, "Neon", 0.12)
pushBlock("LumenRibW", 0.55, 42, 0.55, -4.6, 24.25, -580, NEON_MAGENTA, "Neon", 0.12)
pushBlock("LumenRibE", 0.55, 42, 0.55, 4.6, 24.25, -580, NEON_MAGENTA, "Neon", 0.12)
push(
	piece(
		"LumenCrown",
		"Block",
		{ x = 15, y = 2.8, z = 15 },
		{ x = 0, y = 53.2, z = -580 },
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
pushBlock("LumenSpire", 1.8, 9.5, 1.8, 0, 59.4, -580, ASPHALT, "SmoothPlastic", 0)
pushBall("LumenSpireTip", 2.2, 0, 64.6, -580, NEON, 0.08)

-- Ponto de encontro da praça (sul da torre) — única luz nova da célula.
pushBlock("LumenPlazaMeet", 2.4, 0.7, 2.4, 0, 0.58, -562, CONCRETE_A, "Concrete", 0)
push(
	piece(
		"LumenPlazaCrystal",
		"Ball",
		{ x = 1.8, y = 2.4, z = 1.8 },
		{ x = 0, y = 2.15, z = -562 },
		0,
		NEON,
		"Neon",
		0.08,
		false,
		{
			brightness = 0.95,
			rangeStuds = 16,
			rgb = NEON,
			shadows = false,
		}
	)
)

-- Bancos e cristais da praça (não cercam a torre com anel de combate).
for i, spot in
	{
		{ name = "NW", x = -11, z = -591 },
		{ name = "NE", x = 11, z = -591 },
		{ name = "SW", x = -11, z = -569 },
		{ name = "SE", x = 11, z = -569 },
	}
do
	pushBlock("LumenBench" .. spot.name, 3.4, 0.55, 1.15, spot.x, 0.55, spot.z, CONCRETE_C, "SmoothPlastic", 0)
	pushBlock(
		"LumenBench" .. spot.name .. "Back",
		3.4,
		1.15,
		0.35,
		spot.x,
		1.15,
		spot.z + (if i <= 2 then -0.6 else 0.6),
		CONCRETE_B,
		"SmoothPlastic",
		0
	)
	local lampX = spot.x * 1.55
	local lampZ = spot.z + (if i <= 2 then -3.5 else 3.5)
	pushBlock("LumenPlazaLamp" .. spot.name, 0.4, 6.2, 0.4, lampX, 3.2, lampZ, ASPHALT, "SmoothPlastic", 0)
	pushBall("LumenPlazaGlow" .. spot.name, 1.15, lampX, 6.5, lampZ, if i % 2 == 0 then NEON_MAGENTA else NEON, 0.12)
end

-- Rua principal: faixas lineares (não anéis) e lampiões na calçada |x|=15.
for i = 1, 9 do
	local zz = -472 - (i - 1) * 22
	if zz < -564 and zz > -598 then
		continue
	end
	if zz < -698 or zz > -464 then
		continue
	end
	pushBlock(("LumenStreetDashW_%02d"):format(i), 0.38, 0.14, 9.5, -5.2, 0.12, zz, NEON, "Neon", 0.28)
	pushBlock(("LumenStreetDashE_%02d"):format(i), 0.38, 0.14, 9.5, 5.2, 0.13, zz, NEON, "Neon", 0.28)
end
for i, zz in { -476, -500, -524, -548, -608, -632, -656, -678 } do
	pushBlock(("LumenStreetLampW_%02d"):format(i), 0.45, 7.4, 0.45, -15.2, 3.8, zz, ASPHALT, "SmoothPlastic", 0)
	pushBall(("LumenStreetGlowW_%02d"):format(i), 1.2, -15.2, 7.7, zz, NEON, 0.12)
	pushBlock(("LumenStreetLampE_%02d"):format(i), 0.45, 7.2, 0.45, 15.2, 3.7, zz, ASPHALT, "SmoothPlastic", 0)
	pushBall(("LumenStreetGlowE_%02d"):format(i), 1.2, 15.2, 7.55, zz, NEON_MAGENTA, 0.12)
end

-- Fachadas da rua (oeste / leste). Alturas e recuos diferentes — não é grade.
-- Boca da viela oeste entre W01 e W02 (z ≈ −508..−493). Leste entre E02 e E03.
lumenBuilding("LumenBldW01", -18.5, -486, 14, 14, 12, 1)
lumenBuilding("LumenBldW02", -20.5, -518, 16, 16, 18, 2)
lumenBuilding("LumenBldW03", -18.5, -540, 14, 13, 11, 3)
lumenBuilding("LumenBldW04", -22.0, -560, 18, 18, 22, 4)
lumenBuilding("LumenBldW05", -19.5, -616, 16, 15, 16, 1)
lumenBuilding("LumenBldW06", -23.0, -638, 20, 17, 24, 2)
lumenBuilding("LumenBldW07", -18.5, -662, 16, 14, 14, 3)

lumenBuilding("LumenBldE01", 19.0, -484, 14, 15, 14, 2)
lumenBuilding("LumenBldE02", 18.5, -504, 14, 12, 11, 1)
lumenBuilding("LumenBldE03", 22.0, -534, 18, 17, 20, 4)
lumenBuilding("LumenBldE04", 19.0, -556, 14, 14, 15, 3)
lumenBuilding("LumenBldE05", 21.0, -614, 18, 16, 18, 2)
lumenBuilding("LumenBldE06", 18.5, -636, 16, 13, 12, 1)
lumenBuilding("LumenBldE07", 24.0, -660, 18, 18, 26, 4)

-- Skyline (verticalidade VISUAL, sem piso de combate). Longe da rua.
lumenBuilding("LumenSky01", -86, -492, 16, 14, 32, 4)
lumenBuilding("LumenSky02", -112, -530, 18, 16, 38, 2)
lumenBuilding("LumenSky03", -98, -572, 14, 13, 28, 3)
lumenBuilding("LumenSky04", -90, -648, 16, 15, 36, 4)
lumenBuilding("LumenSky05", 88, -488, 16, 14, 30, 1)
lumenBuilding("LumenSky06", 114, -524, 18, 16, 40, 4)
lumenBuilding("LumenSky07", 100, -570, 14, 13, 26, 2)
lumenBuilding("LumenSky08", 108, -650, 16, 15, 34, 3)

-- Viela oeste: abertura na rua → oeste → jog norte → cotovelo → praça.
-- O jog quebra a linha de visão (docs/02 §3.3). Corredor ~10 studs livre.
pushBlock("LumenAlleyW_WallA", 0.7, 10, 22, -52, 5.1, -500, CONCRETE_B, "Concrete", 0)
pushBlock("LumenAlleyW_WallB", 28, 11, 0.7, -68, 5.6, -512, CONCRETE_A, "SmoothPlastic", 0)
pushBlock("LumenAlleyW_Jog", 12, 16, 10, -104, 8.1, -548, CONCRETE_C, "Slate", 0)
pushBlock("LumenAlleyW_Wing", 8, 13, 14, -112, 6.6, -560, CONCRETE_B, "Concrete", 0)
pushBlock("LumenAlleyW_Elbow", 10, 14, 8, -86, 7.1, -628, CONCRETE_A, "SmoothPlastic", 0)
pushBlock("LumenAlleyW_Cap", 0.6, 9, 16, -42, 4.6, -608, CONCRETE_C, "Concrete", 0)
pushBlock("LumenAlleyW_Lamp1", 0.4, 6.4, 0.4, -78, 3.3, -520, ASPHALT, "SmoothPlastic", 0)
pushBall("LumenAlleyW_Glow1", 1.05, -78, 6.7, -520, NEON, 0.14)
pushBlock("LumenAlleyW_Lamp2", 0.4, 6.4, 0.4, -96, 3.3, -620, ASPHALT, "SmoothPlastic", 0)
pushBall("LumenAlleyW_Glow2", 1.05, -96, 6.7, -620, NEON_MAGENTA, 0.14)

-- Viela leste: jog em Z diferente da oeste, para não espelhar a planta.
pushBlock("LumenAlleyE_WallA", 0.7, 10, 18, 54, 5.1, -518, CONCRETE_A, "Concrete", 0)
pushBlock("LumenAlleyE_WallB", 30, 11, 0.7, 72, 5.6, -528, CONCRETE_C, "SmoothPlastic", 0)
pushBlock("LumenAlleyE_Jog", 12, 17, 10, 116, 8.6, -576, CONCRETE_B, "Slate", 0)
pushBlock("LumenAlleyE_Wing", 8, 12, 16, 124, 6.1, -590, CONCRETE_A, "Concrete", 0)
pushBlock("LumenAlleyE_Elbow", 10, 13, 8, 88, 6.6, -632, CONCRETE_C, "SmoothPlastic", 0)
pushBlock("LumenAlleyE_Cap", 0.6, 9, 16, 44, 4.6, -610, CONCRETE_B, "Concrete", 0)
pushBlock("LumenAlleyE_Lamp1", 0.4, 6.4, 0.4, 80, 3.3, -540, ASPHALT, "SmoothPlastic", 0)
pushBall("LumenAlleyE_Glow1", 1.05, 80, 6.7, -540, NEON_MAGENTA, 0.14)
pushBlock("LumenAlleyE_Lamp2", 0.4, 6.4, 0.4, 100, 3.3, -624, ASPHALT, "SmoothPlastic", 0)
pushBall("LumenAlleyE_Glow2", 1.05, 100, 6.7, -624, NEON, 0.14)

-- Passarelas só sobre as vielas (y alto, sem colisão — não é piso de luta).
pushBlock("LumenBridgeW", 18, 0.7, 3.2, -70, 22.4, -508, CONCRETE_B, "SmoothPlastic", 0)
pushBlock("LumenBridgeWRail", 18, 0.9, 0.25, -70, 23.2, -506.5, NEON, "Neon", 0.2)
pushBlock("LumenBridgeE", 18, 0.7, 3.2, 74, 23.1, -526, CONCRETE_A, "SmoothPlastic", 0)
pushBlock("LumenBridgeERail", 18, 0.9, 0.25, 74, 23.9, -524.5, NEON_MAGENTA, "Neon", 0.2)

-- Serviço 1 — Mercado (leste da praça). Bancada + toldo + caixas + letreiro.
pushBlock("LumenVendor_Back", 0.6, 6.4, 10, 58, 3.3, -598, CONCRETE_C, "Concrete", 0)
pushBlock("LumenVendor_Counter", 3.4, 1.15, 8.5, 54.2, 1.05, -598, CONCRETE_A, "SmoothPlastic", 0)
pushBlock("LumenVendor_Awning", 6.5, 0.35, 10.5, 53.4, 4.15, -598, AWNING, "SmoothPlastic", 0)
pushBlock("LumenVendor_AwningTrim", 6.6, 0.14, 10.6, 53.4, 4.36, -598, NEON, "Neon", 0.12)
pushBlock("LumenVendor_Sign", 0.45, 4.8, 3.6, 51.6, 7.4, -598, NEON, "Neon", 0.06)
pushBlock("LumenVendor_CrateA", 1.8, 1.5, 1.8, 55.6, 0.85, -593.2, { 64, 40, 88 }, "SmoothPlastic", 0)
pushBlock("LumenVendor_CrateB", 1.5, 1.2, 1.5, 53.4, 0.72, -603.4, { 72, 48, 96 }, "SmoothPlastic", 0)
pushBlock("LumenVendor_Shelf", 0.4, 2.4, 6, 57.4, 3.4, -598, CONCRETE_B, "SmoothPlastic", 0)
pushBall("LumenVendor_Lantern", 1.1, 53.2, 3.9, -598, WINDOW_WARM, 0.1)

-- Serviço 2 — Forja (oeste da praça). Lar + chaminé + brasa (bola, sem anel).
pushBlock("LumenForge_Hearth", 6.2, 2.0, 6.2, -54, 1.1, -598, ASPHALT, "Basalt", 0)
pushBlock("LumenForge_Chimney", 2.1, 11, 2.1, -56.4, 7.4, -600.4, CONCRETE_B, "Concrete", 0)
pushBlock("LumenForge_Anvil", 3.1, 1.35, 1.8, -51.6, 2.35, -596.4, SMOKE, "Metal", 0)
pushBlock("LumenForge_Sign", 0.45, 4.8, 3.6, -49.2, 7.4, -598, NEON_MAGENTA, "Neon", 0.06)
pushBlock("LumenForge_Rack", 0.35, 3.2, 4.4, -57.6, 2.4, -595.2, IRON, "Metal", 0)
pushBlock("LumenForge_Back", 0.6, 6.2, 8, -58.4, 3.2, -598, CONCRETE_A, "Concrete", 0)
pushBall("LumenForge_Ember", 1.5, -54, 2.6, -598, EMBER, 0.05)

-- Borda sul (planície): vão x −24..24 livre. Postes + lintel — docs/02 §4.2.
pushBlock("LumenArrivePad", 46, 0.16, 8, 0, 0.14, -470, { 28, 24, 42 }, "Asphalt", 0)
pushBlock("LumenGatePostW", 2.8, 12, 2.8, -28, 6.1, -464, CONCRETE_B, "Concrete", 0)
pushBlock("LumenGatePostE", 2.8, 12, 2.8, 28, 6.1, -464, CONCRETE_B, "Concrete", 0)
pushBlock("LumenGateCapW", 3.2, 1.1, 3.2, -28, 12.6, -464, NEON, "Neon", 0.1)
pushBlock("LumenGateCapE", 3.2, 1.1, 3.2, 28, 12.6, -464, NEON, "Neon", 0.1)
pushBlock("LumenGateLintel", 52, 1.15, 1.15, 0, 13.1, -464, NEON, "Neon", 0.12)
for i, gx in { -52, -80, -118, 52, 80, 118 } do
	pushBlock(("LumenBorderPost_%02d"):format(i), 1.6, 7.5, 1.6, gx, 3.85, -462.5, CONCRETE_A, "SmoothPlastic", 0)
	pushBall(("LumenBorderGlow_%02d"):format(i), 0.95, gx, 7.8, -462.5, if gx < 0 then NEON else NEON_MAGENTA, 0.16)
end

-- Vasos na calçada (fora da rua e das bocas de viela).
for i, pot in
	{
		{ x = -15.2, z = -488 },
		{ x = -15.2, z = -544 },
		{ x = -15.2, z = -624 },
		{ x = -15.2, z = -668 },
		{ x = 15.2, z = -492 },
		{ x = 15.2, z = -544 },
		{ x = 15.2, z = -624 },
		{ x = 15.2, z = -668 },
	}
do
	pushBlock(("LumenPlanter_%02d"):format(i), 1.8, 0.7, 1.8, pot.x, 0.48, pot.z, ASPHALT, "SmoothPlastic", 0)
	pushBall(("LumenBush_%02d"):format(i), 1.5, pot.x, 1.45, pot.z, if i % 2 == 0 then NEON else NEON_MAGENTA, 0.28)
end

-- Caixas nas vielas (não na rua).
pushBlock("LumenAlleyCrateW1", 1.6, 1.3, 1.6, -64, 0.75, -522, { 58, 36, 80 }, "SmoothPlastic", 0)
pushBlock("LumenAlleyCrateW2", 1.4, 1.1, 1.4, -90, 0.65, -624, { 64, 40, 88 }, "SmoothPlastic", 0)
pushBlock("LumenAlleyCrateE1", 1.6, 1.3, 1.6, 68, 0.75, -538, { 58, 36, 80 }, "SmoothPlastic", 0)
pushBlock("LumenAlleyCrateE2", 1.4, 1.1, 1.4, 96, 0.65, -628, { 64, 40, 88 }, "SmoothPlastic", 0)

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
-- Bosque denso: LCG com semente fixa, NÃO grade. Grade lia como pomar.
do
	local seed = 20260819
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local occupied: { { x: number, z: number, r: number } } = {
		{ x = 380, z = -260, r = 10 },
		{ x = 320, z = -180, r = 8 },
		{ x = 440, z = -340, r = 8 },
	}
	local function claim(x: number, z: number, radius: number): boolean
		if x < 252 or x > 508 or z < -428 or z > -92 then
			return false
		end
		for _, spot in occupied do
			local dx, dz = x - spot.x, z - spot.z
			if dx * dx + dz * dz < (radius + spot.r) * (radius + spot.r) then
				return false
			end
		end
		table.insert(occupied, { x = x, z = z, r = radius })
		return true
	end
	local planted = 0
	local attempts = 0
	while planted < 42 and attempts < 2200 do
		attempts += 1
		local x = 260 + rnd() * 240
		local z = -420 + rnd() * 320
		if claim(x, z, 9) then
			planted += 1
			local height = 9 + rnd() * 7
			push(
				piece(
					("WoodsTrunk_%02d"):format(planted),
					"Cylinder",
					{ x = height, y = 1.8 + (planted % 3) * 0.35, z = 1.8 + (planted % 3) * 0.35 },
					{ x = x, y = height / 2, z = z },
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
					("WoodsCanopy_%02d"):format(planted),
					"Ball",
					{ x = 7.5 + (planted % 4), y = 5.2 + (planted % 3) * 0.4, z = 7.2 + (planted % 3) },
					{ x = x + (rnd() - 0.5) * 1.4, y = height + 1.6, z = z + (rnd() - 0.5) * 1.4 },
					0,
					if planted % 3 == 0 then MOSS else LEAF,
					"Grass",
					0.04,
					false,
					nil
				)
			)
			push(
				piece(
					("WoodsCanopyB_%02d"):format(planted),
					"Ball",
					{ x = 5.2, y = 3.6, z = 5.6 },
					{ x = x + 1.8, y = height + 3.2, z = z - 1.2 },
					0,
					LEAF,
					"Grass",
					0.08,
					false,
					nil
				)
			)
		end
	end
	local under = 0
	local underTries = 0
	while under < 36 and underTries < 1600 do
		underTries += 1
		local x = 265 + rnd() * 230
		local z = -415 + rnd() * 310
		if claim(x, z, 3.2) then
			under += 1
			if under % 3 == 0 then
				push(
					piece(
						("WoodsShroom_%02d"):format(under),
						"Ball",
						{ x = 1.5, y = 1.15, z = 1.5 },
						{ x = x, y = 0.72, z = z },
						0,
						{ 180, 80, 160 },
						"SmoothPlastic",
						0,
						false,
						nil
					)
				)
			else
				push(
					piece(
						("WoodsFern_%02d"):format(under),
						"Block",
						{ x = 1.4, y = 1.6, z = 0.35 },
						{ x = x, y = 0.85, z = z },
						rnd() * 180,
						LEAF,
						"LeafyGrass",
						0,
						false,
						nil
					)
				)
			end
		end
	end
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
for i = 1, 10 do
	push(
		piece(
			("PortReed_%02d"):format(i),
			"Block",
			{ x = 0.35, y = 3.2 + (i % 3) * 0.4, z = 0.35 },
			{ x = -330 - (i % 5) * 14, y = 1.7, z = 8 + math.floor((i - 1) / 5) * 18 },
			12 * i,
			MOSS,
			"Grass",
			0,
			false,
			nil
		)
	)
end
for i = 1, 8 do
	push(
		piece(
			("PortShrub_%02d"):format(i),
			"Ball",
			{ x = 2.4, y = 1.6, z = 2.2 },
			{ x = -280 - i * 16, y = 0.9, z = 40 - (i % 3) * 12 },
			0,
			MOSS,
			"LeafyGrass",
			0,
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
for i = 1, 12 do
	push(
		piece(
			("GreyWeed_%02d"):format(i),
			"Ball",
			{ x = 1.8, y = 1.1, z = 1.6 },
			{ x = 190 + (i % 6) * 42, y = 0.62, z = -460 - math.floor((i - 1) / 6) * 36 },
			0,
			{ 70, 78, 58 },
			"Grass",
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
for i = 1, 8 do
	push(
		piece(
			("AcademyHedge_%02d"):format(i),
			"Block",
			{ x = 10, y = 2.2, z = 1.4 },
			{ x = -40 + (i % 4) * 36, y = 1.15, z = 70 + math.floor((i - 1) / 4) * 90 },
			0,
			MOSS,
			"LeafyGrass",
			0,
			false,
			nil
		)
	)
end
for i = 1, 6 do
	push(
		piece(
			("AcademyTree_%02d"):format(i),
			"Cylinder",
			{ x = 8, y = 1.2, z = 1.2 },
			{ x = -50 + i * 28, y = 4, z = 200 },
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
			("AcademyCanopy_%02d"):format(i),
			"Ball",
			{ x = 5.4, y = 3.6, z = 5.4 },
			{ x = -50 + i * 28, y = 9.2, z = 200 },
			0,
			LEAF,
			"Grass",
			0.05,
			false,
			nil
		)
	)
end

-- ── Densidade extra (18/08): postos de leitura por célula ─────────────────
-- Sem PointLight (teto 16). Sem colisão. Fora das âncoras de Fátuo/santuário.

pushBlock("WoodsShrineRing", 0.35, 0.35, 16, 380, 0.22, -260, MOSS, "Slate", 0.08)
pushBlock("WoodsShrineStep", 6, 0.4, 6, 380, 0.25, -248, { 70, 88, 64 }, "Limestone", 0)
for i = 1, 4 do
	local angle = (i - 1) / 4 * math.pi * 2
	push(
		piece(
			("WoodsLantern_%02d"):format(i),
			"Cylinder",
			{ x = 2.4, y = 0.55, z = 0.55 },
			{ x = 380 + math.cos(angle) * 14, y = 2.4, z = -260 + math.sin(angle) * 14 },
			0,
			{ 180, 220, 140 },
			"Neon",
			0.15,
			false,
			nil
		)
	)
end
for i = 1, 3 do
	pushBlock(("WoodsLog_%02d"):format(i), 7 + i, 0.7, 0.8, 300 + i * 28, 0.4, -210 - i * 18, WOOD, "Wood", 0)
end
for i = 1, 6 do
	pushBall(
		("WoodsMist_%02d"):format(i),
		2.2 + (i % 3) * 0.3,
		350 + (i % 3) * 22,
		1.4,
		-300 - math.floor((i - 1) / 3) * 24,
		{ 150, 210, 180 },
		0.45
	)
end

pushBlock("PortCraneMast", 1.4, 22, 1.4, -470, 11, -40, IRON, "Metal", 0)
pushBlock("PortCraneArm", 28, 1.1, 1.1, -456, 21, -40, RUST, "Metal", 0)
pushBlock("PortWarehouse_W", 22, 9, 14, -300, 4.5, 20, { 96, 82, 70 }, "CorrodedMetal", 0)
pushBlock("PortWarehouse_E", 18, 8, 12, -300, 4, -120, { 88, 76, 66 }, "CorrodedMetal", 0)
for i = 1, 6 do
	push(
		piece(
			("PortBollard_%02d"):format(i),
			"Cylinder",
			{ x = 1.6, y = 0.7, z = 0.7 },
			{ x = -430 + i * 12, y = 0.9, z = -78 },
			0,
			IRON,
			"Metal",
			0,
			false,
			nil
		)
	)
end
for i = 1, 4 do
	pushBlock(("PortCrateB_%02d"):format(i), 2.6, 2.2, 2.6, -400 + i * 8, 1.2, -52, RUST, "WoodPlanks", 0)
end

for i = 1, 8 do
	pushBlock(
		("GreyFence_%02d"):format(i),
		0.4,
		2.4,
		0.4,
		200 + (i % 4) * 40,
		1.2,
		-480 - math.floor((i - 1) / 4) * 50,
		SMOKE,
		"Metal",
		0
	)
end
pushBlock("GreyConveyor_A", 36, 0.7, 3.2, 300, 0.55, -540, IRON, "Metal", 0)
pushBlock("GreyConveyor_B", 28, 0.7, 3.2, 360, 0.55, -560, IRON, "Metal", 0)
for i = 1, 3 do
	pushBall(("GreyRust_%02d"):format(i), 3.4, 250 + i * 30, 0.8, -530, RUST, 0)
end
for i = 1, 4 do
	pushBall(("GreyLamp_%02d"):format(i), 1.1, 230 + i * 42, 7.2, -505, { 255, 170, 70 }, 0.1)
end

for i = 1, 4 do
	pushBlock(("AcademyBench_%02d"):format(i), 5.5, 0.7, 1.4, 20 + i * 18, 0.45, 110, CREAM, "WoodPlanks", 0)
end
push(
	piece(
		"AcademySideRing",
		"Cylinder",
		{ x = 0.3, y = 16, z = 16 },
		{ x = 10, y = 0.2, z = 180 },
		0,
		GOLD,
		"Sandstone",
		0.12,
		false,
		nil
	)
)
for i = 1, 4 do
	push(
		piece(
			("AcademyLamp_%02d"):format(i),
			"Cylinder",
			{ x = 3.6, y = 0.45, z = 0.45 },
			{ x = 20 + (i % 2) * 60, y = 3.4, z = 90 + math.floor((i - 1) / 2) * 70 },
			0,
			GOLD,
			"Neon",
			0.12,
			false,
			nil
		)
	)
end
pushBlock("AcademyPlinth", 8, 0.6, 8, 50, 0.35, 168, CREAM, "Marble", 0)

-- Montanhas de identidade por célula. Sem luz nova (teto 16). Sem colisão.
local SNOW = { 236, 236, 242 }
local PEAK_SLATE = { 72, 68, 64 }
local PEAK_LIME = { 150, 138, 116 }

local function biomePeak(
	prefix: string,
	x: number,
	z: number,
	width: number,
	height: number,
	depth: number,
	baseRgb: { number },
	midRgb: { number },
	midMaterial: string,
	snow: boolean
): ()
	push(
		piece(
			prefix .. "_Base",
			"Block",
			{ x = width, y = height * 0.32, z = depth },
			{ x = x, y = height * 0.16, z = z },
			0,
			baseRgb,
			"Slate",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			prefix .. "_Mid",
			"Block",
			{ x = width * 0.64, y = height * 0.36, z = depth * 0.66 },
			{ x = x, y = height * 0.32 + height * 0.18, z = z },
			0,
			midRgb,
			midMaterial,
			0,
			false,
			nil
		)
	)
	push(
		piece(
			prefix .. "_Peak",
			"Block",
			{ x = width * 0.30, y = height * 0.22, z = depth * 0.32 },
			{ x = x, y = height * 0.68 + height * 0.11, z = z },
			0,
			PEAK_SLATE,
			"Basalt",
			0,
			false,
			nil
		)
	)
	push(
		piece(
			prefix .. "_Cap",
			"Ball",
			{ x = width * 0.20, y = height * 0.12, z = depth * 0.20 },
			{ x = x, y = height * 0.92, z = z },
			0,
			if snow then SNOW else PEAK_LIME,
			if snow then "Snow" else "Sandstone",
			0,
			false,
			nil
		)
	)
end

-- Bosque: serra arborizada no fundo leste.
biomePeak("WoodsRidge_01", 498, -400, 36, 52, 26, MOSS, LEAF, "Limestone", false)
biomePeak("WoodsRidge_02", 492, -140, 32, 44, 24, WOOD, LEAF, "Limestone", false)
push(
	piece(
		"WoodsRidge_01_Tree",
		"Ball",
		{ x = 10, y = 7, z = 10 },
		{ x = 490, y = 28, z = -396 },
		0,
		LEAF,
		"Grass",
		0.06,
		false,
		nil
	)
)

-- Lumen: recorte escuro com acento neon, sem nova luz.
biomePeak("LumenRidge_01", -120, -682, 34, 48, 24, ASPHALT, { 64, 40, 88 }, "SmoothPlastic", false)
biomePeak("LumenRidge_02", 118, -678, 32, 42, 22, ASPHALT, { 48, 36, 72 }, "SmoothPlastic", false)
push(
	piece(
		"LumenRidge_01_Trim",
		"Block",
		{ x = 18, y = 1.2, z = 1.2 },
		{ x = -120, y = 36, z = -682 },
		0,
		NEON_MAGENTA,
		"Neon",
		0.2,
		false,
		nil
	)
)

-- Cinza: rocha seca / indústria no fundo norte.
biomePeak("GreyRidge_01", 450, -682, 38, 50, 26, SMOKE, IRON, "Basalt", false)
biomePeak("GreyRidge_02", 210, -678, 34, 40, 24, IRON, SMOKE, "Basalt", false)

-- Porto: falésia de ferro no horizonte oeste.
biomePeak("PortRidge_01", -518, -180, 34, 46, 24, IRON, RUST, "Rock", false)
biomePeak("PortRidge_02", -508, 56, 30, 38, 22, IRON, RUST, "Rock", false)

-- Academia: colina de arenito no fundo do campus.
biomePeak("AcademyRidge_01", 158, 218, 32, 36, 22, CREAM, GOLD, "Sandstone", false)

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

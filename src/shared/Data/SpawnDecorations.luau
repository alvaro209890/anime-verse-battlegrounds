--!strict
-- SpawnDecorations (shared) — decoração procedural da área de spawn (F0).
-- Dados puros: o WorldService materializa em Parts; os testes validam as
-- regras (nada invade os portões, decoração solta fica dentro do volume,
-- a muralha não engole âncoras). Nenhuma regra de jogo vive aqui.
--
-- Bastião do Limiar (zone_bastion_safe): 80×64 centrado na origem
-- (x −40..40, z −32..32). Portões (volumes de transição):
--   norte — x −6..6 em z −32
--   oeste — z −5..5 em x −40
-- Âncoras críticas: spawn (0,0,20), marco (0,0,12), instrutor (20,0,−11),
-- treino (28,0,−20), portões (0,0,−32) e (−40,0,0).
--
-- 17/08: os quatro pilares-marco do bastião passaram a morar aqui
-- (`bastionPillars`). Antes eram uma tabela solta dentro do `buildWalls`, e por
-- isso escapavam da regra de folga da âncora — o pilar (20, −16) ocupava
-- z −18..−14 com a Instrutora plantada em z −14, ou seja, DENTRO dele.

export type Decoration = {
	name: string,
	shape: string, -- "Part" | "Cylinder"
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	rgb: { number }, -- cor pura {r,g,b}
	material: string, -- "SmoothPlastic" | "Neon" | "Slate"
	canCollide: boolean,
	transparency: number,
}

local SpawnDecorations = {}

local DARK = { 82, 85, 88 }
local UMBRAL = { 118, 84, 158 }
local UMBRAL_CORE = { 206, 196, 224 }

local function deco(
	name: string,
	shape: string,
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	rgb: { number },
	material: string,
	canCollide: boolean,
	transparency: number
): Decoration
	return {
		name = name,
		shape = shape,
		size = size,
		position = position,
		rgb = rgb,
		material = material,
		canCollide = canCollide,
		transparency = transparency,
	}
end

-- ── Muralha de perímetro: JÁ EXISTE no `buildWalls` do WorldService
-- (GateBlock, aberturas exatas dos portões). Este módulo só decora: pilares
-- dos cantos/portões, cristais, arcos, lanternas, obelisco e anel do treino.
local WALL_Y = 16

local function pillar(name: string, position: { x: number, y: number, z: number })
	return deco(name, "Part", { x = 2.2, y = WALL_Y, z = 2.2 }, position, DARK, "Slate", true, 0)
end

-- Pilares-marco do bastião (§8.1): os quatro de 20 studs que dão a silhueta
-- vista da planície. O `buildWalls` só materializa — a posição é dado, e dado
-- passa por `anchorClearanceErrors`.
export type MarkerPillar = {
	name: string,
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
}

local PILLAR_MARK_HEIGHT = 20
local PILLAR_MARK_SIDE = 4

local function markerPillar(name: string, x: number, z: number): MarkerPillar
	return {
		name = name,
		size = { x = PILLAR_MARK_SIDE, y = PILLAR_MARK_HEIGHT, z = PILLAR_MARK_SIDE },
		position = { x = x, y = PILLAR_MARK_HEIGHT / 2, z = z },
	}
end

local MARKER_PILLARS: { MarkerPillar } = {
	markerPillar("Pillar1", -20, -16),
	markerPillar("Pillar2", 20, -16),
	markerPillar("Pillar3", -20, 16),
	markerPillar("Pillar4", 20, 16),
}

local function crystal(name: string, position: { x: number, y: number, z: number })
	return deco(name, "Part", { x = 1.4, y = 1.4, z = 1.4 }, position, UMBRAL_CORE, "Neon", false, 0)
end

local function lantern(name: string, position: { x: number, y: number, z: number })
	-- Poste fino + esfera Neon (uma peça por item: duas no total por ponto).
	return deco(
		name .. "_Pole",
		"Part",
		{ x = 0.45, y = 3.2, z = 0.45 },
		{ x = position.x, y = 1.6, z = position.z },
		DARK,
		"Slate",
		false,
		0
	)
end

local function lanternGlow(name: string, position: { x: number, y: number, z: number })
	return deco(
		name .. "_Glow",
		"Part",
		{ x = 0.9, y = 0.9, z = 0.9 },
		{ x = position.x, y = 3.4, z = position.z },
		UMBRAL_CORE,
		"Neon",
		false,
		0
	)
end

local DECORATIONS: { Decoration } = {
	-- ── Pilares dos cantos e das laterais dos portões + cristais ─────────
	pillar("Pillar_NW", { x = -38.5, y = WALL_Y / 2, z = -30.5 }),
	pillar("Pillar_NE", { x = 38.5, y = WALL_Y / 2, z = -30.5 }),
	pillar("Pillar_SW", { x = -38.5, y = WALL_Y / 2, z = 30.5 }),
	pillar("Pillar_SE", { x = 38.5, y = WALL_Y / 2, z = 30.5 }),
	pillar("Pillar_GateNorthW", { x = -7.2, y = WALL_Y / 2, z = -30.5 }),
	pillar("Pillar_GateNorthE", { x = 7.2, y = WALL_Y / 2, z = -30.5 }),
	pillar("Pillar_GateWestN", { x = -38.5, y = WALL_Y / 2, z = -6.2 }),
	pillar("Pillar_GateWestS", { x = -38.5, y = WALL_Y / 2, z = 6.2 }),
	crystal("Crystal_NW", { x = -38.5, y = WALL_Y + 1, z = -30.5 }),
	crystal("Crystal_NE", { x = 38.5, y = WALL_Y + 1, z = -30.5 }),
	crystal("Crystal_SW", { x = -38.5, y = WALL_Y + 1, z = 30.5 }),
	crystal("Crystal_SE", { x = 38.5, y = WALL_Y + 1, z = 30.5 }),
	crystal("Crystal_GateNorthW", { x = -7.2, y = WALL_Y + 1, z = -30.5 }),
	crystal("Crystal_GateNorthE", { x = 7.2, y = WALL_Y + 1, z = -30.5 }),
	crystal("Crystal_GateWestN", { x = -38.5, y = WALL_Y + 1, z = -6.2 }),
	crystal("Crystal_GateWestS", { x = -38.5, y = WALL_Y + 1, z = 6.2 }),

	-- ── Arcos dos portões (visual; a passagem continua livre) ─────────────
	deco(
		"Arch_North_Lintel",
		"Part",
		{ x = 13.2, y = 0.9, z = 0.9 },
		{ x = 0, y = WALL_Y + 0.6, z = -30.5 },
		UMBRAL,
		"Neon",
		false,
		0
	),
	deco(
		"Arch_West_Lintel",
		"Part",
		{ x = 0.9, y = 0.9, z = 11.2 },
		{ x = -38.5, y = WALL_Y + 0.6, z = 0 },
		UMBRAL,
		"Neon",
		false,
		0
	),

	-- ── Obelisco do Marco de Retorno (atrás do marco, fora do raio) ──────
	deco("Obelisk_Base", "Part", { x = 2.2, y = 5.4, z = 2.2 }, { x = 0, y = 2.7, z = 7 }, DARK, "Slate", false, 0),
	deco(
		"Obelisk_Top",
		"Part",
		{ x = 1.1, y = 1.1, z = 1.1 },
		{ x = 0, y = 5.8, z = 7 },
		UMBRAL_CORE,
		"Neon",
		false,
		0
	),

	-- ── Lanternas do caminho norte e da praça ─────────────────────────────
	lantern("Lantern_North1", { x = -2.5, z = -22 }),
	lanternGlow("Lantern_North1", { x = -2.5, z = -22 }),
	lantern("Lantern_North2", { x = 2.5, z = -22 }),
	lanternGlow("Lantern_North2", { x = 2.5, z = -22 }),
	lantern("Lantern_North3", { x = -2.5, z = -30 }),
	lanternGlow("Lantern_North3", { x = -2.5, z = -30 }),
	lantern("Lantern_North4", { x = 2.5, z = -30 }),
	lanternGlow("Lantern_North4", { x = 2.5, z = -30 }),
	lantern("Lantern_Plaza1", { x = -6, z = 12 }),
	lanternGlow("Lantern_Plaza1", { x = -6, z = 12 }),
	lantern("Lantern_Plaza2", { x = 6, z = 12 }),
	lanternGlow("Lantern_Plaza2", { x = 6, z = 12 }),
	lantern("Lantern_Plaza3", { x = -6, z = 20 }),
	lanternGlow("Lantern_Plaza3", { x = -6, z = 20 }),
	lantern("Lantern_Plaza4", { x = 6, z = 20 }),
	lanternGlow("Lantern_Plaza4", { x = 6, z = 20 }),

	-- ── Anel do TrainingPad (24×24 centrado em (28,0,−20)) ────────────────
	deco(
		"Training_Ring_N",
		"Part",
		{ x = 24, y = 0.25, z = 0.3 },
		{ x = 28, y = 0.15, z = -31.8 },
		UMBRAL,
		"Neon",
		false,
		0
	),
	deco(
		"Training_Ring_S",
		"Part",
		{ x = 24, y = 0.25, z = 0.3 },
		{ x = 28, y = 0.15, z = -8.2 },
		UMBRAL,
		"Neon",
		false,
		0
	),
	deco(
		"Training_Ring_W",
		"Part",
		{ x = 0.3, y = 0.25, z = 24 },
		{ x = 16.2, y = 0.15, z = -20 },
		UMBRAL,
		"Neon",
		false,
		0
	),
	deco(
		"Training_Ring_E",
		"Part",
		{ x = 0.3, y = 0.25, z = 24 },
		{ x = 39.8, y = 0.15, z = -20 },
		UMBRAL,
		"Neon",
		false,
		0
	),
}

function SpawnDecorations.all(): { Decoration }
	return DECORATIONS
end

function SpawnDecorations.bastionPillars(): { MarkerPillar }
	return MARKER_PILLARS
end

-- Folga da âncora: nada sólido pode encostar num ponto onde o jogo planta ator
-- ou manda o jogador ir parar (margem de 2 studs no plano XZ). Vale para
-- decoração colidível E para os pilares-marco — é a MESMA regra, e ficar em
-- função separada é o que permite aplicá-la aos dois conjuntos sem duplicar.
local ANCHOR_MARGIN = 2

function SpawnDecorations.anchorClearanceErrors(
	pieces: {
		{
			name: string,
			size: { x: number, y: number, z: number },
			position: { x: number, y: number, z: number },
		}
	},
	anchors: { { x: number, y: number, z: number } }
): { string }
	local errors: { string } = {}
	for _, piece in pieces do
		for _, a in anchors do
			local distX = math.max(math.abs(piece.position.x - a.x) - piece.size.x / 2, 0)
			local distZ = math.max(math.abs(piece.position.z - a.z) - piece.size.z / 2, 0)
			if distX <= ANCHOR_MARGIN and distZ <= ANCHOR_MARGIN then
				table.insert(errors, ("%s colado na âncora (%.0f, %.0f)"):format(piece.name, a.x, a.z))
			end
		end
	end
	return errors
end

-- Validação pura (testes): retorna lista de erros; vazia = ok.
-- 1. Nenhuma peça invade os volumes de transição (portões continuam livres).
-- 2. Peças sem colisão ficam dentro do volume do bastião.
-- 3. Muralha/pilares (canCollide) não engolem âncoras críticas.
-- 4. Nomes únicos.
function SpawnDecorations.validate(
	decorations: { Decoration },
	bastionBox: {
		min: { x: number, y: number, z: number },
		max: { x: number, y: number, z: number },
	},
	transitionBoxes: {
		{
			min: { x: number, y: number, z: number },
			max: { x: number, y: number, z: number },
		}
	},
	anchors: { { x: number, y: number, z: number } }
): { string }
	local errors: { string } = {}
	local seen: { [string]: boolean } = {}

	local function overlaps(a: Decoration, box: any): boolean
		local minX = a.position.x - a.size.x / 2
		local maxX = a.position.x + a.size.x / 2
		local minZ = a.position.z - a.size.z / 2
		local maxZ = a.position.z + a.size.z / 2
		return minX < box.max.x and maxX > box.min.x and minZ < box.max.z and maxZ > box.min.z
	end

	for _, d in decorations do
		if seen[d.name] then
			table.insert(errors, ("nome duplicado: %s"):format(d.name))
		end
		seen[d.name] = true

		-- 1. Portões livres (transição).
		for i, box in transitionBoxes do
			if overlaps(d, box) then
				table.insert(errors, ("%s invade o portão %d"):format(d.name, i))
			end
		end

		-- 2. Decoração solta dentro do bastião.
		if not d.canCollide then
			local minX = d.position.x - d.size.x / 2
			local maxX = d.position.x + d.size.x / 2
			local minZ = d.position.z - d.size.z / 2
			local maxZ = d.position.z + d.size.z / 2
			if
				minX < bastionBox.min.x
				or maxX > bastionBox.max.x
				or minZ < bastionBox.min.z
				or maxZ > bastionBox.max.z
			then
				table.insert(errors, ("%s fora do bastião"):format(d.name))
			end
		end

		-- 3. Muralha não engole âncora (mesma regra dos pilares-marco).
		if d.canCollide then
			for _, err in SpawnDecorations.anchorClearanceErrors({ d }, anchors) do
				table.insert(errors, err)
			end
		end
	end
	return errors
end

return SpawnDecorations

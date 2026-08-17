--!strict
-- WildDecorations (shared) — decoração procedural do lado de FORA do Bastião.
--
-- `SpawnDecorations` cobre a sala segura; este módulo é o passo seguinte de
-- `docs/22-SCENERY-EXPANSION.md` ("caminho norte e portão, corredor oeste e, por
-- fim, a planície ao redor da cratera"). Mesmo contrato: dados puros aqui, o
-- `WorldService` só materializa Parts, e nenhuma regra de jogo vive neste
-- arquivo — nada muda zona, âncora, hitbox, alcance, spawn ou navegação.
--
-- Layout de referência (docs/13 §8.1 e `Zones.luau`):
--   planície livre  — x −80..80, z −160..−40 (+ braço oeste x −80..−48, z −40..8)
--   transições      — norte x −6..6 / z −40..−32; oeste x −48..−40 / z −5..5
--   rota da cratera — faixa de 8 studs em x −4..4, z −100..−40
--   cratera         — centro (0, −102), raio 20; o miolo é ringue do elite
--   6 âncoras de Estilhaço — spawn dos inimigos comuns
--
-- ⚠️ Três regras que a validação trava, porque quebrá-las quebra o jogo:
--   1. NADA colide. Poste no meio da planície viraria parede invisível em cima
--      de perseguição, dash e Ombro Cometa.
--   2. NADA entra no miolo da cratera nem na faixa de caminhada. O elite precisa
--      do ringue inteiro e o jogador precisa da rota legível.
--   3. NADA encosta numa âncora de Estilhaço: o inimigo nasce ali.
-- E uma de honestidade visual (docs/17): nenhuma peça desenha anel/área no chão
-- que possa ser lida como alcance de golpe. Luz é ambiente, nunca telegraph.

export type WildLight = {
	brightness: number,
	rangeStuds: number,
	rgb: { number },
	shadows: boolean,
}

export type WildDecoration = {
	name: string,
	class: "Part" | "WedgePart",
	-- Sem `Cylinder`: o eixo do Cylinder é X e o tamanho deixaria de estar em
	-- eixos do mundo, quebrando o cálculo de pegada da validação. Poste é bloco
	-- de pedra, como as lanternas do spawn.
	shape: "Block" | "Ball",
	-- Tamanho em EIXOS DO MUNDO. Só `yawDegrees` gira a peça, no plano.
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	yawDegrees: number,
	rgb: { number },
	material: string,
	transparency: number,
	light: WildLight?,
}

local WildDecorations = {}

-- Paleta: mesma família fria do cenário (`SceneryPresentation`), declarada aqui
-- para o módulo continuar sem dependência — é catálogo de dados, não runtime.
local STONE: { number } = { 78, 74, 70 }
local STONE_DARK: { number } = { 54, 52, 50 }
local BASALT: { number } = { 46, 44, 48 }
local EMBER: { number } = { 244, 168, 96 }
local EMBER_DEEP: { number } = { 208, 104, 52 }
local RIFT: { number } = { 104, 220, 238 }
local UMBRAL: { number } = { 138, 96, 196 }

-- Fogo de posto: âmbar quente contra a pedra fria. Alcance modesto de propósito
-- (a luz orienta a rota, não ilumina o combate inteiro).
local function torchLight(rangeStuds: number, shadows: boolean): WildLight
	return { brightness = 1.15, rangeStuds = rangeStuds, rgb = EMBER, shadows = shadows }
end

local function deco(
	name: string,
	class: "Part" | "WedgePart",
	shape: "Block" | "Ball",
	size: { x: number, y: number, z: number },
	position: { x: number, y: number, z: number },
	yawDegrees: number,
	rgb: { number },
	material: string,
	transparency: number,
	light: WildLight?
): WildDecoration
	return {
		name = name,
		class = class,
		shape = shape,
		size = size,
		position = position,
		yawDegrees = yawDegrees,
		rgb = rgb,
		material = material,
		transparency = transparency,
		light = light,
	}
end

local DECORATIONS: { WildDecoration } = {}

local function push(decoration: WildDecoration): ()
	table.insert(DECORATIONS, decoration)
end

-- Poste de fogo em três peças: haste de pedra, bacia e chama. Modelo único para
-- a rota norte, o corredor oeste e a borda da cratera — repetição é o que faz o
-- jogador reconhecer "isto é caminho" sem minimapa.
local function brazier(prefix: string, x: number, z: number, height: number, light: WildLight?): ()
	push(
		deco(
			prefix .. "_Post",
			"Part",
			"Block",
			{ x = 0.7, y = height, z = 0.7 },
			{ x = x, y = height / 2, z = z },
			0,
			STONE_DARK,
			"Slate",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_Bowl",
			"Part",
			"Ball",
			{ x = 1.5, y = 0.95, z = 1.5 },
			{ x = x, y = height + 0.2, z = z },
			0,
			BASALT,
			"Basalt",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_Flame",
			"Part",
			"Ball",
			{ x = 1.05, y = 1.35, z = 1.05 },
			{ x = x, y = height + 0.9, z = z },
			0,
			EMBER_DEEP,
			"Neon",
			0.15,
			light
		)
	)
end

-- ── 1. Rota norte: Portão Norte → cratera ───────────────────────────────────
-- Pares de postes ladeando a faixa de caminhada (x ±6,5, fora dos 8 studs da
-- rota). É a leitura de "siga em frente" que o portão promete.
-- A fila para antes do aro da cratera (z ≈ −82): dali em diante quem marca o
-- caminho é o anel de postes da própria cratera.
do
	local lanes = { -46, -56, -66, -76 }
	for index, z in lanes do
		-- Só metade dos pares acende: fonte a cada 10 studs achata o contraste
		-- e custa caro no orçamento de luz do Android.
		local lit = if index % 2 == 1 then torchLight(20, false) else nil
		brazier(("NorthRoute_%02dW"):format(index), -6.5, z, 4.2, lit)
		brazier(("NorthRoute_%02dE"):format(index), 6.5, z, 4.2, nil)
	end
end

-- ── 2. Corredor oeste ───────────────────────────────────────────────────────
-- O muro em L quebra a linha de visão de propósito (§8.1); sem marcação, quem
-- sai pelo Portão Oeste não sabe que o caminho vira ao norte. Os postes
-- desenham a curva e a laje inclinada aponta para a planície.
do
	brazier("WestCorridor_01", -54, 2, 4.2, torchLight(20, false))
	brazier("WestCorridor_02", -54, -16, 4.2, nil)
	brazier("WestCorridor_03", -62, -28, 4.2, torchLight(20, false))
	brazier("WestCorridor_04", -70, -36, 4.2, nil)
	push(
		deco(
			"WestCorridor_Marker",
			"WedgePart",
			"Block",
			{ x = 2.4, y = 5.2, z = 2.4 },
			{ x = -66, y = 2.6, z = -20 },
			34,
			STONE,
			"Slate",
			0,
			nil
		)
	)
	push(
		deco(
			"WestCorridor_MarkerCore",
			"Part",
			"Ball",
			{ x = 0.9, y = 0.9, z = 0.9 },
			{ x = -66, y = 5.6, z = -20 },
			0,
			UMBRAL,
			"Neon",
			0.1,
			nil
		)
	)
end

-- ── 3. Borda da cratera ─────────────────────────────────────────────────────
-- Seis postes fora do aro (raio 23,5) e nenhum dentro: o ringue do elite fica
-- inteiro. Postes altos porque a cratera precisa ser vista da metade da rota.
do
	for index = 1, 6 do
		-- Sem deslocamento angular: assim nenhum poste cai em x ≈ 0, que é a
		-- faixa de caminhada, e o par de 60°/120° emoldura a entrada da rota.
		local angle = (index - 1) / 6 * math.pi * 2
		local x = math.cos(angle) * 23.5
		local z = -102 + math.sin(angle) * 23.5
		local lit = if index % 2 == 1 then torchLight(22, false) else nil
		brazier(("CraterRing_%02d"):format(index), x, z, 5.4, lit)
	end
end

-- ── 4. Formações de Estilhaço ───────────────────────────────────────────────
-- Três lascas de pedra em volta de cada âncora de spawn, com o centro LIVRE
-- (o inimigo nasce ali). Ensina onde caçar sem escrever nada na tela e sem
-- desenhar anel no chão, que seria lido como área de perigo.
-- As posições abaixo repetem as âncoras de `Zones.luau` de propósito: este é um
-- catálogo de dados, sem dependência de runtime. O teste da planície valida a
-- decoração contra as âncoras REAIS do `Zones`, então mover uma âncora lá
-- quebra o gate aqui em vez de deixar a formação órfã no meio do campo.
do
	local anchors = {
		{ name = "Shard1", x = -50, z = -60 },
		{ name = "Shard2", x = 30, z = -60 },
		{ name = "Shard3", x = -30, z = -95 },
		{ name = "Shard4", x = 55, z = -100 },
		{ name = "Shard5", x = -60, z = -130 },
		{ name = "Shard6", x = 25, z = -140 },
	}
	for anchorIndex, anchor in anchors do
		for shardIndex = 1, 3 do
			local angle = (shardIndex - 1) / 3 * math.pi * 2 + anchorIndex * 0.4
			local x = anchor.x + math.cos(angle) * 4.6
			local z = anchor.z + math.sin(angle) * 4.6
			local height = 1.9 + (shardIndex % 2) * 0.7
			push(
				deco(
					("Formation_%s_%d"):format(anchor.name, shardIndex),
					"WedgePart",
					"Block",
					{ x = 1.1, y = height, z = 1.1 },
					{ x = x, y = height / 2, z = z },
					(anchorIndex * 37 + shardIndex * 61) % 180,
					STONE,
					"Slate",
					0,
					nil
				)
			)
		end
		push(
			deco(
				("Formation_%s_Core"):format(anchor.name),
				"Part",
				"Ball",
				{ x = 0.62, y = 0.62, z = 0.62 },
				{ x = anchor.x + 4.6, y = 2.6, z = anchor.z },
				0,
				RIFT,
				"Neon",
				0.2,
				nil
			)
		)
	end
end

-- ============================================================================
-- Vegetação da planície (17/08, ampliada junto com a zona).
--
-- Até 17/08 a planície era 100% mineral — poste, cristal, pilar, formação de
-- estilhaço — e lia como pedreira. A primeira passada plantou 14 árvores em
-- posições escolhidas à mão; com a zona indo de 160×120 para 480×400, escolher
-- coordenada a coordenada deixou de escalar.
--
-- ⚠️ SORTEIO COM SEMENTE FIXA, NÃO `math.random`.
-- O gerador abaixo é um LCG determinístico: a mesma semente produz sempre o
-- mesmo bosque. Isso importa porque a validação é um TESTE — com sorteio real,
-- uma árvore invadindo a rota reprovaria só às vezes, e "às vezes" é o pior
-- estado possível para um gate. Determinístico, o bosque é dado como qualquer
-- outro: revisável no diff e idêntico entre máquinas.
--
-- A paleta NÃO é verde de floresta. O mundo é crepuscular e frio
-- (`SceneryPresentation`); a folhagem puxa para verde-azulado escuro e o tronco
-- para basalto, senão a vegetação parece colada de outro jogo.
local BARK: { number } = { 48, 42, 44 }
local BARK_PALE: { number } = { 66, 60, 58 }
local BARK_DEAD: { number } = { 82, 76, 70 }
local FOLIAGE: { number } = { 44, 92, 84 }
local FOLIAGE_DEEP: { number } = { 30, 66, 64 }
local FOLIAGE_RIFT: { number } = { 58, 118, 116 }
local FOLIAGE_DUSK: { number } = { 52, 80, 104 }
local MOSS: { number } = { 38, 74, 62 }

-- LCG de 32 bits. Números pequenos e sem biblioteca: o módulo é dado puro e
-- precisa carregar no harness Lune sem DataModel.
local seed = 20260817
local function rnd(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function between(lo: number, hi: number): number
	return lo + rnd() * (hi - lo)
end

-- Copa em camadas: massas deslocadas e de cor levemente diferente. Uma bola só
-- vira pirulito; três camadas dão silhueta irregular, que é o que faz a árvore
-- ler como árvore a 100 studs.
local function canopy(prefix: string, x: number, y: number, z: number, spread: number, yaw: number, tint: { number })
	push(
		deco(
			prefix .. "_CanopyA",
			"Part",
			"Ball",
			{ x = spread, y = spread * 0.74, z = spread * 0.94 },
			{ x = x - spread * 0.12, y = y + spread * 0.28, z = z + spread * 0.1 },
			yaw,
			tint,
			"LeafyGrass",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_CanopyB",
			"Part",
			"Ball",
			{ x = spread * 0.8, y = spread * 0.62, z = spread * 0.76 },
			{ x = x + spread * 0.24, y = y + spread * 0.62, z = z - spread * 0.16 },
			yaw + 34,
			FOLIAGE_DEEP,
			"LeafyGrass",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_CanopyC",
			"Part",
			"Ball",
			{ x = spread * 0.62, y = spread * 0.5, z = spread * 0.66 },
			{ x = x - spread * 0.2, y = y + spread * 0.74, z = z - spread * 0.24 },
			yaw + 68,
			tint,
			"LeafyGrass",
			0,
			nil
		)
	)
end

-- Árvore frondosa: tronco, alargamento de base, forquilha inclinada e copa em
-- três camadas. O alargamento é barato e resolve o defeito clássico de tronco
-- primitivo, que é parecer um poste enfiado no chão.
local function tree(prefix: string, x: number, z: number, height: number, spread: number, yaw: number, tint: { number })
	local trunkTop = height * 0.62
	push(
		deco(
			prefix .. "_Root",
			"Part",
			"Ball",
			{ x = 2.1, y = 1.1, z = 2.1 },
			{ x = x, y = 0.6, z = z },
			yaw,
			MOSS,
			"Grass",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_Trunk",
			"Part",
			"Block",
			{ x = 0.9, y = trunkTop, z = 0.9 },
			{ x = x, y = trunkTop / 2, z = z },
			yaw,
			BARK,
			"Slate",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_Fork",
			"Part",
			"Block",
			{ x = 0.55, y = height * 0.3, z = 0.55 },
			{ x = x + spread * 0.16, y = trunkTop + height * 0.11, z = z - spread * 0.1 },
			yaw + 20,
			BARK_PALE,
			"Slate",
			0,
			nil
		)
	)
	canopy(prefix, x, trunkTop, z, spread, yaw, tint)
end

-- Conífera: silhueta cônica feita de três blocos girados. Existe para o bosque
-- não ser feito de um molde só — variedade de SILHUETA lê de longe, variedade
-- de cor não.
local function conifer(prefix: string, x: number, z: number, height: number, spread: number, yaw: number)
	push(
		deco(
			prefix .. "_Trunk",
			"Part",
			"Block",
			{ x = 0.7, y = height * 0.5, z = 0.7 },
			{ x = x, y = height * 0.25, z = z },
			yaw,
			BARK,
			"Slate",
			0,
			nil
		)
	)
	local tiers = { 0.42, 0.66, 0.86 }
	local widths = { 1.0, 0.72, 0.44 }
	for index, tier in tiers do
		push(
			deco(
				("%s_Tier%d"):format(prefix, index),
				"Part",
				"Block",
				{ x = spread * widths[index], y = height * 0.26, z = spread * widths[index] },
				{ x = x, y = height * tier, z = z },
				yaw + index * 22,
				if index == 2 then FOLIAGE_DEEP else FOLIAGE,
				"LeafyGrass",
				0,
				nil
			)
		)
	end
end

-- Tronco morto: só haste e toco. Um bosque sem árvore morta parece cenário de
-- catálogo; com ela, parece lugar com história.
local function deadTree(prefix: string, x: number, z: number, height: number, yaw: number)
	push(
		deco(
			prefix .. "_Snag",
			"Part",
			"Block",
			{ x = 0.8, y = height, z = 0.8 },
			{ x = x, y = height / 2, z = z },
			yaw,
			BARK_DEAD,
			"Slate",
			0,
			nil
		)
	)
	push(
		deco(
			prefix .. "_Limb",
			"Part",
			"Block",
			{ x = 0.45, y = height * 0.34, z = 0.45 },
			{ x = x + 1.1, y = height * 0.72, z = z - 0.5 },
			yaw + 52,
			BARK_DEAD,
			"Slate",
			0,
			nil
		)
	)
end

local function shrub(prefix: string, x: number, z: number, radius: number, rgb: { number })
	push(deco(
		prefix,
		"Part",
		"Ball",
		{ x = radius * 2, y = radius * 1.3, z = radius * 1.8 },
		-- y é o CENTRO da peça: precisa ser ao menos a meia-altura (0.65×raio) ou
		-- a peça nasce enterrada. A validação chama isso de "afunda no chão".
		{ x = x, y = radius * 0.68, z = z },
		0,
		rgb,
		"LeafyGrass",
		0,
		nil
	))
end

-- Pedra musgosa: quebra o campo e amarra a vegetação ao chão mineral do mundo.
local function boulder(prefix: string, x: number, z: number, radius: number, yaw: number)
	push(
		deco(
			prefix,
			"Part",
			"Ball",
			{ x = radius * 2.2, y = radius * 1.5, z = radius * 1.9 },
			{ x = x, y = radius * 0.78, z = z },
			yaw,
			STONE_DARK,
			"Basalt",
			0,
			nil
		)
	)
end

-- ── Distribuição ────────────────────────────────────────────────────────────
-- Zonas de exclusão, todas travadas pela validação (repetir aqui é o que evita
-- gerar peça só para vê-la reprovada):
--   rota da cratera  — |x| <= 9, z −104..−36
--   cratera          — raio 26 em (0, −102)
--   âncoras          — 8 studs de folga
--   bastião/portões  — z > −46 no corredor central
local ANCHOR_SPOTS = {
	{ -50, -60 },
	{ 30, -60 },
	{ -30, -95 },
	{ 55, -100 },
	{ -60, -130 },
	{ 25, -140 },
	{ 0, -102 },
}

local function blocked(x: number, z: number): boolean
	if math.abs(x) <= 9 and z <= -36 and z >= -104 then
		return true
	end
	local cx, cz = x - 0, z + 102
	if math.sqrt(cx * cx + cz * cz) <= 26 then
		return true
	end
	for _, spot in ANCHOR_SPOTS do
		local dx, dz = x - spot[1], z - spot[2]
		if math.sqrt(dx * dx + dz * dz) <= 8 then
			return true
		end
	end
	-- Boca dos portões: nada planta na saída do Bastião.
	if z > -46 and math.abs(x) < 14 then
		return true
	end
	if z > -46 and x > -54 and x < -38 then
		return true
	end
	return false
end

local TINTS = { FOLIAGE, FOLIAGE_RIFT, FOLIAGE_DUSK, FOLIAGE_DEEP }

do
	local planted = 0
	local attempts = 0
	-- Teto de tentativas: sem ele, uma regra de exclusão mais rígida no futuro
	-- transformaria isto em laço infinito no carregamento do módulo.
	while planted < 210 and attempts < 4000 do
		attempts += 1
		local x = between(-228, 228)
		local z = between(-428, -50)
		if not blocked(x, z) then
			planted += 1
			local roll = rnd()
			local tint = TINTS[(planted % #TINTS) + 1]
			local prefix = ("Wild_%03d"):format(planted)
			if roll < 0.42 then
				tree(prefix, x, z, between(9, 15), between(5.4, 8.2), between(0, 360), tint)
			elseif roll < 0.66 then
				conifer(prefix, x, z, between(11, 18), between(4.6, 7.0), between(0, 360))
			elseif roll < 0.74 then
				deadTree(prefix, x, z, between(7, 12), between(0, 360))
			elseif roll < 0.90 then
				shrub(prefix, x, z, between(1.6, 2.6), tint)
			else
				boulder(prefix, x, z, between(1.8, 3.4), between(0, 360))
			end
		end
	end
end

-- ============================================================================

function WildDecorations.all(): { WildDecoration }
	return DECORATIONS
end

function WildDecorations.lightCount(): number
	local count = 0
	for _, decoration in DECORATIONS do
		if decoration.light then
			count += 1
		end
	end
	return count
end

-- Teto de fontes de luz na planície. Oito é o que cabe no orçamento de Android
-- do `docs/15` sem transformar a rota em festival; passar disso é decisão de
-- performance e precisa de medição, não de mais um poste.
local MAX_LIGHTS = 8
-- Distância mínima entre uma peça e uma âncora de Estilhaço (borda a borda).
local ANCHOR_CLEARANCE_STUDS = 3
-- Faixa de caminhada da rota da cratera (`PathToCrater`, 8 studs de largura).
local ROUTE_HALF_WIDTH = 5
local ROUTE_MIN_Z = -100
local ROUTE_MAX_Z = -40

local function footprint(decoration: WildDecoration)
	-- Limite conservador: a maior dimensão horizontal cobre qualquer yaw sem
	-- recalcular a caixa girada.
	local half = math.max(decoration.size.x, decoration.size.z) / 2
	if decoration.yawDegrees % 90 ~= 0 then
		half = math.sqrt(2) * half
	end
	return {
		minX = decoration.position.x - half,
		maxX = decoration.position.x + half,
		minZ = decoration.position.z - half,
		maxZ = decoration.position.z + half,
		half = half,
	}
end

-- Validação pura. Devolve lista de erros; vazia = ok.
function WildDecorations.validate(
	decorations: { WildDecoration },
	freeVolumes: {
		{
			min: { x: number, y: number, z: number },
			max: { x: number, y: number, z: number },
		}
	},
	transitionVolumes: {
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

	for _, decoration in decorations do
		local name = decoration.name
		if seen[name] then
			table.insert(errors, ("nome duplicado: %s"):format(name))
		end
		seen[name] = true

		if decoration.class ~= "Part" and decoration.class ~= "WedgePart" then
			table.insert(errors, ("%s: classe inválida"):format(name))
		end
		if decoration.shape ~= "Block" and decoration.shape ~= "Ball" then
			table.insert(errors, ("%s: shape inválido"):format(name))
		end
		if decoration.class == "WedgePart" and decoration.shape ~= "Block" then
			table.insert(errors, ("%s: WedgePart não aceita shape %s"):format(name, decoration.shape))
		end
		if decoration.transparency < 0 or decoration.transparency >= 1 then
			table.insert(errors, ("%s: transparência fora de 0..1"):format(name))
		end
		if decoration.size.x < 0.05 or decoration.size.y < 0.05 or decoration.size.z < 0.05 then
			table.insert(errors, ("%s: peça menor que o mínimo de Part"):format(name))
		end
		if decoration.position.y - decoration.size.y / 2 < -0.01 then
			table.insert(errors, ("%s: afunda no chão"):format(name))
		end

		local box = footprint(decoration)

		-- 1. Dentro de algum volume livre.
		local inside = false
		for _, volume in freeVolumes do
			if
				box.minX >= volume.min.x
				and box.maxX <= volume.max.x
				and box.minZ >= volume.min.z
				and box.maxZ <= volume.max.z
			then
				inside = true
				break
			end
		end
		if not inside then
			table.insert(errors, ("%s fora da zona livre"):format(name))
		end

		-- 2. Portões continuam limpos.
		for index, volume in transitionVolumes do
			if
				box.minX < volume.max.x
				and box.maxX > volume.min.x
				and box.minZ < volume.max.z
				and box.maxZ > volume.min.z
			then
				table.insert(errors, ("%s invade o portão %d"):format(name, index))
			end
		end

		-- 3. Miolo da cratera intocado (ringue do elite).
		local dx = decoration.position.x - crater.x
		local dz = decoration.position.z - crater.z
		if math.sqrt(dx * dx + dz * dz) - box.half < crater.radius then
			table.insert(errors, ("%s invade o ringue da cratera"):format(name))
		end

		-- 4. Faixa de caminhada da rota livre.
		if
			box.maxX > -ROUTE_HALF_WIDTH
			and box.minX < ROUTE_HALF_WIDTH
			and box.maxZ > ROUTE_MIN_Z
			and box.minZ < ROUTE_MAX_Z
		then
			table.insert(errors, ("%s invade a rota da cratera"):format(name))
		end

		-- 5. Âncora de Estilhaço livre.
		for _, anchor in shardAnchors do
			local anchorX = decoration.position.x - anchor.x
			local anchorZ = decoration.position.z - anchor.z
			local distance = math.sqrt(anchorX * anchorX + anchorZ * anchorZ) - box.half
			if distance < ANCHOR_CLEARANCE_STUDS then
				table.insert(errors, ("%s colado na âncora (%.0f, %.0f)"):format(name, anchor.x, anchor.z))
			end
		end

		-- 6. Orçamento de luz.
		if decoration.light then
			lights += 1
			local light = decoration.light
			if light.brightness <= 0 or light.brightness > 3 then
				table.insert(errors, ("%s: brilho fora do orçamento"):format(name))
			end
			if light.rangeStuds < 8 or light.rangeStuds > 24 then
				table.insert(errors, ("%s: alcance de luz fora do orçamento"):format(name))
			end
			if #light.rgb ~= 3 then
				table.insert(errors, ("%s: cor de luz inválida"):format(name))
			end
		end
	end

	if lights > MAX_LIGHTS then
		table.insert(errors, ("luzes demais na planície: %d (teto %d)"):format(lights, MAX_LIGHTS))
	end
	return errors
end

return WildDecorations

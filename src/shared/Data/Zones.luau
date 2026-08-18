--!strict
-- Zonas e âncoras da fatia F0 (docs/13-F0-SLICE.md §4, §8; docs/02-WORLD.md §4)
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.
--
-- Alto risco NÃO existe nesta fatia (docs/13-F0-SLICE.md §8.2).
-- O greybox abaixo é F0-BASELINE como dados de layout (§8.1), não arte:
-- a geometria física no Studio ainda é pendente (parts, volumes e collision
-- groups `Safe` / `Transition` / `Free` / `GateBlock` são construídos lá).

export type Vec3 = { x: number, y: number, z: number }

export type Box = { min: Vec3, max: Vec3 }

export type ZoneDefinition = {
	id: string,
	displayNameKey: string,
	kind: "safe" | "transition" | "free",
	pvp: boolean,
	-- Volumes físicos da zona (caixas alinhadas aos eixos, em studs).
	-- O WorldService constrói as parts a partir daqui; `zoneAtPosition`
	-- resolve a zona de um ponto com os mesmos números. Uma fonte só.
	volumes: { Box },
	-- Apresentação do piso. Ausente = fallback do kind (pedra/areia).
	floorRgb: { number }?,
	floorMaterial: string?,
}

export type AnchorDefinition = {
	id: string,
	zoneId: string,
	-- Posição de layout em studs (x, y, z); IDs persistidos nunca CFrame cru.
	position: { x: number, y: number, z: number },
}

export type GreyboxLayout = {
	bastionSize: { x: number, z: number },
	bastionWallHeight: number,
	trainingSize: number,
	spawnRadius: number,
	gateNorthWidth: number,
	gateWestWidth: number,
	transitionDepth: number,
	plainSize: { x: number, z: number },
	eliteCraterRadius: number,
	eliteCraterOffsetNorth: number,
	collisionGroups: { string },
}

-- Altura dos volumes: chão em y = 0, muros de 16 e arco de 10 (§8.1). A faixa
-- generosa evita que pulo ou desnível da cratera tirem o jogador da zona.
local Y_MIN = -10
local Y_MAX = 40

local function box(minX: number, minZ: number, maxX: number, maxZ: number): Box
	return {
		min = { x = minX, y = Y_MIN, z = minZ },
		max = { x = maxX, y = Y_MAX, z = maxZ },
	}
end

local Zones: { [string]: ZoneDefinition } = {
	-- 80 × 64 centrado na origem (§8.1). O treino 24×24 no canto NE fica
	-- dentro deste volume: é a mesma zona segura, sem PvP.
	zone_bastion_safe = {
		id = "zone_bastion_safe",
		displayNameKey = "zone.bastion.name",
		kind = "safe",
		pvp = false,
		floorRgb = { 48, 54, 68 },
		floorMaterial = "Slate",
		volumes = {
			box(-40, -32, 40, 32),
			-- Plinto leste/sul: a caixa deixa de ter void colado no muro.
			box(40, -32, 56, 32),
			box(-56, 32, 56, 48),
		},
	},
	-- Um volume de 8 de profundidade em cada portão (§8.1).
	-- 17/08: faixa Lumen (norte da planície) para o aviso de risco antes da
	-- primeira cidade, sem pular segura↔livre.
	zone_threshold_transition = {
		id = "zone_threshold_transition",
		displayNameKey = "", -- spec: sem nome público; só aviso de fronteira
		kind = "transition",
		pvp = false,
		volumes = {
			box(-6, -40, 6, -32), -- Portão Norte, 12 de largura
			box(-48, -5, -40, 5), -- Portão Oeste, 10 de largura
			box(-24, -460, 24, -440), -- Acesso ao Distrito Lumen
		},
	},
	-- Planície + o braço oeste que liga o Portão Oeste a ela. §8.1 dimensiona a
	-- planície mas não diz onde o Portão Oeste desemboca; sem o braço ele seria
	-- um portão para lugar nenhum.
	--
	-- **Ampliada em 17/08 de 160×120 para 480×400.** O tamanho anterior vinha do
	-- F0-BASELINE e servia para provar a fatia; visto em Play, o mundo acabava
	-- logo depois da cratera e lia como arena, não como mundo aberto — que é a
	-- direção do VISION-DEC-013.
	--
	-- Custo de contagem de partes: ZERO. `buildFloors` cria UMA Part por volume,
	-- então o piso só fica maior. O que a ampliação cobra é DECORAÇÃO: campo
	-- vazio grande é pior que campo pequeno cheio, e é por isso que a vegetação
	-- cresceu junto neste mesmo commit.
	--
	-- O que NÃO mudou de propósito: âncoras, cratera, rota e bastião. Mover
	-- spawn de inimigo ou o ringue do elite junto com a expansão misturaria duas
	-- mudanças e tornaria qualquer regressão difícil de atribuir.
	zone_plain_free = {
		id = "zone_plain_free",
		displayNameKey = "zone.plain.name",
		kind = "free",
		pvp = true,
		floorRgb = { 92, 82, 70 },
		floorMaterial = "Ground",
		volumes = {
			box(-240, -440, 240, -40),
			box(-240, -40, -48, 8),
			-- Aventais dos portões: o vão é estreito (12 / 10 studs) e o muro
			-- do Bastião continua. Sem piso colado na face de fora, sair pelo
			-- portão e desviar 1 passo caía no void. São a MESMA zona livre —
			-- o aviso já aconteceu no vão.
			box(-40, -40, -6, -32), -- norte, lado oeste do vão
			box(6, -40, 40, -32), -- norte, lado leste do vão
			box(-48, -32, -40, -5), -- oeste, lado norte do vão
			box(-48, 5, -40, 32), -- oeste, lado sul do vão
			-- Canto nordeste por fora: liga o avental norte ao colar leste.
			box(40, -40, 56, -32),
		},
	},
	-- Distrito Lumen — primeira célula urbana (docs/02 §3.4, docs/24).
	-- Segura: rua, praça e marco neon. PvP só na borda da planície.
	zone_lumen_safe = {
		id = "zone_lumen_safe",
		displayNameKey = "zone.lumen.name",
		kind = "safe",
		pvp = false,
		floorRgb = { 28, 24, 42 },
		floorMaterial = "Asphalt",
		volumes = { box(-160, -700, 160, -460) },
	},
	-- Bosque dos Ecos — leste da planície (docs/02 §3.2). Livre.
	zone_echo_woods = {
		id = "zone_echo_woods",
		displayNameKey = "zone.woods.name",
		kind = "free",
		pvp = true,
		floorRgb = { 42, 72, 46 },
		floorMaterial = "LeafyGrass",
		volumes = { box(240, -440, 520, -80) },
	},
	-- Porto Ferro — oeste do braço (docs/02 §3.4). Livre, docas.
	zone_iron_port = {
		id = "zone_iron_port",
		displayNameKey = "zone.port.name",
		kind = "free",
		pvp = true,
		floorRgb = { 92, 78, 68 },
		floorMaterial = "Concrete",
		volumes = { box(-540, -220, -240, 80) },
	},
	-- Setor Cinza — nordeste, indústria (docs/02 §3.4). Livre.
	zone_grey_sector = {
		id = "zone_grey_sector",
		displayNameKey = "zone.grey.name",
		kind = "free",
		pvp = true,
		floorRgb = { 62, 64, 70 },
		floorMaterial = "Basalt",
		volumes = { box(160, -700, 480, -440) },
	},
	-- Academia Alvorada — sudeste do Bastião, campus seguro.
	zone_academy_safe = {
		id = "zone_academy_safe",
		displayNameKey = "zone.academy.name",
		kind = "safe",
		pvp = false,
		floorRgb = { 186, 176, 148 },
		floorMaterial = "Sandstone",
		volumes = { box(-80, 48, 180, 240) },
	},
}

local Anchors: { [string]: AnchorDefinition } = {
	anchor_bastion_spawn = {
		id = "anchor_bastion_spawn",
		zoneId = "zone_bastion_safe",
		position = { x = 0, y = 0, z = 20 },
	},
	anchor_bastion_return = {
		id = "anchor_bastion_return",
		zoneId = "zone_bastion_safe",
		position = { x = 0, y = 0, z = 12 },
	},
	anchor_training = {
		id = "anchor_training",
		zoneId = "zone_bastion_safe",
		position = { x = 28, y = 0, z = -20 },
	},
	-- 17/08: z −14 → −11. O pilar-marco (20, −16) tem 4 studs de lado e ocupa
	-- z −18..−14: a Instrutora nascia com capa e rabo de cabelo DENTRO da
	-- pedra. Puxando 3 studs para a praça ela sai do pilar e ainda fica sob a
	-- luz-chave dela, que já estava em z −12,5 (SceneryPresentation).
	anchor_instructor = {
		id = "anchor_instructor",
		zoneId = "zone_bastion_safe",
		position = { x = 20, y = 0, z = -11 },
	},
	anchor_gate_north = {
		id = "anchor_gate_north",
		zoneId = "zone_threshold_transition",
		position = { x = 0, y = 0, z = -32 },
	},
	anchor_gate_west = {
		id = "anchor_gate_west",
		zoneId = "zone_threshold_transition",
		position = { x = -40, y = 0, z = 0 },
	},
	anchor_elite = {
		id = "anchor_elite",
		zoneId = "zone_plain_free",
		position = { x = 0, y = 0, z = -102 },
	},

	-- Os 6 pontos de Estilhaço (§8.1): no mínimo 24 studs entre si e nenhum a
	-- menos de 20 de um portão. `CatalogService` valida as duas regras.
	anchor_shard_1 = {
		id = "anchor_shard_1",
		zoneId = "zone_plain_free",
		position = { x = -50, y = 0, z = -60 },
	},
	anchor_shard_2 = {
		id = "anchor_shard_2",
		zoneId = "zone_plain_free",
		position = { x = 30, y = 0, z = -60 },
	},
	anchor_shard_3 = {
		id = "anchor_shard_3",
		zoneId = "zone_plain_free",
		position = { x = -30, y = 0, z = -95 },
	},
	anchor_shard_4 = {
		id = "anchor_shard_4",
		zoneId = "zone_plain_free",
		position = { x = 55, y = 0, z = -100 },
	},
	anchor_shard_5 = {
		id = "anchor_shard_5",
		zoneId = "zone_plain_free",
		position = { x = -60, y = 0, z = -130 },
	},
	anchor_shard_6 = {
		id = "anchor_shard_6",
		zoneId = "zone_plain_free",
		position = { x = 25, y = 0, z = -140 },
	},
	-- Marcos das células de expansão (docs/02 §3.4 / docs/24). Só apresentação
	-- e resolução de zona — nenhum serviço novo nasce deles nesta rodada.
	anchor_lumen_plaza = {
		id = "anchor_lumen_plaza",
		zoneId = "zone_lumen_safe",
		position = { x = 0, y = 0, z = -580 },
	},
	anchor_woods_shrine = {
		id = "anchor_woods_shrine",
		zoneId = "zone_echo_woods",
		position = { x = 380, y = 0, z = -260 },
	},
	anchor_port_pier = {
		id = "anchor_port_pier",
		zoneId = "zone_iron_port",
		position = { x = -390, y = 0, z = -70 },
	},
	anchor_grey_stack = {
		id = "anchor_grey_stack",
		zoneId = "zone_grey_sector",
		position = { x = 320, y = 0, z = -570 },
	},
	anchor_academy_yard = {
		id = "anchor_academy_yard",
		zoneId = "zone_academy_safe",
		position = { x = 50, y = 0, z = 140 },
	},
	-- Clareiras do Fogo-fátuo (Bosque). Longe do santuário (380, −260) e
	-- das árvores reservadas no LCG de BiomeDecorations.
	anchor_wisp_1 = {
		id = "anchor_wisp_1",
		zoneId = "zone_echo_woods",
		position = { x = 320, y = 0, z = -180 },
	},
	anchor_wisp_2 = {
		id = "anchor_wisp_2",
		zoneId = "zone_echo_woods",
		position = { x = 440, y = 0, z = -340 },
	},
	-- Sucateiros do Porto: leste do cais e oeste junto ao farol, fora dos
	-- armazéns e da grua.
	anchor_scrapper_1 = {
		id = "anchor_scrapper_1",
		zoneId = "zone_iron_port",
		position = { x = -270, y = 0, z = -40 },
	},
	anchor_scrapper_2 = {
		id = "anchor_scrapper_2",
		zoneId = "zone_iron_port",
		position = { x = -510, y = 0, z = -90 },
	},
}

-- Pontos de spawn de Estilhaço, na ordem de uso pelo EnemyService.
local SHARD_ANCHORS: { string } = {
	"anchor_shard_1",
	"anchor_shard_2",
	"anchor_shard_3",
	"anchor_shard_4",
	"anchor_shard_5",
	"anchor_shard_6",
}

-- Portões, para a regra "nenhum ponto de Estilhaço a menos de 20 studs".
local GATE_ANCHORS: { string } = { "anchor_gate_north", "anchor_gate_west" }

local WISP_ANCHORS: { string } = { "anchor_wisp_1", "anchor_wisp_2" }

local PORT_ANCHORS: { string } = { "anchor_scrapper_1", "anchor_scrapper_2" }

-- F0-BASELINE (docs/13-F0-SLICE.md §8.1) — medidas de layout do greybox.
-- Studs; eixo z negativo é norte.
local Greybox: GreyboxLayout = {
	bastionSize = { x = 80, z = 64 },
	bastionWallHeight = 16,
	trainingSize = 24,
	spawnRadius = 8,
	gateNorthWidth = 12,
	gateWestWidth = 10,
	transitionDepth = 8,
	plainSize = { x = 160, z = 120 },
	eliteCraterRadius = 20,
	eliteCraterOffsetNorth = 70,
	collisionGroups = { "Safe", "Transition", "Free", "GateBlock" },
}

local ZoneCatalog = {}

function ZoneCatalog.get(zoneId: string): ZoneDefinition?
	return Zones[zoneId]
end

function ZoneCatalog.all(): { ZoneDefinition }
	local out: { ZoneDefinition } = {}
	for _, def in Zones do
		table.insert(out, def)
	end
	return out
end

function ZoneCatalog.getAnchor(anchorId: string): AnchorDefinition?
	return Anchors[anchorId]
end

function ZoneCatalog.allAnchors(): { AnchorDefinition }
	local out: { AnchorDefinition } = {}
	for _, def in Anchors do
		table.insert(out, def)
	end
	return out
end

function ZoneCatalog.greybox(): GreyboxLayout
	return Greybox
end

function ZoneCatalog.shardAnchors(): { string }
	return table.clone(SHARD_ANCHORS)
end

function ZoneCatalog.gateAnchors(): { string }
	return table.clone(GATE_ANCHORS)
end

function ZoneCatalog.wispAnchors(): { string }
	return table.clone(WISP_ANCHORS)
end

function ZoneCatalog.portAnchors(): { string }
	return table.clone(PORT_ANCHORS)
end

local function contains(b: Box, p: Vec3): boolean
	return p.x >= b.min.x and p.x <= b.max.x and p.y >= b.min.y and p.y <= b.max.y and p.z >= b.min.z and p.z <= b.max.z
end

-- Zona de um ponto. Ordem de resolução: transição → livre → segura.
-- A transição vem primeiro porque seus volumes encostam nas bordas das outras
-- duas: no plano exato do portão o jogador já está na fronteira, e é isso que
-- `anchor_gate_north` / `anchor_gate_west` declaram. Fora de todo volume
-- devolve nil — quem chama decide (o bootstrap mantém a zona anterior).
function ZoneCatalog.zoneAtPosition(position: Vec3): string?
	-- Células menores e transições antes das caixas grandes. Sem isso o
	-- Distrito Lumen (norte da planície) seria engolido pela livre.
	local order = {
		"zone_threshold_transition",
		"zone_lumen_safe",
		"zone_academy_safe",
		"zone_echo_woods",
		"zone_iron_port",
		"zone_grey_sector",
		"zone_plain_free",
		"zone_bastion_safe",
	}
	for _, zoneId in order do
		local zone = Zones[zoneId]
		if zone then
			for _, b in zone.volumes do
				if contains(b, position) then
					return zoneId
				end
			end
		end
	end
	return nil
end

return ZoneCatalog

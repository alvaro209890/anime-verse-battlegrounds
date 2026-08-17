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
		volumes = { box(-40, -32, 40, 32) },
	},
	-- Um volume de 8 de profundidade em cada portão (§8.1).
	zone_threshold_transition = {
		id = "zone_threshold_transition",
		displayNameKey = "", -- spec: sem nome público; só aviso de fronteira
		kind = "transition",
		pvp = false,
		volumes = {
			box(-6, -40, 6, -32), -- Portão Norte, 12 de largura
			box(-48, -5, -40, 5), -- Portão Oeste, 10 de largura
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
		volumes = {
			box(-240, -440, 240, -40),
			box(-240, -40, -48, 8),
		},
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
	anchor_instructor = {
		id = "anchor_instructor",
		zoneId = "zone_bastion_safe",
		position = { x = 20, y = 0, z = -14 },
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

local function contains(b: Box, p: Vec3): boolean
	return p.x >= b.min.x and p.x <= b.max.x and p.y >= b.min.y and p.y <= b.max.y and p.z >= b.min.z and p.z <= b.max.z
end

-- Zona de um ponto. Ordem de resolução: transição → livre → segura.
-- A transição vem primeiro porque seus volumes encostam nas bordas das outras
-- duas: no plano exato do portão o jogador já está na fronteira, e é isso que
-- `anchor_gate_north` / `anchor_gate_west` declaram. Fora de todo volume
-- devolve nil — quem chama decide (o bootstrap mantém a zona anterior).
function ZoneCatalog.zoneAtPosition(position: Vec3): string?
	local order = { "zone_threshold_transition", "zone_plain_free", "zone_bastion_safe" }
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

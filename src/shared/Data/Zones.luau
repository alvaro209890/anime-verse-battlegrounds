--!strict
-- Zonas e âncoras da fatia F0 (docs/13-F0-SLICE.md §4, §8; docs/02-WORLD.md §4)
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.
--
-- Alto risco NÃO existe nesta fatia (docs/13-F0-SLICE.md §8.2).
-- O greybox abaixo é F0-BASELINE como dados de layout (§8.1), não arte:
-- a geometria física no Studio ainda é pendente (parts, volumes e collision
-- groups `Safe` / `Transition` / `Free` / `GateBlock` são construídos lá).

export type ZoneDefinition = {
	id: string,
	displayNameKey: string,
	kind: "safe" | "transition" | "free",
	pvp: boolean,
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

local Zones: { [string]: ZoneDefinition } = {
	zone_bastion_safe = {
		id = "zone_bastion_safe",
		displayNameKey = "zone.bastion.name",
		kind = "safe",
		pvp = false,
	},
	zone_threshold_transition = {
		id = "zone_threshold_transition",
		displayNameKey = "zone.threshold.name",
		kind = "transition",
		pvp = false,
	},
	zone_plain_free = {
		id = "zone_plain_free",
		displayNameKey = "zone.plain.name",
		kind = "free",
		pvp = true,
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
}

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

return ZoneCatalog

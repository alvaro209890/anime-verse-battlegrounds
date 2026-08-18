--!strict
-- Superfícies do mundo. ColorMaps vieram de upload_image no Studio (18/08);
-- overlays VFX usam IDs Completed de assets/published-vfx-assets.json.
-- Overlay é só leitura: não muda colisão, hitbox nem zona.

export type Rgb = { number }

export type SurfaceSkin = {
	id: string,
	material: string?,
	studsPerTile: number,
	baseAssetId: string?,
	baseTransparency: number,
	baseRgb: Rgb,
	overlayAssetId: string?,
	overlayTransparency: number,
	overlayRgb: Rgb,
	-- Faces do Texture. Ausente = só o topo (piso).
	faces: { string }?,
}

-- ColorMaps publicadas em 2026-08-18 via Studio MCP upload_image.
local SLATE_FLOOR = "rbxassetid://115496526822547"
local RUNED_WALL = "rbxassetid://101527668600692"
local CRYSTAL = "rbxassetid://91160842506298"

-- Atlas VFX Completed (docs/20). Scorch entra na cratera.
local ENERGY_BALL = "rbxassetid://88905938168827"
local POWER_RING = "rbxassetid://139053543856972"
local LIGHTNING = "rbxassetid://94416490862398"
local SCORCH = "rbxassetid://71986137964693"

local WHITE: Rgb = { 255, 255, 255 }

local function skin(values: {
	id: string,
	material: string?,
	studsPerTile: number,
	baseAssetId: string?,
	baseTransparency: number?,
	baseRgb: Rgb?,
	overlayAssetId: string?,
	overlayTransparency: number?,
	overlayRgb: Rgb?,
	faces: { string }?,
}): SurfaceSkin
	return {
		id = values.id,
		material = values.material,
		studsPerTile = values.studsPerTile,
		baseAssetId = values.baseAssetId,
		baseTransparency = values.baseTransparency or 0.12,
		baseRgb = values.baseRgb or WHITE,
		overlayAssetId = values.overlayAssetId,
		overlayTransparency = values.overlayTransparency or 1,
		overlayRgb = values.overlayRgb or WHITE,
		faces = values.faces,
	}
end

local NAMED: { [string]: SurfaceSkin } = {
	TrainingPad = skin({
		id = "TrainingPad",
		material = "Granite",
		studsPerTile = 16,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.08,
		overlayAssetId = POWER_RING,
		overlayTransparency = 0.35,
		overlayRgb = { 180, 210, 255 },
	}),
	SpawnPlaza = skin({
		id = "SpawnPlaza",
		material = "Slate",
		studsPerTile = 14,
		baseAssetId = SLATE_FLOOR,
		overlayAssetId = POWER_RING,
		overlayTransparency = 0.45,
		overlayRgb = { 200, 180, 255 },
	}),
	BastionSpawn = skin({
		id = "BastionSpawn",
		material = "Slate",
		studsPerTile = 10,
		baseAssetId = SLATE_FLOOR,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.55,
		overlayRgb = { 160, 200, 255 },
	}),
	ReturnBase = skin({
		id = "ReturnBase",
		material = "Slate",
		studsPerTile = 6,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.05,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.25,
		overlayRgb = { 214, 206, 232 },
	}),
	ReturnSpire = skin({
		id = "ReturnSpire",
		material = "Marble",
		studsPerTile = 4,
		baseAssetId = CRYSTAL,
		baseTransparency = 0.1,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.4,
		overlayRgb = { 188, 176, 224 },
		faces = { "Front", "Back", "Left", "Right" },
	}),
	PathNorthGate = skin({
		id = "PathNorthGate",
		material = "Cobblestone",
		studsPerTile = 8,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.35,
	}),
	PathWestGate = skin({
		id = "PathWestGate",
		material = "Cobblestone",
		studsPerTile = 8,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.35,
	}),
	PathTraining = skin({
		id = "PathTraining",
		material = "Cobblestone",
		studsPerTile = 8,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.35,
	}),
	PathToCrater = skin({
		id = "PathToCrater",
		material = "Cobblestone",
		studsPerTile = 10,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.4,
	}),
	PlainTerrain = skin({
		id = "PlainTerrain",
		material = "Ground",
		studsPerTile = 20,
	}),
	EliteCraterBasin = skin({
		id = "EliteCraterBasin",
		material = "Slate",
		studsPerTile = 10,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.2,
		baseRgb = { 90, 80, 100 },
		overlayAssetId = SCORCH,
		overlayTransparency = 0.28,
		overlayRgb = { 70, 48, 92 },
	}),
	EliteCraterRim = skin({
		id = "EliteCraterRim",
		material = "Rock",
		studsPerTile = 5,
		baseAssetId = RUNED_WALL,
		baseTransparency = 0.25,
		overlayAssetId = SCORCH,
		overlayTransparency = 0.55,
		overlayRgb = { 90, 72, 80 },
		faces = { "Top", "Front" },
	}),
	BastionWall = skin({
		id = "BastionWall",
		material = "Limestone",
		studsPerTile = 8,
		baseAssetId = RUNED_WALL,
		baseTransparency = 0.08,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.78,
		overlayRgb = { 150, 130, 190 },
		faces = { "Front", "Back" },
	}),
	GateStone = skin({
		id = "GateStone",
		material = "Basalt",
		studsPerTile = 5,
		baseAssetId = RUNED_WALL,
		baseTransparency = 0.1,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.5,
		overlayRgb = { 170, 150, 210 },
		faces = { "Front", "Back", "Left", "Right" },
	}),
}

local ZONE_FLOORS: { [string]: SurfaceSkin } = {
	zone_bastion_safe = skin({
		id = "zone_bastion_safe",
		material = "Slate",
		studsPerTile = 14,
		baseAssetId = SLATE_FLOOR,
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.78,
		overlayRgb = { 120, 140, 180 },
	}),
	zone_plain_free = skin({
		id = "zone_plain_free",
		material = "Ground",
		studsPerTile = 18,
	}),
	zone_lumen_safe = skin({
		id = "zone_lumen_safe",
		material = "Asphalt",
		studsPerTile = 16,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.55,
		baseRgb = { 40, 50, 90 },
		overlayAssetId = LIGHTNING,
		overlayTransparency = 0.72,
		overlayRgb = { 80, 220, 255 },
	}),
	zone_echo_woods = skin({
		id = "zone_echo_woods",
		material = "LeafyGrass",
		studsPerTile = 12,
	}),
	zone_iron_port = skin({
		id = "zone_iron_port",
		material = "Concrete",
		studsPerTile = 16,
		baseAssetId = RUNED_WALL,
		baseTransparency = 0.55,
		baseRgb = { 140, 120, 100 },
	}),
	zone_grey_sector = skin({
		id = "zone_grey_sector",
		material = "Basalt",
		studsPerTile = 16,
		baseAssetId = RUNED_WALL,
		baseTransparency = 0.45,
		baseRgb = { 90, 92, 100 },
	}),
	zone_academy_safe = skin({
		id = "zone_academy_safe",
		material = "Sandstone",
		studsPerTile = 14,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.45,
		baseRgb = { 220, 190, 140 },
		overlayAssetId = POWER_RING,
		overlayTransparency = 0.82,
		overlayRgb = { 212, 168, 72 },
	}),
	zone_veil_safe = skin({
		id = "zone_veil_safe",
		material = "LeafyGrass",
		studsPerTile = 12,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.62,
		baseRgb = { 48, 62, 52 },
		overlayAssetId = ENERGY_BALL,
		overlayTransparency = 0.8,
		overlayRgb = { 90, 70, 130 },
	}),
	zone_threshold_transition = skin({
		id = "zone_threshold_transition",
		material = "Salt",
		studsPerTile = 10,
		baseAssetId = SLATE_FLOOR,
		baseTransparency = 0.3,
		overlayAssetId = POWER_RING,
		overlayTransparency = 0.55,
		overlayRgb = { 255, 210, 120 },
	}),
}

local ALLOWED_IDS: { [string]: boolean } = {
	[SLATE_FLOOR] = true,
	[RUNED_WALL] = true,
	[CRYSTAL] = true,
	[ENERGY_BALL] = true,
	[POWER_RING] = true,
	[LIGHTNING] = true,
	[SCORCH] = true,
}

local ALLOWED_FACES: { [string]: boolean } = {
	Top = true,
	Bottom = true,
	Front = true,
	Back = true,
	Left = true,
	Right = true,
}

local WorldTextures = {}

WorldTextures.SlateFloor = SLATE_FLOOR
WorldTextures.RunedWall = RUNED_WALL
WorldTextures.Crystal = CRYSTAL
WorldTextures.EnergyBall = ENERGY_BALL
WorldTextures.PowerRing = POWER_RING
WorldTextures.Lightning = LIGHTNING
WorldTextures.Scorch = SCORCH

function WorldTextures.named(name: string): SurfaceSkin?
	return NAMED[name]
end

function WorldTextures.forZone(zoneId: string): SurfaceSkin?
	return ZONE_FLOORS[zoneId]
end

function WorldTextures.all(): { SurfaceSkin }
	local out: { SurfaceSkin } = {}
	for _, entry in NAMED do
		table.insert(out, entry)
	end
	for _, entry in ZONE_FLOORS do
		table.insert(out, entry)
	end
	return out
end

function WorldTextures.overlayIds(): { string }
	return { ENERGY_BALL, POWER_RING, LIGHTNING, SCORCH }
end

function WorldTextures.colorMapIds(): { string }
	return { SLATE_FLOOR, RUNED_WALL, CRYSTAL }
end

function WorldTextures.facesOf(entry: SurfaceSkin): { string }
	if type(entry.faces) == "table" and #entry.faces > 0 then
		return entry.faces
	end
	return { "Top" }
end

local function checkId(assetId: string?, owner: string, kind: string): (boolean, string?)
	if assetId == nil then
		return true, nil
	end
	if ALLOWED_IDS[assetId] ~= true then
		return false, kind .. " não publicado: " .. owner
	end
	return true, nil
end

function WorldTextures.validate(): (boolean, string?)
	for _, entry in WorldTextures.all() do
		if entry.studsPerTile <= 0 then
			return false, "tile inválido: " .. entry.id
		end
		if entry.baseTransparency < 0 or entry.baseTransparency > 1 then
			return false, "base transparência fora de 0..1: " .. entry.id
		end
		if entry.overlayTransparency < 0 or entry.overlayTransparency > 1 then
			return false, "transparência fora de 0..1: " .. entry.id
		end
		if #entry.baseRgb ~= 3 or #entry.overlayRgb ~= 3 then
			return false, "rgb inválido: " .. entry.id
		end
		local okId, reason = checkId(entry.baseAssetId, entry.id, "base")
		if not okId then
			return false, reason
		end
		okId, reason = checkId(entry.overlayAssetId, entry.id, "overlay")
		if not okId then
			return false, reason
		end
		if entry.overlayAssetId ~= nil and entry.overlayTransparency >= 1 then
			return false, "overlay invisível: " .. entry.id
		end
		if entry.baseAssetId ~= nil and entry.baseTransparency >= 1 then
			return false, "base invisível: " .. entry.id
		end
		for _, face in WorldTextures.facesOf(entry) do
			if ALLOWED_FACES[face] ~= true then
				return false, "face inválida: " .. entry.id .. "/" .. face
			end
		end
	end
	return true, nil
end

return WorldTextures

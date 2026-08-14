-- Assets visuais gratuitos selecionados para habilidades de NPC.
-- A licença CC0 e os arquivos locais ficam documentados em docs/21-MONSTER-SKINS-ABILITIES.md.

export type AssetSpec = {
	key: string,
	sourceFile: string,
	assetId: string?,
	mode: "OneShot" | "Loop",
	framerate: number,
}

local ASSETS: { [string]: AssetSpec } = {
	kenney_slash = {
		key = "kenney_slash",
		sourceFile = "AVB-free-vfx-assets/assets/vfx/kenney/slash_01.png",
		assetId = nil,
		mode = "OneShot",
		framerate = 18,
	},
	kenney_spark = {
		key = "kenney_spark",
		sourceFile = "AVB-free-vfx-assets/assets/vfx/kenney/spark_01.png",
		assetId = nil,
		mode = "OneShot",
		framerate = 20,
	},
	kenney_scorch = {
		key = "kenney_scorch",
		sourceFile = "AVB-free-vfx-assets/assets/vfx/kenney/scorch_01.png",
		assetId = nil,
		mode = "OneShot",
		framerate = 16,
	},
}

local EnemyVfxAssets = {}

function EnemyVfxAssets.get(key: string?): AssetSpec?
	if type(key) ~= "string" then
		return nil
	end
	return ASSETS[key]
end

function EnemyVfxAssets.all(): { AssetSpec }
	local out: { AssetSpec } = {}
	for _, asset in ASSETS do
		table.insert(out, asset)
	end
	table.sort(out, function(a, b)
		return a.key < b.key
	end)
	return out
end

function EnemyVfxAssets.validate(): (boolean, string?)
	for key, asset in ASSETS do
		if key ~= asset.key or asset.framerate <= 0 then
			return false, "asset de inimigo inválido: " .. key
		end
	end
	return true, nil
end

return EnemyVfxAssets

-- Catálogo visual do cenário. Não contém regra de jogo, hitbox ou decisão de zona.
-- Os assets externos são referências/importações opcionais; o runtime usa peças
-- Roblox nativas para o mundo funcionar antes de publicar modelos externos.

export type SceneryStyle = {
	wallColor: { number },
	wallAccent: { number },
	wallCap: { number },
	terrainColor: { number },
	terrainAccent: { number },
	roofColor: { number },
	roofTransparency: number,
	wallCapHeight: number,
	rockCount: number,
	grassCount: number,
}

local STYLE: SceneryStyle = {
	wallColor = { 74, 78, 88 },
	wallAccent = { 121, 86, 166 },
	wallCap = { 105, 109, 122 },
	terrainColor = { 92, 82, 70 },
	terrainAccent = { 117, 103, 82 },
	roofColor = { 46, 50, 62 },
	roofTransparency = 0.22,
	wallCapHeight = 0.7,
	rockCount = 22,
	grassCount = 28,
}

local SceneryPresentation = {}

function SceneryPresentation.style(): SceneryStyle
	return STYLE
end

function SceneryPresentation.assetSources(): { { name: string, url: string, license: string } }
	return {
		{
			name = "Kenney Nature Kit",
			url = "https://kenney.nl/assets/nature-kit",
			license = "CC0",
		},
		{
			name = "ambientCG Rock035",
			url = "https://ambientcg.com/view?id=Rock035",
			license = "CC0",
		},
	}
end

local function validRgb(rgb: { number }): boolean
	return #rgb == 3
		and rgb[1] >= 0
		and rgb[1] <= 255
		and rgb[2] >= 0
		and rgb[2] <= 255
		and rgb[3] >= 0
		and rgb[3] <= 255
end

local function distanceXZ(a: any, b: any): number
	local dx = a.position.x - b.position.x
	local dz = a.position.z - b.position.z
	return math.sqrt(dx * dx + dz * dz)
end

function SceneryPresentation.validate(): (boolean, string?)
	for _, key in { "wallColor", "wallAccent", "wallCap", "terrainColor", "terrainAccent", "roofColor" } do
		local rgb = STYLE[key]
		if not validRgb(rgb) then
			return false, ("cor RGB inválida: %s"):format(key)
		end
	end
	if STYLE.wallCapHeight <= 0 or STYLE.wallCapHeight > 4 then
		return false, "altura da tampa de parede fora do orçamento"
	end
	if STYLE.rockCount < 20 or STYLE.rockCount > 64 or STYLE.grassCount < 20 or STYLE.grassCount > 96 then
		return false, "densidade natural fora do orçamento do cenário"
	end
	if STYLE.roofTransparency < 0.08 or STYLE.roofTransparency >= 1 then
		return false, "transparência do teto inválida"
	end
	local sources = SceneryPresentation.assetSources()
	if #sources < 2 then
		return false, "fontes de cenário insuficientes"
	end
	for _, source in sources do
		if source.name == "" or source.license ~= "CC0" or string.sub(source.url, 1, 8) ~= "https://" then
			return false, "fonte de cenário sem licença/URL auditável"
		end
	end
	return true, nil
end

function SceneryPresentation.validateLayout(zones: any): (boolean, string?)
	local ok, reason = SceneryPresentation.validate()
	if not ok then
		return false, reason
	end
	if not zones or type(zones.getAnchor) ~= "function" or type(zones.zoneAtPosition) ~= "function" then
		return false, "catálogo de zonas incompatível"
	end
	local greybox = zones.greybox()
	if greybox.bastionSize.x <= STYLE.wallCapHeight * 2 or greybox.bastionSize.z <= STYLE.wallCapHeight * 2 then
		return false, "bastião menor que o orçamento de parede"
	end
	if
		greybox.spawnRadius <= 0
		or greybox.spawnRadius >= math.min(greybox.bastionSize.x, greybox.bastionSize.z) / 2
	then
		return false, "raio de spawn invade a borda do bastião"
	end
	local required = {
		"anchor_bastion_spawn",
		"anchor_bastion_return",
		"anchor_training",
		"anchor_instructor",
		"anchor_gate_north",
		"anchor_gate_west",
		"anchor_elite",
	}
	for _, anchorId in required do
		local anchor = zones.getAnchor(anchorId)
		if not anchor then
			return false, ("âncora obrigatória ausente: %s"):format(anchorId)
		end
		if zones.zoneAtPosition(anchor.position) ~= anchor.zoneId then
			return false, ("âncora fora da zona declarada: %s"):format(anchorId)
		end
	end
	local gates = zones.gateAnchors()
	local shards = zones.shardAnchors()
	for _, shardId in shards do
		local shard = zones.getAnchor(shardId)
		if not shard then
			return false, ("âncora de shard ausente: %s"):format(shardId)
		end
		for _, gateId in gates do
			local gate = zones.getAnchor(gateId)
			if gate and distanceXZ(shard, gate) < 20 then
				return false, ("shard perto demais do portão: %s"):format(shardId)
			end
		end
	end
	for index, shardId in shards do
		local first = zones.getAnchor(shardId)
		if first then
			for otherIndex = index + 1, #shards do
				local second = zones.getAnchor(shards[otherIndex])
				if second and distanceXZ(first, second) < 24 then
					return false, ("shards muito próximos: %s/%s"):format(shardId, shards[otherIndex])
				end
			end
		end
	end
	return true, nil
end

return SceneryPresentation

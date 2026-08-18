-- Catálogo visual do cenário. Não contém regra de jogo, hitbox ou decisão de zona.
-- Os assets externos são referências/importações opcionais; o runtime usa peças
-- Roblox nativas para o mundo funcionar antes de publicar modelos externos.

-- Uma fonte de luz da sala de spawn. As posições viviam dentro do
-- `WorldService` (15/08) e voltaram para cá pelo mesmo motivo do resto do
-- cenário: onde a luz cai é decisão de apresentação, e decisão é dado.
--
-- `tone` escolhe entre as duas cores do estilo (`lightColor` frio de chave e
-- `fillLightColor` violeta de preenchimento). `shadows` é caro: PointLight com
-- sombra pesa no Android, então só as duas fontes que definem a leitura da sala
-- projetam — as outras só preenchem.
export type SpawnLight = {
	name: string,
	position: { number },
	tone: "key" | "fill",
	shadows: boolean,
}

export type SceneryStyle = {
	wallColor: { number },
	wallAccent: { number },
	wallCap: { number },
	terrainColor: { number },
	terrainAccent: { number },
	roofColor: { number },
	floorColor: { number },
	floorAccent: { number },
	ceilingColor: { number },
	lightColor: { number },
	fillLightColor: { number },
	roofTransparency: number,
	wallCapHeight: number,
	wallMaterial: string,
	wallCapMaterial: string,
	wallBandMaterial: string,
	spawnLightBrightness: number,
	spawnLightRange: number,
	spawnLightCount: number,
	rockCount: number,
	grassCount: number,
}

local STYLE: SceneryStyle = {
	wallColor = { 118, 104, 90 },
	wallAccent = { 138, 96, 196 },
	wallCap = { 176, 164, 142 },
	terrainColor = { 92, 82, 70 },
	terrainAccent = { 117, 103, 82 },
	roofColor = { 32, 38, 54 },
	floorColor = { 48, 54, 68 },
	floorAccent = { 118, 108, 96 },
	ceilingColor = { 32, 38, 54 },
	lightColor = { 144, 216, 255 },
	fillLightColor = { 184, 142, 255 },
	roofTransparency = 0.18,
	wallCapHeight = 0.85,
	wallMaterial = "Limestone",
	wallCapMaterial = "Sandstone",
	wallBandMaterial = "Basalt",
	spawnLightBrightness = 1.35,
	spawnLightRange = 18,
	spawnLightCount = 8,
	rockCount = 22,
	grassCount = 28,
}

-- Oito fontes: as seis da praça mais duas que a rodada de 15/08 não tinha —
-- uma em cima da Instrutora e uma no pad de treino. Os dois pontos onde o
-- jogador precisa ENXERGAR alguma coisa nos primeiros 60 s do roteiro (docs/13
-- §10) eram justamente os que ficavam no escuro.
local SPAWN_LIGHTS: { SpawnLight } = {
	{ name = "PlazaKey", position = { 0, 18, 6 }, tone = "key", shadows = true },
	{ name = "PlazaFill", position = { 0, 9, 6 }, tone = "fill", shadows = false },
	{ name = "SouthWest", position = { -20, 12, 12 }, tone = "key", shadows = false },
	{ name = "SouthEast", position = { 20, 12, 12 }, tone = "fill", shadows = false },
	{ name = "NorthWest", position = { -12, 10, -18 }, tone = "fill", shadows = false },
	{ name = "NorthEast", position = { 12, 10, -18 }, tone = "key", shadows = false },
	{ name = "QuestGiver", position = { 20, 8.5, -12.5 }, tone = "key", shadows = true },
	{ name = "TrainingPad", position = { 28, 9, -20 }, tone = "fill", shadows = false },
}

local SceneryPresentation = {}

function SceneryPresentation.style(): SceneryStyle
	return STYLE
end

function SceneryPresentation.spawnLights(): { SpawnLight }
	return SPAWN_LIGHTS
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
	for _, key in
		{
			"wallColor",
			"wallAccent",
			"wallCap",
			"terrainColor",
			"terrainAccent",
			"roofColor",
			"floorColor",
			"floorAccent",
			"ceilingColor",
			"lightColor",
			"fillLightColor",
		}
	do
		local rgb = STYLE[key]
		if not validRgb(rgb) then
			return false, ("cor RGB inválida: %s"):format(key)
		end
	end
	if STYLE.wallCapHeight <= 0 or STYLE.wallCapHeight > 4 then
		return false, "altura da tampa de parede fora do orçamento"
	end
	if STYLE.wallMaterial == "Slate" and STYLE.wallCapMaterial == "Slate" then
		return false, "muralha não pode ser só Slate uniforme"
	end
	if STYLE.wallMaterial == STYLE.wallCapMaterial and STYLE.wallCapMaterial == STYLE.wallBandMaterial then
		return false, "muralha precisa de ao menos dois materiais"
	end
	if
		STYLE.spawnLightBrightness <= 0
		or STYLE.spawnLightBrightness > 4
		or STYLE.spawnLightRange < 8
		or STYLE.spawnLightRange > 32
		or STYLE.spawnLightCount < 2
		or STYLE.spawnLightCount > 12
	then
		return false, "iluminação do spawn fora do orçamento"
	end
	if #SPAWN_LIGHTS ~= STYLE.spawnLightCount then
		return false, ("fontes declaradas (%d) diferem do orçamento (%d)"):format(#SPAWN_LIGHTS, STYLE.spawnLightCount)
	end
	local shadowCasters = 0
	local names: { [string]: boolean } = {}
	for _, light in SPAWN_LIGHTS do
		if light.name == "" or names[light.name] then
			return false, "fonte de luz sem nome único: " .. light.name
		end
		names[light.name] = true
		if light.tone ~= "key" and light.tone ~= "fill" then
			return false, ("tom de luz inválido em %s"):format(light.name)
		end
		if #light.position ~= 3 then
			return false, ("posição de luz inválida em %s"):format(light.name)
		end
		if light.shadows then
			shadowCasters += 1
		end
	end
	-- Sombra de PointLight é o item mais caro desta sala no Android (docs/15).
	if shadowCasters > 2 then
		return false, ("fontes com sombra além do orçamento: %d"):format(shadowCasters)
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
	-- Luz fora da sala ilumina o lado de fora e deixa a praça escura; luz acima
	-- do teto (Y = 22) fica presa no painel de vidro.
	local bastionHalfX = greybox.bastionSize.x / 2 - 2
	local bastionHalfZ = greybox.bastionSize.z / 2 - 2
	for _, light in SPAWN_LIGHTS do
		local x, y, z = light.position[1], light.position[2], light.position[3]
		if math.abs(x) > bastionHalfX or math.abs(z) > bastionHalfZ then
			return false, ("fonte de luz fora do bastião: %s"):format(light.name)
		end
		if y < 4 or y > 21 then
			return false, ("altura de luz fora da sala: %s (%.1f)"):format(light.name, y)
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

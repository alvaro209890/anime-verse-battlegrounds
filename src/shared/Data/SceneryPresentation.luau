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

function SceneryPresentation.validate(): (boolean, string?)
	if STYLE.wallCapHeight <= 0 or STYLE.rockCount < 0 or STYLE.grassCount < 0 then
		return false, "parâmetros de cenário inválidos"
	end
	if STYLE.roofTransparency < 0 or STYLE.roofTransparency >= 1 then
		return false, "transparência do teto inválida"
	end
	return true, nil
end

return SceneryPresentation

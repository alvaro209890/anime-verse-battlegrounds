--!strict
-- CatalogService (server) — F0
-- Carrega e valida as definições versionadas antes de expor ao resto.
-- Validar no boot: referências cruzadas (ability → character → family) e
-- invariantes mínimas. Falha de catálogo derruba o boot (kill switch de conteúdo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Data.Abilities)
local Characters = require(ReplicatedStorage.Shared.Data.Characters)
local EnergyFamilies = require(ReplicatedStorage.Shared.Data.EnergyFamilies)
local Types = require(ReplicatedStorage.Shared.Types)

local CatalogService = {}

local validated = false

local function fail(reason: string)
	error(("[CatalogService] conteúdo inválido: %s"):format(reason))
end

function CatalogService.validate(): ()
	if validated then
		return
	end

	local familyIds: { [string]: boolean } = {}
	for _, fam in EnergyFamilies.all() do
		familyIds[fam.id] = true
	end

	local characterIds: { [string]: boolean } = {}
	for _, char in Characters.all() do
		characterIds[char.id] = true
		if not familyIds[char.energyFamilyId] then
			fail(("character %s → família desconhecida %s"):format(char.id, char.energyFamilyId))
		end
		if #char.abilityIds == 0 then
			fail(("character %s sem habilidades"):format(char.id))
		end
	end

	for _, ab in Abilities.all() do
		if not characterIds[ab.sourceCharacterId] then
			fail(("ability %s → personagem fonte desconhecido %s"):format(ab.id, ab.sourceCharacterId))
		end
		if not familyIds[ab.energyFamilyId] then
			fail(("ability %s → família desconhecida %s"):format(ab.id, ab.energyFamilyId))
		end
		if ab.kind ~= "Ultimate" and (ab.slotCost < 1 or ab.slotCost > 2) then
			fail(("ability %s → slotCost fora de 1-2"):format(ab.id))
		end
		if ab.cooldown.baseSeconds < 0 or ab.resourceCost.amount < 0 then
			fail(("ability %s → valores negativos"):format(ab.id))
		end
	end

	validated = true
end

function CatalogService.getAbility(abilityId: string): Types.AbilityDefinition?
	CatalogService.validate()
	return Abilities.get(abilityId)
end

function CatalogService.getCharacter(characterId: string): Types.CharacterDefinition?
	CatalogService.validate()
	return Characters.get(characterId)
end

function CatalogService.getFamily(familyId: string): Types.EnergyFamilyDefinition?
	CatalogService.validate()
	return EnergyFamilies.get(familyId)
end

return CatalogService

--!strict
-- CatalogService (server) — F0 (docs/04 §4.1)
-- Carrega e valida as definições versionadas antes de expor ao resto.
-- Validar no boot: referências cruzadas (ability → character → family) e
-- invariantes mínimas. Falha de catálogo derruba o boot (kill switch de conteúdo).
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type CatalogDeps = {
	Abilities: { get: (string) -> any?, all: () -> { any } },
	Characters: { get: (string) -> any?, all: () -> { any } },
	EnergyFamilies: { get: (string) -> any?, all: () -> { any } },
	Npcs: { get: (string) -> any?, all: () -> { any } }?,
}

local CatalogService = {
	validated = false,
	deps = nil :: CatalogDeps?,
}

local function fail(reason: string)
	error(("[CatalogService] conteúdo inválido: %s"):format(reason))
end

function CatalogService.init(deps: CatalogDeps): ()
	CatalogService.deps = deps
	CatalogService.validated = false
	CatalogService.validate()
end

function CatalogService.validate(): ()
	if CatalogService.validated then
		return
	end
	local deps = CatalogService.deps
	if not deps then
		error("[CatalogService] init() não chamado")
	end

	local familyIds: { [string]: boolean } = {}
	for _, fam in deps.EnergyFamilies.all() do
		familyIds[fam.id] = true
	end

	local characterIds: { [string]: boolean } = {}
	for _, char in deps.Characters.all() do
		characterIds[char.id] = true
		if not familyIds[char.energyFamilyId] then
			fail(("character %s → família desconhecida %s"):format(char.id, char.energyFamilyId))
		end
		if #char.abilityIds == 0 then
			fail(("character %s sem habilidades"):format(char.id))
		end
		for _, abilityId in char.abilityIds do
			if deps.Abilities.get(abilityId) == nil then
				fail(("character %s → habilidade ausente %s"):format(char.id, abilityId))
			end
		end
	end

	for _, ab in deps.Abilities.all() do
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

	if deps.Npcs then
		for _, npc in deps.Npcs.all() do
			if npc.maxHealth <= 0 then
				fail(("npc %s → maxHealth inválido"):format(npc.id))
			end
			if npc.attackRange < 0 or npc.attackPeriodSeconds < 0 then
				fail(("npc %s → alcance/período inválido"):format(npc.id))
			end
		end
	end

	CatalogService.validated = true
end

function CatalogService.getAbility(abilityId: string): any?
	local deps = CatalogService.deps
	if not deps then
		return nil
	end
	CatalogService.validate()
	return deps.Abilities.get(abilityId)
end

function CatalogService.getCharacter(characterId: string): any?
	local deps = CatalogService.deps
	if not deps then
		return nil
	end
	CatalogService.validate()
	return deps.Characters.get(characterId)
end

function CatalogService.getFamily(familyId: string): any?
	local deps = CatalogService.deps
	if not deps then
		return nil
	end
	CatalogService.validate()
	return deps.EnergyFamilies.get(familyId)
end

function CatalogService.getNpc(npcId: string): any?
	local deps = CatalogService.deps
	if not deps or not deps.Npcs then
		return nil
	end
	CatalogService.validate()
	return deps.Npcs.get(npcId)
end

return CatalogService

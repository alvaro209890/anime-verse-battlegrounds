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
	Zones: { get: (string) -> any?, all: () -> { any }, getAnchor: (string) -> any?, allAnchors: () -> { any } }?,
}

local CatalogService = {
	validated = false,
	deps = nil :: CatalogDeps?,
}

local function fail(reason: string)
	error(("[CatalogService] conteúdo inválido: %s"):format(reason))
end

function CatalogService.init(deps: CatalogDeps): ()
	local previousDeps = CatalogService.deps
	local previousValidated = CatalogService.validated
	CatalogService.deps = deps
	CatalogService.validated = false
	local ok, err = pcall(CatalogService.validate)
	if not ok then
		CatalogService.deps = previousDeps
		CatalogService.validated = previousValidated
		error(err)
	end
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
		local hasDummy = false
		local hasShard = false
		for _, npc in deps.Npcs.all() do
			if npc.maxHealth <= 0 then
				fail(("npc %s → maxHealth inválido"):format(npc.id))
			end
			if npc.attackRange < 0 or npc.attackPeriodSeconds < 0 then
				fail(("npc %s → alcance/período inválido"):format(npc.id))
			end
			if npc.kind == "enemy" then
				if npc.zoneId == nil or npc.maxAlive == nil or npc.telegraphMs == nil then
					fail(("npc %s → inimigo sem zoneId/maxAlive/telegraphMs"):format(npc.id))
				end
				if npc.maxAlive < 1 then
					fail(("npc %s → maxAlive inválido"):format(npc.id))
				end
			end
			if npc.id == "npc_training_dummy" then
				hasDummy = true
			end
			if npc.id == "enemy_wandering_shard" then
				hasShard = true
				if npc.maxHealth ~= 40 or npc.attackDamage ~= 6 or npc.attackRange ~= 4 then
					fail("enemy_wandering_shard fora do baseline F0 (40 HP / dano 6 / alcance 4)")
				end
				if npc.zoneId ~= "zone_plain_free" then
					fail("enemy_wandering_shard deve viver em zone_plain_free")
				end
				if npc.maxAlive > 4 then
					fail("enemy_wandering_shard maxAlive > 4")
				end
			end
		end
		if not hasDummy then
			fail("catálogo de NPCs sem npc_training_dummy")
		end
		if not hasShard then
			fail("catálogo de NPCs sem enemy_wandering_shard")
		end
	end

	if deps.Zones then
		local zoneIds: { [string]: boolean } = {}
		local freeZones = 0
		for _, zone in deps.Zones.all() do
			zoneIds[zone.id] = true
			if zone.kind ~= "safe" and zone.kind ~= "transition" and zone.kind ~= "free" then
				fail(("zone %s → kind inválido"):format(zone.id))
			end
			if zone.pvp then
				freeZones += 1
				-- F0: alto risco não existe; PvP só em zone_plain_free
				if zone.id ~= "zone_plain_free" then
					fail(("zone %s → PvP fora da planície não existe na fatia"):format(zone.id))
				end
			end
		end
		if freeZones < 1 then
			fail("catálogo de zonas sem zona livre (PvP)")
		end
		if not zoneIds["zone_bastion_safe"] then
			fail("catálogo de zonas sem zone_bastion_safe")
		end
		if not zoneIds["zone_threshold_transition"] then
			fail("catálogo de zonas sem zone_threshold_transition")
		end
		if not zoneIds["zone_plain_free"] then
			fail("catálogo de zonas sem zone_plain_free")
		end

		local anchors: { [string]: boolean } = {}
		for _, anchor in deps.Zones.allAnchors() do
			anchors[anchor.id] = true
			if not zoneIds[anchor.zoneId] then
				fail(("anchor %s → zona desconhecida %s"):format(anchor.id, anchor.zoneId))
			end
		end
		local spawnAnchor = deps.Zones.getAnchor("anchor_bastion_spawn")
		if not spawnAnchor then
			fail("spawn default anchor_bastion_spawn ausente")
		end
		if spawnAnchor.zoneId ~= "zone_bastion_safe" then
			fail(("spawn default deve estar em zone_bastion_safe (está em %s)"):format(spawnAnchor.zoneId))
		end
		local requiredAnchors = {
			"anchor_bastion_spawn",
			"anchor_bastion_return",
			"anchor_training",
			"anchor_gate_north",
			"anchor_gate_west",
			"anchor_elite",
		}
		for _, anchorId in requiredAnchors do
			if not anchors[anchorId] then
				fail(("anchor obrigatória %s ausente"):format(anchorId))
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

function CatalogService.getZone(zoneId: string): any?
	local deps = CatalogService.deps
	if not deps or not deps.Zones then
		return nil
	end
	CatalogService.validate()
	return deps.Zones.get(zoneId)
end

function CatalogService.getAnchor(anchorId: string): any?
	local deps = CatalogService.deps
	if not deps or not deps.Zones then
		return nil
	end
	CatalogService.validate()
	return deps.Zones.getAnchor(anchorId)
end

return CatalogService

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
	Zones: {
		get: (string) -> any?,
		all: () -> { any },
		getAnchor: (string) -> any?,
		allAnchors: () -> { any },
		zoneAtPosition: ((any) -> string?)?,
		shardAnchors: (() -> { string })?,
		gateAnchors: (() -> { string })?,
	}?,
	Quests: { get: (string) -> any?, all: () -> { any }, chain: () -> { string } }?,
	Locale: { hasKey: (string) -> boolean, get: (string, any?) -> string }?,
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
				if type(npc.aggroRadiusStuds) == "number" then
					if npc.aggroRadiusStuds <= 0 or npc.aggroRadiusStuds < npc.attackRange then
						fail(("npc %s → aggroRadiusStuds deve ser ≥ attackRange e > 0"):format(npc.id))
					end
				end
			end
			if npc.id == "npc_training_dummy" then
				hasDummy = true
			end
			if npc.id == "enemy_wandering_shard" then
				hasShard = true
				if npc.maxHealth ~= 60 or npc.attackDamage ~= 8 or npc.attackRange ~= 4 then
					fail("enemy_wandering_shard fora do baseline F0 (60 HP / dano 8 / alcance 4)")
				end
				if npc.aggroRadiusStuds ~= 30 then
					fail("enemy_wandering_shard fora do raio de aggro F0 (30 studs)")
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
		local hasElite = false
		for _, npc in deps.Npcs.all() do
			if npc.id == "enemy_anchored_shard" then
				hasElite = true
				if npc.maxHealth ~= 120 or npc.eliteSlamDamage ~= 14 or npc.eliteSlamTelegraphMs ~= 700 then
					fail("enemy_anchored_shard fora do baseline F0 (120 HP / slam 14 / telegraph 700)")
				end
				if npc.eliteComboDamage ~= 6 or npc.eliteComboTelegraphMs ~= 300 then
					fail("enemy_anchored_shard combo leve fora do baseline (6+6 / 300 ms)")
				end
				if npc.respawnSeconds ~= 180 then
					fail("enemy_anchored_shard respawn deve ser 180 s")
				end
				if npc.xpUnconsolidated ~= 80 or npc.xpCooldownSeconds ~= 180 then
					fail("enemy_anchored_shard XP fora do baseline (80 / cooldown 180 s)")
				end
				if npc.maxAlive ~= 1 then
					fail("enemy_anchored_shard maxAlive deve ser 1")
				end
				if npc.zoneId ~= "zone_plain_free" then
					fail("enemy_anchored_shard deve viver em zone_plain_free")
				end
				if npc.leechDamagePct ~= 0.01 or npc.leechStaySeconds ~= 8 then
					fail("enemy_anchored_shard leeching fora do baseline (1% / 8 s)")
				end
				if npc.attackPattern ~= "elite" then
					fail('enemy_anchored_shard attackPattern deve ser "elite"')
				end
			end
		end
		if not hasElite then
			fail("catálogo de NPCs sem enemy_anchored_shard")
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
				-- Alto risco continua fora; PvP só em zona livre (planície + biomas).
				if zone.kind ~= "free" then
					fail(("zone %s → PvP exige kind=free"):format(zone.id))
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
			"anchor_instructor",
			"anchor_gate_north",
			"anchor_gate_west",
			"anchor_elite",
		}
		for _, anchorId in requiredAnchors do
			if not anchors[anchorId] then
				fail(("anchor obrigatória %s ausente"):format(anchorId))
			end
		end

		-- Volumes: toda zona precisa de pelo menos uma caixa bem formada.
		for _, zone in deps.Zones.all() do
			if zone.volumes == nil or #zone.volumes == 0 then
				fail(("zone %s → sem volume físico"):format(zone.id))
			end
			for index, b in zone.volumes do
				if b.min.x >= b.max.x or b.min.y >= b.max.y or b.min.z >= b.max.z then
					fail(("zone %s → volume %d invertido ou degenerado"):format(zone.id, index))
				end
			end
		end

		-- A geometria e os dados de âncora precisam concordar: cada âncora tem
		-- de cair dentro do volume da zona que ela declara. Isto pega deriva
		-- entre §8.1 (medidas) e §8.3 (âncoras) na hora do boot.
		if deps.Zones.zoneAtPosition then
			for _, anchor in deps.Zones.allAnchors() do
				local resolved = deps.Zones.zoneAtPosition(anchor.position)
				if resolved ~= anchor.zoneId then
					fail(
						("anchor %s declara %s mas a geometria resolve %s"):format(
							anchor.id,
							anchor.zoneId,
							tostring(resolved)
						)
					)
				end
			end
		end

		-- Pontos de Estilhaço (§8.1): 6 âncoras, no mínimo 24 studs entre si e
		-- nenhuma a menos de 20 de um portão.
		if deps.Zones.shardAnchors then
			local shardIds = deps.Zones.shardAnchors()
			if #shardIds ~= 6 then
				fail(("pontos de Estilhaço: esperado 6, encontrado %d"):format(#shardIds))
			end
			local function positionOf(anchorId: string): any
				local anchor = deps.Zones.getAnchor(anchorId)
				if not anchor then
					fail(("ponto de Estilhaço %s ausente"):format(anchorId))
				end
				return anchor
			end
			local function planarDistance(a: any, b: any): number
				local dx = a.x - b.x
				local dz = a.z - b.z
				return math.sqrt(dx * dx + dz * dz)
			end
			for i = 1, #shardIds do
				local anchorA = positionOf(shardIds[i])
				if anchorA.zoneId ~= "zone_plain_free" then
					fail(("ponto de Estilhaço %s fora da planície"):format(shardIds[i]))
				end
				for j = i + 1, #shardIds do
					local anchorB = positionOf(shardIds[j])
					local d = planarDistance(anchorA.position, anchorB.position)
					if d < 24 then
						fail(
							("pontos de Estilhaço %s e %s a %.1f studs (mínimo 24)"):format(
								shardIds[i],
								shardIds[j],
								d
							)
						)
					end
				end
				if deps.Zones.gateAnchors then
					for _, gateId in deps.Zones.gateAnchors() do
						local gate = deps.Zones.getAnchor(gateId)
						if gate then
							local d = planarDistance(anchorA.position, gate.position)
							if d < 20 then
								fail(
									("ponto de Estilhaço %s a %.1f studs do portão %s (mínimo 20)"):format(
										shardIds[i],
										d,
										gateId
									)
								)
							end
						end
					end
				end
			end
		end
	end

	if deps.Quests then
		local npcIds: { [string]: boolean } = {}
		if deps.Npcs then
			for _, npc in deps.Npcs.all() do
				npcIds[npc.id] = true
			end
		end
		for _, quest in deps.Quests.all() do
			if quest.requiredCount < 1 then
				fail(("quest %s → requiredCount inválido"):format(quest.id))
			end
			if quest.xpReward < 0 then
				fail(("quest %s → xpReward negativo"):format(quest.id))
			end
			if quest.autoAcceptAfterSeconds < 0 then
				fail(("quest %s → autoAcceptAfterSeconds negativo"):format(quest.id))
			end
			if quest.kind ~= "kill" and quest.kind ~= "flow_echo" then
				fail(("quest %s → kind não suportado na fatia: %s"):format(quest.id, tostring(quest.kind)))
			end
			if deps.Npcs then
				if quest.kind == "kill" then
					if not npcIds[quest.targetId] then
						fail(("quest %s → alvo desconhecido %s"):format(quest.id, quest.targetId))
					end
				else
					-- kind "flow_echo": o alvo é a HABILIDADE que gera o eco (item 10).
					if deps.Abilities.get(quest.targetId) == nil then
						fail(("quest %s → habilidade de eco desconhecida %s"):format(quest.id, quest.targetId))
					end
				end
				if not npcIds[quest.giverNpcId] then
					fail(("quest %s → ofertante desconhecido %s"):format(quest.id, quest.giverNpcId))
				end
			end
			if type(quest.acceptFlag) ~= "string" or quest.acceptFlag == "" then
				fail(("quest %s → acceptFlag ausente"):format(quest.id))
			end
		end
		local chain = deps.Quests.chain()
		if #chain < 1 then
			fail("cadeia de objetivos vazia (objetivo 1 é obrigatório na fatia)")
		end
		for _, questId in chain do
			if deps.Quests.get(questId) == nil then
				fail(("cadeia referencia objetivo ausente %s"):format(questId))
			end
		end
	end

	-- Toda chave de UI de conteúdo habilitado precisa existir no Locale.
	-- `descriptionKey` entra com a UI (item 12 do backlog).
	if deps.Locale then
		local function requireKey(owner: string, key: string?)
			if key == nil or key == "" then
				return
			end
			if not deps.Locale.hasKey(key) then
				fail(("%s → chave de locale ausente %s"):format(owner, key))
			end
		end
		for _, char in deps.Characters.all() do
			if char.enabled then
				requireKey("character " .. char.id, char.displayNameKey)
			end
		end
		for _, ab in deps.Abilities.all() do
			requireKey("ability " .. ab.id, ab.displayNameKey)
		end
		for _, fam in deps.EnergyFamilies.all() do
			requireKey("family " .. fam.id, fam.displayNameKey)
		end
		if deps.Npcs then
			for _, npc in deps.Npcs.all() do
				if npc.enabled then
					requireKey("npc " .. npc.id, npc.displayNameKey)
				end
			end
		end
		if deps.Zones then
			for _, zone in deps.Zones.all() do
				requireKey("zone " .. zone.id, zone.displayNameKey)
			end
		end
		if deps.Quests then
			for _, quest in deps.Quests.all() do
				requireKey("quest " .. quest.id, quest.trackerKey)
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

function CatalogService.zoneAtPosition(position: any): string?
	local deps = CatalogService.deps
	if not deps or not deps.Zones or not deps.Zones.zoneAtPosition then
		return nil
	end
	CatalogService.validate()
	return deps.Zones.zoneAtPosition(position)
end

function CatalogService.shardAnchors(): { string }
	local deps = CatalogService.deps
	if not deps or not deps.Zones or not deps.Zones.shardAnchors then
		return {}
	end
	CatalogService.validate()
	return deps.Zones.shardAnchors()
end

function CatalogService.getQuest(questId: string): any?
	local deps = CatalogService.deps
	if not deps or not deps.Quests then
		return nil
	end
	CatalogService.validate()
	return deps.Quests.get(questId)
end

function CatalogService.questChain(): { string }
	local deps = CatalogService.deps
	if not deps or not deps.Quests then
		return {}
	end
	CatalogService.validate()
	return deps.Quests.chain()
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

--!strict
-- Testes unitários F0 — CooldownService, CombatService, ResourceService,
-- AbilityService, CatalogService, PlayerSessionService + dados.
-- Uso: lune run tests/run.luau
-- Contrato da fatia: docs/13-F0-SLICE.md §19.

require("./harness")
local fs = require("@lune/fs")

-- ── Miniaframework de teste ─────────────────────────────────────────────────
local tests = {}
local passed = 0
local failed = 0

local function test(name: string, fn: () -> ())
	table.insert(tests, { name = name, fn = fn })
end

local function assertEq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(("%s — esperado %s, obtido %s"):format(msg or "assertEq", tostring(expected), tostring(actual)))
	end
end

local function assertTrue(cond: boolean, msg: string?)
	if not cond then
		error(msg or "assertTrue falhou")
	end
end

local function assertFalse(cond: boolean, msg: string?)
	if cond then
		error(msg or "assertFalse falhou")
	end
end

-- ── Carga dos módulos reais ─────────────────────────────────────────────────
local Abilities = require("../src/shared/Data/Abilities")
local Characters = require("../src/shared/Data/Characters")
local EnergyFamilies = require("../src/shared/Data/EnergyFamilies")
local Npcs = require("../src/shared/Data/Npcs")
local WorldPresentation = require("../src/shared/Data/WorldPresentation")
local SpawnDecorations = require("../src/shared/Data/SpawnDecorations")
local WildDecorations = require("../src/shared/Data/WildDecorations")
local BiomeDecorations = require("../src/shared/Data/BiomeDecorations")
local WorldTextures = require("../src/shared/Data/WorldTextures")
local AbilityVfx = require("../src/shared/Data/AbilityVfx")
local EnemyVfxAssets = require("../src/shared/Data/EnemyVfxAssets")
local ProgressionCatalog = require("../src/shared/Data/ProgressionCatalog")
local Items = require("../src/shared/Data/Items")
local UiPalette = require("../src/shared/Data/UiPalette")
local InventoryService = require("../src/server/Services/InventoryService")
local CareerService = require("../src/server/Services/CareerService")
local LevelUpPlayer = require("../src/client/Presentation/LevelUpPlayer")
local StudioEvidence = require("../scripts/StudioEvidence")
local Remotes = require("../src/shared/Remotes")
local RemoteEnvelope = require("../src/shared/RemoteEnvelope")
local Zones = require("../src/shared/Data/Zones")
local CooldownService = require("../src/server/Services/CooldownService")
local CombatService = require("../src/server/Services/CombatService")
local ResourceService = require("../src/server/Services/ResourceService")
local AbilityService = require("../src/server/Services/AbilityService")
local CatalogService = require("../src/server/Services/CatalogService")
local PlayerSessionService = require("../src/server/Services/PlayerSessionService")
local ZoneService = require("../src/server/Services/ZoneService")
local ProgressionService = require("../src/server/Services/ProgressionService")
local QuestService = require("../src/server/Services/QuestService")
local Quests = require("../src/shared/Data/Quests")
local Locale = require("../src/shared/Data/Locale")
local Locomotion = require("../src/shared/Data/Locomotion")
local Geometry = require("../src/shared/Geometry")
local HitContact = require("../src/shared/HitContact")
local SpatialService = require("../src/server/Services/SpatialService")
local PlayerMotionGuard = require("../src/server/Services/PlayerMotionGuard")
local EnemyService = require("../src/server/Services/EnemyService")
local ClientState = require("../src/client/Controllers/ClientState")
local InputController = require("../src/client/Controllers/InputController")
local CharacterController = require("../src/client/Controllers/CharacterController")
local InteractionController = require("../src/client/Controllers/InteractionController")
local ActorAnimator = require("../src/client/Presentation/ActorAnimator")
local PlayerCombatAnimator = require("../src/client/Presentation/PlayerCombatAnimator")
local AbilityController = require("../src/client/Controllers/AbilityController")
local CombatFeedbackController = require("../src/client/Controllers/CombatFeedbackController")
local CombatHudController = require("../src/client/Controllers/CombatHudController")
local ResourceController = require("../src/client/Controllers/ResourceController")
local ZoneController = require("../src/client/Controllers/ZoneController")
local SecurityService = require("../src/server/Services/SecurityService")
local TelemetryService = require("../src/server/Services/TelemetryService")
local StudioDebug = require("../src/server/Services/StudioDebug")
local InteractionService = require("../src/server/Services/InteractionService")
local Interactions = require("../src/shared/Data/Interactions")

test("bootstrap: serviços são filhos do Script Server gerado pelo Rojo", function()
	local source = fs.readFile("src/server/init.server.lua")
	assertTrue(source:find('local Services = script:WaitForChild("Services")', 1, true) ~= nil, "raiz de Services")
	assertTrue(source:find("script.Parent.Services", 1, true) == nil, "não procura Services em ServerScriptService")
	assertTrue(source:find("CombatService.basicCombatEvent", 1, true) ~= nil, "golpe básico emite dano")
	assertTrue(source:find("StudioDebug.applySessionUnlocks", 1, true) ~= nil, "StudioDebug no join")
	assertTrue(source:find('script:GetAttribute("F0Debug")', 1, true) ~= nil, "F0Debug no Script")
end)

test("greybox: WorldService gera piso para cada volume canônico de zona", function()
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(source:find("for _, zone in zones.all() do", 1, true) ~= nil, "itera todas as zonas")
	assertTrue(source:find("for index, box in zone.volumes do", 1, true) ~= nil, "itera todos os volumes")
	assertTrue(source:find("box.max.x - box.min.x", 1, true) ~= nil, "largura vem do volume")
	assertTrue(source:find("box.max.z - box.min.z", 1, true) ~= nil, "profundidade vem do volume")
	assertTrue(source:find('floor:SetAttribute("ZoneId", zone.id)', 1, true) ~= nil, "piso rastreável")
	assertTrue(source:find("buildSpawnDecorations(root", 1, true) ~= nil, "decoração do spawn entra no bootstrap")
end)

-- Âncoras críticas LIDAS DO CATÁLOGO. Até 17/08 esta lista era copiada à mão
-- aqui dentro: mover a âncora no `Zones` não mexia no teste, e a validação que
-- se dizia "com os dados reais do Zones" conferia números fósseis.
local CRITICAL_ANCHOR_IDS: { string } = {
	"anchor_bastion_spawn",
	"anchor_bastion_return",
	"anchor_instructor",
	"anchor_training",
	"anchor_gate_north",
	"anchor_gate_west",
}

local function criticalAnchors(): { { x: number, y: number, z: number } }
	local anchors = {}
	for _, anchorId in CRITICAL_ANCHOR_IDS do
		local anchor = Zones.getAnchor(anchorId)
		if anchor then
			table.insert(anchors, anchor.position)
		end
	end
	return anchors
end

test("greybox: decoração do spawn valida com os dados reais do Zones", function()
	local bastion = Zones.get("zone_bastion_safe")
	local transition = Zones.get("zone_threshold_transition")
	assertTrue(bastion ~= nil and transition ~= nil, "zonas existem")
	if not bastion or not transition then
		return
	end
	local anchors = criticalAnchors()
	assertEq(#anchors, #CRITICAL_ANCHOR_IDS, "toda âncora crítica existe no catálogo")
	local errors = SpawnDecorations.validate(SpawnDecorations.all(), bastion.volumes[1], transition.volumes, anchors)
	assertEq(#errors, 0, table.concat(errors, "; "))
end)

-- 17/08: o pilar-marco (20, −16) ocupava z −18..−14 e a Instrutora estava
-- plantada em z −14 — ela nascia com capa e cabelo dentro da pedra. A regra de
-- folga existia desde sempre, mas os pilares moravam numa tabela solta dentro
-- do `buildWalls` e nunca passavam por ela. Agora são dado e passam.
test("greybox: pilar-marco não engole nenhuma âncora", function()
	local pillars = SpawnDecorations.bastionPillars()
	assertEq(#pillars, 4, "os quatro pilares do bastião")
	local errors = SpawnDecorations.anchorClearanceErrors(pillars, criticalAnchors())
	assertEq(#errors, 0, table.concat(errors, "; "))
end)

test("greybox: a regra de folga da âncora realmente reprova o pilar antigo", function()
	-- Sem esta contraprova, um erro na aritmética da folga deixaria o teste
	-- acima passar por acidente e o bug voltaria calado.
	local fossil = {
		{
			name = "Pillar2_fossil",
			size = { x = 4, y = 20, z = 4 },
			position = { x = 20, y = 10, z = -16 },
		},
	}
	local errors = SpawnDecorations.anchorClearanceErrors(fossil, { { x = 20, y = 0, z = -14 } })
	assertEq(#errors, 1, "a posição antiga tem de ser reprovada")
end)

test("greybox: decoração do spawn deixa os portões livres e fica no volume", function()
	local bastion = Zones.get("zone_bastion_safe")
	local transition = Zones.get("zone_threshold_transition")
	assertTrue(bastion ~= nil and transition ~= nil, "zonas existem")
	if not bastion or not transition then
		return
	end
	-- Cada peça, individualmente, não invade os volumes de transição.
	for _, d in SpawnDecorations.all() do
		for _, box in transition.volumes do
			local minX = d.position.x - d.size.x / 2
			local maxX = d.position.x + d.size.x / 2
			local minZ = d.position.z - d.size.z / 2
			local maxZ = d.position.z + d.size.z / 2
			local invades = minX < box.max.x and maxX > box.min.x and minZ < box.max.z and maxZ > box.min.z
			assertFalse(invades, ("%s invade o portão"):format(d.name))
		end
		if not d.canCollide then
			local box = bastion.volumes[1]
			local minX = d.position.x - d.size.x / 2
			local maxX = d.position.x + d.size.x / 2
			local minZ = d.position.z - d.size.z / 2
			local maxZ = d.position.z + d.size.z / 2
			assertTrue(
				minX >= box.min.x and maxX <= box.max.x and minZ >= box.min.z and maxZ <= box.max.z,
				("%s fora do bastião"):format(d.name)
			)
		end
	end
end)

test("greybox: decoração do spawn não bloqueia o treino nem o spawn", function()
	local bastion = Zones.get("zone_bastion_safe")
	local transition = Zones.get("zone_threshold_transition")
	assertTrue(bastion ~= nil and transition ~= nil, "zonas existem")
	if not bastion or not transition then
		return
	end
	local errors =
		SpawnDecorations.validate(SpawnDecorations.all(), bastion.volumes[1], transition.volumes, criticalAnchors())
	assertEq(#errors, 0, "nenhum erro com as âncoras críticas")
end)

-- Dados reais do catálogo: a validação da planície precisa ver os mesmos
-- volumes, âncoras e cratera que o `zoneAtPosition` do servidor usa.
local function wildFixture()
	local free = Zones.get("zone_plain_free")
	local transition = Zones.get("zone_threshold_transition")
	local greybox = Zones.greybox()
	local elite = Zones.getAnchor("anchor_elite")
	local anchors = {}
	for _, anchorId in Zones.shardAnchors() do
		local anchor = Zones.getAnchor(anchorId)
		if anchor then
			table.insert(anchors, anchor.position)
		end
	end
	return free,
		transition,
		anchors,
		{
			x = if elite then elite.position.x else 0,
			z = if elite then elite.position.z else 0,
			radius = greybox.eliteCraterRadius,
		}
end

test("planície: decoração externa valida contra zonas, cratera e âncoras reais", function()
	local free, transition, anchors, crater = wildFixture()
	assertTrue(free ~= nil and transition ~= nil, "zonas existem")
	if not free or not transition then
		return
	end
	assertEq(#anchors, 6, "seis âncoras de Estilhaço")
	local errors = WildDecorations.validate(WildDecorations.all(), free.volumes, transition.volumes, anchors, crater)
	assertEq(#errors, 0, table.concat(errors, "; "))
	assertTrue(#WildDecorations.all() >= 60, "planície decorada de verdade")
	assertTrue(WildDecorations.pieceCount() >= 400, "vegetação densa o bastante para ler como campo")
	assertTrue(WildDecorations.pieceCount() <= 2800, "vegetação cabe no teto de 6000 parts")
	local ridges = 0
	for _, decoration in WildDecorations.all() do
		if
			string.find(decoration.name, "Ridge", 1, true)
			or string.find(decoration.name, "Hill_", 1, true)
			or string.find(decoration.name, "Mound_", 1, true)
		then
			ridges += 1
		end
	end
	assertTrue(ridges >= 80, "serras e relevo na planície")
end)

test("bioma: células têm chão, nomes e decoração sem colisão", function()
	assertTrue(Zones.get("zone_lumen_safe") ~= nil, "Lumen")
	assertTrue(Zones.get("zone_echo_woods") ~= nil, "Bosque")
	assertTrue(Zones.get("zone_iron_port") ~= nil, "Porto")
	assertTrue(Zones.get("zone_grey_sector") ~= nil, "Cinza")
	assertTrue(Zones.get("zone_academy_safe") ~= nil, "Academia")
	assertTrue(Zones.get("zone_veil_safe") ~= nil, "Vila Sombria")
	assertEq(Locale.get("zone.lumen.name"), "Distrito Lumen", "nome Lumen")
	assertEq(Locale.get("zone.woods.name", "en"), "Echo Woods", "nome bosque EN")
	assertEq(Locale.get("zone.veil.name"), "Vila Sombria", "nome vila")
	assertEq(Locale.get("zone.veil.name", "en"), "Veil Hamlet", "nome vila EN")
	local volumes = {}
	local hasVeil = false
	for _, zoneId in Zones.biomeZoneIds() do
		if zoneId == "zone_veil_safe" then
			hasVeil = true
		end
		local zone = Zones.get(zoneId)
		assertTrue(zone ~= nil, zoneId)
		if zone then
			for _, volume in zone.volumes do
				table.insert(volumes, volume)
			end
		end
	end
	assertTrue(hasVeil, "bootstrap inclui a Vila Sombria — senão o Play aborta e o spawn cai no void")
	local _, _, anchors, crater = wildFixture()
	local withoutVeil = {}
	for _, zoneId in Zones.biomeZoneIds() do
		if zoneId ~= "zone_veil_safe" then
			local zone = Zones.get(zoneId)
			if zone then
				for _, volume in zone.volumes do
					table.insert(withoutVeil, volume)
				end
			end
		end
	end
	local voidErrors = BiomeDecorations.validate(BiomeDecorations.all(), withoutVeil, anchors, crater)
	assertTrue(#voidErrors > 0, "esquecer a vila na validação do boot derruba o servidor")
	local errors = BiomeDecorations.validate(BiomeDecorations.all(), volumes, anchors, crater)
	assertEq(#errors, 0, table.concat(errors, "; "))
	assertTrue(#BiomeDecorations.all() >= 40, "biomas com marcos visíveis")
	assertTrue(BiomeDecorations.lightCount() <= 16, "teto de luz de bioma")
	local biomeRidges = 0
	for _, item in BiomeDecorations.all() do
		if string.find(item.name, "Ridge", 1, true) then
			biomeRidges += 1
		end
	end
	assertTrue(biomeRidges >= 16, "cada célula tem serra de identidade")
	for _, item in BiomeDecorations.all() do
		assertFalse(item.canCollide, item.name .. " não pode colidir")
	end
	local veil = 0
	for _, item in BiomeDecorations.all() do
		if string.sub(item.name, 1, 4) == "Veil" then
			veil += 1
			assertTrue(item.position.x >= -400 and item.position.x <= -82, item.name .. " X fora da vila")
			assertTrue(item.position.z >= 82 and item.position.z <= 270, item.name .. " Z fora da vila")
		end
	end
	assertTrue(veil >= 40, "Vila Sombria tem leitura de aldeia")
end)

test("mundo: overlays de piso usam só atlas publicados", function()
	local ok, reason = WorldTextures.validate()
	assertTrue(ok, reason or "catálogo de superfícies válido")
	assertEq(Zones.get("zone_echo_woods").floorMaterial, "LeafyGrass", "Bosque com grama frondosa")
	assertEq(Zones.get("zone_bastion_safe").floorMaterial, "Slate", "Bastião com ardósia")
	assertEq(Zones.get("zone_plain_free").floorMaterial, "Ground", "planície com terra")
	local training = WorldTextures.named("TrainingPad")
	assertTrue(training ~= nil, "pad de treino tem pele")
	if training then
		assertEq(training.baseAssetId, WorldTextures.SlateFloor, "pad usa ColorMap de ardósia")
		assertEq(training.overlayAssetId, WorldTextures.PowerRing, "pad usa anel publicado")
		assertTrue(training.overlayTransparency < 1, "anel visível")
	end
	local lumen = WorldTextures.forZone("zone_lumen_safe")
	assertTrue(lumen ~= nil, "Lumen tem pele")
	if lumen then
		assertEq(lumen.overlayAssetId, WorldTextures.Lightning, "rua Lumen usa raio publicado")
	end
	local crater = WorldTextures.named("EliteCraterBasin")
	assertTrue(crater ~= nil, "cratera tem pele")
	if crater then
		assertEq(crater.overlayAssetId, WorldTextures.Scorch, "bacia usa queimadura publicada")
	end
	local wall = WorldTextures.named("BastionWall")
	assertTrue(wall ~= nil, "muro tem pele")
	if wall then
		assertEq(wall.baseAssetId, WorldTextures.RunedWall, "muro usa ColorMap de runas")
		assertEq(#WorldTextures.facesOf(wall), 2, "muro texturiza duas faces")
	end
	assertEq(#WorldTextures.colorMapIds(), 3, "três ColorMaps publicadas")
	local registro = fs.readFile("assets/published-world-assets.json")
	for _, assetId in WorldTextures.colorMapIds() do
		local digits = string.match(assetId, "%d+")
		assertTrue(digits ~= nil and string.find(registro, digits, 1, true) ~= nil, "ColorMap no registro: " .. assetId)
	end
	for _, skin in WorldTextures.all() do
		if skin.overlayAssetId then
			local resolved: string? = nil
			if skin.overlayAssetId == WorldTextures.Scorch then
				local enemy = EnemyVfxAssets.get("kenney_scorch")
				if enemy then
					resolved = enemy.assetId
				end
			else
				local key = if skin.overlayAssetId == WorldTextures.EnergyBall
					then "energy_ball"
					else (if skin.overlayAssetId == WorldTextures.PowerRing
						then "power_ring"
						else "lightning_shock")
				local spec = AbilityVfx.assetFor(key)
				resolved = AbilityVfx.resolveTexture(spec)
			end
			assertTrue(resolved ~= nil, "overlay resolve no catálogo: " .. skin.id)
			assertEq(resolved, skin.overlayAssetId, "ID bate com o publicado")
		end
	end
end)

test("lumen: célula urbana densa — rua, vielas, praça, marco e dois serviços", function()
	local byName = {}
	local lumen = 0
	local lumenLights = 0
	local shadowed = 0
	for _, item in BiomeDecorations.all() do
		if string.sub(item.name, 1, 5) == "Lumen" then
			lumen += 1
			byName[item.name] = item
			assertTrue(item.position.x >= -160 and item.position.x <= 160, item.name .. " X fora da zona")
			assertTrue(item.position.z >= -700 and item.position.z <= -460, item.name .. " Z fora da zona")
			assertFalse(item.canCollide, item.name .. " colide")
			if item.light then
				lumenLights += 1
				assertTrue(item.light.rangeStuds > 0, item.name .. " luz sem alcance")
				if item.light.shadows then
					shadowed += 1
				end
			end
		end
	end
	assertTrue(lumen >= 280, "célula densa o bastante")
	assertTrue(byName.LumenPlaza ~= nil, "praça")
	assertTrue(byName.LumenTower ~= nil, "marco")
	assertTrue(byName.LumenCrown ~= nil, "coroa")
	assertTrue(byName.LumenPlazaCrystal ~= nil, "ponto de encontro")
	assertTrue(byName.LumenVendor_Sign ~= nil, "serviço mercado")
	assertTrue(byName.LumenForge_Sign ~= nil, "serviço forja")
	assertTrue(byName.LumenAlleyW_Jog ~= nil, "viela oeste")
	assertTrue(byName.LumenAlleyE_Jog ~= nil, "viela leste")
	assertTrue(byName.LumenGatePostW ~= nil and byName.LumenGatePostE ~= nil, "borda sul")
	assertTrue(lumenLights <= 3, "luzes reais só nos pontos-chave")
	assertEq(shadowed, 0, "nenhuma sombra extra no Lumen")
	assertTrue(byName.LumenCrown.light ~= nil, "coroa ilumina")
	if byName.LumenCrown.light then
		assertTrue(byName.LumenCrown.light.rangeStuds <= 28, "coroa não declara mais alcance que o concedido")
	end
	if byName.LumenPlazaCrystal.light then
		assertTrue(
			byName.LumenPlazaCrystal.light.rangeStuds <= 16,
			"cristal da praça não declara mais alcance que o concedido"
		)
	end
	for _, item in BiomeDecorations.all() do
		if string.find(item.name, "LumenBld", 1, true) or string.find(item.name, "LumenSky", 1, true) then
			assertTrue(math.abs(item.position.x) >= 16, item.name .. " invade a rua principal")
		end
	end
	assertTrue(byName.LumenGatePostW.position.x <= -24, "vão sul oeste livre")
	assertTrue(byName.LumenGatePostE.position.x >= 24, "vão sul leste livre")
	assertTrue(byName.LumenAlleyW_Jog.position.x < -80, "jog oeste quebra a visão")
	assertTrue(byName.LumenAlleyE_Jog.position.x > 80, "jog leste quebra a visão")
end)

test("planície: nada colide, nada entra no ringue do elite e a luz tem teto", function()
	local _, _, _, crater = wildFixture()
	for _, decoration in WildDecorations.all() do
		assertTrue(decoration.transparency < 1, ("%s invisível"):format(decoration.name))
		local dx = decoration.position.x - crater.x
		local dz = decoration.position.z - crater.z
		assertTrue(math.sqrt(dx * dx + dz * dz) >= crater.radius, ("%s dentro da cratera"):format(decoration.name))
	end
	-- Colisão é decisão do WorldService e é uma só: nenhuma peça da planície
	-- pode virar parede invisível em cima de perseguição, dash ou Cometa.
	-- Normaliza fim de linha antes de casar: o repo é CRLF no Windows e o regex
	-- procura "\nend\n". Sem isto o teste passava no CI Linux e falhava na
	-- máquina de quem desenvolve — falso negativo que ficou dias sendo tratado
	-- como defeito de mundo, quando a materialização sempre existiu.
	local source = string.gsub(fs.readFile("src/server/Services/WorldService.luau"), "\r\n", "\n")
	local build = source:match("local function buildWildDecorations.-\nend\n")
	assertTrue(build ~= nil, "materialização existe")
	if build then
		assertTrue(build:find("part.CanCollide = false", 1, true) ~= nil, "decoração da planície não colide")
		assertTrue(build:find("part.CanQuery = false", 1, true) ~= nil, "não entra em raycast de combate")
	end
	assertTrue(WildDecorations.lightCount() <= 8, "orçamento de luz da planície")
	assertTrue(WildDecorations.lightCount() >= 4, "a rota precisa ser legível à noite")
end)

test("planície: validação recusa peça fora da zona, no ringue e na âncora", function()
	local free, transition, anchors, crater = wildFixture()
	if not free or not transition then
		return
	end
	local function bad(position: { x: number, y: number, z: number })
		return {
			{
				name = "Ruim",
				class = "Part",
				shape = "Block",
				size = { x = 1, y = 2, z = 1 },
				position = position,
				yawDegrees = 0,
				rgb = { 80, 80, 80 },
				material = "Slate",
				transparency = 0,
				light = nil,
			},
		}
	end
	-- Dentro do Bastião (zona segura), não da planície.
	assertTrue(
		#WildDecorations.validate(bad({ x = 0, y = 1, z = 10 }), free.volumes, transition.volumes, anchors, crater) > 0,
		"fora da zona livre é recusado"
	)
	-- Centro da cratera: onde o elite luta.
	assertTrue(
		#WildDecorations.validate(
				bad({ x = 0, y = 1, z = -102 }),
				free.volumes,
				transition.volumes,
				anchors,
				crater
			) > 0,
		"ringue do elite é recusado"
	)
	-- Em cima da âncora do primeiro Estilhaço.
	assertTrue(
		#WildDecorations.validate(
				bad({ x = -50, y = 1, z = -60 }),
				free.volumes,
				transition.volumes,
				anchors,
				crater
			) > 0,
		"âncora de spawn é recusada"
	)
	-- No meio da faixa de caminhada da rota.
	assertTrue(
		#WildDecorations.validate(bad({ x = 0, y = 1, z = -70 }), free.volumes, transition.volumes, anchors, crater) > 0,
		"rota da cratera é recusada"
	)
end)

test("planície: decoração externa entra no bootstrap do mundo", function()
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(source:find("buildWildDecorations(root", 1, true) ~= nil, "chamada no init")
	local bootstrap = fs.readFile("src/server/init.server.lua")
	assertTrue(bootstrap:find("wildDecorations = WildDecorations", 1, true) ~= nil, "dependência declarada")
end)

test("runbook: o roteiro do Studio é catálogo válido e começa pela sincronia", function()
	local ok, reason = StudioEvidence.validate()
	assertTrue(ok, reason)

	local steps = StudioEvidence.steps()
	assertTrue(#steps >= 8, "roteiro cobre o dia inteiro")
	assertEq(steps[1].id, "w1_sync", "sincronia é o primeiro passo")
	assertTrue(#StudioEvidence.stepsForGate("W1") >= 5, "W1 tem os passos de leitura do mundo")
	assertTrue(#StudioEvidence.stepsForGate("A1") >= 2, "A1 tem impacto e cadeia")
	assertTrue(#StudioEvidence.stepsForGate("W2") >= 1, "W2 tem desempenho")
	assertEq(#StudioEvidence.stepsForGate("F9"), 0, "gate inexistente não devolve passo")

	-- `steps()` devolve tabela nova: o CLI serializa e não pode mutar o catálogo.
	assertTrue(StudioEvidence.steps() ~= StudioEvidence.steps(), "cópia por chamada")
	for _, step in steps do
		assertTrue(#step.capture > 0, step.id .. " declara o que capturar")
		assertTrue(step.pass ~= "", step.id .. " declara critério de aprovação")
	end
end)

test("runbook: fora de sync o porteiro barra a sessão antes de qualquer medição", function()
	-- O defeito de 14/08: três commits invisíveis porque o Play rodava outro
	-- place. Aqui isso é regra executável, não recomendação em doc.
	local semResposta = select(1, StudioEvidence.syncGate(nil))
	assertFalse(semResposta, "sem resposta do sync não libera")

	local falhou = select(1, StudioEvidence.syncGate({ ok = false, error = "bridge fora do ar" }))
	assertFalse(falhou, "sync com erro não libera")

	local foraOk, foraReason = StudioEvidence.syncGate({
		ok = true,
		inSync = false,
		mismatched = { {}, {} },
		missingInStudio = { {} },
	})
	assertFalse(foraOk, "fora de sync não libera")
	assertTrue(string.find(foraReason, "2 divergente", 1, true) ~= nil, "motivo conta os divergentes")
	assertTrue(string.find(foraReason, "1 ausente", 1, true) ~= nil, "motivo conta os ausentes")

	local dentro, dentroReason = StudioEvidence.syncGate({ ok = true, inSync = true, matched = 56 })
	assertTrue(dentro, "em sync libera")
	assertEq(dentroReason, "em sync", "motivo estável")
end)

test("runbook: orçamento de desempenho aceita o que cabe e nomeia o que estoura", function()
	local dentro, semQuebra = StudioEvidence.evaluatePerf({
		heartbeatTimeMs = 9.4,
		physicsStepTimeMs = 2.1,
		totalMemoryMb = 780,
		workspaceParts = 3200,
	})
	assertTrue(dentro, "amostra saudável passa")
	assertEq(#semQuebra, 0, "sem violação")

	local fora, quebras = StudioEvidence.evaluatePerf({
		heartbeatTimeMs = 41.7,
		physicsStepTimeMs = 2.1,
		totalMemoryMb = 2100,
		workspaceParts = 3200,
	})
	assertFalse(fora, "amostra pesada reprova")
	assertEq(#quebras, 2, "duas violações nomeadas")
	assertTrue(string.find(quebras[1], "Heartbeat", 1, true) ~= nil, "a violação diz qual campo")

	-- Campo ausente é ignorado de propósito: `Stats` nem sempre publica tudo, e
	-- inventar zero viraria aprovação falsa.
	local parcial = select(1, StudioEvidence.evaluatePerf({ workspaceParts = 10 }))
	assertTrue(parcial, "amostra parcial não inventa reprovação")
	local ausente, motivo = StudioEvidence.evaluatePerf(nil)
	assertFalse(ausente, "sem amostra não aprova")
	assertEq(#motivo, 1, "diz que faltou amostra")
end)

test("runbook: o CLI expõe roteiro e folha de evidência, e o roteiro roda sem bridge", function()
	local source = fs.readFile("scripts/avb-debug.luau")
	assertTrue(source:find('elseif command == "runbook" then', 1, true) ~= nil, "comando runbook no dispatch")
	assertTrue(source:find('elseif command == "home" then', 1, true) ~= nil, "comando home no dispatch")
	assertTrue(source:find('elseif command == "evidence" then', 1, true) ~= nil, "comando evidence no dispatch")
	assertTrue(source:find("StudioEvidence.syncGate(sync)", 1, true) ~= nil, "a folha passa pelo porteiro")
	-- Exit 2 fora de sync: é o contrato que o runbook promete.
	assertTrue(source:find("process.exit(2)", 1, true) ~= nil, "fora de sync sai com 2")
	-- Token do bridge sob demanda: o runbook precisa funcionar com o Studio
	-- fechado, que é quando se prepara a sessão.
	assertTrue(source:find("local function requireBridgeToken", 1, true) ~= nil, "token é exigido sob demanda")
	assertTrue(source:find("local bridgeToken = readBridgeToken()", 1, true) == nil, "sem exigência no carregamento")
end)

test("runbook: o atalho de casa tem três passos e não entra no Play", function()
	local ok, reason = StudioEvidence.validate()
	assertTrue(ok, reason)

	local home = StudioEvidence.homePrep()
	assertEq(#home, 3, "build, sync, impacto")
	assertEq(home[1].id, "home_build", "primeiro gera o place")
	assertTrue(string.find(home[1].command, "build-studio.ps1", 1, true) ~= nil, "comando do snapshot")
	assertEq(home[1].play, false, "build não é Play")
	assertEq(home[2].id, "home_sync", "depois a sincronia")
	assertTrue(string.find(home[2].command, "avb-debug.luau sync", 1, true) ~= nil, "comando do sync")
	assertEq(home[3].id, "home_impact", "por último o dummy")
	assertEq(home[3].play, true, "o terceiro passo é Play")
	assertEq(home[3].command, "", "Play não tem CLI que substitua")

	-- O atalho não empurra w1_sync para segundo: a lista de Play continua igual.
	assertEq(StudioEvidence.steps()[1].id, "w1_sync", "Play ainda começa pela sincronia")
	assertTrue(StudioEvidence.homePrep() ~= StudioEvidence.homePrep(), "cópia por chamada")
end)

test("ci: o script local reproduz a ordem do workflow", function()
	local sh = fs.readFile("scripts/ci.sh")
	local yml = fs.readFile(".github/workflows/ci.yml")
	local passos = {
		"stylua --check src tests plugins scripts",
		"selene src tests plugins scripts",
		"lune run tests/run.luau",
		"lune run tests/animation.luau",
		"lune run tests/security_fuzz.luau",
		"lune run tests/combat_e2e.luau",
		"wally install",
		"rojo build -o /tmp/build.rbxl",
	}
	for _, passo in passos do
		assertTrue(string.find(sh, passo, 1, true) ~= nil, "ci.sh tem " .. passo)
		assertTrue(string.find(yml, passo, 1, true) ~= nil, "workflow tem " .. passo)
	end
end)

test("apresentação: seis atores e estilo do mundo passam validação", function()
	local ok, reason = WorldPresentation.validate()
	assertTrue(ok, reason)
	assertEq(#WorldPresentation.allActors(), 6, "seis receitas")
	assertEq(WorldPresentation.getActor("enemy_wandering_shard").shape, "shard", "inimigo low-poly")
	assertEq(WorldPresentation.getActor("enemy_grove_wisp").shape, "shard", "Fogo-fátuo low-poly")
	assertEq(WorldPresentation.getActor("enemy_port_scrapper").shape, "shard", "Sucateiro low-poly")
	assertTrue(WorldPresentation.style().craterSegments >= 12, "cratera legível")
end)

test("skin: os dois bots do spawn têm receita de rig R15 válida", function()
	local ok, reason = WorldPresentation.validateRigs()
	assertTrue(ok, reason)
	assertEq(#WorldPresentation.allRigs(), 2, "instrutor e boneco de treino")

	local instructor = WorldPresentation.rigFor("npc_threshold_instructor")
	local dummy = WorldPresentation.rigFor("npc_training_dummy")
	assertTrue(instructor ~= nil, "receita do instrutor")
	assertTrue(dummy ~= nil, "receita do boneco")
	if not instructor or not dummy then
		return
	end
	-- Rosto do instrutor é textura embutida do cliente: não depende de download
	-- nem pode ser moderada. O boneco não tem decal — usa botão costurado.
	assertEq(instructor.faceTexture, "rbxasset://textures/face.png", "rosto embutido")
	assertEq(dummy.faceTexture, nil, "saco de estopa não usa rosto de avatar")
	assertEq(WorldPresentation.rigFor("enemy_wandering_shard"), nil, "estilhaço não é humanoide")

	-- Toda peça precisa pousar numa parte que existe no rig R15: um host com
	-- erro de digitação viraria roupa solta no chão em vez de vestir o boneco.
	for _, rig in WorldPresentation.allRigs() do
		assertTrue(#rig.gear >= 8, rig.npcId .. " sem gear suficiente para ler como personagem")
		for _, piece in rig.gear do
			assertTrue(
				WorldPresentation.rigHostExists(piece.host),
				("%s: peça %s pendurada em host inexistente (%s)"):format(rig.npcId, piece.name, piece.host)
			)
		end
	end
end)

test("skin: nenhum bot volta a ser feito de caixas", function()
	-- A reclamação depois da primeira versão foi "ainda tá muito quadrado", e
	-- ela tinha duas causas: gear 100% `Block` e o corpo na proporção cúbica
	-- clássica. Este teste é o que impede as duas de voltarem.
	for _, rig in WorldPresentation.allRigs() do
		local blocks, blobs, bands = 0, 0, 0
		for _, piece in rig.gear do
			if piece.shape == "Ball" then
				blobs += 1
			elseif piece.shape == "Cylinder" then
				bands += 1
			elseif piece.class == "Part" then
				blocks += 1
			end
		end
		assertTrue(
			blocks <= #rig.gear * 0.25,
			("%s: %d de %d peças são bloco — volume grande tem de ser elipsoide"):format(
				rig.npcId,
				blocks,
				#rig.gear
			)
		)
		assertTrue(blobs >= 6, rig.npcId .. " sem volumes redondos suficientes")
		assertTrue(bands >= 4, rig.npcId .. " sem anéis (gola/cinto/punho) suficientes")

		-- `bodyType = 0` é o boneco cúbico do R15 clássico.
		assertTrue(rig.scales.bodyType >= 0.5, rig.npcId .. " com corpo na proporção cúbica")
		assertTrue(WorldPresentation.validateScales(rig.scales), rig.npcId .. " com escalas fora da faixa")
	end

	local ruim = { bodyType = 0, proportion = 0.5, head = 1.14, width = 0.92, height = 0.95 }
	assertTrue(not WorldPresentation.validateScales(ruim), "corpo cúbico clássico é recusado")
	local absurdo = { bodyType = 1, proportion = 0.5, head = 9, width = 0.92, height = 0.95 }
	assertTrue(not WorldPresentation.validateScales(absurdo), "escala fora da faixa é recusada")
end)

test("skin: gear inválido é recusado antes de virar Instance", function()
	local function piece(overrides: { [string]: any }): any
		local base = {
			name = "Teste",
			class = "Part",
			shape = "Block",
			host = "UpperTorso",
			sizeStuds = { 1, 1, 1 },
			offsetStuds = { 0, 0, 0 },
			rotationDegrees = { 0, 0, 0 },
			rgb = { 10, 20, 30 },
			material = "Fabric",
		}
		for key, value in overrides do
			base[key] = value
		end
		return base
	end

	assertTrue(WorldPresentation.validateGear(piece({})), "peça bem formada passa")
	assertTrue(not WorldPresentation.validateGear(piece({ host = "Tronco" })), "host inexistente falha")
	assertTrue(not WorldPresentation.validateGear(piece({ material = "Plutonio" })), "material fora da lista falha")
	-- Peça a 9 studs do host não é roupa: é peça solta boiando ao lado.
	assertTrue(not WorldPresentation.validateGear(piece({ offsetStuds = { 0, 9, 0 } })), "offset distante falha")
	assertTrue(
		not WorldPresentation.validateGear(piece({ sizeStuds = { 0.01, 1, 1 } })),
		"peça menor que o mínimo falha"
	)
	assertTrue(not WorldPresentation.validateGear(piece({ rgb = { 300, 0, 0 } })), "rgb fora de 0..255 falha")
	-- WedgePart não tem Shape: pedir cilindro numa cunha seria engano silencioso.
	assertTrue(
		not WorldPresentation.validateGear(piece({ class = "WedgePart", shape = "Cylinder" })),
		"cunha com shape de cilindro falha"
	)

	-- Cabelo/capuz que desce na frente do rosto tapa os olhos do instrutor.
	local franjaBaixa = piece({ host = "Head", sizeStuds = { 0.3, 0.4, 0.3 }, offsetStuds = { 0, 0.1, -0.6 } })
	assertTrue(not WorldPresentation.gearClearsFace(franjaBaixa), "franja na frente dos olhos falha")
	local franjaAlta = piece({ host = "Head", sizeStuds = { 0.3, 0.36, 0.26 }, offsetStuds = { 0, 0.52, -0.48 } })
	assertTrue(WorldPresentation.gearClearsFace(franjaAlta), "franja acima da faixa dos olhos passa")
	-- Peça atrás do plano do rosto some dentro da malha e não ocluí nada.
	local nuca = piece({ host = "Head", sizeStuds = { 1.3, 1.05, 0.5 }, offsetStuds = { 0, 0.14, 0.52 } })
	assertTrue(WorldPresentation.gearClearsFace(nuca), "capuz atrás da cabeça passa")
	assertTrue(WorldPresentation.gearClearsFace(piece({})), "peça fora da cabeça não é checada")
end)

test("skin: estilhaços têm receita própria em cima do corpo comum", function()
	local ok, reason = WorldPresentation.validateShardSkins(Npcs)
	assertTrue(ok, reason)

	local wandering = WorldPresentation.shardGearFor("enemy_wandering_shard")
	local anchored = WorldPresentation.shardGearFor("enemy_anchored_shard")
	assertTrue(#wandering >= 12, "estilhaço comum tem corpo completo")
	assertTrue(#anchored > #wandering, "elite tem mais camadas que o comum")
	assertEq(#WorldPresentation.shardGearFor("npc_threshold_instructor"), 0, "humanoide não recebe skin mineral")

	local function has(gear: { any }, name: string): boolean
		for _, piece in gear do
			if piece.name == name then
				return true
			end
		end
		return false
	end
	assertTrue(has(wandering, "Core") and has(wandering, "Halo"), "corpo comum entra nos dois")
	assertTrue(has(wandering, "RiftRing"), "fenda ciano tem o anel de fenda")
	assertFalse(has(wandering, "Crown_1"), "coroa é exclusiva do elite")
	assertTrue(has(anchored, "Crown_5") and has(anchored, "AnchorCollar"), "coroa e colar do elite")
	local wisp = WorldPresentation.shardGearFor("enemy_grove_wisp")
	assertTrue(has(wisp, "WispVeil") and has(wisp, "WispCore"), "Fogo-fátuo tem véu e núcleo")
	assertFalse(has(wisp, "Crown_1"), "Fátuo não herda a coroa")
	local scrapper = WorldPresentation.shardGearFor("enemy_port_scrapper")
	assertTrue(has(scrapper, "ScrapHook") and has(scrapper, "ScrapPlate"), "Sucateiro tem gancho e placa")
end)

test("skin: nenhuma peça de estilhaço passa do alcance real do golpe (docs/17)", function()
	for _, npcId in { "enemy_wandering_shard", "enemy_anchored_shard", "enemy_grove_wisp", "enemy_port_scrapper" } do
		local definition = Npcs.get(npcId)
		assertTrue(definition ~= nil, npcId .. " existe no catálogo")
		if definition then
			local reach = WorldPresentation.shardReachStuds(npcId)
			assertTrue(reach > 0, npcId .. " tem corpo visível")
			assertTrue(
				reach <= definition.attackRange,
				("%s: skin alcança %.2f e o golpe alcança %.2f"):format(npcId, reach, definition.attackRange)
			)
		end
	end

	-- O contrário também precisa falhar: uma skin exagerada é recusada.
	local mentirosa = {
		get = function(npcId: string)
			local real = Npcs.get(npcId)
			if not real then
				return nil
			end
			local copy = table.clone(real)
			copy.attackRange = 0.5
			return copy
		end,
	}
	local ok, reason = WorldPresentation.validateShardSkins(mentirosa)
	assertFalse(ok, "alcance menor que a skin precisa ser recusado")
	assertTrue(reason ~= nil and string.find(reason, "alcança", 1, true) ~= nil, "motivo cita o alcance")
end)

test("skin: peça de estilhaço malformada é recusada", function()
	local base = WorldPresentation.shardGearFor("enemy_wandering_shard")[1]
	local function piece(overrides: { [string]: any })
		local copy = table.clone(base)
		for key, value in overrides do
			copy[key] = value
		end
		return copy
	end
	assertTrue(WorldPresentation.validateShardPiece(piece({})), "peça real passa")
	assertFalse(WorldPresentation.validateShardPiece(piece({ tint = "roxo" })), "tint fora da paleta falha")
	assertFalse(WorldPresentation.validateShardPiece(piece({ material = "Plutonio" })), "material fora da lista falha")
	assertFalse(WorldPresentation.validateShardPiece(piece({ transparency = 1 })), "peça invisível falha")
	assertFalse(WorldPresentation.validateShardPiece(piece({ offsetStuds = { 0, 9, 0 } })), "offset distante falha")
	assertFalse(
		WorldPresentation.validateShardPiece(piece({ class = "WedgePart", shape = "Ball" })),
		"cunha com shape de esfera falha"
	)
end)

test("skin: WorldService materializa o estilhaço a partir dos dados", function()
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(source:find("buildShardBody(visualRoot", 1, true) ~= nil, "corpo mineral vem da receita")
	assertTrue(
		source:find('npcId == "enemy_anchored_shard"', 1, true) == nil,
		"a coroa do elite não pode voltar a ser um if do WorldService"
	)
	assertTrue(
		source:find('descendant:GetAttribute("AvbBaseTransparency")', 1, true) ~= nil,
		"respawn devolve a transparência declarada na skin"
	)
end)

test("apresentação: poses procedurais preservam antecipação, impacto e queda", function()
	local recipe = WorldPresentation.getActor("enemy_wandering_shard")
	assertTrue(recipe ~= nil, "receita")
	if not recipe then
		return
	end
	local telegraph = ActorAnimator.sample(recipe, "telegraph", 0.4, 0, false)
	local attack = ActorAnimator.sample(recipe, "attack", 0.175, 0, false, "strike", 0.35)
	local died = ActorAnimator.sample(recipe, "died", 0.55, 0, false)
	assertEq(telegraph.leanDegrees, -recipe.telegraphLeanDegrees, "antecipação recua")
	assertEq(attack.leanDegrees, recipe.attackLeanDegrees, "ataque compromete")
	assertEq(died.leanDegrees, recipe.deathTiltDegrees, "queda limitada pela receita")
end)

test("apresentação: combo e slam usam timing e peso visual distintos", function()
	local recipe = WorldPresentation.getActor("enemy_anchored_shard")
	assertTrue(recipe ~= nil, "receita do elite")
	if not recipe then
		return
	end
	local comboTelegraph = ActorAnimator.sample(recipe, "telegraph", 0.3, 0, false, "combo", 0.3)
	local slamTelegraph = ActorAnimator.sample(recipe, "telegraph", 0.3, 0, false, "slam", 0.7)
	local comboAttack = ActorAnimator.sample(recipe, "attack", 0.1, 0, false, "combo", 0.4)
	local slamAttack = ActorAnimator.sample(recipe, "attack", 0.1, 0, false, "slam", 0.4)
	assertTrue(
		math.abs(slamTelegraph.leanDegrees) > math.abs(comboTelegraph.leanDegrees),
		"slam antecipa com mais peso"
	)
	assertTrue(math.abs(slamAttack.leanDegrees) > math.abs(comboAttack.leanDegrees), "slam ataca com mais compromisso")
	assertTrue(slamTelegraph.bobStuds < comboTelegraph.bobStuds, "slam comprime a silhueta")
end)

test("studio debug: exige Studio + atributo e nunca inclui ultimate", function()
	assertFalse(StudioDebug.isEnabled(false, true), "fora do Studio")
	assertFalse(StudioDebug.isEnabled(true, false), "atributo ausente")
	assertTrue(StudioDebug.isEnabled(true, true), "gate explícito")
	local flags = StudioDebug.unlockFlags()
	assertEq(#flags, 3, "três técnicas F0")
	for _, flag in flags do
		assertFalse(flag == "unlock_eclipse_beat", "ultimate segue desabilitada")
	end
end)

test("studio debug: unlock de sessão aparece no HUD e não entra no save", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(8801)
	assertTrue(ProgressionService.grantSessionUnlock(8801, "unlock_comet_shoulder"), "override concedido")
	assertTrue(ProgressionService.hasUnlock(8801, "unlock_comet_shoulder"), "visível para habilidade/HUD")
	local listed = ProgressionService.listUnlocks(8801)
	assertEq(listed[1], "unlock_comet_shoulder", "snapshot da sessão")
	local snapshot = ProgressionService.snapshotForSave(8801)
	assertTrue(snapshot ~= nil, "snapshot durável")
	if snapshot then
		assertEq(#snapshot.tutorialFlags, 0, "override fora do tutorial persistido")
		assertEq(#snapshot.unlockedAbilities, 0, "override fora de abilities persistidas")
	end
	ProgressionService.unregisterPlayer(8801)
end)

test("studio debug: resolveAttribute ignora nil e aplica as 3 flags só no Studio", function()
	assertEq(StudioDebug.resolveAttribute(nil, true), true, "cai no Script")
	assertEq(StudioDebug.resolveAttribute(false, true), false, "false explícito vence")
	assertEq(StudioDebug.resolveAttribute(nil, nil), nil, "ausente")
	local granted: { string } = {}
	local count = StudioDebug.applySessionUnlocks(true, true, function(flag: string): boolean
		table.insert(granted, flag)
		return true
	end)
	assertEq(count, 3, "três técnicas")
	assertEq(#granted, 3, "grant chamado 3 vezes")
	assertEq(
		StudioDebug.applySessionUnlocks(false, true, function(): boolean
			return true
		end),
		0,
		"fora do Studio"
	)
	assertEq(
		StudioDebug.applySessionUnlocks(true, nil, function(): boolean
			return true
		end),
		0,
		"sem atributo"
	)
end)

-- ── Relógio injetável (janela de reentrada / cap de Fluxo) ──────────────────
local fakeNow = 1000
local function clockNow(): number
	return fakeNow
end

-- taskImpl de teste: defer síncrono; spawn = noop (o loop de regen roda
-- apenas no Roblox com task real — aqui não queremos loop infinito)
local testTask = {
	spawn = function(_fn: () -> ())
		-- noop: não roda o loop de regen em testes
	end,
	defer = function(fn: () -> ())
		fn()
	end,
	wait = function(seconds: number): number
		return seconds
	end,
	delay = function(seconds: number, fn: () -> ())
		task.wait(seconds)
		fn()
	end,
}

local function makePlayerState(userId: number, resource: number, health: number?): any
	return {
		userId = userId,
		characterId = "eclipse_fist",
		health = health or 100,
		resource = resource,
		familyId = "umbral_aether",
		combat = false,
		lastCombatAt = 0,
	}
end

-- ══ Testes: dados ───────────────────────────────────────────────────────────
test("dados: Punho do Eclipse tem 3 skills ligadas e 1 ultimate desligada", function()
	local char = Characters.get("eclipse_fist")
	assertTrue(char ~= nil, "eclipse_fist deveria existir")
	if not char then
		return
	end
	assertEq(#char.abilityIds, 4, "quantidade de habilidades")
	local weaver = Characters.get("echo_weaver")
	assertTrue(weaver ~= nil and weaver.enabled, "segunda identidade no catálogo")
	if weaver then
		assertEq(weaver.energyFamilyId, "vital_flow", "Fluxo Vital")
	end
	assertEq(char.energyFamilyId, "umbral_aether", "família")
	local enabled = 0
	local disabled = 0
	for _, abilityId in char.abilityIds do
		local ab = Abilities.get(abilityId)
		assertTrue(ab ~= nil, "abilityIds referencia " .. abilityId)
		if ab and ab.enabled then
			enabled += 1
		else
			disabled += 1
		end
	end
	assertEq(enabled, 3, "skills ligadas")
	assertEq(disabled, 1, "ultimate desligada")
end)

test("dados: comet_shoulder é o molde com custo/cooldown", function()
	local ab = Abilities.get("comet_shoulder")
	assertTrue(ab ~= nil, "comet_shoulder deveria existir")
	if ab then
		assertEq(ab.kind, "Skill", "kind")
		assertEq(ab.resourceCost.amount, 18, "custo de recurso")
		assertEq(ab.cooldown.baseSeconds, 7, "cooldown")
		assertEq(ab.serverRunnerId, "comet_shoulder_runner", "runner")
		assertEq(ab.enabled, true, "enabled")
	end
end)

test("dados: Umbral segue o baseline da fatia", function()
	local fam = EnergyFamilies.get("umbral_aether")
	assertTrue(fam ~= nil, "umbral_aether deveria existir")
	if fam then
		assertEq(fam.poolBase, 100, "pool")
		assertEq(fam.regenInCombatPerSec, 2, "regen combate")
		assertEq(fam.regenOutOfCombatPerSec, 6, "regen fora")
		assertEq(fam.outOfCombatDelaySeconds, 3, "atraso OOC")
		assertEq(fam.flowTimingWindowMs, 120, "janela")
		assertEq(fam.flowGainOnTimedHit, 6, "fluxo")
		assertEq(fam.flowGainCapSeconds, 1.5, "cap")
		assertEq(fam.flowBonusAmount, 3, "bônus")
	end
end)

test("dados: 4 famílias de energia", function()
	assertEq(#EnergyFamilies.all(), 4, "número de famílias")
end)

test("progressão: curva Blox Fruits e teto GDD de 6%", function()
	assertEq(ProgressionCatalog.POINTS_PER_LEVEL, 3, "3 pontos por nível")
	assertEq(ProgressionCatalog.xpToNextLevel(1), 86, "2×1^2,3+84")
	assertEq(ProgressionCatalog.xpToNextLevel(100), 0, "teto sem próximo")
	local start = ProgressionCatalog.progressFromXp(0)
	assertEq(start.level, 1, "começa no 1")
	assertEq(start.intoLevel, 0, "barra vazia")
	local afterFirst = ProgressionCatalog.progressFromXp(86)
	assertEq(afterFirst.level, 2, "86 XP sobe para 2")
	assertEq(ProgressionCatalog.earnedPoints(2), 3, "nível 2 rende 3 pontos")
	assertEq(ProgressionCatalog.earnedPoints(1), 0, "nível 1 sem pontos")
	local spent = ProgressionCatalog.emptySpent()
	spent.impact = 100
	spent.resonance = 100
	spent.vitality = 50
	local vitals = ProgressionCatalog.vitalsFor(spent)
	assertEq(vitals.damageBonus, 0.06, "impacto no teto GDD")
	assertEq(vitals.resourceCostMul, 0.94, "ressonância no teto GDD")
	assertEq(vitals.maxHealth, 200, "vitalidade +2 HP")
	assertEq(ProgressionCatalog.scaleDamage(10, 0.06), 11, "10 × 1,06")
	assertEq(ProgressionCatalog.scaleDamage(6, 0), 6, "sem bônus não arredonda")
	assertEq(ProgressionCatalog.canSpend(spent, 3, "impact", 1), "track_cap", "trilha no teto 100")
	assertEq(ProgressionCatalog.canSpend(ProgressionCatalog.emptySpent(), 0, "vitality", 1), "no_points", "sem pontos")
	assertEq(
		ProgressionCatalog.canSpend(ProgressionCatalog.emptySpent(), 3, "atk", 1),
		"unknown_track",
		"trilha ATK recusada"
	)
end)

test("dados: remotes registrados com contrato", function()
	local c = Remotes.Contracts.get(Remotes.Names.AbilityIntent)
	assertTrue(c ~= nil, "AbilityIntent deveria ter contrato")
	if c then
		assertEq(c.direction, "ClientToServer", "direção")
		assertEq(c.version, 2, "versão")
	end
	local rejected = Remotes.Contracts.get(Remotes.Names.AbilityRejected)
	assertTrue(rejected ~= nil, "AbilityRejected deveria ter contrato")
	if rejected then
		assertEq(rejected.version, 2, "rejeicao correlacionada")
		assertTrue(rejected.payload:find("executionId", 1, true) ~= nil, "rejeicao carrega executionId")
		assertTrue(rejected.payload:find("phase", 1, true) ~= nil, "rejeicao carrega fase")
	end
	local snap = Remotes.Contracts.get(Remotes.Names.SessionSnapshot)
	assertTrue(snap ~= nil, "SessionSnapshot deveria ter contrato")
	if snap then
		assertEq(snap.direction, "ServerToClient", "snapshot S→C")
	end
end)

test("dados: envelope v2 aceita somente contrato completo", function()
	local envelope = RemoteEnvelope.create("AbilityIntent", { abilityId = "comet_shoulder" }, "req-1", 1)
	local payload, reason = RemoteEnvelope.decode(envelope, "AbilityIntent")
	assertTrue(payload ~= nil, "envelope válido")
	assertEq(reason, nil, "sem rejeição")
	assertEq(payload and payload.abilityId, "comet_shoulder", "payload preservado")
	assertEq(RemoteEnvelope.version(), 2, "versão canônica")
end)

test("dados: envelope v2 rejeita versão, sequência e ação inválidas", function()
	local wrongVersion = RemoteEnvelope.create("AbilityIntent", {}, "req-1", 1)
	wrongVersion.protocolVersion = 1
	local payload, reason = RemoteEnvelope.decode(wrongVersion, "AbilityIntent")
	assertEq(payload, nil, "versão antiga rejeitada")
	assertEq(reason, "protocol_version", "motivo versão")

	local wrongSequence = RemoteEnvelope.create("AbilityIntent", {}, "req-2", 0)
	local sequencePayload, sequenceReason = RemoteEnvelope.decode(wrongSequence, "AbilityIntent")
	assertEq(sequencePayload, nil, "sequência zero rejeitada")
	assertEq(sequenceReason, "client_sequence", "motivo sequência")

	local wrongAction = RemoteEnvelope.create("DashIntent", {}, "req-3", 2)
	local actionPayload, actionReason = RemoteEnvelope.decode(wrongAction, "AbilityIntent")
	assertEq(actionPayload, nil, "ação trocada rejeitada")
	assertEq(actionReason, "action_mismatch", "motivo ação")
end)

test("cliente: input não emite antes do SessionSnapshot ready", function()
	local state = ClientState.new(clockNow)
	local input = InputController.new(state, clockNow)
	local emitted = 0
	InputController.subscribe(input, function(_action: any, _payload: any)
		emitted += 1
	end)
	local ok, reason = InputController.dispatch(input, "BasicLight", {})
	assertFalse(ok, "boot não emite")
	assertEq(reason, "not_ready", "motivo")
	assertEq(emitted, 0, "nenhuma intenção")
end)

test("cliente: input limita combate a 8 intenções por segundo", function()
	fakeNow = 2000
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local emitted = 0
	InputController.subscribe(input, function(_action: any, _payload: any)
		emitted += 1
	end)
	for _ = 1, 8 do
		assertTrue(InputController.dispatch(input, "BasicLight", {}), "primeiras oito")
	end
	local ninth, reason = InputController.dispatch(input, "Dash", {})
	assertFalse(ninth, "nona descartada")
	assertEq(reason, "rate_limited", "motivo")
	assertEq(emitted, 8, "oito emitidas")
	fakeNow += 1.01
	assertTrue(InputController.dispatch(input, "Dash", {}), "nova janela")
end)

test("cliente: toque recusa terceiro botão simultâneo", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	assertTrue(InputController.touchBegin(input, "a", "GuardDown", {}), "primeiro")
	assertTrue(InputController.touchBegin(input, "b", "Ability1", {}), "segundo")
	local ok, reason = InputController.touchBegin(input, "c", "Dash", {})
	assertFalse(ok, "terceiro recusado")
	assertEq(reason, "touch_chord_limit", "motivo")
	InputController.touchEnd(input, "a", "GuardUp", {})
	assertTrue(InputController.touchBegin(input, "c", "Dash", {}), "libera após soltar")
end)

test("cliente: hold-to-heavy — clique rápido é leve, segurar vira pesado", function()
	-- Decisão do Álvaro (17/08): botão direito virou guarda; o pesado passou
	-- a morar no clique esquerdo SEGURADO (~0,3s). A regra é função pura
	-- (`resolveMouseRelease`) — o wiring de InputBegan/Ended só registra o
	-- relógio e chama ela no release.
	assertEq(
		InputController.resolveMouseRelease(nil, 10, InputController.HoldHeavySeconds),
		"BasicLight",
		"sem press registrado = leve (release órfão)"
	)
	assertEq(
		InputController.resolveMouseRelease(10, 10.1, InputController.HoldHeavySeconds),
		"BasicLight",
		"clique rápido (< 0,3s) = leve"
	)
	assertEq(
		InputController.resolveMouseRelease(10, 10.3, InputController.HoldHeavySeconds),
		"BasicHeavy",
		"exatamente no limiar = pesado"
	)
	assertEq(
		InputController.resolveMouseRelease(10, 11, InputController.HoldHeavySeconds),
		"BasicHeavy",
		"hold longo = pesado"
	)
	assertEq(InputController.HoldHeavySeconds, 0.3, "limiar documentado é 0,3s")
end)

test("cliente: CharacterController envia somente intenção sem alvo ou dano", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
	})
	InputController.dispatch(input, "BasicLight", {})
	InputController.dispatch(input, "GuardDown", {})
	InputController.dispatch(input, "Dash", {})
	assertEq(#sent, 3, "três intenções")
	assertEq(sent[1].payload.kind, "light", "ataque sem alvo")
	assertEq(sent[1].payload.targetId, nil, "sem alvo")
	assertEq(sent[1].payload.damage, nil, "sem dano")
	assertEq(sent[2].payload.phase, "down", "guarda sem sucesso inventado")
	assertEq(sent[3].payload.direction.z, -1, "direção unitária fallback")
end)

test("dados: Locomotion F0 é caminhada 16 / corrida 22 com teto no envelope", function()
	local ok, reason = Locomotion.validate()
	assertTrue(ok, reason or "validação")
	assertEq(Locomotion.walkSpeed, 16, "caminhada F0-BASELINE")
	assertEq(Locomotion.runSpeed, 22, "corrida F0-BASELINE")
	assertEq(Locomotion.clampAuthorizedSpeed(16), 16, "caminhada passa")
	assertEq(Locomotion.clampAuthorizedSpeed(22), 22, "corrida passa")
	assertEq(Locomotion.clampAuthorizedSpeed(100), 22, "exploit de WalkSpeed cortado no teto")
	assertEq(Locomotion.clampAuthorizedSpeed(-3), 16, "inválido vira caminhada")
	assertEq(Locomotion.speedForSprinting(true), 22, "sprint on")
	assertEq(Locomotion.speedForSprinting(false), 16, "sprint off")
end)

test("cliente: SprintDown/Up não vira remote e só mexe na velocidade local", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local humanoid = {
		WalkSpeed = 16,
		MoveDirection = { Magnitude = 0 },
	}
	local controller = CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
		players = {
			LocalPlayer = {
				Character = {
					FindFirstChildOfClass = function(_self: any, className: string)
						return if className == "Humanoid" then humanoid else nil
					end,
					FindFirstChild = function(_self: any, _name: string)
						return nil
					end,
				},
			},
		},
		walkSpeed = Locomotion.walkSpeed,
		runSpeed = Locomotion.runSpeed,
	})

	local okDown, reasonDown = InputController.dispatch(input, "SprintDown", {})
	assertTrue(okDown, reasonDown or "SprintDown aceito")
	assertEq(controller.sprinting, true, "estado de corrida")
	assertEq(humanoid.WalkSpeed, 22, "WalkSpeed de corrida")
	assertEq(#sent, 0, "corrida não manda remote")

	-- Sprint é NON_COMBAT: esgota o teto de combate e ainda solta a corrida.
	for _ = 1, 8 do
		assertTrue(InputController.dispatch(input, "Dash", {}), "burst de dash")
	end
	assertEq(#sent, 8, "só os dashes viraram remote")
	local ninth, ninthReason = InputController.dispatch(input, "Dash", {})
	assertFalse(ninth, "9º dash rate limited")
	assertEq(ninthReason, "rate_limited", "motivo do teto")
	local sprintStillOk = InputController.dispatch(input, "SprintUp", {})
	assertTrue(sprintStillOk, "SprintUp fora do teto de combate")
	assertEq(controller.sprinting, false, "soltou a corrida")
	assertEq(humanoid.WalkSpeed, 16, "volta a caminhar")
	assertEq(#sent, 8, "SprintUp também não manda remote")
end)

test("cliente: nada no golpe gira o corpo do personagem", function()
	-- Reclamação do jogador em 14/08: "quando eu bater ou soltar poder o
	-- personagem vira sozinho e fica de costas para a câmera". A causa era o
	-- `faceAim`, que escrevia `root.CFrame = lookAt(pos, direção da câmera)`
	-- antes de cada intenção, só para o servidor ler o look replicado. A direção
	-- passou a viajar declarada no payload, e o caminho que mexia no corpo
	-- deixou de existir — é isso que este teste tranca.
	assertEq(CharacterController.faceAim, nil, "não existe mais caminho que gire o corpo no golpe")
	assertTrue(type(CharacterController.aimVector) == "function", "a mira virou valor declarado")

	-- Sem câmera nem personagem (deps de Instance ausentes no harness), a mira é
	-- desconhecida: o payload sai sem o campo e o servidor cai de volta no look
	-- replicado. O golpe nunca deixa de ser enviado por causa disso.
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local controller = CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
	})
	assertEq(CharacterController.aimVector(controller), nil, "sem câmera não há mira para declarar")
	InputController.dispatch(input, "BasicHeavy", {})
	assertEq(#sent, 1, "o golpe sai mesmo sem mira conhecida")
	assertEq(sent[1].payload.kind, "heavy", "tipo preservado")
	assertEq(sent[1].payload.aim, nil, "mira ausente não vira vetor inventado")
end)

test("cliente: ToggleLock solta um alvo já travado sem enviar remote", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local controller = CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
	})
	local fakeTarget = {
		Parent = {},
		IsA = function(_self: any, className: string): boolean
			return className == "BasePart"
		end,
		GetAttribute = function(_self: any, name: string): any
			return name == "CombatTarget"
		end,
	}
	controller.lockTarget = fakeTarget
	InputController.dispatch(input, "ToggleLock", {})
	assertEq(controller.lockTarget, nil, "segunda ToggleLock solta")
	assertEq(#sent, 0, "mira não é intenção de combate")
end)

test("cliente: clearLock solta a mira sem procurar outro alvo", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local controller = CharacterController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
	})
	local fakeTarget = {
		Parent = {},
		IsA = function(_self: any, className: string): boolean
			return className == "BasePart"
		end,
		GetAttribute = function(_self: any, name: string): any
			return name == "CombatTarget"
		end,
	}
	controller.lockTarget = fakeTarget
	assertTrue(CharacterController.isLocked(controller), "travada")
	CharacterController.clearLock(controller)
	assertFalse(CharacterController.isLocked(controller), "botão SOLTAR MIRA limpa")
	assertEq(controller.lockTarget, nil, "sem alvo")
	assertEq(#sent, 0, "soltar mira não é remote")
end)

test("cliente: clique de combate passa por HUD processed sem botão", function()
	assertTrue(InputController.shouldAcceptInput(false, false, true, false), "mundo livre")
	assertTrue(InputController.shouldAcceptInput(true, false, true, false), "HUD chrome não come o golpe")
	assertFalse(InputController.shouldAcceptInput(true, false, true, true), "GuiButton fica com o botão")
	assertFalse(InputController.shouldAcceptInput(true, true, true, false), "TextBox bloqueia")
	assertFalse(InputController.shouldAcceptInput(true, false, false, false), "teclado processed respeita chat")
end)

test("cliente: ToggleHelp não consome o limite de combate", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local received = 0
	InputController.subscribe(input, function(action: string)
		if action == "ToggleHelp" then
			received += 1
		end
	end)
	for _ = 1, 8 do
		assertTrue(InputController.dispatch(input, "BasicLight", {}), "ataque dentro do limite")
	end
	local ok, reason = InputController.dispatch(input, "BasicLight", {})
	assertFalse(ok, "nono ataque recusado")
	assertEq(reason, "rate_limited", "motivo")
	assertTrue(InputController.dispatch(input, "ToggleHelp", {}), "ajuda passa o limite")
	assertEq(received, 1, "ToggleHelp chegou")
end)

test("cliente: AbilityController mantém 3 slots, oculta ultimate e exige unlock", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local controller = AbilityController.new({
		state = state,
		stateApi = ClientState,
		input = input,
		inputSubscribe = InputController.subscribe,
		abilities = Abilities,
		characters = Characters,
		send = function(_remoteName: string, _action: string, payload: { [string]: any })
			table.insert(sent, payload)
		end,
		guid = function()
			return "execution-1"
		end,
	})
	assertEq(#controller.slotIds, 3, "três slots")
	for _, abilityId in controller.slotIds do
		assertFalse(abilityId == "eclipse_beat", "ultimate desligada oculta")
	end
	local locked, reason = AbilityController.activateSlot(controller, 1)
	assertFalse(locked, "locked não envia")
	assertEq(reason, "locked", "motivo")
	assertEq(#sent, 0, "sem remote")
	state.unlocks.unlock_comet_shoulder = true
	local ok, executionId = AbilityController.activateSlot(controller, 1)
	assertTrue(ok, "destravada envia")
	assertEq(executionId, "execution-1", "correlação")
	assertEq(sent[1].abilityId, "comet_shoulder", "ID sem nome público")
	assertEq(sent[1].executionId, "execution-1", "executionId no payload")
	assertEq(sent[1].damage, nil, "sem dano")
	assertTrue(ClientState.cooldownRemaining(state, "comet_shoulder") > 0, "cooldown radial recebe estado")
end)

test("cliente: Cadência reentra no cooldown com o mesmo executionId e preserva cooldown se rejeitada", function()
	fakeNow = 12000
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, {
		ready = true,
		unlocks = { "unlock_broken_cadence", "unlock_pulse_return" },
	})
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local guidCalls = 0
	local controller = AbilityController.new({
		state = state,
		stateApi = ClientState,
		input = input,
		inputSubscribe = InputController.subscribe,
		abilities = Abilities,
		characters = Characters,
		send = function(_remoteName: string, _action: string, payload: { [string]: any })
			table.insert(sent, payload)
		end,
		guid = function()
			guidCalls += 1
			return ("execution-%d"):format(guidCalls)
		end,
	})

	local activated, executionId = AbilityController.activateSlot(controller, 2)
	assertTrue(activated, "ativação inicial envia")
	assertEq(executionId, "execution-1", "execução inicial")
	assertEq(sent[1].phase, "press", "fase inicial")
	local initialCooldown = state.cooldowns.broken_cadence
	assertTrue(initialCooldown ~= nil, "cooldown inicial previsto")

	fakeNow = 12000.2
	local early, earlyReason = AbilityController.activateSlot(controller, 2)
	assertFalse(early, "buffer não envia antes dos 400 ms")
	assertEq(earlyReason, "reentry_window", "fora da janela local")
	assertEq(#sent, 1, "sem remote prematuro")

	fakeNow = 12000.45
	local reentered, reentryExecutionId = AbilityController.activateSlot(controller, 2)
	assertTrue(reentered, "reentrada atravessa o cooldown")
	assertEq(reentryExecutionId, executionId, "reusa executionId inicial")
	assertEq(sent[2].phase, "reentry", "fase semântica de reentrada")
	assertEq(sent[2].executionId, sent[1].executionId, "mesma execução nos dois intents")
	assertEq(guidCalls, 1, "reentrada não cria execução nova")
	assertEq(state.cooldowns.broken_cadence, initialCooldown, "reentrada não reinicia cooldown local")

	local remainingBeforeRejection = ClientState.cooldownRemaining(state, "broken_cadence")
	AbilityController.onRejected(controller, {
		abilityId = "broken_cadence",
		reason = "reentry_window",
	})
	assertEq(
		ClientState.cooldownRemaining(state, "broken_cadence"),
		remainingBeforeRejection,
		"rejeição da reentrada preserva cooldown inicial"
	)

	local pulseOk, pulseExecutionId = AbilityController.activateSlot(controller, 3)
	assertTrue(pulseOk, "outro slot continua independente")
	assertEq(pulseExecutionId, "execution-2", "outro slot recebe execução própria")
	assertEq(sent[3].abilityId, "pulse_return", "slot 3 intacto")
	assertEq(sent[3].phase, "press", "outro slot não vira reentrada")
end)

test("cliente: rejeição reconcilia cooldown e feedback nunca mostra código", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	ClientState.setCooldown(state, "comet_shoulder", 7)
	local input = InputController.new(state, clockNow)
	local ability = AbilityController.new({
		state = state,
		stateApi = ClientState,
		input = input,
		inputSubscribe = InputController.subscribe,
		abilities = Abilities,
		characters = Characters,
		send = function() end,
		guid = function()
			return "execution-2"
		end,
	})
	local feedback = CombatFeedbackController.new(state, ClientState)
	local payload = { abilityId = "comet_shoulder", reason = "no_resource" }
	AbilityController.onRejected(ability, payload)
	CombatFeedbackController.onRejected(feedback, payload)
	assertEq(ClientState.cooldownRemaining(state, "comet_shoulder"), 0, "predição desfeita")
	assertEq(ClientState.feedback(state), "hud.feedback_no_resource", "chave localizada")
	assertFalse(ClientState.feedback(state) == payload.reason, "código não vai para a tela")
end)

test("cliente: recurso, zona e perda só mudam após ready", function()
	local state = ClientState.new(clockNow)
	local resource = ResourceController.new(state, ClientState)
	local zone = ZoneController.new(state, ClientState)
	ResourceController.onChanged(resource, { current = 0, max = 100, depleted = true })
	ZoneController.onZoneEvent(zone, { to = "zone_plain_free", pvp = true })
	assertEq(state.resource, 0, "pré-ready permanece inicial")
	assertEq(state.zoneId, "", "pré-ready sem zona")
	ClientState.applySnapshot(state, { ready = true, resource = 50, zoneId = "zone_bastion_safe" })
	ResourceController.onChanged(resource, { current = 0, max = 100, depleted = true })
	ZoneController.onZoneEvent(zone, { to = "zone_plain_free", pvp = true })
	ZoneController.onDelta(zone, { deathPenalty = 15 })
	assertEq(state.resource, 0, "recurso autoritativo")
	assertTrue(state.depleted, "esgotado visível")
	assertEq(state.zoneId, "zone_plain_free", "zona autoritativa")
	assertTrue(state.pvp, "PvP ativo")
	assertEq(ClientState.feedback(state), "hud.feedback_death_loss", "perda resumida localizada")
end)

test("cliente: hold de fronteira exige 0,6 s e usa apenas destino oferecido pelo servidor", function()
	fakeNow = 2100
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true, zoneId = "zone_bastion_safe" })
	local sent: { any } = {}
	local zone = ZoneController.new(
		state,
		ClientState,
		nil,
		nil,
		function(remoteName: string, action: string, payload: any)
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
		clockNow
	)
	ZoneController.onZoneEvent(zone, {
		from = "zone_bastion_safe",
		to = "zone_threshold_transition",
		pvp = false,
		signals = { "physical_gate" },
		holdConfirmed = false,
		rejectedReason = "hold_required",
	})
	assertEq(state.zoneId, "zone_bastion_safe", "rejeição não falsifica zona")
	assertTrue(state.zoneHoldRequired, "prompt visível")
	ZoneController.onAction(zone, "ZoneHoldDown")
	fakeNow += 0.59
	ZoneController.onAction(zone, "ZoneHoldUp")
	assertEq(#sent, 2, "hold curto envia begin e cancel")
	assertEq(sent[1].payload.phase, "begin", "servidor inicia relógio")
	assertEq(sent[2].payload.phase, "cancel", "soltura curta cancela")
	ZoneController.onAction(zone, "ZoneHoldDown")
	fakeNow += 0.65
	ZoneController.onAction(zone, "ZoneHoldUp")
	assertEq(#sent, 4, "hold confirmado envia begin e complete")
	assertEq(sent[3].payload.phase, "begin", "nova tentativa começa")
	assertEq(sent[4].payload.phase, "complete", "servidor confirma duração")
	assertEq(sent[4].payload.toZoneId, "zone_threshold_transition", "destino do evento autoritativo")
	assertEq(sent[4].payload.position, nil, "sem posição declarada pelo cliente")
end)

test("cliente: Locale cobre todo texto do HUD F0 em PT-BR e EN", function()
	local keys = {
		"hud.health",
		"hud.guard",
		"hud.resource",
		"hud.resource_depleted",
		"hud.ability_locked",
		"hud.feedback_hit",
		"hud.feedback_guard",
		"hud.feedback_no_resource",
		"hud.feedback_cooldown",
		"hud.feedback_rejected",
		"hud.feedback_death_loss",
		"hud.control_attack",
		"hud.control_guard",
		"hud.control_dash",
		"hud.help_button",
		"hud.help_title",
		"hud.help_hint",
		"hud.help_light",
		"hud.help_heavy",
		"hud.help_guard",
		"hud.help_sprint",
		"hud.help_dash",
		"hud.help_ability",
		"hud.help_lock",
		"hud.help_interact",
		"hud.help_gate",
		"hud.pvp_hold",
		"hud.pvp_hold_key",
		"hud.help_close",
		"hud.lock_on",
		"hud.menu_button",
		"hud.lock_release",
		"hud.lock_engage",
		"hud.settings_close",
		"hud.settings_camera",
		"hud.settings_shake_on",
		"hud.settings_shake_off",
		"hud.settings_where",
		"hud.debug_kit",
		"hud.credits_vfx",
	}
	for _, key in keys do
		assertTrue(Locale.hasKey(key), key .. " existe")
		assertFalse(Locale.get(key, "pt-br") == key, key .. " PT-BR")
		assertFalse(Locale.get(key, "en") == key, key .. " EN")
	end
end)

test("apresentação: jogador tem antecipação, impacto, guarda e recuperação puramente visuais", function()
	-- Instantes lidos da tabela de timing, não escritos à mão: o que este teste
	-- afirma é "antecipa, depois cruza", e isso vale em qualquer calibração.
	local lightWindup = PlayerCombatAnimator.sample("BasicLight", PlayerCombatAnimator.lightChainAnticipation(1), false)
	local lightStrike = PlayerCombatAnimator.sample("BasicLight", PlayerCombatAnimator.lightChainImpact(1), false)
	local heavyStrike = PlayerCombatAnimator.sample("BasicHeavy", PlayerCombatAnimator.HeavyBeats.strikeEnd, false)
	local recovered = PlayerCombatAnimator.sample("BasicHeavy", PlayerCombatAnimator.Durations.BasicHeavy, false)
	local guard = PlayerCombatAnimator.sample(nil, 0, true)
	assertTrue(lightWindup.rootYawDegrees < 0, "leve antecipa para um lado")
	assertTrue(lightStrike.rootYawDegrees > 0, "leve cruza no impacto")
	assertTrue(
		math.abs(heavyStrike.rightShoulderPitchDegrees) > math.abs(lightStrike.rightShoulderPitchDegrees),
		"pesado tem mais compromisso visual"
	)
	assertEq(recovered.rootYawDegrees, 0, "recupera para neutro")
	-- Pitch POSITIVO = braço à frente no rig real (medição em PlayerCombatAnimator,
	-- bloco da GUARD). A asserção anterior exigia negativo e por isso travava a
	-- guarda com os braços atrás do corpo.
	assertTrue(guard.leftShoulderPitchDegrees > 40, "guarda fecha a silhueta")
end)

test("apresentação: Ability1 comunica avanço e impacto sem posição autoritativa", function()
	local beats = PlayerCombatAnimator.AuthoritativeBeats
	local windup = PlayerCombatAnimator.sample("Ability1", 0.18, false)
	local impact = PlayerCombatAnimator.sample("Ability1", beats.cometImpact, false)
	local recovered = PlayerCombatAnimator.sample("Ability1", PlayerCombatAnimator.Durations.Ability1, false)
	assertTrue(windup.rootPitchDegrees < 0, "Ombro Cometa recolhe antes do avanço")
	assertTrue(impact.rootPitchDegrees > 20, "impacto inclina o rig para a frente")
	assertTrue(impact.rightShoulderPitchDegrees < -100, "ombro lidera o impacto")
	-- É ombro, não soco: se o cotovelo estender, a técnica passa a competir com
	-- o ataque pesado na silhueta e o jogador perde a leitura.
	assertTrue(impact.rightElbowPitchDegrees < -60, "cotovelo permanece fechado no contato")
	assertEq((impact :: any).rootPosition, nil, "pose não declara posição autoritativa")
	assertEq(recovered.rootPitchDegrees, 0, "técnica retorna ao baseline")
end)

test("apresentação: Ability2 possui dois golpes alternados e recuperação", function()
	local beats = PlayerCombatAnimator.AuthoritativeBeats
	-- Os instantes amostrados são os mesmos em que o AbilityService resolve dano.
	local first = PlayerCombatAnimator.sample("Ability2", beats.cadenceFirstHit, false)
	local broken = PlayerCombatAnimator.sample("Ability2", 0.24, false)
	local second = PlayerCombatAnimator.sample("Ability2", beats.cadenceSecondHit, false)
	local recovered = PlayerCombatAnimator.sample("Ability2", PlayerCombatAnimator.Durations.Ability2, false)
	assertTrue(first.rootYawDegrees > 15, "primeiro golpe cruza à direita")
	assertTrue(math.abs(broken.rootYawDegrees) < math.abs(first.rootYawDegrees), "cadência recolhe entre golpes")
	assertTrue(second.rootYawDegrees < -20, "segundo golpe alterna o lado")
	assertTrue(first.rightShoulderPitchDegrees < -70, "primeiro golpe usa braço direito")
	assertTrue(second.leftShoulderPitchDegrees < -80, "segundo golpe usa braço esquerdo")
	-- Cotovelada curta seguida de revés estendido: os dois golpes não repetem a
	-- mesma mecânica de braço.
	assertTrue(first.rightElbowPitchDegrees < -60, "golpe 1 é cotovelada — cotovelo fechado")
	assertTrue(second.leftElbowPitchDegrees > -30, "golpe 2 estende o braço")
	assertEq(recovered.rootYawDegrees, 0, "cadência termina neutra")
end)

test("apresentação: Ability3 forma pulso defensivo simétrico e visual", function()
	local gathered = PlayerCombatAnimator.sample("Ability3", 0.1, false)
	local released = PlayerCombatAnimator.sample("Ability3", 0.22, false)
	local recovered = PlayerCombatAnimator.sample("Ability3", PlayerCombatAnimator.Durations.Ability3, false)
	assertTrue(gathered.leftShoulderPitchDegrees < -55, "pulso fecha a guarda")
	assertEq(released.leftShoulderPitchDegrees, released.rightShoulderPitchDegrees, "liberação simétrica")
	assertEq(released.leftShoulderYawDegrees, -released.rightShoulderYawDegrees, "braços abrem em oposição")
	assertEq(released.rootYawDegrees, 0, "pulso não escolhe direção ou alvo")
	assertEq(recovered.leftShoulderPitchDegrees, 0, "pulso retorna ao baseline")
end)

test("interação: catálogo fecha Instrutor e Marco com texto localizado", function()
	local ok, reason = Interactions.validate()
	assertTrue(ok, reason)
	local instructor = Interactions.getByNpc("npc_threshold_instructor")
	local returnMarker = Interactions.getByAnchor("anchor_bastion_return")
	assertTrue(instructor ~= nil, "Instrutor allowlisted")
	assertTrue(returnMarker ~= nil, "Marco allowlisted")
	if instructor and returnMarker then
		assertEq(instructor.anchorId, "anchor_instructor", "posição canônica do Instrutor")
		assertEq(instructor.holdDuration, 0, "conversa imediata")
		assertEq(returnMarker.holdDuration, 1.5, "hold do Marco")
		for _, definition in { instructor, returnMarker } do
			assertTrue(Locale.hasKey(definition.actionTextKey), "ação localizada")
			assertTrue(Locale.hasKey(definition.objectTextKey), "objeto localizado")
			assertTrue(Zones.getAnchor(definition.anchorId) ~= nil, "âncora conhecida")
		end
	end
end)

test("cliente: interação respeita ready e envia somente alvo e fase sem recompensa", function()
	local state = ClientState.new(clockNow)
	local input = InputController.new(state, clockNow)
	local sent: { any } = {}
	local interactionController = InteractionController.new({
		state = state,
		input = input,
		inputSubscribe = InputController.subscribe,
		inputApi = InputController,
		send = function(remoteName: string, action: string, payload: { [string]: any })
			table.insert(sent, { remoteName = remoteName, action = action, payload = payload })
		end,
		workspace = {},
		locale = Locale,
		catalog = Interactions,
		now = clockNow,
	})
	assertEq(interactionController.now(), fakeNow, "relógio do hold injetado")
	local beforeReady, beforeReason = InputController.dispatch(input, "Interact", {
		npcId = "npc_threshold_instructor",
		phase = "complete",
	})
	assertFalse(beforeReady, "não envia no boot")
	assertEq(beforeReason, "not_ready", "gate SLICE-DEC-005")
	ClientState.applySnapshot(state, { ready = true })
	assertTrue(
		InputController.dispatch(input, "Interact", {
			npcId = "npc_threshold_instructor",
			phase = "complete",
		}),
		"envia após snapshot"
	)
	assertEq(#sent, 1, "uma intenção")
	assertEq(sent[1].remoteName, "InteractionIntent", "remote existente")
	assertEq(sent[1].payload.npcId, "npc_threshold_instructor", "alvo semântico")
	assertEq(sent[1].payload.phase, "complete", "fase explícita")
	assertEq(sent[1].payload.anchorId, nil, "payload exclusivo")
	assertEq(sent[1].payload.reward, nil, "sem recompensa declarada")
end)

local function makeInteractionDeps(position: any, calls: { any })
	return {
		catalog = Interactions,
		getAnchor = Zones.getAnchor,
		getPlayerPosition = function(_userId: number)
			return position.value
		end,
		onNpc = function(userId: number, targetId: string, at: number)
			table.insert(calls, { userId = userId, targetId = targetId, at = at })
			return true, nil, { accepted = true }
		end,
		onAnchor = function(userId: number, targetId: string, at: number)
			table.insert(calls, { userId = userId, targetId = targetId, at = at })
			return true, nil, { consolidated = 25 }
		end,
	}
end

test("interação: Instrutor exige alvo conhecido e proximidade autoritativa", function()
	local position = { value = { x = 20, y = 0, z = -14 } }
	local calls: { any } = {}
	InteractionService.init(makeInteractionDeps(position, calls))
	local unknown = InteractionService.tryInteract(600, { npcId = "npc_spoof", phase = "complete" }, 10)
	assertFalse(unknown.ok, "alvo inventado recusado")
	assertEq(unknown.reason, "unknown_target", "motivo")
	local ambiguous = InteractionService.tryInteract(600, {
		npcId = "npc_threshold_instructor",
		anchorId = "anchor_bastion_return",
		phase = "complete",
	}, 10)
	assertFalse(ambiguous.ok, "alvo ambíguo recusado")
	position.value = { x = 35, y = 0, z = -14 }
	local far = InteractionService.tryInteract(600, { npcId = "npc_threshold_instructor", phase = "complete" }, 10)
	assertFalse(far.ok, "fora do alcance")
	assertEq(far.reason, "too_far", "distância no servidor")
	position.value = { x = 20, y = 0, z = -14 }
	local accepted = InteractionService.tryInteract(600, {
		npcId = "npc_threshold_instructor",
		phase = "complete",
	}, 10)
	assertTrue(accepted.ok, "próximo aceita")
	assertEq(#calls, 1, "domínio chamado uma vez")
end)

test("interação: Marco mede hold 1,5 s no relógio do servidor", function()
	local position = { value = { x = 0, y = 0, z = 12 } }
	local calls: { any } = {}
	InteractionService.init(makeInteractionDeps(position, calls))
	local payload = { anchorId = "anchor_bastion_return", phase = "complete" }
	local withoutBegin = InteractionService.tryInteract(601, payload, 20)
	assertFalse(withoutBegin.ok, "complete isolado recusa")
	assertEq(withoutBegin.reason, "hold_required", "begin obrigatório")
	local began = InteractionService.tryInteract(601, { anchorId = "anchor_bastion_return", phase = "begin" }, 20)
	assertTrue(began.ok, "inicia hold")
	local early = InteractionService.tryInteract(601, payload, 21.49)
	assertFalse(early.ok, "cliente não autoriza janela")
	assertEq(early.reason, "hold_incomplete", "faltou tempo")
	local consumed = InteractionService.tryInteract(601, payload, 21.5)
	assertEq(consumed.reason, "hold_required", "complete cedo consome o begin")
	assertTrue(
		InteractionService.tryInteract(601, { anchorId = "anchor_bastion_return", phase = "begin" }, 22).ok,
		"novo hold inicia"
	)
	local completed = InteractionService.tryInteract(601, payload, 23.5)
	assertTrue(completed.ok, "servidor confirmou 1,5 s")
	assertEq(#calls, 1, "consolida uma vez")
end)

test("interação: cancel consome o hold sem executar efeito", function()
	local position = { value = { x = 0, y = 0, z = 12 } }
	local calls: { any } = {}
	InteractionService.init(makeInteractionDeps(position, calls))
	assertTrue(
		InteractionService.tryInteract(603, { anchorId = "anchor_bastion_return", phase = "begin" }, 50).ok,
		"hold inicia"
	)
	local cancelled = InteractionService.tryInteract(603, {
		anchorId = "anchor_bastion_return",
		phase = "cancel",
	}, 50.2)
	assertTrue(cancelled.ok, "cancel aceito")
	local completed = InteractionService.tryInteract(603, {
		anchorId = "anchor_bastion_return",
		phase = "complete",
	}, 52)
	assertEq(completed.reason, "hold_required", "cancel remove pending")
	assertEq(#calls, 0, "sem consolidação")
end)

test("interação: Marco revalida distância ao completar e limpa pending no leave", function()
	local position = { value = { x = 0, y = 0, z = 12 } }
	local calls: { any } = {}
	InteractionService.init(makeInteractionDeps(position, calls))
	assertTrue(
		InteractionService.tryInteract(602, {
			anchorId = "anchor_bastion_return",
			phase = "begin",
		}, 30).ok,
		"hold inicia perto"
	)
	position.value = { x = 30, y = 0, z = 12 }
	local escaped = InteractionService.tryInteract(602, {
		anchorId = "anchor_bastion_return",
		phase = "complete",
	}, 31.5)
	assertFalse(escaped.ok, "afastou antes de concluir")
	assertEq(escaped.reason, "too_far", "alcance final autoritativo")
	position.value = { x = 0, y = 0, z = 12 }
	InteractionService.tryInteract(602, { anchorId = "anchor_bastion_return", phase = "begin" }, 40)
	InteractionService.clearPlayer(602)
	local afterLeave = InteractionService.tryInteract(602, {
		anchorId = "anchor_bastion_return",
		phase = "complete",
	}, 42)
	assertEq(afterLeave.reason, "hold_required", "pending não atravessa sessão")
	assertEq(#calls, 0, "nenhum efeito")
end)

test("telemetria: aceita só evento e campos allowlisted", function()
	local emitted: { any } = {}
	TelemetryService.init({
		sessionId = "session-test",
		releaseId = "release-test",
		now = function()
			return 123
		end,
		emit = function(event: any)
			table.insert(emitted, event)
		end,
	})
	local ok = TelemetryService.record("RemoteRejected", 42, {
		contract = "DashIntent",
		reason = "payload_schema",
		weight = 3,
		payload = { secret = "não deve sair" },
		ip = "127.0.0.1",
	})
	assertTrue(ok, "evento permitido")
	assertEq(#emitted, 1, "emitido")
	assertEq(emitted[1].sessionId, "session-test", "correlação")
	assertEq(emitted[1].fields.contract, "DashIntent", "campo permitido")
	assertEq(emitted[1].fields.payload, nil, "payload bruto removido")
	assertEq(emitted[1].fields.ip, nil, "IP removido")
end)

test("telemetria: rejeita evento/campo inválido e limita o buffer", function()
	TelemetryService.init({ sessionId = "s", releaseId = "r", bufferCapacity = 2 })
	local unknown, unknownReason = TelemetryService.record("ChatMessage", 1, { text = "segredo" })
	assertFalse(unknown, "evento fora da allowlist")
	assertEq(unknownReason, "event_not_allowed", "motivo")
	local wrongType, typeReason = TelemetryService.record("FtueBeat", 1, { flag = 123 })
	assertFalse(wrongType, "tipo inválido")
	assertEq(typeReason, "field_type", "motivo")
	TelemetryService.record("FtueBeat", 1, { flag = "a", elapsedMs = 1 })
	TelemetryService.record("FtueBeat", 1, { flag = "b", elapsedMs = 2 })
	TelemetryService.record("FtueBeat", 1, { flag = "c", elapsedMs = 3 })
	local events = TelemetryService.snapshot()
	assertEq(#events, 2, "buffer limitado")
	assertEq(events[1].fields.flag, "b", "mais antigo descartado")
end)

test("telemetria: os sete eventos F0 possuem schema executável", function()
	TelemetryService.init({ sessionId = "s", releaseId = "r", bufferCapacity = 10 })
	local cases = {
		{ "SessionLoad", { durationMs = 1, schemaFrom = 1, schemaTo = 1, result = "success" } },
		{ "FtueBeat", { flag = "ftue_spawned", elapsedMs = 2 } },
		{ "AbilityResolved", { abilityId = "comet_shoulder", result = "hit", latencyMs = 3, flowGranted = 0 } },
		{ "KillResolved", { zoneId = "zone_plain_free", combatType = "pve", xpLost = 0 } },
		{ "SaveAttempt", { dirty = false, bytes = 4, result = "success" } },
		{ "RemoteRejected", { contract = "DashIntent", reason = "payload_schema", weight = 3 } },
		{ "ZoneTransition", { from = "zone_bastion_safe", to = "zone_plain_free", holdConfirmed = true } },
	}
	for _, case in cases do
		local ok, reason = TelemetryService.record(case[1], 1, case[2])
		assertTrue(ok, case[1] .. ": " .. tostring(reason))
	end
	assertEq(#TelemetryService.snapshot(), 7, "todos registrados")
end)

local function validAbilityEnvelope(sequence: number, requestId: string): any
	return RemoteEnvelope.create("AbilityIntent", {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "exec-1",
		phase = "press",
	}, requestId, sequence)
end

test("segurança: aceita envelope e payload válidos", function()
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		now = function()
			return 10
		end,
	})
	local payload, reason = SecurityService.inspect(50, "AbilityIntent", validAbilityEnvelope(1, "req-1"))
	assertTrue(payload ~= nil, "aceito")
	assertEq(reason, nil, "sem rejeição")
	assertEq(payload.abilityId, "comet_shoulder", "payload semântico")
end)

test("segurança: rejeita campo extra e contrato sem direção C→S", function()
	local rejected: { any } = {}
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		onRejected = function(userId: number, contract: string, reason: string, weight: number)
			table.insert(rejected, { userId = userId, contract = contract, reason = reason, weight = weight })
		end,
	})
	local envelope = validAbilityEnvelope(1, "req-extra")
	envelope.payload.damage = 999999
	local payload, reason = SecurityService.inspect(51, "AbilityIntent", envelope)
	assertEq(payload, nil, "campo hostil descartado")
	assertEq(reason, "payload_schema", "motivo")
	local wrongDirection, directionReason = SecurityService.inspect(51, "StateDelta", envelope)
	assertEq(wrongDirection, nil, "S→C não aceita cliente")
	assertEq(directionReason, "contract_direction", "direção")
	assertEq(#rejected, 2, "duas rejeições observáveis")
	assertEq(rejected[1].weight, 3, "peso do payload hostil")
end)

test("segurança: envelope estrito e telemetria de rejeição não fazem spam", function()
	local currentNow = 5
	local reports = 0
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		now = function()
			return currentNow
		end,
		onRejected = function()
			reports += 1
		end,
	})
	for sequence = 1, 3 do
		local envelope = validAbilityEnvelope(sequence, "extra-" .. sequence)
		envelope.clientTimestamp = 999999
		local payload, reason = SecurityService.inspect(510, "AbilityIntent", envelope)
		assertEq(payload, nil, "envelope com campo extra")
		assertEq(reason, "envelope_schema", "motivo")
	end
	assertEq(reports, 1, "uma emissão por contrato/motivo/segundo")
	currentNow += 1
	local later = validAbilityEnvelope(4, "extra-later")
	later.clientTimestamp = 999999
	SecurityService.inspect(510, "AbilityIntent", later)
	assertEq(reports, 2, "nova janela volta a emitir")
end)

test("segurança: bloqueia replay de requestId e sequência", function()
	SecurityService.init({ decode = RemoteEnvelope.decode })
	local first = SecurityService.inspect(52, "AbilityIntent", validAbilityEnvelope(1, "same-request"))
	assertTrue(first ~= nil, "primeira aceita")
	local replayRequest, requestReason =
		SecurityService.inspect(52, "AbilityIntent", validAbilityEnvelope(2, "same-request"))
	assertEq(replayRequest, nil, "request repetido")
	assertEq(requestReason, "replay_request", "motivo")
	local replaySequence, sequenceReason =
		SecurityService.inspect(52, "AbilityIntent", validAbilityEnvelope(1, "new-request"))
	assertEq(replaySequence, nil, "sequência regressiva")
	assertEq(sequenceReason, "replay_sequence", "motivo")
end)

test("segurança: limita combate a 8/s sem consumir interações", function()
	local currentNow = 20
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		now = function()
			return currentNow
		end,
	})
	for sequence = 1, 8 do
		local envelope = RemoteEnvelope.create(
			"BasicAttackIntent",
			{ kind = "light", phase = "press" },
			"atk-" .. sequence,
			sequence
		)
		local payload = SecurityService.inspect(53, "BasicAttackIntent", envelope)
		assertTrue(payload ~= nil, "combate dentro do orçamento")
	end
	local ninth = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "atk-9", 9)
	local payload, reason = SecurityService.inspect(53, "BasicAttackIntent", ninth)
	assertEq(payload, nil, "nona intenção descartada")
	assertEq(reason, "rate_limited", "motivo")
	local interaction = RemoteEnvelope.create(
		"InteractionIntent",
		{ npcId = "npc_threshold_instructor", phase = "complete" },
		"interaction",
		10
	)
	local allowed = SecurityService.inspect(53, "InteractionIntent", interaction)
	assertTrue(allowed ~= nil, "orçamento default separado")
	currentNow += 1
	local reset = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "atk-10", 11)
	assertTrue(SecurityService.inspect(53, "BasicAttackIntent", reset) ~= nil, "janela reinicia")
end)

test("segurança: orçamento de combate é isolado por jogador", function()
	local currentNow = 30
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		now = function()
			return currentNow
		end,
	})
	for sequence = 1, 8 do
		local envelope = RemoteEnvelope.create(
			"BasicAttackIntent",
			{ kind = "light", phase = "press" },
			("a-%d"):format(sequence),
			sequence
		)
		assertTrue(SecurityService.inspect(601, "BasicAttackIntent", envelope) ~= nil, "jogador A dentro do orçamento")
	end
	local rejected = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "a-9", 9)
	local rejectedPayload, rejectedReason = SecurityService.inspect(601, "BasicAttackIntent", rejected)
	assertEq(rejectedPayload, nil, "jogador A excede o orçamento")
	assertEq(rejectedReason, "rate_limited", "motivo do jogador A")
	local playerB = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "b-1", 1)
	assertTrue(
		SecurityService.inspect(602, "BasicAttackIntent", playerB) ~= nil,
		"jogador B possui orçamento independente"
	)
	currentNow += 1
end)

test("segurança: sequência fora de ordem não atravessa jogadores", function()
	SecurityService.init({ decode = RemoteEnvelope.decode })
	local delayed = validAbilityEnvelope(2, "latency-a-2")
	assertTrue(SecurityService.inspect(603, "AbilityIntent", delayed) ~= nil, "pacote adiantado aceito")
	local late = validAbilityEnvelope(1, "latency-a-1")
	local latePayload, lateReason = SecurityService.inspect(603, "AbilityIntent", late)
	assertEq(latePayload, nil, "pacote atrasado recusado")
	assertEq(lateReason, "replay_sequence", "motivo do pacote atrasado")
	local otherPlayer = validAbilityEnvelope(1, "latency-b-1")
	assertTrue(
		SecurityService.inspect(604, "AbilityIntent", otherPlayer) ~= nil,
		"outro jogador não herda a sequência"
	)
end)

test("segurança: clearPlayer limpa orçamento da sessão anterior", function()
	local currentNow = 40
	SecurityService.init({
		decode = RemoteEnvelope.decode,
		now = function()
			return currentNow
		end,
	})
	for sequence = 1, 8 do
		local envelope = RemoteEnvelope.create(
			"BasicAttackIntent",
			{ kind = "light", phase = "press" },
			("session-a-%d"):format(sequence),
			sequence
		)
		assertTrue(
			SecurityService.inspect(605, "BasicAttackIntent", envelope) ~= nil,
			"sessão antiga dentro do orçamento"
		)
	end
	local ninth = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "session-a-9", 9)
	local rejectedPayload, rejectedReason = SecurityService.inspect(605, "BasicAttackIntent", ninth)
	assertEq(rejectedPayload, nil, "sessão antiga excede o orçamento")
	assertEq(rejectedReason, "rate_limited", "motivo da sessão antiga")
	SecurityService.clearPlayer(605)
	local rejoin = RemoteEnvelope.create("BasicAttackIntent", { kind = "light", phase = "press" }, "session-b-1", 1)
	assertTrue(SecurityService.inspect(605, "BasicAttackIntent", rejoin) ~= nil, "rejoin recebe orçamento novo")
	currentNow += 1
end)

test("segurança: mira declarada entra no contrato de golpe e técnica", function()
	SecurityService.init({ decode = RemoteEnvelope.decode })
	local function inspecionar(contrato: string, payload: { [string]: any }, seq: number)
		return SecurityService.inspect(77, contrato, RemoteEnvelope.create(contrato, payload, "mira-" .. seq, seq))
	end

	-- A mira é OPCIONAL: cliente sem câmera conhecida manda o golpe sem o campo
	-- e o servidor cai de volta no look replicado.
	assertTrue(inspecionar("BasicAttackIntent", { kind = "light", phase = "press" }, 1) ~= nil, "golpe sem mira")
	assertTrue(
		inspecionar("BasicAttackIntent", { kind = "light", phase = "press", aim = { x = 0, z = -1 } }, 2) ~= nil,
		"golpe com mira unitária"
	)
	assertEq(
		inspecionar("BasicAttackIntent", { kind = "light", phase = "press", aim = { x = 0, z = 0 } }, 3),
		nil,
		"mira neutra recusada no schema"
	)
	assertEq(
		inspecionar("BasicAttackIntent", { kind = "light", phase = "press", aim = { x = 9, z = 0 } }, 4),
		nil,
		"mira grande demais recusada"
	)
	assertEq(
		inspecionar("BasicAttackIntent", { kind = "light", phase = "press", aim = { x = 0, y = 1, z = -1 } }, 5),
		nil,
		"mira com campo a mais recusada"
	)

	local tecnica = {
		abilityId = "comet_shoulder",
		inputMode = "Press",
		executionId = "exec-1",
		phase = "press",
		aim = { x = 1, z = 0 },
	}
	assertTrue(inspecionar("AbilityIntent", tecnica, 6) ~= nil, "técnica com mira")
	assertEq(
		inspecionar(
			"AbilityIntent",
			{ abilityId = "comet_shoulder", inputMode = "Press", executionId = "exec-2", aim = "frente" },
			7
		),
		nil,
		"mira que não é vetor recusada"
	)
	assertTrue(
		inspecionar(
			"BasicAttackIntent",
			{ kind = "light", phase = "press", aim = { x = 0, z = -1 }, claimedTargetId = "player:777" },
			8
		) ~= nil,
		"pista de alvo declarada é válida"
	)
	assertEq(
		inspecionar("BasicAttackIntent", { kind = "light", phase = "press", claimedTargetId = "player 777" }, 9),
		nil,
		"pista com espaço recusada"
	)
	assertTrue(inspecionar("BasicAttackIntent", {
		kind = "light",
		phase = "press",
		aim = { x = 0, z = -1 },
		claimedTargetId = "enemy_wandering_shard@anchor_shard_1#1",
	}, 10) ~= nil, "pista de estilhaço (id com @ e #) é válida")
	assertTrue(inspecionar("BasicAttackIntent", {
		kind = "light",
		phase = "press",
		claimedTargetId = "enemy_grove_wisp@anchor_wisp_2#1",
	}, 11) ~= nil, "pista de fátuo é válida")
	assertEq(
		inspecionar("BasicAttackIntent", {
			kind = "light",
			phase = "press",
			claimedTargetId = "enemy_wandering_shard@anchor_shard_1",
		}, 12),
		nil,
		"id de inimigo sem índice recusado"
	)
end)

test("segurança: rejeita vetor impossível, NaN e payload ambíguo", function()
	SecurityService.init({ decode = RemoteEnvelope.decode })
	local tooFar = RemoteEnvelope.create("DashIntent", { direction = { x = 2, z = 0 } }, "dash-1", 1)
	local payload, reason = SecurityService.inspect(54, "DashIntent", tooFar)
	assertEq(payload, nil, "vetor fora do limite")
	assertEq(reason, "payload_schema", "motivo")
	local nan = 0 / 0
	local notNumber = RemoteEnvelope.create("DashIntent", { direction = { x = nan, z = 0 } }, "dash-2", 2)
	assertEq(SecurityService.inspect(54, "DashIntent", notNumber), nil, "NaN descartado")
	local neutral = RemoteEnvelope.create("DashIntent", { direction = { x = 0, z = 0 } }, "dash-3", 3)
	assertEq(SecurityService.inspect(54, "DashIntent", neutral), nil, "dash neutro não concede i-frame")
	local ambiguous = RemoteEnvelope.create("InteractionIntent", {
		npcId = "npc_threshold_instructor",
		anchorId = "anchor_bastion_return",
		phase = "complete",
	}, "interaction-2", 3)
	assertEq(SecurityService.inspect(54, "InteractionIntent", ambiguous), nil, "interação ambígua descartada")
end)

test("segurança: limpar jogador permite nova sessão começar em sequência 1", function()
	SecurityService.init({ decode = RemoteEnvelope.decode })
	assertTrue(SecurityService.inspect(55, "AbilityIntent", validAbilityEnvelope(1, "old-session")) ~= nil, "sessão 1")
	SecurityService.clearPlayer(55)
	assertTrue(SecurityService.inspect(55, "AbilityIntent", validAbilityEnvelope(1, "new-session")) ~= nil, "sessão 2")
end)

test("dados: dummy de treino no catálogo", function()
	local dummy = Npcs.get("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy deveria existir")
	if dummy then
		assertEq(dummy.maxHealth, 10000, "vida")
		assertEq(dummy.attackDamage, 5, "dano")
		assertEq(dummy.attackRange, 8, "alcance")
		assertEq(dummy.grantsXp, false, "sem XP")
	end
end)

test("dados: estilhaço errante segue o baseline da fatia", function()
	local shard = Npcs.get("enemy_wandering_shard")
	assertTrue(shard ~= nil, "estilhaço deveria existir")
	if shard then
		assertEq(shard.kind, "enemy", "kind")
		assertEq(shard.maxHealth, 60, "vida")
		assertEq(shard.attackDamage, 8, "dano")
		assertEq(shard.attackRange, 4, "esfera 4 studs")
		assertEq(shard.telegraphMs, 400, "telegraph")
		assertEq(shard.moveSpeed, 12, "velocidade")
		assertEq(shard.respawnSeconds, 45, "respawn")
		assertEq(shard.xpUnconsolidated, 25, "XP")
		assertEq(shard.maxAlive, 4, "população")
		assertEq(shard.zoneId, "zone_plain_free", "zona")
		assertEq(shard.grantsXp, true, "concede XP")
		assertEq(shard.aggroRadiusStuds, 30, "raio de aggro Blox Fruits")
	end
end)

-- ══ Testes: CooldownService ─────────────────────────────────────────────────
test("cooldown: começa zerado", function()
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "cooldown inicial")
end)

test("cooldown: start aplica e expira", function()
	CooldownService.clear(1)
	CooldownService.start(1, "comet_shoulder", 0.05)
	local remaining = CooldownService.getRemaining(1, "comet_shoulder")
	assertTrue(remaining > 0 and remaining <= 0.06, "cooldown ativo")
	local start = os.clock()
	while os.clock() - start < 0.06 do
	end
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "cooldown expirado")
end)

test("cooldown: clear zera", function()
	CooldownService.start(1, "comet_shoulder", 10)
	CooldownService.clear(1)
	assertEq(CooldownService.getRemaining(1, "comet_shoulder"), 0, "após clear")
end)

-- ══ Testes: CombatService ───────────────────────────────────────────────────
test("combate: dano reduz vida", function()
	local target = makePlayerState(2, 100)
	CombatService.applyDamage(target, 30, 1)
	assertEq(target.health, 70, "vida após dano")
	assertTrue(CombatService.isAlive(target), "deveria estar vivo")
end)

test("combate: dano letal mata", function()
	local target = makePlayerState(2, 100)
	local dead = CombatService.applyDamage(target, 100, 1)
	assertTrue(dead, "dano 100 deveria matar")
	assertEq(target.health, 0, "vida em 0")
	assertFalse(CombatService.isAlive(target), "morto")
end)

test("combate: dano negativo não cura", function()
	local target = makePlayerState(2, 100, 50)
	CombatService.applyDamage(target, -10, 1)
	assertEq(target.health, 50, "vida inalterada")
end)

test("combate: cadeia leve 6+6+8+12", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	assertEq(CombatService.tryLight(atk, tgt, 1.0, "front").damage, 6, "hit 1")
	assertEq(CombatService.tryLight(atk, tgt, 1.2, "front").damage, 6, "hit 2")
	assertEq(CombatService.tryLight(atk, tgt, 1.4, "front").damage, 8, "hit 3")
	assertEq(CombatService.tryLight(atk, tgt, 1.6, "front").damage, 12, "hit 4")
	assertEq(tgt.health, 68, "32 de dano")
end)

test("combate: evento do básico leva dano e miss zera a cadeia", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	local hit = CombatService.tryLight(atk, tgt, 1.0, "front")
	local event = CombatService.basicCombatEvent(hit, "light", tgt.id, false)
	assertEq(event.outcome, "hit", "acerto")
	assertEq(event.damage, 6, "dano no evento")
	assertEq(event.step, 1, "degrau")
	assertTrue(CombatHudController.shouldShowDamage(event), "HUD desenha o número")
	local miss = CombatService.basicCombatEvent(nil, "light", nil, false)
	assertEq(miss.outcome, "miss", "whiff")
	assertEq(miss.damage, 0, "whiff sem número")
	assertFalse(CombatHudController.shouldShowDamage(miss), "HUD esconde whiff")
end)

test("combate: golpe fatal emite outcome death no evento do básico", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 5, 100)
	local hit = CombatService.tryLight(atk, tgt, 1.0, "front")
	assertEq(hit.killed, true, "kill sinalizado no HitResult")
	local event = CombatService.basicCombatEvent(hit, "light", tgt.id, false)
	assertEq(event.outcome, "death", "cliente recebe death, não hit genérico")
	assertTrue(event.damage > 0, "número de dano no golpe fatal")
	assertTrue(CombatHudController.shouldShowDamage(event), "HUD desenha o número da morte")
	local taken = CombatService.basicCombatEvent(hit, "light", tgt.id, false)
	taken.view = "taken"
	assertFalse(CombatHudController.shouldShowDamage(taken), "quem apanha não desenha o número")
end)

test("combate: janela 1,00 s reinicia a cadeia", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.tryLight(atk, tgt, 1.0, "front")
	local result = CombatService.tryLight(atk, tgt, 2.05, "front")
	assertEq(result.step, 1, "reset")
	assertEq(result.damage, 6, "primeiro golpe de novo")
end)

test("combate: guarda frontal reduz HP a 40%", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 10.0)
	local result = CombatService.tryLight(atk, tgt, 10.2, "front")
	assertEq(result.damage, 2, "floor(5*0.4)")
	assertEq(tgt.guard, 94, "guarda perde o dano cheio")
	assertEq(tgt.health, 98, "HP reduzido")
end)

test("combate: aparo nos 120 ms zera dano e guarda", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 20.0)
	local result = CombatService.tryLight(atk, tgt, 20.1, "front")
	assertEq(result.parried, true, "aparo")
	assertEq(result.damage, 0, "sem HP")
	assertEq(tgt.guard, 100, "guarda intacta")
	assertEq(tgt.health, 100, "HP intacto")
end)

test("combate: repetir guarda não renova a janela de aparo", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 25.0)
	CombatService.setGuard(tgt, true, 25.19)
	local result = CombatService.tryLight(atk, tgt, 25.2, "front")
	assertEq(result.parried, nil, "down redundante não reabre os 120 ms")
	assertEq(result.damage, 2, "golpe é bloqueado normalmente")
end)

test("combate: costas ignoram guarda", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 30.0)
	local result = CombatService.tryLight(atk, tgt, 30.2, "back")
	assertEq(result.damage, 6, "dano cheio")
	assertEq(tgt.guard, 100, "guarda não consome")
end)

test("combate: pesado 12 HP, 28 guarda, 2 se bloqueado", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local open = CombatService.createFighter("p:b", "player", 100, 100)
	assertEq(CombatService.tryHeavy(atk, open, 1.0, "front").damage, 12, "sem guarda")
	local guarded = CombatService.createFighter("p:c", "player", 100, 100)
	CombatService.setGuard(guarded, true, 2.0)
	local blocked = CombatService.tryHeavy(atk, guarded, 2.2, "front")
	assertEq(blocked.damage, 2, "HP bloqueado")
	assertEq(guarded.guard, 72, "28 de guarda")
end)

test("combate: quebra de guarda aplica overflow", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 20)
	CombatService.setGuard(tgt, true, 3.0)
	local result = CombatService.tryHeavy(atk, tgt, 3.2, "front")
	assertEq(result.broken, true, "quebra")
	assertEq(tgt.guard, 0, "guarda zerada")
	assertEq(tgt.health, 94, "2 bloqueado + floor(8*0.5)=4")
	local refused = CombatService.setGuard(tgt, true, 3.3)
	assertEq(refused, false, "não guarda durante break")
end)

test("combate: guarda quebra ao chegar exatamente a zero", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 28)
	CombatService.setGuard(tgt, true, 3.0)
	local result = CombatService.tryHeavy(atk, tgt, 3.2, "front")
	assertEq(result.broken, true, "zero também é quebra")
	assertEq(tgt.guard, 0, "guarda zerada")
	assertEq(tgt.health, 98, "sem overflow quando o saldo fecha em zero")
end)

test("combate: pesado que erra bloqueia leve por 0,5 s", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	local miss = CombatService.tryHeavy(atk, nil, 4.0, "front")
	assertEq(miss.ok, false, "miss")
	assertEq(miss.reason, "miss", "motivo")
	local locked = CombatService.tryLight(atk, tgt, 4.4, "front")
	assertEq(locked.ok, false, "leve bloqueado")
	assertEq(locked.reason, "heavy_miss", "motivo")
	local ok = CombatService.tryLight(atk, tgt, 4.5, "front")
	assertEq(ok.ok, true, "após 0,5 s")
end)

test("combate: dash aplica i-frame e cooldown", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	local ok, reason = CombatService.tryDash(tgt, 5.0)
	assertEq(ok, true, "dash " .. tostring(reason))
	local iframe = CombatService.tryLight(atk, tgt, 5.05, "front")
	assertEq(iframe.iframe, true, "i-frame")
	assertEq(iframe.damage, 0, "sem dano")
	assertEq(tgt.health, 100, "HP intacto")
	local cd = CombatService.tryDash(tgt, 5.5)
	assertEq(cd, false, "cooldown")
	local after = CombatService.tryLight(atk, tgt, 8.1, "front")
	assertEq(after.damage, 6, "depois do i-frame")
end)

test("combate: preflight de dash não concede i-frame antes do commit", function()
	CombatService.clear()
	local fighter = CombatService.createFighter("p:dash-preflight", "player", 100, 100)
	local allowed = CombatService.canDash(fighter, 9.0)
	assertEq(allowed, true, "estado permite resolver espaço")
	assertEq(fighter.iframeUntil, 0, "preflight não materializa defesa")
	assertEq(fighter.dashCooldownUntil, 0, "preflight não consome cooldown")
	CombatService.commitDash(fighter, 9.0)
	assertTrue(fighter.iframeUntil > 9.0, "commit materializa i-frame")
	assertTrue(fighter.dashCooldownUntil > 9.0, "commit materializa cooldown")
end)

test("combate: dummy ataca a 8 studs e recusa longe", function()
	CombatService.clear()
	local dummy = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local far = CombatService.tryDummyAttack(dummy, player, 1.0, 9, 2.5, 4, 8)
	assertEq(far.ok, false, "fora de alcance")
	local hit = CombatService.tryDummyAttack(dummy, player, 1.0, 8, 2.5, 4, 8)
	assertEq(hit.ok, true, "no alcance")
	assertEq(hit.damage, 4, "dano do dummy")
	assertEq(player.health, 96, "HP")
	local wait = CombatService.tryDummyAttack(dummy, player, 2.0, 8, 2.5, 4, 8)
	assertEq(wait.reason, "cooldown", "período 2,5 s")
	assertEq(dummy.health, 10000, "dummy não morre no próprio ataque")
end)

test("combate: estilhaço telegraph depois dano 6", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 60, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local windup = CombatService.tryShardCycle(shard, player, 1.0, 4, true, 8, 4, 0.4, 0.6)
	assertEq(windup.phase, "telegraph", "telegraph")
	assertEq(windup.damage, 0, "ainda sem dano")
	assertEq(player.health, 100, "HP intacto")
	local early = CombatService.tryShardCycle(shard, player, 1.2, 4, true, 6, 4, 0.4, 0.6)
	assertEq(early.reason, "telegraph", "ainda no telegraph")
	local hit = CombatService.tryShardCycle(shard, player, 1.4, 4, true, 8, 4, 0.4, 0.6)
	assertEq(hit.ok, true, "acerto")
	assertEq(hit.damage, 8, "dano")
	assertEq(hit.phase, "attack", "fase")
	assertEq(player.health, 92, "HP")
end)

test("combate: estilhaço sem aggro através da fronteira", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 60, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local denied = CombatService.tryShardCycle(shard, player, 1.0, 2, false, 6, 4, 0.4, 0.6)
	assertEq(denied.reason, "no_aggro", "sem aggro")
	assertEq(player.health, 100, "HP intacto")
	assertEq(shard.aiPhase, "idle", "volta a idle")
end)

test("combate: estilhaço recusa fora da esfera de 4 studs", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 60, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	local far = CombatService.tryShardCycle(shard, player, 1.0, 5, true, 6, 4, 0.4, 0.6)
	assertEq(far.reason, "out_of_range", "fora")
end)

test("combate: estilhaço recovery bloqueia o próximo golpe", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 60, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	CombatService.tryShardCycle(shard, player, 1.0, 4, true, 8, 4, 0.4, 0.6)
	CombatService.tryShardCycle(shard, player, 1.4, 4, true, 8, 4, 0.4, 0.6)
	local blocked = CombatService.tryShardCycle(shard, player, 1.5, 4, true, 8, 4, 0.4, 0.6)
	assertEq(blocked.reason, "recovery", "recovery")
	assertEq(player.health, 92, "um único acerto")
end)

test("combate: estilhaço respawn 45 s e bloqueia com combate perto", function()
	CombatService.clear()
	local shard = CombatService.createFighter("enemy_wandering_shard:1", "npc", 60, 0)
	local player = CombatService.createFighter("p:a", "player", 100, 100)
	CombatService.tryLight(player, shard, 1.0, "front")
	-- 6+6+8+12 = 32, precisa de mais para matar 60
	CombatService.tryLight(player, shard, 1.2, "front")
	CombatService.tryLight(player, shard, 1.4, "front")
	CombatService.tryLight(player, shard, 1.6, "front")
	CombatService.tryLight(player, shard, 2.3, "front")
	CombatService.tryLight(player, shard, 2.5, "front")
	CombatService.tryLight(player, shard, 2.7, "front")
	CombatService.tryLight(player, shard, 2.9, "front")
	assertEq(shard.health, 0, "morto")
	assertTrue(shard.diedAt > 0, "diedAt")
	local tooSoon = CombatService.tryRespawn(shard, 20, 45, false)
	assertEq(tooSoon, false, "antes de 45 s")
	local nearby = CombatService.tryRespawn(shard, 50, 45, true)
	assertEq(nearby, false, "combate perto")
	local ok = CombatService.tryRespawn(shard, 50, 45, false)
	assertEq(ok, true, "respawn")
	assertEq(shard.health, 60, "vida cheia")
	assertEq(shard.aiPhase, "idle", "idle")
end)

test("combate: no máximo 4 estilhaços vivos", function()
	CombatService.clear()
	for i = 1, 4 do
		CombatService.createFighter("enemy_wandering_shard:" .. tostring(i), "npc", 60, 0)
	end
	assertEq(CombatService.countAliveNpcs("enemy_wandering_shard"), 4, "4 vivos")
	assertEq(CombatService.canSpawnNpc("enemy_wandering_shard", 4), false, "cap")
	local one = CombatService.getFighter("enemy_wandering_shard:1")
	assertTrue(one ~= nil, "existe")
	if one then
		one.health = 0
	end
	assertEq(CombatService.canSpawnNpc("enemy_wandering_shard", 4), true, "vaga após morte")
end)

test("combate: comet 14 HP aberto", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local result = CombatService.tryCometShoulder(atk, tgt, 1.0, "front")
	assertEq(result.ok, true, "hit")
	assertEq(result.damage, 14, "dano aberto")
	assertEq(tgt.health, 9986, "HP dummy")
	assertEq(result.stoppedOnGuard, nil, "sem guarda")
end)

test("combate: comet na guarda para o avanço", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 10.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 10.2, "front")
	assertEq(result.damage, 6, "HP bloqueado")
	assertEq(tgt.guard, 86, "14 de guarda")
	assertEq(tgt.health, 94, "HP")
	assertEq(result.stoppedOnGuard, true, "avanço interrompe")
end)

test("combate: comet aparo zera dano", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.setGuard(tgt, true, 20.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 20.1, "front")
	assertEq(result.parried, true, "aparo")
	assertEq(result.damage, 0, "sem HP")
	assertEq(tgt.health, 100, "HP intacto")
	assertEq(tgt.guard, 100, "guarda intacta")
	assertEq(result.stoppedOnGuard, true, "para o avanço")
end)

test("combate: comet i-frame zera dano", function()
	CombatService.clear()
	local atk = CombatService.createFighter("p:a", "player", 100, 100)
	local tgt = CombatService.createFighter("p:b", "player", 100, 100)
	CombatService.tryDash(tgt, 5.0)
	local result = CombatService.tryCometShoulder(atk, tgt, 5.05, "front")
	assertEq(result.iframe, true, "i-frame")
	assertEq(result.damage, 0, "sem dano")
	assertEq(tgt.health, 100, "HP intacto")
	assertEq(result.stoppedOnGuard, nil, "não é guarda")
end)

-- ══ Testes: ResourceService ─────────────────────────────────────────────────
local function makeResourceDeps()
	return {
		getFamily = function(familyId: string): any
			return EnergyFamilies.get(familyId)
		end,
		onResourceChanged = nil,
		taskImpl = testTask,
		now = clockNow,
	}
end

test("recurso: cria estado com pool da família", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(10, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if state then
		assertEq(state.resource, 100, "pool inicial")
	end
end)

test("recurso: trySpend deduz e nega sem saldo", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(11, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	assertTrue(ResourceService.trySpend(11, 15), "gasto 15 ok")
	assertEq(state.resource, 85, "pool após gasto")
	assertFalse(ResourceService.trySpend(11, 999), "gasto impossível negado")
	assertEq(state.resource, 85, "pool inalterado após negação")
end)

test("recurso: grantFlowGain respeita o cap", function()
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(12, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	ResourceService.grantFlowGain(12, 500)
	assertEq(state.resource, 100, "cap no teto")
end)

test("recurso: cria estado em família desconhecida retorna nil", function()
	ResourceService.init(makeResourceDeps())
	assertEq(ResourceService.createState(13, "nao_existe"), nil, "nil esperado")
end)

test("recurso: tryGrantFlow aplica 6+3 e respeita cap de 1,5 s", function()
	fakeNow = 2000
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(14, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	state.resource = 50
	assertEq(ResourceService.tryGrantFlow(14), 9, "primeira: 6+3")
	assertEq(state.resource, 59, "pool após primeiro fluxo")
	assertEq(ResourceService.tryGrantFlow(14), 0, "cap 1,5 s")
	assertEq(state.resource, 59, "pool inalterado no cap")
	fakeNow = 2001.5
	assertEq(ResourceService.tryGrantFlow(14), 6, "após cap, sem bônus de 8 s")
	assertEq(state.resource, 65, "pool após segundo fluxo")
end)

test("recurso: regen 2 em combate, 0 na janela, 6 fora", function()
	fakeNow = 3000
	ResourceService.init(makeResourceDeps())
	local state = ResourceService.createState(15, "umbral_aether")
	assertTrue(state ~= nil, "estado criado")
	if not state then
		return
	end
	assertEq(ResourceService.getRegenRate(15), 6, "nunca combateu")
	ResourceService.setCombat(15, true)
	assertEq(ResourceService.getRegenRate(15), 2, "em combate")
	ResourceService.setCombat(15, false)
	assertEq(ResourceService.getRegenRate(15), 0, "atraso de 3 s")
	fakeNow = 3003
	assertEq(ResourceService.getRegenRate(15), 6, "fora de combate")
end)

-- ══ Testes: AbilityService (fluxo completo com deps reais) ──────────────────
local function makeAbilityDeps(unlock: ((number, string) -> boolean)?)
	return {
		getAbility = function(abilityId: string): any
			return Abilities.get(abilityId)
		end,
		getCooldownRemaining = function(userId: number, abilityId: string)
			return CooldownService.getRemaining(userId, abilityId)
		end,
		startCooldown = function(userId: number, abilityId: string, seconds: number)
			CooldownService.start(userId, abilityId, seconds)
		end,
		trySpendResource = function(userId: number, amount: number)
			return ResourceService.trySpend(userId, amount)
		end,
		grantFlowGain = function(userId: number, amount: number)
			ResourceService.grantFlowGain(userId, amount)
		end,
		tryGrantFlow = function(userId: number)
			return ResourceService.tryGrantFlow(userId)
		end,
		isAlive = function(state: any)
			return CombatService.isAlive(state)
		end,
		applyDamage = function(target: any, damage: number, sourceUserId: number?)
			return CombatService.applyDamage(target, damage, sourceUserId)
		end,
		now = clockNow,
		isAbilityUnlocked = unlock,
		creditCareerDamage = CareerService.creditDamage,
	}
end

test("ability: comet_shoulder aplica dano 14 sem Fluxo", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(20)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(20, "umbral_aether")
	local target = makePlayerState(21, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", target)
	assertTrue(ok, "deveria ativar: " .. tostring(reason))
	assertEq(target.health, 86, "dano 14")
	assertEq(attacker.resource, 82, "custo 18, sem fluxo")
end)

test("ability: recusa sem recurso suficiente", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(30)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(30, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	attacker.resource = 5
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "deveria recusar")
	assertEq(reason, "no_resource", "motivo")
end)

test("ability: recusa em cooldown", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(40)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(40, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "segunda ativação deveria recusar")
	if reason then
		assertTrue(reason:match("^cooldown"), "motivo cooldown: " .. reason)
	end
end)

test("ability: habilidade desconhecida", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(50)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(50, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "nao_existe", nil)
	assertFalse(ok, "deveria recusar")
	assertEq(reason, "unknown_ability", "motivo")
end)

test("ability: morto não ativa", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(60)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(60, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	attacker.health = 0
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "morto não ativa")
	assertEq(reason, "dead", "motivo")
end)

test("ability: eclipse_beat desligada", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(70)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(70, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "eclipse_beat", nil)
	assertFalse(ok, "ultimate F0 desligada")
	assertEq(reason, "disabled", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
end)

test("ability: técnica locked rejeita", function()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(71)
	AbilityService.init(makeAbilityDeps(function(_userId: number, _abilityId: string)
		return false
	end))
	local attacker = ResourceService.createState(71, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(ok, "locked")
	assertEq(reason, "locked", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
end)

test("ability: cadência acerta 7+9 e eco 6 com Fluxo no tick", function()
	fakeNow = 4000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(80)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(80, "umbral_aether")
	local target = makePlayerState(81, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", target)
	assertTrue(ok, "cadência: " .. tostring(reason))
	AbilityService.tick(4000.14)
	AbilityService.tick(4000.32)
	assertEq(target.health, 84, "7+9")
	assertEq(attacker.resource, 84, "custo 16")
	-- A reentrada só abre 120 ms após o fim do active do golpe 2 (400 ms).
	local early, earlyReason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertFalse(early, "antes da janela não reentra")
	assertEq(earlyReason, "reentry_window", "motivo")
	fakeNow = 4000.45
	local reOk, reReason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertTrue(reOk, "reentrada na janela: " .. tostring(reReason))
	assertEq(target.health, 84, "reentrada não aplica dano (eco agendado)")
	assertEq(attacker.resource, 84, "reentrada não gasta")
	-- Eco sai 350 ms depois, no tick.
	AbilityService.tick(4000.8)
	assertEq(target.health, 78, "eco 6")
	assertEq(attacker.resource, 93, "fluxo 6+3")
end)

test("ability: cadência resolve alvo autoritativo uma vez e o preserva no eco", function()
	fakeNow = 4500
	CombatService.clear()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(84)
	local target = CombatService.createFighter("enemy_wandering_shard@anchor_shard_1#1", "npc", 100, 0)
	local resolveCalls = 0
	local confirmedHits: { number } = {}
	local deps = makeAbilityDeps()
	deps.resolveCadenceTarget = function(userId: number)
		assertEq(userId, 84, "resolver recebe somente o autor da intenção")
		resolveCalls += 1
		return target
	end
	deps.onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string)
		assertEq(userId, 84, "autor confirmado")
		assertEq(targetId, target.id, "alvo confirmado")
		assertEq(abilityId, "broken_cadence", "habilidade confirmada")
		table.insert(confirmedHits, damage)
	end
	AbilityService.init(deps)
	local attacker = ResourceService.createState(84, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end

	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", nil)
	assertTrue(ok, "cadência espacial: " .. tostring(reason))
	AbilityService.tick(4500.14)
	AbilityService.tick(4500.32)
	assertEq(target.health, 84, "alvo resolvido recebe 7+9")
	assertEq(resolveCalls, 1, "alvo resolvido uma vez no início")

	fakeNow = 4500.45
	local reOk, reReason = AbilityService.tryActivate(attacker, "broken_cadence", nil, { phase = "reentry" })
	assertTrue(reOk, "reentrada sem alvo declarado: " .. tostring(reReason))
	assertEq(target.health, 84, "reentrada apenas agenda o eco")
	AbilityService.tick(4500.8)
	assertEq(table.concat(confirmedHits, ","), "7,9,6", "feedback acompanha os tres impactos")
	assertEq(target.health, 78, "eco 6 reutiliza o alvo autoritativo inicial")
	assertEq(resolveCalls, 1, "reentrada e eco não escolhem outro alvo")
end)

test("ability: cadência recusa reentrada fora da janela", function()
	fakeNow = 5000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(82)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(82, "umbral_aether")
	local target = makePlayerState(83, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "broken_cadence", target)
	AbilityService.tick(5000.14)
	AbilityService.tick(5000.32)
	fakeNow = 5000.2
	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertFalse(ok, "fora da janela")
	assertEq(reason, "reentry_window", "motivo")
	assertEq(target.health, 84, "sem eco")
	assertEq(attacker.resource, 84, "sem fluxo extra")
end)

test("ability: cadencia aceita compensacao de lag ate 80 ms", function()
	fakeNow = 5500
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(86)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(86, "umbral_aether")
	local target = makePlayerState(87, 100)
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	assertTrue(AbilityService.tryActivate(attacker, "broken_cadence", target), "ativacao inicial")
	fakeNow = 5500.58
	local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence", target, { phase = "reentry" })
	assertTrue(ok, "120 ms + 80 ms aceitos: " .. tostring(reason))
end)

test("ability: cadencia carimba e notifica kill uma unica vez", function()
	fakeNow = 5600
	CombatService.clear()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(88)
	local target = CombatService.createFighter("enemy_wandering_shard@anchor_shard_1#9", "npc", 12, 0)
	local kills: { any } = {}
	local deps = makeAbilityDeps()
	deps.resolveCadenceTarget = function()
		return target
	end
	deps.onCombatKill = function(userId: number, targetId: string, abilityId: string)
		table.insert(kills, { userId = userId, targetId = targetId, abilityId = abilityId })
	end
	AbilityService.init(deps)
	local attacker = ResourceService.createState(88, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	assertTrue(AbilityService.tryActivate(attacker, "broken_cadence", nil), "cadencia ativa")
	fakeNow = 5600.14
	AbilityService.tick(5600.14)
	fakeNow = 5600.32
	AbilityService.tick(5600.32)
	assertEq(target.health, 0, "segundo golpe mata")
	assertEq(target.diedAt, 5600.32, "morte usa instante autoritativo do segundo active")
	assertEq(#kills, 1, "notifica uma vez")
	assertEq(kills[1].targetId, target.id, "alvo correlacionado")
end)

test("ability: cadência respeita i-frame e eco sem dano não concede Fluxo", function()
	fakeNow = 5700
	CombatService.clear()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(89)
	local attackerFighter = CombatService.createFighter("player:89", "player", 100, 100)
	local target = CombatService.createFighter("enemy_wandering_shard@anchor_shard_2#1", "npc", 100, 0)
	target.iframeUntil = 5701
	local hits = 0
	local flowEchos = 0
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function()
		return attackerFighter
	end
	deps.resolveCadenceTarget = function()
		return target
	end
	deps.revalidateCadenceTarget = function()
		return true
	end
	deps.tryCadenceHit = CombatService.tryCadenceHit
	deps.onCombatHit = function()
		hits += 1
	end
	deps.onFlowEcho = function()
		flowEchos += 1
	end
	AbilityService.init(deps)
	local attacker = ResourceService.createState(89, "umbral_aether")
	assertTrue(attacker ~= nil, "recurso criado")
	if not attacker then
		return
	end
	assertTrue(
		AbilityService.tryActivate(attacker, "broken_cadence", nil, { executionId = "exec-iframe" }),
		"cadência ativa"
	)
	AbilityService.tick(5700.14)
	AbilityService.tick(5700.32)
	fakeNow = 5700.45
	assertTrue(
		AbilityService.tryActivate(attacker, "broken_cadence", nil, {
			phase = "reentry",
			executionId = "exec-iframe",
		}),
		"reentrada correlacionada"
	)
	AbilityService.tick(5700.8)
	assertEq(target.health, 100, "i-frame evita os três impactos")
	assertEq(attacker.resource, 84, "sem Fluxo fantasma")
	assertEq(hits, 0, "sem feedback de hit falso")
	assertEq(flowEchos, 0, "objetivo não recebe eco falso")
end)

test("ability: Cadência revalida hitbox em cada active", function()
	fakeNow = 5800
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(96)
	local target = makePlayerState(97, 100)
	local allowed = true
	local deps = makeAbilityDeps()
	deps.revalidateCadenceTarget = function(_userId: number, sameTarget: any)
		return allowed and sameTarget == target
	end
	AbilityService.init(deps)
	local attacker = ResourceService.createState(96, "umbral_aether")
	assertTrue(attacker ~= nil, "recurso criado")
	if not attacker then
		return
	end
	assertTrue(AbilityService.tryActivate(attacker, "broken_cadence", target), "cadência ativa")
	AbilityService.tick(5800.14)
	allowed = false
	AbilityService.tick(5800.32)
	assertEq(target.health, 93, "segundo golpe não acerta alvo que saiu da hitbox")
end)

test("ability: reentrada exige executionId da ativação inicial", function()
	fakeNow = 5900
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(98)
	AbilityService.init(makeAbilityDeps())
	local attacker = ResourceService.createState(98, "umbral_aether")
	local target = makePlayerState(99, 100)
	assertTrue(attacker ~= nil, "recurso criado")
	if not attacker then
		return
	end
	assertTrue(
		AbilityService.tryActivate(attacker, "broken_cadence", target, { executionId = "exec-original" }),
		"cadência ativa"
	)
	fakeNow = 5900.45
	local wrong, reason = AbilityService.tryActivate(attacker, "broken_cadence", target, {
		phase = "reentry",
		executionId = "exec-outra",
	})
	assertFalse(wrong, "execução diferente recusada")
	assertEq(reason, "execution_mismatch", "correlação fechada")
	assertTrue(
		AbilityService.tryActivate(attacker, "broken_cadence", target, {
			phase = "reentry",
			executionId = "exec-original",
		}),
		"execução original ainda pode reentrar"
	)
end)

test("combate: Cadência respeita guarda, aparo e Retorno de Pulso", function()
	CombatService.clear()
	local attacker = CombatService.createFighter("player:cadence", "player", 100, 100)
	local target = CombatService.createFighter("player:defender", "player", 100, 100)
	CombatService.setGuard(target, true, 6000)
	local parry = CombatService.tryCadenceHit(attacker, target, 6000.05, 5, "front")
	assertTrue(parry.parried == true and parry.damage == 0, "aparo zera Cadência")
	local guarded = CombatService.tryCadenceHit(attacker, target, 6000.2, 5, "front")
	assertTrue(guarded.stoppedOnGuard == true, "guarda reconhecida")
	assertEq(guarded.damage, 2, "guarda deixa 40% do dano")
	CombatService.setGuard(target, false, 6000.3)
	CombatService.setPulseStance(target, 6001)
	local pulse = CombatService.tryCadenceHit(attacker, target, 6001.05, 6, "front")
	assertTrue(pulse.pulseCounter == true, "Pulso reduz o golpe frontal")
	assertEq(pulse.damage, 3, "Pulso reduz 50%")
end)

test("ability: pulse_return abre postura sem dano; erro vira recovery 600 ms", function()
	fakeNow = 9000
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(90)
	CombatService.clear()
	CombatService.createFighter("player:90", "player", 100, 100)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getFighterById = CombatService.getFighter
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	AbilityService.init(deps)
	local attacker = ResourceService.createState(90, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "pulse_return")
	assertTrue(ok, "postura: " .. tostring(reason))
	assertEq(attacker.resource, 80, "custo 20")
	local fighter = CombatService.getFighter("player:90")
	assertTrue(fighter ~= nil, "fighter existe")
	if fighter then
		assertTrue(fighter.pulseStanceUntil > 0, "postura ativa")
		-- Postura sem golpe: expira e entra em recovery 600 ms.
		local expired = CombatService.pulseTick(fighter, 9000.26)
		assertEq(expired, true, "postura expirou sem golpe")
		assertTrue(CombatService.isPulseRecovery(fighter, 9000.3), "em recovery")
		assertEq(
			CombatService.tryLight(
				fighter,
				CombatService.createFighter("player:90b", "player", 100, 100),
				9000.3,
				"front"
			).reason,
			"recovery",
			"recovery bloqueia ataque"
		)
		assertFalse(CombatService.isPulseRecovery(fighter, 9000.9), "após 600 ms libera")
	end
end)

test("ability: pulse_return reduz 50% de um golpe frontal e contra-ataca 10", function()
	fakeNow = 9100
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(92)
	CombatService.clear()
	CombatService.createFighter("player:92", "player", 100, 100)
	CombatService.createFighter("player:93", "player", 100, 100)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getFighterById = CombatService.getFighter
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	AbilityService.init(deps)
	local attacker = ResourceService.createState(92, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	AbilityService.tryActivate(attacker, "pulse_return")
	local defender = CombatService.getFighter("player:92")
	local striker = CombatService.getFighter("player:93")
	assertTrue(defender ~= nil and striker ~= nil, "fighters")
	if not defender or not striker then
		return
	end
	-- Golpe frontal de 10 (pesado) durante a postura: reduz 50% → 5.
	local hit = CombatService.tryHeavy(striker, defender, 9100.1, "front")
	assertTrue(hit.ok, "golpe conecta")
	assertEq(hit.pulseCounter, true, "contra disparado")
	assertEq(defender.health, 94, "dano reduzido a 50% (6 de 12)")
	-- O contra: 8 de dano no atacante (empurrão é espacial, fora do serviço).
	local counter = CombatService.tryPulseCounter(striker, 9100.1)
	assertEq(counter.damage, 10, "contra 10")
	assertEq(striker.health, 90, "atacante tomou 10")
	-- Segundo golpe na mesma postura: já foi usado, dano cheio.
	local second = CombatService.tryHeavy(striker, defender, 9100.2, "front")
	assertEq(second.pulseCounter, nil, "postura consumida (um golpe por postura)")
	assertEq(defender.health, 82, "dano cheio no segundo golpe")
end)

test("ability: pulse_return costas e slam do elite vencem a postura", function()
	fakeNow = 9200
	CombatService.clear()
	local defender = CombatService.createFighter("player:94", "player", 100, 100)
	local striker = CombatService.createFighter("player:95", "player", 100, 100)
	CombatService.setPulseStance(defender, 9200)
	-- Costas ignoram a postura (docs/13 §6.3: agarrão/costas vencem).
	local backHit = CombatService.tryHeavy(striker, defender, 9200.05, "back")
	assertEq(backHit.pulseCounter, nil, "costas não reduzem")
	assertEq(defender.health, 88, "dano cheio 12")
	-- Slam do elite é unblockable para o Pulso.
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 120, 0)
	CombatService.setPulseStance(striker, 9200.1)
	local slam = CombatService.tryEliteCycle(elite, striker, 9200.2, 5, true, {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 6,
		comboTelegraphSeconds = 0.3,
		slamDamage = 14,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	})
	-- Ciclo começa em combo; forçamos o padrão para slam.
	elite.elitePattern = "slam"
	slam = CombatService.tryEliteCycle(elite, striker, 9200.9, 5, true, {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 6,
		comboTelegraphSeconds = 0.3,
		slamDamage = 14,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	})
	assertEq(slam.ok, true, "slam conecta")
	assertEq(slam.damage, 14, "slam não é reduzido pela postura")
	assertEq(striker.health, 86, "dano cheio do slam")
end)

test("ability: comet no fighter dummy via deps", function()
	CombatService.clear()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(94)
	local hits: { any } = {}
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.onCombatHit = function(userId: number, targetId: string, damage: number, abilityId: string)
		table.insert(hits, {
			userId = userId,
			targetId = targetId,
			damage = damage,
			abilityId = abilityId,
		})
	end
	AbilityService.init(deps)
	CombatService.createFighter(CombatService.playerFighterId(94), "player", 100, 100)
	local dummy = CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local attacker = ResourceService.createState(94, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker criado")
	if not attacker then
		return
	end
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "deveria ativar: " .. tostring(reason))
	assertEq(dummy.health, 9986, "dummy HP")
	assertEq(attacker.resource, 82, "custo 18")
	assertEq(#hits, 1, "CombatHit")
	assertEq(hits[1].targetId, "npc_training_dummy", "alvo")
	assertEq(hits[1].damage, 14, "dano")
	assertEq(hits[1].abilityId, "comet_shoulder", "ability")
end)

-- ══ Testes: CatalogService (validação) ──────────────────────────────────────
test("catálogo: dados reais passam na validação", function()
	CatalogService.init({
		Abilities = Abilities,
		Characters = Characters,
		EnergyFamilies = EnergyFamilies,
		Npcs = Npcs,
		Zones = Zones,
		Quests = Quests,
		Items = Items,
		Locale = Locale,
	})
	assertEq(CatalogService.getQuest("quest_hunt") ~= nil, true, "objetivo 1 no catálogo")
	assertEq(CatalogService.getItem("shard_fragment") ~= nil, true, "item na mochila")
	assertEq(CatalogService.getQuest("quest_elite") ~= nil, true, "objetivo 2 no catálogo")
	assertEq(CatalogService.getQuest("quest_flow") ~= nil, true, "objetivo 3 no catálogo")
	assertEq(#CatalogService.questChain(), 5, "cadeia com as 5 missões")
	assertEq(CatalogService.getCharacter("echo_weaver") ~= nil, true, "segunda identidade")
	assertEq(CatalogService.getNpc("npc_threshold_instructor") ~= nil, true, "instrutor no catálogo")
	assertEq(CatalogService.getAbility("comet_shoulder") ~= nil, true, "habilidade acessível")
	assertEq(CatalogService.getAbility("eclipse_beat") ~= nil, true, "ultimate no catálogo")
	assertEq(CatalogService.getNpc("npc_training_dummy") ~= nil, true, "dummy no catálogo")
	assertEq(CatalogService.getNpc("enemy_wandering_shard") ~= nil, true, "estilhaço no catálogo")
	assertEq(CatalogService.getZone("zone_bastion_safe") ~= nil, true, "zona segura")
	assertEq(CatalogService.getAnchor("anchor_bastion_spawn") ~= nil, true, "âncora de spawn")
end)

test("catálogo: personagem sem habilidade falha", function()
	local badChars = {
		get = function()
			return nil
		end,
		all = function()
			return {
				{
					id = "x",
					contentVersion = 1,
					displayNameKey = "k",
					descriptionKey = "k",
					energyFamilyId = "umbral_aether",
					combatArchetype = "a",
					baseHealth = 100,
					abilityIds = {},
					enabled = true,
				},
			}
		end,
	}
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = badChars,
			EnergyFamilies = EnergyFamilies,
		})
	end)
	assertFalse(ok, "validação deveria falhar")
end)

-- ══ Testes: PlayerSessionService ────────────────────────────────────────────
test("sessão: join cria estado com personagem padrão", function()
	ResourceService.init(makeResourceDeps())
	local joined: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function(userId: number)
			table.insert(joined, userId)
		end,
	})
	local fakePlayer = { UserId = 70, Name = "Teste" }
	PlayerSessionService.onPlayerJoined(fakePlayer)
	local state = ResourceService.getState(70)
	assertTrue(state ~= nil, "estado criado no join")
	if state then
		assertEq(state.characterId, "eclipse_fist", "personagem")
		assertEq(state.health, 100, "vida base")
	end
	PlayerSessionService.onPlayerLeft(fakePlayer)
	assertEq(ResourceService.getState(70), nil, "estado limpo no leave")
	assertEq(#joined, 1, "release chamado no leave")
end)

test("sessão: snapshot Ready na zona segura com dummy", function()
	CombatService.clear()
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	local snapshots: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function(_player: any, snap: { any })
			table.insert(snapshots, snap)
		end,
		getUnlocks = ProgressionService.listUnlocks,
	})
	assertEq(PlayerSessionService.isReady(80), false, "antes do join")
	ProgressionService.registerPlayer(80)
	PlayerSessionService.onPlayerJoined({ UserId = 80, Name = "Snap" })
	assertEq(PlayerSessionService.isReady(80), true, "ready após snapshot")
	assertEq(#snapshots, 1, "um snapshot")
	local snap = snapshots[1]
	assertEq(snap.zoneId, "zone_bastion_safe", "zona")
	assertEq(snap.health, 100, "HP")
	assertEq(snap.guard, 100, "guarda")
	assertEq(snap.familyId, "umbral_aether", "família")
	assertEq(snap.dummyId, "npc_training_dummy", "dummy")
	assertEq(#snap.unlocks, 0, "sem técnicas no spawn")
	assertEq(ProgressionService.grantUnlock(80, "unlock_comet_shoulder"), true, "primeira grant")
	local after = PlayerSessionService.buildSnapshot(80, "eclipse_fist", "umbral_aether")
	assertTrue(after ~= nil, "snapshot após grant")
	if after then
		assertEq(#after.unlocks, 1, "uma flag")
		assertEq(after.unlocks[1], "unlock_comet_shoulder", "comet")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 80, Name = "Snap" })
	ProgressionService.unregisterPlayer(80)
	assertEq(PlayerSessionService.isReady(80), false, "ready limpo")
	assertEq(CombatService.getFighter(CombatService.playerFighterId(80)), nil, "fighter removido")
end)

test("fatia: ready + comet locked no spawn; grant libera 9 HP no dummy", function()
	CombatService.clear()
	CooldownService.clear(100)
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function() end,
		getUnlocks = ProgressionService.listUnlocks,
	})
	assertEq(PlayerSessionService.isReady(100), false, "antes do join")
	ProgressionService.registerPlayer(100)
	PlayerSessionService.onPlayerJoined({ UserId = 100, Name = "Comet" })
	assertEq(PlayerSessionService.isReady(100), true, "ready")
	local attacker = ResourceService.getState(100)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "spawn sem técnica")
	assertEq(lockedReason, "locked", "motivo")
	assertEq(attacker.resource, 100, "não gasta")
	assertEq(ProgressionService.grantUnlock(100, "unlock_comet_shoulder"), true, "grant")
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "comet após unlock: " .. tostring(reason))
	assertEq(attacker.resource, 82, "custo 18, sem fluxo")
	local dummy = CombatService.getFighter("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy existe")
	if dummy then
		assertEq(dummy.health, 9986, "14 de dano")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 100, Name = "Comet" })
	ProgressionService.unregisterPlayer(100)
end)

test("unlock: cadência e pulso também locked no spawn", function()
	ProgressionService.init()
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(101)
	local deps = makeAbilityDeps()
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	ProgressionService.registerPlayer(101)
	local attacker = ResourceService.createState(101, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker")
	if not attacker then
		return
	end
	local cadOk, cadReason = AbilityService.tryActivate(attacker, "broken_cadence", nil)
	assertFalse(cadOk, "cadência locked")
	assertEq(cadReason, "locked", "motivo cadência")
	local pulseOk, pulseReason = AbilityService.tryActivate(attacker, "pulse_return", nil)
	assertFalse(pulseOk, "pulso locked")
	assertEq(pulseReason, "locked", "motivo pulso")
	assertEq(attacker.resource, 100, "não gasta")
	ProgressionService.unregisterPlayer(101)
end)

test("unlock: grant comet é idempotente; flag desconhecida recusa", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(102)
	assertEq(ProgressionService.grantUnlock(102, "unlock_comet_shoulder"), true, "primeira")
	assertEq(ProgressionService.grantUnlock(102, "unlock_comet_shoulder"), false, "segunda")
	assertEq(ProgressionService.grantUnlock(102, "nao_existe"), false, "flag desconhecida")
	assertEq(ProgressionService.hasUnlock(102, "unlock_comet_shoulder"), true, "permanece")
	assertEq(#ProgressionService.listUnlocks(102), 1, "uma flag")
	ProgressionService.unregisterPlayer(102)
end)

test("unlock: leave limpa as flags", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(103)
	ProgressionService.grantUnlock(103, "unlock_comet_shoulder")
	ProgressionService.unregisterPlayer(103)
	assertEq(ProgressionService.isAbilityUnlocked(103, "comet_shoulder"), false, "após leave")
	ProgressionService.registerPlayer(103)
	assertEq(ProgressionService.isAbilityUnlocked(103, "comet_shoulder"), false, "rejoin sem persistência")
	ProgressionService.unregisterPlayer(103)
end)

-- ══ Testes: zonas e fronteira PvP ───────────────────────────────────────────
local function makeZoneDeps(events: { any }?)
	return {
		getZone = function(zoneId: string): any
			return Zones.get(zoneId)
		end,
		getAnchor = function(anchorId: string): any
			return Zones.getAnchor(anchorId)
		end,
		now = clockNow,
		onZoneEvent = function(userId: number, event: { any })
			if events then
				table.insert(events, { userId = userId, event = event })
			end
		end,
	}
end

test("dados: malha de zonas, PvP só em kind=free, âncoras da spec, spawn no bastião", function()
	assertTrue(#Zones.all() >= 9, "Bastião + transição + planície + 6 células de bioma")
	for _, zone in Zones.all() do
		if zone.pvp then
			assertEq(zone.kind, "free", "PvP só em zona livre")
		end
	end
	-- 7 âncoras persistidas de §8.3 + os 6 pontos de Estilhaço de §8.1 + 5 marcos
	-- + 2 clareiras do Fogo-fátuo + 3 da Vila Sombria.
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
		assertTrue(Zones.getAnchor(anchorId) ~= nil, "âncora obrigatória " .. anchorId)
	end
	assertEq(
		#Zones.allAnchors(),
		#required + #Zones.shardAnchors() + #Zones.wispAnchors() + #Zones.portAnchors() + 8,
		"âncoras persistidas + Estilhaço + marcos + Fátuo + Sucateiro + Vila"
	)
	assertTrue(Zones.getAnchor("anchor_veil_well") ~= nil, "poço da Vila Sombria")
	assertEq(#Zones.wispAnchors(), 2, "duas clareiras de Fogo-fátuo")
	assertEq(#Zones.portAnchors(), 2, "dois pontos de Sucateiro")
	local spawn = Zones.getAnchor("anchor_bastion_spawn")
	assertTrue(spawn ~= nil, "anchor_bastion_spawn existe")
	if spawn then
		assertEq(spawn.zoneId, "zone_bastion_safe", "spawn na zona segura")
	end
end)

test("catálogo: zona ou âncora inválida falha validação", function()
	local function withZones(zones: any)
		return pcall(function()
			CatalogService.init({
				Abilities = Abilities,
				Characters = Characters,
				EnergyFamilies = EnergyFamilies,
				Zones = zones,
			})
		end)
	end
	-- âncora aponta para zona inexistente
	local badAnchor = withZones({
		get = Zones.get,
		all = Zones.all,
		getAnchor = Zones.getAnchor,
		allAnchors = function()
			return {
				{ id = "anchor_bad", zoneId = "zona_que_nao_existe", position = { x = 0, y = 0, z = 0 } },
			}
		end,
	})
	assertFalse(badAnchor, "âncora com zona desconhecida deveria falhar")
	-- spawn default ausente
	local noSpawn = withZones({
		get = Zones.get,
		all = Zones.all,
		getAnchor = function()
			return nil
		end,
		allAnchors = function()
			return {
				{ id = "anchor_elite", zoneId = "zone_plain_free", position = { x = 0, y = 0, z = 0 } },
			}
		end,
	})
	assertFalse(noSpawn, "sem anchor_bastion_spawn deveria falhar")
	-- zona com PvP fora da planície
	local wrongPvp = withZones({
		get = Zones.get,
		all = function()
			return {
				{ id = "zone_bastion_safe", displayNameKey = "k", kind = "safe", pvp = false },
				{ id = "zone_threshold_transition", displayNameKey = "k", kind = "transition", pvp = false },
				{ id = "zone_plain_free", displayNameKey = "k", kind = "free", pvp = true },
				{ id = "zone_bad", displayNameKey = "k", kind = "free", pvp = true },
			}
		end,
		getAnchor = Zones.getAnchor,
		allAnchors = Zones.allAnchors,
	})
	assertFalse(wrongPvp, "zona extra com PvP deveria falhar")
end)

test("zona: join começa na zona segura e sem PvP", function()
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(200)
	ZoneService.registerPlayer(201)
	assertEq(ZoneService.getPlayerZone(200), "zone_bastion_safe", "zona inicial")
	assertEq(ZoneService.canPvp(200), false, "sem PvP na segura")
	assertEq(ZoneService.canPvpBetween(200, 201), false, "sem PvP entre jogadores na segura")
end)

test("zona: sem holdConfirmed recusa a primeira ida à livre", function()
	fakeNow = 6000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(210)
	local res = ZoneService.tryEnterZone(210, "zone_threshold_transition", fakeNow, {})
	assertEq(res.ok, false, "recusa")
	assertEq(res.reason, "hold_required", "motivo")
	assertEq(ZoneService.getPlayerZone(210), "zone_bastion_safe", "continua na segura")
	assertEq(ZoneService.canPvp(210), false, "sem PvP")
end)

-- docs/18 §7: a recusa por hold não pode virar parede invisível. O jogador
-- fica parado no vão do portão até segurar E; só recusa de outro tipo devolve
-- o avatar à posição anterior.
-- docs/18 §8: o playtest pelo MCP flagrou o jogador em z = −100 (planície) com
-- o HUD escrito SEGURO. Nesse estado fantasma nenhum dano entra ou sai.
test("zona: quem está fisicamente na planície é reconciliado para a zona livre", function()
	fakeNow = 7000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(310)

	-- No vão do portão continua pedindo o hold: a porta da frente não muda.
	local naTransicao = ZoneService.reconcile(310, "zone_threshold_transition", fakeNow)
	assertEq(naTransicao.ok, false, "transição ainda exige hold")
	assertEq(naTransicao.reason, "hold_required", "motivo do prompt")
	assertEq(ZoneService.getPlayerZone(310), "zone_bastion_safe", "continua seguro no vão")

	-- Já fisicamente na planície: aceita, com a proteção da travessia.
	local naPlanicie = ZoneService.reconcile(310, "zone_plain_free", fakeNow + 1)
	assertTrue(naPlanicie.ok, "planície é aceita")
	assertEq(ZoneService.getPlayerZone(310), "zone_plain_free", "zona lógica acompanha o mundo")
	assertTrue(ZoneService.isInTransition(310, fakeNow + 1), "ganha a proteção de travessia")
	assertFalse(ZoneService.canPvp(310), "protegido não entra em PvP na hora")

	-- Volta para a segura continua livre (sem combate PvP recente).
	local volta = ZoneService.reconcile(310, "zone_bastion_safe", fakeNow + 30)
	assertTrue(volta.ok, "voltar para a segura")
	assertEq(ZoneService.getPlayerZone(310), "zone_bastion_safe", "voltou")
end)

test("zona: hold_required não devolve o jogador; lockout e recusa inválida devolvem", function()
	assertFalse(ZoneService.shouldRestorePosition("hold_required"), "hold não empurra de volta")
	assertTrue(ZoneService.shouldRestorePosition("zone_lockout"), "lockout devolve")
	assertTrue(ZoneService.shouldRestorePosition("invalid_crossing"), "travessia inválida devolve")
	assertFalse(ZoneService.shouldRestorePosition(nil), "sem motivo não devolve")
end)

test("zona: hold autoritativo exige 0,6 s e o mesmo portão", function()
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(211)
	local north = { x = 0, y = 0, z = -32 }
	local west = { x = -40, y = 0, z = 0 }
	assertTrue(
		ZoneService.handleCrossingHold(211, "zone_threshold_transition", "begin", 6100, north).ok,
		"begin junto ao norte"
	)
	local early = ZoneService.handleCrossingHold(211, "zone_threshold_transition", "complete", 6100.59, north)
	assertFalse(early.ok, "complete prematuro recusado")
	assertEq(early.reason, "hold_incomplete", "motivo estável")
	assertTrue(ZoneService.handleCrossingHold(211, "zone_threshold_transition", "begin", 6101, north).ok, "novo begin")
	local swapped = ZoneService.handleCrossingHold(211, "zone_threshold_transition", "complete", 6101.6, west)
	assertFalse(swapped.ok, "não troca de portão no complete")
	assertEq(swapped.reason, "target_mismatch", "mesmo alvo físico")
	assertTrue(
		ZoneService.handleCrossingHold(211, "zone_threshold_transition", "begin", 6102, north).ok,
		"terceiro begin"
	)
	local complete = ZoneService.handleCrossingHold(211, "zone_threshold_transition", "complete", 6102.6, north)
	assertTrue(complete.ok, "0,6 s autoritativos aceitos")
	assertEq(complete.anchorId, "anchor_gate_north", "portão correlacionado")
	assertEq(ZoneService.getPlayerZone(211), "zone_bastion_safe", "hold sozinho não declara posição")
end)

test("zona: hold revalida distância, expira e cancel consome pending", function()
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(212)
	local north = { x = 0, y = 0, z = -32 }
	local far = { x = 40, y = 0, z = 20 }
	local tooFar = ZoneService.handleCrossingHold(212, "zone_threshold_transition", "begin", 6200, far)
	assertEq(tooFar.reason, "too_far", "posição do servidor é obrigatória")
	ZoneService.handleCrossingHold(212, "zone_threshold_transition", "begin", 6201, north)
	local expired = ZoneService.handleCrossingHold(212, "zone_threshold_transition", "complete", 6204.1, north)
	assertEq(expired.reason, "hold_expired", "pending tem prazo curto")
	ZoneService.handleCrossingHold(212, "zone_threshold_transition", "begin", 6205, north)
	assertTrue(
		ZoneService.handleCrossingHold(212, "zone_threshold_transition", "cancel", 6205.1, north).ok,
		"cancel aceito"
	)
	local afterCancel = ZoneService.handleCrossingHold(212, "zone_threshold_transition", "complete", 6206, north)
	assertEq(afterCancel.reason, "hold_required", "cancel remove pending")
end)

test("zona: segura nunca pula direto para livre e respawn força Bastião", function()
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(213)
	local direct = ZoneService.tryEnterZone(213, "zone_plain_free", 6300, { holdConfirmed = true })
	assertFalse(direct.ok, "aresta segura para livre é inválida")
	assertEq(direct.reason, "invalid_crossing", "sem salto de volume")
	ZoneService.tryEnterZone(213, "zone_threshold_transition", 6301, { holdConfirmed = true })
	ZoneService.tryEnterZone(213, "zone_plain_free", 6302, {})
	ZoneService.markPvpCombat(213, 6303)
	ZoneService.forceRespawnSafe(213)
	assertEq(ZoneService.getPlayerZone(213), "zone_bastion_safe", "respawn ignora lockout da vida anterior")
	local transition = ZoneService.tryEnterZone(213, "zone_threshold_transition", 6304, { holdConfirmed = true })
	assertTrue(transition.ok, "lockout anterior foi limpo")
end)

test("zona: com hold entra em transição 5 s e canPvp false", function()
	fakeNow = 7000
	local events: { any } = {}
	ZoneService.init(makeZoneDeps(events))
	ZoneService.registerPlayer(220)
	local res = ZoneService.tryEnterZone(220, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(res.ok, true, "aceita com hold: " .. tostring(res.reason))
	assertEq(ZoneService.getPlayerZone(220), "zone_threshold_transition", "em transição")
	assertEq(ZoneService.canPvp(220), false, "sem PvP durante a transição")
	local crossed = ZoneService.tryEnterZone(220, "zone_plain_free", fakeNow + 1, {})
	assertEq(crossed.ok, true, "cruza para a livre: " .. tostring(crossed.reason))
	assertEq(ZoneService.getPlayerZone(220), "zone_plain_free", "na livre")
	assertEq(ZoneService.canPvp(220), false, "proteção de 5 s ainda ativa")
	fakeNow = 7000 + 5
	assertEq(ZoneService.canPvp(220), true, "PvP ligado após 5 s")
	ZoneService.registerPlayer(221)
	assertEq(ZoneService.canPvpBetween(220, 221), false, "parceiro ainda na segura")
	ZoneService.tryEnterZone(221, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	ZoneService.tryEnterZone(221, "zone_plain_free", fakeNow + 1, {})
	fakeNow = 7011
	assertEq(ZoneService.canPvpBetween(220, 221), true, "ambos na livre: PvP")
	assertEq(#events, 4, "um evento por travessia")
	-- Planície → bosque: duas livres, PvP segue.
	assertTrue(ZoneService.tryEnterZone(221, "zone_echo_woods", fakeNow + 2, {}).ok, "entra no bosque")
	assertEq(ZoneService.canPvp(221), true, "bosque é PvP")
	-- Bastião → academia: duas seguras, sem hold.
	assertTrue(ZoneService.tryEnterZone(220, "zone_academy_safe", fakeNow + 2, {}).ok, "entra na academia")
	assertEq(ZoneService.canPvp(220), false, "academia é segura")
end)

test("zona: ação hostil na transição encerra a proteção na hora", function()
	fakeNow = 8000
	local events: { any } = {}
	ZoneService.init(makeZoneDeps(events))
	ZoneService.registerPlayer(230)
	ZoneService.tryEnterZone(230, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(ZoneService.canPvp(230), false, "protegido na transição")
	ZoneService.markHostileAction(230, fakeNow + 1)
	assertEq(ZoneService.getPlayerZone(230), "zone_plain_free", "ativa PvP indo à livre")
	assertEq(ZoneService.canPvp(230), true, "ação hostil encerra a proteção")
	ZoneService.notifyHostileTransition(230, fakeNow + 1)
	assertEq(#events, 2, "travessia hostil emite a passagem final")
	assertEq(events[2].event.from, "zone_threshold_transition", "evento parte da faixa")
	assertEq(events[2].event.to, "zone_plain_free", "evento confirma a planície")
	assertEq(events[2].event.pvp, true, "HUD recebe PvP ativo")
end)

test("zona: ação hostil na segura não marca lockout PvP", function()
	fakeNow = 8500
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(232)
	ZoneService.markHostileAction(232, fakeNow)
	local res = ZoneService.tryEnterZone(232, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(res.ok, true, "treino no dummy não bloqueia a fronteira: " .. tostring(res.reason))
	assertEq(ZoneService.getPlayerZone(232), "zone_threshold_transition", "entrou na transição")
end)

test("zona: voltar da transição sem hostil é livre", function()
	fakeNow = 8600
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(233)
	ZoneService.tryEnterZone(233, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	local back = ZoneService.tryEnterZone(233, "zone_bastion_safe", fakeNow + 1, {})
	assertEq(back.ok, true, "voltar é livre: " .. tostring(back.reason))
	assertEq(ZoneService.getPlayerZone(233), "zone_bastion_safe", "de volta")
	assertEq(ZoneService.canPvp(233), false, "sem PvP")
end)

test("zona: sinais da fronteira retornam os 5 IDs juntos", function()
	local SIGNAL_IDS: { [string]: boolean } = {
		physical_gate = true,
		lighting_material = true,
		ui_banner = true,
		audio_haptic = true,
		persistent_indicator = true,
	}
	local forward = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free")
	assertTrue(forward ~= nil, "segura→livre tem sinais")
	if forward then
		assertEq(#forward, 5, "5 sinais")
		for _, s in forward do
			assertTrue(SIGNAL_IDS[s] == true, "sinal " .. s)
		end
	end
	local back = ZoneService.getFrontierSignals("zone_plain_free", "zone_bastion_safe")
	assertTrue(back ~= nil and #back == 5, "volta também tem 5 sinais")
	assertEq(ZoneService.getFrontierSignals("zone_bastion_safe", "zone_bastion_safe"), nil, "sem sinais na mesma zona")
end)

test("zona: evento da travessia carrega payload completo", function()
	fakeNow = 9000
	local events: { any } = {}
	ZoneService.init(makeZoneDeps(events))
	ZoneService.registerPlayer(235)
	ZoneService.tryEnterZone(235, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	assertEq(#events, 1, "evento emitido")
	local first = events[1].event
	assertEq(first.from, "zone_bastion_safe", "de")
	assertEq(first.to, "zone_threshold_transition", "para")
	assertEq(first.pvp, false, "transição não é PvP")
	assertEq(#first.signals, 5, "sinais no evento")
	assertEq(first.holdConfirmed, true, "hold confirmado")
	assertEq(first.instant, 9000, "instante")
	local crossed = ZoneService.tryEnterZone(235, "zone_plain_free", fakeNow + 1, {})
	assertEq(crossed.event.pvp, true, "destino livre marca PvP")
end)

test("zona: combate PvP recente bloqueia reentrada na segura por 15 s", function()
	fakeNow = 10000
	ZoneService.init(makeZoneDeps())
	ZoneService.registerPlayer(240)
	ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, { holdConfirmed = true })
	ZoneService.tryEnterZone(240, "zone_plain_free", fakeNow + 1, {})
	fakeNow = 10000 + 6
	ZoneService.markPvpCombat(240, fakeNow)
	local blocked = ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, {})
	assertEq(blocked.ok, false, "bloqueado")
	assertEq(blocked.reason, "combat_lockout", "motivo")
	assertTrue(blocked.event ~= nil and blocked.event.lockoutRemaining ~= nil, "evento com timer")
	assertTrue(
		blocked.lockoutRemaining ~= nil and blocked.lockoutRemaining > 0 and blocked.lockoutRemaining <= 15,
		"timer visível"
	)
	fakeNow = 10000 + 6 + 15
	local free = ZoneService.tryEnterZone(240, "zone_threshold_transition", fakeNow, {})
	assertEq(free.ok, true, "após 15 s libera: " .. tostring(free.reason))
	ZoneService.tryEnterZone(240, "zone_bastion_safe", fakeNow + 1, {})
	assertEq(ZoneService.getPlayerZone(240), "zone_bastion_safe", "de volta à segura")
	assertEq(ZoneService.canPvp(240), false, "sem PvP na segura")
end)

test("zona: projétil/área não cruza a fronteira com dano", function()
	ZoneService.init(makeZoneDeps())
	assertEq(ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_bastion_safe"), false, "livre→segura")
	assertEq(
		ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_threshold_transition"),
		false,
		"livre→transição"
	)
	assertEq(
		ZoneService.canDamageCrossBoundary("zone_bastion_safe", "zone_threshold_transition"),
		true,
		"dentro do lado seguro"
	)
	assertEq(ZoneService.canDamageCrossBoundary("zone_plain_free", "zone_plain_free"), true, "mesma zona livre")
	assertEq(ZoneService.canDamageCrossBoundary("zone_bastion_safe", "zone_bastion_safe"), true, "mesma zona segura")
end)

test("dados: ZoneEvent registrado como remote S→C", function()
	local zc = Remotes.Contracts.get(Remotes.Names.ZoneEvent)
	assertTrue(zc ~= nil, "ZoneEvent deveria ter contrato")
	if zc then
		assertEq(zc.direction, "ServerToClient", "direção")
		assertEq(zc.version, 1, "versão")
		assertTrue(zc.payload:find("signals") ~= nil, "payload com signals")
		assertTrue(zc.payload:find("holdConfirmed") ~= nil, "evento autoritativo confirma hold")
	end
end)

test("dados: ZoneCrossingIntent registrado como remote C→S", function()
	local zc = Remotes.Contracts.get(Remotes.Names.ZoneCrossingIntent)
	assertTrue(zc ~= nil, "ZoneCrossingIntent deveria ter contrato")
	if zc then
		assertEq(zc.direction, "ClientToServer", "direção")
		assertEq(zc.version, 2, "versão")
		assertTrue(zc.payload:find("toZoneId") ~= nil, "payload com toZoneId")
		assertTrue(zc.payload:find("phase") ~= nil, "payload com begin/complete/cancel")
		assertTrue(zc.payload:find("holdConfirmed") == nil, "cliente não declara holdConfirmed")
	end
end)

test("fatia: sessão Ready com ZoneService e comet intacto", function()
	CombatService.clear()
	CooldownService.clear(250)
	fakeNow = 11000
	ProgressionService.init()
	ZoneService.init(makeZoneDeps())
	ResourceService.init(makeResourceDeps())
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	local snapshots: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function(_player: any, snap: { any })
			table.insert(snapshots, snap)
		end,
		getPlayerZone = ZoneService.getPlayerZone,
		getUnlocks = ProgressionService.listUnlocks,
	})
	ProgressionService.registerPlayer(250)
	ZoneService.registerPlayer(250)
	PlayerSessionService.onPlayerJoined({ UserId = 250, Name = "Zona" })
	assertEq(PlayerSessionService.isReady(250), true, "ready")
	assertEq(#snapshots, 1, "snapshot")
	local snap = snapshots[1]
	assertEq(snap.zoneId, "zone_bastion_safe", "zona do snapshot via ZoneService")
	assertEq(#snap.unlocks, 0, "sem técnicas no spawn")
	local attacker = ResourceService.getState(250)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "locked no spawn")
	assertEq(lockedReason, "locked", "motivo")
	assertEq(ProgressionService.grantUnlock(250, "unlock_comet_shoulder"), true, "grant")
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "comet após unlock: " .. tostring(reason))
	local dummy = CombatService.getFighter("npc_training_dummy")
	assertTrue(dummy ~= nil, "dummy existe")
	if dummy then
		assertEq(dummy.health, 9986, "dummy intacto")
	end
	PlayerSessionService.onPlayerLeft({ UserId = 250, Name = "Zona" })
	ZoneService.unregisterPlayer(250)
	ProgressionService.unregisterPlayer(250)
end)

-- ══ Testes: item 7 — Locale, XP e objetivo 1 ────────────────────────────────
local function makeQuestDeps(events: { any }?): any
	return {
		getQuest = Quests.get,
		chain = Quests.chain,
		awardXp = ProgressionService.awardXp,
		grantUnlock = ProgressionService.grantUnlock,
		now = clockNow,
		onQuestEvent = function(userId: number, event: any)
			if events then
				table.insert(events, { userId = userId, event = event })
			end
		end,
	}
end

test("dados: Locale cobre as chaves da fatia em PT-BR e EN", function()
	local required = {
		"character.eclipse_fist.name",
		"family.umbral_aether.name",
		"ability.comet_shoulder.name",
		"ability.broken_cadence.name",
		"ability.pulse_return.name",
		"zone.bastion.name",
		"zone.plain.name",
		"hud.zone_safe",
		"hud.pvp_active",
		"hud.pvp_hold",
		"ftue.dummy_hint",
		"quest.hunt.tracker",
		"npc.threshold_instructor.name",
	}
	for _, key in required do
		assertTrue(Locale.hasKey(key), "chave ausente: " .. key)
		assertTrue(Locale.get(key, "en") ~= key, "sem tradução EN: " .. key)
	end
	assertEq(Locale.defaultLocale(), "pt-br", "default PT-BR")
	assertEq(Locale.get("character.eclipse_fist.name"), "Punho do Eclipse", "nome público")
	assertEq(Locale.get("chave.inexistente"), "chave.inexistente", "chave desconhecida devolve a própria chave")
end)

test("dados: tracker formata progresso e XP da task", function()
	assertEq(
		Locale.format("quest.hunt.tracker", { n = 0, req = 3, xp = 40 }),
		"Estilhaços: 0/3  ·  +40 XP",
		"0/3 + XP"
	)
	assertEq(
		Locale.format("quest.hunt.tracker", { n = 2, req = 3, xp = 40 }),
		"Estilhaços: 2/3  ·  +40 XP",
		"2/3 + XP"
	)
end)

test("dados: objetivo 1 é 3 Estilhaços, +40 XP e unlock do Cometa", function()
	local def = Quests.get("quest_hunt")
	assertTrue(def ~= nil, "quest_hunt deveria existir")
	if not def then
		return
	end
	assertEq(def.kind, "kill", "kind")
	assertEq(def.targetId, "enemy_wandering_shard", "alvo")
	assertEq(def.requiredCount, 3, "3 kills")
	assertEq(def.xpReward, 40, "+40 XP")
	assertEq(def.unlockFlag, "unlock_comet_shoulder", "unlock")
	assertEq(def.acceptFlag, "quest_hunt_accepted", "flag de aceite")
	assertEq(def.giverNpcId, "npc_threshold_instructor", "ofertante")
	assertEq(def.autoAcceptAfterSeconds, 90, "aceite forçado em 90 s")
end)

test("catálogo: objetivo com alvo ou ofertante desconhecido falha validação", function()
	local function withQuests(all: any)
		return pcall(function()
			CatalogService.init({
				Abilities = Abilities,
				Characters = Characters,
				EnergyFamilies = EnergyFamilies,
				Npcs = Npcs,
				Zones = Zones,
				Quests = {
					get = Quests.get,
					all = all,
					chain = Quests.chain,
				},
			})
		end)
	end
	local base = {
		id = "quest_bad",
		trackerKey = "quest.hunt.tracker",
		kind = "kill",
		targetId = "enemy_wandering_shard",
		requiredCount = 3,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 90,
		xpReward = 40,
		unlockFlag = "unlock_comet_shoulder",
		acceptFlag = "quest_hunt_accepted",
		enabled = true,
	}
	local function variant(overrides: { [string]: any }): any
		local copy: { [string]: any } = table.clone(base)
		for k, v in overrides do
			copy[k] = v
		end
		return function()
			return { copy }
		end
	end
	assertFalse(withQuests(variant({ targetId = "enemy_que_nao_existe" })), "alvo desconhecido deveria falhar")
	assertFalse(withQuests(variant({ giverNpcId = "npc_fantasma" })), "ofertante desconhecido deveria falhar")
	assertFalse(withQuests(variant({ requiredCount = 0 })), "requiredCount 0 deveria falhar")
	assertFalse(withQuests(variant({ acceptFlag = "" })), "acceptFlag vazia deveria falhar")
end)

test("catálogo: chave de UI sem entrada no Locale falha validação", function()
	local badNpcs = {
		get = Npcs.get,
		all = function()
			local out: { any } = {}
			for _, npc in Npcs.all() do
				table.insert(out, npc)
			end
			table.insert(out, {
				id = "npc_sem_locale",
				displayNameKey = "npc.sem_locale.name",
				kind = "instructor",
				maxHealth = 1,
				maxGuard = 0,
				attackDamage = 0,
				attackRange = 0,
				attackPeriodSeconds = 0,
				telegraphMs = 0,
				grantsXp = false,
				enabled = true,
			})
			return out
		end,
	}
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = badNpcs,
			Zones = Zones,
			Locale = Locale,
		})
	end)
	assertFalse(ok, "displayNameKey sem tradução deveria falhar")
end)

test("XP: kill do Estilhaço credita 25 não consolidado", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(300)
	local shard = Npcs.get("enemy_wandering_shard")
	assertTrue(shard ~= nil, "estilhaço no catálogo")
	local award = ProgressionService.creditNpcKill(300, shard, "anchor_gate_north")
	assertEq(award.granted, 25, "XP do kill")
	assertEq(ProgressionService.getUnconsolidatedXp(300), 25, "não consolidado")
	assertEq(ProgressionService.getAnchorKills(300, "anchor_gate_north"), 1, "kills na âncora")
	-- Dummy não dá XP
	local dummy = Npcs.get("npc_training_dummy")
	local none = ProgressionService.creditNpcKill(300, dummy, "anchor_training")
	assertEq(none.granted, 0, "dummy não credita")
	assertEq(none.reason, "no_xp_source", "motivo")
end)

test("XP: retorno decrescente por âncora — 6×25, depois 12, depois 0", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(301)
	local shard = Npcs.get("enemy_wandering_shard")
	for i = 1, 6 do
		local award = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
		assertEq(award.granted, 25, ("kill %d ainda paga cheio"):format(i))
	end
	assertEq(ProgressionService.getUnconsolidatedXp(301), 150, "6 kills = 150")
	for i = 7, 12 do
		local award = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
		assertEq(award.granted, 12, ("kill %d paga reduzido"):format(i))
	end
	assertEq(ProgressionService.getUnconsolidatedXp(301), 222, "12 kills = 150 + 72")
	local zeroed = ProgressionService.creditNpcKill(301, shard, "anchor_gate_north")
	assertEq(zeroed.granted, 0, "13º kill não paga")
	assertEq(zeroed.reason, "diminished", "motivo")
	assertEq(ProgressionService.getUnconsolidatedXp(301), 222, "saldo intacto")
end)

test("XP: o decréscimo é por âncora, não global", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(302)
	local shard = Npcs.get("enemy_wandering_shard")
	for _ = 1, 6 do
		ProgressionService.creditNpcKill(302, shard, "anchor_gate_north")
	end
	local other = ProgressionService.creditNpcKill(302, shard, "anchor_gate_west")
	assertEq(other.granted, 25, "outra âncora paga cheio")
	local same = ProgressionService.creditNpcKill(302, shard, "anchor_gate_north")
	assertEq(same.granted, 12, "âncora esgotada continua reduzida")
end)

test("XP: teto de emissão da sessão é 800", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(303)
	assertEq(ProgressionService.sessionXpCap(), 800, "teto")
	local first = ProgressionService.awardXp(303, 790)
	assertEq(first.granted, 790, "primeira emissão")
	local partial = ProgressionService.awardXp(303, 40)
	assertEq(partial.granted, 10, "corta no teto")
	assertEq(partial.withheld, 30, "recusado")
	assertEq(partial.reason, "session_cap", "motivo")
	local blocked = ProgressionService.awardXp(303, 25)
	assertEq(blocked.granted, 0, "nada além do teto")
	assertEq(ProgressionService.getUnconsolidatedXp(303), 800, "saldo no teto")
	assertEq(ProgressionService.awardXp(303, -5).granted, 0, "valor negativo não credita")
	assertEq(ProgressionService.awardXp(999, 25).reason, "unknown_player", "jogador desconhecido")
end)

test("objetivo: aceite no Instrutor marca a flag e abre o tracker", function()
	fakeNow = 20000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(310)
	QuestService.registerPlayer(310, fakeNow)
	assertEq(QuestService.getTracker(310), nil, "sem tracker antes do aceite")
	local ok, reason = QuestService.tryAcceptFromNpc(310, "npc_threshold_instructor", fakeNow)
	assertTrue(ok, "aceite: " .. tostring(reason))
	assertTrue(ProgressionService.hasUnlock(310, "quest_hunt_accepted"), "flag de aceite")
	local tracker = QuestService.getTracker(310)
	assertTrue(tracker ~= nil, "tracker visível")
	if tracker then
		assertEq(tracker.trackerKey, "quest.hunt.tracker", "chave do tracker")
		assertEq(tracker.progress, 0, "0/3")
		assertEq(tracker.required, 3, "3 kills")
	end
	assertEq(#events, 1, "um evento de aceite")
	assertEq(events[1].event.acceptSource, "npc", "aceite pelo NPC")
	-- A cadeia é sequencial: com o objetivo 1 ativo, o NPC não oferece o 2.
	local again, againReason = QuestService.tryAcceptFromNpc(310, "npc_threshold_instructor", fakeNow)
	assertFalse(again, "segundo aceite não repete")
	assertEq(againReason, "already_active", "objetivo 1 ainda ativo")
	assertFalse(QuestService.tryAcceptFromNpc(310, "npc_desconhecido", fakeNow), "NPC errado não oferta")
end)

test("objetivo: kill antes do aceite não conta", function()
	fakeNow = 21000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(311)
	QuestService.registerPlayer(311, fakeNow)
	local events = QuestService.creditKill(311, "enemy_wandering_shard", fakeNow + 1)
	assertEq(#events, 0, "sem progresso sem objetivo ativo")
	local progress = QuestService.getProgress(311, "quest_hunt")
	assertTrue(progress ~= nil, "estado existe")
	if progress then
		assertEq(progress.state, "offered", "ainda ofertado")
		assertEq(progress.progress, 0, "sem progresso")
	end
end)

test("objetivo: tracker aparece sozinho 90 s depois de ignorar o NPC", function()
	fakeNow = 22000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(312)
	QuestService.registerPlayer(312, fakeNow)
	QuestService.tick(312, fakeNow + 89)
	assertEq(QuestService.getTracker(312), nil, "antes de 90 s o tracker não aparece")
	QuestService.tick(312, fakeNow + 90)
	local tracker = QuestService.getTracker(312)
	assertTrue(tracker ~= nil, "tracker forçado após 90 s")
	assertTrue(ProgressionService.hasUnlock(312, "quest_hunt_accepted"), "flag do aceite forçado")
	assertEq(#events, 1, "um evento")
	assertEq(events[1].event.acceptSource, "timeout", "origem timeout")
	QuestService.tick(312, fakeNow + 200)
	assertEq(#events, 1, "tick é idempotente")
end)

test("objetivo: 3º kill completa, dá +40 XP e destrava o Ombro Cometa", function()
	fakeNow = 23000
	ProgressionService.init()
	local events: { any } = {}
	QuestService.init(makeQuestDeps(events))
	ProgressionService.registerPlayer(313)
	QuestService.registerPlayer(313, fakeNow)
	QuestService.tryAcceptFromNpc(313, "npc_threshold_instructor", fakeNow)

	local first = QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 1)
	assertEq(#first, 1, "evento de progresso")
	assertEq(first[1].progress, 1, "1/3")
	assertEq(first[1].state, "active", "ainda ativo")
	assertFalse(ProgressionService.hasUnlock(313, "unlock_comet_shoulder"), "sem unlock em 1/3")

	QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 2)
	local third = QuestService.creditKill(313, "enemy_wandering_shard", fakeNow + 3)
	assertEq(#third, 1, "evento de conclusão")
	assertEq(third[1].state, "completed", "completo")
	assertEq(third[1].progress, 3, "3/3")
	assertEq(third[1].xpGranted, 40, "+40 XP do objetivo")
	assertEq(third[1].unlockFlag, "unlock_comet_shoulder", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(313, "unlock_comet_shoulder"), "Cometa destravado")
	assertEq(ProgressionService.getUnconsolidatedXp(313), 40, "só o XP do objetivo (kills entram pelo NPC)")
	assertEq(QuestService.getTracker(313), nil, "tracker some ao completar")
end)

test("objetivo: kill depois de completo não repete prêmio", function()
	fakeNow = 24000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(314)
	QuestService.registerPlayer(314, fakeNow)
	QuestService.tryAcceptFromNpc(314, "npc_threshold_instructor", fakeNow)
	for i = 1, 3 do
		QuestService.creditKill(314, "enemy_wandering_shard", fakeNow + i)
	end
	assertEq(ProgressionService.getUnconsolidatedXp(314), 40, "prêmio pago uma vez")
	local extra = QuestService.creditKill(314, "enemy_wandering_shard", fakeNow + 10)
	assertEq(#extra, 0, "sem evento novo")
	assertEq(ProgressionService.getUnconsolidatedXp(314), 40, "XP não dobra")
	local progress = QuestService.getProgress(314, "quest_hunt")
	if progress then
		assertEq(progress.progress, 3, "progresso não passa do requerido")
	end
	-- Alvo fora do objetivo não conta
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(315)
	QuestService.registerPlayer(315, fakeNow)
	QuestService.tryAcceptFromNpc(315, "npc_threshold_instructor", fakeNow)
	assertEq(#QuestService.creditKill(315, "npc_training_dummy", fakeNow + 1), 0, "dummy não conta no objetivo")
end)

test("combate: killed só na transição vivo → morto", function()
	CombatService.clear()
	local attacker = CombatService.createFighter("player:400", "player", 100, 100)
	local shard = CombatService.createFighter("enemy_wandering_shard@anchor_gate_north#1", "npc", 10, 0)
	local hit = CombatService.tryLight(attacker, shard, 100, "front")
	assertEq(hit.damage, 6, "primeiro golpe")
	assertEq(hit.killed, nil, "ainda vivo")
	local kill = CombatService.tryLight(attacker, shard, 100.2, "front")
	assertEq(shard.health, 0, "morto")
	assertEq(kill.killed, true, "kill sinalizado")
	assertEq(shard.diedAt, 100.2, "instante da morte")
	local corpse = CombatService.tryLight(attacker, shard, 100.4, "front")
	assertEq(corpse.killed, nil, "golpe em morto não repete o kill")
	assertEq(shard.diedAt, 100.2, "diedAt não é re-carimbado (não empurra o respawn)")
end)

test("dados: InteractionIntent C→S e StateDelta S→C", function()
	local interaction = Remotes.Contracts.get(Remotes.Names.InteractionIntent)
	assertTrue(interaction ~= nil, "InteractionIntent deveria ter contrato")
	if interaction then
		assertEq(interaction.direction, "ClientToServer", "direção")
		assertEq(interaction.version, 2, "versão")
		assertTrue(interaction.payload:find("npcId") ~= nil, "payload com npcId")
		assertTrue(interaction.payload:find("phase") ~= nil, "hold com fase autoritativa")
		assertFalse(interaction.payload:find("reward") ~= nil, "cliente não informa recompensa")
	end
	local delta = Remotes.Contracts.get(Remotes.Names.StateDelta)
	assertTrue(delta ~= nil, "StateDelta deveria ter contrato")
	if delta then
		assertEq(delta.direction, "ServerToClient", "direção")
		assertTrue(delta.payload:find("objective") ~= nil, "payload com objective")
		assertTrue(delta.payload:find("unconsolidatedXp") ~= nil, "payload com XP")
	end
	local snapshot = Remotes.Contracts.get(Remotes.Names.SessionSnapshot)
	assertTrue(snapshot ~= nil and snapshot.payload:find("objective") ~= nil, "snapshot carrega objetivo")
end)

test("fatia: roteiro 0–5 min — spawn locked, objetivo, 3 kills e Cometa liberado", function()
	CombatService.clear()
	CooldownService.clear(320)
	fakeNow = 25000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ZoneService.init(makeZoneDeps())
	ResourceService.init(makeResourceDeps())
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)

	local snapshots: { any } = {}
	PlayerSessionService.init({
		getCharacter = function(id: string): any
			return Characters.get(id)
		end,
		getFamily = function(id: string): any
			return EnergyFamilies.get(id)
		end,
		createResourceState = function(userId: number, familyId: string)
			return ResourceService.createState(userId, familyId)
		end,
		removeResourceState = ResourceService.removeState,
		getResourceState = ResourceService.getState,
		clearCooldowns = function(userId: number)
			CooldownService.clear(userId)
		end,
		releaseProfile = function() end,
		createFighter = CombatService.createFighter,
		removeFighter = CombatService.removeFighter,
		getFighter = CombatService.getFighter,
		playerFighterId = CombatService.playerFighterId,
		onSnapshot = function(_player: any, snap: { any })
			table.insert(snapshots, snap)
		end,
		getPlayerZone = ZoneService.getPlayerZone,
		getUnlocks = ProgressionService.listUnlocks,
		getObjective = QuestService.getTracker,
		getUnconsolidatedXp = ProgressionService.getUnconsolidatedXp,
	})

	-- 0–15 s: spawn na segura, sem técnicas e sem objetivo aceito
	ProgressionService.registerPlayer(320)
	ZoneService.registerPlayer(320)
	QuestService.registerPlayer(320, fakeNow)
	ProgressionService.grantUnlock(320, "ftue_spawned")
	PlayerSessionService.onPlayerJoined({ UserId = 320, Name = "Roteiro" })
	assertEq(#snapshots, 1, "snapshot")
	assertEq(snapshots[1].objective, nil, "sem objetivo no spawn")
	assertEq(snapshots[1].unconsolidatedXp, 0, "sem XP no spawn")
	local attacker = ResourceService.getState(320)
	assertTrue(attacker ~= nil, "estado de recurso")
	if not attacker then
		return
	end
	local locked, lockedReason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertFalse(locked, "Cometa locked no spawn")
	assertEq(lockedReason, "locked", "motivo")

	-- ~60 s–3 min: NPC oferece o objetivo 1
	assertTrue(QuestService.tryAcceptFromNpc(320, "npc_threshold_instructor", fakeNow + 60), "aceite no NPC")

	-- 3–5 min: cruzar a fronteira e matar 3 Estilhaços
	ZoneService.tryEnterZone(320, "zone_threshold_transition", fakeNow + 70, { holdConfirmed = true })
	ZoneService.tryEnterZone(320, "zone_plain_free", fakeNow + 71, {})
	assertEq(ZoneService.getPlayerZone(320), "zone_plain_free", "na planície")
	local shardDef = Npcs.get("enemy_wandering_shard")
	for i = 1, 3 do
		ProgressionService.creditNpcKill(320, shardDef, "anchor_gate_north")
		QuestService.creditKill(320, "enemy_wandering_shard", fakeNow + 100 + i)
	end
	-- 3 × 25 (kills) + 40 (objetivo)
	assertEq(ProgressionService.getUnconsolidatedXp(320), 115, "XP dos kills + objetivo")
	assertTrue(ProgressionService.hasUnlock(320, "unlock_comet_shoulder"), "Cometa destravado no 3º kill")
	assertEq(QuestService.getTracker(320), nil, "tracker some")

	-- 5 min: Cometa utilizável e cobrado
	local ok, reason = AbilityService.tryActivate(attacker, "comet_shoulder", nil)
	assertTrue(ok, "Cometa após o objetivo: " .. tostring(reason))
	assertEq(attacker.resource, 82, "custo 18")
	local dummy = CombatService.getFighter("npc_training_dummy")
	if dummy then
		assertEq(dummy.health, 9986, "dano 14 no alvo")
	end
	-- As outras duas técnicas continuam trancadas
	assertFalse(ProgressionService.hasUnlock(320, "unlock_broken_cadence"), "Cadência ainda locked (item 9)")
	assertFalse(ProgressionService.hasUnlock(320, "unlock_pulse_return"), "Pulso ainda locked (item 10)")

	-- leave: XP da sessão some (persistência é o item 11)
	PlayerSessionService.onPlayerLeft({ UserId = 320, Name = "Roteiro" })
	QuestService.unregisterPlayer(320)
	ZoneService.unregisterPlayer(320)
	ProgressionService.unregisterPlayer(320)
	assertEq(ProgressionService.getUnconsolidatedXp(320), 0, "sem persistência ainda")
	assertEq(QuestService.getProgress(320, "quest_hunt"), nil, "estado do objetivo limpo")
end)

-- ══ Testes: camada espacial (greybox, hitbox, lunge, AI) ────────────────────
local function vec(x: number, y: number, z: number): any
	return { x = x, y = y, z = z }
end

test("movimento: caminhada legítima consome e repõe orçamento horizontal", function()
	PlayerMotionGuard.init()
	assertTrue(PlayerMotionGuard.register(1101, vec(0, 2, 0), 10), "registro inicial")
	local firstOk, firstPosition = PlayerMotionGuard.authorize(1101, vec(4, 7, 0), 10.25, 16)
	assertTrue(firstOk, "primeiro passo dentro do burst")
	assertEq((firstPosition :: any).y, 7, "altura aceita é preservada")
	local secondOk, secondPosition = PlayerMotionGuard.authorize(1101, vec(8, 3, 0), 10.5, 16)
	assertTrue(secondOk, "WalkSpeed repõe quatro studs em 250 ms")
	assertEq((secondPosition :: any).x, 8, "posição horizontal aceita")
	assertEq((secondPosition :: any).y, 3, "nova altura fica no registro")
end)

test("combate: morto não inicia dash nem i-frame", function()
	CombatService.clear()
	local fighter = CombatService.createFighter("player:dead-dash", "player", 100, 100)
	fighter.health = 0
	local ok, reason = CombatService.tryDash(fighter, 10)
	assertFalse(ok, "morto não desloca")
	assertEq(reason, "dead", "motivo estável")
	assertEq(fighter.iframeUntil, 0, "sem iframe")
	assertEq(fighter.dashCooldownUntil, 0, "sem cooldown")
end)

test("movimento: burst inicial não autoriza teleport acima de 8 studs", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1102, vec(0, 0, 0), 20)
	local ok, reason = PlayerMotionGuard.authorize(1102, vec(8.01, 0, 0), 20, 16)
	assertFalse(ok, "teleport recusado")
	assertEq(reason, "movement_budget", "motivo estável")
end)

test("movimento: orçamento recupera proporcionalmente ao WalkSpeed", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1103, vec(0, 0, 0), 30)
	assertTrue(PlayerMotionGuard.authorize(1103, vec(8, 0, 0), 30, 16), "consome burst")
	assertFalse(PlayerMotionGuard.authorize(1103, vec(9, 0, 0), 30, 16), "sem orçamento imediato")
	assertFalse(PlayerMotionGuard.authorize(1103, vec(13, 0, 0), 31, 16), "refill limita elapsed a 250 ms")
	local recovered, position = PlayerMotionGuard.authorize(1103, vec(12, 0, 0), 31, 16)
	assertTrue(recovered, "recupera somente quatro studs após intervalo longo")
	assertEq((position :: any).x, 12, "commit após recuperação")
end)

test("movimento: commit server-side realinha dash sem falsa recusa", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1104, vec(0, 1, 0), 40)
	assertTrue(PlayerMotionGuard.authorize(1104, vec(8, 1, 0), 40, 16), "esgota burst")
	assertTrue(PlayerMotionGuard.commitServerMove(1104, vec(20, 4, 0), 40.01), "dash do servidor")
	local ok, position = PlayerMotionGuard.authorize(1104, vec(20, 4, 0), 40.01, 16)
	assertTrue(ok, "replicação do dash não parece teleport")
	assertEq((position :: any).x, 20, "base realinhada")
	assertEq((position :: any).y, 4, "altura do commit preservada")
end)

test("movimento: posição NaN ou infinita nunca entra no registro", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1105, vec(0, 0, 0), 50)
	local nanOk, nanReason = PlayerMotionGuard.authorize(1105, vec(0 / 0, 0, 0), 50, 16)
	assertFalse(nanOk, "NaN recusado")
	assertEq(nanReason, "invalid_position", "motivo NaN")
	local infOk, infReason = PlayerMotionGuard.authorize(1105, vec(0, math.huge, 0), 50, 16)
	assertFalse(infOk, "infinito recusado")
	assertEq(infReason, "invalid_position", "motivo infinito")
	local valid, position = PlayerMotionGuard.authorize(1105, vec(1, 9, 0), 50, 16)
	assertTrue(valid, "tentativas inválidas não corrompem estado")
	assertEq((position :: any).y, 9, "posição válida posterior")
end)

test("movimento: clear remove estado da sessão anterior", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1106, vec(0, 0, 0), 60)
	PlayerMotionGuard.clearPlayer(1106)
	local ok, reason = PlayerMotionGuard.authorize(1106, vec(1, 0, 0), 60.1, 16)
	assertFalse(ok, "jogador limpo não é autorizado")
	assertEq(reason, "unregistered", "precisa registrar a nova sessão")
end)

test("movimento: teleporte vertical absurdo é recusado", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1107, vec(0, 3, 0), 70)
	local ok, reason = PlayerMotionGuard.authorize(1107, vec(0, 100, 0), 70.1, 16)
	assertFalse(ok, "salto vertical impossível")
	assertEq(reason, "vertical_movement", "motivo vertical estável")
end)

test("movimento: subidas pequenas não acumulam fly por Heartbeat", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1109, vec(0, 3, 0), 75)
	assertTrue(PlayerMotionGuard.authorize(1109, vec(0, 8, 0), 75.1, 16), "primeira metade do salto")
	assertTrue(PlayerMotionGuard.authorize(1109, vec(0, 13, 0), 75.2, 16), "teto acumulado do salto")
	local flyOk, reason = PlayerMotionGuard.authorize(1109, vec(0, 14, 0), 75.3, 16)
	assertFalse(flyOk, "subida monotônica não renova orçamento vertical")
	assertEq(reason, "vertical_movement", "motivo vertical")
	assertTrue(PlayerMotionGuard.authorize(1109, vec(0, 3, 0), 75.4, 16), "descida legítima aceita")
	assertTrue(PlayerMotionGuard.authorize(1109, vec(0, 10, 0), 75.5, 16), "novo salto após descer")
end)

test("movimento: margem pequena absorve jitter sem ampliar burst", function()
	PlayerMotionGuard.init()
	PlayerMotionGuard.register(1108, vec(0, 3, 0), 80)
	assertTrue(PlayerMotionGuard.authorize(1108, vec(8, 3, 0), 80, 16), "consome burst")
	local jitterOk = PlayerMotionGuard.authorize(1108, vec(8.45, 3, 0), 80.025, 16)
	assertTrue(jitterOk, "15% de margem cobre jitter de frame")
	local teleportOk = PlayerMotionGuard.authorize(1108, vec(17, 3, 0), 80.025, 16)
	assertFalse(teleportOk, "burst de 8 continua fechando teleport")
end)

test("geometria: distância, distância horizontal e normalize", function()
	assertEq(Geometry.distance(vec(0, 0, 0), vec(3, 4, 0)), 5, "distância 3-4-5")
	assertEq(Geometry.horizontalDistance(vec(0, 0, 0), vec(3, 99, 4)), 5, "altura é ignorada no plano")
	local unit = Geometry.normalize(vec(0, 0, -8))
	assertEq(unit.z, -1, "unitário aponta ao norte")
	local zero = Geometry.normalize(vec(0, 0, 0))
	assertEq(zero.x, 0, "vetor nulo não vira NaN")
	assertEq(zero.z, 0, "vetor nulo não vira NaN")
end)

test("geometria: costas ignoram guarda, frente não", function()
	local targetPos = vec(0, 0, 0)
	local look = vec(0, 0, -1) -- olhando para o norte
	assertEq(Geometry.facing(targetPos, look, vec(0, 0, -5)), "front", "atacante ao norte está de frente")
	assertEq(Geometry.facing(targetPos, look, vec(0, 0, 5)), "back", "atacante ao sul está pelas costas")
	assertEq(Geometry.facing(targetPos, look, vec(5, 0, 0)), "front", "perpendicular conta como frente")
	assertEq(Geometry.facing(targetPos, vec(0, 0, 0), vec(0, 0, 5)), "front", "sem olhar conhecido assume frente")
end)

test("geometria: cápsula do trajeto acerta no meio e erra fora do raio", function()
	local from = vec(0, 0, 0)
	local to = vec(0, 0, -8)
	assertTrue(Geometry.capsuleContains(from, to, 2, vec(0, 0, -4)), "no eixo do trajeto")
	assertTrue(Geometry.capsuleContains(from, to, 2, vec(1.9, 0, -4)), "dentro do raio")
	assertFalse(Geometry.capsuleContains(from, to, 2, vec(2.5, 0, -4)), "fora do raio")
	assertFalse(Geometry.capsuleContains(from, to, 2, vec(0, 0, -11)), "além do fim do trajeto")
	assertEq(Geometry.distanceToSegment(from, from, vec(0, 0, -3)), 3, "segmento degenerado vira ponto")
end)

test("geometria: lunge anda 7, respeita o cap 8 e para no bloqueio", function()
	local origin = vec(0, 0, 0)
	local north = vec(0, 0, -1)
	local free = Geometry.resolveLunge(origin, north, 7, 8, {})
	assertEq(free.traveled, 7, "anda os 7 studs")
	assertEq(free.blocked, false, "sem bloqueio")
	assertTrue(math.abs(free.position.z + 7) < 1e-6, "para em z = -7")

	local capped = Geometry.resolveLunge(origin, north, 20, 8, {})
	assertEq(capped.traveled, 8, "cap absoluto de 8 studs")

	local wall = { { id = "wall", position = vec(0, 0, -5), radius = 2 } }
	local blocked = Geometry.resolveLunge(origin, north, 7, 8, wall)
	assertEq(blocked.blocked, true, "bloqueado")
	assertEq(blocked.blockedBy, "wall", "quem bloqueou")
	assertTrue(blocked.traveled < 3.1, "para antes do contato: " .. tostring(blocked.traveled))
	assertTrue(blocked.traveled > 0, "mas avança até encostar")
end)

test("geometria: moveToward respeita a velocidade e para no alcance", function()
	local from = vec(0, 0, 0)
	local to = vec(0, 0, -30)
	local step = Geometry.moveToward(from, to, 12, 0.5, 4)
	assertTrue(math.abs(step.z + 6) < 1e-6, "12 studs/s por 0,5 s = 6 studs")
	local arrived = Geometry.moveToward(vec(0, 0, -25), to, 12, 1, 4)
	assertTrue(math.abs(arrived.z + 26) < 1e-6, "para a 4 studs do alvo, sem ultrapassar")
	local touching = Geometry.moveToward(vec(0, 0, -27), to, 12, 1, 4)
	assertEq(touching.z, -27, "já dentro do alcance não anda")
end)

test("greybox: volumes resolvem a zona de cada âncora", function()
	for _, anchor in Zones.allAnchors() do
		local resolved = Zones.zoneAtPosition(anchor.position)
		assertEq(resolved, anchor.zoneId, "âncora " .. anchor.id)
	end
	assertEq(Zones.zoneAtPosition(vec(0, 0, 0)), "zone_bastion_safe", "centro do Bastião")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -36)), "zone_threshold_transition", "vão do Portão Norte")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -80)), "zone_plain_free", "planície")
	assertEq(Zones.zoneAtPosition(vec(0, 0, 500)), nil, "fora de todo volume")
	-- A transição vence a borda compartilhada: no plano do portão o jogador
	-- já está na fronteira, não mais na zona segura.
	assertEq(Zones.zoneAtPosition(vec(0, 0, -32)), "zone_threshold_transition", "plano exato do portão")
	-- Aventais: ao lado do vão havia void. Agora é chão da planície.
	assertEq(Zones.zoneAtPosition(vec(20, 0, -36)), "zone_plain_free", "avental norte leste")
	assertEq(Zones.zoneAtPosition(vec(-20, 0, -36)), "zone_plain_free", "avental norte oeste")
	assertEq(Zones.zoneAtPosition(vec(-44, 0, 16)), "zone_plain_free", "avental oeste sul")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -580)), "zone_lumen_safe", "praça Lumen")
	assertEq(Zones.zoneAtPosition(vec(380, 0, -260)), "zone_echo_woods", "bosque")
	assertEq(Zones.zoneAtPosition(vec(-390, 0, -70)), "zone_iron_port", "porto")
	assertEq(Zones.zoneAtPosition(vec(320, 0, -570)), "zone_grey_sector", "setor cinza")
	assertEq(Zones.zoneAtPosition(vec(50, 0, 140)), "zone_academy_safe", "academia")
	assertEq(Zones.zoneAtPosition(vec(-275, 0, 190)), "zone_veil_safe", "poço da Vila Sombria")
	assertEq(Zones.zoneAtPosition(vec(-280, 0, 96)), "zone_veil_safe", "saída norte da vila")
	assertEq(Zones.zoneAtPosition(vec(-116, 0, 190)), "zone_veil_safe", "saída leste da vila")
	assertEq(Zones.zoneAtPosition(vec(0, 0, -450)), "zone_threshold_transition", "faixa Lumen")
end)

test("greybox: 6 pontos de Estilhaço, 24 studs entre si e 20 do portão", function()
	local shardIds = Zones.shardAnchors()
	assertEq(#shardIds, 6, "6 pontos")
	for i = 1, #shardIds do
		local a = Zones.getAnchor(shardIds[i])
		assertTrue(a ~= nil, "ponto existe: " .. shardIds[i])
		if a then
			assertEq(a.zoneId, "zone_plain_free", "ponto na planície: " .. shardIds[i])
			for j = i + 1, #shardIds do
				local b = Zones.getAnchor(shardIds[j])
				if b then
					local d = Geometry.horizontalDistance(a.position, b.position)
					assertTrue(d >= 24, ("%s→%s = %.1f studs"):format(shardIds[i], shardIds[j], d))
				end
			end
			for _, gateId in Zones.gateAnchors() do
				local gate = Zones.getAnchor(gateId)
				if gate then
					local d = Geometry.horizontalDistance(a.position, gate.position)
					assertTrue(d >= 20, ("%s a %.1f do portão %s"):format(shardIds[i], d, gateId))
				end
			end
		end
	end
end)

test("catálogo: âncora fora do volume da zona declarada falha validação", function()
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = Npcs,
			Zones = {
				get = Zones.get,
				all = Zones.all,
				getAnchor = Zones.getAnchor,
				allAnchors = function()
					local out: { any } = {}
					for _, anchor in Zones.allAnchors() do
						table.insert(out, anchor)
					end
					-- Declara zona segura mas fica no meio da planície.
					table.insert(out, {
						id = "anchor_mentiroso",
						zoneId = "zone_bastion_safe",
						position = { x = 0, y = 0, z = -90 },
					})
					return out
				end,
				zoneAtPosition = Zones.zoneAtPosition,
				shardAnchors = Zones.shardAnchors,
				gateAnchors = Zones.gateAnchors,
			},
		})
	end)
	assertFalse(ok, "âncora incoerente com a geometria deveria falhar")
end)

test("espaço: hitbox à frente acerta o alvo e ignora quem está atrás", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:900", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("alvo_frente", vec(0, 0, -3), vec(0, 0, 1))
	-- Está ao sul do atacante e olha para o sul (+z): de costas para ele.
	SpatialService.setTransform("alvo_atras", vec(0, 0, 6), vec(0, 0, 1))
	SpatialService.setTransform("alvo_longe", vec(0, 0, -30), vec(0, 0, 1))

	local hits = SpatialService.overlapInFront("player:900", 2, 4, nil, 1)
	assertEq(#hits, 1, "máx. 1 alvo")
	assertEq(hits[1], "alvo_frente", "acerta quem está à frente")

	local todos = SpatialService.overlapInFront("player:900", 2, 4, nil)
	assertEq(#todos, 1, "quem está atrás e longe fica fora")

	assertEq(SpatialService.facingOf("alvo_frente", "player:900"), "front", "alvo encara o atacante")
	assertEq(SpatialService.facingOf("alvo_atras", "player:900"), "back", "atacante pelas costas")
	assertEq(SpatialService.distanceBetween("player:900", "alvo_frente"), 3, "distância")
	assertEq(SpatialService.distanceBetween("player:900", "fantasma"), nil, "sem transform devolve nil")
end)

-- docs/18 §8: medido no Studio, "colado no bicho" eram ~11 studs de centro a
-- centro e a esfera de 6 studs nunca conectava. O cone corrige alcance E
-- abertura, e sempre escolhe o alvo mais próximo dentro dela.
test("espaço: cone de aquisição pega o mais próximo dentro do alcance e da abertura", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:cone", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("perto", vec(0, 0, -9), vec(0, 0, 1))
	SpatialService.setTransform("mais_longe", vec(0, 0, -10.5), vec(0, 0, 1))
	SpatialService.setTransform("fora_do_alcance", vec(0, 0, -20), vec(0, 0, 1))
	SpatialService.setTransform("atras", vec(0, 0, 5), vec(0, 0, 1))
	-- Um pouco mais longe que "perto" de propósito: empate de distância é
	-- resolvido pela ordem estável dos ids, não pelo ângulo.
	SpatialService.setTransform("lateral", vec(9.5, 0, 0), vec(0, 0, 1))

	assertEq(SpatialService.acquireTarget("player:cone", 11, 65), "perto", "o mais próximo à frente")
	assertEq(
		SpatialService.acquireTarget("player:cone", 11, 65, function(id)
			return id ~= "perto"
		end),
		"mais_longe",
		"predicado descarta e o próximo assume"
	)
	assertEq(SpatialService.acquireTarget("player:cone", 8, 65), nil, "alcance curto não alcança 9 studs")
	-- 90° de meio-ângulo ainda não pega quem está exatamente ao lado (limite),
	-- mas 91° pega: a abertura é medida no plano do chão.
	assertEq(SpatialService.acquireTarget("player:cone", 11, 30), "perto", "abertura estreita mantém o da frente")
	assertEq(
		SpatialService.acquireTarget("player:cone", 11, 91),
		"perto",
		"abertura larga continua preferindo o próximo"
	)
	assertEq(SpatialService.acquireTarget("player:cone", 4, 65), nil, "ninguém dentro do alcance curto")
	assertEq(SpatialService.acquireTarget("fantasma", 11, 65), nil, "atacante sem transform devolve nil")

	-- Look com componente vertical não pode encolher o cone.
	SpatialService.setTransform("player:cone", vec(0, 0, 0), vec(0, -0.7, -0.7))
	assertEq(SpatialService.acquireTarget("player:cone", 11, 65), "perto", "look inclinado ainda mira à frente")

	-- Virando o corpo, quem estava atrás entra no cone e quem estava à frente sai.
	SpatialService.setTransform("player:cone", vec(0, 0, 0), vec(0, 0, 1))
	assertEq(SpatialService.acquireTarget("player:cone", 11, 65), "atras", "de costas para o alvo antigo")
end)

test("espaço: a mira declarada decide o cone, não a rotação do corpo", function()
	-- O outro lado do conserto de 14/08: o corpo do jogador parou de girar no
	-- golpe, então quem aponta o cone é o vetor que chegou na intenção. Aqui o
	-- corpo olha para -Z e a mira aponta para +Z — leva o golpe quem está atrás
	-- do corpo, porque é para lá que o jogador está mirando.
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:mira", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("na_frente_do_corpo", vec(0, 0, -6), vec(0, 0, 1))
	SpatialService.setTransform("na_direcao_da_mira", vec(0, 0, 6), vec(0, 0, -1))

	assertEq(
		SpatialService.acquireTarget("player:mira", 9, 65),
		"na_frente_do_corpo",
		"sem mira declarada vale o look do corpo"
	)

	local look = SpatialService.aimLook({ x = 0, z = 1 })
	assertTrue(look ~= nil, "mira válida vira look")
	SpatialService.setTransform("player:mira", vec(0, 0, 0), look)
	assertEq(
		SpatialService.acquireTarget("player:mira", 9, 65),
		"na_direcao_da_mira",
		"o golpe segue a mira, não o corpo"
	)
end)

test("espaço: mira inválida é recusada e o cone volta para o corpo", function()
	-- Segunda barreira além do schema, como no dash: vetor neutro, NaN, grande
	-- demais ou fora de formato não vira direção de golpe. Recusar devolvendo
	-- nil é o que faz o chamador manter o look replicado em vez de mirar em
	-- lugar nenhum.
	assertEq(SpatialService.aimLook(nil), nil, "sem campo")
	assertEq(SpatialService.aimLook("frente"), nil, "não é tabela")
	assertEq(SpatialService.aimLook({ x = 0, z = 0 }), nil, "vetor neutro")
	assertEq(SpatialService.aimLook({ x = 0.05, z = 0.05 }), nil, "curto demais para ter direção")
	assertEq(SpatialService.aimLook({ x = 5, z = 0 }), nil, "grande demais")
	assertEq(SpatialService.aimLook({ x = 0 / 0, z = 1 }), nil, "NaN")
	assertEq(SpatialService.aimLook({ x = "1", z = 0 }), nil, "componente que não é número")

	local look = SpatialService.aimLook({ x = 0.6, z = 0.8 })
	assertTrue(look ~= nil, "vetor unitário aceito")
	assertEq((look :: any).y, 0, "mira é sempre plana")
	local magnitude = math.sqrt((look :: any).x ^ 2 + (look :: any).z ^ 2)
	assertTrue(math.abs(magnitude - 1) < 1e-6, "look sai normalizado")

	-- Alvo praticamente em cima do atacante não pode ser recusado por ângulo.
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:abraco", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("grudado", vec(0, 0, 0.5), vec(0, 0, 1))
	assertEq(SpatialService.acquireTarget("player:abraco", 11, 65), "grudado", "colado acerta mesmo por trás")
end)

test("contato: alcance do módulo bate com o handler e o cone pega o mais próximo", function()
	assertEq(CombatService.LightWindowSeconds, 1.00, "janela do servidor")
	assertEq(HitContact.LightReachStuds[1], 13, "leve 1")
	assertEq(HitContact.HeavyReachStuds, 13.5, "pesado")
	assertEq(HitContact.LightHalfAngleDegrees, 92, "cone leve")
	assertEq(HitContact.HeavyHalfAngleDegrees, 80, "cone pesado")
	local source = fs.readFile("src/server/init.server.lua")
	assertTrue(source:find("local BASIC_RANGE_STUDS = 6", 1, true) ~= nil, "handler ainda declara 6")
	assertTrue(source:find("local BODY_ALLOWANCE_STUDS = 7", 1, true) ~= nil, "handler ainda declara folga 7")

	local origin = { x = 0, y = 0, z = 0 }
	local look = { x = 0, y = 0, z = -1 }
	local got = HitContact.acquire(origin, look, {
		{ id = "perto", position = { x = 0, y = 0, z = -6 } },
		{ id = "longe", position = { x = 0, y = 0, z = -8 } },
		{ id = "atras", position = { x = 0, y = 0, z = 6 } },
	}, 9, 65)
	assertEq(got, "perto", "mais próximo à frente")
end)

test("contato: claimed só entra na folga de latência, nunca longe ou pelas costas", function()
	local origin = { x = 0, y = 0, z = 0 }
	local look = { x = 0, y = 0, z = -1 }
	assertTrue(
		HitContact.acceptClaimed({
			origin = origin,
			look = look,
			target = { x = 0, y = 0, z = -12 },
			reach = 9,
			halfAngle = 65,
		}),
		"12 studs cabem em 9+8"
	)
	assertFalse(
		HitContact.acceptClaimed({
			origin = origin,
			look = look,
			target = { x = 0, y = 0, z = -20 },
			reach = 9,
			halfAngle = 65,
		}),
		"20 studs passam da folga"
	)
	assertFalse(
		HitContact.acceptClaimed({
			origin = origin,
			look = look,
			target = { x = 0, y = 0, z = 8 },
			reach = 9,
			halfAngle = 65,
		}),
		"atrás do olhar não entra"
	)
	assertEq(
		HitContact.resolveTarget(nil, "player:777", origin, look, { x = 0, y = 0, z = -12 }, 9, 65),
		"player:777",
		"miss espacial + pista válida"
	)
	assertEq(
		HitContact.resolveTarget("npc:dummy", "player:777", origin, look, { x = 0, y = 0, z = -12 }, 9, 65),
		"npc:dummy",
		"cone autoritativo vence a pista"
	)
	assertEq(
		HitContact.resolveTarget(nil, "player:777", origin, look, { x = 0, y = 0, z = -20 }, 9, 65),
		nil,
		"pista longe demais continua miss"
	)
end)

test("contato: frontal no alcance 13 resolve; 13,6 erra no caminho real", function()
	local origin = { x = 0, y = 0, z = 0 }
	local look = { x = 0, y = 0, z = -1 }
	local reach = HitContact.LightReachStuds[1]
	local angle = HitContact.LightHalfAngleDegrees
	assertEq(reach, 13, "módulo no alcance 13")
	local inside = HitContact.acquire(origin, look, {
		{ id = "perto", position = { x = 0, y = 0, z = -12.9 } },
	}, reach, angle)
	assertEq(inside, "perto", "12,9 studs conecta")
	local outside = HitContact.acquire(origin, look, {
		{ id = "longe", position = { x = 0, y = 0, z = -13.6 } },
	}, reach, angle)
	assertEq(outside, nil, "13,6 studs erra")
	assertEq(
		HitContact.resolveTarget(inside, nil, origin, look, nil, reach, angle),
		"perto",
		"resolveTarget confirma o cone"
	)
	assertEq(
		HitContact.resolveTarget(outside, nil, origin, look, nil, reach, angle),
		nil,
		"resolveTarget preserva o miss"
	)
end)

test("contato: view e replay do feeling não dobram o impacto previsto", function()
	assertEq(HitContact.viewFor("player:1", { view = "taken", targetId = "player:1" }), "taken", "campo vence")
	assertEq(HitContact.viewFor("player:1", { targetId = "player:1" }), "taken", "alvo sou eu")
	assertEq(HitContact.viewFor("player:1", { targetId = "player:2" }), "dealt", "eu bati")
	assertTrue(HitContact.shouldReplayImpact(nil, 10), "sem previsão toca o confirmado")
	assertFalse(HitContact.shouldReplayImpact(10.0, 10.1), "dentro da janela não repete")
	assertTrue(HitContact.shouldReplayImpact(10.0, 10.5), "depois da janela o próximo golpe toca")
end)

test("espaço: dash avança 12 studs e ignora distância declarada na direção", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:dash-1", vec(0, 2, 0), vec(0, 0, -1))
	local clientDirection: any = { x = 0, z = -1, distance = 999 }
	local resolution = SpatialService.resolveDash("player:dash-1", clientDirection, 12, 12)
	assertEq(resolution.traveled, 12, "distância definida pelo servidor")
	assertEq(resolution.position.y, 2, "preserva altura")
	assertTrue(math.abs(resolution.position.z + 12) < 1e-6, "avança 12 para o norte")
	local committed = SpatialService.getPosition("player:dash-1")
	assertTrue(committed ~= nil and math.abs(committed.z + 12) < 1e-6, "posição commitada")
end)

test("espaço: dash normaliza a direção no plano do chão", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:dash-2", vec(1, 3, 2), vec(0, 0, -1))
	local resolution = SpatialService.resolveDash("player:dash-2", { x = 3, y = 100, z = 4 }, 12, 12)
	assertEq(resolution.traveled, 12, "magnitude da entrada não multiplica o dash")
	assertTrue(math.abs(resolution.position.x - 8.2) < 1e-6, "componente x normalizado")
	assertTrue(math.abs(resolution.position.z - 11.6) < 1e-6, "componente z normalizado")
	assertEq(resolution.position.y, 3, "componente vertical é ignorado")
end)

test("espaço: dash respeita hard cap do servidor", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:dash-3", vec(0, 0, 0), vec(1, 0, 0))
	local resolution = SpatialService.resolveDash("player:dash-3", { x = 1, z = 0 }, 20, 12)
	assertEq(resolution.traveled, 12, "pedido interno maior é limitado")
	assertEq(resolution.position.x, 12, "para no cap")
end)

test("espaço: dash para na parede e commita o ponto seguro", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:dash-4", vec(0, 0, 0), vec(0, 0, -1))
	local walls = { { id = "wall_north", position = vec(0, 0, -7), radius = 2 } }
	local resolution = SpatialService.resolveDash("player:dash-4", { x = 0, z = -1 }, 12, 12, walls)
	assertTrue(resolution.blocked, "parede bloqueia")
	assertEq(resolution.blockedBy, "wall_north", "parede autoritativa")
	assertTrue(resolution.traveled > 0 and resolution.traveled < 12, "para antes da parede")
	local committed = SpatialService.getPosition("player:dash-4")
	assertTrue(committed ~= nil, "posição bloqueada commitada")
	if committed then
		assertEq(committed.z, resolution.position.z, "registro usa o ponto resolvido")
	end
end)

test("espaço: dash sem transform não cria posição", function()
	SpatialService.init({ geometry = Geometry })
	local resolution = SpatialService.resolveDash("player:ausente", { x = 0, z = -1 }, 12, 12)
	assertEq(resolution.traveled, 0, "sem avanço")
	assertFalse(resolution.blocked, "sem bloqueio inventado")
	assertEq(SpatialService.getPosition("player:ausente"), nil, "não cria transform")
end)

test("espaço: Ombro Cometa avança 7, commita a posição e acerta 1 alvo", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:901", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("inimigo", vec(0, 0, -6), vec(0, 0, 1))

	local resolution = SpatialService.resolveCometShoulder("player:901", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
		blocks = function(): boolean
			return false
		end,
	})
	assertEq(resolution.traveled, 7, "avanço de 7 studs")
	assertEq(resolution.targetId, "inimigo", "alvo na cápsula do trajeto")
	-- O alvo encara a origem do avanço. Medir na posição final diria "back",
	-- porque o lunge de 7 ultrapassa quem está a 6 — e furaria a guarda.
	assertEq(resolution.facing, "front", "lado do golpe medido da origem")
	local committed = SpatialService.getPosition("player:901")
	assertTrue(committed ~= nil, "posição commitada")
	if committed then
		assertTrue(math.abs(committed.z + 7) < 1e-6, "servidor moveu o atacante")
	end
end)

test("espaço: guarda inimiga para o avanço do Cometa", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:902", vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform("guardiao", vec(0, 0, -5), vec(0, 0, 1))

	local resolution = SpatialService.resolveCometShoulder("player:902", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
		blocks = function(fighterId: string): boolean
			return fighterId == "guardiao"
		end,
	})
	assertEq(resolution.blocked, true, "avanço travado")
	assertEq(resolution.blockedBy, "guardiao", "quem travou")
	assertTrue(resolution.traveled < 7, "não completou os 7 studs")
	local committed = SpatialService.getPosition("player:902")
	if committed then
		assertTrue(committed.z > -7, "parou antes do destino")
	end
end)

test("espaço: Cometa sem ninguém no trajeto avança e não acerta", function()
	SpatialService.init({ geometry = Geometry })
	SpatialService.setTransform("player:903", vec(0, 0, 0), vec(0, 0, -1))
	local resolution = SpatialService.resolveCometShoulder("player:903", {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
	})
	assertEq(resolution.traveled, 7, "avança")
	assertEq(resolution.targetId, nil, "sem alvo")
	assertEq(resolution.blocked, false, "sem bloqueio")
end)

-- Monta EnemyService + CombatService + SpatialService reais.
local function makeEnemyWorld(targets: { any }, events: { any }?): ()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return targets
		end,
		onEnemyEvent = function(fighterId: string, event: { any })
			if events then
				table.insert(events, { fighterId = fighterId, event = event })
			end
		end,
	})
end

test("inimigo: spawn respeita o teto de 4 vivos e usa as âncoras", function()
	makeEnemyWorld({})
	local spawned = EnemyService.spawnInitial()
	assertEq(spawned, 4, "spawna até o teto de 4")
	assertEq(#EnemyService.list(), 4, "4 registrados")
	assertEq(EnemyService.spawnInitial(), 0, "segunda chamada não duplica")
	assertEq(EnemyService.spawnWisps(), 0, "sem wispAnchors no deps não cria Fátuo")
	local first = EnemyService.list()[1]
	assertEq(first.fighterId, "enemy_wandering_shard@anchor_shard_1#1", "id carrega a âncora")
	assertEq(first.zoneId, "zone_plain_free", "vive na planície")
	local position = SpatialService.getPosition(first.fighterId)
	local anchor = Zones.getAnchor("anchor_shard_1")
	assertTrue(position ~= nil and anchor ~= nil, "posicionado na âncora")
	if position and anchor then
		assertEq(position.x, anchor.position.x, "x da âncora")
		assertEq(position.z, anchor.position.z, "z da âncora")
	end
end)

test("inimigo: patrulha em órbita e terceiro golpe rift / Fogo-fátuo", function()
	local rend = EnemyService.chaserPattern("enemy_wandering_shard", 0, Npcs.get("enemy_wandering_shard"))
	local pounce = EnemyService.chaserPattern("enemy_wandering_shard", 1, Npcs.get("enemy_wandering_shard"))
	local rift = EnemyService.chaserPattern("enemy_wandering_shard", 2, Npcs.get("enemy_wandering_shard"))
	assertEq(rend.abilityId, "shard_rend", "ciclo 0 = talho")
	assertEq(pounce.abilityId, "shard_pounce", "ciclo 1 = salto")
	assertEq(rift.abilityId, "shard_rift", "ciclo 2 = fenda")
	assertEq(rift.damage, 10, "fenda bate 10")
	assertEq(rift.telegraphSeconds, 0.55, "fenda telegrafa 550 ms")
	local pierce = EnemyService.chaserPattern("enemy_grove_wisp", 0, Npcs.get("enemy_grove_wisp"))
	assertEq(pierce.abilityId, "wisp_pierce", "Fátuo fura")
	assertEq(pierce.damage, 6, "Fátuo dano 6")
	local cleave = EnemyService.chaserPattern("enemy_port_scrapper", 0, Npcs.get("enemy_port_scrapper"))
	local hook = EnemyService.chaserPattern("enemy_port_scrapper", 1, Npcs.get("enemy_port_scrapper"))
	assertEq(cleave.abilityId, "port_cleave", "Sucateiro talha")
	assertEq(hook.abilityId, "port_hook", "Sucateiro gancho")

	local point = EnemyService.patrolPoint({ x = 0, y = 0, z = 0 }, 2, 6, 8)
	assertTrue(math.abs(point.x * point.x + point.z * point.z - 36) < 0.05, "órbita de raio 6")
	assertEq(point.y, 0, "patrulha no plano")

	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		wispAnchors = Zones.wispAnchors,
		portAnchors = Zones.portAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
	})
	assertEq(EnemyService.spawnWisps(), 2, "dois Fogos-fátuo")
	assertEq(EnemyService.spawnWisps(), 0, "não duplica")
	assertEq(EnemyService.spawnScrappers(), 2, "dois Sucateiros")
	assertEq(EnemyService.spawnScrappers(), 0, "Sucateiro não duplica")
	local wisp = EnemyService.list()
	local sawWisp = false
	for _, record in wisp do
		if record.npcId == "enemy_grove_wisp" then
			sawWisp = true
			assertEq(record.zoneId, "zone_echo_woods", "vive no Bosque")
		end
	end
	assertTrue(sawWisp, "Fátuo registrado")
end)

test("inimigo: persegue a 12 studs/s e ataca só depois do telegraph", function()
	local playerId = "player:910"
	local targets = { { fighterId = playerId, userId = 910, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()

	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	assertTrue(anchor ~= nil, "âncora")
	if not anchor then
		return
	end
	-- Jogador 10 studs ao norte da âncora, na planície.
	local playerPos = vec(anchor.position.x, anchor.position.y, anchor.position.z - 10)
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, playerPos, vec(0, 0, 1))

	-- 1º tick: 12 studs/s por 0,5 s = 6 studs, parando a 4 (o alcance).
	-- Chegando ao alcance no mesmo tick, o ciclo abre o telegraph.
	EnemyService.tick(1000, 0.5)
	local afterMove = SpatialService.getPosition(shardId)
	assertTrue(afterMove ~= nil, "moveu")
	if afterMove then
		local d = Geometry.horizontalDistance(afterMove, playerPos)
		assertTrue(math.abs(d - 4) < 1e-6, "parou no alcance de 4: " .. tostring(d))
	end
	local player = CombatService.getFighter(playerId)
	local shard = CombatService.getFighter(shardId)
	assertTrue(player ~= nil and shard ~= nil, "fighters")
	if not player or not shard then
		return
	end
	assertEq(shard.aiPhase, "telegraph", "abre o telegraph ao alcançar")
	assertEq(player.health, 100, "telegraph não causa dano")

	-- Dentro dos 400 ms o golpe ainda não sai.
	EnemyService.tick(1000.2, 0.1)
	assertEq(player.health, 100, "telegraph de 400 ms ainda correndo")

	-- Passados os 400 ms, o golpe conecta com 6 de dano.
	EnemyService.tick(1000.5, 0.1)
	assertEq(player.health, 92, "dano 8 após o telegraph")
	assertEq(shard.aiPhase, "recovery", "entra em recovery")
end)

test("inimigo: i-frame não vira hit confirmado no evento", function()
	local playerId = "player:919"
	local targets = { { fighterId = playerId, userId = 919, zoneId = "zone_plain_free" } }
	local events: { any } = {}
	makeEnemyWorld(targets, events)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	local player = CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, vec(anchor.position.x, 0, anchor.position.z - 4), vec(0, 0, 1))
	EnemyService.tick(1500, 0.1)
	player.iframeUntil = 1501
	local hits = EnemyService.tick(1500.5, 0.1)
	assertEq(hits, 0, "i-frame não conta conexão")
	local attack: any = nil
	for _, emitted in events do
		if emitted.fighterId == shardId and emitted.event.kind == "attack" then
			attack = emitted.event
		end
	end
	assertTrue(attack ~= nil, "animação de ataque ainda é emitida")
	assertEq(attack.iframe, true, "metadata de evasão preservada")
	assertEq(attack.outcome, "evaded", "cliente não recebe hit falso")
	assertEq(player.health, 100, "HP intacto")
end)

test("inimigo: Retorno de Pulso preserva contra no evento", function()
	local playerId = "player:918"
	local targets = { { fighterId = playerId, userId = 918, zoneId = "zone_plain_free" } }
	local events: { any } = {}
	makeEnemyWorld(targets, events)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	local player = CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, vec(anchor.position.x, 0, anchor.position.z - 4), vec(0, 0, 1))
	EnemyService.tick(1600, 0.1)
	CombatService.setPulseStance(player, 1600.3)
	local hits = EnemyService.tick(1600.41, 0.1)
	assertEq(hits, 1, "contato reduzido ainda conecta")
	local attack: any = nil
	for _, emitted in events do
		if emitted.fighterId == shardId and emitted.event.kind == "attack" then
			attack = emitted.event
		end
	end
	assertTrue(attack ~= nil, "evento de ataque")
	assertEq(attack.pulseCounter, true, "flag chega ao bootstrap")
	assertEq(attack.outcome, "guard", "feedback defensivo")
	assertEq(attack.damage, 4, "8 reduzido pela metade")
end)

test("inimigo: sem aggro através da fronteira", function()
	local playerId = "player:911"
	-- Mesmo perto, um jogador na zona segura não é alvo.
	local targets = { { fighterId = playerId, userId = 911, zoneId = "zone_bastion_safe" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z - 2),
		vec(0, 0, 1)
	)

	EnemyService.tick(2000, 0.5)
	EnemyService.tick(2001, 0.5)
	local player = CombatService.getFighter(playerId)
	assertTrue(player ~= nil and player.health == 100, "jogador na segura não leva dano")
	local shard = CombatService.getFighter(shardId)
	assertTrue(shard ~= nil and shard.aiPhase == "idle", "Estilhaço fica em idle")
	local moved = SpatialService.getPosition(shardId)
	if moved then
		assertEq(moved.z, anchor.position.z, "nem persegue")
	end
end)

test("inimigo: raio de aggro 30 studs — não puxa e larga a perseguição", function()
	assertEq(EnemyService.DefaultAggroRadiusStuds, 30, "padrão Blox Fruits")
	assertTrue(EnemyService.withinAggro(30, 30), "no limite puxa")
	assertFalse(EnemyService.withinAggro(30.01, 30), "1 cm além não puxa")
	assertFalse(EnemyService.withinAggro(nil, 30), "sem distância não puxa")
	assertFalse(EnemyService.withinAggro(10, 0), "raio zero não puxa")

	local playerId = "player:930"
	local targets = { { fighterId = playerId, userId = 930, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	assertTrue(anchor ~= nil, "âncora")
	if not anchor then
		return
	end
	CombatService.createFighter(playerId, "player", 100, 100)
	-- 40 studs: dentro da planície, fora do raio. Não pode nem começar.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z - 40),
		vec(0, 0, 1)
	)
	EnemyService.tick(7000, 0.5)
	local stillHome = SpatialService.getPosition(shardId)
	if stillHome then
		assertEq(stillHome.z, anchor.position.z, "fora do raio não sai da âncora")
	end
	local shard = CombatService.getFighter(shardId)
	assertTrue(shard ~= nil and shard.aiPhase == "idle", "fica em idle")

	-- Entra no raio: 10 studs, persegue como antes.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z - 10),
		vec(0, 0, 1)
	)
	EnemyService.tick(7001, 0.5)
	local chased = SpatialService.getPosition(shardId)
	assertTrue(chased ~= nil, "moveu")
	if chased then
		assertTrue(chased.z ~= anchor.position.z, "dentro do raio persegue")
	end

	-- Sai do raio: larga e começa a voltar pra âncora.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z - 80),
		vec(0, 0, 1)
	)
	local beforeReturn = SpatialService.getPosition(shardId)
	EnemyService.tick(7002, 0.5)
	local afterDrop = SpatialService.getPosition(shardId)
	assertTrue(beforeReturn ~= nil and afterDrop ~= nil, "posições")
	if beforeReturn and afterDrop and anchor then
		local beforeHome = Geometry.horizontalDistance(beforeReturn, anchor.position)
		local afterHome = Geometry.horizontalDistance(afterDrop, anchor.position)
		assertTrue(afterHome < beforeHome - 1e-6, "volta pra âncora ao largar")
	end
	local afterShard = CombatService.getFighter(shardId)
	assertTrue(afterShard ~= nil and afterShard.aiPhase == "idle", "soltou o ciclo")
end)

test("inimigo: respawn de 45 s bloqueia com jogador perto da âncora", function()
	local playerId = "player:912"
	local targets = { { fighterId = playerId, userId = 912, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	local anchor = Zones.getAnchor("anchor_shard_1")
	if not anchor then
		return
	end
	CombatService.createFighter(playerId, "player", 100, 100)
	-- Jogador a 5 studs da âncora: dentro do raio de 20.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x + 5, anchor.position.y, anchor.position.z),
		vec(0, 0, 1)
	)

	local shard = CombatService.getFighter(shardId)
	assertTrue(shard ~= nil, "estilhaço")
	if not shard then
		return
	end
	shard.health = 0
	shard.diedAt = 3000

	EnemyService.tick(3000 + 50, 0.5)
	assertEq(shard.health, 0, "combate perto bloqueia o respawn")

	-- Jogador se afasta para além dos 20 studs.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x + 40, anchor.position.y, anchor.position.z),
		vec(0, 0, 1)
	)
	EnemyService.tick(3000 + 51, 0.5)
	assertEq(shard.health, 60, "respawn com a área limpa")
	local back = SpatialService.getPosition(shardId)
	if back then
		assertEq(back.z, anchor.position.z, "volta para a mesma âncora")
	end
end)

test("inimigo: kill reporta a âncora para o crédito de XP", function()
	local kills: { any } = {}
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, fighterId: string)
			table.insert(kills, { userId = userId, fighterId = fighterId })
		end,
	})
	EnemyService.spawnInitial()
	local shardId = "enemy_wandering_shard@anchor_shard_1#1"
	assertTrue(EnemyService.isEnemy(shardId), "registrado como inimigo")
	assertEq(EnemyService.reportKill(920, shardId), true, "kill reportado")
	assertEq(#kills, 1, "callback disparado")
	assertEq(kills[1].userId, 920, "autor")
	assertEq(kills[1].fighterId, shardId, "fighter")
	assertFalse(EnemyService.reportKill(920, "fighter_inexistente"), "id desconhecido não reporta")
	EnemyService.despawnAll()
	assertEq(#EnemyService.list(), 0, "despawn limpa")
end)

test("dados: EnemyEvent registrado como remote S→C", function()
	local contract = Remotes.Contracts.get(Remotes.Names.EnemyEvent)
	assertTrue(contract ~= nil, "EnemyEvent deveria ter contrato")
	if contract then
		assertEq(contract.direction, "ServerToClient", "direção")
		assertEq(contract.version, 1, "versão")
		assertTrue(contract.payload:find("telegraph") ~= nil, "payload com telegraph")
		assertTrue(contract.payload:find("durationSeconds") ~= nil, "timing visual declarado pelo servidor")
		assertTrue(contract.payload:find("visualPattern") ~= nil, "padrão visual sem autoridade de dano")
	end
end)

-- ══ Testes: item 9 — elite, leeching e cooldown de XP ───────────────────────
test("dados: Estilhaço Ancorado é o baseline da spec §9.3", function()
	local elite = Npcs.get("enemy_anchored_shard")
	assertTrue(elite ~= nil, "enemy_anchored_shard deveria existir")
	if not elite then
		return
	end
	assertEq(elite.kind, "enemy", "kind")
	assertEq(elite.maxHealth, 120, "vida 120")
	assertEq(elite.attackPattern, "elite", "padrão")
	assertEq(elite.eliteSlamDamage, 14, "slam 14")
	assertEq(elite.eliteSlamTelegraphMs, 700, "slam telegraph 700 ms")
	assertEq(elite.eliteComboDamage, 6, "combo 6")
	assertEq(elite.eliteComboTelegraphMs, 300, "combo telegraph 300 ms")
	assertEq(elite.respawnSeconds, 180, "respawn 180 s")
	assertEq(elite.xpUnconsolidated, 80, "XP 80")
	assertEq(elite.xpCooldownSeconds, 180, "cooldown 180 s por jogador")
	assertEq(elite.leechDamagePct, 0.01, "leeching ≥ 1% da vida")
	assertEq(elite.leechStaySeconds, 8, "leeching 8 s no raio")
	assertEq(elite.maxAlive, 1, "um único vivo")
	assertEq(elite.zoneId, "zone_plain_free", "vive na planície")
end)

test("dados: quest_elite derrota o Ancorado e destrava a Cadência", function()
	local quest = Quests.get("quest_elite")
	assertTrue(quest ~= nil, "quest_elite deveria existir")
	if not quest then
		return
	end
	assertEq(quest.kind, "kill", "kind")
	assertEq(quest.targetId, "enemy_anchored_shard", "alvo")
	assertEq(quest.requiredCount, 1, "um kill")
	assertEq(quest.xpReward, 60, "+60 XP")
	assertEq(quest.unlockFlag, "unlock_broken_cadence", "unlock da Cadência")
	assertEq(quest.acceptFlag, "quest_elite_accepted", "flag de aceite")
	assertEq(quest.autoAcceptAfterSeconds, 900, "aceite forçado só após 15 min")
end)

test("dados: quest_flow pede um eco da Cadência e destrava o Pulso", function()
	local quest = Quests.get("quest_flow")
	assertTrue(quest ~= nil, "quest_flow deveria existir")
	if not quest then
		return
	end
	assertEq(quest.kind, "flow_echo", "kind de timing")
	assertEq(quest.targetId, "broken_cadence", "habilidade que gera o eco")
	assertEq(quest.requiredCount, 1, "um eco")
	assertEq(quest.xpReward, 40, "+40 XP")
	assertEq(quest.unlockFlag, "unlock_pulse_return", "unlock do Pulso")
	assertEq(quest.acceptFlag, "quest_flow_accepted", "flag de aceite")
	assertEq(quest.autoAcceptAfterSeconds, 2700, "aceite forçado só após 45 min")
end)

test("catálogo: dados reais validam com elite e os 3 objetivos", function()
	local ok = pcall(function()
		CatalogService.init({
			Abilities = Abilities,
			Characters = Characters,
			EnergyFamilies = EnergyFamilies,
			Npcs = Npcs,
			Zones = Zones,
			Quests = Quests,
			Locale = Locale,
		})
	end)
	assertTrue(ok, "catálogo completo deveria validar")
end)

test("combate: elite alterna combo 6+6 e slam 14, com guarda cortada em 30%", function()
	CombatService.clear()
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 120, 0)
	local player = CombatService.createFighter("player:950", "player", 100, 100)
	local params = {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 6,
		comboTelegraphSeconds = 0.3,
		slamDamage = 14,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	}
	-- Ciclo 1: combo (6+6) após o telegraph de 300 ms.
	local combo = CombatService.tryEliteCycle(elite, player, 1000, 5, true, params)
	assertEq(combo.ok, true, "ciclo abre")
	assertEq(combo.phase, "telegraph", "telegraph primeiro")
	assertEq(combo.damage, 0, "telegraph sem dano")
	local comboHit = CombatService.tryEliteCycle(elite, player, 1000.31, 5, true, params)
	assertEq(comboHit.ok, true, "combo conecta")
	assertEq(comboHit.phase, "attack", "ataque")
	assertEq(comboHit.damage, 12, "6+6")
	assertEq(player.health, 88, "HP após o combo")
	-- Recovery: golpe dentro do recovery não sai.
	local during = CombatService.tryEliteCycle(elite, player, 1000.5, 5, true, params)
	assertEq(during.ok, false, "em recovery")
	assertEq(during.reason, "recovery", "motivo")
	-- Ciclo 2: slam (14) após o telegraph de 700 ms. Recovery termina em
	-- 1000.31 + 0.8 = 1001.11; o próximo ciclo abre depois disso.
	local slamTelegraph = CombatService.tryEliteCycle(elite, player, 1001.2, 5, true, params)
	assertEq(slamTelegraph.phase, "telegraph", "slam em telegraph")
	assertEq(slamTelegraph.damage, 0, "sem dano")
	local slamHit = CombatService.tryEliteCycle(elite, player, 1001.91, 5, true, params)
	assertEq(slamHit.ok, true, "slam conecta")
	assertEq(slamHit.damage, 14, "dano 14")
	assertEq(player.health, 74, "HP após o slam")
	-- Ciclo 3: onda shock (10), guardável. Recovery do slam termina em
	-- 1001.91 + 0.8 = 1002.71.
	local shockTelegraph = CombatService.tryEliteCycle(elite, player, 1002.8, 5, true, params)
	assertEq(shockTelegraph.phase, "telegraph", "shock em telegraph")
	assertEq(elite.elitePattern, "shock", "padrão virou shock")
	local shockHit = CombatService.tryEliteCycle(elite, player, 1003.4, 5, true, params)
	assertEq(shockHit.ok, true, "shock conecta")
	assertEq(shockHit.damage, 10, "onda 10")
	assertEq(player.health, 64, "HP após a onda")
end)

test("combate: Pulso interrompe o combo do elite no primeiro golpe", function()
	CombatService.clear()
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 120, 0)
	local player = CombatService.createFighter("player:956", "player", 100, 100)
	local params = {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 6,
		comboTelegraphSeconds = 0.3,
		slamDamage = 14,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	}
	CombatService.tryEliteCycle(elite, player, 1050, 5, true, params)
	CombatService.setPulseStance(player, 1050.2)
	local hit = CombatService.tryEliteCycle(elite, player, 1050.31, 6, true, params)
	assertEq(hit.pulseCounter, true, "contra preservado")
	assertEq(hit.damage, 3, "primeiro golpe reduzido em 50%")
	assertEq(player.health, 97, "segundo golpe não atravessa o contra")
end)

test("combate: slam do elite atravessa a guarda (reduz só 30%)", function()
	CombatService.clear()
	local elite = CombatService.createFighter("enemy_anchored_shard@anchor_elite#1", "npc", 120, 0)
	local guard = CombatService.createFighter("player:951", "player", 100, 100)
	CombatService.setGuard(guard, true, 1100)
	local params = {
		range = 8,
		recoverySeconds = 0.8,
		comboDamage = 6,
		comboTelegraphSeconds = 0.3,
		slamDamage = 14,
		slamTelegraphSeconds = 0.7,
		slamBlockedPct = 0.7,
	}
	elite.elitePattern = "slam"
	CombatService.tryEliteCycle(elite, guard, 1100, 5, true, params)
	local slam = CombatService.tryEliteCycle(elite, guard, 1100.71, 5, true, params)
	assertEq(slam.ok, true, "slam conecta")
	-- Guarda reduz 30% → 70% do dano passa: ceil(14 * 0.7) = 10.
	assertEq(slam.damage, 10, "dano bloqueado 70%")
	assertEq(guard.health, 90, "HP após slam na guarda")
	assertEq(guard.guard, 86, "guarda sofre o dano cheio (14)")
end)

test("XP: elite paga 80 com cooldown de 3 min por jogador", function()
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	fakeNow = 30000
	ProgressionService.registerPlayer(960)
	local elite = Npcs.get("enemy_anchored_shard")
	assertTrue(elite ~= nil, "elite no catálogo")
	local first = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(first.granted, 80, "primeiro crédito paga 80")
	assertEq(ProgressionService.getUnconsolidatedXp(960), 80, "XP não consolidado")
	-- Mesmo jogador, outro kill dentro de 180 s: recusa.
	fakeNow = 30000 + 100
	local blocked = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(blocked.granted, 0, "dentro do cooldown não paga")
	assertEq(blocked.reason, "xp_cooldown", "motivo")
	-- Depois de 180 s do primeiro: paga de novo.
	fakeNow = 30000 + 181
	local again = ProgressionService.creditNpcKill(960, elite, "anchor_elite")
	assertEq(again.granted, 80, "após 180 s paga de novo")
	assertEq(ProgressionService.getUnconsolidatedXp(960), 160, "80 + 80")
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(960)
end)

test("inimigo: elite spawna único na âncora da cratera", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
	})
	assertEq(EnemyService.spawnElite(), true, "spawna o elite")
	assertEq(EnemyService.spawnElite(), false, "segunda chamada não duplica")
	local elite = CombatService.getFighter("enemy_anchored_shard@anchor_elite#1")
	assertTrue(elite ~= nil, "fighter do elite existe")
	if elite then
		assertEq(elite.maxHealth, 120, "120 de vida")
		local position = SpatialService.getPosition("enemy_anchored_shard@anchor_elite#1")
		local anchor = Zones.getAnchor("anchor_elite")
		assertTrue(position ~= nil and anchor ~= nil, "posicionado")
		if position and anchor then
			assertEq(position.x, anchor.position.x, "x da cratera")
			assertEq(position.z, anchor.position.z, "z da cratera")
		end
	end
	EnemyService.despawnAll()
end)

test("inimigo: tick comum ignora elite e tickElite preserva respawn de 180 s", function()
	local playerId = "player:969"
	local targets = { { fighterId = playerId, userId = 969, zoneId = "zone_plain_free" } }
	makeEnemyWorld(targets)
	EnemyService.spawnInitial()
	assertTrue(EnemyService.spawnElite(), "elite spawna junto dos Errantes")

	local fighterId = "enemy_anchored_shard@anchor_elite#1"
	local elite = CombatService.getFighter(fighterId)
	local anchor = Zones.getAnchor("anchor_elite")
	assertTrue(elite ~= nil and anchor ~= nil, "elite e âncora existem")
	if not elite or not anchor then
		return
	end

	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x, anchor.position.y, anchor.position.z + 12),
		vec(0, 0, -1)
	)

	-- Sem o filtro por npcId, o tick dos Errantes moveria o elite ancorado em
	-- direção ao jogador usando moveSpeed/attackRange do inimigo comum.
	EnemyService.tick(6000, 0.5)
	local afterCommonTick = SpatialService.getPosition(fighterId)
	assertTrue(afterCommonTick ~= nil, "transform do elite permanece registrado")
	if afterCommonTick then
		assertEq(afterCommonTick.x, anchor.position.x, "tick comum não move o elite em x")
		assertEq(afterCommonTick.z, anchor.position.z, "tick comum não move o elite em z")
	end
	assertEq(elite.aiPhase, "idle", "tick comum não abre ciclo de ataque do elite")

	-- Área limpa para isolar o relógio de respawn. Aos 46 s o baseline comum de
	-- 45 s já teria revivido o elite se ele ainda passasse por EnemyService.tick.
	SpatialService.setTransform(
		playerId,
		vec(anchor.position.x + 40, anchor.position.y, anchor.position.z),
		vec(-1, 0, 0)
	)
	elite.health = 0
	elite.diedAt = 6000
	EnemyService.tick(6046, 0.1)
	assertEq(elite.health, 0, "tick comum não aplica respawn de 45 s ao elite")

	EnemyService.tickElite(6179, 0.1)
	assertEq(elite.health, 0, "tickElite ainda aguarda aos 179 s")
	EnemyService.tickElite(6180, 0.1)
	assertEq(elite.health, 120, "tickElite respawna somente aos 180 s")
	local respawnedPosition = SpatialService.getPosition(fighterId)
	if respawnedPosition then
		assertEq(respawnedPosition.x, anchor.position.x, "respawn volta à âncora em x")
		assertEq(respawnedPosition.z, anchor.position.z, "respawn volta à âncora em z")
	end
	EnemyService.despawnAll()
end)

test("inimigo: leeching credita dano ≥ 1% da vida na morte do elite", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	local kills: { any } = {}
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, fighterId: string)
			table.insert(kills, { userId = userId, fighterId = fighterId })
		end,
	})
	EnemyService.spawnElite()
	local fighterId = "enemy_anchored_shard@anchor_elite#1"
	local elite = CombatService.getFighter(fighterId)
	assertTrue(elite ~= nil, "elite existe")
	if not elite then
		return
	end
	-- Jogador 970 causa 1 de dano (≥ 1% de 80); jogador 971 causa 0.5 (abaixo).
	EnemyService.registerEliteDamage(fighterId, 970, 1)
	EnemyService.registerEliteDamage(fighterId, 971, 0.5)
	elite.health = 0
	local credited = EnemyService.resolveEliteDeath(fighterId, 4000)
	assertEq(#credited, 1, "só o elegível")
	assertEq(credited[1], 970, "970 creditado")
	assertEq(#kills, 1, "um onKill")
	assertEq(kills[1].userId, 970, "autor")
	assertEq(kills[1].fighterId, fighterId, "fighter")
	-- Resolver de novo não repete (eliteDeathResolved guarda).
	EnemyService.resolveEliteDeath(fighterId, 4001)
	assertEq(#kills, 1, "idempotente")
	EnemyService.despawnAll()
end)

test("inimigo: leeching credita 8 s no raio mesmo sem causar dano", function()
	CombatService.clear()
	SpatialService.init({ geometry = Geometry })
	local kills: { any } = {}
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return {}
		end,
		onKill = function(userId: number, killedFighterId: string)
			table.insert(kills, { userId = userId, fighterId = killedFighterId })
		end,
	})
	EnemyService.spawnElite()
	local fighterId = "enemy_anchored_shard@anchor_elite#1"
	local elite = CombatService.getFighter(fighterId)
	assertTrue(elite ~= nil, "elite existe")
	if not elite then
		return
	end
	-- Jogador 972 fica 8 s no raio (sem dano): elegível por tempo.
	local elitePos = SpatialService.getPosition(fighterId)
	local playerId = "player:972"
	CombatService.createFighter(playerId, "player", 100, 100)
	SpatialService.setTransform(playerId, { x = elitePos.x + 5, y = 0, z = elitePos.z }, { x = 0, y = 0, z = 1 })
	local targets = { { fighterId = playerId, userId = 972, zoneId = "zone_plain_free" } }
	-- Reinit com o alvo elegível a aggro.
	EnemyService.init({
		getNpc = Npcs.get,
		getAnchor = Zones.getAnchor,
		shardAnchors = Zones.shardAnchors,
		spatial = SpatialService,
		combat = CombatService,
		geometry = Geometry,
		listTargets = function(): { any }
			return targets
		end,
		onKill = function(userId: number, killedFighterId: string)
			table.insert(kills, { userId = userId, fighterId = killedFighterId })
		end,
	})
	EnemyService.spawnElite()
	-- 8 ticks de 1 s dentro do raio.
	for i = 1, 8 do
		EnemyService.tickElite(5000 + i, 1)
	end
	elite.health = 0
	local credited = EnemyService.resolveEliteDeath(fighterId, 5009)
	assertEq(#credited, 1, "tempo no raio credita")
	assertEq(credited[1], 972, "972 creditado")
	assertEq(#kills, 1, "onKill disparado")
	EnemyService.despawnAll()
end)

-- ══ Testes: item 10 — objetivo Fluxo e unlock do Pulso ──────────────────────
test("objetivo: cadeia sequencial — elite só é oferecido após a caça", function()
	fakeNow = 40000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(980)
	QuestService.registerPlayer(980, fakeNow)
	-- Objetivo 1 ainda oferecido: fala com o NPC → aceita a caça.
	assertTrue(QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow), "aceita a caça")
	-- Com a caça ativa, o elite NÃO é oferecido.
	local ok, reason = QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 1)
	assertFalse(ok, "elite bloqueado enquanto a caça está ativa")
	assertEq(reason, "already_active", "motivo")
	-- Completa a caça (3 shards) e o elite é oferecido.
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 3)
	QuestService.creditKill(980, "enemy_wandering_shard", fakeNow + 4)
	assertTrue(
		QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 5),
		"elite oferecido após a caça"
	)
	assertEq(QuestService.getProgress(980, "quest_elite").state, "active", "elite ativo")
	-- Fluxo ainda bloqueado (elite ativo).
	local flowOk, flowReason = QuestService.tryAcceptFromNpc(980, "npc_threshold_instructor", fakeNow + 6)
	assertFalse(flowOk, "fluxo bloqueado enquanto o elite está ativo")
	assertEq(flowReason, "already_active", "motivo")
	ProgressionService.unregisterPlayer(980)
end)

test("objetivo: kill do elite completa, dá +60 XP e destrava a Cadência", function()
	fakeNow = 41000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(981)
	QuestService.registerPlayer(981, fakeNow)
	QuestService.tryAcceptFromNpc(981, "npc_threshold_instructor", fakeNow) -- caça
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 1)
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(981, "enemy_wandering_shard", fakeNow + 3)
	QuestService.tryAcceptFromNpc(981, "npc_threshold_instructor", fakeNow + 4) -- elite
	local events = QuestService.creditKill(981, "enemy_anchored_shard", fakeNow + 5)
	assertEq(#events, 1, "evento de conclusão")
	assertEq(events[1].state, "completed", "completo")
	assertEq(events[1].xpGranted, 60, "+60 XP do objetivo")
	assertEq(events[1].unlockFlag, "unlock_broken_cadence", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(981, "unlock_broken_cadence"), "Cadência destravada")
	assertEq(QuestService.getTracker(981), nil, "tracker some")
	ProgressionService.unregisterPlayer(981)
end)

test("objetivo: eco da Cadência completa o objetivo Fluxo e destrava o Pulso", function()
	fakeNow = 42000
	ProgressionService.init()
	QuestService.init(makeQuestDeps())
	ProgressionService.registerPlayer(982)
	QuestService.registerPlayer(982, fakeNow)
	-- Pula a caça e o elite via aceite forçado por tempo.
	QuestService.tick(982, fakeNow + 90) -- caça (90 s)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 91)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 92)
	QuestService.creditKill(982, "enemy_wandering_shard", fakeNow + 93)
	QuestService.tryAcceptFromNpc(982, "npc_threshold_instructor", fakeNow + 94) -- elite
	QuestService.creditKill(982, "enemy_anchored_shard", fakeNow + 95)
	QuestService.tryAcceptFromNpc(982, "npc_threshold_instructor", fakeNow + 96) -- fluxo
	-- Eco da Cadência: kind flow_echo, alvo broken_cadence.
	local events = QuestService.creditFlowEcho(982, "broken_cadence", fakeNow + 97)
	assertEq(#events, 1, "evento de conclusão")
	assertEq(events[1].state, "completed", "completo")
	assertEq(events[1].xpGranted, 40, "+40 XP do objetivo")
	assertEq(events[1].unlockFlag, "unlock_pulse_return", "flag no evento")
	assertTrue(ProgressionService.hasUnlock(982, "unlock_pulse_return"), "Pulso destravado")
	-- Eco de outra habilidade não conta.
	assertEq(#QuestService.creditFlowEcho(982, "comet_shoulder", fakeNow + 98), 0, "habilidade errada ignora")
	ProgressionService.unregisterPlayer(982)
end)

test("fatia: roteiro 0–60 min — caça, elite, eco e as 3 técnicas liberadas", function()
	fakeNow = 50000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	QuestService.init(makeQuestDeps())
	ResourceService.init(makeResourceDeps())
	CombatService.clear()
	CooldownService.clear(990)
	CombatService.createFighter("npc_training_dummy", "npc", 10000, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc_training_dummy")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.setPulseStance = CombatService.setPulseStance
	deps.expirePulseStance = CombatService.pulseTick
	deps.getFighterById = CombatService.getFighter
	deps.isAbilityUnlocked = ProgressionService.isAbilityUnlocked
	AbilityService.init(deps)
	ProgressionService.registerPlayer(990)
	QuestService.registerPlayer(990, fakeNow)
	CombatService.createFighter("player:990", "player", 100, 100)

	-- 0–5 min: caça (aceite no NPC, 3 shards).
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 1)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 2)
	QuestService.creditKill(990, "enemy_wandering_shard", fakeNow + 3)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_comet_shoulder"), "Cometa destravado")
	-- 15–20 min: elite → Cadência.
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow + 4)
	QuestService.creditKill(990, "enemy_anchored_shard", fakeNow + 5)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_broken_cadence"), "Cadência destravada")
	-- 45–60 min: eco → Pulso.
	QuestService.tryAcceptFromNpc(990, "npc_threshold_instructor", fakeNow + 6)
	QuestService.creditFlowEcho(990, "broken_cadence", fakeNow + 7)
	assertTrue(ProgressionService.hasUnlock(990, "unlock_pulse_return"), "Pulso destravado")

	-- As 3 técnicas agora ativam contra o dummy (cadência com eco agendado).
	local attacker = ResourceService.createState(990, "umbral_aether")
	assertTrue(attacker ~= nil, "estado de recurso")
	if attacker then
		attacker.resource = 100
		local ok, reason = AbilityService.tryActivate(attacker, "broken_cadence")
		assertTrue(ok, "cadência ativa: " .. tostring(reason))
		AbilityService.tick(fakeNow + 8)
	end
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(990)
end)

-- ══ Testes: item 11 — consolidação, morte e ProfileStore ───────────────────
local SaveService = require("../src/server/Services/SaveService")

-- Mock do adaptador ProfileStore: DataStore em memória com session lock.
local function makeMockStore()
	local stored = {} -- key → dados persistidos
	local locked = {} -- key → true (lock ativo)
	local saves = 0
	-- store declarado antes: a closure do startSession referencia a variável
	-- (quirk do Lune/MLua com closure auto-referente).
	local store: any = nil
	store = {
		stored = stored,
		saves = function()
			return saves
		end,
		startSession = function(profileKey: string): any?
			if locked[profileKey] then
				return nil -- lock de outro servidor (§11.2 item 4)
			end
			locked[profileKey] = true
			-- handle declarado antes para o closure do Save enxergar a tabela
			-- (quirk do Lune/MLua com closure auto-referente).
			local handle: any = nil
			handle = {
				Save = function()
					stored[profileKey] = table.clone(handle.Data)
					saves += 1
				end,
				EndSession = function()
					locked[profileKey] = nil
				end,
			}
			-- ProfileStore hard-copia: jogador novo recebe nil (o SaveService
			-- aplica o template); jogador existente recebe o save.
			handle.Data = if stored[profileKey] then table.clone(stored[profileKey]) else nil
			store.lastHandle = handle
			return handle
		end,
	}
	return store
end

local function makeSaveDeps(store: any): any
	return {
		store = store,
		getSessionId = function()
			return "job-test-1"
		end,
		now = clockNow,
		getSnapshot = function(userId: number)
			local snapshot = ProgressionService.snapshotForSave(userId)
			if snapshot then
				local payload = snapshot :: any
				payload.career = CareerService.snapshot(userId, clockNow())
				return payload
			end
			local career = CareerService.snapshot(userId, clockNow())
			if career then
				return { career = career }
			end
			return nil
		end,
		getCareer = function(userId: number)
			return CareerService.snapshot(userId, clockNow())
		end,
		applySnapshot = function(userId: number, snapshot: any)
			ProgressionService.restoreFromSave(userId, snapshot)
		end,
		autosaveBaseSeconds = 60,
	}
end

test("consolidação: move todo não consolidado e emite recibo idempotente", function()
	fakeNow = 60000
	ProgressionService.init()
	ProgressionService.registerPlayer(1000)
	ProgressionService.awardXp(1000, 130)
	assertEq(ProgressionService.getUnconsolidatedXp(1000), 130, "não consolidado antes")
	assertEq(ProgressionService.getLedger(1000).consolidated, 0, "consolidado antes")
	local receipt = ProgressionService.consolidate(1000, fakeNow)
	assertTrue(receipt ~= nil, "recibo emitido")
	if receipt then
		assertEq(receipt.consolidated, 130, "moveu 130")
		assertEq(receipt.operationId, "cons_1000_60000", "operationId determinístico")
	end
	assertEq(ProgressionService.getUnconsolidatedXp(1000), 0, "zerou o não consolidado")
	assertEq(ProgressionService.getLedger(1000).consolidated, 130, "consolidado 130")
	assertEq(ProgressionService.getLedger(1000).lastConsolidationAt, 60000, "timestamp")
	-- Consolidar de novo com saldo zero: recibo sem movimento.
	local empty = ProgressionService.consolidate(1000, fakeNow + 1)
	if empty then
		assertEq(empty.consolidated, 0, "nada a consolidar")
	end
	assertEq(ProgressionService.getLedger(1000).consolidated, 130, "não duplica")
	assertEq(ProgressionService.getLedger(1000).accountLevel, 2, "130 XP consolidado = nível 2")
	assertEq(ProgressionService.getLedger(1000).unspentPoints, 3, "3 pontos no level-up")
	if receipt then
		assertEq(receipt.levelsGained, 1, "subiu 1 nível")
		assertEq(receipt.pointsGranted, 3, "ganhou 3 pontos")
	end
	ProgressionService.unregisterPlayer(1000)
end)

test("progressão: gasta pontos nas trilhas e respec só na segura", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1400)
	ProgressionService.awardXp(1400, 300)
	local receipt = ProgressionService.consolidate(1400, 1)
	assertTrue(receipt ~= nil and (receipt.levelsGained or 0) >= 2, "vários níveis com 300 XP")
	local view = ProgressionService.viewFor(1400)
	assertTrue(view ~= nil, "view")
	if not view then
		return
	end
	assertTrue(view.unspentPoints >= 6, "pontos suficientes")
	local denied = ProgressionService.spendPoints(1400, "atk", 1)
	assertEq(denied.ok, false, "ATK não existe")
	local ok = ProgressionService.spendPoints(1400, "vitality", 2)
	assertEq(ok.ok, true, "gastou vitalidade")
	if ok.vitals then
		assertEq(ok.vitals.maxHealth, 104, "+2 HP por ponto")
	end
	local impact = ProgressionService.spendPoints(1400, "impact", 1)
	assertEq(impact.ok, true, "gastou impacto")
	assertTrue(ProgressionService.damageBonus(1400) > 0, "bônus de dano")
	assertTrue(ProgressionService.damageBonus(1400) <= 0.06, "abaixo do teto")
	local unsafe = ProgressionService.respecPoints(1400, false)
	assertEq(unsafe.reason, "not_safe", "respec bloqueado no campo")
	local reset = ProgressionService.respecPoints(1400, true)
	assertEq(reset.ok, true, "respec na segura")
	if reset.vitals then
		assertEq(reset.vitals.maxHealth, 100, "vida base após reset")
	end
	local snap = ProgressionService.snapshotForSave(1400)
	assertTrue(snap ~= nil and snap.accountLevel ~= nil and snap.accountLevel >= 3, "snapshot com nível")
	ProgressionService.unregisterPlayer(1400)
	ProgressionService.registerPlayer(1400)
	if snap then
		ProgressionService.restoreFromSave(1400, snap)
	end
	local restored = ProgressionService.viewFor(1400)
	assertTrue(restored ~= nil and restored.accountLevel >= 3, "nível restaurado")
	ProgressionService.unregisterPlayer(1400)
end)

test("progressão: ciclo completo de XP, nível e pontos", function()
	fakeNow = 90000
	ProgressionService.init()
	ProgressionService.registerPlayer(1800)

	-- Campo não sobe nível nem solta ponto. 85 < 86.
	ProgressionService.awardXp(1800, 85)
	local early = ProgressionService.viewFor(1800)
	assertTrue(early ~= nil, "view inicial")
	if early then
		assertEq(early.accountLevel, 1, "nível só depois de consolidar")
		assertEq(early.unspentPoints, 0, "sem ponto no campo")
		assertEq(early.pendingLevels, 0, "85 não fecha o nível 1")
		assertEq(early.previewLevel, 1, "preview ainda 1")
		assertEq(early.xpIntoLevel, 85, "barra mostra o campo")
	end
	local okBalance, balReason = ProgressionCatalog.pointsBalance(1, ProgressionCatalog.emptySpent(), 0)
	assertTrue(okBalance, balReason or "nível 1 equilibrado")

	-- +1 fecha o nível no preview, pontos ainda 0.
	ProgressionService.awardXp(1800, 1)
	local preview = ProgressionService.viewFor(1800)
	if preview then
		assertEq(preview.previewLevel, 2, "preview sobe")
		assertEq(preview.pendingLevels, 1, "1 nível pendente")
		assertEq(preview.accountLevel, 1, "conta ainda 1")
		assertEq(preview.unspentPoints, 0, "ponto só na consolidação")
		assertEq(preview.xpIntoLevel, 86, "barra cheia até consolidar")
	end

	local receipt = ProgressionService.consolidate(1800, fakeNow)
	assertTrue(receipt ~= nil, "recibo")
	if receipt then
		assertEq(receipt.consolidated, 86, "moveu 86")
		assertEq(receipt.levelsGained, 1, "subiu 1")
		assertEq(receipt.pointsGranted, 3, "3 pontos")
		assertEq(receipt.accountLevel, 2, "nível 2")
	end
	local leveled = ProgressionService.viewFor(1800)
	if leveled then
		assertEq(leveled.accountLevel, 2, "conta 2")
		assertEq(leveled.unspentPoints, 3, "3 livres")
		assertEq(leveled.pendingLevels, 0, "nada pendente")
		local balanced, why = ProgressionCatalog.pointsBalance(2, leveled.spent, leveled.unspentPoints)
		assertTrue(balanced, why or "saldo após level-up")
	end

	-- Dummy não paga XP. Estilhaço paga 25 com decréscimo por âncora.
	local dummy = Npcs.get("npc_training_dummy")
	local shard = Npcs.get("enemy_wandering_shard")
	assertTrue(dummy ~= nil and dummy.grantsXp == false, "dummy sem XP")
	local dummyAward = ProgressionService.creditNpcKill(1800, dummy, "anchor_training")
	assertEq(dummyAward.granted, 0, "dummy não credita")
	assertEq(dummyAward.reason, "no_xp_source", "motivo dummy")
	local firstKill = ProgressionService.creditNpcKill(1800, shard, "anchor_shard_1")
	assertEq(firstKill.granted, 25, "primeiro kill 25")
	for _ = 1, 5 do
		ProgressionService.creditNpcKill(1800, shard, "anchor_shard_1")
	end
	local reduced = ProgressionService.creditNpcKill(1800, shard, "anchor_shard_1")
	assertEq(reduced.granted, 12, "sétimo kill reduzido")
	local otherAnchor = ProgressionService.creditNpcKill(1800, shard, "anchor_shard_2")
	assertEq(otherAnchor.granted, 25, "outra âncora começa cheia")

	-- Morte: só come o não consolidado. Segura 0. Livre 10% / 15%. Cap 200.
	local beforeDeath = ProgressionService.getUnconsolidatedXp(1800)
	assertTrue(beforeDeath > 0, "tem campo para perder")
	local safeDeath = ProgressionService.applyDeathPenalty(1800, "safe", false)
	assertEq(safeDeath.lost, 0, "vila/bastião não perde")
	local veilDeath = ProgressionService.applyDeathPenalty(1800, "safe", true)
	assertEq(veilDeath.lost, 0, "Vila Sombria é segura")
	local pve = ProgressionService.applyDeathPenalty(1800, "free", false)
	assertEq(pve.lost, math.floor(beforeDeath * 0.10), "PvE 10%")
	ProgressionService.awardXp(1800, 3000)
	local huge = ProgressionService.getUnconsolidatedXp(1800)
	local pvp = ProgressionService.applyDeathPenalty(1800, "free", true)
	local rawPvp = math.floor(huge * 0.15)
	assertEq(pvp.lost, math.min(rawPvp, 200), "cap 200")
	assertEq(pvp.capped, rawPvp > 200, "flag de cap")
	assertEq(ProgressionService.getLedger(1800).consolidated, 86, "consolidado intacto na morte")

	-- Gasto 1/2/3, recusas, teto, vitais, respec devolve o ganho.
	local spendBad = ProgressionService.spendPoints(1800, "vitality", 0)
	assertEq(spendBad.reason, "invalid_amount", "zero inválido")
	local spendFour = ProgressionService.spendPoints(1800, "vitality", 4)
	assertEq(spendFour.reason, "invalid_amount", "4 de uma vez inválido")
	local spendOk = ProgressionService.spendPoints(1800, "vitality", 3)
	assertEq(spendOk.ok, true, "gastou 3 em vitalidade")
	if spendOk.vitals then
		assertEq(spendOk.vitals.maxHealth, 106, "100+3×2")
	end
	local afterSpend = ProgressionService.viewFor(1800)
	if afterSpend then
		local balanced, why = ProgressionCatalog.pointsBalance(2, afterSpend.spent, afterSpend.unspentPoints)
		assertTrue(balanced, why or "saldo após gasto")
		assertEq(afterSpend.unspentPoints, 0, "gastou os 3")
	end
	local noMore = ProgressionService.spendPoints(1800, "umbral", 1)
	assertEq(noMore.reason, "no_points", "sem saldo")
	local respecField = ProgressionService.respecPoints(1800, false)
	assertEq(respecField.reason, "not_safe", "respec só na segura")
	local respecOk = ProgressionService.respecPoints(1800, true)
	assertEq(respecOk.ok, true, "respec")
	if respecOk.vitals then
		assertEq(respecOk.vitals.maxHealth, 100, "vida base")
	end
	local afterRespec = ProgressionService.viewFor(1800)
	if afterRespec then
		assertEq(afterRespec.unspentPoints, 3, "pontos devolveram")
		local balanced, why = ProgressionCatalog.pointsBalance(2, afterRespec.spent, afterRespec.unspentPoints)
		assertTrue(balanced, why or "saldo após respec")
	end

	-- Teto GDD: 100 impacto = 6%. Curva 2×n^2,3+84.
	assertEq(ProgressionCatalog.xpToNextLevel(2), 93, "nível 2")
	assertEq(ProgressionCatalog.xpToNextLevel(3), 109, "nível 3")
	local maxed = ProgressionCatalog.emptySpent()
	maxed.impact = 100
	assertEq(ProgressionCatalog.vitalsFor(maxed).damageBonus, 0.06, "teto impacto")
	assertEq(ProgressionCatalog.scaleDamage(14, 0.06), 15, "cometa com teto")
	assertEq(ProgressionCatalog.canSpend(maxed, 3, "impact", 1), "track_cap", "trilha 100")

	-- Persistência: sessão (emitted) zera; nível/pontos/gastos voltam.
	ProgressionService.spendPoints(1800, "guard", 2)
	local snap = ProgressionService.snapshotForSave(1800)
	assertTrue(snap ~= nil, "snapshot")
	if snap then
		assertEq(snap.accountLevel, 2, "nível persistido")
		assertEq(snap.consolidatedXp, 86, "XP banco persistido")
	end
	local emittedBefore = ProgressionService.getLedger(1800).emitted
	assertTrue(emittedBefore > 0, "sessão emitiu")
	ProgressionService.unregisterPlayer(1800)
	ProgressionService.registerPlayer(1800)
	if snap then
		ProgressionService.restoreFromSave(1800, snap)
	end
	assertEq(ProgressionService.getLedger(1800).emitted, 0, "teto de sessão recomeça")
	local back = ProgressionService.viewFor(1800)
	if back then
		assertEq(back.accountLevel, 2, "nível voltou")
		assertEq(back.spent.guard, 2, "guarda persistiu")
		assertEq(back.unspentPoints, 1, "1 ponto livre")
		assertEq(back.vitals.maxGuard, 104, "vital de guarda")
		local balanced, why = ProgressionCatalog.pointsBalance(2, back.spent, back.unspentPoints)
		assertTrue(balanced, why or "saldo restaurado")
	end

	-- Restore podre (gastou mais do que ganhou) zera trilhas.
	ProgressionService.unregisterPlayer(1801)
	ProgressionService.registerPlayer(1801)
	ProgressionService.restoreFromSave(1801, {
		consolidatedXp = 86,
		unconsolidatedXp = 0,
		lastConsolidationAt = 1,
		tutorialFlags = {},
		unlockedAbilities = {},
		accountLevel = 2,
		unspentProgressionPoints = 0,
		spentTracks = {
			vitality = 50,
			umbral = 0,
			impact = 0,
			guard = 0,
			resonance = 0,
		},
	})
	local cleaned = ProgressionService.viewFor(1801)
	if cleaned then
		assertEq(cleaned.spent.vitality, 0, "gasto impossível descartado")
		assertEq(cleaned.unspentPoints, 3, "saldo reconcilia para o ganho real")
		local balanced, why = ProgressionCatalog.pointsBalance(2, cleaned.spent, cleaned.unspentPoints)
		assertTrue(balanced, why or "restore podre reconcilia")
	end

	-- Vários níveis num único consolidate.
	ProgressionService.registerPlayer(1802)
	local need = ProgressionCatalog.cumulativeXpForLevel(5)
	ProgressionService.awardXp(1802, need)
	local multi = ProgressionService.consolidate(1802, fakeNow + 10)
	if multi then
		assertEq(multi.accountLevel, 5, "nível 5 de uma vez")
		assertEq(multi.levelsGained, 4, "1→5")
		assertEq(multi.pointsGranted, 12, "4×3")
	end
	local multiView = ProgressionService.viewFor(1802)
	if multiView then
		local balanced, why = ProgressionCatalog.pointsBalance(5, multiView.spent, multiView.unspentPoints)
		assertTrue(balanced, why or "vários níveis")
	end

	ProgressionService.unregisterPlayer(1800)
	ProgressionService.unregisterPlayer(1801)
	ProgressionService.unregisterPlayer(1802)
end)

test("dados: SpendProgressionIntent tem contrato C→S", function()
	local contract = Remotes.Contracts.get("SpendProgressionIntent")
	assertTrue(contract ~= nil, "contrato existe")
	if contract then
		assertEq(contract.direction, "ClientToServer", "intenção do cliente")
		assertTrue(contract.payload:find("trackId", 1, true) ~= nil, "trilha no payload")
	end
end)

test("morte: segura/treino não perde; livre PvE 10% e PvP 15% com cap 200", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1001)
	ProgressionService.awardXp(1001, 500)
	local safe = ProgressionService.applyDeathPenalty(1001, "safe", false)
	assertEq(safe.lost, 0, "segura não perde")
	assertEq(safe.reason, "safe_zone", "motivo")
	local transition = ProgressionService.applyDeathPenalty(1001, "transition", true)
	assertEq(transition.lost, 0, "transição não perde")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 500, "saldo intacto")
	local pve = ProgressionService.applyDeathPenalty(1001, "free", false)
	assertEq(pve.lost, 50, "10% de 500 = 50")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 450, "perdeu 50")
	local pvp = ProgressionService.applyDeathPenalty(1001, "free", true)
	assertEq(pvp.lost, 67, "15% de 450 = 67 (floor)")
	assertEq(ProgressionService.getUnconsolidatedXp(1001), 383, "perdeu 67")
	assertEq(ProgressionService.getLedger(1001).consolidated, 0, "consolidado nunca é perdido")
	ProgressionService.unregisterPlayer(1001)
end)

test("morte: cap de 200 aplica em saldo grande", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1002)
	-- Saldo alto (acima do teto de emissão da sessão, via restore simulado).
	ProgressionService.restoreFromSave(1002, {
		consolidatedXp = 0,
		unconsolidatedXp = 3000,
		lastConsolidationAt = 0,
		tutorialFlags = {},
		unlockedAbilities = {},
	})
	local pvp = ProgressionService.applyDeathPenalty(1002, "free", true)
	assertEq(pvp.lost, 200, "cap 200 (15% de 3000 = 450)")
	assertEq(pvp.capped, true, "cap sinalizado")
	assertEq(ProgressionService.getUnconsolidatedXp(1002), 2800, "3000 - 200")
	-- PvE também respeita o cap.
	local pve = ProgressionService.applyDeathPenalty(1002, "free", false)
	assertEq(pve.lost, 200, "cap 200 no PvE (10% de 2800 = 280)")
	assertEq(ProgressionService.getUnconsolidatedXp(1002), 2600, "2800 - 200")
	-- Jogador desconhecido não quebra.
	local ghost = ProgressionService.applyDeathPenalty(999, "free", true)
	assertEq(ghost.lost, 0, "desconhecido 0")
	ProgressionService.unregisterPlayer(1002)
end)

test("save: leave persiste flags e XP (item 1 da §11.2)", function()
	fakeNow = 61000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1010)
	local profile = SaveService.loadProfile(1010)
	assertTrue(profile ~= nil, "perfil aberto")
	-- Joga: ganha XP, desbloqueia, suja o perfil.
	ProgressionService.awardXp(1010, 90)
	ProgressionService.grantUnlock(1010, "unlock_comet_shoulder")
	SaveService.markDirty(1010)
	SaveService.releaseProfile(1010) -- leave: salva se sujo e libera o lock
	assertFalse(SaveService.hasOpenProfile(1010), "lock liberado")
	assertTrue(store.stored["player:1010"] ~= nil, "save escrito")
	-- Rejoin (novo servidor): o save restaura flags e XP.
	ProgressionService.unregisterPlayer(1010)
	ProgressionService.registerPlayer(1010)
	local restored = SaveService.loadProfile(1010)
	assertTrue(restored ~= nil, "reabre")
	assertEq(ProgressionService.getUnconsolidatedXp(1010), 90, "XP restaurado")
	assertTrue(ProgressionService.hasUnlock(1010, "unlock_comet_shoulder"), "flag restaurada")
	SaveService.releaseProfile(1010)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1010)
end)

test("save: crash no autosave não duplica unlock (item 2 da §11.2)", function()
	fakeNow = 62000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1011)
	SaveService.loadProfile(1011)
	ProgressionService.grantUnlock(1011, "unlock_broken_cadence")
	SaveService.markDirty(1011)
	SaveService.saveProfile(1011) -- autosave 1
	SaveService.saveProfile(1011) -- sem dirty: não reescreve
	assertEq(store.saves(), 1, "um save para um dirty")
	assertEq(#ProgressionService.listUnlocks(1011), 1, "uma flag na sessão")
	-- Restaura do save: flag não duplica (grantUnlock idempotente).
	local saved = store.stored["player:1011"]
	assertEq(#saved.progression.tutorialFlags, 1, "uma flag persistida")
	-- Reaplica o snapshot salvo (como um crash que religa e reconstrói a
	-- sessão a partir do último save): a flag continua única.
	SaveService.releaseProfile(1011)
	ProgressionService.unregisterPlayer(1011)
	ProgressionService.registerPlayer(1011)
	SaveService.loadProfile(1011)
	assertEq(#ProgressionService.listUnlocks(1011), 1, "sem duplicar no rejoin")
	SaveService.releaseProfile(1011)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1011)
end)

test("save: rejoin no mesmo servidor devolve a sessão aberta (item 3)", function()
	fakeNow = 63000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1012)
	local first = SaveService.loadProfile(1012)
	ProgressionService.awardXp(1012, 25)
	SaveService.markDirty(1012)
	local second = SaveService.loadProfile(1012)
	assertTrue(second ~= nil, "rejoin abre")
	assertTrue(first == second, "mesma sessão (mesma tabela)")
	assertEq(ProgressionService.getUnconsolidatedXp(1012), 25, "estado da sessão mantido")
	SaveService.releaseProfile(1012)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1012)
end)

test("save: segundo servidor recusa sessão concorrente (item 4)", function()
	fakeNow = 64000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1013)
	-- Servidor A abre o lock.
	local serverA = SaveService.loadProfile(1013)
	assertTrue(serverA ~= nil, "servidor A abriu")
	-- Servidor B (mesmo store) não consegue: startSession devolve nil.
	SaveService.init(makeSaveDeps(store))
	ProgressionService.unregisterPlayer(1013)
	ProgressionService.registerPlayer(1013)
	local serverB = SaveService.loadProfile(1013)
	assertTrue(serverB == nil, "servidor B recusado (lock)")
	assertFalse(SaveService.hasOpenProfile(1013), "sem sessão aberta")
	-- Servidor A sai (EndSession) → o lock libera → B consegue abrir.
	store.lastHandle.EndSession()
	local reopened = SaveService.loadProfile(1013)
	assertTrue(reopened ~= nil, "após o A liberar, B abre")
	SaveService.releaseProfile(1013)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1013)
end)

test("save: falha injetada no load não entra com default por cima (item 5)", function()
	fakeNow = 65000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1014)
	SaveService.loadProfile(1014)
	ProgressionService.awardXp(1014, 50)
	SaveService.markDirty(1014)
	SaveService.releaseProfile(1014) -- save existe: 50 XP não consolidado
	assertTrue(store.stored["player:1014"] ~= nil, "save existente")
	-- Próximo load falha (startSession devolve nil por erro de rede simulado).
	local failing = {
		stored = store.stored,
		startSession = function()
			return nil
		end,
	}
	SaveService.init({
		store = failing,
		getSessionId = function()
			return "job-fail"
		end,
		now = clockNow,
	})
	ProgressionService.unregisterPlayer(1014)
	ProgressionService.registerPlayer(1014)
	local profile = SaveService.loadProfile(1014)
	assertTrue(profile == nil, "load falho → nil")
	assertFalse(SaveService.hasOpenProfile(1014), "sem sessão")
	assertTrue(store.stored["player:1014"] ~= nil, "save NÃO foi sobrescrito por default")
	-- O save original continua intacto (50 XP).
	assertEq(store.stored["player:1014"].progression.unconsolidatedXp, 50, "save intacto")
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1014)
end)

test("save: anel de recentOperations limita a 32 recibos", function()
	fakeNow = 66000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1015)
	local profile = SaveService.loadProfile(1015)
	assertTrue(profile ~= nil, "perfil")
	for i = 1, 40 do
		SaveService.appendOperation(1015, { operationId = ("op_%d"):format(i), kind = "test", at = fakeNow + i })
	end
	assertEq(#profile.recentOperations, 32, "anel limitado a 32")
	assertEq(profile.recentOperations[1].operationId, "op_9", "mais antigo descartado")
	assertEq(profile.recentOperations[32].operationId, "op_40", "mais recente presente")
	SaveService.releaseProfile(1015)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1015)
end)

-- ══ Runner ─────────────────────────────────────────────────────────────────
print("")
print("== Testes F0 — Anime Verse Battlegrounds ==")
print("")

test("carreira: totais autoritativos persistem no snapshot", function()
	CareerService.init()
	CareerService.registerPlayer(1600, 100)
	CareerService.creditKill(1600, "enemy_wandering_shard", false)
	CareerService.creditKill(1600, "enemy_anchored_shard", true)
	CareerService.creditKill(1600, "npc_training_dummy", false)
	CareerService.creditDamage(1600, 14)
	CareerService.creditDamage(1600, 6)
	CareerService.creditDeath(1600)
	CareerService.creditTechnique(1600)
	CareerService.creditConsolidation(1600)
	CareerService.creditQuest(1600)
	local live = CareerService.viewFor(1600, 160)
	assertTrue(live ~= nil, "view")
	if live then
		assertEq(live.monsterKills, 1, "dummy não conta")
		assertEq(live.bossKills, 1, "elite")
		assertEq(live.damageDealt, 20, "dano")
		assertEq(live.playTimeSeconds, 60, "sessão 60 s")
		assertEq(live.deaths, 1, "queda")
		assertEq(live.techniquesUsed, 1, "técnica")
		assertEq(live.consolidations, 1, "marco")
		assertEq(live.questsCompleted, 1, "missão")
	end
	local snap = CareerService.snapshot(1600, 160)
	CareerService.unregisterPlayer(1600, 160)
	CareerService.registerPlayer(1600, 200)
	CareerService.restore(1600, snap, 200)
	local restored = CareerService.viewFor(1600, 200)
	assertTrue(restored ~= nil, "restore")
	if restored and snap then
		assertEq(restored.monsterKills, snap.monsterKills, "monstros")
		assertEq(restored.bossKills, snap.bossKills, "chefes")
		assertEq(restored.damageDealt, snap.damageDealt, "dano")
		assertEq(restored.playTimeSeconds, snap.playTimeSeconds, "tempo persistido")
	end
	assertEq(CareerService.formatPlayTime(75), "1m 15s", "formato")
	CareerService.unregisterPlayer(1600, 200)
end)

test("save: carreira persiste no leave sem markDirty manual", function()
	fakeNow = 68000
	ProgressionService.init()
	ProgressionService.setNow(clockNow)
	CareerService.init()
	CareerService.registerPlayer(1610, fakeNow)
	CareerService.creditKill(1610, "enemy_wandering_shard", false)
	CareerService.creditKill(1610, "enemy_anchored_shard", true)
	CareerService.creditDamage(1610, 42)
	CareerService.creditTechnique(1610)
	CareerService.creditDeath(1610)
	local store = makeMockStore()
	SaveService.init(makeSaveDeps(store))
	ProgressionService.registerPlayer(1610)
	local profile = SaveService.loadProfile(1610)
	assertTrue(profile ~= nil, "perfil")
	assertFalse((SaveService.getProfile(1610) :: any) == nil, "sessão aberta")
	-- Ordem do leave vivo: progressão sai, depois o release. Sem markDirty.
	ProgressionService.unregisterPlayer(1610)
	SaveService.releaseProfile(1610)
	CareerService.unregisterPlayer(1610, fakeNow)
	ProgressionService.registerPlayer(1610)
	CareerService.registerPlayer(1610, fakeNow + 10)
	local restored = SaveService.loadProfile(1610)
	assertTrue(restored ~= nil and type(restored.career) == "table", "career no save")
	if restored then
		CareerService.restore(1610, restored.career, fakeNow + 10)
	end
	local view = CareerService.viewFor(1610, fakeNow + 10)
	assertTrue(view ~= nil, "view")
	if view then
		assertEq(view.monsterKills, 1, "errante persistiu")
		assertEq(view.bossKills, 1, "elite persistiu")
		assertEq(view.damageDealt, 42, "dano persistiu")
		assertEq(view.techniquesUsed, 1, "técnica persistiu")
		assertEq(view.deaths, 1, "queda persistiu")
	end
	SaveService.releaseProfile(1610)
	CareerService.unregisterPlayer(1610, fakeNow + 10)
	ProgressionService.setNow(nil)
	ProgressionService.unregisterPlayer(1610)
end)

test("carreira: Cometa e Cadência creditam dano no AbilityService", function()
	fakeNow = 70000
	CareerService.init()
	CareerService.registerPlayer(1622, fakeNow)
	ResourceService.init(makeResourceDeps())
	CooldownService.clear(1622)
	CombatService.clear()
	CombatService.createFighter("player:1622", "player", 100, 100)
	local shard = CombatService.createFighter("npc:career-shard", "npc", 200, 0)
	local deps = makeAbilityDeps()
	deps.getAttackerFighter = function(userId: number)
		return CombatService.getFighter(CombatService.playerFighterId(userId))
	end
	deps.getFighterById = CombatService.getFighter
	deps.getAbilityTarget = function(_userId: number)
		return CombatService.getFighter("npc:career-shard")
	end
	deps.tryCometShoulder = CombatService.tryCometShoulder
	deps.tryCadenceHit = function(attacker: any, target: any, currentNow: number, damage: number, _facing: string)
		return CombatService.tryCadenceHit(attacker, target, currentNow, damage, "front")
	end
	deps.setPulseStance = CombatService.setPulseStance
	AbilityService.init(deps)
	local attacker = ResourceService.createState(1622, "umbral_aether")
	assertTrue(attacker ~= nil, "attacker")
	if not attacker then
		return
	end
	local cometOk, cometReason = AbilityService.tryActivate(attacker, "comet_shoulder")
	assertTrue(cometOk, "cometa: " .. tostring(cometReason))
	local afterComet = CareerService.viewFor(1622, fakeNow)
	assertTrue(afterComet ~= nil, "view cometa")
	if afterComet then
		assertEq(afterComet.damageDealt, 14, "Cometa no placar")
	end
	CooldownService.clear(1622)
	local cadOk, cadReason = AbilityService.tryActivate(attacker, "broken_cadence", shard)
	assertTrue(cadOk, "cadência: " .. tostring(cadReason))
	AbilityService.tick(fakeNow + 0.14)
	AbilityService.tick(fakeNow + 0.32)
	local afterCad = CareerService.viewFor(1622, fakeNow)
	assertTrue(afterCad ~= nil, "view cadência")
	if afterCad then
		assertEq(afterCad.damageDealt, 30, "14 + 7 + 9")
	end
	CooldownService.clear(1622)
	local pulseOk, pulseReason = AbilityService.tryActivate(attacker, "pulse_return")
	assertTrue(pulseOk, "pulso: " .. tostring(pulseReason))
	CareerService.creditFromFighterId("player:1622", 10)
	local afterPulse = CareerService.viewFor(1622, fakeNow)
	if afterPulse then
		assertEq(afterPulse.damageDealt, 40, "contra do Pulso no placar")
	end
	CareerService.unregisterPlayer(1622, fakeNow)
	CombatService.clear()
end)

test("bots: nível vem do catálogo e não é string vazia", function()
	local shard = Npcs.get("enemy_wandering_shard")
	local elite = Npcs.get("enemy_anchored_shard")
	assertEq(Npcs.levelLabel(shard), "Nv. 8", "errante")
	assertEq(Npcs.levelLabel(elite), "Nv. 18", "elite")
	assertTrue(Npcs.levelLabel(shard) ~= "", "rótulo")
end)

test("muralha: paleta usa mais de um material, não Slate único", function()
	local style = require("../src/shared/Data/SceneryPresentation").style()
	assertTrue(style.wallMaterial ~= "Slate", "corpo não é Slate")
	assertTrue(style.wallMaterial ~= style.wallCapMaterial, "tampa distinta")
end)

test("técnicas F0: as três existem, têm VFX e desbloqueiam no caminho real", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1601)
	for _, abilityId in { "comet_shoulder", "broken_cadence", "pulse_return" } do
		local ab = Abilities.get(abilityId)
		assertTrue(ab ~= nil and ab.enabled, abilityId .. " no catálogo")
		assertTrue(AbilityVfx.get(abilityId) ~= nil, abilityId .. " tem VFX")
		assertFalse(ProgressionService.isAbilityUnlocked(1601, abilityId), abilityId .. " começa locked")
	end
	assertTrue(ProgressionService.grantUnlock(1601, "unlock_comet_shoulder"), "grant cometa")
	assertTrue(ProgressionService.grantUnlock(1601, "unlock_broken_cadence"), "grant cadência")
	assertTrue(ProgressionService.grantUnlock(1601, "unlock_pulse_return"), "grant pulso")
	assertTrue(ProgressionService.isAbilityUnlocked(1601, "comet_shoulder"), "cometa unlock")
	assertTrue(ProgressionService.isAbilityUnlocked(1601, "broken_cadence"), "cadência unlock")
	assertTrue(ProgressionService.isAbilityUnlocked(1601, "pulse_return"), "pulso unlock")
	ProgressionService.unregisterPlayer(1601)
end)

test("HUD: XP flutuante só com valor positivo do servidor", function()
	assertTrue(CombatHudController.shouldShowXp({ amount = 25, targetId = "e1" }), "kill mostra XP")
	assertFalse(CombatHudController.shouldShowXp({ amount = 0 }), "zero some")
	assertFalse(CombatHudController.shouldShowXp({}), "sem amount some")
	assertFalse(CombatHudController.shouldShowXp({ amount = 25, view = "taken" }), "quem apanha não vê")
	assertEq(CombatHudController.xpText(25), "+25 XP", "texto")
	local rgb = CombatHudController.xpColor()
	assertEq(rgb[1], 255, "dourado")
	assertEq(rgb[1], UiPalette.xpColor()[1], "XP vem da paleta")
end)

test("ui: paleta semântica valida e o ghost só decai rumo ao atual", function()
	local ok, reason = UiPalette.validate()
	assertTrue(ok, reason or "paleta")
	assertEq(UiPalette.damageColor("hit")[1], 255, "acerto branco")
	assertEq(UiPalette.damageColor("guard")[2], 190, "guarda")
	assertEq(UiPalette.zoneFill(true)[1], UiPalette.pvp[1], "pvp")
	assertEq(UiPalette.zoneFill(false)[2], UiPalette.safe[2], "seguro")
	assertEq(UiPalette.enemyFill(0.2, true)[1], UiPalette.enemyElite[1], "elite")
	local dropped = UiPalette.ghostFraction(0.4, 0.9, 0.2, 1)
	assertTrue(dropped < 0.9 and dropped >= 0.4, "ghost desce")
	assertEq(UiPalette.ghostFraction(0.6, 0.3, 1, 4), 0.6, "não passa do atual")
end)

test("evolução: flash nasce, pico e some", function()
	assertTrue(LevelUpPlayer.shouldPlay({ levelsGained = 1 }), "toca no level-up")
	assertFalse(LevelUpPlayer.shouldPlay({ levelsGained = 0 }), "sem nível não toca")
	assertTrue(LevelUpPlayer.flashAlpha(0.2, 1.6) > 0.4, "vê o brilho")
	assertEq(LevelUpPlayer.flashAlpha(1.6, 1.6), 0, "some no fim")
	assertTrue(LevelUpPlayer.ringScale(1.6, 1.6) > 1, "anel abre")
end)

test("mochila: concede material sem poder e respeita teto", function()
	InventoryService.init({ getItem = Items.get, capacity = 30 })
	InventoryService.registerPlayer(1500)
	local wrap = InventoryService.grant(1500, "traveler_wrap", 1)
	assertEq(wrap.granted, 1, "faixa inicial")
	local frag = InventoryService.grant(1500, "shard_fragment", 2)
	assertEq(frag.granted, 2, "fragmentos")
	assertEq(InventoryService.count(1500, "shard_fragment"), 2, "saldo")
	local full = InventoryService.grant(1500, "traveler_wrap", 1)
	assertEq(full.reason, "stack_cap", "cosmético não empilha além de 1")
	local unknown = InventoryService.grant(1500, "atk_potion", 1)
	assertEq(unknown.reason, "unknown_item", "item de poder recusado")
	local loot = Items.lootForNpc("enemy_wandering_shard")
	assertEq(#loot, 1, "loot do errante")
	assertEq(loot[1].itemId, "shard_fragment", "fragmento")
	local snap = InventoryService.snapshot(1500)
	InventoryService.unregisterPlayer(1500)
	InventoryService.registerPlayer(1500)
	InventoryService.restore(1500, snap)
	assertEq(InventoryService.count(1500, "shard_fragment"), 2, "restore")
	InventoryService.unregisterPlayer(1500)
end)

test("progressão: a barra enche com XP do campo antes de consolidar", function()
	ProgressionService.init()
	ProgressionService.registerPlayer(1501)
	ProgressionService.awardXp(1501, 80)
	local view = ProgressionService.viewFor(1501)
	assertTrue(view ~= nil, "view")
	if view then
		assertEq(view.accountLevel, 1, "ainda nível 1")
		assertEq(view.xpIntoLevel, 80, "barra mostra o campo")
		assertEq(view.xpToNext, 86, "próximo em 86")
		assertEq(view.pendingLevels, 0, "ainda não cruzou")
	end
	ProgressionService.awardXp(1501, 10)
	local ready = ProgressionService.viewFor(1501)
	if ready then
		assertEq(ready.pendingLevels, 1, "pronto para evoluir")
		assertEq(ready.xpIntoLevel, 86, "barra cheia")
	end
	ProgressionService.unregisterPlayer(1501)
end)

test("cliente: snapshot e delta carregam nível e pontos", function()
	local state = ClientState.new(clockNow)
	assertTrue(
		ClientState.applySnapshot(state, {
			ready = true,
			accountLevel = 4,
			xpIntoLevel = 20,
			xpToNext = 132,
			unspentPoints = 6,
			pendingLevels = 1,
			spent = { vitality = 2, umbral = 0, impact = 0, guard = 0, resonance = 0 },
			career = { monsterKills = 3, bossKills = 1, damageDealt = 40, playTimeSeconds = 75 },
		}),
		"snapshot aceito"
	)
	assertEq(state.accountLevel, 4, "nível")
	assertEq(state.unspentPoints, 6, "pontos")
	assertEq(state.spent.vitality, 2, "trilha")
	assertTrue(state.career ~= nil, "carreira no snapshot")
	if state.career then
		assertEq(state.career.monsterKills, 3, "kills na réplica")
		assertEq(state.career.playTimeSeconds, 75, "tempo na réplica")
	end
	ClientState.applyDelta(state, {
		unspentPoints = 5,
		feedbackKey = "hud.feedback_spent",
		career = { monsterKills = 4, bossKills = 1, damageDealt = 46, playTimeSeconds = 80 },
	})
	assertEq(state.unspentPoints, 5, "gasto chegou")
	assertEq(ClientState.feedback(state), "hud.feedback_spent", "feedback do gasto")
	if state.career then
		assertEq(state.career.monsterKills, 4, "delta atualiza carreira")
	end
end)

test("combate: impacto escala o pesado e respeita o teto de 6%", function()
	CombatService.clear()
	local attacker = CombatService.createFighter("p:scale", "player", 100, 100)
	local target = CombatService.createFighter("n:scale", "npc", 200, 100)
	CombatService.applyVitals("p:scale", 104, 100, 0.06)
	assertEq(attacker.maxHealth, 104, "vida sobe")
	local heavy = CombatService.tryHeavy(attacker, target, 10, "front")
	assertEq(heavy.damage, 13, "12 × 1,06 = 13")
	CombatService.clear()
end)

test("cliente: cooldown parametrizado nunca aparece como codigo interno", function()
	local state = ClientState.new(clockNow)
	ClientState.applySnapshot(state, { ready = true })
	local feedback = CombatFeedbackController.new(state, ClientState)
	CombatFeedbackController.onRejected(feedback, { reason = "cooldown:6.9" })
	assertEq(ClientState.feedback(state), "hud.feedback_cooldown", "chave localizada")
end)

local function runAll()
	for _, t in tests do
		local ok, err = pcall(t.fn)
		if ok then
			passed += 1
			print(("  ✅ %s"):format(t.name))
		else
			failed += 1
			print(("  ❌ %s"):format(t.name))
			print(("     %s"):format(tostring(err):gsub("\n", "\n     ")))
		end
	end
	print("")
	print(("Resultado: %d passaram, %d falharam"):format(passed, failed))
	if failed > 0 then
		error("Há testes falhando")
	end
end

runAll()

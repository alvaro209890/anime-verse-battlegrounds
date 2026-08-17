--!strict
-- Simulação de combate ponta a ponta (headless).
-- Uso: lune run tests/combat_e2e.luau
--
-- POR QUE ESTE ARQUIVO EXISTE
--
-- `docs/14` §4.8 e o item 1 do recorte executivo de `docs/06` §5 registram o
-- mesmo buraco: a camada de impacto — hit-stop, tremida de câmera, luz, som e
-- número de dano — **nunca rodou uma vez sequer**. Não por defeito: o jogador
-- estava a 41,2 studs do único alvo vivo e o alcance do golpe leve é 9, então
-- nenhum `CombatEvent` de acerto jamais chegou ao cliente. Todo aquele código
-- estava certo e mudo, e nenhuma suíte reclamava, porque cada peça era testada
-- sozinha.
--
-- Aqui a cadeia inteira roda: posição → aquisição em cone → resolução no
-- servidor → `CombatEvent` → as cinco reações do cliente → `StateDelta`. A
-- prova é por EFEITO OBSERVÁVEL (evento emitido, trauma acumulado, hit-stop
-- ativo, deixa de áudio resolvida, número autorizado, vida replicada), não por
-- instrumentação de módulo — `require` num teste devolve uma cópia do módulo, e
-- foi exatamente essa confusão que sustentou quatro rodadas de diagnóstico
-- errado em 14/08.
--
-- ⚠️ O QUE ISTO **NÃO** É. Continua sendo headless: não prova Parts, física,
-- render, latência, input real, câmera de verdade nem desempenho. W1/A1/R1/W2
-- seguem pendentes de Play (`docs/32-STUDIO-PLAYTEST-RUNBOOK.md`). O que esta
-- suíte garante é que, no dia em que o Studio abrir, a cadeia já foi exercida
-- de ponta a ponta em contrato e o que sobrar de erro é runtime.

require("./harness")

local fs = require("@lune/fs")

local Geometry = require("../src/shared/Geometry")
local SpatialService = require("../src/server/Services/SpatialService")
local CombatService = require("../src/server/Services/CombatService")
local CombatAudio = require("../src/shared/Data/CombatAudio")
local AbilityVfx = require("../src/shared/Data/AbilityVfx")
local Abilities = require("../src/shared/Data/Abilities")
local ClientState = require("../src/client/Controllers/ClientState")
local CombatFeedbackController = require("../src/client/Controllers/CombatFeedbackController")
local CombatHudController = require("../src/client/Controllers/CombatHudController")
local CombatCameraController = require("../src/client/Presentation/CombatCameraController")
local PlayerCombatAnimator = require("../src/client/Presentation/PlayerCombatAnimator")

local passed = 0
local failed = 0
local currentTest = ""

local function test(name: string, body: () -> ())
	currentTest = name
	local ok, err = pcall(body)
	if ok then
		passed += 1
		print(("[ok]   %s"):format(name))
	else
		failed += 1
		print(("[FALHA] %s\n        %s"):format(name, tostring(err)))
	end
end

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error(("%s (em: %s)"):format(message, currentTest), 2)
	end
end

local function assertFalse(condition: boolean, message: string)
	assertTrue(not condition, message)
end

local function assertEq(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(("%s — esperado %s, obtido %s"):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local function vec(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

-- ── Constantes do handler real ──────────────────────────────────────────────
-- Cópias de `src/server/init.server.lua`. A simulação só vale se estes números
-- forem os do jogo, então o primeiro teste confere a fonte: mexeu lá e esqueceu
-- aqui, a suíte quebra em vez de simular um combate que não existe.
local BASIC_RANGE_STUDS = 6
local BODY_ALLOWANCE_STUDS = 3
local LIGHT_REACH: { number } = {
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 1,
}
local HEAVY_REACH = BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5
local LIGHT_HALF_ANGLE = 65
local HEAVY_HALF_ANGLE = 50
-- A distância histórica do playtest de 14/08, que é o caso que abre a suíte.
local PLAYTEST_DISTANCE_STUDS = 41.2

-- ── Mundo simulado ──────────────────────────────────────────────────────────
-- Um "servidor" e um "cliente" ligados pelo mesmo `CombatEvent`/`StateDelta`
-- que o `init.server.lua` emite e o `init.client.lua` consome. A fiação abaixo
-- espelha os dois handlers linha a linha; qualquer divergência é bug do teste.

type Sim = {
	now: number,
	attackerId: string,
	targetId: string,
	events: { { [string]: any } },
	deltas: { { [string]: any } },
	cues: { string },
	numbers: { { damage: number, rgb: { number } } },
	camera: any,
	animator: any,
	state: any,
	feedback: any,
	vfxConfirmed: { [string]: boolean },
}

local function newSim(distanceStuds: number, targetKind: string?): Sim
	local sim: Sim
	local clock = 1000
	local function now(): number
		return sim.now
	end

	SpatialService.init({ geometry = Geometry })
	SpatialService.clear()
	CombatService.clear()

	local attackerId = CombatService.playerFighterId(4242)
	local targetId = if targetKind == "player" then CombatService.playerFighterId(777) else "npc:dummy@treino"
	CombatService.createFighter(attackerId, "player", 100, 100)
	CombatService.createFighter(targetId, if targetKind == "player" then "player" else "npc", 100, 100)

	-- O alvo fica ao norte (−Z) e o atacante olha para ele: é a geometria do
	-- pad de treino, e é o que o cone de aquisição precisa enxergar.
	SpatialService.setTransform(attackerId, vec(0, 0, 0), vec(0, 0, -1))
	SpatialService.setTransform(targetId, vec(0, 0, -distanceStuds), vec(0, 0, 1))

	local state = ClientState.new(now)
	state.ready = true

	sim = {
		now = clock,
		attackerId = attackerId,
		targetId = targetId,
		events = {},
		deltas = {},
		cues = {},
		numbers = {},
		camera = CombatCameraController.new({}),
		animator = PlayerCombatAnimator.new({ player = nil, runService = nil, now = now }),
		state = state,
		feedback = CombatFeedbackController.new(state, ClientState),
		vfxConfirmed = {},
	}
	return sim
end

-- Cliente: a MESMA ordem de reações do `init.client.lua` no `CombatEvent`.
local function receiveCombatEvent(sim: Sim, payload: { [string]: any }): ()
	table.insert(sim.events, payload)
	CombatFeedbackController.onCombatEvent(sim.feedback, payload)
	local cue = CombatAudio.impactId(payload.abilityId, payload.outcome)
	if cue then
		table.insert(sim.cues, cue)
	end
	PlayerCombatAnimator.confirmHit(sim.animator, payload.outcome)
	CombatCameraController.addImpact(sim.camera, payload.outcome, payload.abilityId)
	-- `AbilityVfxPlayer.confirm` só marca a entrada ativa; o efeito observável
	-- da confirmação é o `planAt` passar a devolver as camadas de contato.
	local confirming = payload.outcome == "hit"
		or payload.outcome == "guard"
		or payload.outcome == "counter"
		or payload.outcome == "death"
	if confirming and type(payload.abilityId) == "string" then
		sim.vfxConfirmed[payload.abilityId] = true
	end
	if CombatHudController.shouldShowDamage(payload) then
		table.insert(sim.numbers, {
			damage = payload.damage,
			rgb = CombatHudController.damageColor(payload.outcome),
		})
	end
end

-- Servidor: replica `fireVitalsForFighter` para o alvo NPC (com fighterId) ou
-- jogador (vitals puras).
local function fireVitals(sim: Sim, fighterId: string): ()
	local fighter = CombatService.getFighter(fighterId)
	if not fighter then
		return
	end
	local delta: { [string]: any } = {
		health = fighter.health,
		maxHealth = fighter.maxHealth,
		guard = fighter.guard,
		maxGuard = fighter.maxGuard,
	}
	if string.match(fighterId, "^player:(%d+)$") == nil then
		delta.fighterId = fighterId
	end
	table.insert(sim.deltas, delta)
	if delta.fighterId == nil then
		ClientState.applyDelta(sim.state, delta)
	end
end

-- Servidor: o handler de `BasicAttackIntent`, sem o gate de rate limit (que é
-- do SecurityService e tem suíte própria) e sem telemetria.
local function serverBasicAttack(sim: Sim, kind: string): { [string]: any }
	local attacker = CombatService.getFighter(sim.attackerId)
	local isHeavy = kind == "heavy"
	assertTrue(attacker ~= nil, "atacante existe")
	if not attacker then
		error("atacante ausente")
	end

	local step = math.clamp(attacker.lightStep + 1, 1, 4)
	local reach = if isHeavy then HEAVY_REACH else LIGHT_REACH[step]
	local halfAngle = if isHeavy then HEAVY_HALF_ANGLE else LIGHT_HALF_ANGLE
	local targetId = SpatialService.acquireTarget(sim.attackerId, reach, halfAngle, function(fighterId: string): boolean
		local other = CombatService.getFighter(fighterId)
		return other ~= nil and other.health > 0
	end)
	local target = if targetId then CombatService.getFighter(targetId) else nil
	local facing = if targetId then SpatialService.facingOf(targetId, sim.attackerId) else "front"

	local result = if isHeavy
		then CombatService.tryHeavy(attacker, target, sim.now, facing :: any)
		else (if target then CombatService.tryLight(attacker, target, sim.now, facing :: any) else nil)

	local event
	if result and result.ok and target then
		event = CombatService.basicCombatEvent(result, kind, target.id, target.guarding == true)
		if not result.iframe then
			receiveCombatEvent(sim, event)
			fireVitals(sim, target.id)
		end
	else
		if not isHeavy then
			attacker.lightStep = 0
		end
		event = CombatService.basicCombatEvent(result, kind, nil, false)
		receiveCombatEvent(sim, event)
	end
	return event
end

-- Aproxima o atacante do alvo, como o jogador andando. Só move o transform
-- espacial do atacante: nada de teleporte de combate, e o alvo fica onde está.
local function walkTo(sim: Sim, distanceStuds: number): ()
	local target = SpatialService.getPosition(sim.targetId)
	assertTrue(target ~= nil, "alvo tem posição")
	if not target then
		return
	end
	SpatialService.setTransform(sim.attackerId, vec(target.x, target.y, target.z + distanceStuds), vec(0, 0, -1))
	local distancia = SpatialService.distanceBetween(sim.attackerId, sim.targetId)
	assertTrue(distancia ~= nil and math.abs(distancia - distanceStuds) < 1e-6, "caminhada parou na distância pedida")
end

local function assertSilentImpact(sim: Sim, label: string)
	assertEq(#sim.cues, 0, label .. ": sem deixa de impacto")
	assertEq(#sim.numbers, 0, label .. ": sem número")
	assertEq(sim.camera.trauma, 0, label .. ": câmera parada")
	assertEq(sim.camera.fovPunch, 0, label .. ": sem punch de FOV")
	assertFalse(PlayerCombatAnimator.hitStopActive(sim.now, sim.animator.hitStopUntil), label .. ": sem hit-stop")
	assertEq(#sim.deltas, 0, label .. ": sem StateDelta")
end

-- Espelha o runner espacial de `AbilityService`: avança, e só emite CombatEvent
-- se a cápsula pegar alguém. Avanço sem alvo é válido e mudo no cliente.
local COMET_PARAMS = {
	distance = 7,
	hardCap = 8,
	capsuleRadius = 2,
	blockerRadius = 2,
	blocks = function(): boolean
		return false
	end,
}

local function serverComet(sim: Sim): { [string]: any }?
	local attacker = CombatService.getFighter(sim.attackerId)
	assertTrue(attacker ~= nil, "atacante existe")
	if not attacker then
		return nil
	end
	local resolucao = SpatialService.resolveCometShoulder(sim.attackerId, COMET_PARAMS)
	if resolucao.targetId == nil then
		return nil
	end
	local target = CombatService.getFighter(resolucao.targetId)
	if not target then
		return nil
	end
	local resultado = CombatService.tryCometShoulder(attacker, target, sim.now, resolucao.facing :: any)
	if not resultado.ok or resultado.iframe then
		return nil
	end
	local event = {
		targetId = resolucao.targetId,
		abilityId = "comet_shoulder",
		outcome = if resultado.stoppedOnGuard then "guard" else "hit",
		damage = resultado.damage,
	}
	receiveCombatEvent(sim, event)
	fireVitals(sim, target.id)
	return event
end

-- ── 0. A simulação usa os números do jogo ───────────────────────────────────

test("fonte: alcance e cone da simulação são os do handler real", function()
	local source = fs.readFile("src/server/init.server.lua")
	assertTrue(source:find("local BASIC_RANGE_STUDS = 6", 1, true) ~= nil, "alcance base do golpe")
	assertTrue(source:find("local BODY_ALLOWANCE_STUDS = 3", 1, true) ~= nil, "folga de corpo")
	assertTrue(source:find("local BASIC_LIGHT_HALF_ANGLE_DEGREES = 65", 1, true) ~= nil, "cone leve")
	assertTrue(source:find("local BASIC_HEAVY_HALF_ANGLE_DEGREES = 50", 1, true) ~= nil, "cone pesado")
	assertEq(LIGHT_REACH[1], 9, "alcance leve efetivo")
	assertEq(HEAVY_REACH, 9.5, "alcance pesado efetivo")
end)

-- ── 1. O caso histórico: longe demais, cadeia inteira muda ──────────────────

test("41 studs: o golpe erra e NENHUMA camada de impacto acende (docs/14 §4.8)", function()
	local sim = newSim(PLAYTEST_DISTANCE_STUDS)
	local event = serverBasicAttack(sim, "light")

	assertEq(event.outcome, "miss", "a 41,2 studs o golpe erra")
	assertEq(event.damage, 0, "sem dano")
	assertEq(event.targetId, nil, "nenhum alvo adquirido")

	-- As cinco reações do cliente ficam exatamente onde estavam: paradas.
	assertEq(#sim.cues, 0, "nenhuma deixa de áudio de impacto")
	assertEq(#sim.numbers, 0, "nenhum número de dano")
	assertEq(sim.camera.trauma, 0, "câmera não treme")
	assertEq(sim.camera.fovPunch, 0, "sem punch de FOV")
	assertFalse(PlayerCombatAnimator.hitStopActive(sim.now, sim.animator.hitStopUntil), "sem hit-stop")
	assertEq(#sim.deltas, 0, "nenhum StateDelta — ninguém tomou dano")
	assertEq(ClientState.feedback(sim.state), nil, "HUD não anuncia acerto")

	-- E o alvo continua intacto: era isso que o Output dizia, uma linha por
	-- golpe, e ninguém leu como "o problema é a distância".
	local target = CombatService.getFighter(sim.targetId)
	assertTrue(target ~= nil and target.health == 100, "alvo intacto")
end)

test("41 studs: o pesado também erra e nenhuma camada de impacto acende", function()
	local sim = newSim(PLAYTEST_DISTANCE_STUDS)
	local event = serverBasicAttack(sim, "heavy")

	assertEq(event.outcome, "miss", "a 41,2 studs o pesado erra")
	assertEq(event.abilityId, "heavy", "é o pesado que errou")
	assertEq(event.damage, 0, "sem dano")
	assertEq(event.targetId, nil, "nenhum alvo adquirido")
	assertSilentImpact(sim, "pesado longe")
	local target = CombatService.getFighter(sim.targetId)
	assertTrue(target ~= nil and target.health == 100, "alvo intacto")
end)

-- ── 2. Aproximar liga a cadeia inteira ──────────────────────────────────────

test("dentro do alcance: um leve confirmado acende as cinco camadas de uma vez", function()
	local sim = newSim(PLAYTEST_DISTANCE_STUDS)
	walkTo(sim, 6)
	local event = serverBasicAttack(sim, "light")

	-- (a) o servidor confirmou
	assertEq(event.outcome, "hit", "desfecho confirmado")
	assertEq(event.targetId, sim.targetId, "alvo no evento")
	assertTrue(event.damage > 0, "dano positivo")
	assertEq(event.step, 1, "primeiro degrau da cadeia")

	-- (b) som de impacto resolvido pelo catálogo
	assertEq(#sim.cues, 1, "uma deixa de impacto")
	assertTrue(sim.cues[1] ~= nil and #sim.cues[1] > 0, "deixa com id real")

	-- (c) hit-stop ativo agora e expirado depois da janela
	assertTrue(PlayerCombatAnimator.hitStopActive(sim.now, sim.animator.hitStopUntil), "hit-stop ligou")
	local hitStopMs = PlayerCombatAnimator.HitStopMs.hit
	assertFalse(
		PlayerCombatAnimator.hitStopActive(sim.now + hitStopMs / 1000 + 0.001, sim.animator.hitStopUntil),
		"hit-stop solta sozinho"
	)

	-- (d) tremida de câmera acumulada e decaindo
	assertTrue(sim.camera.trauma > 0, "trauma acumulado")
	assertTrue(CombatCameraController.shakeAmplitude(sim.camera.trauma) > 0, "amplitude visível")
	local traumaAntes = sim.camera.trauma
	CombatCameraController.tick(sim.camera, 0.5)
	assertTrue(sim.camera.trauma < traumaAntes, "trauma decai")

	-- (e) número de dano autorizado, com a cor do desfecho
	assertEq(#sim.numbers, 1, "um número de dano")
	assertEq(sim.numbers[1].damage, event.damage, "número bate com o dano do servidor")
	assertEq(#sim.numbers[1].rgb, 3, "cor RGB completa")

	-- (f) vida do alvo replicada para a barra do HUD
	assertEq(#sim.deltas, 1, "um StateDelta")
	assertEq(sim.deltas[1].fighterId, sim.targetId, "delta identifica o NPC")
	assertTrue(sim.deltas[1].health < 100, "vida caiu")
	local fracao = CombatHudController.barFraction(sim.deltas[1].health, sim.deltas[1].maxHealth)
	assertTrue(fracao > 0 and fracao < 1, "barra entre cheia e vazia")

	-- (g) faixa de feedback do HUD
	assertEq(ClientState.feedback(sim.state), "hud.feedback_hit", "HUD anuncia acerto")
end)

test("a distância é a única diferença entre o mudo e o completo", function()
	-- Mesmo código, mesmo golpe, mesmo alvo: só a distância muda. É a prova de
	-- que a camada de impacto nunca esteve quebrada.
	local longe = newSim(PLAYTEST_DISTANCE_STUDS)
	serverBasicAttack(longe, "light")
	local perto = newSim(6)
	serverBasicAttack(perto, "light")

	assertEq(#longe.numbers, 0, "longe: nada")
	assertEq(#perto.numbers, 1, "perto: tudo")
	assertTrue(perto.camera.trauma > longe.camera.trauma, "só o perto treme")
	assertTrue(#perto.cues > #longe.cues, "só o perto soa")
end)

test("pesado: a distância é a única diferença entre o mudo e o completo", function()
	local longe = newSim(PLAYTEST_DISTANCE_STUDS)
	serverBasicAttack(longe, "heavy")
	local perto = newSim(PLAYTEST_DISTANCE_STUDS)
	walkTo(perto, 6)
	local evento = serverBasicAttack(perto, "heavy")

	assertEq(evento.outcome, "hit", "pesado confirma a 6 studs")
	assertTrue(evento.damage > 0, "dano positivo")
	assertEq(#longe.numbers, 0, "longe: nada")
	assertEq(#perto.numbers, 1, "perto: número")
	assertTrue(perto.camera.trauma > longe.camera.trauma, "só o perto treme")
	assertTrue(#perto.cues > #longe.cues, "só o perto soa")
	assertTrue(PlayerCombatAnimator.hitStopActive(perto.now, perto.animator.hitStopUntil), "hit-stop do pesado")
	assertEq(#perto.deltas, 1, "vida replicada")
	-- ✅ Resolvido em 17/08 (decisão do playtest): o pesado entrou em
	-- `HEAVY_ABILITIES` e agora sacode MAIS que o leve (trauma 0,8 vs 0,5).
	local leve = newSim(6)
	serverBasicAttack(leve, "light")
	assertTrue(perto.camera.trauma > leve.camera.trauma, "pesado básico sacode mais que o jab")
end)

test("borda do alcance: 9 studs conecta, 9,5 não (leve, degrau 1)", function()
	local dentro = newSim(8.9)
	assertEq(serverBasicAttack(dentro, "light").outcome, "hit", "dentro do alcance")
	local fora = newSim(9.6)
	assertEq(serverBasicAttack(fora, "light").outcome, "miss", "fora do alcance")
end)

test("fora do cone: alvo às costas não é adquirido mesmo colado", function()
	local sim = newSim(4)
	-- Alvo atrás: o cone de 65° não alcança, mesmo a 4 studs.
	SpatialService.setTransform(sim.targetId, vec(0, 0, 4), vec(0, 0, -1))
	local event = serverBasicAttack(sim, "light")
	assertEq(event.outcome, "miss", "cone recusa o alvo às costas")
	assertEq(#sim.numbers, 0, "nada acende")
end)

-- ── 3. Pesado e cadeia ──────────────────────────────────────────────────────

test("pesado confirmado bate mais forte, mas sacode IGUAL ao leve (achado)", function()
	local leve = newSim(6)
	local eventoLeve = serverBasicAttack(leve, "light")
	local pesado = newSim(6)
	local eventoPesado = serverBasicAttack(pesado, "heavy")

	assertEq(eventoPesado.outcome, "hit", "pesado confirma")
	assertTrue(eventoPesado.damage > eventoLeve.damage, "pesado dói mais")
	assertEq(eventoPesado.step, 0, "pesado não entra na cadeia leve")
	assertTrue(pesado.camera.trauma > 0 and leve.camera.trauma > 0, "os dois sacodem")

	-- ✅ Resolvido em 17/08 (decisão do playtest W1/A1, docs/32 §6): o pesado
	-- básico entrou em `HEAVY_ABILITIES` (`heavy = true`) e agora usa o mesmo
	-- multiplicador das técnicas (trauma 0,5→0,8, FOV 2,6→3,64). A lição de
	-- docs/14 §4.8 continua: o número veio do multiplicador já existente da
	-- lista, não de um palpite — o Álvaro confirmou no Studio que o pesado
	-- estava leve demais para o dobro de dano e a quebra de guarda.
	assertTrue(pesado.camera.trauma > leve.camera.trauma, "pesado básico sacode mais que o jab")
	local perfilPesado = CombatCameraController.profileFor("hit", "heavy")
	local perfilLeve = CombatCameraController.profileFor("hit", "light")
	assertTrue(
		perfilPesado ~= nil and perfilLeve ~= nil and perfilPesado.trauma > perfilLeve.trauma,
		"perfil do pesado é mais forte que o do jab"
	)
	-- A técnica, essa sim, tem perfil próprio — o Cometa continua sendo o
	-- golpe mais pesado do kit (trauma 0,85 vs 0,8 do pesado básico).
	local perfilTecnica = CombatCameraController.profileFor("hit", "comet_shoulder")
	local perfilBasico = CombatCameraController.profileFor("hit", "heavy")
	assertTrue(
		perfilTecnica ~= nil and perfilBasico ~= nil and perfilTecnica.trauma > perfilBasico.trauma,
		"Ombro Cometa sacode mais que o básico"
	)
end)

test("cadeia leve: quatro golpes seguidos sobem o degrau e o 4º é o mais forte", function()
	local sim = newSim(6)
	local danos: { number } = {}
	for degrau = 1, 4 do
		local event = serverBasicAttack(sim, "light")
		assertEq(event.outcome, "hit", ("degrau %d confirma"):format(degrau))
		assertEq(event.step, degrau, ("degrau %d publicado"):format(degrau))
		table.insert(danos, event.damage)
		sim.now += 0.3
	end
	assertEq(#sim.numbers, 4, "quatro números de dano")
	assertTrue(danos[4] > danos[1], "finalizador é o mais forte da cadeia")
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(
		alvo ~= nil and alvo.health <= 100 - (danos[1] + danos[2] + danos[3] + danos[4]) + 1e-9,
		"vida somou o dano"
	)
end)

-- ── 4. Guarda: outro desfecho, outra leitura, mesma cadeia ──────────────────

test("alvo em guarda muda desfecho, cor e deixa — sem apagar a cadeia", function()
	local sim = newSim(6)
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(alvo ~= nil, "alvo existe")
	if not alvo then
		return
	end
	CombatService.setGuard(alvo, true, sim.now)

	local event = serverBasicAttack(sim, "light")
	assertEq(event.outcome, "guard", "desfecho de guarda")
	assertEq(sim.cues[1], "impact_guard", "deixa própria de guarda")
	assertEq(ClientState.feedback(sim.state), "hud.feedback_guard", "HUD distingue guarda de acerto")
	assertTrue(sim.camera.trauma > 0, "guarda também sacode")
	local corGuarda = CombatHudController.damageColor("guard")
	local corAcerto = CombatHudController.damageColor("hit")
	local diferente = corGuarda[1] ~= corAcerto[1] or corGuarda[2] ~= corAcerto[2] or corGuarda[3] ~= corAcerto[3]
	assertTrue(diferente, "cor do número distingue guarda")
end)

test("pesado na guarda: desfecho próprio, sem dano fantasma", function()
	local sim = newSim(6)
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(alvo ~= nil, "alvo existe")
	if not alvo then
		return
	end
	local vidaAntes = alvo.health
	CombatService.setGuard(alvo, true, sim.now)

	local event = serverBasicAttack(sim, "heavy")
	assertEq(event.outcome, "guard", "desfecho de guarda")
	assertEq(event.abilityId, "heavy", "é o pesado")
	assertEq(sim.cues[1], "impact_guard", "deixa de guarda, não de impacto pesado")
	assertEq(ClientState.feedback(sim.state), "hud.feedback_guard", "HUD lê guarda")
	assertTrue(sim.camera.trauma > 0, "guarda do pesado também sacode")
	local perda = vidaAntes - alvo.health
	assertTrue(math.abs(perda - event.damage) < 1e-9, "vida perdida bate com o evento")
	if event.damage > 0 then
		assertEq(#sim.numbers, 1, "número só do dano real")
		assertEq(sim.numbers[1].damage, event.damage, "número igual ao evento")
	else
		assertEq(#sim.numbers, 0, "sem dano, sem número")
	end
end)

-- ── 5. Técnica: Ombro Cometa de ponta a ponta ───────────────────────────────

test("Ombro Cometa: avança no servidor, confirma e só então acende contato", function()
	local sim = newSim(6)
	local attacker = CombatService.getFighter(sim.attackerId)
	local target = CombatService.getFighter(sim.targetId)
	assertTrue(attacker ~= nil and target ~= nil, "fighters existem")
	if not attacker or not target then
		return
	end

	local definicao = Abilities.get("comet_shoulder")
	assertTrue(definicao ~= nil, "catálogo tem o Ombro Cometa")

	-- (a) o servidor resolve o avanço espacial e commita a posição
	local antes = SpatialService.getPosition(sim.attackerId)
	local resolucao = SpatialService.resolveCometShoulder(sim.attackerId, {
		distance = 7,
		hardCap = 8,
		capsuleRadius = 2,
		blockerRadius = 2,
		blocks = function(): boolean
			return false
		end,
	})
	local depois = SpatialService.getPosition(sim.attackerId)
	assertTrue(antes ~= nil and depois ~= nil, "posições conhecidas")
	if antes and depois then
		assertTrue(math.abs(depois.z - antes.z) > 1e-6, "o SERVIDOR moveu o atacante, não a animação")
	end
	assertEq(resolucao.targetId, sim.targetId, "alvo na cápsula do trajeto")

	-- (b) resolução de dano e evento autoritativo
	local resultado = CombatService.tryCometShoulder(attacker, target, sim.now, resolucao.facing :: any, false)
	assertTrue(resultado.ok, "cometa resolveu")
	local event = {
		targetId = sim.targetId,
		abilityId = "comet_shoulder",
		outcome = if resultado.stoppedOnGuard then "guard" else "hit",
		damage = resultado.damage,
	}

	-- (c) ANTES do evento, as camadas de contato ficam apagadas
	local receita = AbilityVfx.forAction("Ability1")
	assertTrue(receita ~= nil, "receita visual do cometa existe")
	if not receita then
		return
	end
	local antesDoDesfecho = AbilityVfx.planAt(receita, 0.42, false)
	local depoisDoDesfecho = AbilityVfx.planAt(receita, 0.42, true)
	assertTrue(#depoisDoDesfecho > #antesDoDesfecho, "confirmação acrescenta camadas de contato")

	-- (d) o cliente reage ao evento como reage a qualquer outro
	receiveCombatEvent(sim, event)
	fireVitals(sim, sim.targetId)
	assertTrue(sim.vfxConfirmed["comet_shoulder"] == true, "VFX do cometa confirmado")
	assertTrue(sim.camera.trauma > 0, "impacto da técnica sacode")
	assertEq(#sim.numbers, 1, "número de dano da técnica")
	assertTrue(PlayerCombatAnimator.hitStopActive(sim.now, sim.animator.hitStopUntil), "hit-stop da técnica")
	assertEq(#sim.deltas, 1, "vida do alvo replicada")

	-- (e) honestidade: nenhuma camada passa do alcance da própria habilidade
	for _, camada in receita.layers do
		assertTrue(camada.radiusStuds <= receita.rangeStuds, ("camada %s passa do alcance"):format(camada.id))
	end
end)

test("Ombro Cometa a 41 studs: a cápsula não pega o dummy e o cliente fica mudo", function()
	local sim = newSim(PLAYTEST_DISTANCE_STUDS)
	local antes = SpatialService.getPosition(sim.attackerId)
	local event = serverComet(sim)
	local depois = SpatialService.getPosition(sim.attackerId)

	assertEq(event, nil, "sem CombatEvent — o runner não inventa alvo")
	assertSilentImpact(sim, "cometa longe")
	assertEq(sim.vfxConfirmed["comet_shoulder"], nil, "sem VFX de contato")
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(alvo ~= nil and alvo.health == 100, "dummy intacto")
	-- O avanço ainda acontece: custo já foi pago. Só o impacto que não existe.
	assertTrue(antes ~= nil and depois ~= nil, "posições conhecidas")
	if antes and depois then
		assertTrue(math.abs(depois.z - antes.z) > 1e-6, "o servidor moveu mesmo sem alvo")
	end
end)

test("Ombro Cometa na guarda: stoppedOnGuard, cadeia de guarda, sem hit", function()
	local sim = newSim(6)
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(alvo ~= nil, "alvo existe")
	if not alvo then
		return
	end
	local vidaAntes = alvo.health
	CombatService.setGuard(alvo, true, sim.now)

	local event = serverComet(sim)
	assertTrue(event ~= nil, "evento publicado")
	if not event then
		return
	end
	assertEq(event.outcome, "guard", "desfecho de guarda")
	assertEq(event.abilityId, "comet_shoulder", "é o Cometa")
	assertEq(sim.cues[1], "impact_guard", "deixa de guarda, não de impacto pesado")
	assertEq(ClientState.feedback(sim.state), "hud.feedback_guard", "HUD lê guarda")
	assertTrue(sim.vfxConfirmed["comet_shoulder"] == true, "VFX confirma o contato de guarda")
	assertTrue(sim.camera.trauma > 0, "guarda do Cometa sacode")
	local perfilGuarda = CombatCameraController.profileFor("guard", "comet_shoulder")
	local perfilHit = CombatCameraController.profileFor("hit", "comet_shoulder")
	assertTrue(
		perfilGuarda ~= nil and perfilHit ~= nil and perfilGuarda.trauma < perfilHit.trauma,
		"guarda sacode menos que o acerto da técnica"
	)
	local perda = vidaAntes - alvo.health
	assertTrue(math.abs(perda - event.damage) < 1e-9, "sem dano fantasma")
	if event.damage > 0 then
		assertEq(#sim.numbers, 1, "número do dano reduzido")
		assertEq(sim.numbers[1].damage, event.damage, "número igual ao evento")
	else
		assertEq(#sim.numbers, 0, "sem dano, sem número")
	end
end)

-- ── 6. Morte fecha o ciclo ──────────────────────────────────────────────────

test("morte: o último golpe emite desfecho de morte e ainda mostra o número", function()
	local sim = newSim(6)
	local alvo = CombatService.getFighter(sim.targetId)
	assertTrue(alvo ~= nil, "alvo existe")
	if not alvo then
		return
	end
	alvo.health = 3

	local event = serverBasicAttack(sim, "light")
	assertTrue(event.damage > 0, "golpe causou dano")
	assertTrue(alvo.health <= 0, "alvo caiu")
	assertEq(event.outcome, "death", "golpe fatal já chega como death (não hit + evento extra)")
	assertEq(#sim.numbers, 1, "número do golpe fatal aparece")
	assertEq(ClientState.feedback(sim.state), "hud.feedback_death", "HUD anuncia a morte")
	assertTrue(PlayerCombatAnimator.HitStopMs.death > PlayerCombatAnimator.HitStopMs.hit, "morte segura mais")
end)

-- ── 7. Dois jogadores (recorte headless do R1) ──────────────────────────────

test("dois jogadores: aparo devolve contra sem dano fantasma", function()
	local sim = newSim(6, "player")
	local atacante = CombatService.getFighter(sim.attackerId)
	local defensor = CombatService.getFighter(sim.targetId)
	assertTrue(atacante ~= nil and defensor ~= nil, "dois fighters de jogador")
	if not atacante or not defensor then
		return
	end

	-- Postura do Retorno de Pulso: reduz UM golpe frontal e devolve o contra.
	local abriu = CombatService.setPulseStance(defensor, sim.now)
	assertTrue(abriu, "postura aberta")

	local vidaAntes = defensor.health
	local event = serverBasicAttack(sim, "light")
	assertTrue(event.outcome == "guard" or event.outcome == "hit", "desfecho válido")
	assertTrue(defensor.health >= vidaAntes - event.damage - 1e-9, "dano no defensor bate com o evento")
	-- O número de dano nunca contradiz o evento: sem dano positivo, sem número.
	if event.damage > 0 then
		assertEq(#sim.numbers, 1, "um número, do dano real")
		assertEq(sim.numbers[1].damage, event.damage, "número igual ao evento")
	else
		assertEq(#sim.numbers, 0, "sem dano, sem número")
	end
end)

test("dois jogadores: i-frame não vira acerto confirmado nem número", function()
	local sim = newSim(6, "player")
	local defensor = CombatService.getFighter(sim.targetId)
	assertTrue(defensor ~= nil, "defensor existe")
	if not defensor then
		return
	end
	-- Dash concede i-frames: o alvo é intocável na janela.
	defensor.iframeUntil = sim.now + 0.08

	local vidaAntes = defensor.health
	serverBasicAttack(sim, "light")
	assertEq(defensor.health, vidaAntes, "i-frame não tira vida")
	assertEq(#sim.numbers, 0, "i-frame não gera número de dano")
	assertEq(#sim.deltas, 0, "i-frame não replica vitals")
	assertEq(sim.camera.trauma, 0, "i-frame não sacode a câmera do atacante")
end)

test("dois jogadores: o dano do alvo nunca ultrapassa o publicado no evento", function()
	-- Regressão do combo do elite (14/08): somar o dano do 1º golpe quando o 2º
	-- foi aparado criava "dano fantasma" — vida caindo mais do que o evento diz.
	local sim = newSim(6, "player")
	local defensor = CombatService.getFighter(sim.targetId)
	assertTrue(defensor ~= nil, "defensor existe")
	if not defensor then
		return
	end
	local vidaInicial = defensor.health
	local somaEventos = 0
	for _ = 1, 3 do
		local event = serverBasicAttack(sim, "light")
		somaEventos += event.damage
		sim.now += 0.3
	end
	local perdaReal = vidaInicial - defensor.health
	assertTrue(
		math.abs(perdaReal - somaEventos) < 1e-9,
		("vida perdida %.2f difere da soma dos eventos %.2f"):format(perdaReal, somaEventos)
	)
end)

print(("Resultado combate E2E: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then
	error("simulação de combate falhou")
end

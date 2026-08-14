--!strict
-- Testes da cadeia de golpes do jogador (apresentação pura).
-- Uso: lune run tests/animation.luau
--
-- Arquivo separado de run.luau de propósito: a cadeia leve é camada de
-- apresentação e não toca serviço autoritativo. Pode ser dobrado em run.luau
-- quando não houver edição concorrente.

require("./harness")

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

local PlayerCombatAnimator = require("../src/client/Presentation/PlayerCombatAnimator")
local CombatCameraController = require("../src/client/Presentation/CombatCameraController")
local CombatAudioPlayer = require("../src/client/Presentation/CombatAudioPlayer")
local CombatAudio = require("../src/shared/Data/CombatAudio")
local AbilityVfx = require("../src/shared/Data/AbilityVfx")
local CombatHudController = require("../src/client/Controllers/CombatHudController")
local CombatAnimations = require("../src/shared/Data/CombatAnimations")
local ActorAnimator = require("../src/client/Presentation/ActorAnimator")
local fs = require("@lune/fs")

local CHAIN = PlayerCombatAnimator.LightChainLength

-- Amostra o pico de impacto de um degrau: fim da pausa menos uma folga curta.
local function strikeOf(step: number)
	local duration = PlayerCombatAnimator.lightChainDuration(step)
	return PlayerCombatAnimator.sample("BasicLight", duration * 0.45, false, step)
end

test("cadeia: quatro degraus existem e ficam progressivamente mais longos", function()
	assertEq(CHAIN, 4, "cadeia tem quatro golpes")
	local previous = 0
	for step = 1, CHAIN do
		local duration = PlayerCombatAnimator.lightChainDuration(step)
		assertTrue(duration > previous, ("degrau %d dura mais que o anterior"):format(step))
		previous = duration
	end
end)

test("cadeia: cada degrau tem silhueta distinta, não a mesma pose repetida", function()
	local seen: { any } = {}
	for step = 1, CHAIN do
		seen[step] = strikeOf(step)
	end
	for a = 1, CHAIN do
		for b = a + 1, CHAIN do
			local same = seen[a].rootYawDegrees == seen[b].rootYawDegrees
				and seen[a].leftShoulderPitchDegrees == seen[b].leftShoulderPitchDegrees
				and seen[a].rightShoulderPitchDegrees == seen[b].rightShoulderPitchDegrees
				and seen[a].rightHipPitchDegrees == seen[b].rightHipPitchDegrees
			assertTrue(not same, ("degrau %d difere do degrau %d"):format(a, b))
		end
	end
end)

test("cadeia: socos estendem o cotovelo e chutes levantam a perna", function()
	local jab = strikeOf(1)
	local cross = strikeOf(2)
	local kick = strikeOf(3)
	local spin = strikeOf(4)

	-- Soco = cotovelo sai de dobrado e chega perto de reto no impacto.
	assertTrue(jab.leftElbowPitchDegrees > -30, "jab estende o cotovelo esquerdo")
	assertTrue(cross.rightElbowPitchDegrees > -30, "direto estende o cotovelo direito")
	-- Braço de apoio nunca cai: mantém a guarda dobrada.
	assertTrue(jab.rightElbowPitchDegrees < -60, "jab mantém guarda do outro braço")
	assertTrue(cross.leftElbowPitchDegrees < -50, "direto mantém guarda do outro braço")
	-- Chute = quadril levanta a perna muito além da postura de soco.
	assertTrue(kick.rightHipPitchDegrees < -50, "chute levanta a perna direita")
	assertTrue(
		math.abs(kick.rightHipPitchDegrees) > math.abs(cross.rightHipPitchDegrees) * 3,
		"chute é perna, não soco"
	)
	assertTrue(spin.leftHipPitchDegrees < -50, "finalizador chuta com a outra perna")
end)

test("cadeia: amplitude cresce até o finalizador", function()
	local jab = strikeOf(1)
	local spin = strikeOf(4)
	assertTrue(
		math.abs(spin.rootYawDegrees) > math.abs(jab.rootYawDegrees) * 2,
		"finalizador gira muito mais que o jab"
	)
	assertTrue(spin.rootHeightStuds < jab.rootHeightStuds, "finalizador baixa mais o centro de massa")
end)

test("cadeia: todo degrau termina exatamente em neutro", function()
	for step = 1, CHAIN do
		local duration = PlayerCombatAnimator.lightChainDuration(step)
		local recovered = PlayerCombatAnimator.sample("BasicLight", duration, false, step)
		assertEq(recovered.rootYawDegrees, 0, ("degrau %d volta ao neutro (yaw)"):format(step))
		assertEq(recovered.leftElbowPitchDegrees, 0, ("degrau %d volta ao neutro (cotovelo)"):format(step))
		assertEq(recovered.rightHipPitchDegrees, 0, ("degrau %d volta ao neutro (quadril)"):format(step))
	end
end)

test("cadeia: retorno é elástico — ultrapassa o alvo antes de assentar", function()
	local duration = PlayerCombatAnimator.lightChainDuration(2)
	-- Perto do fim a pose deve ter cruzado o neutro, invertendo o sinal do yaw
	-- em relação ao impacto. É o overshoot que tira a sensação de robô.
	local strike = strikeOf(2)
	local settling = PlayerCombatAnimator.sample("BasicLight", duration * 0.96, false, 2)
	assertTrue(strike.rootYawDegrees > 0, "impacto do direto cruza para a direita")
	assertTrue(settling.rootYawDegrees < 0, "recuperação passa levemente do neutro")
end)

test("cadeia: núcleo se adianta à extremidade durante a antecipação", function()
	-- Em pleno windup o tronco já saiu mais do neutro (em fração do próprio
	-- alvo) do que o braço — é o "peso atrasado" de docs/14 §3.
	local mid = PlayerCombatAnimator.sample("BasicLight", 0.035, false, 2)
	local windupCoreTarget = -18 -- CROSS_WINDUP.rootYawDegrees
	local windupLimbTarget = -104 -- CROSS_WINDUP.rightElbowPitchDegrees
	local coreProgress = mid.rootYawDegrees / windupCoreTarget
	local limbProgress = mid.rightElbowPitchDegrees / windupLimbTarget
	assertTrue(coreProgress > limbProgress, "quadril/tronco lidera o cotovelo")
end)

test("cadeia: play avança o degrau e reinicia fora da janela", function()
	local clock = 0
	local animator = PlayerCombatAnimator.new({
		player = { Character = nil },
		runService = nil,
		now = function()
			return clock
		end,
	})

	for step = 1, CHAIN do
		clock += 0.3
		PlayerCombatAnimator.play(animator, "BasicLight")
		assertEq(animator.comboStep, step, ("golpe encadeado vira degrau %d"):format(step))
	end

	-- Depois do último, recomeça.
	clock += 0.3
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 1, "cadeia reinicia após o finalizador")

	-- Fora da janela, recomeça.
	clock += PlayerCombatAnimator.LightChainWindowSeconds + 0.1
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 1, "janela expirada volta ao jab")

	-- Outra ação quebra a cadeia.
	clock += 0.1
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 2, "encadeou para o segundo golpe")
	PlayerCombatAnimator.play(animator, "Dash")
	assertEq(animator.comboStep, 0, "dash quebra a cadeia")
	clock += 0.1
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 1, "após quebra recomeça no jab")
end)

test("cadeia: janela de apresentação bate com LIGHT_WINDOW do servidor", function()
	assertEq(PlayerCombatAnimator.LightChainWindowSeconds, 0.65, "janela espelha CombatService")
end)

test("cadeia: pose nunca declara posição autoritativa", function()
	for step = 1, CHAIN do
		local sample = strikeOf(step)
		assertEq((sample :: any).rootPosition, nil, "pose não carrega posição")
		assertEq((sample :: any).velocity, nil, "pose não carrega velocidade")
		assertEq((sample :: any).damage, nil, "pose não carrega dano")
	end
end)

test("cadeia: syncStep fixa o degrau do servidor e whiff zera", function()
	local clock = 0
	local animator = PlayerCombatAnimator.new({
		player = { Character = nil },
		runService = nil,
		now = function()
			return clock
		end,
	})
	PlayerCombatAnimator.play(animator, "BasicLight")
	clock += 0.1
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 2, "cliente avançou para o degrau 2")
	-- Servidor confirmou o degrau 1 (o segundo clique errou): puxa para trás.
	PlayerCombatAnimator.syncStep(animator, 1)
	assertEq(animator.comboStep, 1, "servidor puxa o degrau para trás")
	-- Whiff: zera a cadeia visual.
	PlayerCombatAnimator.syncStep(animator, 0)
	assertEq(animator.comboStep, 0, "whiff zera a cadeia")
	-- Acerto confirmado no degrau 3.
	PlayerCombatAnimator.syncStep(animator, 3)
	assertEq(animator.comboStep, 3, "acerto confirma o degrau")
	-- Degrau inválido clampa no intervalo 1..4 (ou 0).
	PlayerCombatAnimator.syncStep(animator, 99)
	assertEq(animator.comboStep, 4, "clampa no finalizador")
	PlayerCombatAnimator.syncStep(animator, -1)
	assertEq(animator.comboStep, 0, "negativo zera")
end)

-- ── Áudio de combate ────────────────────────────────────────────────────────

test("áudio: catálogo passa validação", function()
	local ok, reason = CombatAudio.validate()
	assertTrue(ok, reason)
end)

test("áudio: todo arquivo de origem existe no disco", function()
	local files = CombatAudio.sourceFiles()
	assertTrue(#files > 0, "catálogo referencia ao menos um arquivo")
	for _, path in files do
		assertTrue(fs.isFile(path), ("arquivo existe: %s"):format(path))
	end
end)

test("áudio: toda deixa emitida pelo animador existe no catálogo", function()
	-- Trava a duplicação consciente de ids entre animador e catálogo: se um
	-- lado mudar sozinho, este teste quebra em vez de o jogo ficar mudo.
	for _, cueId in PlayerCombatAnimator.LightSwingCueIds do
		assertTrue(CombatAudio.get(cueId) ~= nil, ("deixa da cadeia existe: %s"):format(cueId))
	end
	for action, entry in PlayerCombatAnimator.ActionCueIds do
		assertTrue(CombatAudio.get(entry.id) ~= nil, ("deixa de %s existe: %s"):format(action, entry.id))
		assertTrue(entry.delaySeconds >= 0, ("atraso de %s não é negativo"):format(action))
	end
end)

test("áudio: cada degrau da cadeia tem corte de ar próprio", function()
	local seen: { [string]: boolean } = {}
	for step = 1, CHAIN do
		local cueId = CombatAudio.lightSwingId(step)
		assertTrue(not seen[cueId], ("degrau %d tem deixa própria"):format(step))
		seen[cueId] = true
	end
end)

test("áudio: impacto depende do desfecho autoritativo, não da intenção", function()
	assertEq(CombatAudio.impactId("light", "hit"), "impact_light", "acerto leve")
	assertEq(CombatAudio.impactId("heavy", "hit"), "impact_heavy", "acerto pesado")
	assertEq(CombatAudio.impactId("light", "guard"), "impact_guard", "bloqueio soa diferente")
	assertEq(CombatAudio.impactId("heavy", "guard"), "impact_guard", "bloqueio independe do peso")
	-- Sem desfecho não há som de impacto: intenção local nunca soa como acerto.
	assertEq(CombatAudio.impactId("light", nil), nil, "sem desfecho não soa")
	assertEq(CombatAudio.impactId("light", "miss"), nil, "erro não soa como acerto")
end)

test("áudio: deixa sem upload é ignorada em silêncio, não quebra", function()
	-- assetId vazio continua sendo estado suportado (deixa nova, upload
	-- rejeitado): o player devolve nil sem erro, senão o jogo quebra
	-- esperando áudio inexistente.
	local semUpload = {
		get = function(_id: string)
			return {
				id = "sem_upload",
				assetId = "",
				sourceFile = "x.ogg",
				variantFiles = {},
				volume = 0.5,
				pitchMin = 1,
				pitchMax = 1,
				rolloffMaxStuds = 60,
				enabled = true,
			}
		end,
	}
	local player = CombatAudioPlayer.new({
		catalog = semUpload,
		now = function()
			return 0
		end,
	})
	assertEq(CombatAudioPlayer.resolve(player, "sem_upload"), nil, "sem assetId não resolve")

	local real = CombatAudioPlayer.new({
		catalog = CombatAudio,
		now = function()
			return 0
		end,
	})
	assertEq(CombatAudioPlayer.resolve(real, "inexistente"), nil, "deixa desconhecida não resolve")
end)

test("áudio: todo o catálogo aponta para um asset tocável", function()
	-- O kit placeholder do Roblox tirou o combate do mudo (docs/16 §7). Se
	-- alguém acrescentar deixa sem asset, o combate volta a ficar em silêncio
	-- sem ninguém perceber — este teste é o alarme.
	local count = 0
	for _, entry in CombatAudio.all() do
		count += 1
		assertTrue(
			string.match(entry.assetId, "^rbxassetid://%d+$") ~= nil,
			("deixa %s sem assetId válido (%s)"):format(entry.id, entry.assetId)
		)
	end
	assertTrue(count >= 15, "catálogo completo percorrido")
end)

test("áudio: com assetId publicado, resolve com pitch dentro da faixa", function()
	local fake = {
		get = function(_id: string)
			return {
				id = "teste",
				assetId = "rbxassetid://123",
				sourceFile = "x.ogg",
				variantFiles = {},
				volume = 0.5,
				pitchMin = 0.9,
				pitchMax = 1.1,
				rolloffMaxStuds = 60,
				enabled = true,
			}
		end,
	}
	local player = CombatAudioPlayer.new({
		catalog = fake,
		random = {
			NextNumber = function()
				return 0.5
			end,
		},
		now = function()
			return 0
		end,
	})
	local resolved = CombatAudioPlayer.resolve(player, "teste")
	assertTrue(resolved ~= nil, "resolve com assetId")
	assertEq((resolved :: any).pitch, 1.0, "pitch no meio da faixa")
	assertEq((resolved :: any).assetId, "rbxassetid://123", "usa o asset publicado")
end)

test("áudio: animador agenda o corte de ar para o fim da antecipação", function()
	local clock = 0
	local emitted: { string } = {}
	local animator = PlayerCombatAnimator.new({
		player = { Character = nil },
		runService = nil,
		now = function()
			return clock
		end,
		emitCue = function(cueId: string)
			table.insert(emitted, cueId)
		end,
	})

	PlayerCombatAnimator.play(animator, "BasicLight")
	-- Antes do fim da antecipação (0.065 s do jab) nada soa.
	assertEq(PlayerCombatAnimator.flushCue(animator, 0.03), nil, "não soa durante a antecipação")
	assertEq(#emitted, 0, "nenhuma deixa emitida ainda")
	-- Ao alcançar a antecipação, o corte de ar sai uma única vez.
	assertEq(PlayerCombatAnimator.flushCue(animator, 0.065), "swing_light_1", "jab soa no fim da antecipação")
	assertEq(PlayerCombatAnimator.flushCue(animator, 0.20), nil, "não repete a mesma deixa")
	assertEq(#emitted, 1, "emitiu exatamente uma vez")

	-- Encadear troca a deixa: o segundo golpe soa como direto, não como jab.
	clock = 0.3
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(animator.comboStep, 2, "encadeou para o direto")
	assertEq(PlayerCombatAnimator.flushCue(animator, 0.3 + 0.07), "swing_light_2", "direto tem deixa própria")
end)

test("áudio: animador sem emitCue continua funcionando em silêncio", function()
	local animator = PlayerCombatAnimator.new({
		player = { Character = nil },
		runService = nil,
		now = function()
			return 0
		end,
	})
	PlayerCombatAnimator.play(animator, "BasicLight")
	assertEq(PlayerCombatAnimator.flushCue(animator, 10), nil, "sem emitCue não agenda deixa")
	assertEq(animator.comboStep, 1, "animação continua normal")
end)

-- ── Polimento de combate (docs/17) ───────────────────────────────────────────

test("cadeia: follow-through ultrapassa o impacto e ainda assenta em neutro", function()
	local step = 2
	local duration = PlayerCombatAnimator.lightChainDuration(step)
	-- 0.18 cai na pausa de impacto do direto (strikeEnd 0.150 .. holdEnd 0.200),
	-- então é a pose de impacto canônica de referência.
	local impact = PlayerCombatAnimator.sample("BasicLight", 0.18, false, step)
	local peak = 0
	for i = 0, 200 do
		local s = PlayerCombatAnimator.sample("BasicLight", duration * (i / 200), false, step)
		peak = math.max(peak, math.abs(s.rootYawDegrees))
	end
	assertTrue(peak > math.abs(impact.rootYawDegrees), "follow-through excede a pose de impacto")
	assertEq(
		PlayerCombatAnimator.sample("BasicLight", duration, false, step).rootYawDegrees,
		0,
		"termina em neutro exato"
	)
end)

test("apresentação: idle respira — o neutro não fica congelado entre ações", function()
	local a = PlayerCombatAnimator.sample(nil, 0, false, 1, 0.5)
	local b = PlayerCombatAnimator.sample(nil, 0, false, 1, 1.0)
	assertTrue(a.waistPitchDegrees ~= 0 or b.waistPitchDegrees ~= 0, "idle tem micro-movimento")
	assertTrue(a.waistPitchDegrees ~= b.waistPitchDegrees, "respiração avança com o relógio")
	-- Sem relógio (nil) a pose base permanece canônica: guarda não muda.
	assertEq(PlayerCombatAnimator.sample(nil, 0, false).waistPitchDegrees, 0, "sem relógio não respira")
	local guard = PlayerCombatAnimator.sample(nil, 0, true)
	assertTrue(guard.leftShoulderPitchDegrees < -40, "guarda canônica preservada")
end)

test("cadeia: punho estala no impacto — soco flexiona, chute não", function()
	local jab = strikeOf(1)
	local cross = strikeOf(2)
	local kick = strikeOf(3)
	assertTrue(jab.leftWristPitchDegrees < -10, "jab fecha o punho esquerdo")
	assertTrue(cross.rightWristPitchDegrees < -10, "direto fecha o punho direito")
	assertEq(kick.leftWristPitchDegrees, 0, "chute é perna — não flexiona punho")
end)

test("combate: hit-stop só congela no desfecho confirmado", function()
	local clock = 0
	local animator = PlayerCombatAnimator.new({
		player = { Character = nil },
		runService = nil,
		now = function()
			return clock
		end,
	})
	PlayerCombatAnimator.play(animator, "BasicHeavy")
	assertTrue(not PlayerCombatAnimator.hitStopActive(clock, animator.hitStopUntil), "sem confirmHit não há hit-stop")
	PlayerCombatAnimator.confirmHit(animator, "hit")
	assertTrue(PlayerCombatAnimator.hitStopActive(clock, animator.hitStopUntil), "hit confirmado congela")
	assertEq(animator.hitStopUntil, PlayerCombatAnimator.HitStopMs.hit / 1000, "dura os ms declarados")
	clock += PlayerCombatAnimator.HitStopMs.hit / 1000 + 0.001
	assertTrue(not PlayerCombatAnimator.hitStopActive(clock, animator.hitStopUntil), "após a janela descongela")
end)

test("câmera: trauma decai, clampa e técnica pesada sacode mais", function()
	local d = CombatCameraController.decay(0.5, 2.0, 0.1)
	assertTrue(math.abs(d - 0.3) < 1e-9, "decaimento linear")
	assertEq(CombatCameraController.decay(0.1, 2.0, 0.1), 0, "decaimento não fica negativo")
	assertEq(CombatCameraController.shakeAmplitude(0.5), 0.25, "curva quadrática")
	assertEq(CombatCameraController.shakeAmplitude(2), 1, "clampa acima de 1")
	local heavy = CombatCameraController.profileFor("hit", "comet_shoulder")
	local light = CombatCameraController.profileFor("hit", "basic_light")
	assertTrue(heavy ~= nil and light ~= nil, "perfis de acerto existem")
	if heavy and light then
		assertTrue(heavy.trauma > light.trauma, "técnica pesada sacode mais")
	end
	assertEq(CombatCameraController.profileFor("desconhecido", nil), nil, "desfecho desconhecido não treme")
end)

test("câmera: addImpact clampa trauma e fov no teto e decai no tick", function()
	local cam = CombatCameraController.new({
		random = function()
			return 0.5
		end,
	})
	CombatCameraController.addImpact(cam, "death")
	CombatCameraController.addImpact(cam, "death")
	CombatCameraController.addImpact(cam, "death")
	assertEq(cam.trauma, 1, "trauma no teto 1")
	assertEq(cam.fovPunch, CombatCameraController.MaxFovPunch, "fov punch no teto")
	CombatCameraController.tick(cam, 0.5)
	assertTrue(cam.trauma < 1, "decaimento após tick")
	assertTrue(cam.fovPunch < CombatCameraController.MaxFovPunch, "fov decai após tick")
end)

test("câmera: shakeEnabled false ignora impacto confirmado", function()
	local cam = CombatCameraController.new({
		random = function()
			return 0.5
		end,
	})
	cam.shakeEnabled = false
	CombatCameraController.addImpact(cam, "death")
	assertEq(cam.trauma, 0, "sem tremor")
	assertEq(cam.fovPunch, 0, "sem punch")
	cam.shakeEnabled = true
	CombatCameraController.addImpact(cam, "hit")
	assertTrue(cam.trauma > 0, "liga de novo")
end)

-- ── VFX do Ombro Cometa (docs/14 §4.1, docs/18 §4) ─────────────────────────

test("vfx: catálogo do cometa tem aura, flash e onda de choque", function()
	local technique = AbilityVfx.get("comet_shoulder")
	assertTrue(technique ~= nil, "técnica existe")
	if not technique then
		return
	end
	local ids: { [string]: boolean } = {}
	for _, entry in technique.layers do
		ids[entry.id] = true
	end
	assertTrue(ids.comet_aura, "aura de carga declarada")
	assertTrue(ids.comet_flash, "flash de impacto declarado")
	assertTrue(ids.comet_ring, "onda de choque declarada")
	local ok, reason = AbilityVfx.validate()
	assertTrue(ok, reason or "catálogo válido")
end)

test("vfx: aura acende durante a carga sem precisar de confirmação", function()
	local technique = AbilityVfx.get("comet_shoulder")
	assertTrue(technique ~= nil, "técnica existe")
	if not technique then
		return
	end
	local lit = AbilityVfx.planAt(technique, 0.08, false)
	local auraFound = false
	for _, planned in lit do
		if planned.layer.id == "comet_aura" then
			auraFound = true
			assertTrue(planned.intensity > 0, "aura com intensidade na carga")
		end
	end
	assertTrue(auraFound, "aura acesa na carga sem desfecho")
end)

test("vfx: flash e onda só acendem depois do desfecho confirmado", function()
	local technique = AbilityVfx.get("comet_shoulder")
	assertTrue(technique ~= nil, "técnica existe")
	if not technique then
		return
	end
	local function has(id: string, confirmed: boolean): boolean
		for _, planned in AbilityVfx.planAt(technique, 0.45, confirmed) do
			if planned.layer.id == id then
				return true
			end
		end
		return false
	end
	assertTrue(not has("comet_flash", false), "flash não acende sem confirmação")
	assertTrue(not has("comet_ring", false), "onda não acende sem confirmação")
	assertTrue(has("comet_flash", true), "flash acende com confirmação")
	assertTrue(has("comet_ring", true), "onda acende com confirmação")
end)

test("vfx: flash e onda nascem no instante autoritativo do impacto (0,40 s)", function()
	local technique = AbilityVfx.get("comet_shoulder")
	assertTrue(technique ~= nil, "técnica existe")
	if not technique then
		return
	end
	-- 0,42 s = logo após o impacto autoritativo (cometImpact = 0,40 s):
	-- no instante exato a subida do envelope ainda é 0, o efeito nasce no
	-- quadro seguinte.
	local atImpact: { [string]: boolean } = {}
	for _, planned in AbilityVfx.planAt(technique, 0.42, true) do
		atImpact[planned.layer.id] = true
	end
	assertTrue(atImpact.comet_flash, "flash nasce logo após 0,40 s")
	assertTrue(atImpact.comet_ring, "onda nasce logo após 0,40 s")
	-- E o rastro já estava aceso desde o avanço (0,18 s).
	assertTrue(atImpact.comet_trail, "trail segue aceso no impacto")
end)

test("vfx: nenhum raio do cometa ultrapassa o alcance da habilidade", function()
	local technique = AbilityVfx.get("comet_shoulder")
	assertTrue(technique ~= nil, "técnica existe")
	if not technique then
		return
	end
	for _, entry in technique.layers do
		assertTrue(
			entry.radiusStuds <= technique.rangeStuds,
			("camada %s raio %.1f <= alcance %.1f"):format(entry.id, entry.radiusStuds, technique.rangeStuds)
		)
	end
end)

-- ── HUD de combate: números de dano + barras de inimigos (docs/17) ─────────

test("hud: número de dano só com desfecho e dano positivo", function()
	assertTrue(CombatHudController.shouldShowDamage({ outcome = "hit", damage = 14 }), "acerto mostra")
	assertTrue(CombatHudController.shouldShowDamage({ outcome = "counter", damage = 10 }), "contra mostra")
	assertTrue(
		CombatHudController.shouldShowDamage({ outcome = "guard", damage = 6 }),
		"guarda com dano reduzido mostra"
	)
	assertTrue(not CombatHudController.shouldShowDamage({ outcome = "hit", damage = 0 }), "dano zero não mostra")
	assertTrue(not CombatHudController.shouldShowDamage({ outcome = "miss", damage = 10 }), "erro não mostra")
	assertTrue(not CombatHudController.shouldShowDamage({ outcome = "hit" }), "sem dano não mostra")
	assertTrue(not CombatHudController.shouldShowDamage({}), "payload vazio não mostra")
end)

test("hud: cor do número varia com o desfecho", function()
	local function assertRgb(outcome: string?, expected: { number }, msg: string)
		local rgb = CombatHudController.damageColor(outcome)
		assertEq(rgb[1], expected[1], msg .. " r")
		assertEq(rgb[2], expected[2], msg .. " g")
		assertEq(rgb[3], expected[3], msg .. " b")
	end
	assertRgb("hit", { 255, 255, 255 }, "acerto branco")
	assertRgb("guard", { 150, 190, 255 }, "guarda azul")
	assertRgb("counter", { 255, 200, 120 }, "contra âmbar")
	assertRgb("death", { 255, 90, 90 }, "morte vermelho")
	assertRgb(nil, { 255, 255, 255 }, "sem desfecho cai no branco")
end)

test("hud: fração da barra clampa em 0..1", function()
	assertEq(CombatHudController.barFraction(60, 60), 1, "vida cheia")
	assertEq(CombatHudController.barFraction(30, 60), 0.5, "meia vida")
	assertEq(CombatHudController.barFraction(0, 60), 0, "morta")
	assertEq(CombatHudController.barFraction(-5, 60), 0, "negativo clampa em 0")
	assertEq(CombatHudController.barFraction(90, 60), 1, "acima do máximo clampa em 1")
	assertEq(CombatHudController.barFraction(30, 0), 0, "máximo zero não divide")
end)

-- ── Clipes de animação (assets livres do Roblox) ────────────────────────────

test("clipes: catálogo válido e todo asset é rbxassetid do conjunto declarado", function()
	local ok, reason = CombatAnimations.validate()
	assertTrue(ok, tostring(reason))

	local allowed: { [string]: boolean } = {}
	for _, assetId in CombatAnimations.assetIds() do
		assertTrue(string.match(assetId, "^rbxassetid://%d+$") ~= nil, "formato do asset: " .. assetId)
		allowed[assetId] = true
	end
	for _, clip in CombatAnimations.all() do
		assertTrue(allowed[clip.assetId] == true, clip.action .. " usa asset fora da lista declarada")
	end
end)

test("clipes: nenhum golpe vira borrão — velocidade legível e janela dentro do clipe", function()
	local seen: { [string]: boolean } = {}
	for step = 1, CHAIN do
		local clip = CombatAnimations.forAction("BasicLight", step)
		if clip then
			local budget = PlayerCombatAnimator.lightChainDuration(step)
			-- A janela tocada dura exatamente a ação; o que se checa é que esse
			-- trecho EXISTE no clipe. Pedir além do fim congela o último quadro.
			assertTrue(
				clip.startTimeSeconds + budget * clip.speed <= clip.nominalSeconds + 0.01,
				("degrau %d pede trecho além do fim do clipe (%.3fs)"):format(step, clip.nominalSeconds)
			)
			assertTrue(
				clip.speed >= CombatAnimations.MinSpeed and clip.speed <= CombatAnimations.MaxSpeed,
				("degrau %d com velocidade ilegível (%.2f×)"):format(step, clip.speed)
			)
			seen[clip.action] = true
		end
	end
	-- Três degraus com clipe: o 3 é CHUTE e fica sem, porque o único clipe
	-- livre disponível é um corte de espada e um braço de espada num chute
	-- informa errado (docs/14 §5.1).
	local count = 0
	for _ in seen do
		count += 1
	end
	assertEq(count, 3, "um clipe distinto por degrau que tem clipe")
	assertEq(CombatAnimations.forAction("BasicLight", 3), nil, "degrau 3 (chute) é procedural puro")

	-- Degrau fora da faixa clampa em vez de estourar índice (o servidor pode
	-- mandar um step estranho e o cliente não pode quebrar por isso).
	assertEq(CombatAnimations.forAction("BasicLight", 0), CombatAnimations.forAction("BasicLight", 1), "step 0 clampa")
	assertEq(
		CombatAnimations.forAction("BasicLight", 99),
		CombatAnimations.forAction("BasicLight", 4),
		"step alto clampa"
	)
end)

test("clipes: só o corte medido entra — o lunge de 2 quadros ficou fora", function()
	-- O "R15 Lunge de Espada" (522638767) tem keyframes só em 0 e 1,5 s: é uma
	-- interpolação linear, não uma animação. Acelerado 2,9× era o espasmo de
	-- docs/18 §8. Se alguém o trouxer de volta, este teste cai.
	for _, assetId in CombatAnimations.assetIds() do
		assertTrue(string.find(assetId, "522638767") == nil, "lunge de 2 quadros não pode voltar ao catálogo")
	end
	for _, clip in CombatAnimations.all() do
		assertTrue(string.find(clip.assetId, "522638767") == nil, clip.action .. " voltou a usar o lunge")
	end

	-- Ações em que um corte de espada mentiria sobre o que o corpo faz.
	assertEq(CombatAnimations.forAction("Ability1"), nil, "Ombro Cometa é ombro, não braço de espada")
	assertEq(CombatAnimations.forAction("Ability3"), nil, "Retorno de Pulso é postura, não golpe")
end)

test("clipes: duração declarada bate com PlayerCombatAnimator e guarda/dash seguem procedurais", function()
	for action, seconds in PlayerCombatAnimator.Durations do
		-- BasicLight não tem duração única: cada degrau da cadeia tem a sua.
		if action ~= "BasicLight" then
			local declared = CombatAnimations.actionSeconds(action)
			if declared ~= nil then
				assertEq(declared, seconds, "duração divergente em " .. action)
			end
		end
	end
	for step = 1, CHAIN do
		assertEq(
			CombatAnimations.actionSeconds("BasicLight", step),
			PlayerCombatAnimator.lightChainDuration(step),
			"degrau " .. step .. " com duração divergente"
		)
	end
	-- Decisão de docs/14 §5.1: não existe clipe livre honesto de aparo/esquiva.
	assertEq(CombatAnimations.forAction("GuardDown"), nil, "guarda sem clipe")
	assertEq(CombatAnimations.forAction("Dash"), nil, "dash sem clipe")
	assertEq(CombatAnimations.forAction("Inexistente"), nil, "ação desconhecida sem clipe")
end)

test("clipes: janela fora do clipe, borrão e asset inválido são recusados", function()
	local function fake(overrides: { [string]: any }): any
		local base = {
			action = "Falso",
			assetId = "rbxassetid://1",
			speed = 1,
			startTimeSeconds = 0,
			fadeInSeconds = 0.05,
			fadeOutSeconds = 0.1,
			weight = 1,
			nominalSeconds = 0.5,
			source = "teste",
		}
		for key, value in overrides do
			base[key] = value
		end
		return base
	end

	-- Trecho pedido passa do fim do clipe: o track congelaria no último quadro.
	local ok, reason = CombatAnimations.validateClip(fake({ startTimeSeconds = 0.4 }), 0.3)
	assertTrue(not ok, "janela além do fim do clipe deve falhar")
	assertTrue(reason ~= nil and string.find(reason, "estoura o clipe") ~= nil, "motivo explica o estouro")

	-- 2,9× era exatamente o que o lunge fazia no finalizador até 14/08.
	local borrao = CombatAnimations.validateClip(fake({ speed = 2.9, nominalSeconds = 1.5 }), 0.5)
	assertTrue(not borrao, "2,9× é borrão e deve falhar")

	-- Câmera lenta também não lê como golpe.
	local lerdo = CombatAnimations.validateClip(fake({ speed = 0.2 }), 0.5)
	assertTrue(not lerdo, "0,2× é câmera lenta e deve falhar")

	local janelaNegativa = CombatAnimations.validateClip(fake({ startTimeSeconds = -0.1 }), 0.3)
	assertTrue(not janelaNegativa, "início negativo falha")

	local janelaForaDoClipe = CombatAnimations.validateClip(fake({ startTimeSeconds = 0.5 }), 0.1)
	assertTrue(not janelaForaDoClipe, "início igual ao fim do clipe falha")

	local badAsset = CombatAnimations.validateClip(fake({ assetId = "http://exemplo/animacao" }), 0.3)
	assertTrue(not badAsset, "asset fora do formato rbxassetid falha")
end)

-- ── Juntas do overlay: o bug que deixava o combate sem animação ─────────────

test("juntas: overlay aceita Motor6D e AnimationConstraint", function()
	-- O avatar R15 atual monta o rig com AnimationConstraint e ZERO Motor6D
	-- (medido no Studio em 14/08). Enquanto o animador procurava só Motor6D, o
	-- overlay inteiro não saía do papel — era a reclamação "as animações de
	-- golpes estão péssimas". Este teste é o que impede a regressão.
	assertTrue(PlayerCombatAnimator.isPoseJointClass("AnimationConstraint"), "rig novo do avatar")
	assertTrue(PlayerCombatAnimator.isPoseJointClass("Motor6D"), "rig clássico")
	assertTrue(not PlayerCombatAnimator.isPoseJointClass("Weld"), "weld não é junta de pose")
	assertTrue(not PlayerCombatAnimator.isPoseJointClass("BallSocketConstraint"), "física não é junta de pose")

	assertTrue(ActorAnimator.isPoseJointClass("AnimationConstraint"), "ator de rig R15")
	assertTrue(ActorAnimator.isPoseJointClass("Motor6D"), "ator greybox em Parts")
	assertTrue(not ActorAnimator.isPoseJointClass("Weld"), "gear soldado não é junta de pose")
end)

test("juntas: nome do rig vira papel da pose nos dois formatos", function()
	assertEq(PlayerCombatAnimator.jointRole("RightShoulder"), "rightShoulder", "R15 sem espaço")
	assertEq(PlayerCombatAnimator.jointRole("Right Shoulder"), "rightShoulder", "R6 com espaço")
	assertEq(PlayerCombatAnimator.jointRole("RootJoint"), "root", "raiz do R6")
	assertEq(PlayerCombatAnimator.jointRole("Root"), "root", "raiz do R15")
	assertEq(PlayerCombatAnimator.jointRole("Waist"), "waist", "cintura")
	assertEq(PlayerCombatAnimator.jointRole("LeftKnee"), "leftKnee", "joelho do chute")
	assertEq(PlayerCombatAnimator.jointRole("RightWrist"), "rightWrist", "punho do estalo")
	assertEq(PlayerCombatAnimator.jointRole("GearWeld"), nil, "roupa soldada não vira junta")
	assertEq(PlayerCombatAnimator.jointRole("Handle"), nil, "nome desconhecido não vira junta")
end)

for _, entry in tests do
	local ok, err = pcall(entry.fn)
	if ok then
		passed += 1
		print(("[ok]   %s"):format(entry.name))
	else
		failed += 1
		print(("[FALHA] %s\n        %s"):format(entry.name, tostring(err)))
	end
end

print(("\nResultado: %d passaram, %d falharam"):format(passed, failed))
if failed > 0 then
	error("Há testes falhando")
end

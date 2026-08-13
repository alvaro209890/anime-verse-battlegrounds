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
	-- assetId vazio é o estado atual do catálogo (pré-upload). O player precisa
	-- devolver nil sem erro, senão o jogo quebra esperando áudio inexistente.
	local player = CombatAudioPlayer.new({
		catalog = CombatAudio,
		now = function()
			return 0
		end,
	})
	assertEq(CombatAudioPlayer.resolve(player, "impact_light"), nil, "sem assetId não resolve")
	assertEq(CombatAudioPlayer.resolve(player, "inexistente"), nil, "deixa desconhecida não resolve")
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

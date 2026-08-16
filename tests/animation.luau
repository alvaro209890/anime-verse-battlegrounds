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

local function assertFalse(cond: boolean, msg: string?)
	assertTrue(not cond, msg or "assertFalse falhou")
end

local PlayerCombatAnimator = require("../src/client/Presentation/PlayerCombatAnimator")
local CombatCameraController = require("../src/client/Presentation/CombatCameraController")
local CombatAudioPlayer = require("../src/client/Presentation/CombatAudioPlayer")
local CombatAudio = require("../src/shared/Data/CombatAudio")
local AbilityVfx = require("../src/shared/Data/AbilityVfx")
local CombatHudController = require("../src/client/Controllers/CombatHudController")
local CombatAnimations = require("../src/shared/Data/CombatAnimations")
local ActorAnimator = require("../src/client/Presentation/ActorAnimator")
local EnemyAbilities = require("../src/shared/Data/EnemyAbilities")
local EnemyVfxAssets = require("../src/shared/Data/EnemyVfxAssets")
local EnemyVfxPlayer = require("../src/client/Presentation/EnemyVfxPlayer")
local ZoneSignalPlayer = require("../src/client/Presentation/ZoneSignalPlayer")
local Npcs = require("../src/shared/Data/Npcs")
local SceneryPresentation = require("../src/shared/Data/SceneryPresentation")
local InteractionBinding = require("../src/shared/InteractionBinding")
local WorldBootstrapContract = require("../src/shared/WorldBootstrapContract")
local Interactions = require("../src/shared/Data/Interactions")
local InteractionController = require("../src/client/Controllers/InteractionController")
local InteractionService = require("../src/server/Services/InteractionService")
local Zones = require("../src/shared/Data/Zones")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local CHAIN = PlayerCombatAnimator.LightChainLength

-- Amostra o quadro de IMPACTO do degrau. Antes isto usava `duração × 0,45`,
-- que com a trilha de quatro quadros (14/08) cai em cima do quadro do meio nos
-- degraus 3 e 4 — mediria o "dirige", não o golpe. O instante autoritativo é
-- publicado pelo próprio animador.
local function strikeOf(step: number)
	return PlayerCombatAnimator.sample("BasicLight", PlayerCombatAnimator.lightChainImpact(step), false, step)
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

test("cadeia: o golpe move o CORPO, não só o braço", function()
	-- Esta é a regressão de 14/08 à tarde: "quando eu mando um ataque o
	-- personagem tá só levantando o braço". Todo degrau — inclusive o jab, que
	-- é o que o jogador mais vê porque ataque solto é sempre o degrau 1 —
	-- precisa girar quadril e tronco e mexer as pernas no quadro de impacto.
	for step = 1, CHAIN do
		local hit = strikeOf(step)
		assertTrue(
			math.abs(hit.rootYawDegrees) >= 18,
			("degrau %d gira o quadril só %.1f° — lê como braço solto"):format(step, hit.rootYawDegrees)
		)
		assertTrue(
			math.abs(hit.waistYawDegrees) >= 20,
			("degrau %d torce o tronco só %.1f°"):format(step, hit.waistYawDegrees)
		)
		assertTrue(hit.rootHeightStuds <= -0.03, ("degrau %d não baixa o centro de massa"):format(step))
		-- Pernas participam: joelhos e tornozelos saem do neutro.
		assertTrue(
			hit.leftKneePitchDegrees ~= 0 and hit.rightKneePitchDegrees ~= 0,
			("degrau %d com joelhos parados"):format(step)
		)
		assertTrue(
			hit.leftAnklePitchDegrees ~= 0 or hit.rightAnklePitchDegrees ~= 0,
			("degrau %d com os dois pés colados no chão"):format(step)
		)
		-- Entrar no golpe: medido no Studio, o deslocamento do quadril move o
		-- corpo INTEIRO (0,220 pedido → 0,220 em todas as partes). Sem ele o
		-- rig gira no lugar e o soco vira braço mexendo.
		assertTrue(
			hit.rootForwardStuds >= 0.2,
			("degrau %d não entra no golpe (%.3f stud)"):format(step, hit.rootForwardStuds)
		)
	end

	-- E o peso vai para trás antes de ir para a frente: sem isso o passo não
	-- tem antecipação e o golpe começa já chegando.
	for step = 1, CHAIN do
		local windup =
			PlayerCombatAnimator.sample("BasicLight", PlayerCombatAnimator.lightChainImpact(step) * 0.3, false, step)
		assertTrue(windup.rootForwardStuds < 0, ("degrau %d não recua o peso na antecipação"):format(step))
	end
end)

test("A1: Ombro Cometa tem recuo, avanço corporal, impacto e recuperação", function()
	local beats = PlayerCombatAnimator.AuthoritativeBeats
	assertEq(beats.cometImpact, 0.40, "impacto autoritativo do Cometa")
	local windup = PlayerCombatAnimator.sample("Ability1", 0.16, false)
	local impact = PlayerCombatAnimator.sample("Ability1", beats.cometImpact + 0.02, false)
	local recovery = PlayerCombatAnimator.sample("Ability1", 0.74, false)
	assertTrue(windup.rootPitchDegrees < -4, "Cometa recolhe o corpo antes de dirigir")
	assertTrue(impact.rootPitchDegrees > 20, "ombro conduz a silhueta no impacto")
	assertTrue(impact.waistYawDegrees > 18, "tronco acompanha a direção do ombro")
	assertTrue(impact.rightElbowPitchDegrees < -60, "braço permanece fechado para não virar soco")
	assertTrue(math.abs(recovery.rootPitchDegrees) < 4, "Cometa retorna a raiz visual ao neutro")
end)

test("cadeia: cada degrau tem quadro do meio distinto do impacto", function()
	-- O quadro "dirige" é o que dá corpo ao golpe: o quadril já virou e a
	-- extremidade ainda está a caminho. Com dois quadros só (recolhe → bate) o
	-- rig chega inteiro de uma vez e sobra a extremidade para o olho.
	for step = 1, CHAIN do
		local impact = PlayerCombatAnimator.lightChainImpact(step)
		local drive = PlayerCombatAnimator.sample("BasicLight", impact * 0.75, false, step)
		local hit = PlayerCombatAnimator.sample("BasicLight", impact, false, step)
		assertTrue(
			math.abs(hit.rootYawDegrees - drive.rootYawDegrees) > 5,
			("degrau %d: meio e impacto viraram a mesma pose"):format(step)
		)
		-- O núcleo no meio do caminho já está adiantado em relação ao início.
		assertTrue(drive.rootYawDegrees ~= 0, ("degrau %d sem quadro do meio"):format(step))
	end
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
	local windupCoreTarget = -24 -- CROSS_COIL.rootYawDegrees
	local windupLimbTarget = -108 -- CROSS_COIL.rightElbowPitchDegrees
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
	assertEq(#CombatAudio.all(), 15, "15 deixas no catálogo")
end)

test("áudio: todo arquivo de origem existe no disco", function()
	local files = CombatAudio.sourceFiles()
	assertEq(#files, 33, "33 ogg distintos a publicar")
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
	assertEq(count, 15, "catálogo completo percorrido")
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
	-- A curva era quadrática e engolia o degrau de baixo (ver o teste seguinte).
	assertTrue(CombatCameraController.shakeAmplitude(0.5) > 0.25, "curva não achata mais o acerto comum")
	assertEq(CombatCameraController.shakeAmplitude(0), 0, "sem trauma não treme")
	assertEq(CombatCameraController.shakeAmplitude(1), 1, "trauma saturado é amplitude cheia")
	assertEq(CombatCameraController.shakeAmplitude(2), 1, "clampa acima de 1")
	local heavy = CombatCameraController.profileFor("hit", "comet_shoulder")
	local light = CombatCameraController.profileFor("hit", "basic_light")
	assertTrue(heavy ~= nil and light ~= nil, "perfis de acerto existem")
	if heavy and light then
		assertTrue(heavy.trauma > light.trauma, "técnica pesada sacode mais")
	end
	assertEq(CombatCameraController.profileFor("desconhecido", nil), nil, "desfecho desconhecido não treme")
end)

test("câmera: o acerto comum treme o bastante para ser visto", function()
	-- Regressão de 14/08 (noite): os perfis existiam, o código rodava, e o
	-- resultado era invisível. Com trauma 0,35 na curva quadrática o ACERTO
	-- COMUM — o golpe que o jogador mais dá — rendia 0,24° e 0,037 stud por
	-- 0,13 s. Este teste trava o PISO do que precisa ser sentido, e a ordem
	-- entre os desfechos, que é o que dá leitura sem depender de cor ou som.
	local function grausDe(outcome: string): number
		local perfil = CombatCameraController.profileFor(outcome, nil)
		assertTrue(perfil ~= nil, "perfil existe: " .. outcome)
		local trauma = (perfil :: any).trauma
		return CombatCameraController.shakeAmplitude(trauma) * CombatCameraController.MaxShakeDegrees
	end

	assertTrue(grausDe("hit") >= 1.0, ("acerto comum treme só %.2f°"):format(grausDe("hit")))
	assertTrue(grausDe("guard") < grausDe("hit"), "guarda sacode menos que acerto")
	assertTrue(grausDe("hit") < grausDe("counter"), "contra sacode mais que acerto")
	assertTrue(grausDe("counter") < grausDe("death"), "morte é o maior impacto")
	assertTrue(grausDe("death") <= CombatCameraController.MaxShakeDegrees, "nada passa do teto declarado")

	-- O punch de FOV é o outro meio-caminho do impacto e não depende da curva.
	local acerto = CombatCameraController.profileFor("hit", nil)
	assertTrue(acerto ~= nil and (acerto :: any).fov >= 2, "acerto precisa de punch de FOV perceptível")
end)

test("vfx: toda camada acende luz proporcional ao próprio raio", function()
	-- Reclamação de 14/08: "não está tendo luzes". Era literal — a camada de
	-- VFX criava ParticleEmitter, Trail e Part e NENHUM PointLight. Partícula
	-- com LightEmission brilha, mas não ilumina o chão nem o oponente.
	for _, technique in AbilityVfx.all() do
		for _, camada in technique.layers do
			local rotulo = technique.abilityId .. "/" .. camada.id
			assertTrue(camada.glowStuds > 0, rotulo .. " não acende luz nenhuma")
			local fator = AbilityVfx.GlowByKind[camada.kind]
			assertTrue(fator ~= nil, "forma sem fator de luz: " .. camada.kind)
			assertTrue(
				math.abs(camada.glowStuds - camada.radiusStuds * (fator :: number)) < 1e-9,
				rotulo .. ": a luz precisa seguir o raio da forma"
			)
		end
	end
	-- Instante do golpe estoura mais que a espera: é o disparo que deve marcar.
	assertTrue(AbilityVfx.GlowByKind.burst > AbilityVfx.GlowByKind.charge, "estouro acende mais que carga")
	assertTrue(AbilityVfx.GlowByKind.ring > AbilityVfx.GlowByKind.trail, "anel acende mais que rastro")
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

test("cenário: catálogo visual, terreno e teto têm parâmetros válidos", function()
	local ok, reason = SceneryPresentation.validate()
	assertTrue(ok, reason or "catálogo de cenário válido")
	local layoutOk, layoutReason = SceneryPresentation.validateLayout(Zones)
	assertTrue(layoutOk, layoutReason or "layout de cenário válido")
	local style = SceneryPresentation.style()
	assertTrue(style.wallCapHeight > 0, "tampa de parede positiva")
	assertTrue(style.roofTransparency > 0 and style.roofTransparency < 1, "teto translúcido")
	assertTrue(style.rockCount >= 20, "terreno tem rochas")
	assertTrue(style.grassCount >= 20, "terreno tem grama")
	assertEq(SceneryPresentation.assetSources()[1].license, "CC0", "fonte de cenário CC0")
end)

test("cenário: paleta e iluminação do spawn têm orçamento válido", function()
	local style = SceneryPresentation.style()
	assertTrue(style.spawnLightBrightness > 0 and style.spawnLightBrightness <= 4, "brilho do spawn limitado")
	assertTrue(style.spawnLightRange >= 8 and style.spawnLightRange <= 32, "alcance da luz limitado")
	assertTrue(style.spawnLightCount >= 2 and style.spawnLightCount <= 12, "quantidade de luzes limitada")
	for _, key in { "floorColor", "floorAccent", "ceilingColor", "lightColor", "fillLightColor" } do
		local rgb = style[key]
		assertEq(#rgb, 3, key .. " tem RGB completo")
	end
end)

test("fronteira: os cinco sinais do servidor viram apresentação local", function()
	local ZoneService = require("../src/server/Services/ZoneService")
	local signals = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free")
	assertTrue(signals ~= nil, "travessia de fronteira declara sinais")
	if not signals then
		return
	end
	assertEq(#signals, 5, "os cinco sinais vêm juntos (docs/02 §4.2)")
	assertTrue(ZoneSignalPlayer.hasAllSignals(signals), "o cliente reconhece o conjunto completo")

	local entering = ZoneSignalPlayer.plan({
		to = "zone_plain_free",
		pvp = true,
		signals = signals,
	})
	assertTrue(entering ~= nil, "entrar na livre tem apresentação")
	if not entering then
		return
	end
	assertEq(entering.bannerKey, "hud.pvp_active", "faixa avisa o PvP")
	assertTrue(entering.tintIntensity > 0 and entering.tintIntensity <= 0.35, "pulso fraco, não tela de dano")
	assertTrue(entering.durationSeconds <= 1.2, "pulso curto")

	local returning = ZoneSignalPlayer.plan({
		to = "zone_bastion_safe",
		pvp = false,
		signals = ZoneService.getFrontierSignals("zone_plain_free", "zone_bastion_safe"),
	})
	assertTrue(returning ~= nil, "voltar para a segura também sinaliza")
	if returning then
		assertEq(returning.bannerKey, "hud.zone_safe", "faixa volta para SEGURO")
		assertTrue(returning.tintRgb[3] > returning.tintRgb[1], "volta puxa para o frio")
		assertTrue(entering.tintRgb[1] > entering.tintRgb[3], "ida puxa para o quente")
	end
end)

test("fronteira: travessia recusada e evento interno não acendem nada", function()
	local ZoneService = require("../src/server/Services/ZoneService")
	local signals = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free")

	-- Recusa é o caso que mais importa: o hold ainda não terminou, o jogador
	-- NÃO cruzou, e pintar a tela ensinaria que cruzou.
	assertEq(
		ZoneSignalPlayer.plan({
			to = "zone_plain_free",
			pvp = true,
			signals = signals,
			rejectedReason = "hold_required",
		}),
		nil,
		"hold_required não apresenta"
	)
	assertEq(
		ZoneSignalPlayer.plan({
			to = "zone_bastion_safe",
			pvp = false,
			signals = signals,
			rejectedReason = "combat_lockout",
		}),
		nil,
		"lockout de combate não apresenta"
	)
	-- A faixa de transição É a fronteira, então segura↔transição carrega os
	-- sinais. Quem não carrega é movimento dentro da mesma zona — e sem sinais
	-- no payload o cliente não apresenta nada.
	assertEq(
		ZoneService.getFrontierSignals("zone_bastion_safe", "zone_bastion_safe"),
		nil,
		"mesma zona não é fronteira"
	)
	assertEq(ZoneSignalPlayer.plan({ to = "zone_bastion_safe", pvp = false }), nil, "sem sinais, sem pulso")
	assertEq(
		ZoneSignalPlayer.plan({ to = "zone_plain_free", pvp = true, signals = { "ui_banner" } }),
		nil,
		"conjunto incompleto é recusado"
	)
	assertEq(ZoneSignalPlayer.plan(nil), nil, "payload ausente é recusado")
end)

test("fronteira: o pulso sobe, desce e volta ao neutro sozinho", function()
	local ZoneService = require("../src/server/Services/ZoneService")
	local plan = ZoneSignalPlayer.plan({
		to = "zone_plain_free",
		pvp = true,
		signals = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free"),
	})
	assertTrue(plan ~= nil, "plano existe")
	if not plan then
		return
	end
	assertEq(ZoneSignalPlayer.intensityAt(plan, 0), 0, "começa em zero")
	local peak = ZoneSignalPlayer.intensityAt(plan, 0.12)
	assertTrue(peak > ZoneSignalPlayer.intensityAt(plan, 0.06), "sobe até o pico")
	assertTrue(peak > ZoneSignalPlayer.intensityAt(plan, 0.5), "e desce depois dele")
	assertEq(ZoneSignalPlayer.intensityAt(plan, plan.durationSeconds), 0, "acaba exatamente no fim")
	assertEq(ZoneSignalPlayer.intensityAt(plan, 5), 0, "não fica preso aceso")
	assertEq(ZoneSignalPlayer.intensityAt(plan, -1), 0, "tempo negativo não acende")

	-- A vibração sai uma vez, no evento aceito, e nunca no recusado.
	local pulses = 0
	local player = ZoneSignalPlayer.new({
		lighting = nil,
		runService = nil,
		haptics = function()
			pulses += 1
		end,
		now = function()
			return 0
		end,
	})
	local accepted = ZoneSignalPlayer.onZoneEvent(player, {
		to = "zone_plain_free",
		pvp = true,
		signals = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free"),
	})
	assertTrue(accepted, "evento aceito arma o pulso")
	assertEq(pulses, 1, "uma vibração por travessia")
	local rejected = ZoneSignalPlayer.onZoneEvent(player, {
		to = "zone_plain_free",
		pvp = true,
		signals = ZoneService.getFrontierSignals("zone_bastion_safe", "zone_plain_free"),
		rejectedReason = "hold_required",
	})
	assertFalse(rejected, "evento recusado é ignorado")
	assertEq(pulses, 1, "recusa não vibra")
end)

test("fronteira: o cliente liga o apresentador ao ZoneEvent e ao passo de render", function()
	local source = fs.readFile("src/client/init.client.lua")
	assertTrue(source:find("ZoneSignalPlayer.onZoneEvent(zoneSignals, payload)", 1, true) ~= nil, "ligado ao evento")
	assertTrue(source:find("ZoneSignalPlayer.step(zoneSignals)", 1, true) ~= nil, "decai no passo de render")
	-- A vibração é opcional por plataforma: sem proteção, um erro de
	-- HapticService derrubaria a travessia inteira.
	assertTrue(source:find("HapticService:SetMotor", 1, true) ~= nil, "vibração é um dos cinco sinais")
	assertTrue(source:find("pcall(function()", 1, true) ~= nil, "plataforma sem vibração não quebra a travessia")
end)

test("cenário: as fontes de luz do spawn são dados, ficam na sala e cobrem o roteiro", function()
	local lights = SceneryPresentation.spawnLights()
	local style = SceneryPresentation.style()
	assertEq(#lights, style.spawnLightCount, "quantidade declarada bate com o orçamento")

	local shadowCasters = 0
	local greybox = Zones.greybox()
	for _, light in lights do
		assertEq(#light.position, 3, light.name .. " tem posição completa")
		assertTrue(light.tone == "key" or light.tone == "fill", light.name .. " usa um tom do estilo")
		-- Luz fora da sala ilumina o lado de fora; acima do teto (Y = 22) fica
		-- presa no painel de vidro.
		assertTrue(math.abs(light.position[1]) <= greybox.bastionSize.x / 2 - 2, light.name .. " dentro em X")
		assertTrue(math.abs(light.position[3]) <= greybox.bastionSize.z / 2 - 2, light.name .. " dentro em Z")
		assertTrue(light.position[2] >= 4 and light.position[2] <= 21, light.name .. " na altura da sala")
		if light.shadows then
			shadowCasters += 1
		end
	end
	assertTrue(shadowCasters <= 2, "sombra de PointLight é o item caro no Android")

	-- Os dois alvos dos primeiros 60 s do roteiro (docs/13 §10) precisam de luz
	-- própria: sem isso o jogador procura a Instrutora e o boneco no escuro.
	local function lightNear(x: number, z: number, radius: number): boolean
		for _, light in lights do
			local dx = light.position[1] - x
			local dz = light.position[3] - z
			if math.sqrt(dx * dx + dz * dz) <= radius then
				return true
			end
		end
		return false
	end
	local instructor = Zones.getAnchor("anchor_instructor")
	local training = Zones.getAnchor("anchor_training")
	assertTrue(instructor ~= nil and training ~= nil, "âncoras existem")
	if instructor and training then
		assertTrue(lightNear(instructor.position.x, instructor.position.z, 6), "Instrutora iluminada")
		assertTrue(lightNear(training.position.x, training.position.z, 6), "pad de treino iluminado")
	end

	-- A materialização não pode voltar a ter posição escrita à mão.
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(source:find("scenery.spawnLights()", 1, true) ~= nil, "buildLighting lê o catálogo")
	assertTrue(source:find("local lightPositions", 1, true) == nil, "sem lista de posições no WorldService")
end)

test("npc: instrutora tem silhueta visual enriquecida e rosto validado", function()
	local rig = require("../src/shared/Data/WorldPresentation").rigFor("npc_threshold_instructor")
	assertTrue(rig ~= nil, "rig da instrutora existe")
	if not rig then
		return
	end
	assertTrue(#rig.gear >= 20, "instrutora tem camadas suficientes")
	assertEq(rig.faceTexture, "rbxasset://textures/face.png", "rosto usa textura embutida")
	local ok, reason = require("../src/shared/Data/WorldPresentation").validateRigs()
	assertTrue(ok, reason or "rigs válidos")
end)

test("npc: os dois bots têm volume de perfil, de costas e nas pernas", function()
	local Presentation = require("../src/shared/Data/WorldPresentation")
	for _, rig in Presentation.allRigs() do
		local lateral, back, legs = 0, 0, 0
		for _, piece in rig.gear do
			if math.abs(piece.offsetStuds[1]) >= 0.3 then
				lateral += 1
			end
			if piece.offsetStuds[3] >= 0.2 then
				back += 1
			end
			if string.find(piece.host, "Leg") or string.find(piece.host, "Foot") then
				legs += 1
			end
		end
		-- Um boneco resolvido só de frente vira papelão quando a câmera gira —
		-- é o que a rodada de 15/08 foi corrigir nos dois.
		assertTrue(lateral >= 6, rig.npcId .. " precisa de volume lateral")
		assertTrue(back >= 3, rig.npcId .. " precisa de volume nas costas")
		assertTrue(legs >= 4, rig.npcId .. " precisa de camada nas pernas")
	end
	local ok, reason = Presentation.validateRigs()
	assertTrue(ok, reason or "rigs continuam válidos após o enriquecimento")
end)

test("npc: interação procura a cabeça também dentro do Body R15", function()
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(
		source:find('model:FindFirstChild("Head", true)', 1, true) ~= nil,
		"cabeça do rig R15 precisa ser localizada recursivamente"
	)
end)

test("npc: bootstrap verifica vínculo único da Instrutora", function()
	local source = fs.readFile("src/server/Services/WorldService.luau")
	assertTrue(
		source:find('verifyNpcInteractionBinding(root, "ThresholdInstructor", "npc_threshold_instructor")', 1, true)
			~= nil,
		"bootstrap verifica o vínculo da Instrutora"
	)
	assertTrue(
		source:find("InteractionBinding.isUniqueNpcBinding", 1, true) ~= nil,
		"bootstrap usa a regra compartilhada de vínculo"
	)
end)

test("npc: harness simula vínculo único, duplicado e ausente", function()
	local function part(name: string, npcId: string?)
		return {
			Name = name,
			IsA = function(_self: any, className: string)
				return className == "BasePart"
			end,
			GetAttribute = function(_self: any, attributeName: string)
				return if attributeName == "InteractionNpcId" then npcId else nil
			end,
		}
	end
	local function model(descendants: { any })
		return {
			GetDescendants = function(_self: any)
				return descendants
			end,
		}
	end

	local unique, uniqueCount, uniquePart = InteractionBinding.isUniqueNpcBinding(
		model({ part("Head", "npc_threshold_instructor"), part("Hair", nil) }),
		"npc_threshold_instructor"
	)
	assertTrue(unique, "rig R15 com Head aninhado tem vínculo único")
	assertEq(uniqueCount, 1, "contagem única")
	assertEq(uniquePart, "Head", "parte vinculada")

	local duplicate, duplicateCount = InteractionBinding.isUniqueNpcBinding(
		model({ part("Head", "npc_threshold_instructor"), part("Face", "npc_threshold_instructor") }),
		"npc_threshold_instructor"
	)
	assertFalse(duplicate, "duplicidade é rejeitada")
	assertEq(duplicateCount, 2, "contagem duplicada")

	local missing, missingCount =
		InteractionBinding.isUniqueNpcBinding(model({ part("Head", nil) }), "npc_threshold_instructor")
	assertFalse(missing, "vínculo ausente é rejeitado")
	assertEq(missingCount, 0, "contagem ausente")
end)

test("mundo: duas reconstruções mantêm snapshot estático único", function()
	local function snapshot()
		return {
			rootCount = 1,
			actorFolderCount = 1,
			spawnLightingCount = 1,
			staticActors = WorldBootstrapContract.expectedStaticActors(),
		}
	end

	local first = snapshot()
	local second = snapshot()
	local firstOk, firstReason = WorldBootstrapContract.validate(first)
	local secondOk, secondReason = WorldBootstrapContract.validate(second)
	assertTrue(firstOk, firstReason or "primeiro snapshot válido")
	assertTrue(secondOk, secondReason or "segundo snapshot válido")
	assertTrue(first.staticActors ~= second.staticActors, "reconstruções não compartilham tabela de atores")

	local duplicate = snapshot()
	table.insert(duplicate.staticActors, duplicate.staticActors[1])
	local duplicateOk = WorldBootstrapContract.validate(duplicate)
	assertFalse(duplicateOk, "ator duplicado é rejeitado")

	local duplicatedLighting = snapshot()
	duplicatedLighting.spawnLightingCount = 2
	local lightingOk = WorldBootstrapContract.validate(duplicatedLighting)
	assertFalse(lightingOk, "iluminação duplicada é rejeitada")
end)

test("interação: fluxo cliente-servidor aceita válida e rejeita distante", function()
	local sent: { any } = {}
	local controller = {
		state = { ready = true },
		catalog = Interactions,
		send = function(_remoteName: string, _action: string, payload: { [string]: any })
			table.insert(sent, payload)
		end,
	}

	InteractionController.onAction(controller, "Interact", {
		npcId = "npc_threshold_instructor",
		phase = "complete",
	})
	assertEq(#sent, 1, "cliente envia uma intenção")
	assertEq(sent[1].npcId, "npc_threshold_instructor", "cliente envia alvo semântico")
	assertEq(sent[1].anchorId, nil, "cliente não mistura alvo de âncora")

	local anchor = Zones.getAnchor("anchor_instructor")
	assertTrue(anchor ~= nil, "âncora da Instrutora existe")
	if not anchor then
		return
	end
	local position = { value = anchor.position }
	InteractionService.init({
		catalog = Interactions,
		getAnchor = Zones.getAnchor,
		getPlayerPosition = function(_userId: number)
			return position.value
		end,
		onNpc = function(_userId: number, _targetId: string, _at: number)
			return true, nil, { accepted = true }
		end,
		onAnchor = function(_userId: number, _targetId: string, _at: number)
			return true, nil, { accepted = true }
		end,
	})

	local accepted = InteractionService.tryInteract(700, sent[1], 10)
	assertTrue(accepted.ok, accepted.reason or "interação válida aceita")
	position.value = { x = anchor.position.x + 50, y = anchor.position.y, z = anchor.position.z }
	local far = InteractionService.tryInteract(700, sent[1], 11)
	assertFalse(far.ok, "interação distante rejeitada")
	assertEq(far.reason, "too_far", "motivo da rejeição distante")
end)

test("npc: catálogo de habilidades e assets gratuitos é válido", function()
	local ok, reason = EnemyAbilities.validate()
	assertTrue(ok, reason or "habilidades de NPC válidas")
	local assetsOk, assetsReason = EnemyVfxAssets.validate()
	assertTrue(assetsOk, assetsReason or "assets de NPC válidos")
	assertEq(EnemyAbilities.forEvent("enemy_wandering_shard", "pounce").id, "shard_pounce", "Pounce resolve")
	assertEq(EnemyAbilities.forEvent("enemy_anchored_shard", "slam").id, "anchored_slam", "Slam resolve")
	for _, asset in EnemyVfxAssets.all() do
		assertTrue(fs.isFile(asset.sourceFile), "asset Kenney existe: " .. asset.sourceFile)
	end
end)

test("npc: Pounce e Slam têm poses mais fortes que o baseline", function()
	local recipe = {
		shape = "shard",
		idleBobStuds = 0.2,
		idleCyclesPerSecond = 0.5,
		strideDegrees = 12,
		telegraphLeanDegrees = 20,
		attackLeanDegrees = 40,
		deathTiltDegrees = 80,
	}
	local pounce = ActorAnimator.sample(recipe, "attack", 0.17, 1, false, "pounce", 0.35)
	local rend = ActorAnimator.sample(recipe, "attack", 0.17, 1, false, "rend", 0.35)
	local slam = ActorAnimator.sample(recipe, "attack", 0.20, 1, false, "slam", 0.40)
	assertTrue(math.abs(pounce.leanDegrees) > math.abs(rend.leanDegrees), "Pounce inclina mais")
	assertTrue(math.abs(slam.leanDegrees) > math.abs(rend.leanDegrees), "Slam inclina mais")
end)

test("vfx: cada camada usa asset preparado conhecido e atlas existente", function()
	local assets = AbilityVfx.allAssets()
	assertEq(#assets, 5, "cinco assets preparados no catálogo")
	for _, asset in assets do
		assertTrue(fs.isFile(asset.preparedFile), "atlas preparado existe: " .. asset.preparedFile)
		assertTrue(fs.isFile(asset.sourceFile), "fonte existe: " .. asset.sourceFile)
		assertTrue(asset.assetId == nil, "IDs Roblox não são inventados antes da publicação")
		assertTrue(asset.framerate > 0, "framerate positivo: " .. asset.key)
	end
	for _, technique in AbilityVfx.all() do
		for _, layer in technique.layers do
			assertTrue(layer.assetKey ~= nil, technique.action .. "/" .. layer.id .. " tem asset")
			local asset = AbilityVfx.assetFor(layer.assetKey)
			assertTrue(asset ~= nil, technique.action .. "/" .. layer.id .. " resolve asset")
		end
	end
	local ok, reason = AbilityVfx.validate()
	assertTrue(ok, reason or "catálogo de VFX válido")
end)

test("vfx: defesa e dash usam receitas locais sem declarar acerto", function()
	local guard = AbilityVfx.get("guard_raise")
	local dash = AbilityVfx.get("dash_run")
	assertTrue(guard ~= nil, "receita de defesa existe")
	assertTrue(dash ~= nil, "receita de dash existe")
	if not guard or not dash then
		return
	end
	assertEq(guard.action, "GuardDown", "defesa mapeia para GuardDown")
	assertEq(dash.action, "Dash", "corrida mapeia para Dash")
	assertEq(guard.actionDurationSeconds, PlayerCombatAnimator.Durations.GuardDown, "duração da defesa")
	assertEq(dash.actionDurationSeconds, PlayerCombatAnimator.Durations.Dash, "duração do dash")
	for _, recipe in { guard, dash } do
		for _, layer in recipe.layers do
			assertTrue(not layer.requiresConfirmation, recipe.action .. "/" .. layer.id .. " não afirma contato")
			assertTrue(layer.radiusStuds <= recipe.rangeStuds, recipe.action .. "/" .. layer.id .. " respeita o raio")
		end
	end
	local guardPlan = AbilityVfx.planAt(guard, 0.08, false)
	local dashPlan = AbilityVfx.planAt(dash, 0.20, false)
	assertTrue(#guardPlan >= 1, "defesa acende durante a entrada")
	assertTrue(#dashPlan >= 1, "dash acende no atrito")
end)

test("apresentação: dash tem preparação, passada e recuperação distintas", function()
	local prep = PlayerCombatAnimator.sample("Dash", 0.03, false)
	local drive = PlayerCombatAnimator.sample("Dash", 0.11, false)
	local recover = PlayerCombatAnimator.sample("Dash", 0.20, false)
	local neutral = PlayerCombatAnimator.sample("Dash", PlayerCombatAnimator.Durations.Dash, false)
	assertTrue(prep.rootForwardStuds < 0, "dash comprime antes de sair")
	assertTrue(drive.rootForwardStuds > prep.rootForwardStuds, "dash entra no passo")
	assertTrue(
		math.abs(drive.rightKneePitchDegrees) > math.abs(prep.rightKneePitchDegrees),
		"dash levanta a perna de impulso"
	)
	assertTrue(recover.rootForwardStuds > 0, "dash tem recuperação com peso à frente")
	assertEq(neutral.rootForwardStuds, 0, "dash volta ao neutro")
end)

test("apresentação: defesa fecha braços, joelhos e pulsos", function()
	local guard = PlayerCombatAnimator.sample("GuardDown", 0.12, false)
	assertTrue(guard.leftShoulderPitchDegrees < -35, "braço esquerdo fecha")
	assertTrue(guard.rightShoulderPitchDegrees < -35, "braço direito fecha")
	assertTrue(guard.leftElbowPitchDegrees < 0 and guard.rightElbowPitchDegrees < 0, "cotovelos sustentam a guarda")
	assertTrue(guard.leftKneePitchDegrees < 0 and guard.rightKneePitchDegrees < 0, "joelhos absorvem a postura")
	assertTrue(
		guard.leftWristPitchDegrees ~= 0 or guard.rightWristPitchDegrees ~= 0,
		"punhos dão acabamento à defesa"
	)
end)

test("vfx: bootstrap conecta defesa e dash ao player local", function()
	local source = fs.readFile("src/client/init.client.lua")
	assertTrue(source:find("AbilityVfxPlayer.play(abilityVfx, action)", 1, true) ~= nil, "input dispara VFX local")
	assertTrue(source:find("servidor continua", 1, true) ~= nil, "comentário preserva autoridade")
end)

test("vfx: bootstrap instancia, inicia e confirma o player", function()
	local source = fs.readFile("src/client/init.client.lua")
	assertTrue(source:find("abilityVfx = AbilityVfxPlayer.new", 1, true) ~= nil, "player de VFX é instanciado")
	assertTrue(source:find("AbilityVfxPlayer.start(abilityVfx)", 1, true) ~= nil, "player de VFX é iniciado")
	assertTrue(
		source:find("AbilityVfxPlayer.confirm(abilityVfx", 1, true) ~= nil,
		"VFX recebe confirmação autoritativa"
	)
	assertTrue(
		source:find('payload.abilityId == "pulse_return" and payload.outcome == "counter"', 1, true) ~= nil,
		"contra é filtrado pelo evento"
	)
	assertTrue(
		source:find('PlayerCombatAnimator.play(playerCombatAnimator, "Ability3Counter")', 1, true) ~= nil,
		"contra inicia pose específica"
	)
	assertTrue(
		source:find('AbilityVfxPlayer.play(abilityVfx, "Ability3Counter")', 1, true) ~= nil,
		"contra inicia VFX específico"
	)
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

test("clipes: nenhum clipe entra no combate — a apresentação é procedural", function()
	-- Decisão de 14/08 (docs/14 §4.6): o corte de espada balança o braço DIREITO
	-- e o jab procedural soca com o ESQUERDO. As duas camadas discordavam sobre
	-- qual braço ataca, e o clipe ganhava a tela — era o "personagem só
	-- levantando o braço". Este teste impede a volta silenciosa.
	for step = 1, CHAIN do
		assertEq(CombatAnimations.forAction("BasicLight", step), nil, ("degrau %d sem clipe"):format(step))
	end
	for _, action in { "BasicHeavy", "Ability1", "Ability2", "Ability2Echo", "Ability3", "Ability3Counter" } do
		assertEq(CombatAnimations.forAction(action), nil, action .. " sem clipe")
	end
	assertEq(#CombatAnimations.all(), 0, "catálogo vazio")
	assertEq(#CombatAnimations.assetIds(), 0, "nenhum asset declarado sobrando")

	-- A costura continua de pé para o Gate A1: declarar um clipe volta a ligar a
	-- camada, e o validador continua recusando o que não é legível.
	local exemplo = CombatAnimations.clip({
		action = "Exemplo",
		assetId = "rbxassetid://1",
		speed = 1,
		nominalSeconds = 0.5,
	})
	assertTrue(CombatAnimations.validateClip(exemplo, 0.5), "clipe bem formado continua passando")
	assertEq(exemplo.startTimeSeconds, 0, "padrão do janelamento é o início do clipe")
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

test("juntas: rig que só aparece depois do personagem ainda entra na pose", function()
	-- O defeito real, medido no personagem do jogador em 2026-08-14: no instante
	-- do CharacterAdded o modelo tem 0 AnimationConstraint, 0 Motor6D e nem
	-- RightHand — as 15 juntas só existem meio segundo depois. Com uma varredura
	-- única no anexo, o animador capturava zero junta e nunca mais procurava: o
	-- combate ficava sem NENHUMA animação. Aqui o `joints` começa vazio de
	-- propósito, como no anexo que chegou cedo, e as juntas são oferecidas depois.
	local R15 = {
		"Root",
		"Waist",
		"Neck",
		"LeftShoulder",
		"RightShoulder",
		"LeftElbow",
		"RightElbow",
		"LeftWrist",
		"RightWrist",
		"LeftHip",
		"RightHip",
		"LeftKnee",
		"RightKnee",
		"LeftAnkle",
		"RightAnkle",
	}

	local joints: { [string]: any } = {}
	assertEq(next(joints), nil, "anexo cedo começa sem junta nenhuma")

	for _, nome in R15 do
		local papel = PlayerCombatAnimator.jointSlotFor(joints, "AnimationConstraint", nome)
		assertTrue(papel ~= nil, "junta que chega depois precisa achar papel: " .. nome)
		joints[papel :: string] = { nome = nome }
	end

	local total = 0
	for _ in joints do
		total += 1
	end
	assertEq(total, #R15, "as 15 juntas do R15 entram mesmo chegando atrasadas")
	assertTrue(joints.root ~= nil, "raiz é quem carrega o passo à frente")
	assertTrue(joints.leftAnkle ~= nil and joints.rightAnkle ~= nil, "tornozelos tiram o pé colado")
end)

test("juntas: papel já ocupado não é roubado por junta que chega depois", function()
	-- Primeira vista vence, senão um acessório com nome de junta trocaria o rig
	-- no meio do jogo. Vale igual na varredura inicial e na adoção tardia.
	local joints: { [string]: any } = {}
	local primeiro = PlayerCombatAnimator.jointSlotFor(joints, "Motor6D", "RightShoulder")
	assertEq(primeiro, "rightShoulder", "primeira junta ocupa o papel")
	joints.rightShoulder = { nome = "original" }

	assertEq(
		PlayerCombatAnimator.jointSlotFor(joints, "AnimationConstraint", "RightShoulder"),
		nil,
		"papel ocupado recusa a segunda"
	)
	assertEq(PlayerCombatAnimator.jointSlotFor(joints, "Weld", "LeftShoulder"), nil, "classe errada é recusada")
	assertEq(PlayerCombatAnimator.jointSlotFor(joints, "AnimationConstraint", "Handle"), nil, "nome sem papel")
	assertEq(
		PlayerCombatAnimator.jointSlotFor(joints, "AnimationConstraint", "LeftShoulder"),
		"leftShoulder",
		"papel livre continua aceitando"
	)
end)

test("vfx inimigo: luz de ataque nunca excede a hitbox real do NPC (docs/17)", function()
	-- Honestidade visual: o Range da PointLight deriva de NpcDef.attackRange
	-- (função pura rangeFor) — antes era fixo (12/8 telegraph, 16/10 ataque)
	-- e "mentia" sobre o alcance real do golpe (errante 4, ancorado 8).
	local checked = 0
	for _, npcDef in Npcs.all() do
		if type(npcDef.attackRange) == "number" and npcDef.attackRange > 0 then
			local range = EnemyVfxPlayer.rangeFor(npcDef)
			assertTrue(
				range <= npcDef.attackRange,
				("%s: luz %.1f excede hitbox %.1f"):format(tostring(npcDef.id), range, npcDef.attackRange)
			)
			assertTrue(range >= 0, "alcance nunca é negativo")
			checked += 1
		end
	end
	assertTrue(checked > 0, "pelo menos um NPC com attackRange foi verificado")
	-- Fallback sem def: âncora (8) é o teto honesto; nunca 16/10 antigos.
	assertEq(EnemyVfxPlayer.rangeFor(nil), 8, "fallback sem def usa o teto do ancorado")
	assertEq(EnemyVfxPlayer.rangeFor({ attackRange = 4 }), 4, "errante usa 4")
end)

test("visual: inventário canônico cobre 31 conceitos e nada está ligado ao runtime", function()
	assertTrue(fs.isFile("docs/assets/visual-inventory.json"), "inventário existe")
	local inventory = serde.decode("json", fs.readFile("docs/assets/visual-inventory.json"))
	assertEq(inventory.schemaVersion, 1, "schema do inventário")
	assertEq(inventory.runtimeLinked, false, "inventário não marca runtime")
	assertEq(#inventory.conceptImages, 31, "31 PNGs conceituais")
	local f1Only = 0
	local textureCandidates = 0
	for _, image in inventory.conceptImages do
		assertTrue(fs.isFile(image.path), "conceito no disco: " .. image.path)
		assertEq(image.runtimeLinked, false, "conceito desligado: " .. image.path)
		assertEq(#image.sha256, 64, "sha256 de " .. image.path)
		assertTrue(image.verdict ~= nil and image.verdict ~= "", "veredito de " .. image.path)
		if image.verdict == "f1_only" then
			f1Only += 1
		elseif image.verdict == "texture_candidate" then
			textureCandidates += 1
		end
	end
	assertEq(f1Only, 8, "oito habilidades futuras continuam F1-only")
	assertEq(textureCandidates, 3, "três texturas candidatas")
	assertEq(
		inventory.kenneyParticlePack.path,
		"docs/assets/open-candidates/kenney_particle-pack.zip",
		"path canônico do zip Kenney"
	)
	assertTrue(fs.isFile(inventory.kenneyParticlePack.path), "zip Kenney no disco")
	assertEq(inventory.kenneyParticlePack.pngCount, 193, "193 PNG no arquivo")
	assertEq(inventory.kenneyNatureKit.meshCount, 0, "Nature Kit sem malha versionada")
	assertEq(#inventory.vfxCatalog.files, 13, "cinco fontes + cinco atlas + três Kenney de inimigo")
end)

test("visual: paleta extraída não autoriza recolorir o runtime", function()
	assertTrue(fs.isFile("docs/assets/art-direction-palette.json"), "paleta existe")
	local palette = serde.decode("json", fs.readFile("docs/assets/art-direction-palette.json"))
	assertEq(palette.doNotRecolorRuntimeWithoutPlay, true, "trava de recolor")
	assertEq(#palette.knownDrift, 3, "três UMBRAL_CORE documentados")
	assertEq(AbilityVfx.UmbralCoreRgb[1], 214, "núcleo umbral R")
	assertEq(AbilityVfx.UmbralCoreRgb[2], 206, "núcleo umbral G")
	assertEq(AbilityVfx.UmbralCoreRgb[3], 232, "núcleo umbral B")
	assertEq(AbilityVfx.UmbralEdgeRgb[1], 88, "borda umbral R")
	local style = SceneryPresentation.style()
	assertEq(style.wallColor[1], 74, "parede greybox")
	assertEq(style.lightColor[1], 144, "luz fria de chave")
	assertEq(style.fillLightColor[1], 184, "preenchimento violeta")
end)

test("visual: thumbnail e ícone existem e continuam unpublished", function()
	local store = serde.decode("json", fs.readFile("docs/assets/roblox-ready/store/store-art-manifest.json"))
	assertEq(#store.assets, 2, "thumbnail e ícone")
	for _, asset in store.assets do
		assertEq(asset.published, false, asset.role .. " não publicado")
		assertTrue(fs.isFile(asset.output), asset.output)
	end
	assertTrue(fs.isFile("docs/33-ASSET-USABILITY.md"), "matriz de usabilidade")
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

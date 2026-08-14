--!nonstrict
-- Toca clipes de animação de verdade no avatar do jogador local, a partir do
-- catálogo puro `src/shared/Data/CombatAnimations.luau`.
--
-- Camada de Instances (como WorldService): não é coberta por teste Lune —
-- Animator, AnimationTrack e Trail não existem sem DataModel. O que é decisão
-- (qual clipe, que velocidade, cabe na duração da ação?) mora no catálogo e
-- **é** testado. Aqui só há materialização.
--
-- Convivência com o procedural: o `PlayerCombatAnimator` continua compondo
-- overlay nos Motor6D. Um AnimationTrack com prioridade Action ganha do idle
-- do Animate padrão; o overlay procedural entra por cima do resultado. Se o
-- asset não carregar (moderação, offline), o clipe é ignorado e o procedural
-- segue sozinho — o combate nunca fica sem nenhuma leitura.

local CharacterAnimationPlayer = {}

local TRAIL_LIFETIME_SECONDS = 0.16
local TRAIL_HOLD_SECONDS = 0.06
local TRAIL_COLOR = Color3.fromRGB(186, 150, 232)

function CharacterAnimationPlayer.new(deps: {
	player: any,
	catalog: any,
	now: (() -> number)?,
}): any
	return {
		player = deps.player,
		catalog = deps.catalog,
		now = deps.now or os.clock,
		character = nil,
		animator = nil,
		tracks = {},
		failed = {},
		current = nil,
		currentUntil = 0,
		currentFadeOut = 0.12,
		trail = nil,
		trailUntil = 0,
		characterAddedConnection = nil,
		warned = false,
	}
end

local function buildTrail(character: Model): Trail?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end
	local existing = hand:FindFirstChild("AvbSwingTrail")
	if existing and existing:IsA("Trail") then
		return existing
	end

	local top = Instance.new("Attachment")
	top.Name = "AvbSwingTrailTop"
	top.Position = Vector3.new(0, 0.25, 0)
	top.Parent = hand

	local bottom = Instance.new("Attachment")
	bottom.Name = "AvbSwingTrailBottom"
	bottom.Position = Vector3.new(0, -0.45, 0)
	bottom.Parent = hand

	-- Sem Texture: o Trail sem textura é um rastro sólido do próprio engine —
	-- nada para subir ao Roblox e nada que possa ser moderado.
	local trail = Instance.new("Trail")
	trail.Name = "AvbSwingTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = TRAIL_LIFETIME_SECONDS
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.65
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(TRAIL_COLOR)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.Enabled = false
	trail.Parent = hand
	return trail
end

local function detach(player: any): ()
	if player.current then
		pcall(function()
			player.current:Stop(0.1)
		end)
		player.current = nil
	end
	player.tracks = {}
	player.animator = nil
	player.trail = nil
	player.character = nil
end

local function attach(player: any, character: Model?): ()
	if player.character == character then
		return
	end
	detach(player)
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	player.character = character
	player.animator = animator
	player.trail = buildTrail(character)
end

-- Carrega (uma vez por personagem) o track do asset. Falha vira silêncio com
-- um aviso único: o jogo não pode quebrar porque um placeholder saiu do ar.
local function trackFor(player: any, assetId: string): any?
	if player.failed[assetId] then
		return nil
	end
	local cached = player.tracks[assetId]
	if cached then
		return cached
	end
	local animator = player.animator
	if not animator then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		player.failed[assetId] = true
		if not player.warned then
			player.warned = true
			warn(
				("[CharacterAnimationPlayer] clipe %s não carregou (%s) — pose procedural assume"):format(
					assetId,
					tostring(track)
				)
			)
		end
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	player.tracks[assetId] = track
	return track
end

-- Toca o clipe da ação. Devolve true quando um clipe real entrou (o chamador
-- não muda de comportamento por isso — serve para teste manual e telemetria).
function CharacterAnimationPlayer.play(player: any, action: string, comboStep: number?): boolean
	attach(player, player.player.Character)
	local clip = player.catalog.forAction(action, comboStep)
	if not clip then
		return false
	end
	local track = trackFor(player, clip.assetId)
	if not track then
		return false
	end

	if player.current and player.current ~= track then
		pcall(function()
			player.current:Stop(clip.fadeOutSeconds)
		end)
	end
	local played = pcall(function()
		track:Play(clip.fadeInSeconds, clip.weight, clip.speed)
		track:AdjustSpeed(clip.speed)
		-- Janelamento (docs/14 §5.1): ações curtas entram no instante do golpe
		-- em vez de tocar o clipe inteiro acelerado. TimePosition só vale depois
		-- do Play — antes dele o track não tem duração para posicionar.
		if clip.startTimeSeconds > 0 then
			track.TimePosition = clip.startTimeSeconds
		end
	end)
	if not played then
		return false
	end
	player.current = track

	local budget = player.catalog.actionSeconds(action, comboStep) or 0.3
	-- Honestidade visual: a pose morre com a ação. O clipe pode ser mais longo
	-- que a janela (docs/14 §4.4) — quem corta é este prazo, com fade.
	player.currentUntil = player.now() + budget
	player.currentFadeOut = clip.fadeOutSeconds

	if player.trail then
		player.trail.Enabled = true
		player.trailUntil = player.now() + budget + TRAIL_HOLD_SECONDS
	end
	return true
end

-- Chamado todo frame pelo bootstrap: corta o clipe e o rastro no fim da ação.
function CharacterAnimationPlayer.step(player: any): ()
	local now = player.now()
	local trail = player.trail
	if trail and trail.Enabled and now >= player.trailUntil then
		trail.Enabled = false
	end
	local track = player.current
	if track and now >= player.currentUntil then
		player.current = nil
		pcall(function()
			track:Stop(player.currentFadeOut or 0.12)
		end)
	end
end

function CharacterAnimationPlayer.start(player: any): ()
	attach(player, player.player.Character)
	player.characterAddedConnection = player.player.CharacterAdded:Connect(function(character: Model)
		attach(player, character)
	end)
end

function CharacterAnimationPlayer.stop(player: any): ()
	if player.characterAddedConnection then
		player.characterAddedConnection:Disconnect()
		player.characterAddedConnection = nil
	end
	detach(player)
end

return CharacterAnimationPlayer

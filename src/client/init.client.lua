--!strict
-- Bootstrap de apresentação F0. Não há FireServer de boot: toda intenção passa
-- pelo InputController e somente depois de SessionSnapshot ready.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Data.Abilities)
local Characters = require(Shared.Data.Characters)
local Locale = require(Shared.Data.Locale)
local Interactions = require(Shared.Data.Interactions)
local WorldPresentation = require(Shared.Data.WorldPresentation)
local RemoteEnvelope = require(Shared.RemoteEnvelope)
local Remotes = require(Shared.Remotes)

local Controllers = script:WaitForChild("Controllers")
local Presentation = script:WaitForChild("Presentation")
local InputController = require(Controllers.InputController)
local InteractionController = require(Controllers.InteractionController)
local CharacterController = require(Controllers.CharacterController)
local AbilityController = require(Controllers.AbilityController)
local CombatFeedbackController = require(Controllers.CombatFeedbackController)
local CombatHudController = require(Controllers.CombatHudController)
local ResourceController = require(Controllers.ResourceController)
local ZoneController = require(Controllers.ZoneController)
local UIController = require(Controllers.UIController)
local ClientState = require(Controllers.ClientState)
local ActorAnimator = require(Presentation.ActorAnimator)
local PlayerCombatAnimator = require(Presentation.PlayerCombatAnimator)
local CombatCameraController = require(Presentation.CombatCameraController)
local CombatAudioPlayer = require(Presentation.CombatAudioPlayer)
local AbilityVfxPlayer = require(Presentation.AbilityVfxPlayer)
local EnemyVfxPlayer = require(Presentation.EnemyVfxPlayer)
local CharacterAnimationPlayer = require(Presentation.CharacterAnimationPlayer)
local CombatAudio = require(Shared.Data.CombatAudio)
local CombatAnimations = require(Shared.Data.CombatAnimations)
local AbilityVfx = require(Shared.Data.AbilityVfx)
local EnemyAbilities = require(Shared.Data.EnemyAbilities)
local EnemyVfxAssets = require(Shared.Data.EnemyVfxAssets)
local Npcs = require(Shared.Data.Npcs)

local player = Players.LocalPlayer
local state = ClientState.new(os.clock)
local remotesFolder = Shared:WaitForChild("Remotes")
local sequence = 0

local function remote(name: string): RemoteEvent
	return remotesFolder:WaitForChild(name) :: RemoteEvent
end

local function send(remoteName: string, action: string, payload: { [string]: any }): ()
	if not state.ready then
		return
	end
	sequence += 1
	local requestId = HttpService:GenerateGUID(false)
	remote(remoteName):FireServer(RemoteEnvelope.create(action, payload, requestId, sequence))
end

-- Ordem obrigatória de controllers (docs/13 §12.3).
local input = InputController.new(state, os.clock)
local playerCombatAnimator: any = nil
-- Declarado antes do AbilityController porque o callback de ativação o captura;
-- a construção fica junto das demais camadas de apresentação, abaixo.
local abilityVfx: any = nil
local enemyVfx = EnemyVfxPlayer.new({
	workspace = Workspace,
	runService = RunService,
	recipes = EnemyAbilities,
	assets = EnemyVfxAssets,
	npcs = Npcs,
	now = os.clock,
})
-- Clipes de animação reais (assets livres do Roblox). Mesmo motivo do
-- abilityVfx: o callback de ativação captura a referência.
local characterAnimation: any = nil
local character = CharacterController.new({
	state = state,
	input = input,
	inputSubscribe = InputController.subscribe,
	send = send,
	workspace = Workspace,
	players = Players,
	runService = RunService,
})
local ability = AbilityController.new({
	state = state,
	stateApi = ClientState,
	input = input,
	inputSubscribe = InputController.subscribe,
	abilities = Abilities,
	characters = Characters,
	send = send,
	guid = function()
		return HttpService:GenerateGUID(false)
	end,
	-- Quem conhece câmera e alvo travado é o CharacterController; a técnica só
	-- carrega a mira dele até o payload.
	aim = function()
		return CharacterController.aimVector(character)
	end,
	onActivated = function(slot: number, _abilityId: string, phase: string)
		-- A reentrada da Cadência não é "a técnica de novo": o servidor resolve
		-- um eco 350 ms depois, com dano próprio. Repetir a pose de ativação
		-- faria o jogador ler dois golpes iguais onde a regra mudou.
		local action = if phase == "reentry" then "Ability2Echo" else ("Ability%d"):format(slot)
		if playerCombatAnimator then
			PlayerCombatAnimator.play(playerCombatAnimator, action)
		end
		if characterAnimation then
			CharacterAnimationPlayer.play(characterAnimation, action)
		end
		if abilityVfx then
			AbilityVfxPlayer.play(abilityVfx, action)
		end
	end,
})
local feedback = CombatFeedbackController.new(state, ClientState)
local combatHud = CombatHudController.new({
	player = player,
	workspace = Workspace,
	now = os.clock,
})
local resource = ResourceController.new(state, ClientState)
local zone = ZoneController.new(state, ClientState, input, InputController.subscribe, send, os.clock)
local actorAnimator = ActorAnimator.new({
	workspace = Workspace,
	runService = RunService,
	recipes = WorldPresentation,
	now = os.clock,
})
-- Áudio de combate: o corte de ar sai da própria ação do jogador (2D, preso à
-- câmera); o impacto espera o desfecho autoritativo em CombatEvent.
local combatAudio = CombatAudioPlayer.new({
	catalog = CombatAudio,
	soundParent = workspace.CurrentCamera,
	now = os.clock,
})
playerCombatAnimator = PlayerCombatAnimator.new({
	player = player,
	runService = RunService,
	now = os.clock,
	emitCue = function(cueId: string)
		CombatAudioPlayer.play(combatAudio, cueId)
	end,
})
-- Câmera de impacto: shake/FOV locais disparados apenas por desfecho confirmado.
local combatCamera = CombatCameraController.new({
	workspace = Workspace,
	runService = RunService,
})
characterAnimation = CharacterAnimationPlayer.new({
	player = player,
	catalog = CombatAnimations,
	now = os.clock,
})
abilityVfx = AbilityVfxPlayer.new({
	player = player,
	runService = RunService,
	workspace = Workspace,
	recipes = AbilityVfx,
	now = os.clock,
})
InputController.subscribe(input, function(action: string, _payload: { [string]: any })
	if string.match(action, "^Ability%d$") == nil then
		PlayerCombatAnimator.play(playerCombatAnimator, action)
		-- O degrau da cadeia já foi avançado pelo play acima: é ele que decide
		-- qual dos quatro clipes leves entra.
		CharacterAnimationPlayer.play(characterAnimation, action, playerCombatAnimator.comboStep)
	end
end)
local interaction = InteractionController.new({
	state = state,
	input = input,
	inputSubscribe = InputController.subscribe,
	inputApi = InputController,
	send = send,
	workspace = Workspace,
	locale = Locale,
	catalog = Interactions,
	now = os.clock,
})
local characterStarted = false

remote(Remotes.Names.SessionSnapshot).OnClientEvent:Connect(function(payload: { [string]: any })
	if ClientState.applySnapshot(state, payload) and not characterStarted then
		characterStarted = true
		CharacterController.start(character)
	end
end)

remote(Remotes.Names.StateDelta).OnClientEvent:Connect(function(payload: { [string]: any })
	-- Delta de inimigo (vida de NPC) não toca o estado do jogador: alimenta
	-- as barras do HUD de combate.
	if type(payload.fighterId) == "string" then
		CombatHudController.onFighterDelta(combatHud, payload)
		return
	end
	ClientState.applyDelta(state, payload)
	ZoneController.onDelta(zone, payload)
end)

remote(Remotes.Names.ResourceChanged).OnClientEvent:Connect(function(payload: { [string]: any })
	ResourceController.onChanged(resource, payload)
end)

remote(Remotes.Names.ZoneEvent).OnClientEvent:Connect(function(payload: { [string]: any })
	ZoneController.onZoneEvent(zone, payload)
end)

remote(Remotes.Names.CombatEvent).OnClientEvent:Connect(function(payload: { [string]: any })
	CombatFeedbackController.onCombatEvent(feedback, payload)
	-- Impacto é reação a resultado do servidor, nunca a intenção local: só soa
	-- quando o acerto/guarda já foi decidido (docs/14 §5, PresentationImpact).
	local impactCue = CombatAudio.impactId(payload.abilityId, payload.outcome)
	if impactCue then
		CombatAudioPlayer.play(combatAudio, impactCue)
	end
	-- O contra do Pulso nasce somente deste evento autoritativo: primeiro inicia a
	-- pose/receita própria, depois confirma as camadas de contato.
	if payload.abilityId == "pulse_return" and payload.outcome == "counter" then
		PlayerCombatAnimator.play(playerCombatAnimator, "Ability3Counter")
		CharacterAnimationPlayer.play(characterAnimation, "Ability3Counter")
		if abilityVfx then
			AbilityVfxPlayer.play(abilityVfx, "Ability3Counter")
		end
	end
	-- Hit-stop, câmera e VFX de contato reagem ao desfecho, nunca à intenção local.
	PlayerCombatAnimator.confirmHit(playerCombatAnimator, payload.outcome)
	CombatCameraController.addImpact(combatCamera, payload.outcome, payload.abilityId)
	if abilityVfx then
		AbilityVfxPlayer.confirm(abilityVfx, payload.abilityId, payload.outcome)
	end
	-- Número de dano flutuante (dano > 0, desfecho confirmado).
	CombatHudController.onCombatEvent(combatHud, payload)
	-- Sincronização da cadeia leve com o degrau autoritativo (docs/14 §4.3):
	-- whiff zera a pose visual; acerto confirma o degrau do servidor.
	if type(payload.step) == "number" then
		PlayerCombatAnimator.syncStep(playerCombatAnimator, payload.step)
	end
end)

remote(Remotes.Names.AbilityRejected).OnClientEvent:Connect(function(payload: { [string]: any })
	AbilityController.onRejected(ability, payload)
	CombatFeedbackController.onRejected(feedback, payload)
end)

remote(Remotes.Names.EnemyEvent).OnClientEvent:Connect(function(payload: { [string]: any })
	ActorAnimator.onEnemyEvent(actorAnimator, payload)
	EnemyVfxPlayer.onEnemyEvent(enemyVfx, payload)
end)

-- UI é o último controller; os listeners de remotes já estão conectados antes
-- de WaitForChild(PlayerGui), reduzindo a janela de perda do snapshot.
local ui = UIController.new({
	player = player,
	state = state,
	stateApi = ClientState,
	locale = Locale,
	abilities = Abilities,
	abilityController = ability,
	abilityApi = AbilityController,
	characterController = character,
	characterApi = CharacterController,
	combatCamera = combatCamera,
	input = input,
	inputApi = InputController,
	runService = RunService,
})

local function mouseOnButton(): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local inset = GuiService:GetGuiInset()
	local location = UserInputService:GetMouseLocation()
	local hits = playerGui:GetGuiObjectsAtPosition(location.X - inset.X, location.Y - inset.Y)
	for _, obj in hits do
		if obj:IsA("GuiButton") and obj.Active and obj.Visible then
			local current: Instance? = obj
			local blocked = false
			while current and current ~= playerGui do
				if current:IsA("GuiObject") and current.Visible == false then
					blocked = true
					break
				end
				if current:IsA("LayerCollector") and current.Enabled == false then
					blocked = true
					break
				end
				current = current.Parent
			end
			if not blocked then
				return true
			end
		end
	end
	return false
end

InputController.start(input, UserInputService, { mouseOnButton = mouseOnButton })
ActorAnimator.start(actorAnimator)
PlayerCombatAnimator.start(playerCombatAnimator)
CharacterAnimationPlayer.start(characterAnimation)
AbilityVfxPlayer.start(abilityVfx)
EnemyVfxPlayer.start(enemyVfx)
-- O rastro do golpe e as camadas de VFX se apagam sozinhos quando a ação acaba.
RunService.RenderStepped:Connect(function()
	CharacterAnimationPlayer.step(characterAnimation)
end)
CombatCameraController.start(combatCamera)
InteractionController.start(interaction)

-- Mantém referência forte e torna explícito que UI é o último controller.
if not ui then
	error("UIController não inicializado")
end

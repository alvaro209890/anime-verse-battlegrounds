--!strict
-- Bootstrap de apresentação F0. Não há FireServer de boot: toda intenção passa
-- pelo InputController e somente depois de SessionSnapshot ready.

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
local RemoteEnvelope = require(Shared.RemoteEnvelope)
local Remotes = require(Shared.Remotes)

local Controllers = script:WaitForChild("Controllers")
local InputController = require(Controllers.InputController)
local CharacterController = require(Controllers.CharacterController)
local AbilityController = require(Controllers.AbilityController)
local CombatFeedbackController = require(Controllers.CombatFeedbackController)
local ResourceController = require(Controllers.ResourceController)
local ZoneController = require(Controllers.ZoneController)
local UIController = require(Controllers.UIController)
local ClientState = require(Controllers.ClientState)

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
})
local feedback = CombatFeedbackController.new(state, ClientState)
local resource = ResourceController.new(state, ClientState)
local zone = ZoneController.new(state, ClientState, input, InputController.subscribe, send, os.clock)
local characterStarted = false

remote(Remotes.Names.SessionSnapshot).OnClientEvent:Connect(function(payload: { [string]: any })
	if ClientState.applySnapshot(state, payload) and not characterStarted then
		characterStarted = true
		CharacterController.start(character)
	end
end)

remote(Remotes.Names.StateDelta).OnClientEvent:Connect(function(payload: { [string]: any })
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
end)

remote(Remotes.Names.AbilityRejected).OnClientEvent:Connect(function(payload: { [string]: any })
	AbilityController.onRejected(ability, payload)
	CombatFeedbackController.onRejected(feedback, payload)
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
	input = input,
	inputApi = InputController,
	runService = RunService,
})

InputController.start(input, UserInputService)

-- Mantém referência forte e torna explícito que UI é o último controller.
if not ui then
	error("UIController não inicializado")
end

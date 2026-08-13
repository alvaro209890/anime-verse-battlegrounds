--!strict
-- Resposta procedural local para intenções de combate do jogador. Esta camada
-- não decide acerto, alvo, dano, custo ou deslocamento autoritativo; ela apenas
-- aplica um overlay visual temporário sobre os Motor6D do personagem local.

export type CombatAction = "BasicLight" | "BasicHeavy" | "GuardDown" | "GuardUp" | "Dash"

export type PoseSample = {
	rootHeightStuds: number,
	rootPitchDegrees: number,
	rootYawDegrees: number,
	rootRollDegrees: number,
	waistPitchDegrees: number,
	waistYawDegrees: number,
	waistRollDegrees: number,
	neckPitchDegrees: number,
	neckYawDegrees: number,
	leftShoulderPitchDegrees: number,
	leftShoulderYawDegrees: number,
	leftShoulderRollDegrees: number,
	rightShoulderPitchDegrees: number,
	rightShoulderYawDegrees: number,
	rightShoulderRollDegrees: number,
	leftHipPitchDegrees: number,
	rightHipPitchDegrees: number,
}

type JointState = {
	motor: Motor6D,
	baseTransform: CFrame,
	lastApplied: CFrame?,
}

export type Animator = {
	player: any,
	runService: any,
	now: () -> number,
	action: CombatAction?,
	actionStartedAt: number,
	guarding: boolean,
	character: Model?,
	joints: { [string]: JointState },
	preSimulationConnection: any?,
	characterAddedConnection: any?,
}

local PlayerCombatAnimator = {}

local DURATIONS: { [string]: number } = {
	BasicLight = 0.28,
	BasicHeavy = 0.52,
	GuardDown = 0.16,
	GuardUp = 0.18,
	Dash = 0.32,
}

PlayerCombatAnimator.Durations = table.freeze({
	BasicLight = DURATIONS.BasicLight,
	BasicHeavy = DURATIONS.BasicHeavy,
	GuardDown = DURATIONS.GuardDown,
	GuardUp = DURATIONS.GuardUp,
	Dash = DURATIONS.Dash,
})

local function pose(values: { [string]: number }?): PoseSample
	local source = values or {}
	return {
		rootHeightStuds = source.rootHeightStuds or 0,
		rootPitchDegrees = source.rootPitchDegrees or 0,
		rootYawDegrees = source.rootYawDegrees or 0,
		rootRollDegrees = source.rootRollDegrees or 0,
		waistPitchDegrees = source.waistPitchDegrees or 0,
		waistYawDegrees = source.waistYawDegrees or 0,
		waistRollDegrees = source.waistRollDegrees or 0,
		neckPitchDegrees = source.neckPitchDegrees or 0,
		neckYawDegrees = source.neckYawDegrees or 0,
		leftShoulderPitchDegrees = source.leftShoulderPitchDegrees or 0,
		leftShoulderYawDegrees = source.leftShoulderYawDegrees or 0,
		leftShoulderRollDegrees = source.leftShoulderRollDegrees or 0,
		rightShoulderPitchDegrees = source.rightShoulderPitchDegrees or 0,
		rightShoulderYawDegrees = source.rightShoulderYawDegrees or 0,
		rightShoulderRollDegrees = source.rightShoulderRollDegrees or 0,
		leftHipPitchDegrees = source.leftHipPitchDegrees or 0,
		rightHipPitchDegrees = source.rightHipPitchDegrees or 0,
	}
end

local NEUTRAL = table.freeze(pose(nil))
local GUARD = table.freeze(pose({
	rootHeightStuds = -0.04,
	rootPitchDegrees = 4,
	rootYawDegrees = -4,
	waistPitchDegrees = -3,
	waistYawDegrees = 8,
	neckPitchDegrees = -2,
	neckYawDegrees = -4,
	leftShoulderPitchDegrees = -52,
	leftShoulderYawDegrees = -18,
	leftShoulderRollDegrees = -12,
	rightShoulderPitchDegrees = -48,
	rightShoulderYawDegrees = 20,
	rightShoulderRollDegrees = 14,
	leftHipPitchDegrees = -4,
	rightHipPitchDegrees = 4,
}))
local LIGHT_WINDUP = table.freeze(pose({
	rootPitchDegrees = -4,
	rootYawDegrees = -13,
	rootRollDegrees = -3,
	waistYawDegrees = -18,
	neckYawDegrees = 7,
	leftShoulderPitchDegrees = -24,
	leftShoulderYawDegrees = -10,
	rightShoulderPitchDegrees = 28,
	rightShoulderYawDegrees = 20,
	rightShoulderRollDegrees = 8,
}))
local LIGHT_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.03,
	rootPitchDegrees = 9,
	rootYawDegrees = 19,
	rootRollDegrees = 4,
	waistPitchDegrees = 5,
	waistYawDegrees = 25,
	neckYawDegrees = -9,
	leftShoulderPitchDegrees = -29,
	leftShoulderYawDegrees = -12,
	rightShoulderPitchDegrees = -76,
	rightShoulderYawDegrees = -12,
	rightShoulderRollDegrees = -9,
	leftHipPitchDegrees = 6,
	rightHipPitchDegrees = -6,
}))
local HEAVY_WINDUP = table.freeze(pose({
	rootHeightStuds = -0.08,
	rootPitchDegrees = -9,
	rootYawDegrees = -27,
	rootRollDegrees = -6,
	waistPitchDegrees = -6,
	waistYawDegrees = -32,
	waistRollDegrees = -5,
	neckPitchDegrees = 5,
	neckYawDegrees = 14,
	leftShoulderPitchDegrees = -18,
	leftShoulderYawDegrees = -14,
	rightShoulderPitchDegrees = 48,
	rightShoulderYawDegrees = 31,
	rightShoulderRollDegrees = 16,
	leftHipPitchDegrees = -8,
	rightHipPitchDegrees = 8,
}))
local HEAVY_STRIKE = table.freeze(pose({
	rootHeightStuds = -0.12,
	rootPitchDegrees = 16,
	rootYawDegrees = 31,
	rootRollDegrees = 8,
	waistPitchDegrees = 13,
	waistYawDegrees = 38,
	waistRollDegrees = 7,
	neckPitchDegrees = -7,
	neckYawDegrees = -16,
	leftShoulderPitchDegrees = 24,
	leftShoulderYawDegrees = -18,
	rightShoulderPitchDegrees = -112,
	rightShoulderYawDegrees = -18,
	rightShoulderRollDegrees = -15,
	leftHipPitchDegrees = 10,
	rightHipPitchDegrees = -10,
}))
local DASH = table.freeze(pose({
	rootHeightStuds = -0.12,
	rootPitchDegrees = 18,
	waistPitchDegrees = 11,
	neckPitchDegrees = -9,
	leftShoulderPitchDegrees = 31,
	leftShoulderYawDegrees = -7,
	leftShoulderRollDegrees = -8,
	rightShoulderPitchDegrees = 35,
	rightShoulderYawDegrees = 7,
	rightShoulderRollDegrees = 8,
	leftHipPitchDegrees = -12,
	rightHipPitchDegrees = -12,
}))

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function smooth(value: number): number
	local clamped = clamp01(value)
	return clamped * clamped * (3 - 2 * clamped)
end

local function blend(from: PoseSample, to: PoseSample, alpha: number): PoseSample
	local amount = clamp01(alpha)
	local function value(key: string): number
		return (from :: any)[key] + ((to :: any)[key] - (from :: any)[key]) * amount
	end
	return {
		rootHeightStuds = value("rootHeightStuds"),
		rootPitchDegrees = value("rootPitchDegrees"),
		rootYawDegrees = value("rootYawDegrees"),
		rootRollDegrees = value("rootRollDegrees"),
		waistPitchDegrees = value("waistPitchDegrees"),
		waistYawDegrees = value("waistYawDegrees"),
		waistRollDegrees = value("waistRollDegrees"),
		neckPitchDegrees = value("neckPitchDegrees"),
		neckYawDegrees = value("neckYawDegrees"),
		leftShoulderPitchDegrees = value("leftShoulderPitchDegrees"),
		leftShoulderYawDegrees = value("leftShoulderYawDegrees"),
		leftShoulderRollDegrees = value("leftShoulderRollDegrees"),
		rightShoulderPitchDegrees = value("rightShoulderPitchDegrees"),
		rightShoulderYawDegrees = value("rightShoulderYawDegrees"),
		rightShoulderRollDegrees = value("rightShoulderRollDegrees"),
		leftHipPitchDegrees = value("leftHipPitchDegrees"),
		rightHipPitchDegrees = value("rightHipPitchDegrees"),
	}
end

local function attackPose(
	elapsed: number,
	windupEnd: number,
	strikeEnd: number,
	duration: number,
	windup: PoseSample,
	strike: PoseSample
): PoseSample
	if elapsed <= windupEnd then
		return blend(NEUTRAL, windup, smooth(elapsed / windupEnd))
	elseif elapsed <= strikeEnd then
		return blend(windup, strike, smooth((elapsed - windupEnd) / (strikeEnd - windupEnd)))
	end
	return blend(strike, NEUTRAL, smooth((elapsed - strikeEnd) / (duration - strikeEnd)))
end

-- Função pura: a mesma intenção e tempo sempre produzem a mesma pose numérica.
-- Isso permite validar timing e amplitudes sem DataModel, personagem ou assets.
function PlayerCombatAnimator.sample(action: CombatAction?, elapsed: number, guarding: boolean): PoseSample
	local safeElapsed = math.max(0, elapsed)
	if action == "GuardDown" then
		return blend(NEUTRAL, GUARD, smooth(safeElapsed / DURATIONS.GuardDown))
	elseif action == "GuardUp" then
		return blend(GUARD, NEUTRAL, smooth(safeElapsed / DURATIONS.GuardUp))
	elseif action == "BasicLight" then
		return attackPose(safeElapsed, 0.065, 0.135, DURATIONS.BasicLight, LIGHT_WINDUP, LIGHT_STRIKE)
	elseif action == "BasicHeavy" then
		return attackPose(safeElapsed, 0.17, 0.285, DURATIONS.BasicHeavy, HEAVY_WINDUP, HEAVY_STRIKE)
	elseif action == "Dash" then
		if safeElapsed <= 0.075 then
			return blend(NEUTRAL, DASH, smooth(safeElapsed / 0.075))
		elseif safeElapsed <= 0.18 then
			return pose(DASH :: any)
		end
		return blend(DASH, NEUTRAL, smooth((safeElapsed - 0.18) / (DURATIONS.Dash - 0.18)))
	end
	return if guarding then pose(GUARD :: any) else pose(NEUTRAL :: any)
end

local JOINT_CANDIDATES: { [string]: { string } } = {
	root = { "root", "rootjoint" },
	waist = { "waist" },
	neck = { "neck" },
	leftShoulder = { "leftshoulder" },
	rightShoulder = { "rightshoulder" },
	leftHip = { "lefthip" },
	rightHip = { "righthip" },
}

local function normalizedName(name: string): string
	return string.lower(string.gsub(name, "[^%w]", ""))
end

local function restoreJoints(animator: Animator): ()
	for _, state in animator.joints do
		local motor = state.motor
		if motor.Parent and state.lastApplied and motor.Transform == state.lastApplied then
			motor.Transform = state.baseTransform
		end
	end
	table.clear(animator.joints)
end

local function attachCharacter(animator: Animator, character: Model?): ()
	if animator.character == character then
		return
	end
	restoreJoints(animator)
	animator.character = character
	if not character then
		return
	end

	local motorsByName: { [string]: Motor6D } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motorsByName[normalizedName(descendant.Name)] = descendant
		end
	end
	for role, candidates in JOINT_CANDIDATES do
		for _, candidate in candidates do
			local motor = motorsByName[candidate]
			if motor then
				animator.joints[role] = {
					motor = motor,
					baseTransform = motor.Transform,
					lastApplied = nil,
				}
				break
			end
		end
	end
end

local function overlay(pitchDegrees: number, yawDegrees: number, rollDegrees: number, heightStuds: number?): CFrame
	return CFrame.new(0, heightStuds or 0, 0)
		* CFrame.Angles(math.rad(pitchDegrees), math.rad(yawDegrees), math.rad(rollDegrees))
end

local function applyJoint(animator: Animator, role: string, value: CFrame): ()
	local state = animator.joints[role]
	if not state or not state.motor.Parent then
		return
	end
	local current = state.motor.Transform
	-- Sem Animator ativo, Transform ainda contém nosso resultado anterior. Nesse
	-- caso recuperamos a base salva antes de compor o novo overlay. Se o Animator
	-- escreveu uma pose nova em PreAnimation, ela vira a nova base naturalmente.
	if state.lastApplied and current == state.lastApplied then
		current = state.baseTransform
	end
	state.baseTransform = current
	local applied = current * value
	state.motor.Transform = applied
	state.lastApplied = applied
end

local function applySample(animator: Animator, sample: PoseSample): ()
	applyJoint(
		animator,
		"root",
		overlay(sample.rootPitchDegrees, sample.rootYawDegrees, sample.rootRollDegrees, sample.rootHeightStuds)
	)
	applyJoint(animator, "waist", overlay(sample.waistPitchDegrees, sample.waistYawDegrees, sample.waistRollDegrees))
	applyJoint(animator, "neck", overlay(sample.neckPitchDegrees, sample.neckYawDegrees, 0))
	applyJoint(
		animator,
		"leftShoulder",
		overlay(sample.leftShoulderPitchDegrees, sample.leftShoulderYawDegrees, sample.leftShoulderRollDegrees)
	)
	applyJoint(
		animator,
		"rightShoulder",
		overlay(sample.rightShoulderPitchDegrees, sample.rightShoulderYawDegrees, sample.rightShoulderRollDegrees)
	)
	applyJoint(animator, "leftHip", overlay(sample.leftHipPitchDegrees, 0, 0))
	applyJoint(animator, "rightHip", overlay(sample.rightHipPitchDegrees, 0, 0))
end

function PlayerCombatAnimator.new(deps: {
	player: any,
	runService: any,
	now: (() -> number)?,
}): Animator
	return {
		player = deps.player,
		runService = deps.runService,
		now = deps.now or os.clock,
		action = nil,
		actionStartedAt = 0,
		guarding = false,
		character = nil,
		joints = {},
		preSimulationConnection = nil,
		characterAddedConnection = nil,
	}
end

function PlayerCombatAnimator.play(animator: Animator, action: string): boolean
	if not DURATIONS[action] then
		return false
	end
	if action == "GuardDown" then
		animator.guarding = true
	elseif action == "GuardUp" then
		animator.guarding = false
	end
	animator.action = action :: CombatAction
	animator.actionStartedAt = animator.now()
	return true
end

function PlayerCombatAnimator.step(animator: Animator): ()
	local character = animator.player.Character
	if character ~= animator.character then
		attachCharacter(animator, character)
	end
	if not animator.character or not animator.character.Parent then
		return
	end

	local action = animator.action
	local elapsed = if action then math.max(0, animator.now() - animator.actionStartedAt) else 0
	if action and elapsed >= (DURATIONS[action] or 0) then
		action = nil
		animator.action = nil
	end
	applySample(animator, PlayerCombatAnimator.sample(action, elapsed, animator.guarding))
end

function PlayerCombatAnimator.start(animator: Animator): ()
	if animator.preSimulationConnection then
		return
	end
	animator.characterAddedConnection = animator.player.CharacterAdded:Connect(function(character: Model)
		attachCharacter(animator, character)
	end)
	attachCharacter(animator, animator.player.Character)
	animator.preSimulationConnection = animator.runService.PreSimulation:Connect(function()
		PlayerCombatAnimator.step(animator)
	end)
end

function PlayerCombatAnimator.stop(animator: Animator): ()
	if animator.preSimulationConnection then
		animator.preSimulationConnection:Disconnect()
		animator.preSimulationConnection = nil
	end
	if animator.characterAddedConnection then
		animator.characterAddedConnection:Disconnect()
		animator.characterAddedConnection = nil
	end
	restoreJoints(animator)
	animator.character = nil
	animator.action = nil
	animator.guarding = false
end

return PlayerCombatAnimator

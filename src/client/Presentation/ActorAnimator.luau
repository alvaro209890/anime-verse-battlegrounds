--!strict
-- Animação procedural de apresentação para os modelos greybox F0. Não abre
-- hitbox, não decide dano e não move o root autoritativo; só altera Motor6D
-- localmente a partir de EnemyEvent e atributos replicados do WorldService.

export type PoseSample = {
	bobStuds: number,
	leanDegrees: number,
	limbDegrees: number,
	spinDegrees: number,
}

export type Animator = {
	workspace: any,
	runService: any,
	recipes: any,
	now: () -> number,
	events: { [string]: { kind: string, startedAt: number } },
	jointCache: { [any]: { [string]: any } },
	connection: any?,
}

local ActorAnimator = {}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

function ActorAnimator.sample(recipe: any, kind: string, elapsed: number, now: number, moving: boolean): PoseSample
	local cycle = math.sin(now * math.pi * 2 * recipe.idleCyclesPerSecond)
	local bob = cycle * recipe.idleBobStuds
	local lean = 0
	local limbs = if moving then cycle * recipe.strideDegrees else cycle * recipe.strideDegrees * 0.12
	local spin = if recipe.shape == "shard" then now * 22 else 0

	if kind == "telegraph" then
		local anticipation = math.sin(clamp01(elapsed / 0.4) * math.pi / 2)
		lean = -recipe.telegraphLeanDegrees * anticipation
		limbs *= 0.2
	elseif kind == "attack" then
		local strike = math.sin(clamp01(elapsed / 0.24) * math.pi)
		lean = recipe.attackLeanDegrees * strike
		limbs = recipe.attackLeanDegrees * 0.65 * strike
	elseif kind == "died" then
		local fall = 1 - (1 - clamp01(elapsed / 0.55)) ^ 3
		lean = recipe.deathTiltDegrees * fall
		limbs = -12 * fall
		bob = -recipe.idleBobStuds * fall
	elseif kind == "spawn" or kind == "respawn" then
		local settle = 1 - clamp01(elapsed / 0.6)
		bob += settle * 0.6
		spin += settle * 80
	end

	return {
		bobStuds = bob,
		leanDegrees = lean,
		limbDegrees = limbs,
		spinDegrees = spin,
	}
end

function ActorAnimator.new(deps: {
	workspace: any,
	runService: any,
	recipes: any,
	now: (() -> number)?,
}): Animator
	return {
		workspace = deps.workspace,
		runService = deps.runService,
		recipes = deps.recipes,
		now = deps.now or os.clock,
		events = {},
		jointCache = {},
		connection = nil,
	}
end

function ActorAnimator.onEnemyEvent(animator: Animator, payload: { [string]: any }): ()
	local fighterId = payload.fighterId
	local kind = payload.kind
	if type(fighterId) ~= "string" or type(kind) ~= "string" then
		return
	end
	animator.events[fighterId] = {
		kind = kind,
		startedAt = animator.now(),
	}
end

local function setTransform(animator: Animator, model: Model, jointName: string, value: CFrame): ()
	local cache = animator.jointCache[model]
	if not cache then
		cache = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Motor6D") then
				cache[descendant.Name] = descendant
			end
		end
		animator.jointCache[model] = cache
	end
	local joint = cache[jointName]
	if joint and joint:IsA("Motor6D") then
		joint.Transform = value
	end
end

local function applyPose(animator: Animator, model: Model, recipe: any, sample: PoseSample): ()
	local lean = math.rad(sample.leanDegrees)
	local limb = math.rad(sample.limbDegrees)
	setTransform(animator, model, "Joint_Torso", CFrame.new(0, sample.bobStuds, 0) * CFrame.Angles(lean, 0, 0))
	if recipe.shape == "humanoid" then
		setTransform(animator, model, "Joint_LeftArm", CFrame.Angles(limb, 0, 0))
		setTransform(animator, model, "Joint_RightArm", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "Joint_LeftLeg", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "Joint_RightLeg", CFrame.Angles(limb, 0, 0))
	else
		local spin = math.rad(sample.spinDegrees)
		setTransform(animator, model, "Joint_Core", CFrame.Angles(lean, spin, 0))
		setTransform(animator, model, "Joint_ShardLeft", CFrame.Angles(0, 0, limb * 0.35))
		setTransform(animator, model, "Joint_ShardRight", CFrame.Angles(0, 0, -limb * 0.35))
	end
end

local function presentationKind(animator: Animator, model: Model, actorId: string): (string, number)
	local event = animator.events[actorId]
	if event then
		local elapsed = animator.now() - event.startedAt
		local durationByKind = {
			spawn = 0.6,
			respawn = 0.6,
			telegraph = 1,
			attack = 0.35,
		}
		local duration = durationByKind[event.kind]
		if not duration or elapsed <= duration then
			return event.kind, elapsed
		end
		animator.events[actorId] = nil
	end
	local replicatedKind = model:GetAttribute("PoseKind")
	-- O atributo cobre late join somente para estado persistente. Eventos
	-- transitórios chegam pelo remote; reaplicá-los para sempre congelaria a
	-- locomoção depois de um ataque já encerrado.
	return if replicatedKind == "died" then "died" else "idle", 1
end

function ActorAnimator.step(animator: Animator): ()
	local world = animator.workspace:FindFirstChild("GreyboxF0")
	local actors = if world then world:FindFirstChild("Actors") else nil
	if not actors then
		return
	end
	local now = animator.now()
	for _, child in actors:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PresentationActor") == true then
			local npcId = child:GetAttribute("NpcId")
			local actorId = child:GetAttribute("ActorId")
			if type(npcId) == "string" and type(actorId) == "string" then
				local recipe = animator.recipes.getActor(npcId)
				if recipe then
					local kind, elapsed = presentationKind(animator, child, actorId)
					local moving = child:GetAttribute("Moving") == true
					applyPose(animator, child, recipe, ActorAnimator.sample(recipe, kind, elapsed, now, moving))
				end
			end
		end
	end
end

function ActorAnimator.start(animator: Animator): ()
	if animator.connection then
		return
	end
	animator.connection = animator.runService.RenderStepped:Connect(function()
		ActorAnimator.step(animator)
	end)
end

function ActorAnimator.stop(animator: Animator): ()
	if animator.connection then
		animator.connection:Disconnect()
		animator.connection = nil
	end
	table.clear(animator.events)
	table.clear(animator.jointCache)
end

return ActorAnimator

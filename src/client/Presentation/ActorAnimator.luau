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
	events: { [string]: { kind: string, startedAt: number, durationSeconds: number?, visualPattern: string? } },
	seenPoseSerial: { [any]: number },
	jointCache: { [any]: { [string]: any } },
	connection: any?,
}

local ActorAnimator = {}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

function ActorAnimator.sample(
	recipe: any,
	kind: string,
	elapsed: number,
	now: number,
	moving: boolean,
	visualPattern: string?,
	durationSeconds: number?
): PoseSample
	local cycle = math.sin(now * math.pi * 2 * recipe.idleCyclesPerSecond)
	local bob = cycle * recipe.idleBobStuds
	local lean = 0
	local limbs = if moving then cycle * recipe.strideDegrees else cycle * recipe.strideDegrees * 0.12
	local spin = if recipe.shape == "shard" then now * 22 else 0

	if kind == "telegraph" then
		local duration = math.max(0.1, durationSeconds or 0.4)
		local anticipation = math.sin(clamp01(elapsed / duration) * math.pi / 2)
		local patternWeight = 1
		if visualPattern == "slam" then
			patternWeight = 1.3
		elseif visualPattern == "shock" then
			patternWeight = 1.15
		elseif visualPattern == "combo" then
			patternWeight = 0.72
		elseif visualPattern == "pounce" or visualPattern == "rift" or visualPattern == "hook" then
			patternWeight = 1.2
		elseif visualPattern == "pierce" or visualPattern == "cleave" then
			patternWeight = 1.1
		end
		lean = -recipe.telegraphLeanDegrees * patternWeight * anticipation
		limbs = if visualPattern == "combo"
			then recipe.strideDegrees * 0.45 * math.sin(clamp01(elapsed / duration) * math.pi * 2)
			else limbs * 0.2
		if visualPattern == "slam" or visualPattern == "shock" then
			bob -= recipe.idleBobStuds * 0.65 * anticipation
		end
	elseif kind == "attack" then
		local duration = math.max(0.1, durationSeconds or 0.35)
		local progress = clamp01(elapsed / duration)
		local strike = if visualPattern == "combo"
			then math.abs(math.sin(progress * math.pi * 2))
			else math.sin(progress * math.pi)
		local patternWeight = 1
		if visualPattern == "slam" then
			patternWeight = 1.25
		elseif visualPattern == "shock" then
			patternWeight = 1.12
		elseif visualPattern == "combo" then
			patternWeight = 0.78
		elseif visualPattern == "pounce" or visualPattern == "rift" or visualPattern == "hook" then
			patternWeight = 1.35
		elseif visualPattern == "pierce" or visualPattern == "cleave" then
			patternWeight = 1.18
		end
		lean = recipe.attackLeanDegrees * patternWeight * strike
		limbs = recipe.attackLeanDegrees * 0.65 * patternWeight * strike
		if visualPattern == "slam" then
			bob -= recipe.idleBobStuds * 1.1 * strike
		elseif visualPattern == "shock" then
			bob -= recipe.idleBobStuds * 0.7 * strike
			spin += 40 * strike
		elseif visualPattern == "pounce" or visualPattern == "rift" or visualPattern == "hook" then
			bob += recipe.idleBobStuds * 1.4 * strike
		elseif visualPattern == "pierce" or visualPattern == "cleave" then
			bob += recipe.idleBobStuds * 0.5 * strike
			lean += recipe.attackLeanDegrees * 0.25 * strike
		end
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
		seenPoseSerial = {},
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
		durationSeconds = if type(payload.durationSeconds) == "number" then payload.durationSeconds else nil,
		visualPattern = if type(payload.visualPattern) == "string" then payload.visualPattern else nil,
	}
end

-- Classes de junta que aceitam overlay. Os atores em Parts usam Motor6D; o rig
-- R15 dos bots do spawn (WorldService) usa AnimationConstraint, que expõe o
-- mesmo `Transform`. Procurar só Motor6D deixaria o rig novo sem pose alguma —
-- foi exatamente o que aconteceu com o overlay do jogador (PlayerCombatAnimator).
local POSE_JOINT_CLASSES: { [string]: boolean } = {
	Motor6D = true,
	AnimationConstraint = true,
}

function ActorAnimator.isPoseJointClass(className: string): boolean
	return POSE_JOINT_CLASSES[className] == true
end

local function setTransform(animator: Animator, model: Model, jointName: string, value: CFrame): ()
	local cache = animator.jointCache[model]
	if not cache then
		cache = {}
		local achouJunta = false
		for _, descendant in model:GetDescendants() do
			if ActorAnimator.isPoseJointClass(descendant.ClassName) then
				cache[descendant.Name] = descendant
				achouJunta = true
			end
		end
		-- Rig ainda em montagem devolve zero junta. Guardar esse vazio congelaria
		-- o ator sem pose para sempre — o mesmo defeito que matou o overlay do
		-- jogador. Sem guardar, a próxima chamada procura de novo.
		if achouJunta then
			animator.jointCache[model] = cache
		end
	end
	local joint = cache[jointName]
	if joint then
		joint.Transform = value
	end
end

local function applyPose(animator: Animator, model: Model, recipe: any, sample: PoseSample): ()
	local lean = math.rad(sample.leanDegrees)
	local limb = math.rad(sample.limbDegrees)
	if recipe.shape == "humanoid" then
		-- Dois conjuntos de nomes de propósito: `Joint_*` é o ator greybox em
		-- Parts (fallback), `Root`/`Waist`/`LeftShoulder`… é o rig R15 de verdade
		-- dos bots do spawn. Nome ausente é ignorado pelo setTransform, então o
		-- mesmo caminho serve aos dois sem ramo por tipo de corpo.
		setTransform(animator, model, "Joint_Torso", CFrame.new(0, sample.bobStuds, 0) * CFrame.Angles(lean, 0, 0))
		setTransform(animator, model, "Joint_LeftArm", CFrame.Angles(limb, 0, 0))
		setTransform(animator, model, "Joint_RightArm", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "Joint_LeftLeg", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "Joint_RightLeg", CFrame.Angles(limb, 0, 0))

		-- No R15 a respiração vai no Root (o quadril sobe/desce) e a inclinação
		-- na cintura: girar o Root inteiro faria o boneco pivotar nos pés.
		setTransform(animator, model, "Root", CFrame.new(0, sample.bobStuds, 0))
		setTransform(animator, model, "Waist", CFrame.Angles(lean, 0, 0))
		setTransform(animator, model, "Neck", CFrame.Angles(-lean * 0.35, 0, 0))
		setTransform(animator, model, "LeftShoulder", CFrame.Angles(limb, 0, 0))
		setTransform(animator, model, "RightShoulder", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "LeftHip", CFrame.Angles(-limb, 0, 0))
		setTransform(animator, model, "RightHip", CFrame.Angles(limb, 0, 0))
	else
		local spin = math.rad(sample.spinDegrees)
		-- O shard inteiro se move por um pivot visual comum. Assim bob, lean e
		-- spin nunca separam o torso do núcleo ou das cunhas.
		setTransform(
			animator,
			model,
			"Joint_VisualRoot",
			CFrame.new(0, sample.bobStuds, 0) * CFrame.Angles(lean, spin, 0)
		)
		setTransform(animator, model, "Joint_ShardLeft", CFrame.Angles(0, 0, limb * 0.35))
		setTransform(animator, model, "Joint_ShardRight", CFrame.Angles(0, 0, -limb * 0.35))
	end
end

local function presentationKind(animator: Animator, model: Model, actorId: string): (string, number, string?, number?)
	local event = animator.events[actorId]
	if event then
		local replicatedSerial = model:GetAttribute("PoseSerial")
		if type(replicatedSerial) == "number" then
			animator.seenPoseSerial[model] = replicatedSerial
		end
		local elapsed = animator.now() - event.startedAt
		local durationByKind = {
			spawn = 0.6,
			respawn = 0.6,
			telegraph = 1,
			attack = 0.35,
		}
		local duration = event.durationSeconds or durationByKind[event.kind]
		if not duration or elapsed <= duration then
			return event.kind, elapsed, event.visualPattern, duration
		end
		animator.events[actorId] = nil
	end
	local replicatedKind = model:GetAttribute("PoseKind")
	local replicatedSerial = model:GetAttribute("PoseSerial")
	if type(replicatedSerial) == "number" and animator.seenPoseSerial[model] ~= replicatedSerial then
		animator.seenPoseSerial[model] = replicatedSerial
		local startedAt = model:GetAttribute("PoseStartedAt")
		local duration = model:GetAttribute("PoseDuration")
		local elapsed = if type(startedAt) == "number"
			then math.max(0, animator.workspace:GetServerTimeNow() - startedAt)
			else 0
		if type(replicatedKind) == "string" and (type(duration) ~= "number" or elapsed <= duration) then
			if replicatedKind == "spawn" or replicatedKind == "respawn" then
				model:SetAttribute("SpawnPresentation", false)
			end
			local visualPattern = model:GetAttribute("VisualPattern")
			return replicatedKind, elapsed, if type(visualPattern) == "string" then visualPattern else nil, duration
		end
	end
	-- Um modelo recém-replicado preserva a apresentação de spawn mesmo se o
	-- RemoteEvent ocorreu antes deste cliente existir.
	if model:GetAttribute("SpawnPresentation") == true then
		model:SetAttribute("SpawnPresentation", false)
		return "spawn", 0, "arrival", 0.6
	end
	return if replicatedKind == "died" then "died" else "idle", 1, nil, nil
end

function ActorAnimator.step(animator: Animator): ()
	local world = animator.workspace:FindFirstChild("GreyboxF0")
	local actors = if world then world:FindFirstChild("Actors") else nil
	if not actors then
		return
	end
	-- Limpeza de cache (alerta 14/08): jointCache e seenPoseSerial são
	-- chaveados por Model e vazavam quando o NPC morria/respawnava (45 s/180 s)
	-- — a árvore destruída ficava presa por referência forte e a memória
	-- crescia em sessão longa. Remove entradas de modelos que não estão mais
	-- vivos no folder de atores (mesmo padrão do modelCache do HUD).
	for model in animator.jointCache do
		if not model.Parent or model.Parent ~= actors then
			animator.jointCache[model] = nil
		end
	end
	for model in animator.seenPoseSerial do
		if not model.Parent or model.Parent ~= actors then
			animator.seenPoseSerial[model] = nil
		end
	end
	local now = animator.now()
	for _, child in actors:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PresentationActor") == true then
			local npcId = child:GetAttribute("NpcId")
			local actorId = child:GetAttribute("ActorId")
			if type(npcId) == "string" and type(actorId) == "string" then
				local recipe = animator.recipes.getActor(npcId)
				if recipe then
					local kind, elapsed, visualPattern, durationSeconds = presentationKind(animator, child, actorId)
					local moving = child:GetAttribute("Moving") == true
					applyPose(
						animator,
						child,
						recipe,
						ActorAnimator.sample(recipe, kind, elapsed, now, moving, visualPattern, durationSeconds)
					)
				end
			end
		end
	end
end

function ActorAnimator.start(animator: Animator): ()
	if animator.connection then
		return
	end
	animator.connection = animator.runService.PreSimulation:Connect(function()
		ActorAnimator.step(animator)
	end)
end

function ActorAnimator.stop(animator: Animator): ()
	if animator.connection then
		animator.connection:Disconnect()
		animator.connection = nil
	end
	table.clear(animator.events)
	table.clear(animator.seenPoseSerial)
	table.clear(animator.jointCache)
end

return ActorAnimator

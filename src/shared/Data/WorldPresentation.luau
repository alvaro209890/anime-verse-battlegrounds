--!strict
-- Receitas puras da apresentação F0. O módulo não cria Instances: mantém
-- proporções, paleta e amplitudes procedurais testáveis fora do Studio.
-- Os modelos continuam sendo greybox original em Parts até o Gate P1.

export type Rgb = { number }

export type ActorRecipe = {
	id: string,
	shape: "humanoid" | "shard",
	scale: number,
	bodyRgb: Rgb,
	accentRgb: Rgb,
	coreRgb: Rgb,
	idleBobStuds: number,
	idleCyclesPerSecond: number,
	strideDegrees: number,
	telegraphLeanDegrees: number,
	attackLeanDegrees: number,
	deathTiltDegrees: number,
}

export type WorldStyle = {
	pathWidth: number,
	spawnPlazaRadius: number,
	craterSegments: number,
	boundaryPostCount: number,
	landmarkShardCount: number,
}

local Actors: { [string]: ActorRecipe } = {
	npc_training_dummy = {
		id = "npc_training_dummy",
		shape = "humanoid",
		scale = 1,
		bodyRgb = { 134, 124, 111 },
		accentRgb = { 91, 83, 75 },
		coreRgb = { 226, 214, 183 },
		idleBobStuds = 0.03,
		idleCyclesPerSecond = 0.55,
		strideDegrees = 0,
		telegraphLeanDegrees = 4,
		attackLeanDegrees = 8,
		deathTiltDegrees = 20,
	},
	npc_threshold_instructor = {
		id = "npc_threshold_instructor",
		shape = "humanoid",
		scale = 1.05,
		bodyRgb = { 93, 101, 108 },
		accentRgb = { 184, 174, 151 },
		coreRgb = { 218, 224, 220 },
		idleBobStuds = 0.04,
		idleCyclesPerSecond = 0.35,
		strideDegrees = 7,
		telegraphLeanDegrees = 5,
		attackLeanDegrees = 10,
		deathTiltDegrees = 35,
	},
	enemy_wandering_shard = {
		id = "enemy_wandering_shard",
		shape = "shard",
		scale = 0.9,
		bodyRgb = { 77, 82, 88 },
		accentRgb = { 172, 176, 166 },
		coreRgb = { 238, 238, 222 },
		idleBobStuds = 0.32,
		idleCyclesPerSecond = 0.8,
		strideDegrees = 18,
		telegraphLeanDegrees = 16,
		attackLeanDegrees = 34,
		deathTiltDegrees = 78,
	},
	enemy_anchored_shard = {
		id = "enemy_anchored_shard",
		shape = "shard",
		scale = 1.65,
		bodyRgb = { 60, 64, 70 },
		accentRgb = { 191, 184, 166 },
		coreRgb = { 244, 241, 218 },
		idleBobStuds = 0.18,
		idleCyclesPerSecond = 0.45,
		strideDegrees = 8,
		telegraphLeanDegrees = 22,
		attackLeanDegrees = 42,
		deathTiltDegrees = 82,
	},
}

local STYLE: WorldStyle = {
	pathWidth = 8,
	spawnPlazaRadius = 10,
	craterSegments = 16,
	boundaryPostCount = 6,
	landmarkShardCount = 7,
}

local Presentation = {}

function Presentation.getActor(npcId: string): ActorRecipe?
	return Actors[npcId]
end

function Presentation.allActors(): { ActorRecipe }
	local ids: { string } = {}
	for npcId in Actors do
		table.insert(ids, npcId)
	end
	table.sort(ids)
	local out: { ActorRecipe } = {}
	for _, npcId in ids do
		table.insert(out, Actors[npcId])
	end
	return out
end

function Presentation.style(): WorldStyle
	return STYLE
end

local function validRgb(rgb: Rgb): boolean
	if #rgb ~= 3 then
		return false
	end
	for _, component in rgb do
		if component % 1 ~= 0 or component < 0 or component > 255 then
			return false
		end
	end
	return true
end

function Presentation.validate(): (boolean, string?)
	local expected = {
		"npc_training_dummy",
		"npc_threshold_instructor",
		"enemy_wandering_shard",
		"enemy_anchored_shard",
	}
	for _, npcId in expected do
		if not Actors[npcId] then
			return false, "missing_actor:" .. npcId
		end
	end
	for npcId, recipe in Actors do
		if recipe.id ~= npcId then
			return false, "actor_id_mismatch:" .. npcId
		end
		if recipe.scale <= 0 or recipe.idleBobStuds < 0 or recipe.idleCyclesPerSecond <= 0 then
			return false, "invalid_motion:" .. npcId
		end
		if
			recipe.strideDegrees < 0
			or recipe.telegraphLeanDegrees < 0
			or recipe.attackLeanDegrees < recipe.telegraphLeanDegrees
			or recipe.deathTiltDegrees <= 0
			or recipe.deathTiltDegrees > 90
		then
			return false, "invalid_pose_range:" .. npcId
		end
		if not validRgb(recipe.bodyRgb) or not validRgb(recipe.accentRgb) or not validRgb(recipe.coreRgb) then
			return false, "invalid_rgb:" .. npcId
		end
	end
	if
		STYLE.pathWidth < 6
		or STYLE.spawnPlazaRadius < 8
		or STYLE.craterSegments < 12
		or STYLE.boundaryPostCount < 4
		or STYLE.landmarkShardCount < 5
	then
		return false, "invalid_world_style"
	end
	return true, nil
end

return Presentation

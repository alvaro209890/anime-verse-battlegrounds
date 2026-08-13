--!strict
-- Catálogo fechado das interações F0. O cliente usa estes dados apenas para
-- apresentar o ProximityPrompt; alvo, distância e efeito são revalidados no
-- servidor antes de qualquer mudança de estado.

export type InteractionKind = "npc" | "anchor"

export type InteractionDefinition = {
	id: string,
	kind: InteractionKind,
	targetId: string,
	anchorId: string,
	actionTextKey: string,
	objectTextKey: string,
	holdDuration: number,
	maxDistance: number,
	requiresLineOfSight: boolean,
}

local DEFINITIONS: { [string]: InteractionDefinition } = {
	interaction_threshold_instructor = {
		id = "interaction_threshold_instructor",
		kind = "npc",
		targetId = "npc_threshold_instructor",
		anchorId = "anchor_instructor",
		actionTextKey = "interaction.talk.action",
		objectTextKey = "npc.threshold_instructor.name",
		holdDuration = 0,
		maxDistance = 10,
		-- A raiz visual do Instrutor fica dentro do torso low-poly; LOS faria o
		-- próprio modelo ocultar o prompt. A distância continua autoritativa.
		requiresLineOfSight = false,
	},
	interaction_bastion_return = {
		id = "interaction_bastion_return",
		kind = "anchor",
		targetId = "anchor_bastion_return",
		anchorId = "anchor_bastion_return",
		actionTextKey = "interaction.consolidate.action",
		objectTextKey = "interaction.return_marker.name",
		holdDuration = 1.5,
		maxDistance = 10,
		requiresLineOfSight = false,
	},
}

local BY_NPC: { [string]: InteractionDefinition } = {}
local BY_ANCHOR: { [string]: InteractionDefinition } = {}
for _, definition in DEFINITIONS do
	if definition.kind == "npc" then
		BY_NPC[definition.targetId] = definition
	else
		BY_ANCHOR[definition.targetId] = definition
	end
end

local Interactions = {}

function Interactions.get(id: string): InteractionDefinition?
	return DEFINITIONS[id]
end

function Interactions.getByNpc(npcId: string): InteractionDefinition?
	return BY_NPC[npcId]
end

function Interactions.getByAnchor(anchorId: string): InteractionDefinition?
	return BY_ANCHOR[anchorId]
end

function Interactions.all(): { InteractionDefinition }
	local ids: { string } = {}
	for id in DEFINITIONS do
		table.insert(ids, id)
	end
	table.sort(ids)
	local out: { InteractionDefinition } = {}
	for _, id in ids do
		table.insert(out, DEFINITIONS[id])
	end
	return out
end

-- Resolve exatamente um alvo. Um payload com os dois campos é ambíguo e nunca
-- deve chegar ao domínio, mesmo que a camada de segurança também o bloqueie.
function Interactions.resolve(npcId: any, anchorId: any): (InteractionDefinition?, string?)
	local hasNpc = type(npcId) == "string"
	local hasAnchor = type(anchorId) == "string"
	if hasNpc == hasAnchor then
		return nil, "ambiguous_target"
	end
	local definition = if hasNpc then BY_NPC[npcId :: string] else BY_ANCHOR[anchorId :: string]
	if not definition then
		return nil, "unknown_target"
	end
	return definition, nil
end

function Interactions.validate(): (boolean, string?)
	local seenTargets: { [string]: boolean } = {}
	for id, definition in DEFINITIONS do
		if definition.id ~= id then
			return false, "id_mismatch:" .. id
		end
		if definition.kind ~= "npc" and definition.kind ~= "anchor" then
			return false, "invalid_kind:" .. id
		end
		local targetKey = definition.kind .. ":" .. definition.targetId
		if seenTargets[targetKey] then
			return false, "duplicate_target:" .. targetKey
		end
		seenTargets[targetKey] = true
		if definition.anchorId == "" or definition.actionTextKey == "" or definition.objectTextKey == "" then
			return false, "missing_reference:" .. id
		end
		if definition.holdDuration < 0 or definition.maxDistance <= 0 then
			return false, "invalid_prompt:" .. id
		end
	end
	return true, nil
end

return Interactions

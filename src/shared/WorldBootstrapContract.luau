-- Contrato puro do bootstrap visual F0.
--
-- O WorldService usa este módulo para validar a árvore recém-construída. Os
-- testes Lune podem fornecer snapshots simples e simular duas reconstruções sem
-- depender de Instances, Workspace ou Roblox Studio.

export type ActorSummary = {
	name: string,
	npcId: string,
	interactionBindingCount: number,
}

export type WorldSummary = {
	rootCount: number,
	actorFolderCount: number,
	spawnLightingCount: number,
	staticActors: { ActorSummary },
}

local EXPECTED_STATIC_ACTORS = {
	{ name = "TrainingDummy", npcId = "npc_training_dummy", interactionBindingCount = 0 },
	{ name = "ThresholdInstructor", npcId = "npc_threshold_instructor", interactionBindingCount = 1 },
}

local WorldBootstrapContract = {}

function WorldBootstrapContract.expectedStaticActors(): { ActorSummary }
	local result: { ActorSummary } = {}
	for _, actor in EXPECTED_STATIC_ACTORS do
		table.insert(result, {
			name = actor.name,
			npcId = actor.npcId,
			interactionBindingCount = actor.interactionBindingCount,
		})
	end
	return result
end

local function findExpected(name: string): ActorSummary?
	for _, actor in EXPECTED_STATIC_ACTORS do
		if actor.name == name then
			return actor
		end
	end
	return nil
end

function WorldBootstrapContract.validate(summary: WorldSummary?): (boolean, string?)
	if not summary then
		return false, "snapshot ausente"
	end
	if summary.rootCount ~= 1 then
		return false, ("raízes GreyboxF0 esperadas: 1, obtidas: %d"):format(summary.rootCount)
	end
	if summary.actorFolderCount ~= 1 then
		return false, ("pastas Actors esperadas: 1, obtidas: %d"):format(summary.actorFolderCount)
	end
	if summary.spawnLightingCount ~= 1 then
		return false, ("pastas F0SpawnLighting esperadas: 1, obtidas: %d"):format(summary.spawnLightingCount)
	end
	if #summary.staticActors ~= #EXPECTED_STATIC_ACTORS then
		return false,
			("atores estáticos esperados: %d, obtidos: %d"):format(#EXPECTED_STATIC_ACTORS, #summary.staticActors)
	end

	local seen: { [string]: boolean } = {}
	for _, actor in summary.staticActors do
		if seen[actor.name] then
			return false, "ator estático duplicado: " .. actor.name
		end
		seen[actor.name] = true
		local expected = findExpected(actor.name)
		if not expected then
			return false, "ator estático inesperado: " .. actor.name
		end
		if actor.npcId ~= expected.npcId then
			return false, "npcId divergente: " .. actor.name
		end
		if actor.interactionBindingCount ~= expected.interactionBindingCount then
			return false, "vínculo de interação divergente: " .. actor.name
		end
	end

	for _, expected in EXPECTED_STATIC_ACTORS do
		if not seen[expected.name] then
			return false, "ator estático ausente: " .. expected.name
		end
	end
	return true, nil
end

return WorldBootstrapContract

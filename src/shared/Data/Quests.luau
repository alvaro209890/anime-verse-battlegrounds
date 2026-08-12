--!strict
-- Objetivos da fatia F0 (docs/13-F0-SLICE.md §10, §11.1)
-- Dirigido por dados: o QuestService não faz `if` por objetivo. Itens 9 e 10
-- do backlog (elite e Fluxo) entram como LINHAS aqui, não como código novo.
--
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.

export type QuestObjectiveKind = "kill"

export type QuestDefinition = {
	id: string,
	trackerKey: string,
	kind: QuestObjectiveKind,
	-- Alvo contado pelo objetivo (id de NPC do catálogo).
	targetId: string,
	requiredCount: number,
	-- NPC que oferece o objetivo (InteractionIntent).
	giverNpcId: string,
	-- Tracker aparece sozinho se o jogador ignorar o NPC (§10).
	autoAcceptAfterSeconds: number,
	xpReward: number,
	-- Flag concedida ao completar; nil = objetivo sem unlock.
	unlockFlag: string?,
	-- Flag marcada no aceite (telemetria/FtueBeat).
	acceptFlag: string,
	enabled: boolean,
}

local Quests: { [string]: QuestDefinition } = {
	-- Objetivo 1 — 3–5 min do roteiro; unlock do Ombro Cometa no 3º kill.
	quest_hunt = {
		id = "quest_hunt",
		trackerKey = "quest.hunt.tracker",
		kind = "kill",
		targetId = "enemy_wandering_shard",
		requiredCount = 3,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 90,
		xpReward = 40,
		unlockFlag = "unlock_comet_shoulder",
		acceptFlag = "quest_hunt_accepted",
		enabled = true,
	},
}

-- Ordem de oferta na fatia. Itens 9/10 acrescentam `quest_elite` e `quest_flow`.
local CHAIN: { string } = { "quest_hunt" }

local QuestCatalog = {}

function QuestCatalog.get(questId: string): QuestDefinition?
	return Quests[questId]
end

function QuestCatalog.all(): { QuestDefinition }
	local out: { QuestDefinition } = {}
	for _, def in Quests do
		table.insert(out, def)
	end
	return out
end

-- Cadeia ordenada (só objetivos habilitados).
function QuestCatalog.chain(): { string }
	local out: { string } = {}
	for _, questId in CHAIN do
		local def = Quests[questId]
		if def and def.enabled then
			table.insert(out, questId)
		end
	end
	return out
end

return QuestCatalog

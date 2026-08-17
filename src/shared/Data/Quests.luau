--!strict
-- Objetivos da fatia F0 (docs/13-F0-SLICE.md §10, §11.1)
-- Dirigido por dados: o QuestService não faz `if` por objetivo. Itens 9 e 10
-- do backlog (elite e Fluxo) entram como LINHAS aqui, não como código novo.
--
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.

export type QuestObjectiveKind = "kill" | "flow_echo"

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

	-- Objetivo 2 — elite da cratera (15–20 min do roteiro); unlock da
	-- Cadência Quebrada ao derrotar (docs/13 §9.3, §10). Aceite forçado só
	-- após 15 min (o roteiro não pula direto para o elite).
	quest_elite = {
		id = "quest_elite",
		trackerKey = "quest.elite.tracker",
		kind = "kill",
		targetId = "enemy_anchored_shard",
		requiredCount = 1,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 900,
		xpReward = 60,
		unlockFlag = "unlock_broken_cadence",
		acceptFlag = "quest_elite_accepted",
		enabled = true,
	},

	-- Objetivo 3 — timing (45–60 min do roteiro): acertar um eco da Cadência
	-- Quebrada (docs/13 §6.2, §10); unlock do Retorno de Pulso.
	-- kind "flow_echo": o alvo é a HABILIDADE que gera o eco, não um NPC.
	quest_flow = {
		id = "quest_flow",
		trackerKey = "quest.flow.tracker",
		kind = "flow_echo",
		targetId = "broken_cadence",
		requiredCount = 1,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 2700,
		xpReward = 40,
		unlockFlag = "unlock_pulse_return",
		acceptFlag = "quest_flow_accepted",
		enabled = true,
	},

	-- Depois da cadeia F0: caça maior no campo, destrava o Tecelão de Ecos.
	quest_grove = {
		id = "quest_grove",
		trackerKey = "quest.grove.tracker",
		kind = "kill",
		targetId = "enemy_wandering_shard",
		requiredCount = 6,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 2800,
		xpReward = 50,
		unlockFlag = "unlock_echo_weaver",
		acceptFlag = "quest_grove_accepted",
		enabled = true,
	},

	-- Retorno à cratera: outro crédito no elite (cooldown de XP do NPC segue).
	quest_remnant = {
		id = "quest_remnant",
		trackerKey = "quest.remnant.tracker",
		kind = "kill",
		targetId = "enemy_anchored_shard",
		requiredCount = 1,
		giverNpcId = "npc_threshold_instructor",
		autoAcceptAfterSeconds = 3200,
		xpReward = 80,
		unlockFlag = nil,
		acceptFlag = "quest_remnant_accepted",
		enabled = true,
	},
}

-- Ordem: cadeia F0 e depois as missões extras.
local CHAIN: { string } = { "quest_hunt", "quest_elite", "quest_flow", "quest_grove", "quest_remnant" }

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

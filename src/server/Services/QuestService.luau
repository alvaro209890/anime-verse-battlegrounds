--!strict
-- QuestService (server) — F0 (docs/13-F0-SLICE.md §10)
-- Cadeia de objetivos dirigida por dados: oferta → aceite → progresso → prêmio.
-- Não existe `if` por objetivo; itens 9 e 10 do backlog entram como linhas em
-- `src/shared/Data/Quests.luau`.
--
-- Autoridade total no servidor: o cliente manda `InteractionIntent` (aceitar) e
-- recebe tracker; nunca informa progresso nem recompensa.
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type QuestDeps = {
	getQuest: (string) -> any?,
	chain: () -> { string },
	-- Recompensa: XP do objetivo e flag de unlock (idempotente).
	awardXp: (number, number) -> any,
	grantUnlock: (number, string) -> boolean,
	now: () -> number,
	onQuestEvent: ((number, QuestEvent) -> ())?,
}

export type QuestState = "offered" | "active" | "completed"

export type QuestProgress = {
	questId: string,
	state: QuestState,
	progress: number,
	required: number,
	offeredAt: number,
	acceptedAt: number,
	completedAt: number,
}

export type QuestEvent = {
	questId: string,
	state: QuestState,
	trackerKey: string,
	progress: number,
	required: number,
	-- Prêmio anunciado (o cliente não inventa o número).
	xpReward: number?,
	-- Só no evento de conclusão.
	xpGranted: number?,
	unlockFlag: string?,
	-- "npc" quando o jogador falou com o Instrutor; "timeout" no aceite forçado.
	acceptSource: string?,
}

local QuestService = {
	deps = nil :: QuestDeps?,
	-- userId → questId → progresso
	states = {} :: { [number]: { [string]: QuestProgress } },
}

function QuestService.init(deps: QuestDeps): ()
	QuestService.deps = deps
	table.clear(QuestService.states)
end

local function emit(userId: number, event: QuestEvent): ()
	local deps = QuestService.deps
	if deps and deps.onQuestEvent then
		deps.onQuestEvent(userId, event)
	end
end

-- Oferece a cadeia ao entrar. O tracker só aparece depois do aceite (ou do
-- aceite forçado por tempo).
function QuestService.registerPlayer(userId: number, now: number): ()
	local deps = QuestService.deps
	if not deps then
		return
	end
	local userStates: { [string]: QuestProgress } = {}
	QuestService.states[userId] = userStates
	for _, questId in deps.chain() do
		local def = deps.getQuest(questId)
		if def then
			userStates[questId] = {
				questId = questId,
				state = "offered",
				progress = 0,
				required = def.requiredCount,
				offeredAt = now,
				acceptedAt = 0,
				completedAt = 0,
			}
		end
	end
end

function QuestService.unregisterPlayer(userId: number): ()
	QuestService.states[userId] = nil
end

function QuestService.getProgress(userId: number, questId: string): QuestProgress?
	local userStates = QuestService.states[userId]
	if not userStates then
		return nil
	end
	return userStates[questId]
end

-- Aceita o objetivo. `source` é "npc" (InteractionIntent) ou "timeout".
function QuestService.tryAccept(userId: number, questId: string, now: number, source: string): (boolean, string?)
	local deps = QuestService.deps
	if not deps then
		return false, "not_initialized"
	end
	local userStates = QuestService.states[userId]
	if not userStates then
		return false, "unknown_player"
	end
	local progress = userStates[questId]
	if not progress then
		return false, "unknown_quest"
	end
	if progress.state == "active" then
		return false, "already_active"
	end
	if progress.state == "completed" then
		return false, "already_completed"
	end
	local def = deps.getQuest(questId)
	if not def then
		return false, "unknown_quest"
	end

	progress.state = "active"
	progress.acceptedAt = now
	deps.grantUnlock(userId, def.acceptFlag)
	emit(userId, {
		questId = questId,
		state = "active",
		trackerKey = def.trackerKey,
		progress = progress.progress,
		required = progress.required,
		xpReward = def.xpReward,
		acceptSource = source,
	})
	return true, nil
end

-- Aceite pelo NPC ofertante (docs/13 §13 — InteractionIntent).
-- A cadeia é sequencial: o NPC só oferece o próximo objetivo quando o
-- anterior foi completado (roteiro §10: caça → elite → timing). Sem isso,
-- falar duas vezes com o Instrutor aceitaria os três de uma vez.
function QuestService.tryAcceptFromNpc(userId: number, npcId: string, now: number): (boolean, string?)
	local deps = QuestService.deps
	if not deps then
		return false, "not_initialized"
	end
	local userStates = QuestService.states[userId]
	if not userStates then
		return false, "unknown_player"
	end
	local chain = deps.chain()
	local previousCompleted = true
	for index, questId in chain do
		local def = deps.getQuest(questId)
		local progress = userStates[questId]
		if def and progress then
			if def.giverNpcId == npcId and progress.state == "offered" and previousCompleted then
				return QuestService.tryAccept(userId, questId, now, "npc")
			end
			if progress.state == "active" then
				return false, "already_active"
			end
			if progress.state == "completed" then
				previousCompleted = true
			else
				previousCompleted = false
			end
		end
		if index < #chain and not userStates[chain[index + 1]] then
			break
		end
	end
	return false, "no_offer"
end

-- Aceite forçado por tempo (§10: o tracker aparece após 90 s mesmo se o
-- jogador ignorar o NPC). Idempotente; seguro em heartbeat.
function QuestService.tick(userId: number, now: number): ()
	local deps = QuestService.deps
	if not deps then
		return
	end
	local userStates = QuestService.states[userId]
	if not userStates then
		return
	end
	for _, questId in deps.chain() do
		local def = deps.getQuest(questId)
		local progress = userStates[questId]
		if def and progress and progress.state == "offered" then
			local deadline = progress.offeredAt + def.autoAcceptAfterSeconds
			if now >= deadline then
				QuestService.tryAccept(userId, questId, now, "timeout")
			end
		end
	end
end

-- Credita um kill no objetivo ativo cujo alvo bate. Retorna os eventos gerados
-- (progresso e, se fechar, conclusão). Kill fora de objetivo ativo não conta.
function QuestService.creditKill(userId: number, targetNpcId: string, now: number): { QuestEvent }
	return QuestService.creditEvent(userId, "kill", targetNpcId, now)
end

-- Credita um eco de Fluxo acertado (docs/13 §6.2/§10 — kind "flow_echo").
-- `abilityId` é a habilidade que gerou o eco (quest_flow mira broken_cadence).
-- Mesma máquina de estado do kill, só muda o gatilho.
function QuestService.creditFlowEcho(userId: number, abilityId: string, now: number): { QuestEvent }
	return QuestService.creditEvent(userId, "flow_echo", abilityId, now)
end

-- Núcleo do crédito de objetivo: procura o primeiro objetivo ATIVO da cadeia
-- cujo kind e alvo batem e avança o progresso. Recompensa idempotente.
function QuestService.creditEvent(userId: number, kind: string, targetId: string, now: number): { QuestEvent }
	local out: { QuestEvent } = {}
	local deps = QuestService.deps
	if not deps then
		return out
	end
	QuestService.tick(userId, now)
	local userStates = QuestService.states[userId]
	if not userStates then
		return out
	end

	for _, questId in deps.chain() do
		local def = deps.getQuest(questId)
		local progress = userStates[questId]
		if def and progress and progress.state == "active" and def.kind == kind and def.targetId == targetId then
			progress.progress = math.min(progress.progress + 1, progress.required)
			if progress.progress < progress.required then
				local event: QuestEvent = {
					questId = questId,
					state = "active",
					trackerKey = def.trackerKey,
					progress = progress.progress,
					required = progress.required,
					xpReward = def.xpReward,
				}
				table.insert(out, event)
				emit(userId, event)
			else
				progress.state = "completed"
				progress.completedAt = now
				local xpGranted = 0
				if def.xpReward > 0 then
					local award = deps.awardXp(userId, def.xpReward)
					xpGranted = if award and award.granted then award.granted else 0
				end
				if def.unlockFlag then
					deps.grantUnlock(userId, def.unlockFlag)
				end
				local event: QuestEvent = {
					questId = questId,
					state = "completed",
					trackerKey = def.trackerKey,
					progress = progress.progress,
					required = progress.required,
					xpReward = def.xpReward,
					xpGranted = xpGranted,
					unlockFlag = def.unlockFlag,
				}
				table.insert(out, event)
				emit(userId, event)
			end
			-- Um kill alimenta um objetivo por vez.
			break
		end
	end
	return out
end

-- Tracker visível: primeiro objetivo ativo da cadeia. `nil` quando não há
-- objetivo aceito (HUD §12.2: a linha some ao completar).
function QuestService.getTracker(userId: number): QuestEvent?
	local deps = QuestService.deps
	if not deps then
		return nil
	end
	local userStates = QuestService.states[userId]
	if not userStates then
		return nil
	end
	for _, questId in deps.chain() do
		local def = deps.getQuest(questId)
		local progress = userStates[questId]
		if def and progress and progress.state == "active" then
			return {
				questId = questId,
				state = "active",
				trackerKey = def.trackerKey,
				progress = progress.progress,
				required = progress.required,
				xpReward = def.xpReward,
			}
		end
	end
	return nil
end

return QuestService

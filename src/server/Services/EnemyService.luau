--!strict
-- EnemyService (server) — F0 (docs/13-F0-SLICE.md §9.2)
-- Spawn, perseguição, ciclo de ataque e respawn do Estilhaço Errante.
-- Autoridade total no servidor; sem pathfinding — perseguição em linha reta,
-- como a spec pede ("sem pathfinding complexo").
--
-- Fecha a metade espacial do item 7: o `CombatService.tryShardCycle` já tinha a
-- máquina idle → telegraph → ataque → recovery, mas ninguém produzia a
-- distância nem escolhia o alvo. É aqui.
--
-- Convenção de id do fighter: "<npcId>@<anchorId>#<n>" — a âncora vive no id
-- porque o retorno decrescente de XP é por ponto de spawn (§9.2).
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type Vec3 = { x: number, y: number, z: number }

export type EnemyTarget = {
	fighterId: string,
	userId: number,
	zoneId: string,
}

export type EnemyDeps = {
	getNpc: (string) -> any?,
	getAnchor: (string) -> any?,
	shardAnchors: () -> { string },
	spatial: any,
	combat: any,
	geometry: any,
	-- Jogadores elegíveis a aggro neste tick (vivos e prontos).
	listTargets: () -> { EnemyTarget },
	-- Kill confirmado: crédito de XP e objetivo ficam fora deste serviço.
	onKill: ((number, string) -> ())?,
	-- Telegraph, ataque, spawn e morte — o bootstrap liga ao cliente.
	onEnemyEvent: ((string, { any }) -> ())?,
}

export type EnemyRecord = {
	fighterId: string,
	npcId: string,
	anchorId: string,
	zoneId: string,
}

local SHARD_NPC_ID = "enemy_wandering_shard"

local EnemyService = {
	deps = nil :: EnemyDeps?,
	-- fighterId → registro
	enemies = {} :: { [string]: EnemyRecord },
}

function EnemyService.init(deps: EnemyDeps): ()
	EnemyService.deps = deps
	table.clear(EnemyService.enemies)
end

function EnemyService.fighterId(npcId: string, anchorId: string, index: number): string
	return ("%s@%s#%d"):format(npcId, anchorId, index)
end

function EnemyService.list(): { EnemyRecord }
	local out: { EnemyRecord } = {}
	local ids: { string } = {}
	for fighterId in EnemyService.enemies do
		table.insert(ids, fighterId)
	end
	table.sort(ids)
	for _, fighterId in ids do
		table.insert(out, EnemyService.enemies[fighterId])
	end
	return out
end

local function emit(fighterId: string, event: { any }): ()
	local deps = EnemyService.deps
	if deps and deps.onEnemyEvent then
		deps.onEnemyEvent(fighterId, event)
	end
end

-- Povoa a planície até o teto de vivos (§9.2: no máximo 4). Idempotente:
-- chamar duas vezes não cria duplicata na mesma âncora.
function EnemyService.spawnInitial(): number
	local deps = EnemyService.deps
	if not deps then
		return 0
	end
	local def = deps.getNpc(SHARD_NPC_ID)
	if not def or not def.enabled then
		return 0
	end
	local maxAlive = def.maxAlive or 0
	local spawned = 0
	for _, anchorId in deps.shardAnchors() do
		if not deps.combat.canSpawnNpc(SHARD_NPC_ID .. "@", maxAlive) then
			break
		end
		local fighterId = EnemyService.fighterId(SHARD_NPC_ID, anchorId, 1)
		if not EnemyService.enemies[fighterId] then
			local anchor = deps.getAnchor(anchorId)
			if anchor then
				deps.combat.createFighter(fighterId, "npc", def.maxHealth, def.maxGuard)
				deps.spatial.setTransform(fighterId, {
					x = anchor.position.x,
					y = anchor.position.y,
					z = anchor.position.z,
				}, { x = 0, y = 0, z = 1 })
				EnemyService.enemies[fighterId] = {
					fighterId = fighterId,
					npcId = SHARD_NPC_ID,
					anchorId = anchorId,
					zoneId = anchor.zoneId,
				}
				spawned += 1
				emit(fighterId, { kind = "spawn", anchorId = anchorId })
			end
		end
	end
	return spawned
end

-- Alvo mais próximo elegível. Sem aggro através da fronteira (§9): um jogador
-- na zona segura ou na transição é invisível para o Estilhaço.
local function nearestTarget(record: EnemyRecord, targets: { EnemyTarget }): (EnemyTarget?, number?)
	local deps = EnemyService.deps
	if not deps then
		return nil, nil
	end
	local best: EnemyTarget? = nil
	local bestDistance: number? = nil
	for _, target in targets do
		if target.zoneId == record.zoneId then
			local distance = deps.spatial.distanceBetween(record.fighterId, target.fighterId)
			if distance and (bestDistance == nil or distance < bestDistance) then
				best = target
				bestDistance = distance
			end
		end
	end
	return best, bestDistance
end

-- Alguém em combate perto da âncora bloqueia o respawn (§9.2).
local function combatNearAnchor(record: EnemyRecord, targets: { EnemyTarget }, radius: number): boolean
	local deps = EnemyService.deps
	if not deps then
		return false
	end
	local anchor = deps.getAnchor(record.anchorId)
	if not anchor then
		return false
	end
	for _, target in targets do
		local position = deps.spatial.getPosition(target.fighterId)
		if position and deps.geometry.horizontalDistance(anchor.position, position) <= radius then
			return true
		end
	end
	return false
end

-- Um passo da AI de todos os Estilhaços. `deltaSeconds` é o tempo desde o
-- último tick (o bootstrap passa o do Heartbeat; os testes passam um valor
-- fixo). Retorna quantos ataques conectaram, para telemetria.
function EnemyService.tick(now: number, deltaSeconds: number): number
	local deps = EnemyService.deps
	if not deps then
		return 0
	end
	local def = deps.getNpc(SHARD_NPC_ID)
	if not def then
		return 0
	end
	local targets = deps.listTargets()
	local hits = 0

	for _, record in EnemyService.list() do
		local fighter = deps.combat.getFighter(record.fighterId)
		if fighter then
			if fighter.health <= 0 then
				local radius = def.combatClearRadius or 20
				local blocked = combatNearAnchor(record, targets, radius)
				local respawned = deps.combat.tryRespawn(fighter, now, def.respawnSeconds or 45, blocked)
				if respawned then
					local anchor = deps.getAnchor(record.anchorId)
					if anchor then
						deps.spatial.setTransform(record.fighterId, {
							x = anchor.position.x,
							y = anchor.position.y,
							z = anchor.position.z,
						}, { x = 0, y = 0, z = 1 })
					end
					emit(record.fighterId, { kind = "respawn", anchorId = record.anchorId })
				end
			else
				local target, distance = nearestTarget(record, targets)
				if target and distance then
					-- Move só fora do compromisso: telegraph e recovery travam.
					if fighter.aiPhase == "idle" then
						local from = deps.spatial.getPosition(record.fighterId)
						local to = deps.spatial.getPosition(target.fighterId)
						if from and to then
							local moved =
								deps.geometry.moveToward(from, to, def.moveSpeed or 12, deltaSeconds, def.attackRange)
							local look = deps.geometry.normalize(deps.geometry.sub(to, moved))
							deps.spatial.setTransform(record.fighterId, moved, look)
							distance = deps.geometry.horizontalDistance(moved, to)
						end
					end

					local targetFighter = deps.combat.getFighter(target.fighterId)
					if targetFighter then
						local result = deps.combat.tryShardCycle(
							fighter,
							targetFighter,
							now,
							distance,
							true,
							def.attackDamage,
							def.attackRange,
							def.telegraphMs / 1000,
							def.recoverySeconds or 0.6
						)
						if result.ok and result.phase == "telegraph" then
							emit(record.fighterId, { kind = "telegraph", targetId = target.fighterId })
						elseif result.ok and result.phase == "attack" then
							hits += 1
							emit(record.fighterId, {
								kind = "attack",
								targetId = target.fighterId,
								damage = result.damage,
							})
						end
					end
				else
					-- Sem alvo elegível: encerra o compromisso e volta ao idle.
					deps.combat.tryShardCycle(
						fighter,
						fighter,
						now,
						math.huge,
						false,
						def.attackDamage,
						def.attackRange,
						def.telegraphMs / 1000,
						def.recoverySeconds or 0.6
					)
				end
			end
		end
	end
	return hits
end

-- Morte de um Estilhaço causada por `userId`. Chamado pelo bootstrap quando o
-- combate devolve `killed`; o crédito de XP/objetivo é do ProgressionService.
function EnemyService.reportKill(userId: number, fighterId: string): boolean
	local deps = EnemyService.deps
	local record = EnemyService.enemies[fighterId]
	if not deps or not record then
		return false
	end
	emit(fighterId, { kind = "died", anchorId = record.anchorId, byUserId = userId })
	if deps.onKill then
		deps.onKill(userId, fighterId)
	end
	return true
end

function EnemyService.isEnemy(fighterId: string): boolean
	return EnemyService.enemies[fighterId] ~= nil
end

function EnemyService.despawnAll(): ()
	local deps = EnemyService.deps
	for fighterId in EnemyService.enemies do
		if deps then
			deps.combat.removeFighter(fighterId)
			deps.spatial.remove(fighterId)
		end
	end
	table.clear(EnemyService.enemies)
end

return EnemyService

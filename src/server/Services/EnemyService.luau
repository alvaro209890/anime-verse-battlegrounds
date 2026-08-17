--!strict
-- EnemyService (server) — F0 (docs/13-F0-SLICE.md §9)
-- Spawn, perseguição, ciclo de ataque e respawn do Estilhaço Errante e do
-- Estilhaço Ancorado (elite da cratera). Autoridade total no servidor; sem
-- pathfinding — perseguição em linha reta, como a spec pede.
--
-- Item 9 (2026-08-12): o elite entra como segundo NPC — spawn único na
-- âncora `anchor_elite`, ciclo alternado combo/slam (`tryEliteCycle`),
-- respawn 180 s e leeching: crédito de XP/objetivo para quem causou ≥ 1% da
-- vida OU ficou 8 s no raio 20 da cratera. Sem último golpe (§9.3).
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
local ELITE_NPC_ID = "enemy_anchored_shard"
local ELITE_ANCHOR_ID = "anchor_elite"

local EnemyService = {
	deps = nil :: EnemyDeps?,
	-- fighterId → registro
	enemies = {} :: { [string]: EnemyRecord },
	-- fighterId → userId → dano causado nesta vida (leeching §9.3)
	eliteDamage = {} :: { [string]: { [number]: number } },
	-- fighterId → userId → segundos acumulados no raio 20 (leeching §9.3)
	eliteTimeInRadius = {} :: { [string]: { [number]: number } },
	-- fighterId → true quando a morte do elite já foi resolvida (leeching)
	eliteDeathResolved = {} :: { [string]: boolean },
	-- Alternância visual do inimigo comum; não altera hitbox nem dano.
	shardCycleCount = {} :: { [string]: number },
	-- fighterId → já emitiu "died" nesta vida (evita zumbi com vida 0 sem pose
	-- de morte se o creditKill falhou ou o golpe não passou por reportKill).
	deathPresented = {} :: { [string]: boolean },
}

function EnemyService.init(deps: EnemyDeps): ()
	EnemyService.deps = deps
	table.clear(EnemyService.enemies)
	table.clear(EnemyService.eliteDamage)
	table.clear(EnemyService.eliteTimeInRadius)
	table.clear(EnemyService.eliteDeathResolved)
	table.clear(EnemyService.shardCycleCount)
	table.clear(EnemyService.deathPresented)
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

-- Garante apresentação de morte uma vez por vida (corpo some / CombatTarget off).
local function ensureDeathPresented(fighterId: string, anchorId: string, durationSeconds: number?): ()
	if EnemyService.deathPresented[fighterId] then
		return
	end
	EnemyService.deathPresented[fighterId] = true
	emit(fighterId, {
		kind = "died",
		anchorId = anchorId,
		durationSeconds = durationSeconds or 0.75,
		visualPattern = "collapse",
	})
end

local function attackOutcome(result: any, target: any): string
	if result.iframe == true then
		return "evaded"
	end
	if
		result.parried == true
		or result.broken == true
		or result.pulseCounter == true
		or (target and target.guarding == true)
	then
		return "guard"
	end
	return "hit"
end

local function registerEnemy(fighterId: string, npcId: string, anchor: any): EnemyRecord
	local record: EnemyRecord = {
		fighterId = fighterId,
		npcId = npcId,
		anchorId = anchor.id,
		zoneId = anchor.zoneId,
	}
	EnemyService.enemies[fighterId] = record
	return record
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
				registerEnemy(fighterId, SHARD_NPC_ID, anchor)
				EnemyService.shardCycleCount[fighterId] = 0
				spawned += 1
				emit(
					fighterId,
					{ kind = "spawn", anchorId = anchorId, durationSeconds = 0.6, visualPattern = "arrival" }
				)
			end
		end
	end
	return spawned
end

-- Spawn do Estilhaço Ancorado na cratera (§9.3: um único, respawn 180 s).
-- Idempotente: chamar duas vezes não cria duplicata.
function EnemyService.spawnElite(): boolean
	local deps = EnemyService.deps
	if not deps then
		return false
	end
	local def = deps.getNpc(ELITE_NPC_ID)
	local anchor = deps.getAnchor(ELITE_ANCHOR_ID)
	if not def or not def.enabled or not anchor then
		return false
	end
	local fighterId = EnemyService.fighterId(ELITE_NPC_ID, ELITE_ANCHOR_ID, 1)
	if EnemyService.enemies[fighterId] then
		return false
	end
	deps.combat.createFighter(fighterId, "npc", def.maxHealth, def.maxGuard)
	deps.spatial.setTransform(fighterId, {
		x = anchor.position.x,
		y = anchor.position.y,
		z = anchor.position.z,
	}, { x = 0, y = 0, z = 1 })
	registerEnemy(fighterId, ELITE_NPC_ID, anchor)
	EnemyService.eliteDamage[fighterId] = {}
	EnemyService.eliteTimeInRadius[fighterId] = {}
	EnemyService.eliteDeathResolved[fighterId] = false
	EnemyService.shardCycleCount[fighterId] = 0
	emit(fighterId, { kind = "spawn", anchorId = ELITE_ANCHOR_ID, durationSeconds = 0.6, visualPattern = "arrival" })
	return true
end

-- Registra dano causado ao elite por um jogador (leeching §9.3). Chamado pelo
-- bootstrap quando um golpe acerta o elite; o crédito não depende do último
-- golpe.
function EnemyService.registerEliteDamage(fighterId: string, userId: number, damage: number): ()
	if not EnemyService.eliteDamage[fighterId] then
		EnemyService.eliteDamage[fighterId] = {}
	end
	EnemyService.eliteDamage[fighterId][userId] = (EnemyService.eliteDamage[fighterId][userId] or 0) + damage
end

function EnemyService.isEnemy(fighterId: string): boolean
	return EnemyService.enemies[fighterId] ~= nil
end

function EnemyService.isElite(fighterId: string): boolean
	local record = EnemyService.enemies[fighterId]
	return record ~= nil and record.npcId == ELITE_NPC_ID
end

-- Alvo mais próximo elegível. Sem aggro através da fronteira (§9): um jogador
-- na zona segura ou na transição é invisível para o inimigo.
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

-- Um passo da AI de todos os Estilhaços errantes. `deltaSeconds` é o tempo
-- desde o último tick (o bootstrap passa o do Heartbeat; os testes passam um
-- valor fixo). Retorna quantos ataques conectaram, para telemetria.
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
		-- O Estilhaço Ancorado tem máquina de estado e respawn próprios em
		-- tickElite. Processá-lo aqui também moveria o elite e aplicaria o
		-- baseline de 45 s dos Errantes sobre o respawn autoritativo de 180 s.
		if record.npcId ~= SHARD_NPC_ID then
			continue
		end
		local fighter = deps.combat.getFighter(record.fighterId)
		if fighter then
			if fighter.health <= 0 then
				-- Vida 0 sem "died" = zumbi visual (barra 0 e corpo em pé).
				ensureDeathPresented(record.fighterId, record.anchorId, 0.75)
				local radius = def.combatClearRadius or 20
				local blocked = combatNearAnchor(record, targets, radius)
				local respawned = deps.combat.tryRespawn(fighter, now, def.respawnSeconds or 45, blocked)
				if respawned then
					EnemyService.deathPresented[record.fighterId] = nil
					local anchor = deps.getAnchor(record.anchorId)
					if anchor then
						deps.spatial.setTransform(record.fighterId, {
							x = anchor.position.x,
							y = anchor.position.y,
							z = anchor.position.z,
						}, { x = 0, y = 0, z = 1 })
					end
					emit(record.fighterId, {
						kind = "respawn",
						anchorId = record.anchorId,
						durationSeconds = 0.6,
						visualPattern = "arrival",
					})
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
							local pounce = (EnemyService.shardCycleCount[record.fighterId] or 0) % 2 == 1
							emit(record.fighterId, {
								kind = "telegraph",
								targetId = target.fighterId,
								durationSeconds = def.telegraphMs / 1000,
								visualPattern = if pounce then "pounce" else "rend",
								abilityId = if pounce then "shard_pounce" else "shard_rend",
							})
						elseif result.ok and result.phase == "attack" then
							if result.iframe ~= true and result.damage > 0 then
								hits += 1
							end
							local pounce = (EnemyService.shardCycleCount[record.fighterId] or 0) % 2 == 1
							emit(record.fighterId, {
								kind = "attack",
								targetId = target.fighterId,
								damage = result.damage,
								outcome = attackOutcome(result, targetFighter),
								iframe = result.iframe == true,
								pulseCounter = result.pulseCounter == true,
								durationSeconds = 0.35,
								visualPattern = if pounce then "pounce" else "rend",
								abilityId = if pounce then "shard_pounce" else "shard_rend",
							})
							EnemyService.shardCycleCount[record.fighterId] = (
								EnemyService.shardCycleCount[record.fighterId] or 0
							) + 1
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

-- Um passo da AI do Estilhaço Ancorado (item 9). Acumula o tempo no raio da
-- cratera (leeching), roda o ciclo alternado combo/slam e, na morte, resolve
-- o crédito de XP/objetivo para os jogadores elegíveis (≥ 1% da vida ou 8 s
-- no raio — sem último golpe). Retorna quantos ataques conectaram.
function EnemyService.tickElite(now: number, deltaSeconds: number): number
	local deps = EnemyService.deps
	if not deps then
		return 0
	end
	local def = deps.getNpc(ELITE_NPC_ID)
	if not def then
		return 0
	end
	local targets = deps.listTargets()
	local hits = 0
	local fighterId = EnemyService.fighterId(ELITE_NPC_ID, ELITE_ANCHOR_ID, 1)
	local record = EnemyService.enemies[fighterId]
	if not record then
		return 0
	end
	local fighter = deps.combat.getFighter(fighterId)
	if not fighter then
		return 0
	end

	if fighter.health <= 0 then
		-- Morte: resolve o leeching UMA vez (o resolve é idempotente por
		-- construção) e programa o respawn de 180 s.
		EnemyService.resolveEliteDeath(fighterId, now)
		-- resolveEliteDeath já emite "died"; a flag evita reemit no ensure.
		EnemyService.deathPresented[fighterId] = true
		local blocked = combatNearAnchor(record, targets, def.combatClearRadius or 20)
		local respawned = deps.combat.tryRespawn(fighter, now, def.respawnSeconds or 180, blocked)
		if respawned then
			EnemyService.deathPresented[fighterId] = nil
			local anchor = deps.getAnchor(record.anchorId)
			if anchor then
				deps.spatial.setTransform(fighterId, {
					x = anchor.position.x,
					y = anchor.position.y,
					z = anchor.position.z,
				}, { x = 0, y = 0, z = 1 })
			end
			EnemyService.eliteDamage[fighterId] = {}
			EnemyService.eliteTimeInRadius[fighterId] = {}
			EnemyService.eliteDeathResolved[fighterId] = false
			EnemyService.shardCycleCount[fighterId] = 0
			emit(fighterId, {
				kind = "respawn",
				anchorId = record.anchorId,
				durationSeconds = 0.6,
				visualPattern = "arrival",
			})
		end
		return 0
	end

	-- Alvo: o mais próximo na planície; o elite é ancorado (não persegue).
	local target, distance = nearestTarget(record, targets)

	-- Leeching: acumula tempo no raio da cratera para quem está dentro.
	local radius = def.combatClearRadius or 20
	local timeTable = EnemyService.eliteTimeInRadius[fighterId]
	for _, t in targets do
		if t.zoneId == record.zoneId then
			local position = deps.spatial.getPosition(t.fighterId)
			local elitePosition = deps.spatial.getPosition(fighterId)
			if position and elitePosition and deps.geometry.horizontalDistance(elitePosition, position) <= radius then
				timeTable[t.userId] = (timeTable[t.userId] or 0) + deltaSeconds
			end
		end
	end

	if target and distance and distance <= (def.attackRange or 8) then
		local targetFighter = deps.combat.getFighter(target.fighterId)
		if targetFighter then
			local result = deps.combat.tryEliteCycle(fighter, targetFighter, now, distance, true, {
				range = def.attackRange or 8,
				recoverySeconds = def.recoverySeconds or 0.8,
				comboDamage = def.eliteComboDamage or 5,
				comboTelegraphSeconds = (def.eliteComboTelegraphMs or 300) / 1000,
				slamDamage = def.eliteSlamDamage or 12,
				slamTelegraphSeconds = (def.eliteSlamTelegraphMs or 700) / 1000,
				slamBlockedPct = 0.7,
			})
			if result.ok and result.phase == "telegraph" then
				local visualPattern = if fighter.elitePattern == "slam" then "slam" else "combo"
				local durationSeconds = if visualPattern == "slam"
					then (def.eliteSlamTelegraphMs or 700) / 1000
					else (def.eliteComboTelegraphMs or 300) / 1000
				emit(fighterId, {
					kind = "telegraph",
					targetId = target.fighterId,
					durationSeconds = durationSeconds,
					visualPattern = visualPattern,
					abilityId = if visualPattern == "slam" then "anchored_slam" else "anchored_combo",
				})
			elseif result.ok and result.phase == "attack" then
				if result.iframe ~= true and result.damage > 0 then
					hits += 1
				end
				emit(fighterId, {
					kind = "attack",
					targetId = target.fighterId,
					damage = result.damage,
					outcome = attackOutcome(result, targetFighter),
					iframe = result.iframe == true,
					pulseCounter = result.pulseCounter == true,
					durationSeconds = 0.4,
					visualPattern = if fighter.elitePattern == "slam" then "slam" else "combo",
					abilityId = if fighter.elitePattern == "slam" then "anchored_slam" else "anchored_combo",
				})
			end
		end
	else
		-- Sem alvo no alcance: encerra o compromisso e volta ao idle.
		deps.combat.tryEliteCycle(fighter, fighter, now, math.huge, false, {
			range = def.attackRange or 8,
			recoverySeconds = def.recoverySeconds or 0.8,
			comboDamage = def.eliteComboDamage or 5,
			comboTelegraphSeconds = (def.eliteComboTelegraphMs or 300) / 1000,
			slamDamage = def.eliteSlamDamage or 12,
			slamTelegraphSeconds = (def.eliteSlamTelegraphMs or 700) / 1000,
			slamBlockedPct = 0.7,
		})
	end
	return hits
end

-- Resolve o leeching na morte do elite (§9.3): todo jogador que causou ≥ 1%
-- da vida OU ficou 8 s no raio recebe crédito (XP e objetivo), sem precisar do
-- último golpe. O XP "uma vez por 3 min por jogador" é cooldown do
-- ProgressionService (xpCooldownSeconds no catálogo).
function EnemyService.resolveEliteDeath(fighterId: string, _now: number): { number }
	local deps = EnemyService.deps
	local credited: { number } = {}
	if not deps then
		return credited
	end
	-- Idempotente por construção (o tick também guarda via eliteDeathResolved).
	if EnemyService.eliteDeathResolved[fighterId] then
		return credited
	end
	EnemyService.eliteDeathResolved[fighterId] = true
	local def = deps.getNpc(ELITE_NPC_ID)
	if not def then
		return credited
	end
	local damageTable = EnemyService.eliteDamage[fighterId] or {}
	local timeTable = EnemyService.eliteTimeInRadius[fighterId] or {}
	local minDamage = math.max(1, math.floor(def.maxHealth * (def.leechDamagePct or 0.01)))
	local minStay = def.leechStaySeconds or 8

	emit(fighterId, {
		kind = "died",
		anchorId = ELITE_ANCHOR_ID,
		durationSeconds = 0.75,
		visualPattern = "collapse",
	})
	local userIds: { number } = {}
	for userId in damageTable do
		table.insert(userIds, userId)
	end
	for userId in timeTable do
		if not damageTable[userId] then
			table.insert(userIds, userId)
		end
	end
	table.sort(userIds)

	for _, userId in userIds do
		local eligible = (damageTable[userId] or 0) >= minDamage or (timeTable[userId] or 0) >= minStay
		if eligible then
			table.insert(credited, userId)
			if deps.onKill then
				deps.onKill(userId, fighterId)
			end
		end
	end
	return credited
end

-- Morte de um Estilhaço causada por `userId`. Chamado pelo bootstrap quando o
-- combate devolve `killed`; o crédito de XP/objetivo é do ProgressionService.
-- (O elite não passa por aqui — a morte dele resolve o leeching no tick.)
function EnemyService.reportKill(userId: number, fighterId: string): boolean
	local deps = EnemyService.deps
	local record = EnemyService.enemies[fighterId]
	if not deps or not record then
		return false
	end
	ensureDeathPresented(fighterId, record.anchorId, 0.75)
	if deps.onKill then
		deps.onKill(userId, fighterId)
	end
	return true
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
	table.clear(EnemyService.eliteDamage)
	table.clear(EnemyService.eliteTimeInRadius)
	table.clear(EnemyService.eliteDeathResolved)
	table.clear(EnemyService.deathPresented)
end

return EnemyService

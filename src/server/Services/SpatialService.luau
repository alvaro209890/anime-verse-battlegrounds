--!strict
-- SpatialService (server) — F0 (docs/13-F0-SLICE.md §5, §6.1, §9)
-- Registro autoritativo de posição/orientação e as consultas que o combate
-- precisa: distância, costas, hitbox em esfera e cápsula, avanço do lunge.
--
-- Este serviço fecha o buraco de arquitetura da fatia: até aqui `distance`,
-- `facing` e `canAggro` eram PARÂMETROS do CombatService sem ninguém que os
-- produzisse. A posição vem do servidor (heartbeat do bootstrap lê o
-- HumanoidRootPart); o cliente nunca informa onde está para efeito de dano.
--
-- Puro: `Geometry` é injetado no init(), sem require de Instances — testável.

export type Vec3 = { x: number, y: number, z: number }

export type Transform = {
	position: Vec3,
	look: Vec3,
}

export type SpatialDeps = {
	geometry: any,
}

local SpatialService = {
	deps = nil :: SpatialDeps?,
	-- fighterId → transform
	transforms = {} :: { [string]: Transform },
}

local DEFAULT_LOOK: Vec3 = { x = 0, y = 0, z = -1 }

function SpatialService.init(deps: SpatialDeps): ()
	SpatialService.deps = deps
	table.clear(SpatialService.transforms)
end

function SpatialService.clear(): ()
	table.clear(SpatialService.transforms)
end

function SpatialService.setTransform(fighterId: string, position: Vec3, look: Vec3?): ()
	SpatialService.transforms[fighterId] = {
		position = position,
		look = look or DEFAULT_LOOK,
	}
end

function SpatialService.getTransform(fighterId: string): Transform?
	return SpatialService.transforms[fighterId]
end

function SpatialService.getPosition(fighterId: string): Vec3?
	local t = SpatialService.transforms[fighterId]
	return if t then t.position else nil
end

function SpatialService.remove(fighterId: string): ()
	SpatialService.transforms[fighterId] = nil
end

-- Empurrão (docs/13 §6.3 — contra do Retorno de Pulso): move `fighterId`
-- `distance` studs para longe de `fromPosition`, no plano do chão (altura
-- preservada). Sem transform conhecido, não move.
function SpatialService.pushBack(fighterId: string, fromPosition: Vec3, distance: number): boolean
	local transform = SpatialService.transforms[fighterId]
	local deps = SpatialService.deps
	if not transform or not deps or distance <= 0 then
		return false
	end
	local delta = deps.geometry.sub(transform.position, fromPosition)
	local horizontal = math.sqrt(delta.x * delta.x + delta.z * delta.z)
	if horizontal <= 1e-6 then
		return false
	end
	local dir = {
		x = delta.x / horizontal,
		z = delta.z / horizontal,
	}
	transform.position = {
		x = transform.position.x + dir.x * distance,
		y = transform.position.y,
		z = transform.position.z + dir.z * distance,
	}
	SpatialService.transforms[fighterId] = transform
	return true
end

-- Distância no plano do chão. `nil` se algum dos dois não tem transform —
-- quem chama trata como "fora de alcance", nunca como 0.
function SpatialService.distanceBetween(idA: string, idB: string): number?
	local deps = SpatialService.deps
	local a = SpatialService.transforms[idA]
	local b = SpatialService.transforms[idB]
	if not deps or not a or not b then
		return nil
	end
	return deps.geometry.horizontalDistance(a.position, b.position)
end

-- Lado do golpe do ponto de vista do alvo (docs/13 §5.1).
-- Sem transform conhecido assume "front": a guarda não é anulada por
-- ausência de dado.
function SpatialService.facingOf(targetId: string, attackerId: string): "front" | "back"
	local deps = SpatialService.deps
	local target = SpatialService.transforms[targetId]
	local attacker = SpatialService.transforms[attackerId]
	if not deps or not target or not attacker then
		return "front"
	end
	return deps.geometry.facing(target.position, target.look, attacker.position)
end

local function collect(predicate: ((string) -> boolean)?, test: (Vec3) -> boolean, maxTargets: number?): { string }
	local hits: { string } = {}
	local ids: { string } = {}
	for fighterId in SpatialService.transforms do
		table.insert(ids, fighterId)
	end
	-- Ordem estável: iteração de tabela em Luau não é determinística e o
	-- `maxTargets` da spec ("máx. 1 alvo") não pode depender de sorte.
	table.sort(ids)
	for _, fighterId in ids do
		local transform = SpatialService.transforms[fighterId]
		if transform and (not predicate or predicate(fighterId)) and test(transform.position) then
			table.insert(hits, fighterId)
			if maxTargets and #hits >= maxTargets then
				break
			end
		end
	end
	return hits
end

function SpatialService.overlapSphere(
	center: Vec3,
	radius: number,
	predicate: ((string) -> boolean)?,
	maxTargets: number?
): { string }
	local deps = SpatialService.deps
	if not deps then
		return {}
	end
	return collect(predicate, function(position: Vec3): boolean
		return deps.geometry.sphereContains(center, radius, position)
	end, maxTargets)
end

function SpatialService.overlapCapsule(
	from: Vec3,
	to: Vec3,
	radius: number,
	predicate: ((string) -> boolean)?,
	maxTargets: number?
): { string }
	local deps = SpatialService.deps
	if not deps then
		return {}
	end
	return collect(predicate, function(position: Vec3): boolean
		return deps.geometry.capsuleContains(from, to, radius, position)
	end, maxTargets)
end

-- Hitbox à frente do atacante (cadeia leve e pesado — docs/13 §5.1/§5.2).
-- O centro fica `forward` studs adiante do olhar; o próprio atacante nunca
-- entra no resultado.
function SpatialService.overlapInFront(
	attackerId: string,
	forward: number,
	radius: number,
	predicate: ((string) -> boolean)?,
	maxTargets: number?
): { string }
	local deps = SpatialService.deps
	local attacker = SpatialService.transforms[attackerId]
	if not deps or not attacker then
		return {}
	end
	local look = deps.geometry.normalize(attacker.look)
	local center = deps.geometry.add(attacker.position, deps.geometry.scale(look, forward))
	return SpatialService.overlapSphere(center, radius, function(fighterId: string): boolean
		if fighterId == attackerId then
			return false
		end
		return not predicate or predicate(fighterId)
	end, maxTargets)
end

-- Avanço do Ombro Cometa (docs/13 §6.1: 7 studs, cap absoluto 8, para em
-- parede e em guarda inimiga). Os bloqueadores são os outros fighters que
-- `blocks` marcar; paredes entram como bloqueadores estáticos via `extra`.
function SpatialService.resolveLunge(
	attackerId: string,
	maxDistance: number,
	hardCap: number,
	blockerRadius: number,
	blocks: ((string) -> boolean)?,
	extra: { any }?
): any
	local deps = SpatialService.deps
	local attacker = SpatialService.transforms[attackerId]
	if not deps or not attacker then
		return { position = { x = 0, y = 0, z = 0 }, traveled = 0, blocked = false }
	end
	local blockers: { any } = {}
	for fighterId, transform in SpatialService.transforms do
		if fighterId ~= attackerId and (not blocks or blocks(fighterId)) then
			table.insert(blockers, {
				id = fighterId,
				position = transform.position,
				radius = blockerRadius,
			})
		end
	end
	if extra then
		for _, blocker in extra do
			table.insert(blockers, blocker)
		end
	end
	table.sort(blockers, function(a: any, b: any): boolean
		return a.id < b.id
	end)
	return deps.geometry.resolveLunge(attacker.position, attacker.look, maxDistance, hardCap, blockers)
end

export type DashDirection = {
	x: number,
	y: number?,
	z: number,
}

export type DashResolution = {
	position: Vec3,
	traveled: number,
	blocked: boolean,
	blockedBy: string?,
}

-- Dash autoritativo no plano do chão. `distance`, `hardCap` e `walls` são
-- configuração do servidor; o cliente fornece somente a direção semântica.
-- A direção é normalizada aqui e a posição resolvida é commitada no registro.
function SpatialService.resolveDash(
	fighterId: string,
	direction: DashDirection,
	distance: number,
	hardCap: number,
	walls: { any }?
): DashResolution
	local deps = SpatialService.deps
	local transform = SpatialService.transforms[fighterId]
	if not deps or not transform then
		return {
			position = { x = 0, y = 0, z = 0 },
			traveled = 0,
			blocked = false,
		}
	end
	local normalized = deps.geometry.normalize({
		x = direction.x,
		y = 0,
		z = direction.z,
	})
	local resolution =
		deps.geometry.resolveLunge(transform.position, normalized, distance, hardCap, walls or {}) :: DashResolution
	SpatialService.setTransform(fighterId, resolution.position, transform.look)
	return resolution
end

export type CometParams = {
	distance: number,
	hardCap: number,
	-- Raio da cápsula 4×4×8 do trajeto (§6.1).
	capsuleRadius: number,
	blockerRadius: number,
	-- Quem trava o avanço: parede e guarda inimiga (§6.1).
	blocks: ((string) -> boolean)?,
	-- Quem pode ser atingido (exclui o próprio atacante e aliados).
	targets: ((string) -> boolean)?,
	walls: { any }?,
}

export type CometResolution = {
	position: Vec3,
	traveled: number,
	blocked: boolean,
	blockedBy: string?,
	targetId: string?,
	facing: "front" | "back",
}

-- Ombro Cometa completo no espaço (§6.1): avança até 7 studs (cap 8), para no
-- primeiro bloqueio, COMMITA a posição nova e devolve no máximo 1 alvo na
-- cápsula do trajeto, com o lado do golpe.
--
-- A posição é escrita aqui porque o avanço é autoritativo: o cliente prevê o
-- lunge, mas quem move é o servidor (SLICE-DEC-005).
function SpatialService.resolveCometShoulder(attackerId: string, params: CometParams): CometResolution
	local deps = SpatialService.deps
	local attacker = SpatialService.transforms[attackerId]
	if not deps or not attacker then
		return {
			position = { x = 0, y = 0, z = 0 },
			traveled = 0,
			blocked = false,
			facing = "front",
		}
	end
	local origin = attacker.position
	local lunge = SpatialService.resolveLunge(
		attackerId,
		params.distance,
		params.hardCap,
		params.blockerRadius,
		params.blocks,
		params.walls
	)

	SpatialService.setTransform(attackerId, lunge.position, attacker.look)

	local hits = SpatialService.overlapCapsule(
		origin,
		lunge.position,
		params.capsuleRadius,
		function(fighterId: string): boolean
			if fighterId == attackerId then
				return false
			end
			return not params.targets or params.targets(fighterId)
		end,
		1
	)

	local targetId = hits[1]
	local facing: "front" | "back" = "front"
	if targetId then
		-- O lado do golpe se mede da ORIGEM do avanço, não da posição final.
		-- O lunge de 7 studs ultrapassa um alvo a 6; medir no fim faria todo
		-- Ombro Cometa contar como acerto pelas costas e furar a guarda.
		local targetTransform = SpatialService.transforms[targetId]
		if targetTransform then
			facing = deps.geometry.facing(targetTransform.position, targetTransform.look, origin)
		end
	end

	return {
		position = lunge.position,
		traveled = lunge.traveled,
		blocked = lunge.blocked,
		blockedBy = lunge.blockedBy,
		targetId = targetId,
		facing = facing,
	}
end

return SpatialService

--!strict
-- Geometria da fatia F0 (docs/13-F0-SLICE.md §5, §6.1, §8, §9)
-- Matemática pura sobre vetores `{ x, y, z }` — NUNCA `Vector3`. Os adaptadores
-- Roblox convertem na fronteira (WorldService/bootstrap); assim toda regra
-- espacial (distância, costas, hitbox, lunge, volume de zona) roda no Lune.
--
-- Convenção do greybox: +x leste, +y cima, **-z norte** (docs/13 §8.1).

export type Vec3 = { x: number, y: number, z: number }

export type Box = { min: Vec3, max: Vec3 }

export type Blocker = {
	id: string,
	position: Vec3,
	radius: number,
}

export type LungeResult = {
	position: Vec3,
	traveled: number,
	blocked: boolean,
	blockedBy: string?,
}

local Geometry = {}

function Geometry.vec(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

function Geometry.add(a: Vec3, b: Vec3): Vec3
	return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function Geometry.sub(a: Vec3, b: Vec3): Vec3
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function Geometry.scale(a: Vec3, k: number): Vec3
	return { x = a.x * k, y = a.y * k, z = a.z * k }
end

function Geometry.dot(a: Vec3, b: Vec3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function Geometry.magnitude(a: Vec3): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

-- Vetor unitário. Vetor nulo devolve nulo (nunca NaN).
function Geometry.normalize(a: Vec3): Vec3
	local m = Geometry.magnitude(a)
	if m <= 1e-6 then
		return { x = 0, y = 0, z = 0 }
	end
	return { x = a.x / m, y = a.y / m, z = a.z / m }
end

function Geometry.distance(a: Vec3, b: Vec3): number
	return Geometry.magnitude(Geometry.sub(a, b))
end

-- Distância no plano do chão. Alcance de melê ignora desnível pequeno
-- (a cratera da elite tem borda 2 studs mais alta — docs/13 §8.1).
function Geometry.horizontalDistance(a: Vec3, b: Vec3): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Lado do golpe (docs/13 §5.1: costas ignoram guarda). O produto escalar entre
-- o olhar do alvo e a direção alvo→atacante decide: positivo = pela frente.
-- Empate exato (perpendicular) conta como frente: guarda não é punida por
-- ambiguidade numérica.
function Geometry.facing(targetPosition: Vec3, targetLook: Vec3, attackerPosition: Vec3): "front" | "back"
	local toAttacker = Geometry.normalize(Geometry.sub(attackerPosition, targetPosition))
	local look = Geometry.normalize(targetLook)
	if Geometry.magnitude(look) <= 1e-6 then
		return "front"
	end
	if Geometry.dot(look, toAttacker) >= 0 then
		return "front"
	end
	return "back"
end

function Geometry.sphereContains(center: Vec3, radius: number, point: Vec3): boolean
	return Geometry.distance(center, point) <= radius
end

-- Menor distância de um ponto ao segmento a→b. Base da hitbox em cápsula
-- (docs/13 §6.1: cápsula 4×4×8 no trajeto do Ombro Cometa).
function Geometry.distanceToSegment(a: Vec3, b: Vec3, point: Vec3): number
	local ab = Geometry.sub(b, a)
	local lengthSq = Geometry.dot(ab, ab)
	if lengthSq <= 1e-9 then
		return Geometry.distance(a, point)
	end
	local t = Geometry.dot(Geometry.sub(point, a), ab) / lengthSq
	t = math.clamp(t, 0, 1)
	local closest = Geometry.add(a, Geometry.scale(ab, t))
	return Geometry.distance(closest, point)
end

function Geometry.capsuleContains(a: Vec3, b: Vec3, radius: number, point: Vec3): boolean
	return Geometry.distanceToSegment(a, b, point) <= radius
end

-- Caixa alinhada aos eixos (volume de zona). Bordas são inclusivas: um ponto
-- exatamente no plano do portão já conta como dentro da transição.
function Geometry.boxContains(box: Box, point: Vec3): boolean
	return point.x >= box.min.x
		and point.x <= box.max.x
		and point.y >= box.min.y
		and point.y <= box.max.y
		and point.z >= box.min.z
		and point.z <= box.max.z
end

function Geometry.boxFromCenter(center: Vec3, sizeX: number, sizeY: number, sizeZ: number): Box
	return {
		min = { x = center.x - sizeX / 2, y = center.y - sizeY / 2, z = center.z - sizeZ / 2 },
		max = { x = center.x + sizeX / 2, y = center.y + sizeY / 2, z = center.z + sizeZ / 2 },
	}
end

-- Avanço do Ombro Cometa (docs/13 §6.1): anda até `maxDistance` na direção
-- informada e PARA no primeiro bloqueio (parede ou guarda inimiga). Nunca
-- ultrapassa `hardCap` — o cliente prevê o lunge, mas o servidor decide.
--
-- `blockers` são esferas; a primeira interceptada ao longo do trajeto encerra
-- o avanço no ponto de contato. Amostragem discreta em passos de `step` porque
-- a fatia não tem raycast físico no domínio headless.
function Geometry.resolveLunge(
	origin: Vec3,
	direction: Vec3,
	maxDistance: number,
	hardCap: number,
	blockers: { Blocker },
	step: number?
): LungeResult
	local dir = Geometry.normalize(direction)
	local limit = math.min(maxDistance, hardCap)
	if Geometry.magnitude(dir) <= 1e-6 or limit <= 0 then
		return { position = origin, traveled = 0, blocked = false }
	end
	local increment = step or 0.5
	local traveled = 0
	local position = origin
	while traveled < limit do
		local next = math.min(traveled + increment, limit)
		local candidate = Geometry.add(origin, Geometry.scale(dir, next))
		for _, blocker in blockers do
			if Geometry.distance(candidate, blocker.position) <= blocker.radius then
				return { position = position, traveled = traveled, blocked = true, blockedBy = blocker.id }
			end
		end
		position = candidate
		traveled = next
	end
	return { position = position, traveled = traveled, blocked = false }
end

-- Passo de deslocamento por tick (Estilhaço a 12 studs/s — docs/13 §9.2).
-- Nunca ultrapassa o alvo: para a `stopAt` studs dele.
function Geometry.moveToward(from: Vec3, to: Vec3, speed: number, deltaSeconds: number, stopAt: number): Vec3
	local delta = Geometry.sub(to, from)
	local distance = Geometry.magnitude(delta)
	local desired = distance - stopAt
	if desired <= 0 then
		return from
	end
	local travel = math.min(speed * deltaSeconds, desired)
	if travel <= 0 then
		return from
	end
	return Geometry.add(from, Geometry.scale(Geometry.normalize(delta), travel))
end

return Geometry

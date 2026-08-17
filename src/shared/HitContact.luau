--!strict
-- Contato local + validação do alvo declarado (docs/17 §2.11).
--
-- O cliente antecipa o *feeling* do impacto quando vê alguém no cone. O
-- servidor continua sendo a única fonte de HP, número de dano e morte. O
-- `claimedTargetId` que viaja no BasicAttackIntent é pista, não autoridade:
-- só entra se o cone autoritativo falhou (HRP replicada atrasada) e a
-- posição conhecida ainda cabe na folga de latência.
--
-- Puro: só tabelas `{ x, y, z }`. Sem Instances, sem Color3, testável no Lune.

export type Vec3 = { x: number, y: number, z: number }

export type Candidate = {
	id: string,
	position: Vec3,
}

export type ClaimArgs = {
	origin: Vec3,
	look: Vec3,
	target: Vec3,
	reach: number,
	halfAngle: number,
}

-- Matemática mínima copiada de Geometry (sem require de irmão: o Lune não
-- resolve script.Parent e o módulo precisa carregar nos testes).

local function vec(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

local function sub(a: Vec3, b: Vec3): Vec3
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function dot(a: Vec3, b: Vec3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function magnitude(a: Vec3): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

local function normalize(a: Vec3): Vec3
	local m = magnitude(a)
	if m <= 1e-6 then
		return { x = 0, y = 0, z = 0 }
	end
	return { x = a.x / m, y = a.y / m, z = a.z / m }
end

local function horizontalDistance(a: Vec3, b: Vec3): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Espelham o handler de init.server.lua. Um teste trava a igualdade.
-- 17/08: 3 studs deixava o jogador "colado" (centro-a-centro ~11) fora do
-- cone. 5 cobre torso+alvo sem abrir o hitbox para o lado do mapa.
local BODY_ALLOWANCE_STUDS = 5
local BASIC_RANGE_STUDS = 6

local HitContact = {}

HitContact.BasicRangeStuds = BASIC_RANGE_STUDS
HitContact.BodyAllowanceStuds = BODY_ALLOWANCE_STUDS
HitContact.LightReachStuds = {
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5,
	BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 1,
}
HitContact.HeavyReachStuds = BASIC_RANGE_STUDS + BODY_ALLOWANCE_STUDS + 0.5
HitContact.LightHalfAngleDegrees = 78
HitContact.HeavyHalfAngleDegrees = 68

-- Folga de latência: corrida 22 studs/s × ~230 ms de replica + RTT local.
-- Só vale para o alvo que o cliente declarou; não alarga o cone autoritativo.
HitContact.SlackStuds = 7
HitContact.ClaimExtraAngleDegrees = 15
-- Janela em que o CombatEvent não re-toca hit-stop/câmera/som já previstos.
HitContact.PredictWindowSeconds = 0.35

local function horizontalLook(look: Vec3): Vec3
	return normalize(vec(look.x, 0, look.z))
end

-- Distância no plano e se o ponto está no cone (abraço a ≤ 1 stud ignora ângulo).
function HitContact.distanceAndCone(
	origin: Vec3,
	look: Vec3,
	target: Vec3,
	maxDistance: number,
	halfAngleDegrees: number
): (number, boolean)
	local distance = horizontalDistance(origin, target)
	if maxDistance <= 0 or distance > maxDistance then
		return distance, false
	end
	if distance <= 1 then
		return distance, true
	end
	local delta = sub(target, origin)
	local flat = normalize(vec(delta.x, 0, delta.z))
	local facing = horizontalLook(look)
	local cosLimit = math.cos(math.rad(math.clamp(halfAngleDegrees, 0, 180)))
	return distance, dot(flat, facing) >= cosLimit
end

-- Alvo mais próximo dentro do cone. Empate estável por id, como o SpatialService.
function HitContact.acquire(
	origin: Vec3,
	look: Vec3,
	candidates: { Candidate },
	maxDistance: number,
	halfAngleDegrees: number
): string?
	if maxDistance <= 0 then
		return nil
	end
	local best: string? = nil
	local bestDistance = math.huge
	local order: { number } = {}
	for index in candidates do
		table.insert(order, index)
	end
	table.sort(order, function(a: number, b: number): boolean
		return candidates[a].id < candidates[b].id
	end)
	for _, index in order do
		local candidate = candidates[index]
		local distance, inCone =
			HitContact.distanceAndCone(origin, look, candidate.position, maxDistance, halfAngleDegrees)
		if inCone and distance < bestDistance then
			best = candidate.id
			bestDistance = distance
		end
	end
	return best
end

-- Aceita o alvo declarado quando o cone autoritativo errou por replica atrasada.
function HitContact.acceptClaimed(args: ClaimArgs): boolean
	if args.reach <= 0 then
		return false
	end
	local _, inCone = HitContact.distanceAndCone(
		args.origin,
		args.look,
		args.target,
		args.reach + HitContact.SlackStuds,
		args.halfAngle + HitContact.ClaimExtraAngleDegrees
	)
	return inCone
end

-- Decide o alvo final: cone do servidor vence; claimed só entra no miss espacial.
function HitContact.resolveTarget(
	acquiredId: string?,
	claimedId: string?,
	origin: Vec3?,
	look: Vec3?,
	claimedPosition: Vec3?,
	reach: number,
	halfAngle: number
): string?
	if type(acquiredId) == "string" then
		return acquiredId
	end
	if type(claimedId) ~= "string" or not origin or not look or not claimedPosition then
		return nil
	end
	if
		HitContact.acceptClaimed({
			origin = origin,
			look = look,
			target = claimedPosition,
			reach = reach,
			halfAngle = halfAngle,
		})
	then
		return claimedId
	end
	return nil
end

-- "dealt" = eu bati; "taken" = eu apanhei. Campo `view` do servidor vence.
function HitContact.viewFor(localFighterId: string?, payload: { [string]: any }): "dealt" | "taken"
	if payload.view == "taken" then
		return "taken"
	end
	if payload.view == "dealt" then
		return "dealt"
	end
	if type(localFighterId) == "string" and payload.targetId == localFighterId then
		return "taken"
	end
	return "dealt"
end

-- Se o contato previsto já tocou nesta janela, o CombatEvent não repete feeling.
function HitContact.shouldReplayImpact(predictedAt: number?, confirmedAt: number): boolean
	if type(predictedAt) ~= "number" then
		return true
	end
	return (confirmedAt - predictedAt) > HitContact.PredictWindowSeconds
end

return HitContact

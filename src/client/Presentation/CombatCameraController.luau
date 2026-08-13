--!strict
-- Câmera de impacto: shake e FOV punch locais, apenas para eventos de combate
-- confirmados pelo servidor. Nunca altera a mira autoritativa nem a câmera de
-- outro jogador; é puro overlay de apresentação (docs/14 §6, docs/17).

export type ImpactProfile = {
	trauma: number,
	fov: number,
}

export type Controller = {
	workspace: any?,
	runService: any?,
	random: (() -> number)?,
	baseFov: number?,
	trauma: number,
	fovPunch: number,
	connection: any?,
}

local CombatCameraController = {}

-- Perfis por desfecho. trauma alimenta o shake (curva quadrática) e fov o
-- "punch" de campo de visão; ambos decaem com o tempo.
local PROFILES: { [string]: ImpactProfile } = {
	hit = { trauma = 0.35, fov = 1.5 },
	death = { trauma = 0.7, fov = 3.5 },
	guard = { trauma = 0.16, fov = 0.6 },
	-- Contra do Pulso: entre o acerto comum e a morte. É a recompensa por ter
	-- lido o golpe do oponente e precisa ser sentida, não só vista.
	counter = { trauma = 0.5, fov = 2.6 },
}

-- Técnicas de maior compromisso merecem um impacto mais pesado no acerto.
local HEAVY_ABILITIES: { [string]: boolean } = {
	comet_shoulder = true,
	broken_cadence = true,
	eclipse_beat = true,
}

-- Baselines de docs/14 §6: shake local de até 2° e 0,3 stud, sempre limitado.
local MAX_SHAKE_DEGREES = 2.0
local MAX_SHAKE_STUDS = 0.3
local MAX_FOV_PUNCH = 6.0
local TRAUMA_DECAY = 2.6
local FOV_DECAY = 6.0

CombatCameraController.Profiles = PROFILES
CombatCameraController.HeavyAbilities = HEAVY_ABILITIES
CombatCameraController.MaxShakeDegrees = MAX_SHAKE_DEGREES
CombatCameraController.MaxShakeStuds = MAX_SHAKE_STUDS
CombatCameraController.MaxFovPunch = MAX_FOV_PUNCH

function CombatCameraController.decay(value: number, rate: number, dt: number): number
	return math.max(0, value - rate * dt)
end

-- Curva de trauma: impactos pequenos quase não mexem; os grandes disparam,
-- mas o quadrado + clamp evita que o shake saia dos limites declarados.
function CombatCameraController.shakeAmplitude(trauma: number): number
	local t = math.clamp(trauma, 0, 1)
	return t * t
end

function CombatCameraController.profileFor(outcome: string, abilityId: string?): ImpactProfile?
	local base = PROFILES[outcome]
	if not base then
		return nil
	end
	if outcome == "hit" and abilityId and HEAVY_ABILITIES[abilityId] then
		-- O Cometa é o golpe mais comprometido do kit: merece o impacto mais
		-- pesado da câmera (docs/17 §2.6). FOV 2,85 + trauma 0,6 no acerto.
		if abilityId == "comet_shoulder" then
			return {
				trauma = math.min(1, base.trauma * 1.7),
				fov = base.fov * 1.9,
			}
		end
		return {
			trauma = math.min(1, base.trauma * 1.6),
			fov = base.fov * 1.4,
		}
	end
	return base
end

function CombatCameraController.new(deps: {
	workspace: any?,
	runService: any?,
	random: (() -> number)?,
}): Controller
	return {
		workspace = deps.workspace,
		runService = deps.runService,
		random = deps.random,
		baseFov = nil,
		trauma = 0,
		fovPunch = 0,
		connection = nil,
	}
end

function CombatCameraController.addImpact(controller: Controller, outcome: string, abilityId: string?): ()
	local profile = CombatCameraController.profileFor(outcome, abilityId)
	if not profile then
		return
	end
	controller.trauma = math.min(1, controller.trauma + profile.trauma)
	controller.fovPunch = math.min(MAX_FOV_PUNCH, controller.fovPunch + profile.fov)
end

-- Avança o decaimento (puro, sem câmera) para que os testes possam validar a
-- curva sem DataModel.
function CombatCameraController.tick(controller: Controller, dt: number): ()
	controller.trauma = CombatCameraController.decay(controller.trauma, TRAUMA_DECAY, dt)
	controller.fovPunch = CombatCameraController.decay(controller.fovPunch, FOV_DECAY, dt)
end

function CombatCameraController.step(controller: Controller, dt: number): ()
	CombatCameraController.tick(controller, dt)
	local camera = if controller.workspace then controller.workspace.CurrentCamera else nil
	if not camera then
		return
	end
	if controller.baseFov == nil then
		controller.baseFov = camera.FieldOfView
	end
	local amplitude = CombatCameraController.shakeAmplitude(controller.trauma)
	if amplitude > 0 then
		local r = controller.random
		local r1 = if r then r() else math.random()
		local r2 = if r then r() else math.random()
		local r3 = if r then r() else math.random()
		local degrees = amplitude * MAX_SHAKE_DEGREES
		local studs = amplitude * MAX_SHAKE_STUDS
		camera.CFrame = camera.CFrame
			* CFrame.new((r1 * 2 - 1) * studs, (r2 * 2 - 1) * studs * 0.5, (r3 * 2 - 1) * studs)
			* CFrame.Angles(
				math.rad((r1 * 2 - 1) * degrees),
				math.rad((r2 * 2 - 1) * degrees),
				math.rad((r3 * 2 - 1) * degrees * 0.5)
			)
	end
	camera.FieldOfView = controller.baseFov + controller.fovPunch
end

function CombatCameraController.start(controller: Controller): ()
	if controller.connection or not controller.runService then
		return
	end
	controller.connection = controller.runService.RenderStepped:Connect(function(dt: number)
		CombatCameraController.step(controller, dt)
	end)
end

function CombatCameraController.stop(controller: Controller): ()
	if controller.connection then
		controller.connection:Disconnect()
		controller.connection = nil
	end
	controller.trauma = 0
	controller.fovPunch = 0
end

return CombatCameraController

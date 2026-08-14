--!strict
-- Movimento/câmera e ações universais. Magnetismo só altera apresentação da
-- mira: o cliente nunca envia alvo, acerto, dano ou distância final.

export type Controller = {
	state: any,
	input: any,
	send: (string, string, { [string]: any }) -> (),
	workspace: any?,
	players: any?,
	runService: any?,
	lockTarget: any?,
	connection: any?,
	characterAddedConnection: any?,
	now: () -> number,
}

local SOFT_LOCK_DEGREES = 8
local SOFT_LOCK_DISTANCE = 25

local CharacterController = {}

function CharacterController.new(deps: {
	state: any,
	input: any,
	inputSubscribe: (any, (string, { [string]: any }) -> ()) -> (),
	send: (string, string, { [string]: any }) -> (),
	workspace: any?,
	players: any?,
	runService: any?,
	now: (() -> number)?,
}): Controller
	local controller: Controller = {
		state = deps.state,
		input = deps.input,
		send = deps.send,
		workspace = deps.workspace,
		players = deps.players,
		runService = deps.runService,
		lockTarget = nil,
		connection = nil,
		characterAddedConnection = nil,
		now = deps.now or os.clock,
	}
	deps.inputSubscribe(deps.input, function(action: string, _payload: { [string]: any })
		CharacterController.onAction(controller, action)
	end)
	return controller
end

local function isCombatTarget(target: any?): boolean
	return target ~= nil
		and target.Parent ~= nil
		and target:IsA("BasePart")
		and target:GetAttribute("CombatTarget") == true
end

local function findAimTarget(controller: Controller, maxDistance: number, maxDegrees: number): any?
	local workspace = controller.workspace
	local camera = if workspace then workspace.CurrentCamera else nil
	if not camera then
		return nil
	end
	local best: any? = nil
	local bestAngle = maxDegrees
	local root = workspace:FindFirstChild("GreyboxF0")
	if not root then
		return nil
	end
	for _, candidate in root:GetDescendants() do
		if candidate:IsA("BasePart") and candidate:GetAttribute("CombatTarget") == true then
			local offset = candidate.Position - camera.CFrame.Position
			local distance = offset.Magnitude
			if distance > 0 and distance <= maxDistance then
				local dot = math.clamp(camera.CFrame.LookVector:Dot(offset.Unit), -1, 1)
				local angle = math.deg(math.acos(dot))
				if angle <= bestAngle then
					bestAngle = angle
					best = candidate
				end
			end
		end
	end
	return best
end

local function aimAt(controller: Controller, target: any?): ()
	local workspace = controller.workspace
	local camera = if workspace then workspace.CurrentCamera else nil
	if camera and isCombatTarget(target) then
		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.Position)
	end
end

-- Vira o CORPO do personagem para onde o jogador está mirando.
--
-- Medido no Studio em 13/08: com a câmera apontada exatamente para o
-- Estilhaço (0°), o corpo estava 122° virado para outro lado — o `AutoRotate`
-- do Humanoid só gira quem está andando. Como o servidor resolve a hitbox a
-- partir do look da HumanoidRootPart replicada, o golpe saía para trás do
-- jogador e nunca acertava nada (docs/18 §8).
--
-- Isto NÃO é mira do cliente: o cliente só orienta o próprio avatar, que é
-- estado físico que ele já possui. Quem decide alcance, alvo e dano continua
-- sendo o servidor, lendo a rotação replicada.
local function aimDirection(controller: Controller): Vector3?
	local workspace = controller.workspace
	local players = controller.players
	local player = if players then players.LocalPlayer else nil
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local direction: Vector3? = nil
	local target = controller.lockTarget
	if isCombatTarget(target) then
		direction = target.Position - root.Position
	else
		local camera = if workspace then workspace.CurrentCamera else nil
		if camera then
			direction = camera.CFrame.LookVector
		end
	end
	if not direction then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return flat.Unit
end

-- Mira DECLARADA, no formato do contrato de rede.
--
-- Até 14/08 o cliente girava o próprio corpo antes de mandar a intenção
-- (`root.CFrame = lookAt(...)`) e o servidor lia essa rotação replicada. Isso
-- fazia o personagem estalar para a direção da câmera a cada golpe e a cada
-- técnica — de costas para ela — mesmo parado, que foi a reclamação do jogador.
--
-- Declarar a mira não move autoridade nenhuma: quem escrevia aquela rotação já
-- era este mesmo cliente. A diferença é que agora a direção viaja num campo
-- validado (mesma regra do dash) em vez de sair de um efeito colateral no
-- estado físico, e o corpo fica onde o jogador deixou. Alcance, abertura, alvo
-- e dano continuam 100% no servidor.
function CharacterController.aimVector(controller: Controller): { x: number, z: number }?
	local direction = aimDirection(controller)
	if not direction then
		return nil
	end
	return { x = direction.X, z = direction.Z }
end

local function reconcileCamera(controller: Controller, character: Model): ()
	controller.lockTarget = nil
	local function assignSubject(humanoid: Humanoid): ()
		local workspace = controller.workspace
		local players = controller.players
		local player = if players then players.LocalPlayer else nil
		local camera = if workspace then workspace.CurrentCamera else nil
		if camera and player and player.Character == character and character.Parent then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		assignSubject(humanoid)
		return
	end
	task.defer(function()
		local added = character:WaitForChild("Humanoid", 5)
		if added and added:IsA("Humanoid") then
			assignSubject(added)
		end
	end)
end

local function dashDirection(controller: Controller): { [string]: any }
	local players = controller.players
	local player = if players then players.LocalPlayer else nil
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		local direction = humanoid.MoveDirection.Unit
		return { x = direction.X, z = direction.Z }
	end
	local workspace = controller.workspace
	local camera = if workspace then workspace.CurrentCamera else nil
	if camera then
		local look = camera.CFrame.LookVector
		local magnitude = math.sqrt(look.X * look.X + look.Z * look.Z)
		if magnitude > 0 then
			return { x = look.X / magnitude, z = look.Z / magnitude }
		end
	end
	return { x = 0, z = -1 }
end

function CharacterController.isLocked(controller: Controller): boolean
	return isCombatTarget(controller.lockTarget)
end

-- Solta a mira sem procurar outro alvo. O HUD usa isto no botão SOLTAR MIRA:
-- ToggleLock re-travaria se o jogador ainda estivesse olhando para o inimigo.
function CharacterController.clearLock(controller: Controller): ()
	controller.lockTarget = nil
end

function CharacterController.onAction(controller: Controller, action: string): ()
	if action == "BasicLight" or action == "BasicHeavy" then
		if controller.state.platform ~= "KeyboardMouse" then
			aimAt(controller, findAimTarget(controller, SOFT_LOCK_DISTANCE, SOFT_LOCK_DEGREES))
		end
		-- O corpo NÃO gira: a direção do golpe vai declarada no payload.
		controller.send("BasicAttackIntent", "BasicAttackIntent", {
			kind = if action == "BasicHeavy" then "heavy" else "light",
			phase = "press",
			aim = CharacterController.aimVector(controller),
		})
	elseif action == "GuardDown" or action == "GuardUp" then
		controller.send("GuardIntent", "GuardIntent", {
			phase = if action == "GuardDown" then "down" else "up",
		})
	elseif action == "Dash" then
		controller.send("DashIntent", "DashIntent", { direction = dashDirection(controller) })
	elseif action == "ToggleLock" then
		-- Segunda ativação sempre solta. A primeira só trava se houver alvo
		-- de combate à frente; senão permanece livre (não "prende no vazio").
		controller.lockTarget = if isCombatTarget(controller.lockTarget) then nil else findAimTarget(controller, 60, 35)
	end
end

function CharacterController.start(controller: Controller): ()
	local players = controller.players
	local player = if players then players.LocalPlayer else nil
	if player then
		controller.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
			reconcileCamera(controller, character)
		end)
		if player.Character then
			reconcileCamera(controller, player.Character)
		end
	end
	if controller.runService then
		controller.connection = controller.runService.RenderStepped:Connect(function()
			if controller.lockTarget and not isCombatTarget(controller.lockTarget) then
				controller.lockTarget = nil
			end
			aimAt(controller, controller.lockTarget)
		end)
	end
end

return CharacterController

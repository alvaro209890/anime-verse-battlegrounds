--!strict
-- Efeito visual local das técnicas (docs/18-ABILITY-TECHNIQUES.md §4).
--
-- Esta camada não decide nada: não escolhe alvo, não abre hitbox, não informa
-- dano e não move o personagem. Ela lê o catálogo puro de AbilityVfx e acende
-- emissores já existentes no rig local. Tudo roda no cliente do dono da ação.
--
-- Contrato de honestidade visual: camada marcada com `requiresConfirmation` só
-- acende depois de `AbilityVfxPlayer.confirm`, que por sua vez só é chamado a
-- partir de um CombatEvent do servidor. Sem isso o efeito de acerto apareceria
-- em golpe que errou.
--
-- Custo: os emissores são criados uma vez por personagem e reaproveitados
-- (docs/14 §8 — "não criar/destruir attachments a cada hit"). Trocar de
-- personagem destrói o conjunto anterior.

export type ActiveTechnique = {
	technique: any,
	startedAt: number,
	confirmed: boolean,
}

export type Player = {
	player: any,
	runService: any,
	workspace: any,
	recipes: any,
	now: () -> number,
	character: Model?,
	-- id da camada → Instance criada para ela.
	nodes: { [string]: any },
	-- id da camada de estouro → já emitiu nesta passagem. Fica fora de `nodes`
	-- de propósito: misturar marcador booleano com Instance faz a limpeza tentar
	-- destruir um booleano.
	fired: { [string]: boolean },
	attachments: { [string]: Attachment },
	active: { ActiveTechnique },
	folder: Folder?,
	connection: any?,
	characterAddedConnection: any?,
}

local AbilityVfxPlayer = {}

-- Papel declarado no catálogo → nomes de parte no rig, R15 primeiro e R6 como
-- alternativa. Papel sem parte correspondente é simplesmente ignorado: o rig
-- incompleto perde o efeito, nunca quebra a técnica.
local JOINT_PARTS: { [string]: { string } } = {
	root = { "HumanoidRootPart" },
	torso = { "UpperTorso", "Torso", "HumanoidRootPart" },
	rightUpperArm = { "RightUpperArm", "Right Arm", "UpperTorso", "Torso" },
	rightLowerArm = { "RightLowerArm", "Right Arm", "UpperTorso", "Torso" },
	leftLowerArm = { "LeftLowerArm", "Left Arm", "UpperTorso", "Torso" },
	rightHand = { "RightHand", "Right Arm", "UpperTorso", "Torso" },
	leftHand = { "LeftHand", "Left Arm", "UpperTorso", "Torso" },
}

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Textura de partícula embutida no cliente Roblox: não depende de upload nem
-- de asset do grupo, então o efeito funciona no Studio antes de qualquer
-- pipeline de arte.
local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function findPart(character: Model, role: string): BasePart?
	local candidates = JOINT_PARTS[role]
	if not candidates then
		return nil
	end
	for _, name in candidates do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function attachmentFor(vfx: Player, role: string): Attachment?
	local existing = vfx.attachments[role]
	if existing and existing.Parent then
		return existing
	end
	local character = vfx.character
	if not character then
		return nil
	end
	local part = findPart(character, role)
	if not part then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = ("AvbVfx_%s"):format(role)
	attachment.Parent = part
	vfx.attachments[role] = attachment
	return attachment
end

-- Constrói a Instance de uma camada na primeira vez que ela é pedida. Cada
-- forma é uma leitura diferente: carga concentra, rastro alonga, arco corta,
-- casca envolve, anel expande no chão.
local function buildNode(vfx: Player, entry: any): any?
	local attachment = attachmentFor(vfx, entry.joint)
	if not attachment then
		return nil
	end
	local tint = color3(entry.rgb)

	if entry.kind == "charge" or entry.kind == "shell" or entry.kind == "burst" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = ("AvbVfx_%s"):format(entry.id)
		emitter.Texture = PARTICLE_TEXTURE
		emitter.Color = ColorSequence.new(tint)
		emitter.LightEmission = 0.65
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, entry.radiusStuds * 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.18, 0.34)
		emitter.Rate = 0
		emitter.Enabled = false
		-- Casca envolve o corpo; carga e estouro projetam para fora.
		if entry.kind == "shell" then
			emitter.Speed = NumberRange.new(0.5, 1.5)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Acceleration = Vector3.new(0, 2, 0)
		else
			emitter.Speed = NumberRange.new(entry.radiusStuds * 1.5, entry.radiusStuds * 3)
			emitter.SpreadAngle = Vector2.new(35, 35)
		end
		emitter.Parent = attachment
		return emitter
	end

	if entry.kind == "trail" or entry.kind == "arc" then
		-- Trail precisa de dois pontos. O segundo fica deslocado no próprio
		-- attachment, o que basta para dar largura à fita sem tocar o rig.
		local tip = Instance.new("Attachment")
		tip.Name = ("AvbVfx_%s_tip"):format(entry.id)
		tip.Position = Vector3.new(0, entry.radiusStuds * 0.45, 0)
		tip.Parent = attachment.Parent
		local trail = Instance.new("Trail")
		trail.Name = ("AvbVfx_%s"):format(entry.id)
		trail.Attachment0 = attachment
		trail.Attachment1 = tip
		trail.Color = ColorSequence.new(tint)
		trail.LightEmission = 0.7
		trail.LightInfluence = 0
		trail.Lifetime = if entry.kind == "arc" then 0.16 else 0.26
		trail.MinLength = 0
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Enabled = false
		trail.Parent = attachment
		return trail
	end

	if entry.kind == "ring" then
		-- Onda no chão: cilindro achatado ancorado, escalado no step. Não colide,
		-- não é consultável por raycast e nunca entra na física.
		local part = Instance.new("Part")
		part.Name = ("AvbVfx_%s"):format(entry.id)
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.Material = Enum.Material.Neon
		part.Color = tint
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 1, 1)
		part.Parent = vfx.folder
		return part
	end

	return nil
end

local function nodeFor(vfx: Player, entry: any): any?
	local existing = vfx.nodes[entry.id]
	if existing and existing.Parent then
		return existing
	end
	local node = buildNode(vfx, entry)
	if node then
		vfx.nodes[entry.id] = node
	end
	return node
end

local function clearNodes(vfx: Player): ()
	for _, node in vfx.nodes do
		if node and node.Parent then
			node:Destroy()
		end
	end
	table.clear(vfx.nodes)
	table.clear(vfx.fired)
	for _, attachment in vfx.attachments do
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end
	table.clear(vfx.attachments)
end

local function attachCharacter(vfx: Player, character: Model?): ()
	if vfx.character == character then
		return
	end
	clearNodes(vfx)
	vfx.character = character
end

function AbilityVfxPlayer.new(deps: {
	player: any,
	runService: any?,
	workspace: any?,
	recipes: any,
	now: (() -> number)?,
	folder: Folder?,
}): Player
	return {
		player = deps.player,
		runService = deps.runService,
		workspace = deps.workspace,
		recipes = deps.recipes,
		now = deps.now or os.clock,
		character = nil,
		nodes = {},
		fired = {},
		attachments = {},
		active = {},
		folder = deps.folder,
		connection = nil,
		characterAddedConnection = nil,
	}
end

-- Começa o efeito de uma ação do animador. Ação sem receita simplesmente não
-- produz efeito — golpes básicos continuam limpos de propósito.
function AbilityVfxPlayer.play(vfx: Player, action: string): boolean
	local technique = vfx.recipes.forAction(action)
	if not technique then
		return false
	end
	-- Reativar a mesma técnica reinicia a linha do tempo em vez de empilhar.
	for index, entry in vfx.active do
		if entry.technique.action == action then
			table.remove(vfx.active, index)
			break
		end
	end
	table.insert(vfx.active, {
		technique = technique,
		startedAt = vfx.now(),
		confirmed = false,
	})
	return true
end

-- Desfechos que autorizam efeito de contato. "miss" e qualquer razão de
-- rejeição ficam de fora de propósito: sem impacto real não há brilho.
local CONFIRMING_OUTCOMES: { [string]: boolean } = {
	hit = true,
	guard = true,
	counter = true,
	death = true,
}

-- Desfecho autoritativo chegou. Só a partir daqui as camadas de acerto podem
-- desenhar. Casa por `abilityId` (não por ação) porque uma mesma habilidade tem
-- mais de uma ação — Cadência e seu eco compartilham o id no CombatEvent.
function AbilityVfxPlayer.confirm(vfx: Player, abilityId: string?, outcome: string?): boolean
	if type(abilityId) ~= "string" or not CONFIRMING_OUTCOMES[outcome or ""] then
		return false
	end
	local matched = false
	for _, entry in vfx.active do
		if entry.technique.abilityId == abilityId then
			entry.confirmed = true
			matched = true
		end
	end
	return matched
end

-- Plano puro do instante: técnicas ativas + camadas acesas. Exposto para teste
-- headless — a mesma entrada sempre produz a mesma lista.
export type PlannedNode = { id: string, intensity: number, layer: any }

function AbilityVfxPlayer.plan(vfx: Player, now: number): { PlannedNode }
	local out: { PlannedNode } = {}
	for _, entry in vfx.active do
		local elapsed = now - entry.startedAt
		for _, planned in vfx.recipes.planAt(entry.technique, elapsed, entry.confirmed) do
			table.insert(out, {
				id = planned.layer.id,
				intensity = planned.intensity,
				layer = planned.layer,
			})
		end
	end
	return out
end

-- Remove técnicas cuja janela já passou por completo.
local function pruneExpired(vfx: Player, now: number): ()
	for index = #vfx.active, 1, -1 do
		local entry = vfx.active[index]
		if now - entry.startedAt > entry.technique.actionDurationSeconds then
			table.remove(vfx.active, index)
		end
	end
end

-- O anel cresce mesmo quando a intensidade já está caindo: onda que encolhe no
-- fim parece sugada de volta, e não dispersada.
local function ringRadiusFactor(intensity: number): number
	return 0.35 + (1 - intensity) * 0.65
end

AbilityVfxPlayer.ringRadiusFactor = ringRadiusFactor

local function applyNode(vfx: Player, planned: PlannedNode): ()
	local entry = planned.layer
	local node = nodeFor(vfx, entry)
	if not node then
		return
	end
	local intensity = planned.intensity
	if entry.kind == "charge" or entry.kind == "shell" then
		node.Enabled = true
		node.Rate = entry.rate * intensity
	elseif entry.kind == "burst" then
		-- Estouro é disparo único: emite na subida e não fica ligado.
		node.Enabled = false
		if not vfx.fired[entry.id] then
			vfx.fired[entry.id] = true
			node:Emit(math.max(8, math.floor(entry.radiusStuds * 10)))
		end
	elseif entry.kind == "trail" or entry.kind == "arc" then
		node.Enabled = true
	elseif entry.kind == "ring" then
		local character = vfx.character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local radius = entry.radiusStuds * ringRadiusFactor(intensity)
			node.Size = Vector3.new(0.2, radius * 2, radius * 2)
			node.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
			node.Transparency = 1 - intensity * 0.75
		end
	end
end

local function silence(vfx: Player, lit: { [string]: boolean }): ()
	for id, node in vfx.nodes do
		if node.Parent and not lit[id] then
			if node:IsA("ParticleEmitter") then
				node.Enabled = false
				node.Rate = 0
			elseif node:IsA("Trail") then
				node.Enabled = false
			elseif node:IsA("BasePart") then
				node.Transparency = 1
			end
		end
	end
end

function AbilityVfxPlayer.step(vfx: Player): ()
	local now = vfx.now()
	pruneExpired(vfx, now)

	local character = vfx.player.Character
	if character ~= vfx.character then
		attachCharacter(vfx, character)
	end
	if not vfx.character or not vfx.character.Parent then
		return
	end

	local lit: { [string]: boolean } = {}
	for _, planned in AbilityVfxPlayer.plan(vfx, now) do
		lit[planned.id] = true
		applyNode(vfx, planned)
	end
	silence(vfx, lit)

	-- O marcador de estouro só vale enquanto a camada está acesa: apagou, pode
	-- estourar de novo na próxima ativação da técnica.
	for id in vfx.fired do
		if not lit[id] then
			vfx.fired[id] = nil
		end
	end
end

function AbilityVfxPlayer.start(vfx: Player): ()
	if vfx.connection or not vfx.runService then
		return
	end
	if not vfx.folder and vfx.workspace then
		-- Pasta local sob a câmera: nada aqui replica, e sai junto com o cliente.
		local folder = Instance.new("Folder")
		folder.Name = "AvbAbilityVfx"
		folder.Parent = vfx.workspace.CurrentCamera
		vfx.folder = folder
	end
	vfx.characterAddedConnection = vfx.player.CharacterAdded:Connect(function(character: Model)
		attachCharacter(vfx, character)
	end)
	attachCharacter(vfx, vfx.player.Character)
	vfx.connection = vfx.runService.Heartbeat:Connect(function()
		AbilityVfxPlayer.step(vfx)
	end)
end

function AbilityVfxPlayer.stop(vfx: Player): ()
	if vfx.connection then
		vfx.connection:Disconnect()
		vfx.connection = nil
	end
	if vfx.characterAddedConnection then
		vfx.characterAddedConnection:Disconnect()
		vfx.characterAddedConnection = nil
	end
	clearNodes(vfx)
	table.clear(vfx.active)
	if vfx.folder then
		vfx.folder:Destroy()
		vfx.folder = nil
	end
	vfx.character = nil
end

return AbilityVfxPlayer

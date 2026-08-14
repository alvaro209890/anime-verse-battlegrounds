-- VFX local das habilidades de NPC. Só apresenta eventos confirmados pelo servidor;
-- não decide dano, alvo, alcance ou cooldown.

export type EnemyEvent = {
	kind: string,
	startedAt: number,
	durationSeconds: number,
	abilityId: string?,
	visualPattern: string?,
	fired: boolean,
}

export type Player = {
	workspace: any,
	runService: any,
	recipes: any,
	assets: any,
	npcs: any?,
	now: () -> number,
	events: { [string]: EnemyEvent },
	folders: { [string]: Folder },
	connection: any?,
}

local EnemyVfxPlayer = {}

local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function color3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function actorModel(workspace: any, fighterId: string): Model?
	local world = workspace:FindFirstChild("GreyboxF0")
	local actors = if world then world:FindFirstChild("Actors") else nil
	if not actors then
		return nil
	end
	for _, child in actors:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ActorId") == fighterId then
			return child
		end
	end
	return nil
end

local function hostPart(model: Model): BasePart?
	for _, name in { "VisualRoot", "Root", "HumanoidRootPart", "Torso" } do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function ensureFolder(player: Player, fighterId: string, model: Model): Folder?
	local existing = player.folders[fighterId]
	if existing and existing.Parent then
		return existing
	end
	local folder = model:FindFirstChild("EnemyAbilityVfx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnemyAbilityVfx"
		folder.Parent = model
	end
	player.folders[fighterId] = folder :: Folder
	return folder :: Folder
end

local function configureEmitter(emitter: ParticleEmitter, ability: any, assets: any): ()
	local asset = assets.get(ability.assetKey)
	emitter.Texture = PARTICLE_TEXTURE
	if asset and type(asset.assetId) == "string" and string.match(asset.assetId, "^rbxassetid://%d+$") then
		emitter.Texture = asset.assetId
	end
	emitter.Color = ColorSequence.new(color3(ability.color))
	emitter.LightEmission = 0.75
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(0, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.18, 0.32)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function ensureNodes(
	player: Player,
	fighterId: string,
	model: Model,
	ability: any
): (ParticleEmitter?, PointLight?)
	local folder = ensureFolder(player, fighterId, model)
	local host = hostPart(model)
	if not folder or not host then
		return nil, nil
	end
	local attachment = folder:FindFirstChild("AbilityAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "AbilityAttachment"
		attachment.Parent = host
	end
	local emitter = attachment:FindFirstChild("AbilityEmitter")
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "AbilityEmitter"
		emitter.Parent = attachment
	end
	configureEmitter(emitter :: ParticleEmitter, ability, player.assets)
	local light = attachment:FindFirstChild("AbilityLight")
	if not light then
		light = Instance.new("PointLight")
		light.Name = "AbilityLight"
		light.Shadows = false
		light.Parent = attachment
	end
	(light :: PointLight).Color = color3(ability.color)
	return emitter :: ParticleEmitter, light :: PointLight
end

function EnemyVfxPlayer.new(deps: {
	workspace: any,
	runService: any,
	recipes: any,
	assets: any,
	npcs: any?,
	now: (() -> number)?,
}): Player
	return {
		workspace = deps.workspace,
		runService = deps.runService,
		recipes = deps.recipes,
		assets = deps.assets,
		npcs = deps.npcs,
		now = deps.now or os.clock,
		events = {},
		folders = {},
		connection = nil,
	}
end

-- Alcance honesto da luz de ataque (docs/17 — honestidade visual): nunca
-- maior que a hitbox real do NPC (NpcDef.attackRange: errante 4, ancorado 8).
-- Função pura para ser travada por teste.
function EnemyVfxPlayer.rangeFor(npcDef: any): number
	if npcDef and type(npcDef.attackRange) == "number" then
		return math.max(0, npcDef.attackRange)
	end
	return 8
end

function EnemyVfxPlayer.onEnemyEvent(player: Player, payload: { [string]: any }): ()
	local fighterId = payload.fighterId
	if type(fighterId) ~= "string" then
		return
	end
	local duration = if type(payload.durationSeconds) == "number" then payload.durationSeconds else 0.35
	player.events[fighterId] = {
		kind = if type(payload.kind) == "string" then payload.kind else "attack",
		startedAt = player.now(),
		durationSeconds = math.max(0.1, duration),
		abilityId = if type(payload.abilityId) == "string" then payload.abilityId else nil,
		visualPattern = if type(payload.visualPattern) == "string" then payload.visualPattern else nil,
		fired = false,
	}
end

function EnemyVfxPlayer.step(player: Player): ()
	local now = player.now()
	for fighterId, event in player.events do
		local model = actorModel(player.workspace, fighterId)
		local ability = player.recipes.forEvent(model and model:GetAttribute("NpcId") or "", event.visualPattern)
		if model and ability then
			local emitter, light = ensureNodes(player, fighterId, model, ability)
			if emitter and light then
				-- Honestidade visual (docs/17): a luz nunca excede a hitbox real
				-- do NPC (NpcDef.attackRange — errante 4, ancorado 8). Antes o
				-- Range era fixo (12/8 telegraph, 16/10 ataque) e "mentia" sobre
				-- o alcance do golpe.
				local npcDef = if player.npcs then player.npcs.get(tostring(model:GetAttribute("NpcId") or "")) else nil
				local honestRange = EnemyVfxPlayer.rangeFor(npcDef)
				local progress = math.clamp((now - event.startedAt) / event.durationSeconds, 0, 1)
				if event.kind == "telegraph" then
					emitter.Enabled = true
					emitter.Rate = 10
					light.Brightness = 1.1 + math.sin(progress * math.pi) * 1.4
					light.Range = honestRange
				elseif event.kind == "attack" then
					emitter.Enabled = false
					light.Brightness = 2.8 * (1 - progress)
					light.Range = honestRange
					if not event.fired then
						event.fired = true
						emitter:Emit(if event.visualPattern == "slam" then 26 else 14)
					end
				else
					emitter.Enabled = false
					light.Brightness = 0
				end
			end
		end
		if now - event.startedAt > event.durationSeconds then
			local folder = player.folders[fighterId]
			if folder and folder.Parent then
				local attachment = folder:FindFirstChild("AbilityAttachment")
				local emitter = if attachment then attachment:FindFirstChild("AbilityEmitter") else nil
				local light = if attachment then attachment:FindFirstChild("AbilityLight") else nil
				if emitter and emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
					emitter.Rate = 0
				end
				if light and light:IsA("PointLight") then
					light.Brightness = 0
				end
			end
			player.events[fighterId] = nil
		end
	end
end

function EnemyVfxPlayer.start(player: Player): ()
	if player.connection then
		return
	end
	player.connection = player.runService.PreSimulation:Connect(function()
		EnemyVfxPlayer.step(player)
	end)
end

function EnemyVfxPlayer.stop(player: Player): ()
	if player.connection then
		player.connection:Disconnect()
		player.connection = nil
	end
	table.clear(player.events)
	table.clear(player.folders)
end

return EnemyVfxPlayer

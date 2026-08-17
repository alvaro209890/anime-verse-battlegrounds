--!strict
-- HUD de combate local: números de dano flutuantes (desfecho confirmado) e
-- barras de vida dos inimigos (StateDelta com fighterId). Tudo apresentação —
-- nenhum valor de combate nasce aqui, o servidor continua autoritativo.
--
-- Número de dano: só aparece com `damage > 0` num CombatEvent (hit/guard/
-- counter/death). O dano do alvo inimigo também atualiza a barra dele.
--
-- Barra: criada no primeiro StateDelta {fighterId, health, maxHealth} do
-- inimigo, some com fade quando a vida zera (morte) e é recriada no respawn.

export type BarEntry = {
	gui: any,
	fill: any,
	label: any,
	dying: boolean,
}

export type Controller = {
	player: any,
	workspace: any,
	players: any?,
	now: (() -> number)?,
	bars: { [string]: BarEntry },
	modelCache: { [string]: any },
	folder: Folder?,
}

local function loadUiPalette(): any
	local ok, mod = pcall(function()
		return require("../../shared/Data/UiPalette")
	end)
	if ok then
		return mod
	end
	return require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("UiPalette")
	)
end

local UiPalette = loadUiPalette()

local CombatHudController = {}

local SHOW_OUTCOMES: { [string]: boolean } = {
	hit = true,
	guard = true,
	counter = true,
	death = true,
}

-- Funções puras (testáveis sem DataModel) ───────────────────────────────────

-- Um CombatEvent vira número de dano? Só desfecho com dano positivo, e só
-- para quem aplicou o golpe. Quem apanha (`view = "taken"`) sente câmera/som
-- mas não inventa o número — o HP dele chega no StateDelta.
function CombatHudController.shouldShowDamage(payload: { [string]: any }): boolean
	if payload.view == "taken" then
		return false
	end
	return SHOW_OUTCOMES[payload.outcome or ""] == true and type(payload.damage) == "number" and payload.damage > 0
end

-- Cor do número por desfecho: acerto branco, guarda azul (dano reduzido),
-- contra âmbar, morte vermelho. Retorna RGB puro (testável fora do Studio;
-- a materialização converte com Color3.fromRGB).
function CombatHudController.damageColor(outcome: string?): { number }
	return UiPalette.damageColor(outcome)
end

function CombatHudController.barFraction(health: number, maxHealth: number): number
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(health / maxHealth, 0, 1)
end

-- Popup de XP: o servidor manda o valor já creditado. Mesma regra do dano —
-- cliente não inventa quantidade.
function CombatHudController.shouldShowXp(payload: { [string]: any }): boolean
	if payload.view == "taken" then
		return false
	end
	local amount = payload.amount
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	return true
end

function CombatHudController.xpColor(): { number }
	return UiPalette.xpColor()
end

function CombatHudController.xpText(amount: number): string
	return ("+%d XP"):format(math.floor(amount))
end

-- Estado e ciclo de vida ─────────────────────────────────────────────────────

function CombatHudController.new(deps: {
	player: any,
	workspace: any,
	players: any?,
	now: (() -> number)?,
}): Controller
	return {
		player = deps.player,
		workspace = deps.workspace,
		players = deps.players,
		now = deps.now or os.clock,
		bars = {},
		modelCache = {},
		folder = nil,
	}
end

-- Modelo do mundo cujo ActorId é o fighterId (cache com invalidação por Parent).
function CombatHudController.modelFor(hud: Controller, fighterId: string): Model?
	local cached = hud.modelCache[fighterId]
	if cached and cached.Parent then
		return cached
	end
	hud.modelCache[fighterId] = nil
	local world = hud.workspace:FindFirstChild("GreyboxF0")
	local actors = if world then world:FindFirstChild("Actors") else nil
	if not actors then
		return nil
	end
	for _, child in actors:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ActorId") == fighterId then
			hud.modelCache[fighterId] = child
			return child
		end
	end
	-- Outro jogador não vive em Actors: o número ancora no Character replicado.
	local userIdText = string.match(fighterId, "^player:(%d+)$")
	local players = hud.players
	if userIdText and players and type(players.GetPlayers) == "function" then
		local userId = tonumber(userIdText)
		for _, other in players:GetPlayers() do
			if other.UserId == userId and other.Character then
				hud.modelCache[fighterId] = other.Character
				return other.Character
			end
		end
	end
	return nil
end

-- Número de dano flutuante: BillboardGui no alvo, sobe e some em 0,8 s.
function CombatHudController.spawnDamage(hud: Controller, payload: { [string]: any }): ()
	local targetId = payload.targetId
	local model = if type(targetId) == "string" then CombatHudController.modelFor(hud, targetId) else nil
	local adornee: Instance? = model
	local offset = 2.4
	if not adornee then
		-- Sem modelo do alvo (ex.: outro jogador longe), ancora na própria tela.
		adornee = hud.player:WaitForChild("PlayerGui")
		offset = 0
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AvbDamage"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Active = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Size = UDim2.fromOffset(92, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(payload.damage)
	local rgb = CombatHudController.damageColor(payload.outcome)
	label.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(UiPalette.ink[1], UiPalette.ink[2], UiPalette.ink[3])
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = adornee
	-- Sobe e desvanece; depois se destrói sozinho.
	task.spawn(function()
		local tweenService = game:GetService("TweenService")
		tweenService
			:Create(
				gui,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ StudsOffsetWorldSpace = Vector3.new(0, offset + 2.6, 0) }
			)
			:Play()
		tweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Linear), { TextTransparency = 1 }):Play()
		task.wait(0.8)
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Barra de vida do inimigo: BillboardGui com track/fill/texto.
function CombatHudController.spawnBar(hud: Controller, fighterId: string): BarEntry?
	local model = CombatHudController.modelFor(hud, fighterId)
	if not model then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AvbEnemyBar"
	gui.Adornee = model
	gui.AlwaysOnTop = true
	gui.Active = false
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	gui.Size = UDim2.fromOffset(128, 18)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(UiPalette.ink[1], UiPalette.ink[2], UiPalette.ink[3])
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 5)
	trackCorner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local startFill = UiPalette.enemyFill(1, false)
	fill.BackgroundColor3 = Color3.fromRGB(startFill[1], startFill[2], startFill[3])
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(UiPalette.text[1], UiPalette.text[2], UiPalette.text[3])
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(UiPalette.ink[1], UiPalette.ink[2], UiPalette.ink[3])
	label.TextStrokeTransparency = 0
	label.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	label.Parent = track
	track.Parent = gui
	gui.Parent = model
	local entry: BarEntry = { gui = gui, fill = fill, label = label, dying = false }
	hud.bars[fighterId] = entry
	return entry
end

-- StateDelta {fighterId, health, maxHealth} do servidor.
function CombatHudController.onFighterDelta(hud: Controller, payload: { [string]: any }): ()
	if type(payload.fighterId) ~= "string" then
		return
	end
	local health = payload.health
	local maxHealth = payload.maxHealth
	if type(health) ~= "number" or type(maxHealth) ~= "number" then
		return
	end
	local entry = hud.bars[payload.fighterId]
	if not entry or not entry.gui.Parent then
		entry = CombatHudController.spawnBar(hud, payload.fighterId)
	end
	if not entry then
		return
	end
	local fraction = CombatHudController.barFraction(health, maxHealth)
	entry.fill.Size = UDim2.fromScale(fraction, 1)
	entry.label.Text = ("%d/%d"):format(math.max(0, math.floor(health + 0.5)), maxHealth)
	local model = CombatHudController.modelFor(hud, payload.fighterId)
	local npcId = if model then model:GetAttribute("NpcId") else nil
	local elite = npcId == "enemy_anchored_shard"
	local fillRgb = UiPalette.enemyFill(fraction, elite == true)
	entry.fill.BackgroundColor3 = Color3.fromRGB(fillRgb[1], fillRgb[2], fillRgb[3])
	if health <= 0 and not entry.dying then
		entry.dying = true
		task.spawn(function()
			-- BillboardGui NÃO tem propriedade Transparency (erro no Output e o
			-- thread morria antes de Destroy — barra ficava em 0/60 para sempre).
			local tweenService = game:GetService("TweenService")
			local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			pcall(function()
				tweenService:Create(entry.gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) }):Play()
			end)
			local track = entry.gui:FindFirstChild("Track")
			if track and track:IsA("GuiObject") then
				tweenService:Create(track, info, { BackgroundTransparency = 1 }):Play()
			end
			if entry.fill and entry.fill.Parent then
				tweenService:Create(entry.fill, info, { BackgroundTransparency = 1 }):Play()
			end
			if entry.label and entry.label.Parent then
				tweenService:Create(entry.label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
			task.wait(0.45)
			if entry.gui and entry.gui.Parent then
				entry.gui:Destroy()
			end
			hud.bars[payload.fighterId] = nil
		end)
	end
end

-- CombatEvent confirmado: número de dano (e o delta de vida já vem à parte).
function CombatHudController.onCombatEvent(hud: Controller, payload: { [string]: any }): ()
	if CombatHudController.shouldShowDamage(payload) then
		CombatHudController.spawnDamage(hud, payload)
	end
end

-- Número de XP flutuante: mesmo ancoradouro do dano, um pouco mais alto e dourado.
function CombatHudController.spawnXp(hud: Controller, payload: { [string]: any }): ()
	if not CombatHudController.shouldShowXp(payload) then
		return
	end
	local targetId = payload.targetId
	local model = if type(targetId) == "string" then CombatHudController.modelFor(hud, targetId) else nil
	local adornee: Instance? = model
	local offset = 3.2
	if not adornee then
		adornee = hud.player:FindFirstChild("PlayerGui") or hud.player:WaitForChild("PlayerGui")
		offset = 0
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AvbXp"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Active = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Size = UDim2.fromOffset(96, 32)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = CombatHudController.xpText(payload.amount)
	local rgb = CombatHudController.xpColor()
	label.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(28, 22, 8)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = adornee
	task.spawn(function()
		local tweenService = game:GetService("TweenService")
		tweenService
			:Create(
				gui,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ StudsOffsetWorldSpace = Vector3.new(0.4, offset + 2.8, 0) }
			)
			:Play()
		tweenService:Create(label, TweenInfo.new(0.95, Enum.EasingStyle.Linear), { TextTransparency = 1 }):Play()
		task.wait(0.95)
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

return CombatHudController

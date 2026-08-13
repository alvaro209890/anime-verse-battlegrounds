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
	now: (() -> number)?,
	bars: { [string]: BarEntry },
	modelCache: { [string]: any },
	folder: Folder?,
}

local CombatHudController = {}

local SHOW_OUTCOMES: { [string]: boolean } = {
	hit = true,
	guard = true,
	counter = true,
	death = true,
}

-- Funções puras (testáveis sem DataModel) ───────────────────────────────────

-- Um CombatEvent vira número de dano? Só desfecho com dano positivo.
function CombatHudController.shouldShowDamage(payload: { [string]: any }): boolean
	return SHOW_OUTCOMES[payload.outcome or ""] == true and type(payload.damage) == "number" and payload.damage > 0
end

-- Cor do número por desfecho: acerto branco, guarda azul (dano reduzido),
-- contra âmbar, morte vermelho. Retorna RGB puro (testável fora do Studio;
-- a materialização converte com Color3.fromRGB).
function CombatHudController.damageColor(outcome: string?): { number }
	if outcome == "guard" then
		return { 150, 190, 255 }
	elseif outcome == "counter" then
		return { 255, 200, 120 }
	elseif outcome == "death" then
		return { 255, 90, 90 }
	end
	return { 255, 255, 255 }
end

function CombatHudController.barFraction(health: number, maxHealth: number): number
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(health / maxHealth, 0, 1)
end

-- Estado e ciclo de vida ─────────────────────────────────────────────────────

function CombatHudController.new(deps: {
	player: any,
	workspace: any,
	now: (() -> number)?,
}): Controller
	return {
		player = deps.player,
		workspace = deps.workspace,
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
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Size = UDim2.fromOffset(80, 34)
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
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 28)
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
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	gui.Size = UDim2.fromOffset(120, 16)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(224, 120, 80)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
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
	entry.fill.Size = UDim2.fromScale(CombatHudController.barFraction(health, maxHealth), 1)
	entry.label.Text = ("%d/%d"):format(math.max(0, math.floor(health + 0.5)), maxHealth)
	entry.fill.BackgroundColor3 = if health / math.max(1, maxHealth) <= 0.25
		then Color3.fromRGB(255, 80, 70)
		else (if health / math.max(1, maxHealth) <= 0.5
			then Color3.fromRGB(240, 190, 70)
			else Color3.fromRGB(224, 120, 80))
	if health <= 0 and not entry.dying then
		entry.dying = true
		task.spawn(function()
			local tweenService = game:GetService("TweenService")
			tweenService
				:Create(
					entry.gui,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) }
				)
				:Play()
			tweenService:Create(entry.gui, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			task.wait(0.45)
			if entry.gui.Parent then
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

return CombatHudController

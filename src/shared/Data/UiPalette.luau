--!strict
-- Paleta semântica da UI. Uma fonte só: HUD, hotbar, dano, faixas e painéis
-- leem daqui. RGB puro (Lune não tem Color3). Sem Instances.

export type Rgb = { number }

local function rgb(r: number, g: number, b: number): Rgb
	return { r, g, b }
end

local UiPalette = {
	ink = rgb(10, 12, 22),
	panel = rgb(18, 16, 36),
	panelRaised = rgb(34, 28, 58),
	stroke = rgb(80, 220, 255),
	strokeAccent = rgb(184, 142, 255),
	text = rgb(244, 242, 255),
	muted = rgb(168, 164, 196),
	health = rgb(70, 230, 120),
	healthGhost = rgb(220, 64, 86),
	guard = rgb(80, 200, 255),
	guardGhost = rgb(90, 110, 180),
	resource = rgb(184, 142, 255),
	xp = rgb(255, 214, 96),
	danger = rgb(255, 80, 90),
	warning = rgb(255, 190, 70),
	safe = rgb(64, 196, 160),
	pvp = rgb(255, 86, 112),
	highlight = rgb(220, 70, 180),
	slot = rgb(22, 20, 42),
	slotReady = rgb(80, 220, 255),
	slotLocked = rgb(48, 46, 62),
	enemyHealth = rgb(224, 120, 80),
	enemyElite = rgb(220, 56, 72),
	enemyLow = rgb(255, 80, 70),
	enemyMid = rgb(240, 190, 70),
	-- Travados pelos testes de HUD (docs/17): não mudar sem atualizar a suíte.
	damageHit = rgb(255, 255, 255),
	damageGuard = rgb(150, 190, 255),
	damageCounter = rgb(255, 200, 120),
	damageDeath = rgb(255, 90, 90),
	xpPopup = rgb(255, 214, 96),
	levelFlash = rgb(255, 214, 110),
	levelTitle = rgb(255, 244, 200),
}

function UiPalette.damageColor(outcome: string?): Rgb
	if outcome == "guard" then
		return UiPalette.damageGuard
	elseif outcome == "counter" then
		return UiPalette.damageCounter
	elseif outcome == "death" then
		return UiPalette.damageDeath
	end
	return UiPalette.damageHit
end

function UiPalette.xpColor(): Rgb
	return UiPalette.xpPopup
end

function UiPalette.enemyFill(fraction: number, elite: boolean): Rgb
	if elite then
		return UiPalette.enemyElite
	end
	if fraction <= 0.25 then
		return UiPalette.enemyLow
	end
	if fraction <= 0.5 then
		return UiPalette.enemyMid
	end
	return UiPalette.enemyHealth
end

function UiPalette.zoneFill(pvp: boolean): Rgb
	return if pvp then UiPalette.pvp else UiPalette.safe
end

-- Atraso visual da barra de "dano recente": só decai rumo ao valor atual.
function UiPalette.ghostFraction(current: number, ghost: number, dt: number, speed: number): number
	local cur = math.clamp(current, 0, 1)
	local g = math.clamp(ghost, 0, 1)
	if g <= cur then
		return cur
	end
	return math.max(cur, g - math.max(0, dt) * math.max(0, speed))
end

local NAMED: { string } = {
	"ink",
	"panel",
	"panelRaised",
	"stroke",
	"strokeAccent",
	"text",
	"muted",
	"health",
	"healthGhost",
	"guard",
	"guardGhost",
	"resource",
	"xp",
	"danger",
	"warning",
	"safe",
	"pvp",
	"highlight",
	"slot",
	"slotReady",
	"slotLocked",
	"enemyHealth",
	"enemyElite",
	"enemyLow",
	"enemyMid",
	"damageHit",
	"damageGuard",
	"damageCounter",
	"damageDeath",
	"xpPopup",
	"levelFlash",
	"levelTitle",
}

local function validRgb(value: any): boolean
	if type(value) ~= "table" or #value ~= 3 then
		return false
	end
	for i = 1, 3 do
		local channel = value[i]
		if type(channel) ~= "number" or channel ~= channel or channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end

function UiPalette.validate(): (boolean, string?)
	for _, key in NAMED do
		if not validRgb((UiPalette :: any)[key]) then
			return false, "cor inválida: " .. key
		end
	end
	if UiPalette.ghostFraction(0.4, 0.8, 0.1, 1) >= 0.8 then
		return false, "ghost não decai"
	end
	if UiPalette.ghostFraction(0.5, 0.4, 1, 2) ~= 0.5 then
		return false, "ghost não pode ficar abaixo do atual"
	end
	return true, nil
end

return UiPalette

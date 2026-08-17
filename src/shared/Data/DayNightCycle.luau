--!strict
-- Ciclo dia/noite F0 — dados puros e amostragem testável fora do Studio.
--
-- O servidor materializa o sample em Lighting (WorldService). Aqui só vivem
-- keyframes, duração do ciclo e interpolação. Sem Color3, sem Instance: Lune
-- valida o arco visual (meia-noite → amanhecer → meio-dia → crepúsculo → noite)
-- e o orçamento de brilho/luz artificial.
--
-- Direção visual (Anime Verse):
--   * Dia limpo com céu frio ciano, sem matar o tom umbral do Bastião.
--   * Amanhecer/pôr do sol com rosa-âmbar e violeta — o "momento bonito".
--   * Noite profunda índigo/violeta; as PointLights do spawn e as tochas da
--     planície sobem (artificialLightScale) e viram a leitura da sala.
--   * O crepúsculo ~18,25 (antigo fixo) continua no arco, agora como fase.

export type Rgb = { number }

export type LightingSample = {
	clockTime: number,
	brightness: number,
	ambientRgb: Rgb,
	outdoorAmbientRgb: Rgb,
	colorShiftTopRgb: Rgb,
	colorShiftBottomRgb: Rgb,
	atmosphereColorRgb: Rgb,
	atmosphereDecayRgb: Rgb,
	atmosphereDensity: number,
	atmosphereGlare: number,
	atmosphereHaze: number,
	bloomIntensity: number,
	bloomSize: number,
	bloomThreshold: number,
	ccBrightness: number,
	ccContrast: number,
	ccSaturation: number,
	ccTintRgb: Rgb,
	starCount: number,
	sunAngularSize: number,
	moonAngularSize: number,
	exposureCompensation: number,
	-- 0 = só sol; 1 = orçamento base do spawn; >1 = noite com glow de tocha.
	artificialLightScale: number,
}

export type Keyframe = {
	id: string,
	hour: number,
	sample: LightingSample,
}

export type Config = {
	-- Segundos reais para um dia completo (0→24h). 600 s = 10 min de sessão.
	cycleSeconds: number,
	-- Hora de jogo em que o servidor começa (0–24).
	startHour: number,
	geographicLatitude: number,
}

local CONFIG: Config = {
	-- 600 s = 10 min reais por dia de jogo (baseline de produção).
	cycleSeconds = 600,
	-- Começa no amanhecer: o primeiro minuto já mostra o arco dourado.
	startHour = 5.75,
	geographicLatitude = 18,
}

-- Keyframes ordenados por `hour`. Cores em sRGB 0–255. Valores de atmosfera
-- e bloom são o "feeling" do F0 — não o look final de marketing (Gate P1).
local KEYFRAMES: { Keyframe } = {
	{
		id = "midnight",
		hour = 0,
		sample = {
			clockTime = 0,
			brightness = 0.55,
			ambientRgb = { 18, 20, 42 },
			outdoorAmbientRgb = { 22, 26, 58 },
			colorShiftTopRgb = { 96, 120, 220 },
			colorShiftBottomRgb = { 72, 48, 140 },
			atmosphereColorRgb = { 48, 56, 110 },
			atmosphereDecayRgb = { 14, 12, 36 },
			atmosphereDensity = 0.32,
			atmosphereGlare = 0.04,
			atmosphereHaze = 1.6,
			bloomIntensity = 0.55,
			bloomSize = 28,
			bloomThreshold = 0.78,
			ccBrightness = -0.04,
			ccContrast = 0.08,
			ccSaturation = 0.12,
			ccTintRgb = { 210, 215, 255 },
			starCount = 3200,
			sunAngularSize = 8,
			moonAngularSize = 14,
			exposureCompensation = -0.35,
			artificialLightScale = 1.45,
		},
	},
	{
		id = "predawn",
		hour = 5.0,
		sample = {
			clockTime = 5.0,
			brightness = 0.9,
			ambientRgb = { 36, 40, 72 },
			outdoorAmbientRgb = { 48, 52, 88 },
			colorShiftTopRgb = { 140, 150, 220 },
			colorShiftBottomRgb = { 110, 80, 160 },
			atmosphereColorRgb = { 90, 96, 150 },
			atmosphereDecayRgb = { 40, 32, 70 },
			atmosphereDensity = 0.28,
			atmosphereGlare = 0.08,
			atmosphereHaze = 1.35,
			bloomIntensity = 0.4,
			bloomSize = 24,
			bloomThreshold = 0.82,
			ccBrightness = -0.02,
			ccContrast = 0.05,
			ccSaturation = 0.08,
			ccTintRgb = { 220, 220, 255 },
			starCount = 1800,
			sunAngularSize = 12,
			moonAngularSize = 11,
			exposureCompensation = -0.15,
			artificialLightScale = 1.15,
		},
	},
	{
		id = "dawn",
		hour = 6.4,
		sample = {
			clockTime = 6.4,
			brightness = 1.55,
			ambientRgb = { 72, 62, 78 },
			outdoorAmbientRgb = { 110, 88, 96 },
			colorShiftTopRgb = { 255, 176, 140 },
			colorShiftBottomRgb = { 210, 120, 180 },
			atmosphereColorRgb = { 255, 190, 170 },
			atmosphereDecayRgb = { 90, 60, 100 },
			atmosphereDensity = 0.22,
			atmosphereGlare = 0.22,
			atmosphereHaze = 1.15,
			bloomIntensity = 0.48,
			bloomSize = 26,
			bloomThreshold = 0.8,
			ccBrightness = 0.03,
			ccContrast = 0.06,
			ccSaturation = 0.18,
			ccTintRgb = { 255, 230, 220 },
			starCount = 200,
			sunAngularSize = 18,
			moonAngularSize = 8,
			exposureCompensation = 0.05,
			artificialLightScale = 0.55,
		},
	},
	{
		id = "morning",
		hour = 9.0,
		sample = {
			clockTime = 9.0,
			brightness = 2.2,
			ambientRgb = { 96, 104, 120 },
			outdoorAmbientRgb = { 130, 148, 170 },
			colorShiftTopRgb = { 170, 210, 255 },
			colorShiftBottomRgb = { 180, 170, 220 },
			atmosphereColorRgb = { 170, 200, 235 },
			atmosphereDecayRgb = { 70, 90, 130 },
			atmosphereDensity = 0.14,
			atmosphereGlare = 0.14,
			atmosphereHaze = 0.55,
			bloomIntensity = 0.22,
			bloomSize = 18,
			bloomThreshold = 0.9,
			ccBrightness = 0.02,
			ccContrast = 0.03,
			ccSaturation = 0.05,
			ccTintRgb = { 245, 248, 255 },
			starCount = 0,
			sunAngularSize = 21,
			moonAngularSize = 6,
			exposureCompensation = 0.1,
			artificialLightScale = 0.28,
		},
	},
	{
		id = "noon",
		hour = 12.0,
		sample = {
			clockTime = 12.0,
			brightness = 2.55,
			ambientRgb = { 118, 124, 132 },
			outdoorAmbientRgb = { 160, 172, 188 },
			colorShiftTopRgb = { 210, 230, 255 },
			colorShiftBottomRgb = { 200, 200, 220 },
			atmosphereColorRgb = { 200, 220, 245 },
			atmosphereDecayRgb = { 90, 110, 150 },
			atmosphereDensity = 0.1,
			atmosphereGlare = 0.18,
			atmosphereHaze = 0.35,
			bloomIntensity = 0.16,
			bloomSize = 14,
			bloomThreshold = 0.92,
			ccBrightness = 0.04,
			ccContrast = 0.02,
			ccSaturation = 0.02,
			ccTintRgb = { 255, 255, 255 },
			starCount = 0,
			sunAngularSize = 21,
			moonAngularSize = 5,
			exposureCompensation = 0.15,
			artificialLightScale = 0.18,
		},
	},
	{
		id = "afternoon",
		hour = 15.5,
		sample = {
			clockTime = 15.5,
			brightness = 2.2,
			ambientRgb = { 110, 108, 118 },
			outdoorAmbientRgb = { 150, 148, 160 },
			colorShiftTopRgb = { 220, 210, 245 },
			colorShiftBottomRgb = { 200, 170, 200 },
			atmosphereColorRgb = { 210, 200, 230 },
			atmosphereDecayRgb = { 100, 90, 130 },
			atmosphereDensity = 0.13,
			atmosphereGlare = 0.16,
			atmosphereHaze = 0.5,
			bloomIntensity = 0.22,
			bloomSize = 18,
			bloomThreshold = 0.9,
			ccBrightness = 0.02,
			ccContrast = 0.03,
			ccSaturation = 0.06,
			ccTintRgb = { 255, 245, 250 },
			starCount = 0,
			sunAngularSize = 20,
			moonAngularSize = 6,
			exposureCompensation = 0.08,
			artificialLightScale = 0.3,
		},
	},
	{
		id = "golden",
		hour = 17.4,
		sample = {
			clockTime = 17.4,
			brightness = 1.85,
			ambientRgb = { 90, 72, 70 },
			outdoorAmbientRgb = { 130, 96, 80 },
			colorShiftTopRgb = { 255, 170, 90 },
			colorShiftBottomRgb = { 230, 110, 150 },
			atmosphereColorRgb = { 255, 180, 120 },
			atmosphereDecayRgb = { 110, 55, 70 },
			atmosphereDensity = 0.2,
			atmosphereGlare = 0.28,
			atmosphereHaze = 1.05,
			bloomIntensity = 0.5,
			bloomSize = 28,
			bloomThreshold = 0.78,
			ccBrightness = 0.04,
			ccContrast = 0.07,
			ccSaturation = 0.2,
			ccTintRgb = { 255, 230, 200 },
			starCount = 80,
			sunAngularSize = 22,
			moonAngularSize = 8,
			exposureCompensation = 0.0,
			artificialLightScale = 0.5,
		},
	},
	{
		-- Herda a intenção do crepúsculo fixo antigo (ClockTime 18.25, haze 0.9).
		id = "dusk",
		hour = 18.25,
		sample = {
			clockTime = 18.25,
			brightness = 2.0,
			ambientRgb = { 48, 52, 70 },
			outdoorAmbientRgb = { 32, 38, 54 },
			colorShiftTopRgb = { 144, 216, 255 },
			colorShiftBottomRgb = { 184, 142, 255 },
			atmosphereColorRgb = { 144, 216, 255 },
			atmosphereDecayRgb = { 32, 38, 54 },
			atmosphereDensity = 0.18,
			atmosphereGlare = 0.12,
			atmosphereHaze = 0.9,
			bloomIntensity = 0.35,
			bloomSize = 22,
			bloomThreshold = 0.84,
			ccBrightness = 0.0,
			ccContrast = 0.04,
			ccSaturation = 0.1,
			ccTintRgb = { 235, 235, 255 },
			starCount = 400,
			sunAngularSize = 16,
			moonAngularSize = 10,
			exposureCompensation = -0.05,
			artificialLightScale = 0.85,
		},
	},
	{
		id = "twilight",
		hour = 19.6,
		sample = {
			clockTime = 19.6,
			brightness = 1.1,
			ambientRgb = { 30, 32, 60 },
			outdoorAmbientRgb = { 28, 30, 58 },
			colorShiftTopRgb = { 110, 130, 230 },
			colorShiftBottomRgb = { 140, 90, 210 },
			atmosphereColorRgb = { 80, 90, 160 },
			atmosphereDecayRgb = { 28, 24, 55 },
			atmosphereDensity = 0.26,
			atmosphereGlare = 0.08,
			atmosphereHaze = 1.3,
			bloomIntensity = 0.48,
			bloomSize = 26,
			bloomThreshold = 0.8,
			ccBrightness = -0.02,
			ccContrast = 0.06,
			ccSaturation = 0.14,
			ccTintRgb = { 220, 215, 255 },
			starCount = 1600,
			sunAngularSize = 10,
			moonAngularSize = 12,
			exposureCompensation = -0.2,
			artificialLightScale = 1.2,
		},
	},
	{
		id = "night",
		hour = 21.5,
		sample = {
			clockTime = 21.5,
			brightness = 0.7,
			ambientRgb = { 20, 22, 48 },
			outdoorAmbientRgb = { 24, 28, 62 },
			colorShiftTopRgb = { 100, 130, 230 },
			colorShiftBottomRgb = { 90, 60, 170 },
			atmosphereColorRgb = { 55, 65, 120 },
			atmosphereDecayRgb = { 16, 14, 40 },
			atmosphereDensity = 0.3,
			atmosphereGlare = 0.05,
			atmosphereHaze = 1.5,
			bloomIntensity = 0.55,
			bloomSize = 28,
			bloomThreshold = 0.78,
			ccBrightness = -0.04,
			ccContrast = 0.08,
			ccSaturation = 0.14,
			ccTintRgb = { 215, 218, 255 },
			starCount = 2800,
			sunAngularSize = 8,
			moonAngularSize = 14,
			exposureCompensation = -0.3,
			artificialLightScale = 1.4,
		},
	},
}

local DayNightCycle = {}

local function clamp01(x: number): number
	if x < 0 then
		return 0
	end
	if x > 1 then
		return 1
	end
	return x
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpRgb(a: Rgb, b: Rgb, t: number): Rgb
	return {
		lerp(a[1], b[1], t),
		lerp(a[2], b[2], t),
		lerp(a[3], b[3], t),
	}
end

local function lerpSample(a: LightingSample, b: LightingSample, t: number): LightingSample
	return {
		clockTime = lerp(a.clockTime, b.clockTime, t),
		brightness = lerp(a.brightness, b.brightness, t),
		ambientRgb = lerpRgb(a.ambientRgb, b.ambientRgb, t),
		outdoorAmbientRgb = lerpRgb(a.outdoorAmbientRgb, b.outdoorAmbientRgb, t),
		colorShiftTopRgb = lerpRgb(a.colorShiftTopRgb, b.colorShiftTopRgb, t),
		colorShiftBottomRgb = lerpRgb(a.colorShiftBottomRgb, b.colorShiftBottomRgb, t),
		atmosphereColorRgb = lerpRgb(a.atmosphereColorRgb, b.atmosphereColorRgb, t),
		atmosphereDecayRgb = lerpRgb(a.atmosphereDecayRgb, b.atmosphereDecayRgb, t),
		atmosphereDensity = lerp(a.atmosphereDensity, b.atmosphereDensity, t),
		atmosphereGlare = lerp(a.atmosphereGlare, b.atmosphereGlare, t),
		atmosphereHaze = lerp(a.atmosphereHaze, b.atmosphereHaze, t),
		bloomIntensity = lerp(a.bloomIntensity, b.bloomIntensity, t),
		bloomSize = lerp(a.bloomSize, b.bloomSize, t),
		bloomThreshold = lerp(a.bloomThreshold, b.bloomThreshold, t),
		ccBrightness = lerp(a.ccBrightness, b.ccBrightness, t),
		ccContrast = lerp(a.ccContrast, b.ccContrast, t),
		ccSaturation = lerp(a.ccSaturation, b.ccSaturation, t),
		ccTintRgb = lerpRgb(a.ccTintRgb, b.ccTintRgb, t),
		starCount = math.floor(lerp(a.starCount, b.starCount, t) + 0.5),
		sunAngularSize = lerp(a.sunAngularSize, b.sunAngularSize, t),
		moonAngularSize = lerp(a.moonAngularSize, b.moonAngularSize, t),
		exposureCompensation = lerp(a.exposureCompensation, b.exposureCompensation, t),
		artificialLightScale = lerp(a.artificialLightScale, b.artificialLightScale, t),
	}
end

local function wrapHour(hour: number): number
	local h = hour % 24
	if h < 0 then
		h += 24
	end
	return h
end

function DayNightCycle.config(): Config
	return CONFIG
end

function DayNightCycle.keyframes(): { Keyframe }
	return KEYFRAMES
end

-- Hora de jogo (0–24) a partir do tempo real decorrido desde o boot do ciclo.
function DayNightCycle.hourAt(elapsedRealSeconds: number, config: Config?): number
	local cfg = config or CONFIG
	local cycle = cfg.cycleSeconds
	if cycle <= 0 then
		return wrapHour(cfg.startHour)
	end
	local progress = (elapsedRealSeconds / cycle) % 1
	if progress < 0 then
		progress += 1
	end
	return wrapHour(cfg.startHour + progress * 24)
end

-- Amostra o lighting no `hour` de jogo, interpolando keyframes adjacentes.
function DayNightCycle.sampleAt(hour: number): LightingSample
	local h = wrapHour(hour)
	local frames = KEYFRAMES
	local n = #frames
	assert(n >= 2, "DayNightCycle precisa de ao menos 2 keyframes")

	-- Encontra o segmento [i, i+1] (com wrap meia-noite).
	local i = n
	for index = 1, n do
		if frames[index].hour > h then
			i = index - 1
			break
		end
	end
	if i < 1 then
		i = n
	end
	local j = if i == n then 1 else i + 1
	local a = frames[i]
	local b = frames[j]

	local span: number
	local into: number
	if b.hour > a.hour then
		span = b.hour - a.hour
		into = h - a.hour
	else
		-- Segmento que cruza a meia-noite (ex.: 21.5 → 0).
		span = (24 - a.hour) + b.hour
		if h >= a.hour then
			into = h - a.hour
		else
			into = (24 - a.hour) + h
		end
	end
	local t = if span <= 0 then 0 else clamp01(into / span)
	return lerpSample(a.sample, b.sample, t)
end

-- Atalho: tempo real → sample.
function DayNightCycle.sampleElapsed(elapsedRealSeconds: number, config: Config?): LightingSample
	return DayNightCycle.sampleAt(DayNightCycle.hourAt(elapsedRealSeconds, config))
end

-- Escala o brilho base de uma fonte artificial (spawn/tocha) pelo sample.
function DayNightCycle.scaledBrightness(baseBrightness: number, sample: LightingSample): number
	return math.max(0, baseBrightness * sample.artificialLightScale)
end

-- Nome de fase legível para debug/telemetria (não é string de UI).
function DayNightCycle.phaseIdAt(hour: number): string
	local h = wrapHour(hour)
	local frames = KEYFRAMES
	local best = frames[1]
	local bestDist = math.huge
	for _, frame in frames do
		local d = math.abs(frame.hour - h)
		local wrap = 24 - d
		local dist = if d < wrap then d else wrap
		if dist < bestDist then
			bestDist = dist
			best = frame
		end
	end
	return best.id
end

local function validRgb(rgb: Rgb): boolean
	return type(rgb) == "table"
		and #rgb == 3
		and rgb[1] >= 0
		and rgb[1] <= 255
		and rgb[2] >= 0
		and rgb[2] <= 255
		and rgb[3] >= 0
		and rgb[3] <= 255
end

local function validSample(sample: LightingSample, id: string): (boolean, string?)
	if sample.clockTime < 0 or sample.clockTime > 24 then
		return false, ("clockTime fora de 0–24 em %s"):format(id)
	end
	if sample.brightness < 0.2 or sample.brightness > 4 then
		return false, ("brightness fora do orçamento em %s"):format(id)
	end
	for _, key in
		{
			"ambientRgb",
			"outdoorAmbientRgb",
			"colorShiftTopRgb",
			"colorShiftBottomRgb",
			"atmosphereColorRgb",
			"atmosphereDecayRgb",
			"ccTintRgb",
		}
	do
		if not validRgb((sample :: any)[key]) then
			return false, ("RGB inválido %s em %s"):format(key, id)
		end
	end
	if sample.atmosphereDensity < 0 or sample.atmosphereDensity > 0.6 then
		return false, ("density fora do orçamento em %s"):format(id)
	end
	if sample.atmosphereHaze < 0 or sample.atmosphereHaze > 3 then
		return false, ("haze fora do orçamento em %s"):format(id)
	end
	if sample.atmosphereGlare < 0 or sample.atmosphereGlare > 1 then
		return false, ("glare fora do orçamento em %s"):format(id)
	end
	if sample.bloomIntensity < 0 or sample.bloomIntensity > 1.2 then
		return false, ("bloomIntensity fora do orçamento em %s"):format(id)
	end
	if sample.bloomSize < 0 or sample.bloomSize > 56 then
		return false, ("bloomSize fora do orçamento em %s"):format(id)
	end
	if sample.bloomThreshold < 0.4 or sample.bloomThreshold > 1 then
		return false, ("bloomThreshold fora do orçamento em %s"):format(id)
	end
	if sample.starCount < 0 or sample.starCount > 5000 then
		return false, ("starCount fora do orçamento em %s"):format(id)
	end
	if sample.artificialLightScale < 0.05 or sample.artificialLightScale > 2.5 then
		return false, ("artificialLightScale fora do orçamento em %s"):format(id)
	end
	if sample.sunAngularSize < 0 or sample.sunAngularSize > 40 then
		return false, ("sunAngularSize inválido em %s"):format(id)
	end
	if sample.moonAngularSize < 0 or sample.moonAngularSize > 40 then
		return false, ("moonAngularSize inválido em %s"):format(id)
	end
	if sample.exposureCompensation < -1 or sample.exposureCompensation > 1 then
		return false, ("exposureCompensation fora do orçamento em %s"):format(id)
	end
	return true, nil
end

function DayNightCycle.validate(): (boolean, string?)
	if CONFIG.cycleSeconds < 120 or CONFIG.cycleSeconds > 3600 then
		return false, "cycleSeconds fora do orçamento (2 min – 1 h)"
	end
	if CONFIG.startHour < 0 or CONFIG.startHour >= 24 then
		return false, "startHour fora de 0–24"
	end
	if CONFIG.geographicLatitude < -80 or CONFIG.geographicLatitude > 80 then
		return false, "geographicLatitude inválida"
	end
	if #KEYFRAMES < 4 then
		return false, "poucos keyframes para um arco dia/noite"
	end
	local seen: { [string]: boolean } = {}
	local prevHour = -1
	local nightFound = false
	local dayFound = false
	for _, frame in KEYFRAMES do
		if frame.id == "" or seen[frame.id] then
			return false, "keyframe sem id único"
		end
		seen[frame.id] = true
		if frame.hour < 0 or frame.hour >= 24 then
			return false, ("hour inválido em %s"):format(frame.id)
		end
		if frame.hour <= prevHour then
			return false, ("keyframes fora de ordem em %s"):format(frame.id)
		end
		prevHour = frame.hour
		local ok, reason = validSample(frame.sample, frame.id)
		if not ok then
			return false, reason
		end
		-- clockTime do sample deve bater com o hour do keyframe (sem drift).
		if math.abs(frame.sample.clockTime - frame.hour) > 0.001 then
			return false, ("clockTime ≠ hour em %s"):format(frame.id)
		end
		if frame.sample.artificialLightScale >= 1.1 then
			nightFound = true
		end
		if frame.sample.brightness >= 2.0 and frame.sample.artificialLightScale <= 0.4 then
			dayFound = true
		end
	end
	if not nightFound then
		return false, "nenhum keyframe de noite (artificialLightScale alto)"
	end
	if not dayFound then
		return false, "nenhum keyframe de dia (brightness alto + luz artificial baixa)"
	end

	-- Amostras intermediárias devem ser finitas e monótonas no clockTime
	-- dentro de um segmento que não cruza a meia-noite.
	local noon = DayNightCycle.sampleAt(12)
	local midnight = DayNightCycle.sampleAt(0)
	if noon.brightness <= midnight.brightness then
		return false, "meio-dia deve ser mais claro que meia-noite"
	end
	if midnight.artificialLightScale <= noon.artificialLightScale then
		return false, "meia-noite deve acentuar luz artificial"
	end
	if midnight.starCount <= noon.starCount then
		return false, "meia-noite precisa de estrelas"
	end
	-- O crepúsculo clássico do spawn continua no arco.
	local dusk = DayNightCycle.sampleAt(18.25)
	if math.abs(dusk.clockTime - 18.25) > 0.05 then
		return false, "crepúsculo 18.25 sumiu do arco"
	end
	-- hourAt respeita o wrap do ciclo.
	local cfg = CONFIG
	local h0 = DayNightCycle.hourAt(0, cfg)
	if math.abs(h0 - cfg.startHour) > 1e-6 then
		return false, "hourAt(0) deve ser startHour"
	end
	local hFull = DayNightCycle.hourAt(cfg.cycleSeconds, cfg)
	if math.abs(hFull - cfg.startHour) > 1e-3 then
		return false, "hourAt(cycleSeconds) deve fechar o ciclo"
	end
	return true, nil
end

return DayNightCycle

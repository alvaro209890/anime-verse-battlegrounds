--!strict
-- Flash de evolução. Só apresentação: o servidor já autorizou o nível.
-- Funções puras para o Lune; a materialização vive no UIController.

local LevelUpPlayer = {}

LevelUpPlayer.DURATION = 1.6

function LevelUpPlayer.shouldPlay(payload: { [string]: any }): boolean
	local gained = payload.levelsGained
	return type(gained) == "number" and gained == gained and gained > 0
end

-- Alpha do véu dourado (0..1). Pico cedo, some até o fim da duração.
function LevelUpPlayer.flashAlpha(elapsed: number, duration: number): number
	if duration <= 0 or elapsed < 0 or elapsed >= duration then
		return 0
	end
	local peakAt = duration * 0.12
	if elapsed <= peakAt then
		return elapsed / peakAt
	end
	return 1 - (elapsed - peakAt) / (duration - peakAt)
end

-- Escala do anel: nasce pequeno e abre.
function LevelUpPlayer.ringScale(elapsed: number, duration: number): number
	if duration <= 0 or elapsed < 0 then
		return 0.4
	end
	local t = math.clamp(elapsed / duration, 0, 1)
	return 0.45 + t * 1.35
end

return LevelUpPlayer

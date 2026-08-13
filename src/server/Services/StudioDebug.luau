--!strict
-- Gate puro para o loadout de playtest. Não existe remote de cheat: o
-- bootstrap só aplica estas flags quando o runtime é Studio E o place declara
-- explicitamente o atributo `F0Debug = true` (docs/13 §18).

local UNLOCK_FLAGS: { string } = {
	"unlock_comet_shoulder",
	"unlock_broken_cadence",
	"unlock_pulse_return",
}

local StudioDebug = {}

function StudioDebug.isEnabled(isStudio: boolean, debugAttribute: any): boolean
	return isStudio and debugAttribute == true
end

function StudioDebug.unlockFlags(): { string }
	return table.clone(UNLOCK_FLAGS)
end

-- Rojo nem sempre carimba `$attributes` no DataModel; o bootstrap tenta o
-- atributo do place e o do Script Server. O primeiro boolean vence.
function StudioDebug.resolveAttribute(...: any): any
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value == true or value == false then
			return value
		end
	end
	return nil
end

function StudioDebug.applySessionUnlocks(isStudio: boolean, debugAttribute: any, grant: (string) -> boolean): number
	if not StudioDebug.isEnabled(isStudio, debugAttribute) then
		return 0
	end
	local granted = 0
	for _, flag in StudioDebug.unlockFlags() do
		if grant(flag) then
			granted += 1
		end
	end
	return granted
end

return StudioDebug

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

return StudioDebug

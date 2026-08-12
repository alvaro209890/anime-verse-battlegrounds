--!strict
-- PlayerSessionService (server) — F0 (docs/04 §4.1)
-- Ciclo join/leave: cria estado de sessão, spawna personagem e limpa no leave.
-- TODO F1: readiness do perfil (save carregado) antes de expor a sessão.

local CatalogService = require(script.Parent.CatalogService)
local ResourceService = require(script.Parent.ResourceService)

local PlayerSessionService = {}

-- personagem padrão da F0 (único do roster)
local DEFAULT_CHARACTER_ID = "eclipse_fist"

function PlayerSessionService.onPlayerJoined(player: Player): ()
	local characterDef = CatalogService.getCharacter(DEFAULT_CHARACTER_ID)
	if not characterDef then
		warn(("[PlayerSessionService] personagem padrão %s ausente"):format(DEFAULT_CHARACTER_ID))
		return
	end

	local state = ResourceService.createState(player.UserId, characterDef.energyFamilyId)
	if not state then
		warn(("[PlayerSessionService] falha ao criar estado de recurso para %d"):format(player.UserId))
		return
	end

	state.characterId = characterDef.id
	state.health = characterDef.baseHealth

	-- TODO: spawn do avatar (CharacterService, F0) + save load (SaveService)
	-- TODO: broadcast de estado inicial (ResourceChanged, etc.)
end

function PlayerSessionService.onPlayerLeft(player: Player): ()
	-- TODO: salvar perfil (SaveService.release), limpar cooldowns e sessão
	ResourceService.states[player.UserId] = nil
end

return PlayerSessionService

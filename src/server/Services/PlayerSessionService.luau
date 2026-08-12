--!strict
-- PlayerSessionService (server) — F0 (docs/04 §4.1)
-- Ciclo join/leave: cria estado de sessão, spawna personagem e limpa no leave.
-- TODO F1: readiness do perfil (save carregado) antes de expor a sessão.
--
-- Dependências injetadas no init() — sem require de Instances (testável).

export type SessionDeps = {
	getCharacter: (string) -> any?,
	createResourceState: (number, string) -> any?,
	removeResourceState: (number) -> (),
	clearCooldowns: (number) -> (),
	releaseProfile: (number) -> (),
}

local PlayerSessionService = {
	deps = nil :: SessionDeps?,
}

-- personagem padrão da F0 (único do roster)
local DEFAULT_CHARACTER_ID = "eclipse_fist"

function PlayerSessionService.init(deps: SessionDeps): ()
	PlayerSessionService.deps = deps
end

function PlayerSessionService.onPlayerJoined(player: Player): ()
	local deps = PlayerSessionService.deps
	if not deps then
		return
	end
	local characterDef = deps.getCharacter(DEFAULT_CHARACTER_ID)
	if not characterDef then
		warn(("[PlayerSessionService] personagem padrão %s ausente"):format(DEFAULT_CHARACTER_ID))
		return
	end

	local state = deps.createResourceState(player.UserId, characterDef.energyFamilyId)
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
	local deps = PlayerSessionService.deps
	if not deps then
		return
	end
	deps.removeResourceState(player.UserId)
	deps.clearCooldowns(player.UserId)
	deps.releaseProfile(player.UserId)
end

return PlayerSessionService

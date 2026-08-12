--!strict
-- SaveService (server) — F0 (docs/04 ADR-002)
-- Adaptador tipado sobre ProfileStore (session locking, autosave, release).
-- ProfileStore é copiado para lib/ (fora do source map) e require via
-- ReplicatedStorage.Shared.vendor quando entra no projeto.
-- TODO F0: integrar lib/ProfileStore.luau em src/shared/vendor + fluxo
-- load → migração → ready → autosave → release (docs/05 §4).

local SaveService = {}

-- ProfileStore instanciado por template (data template versionada)
-- TODO: local ProfileStore = require(...)  — pinado e auditado (ADR-002)
local profileStore = nil

-- userId → handle de perfil
local openProfiles: { [number]: { data: { any }, revision: number } } = {}

function SaveService.init(): ()
	-- TODO: ProfileStore.new(template) — data template = ProfileRoot v1
	-- (docs/05 §4), validar e migrar antes de expor.
	-- Enquanto a biblioteca não entra no build, o serviço é um stub seguro:
	-- nenhum save é escrito e nenhuma sessão depende dele.
	profileStore = nil
end

-- Carrega (ou cria) o perfil do jogador com session lock.
-- Retorna a raiz de dados ou nil se indisponível.
function SaveService.loadProfile(userId: number): { any }?
	if not profileStore then
		-- Degradação segura: sem persistência a sessão segue em memória (dev)
		warn(("[SaveService] persistência indisponível — sessão em memória (userId=%d)"):format(userId))
		local devProfile = {
			schemaVersion = 1,
			userId = userId,
			revision = 0,
			progression = { accountLevel = 1, consolidatedXp = 0, unconsolidatedXp = 0 },
			wallet = { softCurrency = 0, upgradeMaterials = {} },
			characters = {},
			abilities = {},
			loadouts = {},
		}
		openProfiles[userId] = { data = devProfile, revision = 0 }
		return devProfile
	end
	-- TODO: profileStore:LoadAsync(userId) com retry/backoff e session lock
	error("[SaveService] ProfileStore não integrado ainda (F0)")
end

function SaveService.saveProfile(userId: number): boolean
	local profile = openProfiles[userId]
	if not profile then
		return false
	end
	-- TODO: profileStore:SaveAsync(userId, profile.data, profile.revision)
	return true
end

function SaveService.releaseProfile(userId: number): ()
	local profile = openProfiles[userId]
	if not profile then
		return
	end
	-- TODO: profile:Release() — salva se sujo e libera o lock
	SaveService.saveProfile(userId)
	openProfiles[userId] = nil
end

function SaveService.getProfile(userId: number): { any }?
	local profile = openProfiles[userId]
	if profile then
		return profile.data
	end
	return nil
end

return SaveService

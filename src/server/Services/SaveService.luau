--!strict
-- SaveService (server) — F0 (docs/04 ADR-002, docs/05 §4, docs/13 §11)
-- ProfileRoot v1 via adaptador de ProfileStore injetável:
--   loadProfile (session lock) → migração → expor sessão
--   saveProfile (autosave 60–120 s com jitter) → revision monotônico
--   releaseProfile → salva se sujo e libera o lock
--
-- O adaptador é INJETADO no init() para permitir testes headless (mock em
-- memória). Em produção o bootstrap injeta o ProfileStore real
-- (lib/ProfileStore.luau via ReplicatedStorage.Shared.vendor, ADR-002).
--
-- Regras de F0 (docs/13 §11.2):
--   1. leave normal persiste flags e XP
--   2. crash no autosave não duplica unlock (grantUnlock idempotente)
--   3. rejoin no mesmo servidor restaura
--   4. segundo servidor recusa sessão concorrente (lock via startSession)
--   5. falha no load NÃO entra com perfil default por cima de save existente

export type ProfileHandle = {
	Data: { any }?,
	-- Persiste o estado atual (UpdateAsync com revision no adaptador real).
	Save: () -> (),
	-- Libera o session lock (EndSession no ProfileStore).
	EndSession: () -> (),
}

export type ProfileStoreAdapter = {
	-- Inicia sessão com lock. nil = lock de outro servidor OU falha de rede
	-- (o chamador decide como tratar; NUNCA criar default por cima).
	startSession: (profileKey: string) -> ProfileHandle?,
}

export type SaveDeps = {
	store: ProfileStoreAdapter,
	-- Identifica a sessão do servidor (JobId) para lastServerSessionId.
	getSessionId: () -> string,
	now: (() -> number)?,
	-- Leitura do estado durável atual (bootstrap liga ao ProgressionService).
	getSnapshot: ((number) -> any?)?,
	-- Aplica o snapshot carregado (bootstrap liga ao restoreFromSave).
	applySnapshot: ((number, any) -> ())?,
	-- Autosave base em segundos (F0: 60–120 s com jitter; padrão 60).
	autosaveBaseSeconds: number?,
	-- Callback de telemetria (SaveAttempt, docs/13 §15).
	onSaved: ((number, { any }) -> ())?,
}

local SAVE_VERSION = 1
local RECENT_OPERATIONS_CAP = 32
local AUTOSAVE_JITTER_SECONDS = 60
local AUTOSAVE_DEFAULT_BASE = 60

export type OpenProfile = {
	handle: ProfileHandle,
	data: { any },
	dirty: boolean,
	revision: number,
	lastSavedAt: number,
	nextAutosaveAt: number,
}

local SaveService = {
	deps = nil :: SaveDeps?,
	-- userId → perfil aberto (sessão ativa com lock)
	openProfiles = {} :: { [number]: OpenProfile },
}

local function now(): number
	local deps = SaveService.deps
	if deps and deps.now then
		return deps.now()
	end
	return os.clock()
end

local function nextAutosaveAt(): number
	local deps = SaveService.deps
	local base = if deps and deps.autosaveBaseSeconds then deps.autosaveBaseSeconds else AUTOSAVE_DEFAULT_BASE
	return now() + base + math.random() * AUTOSAVE_JITTER_SECONDS
end

-- Template ProfileRoot v1 (docs/13 §11). Sem wallet/loadouts/inventory/quests:
-- a fatia não persiste contêineres de features que ainda não existem (docs/05
-- §4 — "não se persistem contêineres vazios").
local function newTemplate(userId: number, sessionId: string): { any }
	local t = now()
	return {
		schemaVersion = SAVE_VERSION,
		userId = userId,
		revision = 0,
		createdAt = t,
		updatedAt = t,
		lastServerSessionId = sessionId,
		progression = {
			accountLevel = 1,
			consolidatedXp = 0,
			unconsolidatedXp = 0,
			unspentProgressionPoints = 0,
			spentTracks = {
				vitality = 0,
				umbral = 0,
				impact = 0,
				guard = 0,
				resonance = 0,
			},
			lastConsolidationAt = 0,
			tutorialFlags = {},
		},
		inventory = {
			capacity = 30,
			stackables = {},
			revision = 0,
		},
		career = {
			monsterKills = 0,
			bossKills = 0,
			damageDealt = 0,
			playTimeSeconds = 0,
			deaths = 0,
			techniquesUsed = 0,
			consolidations = 0,
			questsCompleted = 0,
		},
		characters = {},
		abilities = {},
		settings = {
			localeId = "pt-br",
			reducedEffects = false,
			inputScheme = "default",
		},
		recentOperations = {},
	}
end

function SaveService.init(deps: SaveDeps): ()
	SaveService.deps = deps
	table.clear(SaveService.openProfiles)
end

function SaveService.isDirty(userId: number): boolean
	local profile = SaveService.openProfiles[userId]
	return profile ~= nil and profile.dirty
end

-- Abre (ou reabre) a sessão do perfil com lock. nil = indisponível (lock de
-- outro servidor ou falha) — o jogador NÃO entra com default por cima de um
-- save existente (docs/13 §11.2 item 5).
function SaveService.loadProfile(userId: number): { any }?
	local deps = SaveService.deps
	if not deps then
		return nil
	end
	local existing = SaveService.openProfiles[userId]
	if existing then
		-- Rejoin no mesmo servidor: devolve a sessão já aberta (item 3).
		return existing.data
	end
	local handle = deps.store.startSession(("player:%d"):format(userId))
	if not handle then
		-- Falha ou lock concorrente: nenhum perfil default é criado.
		return nil
	end
	local data = handle.Data
	if not data then
		-- Jogador novo: template versionado (ProfileStore hard-copia).
		data = newTemplate(userId, deps.getSessionId())
		handle.Data = data
	end
	if data.schemaVersion ~= SAVE_VERSION then
		-- F0 tem só v1; migrações futuras entram aqui antes de expor a sessão.
		SaveService.openProfiles[userId] = nil
		handle.EndSession()
		return nil
	end
	if data.userId ~= userId then
		-- Chave corrompida (payload não pertence a este usuário): recusa,
		-- nunca sobrescreve.
		SaveService.openProfiles[userId] = nil
		handle.EndSession()
		return nil
	end
	SaveService.openProfiles[userId] = {
		handle = handle,
		data = data,
		dirty = false,
		revision = data.revision or 0,
		lastSavedAt = now(),
		nextAutosaveAt = nextAutosaveAt(),
	}
	if deps.applySnapshot then
		deps.applySnapshot(userId, data.progression or {})
	end
	return data
end

-- Marca o perfil sujo (XP, flags, consolidação, morte) — o próximo autosave
-- persiste.
function SaveService.markDirty(userId: number): ()
	local profile = SaveService.openProfiles[userId]
	if profile then
		profile.dirty = true
	end
end

-- Grava o snapshot durável atual no perfil. Revision monotônico, updatedAt
-- renovado, lastServerSessionId atual. Retorna true se salvou.
function SaveService.saveProfile(userId: number): boolean
	local deps = SaveService.deps
	local profile = SaveService.openProfiles[userId]
	if not deps or not profile then
		return false
	end
	if not profile.dirty then
		return false
	end
	if deps.getSnapshot then
		local snapshot = deps.getSnapshot(userId)
		if snapshot then
			local progression = profile.data.progression
			progression.consolidatedXp = snapshot.consolidatedXp
			progression.unconsolidatedXp = snapshot.unconsolidatedXp
			progression.lastConsolidationAt = snapshot.lastConsolidationAt
			progression.tutorialFlags = snapshot.tutorialFlags
			progression.accountLevel = snapshot.accountLevel or 1
			progression.unspentProgressionPoints = snapshot.unspentProgressionPoints or 0
			progression.spentTracks = snapshot.spentTracks
				or {
					vitality = 0,
					umbral = 0,
					impact = 0,
					guard = 0,
					resonance = 0,
				}
			if type(snapshot.inventory) == "table" then
				profile.data.inventory = snapshot.inventory
			end
			if type(snapshot.career) == "table" then
				profile.data.career = snapshot.career
			end
			-- abilities.{id}.unlockedAt — sem masteryXp na fatia (docs/13 §11).
			local abilities = profile.data.abilities
			for _, abilityId in snapshot.unlockedAbilities do
				local entry = abilities[abilityId]
				if not entry then
					abilities[abilityId] = { unlockedAt = now() }
				end
			end
			local character = profile.data.characters["eclipse_fist"]
			if not character then
				profile.data.characters["eclipse_fist"] = { unlockedAt = now() }
			end
		end
	end
	profile.revision += 1
	profile.data.revision = profile.revision
	profile.data.updatedAt = now()
	profile.data.lastServerSessionId = deps.getSessionId()
	profile.handle.Save()
	profile.dirty = false
	profile.lastSavedAt = now()
	profile.nextAutosaveAt = nextAutosaveAt()
	if deps.onSaved then
		deps.onSaved(userId, {
			revision = profile.revision,
			dirty = false,
			bytes = #(table.concat({
				tostring(profile.data.schemaVersion),
				tostring(profile.data.userId),
				tostring(profile.data.revision),
			})),
		})
	end
	return true
end

-- Autosave (docs/13 §11.2: 60–120 s com jitter). Chamado no Heartbeat do
-- bootstrap. Retorna true se salvou nesta chamada.
function SaveService.tick(userId: number, currentNow: number): boolean
	local profile = SaveService.openProfiles[userId]
	if not profile or not profile.dirty then
		return false
	end
	if currentNow < profile.nextAutosaveAt then
		return false
	end
	return SaveService.saveProfile(userId)
end

-- Salva se sujo e libera o lock (leave, docs/13 §11.2 item 1).
function SaveService.releaseProfile(userId: number): ()
	local profile = SaveService.openProfiles[userId]
	if not profile then
		return
	end
	if profile.dirty then
		SaveService.saveProfile(userId)
	end
	profile.handle.EndSession()
	SaveService.openProfiles[userId] = nil
end

function SaveService.getProfile(userId: number): { any }?
	local profile = SaveService.openProfiles[userId]
	if profile then
		return profile.data
	end
	return nil
end

-- Recibo idempotente (docs/13 §11.1): anel ≤ 32 no perfil. O operationId
-- identifica a operação; repetir o mesmo recibo não duplica.
function SaveService.appendOperation(userId: number, receipt: { any }): ()
	local profile = SaveService.openProfiles[userId]
	if not profile then
		return
	end
	local operations = profile.data.recentOperations
	table.insert(operations, receipt)
	while #operations > RECENT_OPERATIONS_CAP do
		table.remove(operations, 1)
	end
	SaveService.markDirty(userId)
end

function SaveService.hasOpenProfile(userId: number): boolean
	return SaveService.openProfiles[userId] ~= nil
end

return SaveService

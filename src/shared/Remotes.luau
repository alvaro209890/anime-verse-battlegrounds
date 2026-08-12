--!strict
-- Contratos de rede registrados — F0 (docs/04 §6, docs/13-F0-SLICE.md §13)
-- Todo remote é declarado aqui com direção, versão e payload.
-- RemoteGateway (server) e client usam este registro; nada de remotes soltos.
--
-- Tipos declarados inline (export type é compile-time) para manter o módulo
-- carregável em testes Lune (que não resolvem require(script.Parent.X)).
-- Contrato canônico: src/shared/Types.luau.

export type NetworkContract = {
	name: string,
	direction: "ClientToServer" | "ServerToClient",
	version: number,
	payload: string,
}

export type RemoteName =
	"AbilityActivate"
	| "AbilityRejected"
	| "ResourceChanged"
	| "CombatHit"
	| "PlayerDied"
	| "SessionSnapshot"
	| "BasicAttackIntent"
	| "GuardIntent"
	| "DashIntent"
	| "ZoneEvent"
	| "ZoneCrossingIntent"
	| "InteractionIntent"
	| "StateDelta"
	| "EnemyEvent"

local REMOTES = {
	AbilityActivate = "AbilityActivate",
	AbilityRejected = "AbilityRejected",
	ResourceChanged = "ResourceChanged",
	CombatHit = "CombatHit",
	PlayerDied = "PlayerDied",
	SessionSnapshot = "SessionSnapshot",
	BasicAttackIntent = "BasicAttackIntent",
	GuardIntent = "GuardIntent",
	DashIntent = "DashIntent",
	ZoneEvent = "ZoneEvent",
	ZoneCrossingIntent = "ZoneCrossingIntent",
	InteractionIntent = "InteractionIntent",
	StateDelta = "StateDelta",
	EnemyEvent = "EnemyEvent",
}

local RemoteContracts = {
	[REMOTES.AbilityActivate] = {
		name = REMOTES.AbilityActivate,
		direction = "ClientToServer",
		version = 1,
		payload = "{ abilityId: string, phase: string?, incomingHit: boolean?, requestId: string }",
	} :: NetworkContract,
	[REMOTES.AbilityRejected] = {
		name = REMOTES.AbilityRejected,
		direction = "ServerToClient",
		version = 1,
		payload = "{ abilityId: string, reason: string }",
	} :: NetworkContract,
	[REMOTES.ResourceChanged] = {
		name = REMOTES.ResourceChanged,
		direction = "ServerToClient",
		version = 1,
		payload = "{ familyId: string, current: number, max: number, depleted: boolean }",
	} :: NetworkContract,
	[REMOTES.CombatHit] = {
		name = REMOTES.CombatHit,
		direction = "ServerToClient",
		version = 1,
		payload = "{ targetId: string, damage: number, abilityId: string }",
	} :: NetworkContract,
	[REMOTES.PlayerDied] = {
		name = REMOTES.PlayerDied,
		direction = "ServerToClient",
		version = 1,
		payload = "{ userId: number, killerUserId: number? }",
	} :: NetworkContract,
	[REMOTES.SessionSnapshot] = {
		name = REMOTES.SessionSnapshot,
		direction = "ServerToClient",
		version = 1,
		payload = "{ protocolVersion: number, ready: boolean, zoneId: string, health: number, guard: number, resource: number, familyId: string, unlocks: { string }, dummyId: string, objective: any?, unconsolidatedXp: number }",
	} :: NetworkContract,
	[REMOTES.BasicAttackIntent] = {
		name = REMOTES.BasicAttackIntent,
		direction = "ClientToServer",
		version = 1,
		payload = '{ kind: "light" | "heavy", requestId: string }',
	} :: NetworkContract,
	[REMOTES.GuardIntent] = {
		name = REMOTES.GuardIntent,
		direction = "ClientToServer",
		version = 1,
		payload = "{ down: boolean, requestId: string }",
	} :: NetworkContract,
	[REMOTES.DashIntent] = {
		name = REMOTES.DashIntent,
		direction = "ClientToServer",
		version = 1,
		payload = "{ requestId: string }",
	} :: NetworkContract,
	[REMOTES.ZoneEvent] = {
		name = REMOTES.ZoneEvent,
		direction = "ServerToClient",
		version = 1,
		payload = "{ from: string, to: string, pvp: boolean, signals: { string }, holdConfirmed: boolean, lockoutRemaining: number?, instant: number }",
	} :: NetworkContract,
	[REMOTES.ZoneCrossingIntent] = {
		name = REMOTES.ZoneCrossingIntent,
		direction = "ClientToServer",
		version = 1,
		payload = "{ toZoneId: string, holdConfirmed: boolean?, requestId: string }",
	} :: NetworkContract,
	-- Aceite de objetivo / uso de âncora. O cliente nunca informa recompensa.
	[REMOTES.InteractionIntent] = {
		name = REMOTES.InteractionIntent,
		direction = "ClientToServer",
		version = 1,
		payload = "{ npcId: string?, anchorId: string?, requestId: string }",
	} :: NetworkContract,
	-- Delta autoritativo de estado; carrega o tracker do objetivo e as flags.
	[REMOTES.StateDelta] = {
		name = REMOTES.StateDelta,
		direction = "ServerToClient",
		version = 1,
		payload = "{ objective: { questId: string, trackerKey: string, progress: number, required: number, state: string, xpGranted: number?, unlockFlag: string? }?, unlocks: { string }?, unconsolidatedXp: number? }",
	} :: NetworkContract,
	-- Telegraph, ataque, spawn e morte de inimigo. O telegraph é o que permite
	-- o contorno branco de perigo (§17); o cliente não decide se acertou.
	[REMOTES.EnemyEvent] = {
		name = REMOTES.EnemyEvent,
		direction = "ServerToClient",
		version = 1,
		payload = '{ fighterId: string, kind: "spawn" | "telegraph" | "attack" | "died" | "respawn", targetId: string?, damage: number? }',
	} :: NetworkContract,
}

local Contracts = {}

function Contracts.get(name: RemoteName): NetworkContract?
	return RemoteContracts[name]
end

function Contracts.all(): { NetworkContract }
	local out: { NetworkContract } = {}
	for _, c in RemoteContracts do
		table.insert(out, c)
	end
	return out
end

return {
	Names = REMOTES,
	Contracts = Contracts,
}

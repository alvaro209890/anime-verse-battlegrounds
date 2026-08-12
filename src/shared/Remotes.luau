--!strict
-- Contratos de rede registrados — F0 (docs/04 §6)
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

-- Nomes de remote. Convenção: <Direção>_<Caso>_<Nome>.
export type RemoteName = "AbilityActivate" | "AbilityRejected" | "ResourceChanged" | "CombatHit" | "PlayerDied"

local REMOTES = {
	-- Cliente → Servidor: intenção de ativar habilidade
	AbilityActivate = "AbilityActivate",
	-- Servidor → Cliente: habilidade recusada (cooldown/recurso/estado)
	AbilityRejected = "AbilityRejected",
	-- Servidor → Cliente: pool de recurso mudou
	ResourceChanged = "ResourceChanged",
	-- Servidor → Cliente: um golpe confirmado acertou
	CombatHit = "CombatHit",
	-- Servidor → Cliente: jogador morreu
	PlayerDied = "PlayerDied",
}

local RemoteContracts = {
	[REMOTES.AbilityActivate] = {
		name = REMOTES.AbilityActivate,
		direction = "ClientToServer",
		version = 1,
		payload = "{ abilityId: string, targetPosition: Vector3?, timestamp: number }",
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
		payload = "{ targetUserId: number, damage: number, abilityId: string }",
	} :: NetworkContract,
	[REMOTES.PlayerDied] = {
		name = REMOTES.PlayerDied,
		direction = "ServerToClient",
		version = 1,
		payload = "{ userId: number, killerUserId: number? }",
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

--!strict
-- CombatService (server) — F0
-- Dano, guarda e morte. Autoridade total; cliente nunca informa dano.
-- Puro (sem Instances) — testável.
-- TODO F1: hitbox por shape, quebra de guarda, stun, validação de distância refinada.

local CombatService = {}

export type ServerPlayerState = {
	userId: number,
	characterId: string,
	health: number,
	resource: number,
	familyId: string,
	combat: boolean,
	lastCombatAt: number,
}

-- Aplica dano confirmado. Retorna true se o alvo morreu.
-- _sourceUserId: mantido no contrato para atribuição futura (sourceAttribution).
function CombatService.applyDamage(target: ServerPlayerState, damage: number, _sourceUserId: number?): boolean
	if damage < 0 then
		return false
	end
	target.health -= damage
	if target.health <= 0 then
		target.health = 0
		-- TODO: broadcast PlayerDied + respawn (via PlayerSessionService/RemoteGateway)
		return true
	end
	return false
end

function CombatService.isAlive(state: ServerPlayerState): boolean
	return state.health > 0
end

return CombatService

--!strict
-- AbilityService (server) — F0
-- Autoriza ativação (estado, cooldown, recurso) e despacha para o runner
-- registrado em serverRunnerId. É o molde de todas as habilidades:
-- adicionar habilidade nova = 1 entrada em Data/Abilities + 1 runner aqui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatalogService = require(script.Parent.CatalogService)
local CooldownService = require(script.Parent.CooldownService)
local CombatService = require(script.Parent.CombatService)
local ResourceService = require(script.Parent.ResourceService)
local Types = require(ReplicatedStorage.Shared.Types)

export type ServerPlayerState = Types.ServerPlayerState
export type AbilityDefinition = Types.AbilityDefinition

local AbilityService = {}

-- Registro de runners: serverRunnerId → função(ativa, alvoEstado?, dados)
-- Cada runner valida alcance/alvos e aplica efeitos via CombatService.
local runners: { [string]: (ServerPlayerState, ServerPlayerState?, { any }) -> () } = {}

-- ── Runner de exemplo: dash_strike ─────────────────────────────────────────
-- Ataque de avanço com janela de timing: acertar dentro do startup dá prêmio
-- de fluxo (Éter Umbral) — premia jogador bom, pune spam (docs/01-GDD).
runners.dash_strike_runner = function(attacker: ServerPlayerState, target: ServerPlayerState?, _payload: { any })
	if not target then
		return
	end
	local ability = CatalogService.getAbility("dash_strike")
	if not ability then
		return
	end

	-- Dano base do molde (balanceamento real: docs/01-GDD, fase F1)
	local damage = 12
	local dead = CombatService.applyDamage(target, damage, attacker.userId)
	if not dead then
		-- TODO: marcar combate em ambos (setCombat true)
		-- Prêmio de fluxo: timing perfeito dentro da janela
		ResourceService.grantFlowGain(attacker.userId, 6)
	end
end

-- ── Runners stub das demais habilidades (F1: implementar) ──────────────────
runners.eclipse_barrier_runner = function(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: { any })
	-- TODO F1: barreira que nega contato com duração de activeMs
end

runners.void_rupture_runner = function(_attacker: ServerPlayerState, _target: ServerPlayerState?, _payload: { any })
	-- TODO F1: corte à distância (projétil server-side) com maxTargets
end

runners.eclipse_judgement_runner = function(
	_attacker: ServerPlayerState,
	_target: ServerPlayerState?,
	_payload: { any }
)
	-- TODO F1: ultimate em área, custo alto, cooldown longo
end

-- Ativação de habilidade. Retorna (ok, motivo).
function AbilityService.tryActivate(
	attacker: ServerPlayerState,
	abilityId: string,
	target: ServerPlayerState?,
	payload: { any }
): (boolean, string?)
	local ability: AbilityDefinition? = CatalogService.getAbility(abilityId)
	if not ability then
		return false, "unknown_ability"
	end
	if not ability.enabled then
		return false, "disabled"
	end

	local runner = runners[ability.serverRunnerId]
	if not runner then
		return false, "runner_not_found"
	end

	if not CombatService.isAlive(attacker) then
		return false, "dead"
	end

	local remaining = CooldownService.getRemaining(attacker.userId, abilityId)
	if remaining > 0 then
		return false, ("cooldown:%.1f"):format(remaining)
	end

	if not ResourceService.trySpend(attacker.userId, ability.resourceCost.amount) then
		return false, "no_resource"
	end

	CooldownService.start(attacker.userId, abilityId, ability.cooldown.baseSeconds)
	runner(attacker, target, payload)
	return true
end

return AbilityService

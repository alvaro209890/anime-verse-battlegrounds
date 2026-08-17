--!strict
-- NPCs da fatia F0 (docs/13-F0-SLICE.md §9)
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.

export type NpcDefinition = {
	id: string,
	displayNameKey: string,
	kind: "dummy" | "enemy" | "instructor",
	maxHealth: number,
	maxGuard: number,
	attackDamage: number,
	attackRange: number,
	attackPeriodSeconds: number,
	telegraphMs: number,
	grantsXp: boolean,
	enabled: boolean,
	moveSpeed: number?,
	respawnSeconds: number?,
	recoverySeconds: number?,
	xpUnconsolidated: number?,
	-- Retorno decrescente por âncora na sessão (docs/13 §9.2): os primeiros
	-- `xpFullKills` pagam `xpUnconsolidated`, os `xpReducedKills` seguintes
	-- pagam `xpReducedValue`, e o resto paga 0. Ausentes = sem decréscimo.
	xpFullKills: number?,
	xpReducedKills: number?,
	xpReducedValue: number?,
	maxAlive: number?,
	zoneId: string?,
	combatClearRadius: number?,
	-- Raio de aggro/leash no plano do chão (docs/13 §9.2). Fora dele o
	-- inimigo não inicia perseguição e larga a que já tinha. Ausente = 30
	-- (padrão Blox Fruits). Dummy e instrutor não usam.
	aggroRadiusStuds: number?,
	-- Nível exibido acima da cabeça (Billboard). Dado de catálogo, não inventado no cliente.
	displayLevel: number?,
	-- Elite (docs/13 §9.3 — Estilhaço Ancorado). Campos opcionais; só o elite
	-- os preenche. `elitePattern` alterna slam/combo no CombatService.
	attackPattern: string?,
	eliteSlamDamage: number?,
	eliteSlamTelegraphMs: number?,
	eliteComboDamage: number?,
	eliteComboTelegraphMs: number?,
	-- XP "uma vez por 3 min por jogador" (§9.3): cooldown de crédito.
	xpCooldownSeconds: number?,
	-- Leeching (§9.3): crédito se causou ≥ 1% da vida (`leechDamagePct`) ou
	-- ficou `leechStaySeconds` no raio `combatClearRadius`. Sem último golpe.
	leechDamagePct: number?,
	leechStaySeconds: number?,
}

local Npcs: { [string]: NpcDefinition } = {
	-- Instrutor do Limiar — oferece o objetivo 1 (docs/13 §10). Não combate:
	-- alvo de InteractionIntent, nunca de hitbox.
	npc_threshold_instructor = {
		id = "npc_threshold_instructor",
		displayNameKey = "npc.threshold_instructor.name",
		kind = "instructor",
		maxHealth = 1,
		maxGuard = 0,
		attackDamage = 0,
		attackRange = 0,
		attackPeriodSeconds = 0,
		telegraphMs = 0,
		grantsXp = false,
		enabled = true,
		zoneId = "zone_bastion_safe",
		displayLevel = 1,
	},
	npc_training_dummy = {
		id = "npc_training_dummy",
		displayNameKey = "npc.training_dummy.name",
		kind = "dummy",
		displayLevel = 1,
		maxHealth = 10000,
		maxGuard = 0,
		attackDamage = 5,
		attackRange = 8,
		attackPeriodSeconds = 2.5,
		telegraphMs = 400,
		grantsXp = false,
		enabled = true,
	},
	enemy_wandering_shard = {
		id = "enemy_wandering_shard",
		displayNameKey = "enemy.wandering_shard.name",
		kind = "enemy",
		displayLevel = 8,
		maxHealth = 60,
		maxGuard = 0,
		attackDamage = 8,
		attackRange = 4,
		attackPeriodSeconds = 1.0,
		telegraphMs = 400,
		grantsXp = true,
		enabled = true,
		moveSpeed = 12,
		respawnSeconds = 45,
		recoverySeconds = 0.6,
		xpUnconsolidated = 25,
		xpFullKills = 6,
		xpReducedKills = 6,
		xpReducedValue = 12,
		maxAlive = 4,
		zoneId = "zone_plain_free",
		combatClearRadius = 20,
		aggroRadiusStuds = 30,
	},
	-- Estilhaço Ancorado — elite da cratera (docs/13 §9.3). Fica na âncora
	-- `anchor_elite` (não persegue: moveSpeed ausente), alterna slam (dano 14,
	-- telegraph 700 ms, `unblockable` para o Retorno de Pulso, guarda reduz 30%)
	-- com combo leve 6+6 (telegraph 300 ms). Respawn 180 s. XP 80 uma vez por
	-- 3 min por jogador, com leeching: crédito se causou ≥ 1% da vida ou ficou
	-- 8 s no raio 20 da cratera. Sem último golpe.
	enemy_anchored_shard = {
		id = "enemy_anchored_shard",
		displayNameKey = "enemy.anchored_shard.name",
		kind = "enemy",
		displayLevel = 18,
		maxHealth = 120,
		maxGuard = 0,
		attackDamage = 14,
		attackRange = 8,
		attackPeriodSeconds = 1.0,
		telegraphMs = 700,
		grantsXp = true,
		enabled = true,
		-- Ancorado: não persegue o jogador; ataca quem entra na cratera.
		attackPattern = "elite",
		respawnSeconds = 180,
		recoverySeconds = 0.8,
		xpUnconsolidated = 80,
		xpCooldownSeconds = 180,
		eliteSlamDamage = 14,
		eliteSlamTelegraphMs = 700,
		eliteComboDamage = 6,
		eliteComboTelegraphMs = 300,
		leechDamagePct = 0.01,
		leechStaySeconds = 8,
		maxAlive = 1,
		zoneId = "zone_plain_free",
		combatClearRadius = 20,
		aggroRadiusStuds = 30,
	},
}

local NpcCatalog = {}

function NpcCatalog.get(npcId: string): NpcDefinition?
	return Npcs[npcId]
end

function NpcCatalog.levelLabel(def: NpcDefinition?): string
	if not def then
		return ""
	end
	local level = def.displayLevel
	if type(level) ~= "number" or level < 1 then
		return ""
	end
	return ("Nv. %d"):format(math.floor(level))
end

function NpcCatalog.all(): { NpcDefinition }
	local out: { NpcDefinition } = {}
	for _, def in Npcs do
		table.insert(out, def)
	end
	return out
end

return NpcCatalog

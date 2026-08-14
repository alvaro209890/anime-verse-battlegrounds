-- Receitas de apresentação e identidade de combate dos NPCs.
-- O servidor continua decidindo dano, alcance, cooldown e resultado; este catálogo
-- só nomeia a habilidade e fornece parâmetros visuais para o cliente.

export type EnemyAbility = {
	id: string,
	npcId: string,
	displayNameKey: string,
	pattern: "rend" | "pounce" | "combo" | "slam",
	telegraphSeconds: number,
	attackSeconds: number,
	recoverySeconds: number,
	color: { number },
	assetKey: string,
}

local ABILITIES: { [string]: EnemyAbility } = {
	shard_rend = {
		id = "shard_rend",
		npcId = "enemy_wandering_shard",
		displayNameKey = "enemy.ability.shard_rend.name",
		pattern = "rend",
		telegraphSeconds = 0.40,
		attackSeconds = 0.35,
		recoverySeconds = 0.60,
		color = { 104, 220, 238 },
		assetKey = "kenney_slash",
	},
	shard_pounce = {
		id = "shard_pounce",
		npcId = "enemy_wandering_shard",
		displayNameKey = "enemy.ability.shard_pounce.name",
		pattern = "pounce",
		telegraphSeconds = 0.40,
		attackSeconds = 0.35,
		recoverySeconds = 0.60,
		color = { 184, 108, 255 },
		assetKey = "kenney_spark",
	},
	anchored_combo = {
		id = "anchored_combo",
		npcId = "enemy_anchored_shard",
		displayNameKey = "enemy.ability.anchored_combo.name",
		pattern = "combo",
		telegraphSeconds = 0.30,
		attackSeconds = 0.40,
		recoverySeconds = 0.80,
		color = { 178, 112, 242 },
		assetKey = "kenney_slash",
	},
	anchored_slam = {
		id = "anchored_slam",
		npcId = "enemy_anchored_shard",
		displayNameKey = "enemy.ability.anchored_slam.name",
		pattern = "slam",
		telegraphSeconds = 0.70,
		attackSeconds = 0.40,
		recoverySeconds = 0.80,
		color = { 255, 118, 92 },
		assetKey = "kenney_scorch",
	},
}

local EnemyAbilities = {}

function EnemyAbilities.get(id: string): EnemyAbility?
	return ABILITIES[id]
end

function EnemyAbilities.forEvent(npcId: string, visualPattern: string?): EnemyAbility?
	if npcId == "enemy_wandering_shard" then
		return if visualPattern == "pounce" then ABILITIES.shard_pounce else ABILITIES.shard_rend
	end
	if npcId == "enemy_anchored_shard" then
		return if visualPattern == "slam" then ABILITIES.anchored_slam else ABILITIES.anchored_combo
	end
	return nil
end

function EnemyAbilities.all(): { EnemyAbility }
	local out: { EnemyAbility } = {}
	for _, ability in ABILITIES do
		table.insert(out, ability)
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function EnemyAbilities.validate(): (boolean, string?)
	for id, ability in ABILITIES do
		if id ~= ability.id or ability.telegraphSeconds <= 0 or ability.attackSeconds <= 0 then
			return false, "habilidade inválida: " .. id
		end
		if #ability.color ~= 3 then
			return false, "paleta inválida: " .. id
		end
	end
	return true, nil
end

return EnemyAbilities

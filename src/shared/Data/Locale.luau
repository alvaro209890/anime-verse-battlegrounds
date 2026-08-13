--!strict
-- Localização placeholder — F0 (docs/13-F0-SLICE.md §16)
-- Arquivo único, PT-BR default e EN segundo. Copy final e revisão P1 não
-- passam por aqui: estas são chaves internas de UI, sem nome de franquia.
--
-- Tipos inline para o harness Lune. Contrato canônico: src/shared/Types.luau.
--
-- Regra: todo `displayNameKey` de catálogo habilitado precisa existir aqui
-- (CatalogService valida no boot). `descriptionKey` entra com a UI (item 12).

export type LocaleId = "pt-br" | "en"

local DEFAULT_LOCALE: LocaleId = "pt-br"
local FALLBACK_LOCALE: LocaleId = "pt-br"

local Strings: { [string]: { [string]: string } } = {
	["pt-br"] = {
		-- Identidade e família
		["character.eclipse_fist.name"] = "Punho do Eclipse",
		["family.umbral_aether.name"] = "Umbral",
		["family.vital_flow.name"] = "Fluxo Vital",
		["family.counterflow.name"] = "Contrafluxo",
		["family.metamorphic_drive.name"] = "Ímpeto Metamórfico",

		-- Técnicas
		["ability.comet_shoulder.name"] = "Ombro Cometa",
		["ability.broken_cadence.name"] = "Cadência Quebrada",
		["ability.pulse_return.name"] = "Retorno de Pulso",
		["ability.eclipse_beat.name"] = "Batimento Eclipse",

		-- Mundo
		["zone.bastion.name"] = "Bastião do Limiar",
		["zone.plain.name"] = "Planície Estilhaçada",

		-- NPCs
		["npc.threshold_instructor.name"] = "Instrutor do Limiar",
		["npc.training_dummy.name"] = "Boneco de Treino",
		["enemy.wandering_shard.name"] = "Estilhaço Errante",
		["enemy.anchored_shard.name"] = "Estilhaço Ancorado",
		["interaction.talk.action"] = "CONVERSAR",
		["interaction.consolidate.action"] = "CONSOLIDAR XP",
		["interaction.return_marker.name"] = "Marco de Retorno",

		-- HUD
		["hud.zone_safe"] = "SEGURO",
		["hud.pvp_active"] = "PvP ATIVO — morte perde XP não consolidado",
		["hud.pvp_hold"] = "Segure para entrar na zona livre",
		["hud.health"] = "VIDA {current}/{max}",
		["hud.guard"] = "GUARDA {current}/{max}",
		["hud.resource"] = "◆ UMBRAL {current}/{max}",
		["hud.resource_depleted"] = "◆ UMBRAL ESGOTADO",
		["hud.ability_locked"] = "CADEADO",
		["hud.feedback_hit"] = "ACERTO",
		["hud.feedback_guard"] = "GUARDA",
		["hud.feedback_death"] = "DERROTADO",
		["hud.feedback_counter"] = "CONTRA",
		["hud.feedback_no_resource"] = "Umbral insuficiente",
		["hud.feedback_cooldown"] = "Técnica em recarga",
		["hud.feedback_locked"] = "Técnica bloqueada",
		["hud.feedback_rejected"] = "Ação recusada",
		["hud.feedback_zone_lockout"] = "Retorno seguro temporariamente bloqueado",
		["hud.feedback_death_loss"] = "Morte: perda de {amount} XP não consolidado",
		["hud.control_attack"] = "ATACAR",
		["hud.control_guard"] = "GUARDA",
		["hud.control_dash"] = "DASH",
		["hud.help_button"] = "?",
		["hud.help_title"] = "COMANDOS",
		["hud.help_hint"] = "Clique: golpe  ·  F guarda  ·  Q dash  ·  Tab mira  ·  H comandos",
		["hud.help_light"] = "Clique esquerdo — golpe leve (cadeia de 4)",
		["hud.help_heavy"] = "Clique direito — golpe pesado",
		["hud.help_guard"] = "F — guarda / aparo (segure)",
		["hud.help_dash"] = "Q — dash",
		["hud.help_ability"] = "1 / 2 / 3 — técnicas (cadeado = ainda bloqueada)",
		["hud.help_lock"] = "Tab ou clique do meio — travar / soltar mira",
		["hud.help_interact"] = "E — conversar / consolidar XP (segure no marco)",
		["hud.help_close"] = "H ou ? fecha esta lista",
		["hud.lock_on"] = "MIRA TRAVADA — Tab para soltar",
		["hud.debug_kit"] = "KIT DE TESTE",

		-- FTUE e objetivos
		["ftue.dummy_hint"] = "Ataque, defenda e esquive no boneco",
		["quest.hunt.tracker"] = "Derrote Estilhaços: {n}/3",
		["quest.elite.tracker"] = "Derrote o Estilhaço Ancorado",
		["quest.flow.tracker"] = "Acerte um eco da Cadência",
	},

	en = {
		["character.eclipse_fist.name"] = "Eclipse Fist",
		["family.umbral_aether.name"] = "Umbral",
		["family.vital_flow.name"] = "Vital Flow",
		["family.counterflow.name"] = "Counterflow",
		["family.metamorphic_drive.name"] = "Metamorphic Drive",

		["ability.comet_shoulder.name"] = "Comet Shoulder",
		["ability.broken_cadence.name"] = "Broken Cadence",
		["ability.pulse_return.name"] = "Pulse Return",
		["ability.eclipse_beat.name"] = "Eclipse Beat",

		["zone.bastion.name"] = "Threshold Bastion",
		["zone.plain.name"] = "Shattered Plain",

		["npc.threshold_instructor.name"] = "Threshold Instructor",
		["npc.training_dummy.name"] = "Training Dummy",
		["enemy.wandering_shard.name"] = "Wandering Shard",
		["enemy.anchored_shard.name"] = "Anchored Shard",
		["interaction.talk.action"] = "TALK",
		["interaction.consolidate.action"] = "CONSOLIDATE XP",
		["interaction.return_marker.name"] = "Return Marker",

		["hud.zone_safe"] = "SAFE",
		["hud.pvp_active"] = "PvP ACTIVE — death loses unconsolidated XP",
		["hud.pvp_hold"] = "Hold to enter the free zone",
		["hud.health"] = "HEALTH {current}/{max}",
		["hud.guard"] = "GUARD {current}/{max}",
		["hud.resource"] = "◆ UMBRAL {current}/{max}",
		["hud.resource_depleted"] = "◆ UMBRAL DEPLETED",
		["hud.ability_locked"] = "LOCKED",
		["hud.feedback_hit"] = "HIT",
		["hud.feedback_guard"] = "GUARD",
		["hud.feedback_death"] = "DEFEATED",
		["hud.feedback_counter"] = "COUNTER",
		["hud.feedback_no_resource"] = "Not enough Umbral",
		["hud.feedback_cooldown"] = "Technique on cooldown",
		["hud.feedback_locked"] = "Technique locked",
		["hud.feedback_rejected"] = "Action rejected",
		["hud.feedback_zone_lockout"] = "Safe return temporarily blocked",
		["hud.feedback_death_loss"] = "Death: lost {amount} unconsolidated XP",
		["hud.control_attack"] = "ATTACK",
		["hud.control_guard"] = "GUARD",
		["hud.control_dash"] = "DASH",
		["hud.help_button"] = "?",
		["hud.help_title"] = "CONTROLS",
		["hud.help_hint"] = "Click: attack  ·  F guard  ·  Q dash  ·  Tab lock-on  ·  H help",
		["hud.help_light"] = "Left click — light attack (4-hit chain)",
		["hud.help_heavy"] = "Right click — heavy attack",
		["hud.help_guard"] = "F — guard / parry (hold)",
		["hud.help_dash"] = "Q — dash",
		["hud.help_ability"] = "1 / 2 / 3 — techniques (lock = still locked)",
		["hud.help_lock"] = "Tab or middle click — lock / unlock aim",
		["hud.help_interact"] = "E — talk / consolidate XP (hold at the marker)",
		["hud.help_close"] = "H or ? closes this list",
		["hud.lock_on"] = "LOCK-ON — Tab to release",
		["hud.debug_kit"] = "TEST KIT",

		["ftue.dummy_hint"] = "Attack, guard and dodge on the dummy",
		["quest.hunt.tracker"] = "Defeat Shards: {n}/3",
		["quest.elite.tracker"] = "Defeat the Anchored Shard",
		["quest.flow.tracker"] = "Land a Cadence echo",
	},
}

local LocaleCatalog = {}

function LocaleCatalog.defaultLocale(): LocaleId
	return DEFAULT_LOCALE
end

function LocaleCatalog.hasKey(key: string): boolean
	return Strings[FALLBACK_LOCALE][key] ~= nil
end

-- Resolve a chave. Sem locale, usa o default; sem tradução, cai no fallback.
-- Chave desconhecida retorna a própria chave (nunca nil na UI).
function LocaleCatalog.get(key: string, locale: LocaleId?): string
	local table_ = Strings[locale or DEFAULT_LOCALE]
	if table_ and table_[key] then
		return table_[key]
	end
	return Strings[FALLBACK_LOCALE][key] or key
end

-- Substitui `{campo}` pelos valores informados. Usado pelos trackers
-- (`quest.hunt.tracker` → "Derrote Estilhaços: 2/3").
function LocaleCatalog.format(key: string, params: { [string]: any }, locale: LocaleId?): string
	local text = LocaleCatalog.get(key, locale)
	local formatted = text:gsub("{(%w+)}", function(field: string): string
		local value = params[field]
		if value == nil then
			return "{" .. field .. "}"
		end
		return tostring(value)
	end)
	return formatted
end

function LocaleCatalog.locales(): { LocaleId }
	return { "pt-br", "en" }
end

return LocaleCatalog

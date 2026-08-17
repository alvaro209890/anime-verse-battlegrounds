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
		["zone.lumen.name"] = "Distrito Lumen",
		["zone.woods.name"] = "Bosque dos Ecos",
		["zone.port.name"] = "Porto Ferro",
		["zone.grey.name"] = "Setor Cinza",
		["zone.academy.name"] = "Academia Alvorada",

		-- NPCs
		["npc.threshold_instructor.name"] = "Instrutora do Limiar",
		["npc.training_dummy.name"] = "Boneco de Treino",
		["enemy.wandering_shard.name"] = "Estilhaço Errante",
		["enemy.anchored_shard.name"] = "Estilhaço Ancorado",
		["skin.cyan_rift_shard"] = "Fenda Ciano",
		["skin.void_crown_boss"] = "Coroa do Vazio",
		["skin.training_sack"] = "Saco de Treino",
		["skin.threshold_warden"] = "Guardiã do Limiar",
		["enemy.ability.shard_rend.name"] = "Talho de Fenda",
		["enemy.ability.shard_pounce.name"] = "Salto do Estilhaço",
		["enemy.ability.anchored_combo.name"] = "Combo da Coroa",
		["enemy.ability.anchored_slam.name"] = "Esmagamento do Vazio",
		["interaction.talk.action"] = "CONVERSAR",
		["interaction.consolidate.action"] = "CONSOLIDAR XP",
		["interaction.return_marker.name"] = "Marco de Retorno",

		-- HUD
		["hud.zone_safe"] = "SEGURO",
		["hud.pvp_active"] = "PvP ATIVO — morte perde XP não consolidado",
		["hud.pvp_hold"] = "Segure para entrar na zona livre",
		["hud.pvp_hold_key"] = "SEGURE E PARA ATRAVESSAR O PORTÃO",
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
		["hud.menu_button"] = "MENU",
		["hud.help_button"] = "MENU",
		["hud.help_title"] = "CONFIGURAÇÕES",
		["hud.help_hint"] = "clique atacar  ·  segure 0,3s pesado  ·  direito guarda  ·  Shift correr  ·  Q dash  ·  Tab mira  ·  E portão  ·  K status  ·  B mochila  ·  H",
		["hud.help_light"] = "Clique esquerdo — golpe leve (cadeia de 4)",
		["hud.help_heavy"] = "Clique esquerdo segurado (~0,3 s) — golpe pesado (quebra guarda)",
		["hud.help_guard"] = "Botão direito ou F — guarda / aparo (segure)",
		["hud.help_sprint"] = "Shift (ou L3 no controle) — correr (segure)",
		["hud.help_dash"] = "Q — dash",
		["hud.help_ability"] = "1 / 2 / 3 — técnicas (cadeado = ainda bloqueada)",
		["hud.help_lock"] = "Tab, clique do meio ou o botão SOLTAR MIRA",
		["hud.help_interact"] = "E — conversar / consolidar XP (segure no marco)",
		["hud.help_gate"] = "Portão: chegue no vão e SEGURE E por 1 s para sair do Bastião",
		["hud.help_close"] = "MENU, H ou FECHAR fecha esta tela",
		["hud.lock_on"] = "MIRA TRAVADA",
		["hud.lock_release"] = "SOLTAR MIRA",
		["hud.lock_engage"] = "TRAVAR MIRA",
		["hud.settings_close"] = "FECHAR",
		["hud.settings_camera"] = "CÂMERA",
		["hud.settings_shake_on"] = "Tremor da câmera: LIGADO",
		["hud.settings_shake_off"] = "Tremor da câmera: DESLIGADO",
		["hud.settings_where"] = "Dummy: canto sudeste. Estilhaços: fora do portão norte.",
		["hud.debug_kit"] = "KIT DE TESTE",
		["hud.level"] = "NV. {level}",
		["hud.xp_bar"] = "{into}/{need}",
		["hud.xp_field"] = "+{amount} no campo",
		["hud.xp_ready"] = "Consolide no Marco — +{levels} nível",
		["hud.xp_ready_many"] = "Consolide no Marco — +{levels} níveis",
		["hud.status_button"] = "STATUS",
		["hud.status_title"] = "EVOLUÇÃO",
		["hud.status_points"] = "{n} ponto(s) livre(s)",
		["hud.status_no_points"] = "Mate Estilhaços e consolide no Marco para subir de nível",
		["hud.status_respec"] = "REDEFINIR PONTOS (zona segura)",
		["hud.track.vitality"] = "Vitalidade",
		["hud.track.umbral"] = "Umbral",
		["hud.track.impact"] = "Impacto",
		["hud.track.guard"] = "Guarda",
		["hud.track.resonance"] = "Ressonância",
		["hud.track.vitality.fx"] = "+{n} vida",
		["hud.track.umbral.fx"] = "+{n} Umbral",
		["hud.track.impact.fx"] = "+{n}% dano (teto 6%)",
		["hud.track.guard.fx"] = "+{n} guarda",
		["hud.track.resonance.fx"] = "−{n}% custo (teto 6%)",
		["hud.help_status"] = "K — painel de nível e pontos (3 por nível, como no Blox Fruits)",
		["hud.feedback_level_up"] = "Nível {level} — +{points} pontos",
		["hud.feedback_spent"] = "Ponto aplicado",
		["hud.feedback_respec"] = "Pontos devolvidos",
		["hud.feedback_no_points"] = "Sem pontos livres — consolide no Marco",
		["hud.feedback_not_safe"] = "Redefinir só na zona segura",

		-- FTUE e objetivos
		["ftue.dummy_hint"] = "Ataque, defenda e esquive no boneco",
		["quest.hunt.tracker"] = "Estilhaços: {n}/{req}  ·  +{xp} XP",
		["quest.elite.tracker"] = "Ancorado  ·  +{xp} XP",
		["quest.flow.tracker"] = "Eco da Cadência  ·  +{xp} XP",
		["item.shard_fragment.name"] = "Fragmento de Estilhaço",
		["item.shard_fragment.desc"] = "Lasca que o Estilhaço Errante deixa. Sem poder de combate.",
		["item.void_splinter.name"] = "Lasca do Vazio",
		["item.void_splinter.desc"] = "Resíduo do Estilhaço Ancorado. Sem poder de combate.",
		["item.umbral_dust.name"] = "Pó Umbral",
		["item.umbral_dust.desc"] = "Poeira de evolução. Sem poder de combate.",
		["item.traveler_wrap.name"] = "Faixa do Viajante",
		["item.traveler_wrap.desc"] = "Lembrança do primeiro passo no Bastião.",
		["hud.bag_button"] = "MOCHILA",
		["hud.bag_title"] = "MOCHILA",
		["hud.bag_abilities"] = "Técnicas",
		["hud.bag_items"] = "Itens",
		["hud.bag_empty"] = "Nada aqui ainda — cace na planície",
		["hud.bag_locked"] = "bloqueada",
		["hud.help_bag"] = "B — mochila de técnicas e itens",
		["hud.feedback_loot"] = "+{item}",
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
		["zone.lumen.name"] = "Lumen District",
		["zone.woods.name"] = "Echo Woods",
		["zone.port.name"] = "Iron Port",
		["zone.grey.name"] = "Grey Sector",
		["zone.academy.name"] = "Dawn Academy",

		["npc.threshold_instructor.name"] = "Threshold Instructress",
		["npc.training_dummy.name"] = "Training Dummy",
		["enemy.wandering_shard.name"] = "Wandering Shard",
		["enemy.anchored_shard.name"] = "Anchored Shard",
		["skin.cyan_rift_shard"] = "Cyan Rift",
		["skin.void_crown_boss"] = "Void Crown",
		["skin.training_sack"] = "Training Sack",
		["skin.threshold_warden"] = "Threshold Guardian",
		["enemy.ability.shard_rend.name"] = "Rift Rend",
		["enemy.ability.shard_pounce.name"] = "Shard Pounce",
		["enemy.ability.anchored_combo.name"] = "Crown Combo",
		["enemy.ability.anchored_slam.name"] = "Void Slam",
		["interaction.talk.action"] = "TALK",
		["interaction.consolidate.action"] = "CONSOLIDATE XP",
		["interaction.return_marker.name"] = "Return Marker",

		["hud.zone_safe"] = "SAFE",
		["hud.pvp_active"] = "PvP ACTIVE — death loses unconsolidated XP",
		["hud.pvp_hold"] = "Hold to enter the free zone",
		["hud.pvp_hold_key"] = "HOLD E TO CROSS THE GATE",
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
		["hud.menu_button"] = "MENU",
		["hud.help_button"] = "MENU",
		["hud.help_title"] = "SETTINGS",
		["hud.help_hint"] = "click attack  ·  hold 0.3s heavy  ·  right-click guard  ·  Shift sprint  ·  Q dash  ·  Tab lock-on  ·  E gate  ·  K status  ·  B bag  ·  H",
		["hud.help_light"] = "Left click — light attack (4-hit chain)",
		["hud.help_heavy"] = "Hold left click (~0.3s) — heavy attack (guard breaker)",
		["hud.help_guard"] = "Right click or F — guard / parry (hold)",
		["hud.help_sprint"] = "Shift (or L3 on gamepad) — sprint (hold)",
		["hud.help_dash"] = "Q — dash",
		["hud.help_ability"] = "1 / 2 / 3 — techniques (lock = still locked)",
		["hud.help_lock"] = "Tab, middle click, or the RELEASE AIM button",
		["hud.help_interact"] = "E — talk / consolidate XP (hold at the marker)",
		["hud.help_gate"] = "Gate: stand in the opening and HOLD E for 1 s to leave the Bastion",
		["hud.help_close"] = "MENU, H or CLOSE dismisses this screen",
		["hud.lock_on"] = "AIM LOCKED",
		["hud.lock_release"] = "RELEASE AIM",
		["hud.lock_engage"] = "LOCK AIM",
		["hud.settings_close"] = "CLOSE",
		["hud.settings_camera"] = "CAMERA",
		["hud.settings_shake_on"] = "Camera shake: ON",
		["hud.settings_shake_off"] = "Camera shake: OFF",
		["hud.settings_where"] = "Dummy: southeast corner. Shards: past the north gate.",
		["hud.debug_kit"] = "TEST KIT",
		["hud.level"] = "LV. {level}",
		["hud.xp_bar"] = "{into}/{need}",
		["hud.xp_field"] = "+{amount} in the field",
		["hud.xp_ready"] = "Consolidate at the Marker — +{levels} level",
		["hud.xp_ready_many"] = "Consolidate at the Marker — +{levels} levels",
		["hud.status_button"] = "STATUS",
		["hud.status_title"] = "EVOLUTION",
		["hud.status_points"] = "{n} unspent point(s)",
		["hud.status_no_points"] = "Hunt Shards and consolidate at the Marker to level up",
		["hud.status_respec"] = "RESET POINTS (safe zone)",
		["hud.track.vitality"] = "Vitality",
		["hud.track.umbral"] = "Umbral",
		["hud.track.impact"] = "Impact",
		["hud.track.guard"] = "Guard",
		["hud.track.resonance"] = "Resonance",
		["hud.track.vitality.fx"] = "+{n} health",
		["hud.track.umbral.fx"] = "+{n} Umbral",
		["hud.track.impact.fx"] = "+{n}% damage (6% cap)",
		["hud.track.guard.fx"] = "+{n} guard",
		["hud.track.resonance.fx"] = "-{n}% cost (6% cap)",
		["hud.help_status"] = "K — level and stat points (3 per level, Blox Fruits-style)",
		["hud.feedback_level_up"] = "Level {level} — +{points} points",
		["hud.feedback_spent"] = "Point spent",
		["hud.feedback_respec"] = "Points returned",
		["hud.feedback_no_points"] = "No free points — consolidate at the Marker",
		["hud.feedback_not_safe"] = "Reset only in a safe zone",

		["ftue.dummy_hint"] = "Attack, guard and dodge on the dummy",
		["quest.hunt.tracker"] = "Shards: {n}/{req}  ·  +{xp} XP",
		["quest.elite.tracker"] = "Anchored  ·  +{xp} XP",
		["quest.flow.tracker"] = "Cadence echo  ·  +{xp} XP",
		["item.shard_fragment.name"] = "Shard Fragment",
		["item.shard_fragment.desc"] = "A chip the Wandering Shard leaves. No combat power.",
		["item.void_splinter.name"] = "Void Splinter",
		["item.void_splinter.desc"] = "Residue of the Anchored Shard. No combat power.",
		["item.umbral_dust.name"] = "Umbral Dust",
		["item.umbral_dust.desc"] = "Evolution dust. No combat power.",
		["item.traveler_wrap.name"] = "Traveler Wrap",
		["item.traveler_wrap.desc"] = "A keepsake of the first step in the Bastion.",
		["hud.bag_button"] = "BAG",
		["hud.bag_title"] = "BACKPACK",
		["hud.bag_abilities"] = "Techniques",
		["hud.bag_items"] = "Items",
		["hud.bag_empty"] = "Empty — hunt on the plain",
		["hud.bag_locked"] = "locked",
		["hud.help_bag"] = "B — backpack of techniques and items",
		["hud.feedback_loot"] = "+{item}",
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
-- (`quest.hunt.tracker` → "Estilhaços: 2/3  ·  +40 XP").
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

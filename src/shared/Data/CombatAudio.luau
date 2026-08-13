--!strict
-- Catálogo de áudio de combate — dirigido por dados (docs/16-COMBAT-AUDIO.md).
--
-- `assetId` aponta hoje para áudios do criador **Roblox** (userId 1), que
-- qualquer experiência pode tocar sem upload — é o kit PLACEHOLDER que tira o
-- combate do mudo enquanto o upload dos .ogg CC0 não acontece (docs/16 §7).
-- Verificados em 2026-08-13 via `economy.roblox.com/v2/assets/<id>/details`
-- (Creator.Id = 1, AssetTypeId = 3):
--   12222216 swordslash.wav · 12222208 swordlunge.wav · 12222225 unsheath.wav
--   12222095 "Rocket whoosh 01.wav" · 12222152 splat.wav · 12222005 glassbreak.wav
-- Vazio continua sendo estado válido: CombatAudioPlayer ignora a deixa em
-- silêncio — o jogo nunca quebra por falta de som.
--
-- `sourceFile` é rastreabilidade: aponta o arquivo CC0 de origem, que continua
-- sendo o som final pretendido, para o upload ser conferível e para trocar o
-- som sem caçar o binário.
--
-- Tipos inline (export type é compile-time) para manter o módulo carregável em
-- testes Lune. Contrato canônico: src/shared/Types.luau.

export type AudioCue = {
	id: string,
	assetId: string,
	sourceFile: string,
	-- Variantes do mesmo golpe: o player sorteia uma. Repetir o mesmo arquivo
	-- em cada soco é o que faz combate soar mecânico.
	variantFiles: { string },
	volume: number,
	-- Faixa de pitch sorteada por reprodução. Mesmo com uma variante só, a
	-- variação de tom já quebra a repetição percebida.
	pitchMin: number,
	pitchMax: number,
	-- Alcance em studs no qual a deixa ainda é audível. Golpe do próprio
	-- jogador usa 2D (rollout 0) porque não deve cair com a câmera.
	rolloffMaxStuds: number,
	enabled: boolean,
}

local BASE = "assets/audio/"

-- Placeholders livres do Roblox por papel sonoro (ver cabeçalho).
local RBX_SLASH = "rbxassetid://12222216"
local RBX_LUNGE = "rbxassetid://12222208"
local RBX_METAL = "rbxassetid://12222225"
local RBX_WHOOSH = "rbxassetid://12222095"
local RBX_IMPACT = "rbxassetid://12222152"
local RBX_SHATTER = "rbxassetid://12222005"

local function cue(values: {
	id: string,
	sourceFile: string,
	assetId: string?,
	variantFiles: { string }?,
	volume: number?,
	pitchMin: number?,
	pitchMax: number?,
	rolloffMaxStuds: number?,
}): AudioCue
	local variants: { string } = {}
	local sources: { string } = values.variantFiles or {}
	for _, path in sources do
		table.insert(variants, BASE .. path)
	end
	return {
		id = values.id,
		assetId = values.assetId or "",
		sourceFile = BASE .. values.sourceFile,
		variantFiles = variants,
		volume = values.volume or 0.5,
		pitchMin = values.pitchMin or 0.94,
		pitchMax = values.pitchMax or 1.06,
		rolloffMaxStuds = values.rolloffMaxStuds or 60,
		enabled = true,
	}
end

-- Uma deixa por momento sonoro, não uma por arquivo. O golpe pede dois sons
-- distintos: o corte de ar (sempre toca, é a ação) e o impacto (só quando o
-- servidor confirma o acerto — docs/14 §5, PresentationImpact).
local Cues: { [string]: AudioCue } = {
	-- ── Corte de ar da cadeia leve: um por degrau, subindo em peso ──────────
	swing_light_1 = cue({
		id = "swing_light_1",
		assetId = RBX_SLASH,
		sourceFile = "rpg-audio/Audio/cloth1.ogg",
		variantFiles = { "rpg-audio/Audio/cloth2.ogg" },
		volume = 0.32,
		pitchMin = 1.12,
		pitchMax = 1.24,
		rolloffMaxStuds = 40,
	}),
	swing_light_2 = cue({
		id = "swing_light_2",
		assetId = RBX_SLASH,
		sourceFile = "rpg-audio/Audio/cloth3.ogg",
		variantFiles = { "rpg-audio/Audio/cloth4.ogg" },
		volume = 0.36,
		pitchMin = 1.02,
		pitchMax = 1.14,
		rolloffMaxStuds = 40,
	}),
	-- Chute: corte mais grave e mais longo que soco.
	swing_light_3 = cue({
		id = "swing_light_3",
		assetId = RBX_SLASH,
		sourceFile = "rpg-audio/Audio/clothBelt.ogg",
		variantFiles = { "rpg-audio/Audio/clothBelt2.ogg" },
		volume = 0.42,
		pitchMin = 0.90,
		pitchMax = 1.00,
		rolloffMaxStuds = 45,
	}),
	-- Finalizador giratório: o mais pesado da cadeia.
	swing_light_4 = cue({
		id = "swing_light_4",
		assetId = RBX_SLASH,
		sourceFile = "rpg-audio/Audio/chop.ogg",
		variantFiles = { "rpg-audio/Audio/clothBelt2.ogg" },
		volume = 0.48,
		pitchMin = 0.80,
		pitchMax = 0.90,
		rolloffMaxStuds = 55,
	}),
	swing_heavy = cue({
		id = "swing_heavy",
		assetId = RBX_LUNGE,
		sourceFile = "rpg-audio/Audio/clothBelt.ogg",
		variantFiles = { "rpg-audio/Audio/chop.ogg" },
		volume = 0.5,
		pitchMin = 0.78,
		pitchMax = 0.88,
		rolloffMaxStuds = 55,
	}),

	-- ── Impacto confirmado pelo servidor ───────────────────────────────────
	impact_light = cue({
		id = "impact_light",
		assetId = RBX_IMPACT,
		sourceFile = "impact-sounds/Audio/impactPunch_medium_000.ogg",
		variantFiles = {
			"impact-sounds/Audio/impactPunch_medium_001.ogg",
			"impact-sounds/Audio/impactPunch_medium_002.ogg",
			"impact-sounds/Audio/impactPunch_medium_003.ogg",
			"impact-sounds/Audio/impactPunch_medium_004.ogg",
		},
		volume = 0.62,
		pitchMin = 0.95,
		pitchMax = 1.10,
	}),
	impact_heavy = cue({
		id = "impact_heavy",
		assetId = RBX_IMPACT,
		sourceFile = "impact-sounds/Audio/impactPunch_heavy_000.ogg",
		variantFiles = {
			"impact-sounds/Audio/impactPunch_heavy_001.ogg",
			"impact-sounds/Audio/impactPunch_heavy_002.ogg",
			"impact-sounds/Audio/impactPunch_heavy_003.ogg",
			"impact-sounds/Audio/impactPunch_heavy_004.ogg",
		},
		volume = 0.78,
		pitchMin = 0.86,
		pitchMax = 0.98,
	}),
	-- Guarda: o golpe parou na defesa. Som metálico, não carnudo — a diferença
	-- entre "acertei" e "foi bloqueado" precisa ser audível sem olhar o HUD.
	impact_guard = cue({
		id = "impact_guard",
		assetId = RBX_METAL,
		sourceFile = "impact-sounds/Audio/impactPlate_heavy_000.ogg",
		variantFiles = {
			"impact-sounds/Audio/impactPlate_heavy_001.ogg",
			"impact-sounds/Audio/impactPlate_heavy_002.ogg",
			"impact-sounds/Audio/impactPlate_medium_000.ogg",
		},
		volume = 0.66,
		pitchMin = 0.92,
		pitchMax = 1.04,
	}),

	-- ── Técnicas do Punho do Eclipse ───────────────────────────────────────
	ability_comet_shoulder = cue({
		id = "ability_comet_shoulder",
		assetId = RBX_WHOOSH,
		sourceFile = "sci-fi-sounds/Audio/thrusterFire_000.ogg",
		variantFiles = { "sci-fi-sounds/Audio/thrusterFire_001.ogg" },
		volume = 0.55,
		pitchMin = 0.94,
		pitchMax = 1.02,
	}),
	ability_broken_cadence = cue({
		id = "ability_broken_cadence",
		assetId = RBX_SLASH,
		sourceFile = "sci-fi-sounds/Audio/laserSmall_000.ogg",
		variantFiles = { "sci-fi-sounds/Audio/laserSmall_001.ogg" },
		volume = 0.5,
		pitchMin = 0.98,
		pitchMax = 1.08,
	}),
	ability_pulse_return = cue({
		id = "ability_pulse_return",
		assetId = RBX_METAL,
		sourceFile = "sci-fi-sounds/Audio/forceField_000.ogg",
		variantFiles = { "sci-fi-sounds/Audio/forceField_001.ogg" },
		volume = 0.58,
		pitchMin = 0.92,
		pitchMax = 1.0,
	}),
	-- Eco da Cadência: mesma família da técnica, meio tom acima e mais curto —
	-- precisa soar como repetição do golpe anterior, não como golpe novo.
	ability_cadence_echo = cue({
		id = "ability_cadence_echo",
		assetId = RBX_SLASH,
		sourceFile = "sci-fi-sounds/Audio/laserSmall_002.ogg",
		variantFiles = { "sci-fi-sounds/Audio/laserSmall_003.ogg" },
		volume = 0.42,
		pitchMin = 1.16,
		pitchMax = 1.28,
	}),
	-- Contra do Pulso: grave e seco. É o único som do kit que só existe depois
	-- de o servidor confirmar — nunca sai por intenção do jogador.
	ability_pulse_counter = cue({
		id = "ability_pulse_counter",
		assetId = RBX_SHATTER,
		sourceFile = "sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg",
		variantFiles = { "sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg" },
		volume = 0.72,
		pitchMin = 0.88,
		pitchMax = 0.96,
	}),

	-- ── Movimento e defesa ─────────────────────────────────────────────────
	dash = cue({
		id = "dash",
		assetId = RBX_WHOOSH,
		sourceFile = "sci-fi-sounds/Audio/spaceEngineSmall_000.ogg",
		variantFiles = { "sci-fi-sounds/Audio/spaceEngineSmall_001.ogg" },
		volume = 0.4,
		pitchMin = 1.05,
		pitchMax = 1.18,
		rolloffMaxStuds = 45,
	}),
	guard_raise = cue({
		id = "guard_raise",
		assetId = RBX_METAL,
		sourceFile = "rpg-audio/Audio/cloth1.ogg",
		volume = 0.28,
		pitchMin = 0.82,
		pitchMax = 0.92,
		rolloffMaxStuds = 30,
	}),
}

-- Mapa degrau da cadeia → deixa de corte de ar. Fora da faixa, cai no jab.
local LIGHT_SWING_BY_STEP: { string } = {
	"swing_light_1",
	"swing_light_2",
	"swing_light_3",
	"swing_light_4",
}

local CombatAudio = {}

function CombatAudio.get(cueId: string): AudioCue?
	return Cues[cueId]
end

function CombatAudio.all(): { AudioCue }
	local out: { AudioCue } = {}
	for _, def in Cues do
		table.insert(out, def)
	end
	return out
end

function CombatAudio.lightSwingId(step: number): string
	local index = math.clamp(math.floor(step), 1, #LIGHT_SWING_BY_STEP)
	return LIGHT_SWING_BY_STEP[index]
end

-- Peso do impacto por habilidade. As técnicas ficavam de fora deste mapa, então
-- Ombro Cometa e Cadência acertavam em silêncio: o corte de ar saía na
-- ativação e o contato não devolvia nada. Um teste garante que toda habilidade
-- que causa dano tenha impacto audível.
local IMPACT_BY_ABILITY: { [string]: string } = {
	light = "impact_light",
	heavy = "impact_heavy",
	-- Ombro é impacto de corpo inteiro: usa o peso do pesado.
	comet_shoulder = "impact_heavy",
	-- Cadência são golpes curtos e rápidos: peso de leve, repetido.
	broken_cadence = "impact_light",
	-- O ataque básico dos inimigos também precisa de retorno tátil.
	basic_enemy = "impact_light",
}

-- Deixa de impacto a partir do desfecho autoritativo do servidor.
function CombatAudio.impactId(abilityId: string?, outcome: string?): string?
	-- O contra do Pulso tem som próprio e é o único desfecho em que o defensor
	-- devolve dano; ele vence a leitura de guarda.
	if outcome == "counter" then
		return "ability_pulse_counter"
	elseif outcome == "guard" then
		return "impact_guard"
	elseif outcome ~= "hit" then
		return nil
	end
	if abilityId == nil then
		return nil
	end
	return IMPACT_BY_ABILITY[abilityId]
end

CombatAudio.ImpactByAbility = IMPACT_BY_ABILITY

-- Todo arquivo referenciado precisa existir e toda deixa precisa de faixa de
-- pitch coerente. Roda em teste para o catálogo não apodrecer em silêncio.
function CombatAudio.validate(): (boolean, string?)
	for id, def in Cues do
		if def.id ~= id then
			return false, ("deixa %s tem id divergente (%s)"):format(id, def.id)
		end
		if def.sourceFile == "" then
			return false, ("deixa %s não declara arquivo de origem"):format(id)
		end
		if def.pitchMin > def.pitchMax then
			return false, ("deixa %s tem pitchMin > pitchMax"):format(id)
		end
		if def.pitchMin <= 0 then
			return false, ("deixa %s tem pitch não positivo"):format(id)
		end
		if def.volume < 0 or def.volume > 1 then
			return false, ("deixa %s tem volume fora de 0..1"):format(id)
		end
		if def.rolloffMaxStuds <= 0 then
			return false, ("deixa %s tem alcance não positivo"):format(id)
		end
	end
	for step, cueId in LIGHT_SWING_BY_STEP do
		if not Cues[cueId] then
			return false, ("degrau %d aponta deixa inexistente (%s)"):format(step, cueId)
		end
	end
	return true, nil
end

-- Lista plana de todo arquivo que precisa de upload — usada pelo manifesto em
-- scripts/audio-manifest.luau e pelo teste de existência.
function CombatAudio.sourceFiles(): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, def in Cues do
		local files = { def.sourceFile }
		for _, extra in def.variantFiles do
			table.insert(files, extra)
		end
		for _, path in files do
			if not seen[path] then
				seen[path] = true
				table.insert(out, path)
			end
		end
	end
	table.sort(out)
	return out
end

return CombatAudio

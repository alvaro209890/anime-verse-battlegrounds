--!strict
-- Reprodução local das deixas de combate. Esta camada não decide acerto,
-- dano nem cooldown: ela só sonoriza um evento que já aconteceu.
--
-- Regras de apresentação (docs/16-COMBAT-AUDIO.md):
--   * corte de ar toca na intenção do jogador (é a ação dele, sempre local);
--   * impacto só toca com desfecho autoritativo vindo de CombatEvent;
--   * deixa sem assetId publicado é ignorada em silêncio, nunca erro;
--   * o mesmo golpe nunca sai idêntico duas vezes (variante + pitch).

export type Player = {
	catalog: any,
	soundParent: Instance?,
	soundGroup: any?,
	random: any,
	now: () -> number,
	-- Uma reprodução por deixa dentro dessa janela. Sem isso, dois eventos no
	-- mesmo frame empilham e o impacto sai com o dobro do volume.
	debounceSeconds: number,
	lastPlayedAt: { [string]: number },
	-- Sons ativos aguardando limpeza após tocar.
	active: { any },
	muted: boolean,
}

local CombatAudioPlayer = {}

local DEFAULT_DEBOUNCE_SECONDS = 0.04

-- Gerador padrão sobre math.random: o módulo não depende de `Random`, que é
-- global do Roblox e não existe em teste headless. Quem quiser stream próprio
-- injeta qualquer objeto com NextNumber().
local DefaultRandom = {}
function DefaultRandom.NextNumber(_self: any): number
	return math.random()
end

function CombatAudioPlayer.new(deps: {
	catalog: any,
	soundParent: Instance?,
	soundGroup: any?,
	random: any?,
	now: (() -> number)?,
	debounceSeconds: number?,
}): Player
	return {
		catalog = deps.catalog,
		soundParent = deps.soundParent,
		soundGroup = deps.soundGroup,
		random = deps.random or DefaultRandom,
		now = deps.now or os.clock,
		debounceSeconds = deps.debounceSeconds or DEFAULT_DEBOUNCE_SECONDS,
		lastPlayedAt = {},
		active = {},
		muted = false,
	}
end

-- Sorteia arquivo e pitch. Função pura o suficiente para ser testada sem
-- DataModel: recebe o gerador e devolve a decisão, sem criar Instance.
function CombatAudioPlayer.resolve(
	player: Player,
	cueId: string
): { assetId: string, volume: number, pitch: number, rolloffMaxStuds: number }?
	local cue = player.catalog.get(cueId)
	if not cue or cue.enabled ~= true then
		return nil
	end
	-- Sem upload ainda: a deixa existe no catálogo mas não tem asset. Silêncio
	-- é o comportamento correto — o jogo não deve quebrar esperando áudio.
	if cue.assetId == "" then
		return nil
	end
	local pitchSpan = cue.pitchMax - cue.pitchMin
	local pitch = if pitchSpan > 0 then cue.pitchMin + player.random:NextNumber() * pitchSpan else cue.pitchMin
	return {
		assetId = cue.assetId,
		volume = cue.volume,
		pitch = pitch,
		rolloffMaxStuds = cue.rolloffMaxStuds,
	}
end

local function debounced(player: Player, cueId: string): boolean
	local now = player.now()
	local last = player.lastPlayedAt[cueId]
	if last and (now - last) < player.debounceSeconds then
		return true
	end
	player.lastPlayedAt[cueId] = now
	return false
end

-- `at` opcional: quando presente, o som é posicional (impacto no alvo);
-- quando ausente, toca 2D — a própria ação do jogador não deve sumir com a
-- distância da câmera.
function CombatAudioPlayer.play(player: Player, cueId: string, at: Instance?): boolean
	if player.muted then
		return false
	end
	if debounced(player, cueId) then
		return false
	end
	local resolved = CombatAudioPlayer.resolve(player, cueId)
	if not resolved then
		return false
	end
	local parent = at or player.soundParent
	if not parent then
		return false
	end

	local sound = Instance.new("Sound")
	sound.SoundId = resolved.assetId
	sound.Volume = resolved.volume
	sound.PlaybackSpeed = resolved.pitch
	sound.RollOffMaxDistance = resolved.rolloffMaxStuds
	sound.RollOffMinDistance = 6
	if player.soundGroup then
		sound.SoundGroup = player.soundGroup
	end
	sound.Parent = parent
	table.insert(player.active, sound)
	-- Limpeza: sem isso cada golpe deixa uma Instance órfã para sempre.
	sound.Ended:Connect(function()
		local index = table.find(player.active, sound)
		if index then
			table.remove(player.active, index)
		end
		sound:Destroy()
	end)
	sound:Play()
	return true
end

function CombatAudioPlayer.setMuted(player: Player, muted: boolean): ()
	player.muted = muted
end

function CombatAudioPlayer.stopAll(player: Player): ()
	for _, sound in player.active do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
	table.clear(player.active)
	table.clear(player.lastPlayedAt)
end

return CombatAudioPlayer

--!strict
-- Catálogo de clipes de animação de combate (docs/14-ANIMATION-PLAN.md §5.1).
--
-- Por que existe: o overlay procedural do `PlayerCombatAnimator` compõe alguns
-- graus por junta em cima da animação que o Roblox já toca. No avatar real do
-- jogador, visto de longe, isso lê como "nada aconteceu" — foi exatamente a
-- reclamação do playtest de 14:26 (docs/18 §7). Um clipe de corpo inteiro
-- resolve a leitura; o procedural continua rodando por cima como tempero.
--
-- Assets: só animações do criador **Roblox** (userId 1), que qualquer
-- experiência pode tocar sem upload nem compra. Verificados em 2026-08-13 via
-- `economy.roblox.com/v2/assets/<id>/details`:
--   522635514 — "R15 Sword Slash"  (Creator: Roblox, AssetTypeId 24)
--   522638767 — "R15 Sword Lunge"  (Creator: Roblox, AssetTypeId 24)
-- São PLACEHOLDER honesto: leem como golpe de braço, não são os clipes finais
-- do jogo (Gate A1 de docs/14 continua aberto).
--
-- `nominalSeconds` é a duração do clipe na velocidade 1, **medida no Studio**
-- em 2026-08-13 15h30 (`AnimationTrack.Length` com o track carregado, via MCP):
--   522635514 → 0,500 s   ·   522638767 → 1,500 s
-- A primeira versão deste catálogo chutou 0,53/0,60 e o lunge acabou tocando a
-- 1,65× para "caber": em 1,5 s de clipe, isso mostrava um quarto do movimento
-- e lia como espasmo. Era a reclamação "as animações estão feias" (docs/18 §8).
-- Nunca declare esses números de cabeça: meça de novo se trocar de asset.
--
-- Tipos inline para o módulo carregar em teste Lune (sem DataModel).

export type Clip = {
	action: string,
	assetId: string,
	-- Multiplicador de velocidade do track. O clipe precisa caber na duração da
	-- ação: quem decide o tempo do golpe é o servidor, não a animação.
	speed: number,
	fadeInSeconds: number,
	fadeOutSeconds: number,
	weight: number,
	nominalSeconds: number,
	source: string,
}

local SLASH = "rbxassetid://522635514"
local LUNGE = "rbxassetid://522638767"
local SLASH_SECONDS = 0.5
local LUNGE_SECONDS = 1.5

local CombatAnimations = {}

-- Duração de cada ação no cliente (espelha PlayerCombatAnimator.Durations e a
-- cadeia leve). Um teste garante que os dois lados não divergem.
local ACTION_SECONDS: { [string]: number } = {
	BasicHeavy = 0.52,
	Ability1 = 0.75,
	Ability2 = 0.68,
	Ability3 = 0.73,
	Ability2Echo = 0.52,
	Ability3Counter = 0.44,
}

local LIGHT_CHAIN_SECONDS: { number } = { 0.240, 0.300, 0.380, 0.480 }

local function clip(values: {
	action: string,
	assetId: string,
	speed: number,
	nominalSeconds: number,
	fadeInSeconds: number?,
	fadeOutSeconds: number?,
	weight: number?,
}): Clip
	return {
		action = values.action,
		assetId = values.assetId,
		speed = values.speed,
		fadeInSeconds = values.fadeInSeconds or 0.03,
		fadeOutSeconds = values.fadeOutSeconds or 0.16,
		weight = values.weight or 1.15,
		nominalSeconds = values.nominalSeconds,
		source = "Roblox (userId 1) — placeholder livre, docs/14 §5.1",
	}
end

-- Cadeia leve: os três primeiros degraus usam o clipe CURTO (slash),
-- desacelerando de 1,92× até 1,22×. O jab sai estalado e o meio da cadeia
-- ganha peso sem virar borrão. O FINALIZADOR (degrau 4) troca para o clipe
-- LONGO (lunge) a 2,9×: é o único degrau com janela para ele (0,48 s de ação
-- vs 1,5/2,9 = 0,52 s de clipe — o jogador vê ~93% do movimento, quase em
-- tempo real). Fecha a cadeia com corpo inteiro em vez do 4º slash repetido.
local LIGHT_CHAIN: { Clip } = {
	clip({ action = "BasicLight1", assetId = SLASH, speed = 1.92, nominalSeconds = SLASH_SECONDS }),
	clip({ action = "BasicLight2", assetId = SLASH, speed = 1.55, nominalSeconds = SLASH_SECONDS }),
	clip({ action = "BasicLight3", assetId = SLASH, speed = 1.22, nominalSeconds = SLASH_SECONDS }),
	clip({
		action = "BasicLight4",
		assetId = LUNGE,
		speed = 2.9,
		nominalSeconds = LUNGE_SECONDS,
		fadeInSeconds = 0.04,
	}),
}

-- Guarda e dash ficam de fora de propósito: não existe clipe grátis do Roblox
-- que leia como aparo ou esquiva, e um golpe de espada no lugar mentiria sobre
-- a ação. Essas duas continuam 100% procedurais (docs/14 §5.1).
local ACTION_CLIPS: { [string]: Clip } = {
	BasicHeavy = clip({
		action = "BasicHeavy",
		assetId = LUNGE,
		speed = 2.7,
		nominalSeconds = LUNGE_SECONDS,
		weight = 1,
	}),
	Ability1 = clip({ action = "Ability1", assetId = LUNGE, speed = 1.9, nominalSeconds = LUNGE_SECONDS }),
	Ability2 = clip({ action = "Ability2", assetId = SLASH, speed = 0.7, nominalSeconds = SLASH_SECONDS }),
	Ability3 = clip({ action = "Ability3", assetId = SLASH, speed = 0.65, nominalSeconds = SLASH_SECONDS }),
	Ability2Echo = clip({ action = "Ability2Echo", assetId = SLASH, speed = 0.9, nominalSeconds = SLASH_SECONDS }),
	Ability3Counter = clip({
		action = "Ability3Counter",
		assetId = SLASH,
		speed = 1.06,
		nominalSeconds = SLASH_SECONDS,
	}),
}

-- Clipe da ação. `comboStep` só importa para a cadeia leve; fora dela o degrau
-- é ignorado. Sem clipe declarado devolve nil — quem chama cai no procedural.
function CombatAnimations.forAction(action: string, comboStep: number?): Clip?
	if action == "BasicLight" then
		local step = math.clamp(math.floor(tonumber(comboStep) or 1), 1, #LIGHT_CHAIN)
		return LIGHT_CHAIN[step]
	end
	return ACTION_CLIPS[action]
end

function CombatAnimations.all(): { Clip }
	local out: { Clip } = {}
	for _, entry in LIGHT_CHAIN do
		table.insert(out, entry)
	end
	for _, entry in ACTION_CLIPS do
		table.insert(out, entry)
	end
	return out
end

function CombatAnimations.assetIds(): { string }
	return { SLASH, LUNGE }
end

-- Duração declarada da ação (para validação e para quem precisa do orçamento).
function CombatAnimations.actionSeconds(action: string, comboStep: number?): number?
	if action == "BasicLight" then
		local step = math.clamp(math.floor(tonumber(comboStep) or 1), 1, #LIGHT_CHAIN_SECONDS)
		return LIGHT_CHAIN_SECONDS[step]
	end
	return ACTION_SECONDS[action]
end

-- Honestidade visual (docs/14 §4.4, mesma regra do VFX): nenhuma pose
-- sobrevive à ação. Forçar o clipe INTEIRO dentro da janela exigiria acelerar
-- 4× um clipe de 1,5 s — foi o que deixou tudo feio. A regra prática: o clipe
-- pode passar no máximo 15% da ação, e quem garante o corte é o runtime
-- (`CharacterAnimationPlayer.step` para o track com fade no fim da ação).
local OVERRUN_LIMIT = 1.15

function CombatAnimations.validate(): (boolean, string?)
	for index, entry in LIGHT_CHAIN do
		local budget = LIGHT_CHAIN_SECONDS[index]
		local ok, reason = CombatAnimations.validateClip(entry, budget)
		if not ok then
			return false, reason
		end
	end
	for action, entry in ACTION_CLIPS do
		local ok, reason = CombatAnimations.validateClip(entry, ACTION_SECONDS[action])
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

function CombatAnimations.validateClip(entry: Clip, budgetSeconds: number?): (boolean, string?)
	if string.match(entry.assetId, "^rbxassetid://%d+$") == nil then
		return false, ("%s: assetId inválido (%s)"):format(entry.action, entry.assetId)
	end
	if entry.speed <= 0 or entry.speed ~= entry.speed then
		return false, ("%s: speed precisa ser positivo"):format(entry.action)
	end
	if entry.nominalSeconds <= 0 then
		return false, ("%s: nominalSeconds precisa ser positivo"):format(entry.action)
	end
	if entry.fadeInSeconds < 0 or entry.fadeOutSeconds < 0 then
		return false, ("%s: fade não pode ser negativo"):format(entry.action)
	end
	if entry.weight <= 0 then
		return false, ("%s: weight precisa ser positivo"):format(entry.action)
	end
	if budgetSeconds == nil then
		return false, ("%s: ação sem duração declarada"):format(entry.action)
	end
	local playedSeconds = entry.nominalSeconds / entry.speed
	if playedSeconds > budgetSeconds * OVERRUN_LIMIT then
		return false,
			("%s: clipe dura %.3fs e a ação só tem %.3fs (limite %.0f%%)"):format(
				entry.action,
				playedSeconds,
				budgetSeconds,
				OVERRUN_LIMIT * 100
			)
	end
	-- Velocidade fora de 0,5×–3× não existe como leitura: ou é câmera lenta ou
	-- é borrão. Se um clipe novo pedir isso, o problema é a escolha do clipe.
	if entry.speed < 0.5 or entry.speed > 3 then
		return false, ("%s: velocidade %.2f× fora da faixa legível (0,5×–3×)"):format(entry.action, entry.speed)
	end
	return true, nil
end

return CombatAnimations

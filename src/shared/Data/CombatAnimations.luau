--!strict
-- Catálogo de clipes de animação de combate (docs/14-ANIMATION-PLAN.md §5.1).
--
-- Por que existe: o overlay procedural do `PlayerCombatAnimator` compõe graus
-- por junta. Um clipe de corpo inteiro por cima dá massa ao golpe — mas só
-- quando o clipe é tocado numa velocidade em que dá para ver o que ele faz.
--
-- ⚠️ HISTÓRICO — leia antes de mexer nos números. Até 2026-08-14 este catálogo
-- acelerava um clipe de 1,5 s a 2,7×–2,9× para "caber" na janela do golpe. Duas
-- medições no Studio (via KeyframeSequenceProvider) explicaram por que aquilo
-- era ilegível:
--   522635514 "R15 Corte de Espada" — Roblox (userId 1), AssetTypeId 24,
--     prioridade Action, 4 quadros: 0 / 0,20 / 0,30 / 0,50 s.
--     Ou seja: antecipação até 0,20, GOLPE de 0,20 a 0,30, recuperação até 0,50.
--   522638767 "R15 Lunge de Espada" — Roblox, prioridade Idle, e apenas DOIS
--     quadros: 0 e 1,5 s. Não é uma animação, é uma interpolação linear entre
--     duas poses. Acelerada 2,9× virava um espasmo — e era o clipe que estava
--     no finalizador, no pesado e no Ombro Cometa.
-- O lunge saiu do catálogo por isso. Nunca declare esses números de cabeça:
-- meça de novo (KeyframeSequenceProvider) se trocar de asset.
--
-- A técnica que substituiu a aceleração é o JANELAMENTO: em vez de espremer o
-- clipe inteiro na janela da ação, `startTimeSeconds` entra no instante certo e
-- toca só o trecho que interessa, em velocidade legível. Um jab de 240 ms passa
-- o trecho 0,20→0,50 (golpe + recuperação) a 1,25× em vez de 0→0,50 a 2,08×:
-- o jogador vê o golpe em vez de ver tudo borrado.
--
-- E onde um corte de espada MENTIRIA sobre a ação, não há clipe: chute, Ombro
-- Cometa (o que viaja é o ombro, o braço não estende — docs/18 §2.1), Retorno
-- de Pulso, guarda e dash. Essas ficam 100% procedurais. Um braço de espada num
-- chute é pior que nenhuma animação: informa errado.
--
-- Tipos inline para o módulo carregar em teste Lune (sem DataModel).

export type Clip = {
	action: string,
	assetId: string,
	-- Multiplicador de velocidade do track. Quem decide o tempo do golpe é o
	-- servidor; o clipe se encaixa nele, nunca o contrário.
	speed: number,
	-- Instante do clipe em que a reprodução começa (janelamento). 0 = do início.
	startTimeSeconds: number,
	fadeInSeconds: number,
	fadeOutSeconds: number,
	weight: number,
	nominalSeconds: number,
	source: string,
}

local SLASH = "rbxassetid://522635514"
local SLASH_SECONDS = 0.5
-- Instante em que o corte começa de fato no clipe (quadro medido em 0,20 s).
local SLASH_STRIKE_AT = 0.2

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
	startTimeSeconds: number?,
	fadeInSeconds: number?,
	fadeOutSeconds: number?,
	weight: number?,
}): Clip
	return {
		action = values.action,
		assetId = values.assetId,
		speed = values.speed,
		startTimeSeconds = values.startTimeSeconds or 0,
		fadeInSeconds = values.fadeInSeconds or 0.03,
		fadeOutSeconds = values.fadeOutSeconds or 0.16,
		weight = values.weight or 1.15,
		nominalSeconds = values.nominalSeconds,
		source = "Roblox (userId 1) — placeholder livre, docs/14 §5.1",
	}
end

-- Cadeia leve. Os dois primeiros degraus são socos curtos: entram direto no
-- corte (0,20 s) e ficam com o trecho golpe+recuperação, a 1,25× e 1,00×. O
-- degrau 3 é CHUTE e não tem clipe — quem carrega é a pose procedural. O
-- degrau 4 é o finalizador giratório, o único com janela para o clipe inteiro
-- (0,48 s de ação para 0,50 s de clipe): entra em 1,04× e mostra tudo,
-- antecipação incluída.
-- Chaveada pelo degrau, não posicional: o degrau 3 é um buraco de propósito, e
-- uma lista com nil no meio deixa `#` indefinido em Lua.
local LIGHT_CHAIN: { [number]: Clip } = {
	[1] = clip({
		action = "BasicLight1",
		assetId = SLASH,
		speed = 1.25,
		startTimeSeconds = SLASH_STRIKE_AT,
		nominalSeconds = SLASH_SECONDS,
	}),
	[2] = clip({
		action = "BasicLight2",
		assetId = SLASH,
		speed = 1.0,
		startTimeSeconds = SLASH_STRIKE_AT,
		nominalSeconds = SLASH_SECONDS,
	}),
	[4] = clip({
		action = "BasicLight4",
		assetId = SLASH,
		speed = 1.04,
		nominalSeconds = SLASH_SECONDS,
		fadeInSeconds = 0.04,
	}),
}

-- Guarda, dash, chute, Ombro Cometa e Retorno de Pulso ficam de fora de
-- propósito (ver cabeçalho): não existe clipe grátis do Roblox que leia como
-- aparo, esquiva, chute, ombrada ou postura defensiva, e um corte de espada no
-- lugar mentiria sobre a ação.
local ACTION_CLIPS: { [string]: Clip } = {
	BasicHeavy = clip({
		action = "BasicHeavy",
		assetId = SLASH,
		speed = 0.96,
		nominalSeconds = SLASH_SECONDS,
		weight = 1,
	}),
	Ability2 = clip({ action = "Ability2", assetId = SLASH, speed = 0.74, nominalSeconds = SLASH_SECONDS }),
	Ability2Echo = clip({
		action = "Ability2Echo",
		assetId = SLASH,
		speed = 0.58,
		startTimeSeconds = SLASH_STRIKE_AT,
		nominalSeconds = SLASH_SECONDS,
	}),
	Ability3Counter = clip({
		action = "Ability3Counter",
		assetId = SLASH,
		speed = 0.68,
		startTimeSeconds = SLASH_STRIKE_AT,
		nominalSeconds = SLASH_SECONDS,
	}),
}

-- Clipe da ação. `comboStep` só importa para a cadeia leve; fora dela o degrau
-- é ignorado. Sem clipe declarado devolve nil — quem chama cai no procedural.
function CombatAnimations.forAction(action: string, comboStep: number?): Clip?
	if action == "BasicLight" then
		local step = math.clamp(math.floor(tonumber(comboStep) or 1), 1, #LIGHT_CHAIN_SECONDS)
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
	return { SLASH }
end

-- Duração declarada da ação (para validação e para quem precisa do orçamento).
function CombatAnimations.actionSeconds(action: string, comboStep: number?): number?
	if action == "BasicLight" then
		local step = math.clamp(math.floor(tonumber(comboStep) or 1), 1, #LIGHT_CHAIN_SECONDS)
		return LIGHT_CHAIN_SECONDS[step]
	end
	return ACTION_SECONDS[action]
end

-- Sobra permitida no fim do clipe: com janelamento, a janela tocada dura
-- exatamente a ação, então o trecho pedido tem de caber no clipe. 10 ms de
-- folga absorvem o arredondamento das velocidades declaradas acima.
local CLIP_TAIL_TOLERANCE = 0.01

-- Faixa de velocidade legível. Abaixo de 0,5× é câmera lenta; acima de 1,5× o
-- olho não acompanha e o golpe vira borrão — foi o erro que este arquivo
-- carregou até 2026-08-14, quando o limite era 3×.
local MIN_SPEED = 0.5
local MAX_SPEED = 1.5

CombatAnimations.MinSpeed = MIN_SPEED
CombatAnimations.MaxSpeed = MAX_SPEED

function CombatAnimations.validate(): (boolean, string?)
	for index, entry in LIGHT_CHAIN do
		local ok, reason = CombatAnimations.validateClip(entry, LIGHT_CHAIN_SECONDS[index])
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
	if entry.startTimeSeconds < 0 or entry.startTimeSeconds >= entry.nominalSeconds then
		return false,
			("%s: janela começa em %.3fs, fora do clipe de %.3fs"):format(
				entry.action,
				entry.startTimeSeconds,
				entry.nominalSeconds
			)
	end
	if budgetSeconds == nil then
		return false, ("%s: ação sem duração declarada"):format(entry.action)
	end
	if entry.speed < MIN_SPEED or entry.speed > MAX_SPEED then
		return false,
			("%s: velocidade %.2f× fora da faixa legível (%.1f×–%.1f×)"):format(
				entry.action,
				entry.speed,
				MIN_SPEED,
				MAX_SPEED
			)
	end
	-- Honestidade visual (docs/14 §4.4): a janela tocada tem exatamente a
	-- duração da ação, então nenhuma pose sobrevive a ela. O que falta checar é
	-- se esse trecho existe no clipe — pedir além do fim congela o último quadro
	-- e devolve a pose estática que o janelamento veio eliminar.
	local windowEnd = entry.startTimeSeconds + budgetSeconds * entry.speed
	if windowEnd > entry.nominalSeconds + CLIP_TAIL_TOLERANCE then
		return false,
			("%s: janela %.3f→%.3fs estoura o clipe de %.3fs"):format(
				entry.action,
				entry.startTimeSeconds,
				windowEnd,
				entry.nominalSeconds
			)
	end
	return true, nil
end

return CombatAnimations

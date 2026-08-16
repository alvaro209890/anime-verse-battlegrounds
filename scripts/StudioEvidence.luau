--!strict
-- Roteiro e critérios do playtest no Studio, como DADO.
--
-- O runbook em prosa está em `docs/32-STUDIO-PLAYTEST-RUNBOOK.md`; este módulo
-- é a mesma coisa numa forma que o CLI executa e o teste headless confere. Ele
-- não fala com o Studio, não abre socket e não tem efeito colateral no require:
-- é catálogo puro mais três funções de decisão.
--
-- Por que existir: a rodada de 14/08 provou que medição sem porteiro vira
-- conclusão errada. O Studio estava com DUAS janelas abertas e três commits de
-- correção ficaram invisíveis porque o Play rodava um place anterior a todos
-- eles. `syncGate` transforma isso em regra executável — fora de sync não se
-- mede, ponto.

export type Step = {
	id: string,
	gate: string,
	title: string,
	-- O que fazer no Play, em uma frase imperativa.
	action: string,
	-- O que precisa sair da sessão para o passo contar como executado.
	capture: { string },
	-- Critério de aprovação em uma linha; ambíguo aqui vira discussão depois.
	pass: string,
}

export type Threshold = {
	field: string,
	label: string,
	max: number?,
	min: number?,
}

export type PerfSample = { [string]: any }

-- Atalho de três passos para quando o Studio abrir em outra máquina.
-- NÃO entra na lista W1/A1: o primeiro passo de Play continua sendo `w1_sync`.
export type HomePrepStep = {
	id: string,
	title: string,
	-- Comando copiável. Vazio só no passo de Play (não há CLI que substitua).
	command: string,
	action: string,
	pass: string,
	play: boolean,
}

local StudioEvidence = {}

-- Ordem do dia. É a sequência de `docs/13` §10 (roteiro de 20 min) cruzada com
-- os gates de `docs/15` (W1), `docs/14` (A1) e `docs/12` §7 (matriz runtime).
local STEPS: { Step } = {
	{
		id = "w1_sync",
		gate = "W1",
		title = "Sincronia antes de qualquer medição",
		action = "Rodar `lune run scripts/avb-debug.luau sync` com o place aberto.",
		capture = { "saída do sync (matched/mismatched)", "nome do arquivo aberto no Studio" },
		pass = "inSync = true. Exit 2 encerra a sessão: nada medido nesse estado vale.",
	},
	{
		id = "w1_boot",
		gate = "W1",
		title = "Boot limpo",
		action = "Play solo e ler o Output do começo ao fim.",
		capture = { "Output completo", "`avb-debug studioerrors`", "print `[Bootstrap] servidor pronto (F0)`" },
		pass = "Nenhum erro Luau do jogo; o bootstrap chega ao fim.",
	},
	{
		id = "w1_spawn",
		gate = "W1",
		title = "Spawn e leitura da sala",
		action = "Ficar parado no spawn e girar a câmera 360°.",
		capture = { "print frontal, perfil e três quartos", "`avb-debug greybox`" },
		pass = "Piso sem z-fighting, teto sem escurecer a cena, praça e as duas rotas legíveis sem minimapa.",
	},
	{
		id = "w1_instructor",
		gate = "W1",
		title = "Instrutora pelo ProximityPrompt",
		action = "Chegar perto da Instrutora, aceitar o objetivo e depois tentar de 15 studs.",
		capture = { "print do prompt visível", "tracker do objetivo no HUD", "recusa `too_far` no Output" },
		pass = "Um único prompt aparece, o aceite abre o tracker e a interação distante é recusada pelo servidor.",
	},
	{
		id = "w1_marker",
		gate = "W1",
		title = "Marco de Retorno com hold de 1,5 s",
		action = "Segurar a interação no Marco fora de combate e soltar antes no primeiro teste.",
		capture = { "print do hold em progresso", "recibo de consolidação no Output" },
		pass = "Soltar cedo não consolida; 1,5 s medidos pelo servidor consolidam com recibo idempotente.",
	},
	{
		id = "w1_gates",
		gate = "W1",
		title = "As duas saídas, sem cair",
		action = "Sair pelo Portão Norte e voltar; sair pelo Portão Oeste e voltar.",
		capture = { "vídeo curto das duas travessias", "os cinco sinais da fronteira", "Output do ZoneEvent" },
		pass = "Nenhum buraco de piso, nenhum snag, hold de 0,6 s exigido na primeira ida e faixa de PvP visível.",
	},
	{
		id = "a1_impact",
		gate = "A1",
		title = "Impacto de verdade, ENCOSTADO no alvo",
		action = "Encostar no boneco de treino (≤ 6 studs) e acertar leve, pesado e Ombro Cometa.",
		capture = {
			"vídeo em 60 fps dos três golpes",
			"número de dano na tela",
			"Output sem `[Combat] ... errou`",
		},
		pass = "Os três conectam e a camada de impacto aparece: hit-stop, tremida, luz, som e número.",
	},
	{
		id = "a1_chain",
		gate = "A1",
		title = "Cadeia leve de quatro degraus",
		action = "Quatro cliques seguidos dentro da janela de 0,65 s.",
		capture = { "vídeo dos quatro degraus", "`props` da junta Root durante o golpe" },
		pass = "Silhueta distinta por degrau e `Root.Transform.Z` diferente de zero — se der zero, é o defeito de docs/14 §4.7.",
	},
	{
		id = "w1_death",
		gate = "W1",
		title = "Morte e retorno",
		action = "Morrer na planície e voltar.",
		capture = { "Output da perda de XP", "posição do respawn" },
		pass = "Respawn no Marco de Retorno com a perda de XP da zona aplicada uma única vez.",
	},
	{
		id = "w1_elite",
		gate = "W1",
		title = "Elite na cratera",
		action = "Ir até a cratera e sobreviver a um ciclo de combo e um de slam.",
		capture = { "vídeo do telegraph de 700 ms", "print da coroa de cinco pontas" },
		pass = "Telegraph legível antes do golpe, ringue livre de decoração e a coroa lê à distância.",
	},
	{
		id = "w2_perf",
		gate = "W2",
		title = "Orçamento de desempenho",
		action = "Repetir o roteiro com 4 Estilhaços vivos e o elite, medindo com o MicroProfiler.",
		capture = { "`avb-debug perf`", "captura do MicroProfiler", "modelo do dispositivo" },
		pass = "Dentro dos limites da tabela de thresholds; PC integrado 60 FPS, Android de entrada 30 FPS sustentados.",
	},
}

local HOME_PREP: { HomePrepStep } = {
	{
		id = "home_build",
		title = "Gerar o place canônico",
		command = ".\\scripts\\build-studio.ps1",
		action = "No PowerShell, na raiz do repo. Fecha lock órfão; aborta se o Studio estiver vivo.",
		pass = "Imprime tamanho, data e SHA-256 de anime-verse-battlegrounds.rbxl. Esse é o único place a abrir.",
		play = false,
	},
	{
		id = "home_sync",
		title = "Conferir sincronia",
		command = "lune run scripts/avb-debug.luau sync",
		action = "Com o place aberto, o plugin AvbDebug instalado e a ponte local no ar.",
		pass = "Exit 0 segue. Exit 2 encerra: reabra o place e não anote nada.",
		play = false,
	},
	{
		id = "home_impact",
		title = "Impacto de verdade (passo a1_impact)",
		command = "",
		action = "Play, uma janela só. Andar até o dummy (≤ 6 studs) e acertar leve, pesado e Ombro Cometa.",
		pass = "Os três conectam e a camada de impacto aparece: hit-stop, tremida, luz, som e número.",
		play = true,
	},
}

-- Limites de `docs/14` §8. São **F0-BASELINE**: número inicial para medir, não
-- promessa de produto. Estourar não reprova sozinho — obriga a registrar o
-- dispositivo, o cenário e a decisão.
local THRESHOLDS: { Threshold } = {
	{ field = "heartbeatTimeMs", label = "tempo de Heartbeat", max = 16.6 },
	{ field = "physicsStepTimeMs", label = "passo de física", max = 8 },
	{ field = "totalMemoryMb", label = "memória total", max = 1400 },
	{ field = "workspaceParts", label = "BaseParts no Workspace", max = 6000 },
}

function StudioEvidence.steps(): { Step }
	local out: { Step } = {}
	for _, step in STEPS do
		table.insert(out, step)
	end
	return out
end

function StudioEvidence.stepsForGate(gate: string): { Step }
	local out: { Step } = {}
	for _, step in STEPS do
		if step.gate == gate then
			table.insert(out, step)
		end
	end
	return out
end

function StudioEvidence.thresholds(): { Threshold }
	return THRESHOLDS
end

function StudioEvidence.homePrep(): { HomePrepStep }
	local out: { HomePrepStep } = {}
	for _, step in HOME_PREP do
		table.insert(out, step)
	end
	return out
end

-- Porteiro da sessão. Recebe a resposta do comando `sync` e decide se vale
-- medir qualquer coisa. Sem `inSync`, medir é opinar sobre outro place.
function StudioEvidence.syncGate(syncResult: { [string]: any }?): (boolean, string)
	if type(syncResult) ~= "table" then
		return false, "sem resposta do sync — a ponte de debug não respondeu"
	end
	if syncResult.ok == false then
		return false, tostring(syncResult.error or "sync falhou")
	end
	if syncResult.inSync ~= true then
		local mismatched = if type(syncResult.mismatched) == "table" then #syncResult.mismatched else 0
		local missing = if type(syncResult.missingInStudio) == "table" then #syncResult.missingInStudio else 0
		return false,
			("fora de sync: %d divergente(s), %d ausente(s) no Studio — não meça nada nesta sessão"):format(
				mismatched,
				missing
			)
	end
	return true, "em sync"
end

-- Confere uma amostra de `avb-debug perf` contra os baselines. Devolve a lista
-- do que estourou; vazia = dentro do orçamento. Campo ausente é IGNORADO de
-- propósito: `Stats` nem sempre publica tudo, e inventar zero viraria aprovação
-- falsa.
function StudioEvidence.evaluatePerf(sample: PerfSample?): (boolean, { string })
	local breaches: { string } = {}
	if type(sample) ~= "table" then
		return false, { "amostra de desempenho ausente" }
	end
	for _, threshold in THRESHOLDS do
		local value = sample[threshold.field]
		if type(value) == "number" then
			if threshold.max ~= nil and value > threshold.max then
				table.insert(breaches, ("%s: %.2f acima do teto %.2f"):format(threshold.label, value, threshold.max))
			end
			if threshold.min ~= nil and value < threshold.min then
				table.insert(breaches, ("%s: %.2f abaixo do piso %.2f"):format(threshold.label, value, threshold.min))
			end
		end
	end
	return #breaches == 0, breaches
end

-- Catálogo bem formado: id único, gate conhecido, e todo passo com ação,
-- captura e critério. Um passo sem critério de aprovação é convite para
-- "pareceu ok" virar evidência.
function StudioEvidence.validate(): (boolean, string?)
	local seen: { [string]: boolean } = {}
	local gates: { [string]: boolean } = { W1 = true, A1 = true, R1 = true, W2 = true }
	for _, step in STEPS do
		if step.id == "" or seen[step.id] then
			return false, "id de passo duplicado ou vazio: " .. step.id
		end
		seen[step.id] = true
		if not gates[step.gate] then
			return false, ("gate desconhecido em %s: %s"):format(step.id, step.gate)
		end
		if step.title == "" or step.action == "" or step.pass == "" then
			return false, "passo sem título, ação ou critério: " .. step.id
		end
		if #step.capture == 0 then
			return false, "passo sem captura declarada: " .. step.id
		end
	end
	if not seen.w1_sync then
		return false, "o passo de sincronia é obrigatório e precisa vir primeiro"
	end
	if STEPS[1].id ~= "w1_sync" then
		return false, "sincronia tem de ser o primeiro passo do roteiro"
	end
	for _, threshold in THRESHOLDS do
		if threshold.field == "" or threshold.label == "" then
			return false, "threshold sem campo ou rótulo"
		end
		if threshold.max == nil and threshold.min == nil then
			return false, "threshold sem limite: " .. threshold.field
		end
	end
	if #HOME_PREP ~= 3 then
		return false, "atalho de casa precisa ter exatamente três passos"
	end
	if HOME_PREP[1].id ~= "home_build" or HOME_PREP[2].id ~= "home_sync" or HOME_PREP[3].id ~= "home_impact" then
		return false, "atalho de casa fora de ordem: build, sync, impacto"
	end
	for _, step in HOME_PREP do
		if step.title == "" or step.action == "" or step.pass == "" then
			return false, "passo de casa sem título, ação ou critério: " .. step.id
		end
		if step.play then
			if step.command ~= "" then
				return false, "passo de Play não leva comando de CLI: " .. step.id
			end
		elseif step.command == "" then
			return false, "passo de casa sem comando: " .. step.id
		end
	end
	if HOME_PREP[3].play ~= true then
		return false, "o terceiro passo de casa é o Play no dummy"
	end
	return true, nil
end

return StudioEvidence

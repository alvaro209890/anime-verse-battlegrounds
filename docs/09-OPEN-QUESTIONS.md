# Questões abertas e registro canônico de decisões

## 1. Como usar este documento

Este arquivo é a fonte canônica das decisões de produto. Os demais documentos detalham
as regras, mas não podem alterar silenciosamente o que está registrado aqui.

Cada decisão distingue:

- **política aprovada:** direção que só muda por nova decisão registrada;
- **baseline de protótipo:** número inicial a implementar e medir;
- **gate de evidência:** condição necessária antes de promover a regra ao lançamento.

As decisões de Q-009 a Q-030 foram selecionadas pelo Codex por delegação explícita de
Álvaro em 2026-08-12. Isso não substitui validação jurídica, teste de jogo, profiling,
economia observada ou políticas vigentes da Roblox quando esses gates forem citados.

## 2. Decisões anteriores à Fase 0

### Q-001 — Qual é a identidade original final do produto?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** manter visual, silhuetas e kits próximos dos animes de
  referência, trocando os nomes públicos.
- **Risco aceito:** renomear não elimina risco de obra derivada ou trade dress.
- **Justificativa:** preserva a direção criativa já aprovada sem apresentar a simples
  troca de nomes como proteção jurídica suficiente.
- **Gate:** P1 continua obrigatório antes de concept art, áudio, animações, marketing
  ou publicação. Licenciamento formal ou parecer especializado pode exigir redesign.

### Q-002 — O nome “Anime Verse Battlegrounds” será mantido?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** manter o nome, condicionado a busca de marca e colisões na
  Roblox e fora dela.
- **Justificativa:** mantém o reconhecimento do briefing enquanto a validação de marca
  ainda pode exigir mudança antes da publicação.
- **Mitigação:** gênero e store page devem comunicar Action RPG persistente, evitando
  a expectativa de arena descartável.

### Q-003 — Qual público e classificação orientam o design?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** público 13+, tom sombrio e gore leve dentro das políticas da
  Roblox; sem gore extremo, linguagem imprópria ou monetização por urgência.
- **Justificativa:** sustenta a fantasia de ação sem ampliar desnecessariamente o risco
  de maturidade, moderação e acesso do público principal.
- **Gate:** preencher e manter correto o questionário de maturidade da experiência.

### Q-004 — Qual equipe, orçamento e horizonte existem?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** equipe de 1–3 pessoas; reduzir conteúdo, nunca autoridade,
  integridade do save, QA multiplataforma, telemetria ou segurança.
- **Justificativa:** conteúdo é o corte reversível; retirar fundações técnicas criaria
  dívida e risco operacional desproporcionais para uma equipe pequena.
- **Planejamento:** estimativas são expressas em pessoa-meses e recalibradas após F0.

### Q-005 — Qual é a matriz mínima de dispositivos?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** Android de entrada, telefone mediano, PC com gráficos
  integrados e gamepad.
- **Justificativa:** cobre os contextos de acesso mais relevantes sem confundir uma
  categoria de dispositivo com prova de desempenho real.
- **Gate:** modelos, memória, resolução e condições de rede são registrados depois do
  benchmark da fatia; a categoria sozinha não prova desempenho.

### Q-006 — Qual câmera e modelo de alvo definem o combate?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** soft lock contextual para ataques básicos, assistência
  configurável em toque/gamepad e habilidades de área direcionáveis.
- **Justificativa:** mantém leitura e agência no PC, reduz atrito de precisão no toque
  e evita automação que decida o combate pelo jogador.

### Q-007 — Quantos jogadores e quais places?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** faixa-alvo de 16–24 jogadores; arena em place e servidor
  reservado.
- **Justificativa:** servidores compactos favorecem legibilidade e custo previsível;
  separar a arena isola regras competitivas e recuperação de partidas.
- **Baseline:** iniciar testes com 16 e promover 20/24 somente após profiling.

### Q-008 — Qual conjunto mínimo prova a fatia vertical?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro.
- **Política aprovada:** uma identidade, ataque básico, dash, guarda, três técnicas,
  um recurso, vila segura, área livre, inimigo simples, objetivo, PvP e save.
- **Justificativa:** é o menor corte que testa o loop ponta a ponta e os riscos de rede,
  persistência e transição PvE/PvP antes de multiplicar conteúdo.
- **Corte:** ultimate é stretch goal da F0.

## 3. Build, progressão e equipamento

### Q-009 — Ressonância, pontos ou modelo combinado?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** Ressonância 2.0 combina quatro unidades de capacidade, uma
  ultimate, impacto máximo 12, no máximo uma técnica `Definidora` e Dissonância.
- **Validação:** calcular `rawD`; `rawD > 3` invalida o loadout. Não fazer clamp
  para transformar mistura excessiva em D = 3.
- **Justificativa:** capacidade e impacto limitam poder absoluto, enquanto Dissonância
  preserva identidade de família sem permitir uma build com todas as melhores respostas.
- **Baseline:** manter os multiplicadores D = 0–3 do GDD durante F1.
- **Regra comercial:** nenhum produto pago reduz slot, impacto ou Dissonância.

### Q-010 — Os nomes atuais das famílias serão públicos?

- **Estado:** ✅ DIREÇÃO APROVADA PARA PLANEJAMENTO — 2026-08-12 — Álvaro
  (seleção delegada ao Codex).
- **Política aprovada:** Fluxo Vital, Éter Umbral, Contrafluxo e Ímpeto Metamórfico.
  HUD compacto usa Fluxo, Umbral, Contra e Ímpeto, sempre com ícones distintos.
- **Justificativa:** o vocabulário diferencia recursos no HUD e mantém IDs estáveis,
  sem antecipar a aprovação jurídica dos nomes públicos.
- **Gate:** nomes públicos continuam condicionados ao P1; IDs internos não mudam por
  renomeação pública.

### Q-011 — Progressão altera números, comportamento ou ambos?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** comportamento é dominante. Níveis 3, 6 e 9 liberam mudanças
  laterais; níveis 2, 5 e 8 concedem até 2% cada, com teto de 6%; nível 10 entrega
  cosmético ou qualidade de vida.
- **Justificativa:** variantes sustentam expressão e aprendizado; o teto numérico baixo
  impede que tempo de conta substitua habilidade, sobretudo fora do ranked.
- **Competitivo:** ranked remove ganhos numéricos e preserva variantes legais.

### Q-012 — Qual teto e duração da maestria?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** técnica com 10 níveis; família com 20.
- **Baseline:** técnica nível 10 em 3,4–4,9 h de uso significativo; família em
  18–24 h com build pura e 24–32 h com XP dividida em híbrida.
- **Justificativa:** a técnica entrega progresso perceptível em poucas sessões, enquanto
  a família sustenta uma meta longa sem atrasar a diversão inicial.
- **Curva de entrada:** combate até 60 s, objetivo visível até 3 min, primeira técnica
  permanente até 5 min, primeiro breakpoint em 15–20 min, três técnicas em 45–60 min,
  ultimate/build pura em 8–10 h e alternativa híbrida em 16–20 h.
- **Gate:** tempos são metas de coorte, não bloqueios rígidos; ajustar por retenção.

### Q-013 — Como funciona o respec?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** desfazer gratuito durante 30 min e primeira troca permanente
  gratuita por técnica; nível e XP são preservados.
- **Justificativa:** experimentar não deve punir o novato, mas mudanças repetidas ainda
  precisam de um sumidouro leve e proteção contra troca oportunista em combate.
- **Baseline:** `500 + 150 × nível + 250 × respecs nos últimos 7 dias`, máximo
  3.000 Marcas, com cooldown de 5 min por técnica.
- **Contexto:** somente zona segura/treino ou antes de confirmar fila.
- **Monetização:** ticket pago fica fora do soft launch; se existir depois, apenas
  substitui moeda e não ignora cooldown ou contexto.

### Q-014 — Quanto atributo bruto um equipamento concede?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** três slots e sidegrades comportamentais como valor principal.
- **Justificativa:** poucos slots e caps pequenos mantêm equipamento desejável sem
  transformar drop em vantagem obrigatória ou dupla de ataque e sobrevivência.
- **Baseline:** no máximo um bônus bruto de 2% por item; conjunto limitado a 5 pontos
  percentuais positivos e um atributo limitado a +3%.
- **Invariante:** item não aumenta ataque e sobrevivência ao mesmo tempo.
- **Competitivo:** ranked remove bônus brutos e normaliza modificadores ao grau 3.

### Q-015 — A forja terá falha aleatória?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** forja totalmente determinística, sem falha, pity, destruição
  ou rebaixamento.
- **Justificativa:** progresso previsível reduz frustração e suporte, preserva confiança
  econômica e elimina a pressão de monetizar proteção contra azar.
- **Baseline:** cinco graus com potência 60/70/80/90/100% e custo relativo
  1/2/3/5/8.
- **Atomicidade:** falha técnica não consome materiais.
- **Separação:** pity existe apenas em loot pessoal de boss, nunca em aprimoramento.

### Q-016 — Quantos presets são gratuitos?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** três presets gratuitos — PvE, Mundo e Arena — e máximo de
  seis.
- **Justificativa:** três contextos cobrem o uso principal sem atrito; os adicionais
  vendem conveniência sem ampliar poder ou quantidade de ações equipadas.
- **Monetização:** o pacote opcional do soft launch pode acrescentar três presets; nunca altera slots
  ativos ou impacto.

## 4. Mundo, economia e sistemas sociais

### Q-017 — Qual formato de mundo será usado?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** topologia híbrida enxuta: um `World Place` com streaming
  para vila/região inicial/zona livre e um `Arena Place` reservado.
- **Justificativa:** um mundo compacto preserva continuidade e reduz operação, enquanto
  o place separado permite isolamento e recuperação das regras competitivas.
- **Gate:** região futura só ganha place próprio quando profiling ou regra distinta
  justificar a divisão.

### Q-018 — Qual perda de morte é justa?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Baseline:** segura/treino 0; livre PvE perde 10% do XP não consolidado; livre PvP
  perde 15% do XP e 5% de material comum; alto risco perde 30% e 15%.
- **Justificativa:** a perda comunica risco e cria sumidouro sem apagar progresso
  permanente; caps por tempo impedem que uma morte encerre a sessão.
- **Caps:** equivalente a 5 min de ganho na zona livre e 10 min no alto risco.
- **Invariante:** equipamento, moeda, maestria, missão, cosmético e item pago nunca
  caem; material perdido sai da economia e não vai ao agressor.

### Q-019 — Haverá troca no lançamento?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** não há troca, presente, empréstimo nem drop no chão no
  lançamento.
- **Justificativa:** adiar transferência entre contas reduz superfície de dupe, fraude,
  mercado cinza e suporte até a economia provar reconciliação confiável.
- **Futuro:** mercado somente por escrow para materiais/projetos não vinculados.
- **Gate:** 30 dias sem dupe crítico, retries/reconexões reconciliados e menos de
  0,1% das operações exigindo reparo manual. Taxas finais dependem da economia real.

### Q-020 — Como bosses distribuem recompensa?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** loot pessoal server-side por dano, cura efetiva, mitigação,
  controle, interrupção, objetivo e presença; MVP não melhora chance rara.
- **Justificativa:** contribuição multidimensional inclui suporte e objetivos, evita
  disputa por último golpe e não recompensa burst excessivo com odds melhores.
- **Baseline:** presença mínima equivalente a 40% do encontro ou 90 s, o que ocorrer
  primeiro; contribuição efetiva
  mínima de 1% da vida; material e ficha garantidos; raro começa em 5%, soma
  5 pontos percentuais por falha e é garantido no décimo clear elegível.
- **Gate:** thresholds e odds são versionados e recalibrados por participação real.

### Q-021 — Reputação é conta, estilo ou temporada?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** persistente por conta, compartilhada entre estilos e
  loadouts; faixa pública de -1.000 a +1.000.
- **Justificativa:** reputação por conta impede escapar de consequências trocando build,
  enquanto o histórico privado sustenta antiabuso sem expor dados desnecessários.
- **Privacidade:** histórico agregado de infrações fica privado no servidor e tem
  retenção limitada; reputação não substitui sanção de moderação.

### Q-022 — Como identificar caça a jogador muito abaixo?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** Effective Power Score derivado pelo servidor, de 0–100:
  progressão 30, completude do loadout 25, maestria 20, equipamento 15 e desempenho
  PvP com incerteza 10.
- **Justificativa:** combinar progressão, build, equipamento e habilidade estimada é
  mais resistente a abuso do que usar apenas nível ou rating competitivo.
- **Grupo:** o lado agressor recebe até 30 pontos adicionais conforme superioridade
  numérica e coordenação recente; a função exata é baseline versionado de playtest.
- **Classificação:** alvo muito abaixo quando a diferença ajustada é ≥25 e o lado
  agressor possui ≥1,35× o poder.
- **Exceções:** autodefesa, bounty, duelo aceito, guerra e evento formal.

### Q-023 — Quais poderes um líder de clã exerce?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** três cargos públicos — Líder, Oficial e Membro — com
  permissões granulares e auditáveis.
- **Justificativa:** poucos cargos reduzem confusão e suporte; atrasos e auditoria
  protegem decisões irreversíveis sem exigir uma hierarquia extensa no F5.
- **Proteções:** transferência espera 72 h; dissolução espera 7 dias; gasto acima de
  25% dos suprimentos espera 24 h.
- **Escopo F5:** sem saque livre, cargos customizados ou bens pessoais no banco.

### Q-024 — Território é necessário antes do lançamento?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** não; território é F7 opcional e pós-lançamento.
- **Justificativa:** território depende de população, teleporte e economia estáveis e
  não deve bloquear o núcleo Action RPG ou o primeiro lançamento público.
- **Gate:** quatro semanas de eventos estáveis, 20 clãs elegíveis, 200 participantes
  semanais, 80% dos eventos formando ao menos 6v6, no-show <10%, teleporte >99% e
  30 dias sem incidente econômico crítico.

## 5. Competitivo, monetização e operação

### Q-025 — O que é normalizado?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** ranked/torneio normaliza HP, dano, guarda, recurso, níveis
  numéricos e refinamento; remove atributos brutos.
- **Justificativa:** preserva expressão de build e conhecimento conquistado, mas remove
  a vantagem estatística que impediria comparação competitiva justa.
- **Preservado:** habilidades desbloqueadas, loadout, Dissonância e variantes legais.
- **Acesso:** dois loadouts de empréstimo versionados, sem unlock no mundo.

### Q-026 — Qual formato de torneio?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Baseline:** 1v1, eliminação simples, 8 participantes, melhor de três rounds de
  90 s; check-in abre 10 min antes e fecha 2 min antes.
- **Justificativa:** o bracket curto cabe na população e na capacidade operacional
  inicial, com duração previsível e espaço para adaptação entre rounds.
- **População:** abaixo de 8 cancela o oficial e oferece casual sem MMR.
- **Expansão:** 16 participantes só após quatro semanas com 80% dos brackets completos
  e no-show <10%.

### Q-027 — Qual rating e quais filas?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** Glicko-2 e uma fila ranked 1v1 por região; casual por desafio.
- **Justificativa:** Glicko-2 modela incerteza de contas novas/inativas, e uma única fila
  evita fragmentar a população de um soft launch regionalmente focado.
- **Baseline:** rating 1.500, RD 350, volatilidade 0,06, `tau` 0,5 e 10 colocações.
- **Divisões provisórias:** Bronze <1200; Prata 1200–1399; Ouro 1400–1599;
  Platina 1600–1799; Diamante 1800–1999; Ascendente 2000–2199; Lenda ≥2200.
- **Gate:** limites visíveis são recalibrados depois da pré-temporada.

### Q-028 — Quais recompensas sazonais são aceitáveis?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** banner, cores, aura/finalização legível e títulos; Top 100
  recebe título numerado. Nada negociável ou com poder.
- **Justificativa:** prestígio visual reconhece desempenho sem criar vantagem futura,
  liquidez especulativa ou obrigação de grind competitivo.
- **Elegibilidade:** recompensa de divisão exige 20 partidas válidas e conduta válida.
- **Baseline:** pré-temporada de 4 semanas; temporadas regulares de 8 semanas, sujeitas
  a revisão formal depois da evidência de população e retorno.

### Q-029 — Quais produtos pagos entram primeiro?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Soft launch:** cosméticos de compra direta, emotes/finalizadores, pacote de três
  presets e servidor privado de treino sem progresso.
- **Justificativa:** compra direta e conveniência delimitada tornam valor e preço claros,
  sem atrelar receita a poder, moeda, inventário funcional ou aleatoriedade.
- **Fora:** boost, respec pago, expansão funcional de inventário, moeda, gacha,
  materiais, personagem, técnica ou proteção de RNG.
- **Gate futuro:** aleatoriedade paga exigiria odds reais e PolicyService, mas não
  pertence à direção inicial.

### Q-030 — O jogo operará globalmente desde o início?

- **Estado:** ✅ DECIDIDO — 2026-08-12 — Álvaro (seleção delegada ao Codex).
- **Política aprovada:** acesso técnico global; aquisição, suporte e calendário do
  soft launch focados no Brasil.
- **Justificativa:** concentra aquisição e suporte para obter sinal operacional útil,
  mantendo acesso amplo e regras de tempo independentes de idioma ou fuso.
- **Idiomas:** PT-BR e inglês revisados manualmente; outros podem usar tradução
  automática sem promessa inicial de suporte.
- **Tempo:** persistir UTC e exibir no horário local; matchmaking prioriza latência.

## 6. Decisões adicionais consolidadas

| ID | Decisão | Estado |
|---|---|---|
| A-001 | Nomes atuais das regiões aprovados para planejamento, sujeitos ao P1 | Aprovada — 2026-08-12 — seleção delegada |
| A-002 | Proteção de novato até onboarding + 30 min, expira em 90 min ou saída voluntária | Aprovada — 2026-08-12 — seleção delegada |
| A-003 | Escala de reputação atual, desconto máximo 5% e acampamento neutro | Aprovada — 2026-08-12 — seleção delegada |
| A-004 | Clã começa em 20 membros, cresce até 40; primeiro evento usa 8v8 | Aprovada — 2026-08-12 — seleção delegada |
| A-005 | Território futuro concede até 5% de material comum, nunca poder/raridade exclusiva | Aprovada — 2026-08-12 — seleção delegada |
| A-006 | Pré-temporada: quarta 20h, sábado 15h e 21h de Brasília, exibidos localmente | Aprovada — 2026-08-12 — seleção delegada |

## 7. Registro D-001 a D-020

| ID | Decisão | Estado | Gate |
|---|---|---|---|
| D-001 | RPG / Action RPG de progressão; arena é contexto competitivo | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | P0 |
| D-002 | F0 é fatia ponta a ponta sem roster grande | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | P0 |
| D-003 | Servidor autoritativo; cliente prevê apresentação | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | P0 |
| D-004 | Conteúdo dirigido por dados versionados | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | P0 |
| D-005 | Slots + impacto + Ressonância suave, com rawD > 3 inválido | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F1 |
| D-006 | Marcos comportamentais e ganhos numéricos capados | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F2 |
| D-007 | Equipamento lateral, teto agregado 5 pp e +3% por atributo | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F2 |
| D-008 | Forja inicial determinística; nunca destrói nem rebaixa | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F2 |
| D-009 | Morte nunca derruba equipamento equipado | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F3 |
| D-010 | Troca e território ficam fora do lançamento; F7 é pós-lançamento | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | pós-lançamento |
| D-011 | Ranked preserva build legal e normaliza números/equipamento | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | F6 |
| D-012 | Monetização não vende poder e mantém rotas gratuitas | Aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) | soft launch |
| D-013 | Visual/kits próximos das referências, só nomes trocados; risco aceito | Aprovada — 2026-08-12 — Álvaro | P1 |
| D-014 | Nome Anime Verse Battlegrounds mantido, sujeito a busca de marca | Aprovada — 2026-08-12 — Álvaro | P1 |
| D-015 | Público 13+, sombrio, gore leve dentro das políticas | Aprovada — 2026-08-12 — Álvaro | P0 |
| D-016 | Equipe 1–3; reduzir conteúdo e preservar gates técnicos | Aprovada — 2026-08-12 — Álvaro | P0 |
| D-017 | Matriz: Android entrada/mediano, PC integrado e gamepad | Aprovada — 2026-08-12 — Álvaro | F0 |
| D-018 | Soft lock contextual e aim assist configurável | Aprovada — 2026-08-12 — Álvaro | F0 |
| D-019 | Alvo 16–24 jogadores; arenas reservadas | Aprovada — 2026-08-12 — Álvaro | F0 |
| D-020 | F0 padrão; ultimate é stretch goal | Aprovada — 2026-08-12 — Álvaro | F0 |

## 8. Perguntas de pesquisa, não de preferência

| ID | Pergunta | Método | Fase |
|---|---|---|---:|
| R-001 | Autoridade continua responsiva? | latência/perda e correções | F0 |
| R-002 | Fronteira PvP é percebida? | teste cego | F0 |
| R-003 | Soft lock favorece plataforma? | PC/toque/gamepad | F0/F1 |
| R-004 | Híbridos são viáveis sem dominar? | simulação + torneio interno | F1 |
| R-005 | Quanto custa produzir habilidade? | medir três ciclos completos | F1 |
| R-006 | Marcos mudam decisão? | teste qualitativo/A-B | F2 |
| R-007 | Quais faucets inflam a economia? | simulação + coortes | F2/F3 |
| R-008 | Morte cria tensão ou abandono? | abandono + entrevista | F3/F4 |
| R-009 | Reputação reduz caça a novato? | cenários adversariais + dados | F4 |
| R-010 | Há população para filas/torneios? | concorrência por região/hora/rank | F6 |
| R-011 | FTUE entrega ação e identidade? | funil 60 s/3 min/5 min | F0 |
| R-012 | Pity de boss reduz frustração sem inundar economia? | clears, abandono e emissão | F3 |

## 9. Valores deliberadamente não finais

Continuam dependentes de playtest, profiling, economia ou população:

- dano, cooldown, regen, alcance, hitbox e drop finais;
- máximo definitivo de servidor acima do baseline 16;
- taxas futuras de mercado;
- duração permanente de temporada depois da pré-temporada;
- preços em Robux;
- quantidade final de regiões, identidades e conteúdo por atualização;
- limites finais de MMR/divisões;
- budgets de frame, memória e rede por dispositivo real.

Mudar um baseline exige versão, hipótese, evidência e registro. Não exige reabrir a
política inteira quando o objetivo aprovado permanece igual.

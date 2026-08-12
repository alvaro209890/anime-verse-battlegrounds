# Questões abertas e registro de decisões

## 1. Como usar este documento

Este arquivo concentra decisões que exigem resposta do responsável pelo produto, validação jurídica, confirmação técnica posterior ou dados de teste. Nenhuma pergunta abaixo bloqueou a elaboração do plano. Algumas, porém, bloqueiam o início da implementação ou a produção de assets caros.

Cada item possui:

- **gate:** último momento seguro para decidir;
- **dono recomendado:** papel responsável por obter a resposta;
- **recomendação provisória:** hipótese usada nos demais documentos;
- **impacto:** o que muda quando a resposta muda.

Uma recomendação provisória não vira decisão silenciosamente. Ao aprovar, registrar responsável, data e justificativa na seção 5.

## 2. Bloqueadores antes da Fase 0

### Q-001 — Qual é a identidade original final do produto?

- **Gate:** P1, antes de concept art, áudio, animações e marketing.
- **Dono recomendado:** direção criativa + assessoria jurídica especializada.
- **Questão:** até que ponto nome, roster, fantasias, silhuetas e kits serão redesenhados para não depender do reconhecimento de franquias existentes?
- **Recomendação provisória:** preservar apenas arquétipos mecânicos amplos; criar universo, terminologia, personagens, histórias, formas, VFX, ícones, falas e áudio próprios. Tratar os codinomes canônicos apenas como referências privadas de design e removê-los de builds, analytics públicos e qualquer asset distribuído.
- **Impacto:** pode alterar nome do jogo, roster, famílias de energia, direção visual, custo de arte e campanha de lançamento.
- **Observação:** trocar nomes isoladamente não elimina risco de obra derivada ou conjunto visual reconhecível.

### Q-002 — O nome “Anime Verse Battlegrounds” será mantido?

- **Gate:** P1, antes de publicar a experiência ou encomendar identidade visual.
- **Dono recomendado:** produto + jurídico + marketing.
- **Opções:** manter após busca de marca; adotar nome original sem “Anime”; usar nome provisório internamente e decidir após teste de posicionamento.
- **Recomendação provisória:** tratá-lo como working title até revisão de marca, discoverability e expectativa de gênero. O termo “Battlegrounds” pode atrair público esperando arena imediata e prejudicar retenção de um MMO de progressão.
- **Impacto:** store page, logo, aquisição, expectativa do público e documentação.

### Q-003 — Qual público e classificação indicativa orientam o design?

- **Gate:** P0.
- **Dono recomendado:** produto + trust & safety.
- **Recomendação provisória:** projetar para público amplo de Roblox, sem gore, linguagem imprópria ou monetização que explore urgência; controles e onboarding acessíveis a jogadores novos, profundidade para domínio posterior.
- **Impacto:** efeitos, narrativa, chat/social, monetização, privacidade, moderação e aquisição.

### Q-004 — Qual equipe, orçamento e horizonte existem de verdade?

- **Gate:** P0.
- **Dono recomendado:** produtor/executive owner.
- **Recomendação provisória:** planejar F0 para equipe experiente de 7 a 10 pessoas; se a equipe for menor, reduzir conteúdo e manter os gates técnicos.
- **Impacto:** quantidade de regiões, roster, qualidade de assets, prazo, terceirização, suporte e live operations.

### Q-005 — Qual é a meta de dispositivos de baixa performance?

- **Gate:** primeira semana da F0.
- **Dono recomendado:** engenharia + produto.
- **Questão:** quais telefones, consoles, resoluções, memória e condições de rede compõem a matriz mínima?
- **Recomendação provisória:** selecionar ao menos um Android de entrada, um telefone mediano, PC integrado e gamepad; definir budgets após benchmark da fatia.
- **Impacto:** tamanho do mundo, quantidade de jogadores, efeitos, streaming, UI, física e custo de QA.

### Q-006 — Qual câmera e modelo de alvo definem o combate?

- **Gate:** antes do primeiro protótipo de combate da F0.
- **Dono recomendado:** combat designer + UX.
- **Opções:** soft lock contextual; lock-on manual; direção livre com aim assist; híbrido por habilidade.
- **Recomendação provisória:** soft lock contextual para ataques básicos e assistência configurável para toque/gamepad, mantendo habilidades de área direcionáveis. Lock-on rígido tende a piorar lutas com muitos participantes.
- **Impacto:** controles, câmera, hit validation, mobilidade, acessibilidade e balanceamento entre plataformas.

### Q-007 — Quantos jogadores por servidor e qual topologia de places?

- **Gate:** arquitetura da F0, antes de comprometer mapa e rede.
- **Dono recomendado:** engenharia de plataforma.
- **Recomendação provisória:** testar o mundo com alvo inicial conservador de 16 a 24 jogadores e arenas em places/servidores reservados separados. Ajustar somente após profiling real.
- **Impacto:** densidade do mapa, bosses, streaming, rede, fila, teleport, custo operacional e sensação de MMO.

### Q-008 — Qual conjunto mínimo prova a fatia vertical?

- **Gate:** P0.
- **Dono recomendado:** produto + game design.
- **Recomendação provisória:** 1 estilo original, ataque básico, dash, guarda e 3 habilidades; 1 recurso; 1 vila segura; 1 área livre; 1 inimigo simples; 1 objetivo; PvP e save. Ultimate é stretch goal.
- **Impacto:** duração da F0, quantidade de arte e superfície de teste.

## 3. Decisões necessárias durante as fases 1 e 2

### Q-009 — Ressonância, orçamento de pontos ou modelo combinado?

- **Gate:** início da F1.
- **Dono recomendado:** systems designer, após simulação e playtest.
- **Recomendação provisória:** modelo combinado: orçamento de slots/complexidade limita poder absoluto; afinidade/ressonância aplica bônus suaves e decrescentes por coerência de família. Evitar punição multiplicativa grande só por hibridizar.
- **Impacto:** liberdade de build, legibilidade, meta, dados de habilidade e UX.
- **Experimento:** comparar as seis builds de papel do GDD e pelo menos 20 builds geradas por busca, medindo burst, sobrevivência, mobilidade, controle e sustentabilidade.

### Q-010 — As famílias de energia serão públicas com os nomes atuais?

- **Gate:** P1 para nomes; F1 para mecânicas.
- **Dono recomendado:** direção criativa + jurídico + systems design.
- **Recomendação provisória:** usar os nomes originais provisórios definidos no GDD — **Fluxo Vital**, **Éter Umbral**, **Contrafluxo** e **Ímpeto Metamórfico** — com lore própria, preservando os quatro padrões mecânicos: reserva/regen, fluxo por precisão, carga por anulação e medidor de transformação. Os quatro nomes ainda passam pelo Gate P1.
- **Impacto:** narrativa, UI, roster, efeitos, quests e comunicação de build.

### Q-011 — Progressão altera números, comportamento ou ambos?

- **Gate:** design detalhado da F2.
- **Dono recomendado:** progression designer.
- **Recomendação provisória:** marcos comportamentais nos níveis principais e pequenos ajustes capados entre eles. Desbloqueios devem criar escolha lateral, não upgrade obrigatório cumulativo.
- **Impacto:** retenção, balanceamento, quantidade de animação/VFX, formato de habilidade e respec.

### Q-012 — Qual teto e duração da maestria?

- **Gate:** F2 antes de popular os dados.
- **Dono recomendado:** progression/economy designer.
- **Recomendação provisória:** poucos níveis significativos por habilidade, primeira mutação na primeira sessão longa e domínio em dezenas — não centenas — de horas distribuídas pela conta. Validar por tempo mediano real, não por melhor jogador.
- **Impacto:** conteúdo necessário, grind, catch-up, valor de item e boost de XP.

### Q-013 — Como funciona o respec gratuito e o ticket pago?

- **Gate:** F2 antes de monetização.
- **Dono recomendado:** produto + economy designer.
- **Recomendação provisória:** primeiro respec guiado gratuito; moeda de jogo com custo previsível para os seguintes; cooldown curto contra abuso. Ticket pago é conveniência opcional e jamais a única rota.
- **Impacto:** confiança, experimentação, economia e percepção de pay-to-win.

### Q-014 — Quanto atributo bruto um equipamento pode conceder?

- **Gate:** F2.
- **Dono recomendado:** combat/economy design.
- **Recomendação provisória:** equipamento majoritariamente modifica comportamento; orçamento bruto pequeno e capado por categoria. Ranked normaliza atributos, mas mantém escolhas de modificador previamente aprovadas.
- **Impacto:** power creep, loot, forja, PvP aberto e normalização.

### Q-015 — A forja terá falha aleatória?

- **Gate:** F2.
- **Dono recomendado:** economy design + produto.
- **Opções:** determinística; chance com medidor de garantia; risco apenas em material bônus; destruição/rebaixamento.
- **Recomendação provisória:** determinística no lançamento. Se testes pedirem tensão, usar garantia crescente e nunca destruir o item principal.
- **Impacto:** inflação, frustração, monetização, suporte e confiança.

### Q-016 — Quantos presets/loadouts são gratuitos?

- **Gate:** F2.
- **Dono recomendado:** produto.
- **Recomendação provisória:** ao menos 3 presets gratuitos para permitir experimentação entre PvE, mundo aberto e arena; vender expansão de conveniência, não acesso básico a builds.
- **Impacto:** UX, monetização e disposição para experimentar.

## 4. Decisões necessárias durante as fases 3 a 7

### Q-017 — Qual formato de mundo será usado?

- **Gate:** pré-produção da F3.
- **Dono recomendado:** world design + engenharia.
- **Opções:** um place com streaming; múltiplas regiões por teleport; hubs instanciados; híbrido.
- **Recomendação provisória:** híbrido: região inicial coesa e pequena com streaming, regiões/arenas de escala ou regra distinta em places próprios. Escolher após profiling, não pela fantasia de “mundo sem loading”.
- **Impacto:** sensação de MMO, party, persistência transitória, eventos, custo de mapa e falhas de teleporte.

### Q-018 — Qual perda de morte é justa em cada zona?

- **Gate:** F3 antes de abrir PvP de risco.
- **Dono recomendado:** economy + PvP design.
- **Recomendação provisória:** segura: nenhuma perda; livre: parte do recurso não consolidado com teto; alto risco: fração maior e respawn mais distante. Nunca equipamento, nível consolidado ou moeda premium.
- **Impacto:** tensão, abandono, camping, inflação e valor da escolta/party.

### Q-019 — O jogo terá troca entre jogadores no lançamento?

- **Gate:** decisão de escopo do soft launch.
- **Dono recomendado:** produto + economia + segurança + suporte.
- **Recomendação provisória:** não. Estabilizar inventário/economia primeiro; depois testar mercado mediado com escrow, bind, imposto, limites, logs e reversão.
- **Impacto:** retenção social, scam, RMT, duplicação, suporte e inflação.

### Q-020 — Como bosses distribuem recompensa?

- **Gate:** F3.
- **Dono recomendado:** PvE/economy design.
- **Recomendação provisória:** participação elegível por contribuição multidimensional e presença, com proteção a suporte e piso/teto; recompensa pessoal rollada no servidor, não drop físico disputado.
- **Impacto:** leeching, toxicidade, party, anti-cheat e economia.

### Q-021 — Reputação é conta, personagem ou temporada?

- **Gate:** F4.
- **Dono recomendado:** social systems design.
- **Recomendação provisória:** reputação principal por conta, com estado recente decaindo e histórico de infrações usado apenas pelo servidor. Evita escapar da consequência trocando build/personagem.
- **Impacto:** persistência, recuperação, privacidade e smurfing.

### Q-022 — Como comparar “jogador muito abaixo” para punir caça a novato?

- **Gate:** F4.
- **Dono recomendado:** data + PvP design.
- **Recomendação provisória:** poder efetivo composto por progresso, equipamento normalizado, MMR incerto e contexto de grupo; nunca usar apenas nível exibido. Excluir autodefesa comprovável e guerra/evento formal.
- **Impacto:** justiça da reputação, exploração e clareza para o jogador.

### Q-023 — Quais poderes um líder de clã pode exercer?

- **Gate:** F5.
- **Dono recomendado:** social design + trust & safety.
- **Recomendação provisória:** permissões granulares; espera e confirmação para ações críticas; bens pessoais nunca confiscáveis; transferência de liderança recuperável; trilha de auditoria visível aos cargos adequados.
- **Impacto:** abuso interno, suporte, banco e retenção social.

### Q-024 — Território é necessário antes do lançamento?

- **Gate:** fim da F5.
- **Dono recomendado:** produto.
- **Recomendação provisória:** não. Primeiro validar eventos competitivos de clã; território sazonal entra somente se houver população, cobertura de fusos e anticolusão suficientes.
- **Impacto:** prazo, concentração de poder, mapa, economia e operação.

### Q-025 — O que é normalizado em torneios?

- **Gate:** início da F6.
- **Dono recomendado:** competitive design.
- **Recomendação provisória:** casual usa build/equipamento próprios; ranked e torneio de topo preservam loadout, maestrias comportamentais elegíveis e identidade, mas normalizam atributos brutos e qualidade do item. Lista de modificadores banidos/capados é versionada.
- **Impacto:** valor da progressão, integridade competitiva e entendimento do espectador.

### Q-026 — Qual formato de torneio cabe na população real?

- **Gate:** F6 após dados de concorrência.
- **Dono recomendado:** live ops + competitive design.
- **Opções:** eliminação simples curta; suíço; grupos + bracket; torneios por região/plataforma.
- **Recomendação provisória:** eliminação simples com check-in e brackets pequenos no primeiro corte; expandir só com concorrência e teleporte confiáveis.
- **Impacto:** tempo de espera, no-show, justiça, servidor e operação.

### Q-027 — Qual sistema de rating e quais filas existem?

- **Gate:** F6.
- **Dono recomendado:** data/competitive design.
- **Recomendação provisória:** rating com incerteza (família Glicko/TrueSkill-like) em vez de ELO puro; uma fila principal por região no início para não fragmentar população; divisão visível suavizada.
- **Impacto:** qualidade de partida, smurfing, decay, leaderboard e tempo de fila.

### Q-028 — Quais recompensas sazonais são aceitáveis?

- **Gate:** antes da primeira temporada.
- **Dono recomendado:** produto + economy design.
- **Recomendação provisória:** cosméticos, títulos e material comum capado; nada exclusivo que aumente poder. Recompensa de participação não deve incentivar bot/AFK.
- **Impacto:** motivação, FOMO, economia e anti-boost.

### Q-029 — Quais produtos pagos entram primeiro?

- **Gate:** antes do soft launch monetizado.
- **Dono recomendado:** produto + jurídico/plataforma + economy design.
- **Recomendação provisória:** cosméticos e slots de preset/inventário após UX gratuita adequada. Adiar boost e respec pago até medir impacto; excluir poder, moeda competitiva exclusiva e bypass de risco.
- **Impacto:** receita, percepção de justiça, público menor e balanceamento.

### Q-030 — O jogo operará globalmente desde o início?

- **Gate:** planejamento do soft launch.
- **Dono recomendado:** produto + operações.
- **Questão:** idiomas, regiões, fusos, suporte e capacidade de moderação estão cobertos?
- **Recomendação provisória:** soft launch limitado aos idiomas/regiões que a equipe consegue suportar; arquitetura de texto e horários preparada para localização desde F0.
- **Impacto:** torneios, clãs, suporte, conteúdo, UI e conformidade.

## 5. Decisões recomendadas pelo plano, aguardando aprovação

| ID | Decisão proposta | Estado | Gate de aprovação |
|---|---|---|---|
| D-001 | Construir MMO de progressão; arena é contexto competitivo, não produto principal | Proposta | P0 |
| D-002 | F0 contém apenas uma fatia ponta a ponta; sem roster grande | Proposta | P0 |
| D-003 | Arquitetura server-authoritative; cliente prevê apenas apresentação | Proposta | P0 |
| D-004 | Habilidade, recurso, item e conteúdo são dirigidos por dados versionados | Proposta | P0 |
| D-005 | Modelo combinado de slots + afinidade/ressonância suave | Proposta | F1 |
| D-006 | Progressão usa marcos comportamentais e ganhos numéricos pequenos/capados | Proposta | F2 |
| D-007 | Equipamento prioriza modificadores laterais; atributo bruto é mínimo | Proposta | F2 |
| D-008 | Falha de forja não destrói equipamento principal | Proposta | F2 |
| D-009 | Morte nunca derruba equipamento equipado | Proposta | F3 |
| D-010 | Troca direta e território ficam fora do lançamento inicial | Proposta | F5/soft launch |
| D-011 | Ranked preserva build, mas normaliza atributo bruto de equipamento | Proposta | F6 |
| D-012 | Monetização não vende poder e mantém rotas gratuitas de respec/progresso | Proposta | Soft launch |

Ao aprovar uma decisão, substituir “Proposta” por `Aprovada — AAAA-MM-DD — responsável` e acrescentar uma nota curta se a decisão divergir da recomendação.

## 6. Perguntas de pesquisa, não de preferência

Estas respostas devem vir de evidência:

| ID | Pergunta | Método recomendado | Fase |
|---|---|---|---:|
| R-001 | O combate continua responsivo com autoridade total? | teste com latência/perda + análise de correções | F0 |
| R-002 | Jogadores percebem a fronteira PvP antes de sofrer dano? | teste cego de navegação | F0 |
| R-003 | Soft lock favorece demais uma plataforma? | comparação PC/toque/gamepad | F0/F1 |
| R-004 | Híbridos são viáveis sem dominar? | simulação + torneio interno de builds | F1 |
| R-005 | Quanto custa produzir e validar uma habilidade? | medir ciclo completo de três habilidades | F1 |
| R-006 | Progressão muda decisão ou só aumenta número? | teste A/B qualitativo de marcos | F2 |
| R-007 | Quais faucets geram inflação? | simulação e coortes de teste | F2/F3 |
| R-008 | A morte incentiva tensão ou abandono? | abandono pós-morte + entrevistas | F3/F4 |
| R-009 | Reputação reduz caça a novato sem punir autodefesa? | cenários adversariais + dados de encontros | F4 |
| R-010 | Há população para dividir filas/torneios? | concorrência por região, hora e rank | F6 |

## 7. Questões que não devem ser decididas cedo demais

- número final de regiões e personagens;
- cadência pública permanente de conteúdo;
- valor de bônus territoriais;
- taxas e limites de mercado entre jogadores;
- fórmula final de MMR;
- duração definitiva de temporada;
- preços em Robux;
- tamanho máximo de servidor;
- números finais de dano, cooldown, regen e drop.

Esses itens dependem de custo real de produção, profiling, economia observada e população. Fixá-los agora produziria falsa precisão.

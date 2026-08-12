# Roadmap de desenvolvimento

## 1. Objetivo e estado deste documento

Este roadmap transforma a visão do jogo em uma sequência de entregas verificáveis e passa a ser a referência de escopo para uma equipe de 1–3 pessoas. A implementação **já começou**: existe um esqueleto F0 com serviços, catálogos e remotes, além de CI com StyLua, Selene, 22 testes Lune, Wally e build Rojo. Esse estado não equivale a F0 concluída e ainda não comprova Roblox Studio, DataStore real, servidor publicado, mobile ou gamepad.

O projeto é um **RPG / Action RPG** persistente; “Battlegrounds” permanece como nome de marketing, não como arquitetura de arena exclusiva. A ordem abaixo prioriza combate em rede, persistência e progressão antes de multiplicar conteúdo ou construir sistemas sociais caros.

Estado dos termos usados neste documento:

| Estado | Significado |
|---|---|
| Decidido | Política aprovada nos documentos; ainda pode não existir em código |
| Implementado | Código/asset existe no repositório; não implica integração completa |
| Validado em CI | Check automatizado passou no commit registrado; não prova runtime Roblox |
| Validado em runtime | Evidência em Studio/place publicado/dispositivo conforme o gate |

### Princípios de execução

1. Uma fatia jogável ponta a ponta vem antes de um roster grande.
2. Sistemas dirigidos por dados vêm antes da produção em escala de personagens, itens e missões.
3. Segurança, telemetria, mobile e console fazem parte do critério de pronto; não são uma fase de polimento tardia.
4. Nenhuma fase começa apenas porque a anterior “parece jogável”. Os gates mensuráveis deste documento precisam passar.
5. Conteúdo protegido ou excessivamente derivativo não entra no pipeline. Nomes, silhuetas, efeitos, ícones, animações, textos e áudio precisam ser originais.
6. A economia é testada com simulação e telemetria antes de troca entre jogadores, banco de clã ou recompensas sazonais.
7. Escopo novo desloca prazo ou remove outro escopo; não é absorvido silenciosamente.

## 2. Premissas de estimativa

**Decisão de equipe (2026-08-12 — Álvaro):** equipe **solo/dupla pequena (1 a 3 pessoas)**. As estimativas são esforço total em **pessoa-mês**, não duração de calendário. Trabalho já feito no esqueleto F0 não foi descontado por falta de apontamento confiável; a reestimativa após o primeiro runtime medido separará concluído e restante.

| Marco | Esforço aprovado | Limite de conteúdo principal |
|---|---:|---|
| F0 | 8–12 pessoa-meses | Fatia vertical mínima |
| F1 | 10–15 pessoa-meses | 3 identidades/famílias |
| F2 | 8–12 pessoa-meses | 6 arquétipos de modificador |
| F3 | 10–15 pessoa-meses | 1 região mista nova e 1 boss |
| F4 | 5–8 pessoa-meses | Reputação, morte e proteção |
| F5 | 6–9 pessoa-meses | Clã sem território |
| F6 | 8–12 pessoa-meses | Ranked 1v1 e torneio de 8 |
| Hardening + soft launch | 4–6 pessoa-meses | Operação Brasil-first |
| F7 opcional pós-lançamento | 12–24 pessoa-meses | Território e mercado, por gates independentes |

Regras que não mudam com equipe pequena: **não** compensar removendo segurança, QA multiplataforma ou persistência; reduzir conteúdo. As durações são faixas de planejamento, não promessas; recalculadas ao final da Fase 0 com velocidade real, qualidade de rede observada e custo real de produção de uma habilidade.

## 3. Gates antes de ampliar o código

### Gate P0 — consolidação do plano

**Entrada:** documentos de produto, arquitetura, segurança e decisões revisados em conjunto.

**Decisões obrigatórias:**

- identidade pública e política de propriedade intelectual;
- público-alvo, classificação indicativa pretendida e intensidade visual;
- modelo final de loadout/ressonância para prototipagem;
- direção de equipamento;
- regra de morte e proteção a novatos;
- arquitetura lógica e solução de persistência;
- tamanho pretendido de servidor e topologia de places;
- equipe, orçamento, cadência e responsável por cada área;
- métricas de sucesso da fatia vertical.

**Saída:** registro de decisões aprovado, questões com responsável e data, backlog priorizado e autorização para continuar a F0. Em 2026-08-12, as decisões de produto foram consolidadas; este gate não retroativamente transforma o esqueleto existente em F0 pronta.

### Gate P1 — revisão jurídica e de plataforma

Antes da produção de assets públicos, uma revisão especializada deve avaliar nome do jogo, roster, kits, terminologia, silhuetas, ícones, áudio, marketing e risco de “trade dress”. Renomear personagens não torna uma cópia segura por si só. Também devem ser revisadas as políticas vigentes da Roblox para conteúdo, comércio, monetização, dados e comunidade.

**Saída:** lista de elementos aprovados, elementos a redesenhar e checklist de aprovação para novos conteúdos.

## 4. Sequência de fases

```text
Plano aprovado
   ↓
F0 Fatia vertical
   ↓
F1 Plataforma de combate + loadout
   ↓
F2 Progressão + equipamento
   ↓
F3 Mundo PvE + economia
   ↓
F4 Reputação + proteção social
   ↓
F5 Clãs (sem território no primeiro corte)
   ↓
F6 Torneios + ranking
   ↓
Hardening → soft launch Brasil-first → lançamento público
   ↓
F7 opcional pós-lançamento: território e mercado mediado
```

Fases podem ter pré-produção sobreposta, mas nenhuma funcionalidade dependente é promovida antes de seu gate. Por exemplo, arenas podem ser prototipadas enquanto o mundo PvE é produzido, mas MMR sazonal não entra em produção sem telemetria, anti-boost e recuperação de partidas.

## 5. Fase 0 — fatia vertical jogável

**Esforço aprovado:** 8–12 pessoa-meses, incluindo o esqueleto já criado e todo o trabalho necessário para provar a fatia em runtime.

### Hipótese a validar

“Um jogador começa limitado, aprende um combate responsivo, conquista o primeiro aumento de poder e entende claramente o risco de sair da zona segura; o servidor mantém autoridade sem fazer o jogo parecer pesado.”

### Escopo obrigatório

- 1 estilo/personagem original aprovado juridicamente;
- 3 habilidades ativas e 1 ataque básico; ultimate fica fora da primeira iteração se ameaçar o prazo;
- 1 dash, guarda, quebra de guarda, stun curto, combo e recuperação;
- 1 família de recurso com custo, regeneração, esgotamento e eventos observáveis;
- 1 mapa pequeno com uma vila segura e uma área livre claramente demarcada;
- PvP de mundo aberto com opt-in geográfico inequívoco;
- 1 inimigo PvE simples e 1 objetivo curto que conceda progresso;
- 1 ciclo de aquisição e consolidação de progresso;
- 1 perfil persistente com session locking, versionamento e recuperação segura;
- HUD e controles funcionais em teclado/mouse, toque e gamepad;
- validação server-authoritative de dano, distância, recurso, cooldown e estado;
- telemetria mínima de sessão, combate, morte, erro de save e abandono;
- ambiente de teste separado de qualquer experiência pública.

Curva inicial de aceite: primeiro combate em até 60 segundos; objetivo de progressão visível em até três minutos; primeira técnica permanente em até cinco minutos; primeiro breakpoint em 15–20 minutos; três técnicas em 45–60 minutos. Ultimate/build pura (8–10 horas) e alternativa híbrida (16–20 horas) são metas posteriores, não requisitos de conteúdo da F0.

### Fora de escopo

- mistura de famílias, ressonância e múltiplos loadouts;
- raridade/forja/equipamento completo;
- clãs, troca, território, torneio, ranked e leaderboard global;
- mundo contínuo grande, navegação marítima ou múltiplas ilhas/regiões;
- roster além do necessário para testar legibilidade de PvP;
- monetização transacional;
- progressão longa ou balanceamento de endgame.

### Experimentos obrigatórios

| Experimento | Como testar | Sinal de sucesso inicial |
|---|---|---|
| Latência percebida | Sessões com condições simuladas de 50, 100, 180 e 250 ms | Ações locais têm resposta visual imediata; servidor corrige sem teleporte frequente |
| Legibilidade | Teste cego com efeitos reduzidos e completos | Jogador identifica atacante, área de risco e janela de resposta |
| Transição PvP | Novos jogadores atravessam o limite sem instrução verbal | Pelo menos 90% percebem que o PvP será ativado antes de poderem sofrer dano |
| Curva inicial | Sessão orientada de 30 a 45 min | Maioria entende ataque, dash, guarda, recurso e primeiro objetivo sem wiki |
| Save | Queda, reconexão, dois servidores e falha injetada | Sem duplicação, rollback silencioso ou sessão concorrente |
| Multiplataforma | Mesmo roteiro em PC, telefone de referência e gamepad | Todas as ações são acessíveis; HUD não obstrui combate |

Os percentuais definitivos devem ser calibrados com amostra e analytics; os valores acima são gates de protótipo, não metas públicas de produto.

### Critério de pronto da Fase 0

- loop de 20 minutos completo em servidor publicado de teste;
- pelo menos 20 sessões internas e 10 sessões externas observadas, incluindo mobile e gamepad;
- nenhuma vulnerabilidade crítica conhecida nos remotes do slice;
- save sobrevive aos cenários de falha definidos em `05-DATA-SCHEMA.md`;
- orçamento de frame, rede e memória medido em dispositivos-alvo, com limites registrados;
- erros críticos têm correlação por versão e sessão;
- jogadores entendem por que ficaram mais fortes e o que fazer em seguida;
- lista explícita de problemas que impedem escalar para mais habilidades.

**Gate F0:** demonstrar a fatia em build versionada e aprovar ou reformular o núcleo. Se o combate não for divertido e legível, não se produz roster.

## 6. Fase 1 — plataforma de combate, conteúdo e loadout

**Esforço aprovado:** 10–15 pessoa-meses.

### Objetivo

Provar que o núcleo escala de um kit fixo para builds configuráveis sem perder clareza, segurança ou balanceabilidade.

### Escopo

- contrato de habilidade dirigido por dados e pipeline de validação de conteúdo;
- 3 identidades originais no total, cada uma associada a uma das 3 famílias entregues nesta fase e com counters claros;
- 4 slots ativos + 1 ultimate, custo por slot e regras de incompatibilidade;
- Ressonância 2.0: quatro unidades de capacidade, uma ultimate, no máximo uma técnica Definidora, impacto até 12 e `rawD <= 3`; `rawD > 3` rejeita o loadout sem clamp;
- 3 famílias de recurso suficientes para testar build pura e híbrida;
- 3 presets-base (`PvE`, `Mundo`, `Arena`), com contrato de capacidade máxima 6 mediante entitlement opcional de conveniência aprovado para o soft launch;
- troca de loadout somente em contexto seguro e com confirmação;
- cooldown, status, hit detection, interrupção, invulnerabilidade e crowd control padronizados;
- ferramentas internas de replay de eventos, inspeção de modificadores e simulação de números;
- testes automatizáveis para contratos, permissões e fórmulas; testes jogáveis para feeling;
- acessibilidade inicial: remapeamento permitido pela plataforma, indicadores redundantes e redução de efeitos.

### Critério de pronto

- adicionar uma habilidade válida não exige editar a lógica central;
- 3 builds puras e 3 híbridas passam pelos limites numéricos definidos no GDD;
- nenhuma combinação possui defesa, fuga e burst máximos simultaneamente;
- servidor rejeita todas as classes conhecidas de solicitação impossível;
- combate continua legível com 6 a 8 jogadores no mesmo encontro;
- balanceamento usa telemetria e versões de dados, não constantes espalhadas.

**Gate F1:** conselho de design aprova diversidade real de builds e manutenção do pipeline. Se cada habilidade exigir exceção no sistema, o contrato deve ser refeito antes da Fase 2.

## 7. Fase 2 — progressão de habilidade e equipamento

**Esforço aprovado:** 8–12 pessoa-meses.

### Objetivo

Validar a promessa “a progressão é o produto” sem transformar PvP em comparação de horas acumuladas.

### Escopo

- maestria de técnica em 10 níveis: variações nos níveis 3/6/9; até 2% nos níveis 2/5/8, total máximo de 6%; nível 10 cosmético/QoL;
- maestria de família em 20 níveis e regras de desbloqueio;
- ranked remove os ganhos numéricos de maestria e preserva apenas variantes comportamentais legais;
- respec com teste gratuito de 30 minutos, primeira troca permanente gratuita por técnica e depois custo `min(3000, 500 + 150 × nível + 250 × respecs nos últimos 7 dias)`, cooldown de cinco minutos e somente em contexto seguro;
- equipamento focado em modificadores laterais de habilidade;
- exatamente 3 slots de equipamento; cada item até 2%, conjunto até 5 pontos percentuais positivos e um atributo até 3%; nenhum item aumenta ataque e sobrevivência simultaneamente;
- 6 arquétipos de modificador reutilizáveis, suficientes para provar variedade sem produzir dezenas de itens únicos;
- inventário limitado, raridade, forja determinística em cinco graus (60/70/80/90/100%) e custos relativos 1/2/3/5/8;
- fontes de material via PvE e PvP sem vender poder direto;
- três presets-base e máximo de seis; comparação clara de efeitos;
- simulador econômico e telemetria de fontes/sumidouros;
- primeira passada de onboarding e proteção contra escolhas irreversíveis.

### Decisão de escopo

**Forja com chance foi rejeitada.** Não existe falha de design, destruição, rebaixamento ou pity de forja. Falha técnica anterior ao commit não consome material; retry retorna o mesmo recibo. Pity pertence somente ao loot pessoal raro de boss.

### Critério de pronto

- jogador obtém uma primeira mudança comportamental em uma janela compatível com o onboarding;
- build antiga permanece utilizável após desbloquear conteúdo novo;
- diferença de equipamento não decide sozinha duelo entre jogadores de habilidade semelhante;
- toda mutação de inventário é idempotente e auditável;
- economia de teste permanece dentro das bandas definidas por pelo menos duas semanas simuladas/aceleradas;
- respec não exige Robux e não apaga progresso conquistado;
- técnica nível 10 converge para 3,4–4,9 horas de uso significativo; família completa converge para 18–24 horas em build pura ou 24–32 horas em híbrida.

**Gate F2:** progressão aumenta possibilidades, não apenas dano. Se o melhor caminho for uma única escada de poder, redesenhar antes de criar dezenas de itens.

## 8. Fase 3 — mundo PvE e economia de recursos

**Esforço aprovado:** 10–15 pessoa-meses.

### Objetivo

Transformar o sandbox de combate em um mundo com motivos claros para explorar, cooperar, arriscar e retornar.

### Escopo recomendado

- `World Place` compacto com streaming, começando em 16 jogadores, reunindo vila, região inicial e zona livre;
- 1 região mista nova, com hub seguro, forja, mercado NPC e quadro de missões;
- 1 cadeia curta de desbloqueio, 1 cadeia de mundo e atividades repetíveis limitadas;
- poucos arquétipos de inimigo reutilizáveis e exatamente 1 boss nesta fase;
- boss/evento com anúncio, contribuição e loot pessoal calculados no servidor;
- elegibilidade de boss ao atingir primeiro 40% da duração do encontro ou 90 segundos de presença, mais contribuição mínima equivalente a 1% da vida;
- material básico e ficha garantidos; raro começa em 5%, sobe 5 p.p. por falha e é garantido no décimo clear elegível; MVP não recebe chance adicional;
- recursos regionais, consolidação segura e morte com perda limitada de recurso não consolidado;
- agenda de eventos com relógio do servidor, tolerância a reinício e fuso mostrado ao jogador;
- sistema de party básico antes de conteúdo cooperativo obrigatório;
- distribuição de recompensa resistente a “último golpe” e leeching;
- primeiros instrumentos de live balancing e feature flags.

### Fora de escopo da fase

- mundo gigantesco;
- dezenas de NPCs com diálogo ramificado;
- comércio direto entre jogadores;
- território de clã;
- evento dependente de operação manual 24/7.

### Critério de pronto

- jogador sempre possui ao menos duas atividades adequadas ao seu progresso;
- deslocamento agrega decisão e não é apenas tempo morto;
- recompensas têm fonte, sink, teto e proteção contra duplicação definidos;
- boss continua funcional com população mínima e máxima de teste;
- servidor reiniciado não duplica nem perde recompensa agendada;
- regiões de risco comunicam regra e consequência antes da entrada.

**Gate F3:** teste fechado valida o loop completo por vários dias, não apenas uma sessão.

## 9. Fase 4 — reputação, morte e proteção social

**Esforço aprovado:** 5–8 pessoa-meses.

### Objetivo

Permitir conflito de mundo aberto sem transformar novatos e jogadores solo em conteúdo descartável para veteranos.

### Escopo

- reputação persistente por conta, compartilhada entre estilos, na escala pública de -1.000 a +1.000; estado recente decai e histórico privado sustenta antiabuso;
- poder efetivo derivado server-side de 0–100: 30% zona, 25% completude do loadout, 20% maestria, 15% equipamento e 10% desempenho PvP com incerteza;
- grupo agressor acrescenta até 30 pontos; alvo muito inferior exige diferença ajustada de 25 e razão mínima de 1,35×, ressalvadas autodefesa, bounty, duelo, guerra e evento formal;
- estado de fora da lei, bounty financiada pelo sistema e limites de resgate;
- proteção de spawn, janela pós-teleporte e saída segura após carregamento;
- detecção de camping, kill trading, alternância de contas e repetição de vítima;
- proteção de novato até completar onboarding + 30 minutos ativos, expirando em 90 minutos ou por saída voluntária;
- morte: segura/treino sem perda; PvE livre perde 10% de XP não consolidado; PvP livre perde 15% de XP e 5% de materiais comuns; alto risco perde 30% e 15%, com caps de cinco/dez minutos de ganho;
- equipamento, moeda, maestria, itens de missão, cosméticos e itens pagos nunca são perdidos;
- denúncia, bloqueio, mute, logs de moderação e apelação operacional;
- políticas contra assédio de grupo e perseguição entre servidores;
- reputação separada de sanção disciplinar: ser “vilão” no jogo não autoriza abuso real.

### Critério de pronto

- matar alvo muito inferior não é estratégia ótima de progresso;
- vítima consegue entender perda, causa e forma de recuperação;
- pares repetidos deixam de gerar recompensa de maneira previsível;
- falso positivo pode ser revisado com trilha de auditoria;
- guardas e mercado não criam prisão permanente sem rota de recuperação;
- métricas de abandono pós-morte e concentração de kills são monitoradas.

**Gate F4:** teste com grupos adversariais demonstra conflito sustentável e proteção a iniciantes.

## 10. Fase 5 — clãs sem guerra territorial completa

**Esforço aprovado:** 6–9 pessoa-meses.

### Objetivo

Validar organização social duradoura antes de dar poder econômico ou territorial a líderes.

### Escopo

- criação com custo em moeda de jogo, nome/tag/emblema moderáveis;
- três cargos públicos — Líder, Oficial e Membro — com permissões explícitas e princípio de menor privilégio;
- 20 membros inicialmente, com progressão até o máximo de 40;
- convite, candidatura, expulsão, saída e transferência de liderança;
- progressão de clã por atividade diversa com limites por membro;
- leaderboard de clã resistente a tamanho bruto;
- chat de clã apoiado pelos recursos e políticas da plataforma;
- banco **somente de suprimentos vinculados e com limites**, sem saque livre ou bens pessoais;
- transferência de liderança com espera de 72 horas, dissolução com sete dias e gasto superior a 25% dos suprimentos com 24 horas;
- primeiro evento competitivo de clã 8v8, sem posse persistente de território.

### Adiamentos deliberados

Banco livre de itens, guerra agendada e território persistente ficam fora deste primeiro corte. Esses sistemas combinam alto risco de fraude, abuso de liderança, timezone unfairness, concentração de poder e custo de moderação.

### Critério de pronto

- toda ação administrativa sensível é auditável;
- nenhuma saída/expulsão pode apagar bens pessoais;
- clã pequeno possui rota de progressão relevante;
- emblemas, nomes e chat passam por controles de segurança;
- dissolução e liderança ausente têm políticas testadas.

**Gate F5:** retenção e segurança social melhoram sem criar dominância inevitável dos maiores grupos.

## 11. Fase 6 — torneios e ranking sazonal

**Esforço aprovado:** 8–12 pessoa-meses.

### Objetivo

Oferecer prova competitiva com integridade, recuperação de falhas e recompensas sem poder direto.

### Escopo

- casual por desafio direto e uma única fila ranked 1v1 por região;
- normalização de HP, dano, guarda, recurso, ganhos numéricos de maestria, atributos brutos e refinamento; habilidades, loadout, Dissonância e variantes comportamentais legais são preservados;
- dois loadouts de empréstimo versionados;
- Glicko-2 com rating inicial 1.500, RD 350, volatilidade 0,06, `tau` 0,5 e dez colocações;
- divisões provisórias: Bronze `<1200`, Prata `1200–1399`, Ouro `1400–1599`, Platina `1600–1799`, Diamante `1800–1999`, Ascendente `2000–2199`, Lenda `>=2200`;
- pré-temporada de quatro semanas e temporadas de oito semanas;
- torneio 1v1 de oito participantes, eliminação simples, melhor de três rounds de 90 segundos em `Arena Place` reservado;
- check-in entre dez e dois minutos antes; menos de oito cancela o oficial e oferece evento casual sem MMR;
- expansão para 16 participantes somente após quatro semanas com pelo menos 80% dos brackets completos e no-show abaixo de 10%;
- inscrição, check-in, bracket, espectador com atraso e resultado idempotente;
- regras para disconnect, reconexão, no-show, empate, forfeit e servidor interrompido;
- detecção de win trading, smurfing, conluio e manipulação de fila;
- leaderboard por temporada e recompensas somente cosméticas; recompensa de divisão exige 20 partidas válidas e Top 100 recebe título numerado;
- runbook operacional para disputa de resultado e falha de torneio.

### Critério de pronto

- partida interrompida não concede duas recompensas nem pune antes da janela definida;
- resultado é reproduzível a partir do log de eventos relevante;
- jogadores entendem o que foi normalizado;
- qualidade da partida é aceitável por plataforma, região e faixa de habilidade;
- pré-temporada sustenta as três janelas brasileiras sem fragmentar a única fila regional;
- leaderboard não depende de confiança no cliente;
- premiação não cria vantagem competitiva exclusiva.

**Gate F6:** temporada curta de teste encerra, premia e arquiva corretamente antes de uma temporada pública.

## 12. Fase 7 — território e mercado opcionais pós-lançamento

**Esforço aprovado:** 12–24 pessoa-meses, somente depois do lançamento e de dados reais das fases anteriores.

Esta fase reúne sistemas de risco que não condicionam o soft launch nem o lançamento público. Cada subfase exige gate independente e pode ser cancelada sem descaracterizar o Action RPG.

### 7A — guerra e território

- janelas múltiplas por região/fuso e limite de participação;
- objetivos contestáveis, não simples contagem de kills;
- posse por temporada com reset, manutenção e catch-up;
- bônus laterais/capados; nunca monopólio de recurso indispensável;
- proteção contra guilda satélite, acordo de rotação e sabotagem interna;
- mecanismo para defender sem disponibilidade diária permanente.

Gate de entrada: quatro semanas de eventos de clã estáveis, 20 clãs elegíveis, 200 participantes semanais, 80% dos eventos formando pelo menos 6v6, no-show abaixo de 10%, teleporte acima de 99% e 30 dias sem incidente econômico crítico. O bônus territorial é limitado a 5% de material comum, nunca item raro ou poder.

### 7B — troca entre jogadores

- começa com mercado mediado/escrow, histórico, confirmação dupla e preço de referência;
- somente materiais e projetos não vinculados explicitamente negociáveis;
- bind em itens de progressão crítica e recompensas competitivas;
- imposto e limites como sinks/anti-lavagem;
- espera para contas novas e ações de alto risco;
- capacidade operacional de congelar, investigar e reverter transação fraudulenta.

Não existe troca, presente, empréstimo ou drop de item no lançamento. O gate futuro exige 30 dias sem dupe crítico, retries/reconexões reconciliados e menos de 0,1% das operações exigindo reparo manual.

### 7C — evolução pós-lançamento

- calendário sustentável, feature flags, rollback e segmentação segura;
- evolução de cosméticos e conveniências sem poder, preservando três presets gratuitos e máximo de seis;
- boost de XP, respec pago, expansão funcional de inventário, moeda, gacha e materiais continuam fora até uma decisão futura explícita;
- revisão de preço, transparência e impacto em menores de idade;
- nenhum produto pago ignora cooldown, recurso, drop ou normalização competitiva.

### Critério de pronto

Cada subfase passa revisão de segurança, economia, moderação, suporte e justiça competitiva. “Funciona tecnicamente” não basta.

## 13. Soft launch e lançamento público

### Soft launch

O hardening/soft launch ocorre **depois de F6**, com esforço de 4–6 pessoa-meses. O acesso técnico é global, mas operação, suporte e aquisição inicial são Brasil-first. PT-BR e inglês recebem revisão manual; outros idiomas podem usar tradução automática sem promessa inicial de suporte. Datas são canônicas em UTC e mostradas no fuso local.

A pré-temporada brasileira oferece quarta às 20h, sábado às 15h e sábado às 21h no horário de Brasília, sempre convertidos para o jogador. Público limitado, sem promessa de save eterno até a política ser comunicada, deve validar:

- retenção por coorte e plataforma;
- funil do tutorial ao primeiro objetivo de mundo;
- distribuição de vitória, morte e poder efetivo;
- inflação, concentração de riqueza e taxa de uso dos sinks;
- estabilidade de save, servidor, matchmaking e teleporte;
- taxa de exploit, denúncia e tempo de resposta;
- custo de conteúdo por hora de jogo entregue;
- clareza de monetização e ausência de vantagem ranqueada.
- qPTR, playtime, dias jogados e co-play, além de retenção e visitas.

Produtos permitidos no soft launch: cosméticos de compra direta, emotes/finalizadores, pacote de +3 presets e servidor privado de treino sem progresso. Boost, respec pago, inventário funcional, moeda, gacha e material ficam fora.

### Gate de lançamento

- nenhum incidente crítico de save sem mitigação;
- plano de rollback e comunicação ensaiado;
- suporte, moderação e resposta a exploit com responsáveis definidos;
- políticas de privacidade, termos, comunidade e monetização aprovadas;
- performance dentro das bandas por dispositivo-alvo;
- experiência completa revisada contra propriedade intelectual;
- calendário de conteúdo compatível com capacidade real da equipe;
- dashboards e alertas essenciais operacionais.

## 14. Trilhas de trabalho transversais

| Trilha | Começa | Entregas contínuas |
|---|---:|---|
| Design de combate | F0 | frame data, counters, matriz de matchups, telemetria e balance patches |
| Engenharia de rede | F0 | autoridade, predição visual, rate limits, profiling e testes de latência |
| Persistência/economia | F0 | schemas, migrações, auditoria, budgets, simulação e recuperação |
| UX multiplataforma | F0 | controles, HUD, onboarding, acessibilidade e testes de dispositivo |
| Arte/áudio original | P1 | linguagem visual, checklist jurídico, budgets e produção de conteúdo |
| Segurança | F0 | threat modeling por feature, testes adversariais, alertas e runbooks |
| Trust & Safety | F3 | denúncia, moderação, políticas sociais, evidência e apelação |
| Live operations | F3 | feature flags, versionamento, dashboards, eventos e rollback |
| QA | F0 | matriz de dispositivos, regressão, soak, falhas injetadas e release gates |

## 15. Dependências críticas

| Entrega | Depende de | Não deve depender de |
|---|---|---|
| Ressonância | contratos de habilidade, recursos, tags e simulador | roster completo |
| Progressão | save versionado, habilidade dirigida por dados | troca entre jogadores |
| Equipamento | modificadores rastreáveis, inventário idempotente | clã ou ranked |
| Mundo de risco | zonas autoritativas, transição clara, regra de morte | território |
| Reputação | poder efetivo, histórico de encontros, telemetria | leaderboard público |
| Banco de clã | inventário auditável, permissões, recuperação | guerra territorial |
| Torneio | teleporte confiável, resultado idempotente, reconexão | território ou troca |
| Ranked | combate estável, normalização, anti-boost | monetização |
| Troca | economia estável, audit log, suporte, anti-dupe e gate de 30 dias | lançamento inicial; só F7 pós-lançamento |

## 16. Definition of Done global

Uma feature só está pronta quando:

- comportamento e estados de falha estão documentados;
- autoridade cliente/servidor está definida;
- dados persistidos, migração e idempotência foram avaliados;
- ameaças e abuso social/econômico foram modelados;
- PC, toque e gamepad foram testados quando aplicável;
- telemetria mede uso, sucesso, erro e impacto econômico;
- performance foi medida em cenário realista;
- UX comunica custo, risco, consequência e recuperação;
- conteúdo público passou checklist de originalidade;
- existe estratégia de rollout, feature flag/kill switch e rollback;
- critérios mensuráveis e evidências estão anexados ao marco.

## 17. Riscos de programa e respostas

| Risco | Probabilidade | Impacto | Resposta de planejamento |
|---|---|---|---|
| Escopo de MMO exceder equipe | Alta | Crítico | F0 pequena; conteúdo limitado; território/troca adiados; gates de corte |
| Combate responsivo conflitar com autoridade | Alta | Crítico | predição somente visual, testes cedo com latência e contratos estreitos |
| Identidade ainda ser derivativa | Alta | Crítico | revisão jurídica/creative redirection antes de assets caros |
| Conteúdo crescer mais rápido que pipeline | Alta | Alto | contrato dirigido por dados, budgets e custo por habilidade medido na F1 |
| Progressão destruir justiça do PvP | Alta | Crítico | poder capado, opções laterais e normalização competitiva |
| Economia sofrer duplicação/inflação | Média/alta | Crítico | ledger, idempotência, sinks medidos e troca tardia |
| Mobile ficar ilegível | Alta | Alto | dispositivo-alvo e UX desde F0; limite de efeitos e densidade |
| Clãs facilitarem abuso/concentração | Média/alta | Alto | permissões, logs, resets sazonais e bônus capados |
| Torneio falhar por teleporte/reconexão | Média | Alto | state machine recuperável e ensaio com falhas antes de prêmio real |
| Cadência de conteúdo causar burnout | Alta | Alto | calendário baseado em capacidade observada, não em promessa de marketing |

## 18. Cortes recomendados se houver pressão de prazo

Ordem de corte, preservando o produto central:

1. território e guerra persistente (F7 opcional);
2. troca entre jogadores (F7 opcional);
3. banco de clã;
4. torneio automatizado de grande escala;
5. quarto estilo/personagem antes do teste fechado;
6. eventos agendados complexos;
7. crafting além da forja determinística aprovada;
8. cosméticos altamente customizáveis.

Não cortar: autoridade do servidor, integridade de save, telemetria mínima, UX de entrada em PvP, testes mobile/gamepad, proteção de novato e revisão de originalidade.

## 19. Cadência de decisão e evidência

- revisão semanal de riscos, dependências e métricas da fase;
- demonstração quinzenal em build real, não somente vídeo;
- decisão registrada com contexto, alternativas, dono e data;
- rebalanceamento versionado com hipótese e resultado;
- revisão de gate ao final de cada fase com três resultados possíveis: **avançar**, **repetir experimento** ou **reduzir/reformular escopo**;
- nenhuma data pública de lançamento antes de F0 validar custo e velocidade reais.


# Roadmap de desenvolvimento

## 1. Objetivo e estado deste documento

Este roadmap transforma a visão do jogo em uma sequência de entregas verificáveis. Ele não autoriza implementação ainda: nesta rodada, a saída é somente planejamento.

O projeto é um action MMO de mundo aberto, não um battleground de arena com conteúdo adicional. A ordem abaixo prioriza o risco central — combate em rede, persistência e progressão — antes de multiplicar conteúdo ou construir sistemas sociais caros.

### Princípios de execução

1. Uma fatia jogável ponta a ponta vem antes de um roster grande.
2. Sistemas dirigidos por dados vêm antes da produção em escala de personagens, itens e missões.
3. Segurança, telemetria, mobile e console fazem parte do critério de pronto; não são uma fase de polimento tardia.
4. Nenhuma fase começa apenas porque a anterior “parece jogável”. Os gates mensuráveis deste documento precisam passar.
5. Conteúdo protegido ou excessivamente derivativo não entra no pipeline. Nomes, silhuetas, efeitos, ícones, animações, textos e áudio precisam ser originais.
6. A economia é testada com simulação e telemetria antes de troca entre jogadores, banco de clã ou recompensas sazonais.
7. Escopo novo desloca prazo ou remove outro escopo; não é absorvido silenciosamente.

## 2. Premissas de estimativa

**Decisão de equipe (2026-08-12 — Álvaro):** equipe **solo/dupla pequena (1 a 3 pessoas)**. As faixas abaixo foram originalmente calibradas para uma equipe experiente de 7 a 10 pessoas (2-3 engenheiros, 2 artistas técnicos/3D, 1 animador/VFX, 1 game/economy designer, 1 UI/UX e QA compartilhado; áudio, moderação, localização e jurídico como serviços externos). Com equipe de 1-3 pessoas, o **conteúdo é reduzido em todas as fases** (roster, regiões, assets) e as **durações precisam ser relidas com fator realista** — a Fase 0 (fatia vertical) permanece o primeiro marco, mas o cronograma deve refletir velocidade de equipe pequena.

Regras que não mudam com equipe pequena: **não** compensar removendo segurança, QA multiplataforma ou persistência; reduzir conteúdo. As durações são faixas de planejamento, não promessas; recalculadas ao final da Fase 0 com velocidade real, qualidade de rede observada e custo real de produção de uma habilidade.

## 3. Gates antes de qualquer código

### Gate P0 — aprovação do plano

**Entrada:** documentos `00` a `09` revisados em conjunto.

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

**Saída:** registro de decisões aprovado, questões com dono e data, backlog priorizado e autorização explícita para iniciar a Fase 0.

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
F7 Território, troca e live operations
   ↓
Soft launch → lançamento público
```

Fases podem ter pré-produção sobreposta, mas nenhuma funcionalidade dependente é promovida antes de seu gate. Por exemplo, arenas podem ser prototipadas enquanto o mundo PvE é produzido, mas MMR sazonal não entra em produção sem telemetria, anti-boost e recuperação de partidas.

## 5. Fase 0 — fatia vertical jogável

**Estimativa inicial:** 8 a 12 semanas após P0/P1.

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

**Estimativa inicial:** 8 a 10 semanas.

### Objetivo

Provar que o núcleo escala de um kit fixo para builds configuráveis sem perder clareza, segurança ou balanceabilidade.

### Escopo

- contrato de habilidade dirigido por dados e pipeline de validação de conteúdo;
- 3 estilos originais, cada um com identidade, counters e pelo menos 4 habilidades candidatas;
- 4 slots ativos + 1 ultimate, custo por slot e regras de incompatibilidade;
- protótipo de ressonância/orçamento de afinidade aprovado no GDD;
- 3 famílias de recurso suficientes para testar build pura e híbrida;
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

**Estimativa inicial:** 8 a 12 semanas.

### Objetivo

Validar a promessa “a progressão é o produto” sem transformar PvP em comparação de horas acumuladas.

### Escopo

- maestria de habilidade com marcos comportamentais, não apenas multiplicadores;
- maestria de família e regras de desbloqueio;
- respec com moeda obtida em jogo; ticket pago só poderá ser avaliado depois de o fluxo gratuito provar ser justo;
- equipamento focado em modificadores laterais de habilidade;
- pequena faixa de atributos brutos, com teto e normalização documentados;
- inventário limitado, raridade, forja determinística no primeiro corte e sinks de moeda;
- fontes de material via PvE e PvP sem vender poder direto;
- presets de loadout e comparação clara de efeitos;
- simulador econômico e telemetria de fontes/sumidouros;
- primeira passada de onboarding e proteção contra escolhas irreversíveis.

### Decisão de escopo

**Upgrade com chance de falha destrutiva não é recomendado.** Se houver risco, a falha deve aumentar um medidor de garantia ou consumir somente material previsível; nunca destruir o equipamento principal. Isso reduz frustração, exploração de jogadores vulneráveis e incentivo a monetização predatória.

### Critério de pronto

- jogador obtém uma primeira mudança comportamental em uma janela compatível com o onboarding;
- build antiga permanece utilizável após desbloquear conteúdo novo;
- diferença de equipamento não decide sozinha duelo entre jogadores de habilidade semelhante;
- toda mutação de inventário é idempotente e auditável;
- economia de teste permanece dentro das bandas definidas por pelo menos duas semanas simuladas/aceleradas;
- respec não exige Robux e não apaga progresso conquistado.

**Gate F2:** progressão aumenta possibilidades, não apenas dano. Se o melhor caminho for uma única escada de poder, redesenhar antes de criar dezenas de itens.

## 8. Fase 3 — mundo PvE e economia de recursos

**Estimativa inicial:** 10 a 14 semanas.

### Objetivo

Transformar o sandbox de combate em um mundo com motivos claros para explorar, cooperar, arriscar e retornar.

### Escopo recomendado

- 3 regiões: introdutória, intermediária e alto risco;
- hubs seguros com spawn, forja, mercado NPC e quadro de missões;
- 2 cadeias de missão de desbloqueio, 1 cadeia de mundo e atividades repetíveis limitadas;
- 3 arquétipos de inimigo, variantes controladas e 2 bosses;
- 1 boss/evento mundial com anúncio e contribuição calculada no servidor;
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

**Estimativa inicial:** 6 a 8 semanas.

### Objetivo

Permitir conflito de mundo aberto sem transformar novatos e jogadores solo em conteúdo descartável para veteranos.

### Escopo

- reputação positiva/negativa com causas transparentes e recuperação jogável;
- comparação de poder efetivo para penalizar caça a alvos muito inferiores;
- estado de fora da lei, bounty financiada pelo sistema e limites de resgate;
- proteção de spawn, janela pós-teleporte e saída segura após carregamento;
- detecção de camping, kill trading, alternância de contas e repetição de vítima;
- penalidade de morte por risco da zona, nunca perda de equipamento equipado;
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

**Estimativa inicial:** 8 a 12 semanas.

### Objetivo

Validar organização social duradoura antes de dar poder econômico ou territorial a líderes.

### Escopo

- criação com custo em moeda de jogo, nome/tag/emblema moderáveis;
- cargos com permissões explícitas e princípio de menor privilégio;
- convite, candidatura, expulsão, saída e transferência de liderança;
- progressão de clã por atividade diversa com limites por membro;
- leaderboard de clã resistente a tamanho bruto;
- chat de clã apoiado pelos recursos e políticas da plataforma;
- banco **somente de materiais vinculados e com limites**, caso auditoria prove segurança;
- evento competitivo de clã sem posse persistente de território.

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

**Estimativa inicial:** 10 a 14 semanas.

### Objetivo

Oferecer prova competitiva com integridade, recuperação de falhas e recompensas sem poder direto.

### Escopo

- fila casual com build própria;
- fila ranqueada com loadout preservado e atributos de equipamento normalizados;
- MMR oculto, divisão visível e incerteza de colocação;
- temporadas, placement, decay no topo e reset suave;
- torneio agendado em servidor/place de arena reservado;
- inscrição, check-in, bracket, espectador com atraso e resultado idempotente;
- regras para disconnect, reconexão, no-show, empate, forfeit e servidor interrompido;
- detecção de win trading, smurfing, conluio e manipulação de fila;
- leaderboard por temporada e recompensas cosméticas/materiais limitados;
- runbook operacional para disputa de resultado e falha de torneio.

### Critério de pronto

- partida interrompida não concede duas recompensas nem pune antes da janela definida;
- resultado é reproduzível a partir do log de eventos relevante;
- jogadores entendem o que foi normalizado;
- qualidade da partida é aceitável por plataforma, região e faixa de habilidade;
- leaderboard não depende de confiança no cliente;
- premiação não cria vantagem competitiva exclusiva.

**Gate F6:** temporada curta de teste encerra, premia e arquiva corretamente antes de uma temporada pública.

## 12. Fase 7 — território, troca e live operations

**Estimativa inicial:** 12 a 18 semanas, somente depois de dados reais das fases anteriores.

Esta fase reúne sistemas que parecem essenciais à fantasia MMO, mas são perigosos cedo demais. Cada um exige um gate independente e pode ser cancelado sem impedir o lançamento.

### 7A — guerra e território

- janelas múltiplas por região/fuso e limite de participação;
- objetivos contestáveis, não simples contagem de kills;
- posse por temporada com reset, manutenção e catch-up;
- bônus laterais/capados; nunca monopólio de recurso indispensável;
- proteção contra guilda satélite, acordo de rotação e sabotagem interna;
- mecanismo para defender sem disponibilidade diária permanente.

### 7B — troca entre jogadores

- começa com mercado mediado/escrow, histórico, confirmação dupla e preço de referência;
- somente itens explicitamente negociáveis;
- bind em itens de progressão crítica e recompensas competitivas;
- imposto e limites como sinks/anti-lavagem;
- espera para contas novas e ações de alto risco;
- capacidade operacional de congelar, investigar e reverter transação fraudulenta.

Troca direta livre não é recomendada no lançamento inicial.

### 7C — live operations e monetização

- calendário sustentável, feature flags, rollback e segmentação segura;
- cosméticos, slots de preset, inventário e conveniências com limites publicados;
- boost de XP não se aplica a MMR e não concede exclusividade de habilidade;
- respec gratuito continua viável mesmo se existir ticket pago;
- revisão de preço, transparência e impacto em menores de idade;
- nenhum produto pago ignora cooldown, recurso, drop ou normalização competitiva.

### Critério de pronto

Cada subfase passa revisão de segurança, economia, moderação, suporte e justiça competitiva. “Funciona tecnicamente” não basta.

## 13. Soft launch e lançamento público

### Soft launch

Público limitado, sem promessa de save eterno até a política ser comunicada. Deve validar:

- retenção por coorte e plataforma;
- funil do tutorial ao primeiro objetivo de mundo;
- distribuição de vitória, morte e poder efetivo;
- inflação, concentração de riqueza e taxa de uso dos sinks;
- estabilidade de save, servidor, matchmaking e teleporte;
- taxa de exploit, denúncia e tempo de resposta;
- custo de conteúdo por hora de jogo entregue;
- clareza de monetização e ausência de vantagem ranqueada.

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
| Troca | economia estável, audit log, suporte e anti-dupe | lançamento inicial |

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

1. território e guerra persistente;
2. troca entre jogadores;
3. banco de clã;
4. torneio automatizado de grande escala;
5. quarto estilo/personagem antes do teste fechado;
6. eventos agendados complexos;
7. crafting com risco;
8. cosméticos altamente customizáveis.

Não cortar: autoridade do servidor, integridade de save, telemetria mínima, UX de entrada em PvP, testes mobile/gamepad, proteção de novato e revisão de originalidade.

## 19. Cadência de decisão e evidência

- revisão semanal de riscos, dependências e métricas da fase;
- demonstração quinzenal em build real, não somente vídeo;
- decisão registrada com contexto, alternativas, dono e data;
- rebalanceamento versionado com hipótese e resultado;
- revisão de gate ao final de cada fase com três resultados possíveis: **avançar**, **repetir experimento** ou **reduzir/reformular escopo**;
- nenhuma data pública de lançamento antes de F0 validar custo e velocidade reais.


# 04 — Arquitetura

## 1. Escopo e decisões arquiteturais

Este documento descreve a arquitetura-alvo e distingue o que já existe do que ainda precisa ser entregue. O repositório contém um **esqueleto executável da F0**: bootstrap de servidor/cliente, catálogos, mundo greybox, modelos/animação procedural de NPCs, apresentação local do jogador, receitas visuais de defesa/dash, interação contextual, domínio, save/ProfileStore, controllers de Input/HUD, registry v2, `SecurityService` e `TelemetryService`. A CI versionada executa StyLua, Selene, 241 testes de domínio, 73 testes de animação/apresentação, 67 casos de fuzz, 19 casos de simulação de combate ponta a ponta, instalação Wally e build Rojo. No Linux a mesma ordem cabe em `scripts/ci.sh`. Isso comprova estrutura e lógica automatizada; **não comprova** roteiro runtime no Studio, DataStore real, teleporte, servidor publicado, mobile ou gamepad.

Decisões principais:

| Tema | Decisão aprovada | Motivo | Custo assumido |
|---|---|---|---|
| Autoridade | Servidor autoritativo para regras, combate, economia, progressão e posição válida | O cliente Roblox é controlável pelo jogador e não pode ser fonte de verdade | Mais trabalho de previsão visual e reconciliação |
| Organização | Arquitetura própria de `service/controller`, com contratos explícitos | Mantém dependências, remotes e superfície de segurança visíveis | Exige disciplina e um bootstrap pequeno |
| Persistência | Adaptador tipado sobre ProfileStore, com session locking | Evita DataStore cru espalhado e permite trocar a biblioteca | Uma camada adicional para manter e testar |
| Conteúdo | Definições em dados versionados; sistemas não conhecem personagens específicos | Adicionar personagem, habilidade, item ou zona não deve alterar o núcleo | Validação de conteúdo precisa ser forte |
| Comunicação | Intenções do cliente; snapshots e deltas aprovados pelo servidor | Não replica o perfil bruto nem aceita resultados calculados no cliente | Contratos precisam de versão e compatibilidade |
| Consistência | Operações econômicas idempotentes, com revisão e recibo | Evita duplicação em retry, reconexão e falhas parciais | Mais metadados e fluxos de compensação |
| Equipamento | Modificadores de habilidade, com bônus numérico pequeno e limitado | Preserva identidade de build sem transformar PvP em corrida de atributos | Maior esforço de balanceamento e QA combinatório |
| Topologia | `World Place` compacto com streaming e `Arena Place` separado | Mantém o mundo persistente legível e isola partidas competitivas em servidores reservados | Teleporte e reconexão precisam de testes publicados |
| Operação | Acesso técnico global, soft launch Brasil-first e datas canônicas em UTC | Concentra suporte inicial sem acoplar regra a idioma ou fuso | PT-BR e inglês exigem revisão manual contínua |

### 1.1 Atributos de qualidade prioritários

1. **Integridade:** nenhuma recompensa, moeda, dano, item ou vitória nasce de uma afirmação do cliente.
2. **Evolução:** schemas de save e contratos de rede possuem versão e caminho de migração.
3. **Auditabilidade:** toda mutação econômica relevante tem origem, identificador de operação e resultado rastreável.
4. **Desempenho previsível:** combate não realiza persistência; consultas espaciais são limitadas e nenhum loop por frame percorre todos os jogadores.
5. **Degradação segura:** falha em DataStore, MemoryStore, arena ou catálogo bloqueia apenas a ação afetada; não concede recompensa por padrão.
6. **Testabilidade:** lógica de domínio não depende diretamente de Instances, remotes ou DataStore.
7. **Compatibilidade multiplataforma:** PC, mobile e console emitem as mesmas intenções semânticas; somente o mapeamento de input muda.

## 2. Knit versus arquitetura própria

### 2.1 Opção A — Knit

Vantagens:

- convenção conhecida de services/controllers e ciclo de inicialização;
- produtividade inicial e menor quantidade de infraestrutura própria;
- integração simples entre cliente e servidor para protótipos.

Riscos neste projeto:

- o repositório oficial está arquivado e declara que Knit não recebe mais manutenção;
- a conveniência de expor métodos ao cliente pode esconder a superfície real de remotes;
- contratos de rede, validação, versionamento e rate limit ainda precisariam de uma camada própria;
- dependência do ciclo de vida e das decisões de uma biblioteca arquivada em um MMO de longa duração;
- facilidade de criar chamadas diretas entre serviços, aumentando acoplamento e dificultando testes.

### 2.2 Opção B — service/controller próprio

Vantagens:

- registro único e explícito de todo remote, direção, payload, resposta e política de abuso;
- interfaces pequenas entre domínio, infraestrutura e apresentação;
- ciclo de vida e grafo de dependências adequados ao jogo;
- troca de ProfileStore, sistema de remotes ou telemetria sem reescrever regras.

Custos:

- bootstrap, container de dependências e gateway de rede precisam ser projetados;
- sem revisão arquitetural, existe risco de recriar um framework grande e inconsistente;
- onboarding exige documentação das convenções.

### 2.3 Escolha

Escolher **service/controller próprio, mínimo**, sem criar um framework genérico. O núcleo terá apenas registro de dependências, fases `Init` e `Start`, desligamento ordenado e registro explícito de contratos de rede. Não haverá descoberta mágica de módulos, exposição automática de métodos nem service locator acessível por toda parte.

Knit fica **rejeitado para o projeto novo**, inclusive no protótipo: adotar uma dependência arquivada não compensa a produtividade inicial. Se o bootstrap próprio consumir esforço material em F0, a contingência é avaliar outra biblioteca ativa contra os mesmos contratos — não retornar automaticamente ao Knit. Migrar depois de dezenas de serviços seria caro; portanto o limite do bootstrap é aprovado em P0 e verificado antes da expansão de F1.

### 2.4 ADR-001 — framework de aplicação

| Campo | Registro |
|---|---|
| Status | Aceito no planejamento em 2026-08-12 |
| Contexto | MMO server-authoritative, remotes sensíveis e framework sugerido pelo prompt sem manutenção upstream |
| Decisão | Services/controllers próprios, tipados, com bootstrap mínimo e contratos de rede registrados |
| Consequências | Mais infraestrutura inicial; superfície de segurança e dependências ficam explícitas |
| Contingência | Avaliar biblioteca ativa somente por ADR novo, prova em branch isolada e equivalência de contratos/testes |

### 2.5 ADR-002 — persistência de perfil

| Campo | Registro |
|---|---|
| Status | Aceito no planejamento em 2026-08-12 |
| Contexto | O upstream do ProfileService declara que novos projetos devem usar ProfileStore |
| Decisão | Usar ProfileStore pinado e auditado, sempre atrás de `ProfileRepository` tipado |
| Consequências | Session locking e ciclo de perfil não vazam para o domínio; atualização da biblioteca exige teste de contrato |
| Contingência | Se auditoria/licença/manutenção falhar antes de F0, trocar por solução mantida que prove locking atômico com UpdateAsync, takeover seguro, autosave e release; DataStore cru não é fallback aceitável |

Referências upstream da decisão: [Knit arquivado](https://github.com/Sleitnick/Knit), [ProfileService direcionando novos projetos ao ProfileStore](https://github.com/MadStudioRoblox/ProfileService), [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) e [orientação do Creator Hub para dados de jogador e session locking](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing).

## 3. Camadas e regras de dependência

| Camada | Responsabilidade | Pode depender de | Não pode depender de |
|---|---|---|---|
| Definições compartilhadas | IDs, schemas, catálogos, enums e contratos sem segredo | Outros dados compartilhados validados | Services, controllers, DataStore, UI |
| Domínio do servidor | Regras puras de combate, recursos, loadout, economia e progressão | Definições e interfaces | Cliente, UI e remotes concretos |
| Aplicação do servidor | Orquestra casos de uso, autorização e transações | Domínio e portas de infraestrutura | Controllers do cliente |
| Infraestrutura do servidor | Persistência, remotes, relógio, telemetria, matchmaking | Interfaces da aplicação | Regras específicas embutidas |
| Controllers do cliente | Input, câmera, UI, previsão visual e reconciliação | Contratos públicos e estado replicado | Perfil completo, fórmulas secretas, concessão de recompensas |
| Apresentação | HUD, menus, VFX, SFX e acessibilidade | Estado dos controllers | Remotes diretamente |

Regras adicionais:

- dependências entre serviços são declaradas no bootstrap e formam um grafo acíclico;
- um serviço não lê o armazenamento de outro; chama a interface pública ou consome evento de domínio;
- eventos notificam fatos concluídos, não substituem comandos que precisam de resultado;
- nenhuma definição de personagem contém função executável arbitrária vinda do cliente;
- IDs e chaves de localização são estáveis; nomes públicos podem mudar após revisão legal sem migrar save.

## 4. Mapa de módulos por estado

### 4.0 Estado auditado do esqueleto F0

- `src/server/init.server.lua` liga os serviços iniciais por dependências explícitas;
- `src/shared/Data` e `src/shared/Remotes.luau` fornecem catálogos e contratos iniciais (incl. `Zones.luau` e o remote `ZoneEvent` S→C);
- `WorldPresentation.luau` mantém proporções/paleta/amplitudes sem Instances; `WorldService` traduz essas receitas para Parts/Motor6D e sincroniza somente a raiz autoritativa dos NPCs;
- `ActorAnimator.luau` apresenta NPCs a partir de `EnemyEvent`; `PlayerCombatAnimator.luau` compõe resposta local para leve, pesado, guarda e dash em fases; `AbilityVfx` fornece casca, rastro e impacto de chão locais; `ZoneSignalPlayer.luau` apresenta os cinco sinais da fronteira a partir de `ZoneEvent` aceito. Nenhum deles altera root, hitbox ou regra de combate;
- **Contrato de anexo (14/08, `docs/14` §4.7).** O rig R15 não existe no instante do `CharacterAdded`. Toda camada de apresentação que procura junta, mão ou parte precisa continuar procurando depois da primeira varredura: `PlayerCombatAnimator` adota junta atrasada via `DescendantAdded`, `CharacterAnimationPlayer` remonta o `Trail` no golpe, e `ActorAnimator` nunca guarda cache de junta vazio. Varredura única é o defeito que matou o overlay inteiro por uma sessão;
- `InteractionController` envia somente alvo/fase semânticos; `InteractionService` fecha catálogo, distância e hold no servidor. Prompts e fluxo real continuam pendentes de Play;
- existem implementações iniciais de `AbilityService`, `CatalogService`, `CombatService`, `CooldownService`, `PlayerSessionService`, `ProgressionService` (flags de unlock; spawn sem técnicas), `RemoteGateway`, `ResourceService`, `SaveService` e `ZoneService` (zona atual, `canPvp`, transição 5 s, lockout 15 s e os 5 sinais da fronteira — domínio headless, item 6 do backlog);
- `src/client/init.client.lua` monta os controllers F0, a extensão contextual de interação e as utilities de apresentação; layout, dispositivos e feeling continuam pendentes de runtime;
- os 241 testes de domínio e 73 testes de animação/apresentação cobrem dados, domínio, controllers, interação, apresentação pura e segurança/telemetria, e a suíte `tests/combat_e2e.luau` liga essas camadas numa cadeia só (posição → aquisição → CombatEvent → impacto → StateDelta); nenhuma delas substitui os testes de runtime previstos neste documento.

As tabelas seguintes são o mapa-alvo. Uma linha em F0 não significa que o contrato inteiro esteja pronto; o roadmap e os testes de aceite determinam a conclusão.

### 4.1 Servidor

| Serviço | Responsabilidade | Dependências principais | Fase inicial |
|---|---|---|---|
| Bootstrap | Validar configuração, ordenar inicialização e desligamento | Registro de serviços | F0 |
| RemoteGateway | Decodificar contratos, autenticar sessão, limitar taxa e despachar intenção | Session, Security, Telemetry | F0 |
| PlayerSessionService | Ciclo join/leave, estado de sessão e readiness | ProfileRepository | F0 |
| ProfileRepositoryAdapter | Load, session lock, migration, save e release | ProfileStore, DataStore | F0 |
| CatalogService | Carregar e validar definições versionadas | Dados compartilhados | F0 |
| CharacterService | Spawn, estado vivo/morto e atributos derivados | Catalog, Profile, Modifier | F0 |
| AbilityService | Autorizar ativação, fases, cancelamento e efeitos | Cooldown, Resource, Combat, Catalog | F0 |
| CombatService | Estado de combate, hitbox, alvo, dano, guarda e morte | SpatialQuery, Character, Zone | F0 |
| ResourceService | Pool, custo, regeneração, exaustão e eventos | Modifier, Catalog | F0 |
| ModifierService | Buff/debuff/passiva/equipamento, fonte e expiração | Relógio do servidor | F0 |
| CooldownService | Cooldowns por habilidade, grupo e personagem | Relógio do servidor | F0 |
| ZoneService | Zona atual, regras PvP, transição e spawn seguro | World/Spatial, Character | F0 — domínio headless feito (item 6); volumes/colisão no Studio pendentes |
| LoadoutService | Validação de slots, ultimate, ressonância e ativação | Catalog, Profile, Resource | F1 |
| ProgressionService | F0: flags de unlock da fatia (spawn sem técnicas; grant idempotente). XP/objetivo 1 no restante do item 7; F2: maestria e respec | Profile, Catalog, Ability | F0 mínimo — flags feitas; XP/quest pendentes |
| InventoryService | Posse, stacks, instâncias, capacidade e equip | Profile, Catalog | F2 |
| CraftingService | Forja determinística, graus, custos, recibos e materiais | Inventory, Economy | F2 |
| TradeService | Mercado mediado, escrow, commit/compensação e histórico | Inventory, Profile, OperationLedger | F7 opcional pós-lançamento |
| QuestService | F0: objetivo único da fatia com receipt/flag; F3: cadeias, estado e objetivos dirigidos por eventos | Profile, Catalog, World | F0 mínimo; amplia F3 |
| BossService | Spawn, contribuição, loot pessoal e pity de raro separado da forja | Combat, Quest, Loot | F3 |
| ReputationService | Reputação, fora da lei, morte e bounty | Combat, Zone, AbuseSignals | F4 |
| ClanService | Membros, cargos, convites, perks e banco limitado | ClanRepository, OperationLedger | F5 |
| TerritoryService | Posse, disputa e bônus capado de região | Clan, World, Scheduler | F7 opcional pós-lançamento |
| TournamentService | Inscrição, bracket, forfeit e premiação | Matchmaking, Teleport, Ranking | F6 |
| RankingService | Temporada, MMR e projeções de leaderboard | SeasonRepository, OrderedDataStore | F6 |
| SecurityService | Validações comuns, score de risco e kill switches | Telemetry, configuração operacional | F0 |
| TelemetryService | Métricas, eventos estruturados e correlação | Sink/console controlado | F0 |

Serviços de fases futuras não devem ser antecipados com implementação vazia em F0. Seus contratos podem ser documentados e introduzidos somente quando o caso de uso vertical chegar.

### 4.2 Cliente

| Controller | Responsabilidade | Regra de autoridade |
|---|---|---|
| InputController | Mapear touch, teclado, mouse e gamepad para intenções semânticas | Nunca decide se a ação foi aceita |
| CharacterController | Movimento local, câmera e leitura do estado confirmado | Previsão visual é corrigível |
| AbilityController | Antecipar animação/VFX e reconciliar aceite/rejeição | Não calcula acerto, dano ou custo final |
| CombatFeedbackController | Hit confirm confirmado, dano recebido e feedback de guarda | Não recebe fórmulas secretas nem escolhe alvo válido |
| ResourceController | Exibir snapshot/delta de recurso | Não regenera nem desconta valor persistente |
| ZoneController | Avisos, borda visual e confirmação de entrada PvP | O servidor define a zona efetiva |
| InteractionController | Exibir prompts localizados e enviar alvo/fase semânticos | O servidor revalida catálogo, distância, hold e efeito |
| LoadoutController | Editar rascunho e enviar comando de ativação | O servidor recalcula slots e ressonância |
| InventoryController | Exibir inventário e solicitar mutações | Não cria, move ou destrói item localmente como verdade |
| SocialController | Clã, torneio, ranking e convites | Exibe projeções autorizadas |
| UIController | Roteamento de telas, acessibilidade e estado transitório | Não chama remotes fora dos controllers de domínio |

`ActorAnimator` e `PlayerCombatAnimator` não entram na ordem dos sete controllers F0: são utilities de apresentação sem autoridade de domínio. O servidor replica a raiz dos NPCs a partir do `SpatialService`; o cliente amostra apenas `Motor6D.Transform`. `InteractionController` é uma extensão contextual subordinada ao input, não um oitavo controller de domínio. A migração futura para clipes R15 não pode mudar essas fronteiras de autoridade.

### 4.3 Topologia de places e operação regional

- O `World Place` reúne vila, região inicial e zona livre em um mapa compacto com streaming. O baseline é 16 jogadores; 20 ou 24 só podem ser habilitados depois de profiling de scripts, física, rede e densidade de combate.
- O `Arena Place` é separado e usa servidores reservados para ranked e torneios. O servidor de arena reconstrói o snapshot permitido; dados do cliente ou do teleporte não autorizam build, rating ou resultado.
- O acesso técnico pode ser global, mas o soft launch é operado primeiro no Brasil. PT-BR e inglês são revisados manualmente; outros idiomas podem usar tradução automática sem promessa inicial de suporte.
- Regras, agendas e persistência usam UTC. A apresentação converte para o locale/fuso do jogador, e o cliente nunca escolhe a janela autoritativa.

## 5. Estado e fronteiras de autoridade

### 5.1 Estado persistente

Pertence aos repositórios do servidor: perfil, progressão, inventário, moedas, loadouts, maestria, reputação, ranking-fonte, associação de clã e registros compartilhados. O cliente recebe somente projeções necessárias à tela.

### 5.2 Estado de sessão

Pertence ao servidor: cooldown, recurso atual, efeitos, estado de combate, proteção de spawn, tokens de teleporte, locks de ação e contribuição de boss. O que precisar sobreviver a crash deve ter recibo ou journal explícito; não se deve salvar a cada golpe.

### 5.3 Estado visual previsto

Pertence ao cliente e pode ser descartado: animação antecipada, trilha, tremor de câmera, retículo e barra interpolada. Cada previsão é correlacionada a um `requestId`; rejeição cancela ou suaviza o visual.

### 5.4 Física e network ownership

Network ownership melhora responsividade, mas não concede autoridade de regra. O servidor valida deslocamento, estado, janela temporal e alcance. Projéteis que causam dano têm trajetória ou resultado validado no servidor; um objeto controlado pelo cliente nunca aplica dano apenas por `Touched`.

## 6. Contratos de rede

### 6.1 Envelope comum

Todo comando cliente → servidor terá, conceitualmente:

| Campo | Finalidade | Regra |
|---|---|---|
| `protocolVersion` | Compatibilidade do contrato | Inteiro conhecido; versão incompatível é rejeitada |
| `requestId` | Correlação e idempotência de comandos elegíveis | ID curto, único por sessão e com retenção limitada |
| `clientSequence` | Ordenação e detecção de replay local | Crescente por canal; não substitui relógio do servidor |
| `action` | Comando permitido no contrato | Enum fechado |
| `payload` | Apenas parâmetros necessários | Schema estrito, limites de tamanho e profundidade |

Não aceitar timestamp do cliente como prova de cooldown, posição, propriedade ou ordem global. O tempo do cliente pode ser usado apenas como pista limitada para compensação de latência, nunca como autoridade.

### 6.2 Catálogo inicial de contratos

| Contrato lógico | Direção | Intenção ou projeção | Resposta esperada |
|---|---|---|---|
| AbilityIntent | C→S | Ativar, manter ou cancelar uma habilidade por ID e input mínimo | Aceite/rejeição com fase e sequência autoritativa |
| MovementAbilityIntent | C→S | Solicitar dash ou movimento especial | Aceite e parâmetros visuais aprovados |
| InteractionIntent | C→S | Interagir com entidade identificada | Resultado do caso de uso, nunca recompensa arbitrária |
| LoadoutCommand | C→S | Salvar ou ativar composição | Aceite/rejeição, loadout recalculado e resumo de Ressonância |
| InventoryCommand | C→S | Equipar, desequipar, forjar ou melhorar | Revisão nova do inventário ou erro de conflito |
| TradeCommand | C→S | Criar, alterar, confirmar ou cancelar troca futura | Estado da saga e revisão; contrato só é habilitado na F7 pós-lançamento |
| QuestCommand | C→S | Aceitar ou reclamar etapa elegível | Progresso/recompensa confirmados |
| ClanCommand | C→S | Convite, cargo, banco, guerra ou território | Estado autorizado ou recibo da operação |
| TournamentCommand | C→S | Inscrição, ready, forfeit ou reconexão | Estado de inscrição/partida |
| SessionSnapshot | S→C | Projeção inicial após perfil pronto | Versão da projeção e seções permitidas |
| StateDelta | S→C | Mudança confirmada de recurso, cooldown, inventário ou progressão | Sequência para detectar lacuna |
| CombatEvent | S→C | Ação aceita, hit confirmado, dano e estado | Dados visuais mínimos, sem segredos desnecessários |
| ZoneEvent | S→C | Pré-aviso e confirmação de transição | Zona, regra PvP e instante de efetivação |
| OperationResult | S→C | Resultado correlacionado de comando | `requestId`, status estável e revisão relevante |

Eventos servidor → cliente usam sequência por domínio. Ao detectar lacuna, o cliente solicita ressincronização limitada da seção, não o perfil inteiro.

Para `LoadoutCommand`, o servidor valida no máximo quatro unidades de capacidade, uma ultimate separada, no máximo uma técnica Definidora e impacto total até 12. Ele calcula `rawD = slots estrangeiros + (2 se a ultimate for estrangeira) + famílias estrangeiras adicionais`. Se `rawD > 3`, o comando é rejeitado; **não** se usa clamp como autorização. O perfil recebe três presets-base (`PvE`, `Mundo`, `Arena`) e pode chegar a seis somente com entitlement de conveniência, sem ampliar slots, impacto ou Dissonância.

## 7. Fluxos ponta a ponta

### 7.1 Entrada do jogador

1. `PlayerSessionService` cria sessão em estado `Loading`; remotes mutáveis ainda não estão disponíveis.
2. O adaptador abre o perfil com session lock e aplica migrações determinísticas.
3. Catálogos referenciados e invariantes do save são validados; referência inválida é normalizada ou colocada em quarentena conforme gravidade.
4. Serviços derivam atributos, loadout e spawn permitido.
5. O servidor envia uma projeção inicial, marca `Ready` e só então aceita comandos.
6. Em falha, o jogador recebe erro recuperável; nunca entra com perfil default sobrescrevendo um save que não carregou.

### 7.2 Ativação de habilidade

1. O cliente prevê apenas o início visual e envia `AbilityIntent`.
2. O gateway valida envelope, sessão, schema, taxa e replay.
3. `AbilityService` verifica personagem vivo, estado, posse, loadout, zona, custo, cooldown e conflitos.
4. Recurso e cooldown são reservados/consumidos em ordem definida; o serviço cria uma execução com ID autoritativo.
5. O servidor resolve janela, hitbox, linha de visão, alvo e dano. O cliente nunca envia dano nem lista final de vítimas.
6. Eventos confirmados alimentam recurso, maestria, reputação, UI, VFX e telemetria.
7. Cancelamento ou interrupção segue política da definição; reembolso também é regra de dados, não decisão do cliente.

Ao conceder maestria elegível, o servidor acumula XP e deriva nível de técnica de 1 a 10. Os marcos comportamentais ficam em 3, 6 e 9; ganhos numéricos pequenos em 2, 5 e 8 são removidos em ranked. Nível 10 não concede pico de poder competitivo.

### 7.3 Morte no mundo aberto

1. `CombatService` emite morte confirmada com cadeia de contribuição.
2. `ZoneService` determina o conjunto de regras vigente no instante do dano decisivo.
3. `ReputationService` calcula elegibilidade, diferença de poder, repetição de pares e sinais de abuso.
4. Penalidades e recompensas são aplicadas por uma operação idempotente.
5. Proteção e destino de respawn são definidos no servidor; o cliente apenas apresenta.

O poder efetivo é uma projeção server-side de 0 a 100, derivada de progressão da zona (30%), completude do loadout (25%), maestria (20%), equipamento (15%) e desempenho PvP com incerteza (10%). O grupo agressor soma até 30 pontos. Esse valor não é persistido nem aceito do cliente; é recalculado sob a versão de regra vigente.

### 7.4 Mutação econômica

1. O comando referencia IDs, quantidade e revisão esperada; nunca envia saldo resultante.
2. O servidor valida propriedade, capacidade, catálogo, estado de combate e permissões.
3. Uma operação com ID único reserva os recursos e registra o estado.
4. A mutação acontece sob lock/revisão do agregado proprietário.
5. Retry retorna o mesmo resultado. Falha parcial entra em compensação; não repete a concessão.
6. O cliente recebe recibo e delta somente após commit lógico.

Na forja, a receita escolhe deterministicamente um dos cinco graus (potência 60/70/80/90/100% e custo relativo 1/2/3/5/8). Não existem roll, falha de design, destruição, rebaixamento ou pity de upgrade. Uma falha técnica anterior ao commit não consome materiais; retry com o mesmo `operationId` retorna o mesmo recibo. O pity persistente pertence somente ao loot pessoal raro de boss e usa agregado próprio por conta/boss/tabela.

### 7.5 Torneio entre servidores

1. Scheduler publica janela e inscrições em estado compartilhado, sem depender do relógio do cliente.
2. O bracket é congelado com versão e participantes elegíveis.
3. Cada participante recebe um token de teleporte de uso único, ligado a partida e UserId.
4. O servidor de arena reconstrói o loadout e aplica a versão de normalização: HP, dano, guarda, recurso, ganhos numéricos de maestria, atributos brutos e refinamento são normalizados; habilidades desbloqueadas, composição, Dissonância e variantes comportamentais legais são preservadas.
5. O resultado usa operação idempotente; arena em falha fica pendente para reconciliação, sem premiar ambos por padrão.
6. OrderedDataStore recebe projeção posterior; não é a fonte de verdade do resultado.

## 8. Persistência, budgets e disponibilidade

- Uma carga principal por perfil no join; nenhum `GetAsync` ou `SetAsync` em loops de gameplay.
- Autosave coalescido, inicialmente entre 60 e 120 segundos com jitter, ajustado por telemetria e orçamento disponível.
- Mudanças críticas marcam seções dirty, mas não forçam uma escrita por item ou kill.
- Saída normal salva e libera o lock; `BindToClose` drena operações com prazo limitado e registra o que ficou pendente.
- O adaptador consulta o budget atual antes de operações não urgentes e aplica backoff com jitter.
- Ranking e telemetria são projeções assíncronas; indisponibilidade deles não bloqueia combate.
- Mercado, troca, banco de clã e premiação podem entrar em modo somente leitura por kill switch.
- MemoryStore pode coordenar leases, filas e matchmaking, mas não é a única fonte durável de posse.
- O perfil terá meta interna de até 256 KiB serializados no lançamento; atingir 80% bloqueia crescimento não essencial e gera alerta.
- Inventário, histórico e recibos têm limites explícitos; logs extensos ficam fora do perfil.

Detalhes de schemas, locking e migração estão em `05-DATA-SCHEMA.md`.

## 9. Observabilidade

### 9.1 Eventos estruturados mínimos

| Evento | Campos essenciais | Uso |
|---|---|---|
| SessionLoad | correlação, versão anterior/nova, duração, resultado | Saúde de save e migrações |
| RemoteRejected | contrato, razão, peso, sequência, correlação | Abuso, bugs de cliente e tuning de limites |
| AbilityResolved | abilityId, fase, resultado agregado, latência | Balanceamento e performance sem registrar input excessivo |
| EconomyMutation | operationId, tipo, origem, deltas, revisões, resultado | Auditoria e anti-dupe |
| KillResolved | zona, diferença de poder, recompensa, sinais | Bounty, camping e win trading |
| TeleportLifecycle | matchId, token hash, origem, destino, estado | Falhas de torneio e replay |
| SaveAttempt | seções dirty, tamanho, budget, tentativas, resultado | Capacidade e risco de perda |
| SecuritySignal | categoria, severidade, evidências resumidas | Investigação e resposta |

Não registrar chat bruto, tokens, payload completo de remotes, endereço de rede ou informação pessoal desnecessária. IDs de operação devem permitir correlação sem expor segredos.

### 9.2 Métricas e alertas

- p50/p95/p99 de load, save, resolução de habilidade e resposta de remote;
- taxa de rejeição por contrato e motivo;
- tamanho de perfil e quantidade de operações pendentes;
- saldo emitido e drenado por fonte, por hora;
- duplicidade de itemInstanceId e falha de reconciliação;
- mortes repetidas por par, spawn e diferença de poder;
- falha de teleporte, arena órfã e resultado pendente;
- tempo de frame do servidor, volume de rede e contagem de candidatos por consulta espacial.

Alertas devem usar baseline por versão. Uma mudança de cliente que aumenta rejeições não deve virar ban automático.

## 10. Estratégia de testes

| Camada | Testes planejados | Critério |
|---|---|---|
| Dados | Schema, IDs únicos, referências, limites, nomes públicos e curvas | Catálogo inválido impede build |
| Domínio | Recursos, modificadores, cooldown, dano, ressonância e economia | Determinístico com relógio e RNG injetados |
| Migração | Fixture de cada versão suportada, repetição e falha | Migrar duas vezes não corrompe nem duplica |
| Contrato | Encode/decode, versão, campos extras, payload hostil | Todo remote falha fechado |
| Integração | Join→combate→save→rejoin e operações econômicas | Estado final e recibos consistentes |
| Propriedade/fuzz | Sequências aleatórias de inventário, trade e comandos | Quantidades nunca ficam negativas; item não tem dois donos |
| Concorrência | Dois servidores, retry, disconnect e shutdown | Lock e fencing impedem dupla sessão/mutação |
| Segurança | Replay, spam, spoof de dano, teleporte e escalada de cargo | Rejeição sem efeito colateral |
| Carga | Bots de teste em servidor cheio, bosses e guerra | Budgets de frame/rede atendidos |
| Cliente | Touch/gamepad/teclado, previsão e resync | Rejeição não deixa UI ou animação presa |

Teste em Studio não substitui teste publicado privado com múltiplos servidores. Fases econômicas só avançam após testes de crash nos pontos entre reserva, commit e resposta.

## 11. Budgets iniciais de performance

São metas internas iniciais, não limites garantidos da plataforma. Devem ser medidos na fatia vertical e revisados antes de aumentar jogadores ou roster.

| Recurso | Meta inicial | Estratégia |
|---|---|---|
| Tempo de scripts do servidor | p95 até 8 ms por frame em servidor-alvo | Profiling por serviço; trabalho pesado fatiado |
| Resolução de intenção de combate | p95 até 100 ms no servidor, sem contar rede | Filas curtas e nenhuma persistência no caminho crítico |
| Consulta de hitbox | Até 32 candidatos antes de filtros finos | Spatial query, collision groups e limites por habilidade |
| Rede de gameplay | Média até 30 KiB/s por jogador; p95 até 50 KiB/s | Deltas, quantização e batching; medir por plataforma |
| Snapshot inicial | Até 128 KiB de projeção ao cliente | Paginar inventário e social; não replicar perfil bruto |
| Perfil persistido | Meta até 256 KiB | Caps, dados esparsos e históricos externos |
| Atualizações de UI | Orientadas a eventos; no máximo 10 Hz para barras contínuas | Interpolação local sem polling do servidor |
| Autosave | 60–120 s com jitter | Coalescer seções e respeitar budget dinâmico |

Regras de implementação futura:

- não usar uma conexão Heartbeat por habilidade, buff ou jogador;
- usar schedulers agregados para expiração e regeneração;
- não replicar efeitos cosméticos para quem está fora do raio de relevância;
- limitar NPCs ativos por região e usar LOD de simulação;
- cachear definições imutáveis, nunca resultados de autorização;
- degradar VFX no mobile, mas preservar telegraph e regra de hit.

## 12. Stack e fluxo de engenharia

| Ferramenta | Papel planejado | Decisão de adoção |
|---|---|---|
| Rojo | Sincronizar filesystem e Studio com mapeamento explícito | Configuração e build de CI existentes; runtime no Studio ainda precisa ser provado |
| Wally | Pacotes Luau com versões fixadas e lockfile | Configuração e instalação de CI existentes; atualização exige revisão |
| luau-lsp | Tipos e análise; módulos core em modo estrito | Alvo incremental; ainda não é gate explícito da CI atual |
| Selene | Lint semântico e regras do projeto | Configuração e check de CI existentes |
| StyLua | Formatação determinística | Configuração e check de CI existentes |
| ProfileStore | Session locking e ciclo de perfil atrás de adaptador | Dependência presente; contrato, takeover e DataStore real ainda precisam de teste publicado |
| GitHub Actions | Formato, lint, testes, dependências e build no push/PR | Pipeline existente; sem credencial ou deploy automático |

Pipeline atual: StyLua check → Selene → 241 testes de domínio + 73 de animação/apresentação + 67 de fuzz + 19 de combate ponta a ponta → instalação Wally → build Rojo. A evolução aprovada acrescenta type check Roblox e fixtures de migração sem remover os gates existentes. A CI não terá credenciais de produção e não publicará place automaticamente.

## 13. Ordem arquitetural por fase

0. **P0 — consolidação do plano:** decisões de produto e arquitetura foram aprovadas em 2026-08-12; divergências documentais são sincronizadas antes de ampliar a implementação.
1. **P1 — gate jurídico/plataforma:** revisar nomes, assets, políticas Roblox e monetização antes de qualquer asset público.
2. **F0 — fatia vertical:** um estilo, três habilidades, uma família de recurso, mapa pequeno com zona segura + livre, PvP e save ponta a ponta.
3. **F1 — plataforma de combate:** conteúdo dirigido a dados, expansão controlada de estilos, loadout e Ressonância.
4. **F2 — progressão/economia básica:** maestria, respec, inventário, equipamento e forja; troca continua fora de escopo.
5. **F3–F4:** mundo PvE/recursos; depois reputação, morte e proteção social.
6. **F5–F6:** clãs sem território completo; depois torneios e ranking sazonal.
7. **Hardening e soft launch Brasil-first:** depois de F6, validar operação, localização, segurança e produto inicial sem poder pago.
8. **F7 opcional pós-lançamento:** território e mercado mediado, cada um atrás de gate próprio de consistência, população e segurança; não condicionam o lançamento.

Conteúdo amplo, comércio aberto, banco compartilhado, guerras e torneio multi-servidor são escopo excessivo para as duas primeiras fases. Antecipá-los aumentaria o risco de perda de save e duplicação antes do combate principal estar validado.

## 14. Riscos e validações técnicas

| Risco | Consequência | Mitigação/validação necessária |
|---|---|---|
| Arquitetura própria crescer como framework | Atraso e complexidade | Limitar bootstrap às quatro capacidades definidas e revisar em F0 |
| ProfileStore ou sua API mudar | Dependência operacional frágil | Pinar revisão, auditar upstream e manter adaptador/testes de contrato |
| Previsão visual divergir do servidor | Combate parece pesado ou injusto | IDs de execução, reconciliação e testes com latência/perda |
| Combinações de modificadores explodirem | Bugs e meta dominante | Ordem de aplicação formal, caps e teste combinatório |
| Trading exigir atomicidade inexistente | Dupe/perda de item | Manter fora do lançamento; F7 só entra com saga/escrow e crash tests |
| Clã e território terem múltiplos escritores | Corrupção ou dupla posse | Revisionamento, UpdateAsync, lease com fencing e registros separados |
| Metas de performance não caberem no mundo | Queda de FPS e latência | Provar na fatia vertical antes de ampliar mapa e servidor |

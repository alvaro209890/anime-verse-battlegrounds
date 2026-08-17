# 13 — Spec de implementação da fatia F0

## 1. Contrato deste documento

Este arquivo é a **spec de execução** da fatia vertical. Política de produto continua em `09-OPEN-QUESTIONS.md`. Números de combate, mapa, objetivo, HUD e ordem de build da F0 são definidos aqui para implementação.

| Tipo | Significado |
|---|---|
| Política | Já aprovada em `09`; este doc só aplica |
| F0-BASELINE | Número inicial a implementar e medir; muda com evidência, sem reabrir a política |
| Congelado para F0 | Não implementar nesta fase, mesmo que exista no GDD |

Em conflito de **execução da fatia**, este documento prevalece sobre catálogo legado, stubs e TODOs do código. Em conflito de **política**, `09-OPEN-QUESTIONS.md` prevalece.

P1 (revisão jurídica) continua obrigatório antes de concept art, áudio final, marketing ou publicação. Greybox, IDs internos e playtest interno controlado podem avançar.

| ID | Decisão | Estado |
|---|---|---|
| SLICE-DEC-001 | Kit F0 usa as três técnicas do Punho do Eclipse; placeholders `dash_strike` / `eclipse_barrier` / `void_rupture` / `eclipse_judgement` saem do catálogo jogável | aprovada para execução — 2026-08-12 |
| SLICE-DEC-002 | Ultimate `eclipse_beat` existe no catálogo com `enabled = false`; não tem botão, runner nem teste de feeling | stretch da F0 |
| SLICE-DEC-003 | Famílias além de `umbral_aether` permanecem no catálogo, mas não são selecionáveis nem gastas | F1 |
| SLICE-DEC-004 | Números de frame, hitbox, XP e mapa deste arquivo são F0-BASELINE | playtest |
| SLICE-DEC-005 | Cliente não dispara intenção no boot; input só após `SessionSnapshot` | obrigatória |

## 2. Divergências do código atual

Itens 1–13 estão fechados em código/headless. O snapshot de implementação anterior era o commit `d7c44e8`, que inclui a integração de VFX, skins de monstros, expansão visual do cenário e teto/terreno. Após a rodada de 16/08 (`scripts/ci.sh`, e2e de pesado/Cometa, atalho de casa), as suítes atuais executam **241 testes de domínio** e **73 de animação/apresentação**; o fuzz determinístico adiciona **67 casos** e a simulação de combate ponta a ponta adiciona **19**, totalizando 400 casos automatizados. Esses resultados são validação automatizada; não equivalem a Play no Studio. O que **não** está comprovado é execução real em Play: o build atual não foi executado, e não há roteiro, Output ou captura dessa revisão. Ainda falta:

| Onde | Estado atual | Alvo desta spec |
|---|---|---|
| `src/shared/Data/Abilities.luau` | `comet_shoulder`, `broken_cadence`, `pulse_return`; `eclipse_beat` desligada | feito |
| `src/shared/Data/EnergyFamilies.luau` | Umbral regen 2/6, Fluxo 6 / 120 ms, cap 1,5 s | feito |
| `src/shared/Data/Npcs.luau` | dummy 10000 HP; `enemy_wandering_shard` 60 HP / dano 8 / alcance 4 / telegraph 400 ms; `npc_threshold_instructor` (ofertante) | **item 9 feito**: `enemy_anchored_shard` (120 HP, slam 14/700 ms, combo 6+6/300 ms, respawn 180 s, XP 80 cooldown 180 s, leeching 1%/8 s) — pathfinding/Studio pendente |
| `src/shared/Data/Zones.luau` | 8 zonas (Bastião, transição, planície + Lumen/Bosque/Porto/Cinza/Academia), aventais dos portões, 7 âncoras F0 + 6 Estilhaços + 5 marcos de bioma | feito |
| `src/shared/Geometry.luau` | distância, costas, esfera, cápsula, caixa, lunge e passo de perseguição | feito |
| `SpatialService` | registro de posição/olhar; hitbox à frente, cápsula do trajeto, `resolveCometShoulder` | feito no domínio; leitura do `HumanoidRootPart` só roda no Studio |
| `EnemyService` | spawn nas 6 âncoras, perseguição 12 studs/s, ciclo de ataque, respawn 45 s, teto 4 | feito no domínio; nunca rodou em Studio |
| `WorldService` / `WorldPresentation` | constrói piso para cada volume canônico — inclusive transições norte/oeste e braço livre oeste —, rotas, praça, portões, cratera, marcos, iluminação, modelos low-poly, telegraph branco + símbolo e collision groups; em 15/08 a decoração da planície/rotas/cratera (`WildDecorations`), as skins de Estilhaço (`shardGearFor`) e as posições de luz do spawn (`spawnLights`) passaram a vir de dados validados | **código/headless/build feitos; aparência, colisão, legibilidade e performance não verificadas em Play** |
| `src/shared/Data/Quests.luau` | `quest_hunt`: 3 Estilhaços, +40 XP, unlock Cometa, aceite forçado em 90 s | **itens 9/10 feitos** + extras: `quest_elite`, `quest_flow`, `quest_grove` (6 errantes, +50 XP, unlock Tecelão) e `quest_remnant` (elite de novo, +80 XP); cadeia de 5 |
| `src/shared/Data/Locale.luau` | chaves §16 em PT-BR e EN; validado no boot contra os catálogos | copy final e P1 |
| `CombatService` | cadeia leve, guarda, aparo, pesado, quebra, dash, dummy, comet, Estilhaço, `killed` na transição vivo → morto; alvo e lado do golpe agora vêm do `SpatialService` | **itens 8/10 feitos**: postura do Pulso (250 ms, 50%, contra 8, erro 600 ms) e ciclo do elite (combo/slam alternados, slam unblockable com guarda 30%) — Studio pendente |
| `AbilityService` | comet resolve o fighter do dummy; `CombatHit` no acerto; unlock via `ProgressionService` no bootstrap | **itens 8/10 feitos**: Cadência com janela de reentrada + eco agendado no tick; Pulso abre postura no FighterState; `onFlowEcho` credita `quest_flow` — Studio pendente |
| `ProgressionService` | spawn sem técnicas; grant idempotente; XP não consolidado com retorno decrescente por âncora e teto de 800/sessão | **item 9 feito**: cooldown de XP por NPC (elite 180 s) — consolidação, perda na morte e persistência (item 11) |
| `QuestService` | oferta → aceite (NPC ou 90 s) → progresso por kill → +40 XP e `unlock_comet_shoulder` no 3º | **itens 9/10 feitos**: cadeia sequencial (anterior precisa completar) e kind `flow_echo` via `creditFlowEcho` |
| `ZoneService` | zona atual, `canPvp`, transição 5 s, lockout 15 s, `ZoneEvent` + `ZoneCrossingIntent`; hostil na segura não marca PvP | 5 sinais visíveis/audíveis, volumes e collision groups no Studio |
| `PlayerSessionService` | snapshot Ready lê zona, unlocks, objetivo e XP não consolidado | feito no domínio |
| `TelemetryService` / `SecurityService` | sete eventos allowlisted; envelope/payload fechado; replay, sequência e rate limit por classe | feito em código/headless; pré-cobertura de dois jogadores e limpeza de orçamento no rejoin adicionadas; fuzz, spam e adversarial runtime ainda pendentes |
| `InteractionService` / `Interactions` | Instrutor e Marco allowlisted; alvo, âncora, posição, distância e hold do Marco medido por 1,5 s no relógio do servidor; pending limpo no leave | feito em código/headless; prompt e fluxo real pendentes no Studio/dispositivos |
| `src/client/init.client.lua` | sete controllers na ordem §12.3; espera `SessionSnapshot.ready`; sem intenção no boot; envelope v2 e HUD localizado; `InteractionController` usa `ProximityPrompt`; `ActorAnimator` e `PlayerCombatAnimator` alteram somente apresentação | feito em código/headless; Studio e dispositivos pendentes |
| `SaveService` | stub em memória; persiste `wallet` | **item 11 feito**: ProfileRoot v1 sem wallet, ProfileStore via `Shared.vendor` (lock, autosave 60–120 s, release); DataStore real e respawn no Studio pendentes |
| `StudioDebug` | exige `RunService:IsStudio()` + atributo `F0Debug = true`; concede as 3 técnicas como flags de sessão fora do save; sem remote de cheat | feito em código/headless; uso real no Studio pendente |
| Mapa/HUD | greybox enriquecido, buracos norte/oeste cobertos a partir dos volumes, HUD mínimo, prompts localizados e telegraph acessível implementados por código | execução, layout, colisão, animação e feeling no Studio/dispositivos pendentes |

Testes Lune no snapshot de implementação atual: 241 casos em `tests/run.luau`, 73 em `tests/animation.luau`, 67 em `tests/security_fuzz.luau` e 19 em `tests/combat_e2e.luau` (`docs/12-TESTING.md` e `docs/23-DOCUMENTATION-SNAPSHOT.md`). Isolamento de orçamento entre jogadores e sequência fora de ordem continuam cobertos headless; não substituem o R1 no Studio.

**Comprovado neste recorte:** técnicas locked no spawn; Estilhaço Errante completo no domínio; XP e objetivo 1; geometria do greybox; hitbox e lunge; uma receita de piso por volume canônico; resposta procedural pura de leve, pesado, guarda e dash em fases, VFX locais de defesa/dash e impacto temporário de chão; reforma visual data-driven do spawn com piso, teto, iluminação e skin enriquecida da instrutora; decoração dirigida por dados da planície, das duas rotas e da borda da cratera, sem colisão e fora do ringue do elite; skin de Estilhaço/elite como receita pura com alcance travado contra o `attackRange` real; apresentação local dos cinco sinais da fronteira, que não acende em travessia recusada; catálogo fechado de interação; gate `ready`; alvo exclusivo; proximidade e hold de 1,5 s revalidados pelo servidor, sem recompensa declarada pelo cliente.

**Não comprovado — e esta é a linha que importa:** não há playtest Studio do build atual. O código constrói pisos, prompts, modelos, telegraph e HUD, mas faltam boot/spawn, Parts/Motor6D reais, layout, clipping, colisão, feeling, hold de fronteira, interação com Instrutor/Marco e sincronismo visual em Play. Toque, mobile e gamepad reais, DataStore real, servidor publicado e dois clientes continuam pendentes. Um teste headless ou `rojo build` verde prova estrutura/regra, não runtime Roblox.

**Arquitetura da camada espacial (2026-08-12).** A regra fica em módulos puros e testáveis; só a tradução para Instances é intocada por teste.

| Camada | Módulo | Testado no Lune |
|---|---|---|
| Matemática | `src/shared/Geometry.luau` | sim |
| Volumes e âncoras | `src/shared/Data/Zones.luau` | sim |
| Consultas de combate | `SpatialService` | sim |
| AI e spawn | `EnemyService` | sim |
| Receitas e poses procedurais | `WorldPresentation` / `ActorAnimator.sample` | sim |
| Parts, muros e collision groups | `WorldService` | **não** — é a fronteira Roblox |

Regra de manutenção: se o `WorldService` precisar de um `if` de gameplay, o `if` está no lugar errado. Ele traduz dados em parts e nada mais.

**Inferência de layout do Portão Oeste.** §8.1 dimensiona a planície em 160 × 120 ao norte, mas não diz onde o Portão Oeste desemboca. `Zones.luau` acrescenta um braço oeste à zona livre para o portão não dar em lugar nenhum. O `WorldService` agora deriva piso de cada volume e cobre tanto esse braço quanto as transições norte/oeste; isso corrige em código os vãos que poderiam derrubar o jogador, mas a travessia ainda precisa ser observada em Play. É F0-BASELINE, revisável no greybox do Studio.

**Interpretação registrada do retorno decrescente (§9.2).** A spec diz “retorno decrescente após 6 kills da mesma âncora na sessão (12, depois 0)” sem fechar onde o 12 termina. A implementação adota **6 kills a 25, os 6 seguintes a 12, o resto a 0**, expresso como dados em `Npcs.luau` (`xpFullKills` / `xpReducedKills` / `xpReducedValue`). É F0-BASELINE: muda com evidência de playtest, sem reabrir política.

## 3. Escopo congelado da fatia

**Entra**

- Punho do Eclipse, Éter Umbral, ataque básico, pesado, guarda, aparo, dash
- três técnicas; ultimate desligada
- Bastião do Limiar + Planície Estilhaçada compacta
- 1 dummy de treino, 1 inimigo comum, 1 elite
- 1 cadeia de três objetivos; consolidação de XP; morte com perda só de XP não consolidado
- PvP na zona livre; fronteira com os cinco sinais de `02-WORLD.md`
- save v1 com session lock no place privado
- HUD e input em teclado/mouse, toque e gamepad
- telemetria mínima §15

**Não entra**

- Ressonância, loadout misto, presets, maestria 1–10, equipamento, forja, moeda, inventário
- clã, reputação completa, bounty, ranked, arena, teleporte entre places
- alto risco, boss, evento agendado, troca
- VFX/áudio/animações de produção; nomes canônicos na UI
- monetização

## 4. Identidade e IDs estáveis

| Conceito | ID interno | Chave pública | UI F0 |
|---|---|---|---|
| Identidade | `eclipse_fist` | `character.eclipse_fist.name` | Punho do Eclipse |
| Família | `umbral_aether` | `family.umbral_aether.name` | Umbral |
| Vila | `zone_bastion_safe` | `zone.bastion.name` | Bastião do Limiar |
| Transição | `zone_threshold_transition` | — | (sem nome; só aviso) |
| Planície | `zone_plain_free` | `zone.plain.name` | Planície Estilhaçada |
| NPC | `npc_threshold_instructor` | `npc.threshold_instructor.name` | Instrutor do Limiar |
| Dummy | `npc_training_dummy` | `npc.training_dummy.name` | Boneco de Treino |
| Comum | `enemy_wandering_shard` | `enemy.wandering_shard.name` | Estilhaço Errante |
| Elite | `enemy_anchored_shard` | `enemy.anchored_shard.name` | Estilhaço Ancorado |

Codinomes internos de roster **não** entram em ID, asset, analytics visível, erro ou UI.

## 5. Ações universais — F0-BASELINE

Avatar de referência: vida 100, guarda 100, caminhada 16 studs/s, corrida 22 studs/s. Buffer de input: 150 ms PC/console, 220 ms mobile. O servidor não aceita timestamp do cliente como prova de janela.

**Corrida (implementada 17/08):** hold **Shift** (PC) ou **L3** (gamepad) →
`Humanoid.WalkSpeed` 22; soltar → 16. Catálogo em `src/shared/Data/Locomotion.luau`.
O cliente aplica a velocidade; o servidor clampa o WalkSpeed lido no envelope de
movimento a no máximo 22 (`Locomotion.clampAuthorizedSpeed`) para um exploit de
speed não inflar o budget do `PlayerMotionGuard`. Não há remote de sprint.

### 5.1 Ataque leve

Cadeia de 4 golpes: **5 + 5 + 6 + 10**. Janela para continuar: 0,65 s. O quarto golpe não gira 180° após o quadro de compromisso.

| Golpe | Startup | Active | Recovery | Hitbox | Stagger |
|---|---:|---:|---:|---|---|
| 1 | 160 ms | 90 ms | 220 ms | esfera 4 studs à frente | `stagger_light` 120 ms |
| 2 | 140 ms | 90 ms | 220 ms | esfera 4 studs | `stagger_light` 120 ms |
| 3 | 180 ms | 100 ms | 260 ms | esfera 4,5 studs | `stagger_light` 150 ms |
| 4 | 260 ms | 120 ms | 550 ms | cápsula 5×4×6 | `stagger_light` 220 ms |

Leve contra guarda: 40% do HP passa; guarda perde o dano cheio. Costas ignoram guarda.

Aquisição autoritativa (centro-a-centro): alcance 6 + folga de corpo **5** = **11 studs** no degrau 1 (cone 78° leve / 68° pesado). Playtest: colado a ~11 studs não conectava com folga 3. Dummy de treino não concede XP nem kill de carreira.

### 5.2 Ataque pesado

| Campo | Valor |
|---|---|
| Startup / active / recovery | 380 / 140 / 520 ms |
| Dano HP (sem guarda) | 10 |
| Dano de guarda | 28 |
| HP se bloqueado e guarda sobrevive | 2 |
| Hitbox | cápsula 5×5×7 |
| Miss | não inicia cadeia leve por 500 ms |

Pesado é a ferramenta de quebra. Se a guarda chega a 0, o excesso vira HP a 50% e o alvo entra em quebra (0,80 s, sem guarda por 1,20 s).

### 5.3 Guarda e aparo

- Redução frontal: 60% do HP. Costas, agarrão e quebra sinalizada ignoram.
- Aparo: primeiros **120 ms** de uma guarda nova. Compensação de latência só no servidor, no máximo **+80 ms**. Aparo válido: 0 HP, 0 guarda, atacante ganha 200 ms de recovery extra.
- Cliente nunca informa “foi aparo”.

### 5.4 Dash

| Campo | Valor |
|---|---|
| Distância / duração | 12 studs / 220 ms |
| Cooldown | 3,0 s |
| I-frames | 80 ms no início do deslocamento; explícitos (flash curto) |
| Colisão | para em parede e em guarda inimiga; não atravessa hitbox ativa inteira |
| Dano | nenhum |

Dash é movimento universal, não substitui Ombro Cometa.

### 5.5 Combo e controle (F0)

Aplicar o teto do GDD: combo garantido acaba em **3 s**, **35 de dano** ou **três controles**. Repetir o mesmo grupo em 4 s: 60% da duração; terceira aplicação: 30% + imunidade 1 s. Cancelamento só se a técnica declarar `cancelable` e o runner abrir a janela.

## 6. Kit — Punho do Eclipse

Capacidade usada: 3. Impacto usado: 6 (ultimate desligada; com ela seria 11). Nenhuma Definidora nesta fatia.

### 6.1 Ombro Cometa — `comet_shoulder`

| Campo | Valor |
|---|---|
| kind / slotCost / impactCost | Skill / 1 / 2 |
| tags | `movement`, `melee`, `cancelable` |
| Custo / cooldown | 18 / 7 s |
| Startup / active / recovery | 180 / 220 / 350 ms |
| Deslocamento | 7 studs à frente; cap absoluto 8 |
| Dano | 9 |
| Hitbox | cápsula 4×4×8 no trajeto |
| Guarda | **para o avanço**; 9 de guarda; HP bloqueado 4 |
| Stagger | `stagger_lunge` 180 ms |
| Contra | lateral e costas no recovery; não atravessa parede |
| `serverRunnerId` | `comet_shoulder_runner` |
| Unlock | flag `unlock_comet_shoulder` |

Runner: reserva recurso e cooldown → move no servidor até 7 studs ou primeiro bloqueio → overlap na janela active, máx. 1 alvo → aplica dano/guarda → emite `CombatEvent`. Cliente prevê o lunge; rejeição reconcilia sem dano fantasma.

### 6.2 Cadência Quebrada — `broken_cadence`

| Campo | Valor |
|---|---|
| kind / slotCost / impactCost | Skill / 1 / 2 |
| tags | `melee`, `cancelable` |
| Custo / cooldown | 16 / 8 s |
| Golpe 1 | startup 140 ms, active 80 ms, dano 7 |
| Intervalo | 100 ms |
| Golpe 2 | active 80 ms, dano 9, recovery 280 ms |
| Hitbox | esfera 4,5 studs, máx. 1 alvo por golpe |
| Reentrada | 120 ms após o fim do active do golpe 2 |
| Eco | 350 ms depois, dano 6, mesma hitbox; não controla |
| Fluxo | se o eco **acerta**, +6 Umbral; máx. 1 vez / 1,5 s |
| `serverRunnerId` | `broken_cadence_runner` |
| Unlock | flag `unlock_broken_cadence` |

Reentrada é um segundo `AbilityIntent` com `abilityId = broken_cadence` e `phase = "reentry"` ligado ao `executionId`. Fora da janela: ignora, sem gastar recurso. Errar a janela **não** atordoa o usuário. Mobile usa buffer de 220 ms só no cliente; o servidor valida 120 ms + lag comp ≤ 80 ms.

Passiva F0 da família (não da identidade): a primeira ativação de Fluxo a cada 8 s devolve **+3** extras. Implementar no `ResourceService`, não no runner.

### 6.3 Retorno de Pulso — `pulse_return`

| Campo | Valor |
|---|---|
| kind / slotCost / impactCost | Skill / 1 / 2 |
| tags | `defense`, `melee` |
| Custo / cooldown | 20 / 12 s |
| Postura | 250 ms; reduz **50%** de **um** golpe frontal |
| Contra (se reduzir) | active 180 ms, dano 10, empurrão 8 studs, recovery 300 ms |
| Erro (nenhum golpe) | recovery 600 ms |
| Agarrão / costas | vencem a postura |
| `serverRunnerId` | `pulse_return_runner` |
| Unlock | flag `unlock_pulse_return` |

Não é invulnerabilidade. Só o primeiro hit frontal na janela é reduzido; o contra não ocorre se o hit for costas, pesado de quebra já em break, ou elite slam marcado `unblockable`.

### 6.4 Ultimate — `eclipse_beat` (desligada)

Catálogo: kind Ultimate, impacto 5, custo 55, CD 90 s, `enabled = false`. Sem `clientPresentationId` obrigatório. Runner pode ser stub que retorna `disabled`.

## 7. Éter Umbral — F0-BASELINE

Alinhar o catálogo ao GDD, não aos números atuais do código:

| Campo | Valor |
|---|---:|
| `poolBase` / `poolCap` | 100 / 100 |
| Regen em combate | 2 / s |
| Regen fora de combate | 6 / s após 3 s sem causar nem receber dano |
| Fluxo | +6; janela da Cadência 120 ms; cap 1 / 1,5 s |
| Bônus passivo F0 | +3 na primeira ativação de Fluxo a cada 8 s |
| Pool em 0 | não gasta técnica; sem exaustão extra nesta fatia |

Leve confirmado **não** gera Fluxo. Só a reentrada da Cadência gera. Isso ensina o breakpoint de 15–20 min.

## 8. Greybox do mapa

Um único `World Place`. Sem streaming obrigatório nesta escala. Collision groups: `Safe`, `Transition`, `Free`, `GateBlock`.

### 8.1 Medidas

| Peça | Tamanho (studs) | Notas |
|---|---|---|
| Bastião do Limiar | 80 × 64, paredes 16 | chão plano, 4 pilares de 20 de altura como marco |
| Treino | 24 × 24 no canto NE | dummy no centro; sem PvP |
| Spawn | círculo r = 8 no centro-sul | não vê a planície em linha reta |
| Portão Norte | 12 de largura, arco 10 de altura | saída principal |
| Portão Oeste | 10 de largura | LOS quebrada por um muro em L |
| Volume de transição | 8 de profundidade em cada portão | zona `zone_threshold_transition` |
| Planície | 160 × 120 | chão com material distinto (areia/pedra vs. pedra clara da vila) |
| Cratera da elite | r = 20, 70 studs ao norte do Portão Norte | borda 2 studs mais alta |
| Pontos de Estilhaço | 6 âncoras | mínimo 24 studs entre si; nenhum a menos de 20 do portão |

O pilar central do Bastião deve ser visível da planície (silhueta). Do spawn, o jogador **não** olha direto para o PvP.

### 8.2 Fronteira PvP

Os cinco sinais de `02-WORLD.md` §4.2, todos juntos:

1. arco/portal físico (não um decal no chão)
2. mudança de iluminação e material
3. faixa de UI: ícone + `hud.pvp_active` + resumo da morte
4. som curto + vibração se houver
5. indicador persistente depois de cruzar

Regras F0:

- saída da segura: 5 s de transição; não causa nem recebe PvP; ação hostil encerra na hora; voltar é livre
- entrada na segura: se combate PvP nos últimos 15 s, bloqueia a barreira interna; timer visível
- projétil/área não atravessa a fronteira com dano
- primeira travessia da sessão: prompt “manter pressionado” 0,6 s no toque; PC/gamepad confirmam com o mesmo hold no botão de interação

Alto risco **não existe** na fatia.

### 8.3 Âncoras de spawn

IDs persistidos, nunca CFrame cru: `anchor_bastion_spawn`, `anchor_bastion_return`, `anchor_training`, `anchor_instructor`, `anchor_gate_north`, `anchor_gate_west`, `anchor_elite`. Morte na planície respawna em `anchor_bastion_return`.

## 9. Inimigos

Autoridade no servidor. Sem pathfinding complexo: estado idle → telegraph → ataque → recovery. Sem aggro através da fronteira.

### 9.1 Boneco de Treino

| Campo | Valor |
|---|---|
| Vida | 10 000 (não morre na prática) |
| Dano | 4 a cada 2,5 s, telegraph 400 ms, só se o jogador estiver a 8 studs |
| XP / objetivo | nenhum |
| Função | ensinar leve, guarda, dash em 60 s |

### 9.2 Estilhaço Errante

| Campo | Valor |
|---|---|
| Vida | 40 |
| Dano | 6, telegraph 400 ms, esfera 4 studs |
| Velocidade | 12 studs/s |
| Aggro / leash | **30 studs** (padrão Blox Fruits): fora do raio não inicia perseguição e larga a que já tinha, voltando à âncora |
| Respawn | 45 s na mesma âncora, se ninguém em combate a 20 studs |
| XP | 25 não consolidado; retorno decrescente após 6 kills da mesma âncora na sessão (12, depois 0) |
| População | no máximo 4 vivos |

### 9.3 Estilhaço Ancorado (elite)

| Campo | Valor |
|---|---|
| Vida | 80 |
| Slam | telegraph 700 ms, dano 12, `unblockable` para Retorno de Pulso, guarda reduz 30% |
| Combo leve | 5 + 5, telegraph 300 ms |
| Respawn | 180 s |
| XP | 80 não consolidado, uma vez por 3 min por jogador |
| Função | breakpoint de 15–20 min |

Leeching: crédito se o jogador causou ≥ 1% da vida ou ficou 8 s no raio 20. Sem último golpe.

## 10. Roteiro da sessão

Textos abaixo são chaves, não copy final. PT-BR placeholder em §16.

| Tempo | Beat | Sistema | Flag |
|---|---|---|---|
| 0–15 s | Spawn no Bastião. HUD: vida, guarda, Umbral, zona segura. Sem técnicas. | `SessionSnapshot` | `ftue_spawned` |
| 15–60 s | Dummy à vista. Prompt `ftue.dummy_hint`. Jogador usa leve, guarda, dash. | combate | `ftue_dummy_hit` após 1 acerto |
| ~60 s–3 min | NPC oferece objetivo 1. Tracker visível. Portões com aviso. | quest | `quest_hunt_accepted` |
| 3–5 min | Cruzar fronteira (sinais). Matar 3 Estilhaços. Unlock **Ombro Cometa** no 3º kill (também no campo). | quest + ability | `unlock_comet_shoulder` |
| 5–15 min | Usar Ombro Cometa. Opcional: PvP, morte, voltar ao Marco de Retorno e consolidar. | zona + save | `first_consolidation` se consolidar |
| 15–20 min | Elite na cratera. Derrotar (ou contribuir). Unlock **Cadência Quebrada**. Prompt de timing/Fluxo. | elite | `unlock_broken_cadence` |
| 20 min | Loop completo da fatia: combate, risco, poder novo, save. | aceite F0 curto | — |
| 45–60 min | NPC: acertar **um** eco de Fluxo. Unlock **Retorno de Pulso**. | quest | `unlock_pulse_return` |

Objetivo 1 não exige PvP: os 3 Estilhaços podem ser lutados sem outro jogador. PvP é opt-in geográfico.

Se o jogador ignorar o NPC, o tracker ainda aparece após 90 s (`quest_hunt_accepted` forçado). Não jogar o combate sozinho: dummy não morre e técnicas não disparam sozinhas.

## 11. Progressão e save

`ProfileSchemaVersion = 1`. Sem `wallet`, `loadouts`, `inventory`, `quests` agregados. Objetivo usa `tutorialFlags` + `recentOperations`.

```text
ProfileRoot v1
  schemaVersion, userId, revision, createdAt, updatedAt, lastServerSessionId
  progression.accountLevel          -- derivado do XP consolidado; começa 1
  progression.consolidatedXp
  progression.unconsolidatedXp
  progression.unspentProgressionPoints
  progression.spentTracks           -- vitality/umbral/impact/guard/resonance
  progression.lastConsolidationAt
  progression.tutorialFlags         -- conjunto de IDs conhecidos
  characters.eclipse_fist           -- unlockedAt
  abilities.{id}                    -- unlockedAt somente; sem masteryXp
  settings                          -- locale, redução de efeitos, esquema de input
  recentOperations                  -- anel ≤ 32 recibos
```

### 11.1 XP e consolidação

Fontes F0: Estilhaço 25, elite 80, objetivo 1 +40, objetivo elite +60, objetivo Fluxo +40. Teto de emissão por sessão: 800 não consolidado.

Consolidar: interagir 1,5 s com `anchor_bastion_return` fora de combate. Move todo `unconsolidatedXp` para `consolidatedXp`. Recibo `operationId` idempotente. Se o consolidado cruzar a curva `floor(2 × n^2,3 + 84)`, o nível sobe e o jogador recebe 3 pontos por nível (HUD STATUS / tecla K). Gasto é `SpendProgressionIntent` com `trackId` allowlisted; o cliente nunca informa o efeito.

Morte (Q-018, sem materiais):

| Zona | Perda |
|---|---|
| Segura / treino | 0 |
| Livre PvE | 10% do não consolidado; cap = 200 XP (5 min × 40/min) |
| Livre PvP | 15% do não consolidado; mesmo cap |

XP perdido sai da economia; não vai ao agressor. Respawn: `anchor_bastion_return`, proteção 8 s ou até atacar/sair do raio 12.

### 11.2 Falhas de save a provar

1. leave normal persiste flags e XP
2. crash no autosave não duplica unlock
3. rejoin no mesmo servidor restaura
4. segundo servidor recusa sessão concorrente (lock)
5. falha injetada no load: jogador **não** entra com perfil default por cima de save existente

Autosave 60–120 s com jitter. Combate não persiste.

## 12. Cliente: input, câmera, HUD

Nenhuma fórmula de dano no cliente. Intenção semântica → remote. Mapeamento: GDD §3.1.

F0 mostra **três** botões de técnica. Slot vazio/bloqueado: ícone cadeado, sem botão morto extra. Ultimate oculto enquanto `eclipse_beat.enabled = false`.

### 12.1 Câmera (Q-006)

- PC: câmera livre; lock-on opcional (**Tab** ou clique do meio). A roda do mouse não trava a mira: ela já zooma a câmera Roblox, e o playtest de 13/08 ficou preso sem HUD de saída (`docs/18-ANALISE-VIDEO.md`).
- Toque/gamepad: magnetismo 8° até 25 studs; some após compromisso e em área
- Soft lock só no ataque básico, não nas técnicas de deslocamento
- HUD: botão **MENU** / tecla **H** abre Configurações; faixa permanente no rodapé; botão **SOLTAR MIRA** no centro quando o lock-on está ativo; botões **ATACAR / GUARDA / DASH** visíveis também no PC. Clique esquerdo de combate **não** é descartado quando a HUD marca `processed` (só TextBox e GuiButton ativo comem o clique).

### 12.2 HUD mínimo

| Elemento | Conteúdo | Regra |
|---|---|---|
| Vidas | HP + guarda | eventos; interpolar local ≤ 10 Hz |
| Umbral | valor / 100; ícone distinto **sem** depender só de cor | esgotado visível |
| Técnicas | 3 slots, cooldown radial, cadeado se locked | não mostra custo mentiroso |
| Zona | “SEGURO” / “PvP ATIVO” + perda resumida | persistente fora da vila |
| Objetivo | progresso + **+XP da task** (número do servidor), máx. 48 caracteres | some ao completar |
| Feedback | hit confirm, guarda, rejeição (`no_resource`, `cooldown`) | 1 s; sem código interno |
| Nível | barra de XP no topo; **STATUS** / tecla **K** abre as 5 trilhas; flash dourado no level-up | pontos só gastam via remote; cliente não calcula curva |
| XP do kill | número dourado flutuante no monstro, como o dano | só com `xpPopup.amount > 0` do servidor |
| Mochila | **MOCHILA** / tecla **B** — técnicas e materiais | itens F0 sem poder de combate |
| Carreira | **CARREIRA** / tecla **J** — kills, chefes, dano, tempo | réplica do servidor; dummy não conta |
| Menu | botão **MENU** / tecla **H**; controles, mira e tremor da câmera | não envia remote |
| Combate | botões **ATACAR / GUARDA / DASH** (PC e toque); clique esquerdo no mundo | HUD chrome não descarta o golpe (`processed`) |
| Mira | botão **SOLTAR MIRA** no centro enquanto travada | só apresentação local; `clearLock` não procura outro alvo |

Mobile: no máximo dois botões simultâneos. Técnicas em cluster direito; dash e guarda separados. Área de combate central sem HUD opaco > 20%.

### 12.3 Controllers a criar

Ordem principal: `InputController` → `CharacterController` → `AbilityController` → `CombatFeedbackController` → `ResourceController` → `ZoneController` → `UIController`. `InteractionController` é uma extensão contextual entre input e UI: cria prompts nativos localizados e emite apenas a intenção; não muda a autoridade nem introduz `LoadoutController`. `PlayerCombatAnimator` é apresentação subordinada ao input, não controller de domínio.

Remover o `FireServer` de boot em `init.client.lua`.

## 13. Remotes da fatia

Envelope: `protocolVersion`, `requestId`, `clientSequence`, `action`, `payload`. Timestamp do cliente não autoriza.

| Contrato | Dir. | Payload aceito | Proibido do cliente |
|---|---|---|---|
| `SessionSnapshot` | S→C | zona, HP, guarda, Umbral, unlocks, objetivo | — |
| `StateDelta` | S→C | HP/guarda/recurso/cooldown/flags | — |
| `BasicAttackIntent` | C→S | `press`/`release`, `aim?`, `claimedTargetId?` (pista) | dano, distância, “foi hit” |
| `GuardIntent` | C→S | `down`/`up` | “parry success” |
| `DashIntent` | C→S | direção unitária limitada | distância final |
| `AbilityIntent` | C→S | `abilityId`, `inputMode`, `executionId?`, `phase?`, ponto/alvo só se a def exigir | dano, vítimas, custo |
| `CombatEvent` | S→C | `executionId`, `abilityId`, hit/guarda/morte, `view` dealt/taken | fórmulas |
| `ZoneEvent` | S→C | de, para, regra PvP, instante, sinais, lockoutRemaining | — |
| `ZoneCrossingIntent` | C→S | `toZoneId`, `holdConfirmed?`, `requestId` | posição, “já cruzei” |
| `InteractionIntent` | C→S | exatamente um de `anchorId` / `npcId`; `phase = begin/complete/cancel` | distância, duração, recompensa |
| `SpendProgressionIntent` | C→S | `trackId` allowlisted, `amount` 1–3 ou `respec` | efeito, nível, saldo |
| `AbilityRejected` | S→C | `abilityId`, `reason` estável | — |

`AbilityActivate` atual vira `AbilityIntent` (mesmo remote pode ser renomeado numa mudança só, com versão 2). Rate limit: 8 intenções de combate/s; excesso descarta sem efeito.

## 14. Serviços — ordem de build

Não criar serviços de F1–F7 vazios.

| # | Entrega | Depende de | Pronto quando |
|---|---|---|---|
| 1 | Catálogo alinhado + testes Lune | — | IDs desta spec; CI verde |
| 2 | Umbral GDD no `ResourceService` | 1 | regen 2/6, Fluxo 6 / 1,5 s |
| 3 | `CharacterService` spawn/morte/respawn | sessão | HP 100, âncora segura |
| 4 | Combate universal (leve, pesado, guarda, dash) | 3 | dummy jogável no Studio |
| 5 | Runners das 3 técnicas | 2, 4 | hitbox e custo no servidor |
| 6 | `ZoneService` + fronteira | 3 | 5 sinais; PvP só na livre |
| 7 | Inimigos + objetivo + flags | 5, 6 | roteiro 20 min |
| 8 | `ProgressionService` mínimo + consolidação | 7, save | unlock idempotente |
| 9 | ProfileStore no place privado | 8 | cenários §11.2 |
| 10 | Input/HUD 3 plataformas | 4–6 | mesmo roteiro em PC, toque, gamepad |
| 11 | `TelemetryService` + `SecurityService` mínimo | gateway | eventos §15; payload hostil rejeitado |

`ModifierService` F0: só guarda quebrada, i-frame de dash e postura de Pulso. Sem buff de equipamento.

## 15. Telemetria mínima

Sem chat, IP, payload completo de remote ou PII. Correlação: `sessionId`, `releaseId`, `userId`.

| Evento | Campos | Uso |
|---|---|---|
| `SessionLoad` | durationMs, schemaFrom, schemaTo, result | save |
| `FtueBeat` | flag, elapsedMs | curva 60 s / 3 min / 5 min |
| `AbilityResolved` | abilityId, result, latencyMs, flowGranted | feeling / abuso |
| `KillResolved` | zoneId, pve\|pvp, powerDelta?, xpLost | fronteira e morte |
| `SaveAttempt` | dirty, bytes, result | lock |
| `RemoteRejected` | contract, reason, weight | exploit |
| `ZoneTransition` | from, to, holdConfirmed | R-002 |

## 16. Localização placeholder

Arquivo único `src/shared/Data/Locale.luau` (PT-BR default, EN segundo). Sem copy de franquia.

| Chave | PT-BR |
|---|---|
| `character.eclipse_fist.name` | Punho do Eclipse |
| `family.umbral_aether.name` | Umbral |
| `ability.comet_shoulder.name` | Ombro Cometa |
| `ability.broken_cadence.name` | Cadência Quebrada |
| `ability.pulse_return.name` | Retorno de Pulso |
| `zone.bastion.name` | Bastião do Limiar |
| `zone.plain.name` | Planície Estilhaçada |
| `hud.zone_safe` | SEGURO |
| `hud.pvp_active` | PvP ATIVO — morte perde XP não consolidado |
| `hud.pvp_hold` | Segure para entrar na zona livre |
| `ftue.dummy_hint` | Ataque, defenda e esquive no boneco |
| `quest.hunt.tracker` | Estilhaços: {n}/{req}  ·  +{xp} XP |
| `quest.elite.tracker` | Derrote o Estilhaço Ancorado |
| `quest.flow.tracker` | Acerte um eco da Cadência |
| `npc.threshold_instructor.name` | Instrutor do Limiar |

## 17. Arte e áudio da fatia

Permitido: parts, cores neutras, luz, UI retangular, som de beep, animação R15 genérica, VFX geométrico (anel, pulso, cone).

Proibido até P1: silhueta/roupa/cabelo reconhecíveis, VFX cromático de referência, áudio temático, ícones de franquia, nomes canônicos em textura.

Telegraph de perigo: contorno branco + símbolo `!`/`!!`, não só vermelho. A implementação procedural recebe duração e padrão autoritativos, preserva apresentação de late join e não abre hitbox. Mobile reduz partículas; mantém o contorno. Tudo isso continua pendente de inspeção em Play.

O personagem local possui overlay procedural de antecipação, impacto, guarda, dash e retorno ao neutro sobre `Motor6D`, sem decidir acerto, dano, custo ou deslocamento final. É resposta greybox testável, não substitui o golpe-modelo A1 nem conta como clip final.

A direção de produção, lista de clipes, markers, gates de qualidade e budgets de dispositivo estão em `docs/14-ANIMATION-PLAN.md`. Esse plano não muda a proibição de assets finais antes de P1 nem transforma animação em autoridade de combate.

## 18. Place, Studio e dispositivos

| Item | Valor F0 |
|---|---|
| Experiência | privada, não listada, distinta de qualquer público |
| Places | só `World Place`; sem Arena |
| Jogadores | 8 no playtest interno; alvo documental 16 depois do profiling |
| DataStore | prefixo `avb_f0_v1_` |
| ProfileStore | `lib/ProfileStore.luau` atrás do adaptador; sem DataStore cru |

Dispositivos (Q-005): registrar modelo, RAM, resolução e rede **depois** do primeiro playtest, não antes. Categorias: Android de entrada, telefone mediano, PC com gráfico integrado, gamepad.

Roteiro de Studio solo: boot limpo → dummy → 3 técnicas (cheats de unlock só em build de teste) → morte → rejoin. Depois: 2 clientes, fronteira, spam de remote.

Cheat de unlock: remote **inexistente** no cliente. O gate `StudioDebug` só concede flags de sessão no servidor se `RunService:IsStudio()` e o atributo `F0Debug = true` existir no DataModel **ou** no Script Server (o Rojo nem sempre carimba a raiz do place). Essas flags não entram no save. O HUD mostra `KIT DE TESTE` quando as três técnicas vêm desse override.

## 19. Testes da mudança de catálogo

Os casos abaixo estão em `tests/run.luau` (166 no total; fonte: chamadas `test(...)`):

- roster `eclipse_fist` com 3 skills enabled + 1 ultimate disabled
- `comet_shoulder` custo 18, CD 7, runner registrado
- ativação gasta 18, dano 14, recusa sem recurso / cooldown / morto
- comet no fighter dummy: 14 HP aberto; guarda para o avanço (6 HP + 14 guarda); aparo e i-frame zeram
- join Ready → comet gasta 18 e dummy fica em 9991 HP
- `broken_cadence` recusa reentrada fora da janela; Fluxo +6 no eco que acerta, respeita cap 1,5 s
- `pulse_return` sem golpe → não aplica contra
- `eclipse_beat` `enabled = false` → `disabled`
- catálogo: Umbral pool 100, regen combate 2
- flags de unlock: técnica locked rejeita `AbilityIntent`

Item 6 (zona/fronteira) adicionou os casos abaixo:

- catálogo: 8 zonas (3 F0 + 5 biomas); PvP em zonas `kind=free`; âncoras F0 + Estilhaço + marcos; spawn = `anchor_bastion_spawn` em `zone_bastion_safe`
- catálogo: zona/âncora inválida (zona desconhecida, spawn ausente, PvP fora da planície) falha validação
- zona: join começa em `zone_bastion_safe`; `canPvp` false
- zona: sem `holdConfirmed`, recusa primeira ida à livre (`hold_required`)
- zona: com hold, entra em transição 5 s; `canPvp` false durante a transição
- zona: ação hostil na transição encerra a proteção na hora
- zona: ação hostil na segura (treino) **não** marca lockout PvP
- zona: voltar da transição sem hostil é livre
- zona: 5 sinais sempre juntos ao cruzar segura↔livre; evento `ZoneEvent` com payload completo
- zona: `markPvpCombat` recente bloqueia reentrada na segura por 15 s (`combat_lockout`, timer no evento); após 15 s libera
- zona: `canDamageCrossBoundary` false cruzando segura↔livre; true dentro do mesmo lado
- remote: `ZoneEvent` S→C e `ZoneCrossingIntent` C→S (version 1)
- fatia: sessão Ready lê a zona do `ZoneService` (`zone_bastion_safe`); dummy/comet intactos após unlock

Unlock no spawn (recorte do item 7):

- join → `comet_shoulder` / `broken_cadence` / `pulse_return` recusam `locked`; recurso intacto
- `grantUnlock("unlock_comet_shoulder")` é idempotente; flag desconhecida recusa
- leave limpa as flags (sem persistência ainda)
- após grant, comet gasta 18 e dummy fica em 9991 HP; snapshot lista a flag

Estilhaço Errante (recorte do item 7):

- catálogo: 60 HP, dano 8, alcance 4, telegraph 400 ms, respawn 45 s, XP 25, max 4, zona livre
- combate: telegraph depois dano 8; `no_aggro` através da fronteira; fora de 4 studs recusa
- combate: recovery bloqueia o próximo golpe; respawn 45 s bloqueia se combate perto; cap 4 vivos

Objetivo 1, XP e Locale (item 7, 2026-08-12):

- locale: as chaves de §16 existem em PT-BR e EN; chave desconhecida devolve a própria chave; `{n}` é substituído pelo progresso
- catálogo: `quest_hunt` é 3 Estilhaços, +40 XP, `unlock_comet_shoulder`, ofertante `npc_threshold_instructor`, aceite forçado em 90 s
- catálogo: objetivo com alvo/ofertante desconhecido, `requiredCount = 0` ou `acceptFlag` vazia falha validação
- catálogo: `displayNameKey` de conteúdo habilitado sem entrada no Locale falha validação
- XP: kill do Estilhaço credita 25 não consolidado; dummy não credita
- XP: 6 kills a 25, 6 a 12, depois 0 — por âncora, não global
- XP: teto de emissão de 800 por sessão corta a emissão e recusa valor negativo/jogador desconhecido
- objetivo: aceite no Instrutor marca `quest_hunt_accepted` e abre o tracker; segundo aceite não repete
- objetivo: kill antes do aceite não conta
- objetivo: tracker aparece sozinho 90 s depois de ignorar o NPC; `tick` é idempotente
- objetivo: 3º kill completa, paga +40 XP, concede `unlock_comet_shoulder` e some o tracker
- objetivo: kill depois de completo não repete prêmio; alvo fora do objetivo não conta
- combate: `killed` só na transição vivo → morto; golpe em morto não re-carimba `diedAt` (não empurra o respawn)
- remote: `InteractionIntent` C→S e `StateDelta` S→C (version 1); `SessionSnapshot` carrega o objetivo
- fatia: roteiro 0–5 min ponta a ponta — spawn locked → aceite → travessia → 3 kills → 115 XP → Ombro Cometa cobrado a 18 Umbral; Cadência e Pulso continuam locked

Camada espacial (greybox, hitbox, lunge e AI — 2026-08-12):

- geometria: distância no plano ignora altura; normalize de vetor nulo não vira NaN
- geometria: costas ignoram guarda; perpendicular conta como frente; sem olhar conhecido assume frente
- geometria: cápsula do trajeto acerta no eixo e no raio, erra fora do raio e depois do fim
- geometria: lunge anda 7, respeita o cap absoluto de 8 e para antes de encostar no bloqueador
- geometria: `moveToward` respeita 12 studs/s e para exatamente no alcance, sem ultrapassar
- greybox: o volume de cada zona resolve a zona declarada por **todas** as âncoras; fora de todo volume devolve nil; o plano exato do portão resolve como transição
- greybox: 6 pontos de Estilhaço, ≥ 24 studs entre si e ≥ 20 de cada portão
- catálogo: âncora que declara uma zona mas cai no volume de outra falha validação
- espaço: hitbox à frente acerta 1 alvo e ignora quem está atrás ou longe
- espaço: Ombro Cometa avança 7, commita a posição no servidor e acerta 1 alvo na cápsula
- espaço: guarda inimiga trava o avanço antes dos 7 studs
- espaço: avanço sem ninguém no trajeto é resultado válido (sem alvo, sem bloqueio)
- inimigo: spawn até o teto de 4, id com a âncora embutida, sem duplicar na segunda chamada
- inimigo: persegue, para no alcance, abre telegraph, não causa dano dentro dos 400 ms e aplica 6 depois
- inimigo: jogador na zona segura não gera aggro nem perseguição
- inimigo: fora de 30 studs não puxa e larga a perseguição (volta à âncora)
- inimigo: respawn de 45 s bloqueado com jogador a menos de 20 studs da âncora, liberado quando ele se afasta
- inimigo: kill reporta âncora e autor para o crédito de XP
- remote: `EnemyEvent` S→C (version 1) com telegraph no payload

Integração Lune não cobre Studio. Evidência runtime: `12-TESTING.md` §6. O que segue **sem nenhuma evidência de execução no build atual**: reabrir o snapshot, ver pisos/parts/prompts do `WorldService`, falar com o Instrutor, consolidar no Marco, avaliar telegraph e resposta procedural, feeling do combate, sinais visíveis/audíveis, hold 0,6 s da fronteira, collision groups reais, latência, toque, mobile, gamepad, DataStore e múltiplos clientes.

## 20. Backlog priorizado

Ordem de implementação; cada item fecha com teste automatizado **ou** evidência Studio anotada.

1. ~~Alinhar catálogo, Umbral, testes Lune e CI~~ (feito 2026-08-12; 31 testes)
2. ~~Tirar `FireServer` do boot; `SessionSnapshot` mínimo~~ (feito 2026-08-12; domínio + remote)
3. ~~Spawn + movimento + leve/guarda/dash contra dummy~~ (domínio headless 2026-08-12; movimento/Studio pendente)
4. ~~Pesado + quebra de guarda~~ (feito 2026-08-12; 43 testes)
5. ~~Ombro Cometa~~ (feito 2026-08-12; lunge espacial de 7 studs com cap 8, parada na guarda e cápsula do trajeto entraram em 2026-08-12 via `SpatialService.resolveCometShoulder`)
6. ~~Greybox + `ZoneService` + 5 sinais~~ (regras concluídas em 2026-08-12; fundação visual evoluída em 2026-08-13. O commit `108be31` passou a gerar piso para todos os volumes, cobrindo os buracos norte/oeste, moveu o soft target para os atores, acrescentou telegraph branco + símbolo e sincronizou duração/padrão de apresentação. Em 2026-08-15 os cinco sinais deixaram de ser só payload: `lighting_material` e `audio_haptic` ganharam apresentação local no `ZoneSignalPlayer`, e travessia recusada (`hold_required`, `combat_lockout`) não acende nada. **Sem execução em Studio**: Parts/Motor6D, pisos, sinais, iluminação, clipping, hold 0,6 s e playtest cego continuam pendentes)
7. ~~Estilhaços + objetivo 1 + unlock Cometa~~ (completo 2026-08-12; 109 testes — Locale, `Quests.luau`, `QuestService`, XP com retorno decrescente e teto de sessão, unlock no 3º kill, `InteractionIntent` + `StateDelta`, e o `EnemyService` com spawn nas 6 âncoras, perseguição, telegraph e respawn. **Pendente**: persistência do XP/flags, que é o item 11, e execução em Studio)
8. ~~Cadência + Fluxo~~ (completo 2026-08-12 — janela de reentrada abre 120 ms após o fim do active do golpe 2 (400 ms da ativação), clique prematuro não destrói a janela, reentrada agenda o eco para 350 ms depois (`AbilityService.tick` no Heartbeat), eco 4 com Fluxo +6, cap 1,5 s e bônus +3 a cada 8 s no `ResourceService`. **Pendente**: execução em Studio)
9. ~~Elite + unlock Cadência~~ (completo 2026-08-12 — `enemy_anchored_shard` no catálogo com slam 14/700 ms unblockable (guarda corta 30%) e combo 6+6/300 ms alternados por ciclo; spawn único na `anchor_elite`; respawn 180 s; leeching ≥ 1% da vida ou 8 s no raio sem último golpe; XP 80 com cooldown de 180 s por jogador; `quest_elite` +60 XP e `unlock_broken_cadence`. **Pendente**: cratera e ciclo no Studio)
10. ~~Pulso + objetivo 45–60 min~~ (completo 2026-08-12 — postura de 250 ms reduz 50% de UM golpe frontal; contra 8 + empurrão 8 studs espacial; erro vira recovery 600 ms; costas e slam do elite vencem a postura; `quest_flow` kind `flow_echo` creditado pelo eco da Cadência, +40 XP e `unlock_pulse_return`. **Pendente**: empurrão e feeling no Studio)
11. ~~Consolidação + morte + ProfileStore~~ (completo 2026-08-12 — consolidação no Marco de Retorno move todo o não consolidado com recibo `operationId` idempotente e anel de 32 recibos; morte aplica perda por zona: segura 0, livre PvE 10%, PvP 15%, cap 200; `SaveService` com ProfileRoot v1, session lock, autosave 60–120 s com jitter e os 5 cenários de §11.2 cobertos por teste; `lib/ProfileStore.luau` entra no build via `ReplicatedStorage.Shared.vendor`. **Pendente**: DataStore real no place privado e respawn com proteção 8 s no Studio)
12. ~~HUD/input mobile e gamepad~~ (implementado em código/headless 2026-08-13 — controllers na ordem §12.3, gate `SessionSnapshot.ready`, envelope v2, 8 intenções/s, teclado/mouse/toque/gamepad, soft lock 8°/25 studs apenas no ataque básico, HUD localizado e resposta procedural local. O recorte I1 adicionou `ProximityPrompt` contextual para PC/toque/gamepad. **Pendente**: qualquer playtest do build atual, toque/mobile e gamepad reais)
13. ~~Telemetria + rejeição adversarial de remotes~~ (implementado em código/headless 2026-08-13 — `TelemetryService` aceita somente os sete eventos da §15 e remove campos arbitrários; `SecurityService` fecha schema de envelope/payload, bloqueia replay de `requestId`/sequência, NaN/vetor impossível/campo extra e aplica 8 intenções de combate/s com orçamento separado para interação. Rejeição é amostrada por contrato/motivo para não inundar logs. **Pendente**: fuzz/spam em Studio com dois clientes e sink operacional fora do log do servidor)
**Recorte preparatório I1 concluído em código/headless; os números abaixo são históricos:** `anchor_instructor`; prompts localizados para Instrutor/Marco; `InteractionIntent` fechado com `begin/complete/cancel`; alvo, distância e hold de 1,5 s autoritativos; pisos das duas transições e do braço oeste; telegraph acessível; resposta procedural do jogador. Nenhuma dessas Instances foi observada em Play.

14. Playtest interno 20 min: primeiro reabrir o snapshot atual, então executar W1 solo com os dois pisos/portões e as duas interações; depois A1 e R1. Android, gamepad, DataStore real e múltiplos clientes só mudam de pendente quando forem realmente executados.

Não puxar item 8 antes do 5. Não puxar ProfileStore real antes do loop dummy existir — senão o save testa um jogo que ainda não se joga.

## 21. Critério de pronto desta spec

A spec está **usada**, não só escrita, quando:

- o catálogo desta fatia substituiu os placeholders
- o roteiro de 20 min roda em Studio sem cheats, salvo unlock de Pulso se a sessão for curta
- fronteira PvP é compreensível sem instrução verbal (meta 90% no teste cego)
- save passa os cinco casos §11.2 no place privado
- as três plataformas executam ataque, dash, guarda e as técnicas desbloqueadas
- lista explícita do que impede F1 (feeling, netcode, custo por habilidade)

Gate F0 do roadmap permanece: 20 sessões internas, 10 externas, sem vulnerabilidade crítica nos remotes do slice.

## 22. Fora desta spec

Qualquer número de F1–F7, busca de marca, parecer jurídico, preços em Robux, 13 identidades, economia completa. Mudança de política (slots, Dissonância, morte que derruba equipamento) exige nova decisão em `09`, não um patch silencioso aqui.

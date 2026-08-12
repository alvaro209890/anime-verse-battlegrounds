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

O esqueleto em `src/` **não** implementa o loop jogável no Studio. Catálogo, Umbral, SessionSnapshot, combate universal e Ombro Cometa headless já estão alinhados (itens 1–5 do backlog). Ainda falta:

| Onde | Estado atual | Alvo desta spec |
|---|---|---|
| `src/shared/Data/Abilities.luau` | `comet_shoulder`, `broken_cadence`, `pulse_return`; `eclipse_beat` desligada | feito |
| `src/shared/Data/EnergyFamilies.luau` | Umbral regen 2/6, Fluxo 6 / 120 ms, cap 1,5 s | feito |
| `src/shared/Data/Npcs.luau` | dummy 10000 HP, dano 4, alcance 8 | feito |
| `CombatService` | cadeia leve, guarda, aparo, pesado, quebra, dash, dummy, comet 9/guarda 9/HP 4 | hitbox espacial e lunge de 7 studs no Studio ainda faltam |
| `AbilityService` | comet resolve o fighter do dummy; `CombatHit` no acerto | Cadência/Pulso contra dummy (itens 8/10); unlock por missão (item 7) |
| `PlayerSessionService` | snapshot Ready na zona segura; intenções só após Ready | feito no domínio |
| `src/client/init.client.lua` | espera `SessionSnapshot`; não dispara no boot | InputController (item 12) |
| `SaveService` | stub em memória; persiste `wallet` | ProfileRoot v1 sem wallet; ProfileStore no place de teste |
| Mapa/HUD | ausentes | §8 e §12 |

Testes Lune: 49 casos em `tests/run.luau` (`docs/12-TESTING.md`).

**Comprovado neste recorte:** join → Ready → `comet_shoulder` gasta 18 Umbral, tira 9 HP do dummy (9991), sem Fluxo; guarda para o avanço (4 HP + 9 guarda); aparo e i-frame zeram o dano. **Não comprovado:** deslocamento espacial, overlap de hitbox, Studio, DataStore, mapa, HUD.

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

### 5.1 Ataque leve

Cadeia de 4 golpes: **5 + 5 + 6 + 10**. Janela para continuar: 0,65 s. O quarto golpe não gira 180° após o quadro de compromisso.

| Golpe | Startup | Active | Recovery | Hitbox | Stagger |
|---|---:|---:|---:|---|---|
| 1 | 160 ms | 90 ms | 220 ms | esfera 4 studs à frente | `stagger_light` 120 ms |
| 2 | 140 ms | 90 ms | 220 ms | esfera 4 studs | `stagger_light` 120 ms |
| 3 | 180 ms | 100 ms | 260 ms | esfera 4,5 studs | `stagger_light` 150 ms |
| 4 | 260 ms | 120 ms | 550 ms | cápsula 5×4×6 | `stagger_light` 220 ms |

Leve contra guarda: 40% do HP passa; guarda perde o dano cheio. Costas ignoram guarda.

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
| Golpe 1 | startup 140 ms, active 80 ms, dano 5 |
| Intervalo | 100 ms |
| Golpe 2 | active 80 ms, dano 6, recovery 280 ms |
| Hitbox | esfera 4,5 studs, máx. 1 alvo por golpe |
| Reentrada | 120 ms após o fim do active do golpe 2 |
| Eco | 350 ms depois, dano 4, mesma hitbox; não controla |
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
| Contra (se reduzir) | active 180 ms, dano 8, empurrão 8 studs, recovery 300 ms |
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

IDs persistidos, nunca CFrame cru: `anchor_bastion_spawn`, `anchor_bastion_return`, `anchor_training`, `anchor_gate_north`, `anchor_gate_west`, `anchor_elite`. Morte na planície respawna em `anchor_bastion_return`.

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
  progression.accountLevel          -- derivado; começa 1
  progression.consolidatedXp
  progression.unconsolidatedXp
  progression.lastConsolidationAt
  progression.tutorialFlags         -- conjunto de IDs conhecidos
  characters.eclipse_fist           -- unlockedAt
  abilities.{id}                    -- unlockedAt somente; sem masteryXp
  settings                          -- locale, redução de efeitos, esquema de input
  recentOperations                  -- anel ≤ 32 recibos
```

### 11.1 XP e consolidação

Fontes F0: Estilhaço 25, elite 80, objetivo 1 +40, objetivo elite +60, objetivo Fluxo +40. Teto de emissão por sessão: 800 não consolidado.

Consolidar: interagir 1,5 s com `anchor_bastion_return` fora de combate. Move todo `unconsolidatedXp` para `consolidatedXp`. Recibo `operationId` idempotente.

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

- PC: câmera livre; lock-on opcional (roda do mouse)
- Toque/gamepad: magnetismo 8° até 25 studs; some após compromisso e em área
- Soft lock só no ataque básico, não nas técnicas de deslocamento

### 12.2 HUD mínimo

| Elemento | Conteúdo | Regra |
|---|---|---|
| Vidas | HP + guarda | eventos; interpolar local ≤ 10 Hz |
| Umbral | valor / 100; ícone distinto **sem** depender só de cor | esgotado visível |
| Técnicas | 3 slots, cooldown radial, cadeado se locked | não mostra custo mentiroso |
| Zona | “SEGURO” / “PvP ATIVO” + perda resumida | persistente fora da vila |
| Objetivo | uma linha, máx. 48 caracteres | some ao completar |
| Feedback | hit confirm, guarda, rejeição (`no_resource`, `cooldown`) | 1 s; sem código interno |

Mobile: no máximo dois botões simultâneos. Técnicas em cluster direito; dash e guarda separados. Área de combate central sem HUD opaco > 20%.

### 12.3 Controllers a criar

Ordem: `InputController` → `CharacterController` → `AbilityController` → `CombatFeedbackController` → `ResourceController` → `ZoneController` → `UIController`. Sem `LoadoutController` nesta fatia.

Remover o `FireServer` de boot em `init.client.lua`.

## 13. Remotes da fatia

Envelope: `protocolVersion`, `requestId`, `clientSequence`, `action`, `payload`. Timestamp do cliente não autoriza.

| Contrato | Dir. | Payload aceito | Proibido do cliente |
|---|---|---|---|
| `SessionSnapshot` | S→C | zona, HP, guarda, Umbral, unlocks, objetivo | — |
| `StateDelta` | S→C | HP/guarda/recurso/cooldown/flags | — |
| `BasicAttackIntent` | C→S | `press`/`release`, `requestId` | alvo, dano |
| `GuardIntent` | C→S | `down`/`up` | “parry success” |
| `DashIntent` | C→S | direção unitária limitada | distância final |
| `AbilityIntent` | C→S | `abilityId`, `inputMode`, `executionId?`, `phase?`, ponto/alvo só se a def exigir | dano, vítimas, custo |
| `CombatEvent` | S→C | `executionId`, `abilityId`, hit/guarda/morte | fórmulas |
| `ZoneEvent` | S→C | de, para, regra PvP, instante | — |
| `InteractionIntent` | C→S | `anchorId` / `npcId` | recompensa |
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
| `quest.hunt.tracker` | Derrote Estilhaços: {n}/3 |
| `quest.elite.tracker` | Derrote o Estilhaço Ancorado |
| `quest.flow.tracker` | Acerte um eco da Cadência |
| `npc.threshold_instructor.name` | Instrutor do Limiar |

## 17. Arte e áudio da fatia

Permitido: parts, cores neutras, luz, UI retangular, som de beep, animação R15 genérica, VFX geométrico (anel, pulso, cone).

Proibido até P1: silhueta/roupa/cabelo reconhecíveis, VFX cromático de referência, áudio temático, ícones de franquia, nomes canônicos em textura.

Telegraph de perigo: contorno branco + ícone, não só vermelho. Mobile reduz partículas; mantém o contorno.

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

Cheat de unlock: remote **inexistente** no cliente. Flag `StudioDebugUnlock` só no servidor se `RunService:IsStudio()` e atributo do place `F0Debug = true`.

## 19. Testes da mudança de catálogo

Os casos abaixo estão em `tests/run.luau` (49 no total; fonte: chamadas `test(...)`):

- roster `eclipse_fist` com 3 skills enabled + 1 ultimate disabled
- `comet_shoulder` custo 18, CD 7, runner registrado
- ativação gasta 18, dano 9, recusa sem recurso / cooldown / morto
- comet no fighter dummy: 9 HP aberto; guarda para o avanço (4 HP + 9 guarda); aparo e i-frame zeram
- join Ready → comet gasta 18 e dummy fica em 9991 HP
- `broken_cadence` recusa reentrada fora da janela; Fluxo +6 no eco que acerta, respeita cap 1,5 s
- `pulse_return` sem golpe → não aplica contra
- `eclipse_beat` `enabled = false` → `disabled`
- catálogo: Umbral pool 100, regen combate 2
- flags de unlock: técnica locked rejeita `AbilityIntent`

Integração Lune não cobre Studio. Evidência runtime: `12-TESTING.md` §6.

## 20. Backlog priorizado

Ordem de implementação; cada item fecha com teste automatizado **ou** evidência Studio anotada.

1. ~~Alinhar catálogo, Umbral, testes Lune e CI~~ (feito 2026-08-12; 31 testes)
2. ~~Tirar `FireServer` do boot; `SessionSnapshot` mínimo~~ (feito 2026-08-12; domínio + remote)
3. ~~Spawn + movimento + leve/guarda/dash contra dummy~~ (domínio headless 2026-08-12; movimento/Studio pendente)
4. ~~Pesado + quebra de guarda~~ (feito 2026-08-12; 43 testes)
5. ~~Ombro Cometa~~ (feito 2026-08-12; 49 testes; domínio headless — lunge espacial no Studio pendente)
6. Greybox + `ZoneService` + 5 sinais
7. Estilhaços + objetivo 1 + unlock Cometa
8. Cadência + Fluxo
9. Elite + unlock Cadência
10. Pulso + objetivo 45–60 min
11. Consolidação + morte + ProfileStore
12. HUD/input mobile e gamepad
13. Telemetria + rejeição adversarial de remotes
14. Playtest interno 20 min (PC, um Android, um gamepad)

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

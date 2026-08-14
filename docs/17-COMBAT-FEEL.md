# 17 — Game-feel de combate corpo a corpo

> **Status em 2026-08-13:** polimento procedural da apresentação de combate
> implementado e testado em headless. **Nenhum asset foi criado** — continua
> valendo o pipeline de clipes de `docs/14-ANIMATION-PLAN.md`; este documento
> cobre apenas o que foi melhorado na camada procedural já existente.

## 1. O problema

A fundação procedural (`PlayerCombatAnimator`, `ActorAnimator`) resolvia os
estados e as silhuetas, mas o arco de cada golpe lia "chapado": toda fase usava
a mesma interpolação (smoothstep), o retorno parava no impacto sem continuar o
movimento, o neutro era um boneco congelado, o punho não fechava no contato e o
acerto confirmado não tinha resposta de câmera nem de peso. Tudo isso é
apresentação local — o servidor continuou 100% autoritativo.

## 2. O que mudou

### 2.1 Easing por fase (`PlayerCombatAnimator`)

- Antecipação usa `easeInCubic` — o corpo "enrola" e acelera até a pose armada.
- Golpe usa `easeOutCubic` — o membro estala do armado para o impacto.
- Retorno mantém `easeOutBack` — assenta com overshoot, sem resíduo entre golpes.

Como `easeIn/easeOut(0)=0` e `(1)=1`, as poses nas fronteiras de fase não
mudaram: todos os testes de silhueta/neutro existentes continuam verdes.

### 2.2 Follow-through

Depois da pausa de impacto, a pose continua **além** do ponto de contato
(`FOLLOW_THROUGH = 0.14` sobre a pose de impacto) durante a primeira fatia da
recuperação (`FOLLOW_WINDOW = 0.32`), e só então o `easeOutBack` assenta em
neutro. `easeOutBack(1) == 1` garante o neutro exato no fim — nenhum golpe
deixa resíduo.

### 2.3 Idle de combate vivo

Quando não há ação em curso, o neutro/guarda recebem uma micro-respiração
(`sin` de baixa frequência sobre tronco/ombros). Com relógio `nil`, a pose
base permanece canônica — a guarda não muda de silhueta.

### 2.4 Wrist snap

O `PoseSample` ganhou `leftWristPitchDegrees`/`rightWristPitchDegrees`.
Socos flexionam o punho no impacto (jab/direto/pesado/Cometa/Cadência); chutes
não mexem o punho. R15 tem o Motor6D de punho; R6 não — o overlay é ignorado e o
resto da pose permanece legível.

### 2.5 Hit-stop visual

`PlayerCombatAnimator.confirmHit(animator, outcome)` congela a pose por
70 ms (hit), 110 ms (death), 35 ms (guard) ou 90 ms (counter). O congelamento só
acontece no desfecho **confirmado** pelo servidor, nunca na intenção local — o
mesmo contrato do áudio de impacto (`16-COMBAT-AUDIO.md` §3.1).

> Recalibrado em 14/08. Os valores anteriores (40/60/20 ms) são 2,4 quadros a
> 60 fps no acerto: curto demais para o olho separar "bateu" de "passou perto".
> Continua curto de propósito — hit-stop longo faz a cadeia leve travar.

### 2.6 Câmera de impacto (`CombatCameraController`)

Módulo de apresentação local:

- **shake** com curva `trauma^1,4` (mantém a ordem entre desfechos sem zerar o
  degrau de baixo);
- **FOV punch** curto que decai com o tempo;
- perfis por desfecho (`hit`/`death`/`guard`/`counter`) e reforço para técnicas
  pesadas (`comet_shoulder`, `broken_cadence`, `eclipse_beat`).

> A curva era **quadrática** e o resultado era invisível: com trauma 0,35, o
> acerto comum — o golpe que o jogador mais dá — rendia 0,24° e 0,037 stud por
> 0,13 s. "Impacto pequeno quase não mexe" é a intenção certa, mas o acerto
> comum era o caso pequeno da própria curva. Tabela dos valores em vigor em
> `docs/14` §6; o piso do que precisa ser sentido está travado por teste.

Baselines de `docs/14` §6 respeitadas: shake limitado a 3,2° e 0,45 stud,
sempre local. Nunca altera a mira autoritativa nem a câmera de outro jogador.

### 2.6.1 Luz de impacto

Até 14/08 o kit não acendia nenhuma luz: a camada de VFX materializava
`ParticleEmitter`, `Trail` e `Part`, e zero `PointLight`. Partícula com
`LightEmission` **brilha mas não ilumina** — nada do combate projetava luz no
chão nem no oponente. Cada camada agora declara `glowStuds` derivado do próprio
raio (`AbilityVfx.GlowByKind`), e o `PointLight` segue a mesma envoltória das
partículas. Sem sombra dinâmica, de propósito: o custo aparece antes da leitura
num combate com vários lutadores.

### 2.7 Pacote VFX do Ombro Cometa (estilo battlegrounds)

O golpe-modelo ganhou uma leitura completa de "golpe pesado de anime", toda
procedural e dirigida por dados em `AbilityVfx.luau` (13/08):

- **Aura de carga no peito** (`comet_aura`): a esfera de energia concentra
  durante o startup (0–0,20 s) junto da carga no ombro — o "power-up" antes do
  avanço, sem confirmação (é telegrafia, não acerto);
- **Flash branco-violeta** (`comet_flash`) + **onda de choque no chão**
  (`comet_ring`, até 5,5 studs) nascendo no instante autoritativo do impacto
  (0,40 s) — ambos `requiresConfirmation`, só com desfecho do servidor;
- **Rastro mais longo** (`comet_trail`, 4,2 studs) durante o avanço;
- **Poses mais pesadas**: coil mais enrolado (joelho −52°, cotovelo colado às
  costelas −124°) e drive mais baixo e varrido (ombro −130°, pitch 38°);
- **Câmera**: o Cometa é a única técnica com perfil próprio de impacto
  (trauma 0,6 + FOV 2,85 no acerto confirmado).

Regras de honestidade visual intactas: nenhum raio passa do alcance (8 studs),
nenhum efeito de acerto acende sem `CombatEvent`, nada sobrevive à duração da
ação. Continua scaffolding procedural — não conta como clip do gate A1.


### 2.8 HUD de combate: números de dano e barras dos inimigos

`CombatHudController.luau` (cliente, 13/08) desenha o resultado dos golpes:

- **Número de dano flutuante** no alvo (BillboardGui, sobe e some em 0,8 s):
  só com `damage > 0` num `CombatEvent` — desfecho autoritativo, nunca
  intenção local. Cores: acerto branco, guarda azul (dano reduzido), contra
  âmbar, morte vermelho.
- **Barra de vida dos inimigos** acima do modelo: alimentada por
  `StateDelta {fighterId, health, maxHealth}` que o servidor envia ao jogador
  que causou o dano; muda de cor abaixo de 50%/25% e some com fade na morte.

Para isso o `CombatEvent` do atacante passou a carregar `damage` e o
`fireVitalsForFighter` ganhou o caminho NPC → atacante (antes só o jogador
recebia vitals).

### 2.9 Balanceamento da primeira passada (13/08)

| Golpe | Antes | Depois |
|---|---:|---:|
| Cadeia leve (jab/direto/chute/finalizador) | 5/5/6/10 | 6/6/8/12 |
| Pesado | 10 | 12 |
| Ombro Cometa | 9 | 14 |
| Cadência (golpe 1 / golpe 2 / eco) | 5/6/4 | 7/9/6 |
| Contra do Pulso | 8 | 10 |
| Estilhaço Errante (vida / dano) | 40 / 6 | 60 / 8 |
| Estilhaço Ancorado (vida / slam / combo) | 80 / 12 / 5+5 | 120 / 14 / 6+6 |
| Dummy (dano) | 4 | 5 |

O jogador continua com 100 de vida (baseHealth do catálogo); a subida do dano
foi compensada na vida dos inimigos para manter o tempo de kill parecido, com
mais peso por golpe. Baselines do `CatalogService` e testes atualizados.


## 3. Regra de autoridade preservada

| Camada | Dispara com | Nunca |
|---|---|---|
| Easing/follow-through/idle/wrist | intenção local (ação do jogador) | decidir acerto/dano |
| Hit-stop | `CombatEvent` (desfecho do servidor) | congelar na intenção |
| Shake/FOV | `CombatEvent` (desfecho do servidor) | tremer sem confirmação |

O bootstrap (`src/client/init.client.lua`) conecta `CombatEvent` a
`confirmHit` + `addImpact`, ao lado do áudio de impacto já existente.

O golpe básico agora emite `damage` no `CombatEvent` e o `StateDelta` da vida
do NPC para o atacante. Sem isso o HUD (`shouldShowDamage` exige `damage > 0`)
e a barra do inimigo ficavam mudos mesmo no acerto — o playtest de 13/08 leu
como "golpe morto" (`docs/18-ANALISE-VIDEO.md`).

O tremor da câmera desliga no menu **MENU → Tremor da câmera** (`shakeEnabled`);
é só apresentação local, não muda dano nem hitbox.

## 4. Cobertura

Novos testes em `tests/animation.luau` (executado pelo CI junto de
`tests/run.luau`):

- follow-through ultrapassa a pose de impacto e ainda assenta em neutro exato;
- idle respira e preserva a guarda canônica sem relógio;
- soco flexiona o punho, chute não;
- hit-stop só congela no desfecho confirmado e descongela após a janela;
- trauma decai/clampa e técnica pesada sacode mais;
- `addImpact` clampa trauma/fov no teto e decai no tick;
- VFX do Cometa: aura acesa na carga sem confirmação; flash e onda só com
  desfecho; ambos nascem logo após o impacto autoritativo (0,42 s); nenhum raio
  passa do alcance da habilidade.

## 5. Fora de escopo (ainda pendente)

- Clipes reais com keyframe/animação R15 (Gate A1, depende de P1 + arte).
- Stagger/hit reaction dos NPCs (exige um `kind="hit"` no `EnemyEvent` —
  mudança no servidor, não nesta rodada).
- Root motion de avanço (o `SpatialService` continua dono da posição).
- Squash & stretch (Motor6D não escala).
- Flag global de acessibilidade "reduzir efeitos" (shake/flash desligáveis) —
  follow-up recomendado antes do playtest público.

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
40 ms (hit), 60 ms (death) ou 20 ms (guard). O congelamento só acontece no
desfecho **confirmado** pelo servidor, nunca na intenção local — o mesmo
contrato do áudio de impacto (`16-COMBAT-AUDIO.md` §3.1).

### 2.6 Câmera de impacto (`CombatCameraController`)

Novo módulo de apresentação local:

- **shake** com curva quadrática de trauma (impactos pequenos quase não mexem);
- **FOV punch** curto que decai com o tempo;
- perfis por desfecho (`hit`/ `death`/ `guard`) e reforço para técnicas
  pesadas (`comet_shoulder`, `broken_cadence`, `eclipse_beat`).

Baselines de `docs/14` §6 respeitadas: shake limitado a 2° e 0,3 stud, sempre
local. Nunca altera a mira autoritativa nem a câmera de outro jogador.

## 3. Regra de autoridade preservada

| Camada | Dispara com | Nunca |
|---|---|---|
| Easing/follow-through/idle/wrist | intenção local (ação do jogador) | decidir acerto/dano |
| Hit-stop | `CombatEvent` (desfecho do servidor) | congelar na intenção |
| Shake/FOV | `CombatEvent` (desfecho do servidor) | tremer sem confirmação |

O bootstrap (`src/client/init.client.lua`) conecta `CombatEvent` a
`confirmHit` + `addImpact`, ao lado do áudio de impacto já existente.

## 4. Cobertura

Novos testes em `tests/animation.luau` (executado pelo CI junto de
`tests/run.luau`):

- follow-through ultrapassa a pose de impacto e ainda assenta em neutro exato;
- idle respira e preserva a guarda canônica sem relógio;
- soco flexiona o punho, chute não;
- hit-stop só congela no desfecho confirmado e descongela após a janela;
- trauma decai/clampa e técnica pesada sacode mais;
- `addImpact` clampa trauma/fov no teto e decai no tick.

## 5. Fora de escopo (ainda pendente)

- Clipes reais com keyframe/animação R15 (Gate A1, depende de P1 + arte).
- Stagger/hit reaction dos NPCs (exige um `kind="hit"` no `EnemyEvent` —
  mudança no servidor, não nesta rodada).
- Root motion de avanço (o `SpatialService` continua dono da posição).
- Squash & stretch (Motor6D não escala).
- Flag global de acessibilidade "reduzir efeitos" (shake/flash desligáveis) —
  follow-up recomendado antes do playtest público.

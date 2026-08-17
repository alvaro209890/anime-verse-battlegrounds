# 16 — Áudio de combate

> **Status em 2026-08-13:** catálogo, player e integração implementados e testados. **Nenhum som toca ainda**: os 29 arquivos `.ogg` precisam ser publicados no Roblox e ter seus IDs preenchidos. Enquanto isso, cada deixa é ignorada em silêncio — o jogo funciona normalmente, apenas mudo.

## 1. A restrição que define todo o desenho

**O Roblox não reproduz arquivo local.** `Sound.SoundId` aceita apenas `rbxassetid://<id>` de um asset publicado na conta ou grupo dono da experiência. O Rojo sincroniza código e instâncias, não binário de áudio: um `.ogg` no repositório nunca vira som tocável por sincronização.

Isso divide o trabalho em duas metades com donos diferentes:

| Metade | Quem faz | Estado |
|---|---|---|
| Catálogo, player, integração, testes | agente / código | **pronto** |
| Upload dos `.ogg` e preenchimento de `assetId` | humano com acesso à conta/grupo | **pendente** |

O código foi escrito para que a segunda metade seja mecânica: `assetId` vazio é estado válido e silencioso, nunca erro.

## 2. Origem e licença dos arquivos

396 arquivos de quatro packs do [Kenney.nl](https://kenney.nl/assets), todos em **CC0 (domínio público)** — uso comercial, modificação e redistribuição livres, atribuição não obrigatória. Detalhes e links originais em `assets/audio/README.md`; cada pack mantém seu `License.txt`.

CC0 é domínio público declarado, não material derivativo — está de acordo com o princípio de conteúdo original de `06-ROADMAP.md` §1. **Áudio CC0 não passa pelos gates P1–P3 de originalidade**, que existem para fantasia e identidade visual/sonora *autoral derivada de referência*. Um som de impacto genérico não carrega identidade de franquia.

## 3. Arquitetura

Três peças, uma responsabilidade cada:

```
src/shared/Data/CombatAudio.luau          catálogo (dados)
src/client/Presentation/CombatAudioPlayer.luau   reprodução
src/client/Presentation/PlayerCombatAnimator.luau  agendamento das deixas
```

**O catálogo é dado, não código.** Adicionar ou trocar um som é editar uma tabela — nenhum sistema ganha ramificação por nome de deixa. Mesmo contrato dos catálogos de `Abilities.luau` e `Characters.luau`: `get`, `all`, `validate`.

Cada deixa declara arquivo de origem (rastreabilidade), variantes, volume, faixa de pitch e alcance. `sourceFile` aponta o `.ogg` CC0 correspondente para que o upload seja conferível e a troca de som não exija caçar o binário.

### 3.1 Regra de autoridade

A regra de `14-ANIMATION-PLAN.md` §5 vale integralmente para som:

| Deixa | Dispara com | Nunca |
|---|---|---|
| Corte de ar (`swing_*`) | intenção local do jogador | representar acerto |
| Impacto (`impact_*`) | contato previsto no cone local, ou `CombatEvent` se a previsão não tocou | autorizar HP ou número de dano |

O corte de ar é a *ação* — é do jogador e sempre acontece, mesmo errando. O
impacto é *contato*: desde 17/08 (`docs/17` §2.11) ele pode sair no instante
da antecipação quando o cone local viu alguém, para o soco no outro jogador
não esperar o RTT. Um `CombatEvent` na mesma janela não toca de novo. HP e
número de dano continuam só no servidor — ouvir o thump sem número é um
flash fantasma aceito; ver vida cair sem thump era o defeito do R1.

`impact_guard` é deliberadamente metálico e distinto de `impact_light`/`impact_heavy`: a diferença entre acertar e ser bloqueado precisa ser audível sem olhar o HUD.

### 3.2 Por que o som não sai idêntico duas vezes

Duas camadas de variação, porque combate repete muito:

1. **Variantes** — o Kenney fornece 5 gravações por impacto; o catálogo lista todas.
2. **Pitch sorteado** por reprodução, dentro de faixa declarada por deixa.

Além disso, cada degrau da cadeia leve tem corte de ar próprio, com pitch decrescente do jab ao finalizador: o som acompanha o peso crescente da animação.

### 3.3 Detalhes que evitam bug conhecido

- **Debounce de 40 ms por deixa** — dois eventos no mesmo frame empilhavam e dobravam o volume do impacto.
- **Limpeza no `Ended`** — sem isso cada golpe deixaria uma `Instance` órfã para sempre.
- **Sem dependência de `Random`** — o player usa `math.random` por padrão; `Random` é global do Roblox e quebraria o teste headless. Um gerador próprio pode ser injetado.
- **Áudio antes do early-return no `step`** — perder o corte de ar por um frame sem rig anexado seria audível.

## 4. Mapa de deixas

13 deixas, 29 arquivos distintos.

| Deixa | Momento | Origem |
|---|---|---|
| `swing_light_1` | jab, fim da antecipação (0,065 s) | `rpg-audio/cloth1-2` |
| `swing_light_2` | direto (0,070 s) | `rpg-audio/cloth3-4` |
| `swing_light_3` | chute circular (0,110 s) | `rpg-audio/clothBelt*` |
| `swing_light_4` | finalizador giratório (0,135 s) | `rpg-audio/chop` |
| `swing_heavy` | ataque pesado (0,170 s) | `rpg-audio/clothBelt`, `chop` |
| `impact_light` | acerto leve confirmado | `impact-sounds/impactPunch_medium_*` (5) |
| `impact_heavy` | acerto pesado confirmado | `impact-sounds/impactPunch_heavy_*` (5) |
| `impact_guard` | golpe parado na guarda | `impact-sounds/impactPlate_*` (4) |
| `ability_comet_shoulder` | Ombro Cometa (0,150 s) | `sci-fi-sounds/thrusterFire_*` |
| `ability_broken_cadence` | Cadência Quebrada (0,080 s) | `sci-fi-sounds/laserSmall_*` |
| `ability_pulse_return` | Retorno de Pulso (0,100 s) | `sci-fi-sounds/forceField_*` |
| `dash` | dash, imediato | `sci-fi-sounds/spaceEngineSmall_*` |
| `guard_raise` | entrada em guarda | `rpg-audio/cloth1` |

O corte de ar soa quando a **antecipação termina**, não no instante do input: é quando o membro acelera. Tocar no input adianta o som em até 135 ms e desalinha da imagem.

### 4.1 Duplicação consciente de ids

`PlayerCombatAnimator` declara os ids das deixas localmente em vez de requerer `CombatAudio`. É proposital: o animador é apresentação pura e precisa carregar em teste headless sem `DataModel`. O risco de divergência é coberto por teste — `áudio: toda deixa emitida pelo animador existe no catálogo` quebra se um lado mudar sozinho, em vez de o jogo ficar mudo silenciosamente.

## 5. Como publicar os sons

```bash
lune run scripts/audio-manifest.luau
```

Lista cada deixa, seu status (`PENDENTE`/`publicado`) e os arquivos de origem, e falha se algum `.ogg` referenciado sumiu do disco.

Passos:

1. Publicar os 29 `.ogg` no Roblox (Creator Dashboard → Audio, ou a Assets API do Open Cloud para automatizar em lote).
2. Preencher `assetId` em `src/shared/Data/CombatAudio.luau` no formato `rbxassetid://<id>`.
3. Rodar `lune run tests/animation.luau` e o manifesto de novo.

Áudio publicado no Roblox passa por moderação e pode levar minutos. Som CC0 do Kenney não costuma ter problema, mas a rejeição é possível — por isso `assetId` vazio é estado suportado e não bloqueia o build.

**Limite conhecido:** o catálogo hoje guarda um `assetId` por deixa, não por variante. Publicadas as 5 gravações de `impactPunch_medium`, apenas uma é usada. A variação atual vem do pitch. Suportar um id por variante é mudança pequena no catálogo e no `resolve`, e deve ser feita **depois** do upload, quando os ids reais existirem.

## 5.1 Kit placeholder do Roblox — combate saiu do mudo (13/08, 15h)

O upload dos `.ogg` CC0 continua pendente e depende de uma conta com acesso ao
Creator Dashboard. Até lá, cada deixa aponta para um áudio do **criador Roblox
(userId 1)**, que qualquer experiência toca sem upload, sem compra e sem
moderação pendente. Verificados em 2026-08-13 via
`economy.roblox.com/v2/assets/<id>/details` (Creator.Id 1, AssetTypeId 3):

| Papel sonoro | Asset | Deixas |
|---|---|---|
| corte de espada | `12222216` swordslash.wav | `swing_light_1..4`, `ability_broken_cadence`, `ability_cadence_echo` |
| avanço pesado | `12222208` swordlunge.wav | `swing_heavy` |
| metal / postura | `12222225` unsheath.wav | `impact_guard`, `ability_pulse_return`, `guard_raise` |
| deslocamento | `12222095` Rocket whoosh 01.wav | `dash`, `ability_comet_shoulder` |
| impacto em corpo | `12222152` splat.wav | `impact_light`, `impact_heavy` |
| estilhaçar | `12222005` glassbreak.wav | `ability_pulse_counter` |

O que **não** mudou: `sourceFile` continua apontando o `.ogg` CC0 que é o som
final pretendido, `assetId` vazio segue sendo estado válido e silencioso, e a
variação por reprodução continua vindo do pitch. Um teste novo
(`áudio: todo o catálogo aponta para um asset tocável`) impede que uma deixa
nova volte a nascer muda sem ninguém perceber.

Limite honesto: um som de espada não é o som do Punho do Eclipse. É o
suficiente para julgar timing, mixagem relativa e a diferença audível entre
acerto e bloqueio — que era o que faltava para o combate ter peso.

## 6. Verificação

`tests/animation.luau` — 19 testes, incluindo 9 de áudio:

- catálogo passa `validate` (volume 0–1, pitch coerente, alcance positivo);
- todo `sourceFile` referenciado existe no disco;
- toda deixa emitida pelo animador existe no catálogo;
- cada degrau da cadeia tem corte de ar próprio;
- impacto depende do desfecho autoritativo — `nil`, `"miss"` e ausência de desfecho não soam como acerto;
- deixa sem upload devolve `nil` sem erro;
- com `assetId` publicado, o pitch cai dentro da faixa declarada;
- o animador agenda o corte de ar para o fim da antecipação e não repete;
- animador sem `emitCue` continua animando em silêncio.

Fica **fora** do que os testes cobrem: se o som é agradável, se o volume relativo está equilibrado e se a mixagem funciona no celular. Isso exige ouvir no Studio depois do upload.

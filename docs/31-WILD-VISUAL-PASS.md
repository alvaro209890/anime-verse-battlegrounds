# 31 — Reforma visual do mundo aberto e das skins de inimigo

## Estado e objetivo — 2026-08-15

Esta rodada continua a reforma que `docs/28-SPAWN-VISUAL-PASS.md` fez na sala de
spawn e a leva para fora do Bastião, fecha os próximos passos estruturais que
`docs/22-SCENERY-EXPANSION.md` deixou escritos, tira a última decisão de
apresentação que ainda morava dentro do `WorldService` e liga os sinais de
fronteira que o servidor já emitia e o cliente ignorava.

**Nada aqui muda regra de jogo.** Zona, âncora, hitbox, alcance, dano, custo,
cooldown, spawn, respawn, XP e autoridade do servidor continuam exatamente como
estavam. Todas as mudanças são catálogo de dados + materialização.

> **Estado:** código, testes headless, Selene, StyLua e build Rojo aprovados.
> **Não houve Play no Roblox Studio neste snapshot.** Aparência real,
> iluminação, clipping, z-fighting e desempenho continuam pendentes de W1
> (`docs/15-WORLD-PRESENTATION.md`).

## 1. Skins de Estilhaço viram dados

O corpo mineral dos dois inimigos era construído dentro do `WorldService`,
incluindo um `if npcId == "enemy_anchored_shard"` para montar a coroa do elite.
Isso contraria a regra de manutenção de `docs/13 §2` ("se o `WorldService`
precisar de um `if` de gameplay, o `if` está no lugar errado"): a camada que só
deveria traduzir dados em Parts estava decidindo aparência.

A receita agora é dado puro em `WorldPresentation.shardGearFor(npcId)` — corpo
comum mais peças exclusivas por NPC — e o `WorldService` itera.

| NPC | Peças | O que entrou nesta rodada |
|---|---:|---|
| `enemy_wandering_shard` (Fenda Ciano) | 13 | Casca mineral arredondando o volume, halo suave do núcleo, anel de fenda em volta do núcleo e duas lascas soltas |
| `enemy_anchored_shard` (Coroa do Vazio) | 23 | Manto, colar de ancoragem em basalto com quatro cravos, coroa de três para cinco pontas de alturas alternadas e núcleo de coroa |

### Honestidade visual travada por teste

`WorldPresentation.validateShardSkins(npcs)` recusa qualquer skin que ocupe, no
plano horizontal, mais studs do que o `attackRange` real do NPC — o mesmo número
que o `EnemyVfxPlayer.rangeFor` usa para a luz de ataque desde 14/08. Um inimigo
que parece alcançar mais do que alcança ensina o jogador a recuar de menos.

| NPC | Skin ocupa | Golpe alcança |
|---|---:|---:|
| `enemy_wandering_shard` | 2,43 studs | 4,00 studs |
| `enemy_anchored_shard` | 4,46 studs | 8,00 studs |

O limite é conservador de propósito: usa a maior dimensão da peça como raio,
então qualquer rotação continua coberta. O bootstrap do servidor aplica a regra
em fail-fast, junto das outras validações de catálogo.

Junto disso foi corrigido um defeito que a transparência declarada na receita
criaria: `setActorVisible` devolvia toda peça a `Transparency = 0` ao reaparecer,
o que apagaria o halo do núcleo no primeiro respawn. A peça agora guarda
`AvbBaseTransparency` e volta ao valor dela.

## 2. Decoração da planície, das rotas e da cratera

Até aqui só o Bastião tinha decoração dirigida por dados
(`SpawnDecorations.luau`). Fora dele havia terreno, rochas e tufos de grama
distribuídos por índice — quem saía pelos portões não tinha nenhuma leitura de
para onde ir. O novo `src/shared/Data/WildDecorations.luau` fecha a sequência
recomendada em `docs/22`: caminho norte e portão, corredor oeste e planície ao
redor da cratera.

| Área | Conteúdo | Função |
|---|---|---|
| Rota norte | 4 pares de postes de fogo em `x ±6,5`, parando antes do aro da cratera | "Siga em frente" que o Portão Norte promete |
| Corredor oeste | 4 postes desenhando a curva + marco inclinado com núcleo umbral | O muro em L quebra a linha de visão de propósito (§8.1); sem marcação o jogador não sabe que o caminho vira ao norte |
| Borda da cratera | 6 postes altos FORA do aro (raio 23,5) | Cratera visível da metade da rota; o par de 60°/120° emoldura a entrada |
| Formações de Estilhaço | 3 lascas em volta de cada uma das 6 âncoras, centro livre | Ensina onde caçar sem escrever nada na tela |

Total original (15/08): **80 peças e 7 fontes de luz**. Em 17/08 a vegetação da
planície passou de sorteio uniforme para bosques com espaçamento mínimo +
sub-bosque (grama, samambaia, tronco caído, flor). As tochas da rota
permanecem 7 luzes. O gate headless agora exige ≥ 400 peças e ≤ 2800.

### O que a validação pura trava

Estas não são preferências de estilo; quebrar qualquer uma quebra o jogo, e por
isso são gate e não comentário:

1. **Nada colide.** Poste no meio da planície viraria parede invisível em cima
   de perseguição, dash e Ombro Cometa. O teste lê a materialização do
   `WorldService` e exige `CanCollide = false` e `CanQuery = false`.
2. **Nada entra no ringue do elite** (raio 20 em torno de `anchor_elite`) nem na
   faixa de caminhada de 8 studs da rota da cratera.
3. **Nada encosta numa âncora de Estilhaço** (folga mínima de 3 studs, borda a
   borda): o inimigo nasce ali.
4. **Tudo cabe dentro de um volume da zona livre** e **nenhum volume de
   transição é invadido**: os dois portões continuam limpos.
5. **Teto de 8 fontes de luz** na planície, cada uma com brilho ≤ 3 e alcance
   entre 8 e 24 studs.

Honestidade visual: nenhuma peça desenha anel ou área no chão que possa ser lida
como alcance de golpe. Luz de tocha é ambiente, nunca telegraph.

As posições das âncoras aparecem duas vezes (em `Zones.luau` e no catálogo de
decoração) de propósito — o módulo de dados não depende de runtime. O teste
valida a decoração contra as âncoras **reais** do `Zones`, então mover uma âncora
lá quebra o gate aqui em vez de deixar a formação órfã no meio do campo.

## 3. Iluminação do spawn dirigida por dados

As seis posições de luz da sala estavam escritas dentro do `WorldService`. Agora
são catálogo (`SceneryPresentation.spawnLights()`), com nome, tom
(chave/preenchimento) e sombra por fonte.

| Mudança | Antes | Agora | Motivo |
|---|---|---|---|
| Fontes | 6 | 8 | Faltava luz sobre a Instrutora e sobre o pad de treino — os dois alvos dos primeiros 60 s do roteiro (`docs/13 §10`) ficavam no escuro |
| Sombras | 4 fontes | 2 fontes | Sombra de `PointLight` é o item mais caro da sala no Android e nenhuma das quatro definia a leitura do espaço |

A validação recusa luz fora do bastião, acima do teto de vidro (`Y = 22`), com
tom desconhecido, com nome repetido, em quantidade diferente do orçamento
declarado ou com mais de duas sombras. O teste headless também exige que exista
uma fonte a até 6 studs de `anchor_instructor` e de `anchor_training`.

## 4. Skins dos dois bots do spawn

Os dois rigs estavam resolvidos de frente e lisos de perfil e de costas — um
boneco assim vira papelão quando a câmera gira.

| Rig | Antes | Agora | O que entrou |
|---|---:|---:|---|
| Instrutora do Limiar | 38 peças | 44 | Laço de cabelo, nó e ponta de cachecol, bolsa de quadril, joelheiras |
| Boneco de Treino | 34 peças | 39 | Argola de suspensão (explica por que ele fica em pé), palha na cintura repetindo a da cabeça, remendo de joelho |

Nenhuma peça nova avança na frente do plano do rosto — `gearClearsFace` continua
travando isso — e a proporção anti-caixa segue em **zero** peça `Block` em Part
nos dois rigs. Teste novo exige volume lateral, de costas e nas pernas em ambos.

## 5. Os cinco sinais da fronteira PvP

O `ZoneService` emite os cinco sinais de `docs/02 §4.2` no `ZoneEvent` desde o
item 6 do backlog, mas só dois tinham apresentação: o portão físico (parts do
`WorldService`) e a faixa de UI. `lighting_material`, `audio_haptic` e
`persistent_indicator` eram string no payload e nada na tela.

Isso importa porque a fronteira é experimento obrigatório da F0: *"pelo menos
90% percebem que o PvP será ativado antes de poderem sofrer dano"*
(`docs/06 §5`). Um aviso que existe só no payload não passa nesse teste cego.

`src/client/Presentation/ZoneSignalPlayer.luau` (apresentação local):

| Sinal | Apresentação |
|---|---|
| `physical_gate` | Já existia: portões, vigas e postes de fronteira do `WorldService` |
| `ui_banner` | Já existia: faixa do `UIController`, que lê `state.pvp` do servidor |
| `persistent_indicator` | Já existia: a mesma faixa permanece enquanto a zona for livre |
| `lighting_material` | **Novo**: pulso curto de `ColorCorrection` — âmbar ao entrar na livre, ciano frio ao voltar para a segura |
| `audio_haptic` | **Novo**: vibração de 0,18 s, protegida por `pcall` (plataforma sem `HapticService` não pode derrubar a travessia) |

### Regras de honestidade, que são o ponto do módulo

- O plano só nasce de `ZoneEvent` **aceito**. `hold_required` e `combat_lockout`
  devolvem `nil`: nada foi atravessado, nada acende. Pintar a tela numa recusa
  ensinaria ao jogador que ele cruzou.
- Só apresenta com os **cinco** sinais no payload; conjunto incompleto é
  recusado.
- `pvp` vem do servidor, nunca da geometria do cliente.
- O pulso é fraco (0,22) e curto (0,9 s), com envelope puro e testado para não
  ficar preso aceso. Tinta forte e permanente viraria leitura de dano recebido,
  e mobile precisa reduzir efeito, não sofrer com ele (`docs/13 §17`).

## 6. Validação headless desta rodada

| Gate | Resultado |
|---|---|
| `tests/run.luau` (domínio) | 235 passaram, 0 falharam |
| `tests/animation.luau` (animação/apresentação) | 73 passaram, 0 falharam |
| `tests/security_fuzz.luau` | 29 passaram, 0 falharam |
| Total automatizado | 337 casos (era o número desta rodada; ver `docs/32` para o estado atual) |
| Selene | 0 erros, 0 warnings, 0 parse errors |
| StyLua | passou (`--check` limpo em `src tests plugins scripts`) |
| Rojo | build aprovado, 318.988 bytes |
| SHA-256 do artefato | `bc6b5056f238787ce2e857f835a1486b193f4f08db7a38bdccb4878d7f83bff4` |
| `git diff --check` | passou |

Casos adicionados nesta rodada: 8 no domínio (skins de estilhaço, alcance
honesto, peça malformada, materialização por dados, e os quatro da planície,
incluindo os negativos de zona, ringue, âncora e rota) e 6 na
animação/apresentação (fronteira aceita/recusada/envelope/bootstrap, luz de
spawn e volume dos rigs).

## 7. Limites e próximo gate

A validação headless prova contrato, invariante puro e árvore de build. Ela
**não** prova nada do que segue, que continua sendo W1 no Studio:

- se os postes ficam na altura certa e se a chama não estoura em Neon;
- se o pulso de fronteira é perceptível sem ser desconfortável, e se ele é
  suficiente para o teste cego dos 90%;
- se as oito luzes do spawn não escurecem ou estouram o rosto da Instrutora;
- se o corpo novo do elite causa clipping com a coroa ou com o aro da cratera;
- z-fighting entre decoração e piso da planície;
- desempenho no Android com as 80 peças e as 7 luzes novas da planície, mais as
  duas sombras da sala.

Em dispositivo de entrada, a ordem de corte continua sendo sombra e partícula
antes de leitura cromática ou densidade de decoração.

## Referências relacionadas

- [`docs/13-F0-SLICE.md`](13-F0-SLICE.md) §8.1, §8.2, §9, §17
- [`docs/15-WORLD-PRESENTATION.md`](15-WORLD-PRESENTATION.md)
- [`docs/17-COMBAT-FEEL.md`](17-COMBAT-FEEL.md) — honestidade visual
- [`docs/21-MONSTER-SKINS-ABILITIES.md`](21-MONSTER-SKINS-ABILITIES.md)
- [`docs/22-SCENERY-EXPANSION.md`](22-SCENERY-EXPANSION.md)
- [`docs/28-SPAWN-VISUAL-PASS.md`](28-SPAWN-VISUAL-PASS.md)
- [`src/shared/Data/WildDecorations.luau`](../src/shared/Data/WildDecorations.luau)
- [`src/shared/Data/WorldPresentation.luau`](../src/shared/Data/WorldPresentation.luau)
- [`src/shared/Data/SceneryPresentation.luau`](../src/shared/Data/SceneryPresentation.luau)
- [`src/client/Presentation/ZoneSignalPlayer.luau`](../src/client/Presentation/ZoneSignalPlayer.luau)

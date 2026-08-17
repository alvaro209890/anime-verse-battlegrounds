# Snapshot Canônico da Documentação — 17/08/2026

## Rodada de 17/08 (Hermes-server) — pesado básico agora sacode de verdade

Achado em aberto do runbook (`docs/32` §6, simulação de 15/08): o perfil de
câmera era escolhido por **desfecho** e `HEAVY_ABILITIES` só listava técnicas,
então o pesado básico chegava como `abilityId = "heavy"` e recebia o mesmo
trauma do jab, apesar de causar o dobro de dano (12 vs 6) e ser a ferramenta
de quebra de guarda. O teste fixava a igualdade por decisão explícita (mudar
feel sem Play era palpite — lição de `docs/14` §4.8).

**Decisão do Álvaro no playtest W1/A1 de 17/08:** o pesado está leve demais.
`heavy = true` entrou em `HEAVY_ABILITIES` (`src/client/Presentation/CombatCameraController.luau`),
usando o multiplicador já existente da lista (1,6×/1,4×): trauma 0,5→**0,8**,
FOV 2,6→**3,64** no acerto. O Cometa segue como o golpe mais pesado (trauma
0,85, perfil próprio). Teste em `tests/combat_e2e.luau` atualizado para exigir
`pesado > jab`. Docs 17 §2.6 e 32 §6 sincronizados no mesmo commit.

**Gates headless:** domínio 243/243, animação 74/74, fuzz 67/67, e2e 19/19,
Selene 0/0/0, StyLua limpo, Rojo build OK (valores conferidos na rodada).

---

## Rodada de 17/08 (noite) — corrida no Shift (16 / 22)

Implementação da corrida hold-to-run pedida no playtest: **Shift** (PC) e
**L3** (gamepad) elevam `Humanoid.WalkSpeed` de 16 para 22 studs/s — os números
já eram F0-BASELINE em `docs/13` §5 e só faltavam no input.

| Peça | Papel |
|---|---|
| `src/shared/Data/Locomotion.luau` | catálogo 16/22 + `clampAuthorizedSpeed` + `validate()` |
| `InputController` | `SprintDown` / `SprintUp` (NON_COMBAT, não gasta rate limit) |
| `CharacterController` | aplica WalkSpeed local; reaplicado no respawn |
| `init.server` | envelope de movimento **nunca** usa WalkSpeed > 22 (anti-exploit) |
| Locale / help | "Shift — correr" em PT-BR e EN |

**Não manda remote.** É apresentação/física local do avatar, como a maioria dos
jogos Roblox. O servidor só limita o budget de `PlayerMotionGuard` pelo teto de
corrida — se o cliente mentir WalkSpeed=100, o clamp corta em 22 e o teleporte
ainda é rejeitado.

**Gates headless desta rodada:** domínio **243/243** (+2: catálogo Locomotion e
SprintDown/Up), animação **74/74**, Selene 0/0/0. StyLua limpo nos arquivos
tocados. MCP do Studio esteve offline nesta sessão de agent — a validação em
Play (segurar Shift e ver 22 studs/s) fica como check humano no rebuild.

**Controles F0 (PC):** clique = leve · botão direito = pesado · **Shift = correr**
· F = guarda · Q = dash · 1/2/3 = técnicas · Tab = mira · E = interagir/portão · H = menu.

---

## Rodada de 17/08 — primeira evidência de runtime da F0

Esta rodada é a primeira do projeto com **medição dentro do Roblox Studio em
Play**, não headless. O que mudou de estado:

| Campo | Antes | Agora |
|---|---|---|
| Sincronia Studio × repo | não verificada | **63/63 arquivos com hash idêntico** |
| Cadeia de impacto (`a1_impact`) | "nunca rodou uma vez sequer" | **executada e confirmada** |
| Testes de animação/apresentação | 73 | **74** |
| Testes de domínio | 241 (declarado) | **240 passam, 1 falha** (ver abaixo) |

**`a1_impact` — o passo que estava travado desde 14/08.** Encostando no boneco
(5,02 studs, com `aim` declarado para o alvo), os golpes conectaram e os números
bateram com `docs/13` §6.1: leve `6/6/8/12` nos degraus 1-4, pesado `12`, Ombro
Cometa `14`. Vida do boneco 10000 → 9930, soma exata. O Cometa fechou distância
de 5,02 para 1,65 studs — o avanço curto existe. Zero linhas de `[Combat] errou`
durante a bateria.

O whiff que travava o passo **não era alcance nem fronteira**: os "5 recusados
pela fronteira" são os 4 Estilhaços + o elite na zona livre (recusa correta), e
o boneco nunca esteve entre eles. Era o **cone** — `CharacterController` declara
a direção no payload (`o corpo NÃO gira`), então mirar é enviar o `aim` certo.

**Guarda — sinal de eixo invertido.** Ver `docs/17` §2.3.1. A pose jogava os dois
braços para trás e para fora porque `pitch` negativo leva o braço para trás no
rig real. Os testes afirmavam `< -35`/`< -40`, ou seja, **travavam o defeito** —
a suíte ficou verde meses com a guarda visivelmente errada.

**Rede de segurança do anexo de junta.** Ver `docs/14` §4.7.1. **Confirmada em
runtime pelo Álvaro:** com ela, a guarda passou a levantar os punhos ao apertar
`F`. Era a causa do "aperto F e não muda nada" — não os números da pose.

**Peso dos socos.** Ver `docs/17` §2.10. Antecipação e recuperação ~30-40%
maiores, velocidade do trecho carga→impacto preservada, todos os degraus ainda
abaixo da janela de 0,65 s do `CombatService`.

**VFX publicado — os assets deixaram de ser fallback.** Os oito atlas CC0/CC-BY
que estavam no repo desde 14/08 esperando publicação (`docs/20`) foram enviados
por script e ganharam ID real. As **21 camadas** de `AbilityVfx` que já
declaravam `assetKey` estavam todas caindo no fallback procedural por falta de
`assetId`; agora usam a textura. Procedência registrada em
`assets/published-vfx-assets.json` (arquivo de origem, licença e crédito por
chave), e o teste que antes exigia `assetId == nil` passou a exigir que todo ID
conste nesse registro — inventar um número reprova.

**Vegetação na planície (17/08).** A planície era 100% mineral — poste, cristal,
pilar, formação de estilhaço — e lia como pedreira. Entraram 14 árvores (tronco,
forquilha e duas massas de copa, para a silhueta não virar pirulito) e 11
arbustos, em paleta verde-azulada escura que pertence ao mundo crepuscular em vez
de verde de floresta. Posições escolhidas, não sorteadas: a validação recusa
invasão de rota, cratera e âncora, e sorteio tornaria a falha intermitente. Ela
pegou dois erros reais na primeira tentativa — árvore colada numa âncora e os
onze arbustos enterrados no chão.

**Suíte 100% verde pela primeira vez: 241/241 de domínio.** A falha que este
snapshot chamava de "pré-existente" era **falso negativo de CRLF no teste**, não
defeito de produto.

**Mundo ampliado (17/08, tarde).** `zone_plain_free` foi de 160×120 para
**480×400**. Custo em contagem de partes da ampliação: zero — `buildFloors` faz
uma Part por volume. A vegetação passou de 25 peças escolhidas à mão para ~210
geradas por LCG de semente fixa, com cinco espécies (frondosa, conífera, tronco
morto, arbusto, pedra musgosa). Âncoras, cratera, rota e bastião **não** foram
movidos de propósito: misturar expansão com reposicionamento de spawn tornaria
qualquer regressão difícil de atribuir.

A validação pegou dois erros na geração — `boulder` e a raiz da árvore com `y`
abaixo da meia-altura, 107 peças enterradas de uma vez.

**Bots de missão — aceitos como estão (decisão do Álvaro, 17/08).** Medido em
runtime: a Instrutora tem 61 peças e o dummy 56,
ambos com o conjunto R15 completo (membros, torsos, mãos, pés) mais roupa
detalhada — capuz, casaco, capa, cabelo, ombreiras. **Mas nenhum dos dois tem
objeto `Humanoid`.** Vale decidir se é intencional (são cenário) ou se falta,
porque sem `Humanoid` não há `Animator` e eles não podem receber clipe algum.

**Sobre "a skin do outro agente não aparece":** verificado em runtime que as
skins do `main` **estão corretas** — os Estilhaços materializam 15 peças (25 no
elite) com as cores certas (ciano 104,220,238 no Halo/RiftRing/CoreGlow). A
skin esperada não existe em código: a branch `cursor/skins-code-pipeline-579d`
traz `docs/34-CODE-DRIVEN-SKINS.md`, que se declara **plano** na primeira linha
e não toca `WorldPresentation.luau`. Não há implementação para aparecer.

**Falha conhecida em aberto:** `planície: nada colide, nada entra no ringue do
elite e a luz tem teto` falha com `materialização existe`. Confirmado como
**pré-existente** (reproduz com a árvore limpa), não introduzido nesta rodada.
Por isso o domínio está em 240/1 e não nos 241 declarados abaixo.

**Não validado nesta rodada:** a camada visual de impacto (hit-stop, tremida,
luz, som, número flutuante) não foi confirmada a olho — `screen_capture` do MCP
só funciona em Edit, e input sintético não chega ao jogo sem foco de janela. W1,
dois clientes, latência, Android e gamepad seguem pendentes.

---

# Snapshot anterior — 16/08/2026

Este arquivo é a referência única para o estado técnico atual do repositório. Os demais documentos preservam decisões e histórico de implementação, mas afirmações antigas sobre commits, contagens de testes ou artefatos devem ser interpretadas como registros históricos quando divergirem deste snapshot.

## Estado atual

| Campo | Estado canônico |
|---|---|
| Branch publicado | `main` (esta rodada entra por PR) |
| Commit-base do código | `0b96d82` (`feat(headless): CI Linux, e2e de pesado/Cometa e atalho de casa`) |
| Estado deste documento | snapshot após CI Linux reproduzível, e2e de pesado/Cometa e atalho de casa |
| Data do commit | 2026-08-16 |
| Última alteração de código-base | `scripts/ci.sh`; 5 casos novos em `tests/combat_e2e.luau` (pesado miss/hit/guarda, Cometa miss/guarda); catálogo `homePrep` + comando `avb-debug home` |
| Testes de domínio | 241 passaram, 0 falharam |
| Testes de animação/apresentação | 73 passaram, 0 falharam |
| Fuzz headless de segurança | 67 passaram, 0 falharam |
| Simulação de combate ponta a ponta | 19 passaram, 0 falharam |
| Selene | 0 erros, 0 warnings, 0 parse errors nesta rodada |
| StyLua | passou nesta rodada (`--check` limpo em `src tests plugins scripts`) |
| Rojo | build aprovado; check local de 318.988 bytes em `/tmp/build.rbxl` (SHA256 `bc6b5056f238787ce2e857f835a1486b193f4f08db7a38bdccb4878d7f83bff4`) |
| Runtime Roblox Studio | ainda não validado neste snapshot |
| Dispositivos reais | Android, gamepad e PC integrado ainda não validados neste snapshot |
| DataStore publicado | ainda não validado em place privado |
| Múltiplos clientes | isolamento de sequência/orçamento coberto headless; latência real, spam, network ownership e dois clientes ainda não validados |

## O que está implementado

O repositório contém a fatia de combate server-authoritative, as três habilidades F0, progressão e quests, inimigo comum e elite, VFX de jogador e inimigos, skins procedurais, defesa e dash com apresentação procedural em fases, receitas locais de impacto de chão, paredes decoradas, teto translúcido no spawn, terreno contínuo, rochas e grama procedurais, referências visuais originais, índice visual na raiz, checklist de validação em `docs/26`, catálogo de habilidades futuras em `docs/27`, oito novas referências originais, reforma visual do spawn em `docs/28`, reforma do mundo aberto e das skins de inimigo em `docs/31`, runbook do playtest em `docs/32`, atalho de três passos para o PC de casa (`avb-debug home`) e o script `scripts/ci.sh` na ordem do GitHub Actions. O pacote público Kenney está arquivado como candidato externo.

O build e os testes automatizados demonstram integridade de código, contratos puros, catálogos, geometria, segurança modelada, apresentação procedural e árvore Rojo. Eles não demonstram que Parts, joints, iluminação, prompts, física, câmera, replicação, DataStore ou dispositivos reais funcionam como esperado dentro do Roblox Studio.

## Próximo estado recomendado

A ordem oficial continua sendo **sincronização do Studio → W1 de leitura do mundo → impacto real dos golpes → A1 do Ombro Cometa → R1 adversarial → W2 de performance e dispositivos → fechamento da F0**. No PC: `.\scripts\build-studio.ps1` → `avb-debug sync` → Play encostado no dummy (`a1_impact`). A F1 de loadout, Ressonância e múltiplas identidades só deve começar depois dos gates da F0 ou de uma decisão explícita de escopo.

## Regra de leitura dos documentos

Quando um documento mencionar commits como `108be31`, `d0f6f8d`, `b529c5e`, contagens como 166, 169, 238, 239 ou 49 testes, 14 casos de combate e2e, ou artefatos antigos de 160.553/128.744 bytes, essas referências são históricas e não representam o snapshot atual. Para esta consolidação, usar o commit final informado no GitHub, 241 testes de domínio, 73 de animação/apresentação, 67 de fuzz, 19 de combate ponta a ponta (400 casos) e a ausência de validação de runtime. Contagens de 227/62 e artefatos de 297.737 bytes pertencem à rodada de 14/08; 235/73/29 e 337 casos pertencem à rodada da manhã de 15/08; 239/73/67/14 e 393 casos pertencem à tarde de 15/08.

## Consolidação automatizada adicional

Após o snapshot `d7c44e8`, foram adicionadas validações puras em `SceneryPresentation.validateLayout(Zones)`. Elas verificam paletas RGB, limites de densidade de rochas e grama, transparência e altura do teto, fontes CC0 auditáveis, âncoras obrigatórias em suas zonas, distância mínima entre shards e distância mínima dos shards aos portões. Essas regras não tocam Instances e podem ser executadas no harness Lune.

Também foi adicionada uma regressão A1 para o blocking procedural do **Ombro Cometa**. O teste fixa o instante autoritativo de impacto em 0,40 s, verifica recolhimento corporal, inclinação do ombro, rotação do tronco, braço fechado para diferenciar a técnica de um soco e retorno visual ao neutro. O teste não declara que existe um clipe final nem substitui o gate A1 no Roblox Studio.

A receita de build existente em `scripts/build-studio.ps1` continua sendo a fonte de geração do artefato de Play. `scripts/ci.sh` só valida a árvore em `/tmp/build.rbxl` e não deve ser aberto no Studio. O bridge permanece limitado a sincronização e inspeção; não foi alegado que ele executa Play, tira screenshots ou mede dispositivos reais.

Nesta rodada, o domínio passou com **241 casos**, a animação/apresentação com **73**, o fuzz de segurança com **67** e a simulação de combate ponta a ponta com **19**. Foram adicionados o script de CI Linux, cinco desfechos de pesado/Cometa na cadeia de impacto e o atalho `home`. O total automatizado atual é **400 casos**. Selene, StyLua, Rojo e as quatro suítes Lune passaram. Isso continua sendo evidência de contratos, apresentação pura e árvore de build; não é evidência de boot, colisão, replicação, latência, Android, gamepad, DataStore real ou qualidade visual final.

O achado da câmera do pesado básico (`abilityId = "heavy"` fora de `HEAVY_ABILITIES`) permanece pinado: o teste fixa o trauma igual ao jab. Só o Play decide se isso muda.

A conclusão recomendada permanece: no PC, `lune run scripts/avb-debug.luau home`, abrir o place canônico, executar W1, registrar evidência de runtime, depois A1/R1/W2. Nenhuma dessas validações externas deve ser marcada como concluída apenas por estes testes.

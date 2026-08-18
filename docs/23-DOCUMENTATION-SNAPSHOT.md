# Snapshot Canônico da Documentação — 18/08/2026

## Rodada de 18/08 (Grok) — upload PBR + texturas do mundo

Studio aberto via tarefa interativa; `upload_image` publicou 12 mapas de
`docs/assets/roblox-ready/textures` (3 ColorMaps + 9 normal/roughness/metalness).
IDs em `assets/published-world-assets.json`. Runtime: `WorldTextures` aplica
ColorMap de ardósia no Bastião/pad/praça/caminhos, runas na muralha/portões,
cristal no Marco; overlays VFX (anel/orbe/raio/`kenney_scorch`) por cima.
Materiais por bioma (LeafyGrass, Cobblestone, Granite, Salt, Marble, Rock).

---

## Rodada de 18/08 (Grok) — todos os VFX/áudio publicados ligados e testados

O player de VFX aplica o `rbxassetid` na hora (os 8 atlas estão Completed).
Trilha também recebe a textura. Teste `assets: todo VFX publicado está
liberado, ligado e tocável` percorre AbilityVfx + EnemyVfx + CombatAudio:
ID no registro, thumbnail Completed, arquivo de origem no disco, nenhum
órfão. Impacto sonoro cobre as habilidades de NPC. Sem Studio.

---

## Rodada de 18/08 (Grok) — VFX liberados + Sucateiro do Porto

1. **Assets.** Os 8 atlas publicados passaram a `thumbnailState=Completed` na API pública (`thumbnails.roblox.com`). Os 5 do AbilityVfx (energy_ball, power_ring, lightning_shock, explosion_0003, explosion_0005) saíram de Pending. Thumbnails no CDN são os sprites reais (orbe, anéis, raio, explosões). Sem re-upload. Crédito CC-BY agora no MENU (`hud.credits_vfx`).
2. **Bots.** `enemy_port_scrapper` — 2 no Porto Ferro (cais leste e farol), Nv. 12, 48 HP, talho/gancho. Patrulha como os outros caçadores.
3. Suite e CI no mesmo commit. Sem Studio.

---

## Rodada de 18/08 (Grok) — bots, poderes e células mais densas

Sem Play no Studio (pedido do Álvaro). Incremento só em dados/serviços/testes:

1. **Bots.** Estilhaço Errante cicla talho → salto → **fenda** (`shard_rift`, dano 10 / 550 ms). Sem alvo, patrulha a âncora (órbita de 6 studs). Elite ganha **onda** (`anchored_shock`, dano 10, guardável) depois do slam. Novo NPC `enemy_grove_wisp` (2 no Bosque, Nv. 10, 36 HP, `wisp_pierce`, loot `umbral_dust`).
2. **Poderes / VFX.** Camadas extra honestas: `comet_dust`, `cadence_spark`, `counter_arc` (raio e brilho ≤ alcance).
3. **Cenário.** Densidade de leitura em Bosque / Porto / Cinza / Academia (lanternas, cais, correias, bancos). Sem PointLight nova, sem colisão. Clareiras do Fátuo reservadas no LCG.
4. Baseline F0 dos Estilhaços **intacto** (60/8/4 e elite 120/14/700). Suite e CI no mesmo commit.

---

## Rodada de 17/08 (Grok) — Distrito Lumen, primeira célula urbana densa (F1)

Commit `801f5fb` no main (CI verde). Catálogo `BiomeDecorations`: **494 peças
Lumen\*** (rua principal, 14 fachadas + 8 skyline, 2 vielas com jog de linha de
visão, praça de asfalto, **Mercado e Forja** visuais, marco `LumenTower`
9×50×9 + coroa neon). 2 PointLights (coroa 28 studs, cristal 16), 0 sombras,
0 colisão. Play no Studio: 494 materializadas, 2535 BaseParts no Workspace
(teto W2 6000). `build.rbxl` 407.098 B. Docs 24 §7 e 02 §3.4 no mesmo commit.
Suite 270+79+71. **Não é a cidade inteira**: sem sistema de compra/forja
(só leitura visual, de propósito); profiling de streaming/memória/render é a
etapa 4 do docs/24 (pendente). Honestidade visual: praça deixou de ser disco
Neon (lia como alcance); luzes reais só na coroa e no cristal, com
`rangeStuds` declarado.

---

## Rodada de 17/08 (Grok) — revalidação dos 8 assets VFX publicados

Commit `920af2f` no main (CI verde). Os 8 atlas publicados (5 AbilityVfx +
3 EnemyVfxAssets) foram revalidados via thumbnail API + sonda ImageLabel no
Play: **todos renderizam os pixels de verdade — nenhum re-upload necessário**
(antes: "asset publicado ≠ asset utilizável", emissor apontava para textura
vazia). Kenney slash/spark/scorch com thumbnail Completed; os 5 da AbilityVfx
ainda Pending na moderação mas carregam no cliente. Registro atualizado em
`assets/published-vfx-assets.json` (revalidatedAt + thumbnailState/
rendersInPlay/action por asset) e `docs/20-VFX-ASSETS.md`. Crédito CC-BY
(energy_ball, lightning_shock) só no JSON/docs, não no MENU.

---

## Rodada de 17/08 (Hermes-server + Grok) — orquestração via janela do Grok

Sessão de desenvolvimento conduzida do server-desktop (Hermes) comandando a
janela "Analyze Local … - grok" no PC Windows (`pcque001imap`) via
schtasks /IT + OCR + clipboard: prompts colados (mundo → UI → validação →
Lumen → VFX), `/compact` quando o contexto estourava, watchdog de estado
(título da janela decide WORKING/DONE; o corpo mantém histórico que polui o
OCR) e encadeamento automático de prompts. Ferramentas criadas nesta sessão
(no server): `grok-paste/grok-send/grok-cmd.ps1` + `grok-watch.sh` + cron
`avb-grok-watch` — documentadas na skill `anime-verse-battlegrounds` do
Hermes. Lição: Enter via SendKeys perde foco entre execuções separadas do
runner — digitar+enviar na MESMA execução (grok_cmd.ps1) funciona.

---

## Rodada de 17/08 (Grok) — pass visual da UI

Paleta única `UiPalette`: vida/guarda/umbral/dano/destaque/perigo. HUD com
cantos, traço e ghost de dano recente. Hotbar com glow no slot pronto. Faixa
de zona colorida **e** texto. Painéis B/K/J/MENU com fundo e traço. Gatilhos
de dano/XP/zona intactos. Ver `docs/35-UI-VISUAL-PASS.md`.

---

## Rodada de 17/08 (Grok) — serras e relevo, fim do chão reto

Cordilheira no horizonte da planície (7 picos + elos, neve nos altos), serras
leste/oeste, colinas e lomadas internas. Identidade por bioma (Bosque, Lumen,
Cinza, Porto, Academia). Dados em `WildDecorations` / `BiomeDecorations`;
WorldService só materializa. 1269 peças na planície (7 luzes) + 352 de bioma
(10 luzes). Y=0, âncoras, cratera e rotas intactos.

---

## Rodada de 17/08 (Grok) — soco mais lento e acerto mais fácil

1. **Cadeia leve ~1,5× mais lenta:** 0,495 / 0,600 / 0,750 / 0,930 s.
   Janela `LIGHT_WINDOW` 0,65 → **1,00 s** (apresentação e servidor iguais).
2. **Acerto:** folga de corpo 5→**7** (alcance leve **13**), cone **92°/80°**,
   folga de pista 8 studs + 20°. Costas e 26 studs continuam miss.

---

## Rodada de 17/08 (Grok) — carreira, missões extras, nível dos bots, muralha, hitbox

1. **Placar de carreira (J):** monstros, chefes, dano, tempo de jogo, quedas,
   técnicas, consolidações, missões. Persistido. Dummy não conta.
2. **Missões** `quest_grove` / `quest_remnant` e identidade **Tecelão de Ecos**.
3. **Nível do bot** no Billboard (`Nv. 8` / `Nv. 18`).
4. **Muralha** Limestone + Sandstone + Basalt (não Slate único).
5. **Golpe:** folga de corpo 3→5 (alcance 11) e cone 78°/68° — depois
   recalibrado para 13 studs / 92° (ver bloco do topo).
6. **Persistência da carreira:** `releaseProfile` sempre grava; créditos
   sujam o perfil. Dano de técnica (Cometa/Cadência) e contra do Pulso
   entram no placar. `getCareer` persiste o placar mesmo depois de
   `ProgressionService.unregisterPlayer` (leave curto / snapshot de XP nil).

---

## Rodada de 17/08 (Grok) — XP visível, flash de nível e mochila

1. **XP do kill** flutua no monstro (`+25 XP` / `+80 XP`), igual o número de dano.
   O tracker da task mostra o prêmio (`+40 / +60 / +40 XP`). A barra de nível
   enche com o XP do campo; os pontos continuam só na consolidação.
2. **Flash de evolução** (1,6 s, dourado) quando o Marco sobe o nível.
3. **Mochila (B):** técnicas + materiais sem poder (fragmento, lasca, pó,
   faixa). Persistida no ProfileRoot. Suite headless + place `anime-verse-battlegrounds.rbxl`.

---

## Rodada de 17/08 (Grok) — vegetação realista + nível por pontos

1. **Vegetação.** A planície saiu do sorteio uniforme (que agrupava e deixava
   claros) e passou a bosques com ocupação mínima + sub-bosque (grama,
   samambaia, tronco, flor). Árvore agora tem tronco em dois segmentos e copa
   em quatro camadas. O Bosque dos Ecos deixou a grade; Lumen/Porto/Cinza/
   Academia ganharam vegetação de bioma. Nada colide; teto W2 6000 intacto.
2. **Evolução.** XP consolidado no Marco vira nível (`floor(2 × n^2,3 + 84)`,
   curva Blox Fruits). Cada nível dá 3 pontos gastos em Vitalidade / Umbral /
   Impacto / Guarda / Ressonância. Impacto e Ressonância capam em 6%
   (GDD-DEC-005). HUD STATUS (K). `SpendProgressionIntent` só declara a
   trilha. Respec só na zona segura.

---

## Rodada de 17/08 (Grok) — void dos portões + malha de biomas

1. **Buracos no void ao lado dos portões.** O vão norte tem 12 studs e o oeste
   10; o muro continua. Um passo para o lado, ainda colado na caixa, caía no
   nada. Aventais `zone_plain_free` cobrem as faces de fora; plinto leste/sul
   amplia o Bastião para a caixa não flutuar.
2. **Malha de células (docs/02 §3.4 / docs/24):** Distrito Lumen (seguro,
   neon), Bosque dos Ecos, Porto Ferro, Setor Cinza (livres, PvP) e Academia
   Alvorada (segura). Pisos coloridos por bioma; decoração sem colisão;
   `ZoneService` generalizado (safe↔safe, free↔free). Âncoras e quests F0
   não se mexeram.

---

## Rodada de 17/08 (Grok) — raio de aggro 30 studs nos bots

Os Estilhaços perseguiam o jogador por toda a planície (480×400). Agora há um
único raio de **30 studs** (padrão Blox Fruits) em `Npcs.aggroRadiusStuds`:
fora dele o bot **não inicia** perseguição e **larga** a que já tinha, voltando
à âncora. Fronteira PvP continua recusando aggro. Elite continua ancorado
(só ataca a 8); o raio só impede de considerar alguém do outro lado do mapa.

---

## Rodada de 17/08 (Grok) — contato local, HP no servidor (R1)

Playtest de dois clientes: o soco de um no outro (e no monstro) chegava
atrasado. Pose já era local; flash/número/hit-stop esperavam o `CombatEvent`;
no PvP a HRP do outro replica.

**Opção A fechada em código:**

1. `HitContact` (shared, puro) — cone, folga de 5 studs + 15°, `view`, janela
   de 350 ms para não dobrar feeling.
2. `claimedTargetId` no `BasicAttackIntent` é pista. Cone do servidor vence;
   a pista só entra no miss espacial e ainda passa por vida/fronteira/folga.
3. Cliente antecipa hit-stop/câmera/som no instante da antecipação se o cone
   local viu alvo. Número e VFX `requiresConfirmation` continuam no
   `CombatEvent`.
4. `CombatEvent.view = dealt | taken` — o outro jogador sente o golpe no
   mesmo frame em que o HP muda.

R1 de feeling/registro fecha em contrato headless. Latência real de dois
clientes no Studio ainda é evidência de Play, não desta suíte.

---

## Rodada de 17/08 (Claude-windows) — a Instrutora sai do pilar e a skin aparece

Rodada de conserto: a silhueta feminina da Instrutora tinha entrado em `54836f9`
e o playtest respondeu "a skin não mudou nada, e está bugada dentro da parede".
As duas queixas estavam certas, por causas independentes — e nenhuma delas era a
modelagem, que estava completa (81 peças, tamanhos corretos, medidos no Studio).

1. **Ela nascia dentro do pilar.** `anchor_instructor` era `(20, 0, −14)`; o
   pilar-marco `(20, −16)` tem 4 studs de lado e ocupa `z −18..−14`. Capa e rabo
   de cabelo ficavam dentro da pedra. A regra que pega isso — *nada sólido a
   menos de 2 studs de uma âncora* — **já existia** em
   `SpawnDecorations.validate` desde 13/08. O que faltava era o pilar estar
   sujeito a ela: os quatro eram uma tabela `local` dentro do `buildWalls`,
   camada de Instances, invisível para os testes. Viraram dado
   (`SpawnDecorations.bastionPillars`), o `WorldService` só materializa, e a
   regra foi extraída para `anchorClearanceErrors`, compartilhada pelos dois
   conjuntos. Âncora movida para `(20, 0, −11)` — que também a põe sob a
   luz-chave dela, já em `z −12,5`. Medido em Play depois: pilar fora da caixa
   de colisão, folga de **2,22 studs**.
2. **A skin era invisível, não ausente.** Cabelo, saia e casaco tinham
   luminância relativa **30, 27 e 41** numa escala 0–255 — degraus de 3 a 14
   pontos, no Bastião à noite. Colapsava numa mancha preta e só o neon lia. A
   paleta agora sobe em degraus de no mínimo 24, travados por
   `Presentation.validatePalette` dentro de `validateRigs`. Cabelo vs saia:
   **3 → 130 pontos**. Detalhe e tabela de tons em `docs/28`.
3. **Fixture que transcrevia o dado.** Os dois casos de âncora do spawn traziam
   `{ x = 20, z = -14 }` escrito à mão, embora o nome dissesse "com os dados
   reais do Zones": mover a âncora não movia o teste. Agora leem de
   `Zones.getAnchor`. Casos novos: folga dos pilares e a contraprova de que a
   posição antiga é reprovada.
4. **`build-studio.ps1` abortava no Wally** — stderr de executável nativo virando
   erro terminante sob `$ErrorActionPreference = "Stop"`, com exit code 0. Ver
   `docs/32` §2.

Suítes: **247** (`run`) + **78** (`animation`) + 67 (fuzz) + 19 (e2e) = **411**.
Selene 0/0, Rojo build ok, CI verde em `5fcbe4c`. Pitfalls de toolchain desta
rodada (incluindo `stylua --check` reprovando o repo inteiro neste Windows por
CRLF) registrados em `docs/12` §9.

**Em aberto:** o torso ainda é a parte fraca. `CoatChest` está em RGB(74,70,104)
mas renderiza bem mais escuro que o valor nominal porque o material `Fabric` tem
textura escura e ruidosa — a escada de valor governa a cor, não o material.
Candidatos: trocar os painéis grandes do casaco para `Leather`/`SmoothPlastic`
ou subir mais o `COAT`.

---

## Rodada de 17/08 (Hermes-server) — guia do W2 no Studio (docs/33)

O gate W2 ganhou um guia operacional passo a passo: **`docs/33-W2-PERF-PLAYTEST.md`**
(preparo PowerShell → sync → boot limpo → cena de estresse com 4 Estilhaços +
elite → MicroProfiler em stepAnimation/script/render → `avb-debug evidence` →
registro dos 4 tetos → ficha docs/26 → fechamento docs/12/docs/23). Referenciado
do `docs/32` §W2. Nada de código mudou — só documentação de sessão.

---

## Rodada de 17/08 (Hermes-server) — honestidade visual: glow contido + auditoria W2

1. **Alerta de 14/08 fechado — a luz não passa mais do alcance** (`AbilityVfx`):
   `validate()` limitava `radiusStuds` mas não `glowStuds` (= raio × `GLOW_BY_KIND`),
   então o brilho podia crescer além do alcance sem teste reclamar — pior caso
   real: `guard_ring` 2,4 × 1,4 = **3,36 vs alcance 3,0** (12% acima). O
   `validate()` agora rejeita `glowStuds > rangeStuds` e o `guard_ring` teve o
   raio ajustado 2,4 → 2,1 (2,94 ≤ 3,0; anel 12% menor, contrato do teste
   "luz = raio × fator" preservado). Teste novo trava o catálogo inteiro.
2. **Auditoria de Parts para o gate W2** (medida nos catálogos, não estimada):

   | Fonte | Parts |
   |---|---:|
   | Vegetação da planície (`WildDecorations`) | **914** (74%) |
   | Rigs ativos (instrutora ~61 + dummy ~56 + 4 errantes ~15 + elite ~25) | ~200 |
   | `SpawnDecorations` (dentro do bastião) | 40 |
   | Pisos (8 volumes + praça/rotas/cratera) | ~17 |
   | Muralha/portões/marcos/postes/estilhas | ~50 |
   | **Total estimado** | **~1.220** |

   Teto F0-BASELINE do W2 é **6.000** — folga de ~5×. Conclusão: **parts não é
   o gargalo provável**; o W2 no Studio deve olhar primeiro `heartbeatTimeMs`
   (16,6) e `stepAnimation` com 5 NPCs animando procedural. Se o Android sofrer,
   a ordem de corte de `docs/31` §7 manda reduzir a densidade da vegetação
   (74% do total) antes de qualquer outra coisa.

**Gates headless:** domínio 244/244, animação 75/75 (+1 glow), fuzz 67/67, e2e
19/19, Selene/StyLua/Rojo limpos (conferidos na rodada).

---

## Rodada de 17/08 (Hermes-server) — controles no padrão dos demais jogos + hotbar Roblox

Duas mudanças de input pedidas pelo Álvaro no playtest (GDD §3.1 e este
snapshot sincronizados no mesmo commit):

1. **Hotbar estilo inventário padrão do Roblox** (`UIController`): o cluster de
   habilidades saiu do canto inferior direito (botões largos 112×78) e virou
   uma hotbar de **slots quadrados 58×58 numerados (1/2/3), centralizada no
   rodapé** — o visual padrão dos jogos Roblox. Número da tecla no canto do
   slot, nome dentro, cooldown radial e cadeado preservados. O prompt de
   travessia (`ZoneHold`) subiu para `y = -178` para não colidir com a hotbar.
2. **Botão direito = defesa, esquerdo = ataque** (`InputController`):
   - clique esquerdo **rápido** = golpe leve (cadeia de 4) — decidido no
     release;
   - clique esquerdo **seguro (~0,3 s)** = golpe pesado (hold-to-heavy, escolha
     do Álvaro; antes o pesado morava no botão direito);
   - botão direito = **guarda/aparo** (antes era o pesado); F e L2 seguem como
     alternativas;
   - gamepad intacto: RT = leve, RB = pesado, LT = guarda; toque segue leve
     no toque (sem hold-to-heavy de propósito — arrasto viraria pesado
     acidental).

Regra extraída para função pura `InputController.resolveMouseRelease` (testada:
release órfão/clique rápido = leve, ≥ 0,3 s = pesado) — o wiring de
InputBegan/Ended só registra o relógio e chama ela. Textos de ajuda (PT/EN)
atualizados.

**Gates headless:** domínio 244/244 (+1 hold-to-heavy), animação 74/74, fuzz
67/67, e2e 19/19, Selene/StyLua/Rojo limpos (conferidos na rodada).

---

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

**Controles F0 (PC):** clique esquerdo = leve · segurar esquerdo ~0,3s = pesado
· **botão direito = guarda** · Shift = correr · Q = dash · 1/2/3 = técnicas
(hotbar numerada no rodapé) · Tab = mira · E = interagir/portão · H = menu.

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
abaixo da janela de 1,00 s do `CombatService`.

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

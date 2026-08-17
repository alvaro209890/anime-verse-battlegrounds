# 12 — Testes e evidências

> **Snapshot de implementação:** 2026-08-17. Quatro suítes Lune: `tests/run.luau` **268 casos de domínio**, `tests/animation.luau` **79 de animação/apresentação**, `tests/security_fuzz.luau` **71 de fuzz adversarial** e `tests/combat_e2e.luau` **23 de simulação de combate ponta a ponta** — total automatizado de **441 casos**, sem transformar essa soma em evidência de runtime Roblox. Nesta rodada: carreira persiste no leave sem `markDirty` manual; Cometa/Cadência creditam dano no `AbilityService`.

## 1. Estado da execução

No snapshot de implementação atual, a verificação automatizada registrou 268/268 em `tests/run.luau`, 79/79 em `tests/animation.luau`, 71/71 em `tests/security_fuzz.luau` e 23/23 em `tests/combat_e2e.luau`. Selene e StyLua continuam gates separados e foram executados neste release: Selene com 0 erros/0 warnings e StyLua com `--check` limpo em `src tests plugins scripts`. O ambiente e o commit devem ser registrados junto de qualquer evidência futura.

**Registro histórico, não evidência do snapshot atual:** uma rodada anterior teve confirmação em Play pelo jogador, com `avb-debug sync` = 56/56, de que a animação de golpe movia o corpo e o personagem não girava sozinho. Essa evidência pertence ao estado anterior documentado em `docs/14` e não deve ser usada para declarar o commit `d7c44e8` validado em runtime. Neste snapshot, o Play atual continua pendente.

Segue sem comprovação em Play deste snapshot: a camada de impacto no Studio com o place novo. Motivo histórico em `docs/14` §4.8: o jogador estava a 41,2 studs do único alvo. O alcance leve efetivo agora é 11 studs (6 + folga de corpo 5, cone 78°/68°); a suíte e2e trava 11 conecta / 11,6 erra. Isso não substitui Play.

Desde 15/08 essa cadeia é **exercida em contrato** por `tests/combat_e2e.luau`. Em 16/08 a suíte passou de 14 para 19 casos: o pesado e o Ombro Cometa repetem os desfechos miss (41,2 studs), acerto (≤ 6 studs) e guarda. O passo `a1_impact` do [`docs/32`](32-STUDIO-PLAYTEST-RUNBOOK.md) é onde isso vira evidência de verdade. O atalho `avb-debug home` só prepara essa sessão — não a substitui.

O histórico abaixo é de 2026-08-13 e fica como registro da rodada anterior. O Play das 14:26 (`docs/18-ANALISE-VIDEO.md` §7) comprovou HUD, MENU, técnicas desbloqueadas e custo de UMBRAL sendo cobrado — e expôs o portão intransponível (prompt de travessia só no toque + recusa devolvendo a posição a cada Heartbeat).

O Play registrado às 09:26 abriu um artefato anterior e chegou a `[Bootstrap] servidor pronto (F0)` sem erro Luau do jogo. Esse arquivo antecede as mudanças atuais e não serve como evidência deste snapshot. O artefato canônico do commit `d7c44e8` ainda não foi reaberto nem executado por nós; boot/spawn atual, apresentação, interação, física, HUD, save e fluxo jogável continuam sem comprovação no Studio.

O checkout está com finais de linha mistos por `core.autocrlf`: o check direto do StyLua 2.5.2 e o check forçado com `--line-endings Windows` retornam diff apenas de EOL em conjuntos opostos. O código alterado foi formatado pelo StyLua, e a validação canônica LF deve ser usada para reproduzir o CI sem converter o repositório inteiro.

Essa evidência valida a **regra** espacial: distância, lado do golpe, cápsula do trajeto, avanço de 7 studs com cap 8 e parada na guarda, perseguição a 12 studs/s, telegraph de 400 ms, respawn de 45 s e coerência entre os volumes do greybox e todas as âncoras.

Ela **não** valida a **execução**. Nesta rodada o novo snapshot não foi reaberto nem houve playtest atual: boot, spawn, dummy, técnicas, animações, interações, morte/respawn, fronteira, objetivo, câmera, HUD e dispositivos continuam sem evidência runtime. A afirmação honesta é "camada cliente e bootstrap compilam e têm regras testadas headless" — não "o jogo atual foi testado no Studio".

## 2. Gates reproduzíveis

Depois de instalar o toolchain, a verificação completa do repositório é:

No Linux/macOS (o que o CI roda, na mesma ordem):

```bash
export PATH="$HOME/.aftman/bin:$HOME/.local/bin:$PATH"
aftman install                 # 1ª vez neste PC: aftman install --no-trust-check
./scripts/ci.sh                # StyLua, Selene, quatro suítes Lune, Wally, rojo build
```

Os comandos expandidos (iguais ao workflow e ao `ci.sh`):

```bash
stylua --check src tests plugins scripts
selene src tests plugins scripts
lune run tests/run.luau
lune run tests/animation.luau
lune run tests/security_fuzz.luau
lune run tests/combat_e2e.luau
wally install && mkdir -p Packages
rojo build -o /tmp/build.rbxl
```

No Windows, com o snapshot canônico no fim:

```powershell
aftman install
stylua --check src tests plugins scripts
selene src tests plugins scripts
lune run tests/run.luau
lune run tests/animation.luau
lune run tests/security_fuzz.luau
lune run tests/combat_e2e.luau
wally install
if (-not (Test-Path -LiteralPath .\Packages)) { New-Item -ItemType Directory .\Packages }
rojo build -o .rojo-tree-check.rbxl
.\scripts\build-studio.ps1
```

Os quatro caminhos (`src tests plugins scripts`) são os mesmos do
`.github/workflows/ci.yml`. Rodar `selene src tests` só — sem `plugins` e
`scripts` — passa localmente e quebra no CI.

O CI executa StyLua, Selene, os testes Lune, a instalação Wally e o build Rojo em todo pull request e em pushes para `main` (`.github/workflows/ci.yml`). Cada resultado precisa registrar commit, ambiente e saída; “verde no CI” não significa “testado no runtime Roblox”. `.rojo-tree-check.rbxl` valida a árvore e é descartável; `scripts/build-studio.ps1` produz o snapshot canônico `anime-verse-battlegrounds.rbxl` e verifica tamanho/data/hash. Nenhum dos dois comandos equivale a abrir o arquivo e usar Play.

O gate de tronco tem nome feio de propósito. Em 2026-08-14 o place canônico estava com um lock órfão, o build saiu para um `build.rbxl` na raiz, e esse arquivo virou o place que o jogador abria no Studio — três commits de correção de animação ficaram invisíveis porque o Play rodava um snapshot anterior a todos eles. Dois `.rbxl` abríveis lado a lado é o bug; o gate de tronco agora escreve num nome que ninguém confunde com place de trabalho, e `build-studio.ps1` limpa lock de sessão morta em vez de empurrar o build para outro arquivo.

**Antes de dizer que uma correção de runtime não funcionou, confirme qual código o Studio está rodando** (`lune run scripts/avb-debug.luau sync`, receita em [docs/19](19-DEBUG-BRIDGE.md#5-receitas)). Sem isso não dá para separar “o conserto está errado” de “o conserto não chegou até aí”, e as duas hipóteses levam a trabalhos opostos.

Em checkout Windows com `core.autocrlf=true`, os arquivos de trabalho podem estar em CRLF enquanto `stylua.toml` exige `Unix`; nesse caso, o check direto acusa somente final de linha. Para reproduzir o CI, use uma cópia com bytes LF canônicos do Git (`git -c core.autocrlf=false archive ...`). `--line-endings Windows` só é equivalente quando todo o checkout está uniformemente em CRLF; ele não resolve uma árvore mista. Não reformatar código só para mascarar essa conversão do checkout.

## 3. Cobertura existente: exatamente 247 testes de domínio

| Área | Cobertura |
|---|---|
| **Dados e rede** (15) | Punho do Eclipse 3+1; `comet_shoulder`; Umbral baseline; 4 famílias; remotes incl. `SessionSnapshot`, `AbilityIntent`, `CombatEvent`, `InteractionIntent`, `StateDelta` e `EnemyEvent`; envelope v2 exige versão, request ID, sequência, ação e payload válidos; dummy 10000 HP / dano 4; Estilhaço Errante 40/6/4; zonas: 3 zonas, PvP só na livre, âncoras persistidas + pontos de Estilhaço, spawn no bastião; Locale PT-BR/EN das chaves §16 e formatação de `{n}`; `quest_hunt` 3 kills / +40 XP / unlock Cometa |
| **Cliente** (13) | gate de `SessionSnapshot.ready`; limite de 8 intenções de combate/s; no máximo 2 botões de toque simultâneos; `CharacterController` envia intenção sem alvo/dano; ToggleLock solta sem remote; `clearLock` solta sem procurar outro alvo; ToggleHelp fora do rate limit; clique de combate passa por HUD `processed` salvo em GuiButton/TextBox; 3 slots, ultimate oculta, unlock e cooldown no `AbilityController`; rejeição reconciliada sem código interno na UI; Umbral/zona/perda só após ready; hold de fronteira de 0,6 s; Locale cobre PT-BR/EN do HUD F0 (inclui MENU/mira/câmera/ATACAR) |
| **Bootstrap/Rojo** (1) | o bootstrap resolve `Services` como filho do Script `Server` gerado pelo Rojo e não procura a pasta em `ServerScriptService` |
| **Telemetria/segurança** (13) | allowlist/remoção de campos arbitrários; tipo/buffer; execução dos sete schemas; envelope/payload válido; campo extra e direção; replay de request/sequence; envelope fechado e amostragem de rejeição; limite 8/s separado de interação; NaN/vetor impossível/interação ambígua; limpeza entre sessões; orçamento de combate isolado entre dois jogadores; sequência fora de ordem não atravessa jogadores |
| **Mundo/apresentação/Studio debug** (10) | quatro receitas e estilo procedural válidos; skin de Estilhaço/elite vem de `WorldPresentation.shardGearFor` e nenhuma peça passa do `attackRange` real do NPC; peça de skin malformada é recusada; o `WorldService` materializa o corpo mineral só a partir dos dados e devolve a transparência declarada no respawn; poses de NPC preservam antecipação/ataque/queda; apresentação local do jogador diferencia antecipação/impacto leve, peso do ataque pesado, guarda e recuperação; gate exige Studio + atributo e exclui ultimate; flags de sessão aparecem para habilidade/HUD e não entram no snapshot durável; `resolveAttribute` cai no Script Server e `applySessionUnlocks` só no Studio |
| **Geometria** (5) | distância no plano ignora altura; normalize de vetor nulo não vira NaN; costas vs. frente vs. perpendicular; cápsula do trajeto dentro/fora do raio e além do fim; lunge de 7 com cap 8 e parada antes do contato; `moveToward` a 12 studs/s parando no alcance |
| **Greybox** (7) | o `WorldService` gera piso rastreável a partir de cada volume canônico; a decoração da planície valida contra zonas, cratera e âncoras reais, não colide nem entra em raycast, respeita o teto de 8 luzes, entra no bootstrap, e os quatro casos negativos (fora da zona livre, no ringue do elite, colada na âncora de spawn e na faixa de caminhada) são recusados; o volume de cada zona resolve a zona declarada por todas as âncoras, o plano do portão resolve como transição e fora de todo volume devolve nil; 6 pontos de Estilhaço ≥ 24 studs entre si e ≥ 20 dos portões |
| **Interação mínima** (5) | catálogo allowlisted/localizado do Instrutor e Marco; cliente bloqueado até `ready` e payload sem recompensa; Instrutor exige alvo conhecido e proximidade medida pelo servidor; Marco exige hold de 1,5 s no relógio do servidor; conclusão revalida distância e pending é limpo no leave |
| **SpatialService** (4) | hitbox à frente acerta 1 e ignora quem está atrás/longe; Ombro Cometa avança 7, commita a posição e acerta 1 alvo na cápsula; guarda inimiga trava o avanço; avanço sem alvo é resultado válido |
| **EnemyService** (5 + elite 3 + leash) | spawn até o teto de 4 com a âncora no id e sem duplicar; persegue, para no alcance, telegraph de 400 ms sem dano e 6 depois; sem aggro para jogador na zona segura; raio 30 studs (não puxa / larga e volta à âncora); respawn de 45 s bloqueado por jogador a menos de 20 studs; kill reporta âncora e autor; **elite**: spawn único na `anchor_elite`; leeching por dano ≥ 1% na morte; leeching por 8 s no raio sem dano |
| **CooldownService** (3) | inicia zerado; `start` aplica e expira; `clear` zera |
| **CombatService** (28) | applyDamage legado; cadeia 6+6+8+12; `basicCombatEvent` leva dano no HUD e miss esconde número; reset 0,65 s; guarda 40%; aparo 120 ms; costas; pesado 12/28/2; quebra+overflow; miss bloqueia leve; dash i-frame/CD; dummy alcance/período; comet 14 aberto; guarda para avanço (6 HP + 14 guarda); aparo; i-frame; Estilhaço telegraph+dano 8; sem aggro na fronteira; alcance 4; recovery; respawn 45 s; cap 4 vivos; `killed` só na transição vivo → morto e `diedAt` não é re-carimbado; **elite**: ciclo alterna combo 6+6 e slam 14; slam na guarda corta 30%; Pulso na postura reduz 50% e consome a postura |
| **ResourceService** (6) | pool; `trySpend`; `grantFlowGain`; família desconhecida; `tryGrantFlow` 6+3 e cap 1,5 s; regen 2 / atraso 3 s / 6 |
| **AbilityService** (14) | Ombro Cometa em `ServerPlayerState`; recusas; ultimate `disabled`; `locked`; Cadência 5+6, janela de reentrada e eco 4 no tick com Fluxo; Pulso: postura sem dano → erro vira recovery 600 ms; postura reduz 50% + contra 8; costas e slam do elite vencem a postura; comet no fighter dummy + `CombatEvent` |
| **CatalogService** (6) | dados reais (incl. dummy, instrutor e cadeia de objetivos); personagem sem habilidade falha; zona/âncora inválida falha; objetivo com alvo/ofertante desconhecido, `requiredCount = 0` ou `acceptFlag` vazia falha; `displayNameKey` sem entrada no Locale falha; âncora que declara uma zona mas cai no volume de outra falha |
| **PlayerSessionService / fatia** (4) | join/leave; snapshot Ready sem unlocks e, após grant, lista `unlock_comet_shoulder`; join Ready → comet `locked` até grant, depois 18 Umbral e dummy 9991 HP; roteiro 0–5 min ponta a ponta (aceite → travessia → 3 kills → 115 XP → Cometa liberado) |
| **ProgressionService** (11) | cadência/pulso locked no spawn; grant comet idempotente e flag desconhecida recusa; leave limpa flags; kill do Estilhaço credita 25 e dummy não credita; retorno decrescente 6×25 → 6×12 → 0; decréscimo por âncora, não global; teto de 800 por sessão, valor negativo e jogador desconhecido; elite 80 com cooldown de 180 s por jogador; **consolidação** move tudo com recibo idempotente; **morte** segura 0 / PvE 10% / PvP 15%; **cap 200** em saldo grande |
| **QuestService** (9) | aceite no Instrutor marca `quest_hunt_accepted` e abre o tracker; kill antes do aceite não conta; tracker forçado após 90 s e `tick` idempotente; 3º kill completa com +40 XP e `unlock_comet_shoulder`; kill após completo não repete prêmio e alvo fora do objetivo não conta; cadeia sequencial (elite só após a caça); kill do elite completa com +60 XP e `unlock_broken_cadence`; eco da Cadência completa `quest_flow` com +40 XP e `unlock_pulse_return`; roteiro 0–60 min ponta a ponta |
| **SaveService** (7) | leave persiste flags/XP e rejoin restaura; autosave não duplica unlock; rejoin no mesmo servidor devolve a mesma sessão; lock concorrente recusa; falha no load não cria default por cima; anel de `recentOperations` limitado a 32; consolidação gera recibo no perfil |
| **Zonas/fronteira** (13) | join na `zone_bastion_safe` sem PvP; `hold_required`; transição 5 s; hostil encerra proteção; hostil na segura **não** marca lockout; voltar da transição é livre; 5 sinais; `ZoneEvent` completo; lockout 15 s com timer no evento; projétil não cruza; `ZoneEvent` S→C; `ZoneCrossingIntent` C→S; fatia Ready + comet após unlock |

Esses testes cobrem o catálogo, o domínio F0, a **regra** da camada espacial e a lógica pura de input/estado dos controllers. Eles **não** cobrem nada que dependa do runtime Roblox: Instances do HUD, eventos reais de dispositivo, parts que o `WorldService` cria, collision groups, leitura do `HumanoidRootPart`, física, câmera, save real, streaming, arena ou competitivo.

A divisão é deliberada: matemática e decisão ficam em módulos puros (`Geometry`, `Zones`, `SpatialService`, `EnemyService`), e só o `WorldService` toca Instances. Um teste que precisasse de `Vector3` ou `workspace` é sinal de que a regra vazou para a camada errada.

## 4. Arquitetura do harness

- **`tests/harness.luau`** simula o mínimo que o Lune não fornece: `_G.game`, `_G.Instance`, `_G.task` e resolução de `require(script.Parent.X)` no filesystem.
- **`tests/run.luau`** contém os 247 casos e usa módulos reais de `src/`, com um miniframework de asserts.
- **`tests/animation.luau`** contém 73 casos de apresentação procedural, VFX, áudio, juntas, defesa, dash, sinais de fronteira, iluminação do spawn e volume das skins.
- **`tests/security_fuzz.luau`** executa 67 casos determinísticos de envelope, payload aninhado, replay de request e de sequência, rate limit por classe com janela de 1 s, hold de fronteira adulterado e combinações.
- **`tests/combat_e2e.luau`** executa 19 casos que ligam servidor e cliente numa cadeia só: posição → aquisição em cone → resolução → `CombatEvent` → hit-stop, tremida, som, número de dano → `StateDelta`. Leve, pesado e Ombro Cometa cobrem miss longe, acerto perto e guarda. É a suíte que faltava: cada peça tinha teste próprio e a cadeia inteira nunca era exercida.
- **`scripts/ci.sh`** reproduz a ordem de `.github/workflows/ci.yml` no Linux. **`avb-debug home`** imprime o atalho de três passos com o Studio fechado.
- **Services testáveis por injeção** recebem dependências em `init()`: `CatalogService`, `AbilityService`, `ResourceService`, `PlayerSessionService`, `ZoneService`, `ProgressionService`, `QuestService`, `SpatialService`, `EnemyService` e `SaveService` (adaptador de store mockado). O bootstrap Roblox monta o grafo real.
- **`src/shared/TaskCompat.luau`** usa `task` nativo no Roblox e o polyfill somente no harness.

Os módulos de dados declaram tipos inline porque o Lune não resolve `script.Parent` como o Roblox. `src/shared/Types.luau` continua sendo o contrato canônico para tooling, mas a duplicação precisa ser comparada em revisão sempre que o tipo evoluir.

## 5. Evidência por camada

| Camada | O que demonstra | O que não demonstra |
|---|---|---|
| lint + 247 testes Lune | sintaxe, estilo e comportamento unitário coberto no ambiente simulado, incluindo isolamento headless de dois jogadores | física, replicação, UI renderizada, dispositivo ou serviços Roblox reais |
| simulação de combate (19 casos) | a cadeia servidor→cliente reage ao desfecho autoritativo e só a ele; leve, pesado e Cometa só ligam impacto na distância certa | que alguma coisa apareça na tela, o feel do golpe, latência e input real |
| Wally + build Rojo | dependências resolvidas e árvore de projeto montável | que o place abre sem erro ou que um fluxo é jogável |
| Studio | bootstrap, UI/input, câmera, física e replicação no cenário testado | DataStore/teleport/rede pública com fidelidade total |
| publicado privado | serviços reais, múltiplos servidores, reconnect, teleport e condições reais de rede | cobertura de dispositivo que não foi executada |

Uma entrega deve dizer explicitamente quais camadas foram executadas, em vez de resumir tudo como “testado”.

## 6. Casos obrigatórios antes de F1/F2

Os testes abaixo são backlog, não parte dos 205 existentes:

- catálogo rejeita `impactCost` ausente, não inteiro ou fora do intervalo;
- validador de loadout aceita capacidade 4/impacto 12 e rejeita qualquer excesso;
- loadout ativo exige exatamente uma ultimate e aceita no máximo uma técnica normal `defining`;
- `rawD = 3` é válido e `rawD > 3` é rejeitado, sem clamp que transforme o valor em 3;
- técnica estrangeira exige `foreignResourceCost > 0`; fallback neutro não gera recurso da família original e política `Blocked` impede equipar;
- maestria contém exatamente níveis 1–10, breakpoints comportamentais em 3/6/9, bônus numéricos somente em 2/5/8 e soma máxima de 6%;
- normalização competitiva remove bônus numéricos de maestria e preserva apenas variantes permitidas pela versão do snapshot;
- IDs de runner/fallback ausentes derrubam validação, e falha não debita recurso nem inicia cooldown.

## 7. Matriz runtime ainda pendente

> **Atualização 17/08 — sessão de Play executada.** Fecharam em runtime: W1
> completo (boot limpo, spawn, Instrutora, Marco de Retorno, saídas norte/oeste,
> morte/respawn, elite), o passo `a1_impact` (leve/pesado/Ombro Cometa com a
> camada de impacto — hit-stop, tremida, luz, som e número — confirmada a
> olho), W2 (desempenho com MicroProfiler em `stepAnimation`/script/render) e
> R1 (dois clientes, latência simulada, Android e gamepad reais). Permanecem
> pendentes por não dependerem de Play no Studio: DataStore real em place
> privado publicado (session lock entre servidores, reconnect, shutdown),
> telemetria operacional (alertas/dashboards) e o Gate P1 jurídico. Medidas
> numéricas do W2 seguem na ficha `docs/26`.

A spec de execução da fatia (`docs/13-F0-SLICE.md` §19–§21) lista os testes Lune que devem mudar com o catálogo novo e o roteiro Studio. Antes de chamar F0 de jogável ou liberar a fase seguinte, registrar evidência para:

- Studio solo: boot limpo, spawn, três técnicas, morte/respawn, save simulado e desconexão;
- Studio server + pelo menos dois clientes: autoridade de dano/custo/cooldown, latência, spam de remote e estado após morte;
- Android de entrada, telefone mediano, PC integrado e gamepad: input, HUD, câmera, telegraph e orçamento de frame/memória;
- experiência publicada privada: DataStore com session lock, reconnect, shutdown, múltiplos servidores e, quando existir, teleport para Arena Place;
- teste adversarial: payload malformado, alvo/alcance falsos, replay, spam, velocidade e network ownership.

O Play antigo das 09:26 não fecha nenhuma linha desta matriz: ele usou um `.rbxl` anterior. Para registrar Studio solo no estado atual, é obrigatório gerar e abrir o artefato correspondente ao commit `d7c44e8`, conferir a sincronia com `avb-debug sync` e executar o roteiro. Isso ainda não foi feito neste snapshot.

Até essas execuções existirem, a formulação correta é **“esqueleto F0 com testes unitários e build de árvore”**, não “runtime validado”. Para o item 6 especificamente: **comprovado** são as regras de zona/PvP/transição/lockout/sinais como dados + testes Lune; **não comprovado** são geometria no Studio, os 5 sinais visíveis/audíveis, o hold de 0,6 s no toque, iluminação, collision groups reais e playtest cego da fronteira.

Para Input/HUD (entrega 10 da §14; item 12 do backlog): **comprovado** em código/headless são o gate `ready`, a ordem dos sete controllers, o envelope v2, o limite local de 8 intenções/s, teclado/mouse/toque/gamepad como intenções semânticas, soft lock de 8°/25 studs apenas no ataque básico para toque/gamepad, 3 slots com unlock/cooldown, ultimate oculta, feedback localizado, Umbral, zona, objetivo e HUD retangular. **Não comprovado** é o runtime inteiro: criação e layout das Instances, boot/spawn, câmera, toque real, gamepad real, magnetismo percebido, limites de obstrução, cooldown radial renderizado e o roteiro jogável.

Para telemetria/segurança (item 13): **comprovado** em código/headless são schemas fechados por remote, envelope v2 sem campos extras, IDs/enums/vetores finitos, replay por `requestId` e sequência, 8 intenções de combate/s, orçamento default separado, limpeza no leave e `RemoteRejected` sanitizado/amostrado. **Não comprovado** são serialização real do payload em bytes, fuzz/spam através de `RemoteEvent`, teto global, network ownership hostil, alertas/dashboards e comportamento sob dois clientes no Studio.

Para a fundação de mundo/apresentação de `docs/15-WORLD-PRESENTATION.md`: **comprovado** são receitas puras de quatro atores, limites de pose, separação root/Motor6D, expiração de eventos transitórios como código, cache de joints, amostras puras de apresentação do jogador para leve/pesado/guarda/dash, piso derivado dos volumes canônicos, gate `Studio + F0Debug` e exclusão das flags temporárias do save. **Não comprovado** é a fronteira Roblox inteira: as Parts e juntas existirem em Play, os overlays R15/R6 aparecerem corretamente, aparência da iluminação, clipping, colisão, sincronismo com eventos, leitura das duas rotas, performance por frame e qualquer critério de beleza. Os modelos são greybox; nenhum clip R15 final foi produzido.

Para a interação mínima: **comprovado** em código/headless são os dois alvos allowlisted, texto localizado, gate `ready`, payload sem recompensa, distância autoritativa, hold de 1,5 s medido no servidor, revalidação no complete e limpeza no leave. **Não comprovado** são prompts reais, teclado/toque/gamepad, feedback visual, proximidade com Parts replicadas e os efeitos de aceitar objetivo ou consolidar durante um Play atual.

Para o item 7: **comprovado** são o catálogo de objetivos, a máquina de estado do objetivo 1 (oferta → aceite por NPC ou 90 s → progresso → prêmio), o ledger de XP com retorno decrescente por âncora e teto de 800/sessão, o unlock do Ombro Cometa no 3º kill, a validação de Locale no boot e o ciclo completo do Estilhaço (spawn nas 6 âncoras, perseguição, telegraph, respawn, teto de 4). **Não comprovado** são a persistência de XP e flags entre sessões (item 11), o tracker na tela e o `InteractionIntent` disparado por um jogador real.

Para os itens 8–10 (Cadência, elite, Pulso — 2026-08-12): **comprovado** são a Cadência com janela de reentrada de 120 ms após o fim do active do golpe 2 (400 ms), o eco agendado em 350 ms que gera Fluxo +6 (cap 1,5 s, bônus +3 a cada 8 s), o objetivo `quest_flow` creditado pelo eco, o ciclo do Estilhaço Ancorado alternando combo 6+6 e slam 14 (unblockable para o Pulso, guarda cortada em 30%), o leeching (≥ 1% da vida ou 8 s no raio, sem último golpe), o cooldown de XP de 180 s por jogador, a postura do Pulso de 250 ms reduzindo 50% de um golpe frontal, o contra de 10 com empurrão e o erro de postura virando recovery de 600 ms, e a cadeia sequencial de objetivos (caça → elite → timing). **Não comprovado** é tudo que exige Studio: o feeling do hold de reentrada, os ecos visíveis, a cratera do elite, o empurrão físico e a latência do contra.

Para o item 11 (consolidação, morte, ProfileStore — 2026-08-12): **comprovado** são a consolidação no Marco de Retorno movendo todo o não consolidado com recibo `operationId` idempotente, a perda na morte por zona (segura 0, PvE 10%, PvP 15%, cap 200), o `SaveService` com ProfileRoot v1 (session lock, autosave 60–120 s com jitter, release no leave, anel de 32 recibos) e os cinco cenários de `§11.2` cobertos por teste com um adaptador de store mockado. **Não comprovado** é o DataStore real: o ProfileStore só roda no place privado publicado (lock entre servidores de verdade, latência de escrita, shutdown do servidor). O respawn com proteção de 8 s na `anchor_bastion_return` também é Studio.

Para a camada espacial (greybox, hitbox, lunge, AI): **comprovado** é toda a regra — os volumes concordam com as âncoras, a hitbox à frente seleciona um alvo, o lunge respeita 7/8 studs e para na guarda, o lado do golpe se mede da origem do avanço, a perseguição respeita 12 studs/s. **Não comprovado** é qualquer coisa que exija abrir o place: as parts existirem e estarem no lugar certo, os collision groups se comportarem, o `Heartbeat` conseguir ler o personagem, o desempenho do tick de AI com 8 jogadores e o feeling do lunge com latência.

## 8. Checklist de consistência documental

Antes de fechar uma revisão de planejamento:

```bash
rg -n "masteryTiers|5 tiers|tiers 1–5|breakpoints? 2/4" docs
rg -n "min\(3, rawD\)|D = min\(3" docs
rg -n "upgradePity|pity.*forja|forja.*pity" docs
rg -n "recomendação provisória|\| Proposta \|" docs/09-OPEN-QUESTIONS.md
rg -n "\\x{FFFD}" README.md docs
```

Números e nomes de função também precisam bater com o código, porque envelhecem
sozinhos a cada rodada:

```bash
# contagens reais das três suítes (a fonte é a saída, não o que o doc afirma)
lune run tests/run.luau | tail -1
lune run tests/animation.luau | tail -1
lune run tests/security_fuzz.luau | tail -1
rojo build -o build.rbxl && stat -c%s build.rbxl   # bytes citados nos docs

# toda contagem/artefato citado em doc, para conferir de uma vez
rg -n "testes de domínio|testes de animação|casos automatizados|bytes" docs README.md

# função citada em doc que não existe mais no código (foi como o faceAim vazou)
rg -n '`[A-Za-z]+\.[a-zA-Z]+\(' docs | sed 's/.*`\([A-Za-z]*\.[a-zA-Z]*\)(.*/\1/' | sort -u
```

- os quatro primeiros comandos devem ficar sem ocorrência normativa obsoleta; menção histórica só permanece se estiver marcada como revogada;
- `rawD > 3` deve ser inválido em schema, GDD, spec e testes planejados;
- pity pertence somente ao loot pessoal de boss, nunca à forja;
- maestria usa níveis 1–10, breakpoints 3/6/9 e ganho numérico total máximo de 6%;
- todos os documentos devem distinguir decisão aprovada, baseline de playtest, implementação existente e gate ainda pendente;
- revisar UTF-8, links, tabelas, âncoras e referências cruzadas após renomear seções;
- confirmar a terminologia transversal: RPG / Action RPG, três presets gratuitos e seis máximos, soft launch Brasil-first e território/F7 pós-lançamento.

## 9. Pitfalls conhecidos

- `task.wait` real em teste cria loop infinito se o polyfill síncrono for usado no `spawn`; o harness injeta `spawn = noop` para o loop de regen. `ZoneService` usa relógio injetado (`fakeNow`), nunca `task.wait`, para as janelas de 5 s e 15 s.
- Busy-wait curto com `os.clock` substitui `task.wait` nos testes de expiração de cooldown.
- Selene permite `global_usage` e `empty_loop` no `selene.toml` porque o harness usa `_G` e busy-waits deliberadamente.
- Contar casos pelo resumo pode mascarar erro: a fonte é a quantidade real de chamadas `test(...)` em `tests/run.luau`; nesta versão são 247.
- Lua patterns não têm alternação (`a|b` é literal): validar IDs de sinal por pertencimento a uma tabela, não com regex no teste.
- Quirk do Lune/MLua: closure auto-referente (`local x = { fn = function() ... x ... end }`) vê `x` como nil dentro da função. Declarar a variável antes (`local x; x = { ... }`) ou o mock do SaveService quebra com "attempt to index nil".
- **Forward reference quebra o Selene no CI.** Chamar uma `local function` antes da linha em que ela é definida passa em Lua e é erro de lint. Aconteceu em 13/08 com `buildSpawnDecorations`: mover a função para antes de quem a chama (e passar dependência por parâmetro) é o conserto.
- **`selene ... | tail -1` esconde o erro.** O resumo final ("Results:") sai depois dos diagnósticos, então cortar a saída mostra "0 errors" de uma execução que falhou. Ler as últimas ~5 linhas, ou nenhuma.
- **Teste headless não pega defeito de anexo.** Toda a classe de bug de `docs/14` §4.7 (rig R15 ausente no `CharacterAdded`, cache de junta congelado vazio, `Trail` nulo permanente) tem função pura verde: o que faltava era alguém aplicar a pose. Verificação dessa camada sai da parte materializada em Play, nunca do dado que alimenta a pose.
- **Número que mora na camada de Instances escapa de toda regra.** Em 17/08 a Instrutora estava nascendo dentro de um pilar. A regra "nada sólido a menos de 2 studs de uma âncora" já existia em `SpawnDecorations.validate` desde sempre — mas os quatro pilares-marco eram uma tabela `local` dentro do `buildWalls`, e o que o teste não enxerga, a regra não protege. O conserto não foi mexer no validador: foi mover as posições para dado (`SpawnDecorations.bastionPillars`) e deixar o `WorldService` só materializar. Antes de escrever coordenada em função de build, perguntar qual regra deixa de valer sobre ela.
- **Teste que copia o dado à mão para de testar o dado.** Os dois casos de âncora do spawn traziam `{ x = 20, z = -14 }` escrito na fixture embora o nome dissesse "com os dados reais do Zones". Mover a âncora no catálogo não movia o teste: ele seguia verde conferindo um número fóssil. Fixture de dado canônico lê do módulo (`Zones.getAnchor`), não transcreve.
- **Silhueta não é só geometria: valor é requisito.** A skin feminina da Instrutora entrou completa e o playtest relatou "não mudou nada" — corretamente, porque cabelo, saia e casaco tinham luminância 30, 27 e 41. Peça modelada e pintada com o mesmo valor da vizinha não existe na tela, e nenhum teste de densidade ou de contagem de peças pega isso. `Presentation.validatePalette` trava a escada de valor; ver `docs/28` §"Escada de valor".
- **`stylua --check` reprova o repo inteiro neste Windows.** `stylua.toml` fixa `line_endings = "Unix"` e o git local está com `core.autocrlf = true`: a working tree fica CRLF e todo arquivo aparece como diff completo, inclusive os que ninguém tocou. Não é regressão — o CI roda em Linux com checkout LF e passa. Saídas: `git config core.autocrlf false` seguido de recheckout, ou conferir a formatação numa cópia com LF antes de confiar no resultado local.


## 10. Protocolo visual baseado em referências

As imagens do pacote de combate e da expansão de domínio são referências de comparação, não provas de runtime. O índice na raiz (`VISUAL-REFERENCE-INDEX.md`) relaciona cada PNG aos sistemas, documentos e gates correspondentes. O protocolo reproduzível de captura, critérios e registro de divergências está em `docs/26-VISUAL-VALIDATION-CHECKLIST.md`.

A validação visual deve registrar commit do build, SHA-256 do `.rbxl`, referência usada, plataforma, resolução, preset, FPS/frame time, câmera, sequência de inputs, capturas sem VFX e com efeitos reduzidos, divergências observáveis e decisão. Defesa, dash e chão quebrando possuem critérios específicos: postura e retorno ao neutro; quatro fases da corrida; e sequência de marcação, anel, crack, poeira/debris e dissipação.

Os testes headless podem comprovar fases, amplitudes, duração, raio, envelopes e ausência de mutação da raiz física. Eles não comprovam foot sliding, clipping, legibilidade, colisão, câmera, replicação, latência real ou desempenho em Android. Esses itens permanecem gates A1/W1/R1/W2 no Roblox Studio.

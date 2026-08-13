# 12 — Testes e evidências

> **Snapshot:** 2026-08-12. `tests/run.luau` declara 133 testes F0 alinhados a `docs/13-F0-SLICE.md`. O commit `1f17de0` cobria 124 testes (itens 8–10); esta revisão acrescenta o item 11 — consolidação de XP, perda na morte e ProfileStore (ProfileRoot v1 com session lock e autosave).

## 1. Estado da execução

Em 2026-08-12, no acer (Linux), foram executados: Selene 0.31.0 (0 erros, 0 warnings); StyLua 2.5.2 (0 diffs); 133 testes Lune 0.10.5 (0 falhas); `rojo build -o /tmp/avb-build.rbxl` (exit 0).

Essa evidência valida a **regra** espacial: distância, lado do golpe, cápsula do trajeto, avanço de 7 studs com cap 8 e parada na guarda, perseguição a 12 studs/s, telegraph de 400 ms, respawn de 45 s e coerência entre os volumes do greybox e todas as âncoras.

Ela **não** valida a **execução**. O `WorldService` constrói o mundo por código e nunca rodou: nenhuma part foi vista, nenhum collision group foi exercitado, nenhum `HumanoidRootPart` foi lido. A afirmação honesta desta revisão é "a camada espacial existe, é coerente e é testada headless" — não "o greybox está no Studio".

## 1. Gates reproduzíveis

Depois de instalar o toolchain, a verificação completa do repositório é:

```bash
aftman install
stylua --check src tests
selene src tests
lune run tests/run.luau
wally install
mkdir -p Packages
rojo build -o build.rbxl
```

O CI executa StyLua, Selene, os testes Lune, a instalação Wally e o build Rojo em todo pull request e em pushes para `main` (`.github/workflows/ci.yml`). Cada resultado precisa registrar commit, ambiente e saída; “verde no CI” não significa “testado no runtime Roblox”. O `.rbxl` gerado pelo Rojo é artefato de validação da árvore, não prova de jogabilidade.

Em checkout Windows com `core.autocrlf=true`, os arquivos de trabalho podem estar em CRLF enquanto `stylua.toml` exige `Unix`; nesse caso, o check direto acusa somente final de linha. Para reproduzir o CI, use uma cópia com bytes LF canônicos do Git (`git -c core.autocrlf=false archive ...`) ou execute o diagnóstico local equivalente com `stylua --check --line-endings Windows src tests`. Não reformatar código só para mascarar essa conversão do checkout.

## 2. Cobertura existente: exatamente 133 testes

| Área | Cobertura |
|---|---|
| **Dados** (13) | Punho do Eclipse 3+1; `comet_shoulder`; Umbral baseline; 4 famílias; remotes incl. `SessionSnapshot`, `InteractionIntent`, `StateDelta` e `EnemyEvent`; dummy 10000 HP / dano 4; Estilhaço Errante 40/6/4; zonas: 3 zonas, PvP só na livre, âncoras persistidas + pontos de Estilhaço, spawn no bastião; Locale PT-BR/EN das chaves §16 e formatação de `{n}`; `quest_hunt` 3 kills / +40 XP / unlock Cometa |
| **Geometria** (5) | distância no plano ignora altura; normalize de vetor nulo não vira NaN; costas vs. frente vs. perpendicular; cápsula do trajeto dentro/fora do raio e além do fim; lunge de 7 com cap 8 e parada antes do contato; `moveToward` a 12 studs/s parando no alcance |
| **Greybox** (2) | o volume de cada zona resolve a zona declarada por todas as âncoras, o plano do portão resolve como transição e fora de todo volume devolve nil; 6 pontos de Estilhaço ≥ 24 studs entre si e ≥ 20 dos portões |
| **SpatialService** (4) | hitbox à frente acerta 1 e ignora quem está atrás/longe; Ombro Cometa avança 7, commita a posição e acerta 1 alvo na cápsula; guarda inimiga trava o avanço; avanço sem alvo é resultado válido |
| **EnemyService** (5 + elite 3) | spawn até o teto de 4 com a âncora no id e sem duplicar; persegue, para no alcance, telegraph de 400 ms sem dano e 6 depois; sem aggro para jogador na zona segura; respawn de 45 s bloqueado por jogador a menos de 20 studs; kill reporta âncora e autor; **elite**: spawn único na `anchor_elite`; leeching por dano ≥ 1% na morte; leeching por 8 s no raio sem dano |
| **CooldownService** (3) | inicia zerado; `start` aplica e expira; `clear` zera |
| **CombatService** (27) | applyDamage legado; cadeia 5+5+6+10; reset 0,65 s; guarda 40%; aparo 120 ms; costas; pesado 10/28/2; quebra+overflow; miss bloqueia leve; dash i-frame/CD; dummy alcance/período; comet 9 aberto; guarda para avanço (4 HP + 9 guarda); aparo; i-frame; Estilhaço telegraph+dano 6; sem aggro na fronteira; alcance 4; recovery; respawn 45 s; cap 4 vivos; `killed` só na transição vivo → morto e `diedAt` não é re-carimbado; **elite**: ciclo alterna combo 5+5 e slam 12; slam na guarda corta 30%; Pulso na postura reduz 50% e consome a postura |
| **ResourceService** (6) | pool; `trySpend`; `grantFlowGain`; família desconhecida; `tryGrantFlow` 6+3 e cap 1,5 s; regen 2 / atraso 3 s / 6 |
| **AbilityService** (14) | Ombro Cometa em `ServerPlayerState`; recusas; ultimate `disabled`; `locked`; Cadência 5+6, janela de reentrada e eco 4 no tick com Fluxo; Pulso: postura sem dano → erro vira recovery 600 ms; postura reduz 50% + contra 8; costas e slam do elite vencem a postura; comet no fighter dummy + `CombatHit` |
| **CatalogService** (6) | dados reais (incl. dummy, instrutor e cadeia de objetivos); personagem sem habilidade falha; zona/âncora inválida falha; objetivo com alvo/ofertante desconhecido, `requiredCount = 0` ou `acceptFlag` vazia falha; `displayNameKey` sem entrada no Locale falha; âncora que declara uma zona mas cai no volume de outra falha |
| **PlayerSessionService / fatia** (4) | join/leave; snapshot Ready sem unlocks e, após grant, lista `unlock_comet_shoulder`; join Ready → comet `locked` até grant, depois 18 Umbral e dummy 9991 HP; roteiro 0–5 min ponta a ponta (aceite → travessia → 3 kills → 115 XP → Cometa liberado) |
| **ProgressionService** (11) | cadência/pulso locked no spawn; grant comet idempotente e flag desconhecida recusa; leave limpa flags; kill do Estilhaço credita 25 e dummy não credita; retorno decrescente 6×25 → 6×12 → 0; decréscimo por âncora, não global; teto de 800 por sessão, valor negativo e jogador desconhecido; elite 80 com cooldown de 180 s por jogador; **consolidação** move tudo com recibo idempotente; **morte** segura 0 / PvE 10% / PvP 15%; **cap 200** em saldo grande |
| **QuestService** (9) | aceite no Instrutor marca `quest_hunt_accepted` e abre o tracker; kill antes do aceite não conta; tracker forçado após 90 s e `tick` idempotente; 3º kill completa com +40 XP e `unlock_comet_shoulder`; kill após completo não repete prêmio e alvo fora do objetivo não conta; cadeia sequencial (elite só após a caça); kill do elite completa com +60 XP e `unlock_broken_cadence`; eco da Cadência completa `quest_flow` com +40 XP e `unlock_pulse_return`; roteiro 0–60 min ponta a ponta |
| **SaveService** (7) | leave persiste flags/XP e rejoin restaura; autosave não duplica unlock; rejoin no mesmo servidor devolve a mesma sessão; lock concorrente recusa; falha no load não cria default por cima; anel de `recentOperations` limitado a 32; consolidação gera recibo no perfil |
| **Zonas/fronteira** (13) | join na `zone_bastion_safe` sem PvP; `hold_required`; transição 5 s; hostil encerra proteção; hostil na segura **não** marca lockout; voltar da transição é livre; 5 sinais; `ZoneEvent` completo; lockout 15 s com timer no evento; projétil não cruza; `ZoneEvent` S→C; `ZoneCrossingIntent` C→S; fatia Ready + comet após unlock |

Esses testes cobrem o catálogo, o domínio F0 e a **regra** da camada espacial. Eles **não** cobrem nada que dependa do runtime Roblox: as parts que o `WorldService` cria, collision groups reais, leitura do `HumanoidRootPart`, física, câmera, HUD, os 5 sinais visíveis/audíveis, hold 0,6 s no toque, save real, streaming, arena ou competitivo.

A divisão é deliberada: matemática e decisão ficam em módulos puros (`Geometry`, `Zones`, `SpatialService`, `EnemyService`), e só o `WorldService` toca Instances. Um teste que precisasse de `Vector3` ou `workspace` é sinal de que a regra vazou para a camada errada.

## 3. Arquitetura do harness

- **`tests/harness.luau`** simula o mínimo que o Lune não fornece: `_G.game`, `_G.Instance`, `_G.task` e resolução de `require(script.Parent.X)` no filesystem.
- **`tests/run.luau`** contém os 133 casos e usa módulos reais de `src/`, com um miniframework de asserts.
- **Services testáveis por injeção** recebem dependências em `init()`: `CatalogService`, `AbilityService`, `ResourceService`, `PlayerSessionService`, `ZoneService`, `ProgressionService`, `QuestService`, `SpatialService`, `EnemyService` e `SaveService` (adaptador de store mockado). O bootstrap Roblox monta o grafo real.
- **`src/shared/TaskCompat.luau`** usa `task` nativo no Roblox e o polyfill somente no harness.

Os módulos de dados declaram tipos inline porque o Lune não resolve `script.Parent` como o Roblox. `src/shared/Types.luau` continua sendo o contrato canônico para tooling, mas a duplicação precisa ser comparada em revisão sempre que o tipo evoluir.

## 4. Evidência por camada

| Camada | O que demonstra | O que não demonstra |
|---|---|---|
| lint + 133 testes Lune | sintaxe, estilo e comportamento unitário coberto no ambiente simulado | física, replicação, UI, input ou serviços Roblox reais |
| Wally + build Rojo | dependências resolvidas e árvore de projeto montável | que o place abre sem erro ou que um fluxo é jogável |
| Studio | bootstrap, UI/input, câmera, física e replicação no cenário testado | DataStore/teleport/rede pública com fidelidade total |
| publicado privado | serviços reais, múltiplos servidores, reconnect, teleport e condições reais de rede | cobertura de dispositivo que não foi executada |

Uma entrega deve dizer explicitamente quais camadas foram executadas, em vez de resumir tudo como “testado”.

## 5. Casos obrigatórios antes de F1/F2

Os testes abaixo são backlog, não parte dos 133 existentes:

- catálogo rejeita `impactCost` ausente, não inteiro ou fora do intervalo;
- validador de loadout aceita capacidade 4/impacto 12 e rejeita qualquer excesso;
- loadout ativo exige exatamente uma ultimate e aceita no máximo uma técnica normal `defining`;
- `rawD = 3` é válido e `rawD > 3` é rejeitado, sem clamp que transforme o valor em 3;
- técnica estrangeira exige `foreignResourceCost > 0`; fallback neutro não gera recurso da família original e política `Blocked` impede equipar;
- maestria contém exatamente níveis 1–10, breakpoints comportamentais em 3/6/9, bônus numéricos somente em 2/5/8 e soma máxima de 6%;
- normalização competitiva remove bônus numéricos de maestria e preserva apenas variantes permitidas pela versão do snapshot;
- IDs de runner/fallback ausentes derrubam validação, e falha não debita recurso nem inicia cooldown.

## 6. Matriz runtime ainda pendente

A spec de execução da fatia (`docs/13-F0-SLICE.md` §19–§21) lista os testes Lune que devem mudar com o catálogo novo e o roteiro Studio. Antes de chamar F0 de jogável ou liberar a fase seguinte, registrar evidência para:

- Studio solo: boot limpo, spawn, três técnicas, morte/respawn, save simulado e desconexão;
- Studio server + pelo menos dois clientes: autoridade de dano/custo/cooldown, latência, spam de remote e estado após morte;
- Android de entrada, telefone mediano, PC integrado e gamepad: input, HUD, câmera, telegraph e orçamento de frame/memória;
- experiência publicada privada: DataStore com session lock, reconnect, shutdown, múltiplos servidores e, quando existir, teleport para Arena Place;
- teste adversarial: payload malformado, alvo/alcance falsos, replay, spam, velocidade e network ownership.

Até essas execuções existirem, a formulação correta é **“esqueleto F0 com testes unitários e build de árvore”**, não “runtime validado”. Para o item 6 especificamente: **comprovado** são as regras de zona/PvP/transição/lockout/sinais como dados + testes Lune; **não comprovado** são geometria no Studio, os 5 sinais visíveis/audíveis, o hold de 0,6 s no toque, iluminação, collision groups reais e playtest cego da fronteira.

Para o item 7: **comprovado** são o catálogo de objetivos, a máquina de estado do objetivo 1 (oferta → aceite por NPC ou 90 s → progresso → prêmio), o ledger de XP com retorno decrescente por âncora e teto de 800/sessão, o unlock do Ombro Cometa no 3º kill, a validação de Locale no boot e o ciclo completo do Estilhaço (spawn nas 6 âncoras, perseguição, telegraph, respawn, teto de 4). **Não comprovado** são a persistência de XP e flags entre sessões (item 11), o tracker na tela e o `InteractionIntent` disparado por um jogador real.

Para os itens 8–10 (Cadência, elite, Pulso — 2026-08-12): **comprovado** são a Cadência com janela de reentrada de 120 ms após o fim do active do golpe 2 (400 ms), o eco agendado em 350 ms que gera Fluxo +6 (cap 1,5 s, bônus +3 a cada 8 s), o objetivo `quest_flow` creditado pelo eco, o ciclo do Estilhaço Ancorado alternando combo 5+5 e slam 12 (unblockable para o Pulso, guarda cortada em 30%), o leeching (≥ 1% da vida ou 8 s no raio, sem último golpe), o cooldown de XP de 180 s por jogador, a postura do Pulso de 250 ms reduzindo 50% de um golpe frontal, o contra de 8 com empurrão e o erro de postura virando recovery de 600 ms, e a cadeia sequencial de objetivos (caça → elite → timing). **Não comprovado** é tudo que exige Studio: o feeling do hold de reentrada, os ecos visíveis, a cratera do elite, o empurrão físico e a latência do contra.

Para o item 11 (consolidação, morte, ProfileStore — 2026-08-12): **comprovado** são a consolidação no Marco de Retorno movendo todo o não consolidado com recibo `operationId` idempotente, a perda na morte por zona (segura 0, PvE 10%, PvP 15%, cap 200), o `SaveService` com ProfileRoot v1 (session lock, autosave 60–120 s com jitter, release no leave, anel de 32 recibos) e os cinco cenários de `§11.2` cobertos por teste com um adaptador de store mockado. **Não comprovado** é o DataStore real: o ProfileStore só roda no place privado publicado (lock entre servidores de verdade, latência de escrita, shutdown do servidor). O respawn com proteção de 8 s na `anchor_bastion_return` também é Studio.

Para a camada espacial (greybox, hitbox, lunge, AI): **comprovado** é toda a regra — os volumes concordam com as âncoras, a hitbox à frente seleciona um alvo, o lunge respeita 7/8 studs e para na guarda, o lado do golpe se mede da origem do avanço, a perseguição respeita 12 studs/s. **Não comprovado** é qualquer coisa que exija abrir o place: as parts existirem e estarem no lugar certo, os collision groups se comportarem, o `Heartbeat` conseguir ler o personagem, o desempenho do tick de AI com 8 jogadores e o feeling do lunge com latência.

## 7. Checklist de consistência documental

Antes de fechar uma revisão de planejamento:

```bash
rg -n "masteryTiers|5 tiers|tiers 1–5|breakpoints? 2/4" docs
rg -n "min\(3, rawD\)|D = min\(3" docs
rg -n "upgradePity|pity.*forja|forja.*pity" docs
rg -n "recomendação provisória|\| Proposta \|" docs/09-OPEN-QUESTIONS.md
rg -n "\\x{FFFD}" README.md docs
```

- os quatro primeiros comandos devem ficar sem ocorrência normativa obsoleta; menção histórica só permanece se estiver marcada como revogada;
- `rawD > 3` deve ser inválido em schema, GDD, spec e testes planejados;
- pity pertence somente ao loot pessoal de boss, nunca à forja;
- maestria usa níveis 1–10, breakpoints 3/6/9 e ganho numérico total máximo de 6%;
- todos os documentos devem distinguir decisão aprovada, baseline de playtest, implementação existente e gate ainda pendente;
- revisar UTF-8, links, tabelas, âncoras e referências cruzadas após renomear seções;
- confirmar a terminologia transversal: RPG / Action RPG, três presets gratuitos e seis máximos, soft launch Brasil-first e território/F7 pós-lançamento.

## 8. Pitfalls conhecidos

- `task.wait` real em teste cria loop infinito se o polyfill síncrono for usado no `spawn`; o harness injeta `spawn = noop` para o loop de regen. `ZoneService` usa relógio injetado (`fakeNow`), nunca `task.wait`, para as janelas de 5 s e 15 s.
- Busy-wait curto com `os.clock` substitui `task.wait` nos testes de expiração de cooldown.
- Selene permite `global_usage` e `empty_loop` no `selene.toml` porque o harness usa `_G` e busy-waits deliberadamente.
- Contar casos pelo resumo pode mascarar erro: a fonte é a quantidade real de chamadas `test(...)` em `tests/run.luau`; nesta versão são 133.
- Lua patterns não têm alternação (`a|b` é literal): validar IDs de sinal por pertencimento a uma tabela, não com regex no teste.
- Quirk do Lune/MLua: closure auto-referente (`local x = { fn = function() ... x ... end }`) vê `x` como nil dentro da função. Declarar a variável antes (`local x; x = { ... }`) ou o mock do SaveService quebra com "attempt to index nil".

# 12 — Testes e evidências

> **Snapshot:** 2026-08-12. `tests/run.luau` declara 61 testes F0 alinhados a `docs/13-F0-SLICE.md`. O HEAD anterior cobria 49 testes de sessão/combate universal/Ombro Cometa; isso não certifica o worktree atual.
> **Limite da evidência:** não há prova registrada de execução no Roblox Studio, servidor publicado privado, Android, gamepad ou múltiplos clientes reais.

### Evidência local desta revisão

Em 2026-08-12, no worktree Windows, foram executados: Selene 0.31.0 (0 erros); StyLua 2.5.2 com `--line-endings Windows` nos arquivos alterados; 61 testes Lune 0.10.5; build Rojo da árvore. Todos passaram. Essa evidência valida o domínio headless de sessão, combate universal, Ombro Cometa contra o dummy e as regras de zona/PvP/transição/lockout/sinais da fronteira (item 6 do backlog); não substitui o CI do commit nem playtest no Studio. A geometria do greybox (parts, volumes de transição e collision groups `Safe`/`Transition`/`Free`/`GateBlock`), os 5 sinais visíveis/audíveis e o hold de 0,6 s no toque continuam **não comprovados**.

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

## 2. Cobertura existente: exatamente 61 testes

| Área | Cobertura |
|---|---|
| **Dados** (7) | Punho do Eclipse 3+1; `comet_shoulder`; Umbral baseline; 4 famílias; remotes incl. `SessionSnapshot`; dummy 10000 HP / dano 4; zonas: 3 zonas, PvP só na livre, 6 âncoras, spawn no bastião |
| **CooldownService** (3) | inicia zerado; `start` aplica e expira; `clear` zera |
| **CombatService** (17) | applyDamage legado; cadeia 5+5+6+10; reset 0,65 s; guarda 40%; aparo 120 ms; costas; pesado 10/28/2; quebra+overflow; miss bloqueia leve; dash i-frame/CD; dummy alcance/período; comet 9 aberto; guarda para avanço (4 HP + 9 guarda); aparo; i-frame |
| **ResourceService** (6) | pool; `trySpend`; `grantFlowGain`; família desconhecida; `tryGrantFlow` 6+3 e cap 1,5 s; regen 2 / atraso 3 s / 6 |
| **AbilityService** (12) | Ombro Cometa em `ServerPlayerState`; recusas; ultimate `disabled`; `locked`; Cadência+Fluxo; Pulso; comet no fighter dummy + `CombatHit` |
| **CatalogService** (3) | dados reais (incl. dummy); personagem sem habilidade falha; zona/âncora inválida falha validação |
| **PlayerSessionService / fatia** (3) | join/leave; snapshot Ready na zona segura com dummy e sem unlocks; join Ready → comet gasta 18 e dummy fica em 9991 HP |
| **Zonas/fronteira** (10) | join na `zone_bastion_safe` sem PvP; `hold_required` sem confirmação; transição 5 s com hold (`canPvp` false); ação hostil encerra a proteção; 5 sinais juntos ao cruzar; evento `ZoneEvent` com payload completo; lockout 15 s bloqueia reentrada e libera depois; projétil/área não cruza a fronteira; `ZoneEvent` registrado S→C; fatia Ready com `ZoneService` + comet intacto |

Esses testes cobrem o catálogo e o domínio F0 atualmente implementados. Eles não cobrem hitbox espacial, lunge de 7 studs, geometria do mapa no Studio, volumes de transição, collision groups reais, HUD, os 5 sinais visíveis/audíveis, save real, streaming, arena ou competitivo.

## 3. Arquitetura do harness

- **`tests/harness.luau`** simula o mínimo que o Lune não fornece: `_G.game`, `_G.Instance`, `_G.task` e resolução de `require(script.Parent.X)` no filesystem.
- **`tests/run.luau`** contém os 61 casos e usa módulos reais de `src/`, com um miniframework de asserts.
- **Services testáveis por injeção** recebem dependências em `init()`: `CatalogService`, `AbilityService`, `ResourceService`, `PlayerSessionService` e `ZoneService` (relógio `now` injetado; sem `task.wait` real). O bootstrap Roblox monta o grafo real.
- **`src/shared/TaskCompat.luau`** usa `task` nativo no Roblox e o polyfill somente no harness.

Os módulos de dados declaram tipos inline porque o Lune não resolve `script.Parent` como o Roblox. `src/shared/Types.luau` continua sendo o contrato canônico para tooling, mas a duplicação precisa ser comparada em revisão sempre que o tipo evoluir.

## 4. Evidência por camada

| Camada | O que demonstra | O que não demonstra |
|---|---|---|
| lint + 61 testes Lune | sintaxe, estilo e comportamento unitário coberto no ambiente simulado | física, replicação, UI, input ou serviços Roblox reais |
| Wally + build Rojo | dependências resolvidas e árvore de projeto montável | que o place abre sem erro ou que um fluxo é jogável |
| Studio | bootstrap, UI/input, câmera, física e replicação no cenário testado | DataStore/teleport/rede pública com fidelidade total |
| publicado privado | serviços reais, múltiplos servidores, reconnect, teleport e condições reais de rede | cobertura de dispositivo que não foi executada |

Uma entrega deve dizer explicitamente quais camadas foram executadas, em vez de resumir tudo como “testado”.

## 5. Casos obrigatórios antes de F1/F2

Os testes abaixo são backlog, não parte dos 61 existentes:

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
- Contar casos pelo resumo pode mascarar erro: a fonte é a quantidade real de chamadas `test(...)` em `tests/run.luau`; nesta versão são 61.
- Lua patterns não têm alternação (`a|b` é literal): validar IDs de sinal por pertencimento a uma tabela, não com regex no teste.

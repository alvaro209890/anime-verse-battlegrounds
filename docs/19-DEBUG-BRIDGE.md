# 19 — Debug Bridge: plugins de Studio para agentes

Criado em 2026-08-13. Doc canônico do plugin `AvbDebug` e da ponte local que
deixa **qualquer agente** (Claude Code, Cursor, Codex, Grok, ou você no
terminal) inspecionar o Roblox Studio sem ninguém copiar texto do Output.

O problema que isso resolve: até aqui, tudo que acontecia dentro do Studio era
invisível para o agente. Os testes Lune cobrem funções puras; Instances, boot do
servidor, greybox materializado e erros de runtime só apareciam se o humano
tirasse print ou colasse o Output. A ponte fecha esse buraco.

## 1. Arquitetura

```
agente  ──►  scripts/avb-debug.luau   (CLI, Lune)
                    │  HTTP 127.0.0.1:34873
                    ▼
             scripts/debug-bridge.luau (ponte, Lune) ──►  .avb-debug/studio-log.jsonl
                    ▲                    │
       resultado    │                    │ fila de comandos
                    │                    ▼
             plugin AvbDebug no Roblox Studio  (poll a cada 0,5 s)
```

- O plugin **puxa** comandos (poll HTTP saindo do Studio); nada entra no Studio
  sem ele pedir.
- Só existe tráfego em `127.0.0.1`. A ponte não fala com a internet, não guarda
  credencial e não abre porta externa.
- O Output do Studio (edit **e** playtest, server + client) é capturado por
  `LogService` e empurrado para `.avb-debug/studio-log.jsonl`.

## 2. Instalação (uma vez)

```powershell
$env:PATH = "$env:USERPROFILE\.aftman\bin;$env:PATH"
cd C:\GIS\anime-verse-battlegrounds
.\scripts\install-plugin.ps1
```

O script compila `plugins/AvbDebug/plugin.project.json` com Rojo e escreve
`AvbDebug.rbxm` em `%LOCALAPPDATA%\Roblox\Plugins`. **Feche e reabra o Studio**
na primeira instalação (o Studio só varre a pasta de plugins no boot). Depois de
alterar o código do plugin, rode o script de novo e reabra o Studio.

Na primeira execução o Studio pede autorização de HTTP para o plugin — aceite.
Plugins podem usar `HttpService` mesmo com "Allow HTTP Requests" desligado no
place, então não é preciso mexer em `GameSettings`.

## 3. Uso no dia a dia

Terminal 1 (deixa rodando enquanto trabalha):

```bash
lune run scripts/debug-bridge.luau
```

Terminal 2 (o agente):

```bash
lune run scripts/avb-debug.luau health          # a ponte está de pé? o Studio conectou?
lune run scripts/avb-debug.luau ping            # place, modo (edit/play), F0Debug, greybox
lune run scripts/avb-debug.luau errors          # só os erros do Output
lune run scripts/avb-debug.luau sync            # o Studio está rodando o código do repo?
lune run scripts/avb-debug.luau home            # 3 passos para o PC de casa (Studio fechado)
lune run scripts/avb-debug.luau runbook         # roteiro W1/A1/W2, também sem Studio
```

Toda saída é JSON no stdout. Exit code: `0` ok, `1` falha, `2` fora de sync.

No Studio há três botões na barra **AVB Debug**: `Painel` (status da ponte +
cauda do Output), `Ponte` (liga/desliga o poll) e `Greybox` (validação sem
agente nenhum, resultado no Output).

## 4. Comandos

### Rodam no Studio (via plugin)

| Comando | O que faz |
|---|---|
| `ping` | contexto: place, `IsRunning`/`IsEdit`, atributo `F0Debug`, se `GreyboxF0` existe, jogadores |
| `tree <path> [--depth N] [--attributes] [--class C]` | hierarquia serializada (posição/tamanho de `BasePart`, pivot de `Model`) |
| `find <path> --name X --class C --attr A [--limit N]` | busca em descendentes com atributos |
| `props <path> [--keys ...]` | propriedades legíveis + atributos + filhos |
| `source <path> [--from N] [--to N]` | `Source` do script **como está no Studio** |
| `sourcemap` | hash FNV-1a de todos os scripts das três raízes (base do `sync`) |
| `select <path>` | seleciona no Explorer (útil para dirigir o humano) |
| `players` | jogadores, posição, vida do Humanoid, atributos |
| `perf` | contagem de Instances/parts, memória e heartbeat (Stats) |
| `greybox` | validação do spawn: dados **e** mundo materializado (§5) |
| `remotes` | remotes vivos × contratos de `src/shared/Remotes.luau` |
| `studiologs` / `studioerrors` | buffer do plugin (inclui o Output anterior à conexão) |
| `eval "<luau>"` | executa Luau no contexto do plugin (§6) |
| `list` | lista os comandos disponíveis naquele plugin |

### Rodam local (não dependem do Studio responder)

| Comando | O que faz |
|---|---|
| `health` | estado da ponte, se o Studio está conectado, se `eval` está liberado |
| `logs [--level error\|warning\|output] [--limit N]` | Output já empurrado para a ponte |
| `errors` | atalho de `logs --level error` |
| `tail [--limit N]` | lê `.avb-debug/studio-log.jsonl` direto do disco |
| `sync` | compara os hashes do Studio com os arquivos do repo |

Flags gerais: `--port`, `--timeout`, `--raw` (envelope completo do plugin).

## 5. Receitas

**"Corrigi o código e nada mudou no Play"** — quase sempre o Studio está com um
snapshot velho (`build não é Play`, ver README):

```bash
lune run scripts/avb-debug.luau sync
```

Saída lista `mismatched` (arquivo por arquivo, hash do repo × hash do Studio) e
`missingInStudio`. Exit code 2 = fora de sync → rodar `scripts/build-studio.ps1`
e reabrir o place.

Essa é a primeira pergunta, não a última. Em 2026-08-14 três commits de animação
foram dados como quebrados quando o problema era o Studio estar com um place
paralelo, anterior aos três: o `PlayerCombatAnimator` carregado tinha 1455 linhas
contra 1559 no disco, sem `lightChainImpact` nem `rootForwardStuds`, e o catálogo
de clipes ainda trazia 7 entradas onde o repositório já tinha zero. Diagnóstico
sem essa checagem gasta a sessão inteira consertando o que já estava certo. Um
sintoma barato, sem ponte: no Client, `require` do módulo e teste de um símbolo
que só existe depois do commit em questão.

**"O playtest quebrou"**:

```bash
lune run scripts/avb-debug.luau errors --limit 30
lune run scripts/avb-debug.luau source ServerScriptService.Server.Services.CombatService --from 120 --to 160
```

**"A decoração do spawn está estranha"** — `greybox` roda a mesma validação pura
dos testes Lune (`SpawnDecorations.validate` contra os volumes reais do `Zones`)
**e** compara cada receita com a Part materializada no `Workspace`, reportando
`drift` (posição/tamanho ≠ dado), `missingParts` e `missingAnchors`. Só faz o
lado do mundo durante um playtest: `GreyboxF0` é construído pelo `WorldService`
no boot do servidor, não existe em modo edição.

**"O inimigo não aparece / a barra não atualiza"**:

```bash
lune run scripts/avb-debug.luau find Workspace.GreyboxF0.Actors --attr CombatTarget
lune run scripts/avb-debug.luau players
lune run scripts/avb-debug.luau remotes
```

## 6. `eval` — poder e limite

`eval` compila e roda Luau no contexto do plugin (`print` é capturado e volta no
JSON). Duas travas:

1. Depende de `ServerScriptService.LoadStringEnabled = true`. Sem isso o comando
   falha com mensagem explícita; `--enableLoadstring` liga a propriedade em modo
   edição.
2. A ponte pode subir com `--no-eval`, e aí o comando é recusado com HTTP 403.

Como é execução de código arbitrário vinda de uma porta local, suba a ponte só
enquanto estiver desenvolvendo. Ela morre com Ctrl+C.

## 7. Limites conhecidos

- O plugin **não** consegue apertar Play/Stop: não existe API de plugin para
  iniciar playtest. O humano continua dando F5.
- Não há screenshot: a captura visual continua sendo vídeo/print manual
  (`docs/18-ANALISE-VIDEO.md`).
- `require` de módulos do jogo (usado por `greybox` e `remotes`) roda no contexto
  do plugin; módulos que dependem de estado de servidor não são materializados.
- Durante um playtest, o que o plugin enxerga é o DataModel que o Studio deixa
  ativo para plugins — para estado exclusivo do cliente, prefira ler o Output
  (`logs`) a inferir da árvore.
- O mapeamento repo → Instance do `sync` assume as raízes do
  `default.project.json` (`src/shared` → `ReplicatedStorage.Shared`,
  `src/server` → `ServerScriptService.Server`, `src/client` →
  `StarterPlayer.StarterPlayerScripts.Client`, `lib/vendor` →
  `ReplicatedStorage.Shared.vendor`). Mudou o project.json, atualize
  `SOURCE_ROOTS` nos dois lados (`plugins/AvbDebug/src/Commands.luau` e
  `scripts/avb-debug.luau`).

## 8. Estender

Comando novo = uma função em `plugins/AvbDebug/src/Commands.luau` que recebe
`args` e devolve tabela serializável (`error("motivo")` para falhar). Registre o
nome em `STUDIO_COMMANDS` no CLI se quiser atalho de linha de comando; a ponte
não precisa saber de nada. Depois: `stylua plugins scripts`, `selene plugins
scripts` e `.\scripts\install-plugin.ps1`.

`plugins/` e `scripts/` entram no lint/format do CI junto com `src` e `tests`.

## 9. Arquivos

| Caminho | Papel |
|---|---|
| `plugins/AvbDebug/src/init.server.luau` | entrypoint do plugin: toolbar, painel, loops de poll e de log |
| `plugins/AvbDebug/src/Commands.luau` | comandos executados no Studio |
| `plugins/AvbDebug/src/Bridge.luau` | cliente HTTP (só 127.0.0.1) |
| `plugins/AvbDebug/src/LogTap.luau` | captura do Output em ring buffer |
| `plugins/AvbDebug/src/Serialize.luau` | Instance/Vector3/CFrame/Enum → JSON |
| `plugins/AvbDebug/src/Resolve.luau` | string → Instance |
| `plugins/AvbDebug/src/Widget.luau` | painel dock |
| `scripts/debug-bridge.luau` | ponte HTTP local + persistência de log |
| `scripts/avb-debug.luau` | CLI dos agentes |
| `scripts/install-plugin.ps1` | build + instalação do `.rbxm` |
| `.avb-debug/` | log e estado locais (ignorado pelo Git) |

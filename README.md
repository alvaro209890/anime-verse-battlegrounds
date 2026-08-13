# Anime Verse Battlegrounds

RPG / Action RPG de mundo aberto no Roblox (Luau) — combate estilo battlegrounds com
progressão persistente, loadout customizável e ressonância de famílias de energia.

> **Status em 2026-08-13 (18h):** itens 1–13 do backlog F0 fechados em código/headless, mais MENU/configurações, mira soltável, golpe com número de dano e, nesta rodada, **combate conectando de verdade**: toque/clique = golpe leve (botão de ataque removido da HUD), **corpo vira para a mira antes do golpe** (o servidor lê o look replicado), **aquisição de alvo em cone** no lugar da esfera (a esfera mediava centro-a-centro e o golpe passava a 11 studs), **reconciliação de zona** (quem já está fisicamente na planície é da planície — acabou o estado fantasma z=−100), **tempos de clipe medidos no Studio** (slash 0,5 s / lunge 1,5 s) com corte por fade no fim da ação, e **skins dos 2 personagens do spawn com assets**: boneco de treino em couro com bullseye/madeira e instrutor como mensageiro do Limiar (casaco escuro, capuz com energia umbral). **Cabeças corrigidas:** mesh humanoide do Roblox + rosto (anime no instrutor, clássico no dummy) no lugar das esferas lisas.
> **Runtime:** o Play roda com os dois atores do spawn na skin nova e com rosto. Correções da rodada anterior seguem valendo: chegue no vão do portão norte e **SEGURE E**.

## Estado comprovado

| Camada | Estado |
|---|---|
| Produto | Q-001 a Q-030 decididas; `docs/09-OPEN-QUESTIONS.md` é o registro canônico |
| Planejamento | visão, GDD, mundo, social, arquitetura, schemas, segurança, roster, roadmap, benchmark e plano de animação documentados |
| Implementado | domínio F0, mundo greybox com rotas/marcos/modelos low-poly, animação procedural de NPCs e do jogador, interações semânticas com Instrutor/Marco, save/ProfileStore, cliente Input/HUD, envelope v2, `SecurityService` e `TelemetryService` mínimo |
| Validado automaticamente | 217/217 testes em `tests/run.luau` + 40/40 em `tests/animation.luau`, Selene limpo, StyLua canônico, Wally e build Rojo |
| Ainda não comprovado | roteiro Play no Studio, physics/collision groups, DataStore real, dois clientes, latência, mobile, gamepad, performance, UX visual e assets de animação |

O CI em pushes para `main` valida contratos headless e a árvore Rojo; não substitui playtest. O snapshot e os links de evidência ficam em `docs/12-TESTING.md`.

## Stack

| Ferramenta | Uso | Config |
|---|---|---|
| Rojo | sync filesystem ↔ Studio | `default.project.json` |
| Wally | gerenciador de pacotes | `wally.toml` |
| luau-lsp | type checking (`--!strict`) | `.luaurc` + VS Code |
| Selene | lint | `selene.toml` |
| StyLua | formatador | `stylua.toml` |
| Lune | testes headless | `tests/run.luau` |
| Aftman | toolchain manager | `aftman.toml` |

## Desenvolvimento

No PowerShell, gere sempre um snapshot novo antes de abrir o projeto no Studio:

```powershell
aftman install
.\scripts\build-studio.ps1
```

O script instala as dependências Wally, garante `Packages/`, sobrescreve exatamente
`anime-verse-battlegrounds.rbxl` e imprime tamanho, data e SHA256 para confirmar que
o arquivo não é um build antigo. Feche o place que já estiver aberto no Studio e
reabra esse `.rbxl` antes de clicar em **Play**.

Esse `.rbxl` é um artefato local ignorado pelo Git: atualizar ou baixar a branch
`main` não reconstrói o arquivo. Rode o script novamente depois de cada atualização.

Snapshot canônico gerado em 2026-08-13 09:48:52 -03: `160553` bytes, SHA256
`8C6D136AE9B6186F5DF6E51F6E6306C085C13BBEF0868097FB8FE6A86831D32F`. Esses
dados comprovam a geração do arquivo, não a execução dele no Studio.

**Build não é Play:** o build apenas copia o estado atual de `src/` para um arquivo
`.rbxl`; ele não inicia o jogo nem atualiza um place que já está aberto. O **Play**
executa o snapshot atualmente carregado no Studio. Portanto, depois de mudar código,
rode novamente o script e reabra o arquivo — ou use uma sessão Rojo live-sync
configurada separadamente.

O atributo `F0Debug=true` do snapshot libera o kit de teste somente no Studio. O
servidor ainda exige `RunService:IsStudio()`, então o mesmo atributo não ativa esse
atalho em uma experiência publicada.

Outros gates locais:

```powershell
lune run tests/run.luau
selene src tests
stylua --check --line-endings Windows src tests
rojo build -o build.rbxl
```

O CI (`.github/workflows/ci.yml`) roda lint + format + testes + build em todo push
(`src`, `tests`, `plugins` e `scripts`).

### Live sync: manter o Studio sempre com o código atual

`build-studio.ps1` gera um snapshot novo, mas **não** atualiza um place já
aberto. Para editar código e ver no Studio sem reabrir nada, use o Rojo:

```powershell
.\scripts\serve.ps1
```

No Studio: aba **Plugins → Rojo → Connect**. Enquanto o serve roda, salvar um
arquivo em `src/` atualiza o place aberto. O plugin do Rojo é instalado com
`rojo plugin install` (já instalado nesta máquina).

Para saber se o Studio está mesmo com o código do repo:

```bash
lune run scripts/avb-debug.luau sync
```

### Debug do Studio por agentes (plugin AvbDebug)

O que acontece dentro do Studio deixou de ser invisível para os agentes. O plugin
`AvbDebug` conversa com uma ponte local (só `127.0.0.1`) e qualquer agente
consulta a árvore, as propriedades, o Output e o estado do playtest pelo CLI:

```powershell
.\scripts\install-plugin.ps1            # uma vez; reabra o Studio depois
lune run scripts/debug-bridge.luau      # terminal 1, deixa rodando
lune run scripts/avb-debug.luau ping    # terminal 2
lune run scripts/avb-debug.luau sync    # o Studio está com o código do repo?
lune run scripts/avb-debug.luau errors  # erros do último playtest
```

Detalhes, comandos e limites em [docs/19-DEBUG-BRIDGE.md](docs/19-DEBUG-BRIDGE.md).

## Estrutura

```
src/
  shared/            módulos compartilhados (dados, contratos, tipos, geometria)
    Data/            catálogos dirigidos por dados (personagens, habilidades, famílias, NPCs, zonas, objetivos, locale)
  server/            services (domínio F0, save, rede, segurança e telemetria)
  client/            controllers (bootstrap de apresentação)
tests/               harness Lune + 249 testes unitários (214 run.luau + 35 animation.luau)
docs/                produto, arquitetura, decisões, testes e planos (00 a 19)
lib/                 bibliotecas pinadas (ProfileStore)
plugins/AvbDebug/    plugin de Studio: ponte de debug usada pelos agentes
scripts/             build do snapshot, ponte de debug e CLI dos agentes
```

## Docs principais

- [docs/00-VISION.md](docs/00-VISION.md) — visão, pilares, público, curva de poder
- [docs/04-ARCHITECTURE.md](docs/04-ARCHITECTURE.md) — arquitetura service/controller, ADRs
- [docs/05-DATA-SCHEMA.md](docs/05-DATA-SCHEMA.md) — schemas de dados e de definição
- [docs/06-ROADMAP.md](docs/06-ROADMAP.md) — fases e gates
- [docs/09-OPEN-QUESTIONS.md](docs/09-OPEN-QUESTIONS.md) — fonte canônica de decisões
- [docs/10-MARKET-BENCHMARKS.md](docs/10-MARKET-BENCHMARKS.md) — evidência de mercado datada e limites de uso
- [docs/11-ABILITY-SPEC.md](docs/11-ABILITY-SPEC.md) — como adicionar habilidade (spec do formato)
- [docs/12-TESTING.md](docs/12-TESTING.md) — como rodar e o que cobre os testes
- [docs/13-F0-SLICE.md](docs/13-F0-SLICE.md) — spec de execução da fatia vertical (kit, mapa, roteiro, backlog)
- [docs/14-ANIMATION-PLAN.md](docs/14-ANIMATION-PLAN.md) — pipeline, qualidade, budgets e gates das animações
- [docs/15-WORLD-PRESENTATION.md](docs/15-WORLD-PRESENTATION.md) — mundo procedural, modelos greybox, animação dos atores e roteiro de validação
- [docs/16-COMBAT-AUDIO.md](docs/16-COMBAT-AUDIO.md) — áudio de combate: catálogo, player, integração e pendência de upload
- [docs/17-COMBAT-FEEL.md](docs/17-COMBAT-FEEL.md) — game-feel: easing, follow-through, idle, wrist snap, hit-stop e câmera de impacto
- [docs/18-ANALISE-VIDEO.md](docs/18-ANALISE-VIDEO.md) — playtest 13/08: golpes invisíveis, mira e overlay de comandos
- [docs/19-DEBUG-BRIDGE.md](docs/19-DEBUG-BRIDGE.md) — plugin AvbDebug e ponte local: como qualquer agente debuga o Studio

`PROMPT_AnimeVerseBattlegrounds_v2.md` é o briefing histórico que originou o
planejamento. Em conflito, os documentos canônicos em `docs/` prevalecem.

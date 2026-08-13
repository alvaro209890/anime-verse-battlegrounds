# Anime Verse Battlegrounds

RPG / Action RPG de mundo aberto no Roblox (Luau) — combate estilo battlegrounds com
progressão persistente, loadout customizável e ressonância de famílias de energia.

> **Status em 2026-08-13:** itens 1–13 do backlog F0 fechados em código/headless, mais MENU/configurações, botão SOLTAR MIRA e golpe básico com número de dano (`docs/18-ANALISE-VIDEO.md`).
> **Runtime:** o Play das 13:48 mostrou spawn/HUD/Instrutor. Reabra o `.rbxl` novo: MENU no canto, clique esquerdo no dummy, SOLTAR MIRA se a câmera grudar.

## Estado comprovado

| Camada | Estado |
|---|---|
| Produto | Q-001 a Q-030 decididas; `docs/09-OPEN-QUESTIONS.md` é o registro canônico |
| Planejamento | visão, GDD, mundo, social, arquitetura, schemas, segurança, roster, roadmap, benchmark e plano de animação documentados |
| Implementado | domínio F0, mundo greybox com rotas/marcos/modelos low-poly, animação procedural de NPCs e do jogador, interações semânticas com Instrutor/Marco, save/ProfileStore, cliente Input/HUD, envelope v2, `SecurityService` e `TelemetryService` mínimo |
| Validado automaticamente | 214/214 testes em `tests/run.luau` + 35/35 em `tests/animation.luau`, Selene limpo, StyLua canônico, Wally e build Rojo |
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

O CI (`.github/workflows/ci.yml`) roda lint + format + testes + build em todo push.

## Estrutura

```
src/
  shared/            módulos compartilhados (dados, contratos, tipos, geometria)
    Data/            catálogos dirigidos por dados (personagens, habilidades, famílias, NPCs, zonas, objetivos, locale)
  server/            services (domínio F0, save, rede, segurança e telemetria)
  client/            controllers (bootstrap de apresentação)
tests/               harness Lune + 249 testes unitários (214 run.luau + 35 animation.luau)
docs/                produto, arquitetura, decisões, testes e planos (00 a 18)
lib/                 bibliotecas pinadas (ProfileStore)
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

`PROMPT_AnimeVerseBattlegrounds_v2.md` é o briefing histórico que originou o
planejamento. Em conflito, os documentos canônicos em `docs/` prevalecem.

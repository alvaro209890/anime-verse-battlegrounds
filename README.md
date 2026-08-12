# Anime Verse Battlegrounds

RPG / Action RPG de mundo aberto no Roblox (Luau) — combate estilo battlegrounds com
progressão persistente, loadout customizável e ressonância de famílias de energia.

> **Status em 2026-08-12:** decisões de produto + spec F0 + catálogo do Punho do Eclipse + combate universal + Ombro Cometa headless contra o dummy.
> O repositório ainda não contém uma fatia jogável completa (mapa, HUD, save real, lunge espacial).

## Estado comprovado

| Camada | Estado |
|---|---|
| Produto | Q-001 a Q-030 decididas; `docs/09-OPEN-QUESTIONS.md` é o registro canônico |
| Planejamento | visão, GDD, mundo, social, arquitetura, schemas, segurança, roster, roadmap e benchmark documentados |
| Implementado | catálogo F0, Umbral, SessionSnapshot, combate universal (leve/guarda/aparo/dash/pesado), dummy de treino, Ombro Cometa no dummy, abilities, remotes, sessão/save stub |
| Validado automaticamente | 49 testes Lune + Selene + StyLua check + Wally + build Rojo no CI |
| Ainda não comprovado | feeling/runtime no Studio, servidor publicado, DataStore real, latência, mobile, gamepad, performance e UX visual |

O CI do commit `33eca73` passou em
[2026-08-12](https://github.com/alvaro209890/anime-verse-battlegrounds/actions/runs/31618843968).
Um build verde valida contratos headless e a árvore Rojo; não substitui playtest.

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

```bash
aftman install        # instala o toolchain (rojo, wally, selene, stylua, lune, luau-lsp)
lune run tests/run.luau   # testes unitários (49)
selene src tests      # lint
stylua --check src tests  # formatação
rojo build -o build.rbxl  # valida a árvore de instâncias
```

O CI (`.github/workflows/ci.yml`) roda lint + format + testes + build em todo push.

## Estrutura

```
src/
  shared/            módulos compartilhados (dados, contratos, tipos)
    Data/            catálogos dirigidos por dados (personagens, habilidades, famílias)
  server/            services (bootstrap, recurso, habilidade, combate, rede, sessão)
  client/            controllers (bootstrap de apresentação)
tests/               harness Lune + 49 testes unitários
docs/                produto, arquitetura, decisões, benchmark, testes e spec F0 (00 a 13)
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

`PROMPT_AnimeVerseBattlegrounds_v2.md` é o briefing histórico que originou o
planejamento. Em conflito, os documentos canônicos em `docs/` prevalecem.

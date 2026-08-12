# Anime Verse Battlegrounds

Action MMO de mundo aberto no Roblox (Luau) — combate estilo battlegrounds com progressão,
loadout customizável e ressonância de famílias de energia.

> **Status:** planejamento + esqueleto F0 (fatia vertical). Documentos de produto em
> `docs/00` a `docs/12`. Código inicial em `src/`.

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
lune run tests/run.luau   # testes unitários (22)
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
tests/               harness Lune + 22 testes unitários
docs/                planejamento (00-VISION a 09-OPEN-QUESTIONS) + implementação
lib/                 bibliotecas pinadas (ProfileStore)
```

## Docs principais

- `docs/00-VISION.md` — visão, pilares, público, curva de poder
- `docs/04-ARCHITECTURE.md` — arquitetura service/controller, ADRs
- `docs/05-DATA-SCHEMA.md` — schemas de dados e de definição
- `docs/06-ROADMAP.md` — fases e gates
- `docs/11-ABILITY-SPEC.md` — como adicionar habilidade (spec do formato)
- `docs/12-TESTING.md` — como rodar e o que cobre os testes

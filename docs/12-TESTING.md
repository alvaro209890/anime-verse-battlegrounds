# 12 — Testes

> **Status:** F0 (2026-08-12) — 22 testes, todos passando localmente e no CI.

## 1. Como rodar

```bash
aftman install   # instala o toolchain (lune incluído)
lune run tests/run.luau
```

O CI roda `lune run tests/run.luau` em todo push (`.github/workflows/ci.yml`).

## 2. O que está coberto (22 testes)

| Área | Cobertura |
|---|---|
| **Dados** (4) | roster → Punho do Eclipse com 4 habilidades; dash_strike como molde (custo 15, cooldown 4s, runner); 4 famílias de energia; contratos de remote registrados |
| **CooldownService** (3) | inicia zerado; start aplica e expira; clear zera |
| **CombatService** (3) | dano reduz vida; dano letal mata; dano negativo não cura |
| **ResourceService** (4) | cria estado com pool da família; trySpend deduz/nega; grantFlowGain respeita cap; família desconhecida → nil |
| **AbilityService** (6) | ativação válida (dano 12 + custo 15 − fluxo +6); recusa sem recurso; recusa em cooldown; habilidade desconhecida; morto não ativa |
| **CatalogService** (2) | dados reais passam na validação; personagem sem habilidade falha |
| **PlayerSessionService** (1) | join cria estado com personagem padrão; leave limpa estado e libera perfil |

## 3. Arquitetura de teste

- **`tests/harness.luau`** — mocka o ambiente Roblox mínimo que o Lune não fornece:
  - `_G.game` (GetService: ReplicatedStorage/Players)
  - `_G.Instance` (new/FindFirstChild/WaitForChild)
  - `_G.task` (polyfill — o Lune declara `task` como local nil em cada módulo)
  - `_G.require` (resolve `require(script.Parent.X)` para caminho real no filesystem)
- **`tests/run.luau`** — 22 testes com miniframework de assert; requer os módulos **reais** de `src/`.
- **Services testáveis por injeção** — os services da F0 recebem dependências no `init()`
  (docs/04 §2.3, princípio de testabilidade): `CatalogService.init({...})`,
  `AbilityService.init({...})`, `ResourceService.init({...})`, `PlayerSessionService.init({...})`.
  Nenhum service faz `require(script.Parent.X)` de outro módulo em runtime — só o bootstrap
  (`init.server.lua`) monta o grafo, que é onde o Roblox é necessário de verdade.
- **`src/shared/TaskCompat.luau`** — usa `task` nativo do Roblox com fallback para o polyfill
  dos testes (o Lune não expõe `task` global).

### Por que os Data modules não usam `require(script.Parent.Parent.Types)`

O Lune declara `script` como nil local em cada módulo carregado — `require(script.Parent.X)`
não é mockável de fora. Os módulos de dados e de contratos declaram os tipos **inline**
(`export type` é compile-time, zero custo em runtime). O `src/shared/Types.luau` permanece
como contrato canônico documentado para o luau-lsp e para referência, mas os módulos de
dados não dependem dele em runtime.

## 4. Pitfalls conhecidos

- `task.wait` real em teste = loop infinito se injetado o polyfill síncrono no spawn:
  os testes injetam `taskImpl` com `spawn` = noop (o loop de regen roda só no Roblox).
- Busy-wait curto (`os.clock`) substitui `task.wait` nos testes de expiração de cooldown.
- Selene: `[lints] global_usage = "allow"` e `empty_loop = "allow"` no `selene.toml`
  (o harness usa `_G` de propósito e os busy-waits têm corpo vazio).

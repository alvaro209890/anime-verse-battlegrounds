# 11 — Spec do formato de habilidade (AbilityDefinition)

> **Status:** rascunho de implementação — F0 (2026-08-12)
> **Fonte:** docs/05-DATA-SCHEMA.md §5.3 (schema canônico) e `src/shared/Types.luau`
> **Regra de ouro:** adicionar habilidade nova **não** exige tocar em sistema. É 1 entrada de dado + 1 runner registrado.

## 1. O formato

Toda habilidade é um registro Luau em `src/shared/Data/Abilities.luau`, validado no boot pelo `CatalogService`. Campos:

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `id` | `string` | sim | ASCII estável ≤ 64 chars; nenhum sistema faz `if` por id |
| `contentVersion` | `int` | sim | Incrementa em mudança de tuning |
| `displayNameKey` / `descriptionKey` | `string` | sim | Chave de localização — **nunca** nome canônico de terceiros |
| `sourceCharacterId` | `string` | sim | Origem de desbloqueio (referência a `Characters.luau`) |
| `energyFamilyId` | `string` | sim | Família usada por custo e ressonância |
| `kind` | `"Basic" \| "Skill" \| "Ultimate"` | sim | Ultimate ocupa slot próprio |
| `slotCost` | `int` | sim | 1–2 (não aplica a Ultimate) |
| `tags` | `{ string }` | sim | Conjunto fechado: `movement`, `melee`, `projectile`, `aoe`, `defense`, `control`, `barrier`, `ultimate`, `cancelable` |
| `inputMode` | `"Press" \| "Hold" \| "Release"` | sim | F0: só `Press` |
| `startupMs` / `activeMs` / `recoveryMs` | `int` | sim | Janelas de fase (timing de fluxo usa a janela da família) |
| `resourceCost.amount` | `int` | sim | Custo do pool da família; zero = sem custo |
| `cooldown.baseSeconds` | `number` | sim | ≥ 0 |
| `range` | `number` | sim | Alcance em studs (0 = self) |
| `maxTargets` | `int` | sim | 0 = sem alvo |
| `serverRunnerId` | `string` | sim | Chave do runner em `AbilityService.runners` |
| `enabled` | `bool` | sim | Kill switch por habilidade |

## 2. Como adicionar uma habilidade (checklist)

1. **Criar a entrada de dado** em `src/shared/Data/Abilities.luau` com todos os campos acima.
2. **Registrar o runner** em `src/server/Services/AbilityService.luau` (função local
   registrada no `init()`):
   ```lua
   local function minhaSkillRunner(attacker, target, _payload)
       -- valida alvo/alcance (F1: SpatialQuery) e aplica efeitos via deps.applyDamage
   end
   -- dentro do init(): runners.minha_skill_runner = minhaSkillRunner
   ```
   O runner **nunca** confia em valor do cliente: dano, custo, cooldown e acerto vêm do servidor.
   Efeitos usam as dependências injetadas (`deps.applyDamage`, `deps.grantFlowGain`...),
   nunca require direto — assim o runner é testável (docs/12-TESTING.md).
3. **Referenciar** em `Characters.luau` → `abilityIds` do personagem fonte.
4. Rodar `selene src tests && stylua --check src tests && lune run tests/run.luau && rojo build`
   (CI faz o mesmo no push).

## 3. Invariantes validadas no boot (CatalogService.validate)

- personagem → família existe;
- habilidade → personagem fonte existe;
- habilidade → família existe;
- `slotCost` ∈ {1,2} (exceto Ultimate);
- cooldown e custo não negativos;
- personagem sem `abilityIds` = erro.

## 4. Efeitos (F1+)

Efeitos não são código arbitrário em dado: `EffectDefinition` com `operation` fechado
(`Damage`, `Heal`, `ApplyModifier`, `Displace`, `SpawnServerProjectile`, ...) — docs/05 §5.4.
Até lá, o runner aplica dano direto via `CombatService.applyDamage`.

## 5. Maestria e tiers (F2+)

`masteryTiers` (5 tiers; 2 e 4 = variações comportamentais) entra quando a progressão
chegar — docs/05 §5.3. F0 roda sem.

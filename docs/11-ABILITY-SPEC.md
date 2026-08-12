# 11 — Spec do formato de habilidade (`AbilityDefinition`)

> **Status:** contrato-alvo aprovado em 2026-08-12; o código F0 implementa apenas o subconjunto identificado abaixo.
> **Fatia jogável:** IDs, runners e números do Punho do Eclipse estão em `docs/13-F0-SLICE.md`. Este arquivo descreve o formato; aquele descreve o conteúdo F0.
> **Fontes:** `docs/01-GDD.md` §4–7, `docs/05-DATA-SCHEMA.md` §5.3 e `src/shared/Types.luau`.
> **Regra de ouro:** adicionar uma habilidade não cria ramificação por personagem em sistema compartilhado; exige uma definição de dados versionada e um runner server-side registrado.

## 1. Estado atual e contrato-alvo

`src/shared/Data/Abilities.luau`, `src/shared/Types.luau` e `CatalogService` possuem hoje o molde mínimo da F0: identidade, família, fases, custo nativo, cooldown, alcance, runner e kill switch. `impactCost`, importação, Ressonância e maestria ainda são contrato documental para F1/F2; este documento não os declara implementados nem validados no boot atual.

O contrato-alvo de cada habilidade é:

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `id` | `string` | sim | ASCII estável, até 64 caracteres; nenhum sistema faz `if` por ID de conteúdo |
| `contentVersion` | `integer` | sim | incrementa em mudança de tuning ou comportamento |
| `displayNameKey` / `descriptionKey` | `string` | sim | chaves de localização; nome público e apresentação continuam bloqueados pelo Gate P1 |
| `sourceCharacterId` | `string` | sim | origem do desbloqueio; não impede uso estrangeiro quando a técnica for importável |
| `energyFamilyId` | `string` | sim | família nativa usada por custo e Ressonância |
| `kind` | `"Basic" \| "Skill" \| "Ultimate"` | sim | ultimate ocupa espaço separado; seu `slotCost` não entra na capacidade normal |
| `slotCost` | `integer` | sim | 1–2 para técnica normal; capacidade normal total máxima 4 |
| `impactCost` | `integer` | alvo F1 | 1–12; soma das técnicas normais e da ultimate não pode exceder 12 |
| `tags` | `{ string }` | sim | conjunto fechado; inclui `movement`, `melee`, `projectile`, `aoe`, `defense`, `control`, `barrier`, `defining`, `ultimate` e `cancelable` |
| `inputMode` | `"Press" \| "Hold" \| "Release"` | sim | F0 implementa apenas `Press` |
| `startupMs` / `activeMs` / `recoveryMs` | `integer` | sim | janelas autoritativas de fase; não vêm do cliente |
| `resourceCost.amount` | `integer` | sim | custo no núcleo nativo; zero é permitido somente quando a mecânica da família justificar |
| `foreignResourceCost` | `integer?` | alvo F1 | positivo quando a técnica for importável; custo nativo zero nunca vira técnica estrangeira grátis |
| `foreignFallbackPolicy` | `{ mode: "Neutral", fallbackId: string } \| { mode: "Blocked" }` | alvo F1 | declara comportamento neutro sem economia da família ou proíbe importação |
| `cooldown.baseSeconds` | `number` | sim | maior ou igual a zero; grupos compartilhados entram em F1 |
| `range` / `maxTargets` | `number` / `integer` | sim | limites server-side; `range = 0` significa self e `maxTargets = 0` significa sem alvo |
| `masteryLevels` | `{ MasteryLevelDefinition }` | alvo F2 | exatamente níveis 1–10 conforme §3 |
| `serverRunnerId` | `string` | sim | chave permitida em `AbilityService.runners` |
| `clientPresentationId` | `string?` | alvo de produção | referência apenas a VFX/animação; não contém regra autoritativa |
| `enabled` | `boolean` | sim | kill switch por habilidade |

`defining` é o ID técnico da tag exibida ao jogador como **Definidora**. Apenas técnica normal pode recebê-la, e um loadout pode conter no máximo uma.

## 2. Loadout, importação e Ressonância

O servidor valida um loadout ativo nesta ordem:

1. somar `slotCost` apenas das técnicas normais e rejeitar total acima de 4;
2. exigir exatamente uma ultimate e rejeitar mais de uma técnica normal com tag `defining`;
3. somar `impactCost` de técnicas normais e ultimate e rejeitar total acima de 12;
4. comparar cada família à família do núcleo ativo e calcular:

   `rawD = slots normais estrangeiros + (ultimate estrangeira ? 2 : 0) + max(0, famílias estrangeiras distintas - 1)`;

5. rejeitar o loadout se `rawD > 3`; depois da validação, `D = rawD` seleciona o perfil de Dissonância;
6. para cada técnica estrangeira, exigir custo positivo e aplicar seu fallback antes dos multiplicadores de Dissonância.

“Slots normais estrangeiros” é a soma de `slotCost` das técnicas normais fora do núcleo. **Não** se usa `min(3, rawD)`, clamp ou saturação para autorizar uma composição inválida. Produto pago, entitlement, item ou maestria não reduz capacidade, impacto ou Dissonância.

Uma técnica estrangeira com `mode = "Neutral"` executa apenas o `fallbackId` registrado: conserva a função mínima declarada, mas não gera, converte nem reembolsa recurso exclusivo da família original. Com `mode = "Blocked"`, ela pode existir no catálogo, porém a validação impede equipá-la fora da família nativa. Ausência de `foreignResourceCost` ou de política de fallback também bloqueia a importação.

## 3. Maestria 1–10

`MasteryLevelDefinition` registra `level`, limiar de XP, recompensa e versão. Devem existir exatamente dez níveis únicos e ordenados:

| Nível | Regra de recompensa |
|---:|---|
| 1 | comportamento base completo e competitivo |
| 2 | ajuste numérico opcional de até 2% |
| 3 | primeira variação comportamental |
| 4 | progresso sem aumento obrigatório de poder |
| 5 | ajuste numérico opcional de até 2% |
| 6 | escolha de variação comportamental lateral |
| 7 | progresso sem aumento obrigatório de poder |
| 8 | ajuste numérico opcional de até 2% |
| 9 | variação de expressão, com contra-jogo e sem cobertura universal |
| 10 | cosmético ou qualidade de vida, sem pico competitivo |

Os níveis 2, 5 e 8 somam no máximo 6% por técnica. A mesma técnica não pode acumular simultaneamente bônus de dano, cooldown e economia de recurso. Ranked e torneio removem esses ganhos numéricos, mas preservam variações comportamentais que estiverem na lista competitiva versionada. O modelo antigo de cinco tiers e breakpoints 2/4 está revogado.

## 4. Como adicionar uma habilidade

1. Criar a definição em `src/shared/Data/Abilities.luau`, mantendo o subconjunto F0 enquanto a migração não chega e preenchendo todo o contrato-alvo depois dela.
2. Confirmar P1 antes de aprovar nome público, silhueta, animação, VFX, áudio ou marketing; codinome de referência não pode ser exportado.
3. Declarar capacidade, impacto, tag `defining` quando aplicável, custo estrangeiro e fallback. Uma técnica bloqueada para mistura deve dizê-lo explicitamente.
4. Registrar o runner e, quando necessário, o fallback neutro em registries permitidos. Runner não confia em dano, custo, cooldown, alvo ou acerto enviados pelo cliente e usa apenas dependências server-side injetadas.
5. Referenciar a habilidade em `Characters.luau` e manter família/origem existentes.
6. Adicionar testes de catálogo, ativação e rejeição relevantes; para conteúdo F1/F2, incluir orçamento, `rawD`, Definidora, fallback e maestria.
7. Executar StyLua check, Selene, os testes Lune, instalação Wally e build Rojo conforme `docs/12-TESTING.md`.

## 5. Invariantes de catálogo

O `CatalogService` atual valida referências de personagem/família, `slotCost` normal, custo/cooldown não negativos e personagem com ao menos uma habilidade. Antes de habilitar Ressonância ou maestria, o boot precisa validar adicionalmente:

- `impactCost` inteiro positivo e dentro do intervalo;
- técnica normal com `slotCost` 1–2 e ultimate excluída da soma de capacidade;
- tag `defining` somente em técnica normal;
- técnica importável com `foreignResourceCost > 0` e fallback neutro registrado;
- política `Blocked` sem fallback executável;
- dez níveis de maestria únicos, breakpoints comportamentais apenas em 3/6/9 e total numérico de no máximo 6%;
- nenhum conteúdo habilitado referencia runner, fallback, efeito ou apresentação ausente.

A validação individual da habilidade não substitui a validação da composição: capacidade, impacto, exatamente uma ultimate, no máximo uma Definidora e `rawD <= 3` pertencem ao validador server-side de loadout.

## 6. Efeitos

Efeitos não são código arbitrário armazenado em dado. O contrato evolui para `EffectDefinition` com operações fechadas como `Damage`, `Heal`, `ApplyModifier`, `Displace` e `SpawnServerProjectile`. Até essa migração, os runners F0 aplicam comportamento pelas dependências server-side existentes. Em ambos os casos, cliente solicita intenção e apresenta resultado; nunca decide acerto ou valor final.

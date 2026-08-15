# 28 — Reforma visual da sala de spawn

## Estado e objetivo

Esta rodada melhora a leitura da sala de spawn sem alterar volumes, portões, âncoras, interações, dano, movimento ou autoridade do servidor. A reforma foi implementada como configuração pura em `SceneryPresentation` e materialização server-side em `WorldService`.

> **Estado atual:** código, testes headless, lint e build Rojo aprovados. O arquivo ainda não foi aberto e observado no Roblox Studio neste snapshot; portanto iluminação real, encaixe visual, colisão e desempenho permanecem pendentes de W1.

## Direção visual

A sala agora usa uma base de **ardósia azul-grafite**, caminhos e praça em tom de ardósia mais claro, teto escuro translúcido e acentos umbral/ciano. A intenção é separar a área segura das rotas sem transformar o spawn em uma caixa plana ou usar brilho em todas as superfícies.

| Elemento | Configuração | Função visual |
|---|---|---|
| Piso seguro | RGB `{57, 63, 76}`, `Slate` | Base fria e legível para spawn e treino |
| Praça | RGB `{96, 102, 122}`, `Slate` | Marca o centro social e o ponto de leitura inicial |
| Caminhos | RGB `{96, 102, 122}`, `Slate` | Conectam spawn, treino e portões sem minimapa |
| Paredes | Paleta existente com cap e acento umbral | Fecham a sala e preservam a silhueta dos portões |
| Teto | RGB `{32, 38, 54}`, `Glass`, transparência `0.18` | Mantém cobertura visual sem matar a leitura do espaço |
| Atmosfera | `ClockTime 18.25`, haze `0.9`, density `0.18` | Contraste de crepúsculo controlado |
| Luzes | 6 PointLights, range 18, brilho 1.35 | Preenchimento alternado ciano/âmbar-umbral, com sombras apenas nas quatro primeiras |

Os valores são dados puros e passam por limites de RGB, transparência, brilho, alcance e quantidade. O código não cria texturas externas nem depende do pacote Kenney para o boot do mundo.

## Skin da instrutora

A personagem `npc_threshold_instructor` mantém o rosto embutido `rbxasset://textures/face.png` e a autoridade da interação existente. A silhueta foi enriquecida com mechas laterais, painel de cintura e painéis de capa, preservando o rosto e mantendo o corpo R15 com proporção não cúbica.

| Camada | Intenção |
|---|---|
| `HairSideL/R` | Enquadrar o rosto sem cobrir a faixa dos olhos |
| `WaistPanel` | Dar transição visual entre torso, cinto e saia do casaco |
| `CapePanelL/R` | Criar leitura lateral e movimento de tecido sem rig novo |
| Emblema, gola, punhos e barra | Continuar usando acento umbral localizado, evitando silhueta toda neon |

A skin é apresentação. Ela não muda `Npcs.luau`, `Interactions.luau`, `QuestService`, alcance, hold, recompensa ou qualquer decisão server-side.

## Validação headless

A suíte adicionou cobertura para a paleta, orçamento de iluminação e densidade da skin. Os resultados desta rodada foram:

| Gate | Resultado |
|---|---|
| Domínio | 227 passaram, 0 falharam |
| Animação/apresentação | 62 passaram, 0 falharam |
| Fuzz de segurança | 29 passaram, 0 falharam |
| Total automatizado | 318 casos |
| Selene | 0 erros, 0 warnings, 0 parse errors |
| Rojo | Build passou; artefato reproduzido com 297.737 bytes |
| `git diff --check` | Passou |

## Limites e próximo gate

A validação headless prova os contratos puros e a construção do artefato; não prova que a sala fica bonita dentro do Studio. W1 deverá capturar o spawn em frente, perfil e três quartos, verificando piso sem z-fighting, teto sem escurecer excessivamente a face da instrutora, luzes sem estourar neon, caminhos legíveis, portões livres, NPC sem clipping e FPS aceitável.

A revisão de qualidade deve também confirmar que as luzes são destruídas e recriadas de forma idempotente em reconstruções do mundo e que a pasta `F0SpawnLighting` não cria objetos duplicados. Em Android, reduzir sombras e partículas antes de reduzir a leitura cromática da sala.

## Referências relacionadas

- [`docs/15-WORLD-PRESENTATION.md`](15-WORLD-PRESENTATION.md)
- [`docs/26-VISUAL-VALIDATION-CHECKLIST.md`](26-VISUAL-VALIDATION-CHECKLIST.md)
- [`docs/27-FUTURE-ABILITY-ASSET-CATALOG.md`](27-FUTURE-ABILITY-ASSET-CATALOG.md)
- [`src/shared/Data/SceneryPresentation.luau`](../src/shared/Data/SceneryPresentation.luau)
- [`src/shared/Data/WorldPresentation.luau`](../src/shared/Data/WorldPresentation.luau)
- [`src/server/Services/WorldService.luau`](../src/server/Services/WorldService.luau)

## Revalidação integral pós-publicação

A revisão de hoje comparou os commits publicados da reforma do spawn, inspecionou o diff de `WorldService`, `SceneryPresentation`, `WorldPresentation` e `tests/animation.luau`, confirmou que os assets alterados não introduzem regras de combate e repetiu os gates completos.

Nenhum bug reproduzível foi encontrado fora do Studio. A iluminação é idempotente: `F0SpawnLighting` é destruída antes de ser reconstruída; os emissores não têm colisão, toque ou consulta; o número de pontos é limitado pelo catálogo; e as cores, brilho, alcance, quantidade e RGB passam por validação. A skin adicional da instrutora continua coberta por validação de rig, host, material, proporção, limite anti-caixa e proteção da faixa dos olhos.

| Verificação de revalidação | Resultado |
|---|---|
| `tests/run.luau` | 227 passaram, 0 falharam |
| `tests/animation.luau` | 62 passaram, 0 falharam |
| `tests/security_fuzz.luau` | 29 passaram, 0 falharam |
| Selene | 0 erros, 0 warnings, 0 parse errors |
| Rojo | Build aprovado, 297.737 bytes |
| `git diff --check` | Passou |
| Commit base da auditoria | `1abb8a1` — antes da correção do prompt |

A inspeção não substitui o Gate W1. Ainda não é possível concluir headless que a iluminação não escurece a face, que não existe clipping no rig, que o teto não causa desconforto visual, que não há z-fighting ou que o desempenho em Android está dentro do orçamento. Esses pontos permanecem como validação manual no Roblox Studio.

## Correção pós-auditoria

A integração do prompt da Instrutora foi corrigida após a migração para o rig R15. O corpo R15 fica aninhado em `Body`, portanto `WorldService.setNpcInteraction` agora procura `Head` recursivamente e continua compatível com o fallback low-poly, no qual a cabeça fica diretamente no ator.

Foi acrescentado um teste de regressão em `tests/animation.luau` para impedir o retorno da busca não-recursiva. A validação no Studio continua obrigatória para confirmar a criação visual do `ProximityPrompt`, a interação válida e a recusa fora de 10 studs.

> Esta alteração não muda catálogo, distância, hold, recompensa ou autoridade server-side; ela apenas restaura a ponte entre o ator visual instanciado e o controlador de interação do cliente.

## Revalidação pós-correção

A correção foi revalidada com a execução integral dos gates locais e a verificação automatizada de bootstrap:

| Verificação | Resultado |
|---|---|
| `tests/run.luau` | 227 passaram, 0 falharam |
| `tests/animation.luau` | 65 passaram, 0 falharam |
| `tests/security_fuzz.luau` | 29 passaram, 0 falharam |
| Selene | 0 erros, 0 warnings, 0 parse errors |
| StyLua | passou |
| Wally | passou, 0 dependências externas |
| Rojo | build aprovado, 297.737 bytes |
| `git diff --check` | passou |
| Cobertura adicional | vínculo único da Instrutora verificado no bootstrap |
| Commit publicado | `6310e28` em `origin/main` |

A validação no Roblox Studio continua sendo o próximo gate para confirmar a criação visual do `ProximityPrompt`, a interação válida e a recusa fora de 10 studs.

## Diagnóstico automatizado de bootstrap

O `WorldService` agora verifica, imediatamente após construir os atores estáticos, se `ThresholdInstructor` existe e se exatamente uma `BasePart` recebeu `InteractionNpcId = "npc_threshold_instructor"`. A inspeção usa `GetDescendants()`, cobrindo o rig R15 aninhado em `Body` e o fallback low-poly. Ausência ou duplicidade gera um aviso explícito no Output do servidor.

A regra foi extraída para `src/shared/InteractionBinding.luau`, permitindo que runtime e harness usem o mesmo contrato. O teste simulado cobre vínculo único, duplicidade e ausência, sem criar dependência de Roblox Studio.

A suíte headless também verifica a presença da chamada de bootstrap, a regra de unicidade e a inspeção recursiva. Essa proteção detecta falhas de montagem e evita um diagnóstico silenciosamente verde, mas não substitui o Playtest W1 para confirmar a criação visual e a usabilidade do `ProximityPrompt`.

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
| Rojo | Build passou; artefato reproduzido com 297.729 bytes |
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

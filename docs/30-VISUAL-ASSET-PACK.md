# Pacote visual F0

Este documento registra um pacote de referências visuais originais para o **Anime Verse: Battlegrounds**. O pacote foi criado para apoiar decisões de textura, props, VFX e animação sem transformar imagens conceituais em assets de runtime automaticamente.

> **Regra de uso:** estes PNGs são referências de direção de arte e receitas visuais. Eles não são decals, texturas importadas, partículas publicadas, meshes, animações ou evidência de validação no Roblox Studio.

## Referência-mãe

![Quadro de direção de arte](assets/asset-pack-art-direction-board.png)

O quadro-mãe fixa a linguagem comum do pacote: pedra slate escura, energia ciano/violeta, luz âmbar, silhuetas legíveis, partículas controladas e composição compatível com a escala visual do projeto. As imagens individuais devem ser comparadas a ele antes de qualquer conversão para Roblox.

## Catálogo

| Arquivo | Categoria | Dimensão | Uso recomendado | Não usar como | SHA-256 |
|---|---|---:|---|---|---|
| `asset-pack-art-direction-board.png` | Referência-mãe | 2560 × 1440 | Paleta, materiais, iluminação e consistência | Screenshot ou atlas de runtime | `ce184de7ed23b3288019f1c94cf4ed3b85f249fe3467d47a21e9235dd932d7b1` |
| `texture-slate-cracked-floor.png` | Textura | 1920 × 1920 | Briefing de piso slate e fissuras de energia | Textura pronta para importar | `25e02020be21f93c5125659bc435eacb06861777db3e90a4769c4bdd80f11ef4` |
| `texture-runed-stone-wall.png` | Textura | 1920 × 1920 | Briefing de muro modular e runas | Textura pronta para importar | `833a749f2217f0b4adb4bdb06814f7b24c4a293c251540e32e548e5d59ffe967` |
| `texture-crystal-emissive-strip.png` | Trim/VFX | 2304 × 1536 | Direção de faixa emissiva e repetição de cristais | Atlas final ou decal | `fb0553c9ca1037922311c287b7da6366c99b232c43dd48ffb6f34cc2e97b1a38` |
| `prop-energy-crystal-beacon.png` | Prop | 1920 × 1920 | Beacon de energia, marco e ponto de navegação | Mesh ou modelo publicável | `c6e05c4d8b1142ce6d5694fb5b22234f4302cb5d9e8e3311b4f746e6981e16b0` |
| `prop-amber-lantern-sconce.png` | Prop | 1920 × 1920 | Arandela, luz de bastião e serviço | Mesh ou fonte de iluminação final | `cf9e035b4ce83d0b22cf89efe6ecd907f48868bda467d49e560c1da739c7ca23` |
| `vfx-guard-orbit-shell.png` | VFX | 1920 × 1920 | Defesa, casca, órbitas e motes | Partículas prontas ou bloqueio confirmado | `dfd3d133e0e25952d3f11c7146cb9c41c412570e6941d2b70d101c8269ff27c9` |
| `vfx-dash-afterimage-trail.png` | VFX | 2304 × 1536 | Afterimages, esteira, rastro e faíscas de dash | Teleporte ou deslocamento autoritativo | `bb7771c715345b687219dd6745811234716cac629d9f882271fe63817c0a83ae` |
| `vfx-ground-break-impact.png` | VFX | 1920 × 1920 | Contato, crack, poeira, debris, flash e dissipação | Alteração permanente de piso | `535b91fac0b34ab6edcf900d421c2c88ccd5ffc7ee3c180dfb6d740ea3e0238e` |
| `animation-combat-poses-board.png` | Animação | 2560 × 1440 | Defesa, preparação de dash e recuperação | Animação publicada ou clip final | `0e046c68fca749329f2ad1d62af8a03bc346f76608d51b63b560e8e59354dcf0` |
| `animation-heavy-strike-poses-board.png` | Animação | 2560 × 1440 | Antecipação, avanço, impacto e recuperação | Animação publicada ou clip final | `d241c3b8f7914fb6947d963539b4090820f9882519ea46395ec185cf24397842` |

## Procedência

As imagens foram geradas para este projeto usando a capa existente como referência de identidade e o quadro-mãe como referência de consistência. A geração utilizou apenas personagens, materiais, props e cenários originais; o pacote não foi baseado em uma franquia, personagem ou pacote comercial específico.

As imagens de VFX que possuem pequenos rótulos ou decomposições visuais devem ser tratadas como **boards de receita**, não como arte final. Antes de qualquer conversão, a equipe deve separar as camadas, reduzir partículas, testar leitura em mobile e confirmar que nenhum efeito visual está sendo usado como autoridade de combate.

## Pipeline de promoção

| Etapa | Decisão necessária |
|---|---|
| Conceito | Comparar com este pacote e registrar a intenção do asset |
| Receita determinística | Definir geometria, cores, tempos, limites e comportamento em Luau |
| Produção Roblox | Criar peças, materiais, partículas, meshes ou animações separadamente |
| Otimização | Medir memória, draw calls, partículas, iluminação e leitura mobile |
| Runtime | Integrar por Rojo somente após revisão de licença e testes |
| Validação | Executar Studio, Playtest e critérios do documento canônico correspondente |

O pacote atual permanece no estado **Conceito**. A capa geral continua documentada em [`docs/29-GAME-COVER.md`](29-GAME-COVER.md), enquanto o índice navegável está em [`VISUAL-REFERENCE-INDEX.md`](../VISUAL-REFERENCE-INDEX.md).

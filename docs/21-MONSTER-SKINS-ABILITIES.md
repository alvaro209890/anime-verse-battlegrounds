# Skins e Habilidades de Monstros (F0) — 14/08/2026

Esta atualização transforma os modelos greybox dos inimigos em identidades visuais distintas com habilidades animadas e efeitos de partículas, preservando a autoridade total do servidor sobre o combate.

## Skins e Identidade Visual

Cada NPC agora possui uma skin declarada em `WorldPresentation.luau`, com paleta de aura e escala visual próprias.

> **Atualização 15/08/2026 (`docs/31`):** o corpo dos dois Estilhaços deixou de
> ser construído dentro do `WorldService` e virou receita de dados em
> `WorldPresentation.shardGearFor(npcId)` — inclusive a coroa do elite, que era
> um `if npcId == "enemy_anchored_shard"` na camada de materialização. A skin
> ganhou volume nas duas (13 e 23 peças) e passou a ter alcance travado por
> teste: nenhuma peça pode ocupar, no plano horizontal, mais studs do que o
> `attackRange` real do NPC (comum 2,43 de 4; elite 4,46 de 8).

| NPC | Skin | Aura | Diferencial Visual |
|---|---|---|---|
| `enemy_wandering_shard` | **Fenda Ciano** | Ciano (104, 220, 238) | Halo ciano orbitando o núcleo mineral, casca de rocha arredondando o volume, anel de fenda e duas lascas soltas. |
| `enemy_anchored_shard` | **Coroa do Vazio** | Laranja (255, 118, 92) | Coroa de cinco pontas de alturas alternadas, colar de ancoragem em basalto com quatro cravos e manto de pedra. |
| `npc_training_dummy` | **Saco de Treino** | Vermelho (226, 78, 78) | Alvo Neon vermelho no peito. |
| `npc_threshold_instructor`| **Guardiã do Limiar** | Violeta (138, 96, 196) | Cabelo longo + rabo, casaco com saia em camadas, neon só nas bordas (capuz/gola/punhos/hem). |

## Habilidades e Animações

Os inimigos agora alternam entre padrões de ataque, cada um com sua própria pose procedural e efeito de VFX.

| Habilidade | NPC | Padrão | Efeito (Kenney) | Descrição |
|---|---|---|---|---|
| `shard_rend` | Comum | Rend | `kenney_slash` | Talho rápido com inclinação frontal. |
| `shard_pounce` | Comum | Pounce | `kenney_spark` | Salto agressivo com aura de faíscas. |
| `anchored_combo` | Boss | Combo | `kenney_slash` | Sequência de dois talhos rápidos. |
| `anchored_slam` | Boss | Slam | `kenney_scorch` | Esmagamento pesado com flash de luz laranja. |

## Assets Gratuitos (CC0)

Utilizamos o **Particle Pack** da Kenney, licenciado sob **Creative Commons CC0** [1] [2]. Os arquivos foram extraídos para `AVB-free-vfx-assets/assets/vfx/kenney/`.

- `slash_01.png`: Usado para talhos e cortes.
- `spark_01.png`: Usado para impactos e saltos.
- `scorch_01.png`: Usado para o esmagamento do boss.
- `smoke_01.png`: Usado para dissipação e spawn.

## Implementação Técnica

1. **Servidor (`EnemyService`)**: Alterna o contador de ciclos e nomeia a habilidade no `EnemyEvent`.
2. **Cliente (`EnemyVfxPlayer`)**: Novo player que escuta `EnemyEvent`, cria emissores e luzes locais vinculados ao rig.
3. **Animação (`ActorAnimator`)**: Poses específicas para `pounce` e `slam` com pesos de inclinação e bobbing distintos.
4. **Catálogo (`EnemyAbilities`)**: Centraliza as receitas visuais das habilidades para fácil ajuste de cor e timing.

## Roteiro de Playtest

1. **Spawn**: Verifique se o halo ciano aparece nos Shards e a coroa laranja no Boss.
2. **Combate Comum**: Observe a alternância entre o talho (Rend) e o salto (Pounce).
3. **Boss**: Verifique o telegraph longo do Slam (luz laranja crescendo) vs o Combo rápido.
4. **Limpeza**: Mate um inimigo e verifique se o VFX de habilidade é interrompido e limpo corretamente.
5. **IDs Roblox**: Quando os assets Kenney forem publicados, preencha os IDs em `EnemyVfxAssets.luau` para substituir as partículas default.

## Referências de Assets Consultadas

| Nº | Fonte | URL | Resultado da consulta |
|---|---|---|---|
| [1] | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | Particle Pack com 80 arquivos, licença CC0, adequado para VFX 2D. |
| [2] | Kenney — Support | https://kenney.nl/support | Confirma que os assets das páginas são domínio público CC0 e não exigem atribuição. |
| [3] | ambientCG — License | https://ambientcg.com/license | Materiais e modelos ambientCG são CC0; fonte selecionada para futuras texturas de rocha, não incorporada nesta alteração. |
| [4] | OpenGameArt — monster cc0 | https://opengameart.org/content/monster-cc0 | Referência de monstro em domínio público; não incorporada diretamente porque o jogo usa atores 3D procedurais. |
| [5] | OpenGameArt — effectshader | https://opengameart.org/content/effectshader | Referência de efeitos 2D; não incorporada diretamente devido à página não expor um pacote estável durante a consulta. |

As fontes acima foram consultadas em 14/08/2026. Os sprites efetivamente copiados para o repositório são somente os arquivos do Particle Pack da Kenney, acompanhados de `AVB-free-vfx-assets/assets/vfx/kenney/License.txt`.

## References

[1]: https://kenney.nl/assets/particle-pack "Kenney — Particle Pack"
[2]: https://kenney.nl/support "Kenney — Support"
[3]: https://ambientcg.com/license "ambientCG — License"
[4]: https://opengameart.org/content/monster-cc0 "OpenGameArt — monster cc0"
[5]: https://opengameart.org/content/effectshader "OpenGameArt — effectshader"

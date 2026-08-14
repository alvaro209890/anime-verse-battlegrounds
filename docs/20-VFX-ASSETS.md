# Assets gratuitos de VFX para ataques e bolas de energia

**Projeto:** Anime Verse Battlegrounds  
**Atualização examinada:** `bb147a6` → `73d8b96`  
**Data da revisão:** 14 de agosto de 2026

## Atualização do repositório

A cópia local foi atualizada com fast-forward para `73d8b96487b5af603a7460b09bd53ca2c324507e`. Entre a revisão anterior e a atual entraram sete commits, com mudanças concentradas em rig, animação e apresentação. A base agora possui rigs R15 para os bots do spawn, volumes curvos para partes do corpo, animação de golpe do jogador com o corpo inteiro, correção da intenção de mira e correções no overlay procedural.[1]

| Área | Mudança observada | Impacto para os VFX |
|---|---|---|
| Rig dos bots | Rigs de spawn passaram para R15; o builder e os joints foram ampliados | Há mais pontos confiáveis para prender efeitos em mão, braço, torso e root |
| Apresentação | Skins ganharam volumes curvos e proporção Rthro | Esferas, auras e impactos podem acompanhar melhor a silhueta sem parecerem apenas blocos |
| Combate | Golpes passaram a usar o corpo inteiro e novas poses de técnica | Rajada, bola de energia e explosão podem ser sincronizadas a momentos específicos da animação |
| Mira | O corpo não gira mais de forma indevida no golpe; a mira segue declarada na intenção | O projétil deve usar a direção autoritativa/intencional correta, sem nascer para trás |
| VFX atual | O catálogo continua dirigido por dados e o player ainda cria emissores procedurais locais | Os assets baixados entram como texturas futuras; não há IDs Roblox inventados nesta etapa |

O README atualizado ainda classifica **assets de animação e UX visual em Play como não comprovados**.[2] Portanto, baixar as imagens não equivale a declarar a integração pronta. Será necessário importar/publicar as texturas no Roblox, preencher IDs reais e fazer playtest com acerto, erro, guarda, contra e morte.

## Assets incluídos nesta entrega

Os arquivos foram adicionados em `assets/vfx/free_sources/` como originais e em `assets/vfx/prepared/` como cópias preparadas para importação. O pacote contém efeitos 2D transparentes de bola de energia, anel, raio e explosão.

| Asset | Arquivos | Licença verificada | Aplicação sugerida |
|---|---|---|---|
| **Energy Ball** | `free_sources/energy_ball_ccby30.png` | CC-BY 3.0 | `comet_aura`, carga, núcleo e quadro de viagem de `comet_shoulder` |
| **Power Rings** | `free_sources/power_ring_cc0.png` | CC0 | `comet_ring`, `pulse_release`, burst radial e contra |
| **Lightning Shock Spell** | `free_sources/lightning_shock_ccby30.png`, `prepared/lightning_shock_8bit.png` | CC-BY 3.0 | `cadence_arc_first`, `cadence_arc_second` e rajadas elétricas |
| **Explosion 0003** | `free_sources/explosion_0003_cc0.png`, `prepared/explosion_0003_cc0_1024px.png` | CC0 | `comet_burst`, impacto confirmado e finalização |
| **Explosion 0005** | `free_sources/explosion_0005_cc0.png`, `prepared/explosion_0005_cc0_1024px.png` | CC0 | Variante de impacto, morte ou elite |

A versão preparada do raio foi convertida de 16-bit para RGBA 8-bit. As versões preparadas das explosões foram reduzidas para 1024 px no maior eixo, diminuindo o peso de aproximadamente 2,6–3,5 MB para cerca de 0,5–0,7 MB. Os originais foram preservados para rastreabilidade.

## Licenças e fontes

Os dois assets CC-BY podem ser redistribuídos com atribuição. O crédito deve permanecer no repositório e também ser exibido nos créditos do jogo:

> Energy Ball — yiannisd, OpenGameArt.org, CC-BY 3.0: [página oficial][3]  
> Lightning Shock Spell — Clint Bellanger, OpenGameArt.org, CC-BY 3.0: [página oficial][4]

Os assets CC0 podem ser modificados e redistribuídos sem atribuição obrigatória, embora as fontes tenham sido registradas no README da pasta para rastreabilidade:

> Power Rings — Oiboo, OpenGameArt.org, CC0: [página oficial][5]  
> Explosion spritesheet low res — dirkwybe, OpenGameArt.org, CC0: [página oficial][6]

Também foi encontrado o [PIPOYA FREE VFX Time Magic][7], com estética próxima de ataques de anime e PNGs em 480x480/192x192. A página permite uso pessoal/comercial e edição, mas proíbe redistribuição ou revenda; por isso, ele **não foi copiado para o repositório**. O download deve ser feito apenas pela página oficial, seguindo os termos do autor.

## Como esses assets entram no pipeline atual

O projeto já define técnicas em `src/shared/Data/AbilityVfx.luau` e materializa efeitos em `src/client/Presentation/AbilityVfxPlayer.luau`. O player atual usa uma textura de partícula embutida do Roblox, `sparkles_main.dds`, para as camadas `charge`, `shell` e `burst`; usa `Trail` para `trail` e `arc`; e usa uma Part cilíndrica Neon para `ring`.[8]

A integração correta, portanto, é substituir a textura genérica por IDs Roblox publicados e manter a semântica do catálogo. A confirmação de hit não deve ser alterada: explosões e flashes de contato continuam condicionados ao evento autoritativo do servidor. O asset visual não pode abrir hitbox, confirmar dano ou sugerir alcance maior que o declarado pela técnica.

| Fase | Ação | Observação |
|---|---|---|
| 1 | Importar os PNGs preparados no Roblox e obter IDs reais | O arquivo local no Git não é automaticamente uma textura jogável |
| 2 | Adicionar IDs em configuração dirigida por dados | Não colocar IDs fictícios nem depender de assets do Creator Store sem revisão |
| 3 | Configurar flipbook ou separar frames individuais | Energy Ball, Power Rings, raio e explosões são spritesheets |
| 4 | Mapear os assets para `AbilityVfxPlayer` | Bola para carga, anel para onda, raio para arco e explosão para impacto |
| 5 | Validar em Play | Conferir distância, orientação, alpha, mobile, frame time, hit, miss e guard |

## Estado desta entrega

O repositório foi atualizado e revisado. Os arquivos de fonte, as cópias preparadas e a documentação de licença foram adicionados localmente. **Ainda não foram feitas alterações de gameplay nem IDs Roblox**, porque esses IDs só existem depois da importação/publicação na conta ou grupo da experiência. O uso imediato mais seguro é abrir `assets/vfx/README.md`, importar os arquivos preparados e então realizar a integração com os IDs reais.

## Referências

[1]: https://github.com/alvaro209890/anime-verse-battlegrounds/compare/bb147a6fcfd9d0673275f0cabf00a4e3acfd153f...73d8b96487b5af603a7460b09bd53ca2c324507e "Comparação das mudanças recentes do repositório"
[2]: https://github.com/alvaro209890/anime-verse-battlegrounds/blob/73d8b96487b5af603a7460b09bd53ca2c324507e/README.md#L9-L19 "Estado comprovado e pendências no README"
[3]: https://opengameart.org/content/energy-ball "Energy Ball — OpenGameArt"
[4]: https://opengameart.org/content/lightning-shock-spell "Lightning Shock Spell — OpenGameArt"
[5]: https://opengameart.org/content/power-rings "Power Rings — OpenGameArt"
[6]: https://opengameart.org/content/explosion-spritesheet-low-res "Explosion spritesheet low res — OpenGameArt"
[7]: https://pipoya.itch.io/pipoya-free-vfx-time-magic "PIPOYA FREE VFX Time Magic — página oficial"
[8]: https://github.com/alvaro209890/anime-verse-battlegrounds/blob/73d8b96487b5af603a7460b09bd53ca2c324507e/src/client/Presentation/AbilityVfxPlayer.luau#L62-L186 "Player atual de VFX e tipos de camada"

# VFX gratuitos para Anime Verse Battlegrounds

Esta pasta reúne **fontes visuais gratuitas de efeitos** para bolas de energia, anéis, raios e explosões. Os arquivos em `free_sources/` são os downloads originais. Os arquivos em `prepared/` são cópias técnicas preparadas para importação, sem alterar a licença do material original.

> **Importante:** o Rojo sincroniza o código e os arquivos do projeto, mas um PNG local não se torna automaticamente uma textura jogável no Roblox. Para uso em `ParticleEmitter.Texture`, `Trail.Texture` ou `ImageLabel`, a imagem precisa ser importada/publicada no Roblox e receber um `rbxassetid://<id>`. Os IDs reais não devem ser inventados no código.

## Pacote incluído

| Asset | Arquivo preparado | Licença | Uso sugerido |
|---|---|---|---|
| Energy Ball | `free_sources/energy_ball_ccby30.png` | CC-BY 3.0 | Carga, esfera viajando e núcleo de `comet_shoulder` |
| Power Rings | `free_sources/power_ring_cc0.png` | CC0 | Onda de choque, burst radial e `pulse_release` |
| Lightning Shock Spell | `prepared/lightning_shock_8bit.png` | CC-BY 3.0 | Arco/rajada direcional para `broken_cadence` |
| Explosion 0003 | `prepared/explosion_0003_cc0_1024px.png` | CC0 | Impacto confirmado de Cometa ou finalização |
| Explosion 0005 | `prepared/explosion_0005_cc0_1024px.png` | CC0 | Variante de impacto ou morte de inimigo |

Os arquivos preparados ainda são spritesheets. Eles devem ser recortados por `FlipbookLayout`/`FlipbookFrames` quando o emissor do Roblox suportar a configuração desejada, ou separados em imagens individuais caso o efeito use `Trail`, `Beam` ou uma superfície animada. O catálogo em `src/shared/Data/AbilityVfx.luau` continua sendo a fonte da duração, do raio e da exigência de confirmação autoritativa.

## Atribuição

Para os dois assets CC-BY, inclua no crédito do jogo e mantenha o aviso abaixo em qualquer distribuição que contenha as imagens:

> Energy Ball — por yiannisd, OpenGameArt.org, licença CC-BY 3.0: https://opengameart.org/content/energy-ball  
> Lightning Shock Spell — por Clint Bellanger, OpenGameArt.org, licença CC-BY 3.0: https://opengameart.org/content/lightning-shock-spell

Os assets CC0 não exigem atribuição, mas suas páginas de origem ficam registradas para rastreabilidade:

> Power Rings — por Oiboo, OpenGameArt.org, CC0: https://opengameart.org/content/power-rings  
> Explosion spritesheet low res — por dirkwybe, OpenGameArt.org, CC0: https://opengameart.org/content/explosion-spritesheet-low-res

## Pack externo não redistribuído

O pack [PIPOYA FREE VFX Time Magic](https://pipoya.itch.io/pipoya-free-vfx-time-magic) foi avaliado porque tem estética próxima de efeitos de anime e fornece PNGs em 480x480 e 192x192. A página permite uso pessoal/comercial e edição, porém proíbe redistribuir ou revender os assets. Por isso, ele **não foi copiado para este repositório**. Faça o download somente pela página oficial e mantenha-o local à sua conta/projeto conforme os termos do autor.

## Mapeamento visual sugerido

| Técnica/camada atual | Primeiro asset a testar | Estado do efeito |
|---|---|---|
| `comet_aura` | Energy Ball, quadros circulares azul/branco | Pré-ataque; não confirma dano |
| `comet_trail` | Energy Ball, quadro de viagem ou Trail procedural | Deslocamento; não aumenta o alcance |
| `comet_burst` | Explosion 0003 ou 0005 | Somente após confirmação do servidor |
| `comet_ring` | Power Rings | Onda no chão após confirmação |
| `cadence_arc_first/second` | Lightning Shock Spell | Dois arcos em tempos diferentes |
| `pulse_release` | Power Rings | Dispersão da casca |
| `pulse_return_counter` | Power Rings + Explosion | Contra confirmado; não usar na intenção local |

Nenhuma alteração de lógica foi feita neste passo para colocar IDs fictícios. A próxima etapa de implementação deve adicionar os IDs publicados em configuração dirigida por dados, configurar os emissores no `AbilityVfxPlayer` e executar o playtest no Studio com hit, miss, guard e counter.

## Atlas preparados para flipbook

A primeira integração usa os seguintes atlas uniformes gerados por `prepare_vfx_atlases.py`:

| Arquivo | Layout | Uso no combate |
|---|---|---|
| `prepared/energy_ball_4x4.png` | 4×4 | carga, aura e casca do Ombro Cometa/Retorno |
| `prepared/power_ring_2x2.png` | 2×2 | onda de choque, dispersão e contra |
| `prepared/lightning_shock_8x8.png` | 8×8 | dois arcos da Cadência e eco |
| `prepared/explosion_0003_cc0_1024px_8x8.png` | 8×8 | flash/burst do Ombro Cometa |
| `prepared/explosion_0005_cc0_1024px_8x8.png` | 8×8 | burst da Cadência e contra do Pulso |

Os atlas são usados somente quando `src/shared/Data/AbilityVfx.luau` tiver um `assetId` publicado válido para a chave correspondente. Até lá, o `AbilityVfxPlayer` usa o fallback procedural, permitindo testar timing, confirmação autoritativa e limpeza sem depender do upload.

O processo recomendado é importar cada atlas no Roblox Studio, registrar os IDs e substituir apenas `assetId = nil` pelo valor `rbxassetid://...`. Não use o caminho local do Git como `ParticleEmitter.Texture` e não crie IDs fictícios. Após o preenchimento, rode o roteiro de Play documentado em `docs/20-VFX-ASSETS.md`.

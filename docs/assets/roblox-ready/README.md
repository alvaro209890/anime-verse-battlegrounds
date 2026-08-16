# Pacote Roblox-ready

Este diretório contém **variantes tecnicamente preparadas** a partir das referências conceituais em `docs/assets`. A conversão normaliza tamanho e formato e deriva mapas PBR candidatos para uso futuro em `SurfaceAppearance`.

> **Importante:** nenhum arquivo deste diretório está ligado automaticamente ao runtime, a um `MeshPart`, a um decal ou a um ID `rbxassetid://`. A importação final, a publicação dos assets e a validação visual continuam sendo etapas do Roblox Studio.

## Estrutura

| Diretório/arquivo | Conteúdo |
|---|---|
| `textures/*_color.png` | Candidato a `SurfaceAppearance.ColorMap` |
| `textures/*_normal.png` | Candidato a `SurfaceAppearance.NormalMap`; intensidade precisa de revisão |
| `textures/*_roughness.png` | Candidato a `SurfaceAppearance.RoughnessMap` |
| `textures/*_metalness.png` | Candidato a `SurfaceAppearance.MetalnessMap` |
| `references/*_emissive_mask.png` | Máscara de emissão para referência; não é conectada automaticamente |
| `references/*_preview.jpg` | Preview leve para documentação, briefing e revisão |
| `roblox-asset-manifest.json` | Mapeamento de fontes, outputs, dimensões, hashes e conjuntos PBR |

## Conjuntos preparados

Foram preparados três conjuntos de textura:

| Conjunto | Tamanho | Uso pretendido |
|---|---:|---|
| `avb_slate_cracked_floor` | 1024 × 1024 | Piso de arena slate com fissuras ciano/violeta |
| `avb_runed_stone_wall` | 1024 × 1024 | Muro modular com runas discretas |
| `avb_crystal_emissive_strip` | 1024 × 683 | Faixa emissiva e motivos de cristal |

O arquivo [`roblox-asset-manifest.json`](roblox-asset-manifest.json) é a fonte canônica do mapeamento entre cada conjunto e seus cinco outputs.

## Procedimento de importação no Studio

No Roblox Studio, importe primeiro apenas o `ColorMap` de um conjunto em uma textura de teste e confirme o tiling em um `MeshPart` ou peça de teste. Depois, crie um `SurfaceAppearance` e associe os mapas `ColorMap`, `NormalMap`, `RoughnessMap` e `MetalnessMap` pelos campos correspondentes. O `NormalMap` deve ser validado com intensidade baixa antes de qualquer ajuste de material.

A máscara emissiva não deve ser colocada automaticamente em um campo inexistente. Para brilho, use a solução de material, `Neon`, partículas ou VFX que o projeto escolher após medir custo e legibilidade mobile. O PNG é apenas uma referência para separar a camada emissiva.

Depois da importação, registre no documento canônico o ID real do asset, quem publicou, data, licença, tamanho final, compressão, uso no place e evidência de Playtest. Não use `rbxassetid://0`, IDs temporários ou nomes de arquivo como mecanismo de ligação.

## Reprodução

A conversão pode ser refeita de forma determinística com:

```bash
python3 scripts/prepare_roblox_assets.py --clean
```

Para só completar JPEGs de briefing que faltam, **sem** regenerar os mapas PBR (os hashes atuais são a linha de base):

```bash
python3 scripts/prepare_roblox_assets.py --previews-only
```

O script preserva os PNGs de origem, grava somente em `docs/assets/roblox-ready` e recalcula o manifesto. Não há dependência de rede nem chamada a serviço externo nessa etapa. `--clean` e `--previews-only` não combinam.

## Limites da conversão

A conversão não cria meshes, decals, partículas, animações, IDs publicados, `SurfaceAppearance` dentro do place, materiais Roblox ou integração em `WorldService`. As imagens de props, VFX, animação, domínio e habilidades futuras permanecem previews de referência. **Skin de NPC não se importa daqui:** ver [`docs/34-CODE-DRIVEN-SKINS.md`](../../34-CODE-DRIVEN-SKINS.md). O veredito por arquivo está em [`docs/33-ASSET-USABILITY.md`](../../33-ASSET-USABILITY.md).

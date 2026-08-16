# 33 — Usabilidade dos assets visuais

Este documento responde, com evidência de arquivo, o que as imagens geradas e os pacotes do repositório **podem** e **não podem** virar no Roblox. A fonte executável é [`docs/assets/visual-inventory.json`](assets/visual-inventory.json), gerada e conferida por [`scripts/audit_visual_assets.py`](../scripts/audit_visual_assets.py). A paleta extraída vs. o RGB já no código está em [`docs/assets/art-direction-palette.json`](assets/art-direction-palette.json).

> **Regra desta rodada:** nada aqui liga PNG ao place, inventa `rbxassetid`, muda RGB de runtime, começa F1 ou substitui Play. Imagem gerada por IA é direção. Textura candidata de **chão/muro** ainda precisa de importação (ou S1 mecânico) e W1. **Skin de NPC não entra nessa fila** — é receita Luau (`docs/34`).

## 1. Veredito em uma página

| Família | Dá para usar? | Como | Bloqueio |
|---|---|---|---|
| Capa + thumbnail 1920×1080 + ícone 512 | **Sim, como vitrine** | Peças já derivadas em `roblox-ready/store/` | Gate P1, busca de marca, leitura em 150 px. `published: false` |
| Piso slate + muro rúnico (PBR 1024) | **Sim, como candidato de `SurfaceAppearance`** | Color/Normal/Roughness/Metalness já gerados | Importar no Studio; **não** substituir o greybox procedural sem W1 |
| Faixa de cristal emissiva | **Sim, como trim** | ColorMap 1024×683 + máscara de referência | Não é flipbook; bloom precisa de orçamento mobile |
| Props (beacon, arandela) | **Só como briefing de modelagem** | Silhueta clara, chunky, compatível com Part | Não são meshes. Reconstruir nativo |
| Boards de VFX (guarda, dash, chão) | **Já estão no código como receita** | `AbilityVfx.guard_raise` / `dash_run` / impacto | Não importar o PNG como decal |
| Boards de animação | **Só pose R15** | Comparar no A1 com `PlayerCombatAnimator` | Catálogo de clipes de combate continua vazio de propósito |
| Atlas de domínio | **Direção de mundo F0→F2** | W1 no Bastião/Planície | Distrito Lumen e ruínas são F1/F2 |
| Habilidades futuras (8 PNGs) | **Não implementar agora** | Catálogo `docs/27` | Sem spec server-side; F0 não ganha habilidade nova |
| Zip Kenney Particle Pack | **Arquivo + subconjunto já extraído** | slash/spark/scorch em `AVB-free-vfx-assets` | Zip não entra no Rojo; `assetId` continua `nil`; **não** é pele de NPC (`docs/34`) |
| Nature Kit | **Só licença** | README + License.txt | Malhas **não** foram versionadas; reconstruir forma em Parts (S0), não importar |
| Skins F0 (4 atores) | **Já usáveis por código** | `WorldPresentation.rigFor` / `shardGearFor` | Não importar PNG/mesh; Play só olha; ver `docs/34` |
| Atlas de VFX gratuitos (energy ball, anel, raio, explosão) | **Candidato de upload** | `prepared/*` no catálogo `AbilityVfx` | PNG local ≠ `ParticleEmitter.Texture` |
| Áudio Kenney CC0 (305 `.ogg`) | **Candidato de upload** | `CombatAudio.sourceFile` já aponta os arquivos | Runtime ainda usa placeholder do criador Roblox |

Nenhuma família acima está `runtimeLinked`. O inventário trava isso.

## 2. O que a análise das imagens mostrou

As 31 PNGs em `docs/assets/*.png` são conceito original do projeto (slate escuro, ciano de rota, violeta umbral, âmbar de serviço, silhuetas blocky). Elas **não** são tilesets recortáveis, spritesheets de produção nem KeyframeSequences.

Pontos concretos, olhando o arquivo e não o prompt:

- **Capa** (`anime-verse-battlegrounds-cover.png`, 2560×1440): melhor peça pública. Título desenhado na faixa superior. O ícone 512 recorta **abaixo de 41% da altura** de propósito — um quadrado central cortaria `ANIME VERSE` / `BATTLEGROUNDS` no meio. Thumbnail 1920×1080 é redução direta 16:9. Publicar exige P1; a experiência continua privada.
- **Piso slate e muro rúnico** (1920×1920): parecem tileable, com fissuras ciano/violeta. Os ColorMaps 1024 em `roblox-ready/textures/` preservam a leitura. Candidatos reais a `SurfaceAppearance`, ainda desligados do greybox.
- **Faixa de cristal**: trim horizontal, não chão. Fundo quase preto + núcleos ciano/violeta — boa máscara emissiva, mau albedo de parede inteira.
- **Beacon e arandela**: conceito de prop de três quartos. Dá para reconstruir com Part, Neon e um `PointLight`. Não há malha no Git.
- **Boards de VFX**: já vêm em camadas numeradas (casca, anéis, motes, anel de base; afterimages; contato→crack→poeira→debris→flash→dissipação). Isso é receita para `AbilityVfx`, não um PNG para colar no emissor.
- **Boards de pose**: R15 blocky, cachecol vermelho, aura violeta. Servem de alvo visual para o animator procedural. Não substituem clip.
- **Domínio**: Bastião → portão → planície → Distrito Lumen. Útil no W1 para perguntar “a praça e o portão se lêem?”. Inútil como heightmap.
- **Habilidades futuras**: projétil, área, burst, constructo, barreira, ultimate, ruptura, microbiblioteca. Linguagem visual boa; **contrato de combate inexistente**. Ficar no catálogo.

## 3. Paleta: extraída vs. runtime

O quadro-mãe foi amostrado. Os números extraídos **não** foram copiados para Luau.

| Papel | Extraído da arte | Já no código | Ação |
|---|---|---|---|
| Pedra | `[82,81,90]` | `SceneryPresentation.wallColor` `[74,78,88]` | Família próxima. Manter greybox |
| Ciano de rota | `[52,157,221]` | `lightColor` `[144,216,255]` | Runtime mais pálido, de propósito (legível sem bloom) |
| Violeta | `[79,34,134]` | `AbilityVfx.UMBRAL_EDGE` `[88,60,138]` | Família próxima |
| Núcleo pálido | mist `[153,150,162]` | `AbilityVfx.UMBRAL_CORE` `[214,206,232]` | Runtime ainda mais claro para efeitos reduzidos |
| Âmbar de serviço | arandela `[201,113,15]` | `RETURN_EDGE` `[168,116,52]` | Família âmbar; o céu do quadro-mãe é entardecer vermelho, **não** usar como luz de serviço |

Há **três** `UMBRAL_CORE` no código (`AbilityVfx` 214,206,232 · `WorldPresentation` 226,214,250 · `SpawnDecorations` 206,196,224). É drift documentado. Unificar só depois do Play. O `--check` da auditoria trava os nove literais da paleta contra o Luau: se alguém recolorir o runtime, o CI quebra até o JSON ser atualizado de propósito.

## 4. Caminhos que estavam errados nos planos

| Documento | Erro | Correção |
|---|---|---|
| `docs/27` | Zip Kenney em `assets/open-candidates/` | O arquivo real é `docs/assets/open-candidates/kenney_particle-pack.zip` (15.001.764 bytes, SHA-256 `b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958`, 193 PNG + `License.txt`) |
| `docs/24` / `AI-GENERATED-ASSETS.md` | Hashes só no pacote F0 (`docs/30`) | Hashes de **todos** os 31 PNGs conceituais passam a viver no inventário |
| CI | Não conferia imagens | `python3 scripts/audit_visual_assets.py --check` entra no workflow e no `scripts/ci.sh` |
| Nature Kit | Citado como fonte de rochas | No Git só há licença. O mundo continua procedural |

O Particle Pack **já** alimenta inimigos: `slash_01`, `spark_01`, `scorch_01` em `AVB-free-vfx-assets/assets/vfx/kenney/`, com `assetId = nil`. O zip é o arquivo do pacote completo (transparent + fundo preto + Unity sample), não um segundo runtime.

## 5. Pipeline reproduzível

```bash
python3 scripts/audit_visual_assets.py --check          # stdlib; o CI roda isto
python3 scripts/prepare_roblox_assets.py --previews-only # JPEGs de briefing que faltam; não regenera PBR
python3 scripts/verify_roblox_assets.py                 # Pillow; hashes dos 43 outputs
python3 scripts/prepare_store_art.py                    # thumbnail + ícone a partir da capa
```

`--previews-only` existe para não reescrever os mapas PBR (os hashes atuais são a linha de base). `--clean` no prepare apagaria esses mapas e exigiria revisão visual de novo.

Previews JPEG novos cobrem domínio, combate e habilidades futuras, todos em `docs/assets/roblox-ready/references/*_preview.jpg`. Continuam briefing: não são decal.

## 6. Ordem de promoção (quando houver Studio)

1. **Não promover** habilidades futuras, Distrito Lumen, ruínas modulares.
2. **P1** antes de qualquer arte pública (capa, ícone, thumbnail, nome).
3. **W1:** greybox atual vs. `domain-expansion-safe-plaza` e `border-gate`. Só então considerar um ColorMap de piso numa peça de **teste**, não no volume inteiro.
4. **A1:** poses e VFX de guarda/dash/impacto contra os boards; upload de atlas `prepared/` e dos `.ogg` é independente e também exige ID real.
5. Qualquer `assetId` preenchido precisa casar `rbxassetid://%d+` e o arquivo publicado. Caminho de Git não é `Texture`.
6. **Skins de NPC não passam por esta fila de importação.** Roupa é S0 (primitivas) ou S1 (mesmo contrato do áudio). Plano: [`docs/34-CODE-DRIVEN-SKINS.md`](34-CODE-DRIVEN-SKINS.md).

## 7. O que esta rodada não faz

- Não começa F1, loadout, Ressonância nem habilidade nova.
- Não altera `SceneryPresentation.STYLE`, `AbilityVfx` RGB, câmera do pesado nem HP de catálogo.
- Não faz upload, não inventa ID, não marca W1/A1/R1/W2.
- Não trata o CI verde como evidência de Play.

O próximo estado de produto continua o do snapshot: no PC, `avb-debug home` → sync → Play no dummy.

# Assets visuais gerados por IA

Este diretório contém imagens originais geradas por IA para a direção de arte e o planejamento da expansão de domínio do Anime Verse Battlegrounds. Elas são referências conceituais do projeto, não modelos 3D publicados, não texturas de runtime e não substituem a validação de licença de qualquer asset externo usado na implementação.

## Convenção

Os arquivos `domain-expansion-*.png` usam a paleta conceitual do mundo: Slate escuro, ciano para rotas e fronteiras, violeta para domínio/energia e âmbar para serviços e alertas. Os nomes são estáveis para permitir que documentos, tickets e futuras revisões apontem para a mesma referência.

| Arquivo | Função | Não usar como |
|---|---|---|
| `domain-expansion-concept.png` | Capa e escala geral Bastião → Planície → Distrito Lumen | Mapa navegável ou textura |
| `anime-verse-battlegrounds-cover.png` | Capa geral do jogo, arena e identidade de batalha | Thumbnail de runtime, decal ou textura |
| `domain-expansion-district-lumen.png` | Direção da cidade, ruas e passarelas | Planta final ou cenário já implementado |
| `domain-expansion-safe-plaza.png` | Praça segura, spawn, treino e serviços | Guia de colisão ou layout autoritativo |
| `domain-expansion-border-gate.png` | Referência da fronteira e duas rotas | Contrato de dano ou regra de PvP |
| `domain-expansion-modular-ruins.png` | Biblioteca de peças para futura modelagem | Atlas Roblox ou malha 3D importável |
| `domain-expansion-vfx-moodboard.png` | Hierarquia cromática de telegraphs e VFX | Partículas prontas para produção |
| `combat-presentation-reference.png` | Referência-mãe de defesa, dash, materiais e escala de impacto | Captura de runtime ou atlas jogável |
| `defense-guard-presentation.png` | Silhueta da defesa, casca ciano, órbitas e faíscas | Decal ou bloqueio confirmado |
| `dash-run-presentation.png` | Preparação, passada, afterimages e atrito da corrida | Animação publicada ou teleport visual |
| `ground-break-impact-presentation.png` | Sequência de crack, estilhaço, poeira e dissipação | Alteração permanente de piso/colisão |
| `impact-vfx-micro-library.png` | Motivos reutilizáveis de anel, rastro, crack e debris | Spritesheet de produção sem preparação |
| `ability-future-energy-projectile.png` | Direção de projétil, carga, trail e impacto | Habilidade pronta ou dano confirmado |
| `ability-future-area-domain.png` | Direção de área, perímetro e pulsos | Zona PvP ou colisão autoritativa |
| `ability-future-mobility-burst.png` | Direção de burst, afterimage e recuperação | Teleporte ou deslocamento real |
| `ability-future-summon-construct.png` | Silhueta de constructo temporário | NPC jogável sem spec de ownership |
| `ability-future-barrier-parry.png` | Barreira, deflexão e janela visual | Bloqueio confirmado por imagem |
| `ability-future-ultimate-composition.png` | Direção cinematográfica de ultimate futura | Ultimate implementada ou câmera final |
| `ability-future-environment-break.png` | Crack, debris, poeira e restauração | Alteração persistente de chão |
| `ability-future-vfx-micro-library.png` | Biblioteca de motivos para receitas futuras | Spritesheet de produção sem conversão |

## Licença e procedência

As imagens desta lista foram geradas para este projeto e devem ser tratadas como **conceito visual original**. Não foram baixadas de uma franquia, personagem ou pacote comercial. Assets externos gratuitos continuam documentados em `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md` e `docs/25-COMBAT-PRESENTATION-PLAN.md`; cada pacote externo precisa ser verificado individualmente antes de entrar no repositório ou no Roblox Studio.

## Navegação e validação

O índice de uso está em `../../VISUAL-REFERENCE-INDEX.md`. O protocolo de captura e aprovação está em `../26-VISUAL-VALIDATION-CHECKLIST.md`. Esses documentos transformam as imagens em referências comparáveis para animações, VFX, HUD e mundo, mas não promovem nenhum PNG a asset de runtime.

## Pipeline futuro

Quando uma imagem for aprovada como referência, a produção deve separar: conceito, modelagem/peça Roblox, colisão, textura, iluminação, otimização mobile, integração por Rojo, adaptação para HUD/loading quando aplicável e teste de runtime. O catálogo de habilidades futuras está em `../27-FUTURE-ABILITY-ASSET-CATALOG.md`. O candidato público arquivado está em `open-candidates/kenney_particle-pack.zip`; ele é CC0 conforme a fonte oficial, mas permanece fora do runtime até conversão, seleção e validação.

Nenhuma imagem deste diretório deve ser ligada automaticamente ao place por nome de arquivo.

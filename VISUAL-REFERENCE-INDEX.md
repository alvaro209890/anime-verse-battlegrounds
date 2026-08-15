# Índice de referências visuais

Este índice conecta as imagens conceituais do Anime Verse Battlegrounds aos documentos, sistemas e gates de validação. As imagens são **referências de direção e comparação**, não evidência de runtime e não devem ser ligadas automaticamente ao place por nome de arquivo.

## Como usar

Comece pela linha da referência desejada. Consulte o documento canônico, revise a receita ou pose relacionada e, somente depois, execute o protocolo em `docs/26-VISUAL-VALIDATION-CHECKLIST.md`. Uma referência só pode ser promovida a asset de runtime depois de produção separada, revisão de licença, otimização e validação no Roblox Studio.

| Referência | Sistema orientado | Documento canônico | Fase | Evidência necessária |
|---|---|---|---|---|
| `docs/assets/combat-presentation-reference.png` | Direção de câmera, escala, materiais e contraste | `docs/25-COMBAT-PRESENTATION-PLAN.md` | F0/A0 | Capturas frontal, perfil e três quartos com e sem VFX |
| `docs/assets/defense-guard-presentation.png` | Pose de defesa, casca e feedback local | `docs/14-ANIMATION-PLAN.md`, `docs/07-SECURITY.md` | F0/A1 | Entrada/sustentação/saída; bloqueio confirmado separado do VFX local |
| `docs/assets/dash-run-presentation.png` | Dash em compressão, aceleração, passada e recuperação | `docs/25-COMBAT-PRESENTATION-PLAN.md` | F0/A1 | Quatro fases, foot sliding, deslocamento server-side e recuperação |
| `docs/assets/ground-break-impact-presentation.png` | Crack, poeira, debris e dissipação | `docs/15-WORLD-PRESENTATION.md`, `docs/25-COMBAT-PRESENTATION-PLAN.md` | F0 → F1 | Sequência temporal, pooling, ausência de colisão alterada |
| `docs/assets/impact-vfx-micro-library.png` | Motivos de anel, rastro, faísca e impacto | `docs/25-COMBAT-PRESENTATION-PLAN.md` | F0 → F2 | Reuso consistente, limite de partículas e legibilidade mobile |
| `docs/assets/domain-expansion-concept.png` | Escala do Bastião à Planície e ao Distrito Lumen | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md` | F0 → F2 | Leitura de rotas, zonas e densidade no Studio |
| `docs/assets/anime-verse-battlegrounds-cover.png` | Capa geral, arena e identidade cromática do jogo | `docs/29-GAME-COVER.md` | F0 | Uso documental; não é evidência de runtime |
| `docs/assets/domain-expansion-district-lumen.png` | Células urbanas e marcos verticais | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md` | F1/F2 | Uma célula modular construída, navegável e performática |
| `docs/assets/domain-expansion-safe-plaza.png` | Spawn, treino, serviços e saídas | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md`, `docs/15-WORLD-PRESENTATION.md` | F0/F1 | W1: spawn, cobertura, rotas, prompts e colisão |
| `docs/assets/domain-expansion-border-gate.png` | Fronteira segura/livre e beacons | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md`, `docs/07-SECURITY.md` | F0 | W1/R1: telegraph, transição e regra PvP no servidor |
| `docs/assets/domain-expansion-modular-ruins.png` | Biblioteca para futuras células de ruínas | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md` | F1/F2 | Peças com colisão, densidade e orçamento mobile |
| `docs/assets/domain-expansion-vfx-moodboard.png` | Hierarquia cromática de risco, rota e telegraph | `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md` | F0 → F2 | Acessibilidade sem depender somente de cor |
| `docs/assets/ability-future-energy-projectile.png` | Projétil energético futuro | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Spec server-side, A1 e W2 |
| `docs/assets/ability-future-area-domain.png` | Área/domínio temporário futuro | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Spec de zona, R1 e W2 |
| `docs/assets/ability-future-mobility-burst.png` | Mobilidade avançada futura | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Movimento autoritativo, R1 e A1 |
| `docs/assets/ability-future-summon-construct.png` | Constructo invocado futuro | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Ownership, despawn e segurança |
| `docs/assets/ability-future-barrier-parry.png` | Barreira/parry futuro | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Confirmação server-side e A1/R1 |
| `docs/assets/ability-future-ultimate-composition.png` | Ultimate futura | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Spec completa, mobile e câmera |
| `docs/assets/ability-future-environment-break.png` | Ruptura de cenário futura | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Colisão, restauração, W1 e W2 |
| `docs/assets/ability-future-vfx-micro-library.png` | Motivos de VFX futuros | `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` | F1/F2 | Reuso, densidade e acessibilidade |

## Estados permitidos

| Estado | Significado |
|---|---|
| **Conceito** | PNG original usado para direção, comparação e briefing. |
| **Receita headless** | Pose/VFX determinístico testado sem Instances reais. |
| **Candidato externo** | Asset aberto registrado, ainda não integrado nem necessariamente baixado. |
| **Runtime validado** | Integração observada no Roblox Studio com evidência reproduzível. |

O estado atual das imagens permanece **Conceito**. As receitas de defesa e dash possuem também estado **Receita headless**; nenhum dos gates W1/A1/R1 é concluído por este índice.

## Documentos relacionados

- [`docs/25-COMBAT-PRESENTATION-PLAN.md`](docs/25-COMBAT-PRESENTATION-PLAN.md): matriz de combate, usos, hashes e candidatos abertos.
- [`docs/26-VISUAL-VALIDATION-CHECKLIST.md`](docs/26-VISUAL-VALIDATION-CHECKLIST.md): protocolo de captura e decisão.
- [`docs/14-ANIMATION-PLAN.md`](docs/14-ANIMATION-PLAN.md): gates de animação e critérios de clip.
- [`docs/15-WORLD-PRESENTATION.md`](docs/15-WORLD-PRESENTATION.md): gate W1 e apresentação do mundo.
- [`docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md`](docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md): atlas do mundo.
- [`docs/assets/AI-GENERATED-ASSETS.md`](docs/assets/AI-GENERATED-ASSETS.md): procedência, hashes e limites dos PNGs.
- [`docs/27-FUTURE-ABILITY-ASSET-CATALOG.md`](docs/27-FUTURE-ABILITY-ASSET-CATALOG.md): habilidades futuras, assets públicos, licenças e promoção para produção.

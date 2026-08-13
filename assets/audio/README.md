# Efeitos sonoros (SFX) — fonte para o jogo

Banco de efeitos sonoros **livres de royalties** baixado em 2026-08-13 para uso no Anime Verse Battlegrounds.

## Origem e licença

Todos os packs vêm do [Kenney.nl](https://kenney.nl/assets) e usam licença
**[Creative Commons CC0 (domínio público)](https://creativecommons.org/publicdomain/zero/1.0/)**:
permitem uso comercial, modificação e redistribuição **sem atribuição obrigatória**.
Atribuir os créditos ao Kenney é boa prática, mas não é exigido pela licença.

Isso está de acordo com a política de conteúdo original do projeto
(`docs/06-ROADMAP.md` § 1, princípio 5): CC0 é domínio público declarado, não material derivativo.

| Pack | Arquivos | Uso no jogo |
|---|---|---|
| `ui-audio/` | 50 | cliques, rollover, switches, toques de menu e HUD |
| `impact-sounds/` | 130 | golpes (leve/pesado), soco, metal, madeira, vidro, guarda/bloqueio, passos em 5 pisos |
| `sci-fi-sounds/` | 70 | habilidades/energia, lasers, explosões, telegraph, campo de força, dash/thruster, portas |
| `rpg-audio/` | 50 | foley fantasia: armas, couro, livros, moedas, facas, creaks, passos |

## Mapeamento sugerido para sistemas do jogo (F0)

| Sistema do jogo | Sons candidatos |
|---|---|
| Ataque leve/pesado (impacto) | `impact-sounds/impactPunch_*`, `impactMetal_*`, `impactWood_*` |
| Guarda / bloqueio / quebra de guarda | `impact-sounds/impactPlate_*`, `impactBell_heavy_*`, `impactMetal_heavy_*` |
| Dash / deslocamento | `sci-fi-sounds/thrusterFire_*`, `spaceEngineSmall_*` |
| Habilidades ativas (energia) | `sci-fi-sounds/laser*`, `forceField_*`, `explosionCrunch_*`, `lowFrequency_explosion_*` |
| Telegraph de área de risco | `sci-fi-sounds/computerNoise_*`, `laserRetro_*` |
| Inimigo PvE (spawn/morte) | `sci-fi-sounds/explosionCrunch_*`, `impactSoft_*` |
| Passos (5 pisos do mundo) | `impact-sounds/footstep_grass_*`, `footstep_concrete_*`, `footstep_wood_*` etc. |
| HUD / menus / tracker de objetivo | `ui-audio/click*`, `rollover*`, `switch*` |
| Interação com Instrutor/Marco (ProximityPrompt) | `ui-audio/switch*`, `rpg-audio/metalClick`, `bookOpen` |

## Uso no Roblox

- Os arquivos já estão em **OGG** — formato aceito no upload de áudio do Roblox.
- Para publicar: faça upload de cada som como **Sound** na experiência e guarde os IDs
  em um catálogo dirigido por dados (padrão do projeto, ver `docs/11-ABILITY-SPEC.md`),
  em vez de `rbxasset://` local.
- Cada pack mantém seu `License.txt` original na raiz da própria pasta.
- Os arquivos `.url` e `Preview.ogg` de cada pack foram removidos; as URLs originais estão abaixo.

## Links originais

- UI Audio: https://kenney.nl/assets/ui-audio
- Impact Sounds: https://kenney.nl/assets/impact-sounds
- Sci-fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- RPG Audio: https://kenney.nl/assets/rpg-audio

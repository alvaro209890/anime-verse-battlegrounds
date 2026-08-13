# Trilha sonora (BGM) — fonte para o jogo

Banco de músicas **livres de royalties** baixado em 2026-08-13 para uso no Anime Verse Battlegrounds. Nenhum código foi alterado; estes arquivos são apenas assets de referência.

## Origem e licenças

| Origem | Licença | Obriga atribuição? |
|---|---|---|
| [Kenney.nl](https://kenney.nl/assets/music-jingles) (Music Jingles) | CC0 (domínio público) | Não |
| [OpenGameArt.org](https://opengameart.org) (faixas individuais) | CC0 (domínio público) | Não |

CC0 é domínio público declarado, compatível com a política de conteúdo original do projeto (`docs/06-ROADMAP.md` § 1, princípio 5). As faixas do OpenGameArt foram verificadas uma a uma na página de cada autor (aba "License(s)").

## Conteúdo

### `kenney-music-jingles/` — 85 jingles curtos (CC0)

5 estilos × 17 faixas: `8-Bit`, `Hit`, `Pizzicato`, `Sax`, `Steel` (`.ogg`).
Uso: feedback de UI, jingles de vitória/derrota, toques de aquisição de técnica, marcações de objetivo.

### `opengameart/` — 6 faixas de BGM (CC0)

| Arquivo | Autor | Uso sugerido |
|---|---|---|
| `battle-theme-a_cynicmusic.mp3` | cynicmusic (Pixelsphere) | Tema de combate PvE/PvP — épico, cordas e metais |
| `jrpg-epic-rock-battle_intro.mp3` (2 s) + `jrpg-epic-rock-battle_loop.mp3` | HydroGene | Tema de boss/JRPG — intro + loop costurados |
| `victory-theme-rpg_cynicmusic.mp3` | cynicmusic | Tela/tracker de vitória, pós-combate |
| `exploring-town_springspring.ogg` | Spring Spring | Vila segura — chiptune rompy |
| `the-bards-tale_randommind.mp3` | RandomMind | Vila/taverna medieval — flauta, loopável |

## Mapeamento sugerido para o mundo F0

| Cena | Faixa |
|---|---|
| Menu / loading | jingle `Steel` ou `Pizzicato` curto |
| Vila segura | `exploring-town_springspring.ogg` ou `the-bards-tale_randommind.mp3` |
| Zona livre (combate) | `battle-theme-a_cynicmusic.mp3` |
| Inimigo/evento forte | `jrpg-epic-rock-battle_intro.mp3` + loop |
| Objetivo completado | `victory-theme-rpg_cynicmusic.mp3` ou jingle `Hit` |
| Feedback de UI (cliques, switches) | `kenney-music-jingles/Audio/8-Bit jingles/*` (alternativa aos SFX `ui-audio`) |

## Uso no Roblox

- `.ogg` e `.mp3` são formatos aceitos no upload de áudio do Roblox.
- Para publicação: suba cada faixa como **Sound** na experiência e guarde os IDs num catálogo dirigido por dados (padrão do projeto).
- BGM longa deve ser loopável; as faixas `_loop`/`_intro+loop` já vêm preparadas.
- Atribuição não é exigida (CC0), mas é boa prática citar autores nos créditos do jogo.

## Links originais

- Music Jingles (Kenney): https://kenney.nl/assets/music-jingles
- Battle Theme A: https://opengameart.org/content/battle-theme-a
- JRPG Epic Rock Battle Theme #1: https://opengameart.org/content/jrpg-epic-rock-battle-theme-1
- Victory Theme for RPG: https://opengameart.org/content/victory-theme-for-rpg
- Exploring Town: https://opengameart.org/content/exploring-town
- Medieval: The Bard's Tale: https://opengameart.org/content/medieval-the-bards-tale

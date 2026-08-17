# 35 — Pass visual da UI (17/08/2026)

Paleta semântica única em `src/shared/Data/UiPalette.luau`. Toda cor de HUD,
hotbar, dano, faixa e painel lê daqui. RGB puro; a camada de Instances converte
com `Color3.fromRGB`.

## Paleta (6 eixos)

| Eixo | RGB | Uso |
|---|---|---|
| Vida | 70, 230, 120 | barra do jogador |
| Guarda | 80, 200, 255 | barra de guarda |
| Umbral | 184, 142, 255 | recurso (violeta do cenário) |
| Dano | 255,255,255 / 150,190,255 / 255,200,120 / 255,90,90 | hit / guarda / contra / morte |
| Destaque | 80, 220, 255 e 220, 70, 180 | traço ciano e magenta |
| Perigo | 255, 86, 112 | faixa PvP |

Ghost da barra (dano recente) é vermelho 220,64,86 e só decai rumo ao valor
atual (`UiPalette.ghostFraction`). Não inventa vida.

## O que mudou na tela

- HUD do jogador: cantos, traço, cores vivas, ghost atrás da vida/guarda.
- Barras de inimigo: mais discretas; elite usa vermelho de identidade.
- Hotbar 58×58: slot ativo com glow ciano; locked mais escuro.
- Dano/XP: mesmo gatilho (`damage > 0` / `amount > 0`); contorno da paleta.
- Faixa de zona: verde seguro / vermelho PvP, **e** o texto continua.
- Painéis B/K/J/MENU: fundo violeta-escuro, traço, cantos.

## Honestidade

Gatilhos e timings de combate não mudaram. `shouldShowDamage` e `shouldShowXp`
permanecem. A faixa de zona ainda só reflete `state.pvp` vindo do servidor.

## Testes

`UiPalette.validate` + ghost + delegação de `damageColor`/`xpColor`. Suite
medida no commit desta rodada.

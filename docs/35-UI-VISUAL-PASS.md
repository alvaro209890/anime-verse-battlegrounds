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

## Validação Play (17/08, place `b1893d2` / SHA `71F1BBFA`)

Studio aberto no `.rbxl` de 400.736 B (título
`anime-verse-battlegrounds.rbxl`). Play no MCP, DataModel Client.

Medido ao vivo:

- HUD: HP 70,230,120 · GRD 80,200,255 · UMB 184,142,255. Ghost atrás
  (vida 220,64,86). Faixa `SEGURO` 64,196,160 **e** texto. Flash de nível
  `Visible=false` no spawn. Feedback vazio até evento.
- Hotbar `Abilities.AbilityN` 58×58, `UICorner`+`UIStroke`, número do slot.
  Glow ciano 80,220,255 quando pronto.
- Painéis J/B/K: fundo 18,16,36, traço, cantos. J mostrou `Dano causado 6`
  só depois do `CombatEvent` confirmado.
- Dummy: barra `AvbEnemyBar` fill 224,120,80 (âmbar comum, não a verde do
  herói), `9994/10000` depois do 1º leve e `9988/10000` no 2º. Número
  flutuante `AvbDamage.Value=6` só com `damage > 0`. Dummy não creditou
  kill (carreira monstros 0).
- Combate no dummy a 7,8 studs: alcance efetivo 13, cone 92°. Teleporte
  instantâneo é recusado pelo MotionGuard — o walk legal chegou.
- Mundo: `WildDecorations` 1269 peças `CanCollide=false` maxY 76,7;
  `BiomeDecorations` 352 / maxY 47,8; 0 peça de serra dentro do Bastião.
  Horizonte de picos visível da cobertura e do portão norte.
- Portão norte: faixa continua `SEGURO` até o hold; prompt
  `SEGURE E PARA ATRAVESSAR O PORTÃO` (texto, não só cor).

Correção desta rodada: `hud.help_status` pt/en não cita mais jogo de
terceiro (docs/02 — nomes originais na tela).

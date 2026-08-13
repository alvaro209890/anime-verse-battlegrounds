# 18 — Análise do playtest em vídeo (2026-08-13)

Vídeo: `2026-08-13 13-48-44.mp4` (OBS, 37 s, 1152×720, Play no snapshot
`anime-verse-battlegrounds.rbxl` gerado às 13:46). Análise frame a frame (~1 fps)
antes de qualquer correção.

## 1. O que o vídeo mostrou

O Play abre o Bastião. HUD aparece: **SEGURO**, VIDA/GUARDA/UMBRAL 100/100,
objetivo `Derrote Estilhaços: 0/3` depois de conversar com o Instrutor
(`[E] CONVERSAR`). As três técnicas ficam com **CADEADO**. O cursor do mouse
permanece livre (sem shift-lock). Não há lista de comandos, nem indicador de
mira travada, nem números de dano.

Nenhuma cadeia leve, pesado, Ombro Cometa, Cadência, Pulso ou animação de
Estilhaço foi observada: o playtest ficou no spawn, andando e passando o mouse
nas técnicas bloqueadas.

## 2. O que está bom

- Greybox do spawn lê como pátio (pilares, lanternas, portão com faixa).
- HUD mínimo existe e o prompt nativo `[E] CONVERSAR` funciona.
- Objetivo aparece após o Instrutor.
- Boot do servidor não explodiu (não há Output de erro visível no recorte).

## 3. O que está quebrado (impacto)

1. **Golpe parece morto (P0).** Clique esquerdo *é* o básico, mas o
   `CombatEvent` do básico não levava `damage` e o `StateDelta` da vida do NPC
   não era enviado ao atacante. Sem número flutuante e sem barra, o acerto
   some. As técnicas em CADEADO reforçam a leitura de "nada funciona".
2. **Técnicas em CADEADO no Studio (P0).** `F0Debug=true` estava só no
   DataModel; o Rojo nem sempre carimba atributo na raiz. O gate `StudioDebug`
   existia, mas o playtest não recebeu as flags de sessão.
3. **Mira presa sem saída visível (P0).** A roda do mouse travava a câmera no
   alvo *e* zooma a câmera Roblox. Não havia HUD "MIRA TRAVADA". Tab/clique do
   meio não existiam.
4. **Zero comandos na tela (P0).** Sem overlay, o jogador tenta as técnicas
   cadeadas em vez do clique esquerdo.

## 4. O que falta (depois desta correção)

- Ver a cadeia leve, o dummy e um Estilhaço no Studio (este vídeo não chegou
  lá). Animações não foram julgadas porque não apareceram.
- Áudio de combate ainda depende de upload de asset (docs/16).
- Play com dois clientes, mobile e gamepad.

## 5. Correção desta rodada

- Evento do básico leva `damage` + barra do inimigo no atacante.
- `F0Debug` também no Script Server; join aplica as 3 técnicas de sessão.
- Mira: **Tab** ou clique do meio (roda do mouse saiu — conflitava com zoom).
- Botão **?** / tecla **H** abre a lista de comandos; faixa permanente no
  rodapé; chip "MIRA TRAVADA" enquanto o lock-on está ativo.

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
nas técnicas bloqueadas. Não foi falta de animação no código — o jogador não
tinha como soltar a mira nem via os golpes (CADEADO + evento sem dano).

## 2. O que está bom

- Greybox do spawn lê como pátio (pilares, lanternas, portão com faixa).
- HUD mínimo existe e o prompt nativo `[E] CONVERSAR` funciona.
- Objetivo aparece após o Instrutor.
- Boot do servidor não explodiu (não há Output de erro visível no recorte).

## 3. O que está quebrado (impacto)

1. **Golpe parece morto (P0).** Clique esquerdo *é* o básico, mas (a) o
   `InputBegan` descartava o clique quando a HUD marcava `processed=true`
   (labels, MENU, técnicas) — golpe e animação local nunca disparavam; (b) o
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

## 4. Animações (julgamento em código + testes)

O vídeo não mostrou combate. A cadeia, as técnicas e os NPCs *existem* em
`PlayerCombatAnimator` / `ActorAnimator` e passam `tests/animation.luau`
(35 casos). Julgamento honesto dessa camada procedural — **não são clipes
finais** (`docs/14` Gate A1 continua aberto):

| Peça | Leitura | Nota |
|---|---|---|
| Cadeia leve 1–4 | silhuetas distintas; soco estende cotovelo, chute levanta perna; follow-through elástico; idle respira | boa gramática greybox |
| Pesado / guarda / dash | peso maior no ombro; guarda fecha o volume; dash é overlay curto | suficiente para F0 |
| Ombro Cometa | recolhe, avança, impacto; VFX aura na carga, flash/onda só com confirmação | honesto visualmente |
| Cadência / Pulso | poses próprias (eco e contra não reusam a ativação) | testado headless |
| NPCs | telegraph / ataque / queda / late join | scaffolding, não clip |

Como ver no Studio agora: dummy no canto sudeste; clique esquerdo **ou** o
botão **ATACAR** 4 vezes seguidas; F ou **GUARDA**; Q ou **DASH**; 1/2/3
técnicas (KIT DE TESTE no spawn). Se a câmera grudar, clique **SOLTAR MIRA**.
Feche o MENU (ele some sozinho no primeiro golpe).

## 5. O que ainda falta (runtime)

- Play humano confirmando a cadeia no dummy e um Estilhaço fora do portão norte.
- Áudio de combate ainda depende de upload de asset (`docs/16`).
- Play com dois clientes, mobile e gamepad.

## 6. Correção desta rodada

- Clique de combate ignora `processed` da HUD (labels/frames); só TextBox e
  GuiButton ativo comem o clique. Botão **ATACAR** visível no PC (não só no
  toque). MENU fecha no primeiro golpe.
- Evento do básico leva `damage` + barra do inimigo no atacante.
- `F0Debug` também no Script Server; join aplica as 3 técnicas de sessão.
- Mira: **Tab** ou clique do meio. Botão **SOLTAR MIRA** no centro (não
  procura outro alvo). A roda do mouse não trava — só zooma.
- Botão **MENU** (tecla **H**) abre Configurações: controles, soltar/travar
  mira, ligar/desligar tremor da câmera, onde estão dummy e Estilhaços.

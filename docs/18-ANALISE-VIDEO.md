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

## 7. Segundo playtest — `2026-08-13 14-26-49.mp4` (27,9 s)

Vídeo do Play no snapshot das 14:10, 1152×720. Método: quadros a 1 fps, folhas
de contato a 6–15 fps nos momentos de interesse e uma tira do medidor UMBRAL a
2 fps para localizar os disparos sem depender de memória.

### 7.1 O que o vídeo prova

- MENU/**CONFIGURAÇÕES** abre e lista os controles; **SOLTAR/TRAVAR MIRA** e o
  tremor da câmera estão lá.
- As três técnicas saíram do CADEADO: os botões mostram contagem de recarga.
- **As técnicas dispararam:** UMBRAL cai 100 → 84 → 72 nos primeiros segundos e
  regenera. O servidor cobrou o custo, ou seja, a intenção chegou e foi aceita.
- O jogador anda pelo pátio, chega ao vão do portão norte… e não sai. Volta a
  circular. É o núcleo da reclamação: *"nem da salinha o personagem consegue
  sair"*.
- Nenhum golpe lê como golpe. Com o boneco a ~60 px de altura na gravação, o
  overlay procedural de poucos graus por junta é invisível.

### 7.2 Causas encontradas no código (não são hipóteses)

1. **Portão trancado por design acidental (P0).** O prompt de travessia só
   existia no toque: `UIController` desenhava o botão com
   `state.platform == "Touch" and state.zoneHoldRequired`. No PC ele nunca
   aparecia — e o botão também só respondia a evento `Touch`, então clicar não
   fazia nada. O jogador não tinha como saber que precisa **segurar E**.
2. **Parede invisível (P0).** No Heartbeat, qualquer recusa de entrada de zona
   devolvia o avatar à posição anterior. Como a primeira ida à zona de
   transição é sempre recusada com `hold_required` (o hold é o contrato de
   docs/02 §4.3), o jogador era empurrado de volta a cada frame no vão do
   portão. Somado ao item 1: portão intransponível e sem explicação.
3. **Golpe sem leitura (P0).** O `PlayerCombatAnimator` compõe overlay nos
   Motor6D em cima da animação que o Roblox já toca. Isso funciona como
   tempero, não como golpe: no avatar real não há silhueta nova.
4. **Combate mudo (P1).** Todo `assetId` do catálogo de áudio estava vazio
   esperando o upload dos `.ogg` CC0 — correto por contrato, mas o resultado
   prático era combate sem nenhum som.

### 7.3 Correção desta rodada

- `ZoneService.shouldRestorePosition` decide, em função pura e testada, quais
  recusas devolvem o avatar. `hold_required` **não** devolve: o jogador fica
  parado no vão, a zona lógica continua segura (sem risco de PvP) e o HUD pede
  o hold. Lockout e travessia inválida continuam devolvendo.
- Prompt **SEGURE E PARA ATRAVESSAR O PORTÃO** em qualquer plataforma, botão
  aceitando mouse e toque, e uma linha nova nas Configurações explicando o
  portão. Chaves novas no Locale (PT-BR e EN), cobertas por teste.
- Clipes de animação reais nas ações de ataque, com assets livres do criador
  Roblox e o procedural como fallback (`docs/14` §4.4). Rastro de golpe com
  `Trail` sem textura.
- Kit de áudio placeholder do próprio Roblox em todas as 15 deixas
  (`docs/16` §5.1).

### 7.4 Como conferir no Studio

1. Ande até o vão do **portão norte**. O aviso **SEGURE E PARA ATRAVESSAR O
   PORTÃO** aparece e o avatar **não** é mais empurrado para trás.
2. Segure **E** por ~1 s: a travessia confirma e a HUD sai de SEGURO.
3. No dummy (canto sudeste), 4 cliques seguidos: cada degrau da cadeia agora
   toca um clipe de corpo inteiro diferente, com rastro na mão e som.
4. Se algum clipe não carregar, o Output traz **um** aviso
   `[CharacterAnimationPlayer] clipe … não carregou` e o combate segue com a
   pose procedural.

### 7.5 O que continua não comprovado

O playtest humano desta rodada. Nada aqui foi visto rodando: as correções são
julgadas por leitura de código e cobertas por 255 testes headless. Falta
gravar o Play mostrando a travessia do portão e a cadeia no dummy.

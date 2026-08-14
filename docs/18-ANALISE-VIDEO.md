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

## 8. Playtest pelo MCP (13/08 15h): golpes que não conectam, corpo virado e estado fantasma

O playtest foi dirigido pelo MCP (câmera e inputs injetados no Studio), medindo
distâncias no próprio mundo em vez de ler o código. Três achados que mudaram a
regra de combate:

### 8.1 O que o playtest mostrou

1. **Golpe passava longe (P0).** "Colado no bicho" media **11 studs de centro a
   centro** (torso 2,2 × escala 0,9 + jogador). A hitbox era uma esfera à frente
   de ~6 studs, toda-ou-nada: 1 stud a mais e o golpe sumia sem nenhuma leitura
   de por quê (docs/13 §5.1).
2. **O corpo não virava para a mira (P0).** Com a câmera apontada exatamente
   para o Estilhaço (0°), o corpo estava **122°** virado para outro lado — o
   AutoRotate do Humanoid só gira quem está andando. Como o servidor resolve
   a hitbox pelo look da HumanoidRootPart replicada, o golpe saía para trás do
   jogador e nunca acertava nada.
3. **Estado fantasma de zona (P0).** O jogador andou até **z = −100** (fundo da
   planície) com o HUD escrito SEGURO. Nesse estado nada funciona:
   canDamageCrossBoundary recusa todo dano nos dois sentidos, então golpes
   "não acertam os bichos", os Estilhaços não revidam e o objetivo nunca anda
   (docs/02 §4.3).

### 8.2 Correções desta rodada

- **Aquisição de alvo em cone** (SpatialService.acquireTarget): alcance
  generoso (6 studs de corpo + 3 de folga, cresce no degrau da cadeia),
  abertura horizontal (65° leve / 50° pesado) e **o mais próximo** dentro dela.
  Medido de centro a centro, mas com a folga de corpo: encostar agora conecta.
  O cone é o padrão de battlegrounds e continua 100% servidor — o transform
  replicado informa posição e direção, nunca o cliente.
- **Corpo vira para a mira** (CharacterController.faceAim): o avatar local
  gira a HRP para a direção do alvo travado ou da câmera, desliga o AutoRotate
  por 0,6 s (cobre a ação mais longa da cadeia) e devolve o giro depois. Apenas
  rotação — posição idêntica, então o PlayerMotionGuard não vê deslocamento.
- **Reconciliação de zona** (ZoneService.reconcile): quem já está fisicamente
  na zona livre É da zona livre. O hold continua sendo a porta da frente no
  portão, mas estado lógico e mundo nunca mais divergem; a proteção de 5 s da
  travessia vale igual.
- **Log de combate de Studio** (F0Debug): quando o golpe não conecta, o Output
  diz por quê — fora do alcance? fora do cone? bloqueado pela fronteira?
  (substitui a única evidência anterior, "não acertou nada").
- **Tempos de clipe medidos no Studio** (CombatAnimations.luau): slash = 0,5 s,
  lunge = 1,5 s (AnimationTrack.Length via MCP). A primeira versão chutou
  0,53/0,60 e acelerava o lunge a 1,65× para "caber" — em 1,5 s de clipe isso
  mostrava um quarto do movimento e lia como espasmo (a reclamação "as
  animações estão feias"). Regra nova: o clipe pode passar no máximo 15% da ação
  e quem corta é o runtime (CharacterAnimationPlayer.step para o track com
  fade), não a validação.
- **Toque = ataque leve**: sem botão de atacar na HUD (decisão do Álvaro,
  13/08), tocar no mundo vira o golpe leve; cliques em botões de habilidade
  continuam com os botões.
- **Skin do boneco de treino com assets** (16h): couro, cinto, botas,
  bandagens, rosto clássico (decal), bullseye Neon e base/poste de madeira —
  todos com joints próprios ignorados pelo ActorAnimator (detalhes em docs/15
  §4).

### 8.3 Como conferir no Studio

1. Play: aproxime do Estilhaço e golpeie — agora conecta mesmo "colado".
2. Mire na direção oposta e ataque: o corpo vira para a mira antes do golpe.
3. Ande até a planície sem passar pelo portão (dash/queda): a HUD troca para
   LIVRE e o combate funciona nos dois sentidos.
4. No dummy: a cadeia leve tem 4 degraus com leitura diferente (jab estalado,
   meio com peso, lunge no fim) e o rastro morre com a ação.
5. O boneco de treino já aparece na skin nova (couro + bullseye + madeira).

### 8.4 O que continua não comprovado

Playtest humano completo do combate com os novos alcances, dois clientes,
latência e performance. As correções são cobertas por 257 testes headless
(217 run + 40 animation).


## 9. Sessão 14/08 — "skins horríveis e golpes péssimos": as duas causas medidas

Reclamação do playtest: as skins dos bots do spawn estavam feias e as animações
de golpe, péssimas. As duas foram **medidas no Studio via MCP**, não deduzidas.

### 9.1 O que a medição mostrou

1. **O overlay procedural de combate nunca foi aplicado.** O personagem do
   jogador tem 15 `AnimationConstraint` e **zero `Motor6D`** — o avatar R15
   atual usa o rig por constraint. O `PlayerCombatAnimator` procurava só
   `Motor6D`, então `animator.joints` ficava vazio e as ~1400 linhas de pose
   (quatro silhuetas da cadeia, quadros das técnicas, hit-stop,
   follow-through) não chegavam ao personagem. O jogador via **apenas** o
   clipe de espada acelerado.
2. **O clipe do finalizador/pesado/cometa não era uma animação.** O
   `522638767` "R15 Lunge de Espada" tem keyframes só em 0 e 1,5 s — uma
   interpolação linear entre duas poses. Tocado a 2,7×–2,9× para caber na
   janela do golpe, virava espasmo. O `522635514` "Corte de Espada", medido,
   tem quatro quadros (0 / 0,20 / 0,30 / 0,50) e estrutura legível.
3. **Os bots eram Parts empilhadas com uma esfera de cabeça** — sem proporção
   humana, sem mãos, sem pés.

### 9.2 Correção desta rodada

- Os dois animadores passaram a aceitar `Motor6D` **e** `AnimationConstraint`.
  Um teste puro trava as duas classes nos dois animadores.
- O lunge saiu do catálogo (teste impede o retorno). Entrou **janelamento**
  (`startTimeSeconds`): ações curtas tocam o trecho do golpe (0,20→0,50) em
  velocidade legível em vez do clipe inteiro acelerado. Teto de velocidade caiu
  de 3× para 1,5×. Chute, Ombro Cometa e Retorno de Pulso ficaram **sem clipe**
  de propósito — um corte de espada mentiria sobre essas três, e agora elas têm
  a pose procedural funcionando.
- Os bots do spawn ganharam corpo de **rig R15 oficial** com roupa vinda de
  dado puro validado, mais um passo de assentamento que põe a sola no chão
  (o rig nasce 0,186 stud enterrado). Detalhes em `docs/15` §4.1.

### 9.3 Como conferir no Studio

1. Play, ataque no dummy: os quatro degraus da cadeia agora têm silhueta
   distinta **no corpo** (jab, direto, chute, giro) — não só o braço de espada.
2. O degrau 3 é um chute sem clipe nenhum: a leitura é 100% da pose.
3. Instrutor e boneco de treino: corpo com proporção humana, pés no chão,
   rosto visível sob o capuz, alvo no peito do boneco e poste apoiado no chão.
4. O `!` de telegraph fica logo acima da cabeça, não boiando.

### 9.4 O que continua não comprovado

Playtest humano com as skins e o overlay novos. A captura de tela do plugin do
Studio parou de responder no meio desta sessão, então a validação visual foi
**numérica** (posição da sola, folga de cada peça em relação ao host,
idempotência do assentamento) e não por imagem. As mudanças são cobertas por
262 testes headless (219 run + 43 animation).

## 10. Sessão 14/08 (tarde) — "4 personagens" e "ainda tá muito quadrado"

Dois retornos depois da rodada anterior. O primeiro era erro de processo meu; o
segundo era erro de direção de arte, e tinha razão.

### 10.1 Os 4 personagens não vinham do jogo

`Workspace.AuditInstructor` e `Workspace.AuditDummy` eram **rigs de teste que eu
deixei na sessão de Play** ao auditar a geometria pelo MCP, plantados a poucos
studs dos bots reais. `GreyboxF0.Actors` sempre teve exatamente os dois bots.
Removidos, e a auditoria de agora destrói o que cria e confere o workspace no
fim (`__modelosRestantes`).

Lição de processo: sonda criada em Play tem de ser destruída na mesma execução.
O que fica no workspace o jogador vê como conteúdo do jogo.

### 10.2 "Muito quadrado" tinha duas causas

Vale registrar que a sessão de Play em que isso foi visto ainda rodava o build
**anterior** (todos os atores em `[greybox]`), então parte do que estava na tela
era o corpo antigo. Mesmo assim a crítica valia para a skin nova, por dois
motivos independentes:

1. **A roupa era 100% `Block`.** Caixa sobre caixa não vira personagem por
   melhor que esteja posicionada. Agora volume grande é `Ball` — com tamanho
   não uniforme o Roblox renderiza elipsoide, que é o que dá capuz, ombreira,
   saia e saco —, faixa é `Cylinder` e ponta é `WedgePart`. Teto de 25% de
   blocos travado por teste (`rig_too_boxy`).
2. **O corpo era o R15 cúbico.** `BodyTypeScale = 0` é o boneco clássico. As
   receitas agora declaram escalas e usam `bodyType = 1` (proporção Rthro):
   medido, o corpo vai de 5,19 studs com tronco 2,00×1,60 para 6,28 studs com
   tronco 1,78×1,91.

Detalhe das escalas, das medidas e das regras em `docs/15` §4.2.

### 10.3 Conferido no Studio

Sola cravada no alvo depois do assentamento (0,000 no instrutor, 0,500 no topo
do pad do boneco), nenhuma peça solta longe do corpo, 33 e 34 peças, e workspace
sem sobra. Continua sendo validação **numérica**: o `screen_capture` do plugin
não voltou a responder nesta sessão.

## 11. Sessão 14/08 (fim) — "o personagem só levanta o braço"

O overlay já chegava à tela (§9), mas o golpe continuava ilegível. Duas causas,
as duas medidas no Studio via MCP no personagem real.

### 11.1 As camadas discordavam sobre qual braço ataca

O clipe de espada balança o braço **direito**. O jab procedural — degrau 1 —
soca com o **esquerdo**. E todo ataque solto é o degrau 1: só encadeando é que
se chega ao 2, 3 e 4. Ou seja, o golpe que o jogador mais vê era exatamente
aquele em que as duas camadas puxavam para lados opostos, e o clipe, sendo
animação autoral em prioridade Action, ganhava a tela. Sobrava um braço subindo.

Onde as duas concordavam (pesado), o problema invertia: os ângulos somavam e
hiperestendiam o ombro.

O catálogo de clipes ficou **vazio, por decisão**: o kit do jogo é punho e
chute e o único clipe livre disponível é de espada. A costura para o Gate A1
continua de pé. O rastro do golpe saiu do caminho do clipe para não sumir junto.

### 11.2 A pose tinha dois quadros

Cada degrau era `recolhe → bate`. Com um quadro forte só, o rig cobre o arco
inteiro num segmento e o olho registra a extremidade. Agora são quatro quadros
(neutro → recolhe → **dirige** → impacto), com o "dirige" no ponto em que o
quadril já virou e a mão ainda está a caminho.

Entraram também o **passo à frente** (o corpo entra no golpe em vez de girar no
lugar — visual, a raiz física não sai do lugar) e os **tornozelos** (sem eles o
pé de trás fica colado e o soco lê como braço mexendo num boneco parado).

### 11.3 Medido no personagem real

Percurso do corpo — soma do deslocamento de tronco, cabeça, quadril, pernas e
pés entre os quadros do jab:

| | Quadros | Percurso do corpo |
|---|---:|---:|
| Antes | 2 | 1,30 studs |
| Depois | 4 | **4,36 studs** |

Também foi verificado, isoladamente, que `AnimationConstraint` aceita
translação (1,0 stud pedido → 1,005 medido) e que o passo move o corpo inteiro
(0,220 → 0,220 em todas as partes).

### 11.4 Lição de método

A primeira métrica que usei — distância de cada parte até a pose neutra — deu
"+2%" e quase me fez descartar o passo. Ela é ruim: um deslocamento para a
frente pode aproximar peças do neutro e pontuar baixo mesmo movendo o corpo
todo. A métrica certa é o **percurso entre quadros consecutivos** do golpe.

### 11.5 O que continua não comprovado

Playtest humano. A captura de tela do plugin do Studio segue sem responder, e
os rigs de auditoria da sessão anterior foram removidos (§10.1) — nesta sessão
nada foi criado no workspace.

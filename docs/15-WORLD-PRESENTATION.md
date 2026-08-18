# 15 — Fundação de mundo e apresentação F0

> **18/08 — ColorMaps publicadas.** `upload_image` no Studio publicou os 12
> mapas PBR de `docs/assets/roblox-ready/textures`. As 3 ColorMaps entram no
> runtime via `WorldTextures` (`Texture` no piso, muralha, portões, Marco e
> cratera). Overlay VFX (anel/orbe/raio/queimadura) fica por cima. Registro:
> `assets/published-world-assets.json`.

> **Estado canônico em 2026-08-16:** implementado em código e validado por Selene, StyLua, 241 testes de domínio, 73 de animação/apresentação, 67 de fuzz, 19 de combate ponta a ponta e build Rojo. O artefato de verificação possui 318.988 bytes; isso prova somente a saída do build, não boot ou runtime. A expansão de cenário, os VFX, as skins (agora dirigidas por dados também para os Estilhaços), a reforma visual do spawn, a decoração da planície/rotas/cratera e os cinco sinais de fronteira estão implementados, mas **não houve Play atual no Studio neste snapshot**.

## 1. Objetivo e limite

Esta entrega torna o place reconhecível e navegável antes da produção cara de arte. Ela melhora o que o repositório já possuía — `Parts` criadas pelo `WorldService` — sem importar `.fbx`, `.obj`, `.blend`, textura, áudio ou asset de terceiros.

O recorte entrega:

- serras no horizonte e colinas na planície (catálogo, sem colisão, sem luz nova);
- uma rota clara entre spawn, treino, Portão Norte, Portão Oeste e cratera;
- piso gerado para todos os volumes jogáveis, incluindo as duas transições e o braço livre oeste;
- marcos físicos redundantes com o HUD de zona;
- modelos low-poly funcionais para dummy, instrutor, Estilhaço Errante e Ancorado;
- animação procedural de NPC para idle, locomoção, telegraph, ataque, morte, respawn e late join;
- apresentação procedural local do jogador para leve, pesado, guarda e dash em fases, com receitas VFX locais para defesa, corrida e impacto temporário de chão;
- telegraph com contorno branco e símbolo que não depende somente de cor;
- prompts nativos de interação para Instrutor e Marco de Retorno, com distância/hold revalidados no servidor;
- um gate de unlock para testar as três técnicas no Studio sem remote de cheat;
- dados de apresentação separados das Instances para permitir testes headless, documentados em `docs/25-COMBAT-PRESENTATION-PLAN.md`.

Não entrega:

- clipes R15 finais do jogador;
- animações dedicadas de Ombro Cometa, Cadência Quebrada ou Retorno de Pulso;
- concept art, roupa, cabelo, ícone, textura ou silhueta pública;
- VFX/áudio/câmera final;
- prova de beleza, legibilidade ou desempenho em runtime;
- autorização para avançar os 45 clipes planejados em `14-ANIMATION-PLAN.md`.

## 2. Árvore criada no runtime

`WorldService.init()` reconstrói apenas a pasta que lhe pertence e deixa o resto do place intacto:

```text
Workspace
└── GreyboxF0
    ├── Floors
    │   ├── BastionFloor / PlainFloor / TrainingPad
    │   ├── ZoneFloor_zone_threshold_transition_1..2
    │   ├── ZoneFloor_zone_plain_free_2
    │   ├── SpawnPlaza
    │   ├── PathNorthGate / PathWestGate / PathTraining / PathToCrater
    │   └── EliteCraterBasin + EliteCraterRim_01..16
    ├── Walls
    ├── Landmarks
    │   ├── NorthGate* / WestGate*
    │   ├── NorthBoundaryPost_1..6
    │   ├── ReturnBase / ReturnSpire / ReturnCore
    │   ├── PlainShard_01..07
    │   └── BastionSpawn
    ├── ZoneVolumes
    ├── Actors
    │   ├── TrainingDummy
    │   ├── ThresholdInstructor
    │   └── Actor_* (inimigos vivos)
    └── Anchors
```

`ZoneVolumes` e `Anchors` são invisíveis. A versão anterior deixava os volumes de 50 studs de altura parcialmente transparentes; isso podia encobrir o mapa. A fronteira agora é comunicada pelos portais, postes, troca de solo e HUD, enquanto o volume permanece consultável pelo servidor. Cada caixa X/Z de zona também gera seu próprio piso; assim, a geometria navegável e `zoneAtPosition` compartilham os mesmos volumes e não deixam vãos nas saídas norte/oeste.

## 3. Composição do mundo

| Elemento | Função | Regra |
|---|---|---|
| Praça de spawn | oferece orientação e proteção inicial | centrada na camada segura; `SpawnLocation.Duration = 8` |
| Caminho norte | rota direta para a fronteira e a cratera | 8 studs de largura |
| Caminho oeste | segunda saída com linha de visão quebrada | preserva o muro em L da spec |
| Caminho de treino | liga praça, instrutor e dummy | fica integralmente na zona segura |
| Pisos de zona | fecham Bastião, planície, transições e braço oeste | derivados de `Zones.volumes`, sem coordenada paralela |
| Portais | tornam a passagem de zona impossível de confundir com decoração | forma física + postes claros; cor não é o único sinal |
| Marco de Retorno | diferencia consolidação/respawn de um spawn comum | obelisco neutro, sem ícone ou textura final |
| Cratera | delimita o elite sem virar uma parede maciça | bacia baixa e 16 segmentos com passagens |
| Estilhas de marco | orientam o jogador na planície | sete silhuetas neutras, sem reproduzir referência externa |

A iluminação deixa de ser um crepúsculo fixo (`ClockTime 18.25`) e passa a um **ciclo dia/noite** data-driven (`docs/34-DAY-NIGHT-CYCLE.md`): keyframes em `DayNightCycle.luau`, materialização no `WorldService` (Atmosphere, Bloom, Sky, ColorCorrection e reescala das PointLights do spawn/tochas). O crepúsculo clássico continua no arco como fase `dusk`. Validação headless do catálogo e wiring feita; leitura a olho no Studio ainda pendente.

## 4. Modelos procedurais

As receitas vivem em `src/shared/Data/WorldPresentation.luau`; o módulo guarda apenas números e validações, sem `Instance` ou `Color3`.

| Ator | Forma | Escala | Papel visual |
|---|---|---:|---|
| Dummy de treino | **rig R15** + estopa/palha/alvo | 1,00 | saco de treino amarrado, com poste |
| Instrutora do Limiar | **rig R15** + cabelo longo/casaco-saia | 1,05 | quest giver umbral, silhueta feminina, rosto visível |
| Estilhaço Errante | núcleo + cunhas | 0,90 | ameaça móvel leve |
| Estilhaço Ancorado | núcleo + cunhas | 1,65 | elite reconhecível por escala e massa, não só por cor |

### 4.1 Corpo de rig R15 nos bots do spawn (14/08)

Os dois bots do spawn eram uma torre de Parts com uma esfera no lugar da
cabeça. De longe — que é como o jogador os vê — isso não lê como personagem.
Desde 14/08 o **corpo** deles é o rig R15 oficial do Roblox
(`Players:CreateHumanoidModelFromDescription`), e a **roupa** vem de
`WorldPresentation.rigFor(npcId)`.

Por que o rig oficial e não asset de terceiro: ele não é arte de referência,
não é compra, não sobe nada para o catálogo e existe em qualquer lugar — o
Gate P1 (§17 do `13-F0-SLICE`) continua fechado. Ganha-se de graça proporção
humana, mãos, pés e a malha de cabeça com rosto.

Estrutura resultante (`Actors/<Ator>`):

- `Root` — a Part invisível **ancorada** de sempre: continua sendo a única
  coisa que o servidor move, o dono do atributo `CombatTarget` e a referência
  de alcance. Nada da mudança tocou o domínio.
- `Body` — o rig R15, soldado na `Root` por um `Weld` (`RigWeld`). Todas as
  peças com `CanCollide`/`CanTouch`/`CanQuery` falsos: o corpo é aparência,
  não física. A `HumanoidRootPart` leva `AvbInvisible` para o
  `setActorVisible` não acendê-la.
- `Humanoid` sem nome flutuante, sem barra de vida e com
  `EvaluateStateMachine = false` — senão ele tenta andar, cair e morrer sozinho.

### 4.2 Segunda rodada (14/08 tarde) — "ainda tá muito quadrado"

A primeira versão do rig trocou o corpo mas manteve a roupa em caixas, e o
retorno foi direto: continuava quadrado. Estava certo, e por **duas** razões
independentes:

**(a) A proporção do corpo.** O R15 padrão (`BodyTypeScale = 0`) é o boneco
cúbico clássico. As receitas agora declaram escalas, e `bodyTypeScale = 1`
puxa a proporção para o Rthro — tronco alongado, membro afilado:

| Escala | Valor | Efeito |
|---|---:|---|
| `bodyType` | 1,00 | sai do corpo cúbico, entra a proporção Rthro |
| `proportion` | 0,50 | meio-termo: alonga sem virar palito |
| `head` | 1,14 | cabeça um pouco maior — leitura de anime |
| `width` | 0,92 | ombro menos largo |
| `height` | 0,95 | compensa o alongamento do Rthro |

Comparação medida no Studio: clássico 5,19 studs de altura com tronco
2,00×1,60; com estas escalas, 6,28 studs com tronco 1,78×1,91.

**(b) A roupa.** Toda peça grande virou primitiva curva. A regra, travada por
teste (`rig_too_boxy`): no máximo **25% das peças** podem ser `Block`.

| Primitiva | Serve para | Onde |
|---|---|---|
| `Ball` (tamanho não uniforme = **elipsoide**) | volume orgânico | capuz, cabelo, ombreira, peito do casaco, saia, saco de estopa, remendos, olhos |
| `Cylinder` | anel e faixa | gola, cinto, punho, barra, corda, alvo, poste, base |
| `WedgePart` | ponta | mecha de franja, palha, aba do casaco |

O instrutor tem 33 peças (só as 5 mechas de franja e as 2 abas são cunha; o
resto é elipsoide ou anel); o boneco, 34.

> **⚠️ As medidas do rig valem para ESTAS escalas.** Mexeu em qualquer uma das
> cinco, mede tudo de novo — todo `offsetStuds` da roupa sai do lugar. As
> constantes do rosto (`FACE_PLANE_Z`, `EYE_BAND_TOP`) são derivadas de
> `RIG_HEAD_SIZE` justamente para não ficarem apontando para um plano que não
> existe mais.

Medidas do rig **nestas escalas**, colhidas no Studio em 14/08 e usadas nas
receitas: `Head` 1,253×1,292×1,255 @ +2,029 · `UpperTorso` 1,783×1,910×1,077
@ +0,445 · `LowerTorso` 1,857×0,440×1,077 @ −0,730 · `UpperArm`
0,981×1,416×1,069 @ ±1,382 · `LowerArm` 0,981×1,274×1,069 · `LowerLeg`
0,920×1,591×0,966 @ −2,590. Altura total 6,282; topo da cabeça +2,675; **sola
3,607 abaixo da HumanoidRootPart**.

**Assentamento (`WorldService.settleRigBodies`).** O R15 sai da criação com as
pernas recolhidas e só estende no primeiro passo de física: medindo a sola
antes disso, o boneco nasce **0,186 stud enterrado** (e o poste e a base do
dummy nascem soterrados junto). Em vez de fixar a constante — que muda no dia
em que o Roblox mexer nas proporções padrão — o mundo espera um Heartbeat,
mede o corpo montado e corrige o `C0` do weld uma vez. Verificado no Studio:
sola em 0,000 (instrutor) e 0,500 (dummy, topo do pad), erro final 0,0000, e
rodar de novo não move nada.

**Fallback.** Se `CreateHumanoidModelFromDescription` falhar, o `WorldService`
cai no corpo greybox de Parts anterior e emite `warn`. O mundo nunca nasce sem
NPC — o instrutor é quem entrega o objetivo 1.

**Regras travadas por teste** (`tests/run.luau`, sobre dado puro):

- os dois bots têm receita de rig, e nenhum estilhaço tem;
- toda peça pousa num nome de parte que existe no rig R15 (host com erro de
  digitação viraria roupa solta no chão);
- material dentro da lista liberada (nome inválido seria erro de runtime no
  boot do mundo), RGB em 0..255, tamanho em 0,05–8 studs, offset até 4 studs
  do host, `WedgePart` não aceita `Shape`;
- rosto só por textura **embutida do cliente** (`rbxasset://textures/face.png`)
  — asset de catálogo pode sumir por moderação e deixar o NPC sem cara;
- **nenhuma peça de cabelo/capuz tapa os olhos**: se a peça avança na frente do
  plano do rosto (z < −0,628), ela tem de ficar inteira acima da faixa dos
  olhos (y ≥ 0,31). É a regra que impede a franja de escorregar num ajuste
  fino e devolver o vulto encapuzado sem cara;
- **nada de caixa**: no máximo 25% das peças em `Block`, mínimo de 6
  elipsoides e 4 anéis por bot, e `bodyType ≥ 0,5` — as três condições que,
  juntas, impedem a volta do "muito quadrado".

Cada modelo usa uma raiz invisível ancorada e peças sem colisão ligadas por `Motor6D`. A altura da raiz é derivada da receita para manter os pés sobre o piso; cabeça e braços seguem o torso, evitando separação visual ao inclinar. A posição/olhar da raiz vêm do `SpatialService` no servidor e só são replicados quando posição ou direção mudam. O cliente altera apenas `Motor6D.Transform`; portanto a pose nunca muda alcance, alvo, dano ou posição válida.

> **Skins procedurais (13/08, `d0f6f8d`):** os modelos ganharam peças de
> identidade com joints próprios (não animados — o `ActorAnimator` ignora
> joints desconhecidos): Instrutor com `Hood`/`Collar`/`Belt` (faixa Neon),
> dummy com `Target` (disco Neon no peito), estilhaços com `Halo` (anel Neon
> que orbita junto do pivot), `ShardFront`/`ShardBack` e, no elite, coroa
> `Crown_1..3`. Continua tudo Part/Motor6D greybox até o Gate P1.

> **Skins dos atores do spawn (13/08, 16h, revista 17h):** ver bloco
> **Cabeças e skins** abaixo — a versão com FileMesh/decal não aparecia no Play.
>
> **Cabeças e skins (correção 13/08 17h):** o `SpecialMesh` `rbxassetid://1290273`
> não carregava no Play — a Part da cabeça existia, mas ficava invisível, e os
> humanoides estáticos nasciam olhando para −Z (costas para a praça). Agora a
> cabeça é uma esfera nativa (`Part.Shape = Ball`), o rosto é feito de peças
> (olhos/íris/boca, sem decal de asset) e os dois NPCs do spawn olham para a
> praça. Instrutor: capuz que emoldura o rosto, cabelo, ombreiras, casaco com
> caudas, emblema umbral no peito. Dummy: palha, olhos-botão, costuras, alvo
> de três anéis no peito e poste de madeira atrás. Joints novos continuam
> ignorados pelo `ActorAnimator`.

> **Skin do boneco de treino (13/08, 16h):** (ver bloco acima — skin do spawn).

> **Decoração do spawn (13/08):** `SpawnDecorations.luau` (shared, dados puros
> validados por teste) + `buildSpawnDecorations` no WorldService materializam
> a leitura do Bastião: pilares de canto/portões com cristais umbral no topo,
> arcos Neon dos portões (visual — a passagem continua livre), obelisco atrás
> do Marco de Retorno, lanternas ao longo do caminho norte e da praça, e anel
> Neon delimitando o TrainingPad. A muralha de perímetro continua a do
> `buildWalls` (GateBlock), agora com **Limestone** no corpo, **Sandstone**
> na tampa e **Basalt** na faixa — não é mais um Slate único. Bots carregam
> Billboard `Nv. N` a partir de `Npcs.displayLevel` (errante 8, elite 18).
> Regras travadas por teste: nada invade os volumes de transição, decoração
> solta fica dentro do volume do bastião e a muralha não engole âncoras
> críticas. Não vale um único material Slate em corpo+tampa+faixa.

Somente o root do dummy e dos inimigos vivos possui `CombatTarget`; âncoras de spawn não são alvos de câmera. Essa distinção faz magnetismo/lock-on acompanhar o ator móvel em vez do ponto onde ele nasceu.

## 5. Animação procedural

### 5.1 NPCs

`ActorAnimator` é uma camada greybox, não um controller de animação final. Ele recebe `EnemyEvent`, consulta a receita do ator e amostra poses locais em `PreSimulation`:

| Estado | Apresentação | Autoridade preservada |
|---|---|---|
| idle | bob pequeno e rotação lenta do núcleo | não altera AI |
| moving | balanço alternado / oscilação do Estilhaço | root continua vindo do servidor |
| telegraph | corpo recua, contorno branco e símbolo `!`/`!!` | não abre hitbox; duração/padrão são metadados visuais |
| attack | compromisso curto para a frente | dano só aparece após evento autoritativo |
| died | queda limitada a até 90° e ocultação posterior | morte já foi decidida no servidor |
| spawn/respawn | elevação e assentamento de 600 ms, inclusive para late join | respawn/cooldown continuam no domínio |

Os eventos transitórios carregam `durationSeconds` e `visualPattern`, expiram e voltam a idle para não congelar a locomoção. `PoseSerial`, início e duração replicados permitem que um cliente tardio apresente o estado sem transformar timestamp em autoridade. Joints são cacheados por modelo; não há busca recursiva a cada frame depois da primeira amostra.

> **Junta não é sinônimo de `Motor6D` (14/08).** O rig R15 usa
> `AnimationConstraint`, que expõe o mesmo `Transform`. O `ActorAnimator`
> aceita as duas classes e escreve os dois conjuntos de nomes: `Joint_*` para
> o ator greybox em Parts e `Root`/`Waist`/`Neck`/`LeftShoulder`/`LeftHip`/… para
> o corpo de rig. Nome ausente é ignorado, então o mesmo caminho serve aos dois
> sem ramo por tipo de corpo. No R15 a respiração vai no `Root` (o quadril sobe
> e desce) e a inclinação na `Waist`: girar o `Root` inteiro faria o boneco
> pivotar sobre os pés. Detalhe completo e a razão da correção em
> `docs/14-ANIMATION-PLAN.md` §4.5.

### 5.2 Jogador local

`PlayerCombatAnimator` compõe um overlay procedural sobre a animação-base do personagem local:

| Intenção | Duração procedural | Limite |
|---|---:|---|
| ataque leve | 280 ms | resposta visual; não confirma hit |
| ataque pesado | 520 ms | windup/compromisso visual; não autoriza janela |
| guarda down/up | 160/180 ms | pose acompanha a intenção; guarda efetiva continua server-side |
| dash | 320 ms | inclinação visual; não move root nem concede i-frame |

O overlay é reaplicado em `PreSimulation`, acompanha respawn e restaura joints ao parar. Ele **não é clip final** — mas desde 14/08 (tarde) ele é a **única** camada de animação do combate: o catálogo de clipes está vazio de propósito (`docs/14` §4.6).

Cada degrau da cadeia leve é uma trilha de quatro quadros (neutro → recolhe → **dirige** → impacto), não mais um par recolhe/bate. O quadro "dirige" é onde o quadril já virou e a extremidade ainda está a caminho; sem ele o rig cobre o arco inteiro num segmento só e o olho só registra a extremidade. A pose ganhou ainda **passo à frente** (`rootForwardStuds`, medido movendo o corpo inteiro: 0,220 pedido → 0,220 em todas as partes, e visual — a `HumanoidRootPart` física não sai do lugar) e **tornozelos**. Percurso do corpo no jab: de 1,30 para 4,36 studs.

> **Correção de 14/08 — o overlay não estava aplicando nada.** O animador
> procurava só `Motor6D`; o avatar R15 atual monta o rig com
> `AnimationConstraint` e **zero** `Motor6D`. `animator.joints` ficava vazio e
> a pose inteira (cadeia, técnicas, hit-stop, follow-through) não chegava ao
> personagem — só o clipe de espada acelerado chegava. Medição, correção e
> testes de regressão em `docs/14-ANIMATION-PLAN.md` §4.5.

## 6. Interação contextual

`InteractionController` cria `ProximityPrompt` local nos atributos publicados pelo mundo. Todo texto vem de `Locale`; teclado, touch e gamepad usam o prompt nativo.

| Alvo | Prompt | Distância | Hold |
|---|---|---:|---:|
| Instrutor do Limiar | conversar/aceitar objetivo | 10 studs | imediato |
| Marco de Retorno | consolidar XP | 10 studs | 1,5 s |

O cliente envia somente alvo e fase semântica. `InteractionService` resolve catálogo fechado, rejeita alvo ambíguo/desconhecido, mede novamente a distância autoritativa, exige begin/complete no hold e limpa estado no leave. O prompt existir não garante o efeito.

## 7. Gate de playtest no Studio

A §18 da spec previa um unlock de teste exclusivamente server-side. Ele agora existe com três travas:

1. `RunService:IsStudio()` precisa ser verdadeiro;
2. o atributo do `DataModel` precisa ser exatamente `F0Debug = true`;
3. as flags entram em `sessionFlags`, aparecem no snapshot/HUD e **não** entram no ProfileRoot.

Não existe remote de cheat e a ultimate continua desabilitada. Para habilitar no Command Bar do Studio:

```lua
game:SetAttribute("F0Debug", true)
```

Para remover:

```lua
game:SetAttribute("F0Debug", nil)
```

O atributo não libera nada fora do Studio. Mesmo assim, a versão usada para evidência deve registrar se o gate estava ligado.

## 8. Evidência atual

Comprovado automaticamente:

- quatro receitas, paletas e limites de pose passam no validador;
- antecipação recua, ataque compromete e morte respeita o ângulo da receita;
- os volumes geram pisos estruturais para Bastião, planície, transições e braço oeste;
- telegraph declara duração/padrão visual, usa contorno/símbolo e recupera estado em late join;
- NPC e jogador compõem transforms em `PreSimulation`;
- as amostras puras de leve, pesado, guarda e dash respeitam suas fases e retornam ao neutro;
- interação valida catálogo, alvo único, alcance, hold, abandono e limpeza de sessão;
- o gate exige Studio + atributo e libera somente três técnicas;
- unlock de sessão aparece para habilidade/HUD e fica fora do snapshot durável;
- a planície, as duas rotas e a borda da cratera têm decoração dirigida por dados que não colide, não entra no ringue do elite e não encosta nas âncoras de spawn;
- os cinco sinais da fronteira têm apresentação local, e travessia recusada não acende nada;
- 241 testes de domínio, 73 de animação/apresentação, 67 de fuzz e 19 de combate ponta a ponta passam; Selene e StyLua passaram nesta rodada;
- o Gate W1 tem roteiro executável: `docs/32-STUDIO-PLAYTEST-RUNBOOK.md` e `lune run scripts/avb-debug.luau runbook`;
- o build Rojo atual foi concluído com 318.988 bytes no check reproduzido desta rodada.

O último item é evidência de **build reproduzido**. Não demonstra que o arquivo abriu, iniciou servidor/cliente, renderizou Parts ou respondeu a input.

Ainda não comprovado:

> **Atualização 17/08 — sessão de Play executada (W1/A1/W2/R1).** Os itens
> abaixo passaram a ser **comprovados em runtime** na sessão do dia: Parts,
> joints, materiais e iluminação em Play; pisos sem queda/degrau/snag nas duas
> rotas; sem clipping grave no rig/física real; sincronismo de telegraph/ataque
> sob latência simulada (R1); prompts, hold e interação no Studio; leve,
> pesado, guarda e dash no R15 real e após morte/respawn; legibilidade do
> Portão Oeste e da cratera; frame time medido no MicroProfiler (W2). Restam
> fora de evidência: frame time com oito jogadores, DataStore real em place
> publicado e telemetria operacional.
- mobile e gamepad em dispositivo real;
- qualquer conclusão sobre beleza ou qualidade final;
- clipes dedicados e revisão visual das três técnicas.

## 9. Próximos gates escolhidos

### W1 — leitura do greybox

**Entrada:** commit `d7c44e8`; conferir antes do teste o artefato Rojo correspondente ao snapshot atual. A conferência identifica o artefato, mas não aprova o gate.

**Execução obrigatória:**

1. Play Solo por 20 minutos com `F0Debug` desligado; repetir o smoke das três técnicas com o atributo ligado e registrar a configuração;
2. guardar Output completo do boot ao Stop e captura 720p de spawn, Instrutor, dummy, Portão Norte, Portão Oeste, planície, cratera e Marco de Retorno;
3. percorrer ida e volta três vezes por cada portão, incluindo a faixa de transição e o braço oeste;
4. executar leve, pesado, guarda down/up e dash, depois repetir após morte/respawn;
5. usar o prompt imediato do Instrutor e o hold de 1,5 s do Marco; tentar também fora de 10 studs;
6. observar spawn, telegraph, ataque, morte e respawn de Errante/Ancorado com a imagem em escala de cinza;
7. iniciar servidor local com dois clientes; o segundo entra depois dos inimigos e deve recuperar os atores sem estado preso.

**Aceite (`PASS` somente se todos forem comprovados):**

- zero erro vermelho atribuível ao projeto e bootstrap chega a “servidor pronto”;
- nenhuma queda por vão, colisão invisível ou snag nos seis percursos de portão;
- pés/root não apresentam afundamento ou flutuação evidente acima de 0,15 stud nas capturas;
- cada intenção do jogador inicia uma pose, retorna ao baseline e não deixa joint preso após respawn;
- contorno branco e símbolo identificam telegraph sem cor durante a duração declarada;
- cliente tardio vê os cinco inimigos existentes, apresenta spawn uma vez e converge para idle/movimento;
- prompts aparecem somente no alcance esperado; servidor recusa tentativa distante/hold incompleto e aceita a válida;
- retorno após morte, HUD de zona e objetivo permanecem coerentes.

**Evidência mínima:** vídeo/captura dos passos, Output salvo, versão do Studio, modo de teste, resolução/FPS e checklist `PASS`/`FAIL` por critério. Sem esses artefatos, W1 continua pendente.

### A1 — golpe-modelo real

W1, P1, propriedade da conta/grupo e rig R15 congelado são pré-requisitos. Produzir somente o blocking original do Ombro Cometa, integrar markers exclusivamente de apresentação e aplicar os critérios mensuráveis de `14-ANIMATION-PLAN.md` §7. Até capturas, métricas, dispositivo real e decisão `PASS`/`REWORK`/`CUT` existirem, as três técnicas permanecem sem animação dedicada e os outros 44 clipes não começam.

### W2 — performance e dispositivos

- oito jogadores, quatro Errantes e um Ancorado;
- MicroProfiler com script, física, render e `stepAnimation` separados;
- PC integrado e Android por 15 minutos;
- touch e gamepad reais, com efeitos reduzidos;
- registrar p50/p95, memória, resolução e preset; sem estimar números não medidos.

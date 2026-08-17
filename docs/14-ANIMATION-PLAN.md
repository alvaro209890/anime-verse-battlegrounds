# 14 — Plano de animação e apresentação de combate

> **Status canônico em 2026-08-15 (`86228ee`):** existe uma fundação procedural para NPCs e para o personagem local em ataque leve, ataque pesado, guarda e dash. O ataque leve virou uma **cadeia de quatro golpes de silhueta distinta** (§4.3), com cotovelo e joelho articulados. Validação apenas por análise estática, build e testes headless. **Nenhum dos 45 clipes finais foi criado ou validado, nenhuma das três técnicas possui animação dedicada e não houve Play atual no Studio.** A F0 continua usando apresentação genérica até os gates W1, P1 e A1.
>
> **Antes de investigar qualquer "não anima", leia §4.7.** A série de correções de 14/08 terminou num defeito que nenhum teste headless pega: o rig R15 não existe no instante do `CharacterAdded`, o anexo capturava zero junta e nunca mais procurava. A receita de diagnóstico em seis passos está no fim daquela seção; a rotação do corpo no golpe está em §4.9.
>
> Áudio de combate tem documento próprio: `16-COMBAT-AUDIO.md`. Polimento procedural de game-feel (easing, follow-through, idle, wrist snap, hit-stop e câmera de impacto) está em `17-COMBAT-FEEL.md`.

## 1. Objetivo

A animação deve fazer o combate parecer rápido, pesado e preciso sem esconder a regra. O jogador precisa reconhecer antecipação, compromisso, impacto e recuperação mesmo com partículas reduzidas, tela pequena ou cor removida.

Ordem de prioridade:

1. resposta ao input e leitura do contra-jogo;
2. pose e silhueta próprias;
3. sensação de peso e continuidade;
4. acabamento de câmera, VFX e áudio;
5. quantidade de variações.

Qualidade vem de poucos movimentos muito bem resolvidos antes de ampliar o catálogo. O primeiro alvo de produção é um **golpe-modelo** do Ombro Cometa; as outras técnicas só avançam após esse pipeline ser medido.

### 1.1 Fundação implementada — não confundir com asset final

`WorldPresentation.luau` e `ActorAnimator.luau` fornecem receitas e poses procedurais para dummy, instrutor e dois Estilhaços. `PlayerCombatAnimator.luau` acrescenta um overlay local para a cadeia leve de quatro golpes, pesado, entrada/saída de guarda e dash. As duas camadas compõem `Motor6D.Transform` em `PreSimulation`; eventos de inimigo carregam apenas duração e padrão visual, e o late join recupera a apresentação pelos atributos replicados.

Essa fundação serve para verificar estados, silhueta básica, telegraph e custo antes da produção R15. Ela não usa timeline, keyframe, marker ou asset publicado e **não conta como nenhum dos 45 clipes planejados**. Ombro Cometa, Cadência Quebrada e Retorno de Pulso ainda não possuem animação dedicada. A árvore, o contrato de autoridade e o roteiro de evidência ficam em `15-WORLD-PRESENTATION.md`.

## 2. Invariantes técnicos e jurídicos

- R15 é o rig-base da primeira produção.
- O servidor continua decidindo hitbox, alvo, dano, custo, cooldown, deslocamento válido, i-frame e janelas. Animação e markers são apresentação; nunca autorização.
- Root motion visual não substitui o `SpatialService`. Toda divergência relevante é reconciliada com o resultado do servidor.
- Markers podem disparar som, câmera e VFX locais. O acerto exibido espera `CombatEvent` ou resultado autoritativo.
- Nenhum asset final começa antes de P1 aprovar linguagem visual e checklist de originalidade.
- Não reproduzir pose-assinatura, sequência, silhueta, timing, câmera, cor, símbolo ou áudio reconhecível de referência. Um nome novo não torna uma animação derivativa segura.
- Assets pertencem à conta/grupo correto, com fonte editável preservada, autoria e licença registradas.
- **Exceção declarada (13/08, §4.4):** clipes e sons do **criador Roblox (userId 1)** podem ser usados como andaime tocável enquanto o kit próprio não existe. Eles não contam como clipe planejado, não passam pelo Gate A1 e não entram em nenhuma decisão de jogo. Todo asset **final** continua sob a regra de propriedade acima. A direção do projeto segue procedural-primeiro: o overlay em Motor6D é a fundação e o fallback quando o asset livre não carrega.

## 3. Linguagem de movimento

O Punho do Eclipse usa três ideias próprias:

- **Órbita curta:** braços e tronco desenham arcos compactos, sem gestos grandiosos antes do impacto.
- **Peso atrasado:** quadril inicia, tórax acompanha e a extremidade fecha o golpe; o contato tem uma pausa visual curta sem congelar a simulação.
- **Retorno elástico:** toda pose forte tem saída clara para guarda, corrida ou recuperação; nada termina “morto” no espaço.

Regras de pose:

- linha de ação legível em frente, perfil e três quartos;
- mãos e pés não atravessam tronco/solo no rig padrão;
- base de apoio permanece crível; pé plantado não desliza durante carga;
- antecipação não pode parecer outro golpe;
- ataques leves compartilham gramática, mas não a mesma silhueta;
- defesa reduz volume e protege o centro; contra-ataque abre a pose apenas depois da confirmação.

## 4. Escopo de clipes da primeira onda

Os movimentos procedurais atuais são scaffolding descartável e não reduzem as contagens abaixo. Um ataque básico responder visualmente ao input em código não equivale a um clip aprovado.

### 4.1 Jogador — prioridade A

| Grupo | Clipes | Observação |
|---|---:|---|
| Locomoção | 6 | idle de combate, corrida, salto, queda, aterrissagem, dash |
| Ataque universal | 6 | cadeia leve 1–4, pesado, erro do pesado |
| Guarda | 5 | entrada, loop, saída, impacto bloqueado, quebra |
| Ombro Cometa | 3 | startup/avanço, impacto/guarda, recuperação |
| Cadência Quebrada | 4 | golpe 1, golpe 2, reentrada, eco visual |
| Retorno de Pulso | 4 | postura, contra confirmado, whiff/recovery, quebra por costas/slam |
| Reações | 4 | hit leve, hit pesado, morte, respawn |

Total de planejamento: **32 clipes de jogador**, contando variantes funcionais e não microvariações cosméticas.

### 4.2 Inimigos — prioridade B

| Grupo | Clipes | Observação |
|---|---:|---|
| Estilhaço Errante | 5 | idle, locomoção, telegraph, ataque, morte |
| Estilhaço Ancorado | 6 | idle, locomoção, combo, slam, recovery, morte |
| NPC/dummy | 2 | idle e reação funcional |

Total de planejamento: **13 clipes de NPC**. Variações de idle, finais cosméticos e ultimate ficam depois do gate do golpe-modelo.

### 4.3 Cadeia leve procedural — implementada

Substitui a pose única de ataque leve por quatro golpes encadeáveis. Continua procedural: nenhum keyframe, timeline ou asset, e **não conta como clipe planejado**. Serve para medir leitura, ritmo e contra-jogo antes de encomendar arte.

| Degrau | Golpe | Duração | Antecipação | O que muda na silhueta |
|---:|---|---:|---:|---|
| 1 | jab (mão da frente) | 0,240 s | 0,065 s | compacto, guarda intacta |
| 2 | direto (mão de trás) | 0,300 s | 0,070 s | quadril entrega o golpe, tronco gira 34° |
| 3 | chute circular | 0,380 s | 0,110 s | perna sobe, tronco contrabalança ao lado oposto |
| 4 | finalizador giratório | 0,480 s | 0,135 s | giro de 74°, chute com a outra perna |

Encadeia dentro de **1,00 s**, espelhando `LIGHT_WINDOW` do `CombatService`. A cadeia leve dura 0,495 / 0,600 / 0,750 / 0,930 s (cerca de 1,5× a trilha anterior) para o soco ler carga. Dash, guarda e técnicas quebram a cadeia, como no servidor. O degrau é decisão de apresentação: quem resolve o `lightStep` autoritativo continua sendo o servidor.

Três mecanismos sustentam a sensação de peso, todos em número:

- **Cotovelo e joelho articulados.** O rig só compunha ombro e quadril, então nenhum soco estendia e chute era impossível. O cotovelo sai de −92° e estala perto de reto no impacto; o joelho encaixa a perna dobrada e estende no chute.
- **Peso atrasado.** Quadril e tronco são amostrados 25% à frente da extremidade. Sem esse deslocamento de fase o corpo inteiro chega junto e o rig parece girar de uma peça só.
- **Pausa de impacto e retorno elástico.** A pose do golpe segura alguns quadros e a volta usa `easeOutBack`, que ultrapassa levemente o neutro antes de assentar. `easeOutBack(1)` é exatamente 1, então toda ação termina em neutro cravado, sem resíduo entre golpes.

Ataque pesado e Ombro Cometa herdaram pausa, elástico e cotovelo.

**Limite conhecido — CORRIGIDO em 13/08:** o cliente avançava o degrau a cada
clique, mas o servidor zerava `lightStep` quando o golpe errava — numa
sequência de erros a pose podia exibir o chute enquanto o servidor estava no
jab. Agora o `CombatEvent` do ataque básico carrega `step` (degrau autoritativo)
e, no whiff, o servidor zera a cadeia e notifica `outcome="miss"` — o cliente
sincroniza a pose via `PlayerCombatAnimator.syncStep`. A divergência era
puramente cosmética e segue sem nenhuma decisão de acerto dependendo dela.

Cobertura: `tests/animation.luau` (silhuetas distintas, extensão de cotovelo, chute como perna, amplitude crescente, retorno exato ao neutro, overshoot, liderança do núcleo, janela de encadeamento).

### 4.4 Clipes livres do Roblox — placeholder tocável (13/08, 15h)

O playtest das 14:26 (`docs/18` §7) mostrou por que o procedural sozinho não
resolve: o overlay compõe alguns graus por junta **em cima** da animação que o
Roblox já toca no avatar. No boneco real, de terceira pessoa e com roupa larga,
isso lê como "não aconteceu nada". A resposta foi somar um clipe de corpo
inteiro por ação, com a decisão em dados puros e testados.

- Catálogo: `src/shared/Data/CombatAnimations.luau` (puro, testável em Lune).
- Materialização: `src/client/Presentation/CharacterAnimationPlayer.luau`
  (camada de Instances, não coberta por teste — como o `WorldService`).
- Assets: **só do criador Roblox (userId 1)**, que qualquer experiência toca
  sem upload nem compra. Verificados em 2026-08-13 em
  `economy.roblox.com/v2/assets/<id>/details`:
  `522635514` "R15 Sword Slash" e `522638767` "R15 Sword Lunge" (AssetTypeId 24).

### 4.5 Correção de 14/08 — a causa real de "as animações estão péssimas"

Duas coisas foram medidas no Studio (via MCP) em **2026-08-14** e derrubaram a
premissa da seção anterior.

**(1) O overlay procedural não estava sendo aplicado. Nunca.**

O avatar R15 atual do Roblox monta o rig com `AnimationConstraint`
(Attachment→Attachment) e **zero `Motor6D`**. Medição no personagem do jogador
em sessão de Play: 15 `AnimationConstraint` (`Root`, `Waist`, `Neck`,
`LeftShoulder`, …), 14 `BallSocketConstraint`, **nenhum `Motor6D`**.

O `PlayerCombatAnimator` procurava exclusivamente `Motor6D`. Resultado:
`animator.joints` ficava vazio e as ~1400 linhas de pose — as quatro silhuetas
da cadeia, os quadros das três técnicas, o hit-stop, o follow-through — não
saíam do papel. **O que o jogador via era só o clipe de espada acelerado.**

`AnimationConstraint` expõe `Transform: CFrame` com a mesma semântica do
`Motor6D`, então a correção foi aceitar as duas classes na busca. Vale para o
`ActorAnimator` também (que agora posa os bots do spawn, de rig R15).

**(2) O "R15 Sword Lunge" não é uma animação.**

`KeyframeSequenceProvider:GetKeyframeSequenceAsync` mostrou:

| Asset | Nome | Criador | Prioridade | Keyframes |
|---|---|---|---|---|
| `522635514` | R15 Corte de Espada | Roblox (1) | Action | **0 · 0,20 · 0,30 · 0,50 s** |
| `522638767` | R15 Lunge de Espada | Roblox (1) | Idle | **0 · 1,5 s** — só dois |

O lunge tem dois quadros: é uma interpolação linear entre duas poses, sem
conteúdo no meio. Acelerado 2,7×–2,9× para caber numa janela de meio segundo,
virava espasmo — e era ele que estava no finalizador, no pesado e no Ombro
Cometa. **Saiu do catálogo**, e um teste impede que volte.

O corte, por outro lado, tem estrutura legível: antecipação até 0,20, **golpe
de 0,20 a 0,30**, recuperação até 0,50.

**Janelamento em vez de aceleração.** Em vez de espremer o clipe inteiro na
janela da ação, `startTimeSeconds` entra no instante do golpe e toca só o
trecho que interessa, em velocidade legível:

| Ação | Clipe | Início | Velocidade | Trecho visto | Orçamento |
|---|---|---:|---:|---|---:|
| Leve 1 (jab) | Corte | 0,20 s | 1,25× | golpe + recuperação | 0,240 s |
| Leve 2 (direto) | Corte | 0,20 s | 1,00× | golpe + recuperação | 0,300 s |
| Leve 3 (chute) | — | — | — | **procedural puro** | 0,380 s |
| Leve 4 (finalizador) | Corte | 0 | 1,04× | clipe inteiro | 0,480 s |
| Pesado | Corte | 0 | 0,96× | clipe inteiro | 0,520 s |
| Ombro Cometa | — | — | — | **procedural puro** | 0,750 s |
| Cadência Quebrada | Corte | 0 | 0,74× | clipe inteiro | 0,680 s |
| Retorno de Pulso | — | — | — | **procedural puro** | 0,730 s |
| Eco da Cadência | Corte | 0,20 s | 0,58× | golpe + recuperação | 0,520 s |
| Contra do Pulso | Corte | 0,20 s | 0,68× | golpe + recuperação | 0,440 s |

Nenhuma velocidade sai de **0,5×–1,5×** (o teto era 3×). Fora dessa faixa ou é
câmera lenta ou é borrão.

**Onde não há clipe, é decisão, não falta.** Chute, Ombro Cometa e Retorno de
Pulso ficaram sem clipe pelo mesmo motivo que guarda e dash já estavam:
o único clipe livre disponível é um **corte de espada**, e um braço de espada
num chute, numa ombrada ou numa postura defensiva informa errado. Com o
overlay procedural finalmente funcionando, essas três têm leitura própria.

Regras que os testes travam (`tests/animation.luau`):

- a janela pedida **existe dentro do clipe** (`início + orçamento × velocidade
  ≤ duração`): pedir além do fim congela o último quadro, que é exatamente a
  pose estática que o janelamento veio eliminar;
- velocidade dentro de 0,5×–1,5×;
- o lunge de dois quadros não volta ao catálogo;
- `Ability1` e `Ability3` continuam sem clipe;
- todo `assetId` casa `rbxassetid://%d+` e sai da lista declarada;
- a duração declarada aqui bate com `PlayerCombatAnimator.Durations`;
- `isPoseJointClass` aceita `Motor6D` **e** `AnimationConstraint`, nos dois
  animadores — é este teste que impede o combate de voltar a ficar sem pose.

**Isto não fecha o Gate A1.** O corte continua sendo placeholder honesto: lê
como golpe de braço, não é o kit final do Punho do Eclipse.

Fallback: se o asset não carregar (moderação, offline), o clipe é ignorado com
um aviso único e o overlay procedural segue sozinho. O combate nunca fica sem
nenhuma leitura.

Rastro de golpe: um `Trail` sem textura (recurso do próprio engine, nada para
subir) na mão direita acende durante a ação e apaga sozinho no fim dela.

### 4.6 Correção de 14/08 (tarde) — "o personagem só levanta o braço"

Terceira rodada. O overlay já chegava à tela (§4.5), mas o golpe continuava
ilegível. Duas medições no Studio explicaram por quê, e as duas foram cegas
para quem só lia o código.

**(1) As duas camadas discordavam sobre qual braço ataca.**

O clipe `522635514` ("Corte de Espada") balança o braço **DIREITO**. O jab
procedural — degrau 1 — soca com o **ESQUERDO**:

| Camada | Braço que age no degrau 1 |
|---|---|
| Clipe de espada (prioridade Action) | direito |
| `JAB_STRIKE` procedural | esquerdo (`leftShoulderPitch = −92`) |

E **todo ataque solto é o degrau 1** — só encadeando é que se chega ao 2, 3, 4.
Ou seja: o golpe que o jogador mais vê era exatamente aquele em que as camadas
brigavam, e o clipe, sendo animação autoral em prioridade Action, ganhava a
tela. O que sobrava para o olho era um braço subindo.

Quando as duas concordavam (pesado, ambas no direito), o problema virava o
oposto: os ângulos **somavam** e hiperestendiam o ombro.

**Decisão: a apresentação de combate é 100% procedural.** O catálogo de clipes
está vazio, e isso é decisão, não pendência — o kit do jogo é punho e chute
(Punho do Eclipse) e o único clipe livre disponível é de espada. `Combat-
Animations` continua existindo como a costura do Gate A1: declarar um clipe lá
volta a ligar a camada. O rastro do golpe (`Trail`) foi movido para fora do
caminho do clipe, senão sumiria junto.

**(2) A pose tinha dois quadros, e o corpo chegava inteiro de uma vez.**

Cada degrau era `recolhe → bate`. Com um único quadro forte, o rig cobre todo
o arco num segmento só e o que o olho registra é a extremidade. Agora cada
degrau é uma trilha de quatro quadros, no mesmo motor das técnicas
(`techniquePose`):

| Quadro | Papel | Instante |
|---|---|---|
| neutro | de onde sai | 0 |
| **recolhe** | peso vai para trás, extremidade carrega | fim da antecipação |
| **dirige** | o quadril já virou, a extremidade ainda está a caminho | 60% do caminho até o impacto |
| **impacto** | silhueta do golpe | instante autoritativo |
| (sustenta) | pausa de impacto, depois recuperação elástica | fim da pausa |

Duas coisas novas entraram na pose para o corpo aparecer:

- **`rootForwardStuds`** — o passo. Entrar no golpe em vez de girar no lugar.
  Medido no Studio: 0,220 pedido → **0,220 em todas as partes do corpo**, então
  o deslocamento move o personagem inteiro. É **visual**: a
  `HumanoidRootPart` física não sai do lugar, então alcance, hitbox e posição
  autoritativa não mudam. No impacto vale de 0,26 (chute) a 0,48 stud (pesado),
  e é **negativo** na antecipação — o peso recua antes de ir.
- **tornozelos** (`leftAnklePitchDegrees` / `rightAnklePitchDegrees`) — sem
  eles o pé de trás fica colado enquanto o quadril gira, e o golpe lê como
  braço mexendo em cima de um boneco parado.

**Resultado medido no personagem real do Studio.** Percurso do corpo (soma do
deslocamento de tronco, cabeça, quadril, pernas e pés entre os quadros do
golpe), jab antigo × jab novo:

| | Quadros | Percurso do corpo |
|---|---:|---:|
| Antes (2 quadros, sem passo, com clipe) | 2 | 1,30 studs |
| Depois (4 quadros, passo, tornozelos) | 4 | **4,36 studs** |

**+235%.**

Regras travadas por teste (`tests/animation.luau`):

- todo degrau gira o quadril ≥ 18° e o tronco ≥ 20° **no impacto** — inclusive
  o jab, que é o mais visto;
- todo degrau baixa o centro de massa, mexe os dois joelhos e ao menos um
  tornozelo;
- todo degrau entra no golpe (`rootForwardStuds ≥ 0,2`) e **recua o peso** na
  antecipação (negativo);
- o quadro do meio é distinto do impacto (senão a trilha voltou a ter dois);
- nenhuma ação de combate tem clipe declarado, e o construtor de clipe continua
  válido para o Gate A1.

> O helper de teste `strikeOf` passou a amostrar o **instante de impacto**
> publicado por `lightChainImpact`. Antes usava `duração × 0,45`, que com
> quatro quadros cai em cima do "dirige" nos degraus 3 e 4 — mediria o quadro
> errado e deixaria a regressão passar.

### 4.7 Correção de 14/08 (noite) — o overlay nascia morto

Tudo de §4.5 e §4.6 estava certo no código e **nada disso aparecia no jogo**.
Com o place correto aberto e o `sync` acusando 56/56 arquivos batendo, o
jogador atacava e o corpo não se mexia.

O que a medição no personagem real mostrou, atacando de verdade (cliques
sintéticos, 421 quadros, 4 ataques confirmados no servidor):

| Medida | Valor |
|---|---|
| Maiores ângulos de junta | todos de perna — a caminhada do Animate padrão |
| `Root.Transform.Z` (o passo à frente) | **0,0000 em todos os quadros** |
| Quadros com o rastro do golpe ligado | **0** |
| Ombro no impacto | abaixo de 8°, onde a pose pede 92° |

A pose nunca chegava na junta. A causa é uma corrida no anexo, medida
direto no `CharacterAdded`:

| No instante em que o personagem chega | 0,5 s depois |
|---|---|
| 0 `AnimationConstraint` | 15 |
| 0 `Motor6D` | 0 |
| sem `RightHand` | com `RightHand` |

**O rig R15 não existe quando o personagem existe.** `attachCharacter` varria
os descendentes exatamente nesse instante, capturava zero junta, e — como o
anexo sai cedo quando o personagem é o mesmo — nunca mais procurava. O overlay
inteiro ficava morto pelo resto da sessão.

Isso reescreve o diagnóstico das rodadas anteriores: o "só levantava o braço"
de §4.6 era o clipe de espada sozinho na tela, porque o procedural **nunca**
tinha entrado. Tirar o clipe (decisão correta por outro motivo) removeu a única
camada que ainda animava, e o sintoma virou "ataque sem animação nenhuma".

Três lugares tinham o mesmo padrão de anexo-uma-vez-só:

| Arquivo | Sintoma | Conserto |
|---|---|---|
| `PlayerCombatAnimator` | pose nunca aplicada | adota junta que chega depois, via `DescendantAdded` |
| `CharacterAnimationPlayer` | rastro do golpe nunca acende (`buildTrail` sem `RightHand` devolve nil e o nil ficava permanente) | tenta montar o rastro de novo no golpe |
| `ActorAnimator` | cache de juntas do bot congelado vazio | não guarda cache vazio; a próxima chamada procura de novo |

A regra de adoção virou `PlayerCombatAnimator.jointSlotFor(joints, className,
jointName)`, pura e testada: classe válida, nome com papel, papel ainda livre
(primeira vista vence). O teste começa com `joints` **vazio de propósito** —
como no anexo que chegou cedo — e oferece as 15 juntas depois, travando
justamente o caso que quebrou.

> Lição de método, terceira desta série: medir a função pura não é medir o
> jogo. `sample()` devolvia a pose certa em todas as rodadas — o que faltava
> era alguém aplicá-la. Verificação de apresentação tem que sair da parte
> materializada (posição de parte, `Transform` de junta, `Trail.Enabled`)
> durante uma ação de verdade, nunca do dado que alimenta a pose.

#### Onde o conserto vive no código

Quem for mexer nessas camadas precisa saber o que **não** pode voltar a ser
uma varredura única. Os três pontos, com âncora:

| Âncora | Regra que não pode regredir |
|---|---|
| `PlayerCombatAnimator.jointSlotFor(joints, className, jointName)` | Pura: devolve o papel da junta só se a classe for de pose (`Motor6D`/`AnimationConstraint`), o nome tiver papel conhecido e o papel ainda estiver livre. Primeira vista vence — senão um acessório com nome de junta trocaria o rig no meio do jogo. |
| `PlayerCombatAnimator.attachCharacter` → `character.DescendantAdded:Connect` | O anexo **continua escutando** depois da varredura inicial e adota junta que chega atrasada. A conexão é guardada em `animator.descendantConnection` e desligada ao desanexar. |
| `CharacterAnimationPlayer.flashTrail` | Se `player.trail` é nil e o personagem existe, tenta `buildTrail` **de novo, a cada golpe**. Só roda em golpe, então é barato, e nessa altura a `RightHand` já existe. |
| `ActorAnimator.setTransform` | Só grava `jointCache[model]` quando achou **pelo menos uma** junta. Guardar a lista vazia de um rig em montagem congelaria o bot sem pose para sempre. |

#### Receita para o próximo "não anima"

Esta classe de defeito não aparece em teste headless nenhum: a função pura
devolve a pose certa e o teste passa. A ordem abaixo é a que separou as quatro
hipóteses em 14/08 e vale para qualquer camada de apresentação:

1. **O código no Studio é este?** `lune run scripts/avb-debug.luau sync`
   (exit 2 = fora de sync). Duas janelas do Studio abertas medem places
   diferentes — ver `docs/19` §5.
2. **A intenção chega ao servidor?** Uma linha por golpe no Output com
   `F0Debug` (`[Combat] light errou` já é chegada).
3. **O mecanismo funciona?** Escrever `Transform` numa junta à mão e ver a mão
   se mover prova que a junta responde.
4. **O animador roda?** O idle mexe Root/Waist/Ombro sem input nenhum.
5. **A pose chega na junta?** Ler `Root.Transform.Z` durante o golpe. Zero em
   todos os quadros = o anexo não pegou as juntas, que é o defeito desta seção.
6. Só depois disso vale suspeitar da pose em si.

> `require` de um módulo via MCP devolve uma **cópia separada** — o estado vive
> na closure original. Instrumentação que dá zero por esse caminho não prova
> "não roda"; provar por efeito observável.

#### 4.7.1 Rede de segurança de 17/08 — revarredura quando `joints` está vazio

A adoção tardia de §4.7 cobre a corrida do `CharacterAdded`, mas não cobre um
caso: `attachCharacter` **sai cedo quando o personagem é o mesmo objeto**
(`animator.character == character`). Se a varredura inicial pegou zero junta e o
`DescendantAdded` já passou, a tabela fica vazia para sempre e o overlay inteiro
morre — guarda, cadeia leve e as três técnicas, todas ao mesmo tempo, sem erro
no Output.

`step()` agora revarre quando `next(animator.joints) == nil` com personagem
vivo. Custa uma iteração só no estado quebrado e devolve a animação sozinho.
Travado por teste (`juntas: tabela vazia é revarrida`).

**Sintoma que leva direto aqui:** o input chega (`processed=false` no
`InputBegan`, e o servidor responde ao golpe) mas nenhuma junta se move. Foi o
que se mediu em 17/08 com a guarda: `F` recebido, cotovelo parado em 4-8° onde a
pose pede 75°, enquanto um animator instanciado à mão no mesmo personagem
adotava as 15 juntas e posava na hora.

### 4.8 Correção de 14/08 (noite) — impacto sem luz, sem tremida e sem acerto

Reclamação: "não está tendo luzes, efeitos, tremidas". Três causas distintas,
duas delas no código e uma que não era código nenhum.

**(1) O jogador nunca tinha acertado nada.** Medido na sessão: o personagem
estava a **41,2 studs** do único alvo vivo do mundo, e o alcance do golpe leve é
**9**. Toda a camada de impacto — tremida de câmera, hit-stop, som de acerto e
número de dano — só dispara em desfecho confirmado pelo servidor
(`CombatEvent`, ver §5 e a tabela de `PresentationImpact`). Ela é correta e
nunca tinha rodado uma única vez. O console dizia isso o tempo todo, uma linha
por golpe: `[Combat] light errou`.

Isso não é defeito de apresentação, é o mundo F0 ter um alvo só e ele estar
longe. Fica registrado porque explica metade da reclamação e porque a próxima
pessoa que for investigar "o impacto não aparece" precisa checar **primeiro** se
houve impacto.

**(2) A tremida estava calibrada para ser invisível.** Ver §6: o problema não
era o teto, era a curva quadrática engolir o acerto comum. Recalibrado lá.

**(3) Luz não existia.** Ver §6: `PointLight` nenhum no kit inteiro, e partícula
com `LightEmission` brilha sem iluminar.

> Lição de método, quarta desta série: antes de mexer na apresentação de um
> evento, confirme que o evento **acontece**. Duas das três reclamações eram
> código; a terceira era o jogador nunca ter chegado perto o bastante para o
> código rodar. Custa uma medição de distância e evita reescrever um sistema
> que estava certo.

#### A cadeia agora é exercida headless (15/08)

O buraco desta seção não era falta de teste por peça — era que **nenhum teste
ligava as peças**. `tests/combat_e2e.luau` (19 casos) fecha isso: espelha os
handlers de `init.server.lua` e `init.client.lua` linha a linha e roda posição
→ aquisição em cone → resolução → `CombatEvent` → hit-stop, tremida, som,
número de dano → `StateDelta`.

Os três primeiros casos são a própria história desta seção:

| Caso | O que prova |
|---|---|
| a 41,2 studs | o golpe erra e as cinco camadas ficam exatamente onde estavam: paradas |
| a 6 studs | um leve confirmado acende as cinco de uma vez |
| os dois lado a lado | **a distância era a única diferença** — a camada de impacto nunca esteve quebrada |

A prova é por efeito observável (evento emitido, trauma acumulado, hit-stop
ativo, deixa resolvida, número autorizado, vida replicada), nunca por
instrumentação de módulo — a armadilha de §4.7.

**Achado que saiu da simulação e ainda não tem resposta.** O perfil de câmera
é escolhido por DESFECHO, e `HEAVY_ABILITIES` do `CombatCameraController` só
lista técnicas (`comet_shoulder`, `broken_cadence`, `eclipse_beat`). O pesado
básico chega como `abilityId = "heavy"` e recebe **o mesmo trauma do jab**,
apesar de causar o dobro de dano e ser a ferramenta de quebra de guarda. O
teste FIXA o comportamento atual em vez de mascarar: mudar feel é decisão de
Play, não número escolhido no escuro — é a lição desta própria seção. Está no
passo `a1_impact` do runbook (`docs/32` §6) para comparar leve e pesado com o
olho e decidir com medição.

### 4.9 Correção de 14/08 — o corpo estalava para a câmera a cada golpe

Reclamação separada das três acima, e mais fácil de reproduzir: **parado**, de
costas para a câmera, o personagem girava sozinho no instante do golpe e de
cada técnica.

Não era a animação. `CharacterController.faceAim` girava a `HumanoidRootPart`
com `CFrame.lookAt` **antes** de enviar a intenção, desligava o `AutoRotate`
por 0,6 s e devolvia o giro depois. O servidor então lia essa rotação
replicada para resolver alcance e cone. Ou seja: a direção do golpe chegava ao
servidor como **efeito colateral no estado físico**, e o preço era o corpo
mudar de ângulo em relação à câmera a cada ação.

A mira agora é **declarada**:

| Camada | Antes | Agora |
|---|---|---|
| Cliente | `root.CFrame = CFrame.lookAt(...)` + `AutoRotate = false` por 0,6 s | `CharacterController.aimVector(controller)` devolve `{ x, z }` unitário |
| Rede | direção viajava implícita, na rotação replicada | campo `aim` no payload da intenção, validado como o do dash |
| Servidor | lia a rotação da `HumanoidRootPart` | `applyDeclaredAim` → `SpatialService.aimLook(aim)` |

**Nenhuma autoridade mudou de lado.** Quem escrevia aquela rotação já era este
mesmo cliente; a diferença é que a direção passou a viajar num campo fechado e
validado em vez de sair de um efeito colateral. Alcance, abertura, escolha de
alvo e dano continuam 100% no servidor (§5.1 de `docs/13`), e o corpo fica onde
o jogador deixou.

> `docs/18` §8.2 descreve o `faceAim` como correção da rodada de 13/08. Aquele
> texto é registro histórico: a função não existe mais no código.


## 5. Fases e markers

Cada clip de combate declara os markers abaixo quando aplicáveis:

| Marker | Uso de apresentação | Proibido |
|---|---|---|
| `AnticipationEnd` | encerrar smear/câmera de preparação | abrir hitbox |
| `PresentationImpact` | som e hit-stop no contato previsto ou no `CombatEvent`; VFX de acerto só com confirmação | decidir acerto/dano |
| `FootPlantL` / `FootPlantR` | passo e poeira local | alterar velocidade |
| `TrailOn` / `TrailOff` | trilha geométrica local | representar alcance maior que a hitbox |
| `RecoveryPose` | iniciar blend visual de retorno | liberar ação antes do servidor |
| `ClipEnd` | limpeza de apresentação | encerrar cooldown/estado autoritativo |

O Roblox permite markers na timeline e leitura com `AnimationTrack:GetMarkerReachedSignal()`. A implementação deve desconectar sinais ao destruir a track e possuir fallback por tempo visual se um marker de apresentação faltar. Referência: [Animation events — Roblox Creator Hub](https://create.roblox.com/docs/animation/events).

## 6. Critérios de qualidade

Um clip só muda de “blocking” para “aprovado” quando:

- a ação é identificada corretamente por 4 de 5 observadores em silhueta, sem VFX/áudio;
- startup, active visual e recovery concordam com a spec server-side com tolerância máxima inicial de um frame a 60 FPS nos pontos de apresentação;
- pé declarado como plantado não deriva mais de 0,15 stud no rig padrão;
- não há interseção evidente de membros em reprodução normal e a 0,25×;
- transições de idle/corrida/guarda não produzem estalo visível em captura a 60 FPS;
- impacto continua compreensível com partículas reduzidas e em 720p;
- efeito percebido nunca sugere alcance maior que a hitbox;
- versão sem tremor, flash forte e vibração preserva toda informação funcional;
- pose, câmera e timing passam o checklist de originalidade P1.

Baselines de feeling para playtest, não regras finais:

- blends curtos de 60–120 ms em ações responsivas e mais longos somente onde a recuperação exige peso;
- nenhum shake move a câmera de outro jogador ou altera a mira autoritativa.

**Valores em vigor (recalibrados em 14/08 à noite).** Os anteriores — hit-stop
de 33–50 ms e shake de até 2° / 0,3 stud — estavam implementados e eram
invisíveis. O motivo não era o teto e sim a curva: `amplitude = trauma²`
achatava justamente o degrau de baixo, e o degrau de baixo é o **acerto comum**,
o golpe que o jogador mais dá. A curva passou a `trauma^1,4`, que preserva a
ordem entre os desfechos sem zerar o mais frequente.

| Desfecho | trauma | antes (t², teto 2°) | agora (t^1,4, teto 3,2°) | punch de FOV | hit-stop |
|---|---:|---:|---:|---:|---:|
| guarda | 0,28 | 0,05° | 0,53° | +1,2 | 35 ms |
| acerto | 0,50 | **0,24°** | **1,21°** | +2,6 | 70 ms |
| contra | 0,70 | 0,50° | 1,94° | +4,0 | 90 ms |
| morte | 0,85 | 0,98° | 2,55° | +5,0 | 110 ms |

O teto continua existindo para o shake nunca virar enjoo: o máximo absoluto
(3,2° / 0,45 stud) só é alcançado com trauma saturado em 1, o que nenhum perfil
sozinho atinge. O hit-stop segue curto de propósito — congelar muito faz a
cadeia leve parecer travada.

**Luz.** Até 14/08 o kit não tinha nenhuma: a camada de VFX criava
`ParticleEmitter`, `Trail` e `Part`, e zero `PointLight`. Partícula com
`LightEmission` **brilha mas não ilumina** — nada do combate projetava luz no
chão nem no oponente. Agora cada camada declara `glowStuds`, derivado do próprio
raio da forma (`AbilityVfx.GlowByKind`), e o `PointLight` segue a mesma
envoltória das partículas, acendendo e apagando junto com a forma:

| Forma | multiplicador do raio | papel |
|---|---:|---|
| `burst` | 1,6 | o instante do golpe estoura |
| `ring` | 1,4 | expansão no chão |
| `arc` | 1,2 | corte |
| `shell` | 1,0 | envolve o corpo |
| `charge` | 0,9 | telegrafa a antecipação |
| `trail` | 0,8 | alonga sem competir |

A regra é "a luz acompanha o raio" e não um número solto por camada, para não
existirem duas grandezas que alguém precise manter em sincronia na mão.
`AbilityVfx.validate()` recusa camada com `glowStuds` zerado.

## 7. Pipeline de produção

### Gate W1 — runtime da fundação

W1 é pré-requisito para produzir o golpe-modelo. O código e o RBXL construído não bastam: o roteiro completo e os critérios de aprovação estão em `15-WORLD-PRESENTATION.md` §9.

Para W1 passar, a evidência precisa mostrar, no mínimo:

- Play Solo por 20 minutos com Output limpo de erros do projeto;
- leve, pesado, guarda e dash retornando à pose-base sem joint preso;
- telegraph de inimigo legível por contorno branco e símbolo, inclusive sem depender de cor;
- spawn/respawn e entrada tardia sem ator invisível, duplicado ou congelado;
- percurso completo pelas duas saídas sem queda entre pisos;
- prompt do Instrutor e hold de 1,5 s do Marco de Retorno funcionando com validação server-side.

Até essa execução existir, W1 permanece **pendente**, mesmo com 241 testes de domínio, 73 de animação/apresentação, 67 de fuzz e 19 de simulação de combate verdes. O roteiro do dia está em [`docs/32-STUDIO-PLAYTEST-RUNBOOK.md`](32-STUDIO-PLAYTEST-RUNBOOK.md).

### Gate A0 — direção e originalidade

- moodboard abstrato de peso, ritmo e materiais, sem copiar frames de anime;
- folha de poses próprias em frente/perfil/três quartos;
- revisão P1 e lista explícita do que evitar;
- rig R15 e escala canônica congelados.

### Gate A1 — golpe-modelo

**Entrada obrigatória:** W1 aprovado, P1 concluído, rig R15 canônico congelado e conta/grupo proprietário definidos.

**Execução:**

- produzir somente o blocking original do Ombro Cometa e preservar o arquivo-fonte;
- fazer uma segunda passada de curvas, arcos, peso e retorno à locomoção;
- declarar `AnticipationEnd`, `PresentationImpact`, `RecoveryPose` e `ClipEnd`;
- integrar variantes visuais de impacto aberto, guarda e whiff sem conceder autoridade ao marker;
- capturar frente, perfil e três quartos a 1× e 0,25×, sem VFX e com efeitos reduzidos;
- executar no Studio em PC, touch e gamepad, incluindo ao menos um dispositivo real antes do PASS.

**Aceite mensurável:**

- 4 de 5 observadores identificam o golpe em silhueta sem áudio/VFX;
- pé plantado deriva no máximo 0,15 stud e não há clipping evidente a 0,25×;
- pontos de apresentação ficam a no máximo um frame de 60 FPS do contrato visual esperado;
- aberto, guarda e whiff são distinguíveis e nunca exibem hit sem confirmação autoritativa;
- nenhum joint fica preso após cancelar, morrer, respawnar ou alternar para guarda/dash;
- o cenário-alvo atende ao budget de §8 no dispositivo medido;
- a revisão registra resultado `PASS`, `REWORK` ou `CUT`, IDs, versões, capturas, métricas e divergências.

Não produzir os outros 44 clipes antes de A1 comprovar o pipeline.

### Gate A2 — kit F0

- locomoção/guarda/cadeia leve;
- três técnicas completas;
- reações do jogador e inimigos;
- LOD de apresentação e redução de efeitos;
- teste cego de leitura e teste adversarial de dessync.

### Gate A3 — polish

- variações de impacto e transições;
- câmera, áudio e VFX próprios sincronizados;
- limpeza de metadados de rigs e keyframes redundantes;
- profiling com oito jogadores e NPCs ativos;
- aprovação final de originalidade e acessibilidade.

O Animation Editor possui otimização de keyframes com preview; a redução só é aceita depois de comparar silhueta, markers e foot plant. Referência: [Animation Editor — Roblox Creator Hub](https://create.roblox.com/docs/animation/editor).

## 8. Performance e dispositivos

Baselines iniciais a medir, não evidência atual:

- cenário: 8 jogadores, 4 Estilhaços Errantes e 1 Ancorado;
- PC integrado: alvo 60 FPS com frame pacing estável;
- Android de entrada: alvo mínimo 30 FPS sustentado por 15 min, sem degradação térmica progressiva atribuída à apresentação;
- `stepAnimation` p95 inicial abaixo de 3 ms no dispositivo móvel de referência;
- NPC distante não reproduz camada de detalhe; apresentação de NPC é priorizada no cliente por distância/visibilidade;
- não criar/destroçar tracks e attachments a cada hit; carregar/cachear por personagem e limpar no despawn;
- VFX, tweens e câmera rodam localmente; servidor replica somente estado necessário.

O MicroProfiler deve separar `stepAnimation`, script e render. Um PC potente não substitui o teste no telefone. Referências: [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler) e [testes em hardware](https://create.roblox.com/docs/performance-optimization/test-on-hardware).

## 9. Evidência obrigatória por clip

Para cada revisão aprovada, guardar:

- ID do asset, versão, autor, rig e arquivo-fonte;
- duração e lista de markers;
- captura 1× e 0,25× em frente, perfil e três quartos;
- captura sem VFX e com efeitos reduzidos;
- resultado do checklist de foot sliding/interseção/silhueta;
- plataforma, resolução, FPS, frame time e preset gráfico;
- divergência observada entre apresentação e evento autoritativo;
- decisão: aprovar, retrabalhar ou cortar.

“Ficou bonito” é comentário; “4/5 reconheceram a ação, sem foot sliding acima do limite e sem frame spike no Android-alvo” é evidência.

## 10. Estado e próximos passos

Comprovado agora: regras de combate, eventos autoritativos, receitas/poses procedurais puras para NPC e jogador local, cadeia leve de quatro golpes (§4.3), catálogo e integração de áudio de combate (`16-COMBAT-AUDIO.md`), contrato visual de telegraph/late join e os testes headless. Um RBXL também foi reconstruído, mas build não comprova execução, aparência nem feeling. **A inspeção visual e o profiling do runtime continuam ausentes** — nada aqui foi visto rodando.

Ainda pendente:

1. concluir P1;
2. definir conta/grupo proprietário dos assets;
3. escolher animador e ferramenta-fonte;
4. executar e aprovar W1 no Studio;
5. **ver a cadeia leve rodando no Studio** — quatro cliques seguidos num Estilhaço, conferindo leitura do chute e do finalizador na câmera padrão, e confirmando pela parte materializada (`Root.Transform.Z` ≠ 0 no golpe) que o anexo de junta de §4.7 continua pegando;
6. publicar os 29 `.ogg` e preencher `assetId` em `CombatAudio.luau` (`16-COMBAT-AUDIO.md` §5);
7. produzir o blocking original do Ombro Cometa;
8. substituir gradualmente o procedural somente quando houver asset real aprovado — não criar serviço vazio;
9. executar A1 no Studio e em dispositivo real antes de animar Cadência Quebrada ou Retorno de Pulso.

> **13/08:** o Ombro Cometa ganhou um pacote VFX procedural de "golpe pesado"
> (aura de carga, flash e onda de choque no impacto, rastro maior, poses mais
> pesadas e perfil de câmera próprio — ver `17-COMBAT-FEEL.md` §2.7). Continua
> scaffolding descartável, sem keyframe/asset, e **não reduz** a contagem de
> clipes do gate A1 — mas é o que deve aparecer no Studio já no próximo
> playtest (tecla 1 contra o dummy).

## 11. Pacote de apresentação de defesa, dash e chão quebrando — 2026-08-14

Esta rodada adiciona um pacote procedural focado nas ações que o jogador repete com maior frequência. A defesa agora tem braços fechados, cotovelos, punhos, joelhos e pequenos ajustes de tornozelo; a leitura é de absorção e não de pose estática. O dash deixou de ser uma pose única e passou a ter quatro momentos: compressão, entrada no passo, passada de aceleração e recuperação. A raiz visual pode inclinar e avançar poucos studs como ilusão de peso, mas nunca escreve posição física ou `HumanoidRootPart.CFrame`.

O catálogo `src/shared/Data/AbilityVfx.luau` recebeu as receitas `guard_raise` e `dash_run`. A defesa usa uma casca ciano e um anel curto. O dash usa rastro próximo ao torso, anel de atrito nos pés e burst âmbar de chão quebrando. Todas as camadas são locais e não confirmadas: elas não afirmam dano, acerto ou bloqueio. O player de VFX foi conectado ao fluxo de input em `src/client/init.client.lua`, enquanto a confirmação de contato continua exclusiva do `CombatEvent` server-side.

| Ação | Fases da pose | Apresentação | O que não pode fazer |
|---|---|---|---|
| Defesa | Fechar → sustentar → liberar | Casca ciano, órbita e faíscas de deflexão | Não declarar bloqueio sem evento autoritativo |
| Dash | Comprimir → acelerar → passar → recuperar | Rastro ciano, atrito âmbar e estilhaços temporários | Não teleportar, criar hitbox ou alterar posição válida |
| Chão quebrando | Marcar → levantar → dissipar | Anel, crack, poeira e debris em pool futuro | Não abrir buraco persistente nem mudar colisão |

As imagens `docs/assets/combat-presentation-reference.png`, `defense-guard-presentation.png`, `dash-run-presentation.png`, `ground-break-impact-presentation.png` e `impact-vfx-micro-library.png` são referências conceituais originais. O documento `docs/25-COMBAT-PRESENTATION-PLAN.md` contém o inventário, as fontes CC0 candidatas e a ordem de integração. Elas orientam a arte, mas não são evidência de Play no Studio.

A suíte headless passou a cobrir 73 casos de animação/apresentação, incluindo a distinção entre as fases do dash, a postura defensiva, a conexão das receitas ao input, a adoção de junta atrasada (§4.7), os sinais de fronteira e a validação da paleta/iluminação do spawn e da silhueta dos dois bots. A aprovação visual ainda exige A1/W1 no Roblox Studio, com captura em frente, perfil e três quartos, além de verificação de foot sliding, interseção, FPS e redução de efeitos em Android.


## 12. Referências visuais como evidência de revisão

O índice `VISUAL-REFERENCE-INDEX.md` relaciona cada referência às poses, receitas e gates. Para qualquer revisão de defesa, dash ou impacto, usar `docs/26-VISUAL-VALIDATION-CHECKLIST.md` e registrar a referência, o hash do PNG, o build, as três câmeras, a captura sem VFX, a captura com efeitos reduzidos e as divergências observáveis.

A imagem orienta a silhueta, o ritmo e a hierarquia de materiais; não comprova que o personagem se moveu, que o bloqueio foi aceito ou que o chão foi alterado. A decisão de aprovação exige Play no Studio, e A1 continua separado dos testes headless de fases e amplitudes.

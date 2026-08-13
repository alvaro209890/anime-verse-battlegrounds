# 15 — Fundação de mundo e apresentação F0

> **Estado em 2026-08-13 (`108be31`):** implementado em código e validado por lint, 166 testes Lune e build Rojo. O artefato local reconstruído possui 160553 bytes e SHA-256 `8C6D136AE9B6186F5DF6E51F6E6306C085C13BBEF0868097FB8FE6A86831D32F`; isso prova somente a saída do build, não boot ou runtime. Nenhuma imagem, malha ou animação final foi produzida e **não houve Play atual no Studio**.

## 1. Objetivo e limite

Esta entrega torna o place reconhecível e navegável antes da produção cara de arte. Ela melhora o que o repositório já possuía — `Parts` criadas pelo `WorldService` — sem importar `.fbx`, `.obj`, `.blend`, textura, áudio ou asset de terceiros.

O recorte entrega:

- uma rota clara entre spawn, treino, Portão Norte, Portão Oeste e cratera;
- piso gerado para todos os volumes jogáveis, incluindo as duas transições e o braço livre oeste;
- marcos físicos redundantes com o HUD de zona;
- modelos low-poly funcionais para dummy, instrutor, Estilhaço Errante e Ancorado;
- animação procedural de NPC para idle, locomoção, telegraph, ataque, morte, respawn e late join;
- apresentação procedural local do jogador para leve, pesado, guarda e dash;
- telegraph com contorno branco e símbolo que não depende somente de cor;
- prompts nativos de interação para Instrutor e Marco de Retorno, com distância/hold revalidados no servidor;
- um gate de unlock para testar as três técnicas no Studio sem remote de cheat;
- dados de apresentação separados das Instances para permitir testes headless.

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

A iluminação usa tarde clara, sombras globais e atmosfera neutra. Os valores são baseline de greybox, não direção de arte aprovada.

## 4. Modelos procedurais

As receitas vivem em `src/shared/Data/WorldPresentation.luau`; o módulo guarda apenas números e validações, sem `Instance` ou `Color3`.

| Ator | Forma | Escala | Papel visual |
|---|---|---:|---|
| Dummy de treino | humanoide em blocos | 1,00 | alvo estável e neutro |
| Instrutor do Limiar | humanoide em blocos | 1,05 | leitura distinta do dummy sem roupa/cabelo final |
| Estilhaço Errante | núcleo + cunhas | 0,90 | ameaça móvel leve |
| Estilhaço Ancorado | núcleo + cunhas | 1,65 | elite reconhecível por escala e massa, não só por cor |

Cada modelo usa uma raiz invisível ancorada e peças sem colisão ligadas por `Motor6D`. A altura da raiz é derivada da receita para manter os pés sobre o piso; cabeça e braços seguem o torso, evitando separação visual ao inclinar. A posição/olhar da raiz vêm do `SpatialService` no servidor e só são replicados quando posição ou direção mudam. O cliente altera apenas `Motor6D.Transform`; portanto a pose nunca muda alcance, alvo, dano ou posição válida.

> **Skins procedurais (13/08, `d0f6f8d`):** os modelos ganharam peças de
> identidade com joints próprios (não animados — o `ActorAnimator` ignora
> joints desconhecidos): Instrutor com `Hood`/`Collar`/`Belt` (faixa Neon),
> dummy com `Target` (disco Neon no peito), estilhaços com `Halo` (anel Neon
> que orbita junto do pivot), `ShardFront`/`ShardBack` e, no elite, coroa
> `Crown_1..3`. Continua tudo Part/Motor6D greybox até o Gate P1.

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

Os eventos transitórios carregam `durationSeconds` e `visualPattern`, expiram e voltam a idle para não congelar a locomoção. `PoseSerial`, início e duração replicados permitem que um cliente tardio apresente o estado sem transformar timestamp em autoridade. Joints são cacheados por modelo; não há busca recursiva de `Motor6D` a cada frame depois da primeira amostra.

### 5.2 Jogador local

`PlayerCombatAnimator` compõe um overlay procedural sobre a animação-base do personagem local:

| Intenção | Duração procedural | Limite |
|---|---:|---|
| ataque leve | 280 ms | resposta visual; não confirma hit |
| ataque pesado | 520 ms | windup/compromisso visual; não autoriza janela |
| guarda down/up | 160/180 ms | pose acompanha a intenção; guarda efetiva continua server-side |
| dash | 320 ms | inclinação visual; não move root nem concede i-frame |

O overlay é reaplicado em `PreSimulation`, acompanha respawn e restaura joints ao parar. Ele **não é clip final** e não cobre as três técnicas: Ombro Cometa, Cadência Quebrada e Retorno de Pulso ainda usam somente a resposta genérica do restante do cliente.

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
- 166 testes Lune, Selene e build Rojo passam;
- `anime-verse-battlegrounds.rbxl`: 160553 bytes, SHA-256 `8C6D136AE9B6186F5DF6E51F6E6306C085C13BBEF0868097FB8FE6A86831D32F`.

O último item é evidência de **build reproduzido**. Não demonstra que o arquivo abriu, iniciou servidor/cliente, renderizou Parts ou respondeu a input.

Ainda não comprovado:

- que todas as Parts, joints, materiais e iluminação aparecem corretamente em Play;
- que os pisos realmente evitam queda, degrau ou snag nas duas rotas;
- que os modelos não afundam, flutuam ou sofrem clipping no rig/física real;
- sincronismo visual de telegraph/ataque sob latência;
- funcionamento visual dos prompts, hold e interação no Studio;
- leve, pesado, guarda e dash no R15 real e após morte/respawn;
- legibilidade do Portão Oeste e da cratera sem instrução verbal;
- frame time de `ActorAnimator`/`PlayerCombatAnimator` em PC integrado, Android e oito jogadores;
- mobile e gamepad em dispositivo real;
- qualquer conclusão sobre beleza ou qualidade final;
- clipes dedicados e revisão visual das três técnicas.

## 9. Próximos gates escolhidos

### W1 — leitura do greybox

**Entrada:** commit `108be31`; conferir antes do teste o RBXL de 160553 bytes e o SHA-256 registrado em §8. A conferência identifica o artefato, mas não aprova o gate.

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

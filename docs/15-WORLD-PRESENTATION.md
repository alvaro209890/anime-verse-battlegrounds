# 15 — Fundação de mundo e apresentação F0

> **Estado em 2026-08-13:** implementado em código e validado por lint, 159 testes Lune e build Rojo. Nenhuma imagem, malha ou animação final foi produzida; não houve inspeção visual em Play nesta rodada. O conteúdo abaixo é greybox procedural original e continua sujeito aos gates P1, Studio e dispositivo.

## 1. Objetivo e limite

Esta entrega torna o place reconhecível e navegável antes da produção cara de arte. Ela melhora o que o repositório já possuía — `Parts` criadas pelo `WorldService` — sem importar `.fbx`, `.obj`, `.blend`, textura, áudio ou asset de terceiros.

O recorte entrega:

- uma rota clara entre spawn, treino, Portão Norte, Portão Oeste e cratera;
- marcos físicos redundantes com o HUD de zona;
- modelos low-poly funcionais para dummy, instrutor, Estilhaço Errante e Ancorado;
- animação procedural de apresentação para idle, locomoção, telegraph, ataque, morte e respawn;
- um gate de unlock para testar as três técnicas no Studio sem remote de cheat;
- dados de apresentação separados das Instances para permitir testes headless.

Não entrega:

- clipes R15 finais do jogador;
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

`ZoneVolumes` e `Anchors` são invisíveis. A versão anterior deixava os volumes de 50 studs de altura parcialmente transparentes; isso podia encobrir o mapa. A fronteira agora é comunicada pelos portais, postes, troca de solo e HUD, enquanto o volume permanece consultável pelo servidor.

## 3. Composição do mundo

| Elemento | Função | Regra |
|---|---|---|
| Praça de spawn | oferece orientação e proteção inicial | centrada na camada segura; `SpawnLocation.Duration = 8` |
| Caminho norte | rota direta para a fronteira e a cratera | 8 studs de largura |
| Caminho oeste | segunda saída com linha de visão quebrada | preserva o muro em L da spec |
| Caminho de treino | liga praça, instrutor e dummy | fica integralmente na zona segura |
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

Cada modelo usa uma raiz invisível ancorada e peças sem colisão ligadas por `Motor6D`. A posição/olhar da raiz vêm do `SpatialService` no servidor. O cliente altera apenas `Motor6D.Transform`; portanto a pose nunca muda alcance, alvo, dano ou posição válida.

## 5. Animação procedural

`ActorAnimator` é uma camada greybox, não o `AnimationController` final do jogador. Ele recebe `EnemyEvent`, consulta a receita do ator e amostra poses locais:

| Estado | Apresentação | Autoridade preservada |
|---|---|---|
| idle | bob pequeno e rotação lenta do núcleo | não altera AI |
| moving | balanço alternado / oscilação do Estilhaço | root continua vindo do servidor |
| telegraph | corpo recua e segura a antecipação | não abre hitbox |
| attack | compromisso curto para a frente | dano só aparece após evento autoritativo |
| died | queda limitada a até 90° e ocultação posterior | morte já foi decidida no servidor |
| spawn/respawn | elevação e assentamento de 600 ms | respawn/cooldown continuam no domínio |

Os eventos transitórios expiram e voltam a idle para não congelar a locomoção. Joints são cacheados por modelo; não há busca recursiva de `Motor6D` a cada frame depois da primeira amostra.

## 6. Gate de playtest no Studio

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

## 7. Evidência atual

Comprovado automaticamente:

- quatro receitas, paletas e limites de pose passam no validador;
- antecipação recua, ataque compromete e morte respeita o ângulo da receita;
- o gate exige Studio + atributo e libera somente três técnicas;
- unlock de sessão aparece para habilidade/HUD e fica fora do snapshot durável;
- 159 testes Lune, Selene e build Rojo passam.

Ainda não comprovado:

- que todas as Parts, joints, materiais e iluminação aparecem corretamente em Play;
- que os modelos não afundam, flutuam ou sofrem clipping no rig/física real;
- sincronismo visual de telegraph/ataque sob latência;
- legibilidade do Portão Oeste e da cratera sem instrução verbal;
- frame time do `ActorAnimator` em PC integrado, Android e oito jogadores;
- qualidade visual das animações finais do jogador.

## 8. Próximos gates escolhidos

### W1 — leitura do greybox

- executar o roteiro solo com `F0Debug` desligado e ligado;
- capturar spawn, treino, ambos os portões e cratera em 720p;
- verificar colisão, rotas, clipping, orientação e retorno após morte;
- teste cego: pelo menos 9/10 jogadores identificam a saída segura e o risco antes de cruzar.

### A1 — golpe-modelo real

- concluir P1 e propriedade da conta/grupo;
- produzir somente o blocking original do Ombro Cometa em R15;
- integrar markers exclusivamente de apresentação;
- medir silhueta, foot sliding, sincronismo e frame time conforme `14-ANIMATION-PLAN.md`;
- não iniciar os outros 44 clipes antes da decisão de A1.

### W2 — performance e dispositivos

- oito jogadores, quatro Errantes e um Ancorado;
- MicroProfiler com script, física, render e `stepAnimation` separados;
- PC integrado e Android por 15 minutos;
- touch e gamepad reais, com efeitos reduzidos;
- registrar p50/p95, memória, resolução e preset; sem estimar números não medidos.

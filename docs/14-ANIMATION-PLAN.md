# 14 — Plano de animação e apresentação de combate

> **Status em 2026-08-13 (`108be31` + cadeia leve):** existe uma fundação procedural para NPCs e para o personagem local em ataque leve, ataque pesado, guarda e dash. O ataque leve virou uma **cadeia de quatro golpes de silhueta distinta** (§4.3), com cotovelo e joelho articulados. Validação apenas por análise estática, build e testes headless. **Nenhum dos 45 clipes finais foi criado ou validado, nenhuma das três técnicas possui animação dedicada e não houve Play atual no Studio.** A F0 continua usando apresentação genérica até os gates W1, P1 e A1.
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

Encadeia dentro de **0,65 s**, espelhando `LIGHT_WINDOW` do `CombatService`. Dash, guarda e técnicas quebram a cadeia, como no servidor. O degrau é decisão de apresentação: quem resolve o `lightStep` autoritativo continua sendo o servidor.

Três mecanismos sustentam a sensação de peso, todos em número:

- **Cotovelo e joelho articulados.** O rig só compunha ombro e quadril, então nenhum soco estendia e chute era impossível. O cotovelo sai de −92° e estala perto de reto no impacto; o joelho encaixa a perna dobrada e estende no chute.
- **Peso atrasado.** Quadril e tronco são amostrados 25% à frente da extremidade. Sem esse deslocamento de fase o corpo inteiro chega junto e o rig parece girar de uma peça só.
- **Pausa de impacto e retorno elástico.** A pose do golpe segura alguns quadros e a volta usa `easeOutBack`, que ultrapassa levemente o neutro antes de assentar. `easeOutBack(1)` é exatamente 1, então toda ação termina em neutro cravado, sem resíduo entre golpes.

Ataque pesado e Ombro Cometa herdaram pausa, elástico e cotovelo.

**Limite conhecido:** o cliente avança o degrau a cada clique, mas o servidor zera `lightStep` quando o golpe erra. Numa sequência de erros a pose pode exibir o chute enquanto o servidor está no jab. A divergência é puramente cosmética — nenhuma decisão de acerto depende dela — e só some quando o servidor devolver o degrau confirmado.

Cobertura: `tests/animation.luau` (silhuetas distintas, extensão de cotovelo, chute como perna, amplitude crescente, retorno exato ao neutro, overshoot, liderança do núcleo, janela de encadeamento).

## 5. Fases e markers

Cada clip de combate declara os markers abaixo quando aplicáveis:

| Marker | Uso de apresentação | Proibido |
|---|---|---|
| `AnticipationEnd` | encerrar smear/câmera de preparação | abrir hitbox |
| `PresentationImpact` | som, hit-stop visual e VFX se o servidor confirmou | decidir acerto/dano |
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

- hit-stop apenas visual de 33–50 ms em golpe forte confirmado;
- shake local de até 0,3 stud e 2° no preset completo, sempre desativável;
- blends curtos de 60–120 ms em ações responsivas e mais longos somente onde a recuperação exige peso;
- nenhum shake move a câmera de outro jogador ou altera a mira autoritativa.

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

Até essa execução existir, W1 permanece **pendente**, mesmo com 166 testes verdes.

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
5. **ver a cadeia leve rodando no Studio** — quatro cliques seguidos num Estilhaço, conferindo leitura do chute e do finalizador na câmera padrão;
6. publicar os 29 `.ogg` e preencher `assetId` em `CombatAudio.luau` (`16-COMBAT-AUDIO.md` §5);
7. produzir o blocking original do Ombro Cometa;
8. substituir gradualmente o procedural somente quando houver asset real aprovado — não criar serviço vazio;
9. executar A1 no Studio e em dispositivo real antes de animar Cadência Quebrada ou Retorno de Pulso.

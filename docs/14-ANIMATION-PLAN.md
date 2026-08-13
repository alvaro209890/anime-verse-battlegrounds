# 14 — Plano de animação e apresentação de combate

> **Status em 2026-08-13:** a fundação greybox procedural de NPCs foi implementada; nenhum dos 45 clipes finais foi criado ou validado. A F0 continua usando modelos em Parts e apresentação genérica até o Gate P1. Este documento transforma “animações bem bonitas” em entregas e critérios verificáveis, sem autorizar cópia de pose, timing, câmera ou efeito de uma franquia.

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

`WorldPresentation.luau` e `ActorAnimator.luau` introduzem receitas e poses procedurais para dummy, instrutor e dois Estilhaços. Essa camada serve para verificar estados, silhueta básica, telegraph e custo de atualização antes da produção R15. Ela não usa timeline, keyframe, marker ou asset publicado e não conta como nenhum dos 45 clipes planejados. A árvore, o contrato de autoridade e o roteiro de evidência ficam em `15-WORLD-PRESENTATION.md`.

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

### Gate A0 — direção e originalidade

- moodboard abstrato de peso, ritmo e materiais, sem copiar frames de anime;
- folha de poses próprias em frente/perfil/três quartos;
- revisão P1 e lista explícita do que evitar;
- rig R15 e escala canônica congelados.

### Gate A1 — golpe-modelo

- blocking do Ombro Cometa;
- segunda passada de curvas/arcos;
- markers e integração somente de apresentação;
- variantes impacto aberto, guarda e whiff;
- captura PC + emulação touch + gamepad;
- relatório de tempo de produção, bugs e custo de revisão.

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

Comprovado agora: regras de combate, eventos autoritativos, receitas/poses procedurais puras e build/testes headless descritos em `12-TESTING.md`. A inspeção visual e o profiling do runtime continuam ausentes.

Ainda pendente:

1. concluir P1;
2. definir conta/grupo proprietário dos assets;
3. escolher animador e ferramenta-fonte;
4. produzir o blocking original do Ombro Cometa;
5. substituir gradualmente o greybox procedural por um futuro `AnimationController` somente quando houver asset real — não criar serviço vazio;
6. executar A1 no Studio e em dispositivo antes de ampliar a lista.

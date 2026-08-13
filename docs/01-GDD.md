# Anime Verse Battlegrounds — Game Design Document

## 1. Escopo e decisões de design

Este documento define os contratos de experiência de combate, recursos, loadout, Ressonância, progressão, equipamento e monetização. É planejamento; não contém implementação.

| ID | Decisão | Estado |
|---|---|---|
| GDD-DEC-001 | Um único núcleo energético governa o loadout; técnica estrangeira converte seu custo para esse recurso. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |
| GDD-DEC-002 | Loadout usa quatro unidades de capacidade, uma ultimate e orçamento de impacto 12. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |
| GDD-DEC-003 | Ressonância 2.0 combina slots, impacto e Dissonância; `rawD > 3` invalida o loadout. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |
| GDD-DEC-004 | Build pura recebe consistência e passiva; não recebe redução global de cooldown. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |
| GDD-DEC-005 | Técnica tem 10 níveis, família tem 20; comportamento domina e bônus numérico por técnica não passa de 6%. | aprovada como política; curvas de XP são baseline de playtest |
| GDD-DEC-006 | Equipamento é sidegrade em três slots, com caps de status e normalização competitiva. | aprovada como política; efeitos são baseline de playtest |
| GDD-DEC-007 | Monetização permanece somente no plano e não vende poder. | fechada pelo briefing |
| GDD-DEC-008 | Somente números explicitamente marcados como baseline podem ser recalibrados por playtest; políticas estruturais exigem nova decisão. | obrigatória |
| GDD-DEC-009 | Forja possui cinco graus determinísticos, sem falha, destruição, rebaixamento ou pity. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |
| GDD-DEC-010 | Há três presets gratuitos e no máximo seis com entitlement; quatro slots ativos não mudam. | aprovada — 2026-08-12 — Álvaro (seleção delegada ao Codex) |

## 2. Modelo de combate

### 2.1 Objetivos

- Tempo para eliminar um oponente de poder equivalente: **12–18 segundos** numa troca completa, sem contar fuga prolongada.
- Uma sequência confirmada comum remove **18–28%** da vida; uma sequência excepcional, com recurso e ultimate, não excede **45%** sem uma segunda leitura do oponente.
- Todo controle forte tem antecipação, duração, recuperação e imunidade temporária subsequente.
- Movimento cria ângulo; não deve apagar toda oportunidade de punição.
- Efeito visual comunica área funcional. A hitbox nunca é maior que o efeito percebido.

Os valores são baselines de teste. Alterações exigem registro do motivo, hipótese e resultado observado.

### 2.2 Estado base de referência

O balanceamento começa com um avatar de referência:

| Atributo | Baseline |
|---|---:|
| Vida em PvP equivalente | 100 |
| Guarda | 100 |
| Velocidade de caminhada | 16 studs/s |
| Velocidade de corrida | 22 studs/s |
| Dash | 12 studs em 0,22 s |
| Recarga base do dash | 3,0 s |
| Cadeia de ataque básico | 4 golpes: 5 + 5 + 6 + 10 |
| Janela para continuar a cadeia | 0,65 s |
| Recuperação do quarto golpe | 0,55 s |
| Buffer de entrada | 150 ms PC/console; 220 ms mobile |

A cadeia básica completa causa 26 de dano apenas se todos os golpes forem confirmados. O quarto golpe é o mais legível e punível. Ataques não giram automaticamente 180° depois do quadro de compromisso.

### 2.3 Ações universais

- **Ataque leve:** pressão, confirmação e ganho pequeno de recurso conforme a família.
- **Ataque pesado:** quebra guarda e cobra recuperação maior; não inicia combo seguro quando erra.
- **Guarda:** reduz dano frontal e consome barra. Costas, agarrões e ataques sinalizados de quebra são respostas.
- **Aparo:** primeiros 120 ms de uma guarda nova; uma compensação de latência validada pelo servidor pode acrescentar no máximo 80 ms, sem aceitar tempo informado pelo cliente.
- **Dash:** reposiciona; invulnerabilidade, quando existir, é curta e explícita. O dash inicial não atravessa todo ataque.
- **Queda/recuperação:** após controle, o jogador recebe 0,75 s de resistência crescente a novo controle do mesmo grupo.
- **Ultimate:** ferramenta de virada ou fechamento, não botão de eliminação. Exige telemetria própria de acerto, interrupção e impacto na vitória.

### 2.4 Regras de combo e controle

- Cada técnica declara antecipação, quadros ativos, recuperação, tipo de stagger, empurrão e grupo de controle.
- Repetir o mesmo grupo de controle em até 4 s aplica duração de 60%; a terceira aplicação aplica 30% e imunidade de 1 s.
- Um combo garantido termina por limite de 3 s, 35 de dano ou três controles, o que ocorrer primeiro. O próximo dano abre uma janela defensiva.
- Técnicas de área, mobilidade dura e defesa dominante compartilham grupos de recarga quando necessário. Isso impede rodízio infinito de ferramentas equivalentes.
- Cancelamentos existem somente quando declarados pela técnica. Efeito visual previsto pelo cliente não concede dano, deslocamento, invulnerabilidade ou custo confirmado.

### 2.5 Autoridade e percepção

O servidor decide recurso, cooldown, posição válida, acerto, dano, controle, morte, recompensa e progresso. O cliente pode antecipar animação, áudio, câmera e partículas para resposta imediata; em rejeição, corrige sem criar acerto fantasma.

Metas de percepção:

- resposta visual local em até um quadro;
- confirmação do servidor apresentada sem duplicar efeito;
- tolerância de lag limitada e simétrica, nunca “confie no cliente”;
- degradação de VFX preserva telegraph, cor de perigo e contorno de área.

## 3. Combate multiplataforma

### 3.1 Mapeamento funcional

| Ação | PC | Mobile | Console |
|---|---|---|---|
| ataque leve | botão esquerdo | botão primário | RT |
| ataque pesado | botão direito | segurar primário | RB |
| guarda/aparo | F | botão de escudo | LT |
| dash | Q | botão de dash | B sem modificador |
| pulo | Espaço | botão de pulo | A sem modificador |
| técnicas 1–4 | 1–4 | botões contextuais 1–4 | segurar LB + A/B/X/Y |
| ultimate | R | botão de ultimate com confirmação | LB + RB |
| lock-on opcional | Tab / clique do meio | toque no alvo/ícone | R3 |

Uma técnica de custo dois ocupa duas unidades de capacidade, mas usa um único botão. O espaço não utilizado não produz botão vazio na interface.

### 3.2 Igualdade sem automação

- Mobile e console recebem magnetismo leve de câmera, não acerto automático. O cone inicial é 8° até 25 studs e cai a zero para ataques de área ou após o quadro de compromisso.
- PC pode usar câmera livre; lock-on é opcional em todas as plataformas.
- Toque nunca exige mais de dois botões simultâneos. Ultimate mobile pede pressionar por 250 ms para reduzir ativação acidental, sem atrasar outras plataformas além da própria antecipação da técnica.
- Tamanho, distância e opacidade dos botões são configuráveis. Vibração, tremor de câmera, flashes e segurar/alternar possuem opções de acessibilidade.
- Matchmaking monitora plataforma e método de entrada para detectar diferença persistente, mas não separa a comunidade por padrão.
- Testes de balanceamento incluem celular de baixo desempenho, controle e mouse/teclado antes de aceitar uma técnica.

## 4. Famílias de recurso

As quatro famílias aprovadas para planejamento são **Fluxo Vital**, **Éter Umbral**, **Contrafluxo** e **Ímpeto Metamórfico**, ainda condicionadas ao Gate jurídico P1. O HUD compacto usa **Fluxo**, **Umbral**, **Contra** e **Ímpeto**. A identidade visual de cada barra precisa ser distinguível também sem cor.

### 4.1 Fluxo Vital

- Pool de referência: **120**.
- Regeneração em combate: **4/s**; fora de combate: **6/s**.
- Custos previsíveis e ritmo constante.
- Ao chegar a zero: 4 s de exaustão, movimento −10% e dano de guarda recebido +15%.
- Passiva pura: a primeira técnica após 3 s sem gastar recurso custa 10% menos; recarga interna de 8 s.

### 4.2 Éter Umbral

- Pool de referência: **100**.
- Regeneração em combate: **2/s**; fora de combate: **6/s** depois de 3 s sem causar nem receber dano.
- Acertos em janela precisa geram **Fluxo**: devolvem 6 de recurso, no máximo uma vez por 1,5 s, e podem habilitar uma variação declarada.
- Errar a janela não remove controle do personagem; apenas perde o retorno.
- Passiva pura: a primeira ativação de Fluxo a cada 8 s devolve 3 adicionais.

### 4.3 Contrafluxo

- Capacidade de referência: **100**; sem regeneração passiva.
- Aparo válido: +18. Anulação parcial: +12. Absorver dano permitido pela técnica: +1 por 2 de dano pré-mitigação, limitado a 20 por evento.
- O mesmo ataque só alimenta uma vez; aliado e objeto próprio nunca geram carga.
- Fora de combate e abaixo de 20, a barra volta lentamente a 20 para impedir soft lock de exploração, sem permitir acumular para uma ultimate.
- Passiva pura: anulação perfeita reduz em 20% o custo da próxima técnica, uma vez a cada 10 s.

### 4.4 Ímpeto Metamórfico

- Pool de referência: **110**.
- Fora da forma: funciona como stamina de movimento e guarda, regenerando **3/s** em combate e **7/s** após 2 s sem gasto.
- Em forma: regeneração para; dreno base de 5/s, somado ao custo de ações.
- Chegar a zero encerra a forma, aplica 1,25 s de recuperação e impede nova transformação por 12 s.
- Passiva pura: bloquear no timing correto reduz o dreno da forma em 2/s durante 3 s; não acumula.

### 4.5 Modificadores

Todo modificador de recurso precisa declarar fonte, operação, prioridade, duração e condição de remoção. A ordem conceitual é:

1. valor base da família;
2. alteração fixa;
3. multiplicador aditivo agrupado;
4. multiplicador final excepcional;
5. limites mínimo e máximo.

Buffs com a mesma fonte substituem o anterior, salvo regra explícita. Interface e telemetria precisam conseguir explicar por que o valor mudou. Nenhum equipamento pode criar regeneração passiva para Contrafluxo ou remover a exaustão de uma família.

### 4.6 Conversão de técnica estrangeira

O núcleo escolhido é a única barra exibida e a única fonte de pagamento do loadout. Uma técnica de outra família não cria uma segunda barra.

- Cada técnica importável declara um custo-base estrangeiro maior que zero. Se não declarar, ela é inelegível para mistura até revisão.
- O multiplicador de Dissonância incide nesse custo estrangeiro, não em custo nativo zero.
- Geração de recurso exclusiva da família só funciona com núcleo correspondente. Fora dele, a técnica usa fallback neutro declarado e nunca converte defesa em recurso de outra família.
- Estado secundário próprio da técnica, como marca ou bobina, pode permanecer se não reproduzir a economia da família.
- Interface mostra antecipadamente custo convertido, fallback perdido e Dissonância resultante.

Exemplo: Guarda Dissipadora custa zero quando alimenta Contrafluxo nativo. Importada, usa custo-base estrangeiro 18, não gera recurso ao neutralizar e depois recebe o multiplicador de Dissonância. Isso evita uma defesa gratuita num núcleo com regeneração passiva.

## 5. Loadout

### 5.1 Estrutura

- 4 unidades de capacidade para técnicas normais.
- 1 espaço separado para ultimate.
- Técnica comum custa 1 unidade; técnica definidora custa 2.
- Orçamento total de impacto: **12**, somando técnicas e ultimate.
- Uma única ultimate.
- No máximo uma técnica normal com tag `Definidora`.
- No máximo duas técnicas do mesmo grupo de controle forte.
- Troca de loadout apenas em zona segura, ponto de descanso ou fila antes da confirmação. Nunca durante combate, perseguição ou bracket.
- Três presets são gratuitos: **PvE**, **Mundo** e **Arena**. O entitlement opcional aprovado para o soft launch pode adicionar três, respeitando o máximo absoluto de seis.
- Preset adicional só salva composição; não aumenta as quatro unidades ativas, o espaço de ultimate nem o orçamento de impacto.

“Impacto” mede o quanto uma ação comprime poder, segurança e cobertura: 1 para ferramenta estreita, 2 para ação padrão, 3 para mobilidade/controle forte, 4 para definidora e 4–6 para ultimate. Impacto não aparece como dano; é um orçamento de composição revisado por telemetria.

### 5.2 Por que dois orçamentos

Capacidade limita quantidade de botões e faz uma técnica definidora competir com variedade. Impacto impede que quatro ações de custo um sejam, silenciosamente, quatro melhores escolhas. Os dois valores ficam nos dados de cada técnica e podem ser auditados sem exceções escondidas.

O trio problemático “negação de contato + mobilidade instantânea + ultimate de grande escala” custaria, no baseline, 4 + 3 + 6 = 13 de impacto antes de preencher os demais slots; portanto é inválido sob o teto 12. Se versões futuras reduzirem esses valores, a revisão precisa justificar o contra-jogo criado.

## 6. Avaliação da Ressonância

### 6.1 Opção A — proposta original isolada

Build pura ganha pool/regen/cooldown; híbrida perde pool/regen e paga ultimate mais cara.

**Vantagens:** simples de explicar, reforça fantasia das famílias e cria incentivo claro para especialização.

**Problemas:** uma penalidade global não mede o poder da habilidade importada; uma técnica utilitária barata e uma barreira definidora seriam taxadas quase do mesmo jeito. Redução global de cooldown multiplica pressão, defesa e mobilidade ao mesmo tempo, tornando a build pura difícil de balancear. Ainda seria possível montar as três melhores ferramentas e aceitar a taxa quando a cobertura obtida valesse mais que os números perdidos.

**Conclusão:** serve como camada de identidade, mas não fecha a composição sozinha.

### 6.2 Opção B — somente orçamento de pontos/classes

Cada técnica consome capacidade e impacto; limites por tag impedem excesso de mobilidade, defesa ou controle. Não existe afinidade energética.

**Vantagens:** taxa diretamente o valor da ação, é auditável e neutraliza combinações específicas sem reduzir todos os híbridos.

**Problemas:** perde a fantasia de incompatibilidade, dá pouca razão para maestria de família e pode transformar criação de build numa planilha. Sem vantagem de consistência, a tendência é preencher cada função com a melhor técnica de qualquer origem.

**Conclusão:** resolve melhor o pico de poder, mas não sustenta sozinho a identidade pretendida.

### 6.3 Decisão — Ressonância 2.0

Combinar as duas abordagens:

1. o jogador escolhe um núcleo energético;
2. capacidade e impacto limitam o poder absoluto;
3. Dissonância mede apenas técnicas fora do núcleo;
4. build pura ganha economia modesta e passiva; não ganha redução global de cooldown;
5. técnica importada paga custo maior, e híbrido profundo perde um pouco de capacidade e regeneração;
6. tags e recargas compartilhadas tratam combinações funcionalmente redundantes.

Isso mantém a leitura “pura = sustentação; híbrida = respostas” sem garantir que uma pura vença todo duelo ou que uma híbrida tenha todas as ferramentas.

### 6.4 Cálculo reproduzível

Para um loadout, calcule primeiro `rawD`:

- `rawD` começa com a soma do custo de capacidade de cada técnica normal fora do núcleo;
- ultimate fora do núcleo acrescenta 2 a `rawD`;
- cada família estrangeira além da primeira acrescenta 1 a `rawD`;
- se `rawD > 3`, o loadout é inválido e deve ser rejeitado pelo servidor;
- somente após essa validação, `D = rawD` seleciona os modificadores da tabela.

Não se usa `min(3, rawD)`, clamp ou qualquer normalização que transforme uma composição acima do teto em válida. Cliente pode explicar o erro, mas não autoriza a build.

Modificadores:

| D | Estado | Pool | Regen | Custo nativo | Custo estrangeiro | Ultimate estrangeira | Passiva pura |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | pura | ×1,00 | ×1,10 | ×0,95 | — | — | ativa |
| 1 | híbrida leve | ×1,00 | ×1,00 | ×1,00 | ×1,15 | ×1,15 e mais ×1,10 | inativa |
| 2 | híbrida focada | ×0,95 | ×0,95 | ×1,00 | ×1,20 | ×1,20 e mais ×1,10 | inativa |
| 3 | híbrida profunda | ×0,90 | ×0,90 | ×1,00 | ×1,25 | ×1,25 e mais ×1,10 | inativa |

Cada custo final é arredondado para cima após multiplicadores. A penalidade adicional de ultimate estrangeira é multiplicativa. Exemplo: ultimate base 65 em `D = 2` custa `teto(65 × 1,20 × 1,10) = 86`.

Para técnica estrangeira, “base” sempre significa seu custo-base estrangeiro declarado conforme GDD-DEC-001, nunca um custo nativo zero.

O teto de Dissonância impede misturas sem identidade. Uma técnica estrangeira definidora usa `rawD = 2` sozinha; uma ultimate estrangeira também. Nenhum produto ou modificador pago reduz impacto, `rawD` ou Dissonância.

### 6.5 Protótipo em papel

Premissas do teste:

- capacidade normal máxima 4; impacto máximo 12;
- pool e regen usam os baselines da seção 4;
- “rotação” significa usar cada técnica normal uma vez, sem ganho por acerto;
- saldo = pool ajustado menos custo da rotação;
- reposição = custo da rotação dividido pela regen ajustada;
- os nomes abaixo são públicos e provisórios, não referências canônicas.

| Build | Núcleo e composição | Slots / impacto | D | Pool / regen | Custo da rotação | Saldo | Ultimate final | Reposição |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Pura — Rota Marcada | Fluxo Vital: 24 + 20 + 18 + 16; ultimate 60 | 4 / 12 | 0 | 120 / 4,4 s | 23 + 19 + 18 + 16 = **76** | 44 | 57 | 17,3 s |
| Pura — Cadência Umbral | Éter Umbral: 22 + 20 + 18 + 16; ultimate 55 | 4 / 12 | 0 | 100 / 2,2 s | 21 + 19 + 18 + 16 = **74** | 26 | 53 | 33,6 s |
| Pura — Bastião | Ímpeto: definidora 20 + 18 + 16; ultimate 65 | 4 / 12 | 0 | 110 / 3,3 s | 19 + 18 + 16 = **53** | 57 | 62 | 16,1 s |
| Híbrida — Nó Sombrio | núcleo Fluxo Vital; nativas 20 + 18 + 16, estrangeira Umbral 24; ultimate nativa 60 | 4 / 12 | 1 | 120 / 4,0 s | 20 + 18 + 16 + 28 = **82** | 38 | 60 | 20,5 s |
| Híbrida — Pacto de Cerco | núcleo Éter Umbral; quatro nativas 22 + 20 + 18 + 16; ultimate estrangeira Ímpeto 65 | 4 / 12 | 2 | 95 / 1,9 s | **76** | 19 | 86 | 40,0 s |
| Híbrida — Três Horizontes | núcleo Ímpeto; definidora nativa 30, estrangeira Fluxo 18, estrangeira Umbral 20; ultimate nativa 65 | 4 / 12 | 3 | 99 / 2,7 s | 30 + 23 + 25 = **78** | 21 | 65 | 28,9 s |

Leitura do protótipo:

- todas as híbridas executam uma rotação funcional a partir do pool cheio;
- a híbrida leve perde 18,5% de eficiência de reposição frente à pura de Fluxo, em troca de uma resposta Umbral;
- a ultimate estrangeira continua utilizável, mas consome 90,5% do pool cheio do Pacto de Cerco;
- a mistura de três famílias quase dobra o tempo de reposição frente ao Bastião puro e, portanto, não sustenta pressão contínua;
- orçamento de impacto continua sendo necessário: Dissonância mede compatibilidade, não substitui o valor intrínseco das ações.

Critério de teste: em confrontos de habilidade equivalente, builds híbridas devem permanecer entre 48% e 52% de vitória agregada, sem exceder simultaneamente builds puras em presença e vitória. Se híbridas ficarem abaixo de 45%, reduzir primeiro a taxa de custo estrangeiro; se dominarem, revisar impacto/tags da combinação antes de aumentar toda penalidade.

## 7. Progressão

### 7.1 Progressão geral

O jogador ganha experiência geral por missão, exploração, evento, boss e objetivo PvP. Eliminar repetidamente o mesmo alvo, inimigo trivial ou parceiro combinado tem retorno decrescente.

Progressão geral abre regiões, receitas, capacidade social e cadeias de descoberta. Ela não adiciona dano infinito. O estado funcional esperado é:

- primeiro combate em até 60 segundos;
- objetivo de progressão visível em até 3 minutos;
- primeira técnica permanente em até 5 minutos;
- primeiro breakpoint comportamental em 15–20 minutos;
- três técnicas iniciais em 45–60 minutos;
- primeira ultimate e build pura em 8–10 horas;
- alternativa híbrida funcional em 16–20 horas.

Esses tempos são metas de onboarding e baselines de playtest, não promessas comerciais. A política permanente é entregar combate funcional imediatamente e fazer progressão mudar comportamento antes de acumular poder bruto.

### 7.2 Maestria de técnica

Cada técnica possui níveis 1–10. XP para passar do nível `n` ao `n + 1` é:

**100 + 50n + 25n²**, para `n` de 1 a 9.

| Próximo nível | XP | Acumulado |
|---:|---:|---:|
| 2 | 175 | 175 |
| 3 | 300 | 475 |
| 4 | 475 | 950 |
| 5 | 700 | 1.650 |
| 6 | 975 | 2.625 |
| 7 | 1.300 | 3.925 |
| 8 | 1.675 | 5.600 |
| 9 | 2.100 | 7.700 |
| 10 | 2.575 | 10.275 |

Com rendimento alvo de 35–50 XP válidos por minuto, uma técnica chega ao nível 10 em aproximadamente 3,4–4,9 h de uso significativo. “Uso significativo” é acerto, defesa, mobilidade que evita dano, contribuição em objetivo ou resolução de encontro; apertar a técnica no vazio não rende XP. Há teto por alvo e encontro contra farm automático. Itens de treino podem fornecer no máximo 40% do requisito de um nível; jogo real permanece obrigatório.

Breakpoints:

| Nível | Recompensa |
|---:|---|
| 1 | comportamento base completo e competitivo |
| 3 | propriedade contextual, como segundo dash condicionado a acerto/esquiva |
| 6 | escolha entre duas variantes laterais; nunca ambas |
| 9 | interação de maestria que aumenta expressão, não cobertura universal |
| 10 | efeito, título e ajuste de qualidade de vida; sem novo pico de dano |

Níveis 2, 5 e 8 podem conceder até 2% de eficiência cada, com teto total de 6% e sem empilhar dano, cooldown e recurso na mesma técnica. Toda variante comportamental inclui contra-jogo e custo atualizado.

### 7.3 Maestria de família

- 20 níveis por família.
- XP por próximo nível `n`: **500 + 100n**, de `n = 0` a `19`; total 29.000.
- Build pura recebe 1,25× XP de família.
- Build híbrida divide a XP proporcionalmente ao recurso efetivamente gasto por origem; não duplica XP.
- Benefícios: acesso a instrutores, receitas, cosméticos e redução de 2% no custo de materiais de desbloqueio a cada 5 níveis, máximo 8%.
- Não concede dano, vida ou regen direta.

O baseline de conclusão da família é **18–24 horas** para uma build pura e **24–32 horas** para uma híbrida. Essa meta mede uso significativo e pode ser recalibrada sem mudar a estrutura de 20 níveis.

Isso incentiva especialização sem tornar a família já dominada objetivamente mais forte no duelo.

### 7.4 Respec e edição de build

- Trocar técnicas desbloqueadas e presets é gratuito em zona segura.
- Respec altera a escolha comportamental do nível 6; nível e XP da técnica são preservados.
- Primeira troca de cada técnica é gratuita e há uma janela de teste de 30 min após escolher uma variante.
- Depois disso, custo em moeda: **500 + 150 × nível da técnica + 250 × respecs feitos nos últimos 7 dias**, máximo 3.000.
- Há cooldown de 5 minutos entre respecs pagos com Marcas.
- Respec é bloqueado em combate, perseguição, arena, guerra ou fila confirmada.

O jogador nunca perde técnica, maestria ou equipamento ao corrigir uma build. A taxa impede troca a cada duelo, não pune experimentação legítima.

## 8. Equipamento

### 8.1 Direção escolhida

Adotar **modificadores de habilidade com uma pitada mínima de status**, e não progressão centrada em ATK/DEF.

Cada item deve responder “como meu estilo muda?”. Exemplos de sidegrade:

- dash deixa um rastro que causa 4 de dano, mas sua recarga sobe 20%;
- barreira devolve 20% do dano mitigado como desgaste de guarda, mas perde 25% de durabilidade;
- técnica de avanço ganha curva manual, mas perde magnetismo de alvo;
- cura atua em área pequena, mas cura o usuário 30% menos.

Cada item concede no máximo **2%** de bônus bruto. O conjunto dos três slots é limitado a **5 pontos percentuais positivos**, e um mesmo atributo não pode receber mais de **3%**. Nenhum item aumenta simultaneamente ataque e sobrevivência, mesmo com desvantagem declarada. No ranqueado e no torneio, bônus brutos são removidos e modificadores comportamentais são normalizados ao grau 3.

### 8.2 Slots e raridade

- 3 slots: **Condutor**, **Guarda** e **Relíquia**.
- No máximo um modificador equipado por técnica.
- Raridade indica complexidade e dificuldade de obtenção, não vitória automática: Comum, Refinado, Raro, Relicário.
- Um Relicário pode mudar mais o comportamento, mas carrega desvantagem equivalente e maior custo de impacto quando aplicável.
- Item equipado fica vinculado; materiais e projetos não usados podem ser negociáveis.

### 8.3 Fontes

| Fonte | Recompensa principal | Proteção contra grind |
|---|---|---|
| missão/cadeia | projeto previsível e material comum | progresso determinístico |
| elite e evento | material de refinamento | teto diário suave, não bloqueio total |
| boss de mundo | projeto temático e material raro | ficha de participação acumulável |
| forja | escolha de modificador e conversão de duplicatas | receita conhecida, sem resultado secreto |
| torneio | material e aparência de prestígio | nunca item de poder exclusivo |

### 8.4 Forja determinística

Há cinco graus de refinamento. Cada operação válida sempre conclui o grau escolhido; não existe rolagem de sucesso, destruição, rebaixamento, perda parcial nem pity de forja.

| Grau | Potência do modificador | Custo relativo |
|---:|---:|---:|
| 1 | 60% | 1 |
| 2 | 70% | 2 |
| 3 | 80% | 3 |
| 4 | 90% | 5 |
| 5 | 100% | 8 |

A desvantagem do modificador acompanha sua potência planejada. Uma falha técnica ou transacional não consome Marcas nem materiais; retry idempotente retorna o mesmo recibo. Pity existe somente no loot pessoal de bosses. No ranqueado e no torneio, todos os modificadores comportamentais são normalizados ao grau 3; a escolha continua relevante, o investimento não decide a luta.

### 8.5 Troca e economia

Para reduzir scam e inflação:

- somente materiais e projetos ainda não vinculados serão negociáveis **quando o mercado em custódia for liberado na F7**; antes disso, não há troca entre contas;
- troca usa custódia atômica, duas confirmações e tela final com nome, quantidade, raridade e vínculo;
- item alterado reinicia a confirmação; não existe drop no chão;
- histórico, identificador único, limites de valor/volume e cooldown de conta nova sustentam investigação;
- taxa de mercado, forja, respec e conversão de duplicata retiram moeda da economia;
- preço mediano e faixa recente aparecem na interface; mensagens não prometem “valor futuro”;
- kill trading, contas relacionadas e transferência circular alimentam revisão antiabuso.

O mercado só pode ser habilitado após **30 dias sem dupe crítico**, retries e reconexões reconciliados e menos de **0,1%** das operações exigindo reparo manual. Comércio de item equipado só deve ser reconsiderado depois de a F7 e o suporte provarem rastreabilidade. Equipamento nunca cai na morte.

## 9. Relação entre mundo aberto e competitivo

- Mundo aberto usa progressão construída, dentro de faixas de nível e proteção contra diferença extrema.
- Arena casual usa loadout e equipamento do jogador para validar a fantasia de construção.
- Ranqueado e torneio normalizam HP, dano, guarda, recurso, ganhos numéricos de nível e refinamento; removem bônus brutos; preservam técnicas desbloqueadas, loadout, Dissonância e variantes comportamentais legais.
- Modificadores comportamentais legais são normalizados ao grau 3. Dois loadouts de empréstimo versionados permitem entrada competitiva sem desbloquear conteúdo no mundo.
- Ultimate, tags, orçamento de impacto e Dissonância permanecem iguais nos três contextos.
- Ajuste exclusivo por modo é último recurso e precisa aparecer na descrição da técnica; regras invisíveis quebram aprendizado.

## 10. Monetização — produtos aprovados para o soft launch

| Oferta inicial | Regra | Risco e mitigação |
|---|---|---|
| cosméticos e skins de compra direta | silhueta e telegraph funcionais preservados | revisão de legibilidade e propriedade intelectual |
| emotes e finalizadores | não alteram duração, hitbox ou leitura da ação | versão funcional padrão permanece igualmente legível |
| pacote de três presets | eleva presets salvos de 3 para no máximo 6; capacidade ativa continua 4 + ultimate | texto nunca chama de “slot de habilidade” |
| servidor privado de treino | sem progresso, recompensa, drop, MMR ou economia | estado de treino nunca é persistido como ganho |

Itens proibidos:

- personagem, técnica, ultimate ou variante exclusiva paga;
- recurso, dano, vida, guarda, cooldown, slot ativo ou orçamento de impacto;
- material de upgrade competitivo, redução paga de custo da forja ou chance de drop;
- reputação, MMR, remoção de bounty ou recuperação de penalidade;
- loot box de poder ou vantagem temporária em PvP.

Boost, respec pago, expansão funcional de inventário, moeda, gacha e material ficam fora do soft launch. Qualquer aleatoriedade paga futura exigiria odds reais, verificação de política por jogador e uma nova decisão formal; não faz parte da direção atual.

O plano de monetização só avança após a fatia vertical demonstrar retenção sem compra, combate justo e persistência confiável.

## 11. Telemetria e critérios de balanceamento

Registrar por técnica, família, build, faixa de nível, plataforma e contexto:

- escolha, abandono, taxa de acerto e dano confirmado;
- recurso gasto, devolvido e desperdiçado;
- tempo segurando cooldown pronto;
- início e quebra de combo;
- vitória, sobrevivência e contribuição de objetivo;
- combinação de técnicas e impacto total;
- Dissonância, tempo de reposição e ultimate usada;
- método de entrada, FPS e latência em faixas, sem dado pessoal desnecessário.

Gatilhos de revisão:

- presença acima de 35% e vitória acima de 53% por amostra confiável;
- técnica acima de 70% entre builds elegíveis;
- ultimate decide mais de 25% das lutas em que é usada sem resposta defensiva;
- plataforma com diferença de vitória acima de 3 pontos percentuais após controlar experiência;
- equipamento específico torna-se escolha obrigatória acima de 60%.

Primeiro se revisa telegraph, tag, impacto, custo e contra-jogo. Dano é o último ajuste quando o problema real for cobertura ou segurança.

## 12. Critérios de pronto de design

Um sistema desta GDD está pronto para implementação somente quando:

- todos os números necessários estão nos dados planejados, sem exceção silenciosa;
- cliente e servidor têm responsabilidades inequívocas;
- PC, mobile e console possuem entrada e interface testáveis;
- existe contra-jogo descrito para cada técnica dominante;
- progressão informa tempo esperado e proteção anti-farm;
- monetização não altera o resultado competitivo;
- nomes, silhuetas, VFX, áudio e narrativa passam por revisão de originalidade;
- um teste em papel reproduzível antecede teste em jogo.

## 13. Baselines que exigem playtest

Não bloqueiam o planejamento, mas não devem virar verdade permanente sem teste:

- multiplicadores de pool, regeneração e custo associados a `D = 0–3`;
- bônus puro de 10% de regen e 5% de economia;
- TTK de 12–18 s;
- magnetismo de 8°;
- curva de 3,4–4,9 h para maestria completa de uma técnica;
- normalização de equipamento no grau 3;
- curva de custo relativo 1/2/3/5/8 da forja.

Os limites estruturais — quatro unidades, uma ultimate, impacto 12, `rawD <= 3`, três slots, caps de 2%/5 pontos/3%, forja determinística e três/seis presets — são políticas aprovadas. Seus números de balanceamento podem ser revistos formalmente após playtest, mas não são alternativas abertas. Cada baseline deve ter teste isolado, amostra por plataforma e decisão registrada antes de expansão de conteúdo.

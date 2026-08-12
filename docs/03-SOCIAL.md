# 03 — PvP social, reputação, clãs e competitivo

## 1. Contrato deste documento

Este documento define regras sociais e competitivas em nível de produto. Não contém implementação. Políticas marcadas como aprovadas são vinculantes para o planejamento; percentuais, tempos e limiares operacionais são **baselines de teste** e só mudam por decisão registrada com evidência.

Objetivos:

- permitir PvP de mundo aberto sem transformar jogador novo em conteúdo descartável;
- dar consequência à agressão sem apagar progresso permanente;
- criar pertencimento por clãs sem entregar poder cumulativo a uma oligarquia;
- medir habilidade em arena preservando a identidade de build;
- tratar reconexão, desistência, conluio e assédio como parte do design, não como exceções posteriores;
- manter todo conteúdo público original, sem nomes, franquias, técnicas, emblemas ou imagens protegidas.

Reputação ajuda a deter veteranos que caçam iniciantes, mas **não resolve isso sozinha**. Parte dos ofensores valorizará o status de fora da lei. O sistema precisa combinar proteção de novato, supressão de recompensa, segurança de spawn, reputação, guardas, bounty e detecção de repetição.

## 2. Contextos de PvP

As regras não podem vazar de um contexto para outro.

| Contexto | Poder usado | Perda de mundo | Reputação | Resultado competitivo |
|---|---|---|---|---|
| Mundo — zona livre | progressão própria | sim, limitada | sim | estatística de mundo/bounty |
| Mundo — alto risco | progressão própria | sim, aumentada e limitada | sim | estatística de mundo/território |
| Duelo casual | build própria | não | não | histórico casual, sem MMR principal |
| Arena ranqueada | loadout próprio com números normalizados | não | não | MMR sazonal |
| Torneio oficial | regra ranqueada normalizada | não | não | pontos de torneio e colocação |
| Evento de clã 8v8 | loadout próprio com teto de poder | não | não | classificação de clã |
| Guerra territorial pós-lançamento | loadout próprio com teto de poder de guerra | não | não | classificação de clã |

Separar reputação de MMR é deliberado: reputação mede conduta no mundo; MMR mede desempenho em regras competitivas. Um grande caçador de bounty não recebe rating de arena, e um jogador procurado não recebe bônus nem penalidade de MMR.

## 3. Proteção de novato

### 3.1 Regra aprovada

Na região inicial, proteção permanece até o jogador concluir o onboarding **e** acumular pelo menos 30 minutos ativos; ela expira automaticamente com 90 minutos ativos ou ao entrar voluntariamente em alto risco. Os tempos serão calibrados por testes.

Enquanto protegida, a pessoa:

- não causa nem recebe dano PvP de jogadores não protegidos no corredor inicial;
- não pode coletar recompensa de alto risco, bounty ou guerra;
- vê claramente quando e por que a proteção termina;
- pode optar por encerrá-la, com confirmação, de forma permanente para aquele perfil;
- não perde a proteção do mundo por participar de arena isolada.

Tentar iniciar ação hostil abre a confirmação de saída. A ação só ocorre após confirmar; isso evita tanto agressão invulnerável quanto perda acidental da proteção.

Depois da proteção, ataques iniciados contra alguém muito abaixo em poder efetivo geram punição forte, salvo autodefesa, bounty, duelo aceito, guerra válida ou evento formal.

### 3.2 Poder efetivo

O servidor deriva um score de **0 a 100**; o cliente nunca envia nem persiste um valor autoritativo. A composição aprovada é:

| Componente normalizado | Peso |
|---|---:|
| progressão da zona | 30% |
| completude do loadout | 25% |
| maestria | 20% |
| equipamento | 15% |
| desempenho PvP com incerteza | 10% |

Ao avaliar agressão em grupo, o lado agressor recebe até **30 pontos adicionais** conforme superioridade numérica e coordenação recente. Um alvo é “muito abaixo” quando a diferença ajustada é de pelo menos **25 pontos** e o agressor possui pelo menos **1,35×** seu poder efetivo. Nível bruto isolado não autoriza a classificação. Pesos, bônus de grupo e limiares são baselines iniciais; a política permanente é derivação server-side, explicável e resistente a manipulação.

### 3.3 Trade-off

Proteção absoluta reduz a fantasia de mundo totalmente livre e pode ser explorada para observação segura. Por isso ela vale apenas no corredor inicial, impede interação com recompensas contestadas e possui expiração. A alternativa — só reputação — é mais aberta, porém não impede o primeiro abuso e tende a perder jogadores antes de a punição alcançar o agressor.

## 4. Reputação e lei

### 4.1 Escala aprovada

Reputação varia de **-1.000 a +1.000** e começa em 0. As faixas são públicas; a fórmula exata de cada evento pode ser ajustada sem renomeá-las.

A reputação acompanha persistentemente o perfil da conta dentro da experiência e é compartilhada entre estilos e loadouts. Trocar build não limpa consequência. O score público permanece entre -1.000 e +1.000; estado recente pode decair, enquanto o histórico privado do servidor sustenta antiabuso e investigação.

| Pontuação | Estado | Consequência |
|---:|---|---|
| +300 a +1.000 | Honrado | até 5% de desconto, missão de prestígio e cosmético de status |
| +100 a +299 | Respeitado | pequena melhoria de serviço e acesso a contratos cívicos |
| -99 a +99 | Neutro | regras normais |
| -100 a -299 | Suspeito | guardas alertas, serviços sem desconto e aviso público discreto |
| -300 a -699 | Fora da lei | guardas hostis, mercado principal bloqueado e bounty ativo |
| -700 a -1.000 | Procurado | bounty maior, rastreamento regional e recuperação mais longa |

O desconto máximo é pequeno para não transformar boa reputação em vantagem econômica acumulativa. Cosméticos e acesso social devem carregar mais valor que poder.

### 4.2 Eventos de reputação

| Ação | Efeito inicial (baseline) | Observação |
|---|---:|---|
| Matar alvo não hostil duas ou mais faixas abaixo | -120 a -250 | cresce com diferença de poder e reincidência |
| Matar repetidamente a mesma vítima | perda duplicada, depois sem recompensa | janela inicial de 30 min |
| Atacar e matar alvo comparável não hostil | perda pequena a média | PvP continua permitido, mas tem consequência |
| Autodefesa contra primeiro agressor | sem perda | autoria do combate é decidida pelo servidor |
| Cumprir bounty legítimo | +10 a +30 | limitado por dia e relação entre contas |
| Concluir restituição | +20 a +40 | tarefa ativa, não comprável |
| Proteger evento cívico | ganho pequeno | retorno decrescente em conteúdo trivial |

Ataque inicial, dano relevante, cura deliberada do agressor e participação de grupo compõem autoria. Pequeno dano acidental não deve transformar a vítima em agressora. Empurrão para ambiente e último golpe de NPC preservam atribuição PvP recente.

### 4.3 Recuperação

- Nenhum produto pago, passe ou Robux recupera reputação.
- Tempo limpo só conta com atividade válida e recupera lentamente até o limite “Suspeito”; ficar AFK não basta.
- Restituição exige contratos de serviço, entrega de recursos obtidos em jogo e períodos sem nova infração.
- Ganho diário tem teto. Uma queda profunda exige mais de uma sessão para recuperar.
- Morrer para caçador não zera a dívida; reduz apenas uma pequena parcela para evitar ciclos infinitos.
- Reputação positiva alta sofre leve retorno ao centro ao longo de temporadas, impedindo vantagem eterna de veterano.

O acampamento neutro descrito em `02-WORLD.md` mantém banco pessoal e recuperação acessíveis a infratores sem neutralizar a consequência do mercado bloqueado.

## 5. Bounty

### 5.1 Criação e caça

- Bounty ativa ao chegar a “Fora da lei” e cresce com reputação negativa, vítimas distintas e diferença de poder.
- Valor é limitado por sessão e por dia; não corresponde ao patrimônio do alvo.
- Caçadores recebem uma área aproximada atualizada em intervalos, nunca posição exata em tempo real.
- Grupo divide a recompensa por contribuição válida.
- A recompensa vem de um fundo sistêmico controlado e é um faucet medido na economia.
- Morte do alvo reduz bounty e inicia uma curta proteção contra nova cobrança, mas não restaura reputação por completo.

### 5.2 Elegibilidade e abuso

Não há pagamento quando caçador e alvo:

- pertencem ao mesmo clã ou pertenceram recentemente;
- repetem o mesmo par acima do limite da janela;
- realizaram transferência econômica relevante recente;
- apresentam padrão coordenado de dano, cura, desistência ou troca de servidor;
- não alcançam contribuição mínima real.

Uma única relação social não prova fraude. Sinais combinados podem reter a recompensa para análise, retirar ganho e impor espera; punição de conta exige evidência adicional.

O leaderboard de bounty deve classificar **bounties legítimos capturados**, não premiar “quem mais atacou novatos”. Se também for exibida uma lista de procurados, ela não concede prêmio sazonal.

## 6. Morte, respawn e desconexão no mundo

### 6.1 Penalidade aprovada como baseline operacional

| Contexto | XP não consolidado | Material comum elegível | Respawn | Equipamento/moeda/progresso permanente |
|---|---:|---:|---:|---|
| Zona segura/treino | 0% | 0% | imediato no ponto seguro | nunca perdido |
| Zona livre por PvE | 10% | 0% | 8 s | nunca perdido |
| Zona livre por PvP | 15% | 5% | 8 s | nunca perdido |
| Alto risco | 30% | 15% | 12 s | nunca perdido |
| Arena, torneio ou guerra | 0% | 0% | regra da partida | nunca perdido |

Perdas de XP são limitadas ao equivalente aproximado de 5 minutos de ganho mediano em zona livre e 10 minutos em alto risco. Só entram materiais comuns, negociáveis e obtidos naquela expedição; Catalisadores, itens de missão, cosméticos, itens pagos e recursos vinculados não entram.

Na primeira versão, materiais perdidos são removidos da economia, não entregues ao assassino. Isso torna a morte um sumidouro e reduz kill trading. Um cache contestável pode ser testado depois em alto risco, mas não deve entrar antes de auditoria de conluio.

Justificativa: perder equipamento destrói retenção e desencoraja experimentar builds. Perder uma porção limitada da expedição cria tensão recuperável. Timer crescente é usado apenas contra cadeia de mortes, não como punição longa.

### 6.2 Repetição e atribuição

- Mortes adicionais em 10 minutos elevam respawn para 12, 16 e no máximo 20 segundos; depois a série expira.
- O mesmo agressor deixa de receber qualquer ganho pela mesma vítima antes de a vítima completar atividade relevante ou a janela expirar.
- Morte por ambiente mantém crédito do agressor que causou deslocamento ou dano relevante recentemente.
- Suicídio, reset e NPC não removem marca de combate nem evitam penalidade correspondente.
- Spawn concede até 10 segundos de proteção, encerrada ao atacar ou deixar o raio.
- Um ponto excessivamente acampado oferece saída alternativa; o problema também entra na fila de correção de mapa.

### 6.3 Combat logging

- Em queda de cliente durante combate, o avatar permanece no mundo por até 15 segundos sob autoridade do servidor.
- Reconectar dentro de 60 segundos retoma o estado válido se o avatar sobreviver.
- Se o avatar morrer, a penalidade normal é aplicada uma vez.
- Falha confirmada do servidor ou da plataforma cancela a penalidade de morte; não restaura uma cópia concorrente do inventário.
- Trocar de servidor durante marca de combate não consolida XP nem recursos.

Os valores precisam ser testados em conexões móveis reais. Desconexão isolada não gera sanção disciplinar; padrão repetido gera espera para reentrada em zona de alto risco.

## 7. Clãs e guildas

### 7.1 Uma entidade, não duas

“Clã” e “guilda” representam o mesmo sistema. Criar duas entidades dividiria chat, banco, guerra e progressão sem benefício claro. O nome público aprovado é **Clã**.

Criação exige:

- onboarding concluído;
- reputação Neutra ou melhor;
- conta com tempo mínimo de existência a calibrar;
- custo em Marcas equivalente a algumas sessões intermediárias, não a dezenas de horas;
- nome e tag aprovados pelo filtro da plataforma.

Capacidade inicial: **20 membros**, crescendo até **40** por progressão de clã. Aumento de membros por Robux é proibido porque altera capacidade de evento e geração econômica.

### 7.2 Cargos e permissões

| Cargo padrão | Capacidades iniciais |
|---|---|
| Líder | propriedade, matriz de permissões, eventos e dissolução protegida |
| Oficial | capacidades granulares delegadas, como moderação, convite e gastos predeterminados |
| Membro | chat, contribuição e participação |

Permissões são granulares; título não concede poder implícito fora da matriz. Transferência de liderança espera **72 horas** e pode ser cancelada; dissolução espera **7 dias** com confirmação reforçada; gasto superior a **25% dos Suprimentos** espera **24 horas** e permanece visível no log.

### 7.3 Banco e auditoria

- Na Fase 5, aceita somente Suprimentos e materiais de clã vinculados; não aceita Marcas, bens pessoais ou itens negociáveis.
- Depósitos são imediatos e registrados.
- Na F5, gastos predeterminados têm limite por permissão, por dia e por categoria; não são saques livres.
- Uma versão futura com tesouraria avançada exige duas aprovações para operação de alto valor.
- Nessa versão futura, convite recente, promoção recente e saída programada reduzem temporariamente o limite de saque.
- Histórico mostra ator, item, quantidade, antes/depois e motivo por pelo menos uma temporada.
- Não existe “desfazer” silencioso; recuperação administrativa cria uma transação compensatória auditável.

Na Fase 5, não há saque livre: contribuições alimentam Suprimentos vinculados ao clã e gastos predeterminados. Banco livre de itens e saques avançados são subprojetos opcionais pós-lançamento e dependem de auditoria, suporte e recuperação comprovados.

### 7.4 Progressão e perks

Clã ganha renome por participação distinta em missões coletivas, guerras e eventos. Repetir o mesmo conteúdo trivial ou alimentar alts tem retorno decrescente e teto por membro.

Perks aprovados para planejamento:

- capacidade, cargos e opções de emblema;
- decoração e salão;
- contratos cooperativos;
- logística, como ponto de reunião fora de combate;
- bônus pequeno e limitado de recurso PvE;
- cosméticos e efeitos de celebração.

Perks não aumentam dano, defesa, cooldown ou recurso em arena ranqueada. Buff de mundo não excede um teto pequeno e não se acumula com território sem limite.

### 7.5 Convite, saída e chat

- Convite expira, tem limite e respeita “não receber convites”.
- Bloquear alguém bloqueia convite direto dessa conta.
- Sair é imediato fora de guerra, mas elegibilidade territorial em outro clã espera 24–72 horas.
- Expulsão durante janela de guerra não remove obrigação já registrada nem rouba recompensa conquistada.
- Chat usa filtragem nativa da plataforma; não há transporte de texto bruto nem link externo.
- Nome, tag e descrição são filtrados na criação e em toda edição.

## 8. Evento de clã e território pós-lançamento

### 8.1 Gate obrigatório de território

Território fica fora do lançamento. Só pode avançar depois de **quatro semanas de eventos de clã estáveis** e quando, simultaneamente, houver:

- pelo menos 20 clãs elegíveis e 200 participantes semanais;
- pelo menos 80% dos eventos formando no mínimo 6v6;
- no-show abaixo de 10%;
- teleporte bem-sucedido acima de 99%;
- 30 dias sem incidente econômico crítico.

Cumprir o gate autoriza desenvolvimento e teste controlado, não lançamento automático. Para impedir bola de neve no corte futuro:

- proprietário recebe Suprimentos de clã e até 5% de ganho extra de material comum na região, com teto diário;
- território nunca concede item raro, chance rara adicional ou poder exclusivo;
- nenhum bônus territorial funciona em arena ranqueada;
- cada clã controla no máximo um território no primeiro corte pós-lançamento;
- território volta a ser disputável e sofre reset sazonal.

Isso mantém motivo econômico e prestígio sem transformar derrota em exclusão permanente.

### 8.2 Evento inicial e fluxo territorial futuro

O primeiro evento de clã é **8v8 por objetivos**, sem posse persistente. O baseline é até 5 reservas, partida de 20 minutos, três objetivos de mapa e pontuação por captura/manutenção. Mortes ajudam a abrir espaço, mas não são o placar principal. Esse formato valida população, matchmaking, teleporte e clareza antes de qualquer território.

Somente depois do gate da seção 8.1, o fluxo territorial planejado é:

1. clã elegível paga Suprimentos para declarar;
2. sistema oferece três janelas regionais dentro dos próximos dias;
3. defensor escolhe uma; ausência de escolha usa a janela intermediária publicada;
4. roster e reservas são travados antes da partida;
5. servidor reservado recebe os dois lados e valida participantes;
6. resultado atualiza território e inicia período curto de proteção.

Não existe captura offline. Um defensor não pode adiar indefinidamente, e um atacante não pode escolher madrugada local como surpresa.

Esse fluxo completo pertence à Fase 7 opcional e pós-lançamento. Na Fase 5, não há declaração, posse persistente, bônus regional ou banco livre. Tamanho maior que 8v8 fica para depois de desempenho, matchmaking e clareza visual comprovarem capacidade.

### 8.3 Elegibilidade e equilíbrio

- clã precisa de idade mínima, membros ativos distintos e reputação coletiva aceitável;
- novo membro espera antes de guerra territorial, impedindo contratação relâmpago;
- loadouts permanecem próprios, mas atributos numéricos respeitam teto sazonal de guerra;
- itens pagos não alteram orçamento de combate;
- abandono deliberado, alimentação de placar e acordo de resultado anulam recompensa;
- clã em desvantagem recebe opção de objetivo defensivo e recuperação logística, não dano artificial;
- uma semana de proteção após captura é baseline inicial para evitar guerra diária e exaustão.

Alianças formais, tributo, empréstimo entre clãs e múltiplos territórios ficam fora da primeira versão. São sistemas políticos e econômicos grandes o bastante para uma fase própria.

## 9. Torneios

### 9.1 Cadência

Durante a pré-temporada Brasil-first, há três janelas semanais em horário de Brasília: **quarta às 20h, sábado às 15h e sábado às 21h**. A UI converte sempre para o horário local e mostra contagem regressiva.

- O torneio oficial exige e limita a **8 participantes**.
- Check-in abre 10 minutos antes e fecha 2 minutos antes do início.
- Com menos de 8 confirmados, o torneio oficial é cancelado e os presentes recebem opção de evento casual sem MMR; bots nunca completam o bracket.
- Expandir para 16 exige quatro semanas com pelo menos 80% dos brackets completos e no-show abaixo de 10%.

Cadência maior depende de população e operação comprovadas; torneio a cada duas horas não é meta de lançamento.

### 9.2 Normalização aprovada

- **duelo casual:** usa loadout, maestria e equipamento construídos no mundo;
- **ranqueado e torneio oficial:** normalizam HP, dano, guarda, recurso, ganhos numéricos de nível e refinamento; removem atributos brutos; preservam habilidades desbloqueadas, loadout, Dissonância e variantes comportamentais legais;
- modificadores comportamentais têm custo competitivo e lista de legalidade; efeito impossível de equilibrar pode ficar fora da temporada;
- modificadores comportamentais legais são normalizados ao grau 3;
- dois loadouts de empréstimo versionados permitem experimentar o modo, mas não concedem desbloqueio no mundo.

Normalizar tudo apagaria o produto de progressão; não normalizar nada transformaria ranking em inventário. A regra aprovada preserva identidade e fecha a maior diferença de poder.

### 9.3 Bracket e partida

- Primeira versão: 1v1, eliminação simples, exatamente 8 participantes e semente por faixa de MMR.
- Jogadores do mesmo clã são separados nas primeiras rodadas quando possível, sem adulterar a semente inteira.
- Bye não conta como vitória jogada nem gera recompensa de atividade.
- Cada confronto usa melhor de três rounds de **90 segundos**; empate vai para objetivo de desempate, não dano total bruto.
- Arena dedicada é simétrica, sem vantagem de spawn e com limites visíveis.
- Espectador tem atraso de 15 segundos e chat separado para reduzir coaching.
- Não há aposta, bolsa de prêmio financiada por jogadores nem troca no servidor de arena.

Premiação de torneio é cosmética e de prestígio. Participação só premia após atividade mínima; poder, item negociável e melhoria paga não entram.

## 10. Matchmaking e ranking

### 10.1 Filas

Há uma fila ranqueada 1v1 por região. Casual ocorre por desafio direto; fila de equipe fica fora da primeira temporada. Torneio é evento agendado, usa rating para seeding e não cria outra fila contínua.

Primeira busca considera região de baixa latência, MMR e preferência de entrada. A faixa de MMR expande com o tempo; preferência de teclado/controle/toque pode relaxar antes do limite de latência. O jogador é avisado e pode cancelar, nunca é forçado a uma partida claramente inviável.

Hipótese de expansão:

| Tempo de fila | Faixa de rating | Outras regras |
|---:|---:|---|
| 0–30 s | ±100 | mesma região e preferência de entrada |
| 30–90 s | ±200 | mistura de entrada permitida |
| 90–180 s | ±350 | regiões adjacentes somente se latência aceitável |
| acima de 180 s | escolha do jogador | continuar, migrar para casual ou sair sem punição |

Evitar o mesmo oponente em sequência e o mesmo clã quando houver alternativa. Não usar nível do mundo para matchmaking normalizado. Fila de equipe fica fora da primeira temporada.

### 10.2 Rating

O rating aprovado é **Glicko-2**, com rating inicial **1.500**, RD **350**, volatilidade **0,06**, `tau` **0,5** e **10 partidas de colocação**. Ele trata conta nova, pouca amostra e retorno após inatividade melhor que Elo puro. O rating permanece interno; divisão e progresso são a representação pública.

Contrato aprovado:

- rating e incerteza independentes por modo e temporada;
- divisão provisória durante as 10 colocações;
- divisões: Bronze `<1200`, Prata `1200–1399`, Ouro `1400–1599`, Platina `1600–1799`, Diamante `1800–1999`, Ascendente `2000–2199` e Lenda `≥2200`;
- topo exige mínimo de partidas válidas e baixa incerteza;
- UI mostra divisão, progresso e motivo das mudanças; parâmetros antifraude internos não são expostos.

### 10.3 Leaderboards separados

| Quadro | Métrica | Reset |
|---|---|---|
| Ranqueado individual | rating com requisito de atividade | sazonal |
| Torneio | melhores colocações/pontos, com limite de resultados contados | sazonal |
| Clã | guerra, território e objetivos normalizados por atividade | sazonal |
| Bounty | valor legítimo capturado por caçadores | sazonal |

Contar apenas os melhores resultados de torneio por semana evita que volume de horários vença habilidade. Leaderboard de clã não pode ser soma bruta ilimitada de membros; deve normalizar por guerra e adversário.

Atualização pública pode ocorrer em lotes a cada poucos minutos. Não gastar orçamento persistente para aparência de tempo real. Resultado da partida é gravado antes da projeção do leaderboard.

## 11. Temporadas

A pré-temporada dura **4 semanas** e as temporadas regulares duram **8 semanas**.

- MMR sofre compressão de 25% em direção ao centro, não reset total.
- Recompensa de divisão usa a maior divisão alcançada e exige pelo menos **20 partidas válidas** e conduta elegível.
- Recompensas são banner, cores, aura/finalização legível e títulos; Top 100 recebe título numerado. Nunca incluem poder ou item negociável.
- Após 14 dias sem jogar, apenas faixas altas começam a perder posição visível; incerteza sobe para todos.
- Decaimento tem teto de uma divisão por semana e não empurra jogador casual indefinidamente para baixo.
- Mudança grande de balanceamento entra entre temporadas. Correção de exploit pode entrar imediatamente com comunicação e, se necessário, congelamento de rating.
- Territórios são neutralizados ou comprimidos no fim da temporada; campeão mantém registro e cosmético, não domínio permanente.
- Histórico preserva temporada, divisão de pico, rating final e sanções que afetaram elegibilidade.

### 11.1 Operação Brasil-first

O acesso técnico é global, mas o soft launch tem suporte e agenda operacional focados no Brasil. PT-BR e inglês recebem revisão manual; outros idiomas podem usar tradução automática sem promessa inicial de suporte. Datas são armazenadas em UTC e exibidas no horário local do jogador.

## 12. Reconexão, no-show e forfeit em arena

### 12.1 Antes da partida

- Check-in abre 10 minutos antes do início e fecha 2 minutos antes.
- Não fazer check-in remove do bracket sem derrota de MMR, mas repetição aplica cooldown de inscrição.
- Com menos de 8 confirmados no fechamento, o torneio oficial é cancelado e pode virar evento casual sem MMR.
- Depois de o bracket oficial ser criado, ausência passa a ser no-show e conta como derrota.

### 12.2 Durante a partida

- Primeira desconexão de cada jogador pausa o round por até 45 segundos.
- O total de reconexão permitido por confronto é 60 segundos; exceder resulta em forfeit.
- O oponente vê o estado e não pode causar dano durante pausa.
- Reconectar restaura apenas o estado confirmado pelo servidor, sem refazer cooldown ou recurso.
- Desconexões repetidas aplicam perda normal e cooldown de fila, não banimento automático.

Pausa é mais justa que deixar um avatar indefeso, mas pode ser usada para quebrar ritmo. A regra adotada limita-a a uma ocorrência curta por jogador.

### 12.3 Desistência e falha de serviço

- Forfeit exige manter confirmação e mostra efeito em MMR/bracket.
- Conta como derrota normal; não há multa econômica nem perda do mundo.
- Repetição em janela curta aumenta cooldown e remove recompensa de participação.
- AFK após aviso e 30 segundos sem ação válida vira forfeit. Detecção considera ações de combate/objetivo, não apenas movimento.
- Crash confirmado do servidor tenta recriar o confronto uma vez sem alterar MMR.
- Indisponibilidade ampla da plataforma anula o confronto e devolve inscrição. Se o bracket não puder continuar de forma íntegra, o evento é encerrado com compensação não competitiva, em vez de escolher vencedor arbitrário.

## 13. Anti-boost e antiabuso

### 13.1 Princípio de resposta

Nenhum sinal isolado deve banir. O sistema combina evidências, pode reter prêmio/leaderboard e encaminha casos graves para revisão. Ganhos fraudulentos são revertidos com transação auditável; o jogador recebe motivo e canal de contestação conforme a política do produto.

| Abuso | Sinais combináveis | Resposta progressiva |
|---|---|---|
| Farm de bounty | mesmo par, mesmo clã recente, transferências, mortes sem resistência | negar recompensa, espera, reter bounty, revisão |
| Kill trading | alternância previsível, duração anormal, repetição de pares | sem ganho, remover estatística, cooldown |
| Camping de spawn | mortes concentradas por vítima/célula/tempo | zerar recompensa, rota alternativa, revisão do mapa |
| Combat logging | desconexão sob marca repetida | avatar persistente, perda normal, espera de reentrada |
| Win trading | forfeit e resultado repetido entre relações próximas | reter MMR/prêmio, rollback, suspensão competitiva |
| Queue sniping | entradas sincronizadas e pares repetidos | atraso aleatório, expansão/mescla de fila, revisão |
| Smurfing/boost de conta | desempenho muito acima da incerteza, subida coordenada e partidas entregues | acelerar colocação, reter leaderboard/prêmio e revisar; habilidade isolada não gera punição |
| Boost de clã | guerras combinadas, roster circular, objetivos entregues | anular guerra, bloquear território, reter Suprimentos |
| Lavagem no banco | depósito/saque circular e promoções rápidas | limite, custódia, congelar transação |
| Assédio coordenado | convite, perseguição e chat após bloqueio | rate limit, restrição social e moderação |

Não há acesso a IP do jogador como base de detecção. O plano só depende de sinais disponíveis e legítimos na plataforma: conta, sessão, partida, clã, transação e comportamento dentro da experiência.

## 14. Segurança social e moderação

### 14.1 Chat e identidade

- Todo texto usa filtragem da plataforma para o remetente e cada destinatário.
- Não existe chat paralelo sem filtro, texto em placa arbitrária ou link externo clicável.
- Quick chat cobre coordenação de boss, guerra e arena sem exigir voz.
- Jogador pode mutar, bloquear e desativar convites sem perder acesso ao jogo.
- Bloqueio impede convite direto, mensagem e pareamento social voluntário quando possível; não garante separação absoluta em servidor público.
- Nome, tag e descrição de clã são filtrados e revalidados após edição.
- Emblema inicial é montado com formas e cores aprovadas. Upload de imagem personalizada fica adiado por risco de conteúdo impróprio e propriedade intelectual.

### 14.2 Ferramentas de proteção

- denúncia contextual a partir de chat, perfil, bracket, banco e guerra;
- evidência de sistema anexada sem pedir que o usuário copie texto ofensivo;
- rate limit de convite, pedido de duelo e convite de clã;
- preferência “não receber duelos/invites” respeitada globalmente;
- chat de espectador separado e atrasado;
- modo de interface que reduz nomes, notificações e pedidos durante transmissão;
- não há aposta, transferência por promessa ou prêmio dependente de conversa externa;
- design não depende de voz e mantém sinais visuais/sonoros redundantes.

### 14.3 Sanções por superfície

Sanções devem ser proporcionais e separáveis:

- mute/chat restrito para abuso de comunicação;
- bloqueio de convite e criação de clã para spam/identidade imprópria;
- suspensão competitiva para manipulação de resultado;
- congelamento de banco/mercado para fraude econômica;
- remoção de emblema, tag ou clã em violação;
- banimento da experiência apenas para gravidade ou reincidência compatível com política.

Um bom jogador de arena não recebe imunidade social. Líder de clã é responsável por permissões e nome público, mas não recebe punição automática por toda fala isolada de membro.

## 15. Escopo por fase

As fases devem ser sincronizadas com `06-ROADMAP.md`.

### Fase 0 — fatia vertical

- transição segura/livre, marca de combate e proteção de spawn;
- morte sem perda de equipamento e supressão de morte repetida;
- telemetria para projetar a proteção de novato da Fase 4;
- PvP funcional sem proteção persistente de novato, reputação completa, clã, torneio ou ranking.

### Fase 1 — combate e regras de duelo

- duelo casual isolado para testar loadouts;
- atribuição de agressor, autodefesa e telemetria de diferença de poder;
- sem MMR público enquanto combate e ressonância estiverem mudando.

### Fase 2 — progressão e equipamento

- teste da normalização competitiva em fila não ranqueada;
- reconexão e forfeit antes de qualquer rating persistente.

### Fase 3 — mundo PvE e economia de recursos

- XP/material não consolidado e perda limitada por risco entram com as regiões;
- atribuição e telemetria são exercitadas, mas reputação completa ainda não é requisito;
- não liberar bounty, clã ou leaderboard social antecipadamente.

### Fase 4 — reputação, morte e proteção social

- escala, guardas, acampamento neutro, restituição e bounty;
- calibração de perda por tipo de morte e poder efetivo;
- detecção de repetição e retenção de recompensa;
- leaderboard de caçadores somente após validar antifraude.

### Fase 5 — clãs sem território persistente

- primeiro clã: convite, cargos, chat filtrado e contribuição;
- três cargos públicos com permissões granulares e Suprimentos sem saque livre;
- evento competitivo de clã 8v8 sem posse persistente;
- sem banco livre, guerra agendada, alianças, territórios ou política econômica avançada.

### Fase 6 — torneio, ranking e temporada

- primeiro duelo ranqueado 1v1 com pré-temporada;
- torneio de 8 participantes nas três janelas semanais Brasil-first;
- Glicko-2, leaderboards separados, soft reset e prêmios cosméticos;
- cadência maior somente após população, reconexão e antifraude passarem os gates.

### Fase 7 opcional e pós-lançamento — território e sistemas avançados

- território só começa após todos os gates de população, formação, no-show, teleporte e economia;
- guerra territorial usa o formato 8v8 já validado e no máximo um território por clã no primeiro corte;
- posse sazonal, bônus capados, catch-up e proteção contra captura offline;
- banco livre e saque avançado são subprojeto independente e podem continuar adiados;
- alianças formais, múltiplos territórios e tributo continuam fora até existir justificativa própria.

## 16. Critérios de pronto do plano social

- iniciante não pode ser atacado no corredor sem ter encerrado proteção conscientemente;
- autoria distingue agressão, autodefesa, assistência e dano ambiental;
- morte aplica no máximo uma transação e nunca remove equipamento;
- repetição do mesmo par não gera moeda, reputação, bounty ou MMR ilimitado;
- recuperação de reputação funciona sem Robux e não pode ser feita AFK;
- banco de clã possui permissões e auditoria antes de aceitar valor negociável;
- território não concede poder exclusivo nem permite captura offline;
- ranqueado normaliza números, preserva loadout e ignora produto pago;
- reconexão, no-show, forfeit, crash e indisponibilidade ampla têm resultado definido;
- leaderboard é derivado do resultado persistido, não a fonte de verdade;
- chat, nome, tag e emblema têm fluxo de filtro, bloqueio e denúncia;
- experiência é jogável sem voz e com toque/controle/teclado;
- nomes e símbolos públicos passam por revisão de originalidade.

## 17. Decisões e trade-offs

| Tema | Decisão adotada | Custo aceito | Gatilho para rever |
|---|---|---|---|
| Proteção de novato | proteção real no corredor, com expiração | mundo menos livre no onboarding | abuso de observador protegido ou confusão alta |
| Reputação | lei gradual + recuperação ativa | mais estado e suporte | punição não reduzir vitimização |
| Morte | XP/material limitado; sem equipamento | risco menor que loot integral | alto risco não mudar comportamento |
| Bounty | prêmio a caçador, não a infrator | menos fantasia de “mais procurado” | caça legítima sem adesão |
| Clã/guilda | uma entidade chamada Clã | menos opções de fantasia | necessidade real de organizações distintas |
| Buff de território | recurso comum limitado, sem poder exclusivo | território menos dominante | guerras sem motivação apesar de prestígio |
| Guerra | agendada, 8v8 por objetivos | menos espontaneidade | população e infraestrutura suportarem escala maior |
| Torneio | 8 jogadores em três janelas semanais Brasil-first | menos eventos diários | quatro semanas com 80% completos e no-show abaixo de 10% |
| Competitivo | loadout próprio, números normalizados | inventário raro não vale integralmente | progressão perder identidade na arena |
| Rating | Glicko-2 com incerteza | maior complexidade que Elo | equipe não conseguir explicar/testar corretamente |
| Temporada | 8 semanas e soft reset | calendário operacional contínuo | população ou cadência de conteúdo não sustentar |
| Emblema | construtor aprovado | menos liberdade visual | moderação e revisão de imagem maduras |

## 18. Dependências e decisões consolidadas

Dependências obrigatórias:

- `01-GDD.md`: rating de poder efetivo, normalização, legalidade de modificadores e tempo para matar;
- `02-WORLD.md`: fronteiras, postos seguros, consolidação de XP e fontes/sumidouros;
- `04-ARCHITECTURE.md`: servidor reservado, mensageria de bracket, locks e autoridade de resultado;
- `05-DATA-SCHEMA.md`: histórico de reputação, transações, clã, temporada, idempotência e auditoria;
- `06-ROADMAP.md`: gates de população, estabilidade e moderação antes de cada fase;
- `07-SECURITY.md`: modelo de ameaça para remotes, teleporte, duplicação, spoof de resultado e fraude econômica;
- operação/moderação: política de sanção, revisão, contestação e resposta a incidentes;
- jurídico e criação: revisão de nomes, tags, emblemas, cosméticos e comunicação pública.

Decisões antes abertas agora consolidadas:

1. proteção de novato por onboarding + 30 minutos ativos, com expiração em 90 minutos ou saída voluntária;
2. reputação persistente por conta entre -1.000 e +1.000, desconto máximo de 5% e acampamento neutro;
3. perdas de morte com percentuais aprovados como baseline e caps de 5/10 minutos de ganho;
4. clãs de 20–40 membros, três cargos públicos e primeiro evento 8v8;
5. território apenas pós-lançamento, limitado a 5% de material comum e sem item raro ou poder;
6. três janelas semanais Brasil-first, torneio de 8 e expansão condicionada a métricas;
7. normalização parcial e Glicko-2 com parâmetros definidos para a pré-temporada;
8. pré-temporada de 4 semanas e temporadas regulares de 8 semanas.

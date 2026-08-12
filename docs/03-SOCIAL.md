# 03 — PvP social, reputação, clãs e competitivo

## 1. Contrato deste documento

Este documento define regras sociais e competitivas em nível de produto. Não contém implementação. Valores de tempo, faixas, perdas e tamanhos de equipe são **hipóteses de teste**, explicitadas para que não virem decisões silenciosas.

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
| Guerra territorial | loadout próprio com teto de poder de guerra | não | não | classificação de clã |

Separar reputação de MMR é deliberado: reputação mede conduta no mundo; MMR mede desempenho em regras competitivas. Um grande caçador de bounty não recebe rating de arena, e um jogador procurado não recebe bônus nem penalidade de MMR.

## 3. Proteção de novato

### 3.1 Regra recomendada

Na região inicial, proteção permanece até o jogador concluir o onboarding **e** acumular pelo menos 30 minutos ativos; ela expira automaticamente com 90 minutos ativos ou ao entrar voluntariamente em alto risco. Os tempos serão calibrados por testes.

Enquanto protegida, a pessoa:

- não causa nem recebe dano PvP de jogadores não protegidos no corredor inicial;
- não pode coletar recompensa de alto risco, bounty ou guerra;
- vê claramente quando e por que a proteção termina;
- pode optar por encerrá-la, com confirmação, de forma permanente para aquele perfil;
- não perde a proteção do mundo por participar de arena isolada.

Tentar iniciar ação hostil abre a confirmação de saída. A ação só ocorre após confirmar; isso evita tanto agressão invulnerável quanto perda acidental da proteção.

Depois da proteção, ataques iniciados contra alguém duas faixas efetivas abaixo geram punição forte, salvo autodefesa, guerra válida ou bounty. “Poder efetivo” combina progressão, maestria e orçamento de equipamento; nível bruto sozinho seria fácil de manipular e classificaria mal builds.

### 3.2 Trade-off

Proteção absoluta reduz a fantasia de mundo totalmente livre e pode ser explorada para observação segura. Por isso ela vale apenas no corredor inicial, impede interação com recompensas contestadas e possui expiração. A alternativa — só reputação — é mais aberta, porém não impede o primeiro abuso e tende a perder jogadores antes de a punição alcançar o agressor.

## 4. Reputação e lei

### 4.1 Escala recomendada

Reputação varia de **-1.000 a +1.000** e começa em 0. As faixas são públicas; a fórmula exata de cada evento pode ser ajustada sem renomeá-las.

Neste plano, a reputação acompanha o perfil da conta dentro da experiência, não o loadout. Trocar build não limpa consequência. Essa recomendação permanece sujeita à aprovação da questão correspondente em `09-OPEN-QUESTIONS.md`.

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

| Ação | Efeito inicial recomendado | Observação |
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

### 6.1 Penalidade recomendada

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

“Clã” e “guilda” representam o mesmo sistema. Criar duas entidades dividiria chat, banco, guerra e progressão sem benefício claro. O nome público recomendado é **Clã**.

Criação exige:

- onboarding concluído;
- reputação Neutra ou melhor;
- conta com tempo mínimo de existência a calibrar;
- custo em Marcas equivalente a algumas sessões intermediárias, não a dezenas de horas;
- nome e tag aprovados pelo filtro da plataforma.

Capacidade inicial proposta: 20 membros, crescendo até 40 por progressão de clã. Vender aumento de membros por Robux não é recomendado porque altera capacidade de guerra e geração econômica.

### 7.2 Cargos e permissões

| Cargo padrão | Capacidades iniciais |
|---|---|
| Líder | propriedade, cargos, guerra, território e dissolução protegida |
| Oficial | moderação, escalação de guerra e convite conforme permissão |
| Tesoureiro | gestão limitada do banco e receitas |
| Recrutador | convite e avaliação de candidatos |
| Membro | chat, contribuição e participação |

Permissões são granulares; título não concede poder implícito fora da matriz. Ações sensíveis exigem confirmação, cooldown e log. Transferência de liderança tem espera e pode ser cancelada; dissolução exige confirmação reforçada e período de arrependimento.

### 7.3 Banco e auditoria

- Aceita Marcas autorizadas e materiais de clã; não aceita itens vinculados.
- Depósitos são imediatos e registrados.
- Saques têm limite por cargo, por dia e por categoria.
- Operação de alto valor exige aprovação de duas pessoas na versão com tesouraria avançada.
- Convite recente, promoção recente e saída programada reduzem temporariamente limite de saque.
- Histórico mostra ator, item, quantidade, antes/depois e motivo por pelo menos uma temporada.
- Não existe “desfazer” silencioso; recuperação administrativa cria uma transação compensatória auditável.

Na Fase 5, somente depósito de materiais vinculados/Suprimentos e gastos em opções predeterminadas reduz o risco de roubo e duplicação. Banco livre de itens e saques avançados fica adiado para a Fase 7 ou posterior e ainda depende de auditoria, suporte e recuperação comprovados.

### 7.4 Progressão e perks

Clã ganha renome por participação distinta em missões coletivas, guerras e eventos. Repetir o mesmo conteúdo trivial ou alimentar alts tem retorno decrescente e teto por membro.

Perks recomendados:

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

## 8. Guerra e território

### 8.1 Problema de bola de neve

Dar mais recurso e chance de drop irrestrita ao clã já dominante faz o vencedor ficar progressivamente mais forte. A recomendação adapta a proposta original:

- proprietário recebe Suprimentos de clã e até 5% de ganho extra de material comum na região, com teto diário;
- chance adicional se aplica a cosmético ou cache utilitário, nunca a item de poder exclusivo;
- nenhum bônus territorial funciona em arena ranqueada;
- cada clã controla no máximo um território na primeira versão;
- território volta a ser disputável e sofre reset sazonal.

Isso mantém motivo econômico e prestígio sem transformar derrota em exclusão permanente.

### 8.2 Declaração e agenda

Fluxo recomendado:

1. clã elegível paga Suprimentos para declarar;
2. sistema oferece três janelas regionais dentro dos próximos dias;
3. defensor escolhe uma; ausência de escolha usa a janela intermediária publicada;
4. roster e reservas são travados antes da partida;
5. servidor reservado recebe os dois lados e valida participantes;
6. resultado atualiza território e inicia período curto de proteção.

Não existe captura offline. Um defensor não pode adiar indefinidamente, e um atacante não pode escolher madrugada local como surpresa.

Esse fluxo completo pertence à Fase 7. Na Fase 5, o mesmo formato pode ser prototipado como evento competitivo sem declaração, posse persistente, bônus regional ou banco livre.

Hipótese de primeiro formato: 8 contra 8, até 5 reservas, partida de 20 minutos, três objetivos de mapa e pontuação por captura/manutenção. Mortes ajudam a abrir espaço, mas não são o placar principal. Tamanho maior fica para depois de desempenho, matchmaking e clareza visual comprovarem capacidade.

### 8.3 Elegibilidade e equilíbrio

- clã precisa de idade mínima, membros ativos distintos e reputação coletiva aceitável;
- novo membro espera antes de guerra territorial, impedindo contratação relâmpago;
- loadouts permanecem próprios, mas atributos numéricos respeitam teto sazonal de guerra;
- itens pagos não alteram orçamento de combate;
- abandono deliberado, alimentação de placar e acordo de resultado anulam recompensa;
- clã em desvantagem recebe opção de objetivo defensivo e recuperação logística, não dano artificial;
- uma semana de proteção após captura é hipótese inicial para evitar guerra diária e exaustão.

Alianças formais, tributo, empréstimo entre clãs e múltiplos territórios ficam fora da primeira versão. São sistemas políticos e econômicos grandes o bastante para uma fase própria.

## 9. Torneios

### 9.1 Cadência

Realizar um torneio a cada duas horas desde o lançamento fragmentaria uma população pequena. Recomendação:

- começar com quatro janelas regionais por dia e um evento maior no fim de semana;
- mostrar horário local e contagem regressiva global;
- abrir inscrição antecipada e check-in próximo da partida;
- exigir mínimo de 8 e limitar a 16 participantes na primeira versão;
- aumentar para cadência de duas horas apenas quando concorrência por região sustentar brackets completos.

Se não atingir o mínimo, participantes escolhem reembolso/saída ou conversão para evento casual sem MMR. O sistema não preenche torneio oficial com bots.

### 9.2 Normalização recomendada

Adotar o meio-termo:

- **duelo casual:** usa loadout, maestria e equipamento construídos no mundo;
- **ranqueado e torneio oficial:** mantém apenas habilidades já desbloqueadas e escolhas de loadout, mas normaliza nível numérico da habilidade, atributos e orçamento de equipamento;
- modificadores comportamentais têm custo competitivo e lista de legalidade; efeito impossível de equilibrar pode ficar fora da temporada;
- uma rotação de loadouts de empréstimo permite experimentar o modo, mas não concede desbloqueio no mundo.

Normalizar tudo mediria execução, porém apagaria o produto de progressão. Não normalizar nada transformaria ranking em inventário. A regra proposta preserva identidade e fecha a maior diferença de poder.

### 9.3 Bracket e partida

- Primeira versão: 1v1, eliminação simples, semente por faixa de MMR.
- Jogadores do mesmo clã são separados nas primeiras rodadas quando possível, sem adulterar a semente inteira.
- Bye não conta como vitória jogada nem gera recompensa de atividade.
- Cada confronto usa melhor de três rounds curtos; empate vai para objetivo de desempate, não dano total bruto.
- Arena dedicada é simétrica, sem vantagem de spawn e com limites visíveis.
- Espectador tem atraso de 15 segundos e chat separado para reduzir coaching.
- Não há aposta, bolsa de prêmio financiada por jogadores nem troca no servidor de arena.

Premiação:

- cosmético, título temporário, Insígnia competitiva e rota alternativa para material existente;
- participação só premia após atividade mínima;
- poder exclusivo e melhoria paga não entram;
- resultados superiores melhoram prestígio e quantidade, não desbloqueiam uma categoria de atributo inacessível.

## 10. Matchmaking e ranking

### 10.1 Filas

Haverá duas filas separadas quando a população justificar:

- **Duelo ranqueado contínuo:** alimenta MMR individual.
- **Torneio agendado:** usa MMR para seeding e gera pontos de torneio separados.

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

Recomendação: **Glicko-2 ou equivalente com incerteza**, em vez de Elo puro. Ele trata conta nova, pouca amostra e retorno após inatividade melhor, ao custo de implementação e explicação maiores. O MMR permanece oculto; a divisão e seu progresso são a representação pública.

Contrato proposto:

- 10 partidas de colocação com divisão provisória;
- rating e incerteza independentes por modo e temporada;
- divisão visível: Bronze, Prata, Ouro, Platina, Diamante, Ascendente e Lenda;
- limites numéricos definidos após observar a distribuição, não fixados por estética;
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

Hipótese inicial: 8 semanas competitivas e uma pré-temporada curta de validação.

- MMR sofre compressão de 25% em direção ao centro, não reset total.
- Recompensa usa maior divisão alcançada com mínimo de partidas e conduta válida.
- Recompensas são cosméticas, título e Insígnias; nunca status ranqueado.
- Após 14 dias sem jogar, apenas faixas altas começam a perder posição visível; incerteza sobe para todos.
- Decaimento tem teto de uma divisão por semana e não empurra jogador casual indefinidamente para baixo.
- Mudança grande de balanceamento entra entre temporadas. Correção de exploit pode entrar imediatamente com comunicação e, se necessário, congelamento de rating.
- Territórios são neutralizados ou comprimidos no fim da temporada; campeão mantém registro e cosmético, não domínio permanente.
- Histórico preserva temporada, divisão de pico, rating final e sanções que afetaram elegibilidade.

## 12. Reconexão, no-show e forfeit em arena

### 12.1 Antes da partida

- Check-in abre 2 minutos antes do fechamento.
- Não fazer check-in remove do bracket sem derrota de MMR, mas repetição aplica cooldown de inscrição.
- Depois de o confronto ser criado, ausência passa a ser no-show e conta como derrota.
- Bye gerado por número ímpar não pune ninguém.

### 12.2 Durante a partida

- Primeira desconexão de cada jogador pausa o round por até 45 segundos.
- O total de reconexão permitido por confronto é 60 segundos; exceder resulta em forfeit.
- O oponente vê o estado e não pode causar dano durante pausa.
- Reconectar restaura apenas o estado confirmado pelo servidor, sem refazer cooldown ou recurso.
- Desconexões repetidas aplicam perda normal e cooldown de fila, não banimento automático.

Pausa é mais justa que deixar um avatar indefeso, mas pode ser usada para quebrar ritmo. Limitá-la a uma ocorrência curta por jogador é o meio-termo recomendado.

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
- banco somente de materiais vinculados, se a auditoria estiver pronta;
- evento competitivo de clã sem posse persistente;
- sem banco livre, guerra agendada, alianças, territórios ou política econômica avançada.

### Fase 6 — torneio, ranking e temporada

- primeiro duelo ranqueado 1v1 com pré-temporada;
- torneio de 8–16 participantes em janelas regionais;
- Glicko-2, leaderboards separados, soft reset e prêmios cosméticos;
- cadência maior somente após população, reconexão e antifraude passarem os gates.

### Fase 7 — guerra, território e banco avançado

- guerra agendada 8v8 e no máximo um território por clã no primeiro corte;
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

| Tema | Recomendação adotada | Custo aceito | Gatilho para rever |
|---|---|---|---|
| Proteção de novato | proteção real no corredor, com expiração | mundo menos livre no onboarding | abuso de observador protegido ou confusão alta |
| Reputação | lei gradual + recuperação ativa | mais estado e suporte | punição não reduzir vitimização |
| Morte | XP/material limitado; sem equipamento | risco menor que loot integral | alto risco não mudar comportamento |
| Bounty | prêmio a caçador, não a infrator | menos fantasia de “mais procurado” | caça legítima sem adesão |
| Clã/guilda | uma entidade chamada Clã | menos opções de fantasia | necessidade real de organizações distintas |
| Buff de território | recurso comum limitado, sem poder exclusivo | território menos dominante | guerras sem motivação apesar de prestígio |
| Guerra | agendada, 8v8 por objetivos | menos espontaneidade | população e infraestrutura suportarem escala maior |
| Torneio | janelas regionais, não a cada 2h no início | menos eventos diários | brackets lotados e fila saudável |
| Competitivo | loadout próprio, números normalizados | inventário raro não vale integralmente | progressão perder identidade na arena |
| Rating | Glicko-2 com incerteza | maior complexidade que Elo | equipe não conseguir explicar/testar corretamente |
| Temporada | 8 semanas e soft reset | calendário operacional contínuo | população ou cadência de conteúdo não sustentar |
| Emblema | construtor aprovado | menos liberdade visual | moderação e revisão de imagem maduras |

## 18. Dependências e questões para consolidação

Dependências obrigatórias:

- `01-GDD.md`: rating de poder efetivo, normalização, legalidade de modificadores e tempo para matar;
- `02-WORLD.md`: fronteiras, postos seguros, consolidação de XP e fontes/sumidouros;
- `04-ARCHITECTURE.md`: servidor reservado, mensageria de bracket, locks e autoridade de resultado;
- `05-DATA-SCHEMA.md`: histórico de reputação, transações, clã, temporada, idempotência e auditoria;
- `06-ROADMAP.md`: gates de população, estabilidade e moderação antes de cada fase;
- `07-SECURITY.md`: modelo de ameaça para remotes, teleporte, duplicação, spoof de resultado e fraude econômica;
- operação/moderação: política de sanção, revisão, contestação e resposta a incidentes;
- jurídico e criação: revisão de nomes, tags, emblemas, cosméticos e comunicação pública.

Questões que devem aparecer em `09-OPEN-QUESTIONS.md`:

1. Aprovar proteção de novato por marco + tempo, incluindo expiração de 90 minutos.
2. Aprovar a escala de reputação, os benefícios máximos e o acampamento neutro.
3. Confirmar percentuais de morte só depois de medir ganho por minuto e retenção.
4. Aprovar limite inicial de 20–40 membros e guerra 8v8.
5. Aprovar bônus territorial limitado em vez de chance irrestrita de item raro.
6. Aprovar janelas regionais antes da meta de torneio a cada duas horas.
7. Aprovar normalização parcial e Glicko-2 para a primeira pré-temporada.
8. Decidir duração final de temporada após a pré-temporada e a capacidade de produção de conteúdo.

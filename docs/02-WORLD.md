# 02 — Mundo, conteúdo PvE e economia

## 1. Contrato deste documento

Este documento planeja o espaço jogável, a leitura de risco, as missões, os encontros PvE e o ciclo econômico. Ele não define implementação. Os números indicados são **hipóteses iniciais de balanceamento** e precisam ser validados por telemetria, teste de jogo e pesquisa com jogadores.

O mundo deve sustentar o loop de um action MMO: explorar, assumir risco, conquistar habilidades, obter recursos, melhorar a build e voltar ao conflito com uma decisão nova. Ele não pode ser apenas um corredor entre arenas.

Regras permanentes:

- nomes públicos, textos, imagens, áudio, arquitetura e efeitos devem ser originais;
- nenhuma região, missão, habilidade, criatura ou evento pode usar nome de personagem, franquia ou técnica protegida;
- habilidades são conquistadas jogando; não são vendidas por Robux;
- equipamento não cai do inventário ao morrer;
- risco maior aumenta variedade e eficiência de recompensa, mas não cria um item de poder obrigatório e exclusivo;
- cliente nunca decide zona, recompensa, moeda, inventário ou conclusão de missão;
- PC, mobile e console devem receber a mesma informação de risco, sem depender só de cor ou de texto pequeno.

## 2. Pilares do mundo

1. **Risco legível:** ninguém entra em PvP ou em uma penalidade maior sem aviso redundante e tempo para desistir.
2. **Progressão com descoberta:** habilidades e modificadores vêm de cadeias, bosses e exploração, não apenas de uma loja ou barra de XP.
3. **Densidade antes de tamanho:** cada região precisa ter rotas, marcos e encontros úteis. Um mapa menor e vivo vale mais que um continente vazio.
4. **Conflito com saída:** todo espaço perigoso precisa oferecer mais de uma rota, objetivos além de matar jogadores e uma forma clara de voltar a um ponto seguro.
5. **Recompensa pessoal em conteúdo coletivo:** contribuição conta; último golpe não rouba boss nem evento.
6. **Economia com remoção real:** toda fonte recorrente de moeda ou material precisa ter um sumidouro saudável correspondente.

## 3. Forma do mapa

### 3.1 Decisão recomendada

Adotar um mapa contínuo em **rede de regiões**, cada uma com um assentamento ou posto seguro e duas ou mais saídas para áreas livres. Até a expansão do mundo, manter tudo no mesmo lugar da experiência. Arena ranqueada usa lugar reservado separado. Só dividir o mundo em vários lugares se orçamento de memória, streaming ou população por servidor provar a necessidade.

Essa direção favorece exploração e encontros espontâneos. A alternativa — várias ilhas ou instâncias independentes — simplifica desempenho, mas transforma a viagem em menu e reduz a sensação de mundo compartilhado.

### 3.2 Regiões planejadas

As faixas abaixo medem progressão efetiva, não autorizam dano garantido sobre jogadores abaixo delas. Nomes e temas ainda passam por revisão jurídica e visual antes de produção.

| Região pública provisória | Faixa recomendada | Perfil | Função | Fase mínima |
|---|---:|---|---|---|
| **Bastião do Limiar** | 1–5 | segura | spawn inicial, treino, forja básica, quadro de missão e acesso futuro a torneio | Fase 0 |
| **Planície Estilhaçada** | 1–8 | livre com transição de onboarding | primeiro PvP, recursos comuns, rotas curtas e primeiro encontro PvE | Fase 0 |
| **Bosque dos Ecos** | 6–14 | mista | cadeias de habilidade, coleta e encontros de emboscada com boa visibilidade alternativa | Fase 3 |
| **Garganta de Cinzas** | 12–22 | alto risco | boss regional, materiais de forja e primeiro contrato de perda aumentada | Fase 3 |
| **Arquipélago da Tormenta** | 20–30 | mista | mobilidade avançada, eventos agendados e rotas de alto valor | Fase 7 ou posterior |
| **Cratera do Véu** | 25+ | alto risco | materiais eficientes de fim de jogo, guardiões e conflito territorial | pós-Fase 7 |

“Mista” significa uma região com um posto seguro claramente delimitado e uma área externa livre; não significa alternar PvP silenciosamente dentro da mesma rua.

O lançamento não promete todas essas regiões. A lista é uma malha de expansão para impedir que arte e conteúdo sejam produzidos sem função sistêmica.

### 3.3 Regras de composição

- O jogador deve identificar um ponto seguro ou uma rota de retirada a partir de marcos visuais, não de minimapa obrigatório.
- Cada saída de assentamento tem pelo menos uma alternativa com linha de visão quebrada, evitando um único gargalo fácil de acampar.
- O spawn fica dentro de uma camada segura interna; não aponta diretamente para a fronteira PvP.
- Recursos de maior valor ficam distribuídos entre objetivos móveis, bosses e rotas, não concentrados em um único ponto permanente.
- Viagem rápida só conecta locais seguros já descobertos. É bloqueada durante combate e exige uma canalização cancelável.
- Não há teleporte direto para área livre ou de alto risco.
- Água, abismos e paredes não podem criar atalhos que atravessem a fronteira sem passar pelo aviso de risco.
- A região inicial precisa ser atravessável em poucos minutos; o tempo deve vir das decisões e dos encontros, não de caminhada vazia.

## 4. Tipos de zona e transição PvP

### 4.1 Regras por tipo

| Regra | Zona segura | Zona livre | Zona de alto risco |
|---|---|---|---|
| PvP entre jogadores | desligado | ligado | ligado |
| Ataque de guardas | apenas contra infratores | não se aplica | não se aplica |
| Penalidade de morte | nenhuma perda econômica | padrão | aumentada, com teto |
| Qualidade de recurso | básica/serviços | melhor eficiência | melhor eficiência e variedade |
| Viagem rápida de entrada | permitida | não | não |
| Troca/mercado | serviços autorizados | não | não |
| Confirmação explícita | ao sair para risco pela primeira vez | aviso persistente | confirmação reforçada |

Zona segura desliga PvP entre jogadores, mas não torna um infrator imune aos guardas. Um jogador procurado que atravesse o limite continua sem poder ser atacado por outros jogadores ali; a aplicação da lei é PvE, decidida pelo servidor.

### 4.2 Contrato visual e de interação

Toda fronteira usa, ao mesmo tempo:

1. portal, ponte ou marco físico impossível de confundir com decoração;
2. mudança de iluminação e material de solo;
3. faixa de UI com ícone, texto “PvP ATIVO” ou “ALTO RISCO” e penalidade de morte resumida;
4. sinal sonoro e vibração curta quando suportada;
5. indicador persistente do estado da zona após a travessia.

Cor nunca é o único sinal. O texto deve caber em tela mobile e poder ser lido por leitor/assistência quando a plataforma oferecer. Alto risco exige ação de manter pressionado na primeira entrada da sessão e sempre que as regras mudarem.

### 4.3 Estado de fronteira

- **Saída da zona segura:** após confirmar, o jogador recebe 5 segundos de transição. Nesse período não causa nem recebe dano PvP; usar ação hostil encerra a proteção e ativa PvP imediatamente. Ele pode voltar sem punição.
- **Entrada na zona segura:** um jogador marcado por combate PvP nos últimos 15 segundos não cruza a barreira interna. A contagem é visível. Isso evita atacar e escapar instantaneamente.
- **Projéteis e áreas:** não atravessam a fronteira causando dano. Empurrão, puxão e teleporte hostil param antes dela.
- **Mudança forçada de região:** nunca pode remover a confirmação de alto risco ou depositar alguém fora da proteção de spawn.
- **Queda de conexão:** não limpa marca de combate nem converte inventário em estado seguro; a regra de desconexão está detalhada em `03-SOCIAL.md`.

Os tempos de 5 e 15 segundos são valores de partida. O critério é impedir abuso sem deixar a retirada impossível; devem ser ajustados com dados de tempo para matar, latência e mobilidade.

### 4.4 Prevenção de camping

- dois ou mais portões funcionais por assentamento;
- área sem linha de visão direta entre spawn e exterior;
- proteção de respawn até 10 segundos, encerrada ao atacar ou sair do raio protegido;
- nenhum ganho de bounty, reputação, moeda ou estatística por mortes repetidas da mesma vítima em janela curta;
- ponto de retorno alternativo quando uma saída acumular combate excessivo;
- corredor inicial com restrição de iniciação por diferença de poder, detalhado em `03-SOCIAL.md`;
- telemetria de mortes por célula para identificar gargalos de mapa, não apenas punir o jogador depois do dano.

## 5. Zonas seguras

O Bastião do Limiar é o primeiro espaço social e o padrão para futuros assentamentos. Deve conter:

- spawn e ponto de retorno;
- treino sem dano real e teste de loadout;
- forja e identificação de materiais;
- vendedores e, quando liberado, mercado em custódia;
- quadro de missões e NPCs de cadeia;
- banco pessoal e gestão de inventário;
- acesso a viagem rápida;
- entrada/inscrição de torneio, sem obrigar o jogador a permanecer no local até começar;
- guardas, sinalização da lei e uma saída neutra para jogadores com reputação negativa.

Jogadores fora da lei não usam o mercado principal e são perseguidos pelos guardas, mas não ficam em um bloqueio irrecuperável. Um acampamento neutro oferece banco pessoal, recuperação de reputação e serviços básicos com custo maior; ele não oferece desconto, mercado global nem missão de prestígio.

Não colocar todos os NPCs numa única fileira. Serviços recorrentes ficam próximos; personagens de cadeia e segredos usam a área para estimular descoberta sem aumentar atrito de manutenção.

## 6. Missões e descoberta de habilidades

### 6.1 Estrutura de conteúdo

Há três camadas, com responsabilidades diferentes:

| Camada | Autoria | Repetição | Recompensa principal |
|---|---|---|---|
| Cadeia de habilidade | feita à mão | uma vez por habilidade | desbloqueio e entendimento do uso |
| Contrato regional | modelo parametrizado com revisão | repetível com rotação | moeda, materiais e maestria |
| Evento público | feito à mão, agenda ou gatilho de mundo | recorrente | recurso compartilhado, boss e status social |

Desbloqueio de habilidade nunca depende de drop aleatório raro. Uma cadeia padrão tem quatro atos:

1. descoberta da fantasia e do mentor;
2. prova que ensina a mecânica central;
3. variação de objetivo que testa decisão, não só dano;
4. confronto ou desafio final que concede a habilidade.

Fracassar permite tentar de novo sem pagar Robux e sem perder o progresso narrativo. Materiais opcionais podem acelerar preparação, nunca comprar o desbloqueio.

### 6.2 Tipos de missão

| Tipo | Uso recomendado | Risco a evitar |
|---|---|---|
| Caça | ensinar alvo, rota e mecânica | contagem longa de inimigos idênticos |
| Boss | fechar cadeia ou reunir região | último golpe, espera excessiva e boss sem telégrafo |
| Coleta | criar rota e conflito de recurso | pontos estáticos dominados por um grupo |
| Tempo | domínio de movimento e execução | requisito impossível em mobile/alta latência |
| Encontro raro agendado | formar público e antecipação | janela única que exclui fusos horários |
| Escolta | proteger e tomar decisões em rota | NPC frágil, pathfinding estreito e sessão longa |

Escolta é a mais cara e frágil; fica fora da fatia vertical e só entra após um protótipo de rota aberta funcionar em todas as plataformas.

### 6.3 Regras de participação

- Crédito de grupo considera presença e contribuição; não exige último golpe.
- Contribuição pode vir de dano, proteção, interrupção, cura, controle e objetivo.
- Dificuldade escala em faixas, com limite. Vida não aumenta continuamente a cada entrada, evitando cura súbita do boss.
- Abandonar uma missão preserva desbloqueios anteriores e informa exatamente o que será reiniciado.
- Objetivo agendado oferece mais de uma janela regional ou uma rota alternativa equivalente.
- Recompensa diária melhora variedade, mas não cria sequência obrigatória nem perda crescente por faltar um dia.
- Maestria de família sobe pelo uso válido em combate e objetivos, com retorno decrescente contra alvos triviais. Ela reduz custo de acesso a conteúdo da mesma família; não substitui a cadeia.

## 7. Bosses e eventos de mundo

### 7.1 Categorias

| Categoria | Grupo esperado | Cadência inicial | Papel |
|---|---:|---|---|
| Elite local | 1–3 | reaparece em 10–15 min | ensinar leitura e dar material comum |
| Boss regional | 3–8 | janela de 30–45 min | fechar cadeia e alimentar forja |
| Boss de mundo | 8–20 | horários regionais anunciados | encontro social, cosmético e material raro |
| Guardião de alto risco | variável | invocado por recurso/objetivo | concentrar disputa endgame sem spawn aleatório |

Cadências são hipóteses. Um boss obrigatório para habilidade precisa ter instância, invocação ou espera máxima garantida; não pode exigir que o jogador fique parado por 45 minutos.

### 7.2 Contrato de combate e recompensa

- Ataques perigosos têm silhueta, áudio e tempo de reação compatíveis com mobile e latência real.
- Boss possui limite de perseguição e reset previsível. Reset provocado repetidamente é abuso detectável.
- Recompensa é pessoal e calculada pelo servidor; não existe roubo por último golpe.
- Participação mínima combina atividade e contribuição, sem privilegiar apenas dano bruto.
- Todo encontro importante entrega um recurso garantido e uma rolagem rara separada.
- Falhas na rolagem rara acumulam garantia vinculada à conta; o contador e o teto são visíveis.
- Grupo grande reduz ganho marginal individual antes de tornar o boss uma esponja de vida.
- Reentrada após morte preserva contribuição com decaimento, impedindo tanto perda total quanto retorno infinito sem risco.

### 7.3 Eventos

Primeiras famílias de evento:

- ruptura local: objetivos curtos encadeados e elite final;
- caravana: escolta PvE em rota aberta, somente depois da validação técnica;
- convergência de recursos: pontos móveis que mudam a rota ótima;
- ameaça regional: boss anunciado com preparação coletiva;
- disputa territorial: objetivo de clã em janela própria, não misturado a evento casual.

Eventos públicos duram o suficiente para chegada após o alerta e apresentam estado no mapa. Servidores com pouca população recebem escala menor ou agrupamento, nunca objetivo impossível. Trocar de servidor repetidamente não duplica a recompensa principal da mesma ocorrência.

## 8. Recursos, itens e equipamento no mundo

### 8.1 Direção recomendada

O mundo assume equipamento predominantemente **horizontal**: peças modificam comportamento, alcance, custo ou interação de uma habilidade, com uma parcela pequena e limitada de atributos básicos. Status bruto irrestrito cria power creep, invalida conteúdo antigo e torna PvP uma checagem de inventário.

O contrato detalhado de slots e modificadores pertence a `01-GDD.md`. Para distribuição no mundo:

- usar as quatro raridades definidas em `01-GDD.md`: Comum, Refinado, Raro e Relicário; uma quinta raridade só entra se tiver função distinta;
- respeitar os três slots definidos no GDD — Condutor, Guarda e Relíquia — sem criar slot adicional por região ou recompensa;
- peça rara não é automaticamente melhor: ela oferece efeito mais especializado e custo de build correspondente;
- fontes: cadeia, drop pessoal de boss, forja, evento e recompensa competitiva não exclusiva;
- itens de cadeia e catalisadores de progressão são vinculados à conta;
- materiais comuns podem se tornar negociáveis após a economia provar estabilidade;
- equipamento equipado ou aprimorado fica vinculado, evitando aluguel de poder e circulação infinita.

### 8.2 Aprimoramento com risco controlado

Recomendação: manter chance de falha apenas como **consumo de material**, nunca destruição da peça, regressão de nível ou perda de efeito. Cada falha enche uma barra de garantia; no limite, o próximo aprimoramento é certo.

Isso preserva um sumidouro econômico sem criar o pico de frustração de perder um item raro. A alternativa determinística é mais justa e simples; deve substituir a falha caso testes mostrem que a animação de tentativa não acrescenta decisão real.

## 9. Modelo econômico

### 9.1 Recursos planejados

| Recurso | Propriedade | Fontes | Usos | Negociação |
|---|---|---|---|---|
| **Marcas** | moeda comum | missões, PvE, eventos e bounties válidos | forja, respec, viagem, criação de clã e taxas | não transferível diretamente |
| **Fragmentos** | material por categoria | coleta, contratos e elites | receitas e tentativas de aprimoramento | mercado futuro, com limites |
| **Catalisadores** | material raro | cadeia, boss e garantia de drop | modificadores e marcos de maestria | vinculado à conta |
| **Insígnias competitivas** | prova de participação | torneio e temporada | cosméticos ou rota alternativa para material já obtível em PvE | vinculado à conta |
| **Suprimentos de clã** | recurso coletivo sazonal | guerra, território e contribuição validada | manutenção, perks horizontais e cosméticos | somente banco do clã |

Maestria, XP e reputação são progressão, não moeda. Não podem ser enviados, vendidos ou convertidos em Robux.

Insígnia competitiva não compra poder exclusivo. Dar material de aprimoramento a vencedores sem rota equivalente faria os melhores ficarem mecanicamente mais fortes por vencer, criando efeito bola de neve.

### 9.2 Fontes e sumidouros

| Fluxo | Tipo | Frequência | Controle econômico |
|---|---|---|---|
| Missão/contrato | fonte de Marcas e Fragmentos | alta | retorno decrescente em repetição trivial e limite por objetivo |
| Elite/boss | fonte de material e pequena moeda | média | crédito de contribuição, garantia e bloqueio por ocorrência |
| Evento | fonte de material e cosmético | média | recompensa por conta/ocorrência e escala por população |
| Bounty | fonte de Marcas | variável | teto diário, divisão por participação e análise de relação repetida |
| Forja/aprimoramento | sumidouro de Marcas e Fragmentos | alta | custo cresce por marco, sem destruir equipamento |
| Respec | sumidouro de Marcas | ocasional | primeiro respec barato; custo tem teto e espera, nunca vira prisão |
| Viagem rápida | sumidouro leve de Marcas | frequente | preço por distância, gratuito no onboarding |
| Criação/manutenção de clã | sumidouro de Marcas/Suprimentos | média | custo previsível; atraso não apaga o clã imediatamente |
| Mercado | sumidouro por taxa | alta após liberação | taxa de listagem + taxa de venda, ambas visíveis |
| Cosméticos e personalização | sumidouro opcional | recorrente | sem atributo de combate |

Não usar durabilidade e conserto como sumidouro no lançamento. É uma taxa punitiva ligada ao tempo jogado e conflita com experimentação de builds.

### 9.3 Metas e monitoramento

Antes de ajustar preços, acompanhar por faixa de progressão:

- Marcas criadas, removidas e saldo mediano por jogador ativo;
- tempo mediano para um aprimoramento e um respec;
- concentração de riqueza e materiais nas contas superiores;
- preço mediano, dispersão e velocidade de venda por item;
- taxa de falha/garantia e abandono após tentativa;
- recursos perdidos por morte versus recursos obtidos na mesma sessão;
- proporção de recompensa vinda de PvE, PvP, evento e comércio.

Meta inicial: sumidouros voluntários devem remover a maior parte da emissão recorrente sem impedir o primeiro respec ou a primeira peça funcional. Criar uma moeda nova não corrige inflação da antiga.

### 9.4 Troca e mercado

**Decisão recomendada:** não liberar troca direta na fatia vertical nem junto do primeiro sistema de equipamento. Primeiro registrar emissão, consumo e duplicação em ambiente sem comércio. Depois liberar um mercado em custódia pelo servidor.

Regras do mercado futuro:

- vendedor lista item e preço; o item sai do inventário para custódia;
- comprador vê atributos, vínculo, histórico essencial e valor total antes de confirmar;
- confirmação final não pode ser alterada por uma das partes;
- taxa de listagem combate spam; taxa de venda remove moeda;
- contas novas têm limites progressivos de valor e volume;
- itens vinculados, moeda, Catalisadores e Insígnias não são negociáveis;
- todas as transações têm identificador e trilha de auditoria;
- convite, chat ou promessa externa nunca fazem parte do contrato de troca;
- sem empréstimo, aposta, presente de alto valor ou leilão na primeira versão.

Preço mínimo/máximo imposto pelo sistema pode bloquear descoberta de preço e só deve ser usado temporariamente diante de exploração comprovada. Alertas de preço muito fora da mediana são preferíveis.

## 10. Penalidade de morte como fluxo do mundo

Os valores completos e as exceções sociais estão em `03-SOCIAL.md`. O mundo precisa sustentar este contrato:

- só XP ainda não consolidado e uma fração de material comum carregado entram em risco;
- moeda, equipamento, habilidade, maestria, item de missão e recurso comprado nunca caem;
- posto seguro, conclusão de missão e extração explícita consolidam progresso;
- zona livre limita a perda ao equivalente aproximado de 5 minutos de ganho mediano;
- alto risco limita a perda ao equivalente aproximado de 10 minutos;
- a UI mostra o que está em risco antes de entrar e enquanto estiver na zona;
- morte em arena não toca no estado econômico do mundo.

## 11. Escopo por fase

As fases devem ser consolidadas com `06-ROADMAP.md`; esta sequência expressa dependência de produto, não promessa de data.

### Fase 0 — fatia vertical

- Bastião do Limiar e uma parte pequena da Planície Estilhaçada;
- uma fronteira segura/livre com todos os sinais e regras de combate;
- spawn, treino, retorno e um NPC para o primeiro objetivo;
- um recurso simples de progresso persistido e consolidado, sem mercado ou economia completa;
- um objetivo PvE curto para provar recompensa ponta a ponta;
- sem economia profunda, cadeia extensa, evento agendado, troca ou alto risco.

### Fase 1 — combate e composição

- ampliar somente o necessário para testar novos kits, loadout e ressonância;
- arena de treino e métricas de uso por área;
- nenhuma nova região grande antes de o combate suportar população real.

### Fase 2 — progressão e equipamento

- primeira cadeia de habilidade completa;
- forja, uma família de modificador e aprimoramento com garantia;
- boss regional controlado;
- economia ainda fechada à troca entre jogadores.

### Fase 3 — mundo e economia

- Bosque dos Ecos e Garganta de Cinzas, se as regiões anteriores atingirem densidade alvo;
- contratos, boss de mundo, eventos e maestria de família;
- consolidação e perda limitada de recurso por risco da zona;
- economia fechada a jogadores, com mercado NPC, simulação e telemetria; sem troca ou mercado entre contas.

### Fase 4 — reputação, morte e proteção social

- reputação, bounty e calibração da morte usam as regiões existentes;
- nenhuma região nova é necessária para validar proteção social;
- acampamento neutro e guardas fecham a recuperação sem criar prisão permanente.

### Fase 5 — clãs sem território persistente

- recursos de clã vinculados e evento coletivo sem posse de região;
- sem banco livre, guerra agendada, território, aliança ou economia entre clãs.

### Fase 6 — torneio e ranking

- as regiões existentes apenas encaminham à arena reservada;
- premiação competitiva é não exclusiva e entra nos mesmos controles econômicos;
- não criar nova área aberta para justificar o modo competitivo.

### Fase 7 — território, troca e live operations

- guerra e território só entram após clãs e economia auditável passarem seus gates;
- mercado em custódia pode ser testado separadamente; troca direta livre continua não recomendada;
- Arquipélago da Tormenta só avança se a densidade atual justificar expansão;
- Cratera do Véu e sua economia endgame ficam para depois dos gates de território, população e retenção.

## 12. Critérios de validação

O plano de mundo só avança se os testes demonstrarem:

- jogador novo identifica, antes de cruzar, que PvP será ativado e o que pode perder;
- não é possível causar dano, empurrar ou projetar área através da fronteira;
- spawn e duas rotas de saída não ficam dominados por um único grupo;
- missão compartilhada credita funções além de dano e não depende de último golpe;
- boss obrigatório possui espera máxima ou método de invocação;
- toda recompensa persistida é idempotente e auditável;
- nenhuma fonte econômica importante existe sem sumidouro e métrica correspondente;
- morte nunca remove equipamento ou progresso permanente;
- conteúdo e sinalização funcionam em tela pequena, controle e teclado;
- nomes, efeitos e temas passam por revisão de originalidade antes de publicação.

## 13. Decisões e trade-offs

| Tema | Recomendação adotada no plano | Custo aceito | Gatilho para rever |
|---|---|---|---|
| Topologia | mundo contínuo em rede | streaming e balanceamento de população mais difíceis | orçamento de memória ou servidores vazios por região |
| Fronteira | confirmação física, visual e textual | mais atrito ao atravessar | teste comprovar fadiga sem reduzir acidentes |
| Equipamento | modificador horizontal, pouco status bruto | mais conteúdo e QA por efeito | builds sem sensação de crescimento |
| Falha de upgrade | perde material, ganha garantia | menos tensão que destruir item | falha não gerar decisão nem sumidouro útil |
| Loot de boss | pessoal, contribuição ampla e garantia | menos disputa por último golpe | exploração de contribuição passiva |
| Troca | adiada; depois mercado em custódia | menos interação econômica no início | estabilidade e auditoria comprovadas |
| Torneio e material | rota alternativa, nunca poder exclusivo | prêmio competitivo menos agressivo | participação baixa sem motivação cosmética |
| Mapa futuro | regiões são plano, não escopo de lançamento | menos promessa de escala | retenção e densidade justificarem expansão |

## 14. Dependências e questões para consolidação

Dependências obrigatórias:

- `01-GDD.md`: orçamento de poder, slots, vínculo e formato dos modificadores;
- `03-SOCIAL.md`: reputação, marca de combate, morte, bounty, território e torneio;
- `04-ARCHITECTURE.md`: autoridade de zona, agendamento, reservas de servidor e fluxo de recompensa;
- `05-DATA-SCHEMA.md`: inventário transacional, progresso de missão, garantia de drop e livro econômico;
- `06-ROADMAP.md`: nomes finais e critérios de entrada/saída de cada fase;
- `07-SECURITY.md`: duplicação, teleporte, spoof de contribuição e repetição de recompensa;
- produção de arte/áudio: linguagem original, marcos de fronteira e telégrafos acessíveis.

Questões que devem aparecer em `09-OPEN-QUESTIONS.md`:

1. Aprovar ou substituir nomes provisórios das regiões após revisão de originalidade.
2. Confirmar se a proteção de novato termina por tempo ativo, marco de onboarding ou ambos.
3. Confirmar percentuais e tetos de perda somente após medir ganho por minuto.
4. Autorizar mercado apenas depois do teste econômico fechado; troca direta continua não recomendada.
5. Definir se a falha com garantia tem valor emocional suficiente ou se o upgrade será totalmente determinístico.

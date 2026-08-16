# Anime Verse Battlegrounds — Roster planejado

## 1. Status, uso e regra de exportação

As prioridades de produção e as quatro famílias foram aprovadas para planejamento em 2026-08-12. Ainda assim, todos os nomes públicos, rótulos de energia, fantasias e kits deste documento são **provisórios** até o **Gate jurídico P1**. Aprovação de escopo não equivale a liberação jurídica nem autoriza concept art público, marketing ou publicação. Os nomes foram afastados dos sugeridos inicialmente porque apenas trocar o nome de uma técnica não torna seguro um conjunto reconhecível de silhueta, poderes, animação, cor, história e marketing.

A coluna **“Codinome interno — NÃO EXPORTAR”** existe somente para rastrear a intenção de balanceamento autorizada pelo briefing. Ela não pode chegar a:

- interface, diálogo, missão, badge, conquista ou leaderboard;
- nome de asset, animação, áudio, textura ou pacote entregue ao cliente;
- analytics visível, mensagem de erro, localização ou material de suporte;
- metadado público, página da experiência, anúncio, trailer ou rede social.

Os codinomes canônicos devem ser removidos do artefato publicado, não apenas ocultados na tela. A presença de um codinome interno neste plano não autoriza seu uso em produção.

## 2. Decisões do roster

| ID | Decisão | Estado |
|---|---|---|
| ROSTER-DEC-001 | O avatar pertence ao jogador; identidades são escolas/títulos desbloqueáveis, não personagens licenciados jogáveis. | aprovada — 2026-08-12 |
| ROSTER-DEC-002 | Rótulos de planejamento: Éter Umbral, Fluxo Vital, Contrafluxo e Ímpeto Metamórfico. | aprovada para planejamento; publicação bloqueada até P1 |
| ROSTER-DEC-003 | Cada identidade oferece três técnicas normais e uma ultimate quando seu passe de conteúdo estiver completo; produção pode ser fatiada sem anunciar kit incompleto. | aprovada — 2026-08-12 |
| ROSTER-DEC-004 | Todo kit completo respeita capacidade máxima 4, impacto máximo 12 e no máximo uma técnica normal Definidora; técnicas continuam combináveis por dados. | aprovada — 2026-08-12 |
| ROSTER-DEC-005 | O roster de treze identidades é backlog pós-lançamento, não escopo comprometido de lançamento. | aprovada — 2026-08-12 |
| ROSTER-DEC-006 | Nenhuma identidade tem passiva gratuita própria; sua sinergia vem de marcas/estados produzidos pelas técnicas e da passiva pública da família. | aprovada — 2026-08-12 |
| ROSTER-DEC-007 | Para uma equipe de 1–3 pessoas, F0 prova uma identidade e F1 termina com três identidades/famílias; identidade adicional só entra depois de medir custo e qualidade do conteúdo anterior. | aprovada — 2026-08-12 |

## 3. Contrato de conteúdo

O roster deve viver em definições de dados, nunca em condicionais de sistemas. Cada identidade declara, conceitualmente:

- identificador interno neutro e não canônico para produção;
- nome público localizado e status do Gate P1;
- família energética pública;
- referências às definições de técnica e ultimate;
- ordem de desbloqueio, requisitos de missão e faixa recomendada;
- papel, dificuldade, tags de combate e grupos de recarga;
- capacidade e impacto de cada técnica;
- versão de balanceamento, estado de lançamento e substituição segura;
- referências de VFX, áudio, animação e ícone somente depois dos respectivos gates.

Adicionar uma identidade nova deve consistir em adicionar suas definições e conteúdo validado. ResourceSystem, combate, UI, persistência e loadout consomem o mesmo contrato e não recebem ramificação específica para um nome.

Quando uma técnica depende de marca criada por outra, ela precisa de comportamento mínimo independente. Isso evita que uma técnica importada se torne botão morto e impede bônus escondido por equipar um “kit completo”.

## 4. Ondas de produção

| Onda | Identidades | Objetivo | Fora do escopo dessa onda |
|---|---|---|---|
| Fase 0 | Punho do Eclipse | provar combate, Éter Umbral, três técnicas e persistência | ultimate final, mistura e roster completo |
| F1 | Punho do Eclipse, Tecelão de Ecos, Lâmina Nula | terminar três identidades e três famílias jogáveis; validar recursos, controles e o primeiro conjunto limitado de builds | Ímpeto Metamórfico, quarta identidade e roster grande |
| F2 | as mesmas três identidades | entregar maestria 1–10 e seis arquétipos de modificador reutilizáveis antes de ampliar conteúdo | identidade nova apenas para inflar variedade |
| Pós-lançamento A | Bastião Mutável | introduzir Ímpeto Metamórfico e a quarta família somente após custo, retenção e legibilidade de F1/F2 serem conhecidos | qualquer outra identidade em produção paralela |
| Backlog pós-lançamento | Nexo Inalcançável, Condutor de Âmbar, Oráculo Cinerário, Navegante Abissal, Monarca da Ruína, Jardineiro Primevo, Riscador Áureo, Andarilho Oblíquo, Regente Celeste | selecionar uma lacuna por vez a partir de telemetria e capacidade real da equipe | calendário ou ordem prometida antes de P1 e dos gates de produção |

Uma onda só avança após os kits anteriores terem telegraph legível nas três plataformas, taxa de escolha saudável, contra-jogo compreendido, custo de produção medido e aprovação de originalidade. O Gate P1 é obrigatório antes de encomendar arte pública ou expor qualquer identidade fora de teste interno controlado. Backlog não representa promessa de lançamento.

## 5. Resumo do roster

“Risco PI” é triagem de design antes de arte, não conclusão jurídica. **Alto** significa que a fantasia mecânica combinada ainda lembra um arquétipo muito específico e exige transformação adicional no Gate P1.

| Codinome interno — NÃO EXPORTAR | Nome público provisório | Energia pública | Papel | Dificuldade | Onda | Risco PI inicial |
|---|---|---|---|---|---|---|
| gojo | Nexo Inalcançável | Éter Umbral | zoner / defesa direcional | alta | backlog | alto |
| sukuna | Monarca da Ruína | Éter Umbral | pressão / armadilhas de linha | média | backlog | alto |
| yuji | Punho do Eclipse | Éter Umbral | bruiser / timing | baixa–média | F0 | médio |
| kashimo | Condutor de Âmbar | Éter Umbral | mobilidade / sobrecarga | alta | backlog | alto |
| asta | Lâmina Nula | Contrafluxo | anti-projétil / quebra de guarda | média | F1 | alto |
| eren | Bastião Mutável | Ímpeto Metamórfico | tanque / transformação de cerco | média | pós-lançamento A | alto |
| naruto | Tecelão de Ecos | Fluxo Vital | pressão / repetição atrasada | média | F1 | alto |
| sasuke | Oráculo Cinerário | Fluxo Vital | precisão / leitura | alta | backlog | alto |
| hashirama | Jardineiro Primevo | Fluxo Vital | controle / suporte destrutível | média | backlog | alto |
| tobirama | Navegante Abissal | Fluxo Vital | rotas / invocação utilitária | alta | backlog | alto |
| minato | Riscador Áureo | Fluxo Vital | trilhos / burst móvel | alta | backlog | alto |
| obito | Andarilho Oblíquo | Fluxo Vital | redirecionamento / antiprojetil | alta | backlog | alto |
| madara | Regente Celeste | Fluxo Vital | defesa orbital / área tardia | alta | backlog | alto |

## 6. Kits planejados

Valores são **hipóteses de playtest**, medidos contra 100 de vida e os recursos-base do GDD. `Cap/Imp` significa capacidade normal e impacto. Ultimate não usa capacidade normal, mas consome impacto. Quando um kit possui técnica normal com `Cap = 2`, ela é a `Definidora`; nenhum kit pode ter mais de uma. `C` é custo-base de recurso; `CD` é recarga-base em segundos. Dano indicado não inclui ataque básico, equipamento ou variante de maestria.

### 6.1 Nexo Inalcançável

**Eixo original:** refratar trajetórias com planos direcionais finitos. Não possui invulnerabilidade permanente nem negação total de contato.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Lente de Desvio | 1/2 | 18 / 9 | Cone curto causa 8 e empurra 8 studs. Guarda reduz o empurrão; errar abre 0,45 s de recuperação. |
| Margem Refratada | 2/4 | 28 / 18 | Plano frontal por 3 s, 40 de durabilidade; desvia um projétil e reduz impulso de quem cruza. Laterais, costas e quebra de guarda permanecem abertas. |
| Poço Vetorial | 1/2 | 22 / 13 | Zona de 4 studs por 2,5 s curva dashes em direção visível e causa até 8. Sair a pé ou destruir o foco encerra o efeito. |
| Ultimate — Horizonte Partido | —/4 | 60 / 100 | Três faixas móveis alternam direção de impulso por 8 s, máximo 24 de dano. Há corredores seguros e 0,8 s de antecipação por mudança. |

**Notas de balanceamento:** Margem Refratada é `Definidora`, usa grupo de recarga de defesa dominante e não protege objetivo inteiro. O kit completo soma capacidade 4 e impacto 12.

**Risco PI — alto:** defesa inalcançável, atração/repulsão e fantasia espacial, quando combinadas, podem continuar reconhecíveis. P1 deve exigir silhueta não humanoide de “mestre”, geometria óptica própria, paleta não associada e testes de reconhecimento sem mostrar o nome. Se avaliadores identificarem uma referência específica de forma espontânea, o kit volta ao conceito.

### 6.2 Monarca da Ruína

**Eixo original:** desenhar falhas visíveis no terreno e obrigar o oponente a escolher por onde atravessar.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Fratura Anunciada | 1/2 | 18 / 7 | Linha no solo acende por 0,4 s e rompe por 10. Pode ser saltada ou aparada; nunca é corte invisível. |
| Tributo de Estilhaço | 1/2 | 20 / 10 | Golpe corpo a corpo causa 12; sobre uma falha própria consome-a para causar +4 de guarda, não dano. |
| Decreto Rachado | 2/4 | 30 / 18 | Cria três placas de falha por 6 s. Cruzar ativa 8 e stagger de 0,35 s uma vez por alvo; placas são contornáveis. |
| Ultimate — Coroa de Estilhaços | —/4 | 55 / 95 | Seis ondas concêntricas com setores seguros alternados, máximo 30. O centro não é automaticamente seguro para o usuário. |

**Notas de balanceamento:** nenhuma falha acerta sem telegraph; múltiplas placas compartilham limite de controle. Kit 4/12.

**Risco PI — alto:** brutalidade, cortes remotos e grande zona ritual são uma combinação distintiva. O kit deve permanecer baseado em placas sísmicas públicas, sem símbolos, gestos, arquitetura, frases ou cortes invisíveis associados a outra obra.

### 6.3 Punho do Eclipse

**Eixo original:** alternar golpes em dois tempos; timing correto cria eco, mas não transforma todo acerto em crítico garantido.

IDs estáveis e frame data de implementação: `docs/13-F0-SLICE.md` §6 (`comet_shoulder`, `broken_cadence`, `pulse_return`, `eclipse_beat` desligada). Os números da tabela abaixo do Punho do Eclipse são o **kit implementado** (retune 13/08); o restante do roster continua especulação de design.

| Ação | ID | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---|---:|---:|---|
| Ombro Cometa | `comet_shoulder` | 1/2 | 18 / 7 | Avanço de 7 studs e impacto de 14. Para na guarda (14 de guarda, 6 HP bloqueado) e pode ser punido lateralmente. |
| Cadência Quebrada | `broken_cadence` | 1/2 | 16 / 8 | Dois golpes de 7 + 9; reentrada numa janela de 120 ms (+ até 80 ms de lag no servidor) cria eco atrasado de 6 e ativa Fluxo se acertar. |
| Retorno de Pulso | `pulse_return` | 1/2 | 20 / 12 | Postura de 0,25 s reduz 50% de um golpe e responde com 10 e empurrão. Erro gera 0,6 s de recuperação; agarrão vence. |
| Ultimate — Batimento Eclipse | `eclipse_beat` | —/5 | 55 / 90 | Por 10 s, três timings corretos carregam finalizador sinalizado de até 26. Perder o ritmo não paralisa o usuário, mas zera a carga parcial. F0: `enabled = false`. |

**Notas de balanceamento:** o kit inicial usa apenas 3 de capacidade e 11 de impacto, deixando espaço futuro sem exigir mistura. Timing precisa ser tolerante no mobile e validado pelo servidor. Não há dano de 100–0.

**Risco PI — médio:** “golpe com segundo impacto” ainda pode lembrar referências conhecidas. Direção de arte deve usar motivo astronômico, postura e áudio próprios; não reproduzir sequência, pose ou efeito cromático reconhecível.

### 6.4 Condutor de Âmbar

**Eixo original:** instalar bobinas visíveis, escolher polaridade e aceitar queda de eficiência após sobrecarga.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Arco Residual | 1/2 | 18 / 8 | Projétil causa 9; perto de bobina própria curva uma vez, com trajeto visível. |
| Salto de Polaridade | 1/3 | 22 / 11 | Avança por arco até uma bobina a 18 studs. Não funciona sem âncora, não atravessa parede e não dá invulnerabilidade. |
| Núcleo de Sobrecarga | 2/3 | 30 / 17 | Instala bobina destrutível; três acertos próximos a carregam para detonação de até 18. Após detonar, regen é suspensa por 3 s. |
| Ultimate — Tempestade de Bobinas | —/4 | 55 / 100 | Bobinas emitem pulsos sequenciais por 7 s, máximo 28. Ao terminar, Fluxo não pode devolver recurso por 5 s. |

**Notas de balanceamento:** sem bobina, mobilidade e pressão caem. Destruir ou afastar-se da rede é a resposta. Kit 4/12.

**Risco PI — alto:** eletricidade corporal, velocidade e modo autodestrutivo formam conjunto reconhecível. Manter tecnologia mineral/bobinas, sem transformação corporal, penteado, traje, cor ou nomenclatura associados.

### 6.5 Lâmina Nula

**Eixo original:** conquistar Contrafluxo por defesa ativa e gastar a carga em interferência, sem desligar o oponente por completo.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Corte de Silêncio | 1/2 | 16 / 7 | Arco pesado causa 11 e aumenta em 10% o custo da próxima técnica inimiga; não silencia botão. |
| Guarda Dissipadora | 2/4 | 0 / 14 | Janela frontal de 0,25 s neutraliza um projétil e gera carga válida. Erro remove 30 de guarda. Não absorve ultimate. Importada: custo-base 18 e não gera recurso. |
| Lastro Inverso | 1/2 | 24 / 12 | Impacto lento causa 14 e 30 de dano de guarda. Pode ser interrompido durante 0,55 s de antecipação. |
| Ultimate — Queda do Campo | —/4 | 70 / 105 | Campo por 7 s aumenta custos de projétil em 15% e reduz seu dano em 20%. Oponentes corpo a corpo não são prejudicados. |

**Notas de balanceamento:** Contra adversário sem projétil, Guarda Dissipadora ainda apara golpe leve, mas gera só 8. Kit 4/12.

**Risco PI — alto:** espada pesada que nega energia e ausência de regen podem parecer reprodução direta. P1 deve exigir origem narrativa, forma de arma, linguagem visual e método de interferência próprios; evitar símbolos, silhueta, roupa e animações reconhecíveis.

### 6.6 Bastião Mutável

**Eixo original:** montar uma exoforma cristalina de cerco com escolha defensiva explícita, não virar gigante humanoide.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Placa Emergente | 1/2 | 18 / 9 | Forma placa frontal de 24 de durabilidade por 2 s. Ataques laterais ignoram; ao quebrar, o usuário perde 15 de guarda. |
| Investida de Cerco | 1/2 | 22 / 11 | Corrida de 8 studs causa 10 e alto dano de guarda. Curva limitada; errar colide e recupera por 0,6 s. |
| Molde Reativo | 2/3 | 30 / 18 | Reduz em 25% o último tipo de dano recebido por 5 s, mas aumenta outro tipo indicado em 10%. |
| Ultimate — Forma Fortaleza | —/5 | 65 / 110 | Exoforma 1,35× por até 10 s, +30 de guarda e alcance +10%, velocidade −20%; drena Ímpeto e pode ser encerrada cedo. |

**Notas de balanceamento:** tamanho visual e hitbox crescem juntos. Portas e arenas precisam de envelope compatível; transformação não pisa em jogadores nem muda câmera alheia. Kit 4/12.

**Risco PI — alto:** transformação, endurecimento e escala são elementos combinados de alto reconhecimento. A forma deve ser exoesqueleto modular não humanoide, sem anatomia, narrativa, símbolos ou cenas evocativas.

### 6.7 Tecelão de Ecos

**Eixo original:** gravar ações próprias e repeti-las com atraso reduzido; ecos não são aliados autônomos.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Eco de Passos | 1/2 | 18 / 8 | Se o próximo leve acertar, uma silhueta geométrica repete 40% do dano 0,6 s depois. Eco não controla nem gera recurso. |
| Nó Cinético | 1/2 | 20 / 10 | Orbe causa 7 e marca impulso; o próximo empurrão no alvo ganha 4 studs, com ícone visível. |
| Laço de Retorno | 2/4 | 28 / 17 | Grava posição por até 3 s e retorna pelo trajeto visível em 0,45 s. Controle durante o retorno interrompe. |
| Ultimate — Coro dos Ecos | —/4 | 60 / 100 | As três próximas técnicas repetem 35% de dano após 1 s; cópias não controlam, curam, marcam nem devolvem recurso. |

**Notas de balanceamento:** repetição amplifica dano confirmado, não cobertura. O atraso oferece dash/guarda. Kit 4/12.

**Risco PI — alto:** duplicação visual, esfera e estado de poder em conjunto podem remeter a um kit específico. Usar ecos abstratos, sem clones autônomos, gesto, aparência, nomenclatura ou transformação reconhecível.

### 6.8 Oráculo Cinerário

**Eixo original:** prever uma ação, marcar cinza e construir rotas de brasa visíveis; não usa olho especial nem chama inevitável.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Agulha Voltaica | 1/2 | 18 / 7 | Projétil estreito causa 9 e aplica marca por 4 s. Guarda remove a marca. |
| Leitura de Cinza | 1/3 | 22 / 13 | Passo lateral durante janela de 0,25 s; se evita um golpe, marca o agressor. Não causa dano automático; erro recupera 0,5 s. |
| Brasa Persistente | 1/2 | 20 / 10 | Brasa visível no chão detona por 8 quando alvo marcado usa técnica sobre ela; pode ser apagada por ataque pesado. |
| Ultimate — Mapa de Brasas | —/5 | 60 / 95 | Liga marcas em corredores após 0,9 s; três pulsos causam máximo 30. Limpar a marca ou sair do polígono responde. |

**Notas de balanceamento:** o kit usa 3/12; sobra capacidade, mas não impacto para outra ferramenta forte. Marcas têm ícone, duração e método de limpeza.

**Risco PI — alto:** precisão elétrica, contra por leitura e fogo persistente são um conjunto reconhecível. A produção deve evitar olho, arma, cor, gesto e fogo visual associados; cinza cartográfica e armadilhas públicas precisam dominar a leitura.

### 6.9 Jardineiro Primevo

**Eixo original:** investir recurso em estruturas vivas pequenas, destrutíveis e posicionais.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Raiz de Amparo | 1/2 | 20 / 10 | Broto de 20 de vida cura 2/s por até 5 s num raio curto. Um broto por usuário; fogo não recebe bônus automático. |
| Semente de Retorno | 1/2 | 18 / 12 | Semente em aliado por 6 s concede escudo 10 ao cair abaixo de 35 de vida. Inimigos veem e podem remover com pesado. |
| Muro Germinal | 2/4 | 28 / 16 | Parede de 50 de durabilidade por 6 s, com dois segmentos e abertura central. Não nasce sob jogador. |
| Ultimate — Bosque Ambulante | —/4 | 60 / 110 | Três troncos destrutíveis avançam lentamente, criando cobertura por 8 s e curando aliados próximos em até 12. |

**Notas de balanceamento:** estruturas contam para limite global por área e não bloqueiam spawn/porta. Kit 4/12.

**Risco PI — alto:** vegetação, cura e estruturas gigantes combinadas são distintivas. Reduzir escala, usar botânica e arquitetura próprias, evitar estátuas, gestos e formas reconhecíveis.

### 6.10 Navegante Abissal

**Eixo original:** desenhar correntes navegáveis e convocar um único instrumento aquático não humanoide.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Corrente de Avanço | 1/2 | 18 / 8 | Onda baixa percorre 14 studs, causa 7 e cria esteira que acelera qualquer jogador 8% por 2 s. |
| Âncora de Maré | 1/3 | 22 / 12 | Instala âncora a 18 studs; reativar surfa até ela em 0,4 s por rota visível. Parede e controle interrompem. |
| Vigia Salino | 2/3 | 28 / 18 | Mote aquático de 24 de vida lança dois projéteis lentos de 5. Um ativo; sem perseguição fora de 20 studs. |
| Ultimate — Maré de Sete Rotas | —/4 | 60 / 100 | Sete faixas surgem em sequência, cada uma antecipada por 0,7 s; máximo 28 no mesmo alvo. |

**Notas de balanceamento:** a esteira beneficia inimigos atentos, criando decisão espacial. Invocação não caça através do mapa. Kit 4/12.

**Risco PI — alto:** água, deslocamento marcado e aliados temporários podem reproduzir combinação reconhecível. Âncoras, surf físico e instrumentos não humanoides precisam substituir teleporte, gestos e figuras associadas.

### 6.11 Riscador Áureo

**Eixo original:** desenhar trilhos retos e comprometer-se com rotas de alta velocidade, em vez de teleporte instantâneo.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Risco Luminal | 1/3 | 20 / 9 | Desenha trilho reto de até 20 studs; reativar percorre em 0,35 s. Não curva, atravessa parede ou concede invulnerabilidade. |
| Perfuração Prismática | 1/2 | 18 / 8 | Disparo fino causa 11; 0,45 s de antecipação e recuperação maior se errar. |
| Cruzamento Solar | 2/3 | 28 / 16 | Cria dois trilhos; a interseção pulsa por 12 após 0,8 s. Inimigo pode sair ou ocupar um trilho para negar rota segura. |
| Ultimate — Rede de Meridianos | —/4 | 60 / 95 | Três trilhos por 8 s e até quatro travessias; cada saída tem 0,25 s vulnerável. Colisão e controle encerram uma travessia. |

**Notas de balanceamento:** alta mobilidade exige preparação visível e geometria favorável. Kit 4/12.

**Risco PI — alto:** marcação seguida de teleporte e burst é extremamente reconhecível. Por isso o conceito usa trilho com tempo de viagem, risco de rota e linguagem cartográfica; qualquer retorno a teleporte instantâneo exige novo P1.

### 6.12 Andarilho Oblíquo

**Eixo original:** redirecionar vetores com superfícies anguladas. Não desaparece do mundo nem suga jogadores para outra dimensão.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Passagem Oblíqua | 1/3 | 22 / 12 | Passo lateral de 6 studs; por 0,18 s ignora projétil, mas continua vulnerável a melee e área. |
| Cunha de Margem | 1/2 | 18 / 9 | Cunha causa 8 e desloca 5 studs para o lado indicado. Guarda anula deslocamento. |
| Câmara Inclinada | 2/3 | 28 / 17 | Plano por 3 s rotaciona em 45° projéteis de qualquer equipe. Pode ajudar o inimigo e tem 30 de durabilidade. |
| Ultimate — Paralaxe Total | —/4 | 60 / 105 | Quatro planos diagonais alternam a direção de movimento por 7 s e causam três pulsos de até 24; linhas de transição ficam visíveis. |

**Notas de balanceamento:** ferramenta defensiva é direcional e simétrica. Áreas e melee vencem o passo. Kit 4/12.

**Risco PI — alto:** intangibilidade, reposicionamento e distorção espacial formam assinatura reconhecível. Limitar fase a projéteis, eliminar vórtice/teleporte dimensional e criar geometria angular própria são requisitos, não sugestões.

### 6.13 Regente Celeste

**Eixo original:** comandar placas orbitais e fragmentos menores, sem avatar humanoide gigante nem meteoro único.

| Ação | Cap/Imp | C / CD | Comportamento e contra-jogo |
|---|---:|---:|---|
| Placa Orbital | 1/2 | 20 / 10 | Duas placas de 8 de durabilidade orbitam e interceptam o primeiro golpe em seus arcos. Podem ser destruídas lateralmente. |
| Peso de Estilhaço | 1/2 | 20 / 9 | Fragmento causa 8 e reduz pulo/aceleração em 15% por 2 s; dash continua disponível. |
| Decreto de Impacto | 2/4 | 30 / 18 | Grupo de fragmentos marca área por 0,9 s e cai por 14. Centro e borda não acumulam dano. |
| Ultimate — Queda do Firmamento | —/4 | 65 / 110 | Seis impactos pequenos, cada um telegrafado por 1 s; máximo total 32 e nenhum rastreia após marcar o chão. |

**Notas de balanceamento:** defesa tem ângulos, área tem aviso longo e ultimate não cobre toda arena. Kit 4/12.

**Risco PI — alto:** defesa colossal e queda celeste podem remeter diretamente a uma referência. Sem avatar gigante, armadura reconhecível, meteoro singular, pose, olhos, voz ou narrativa correspondente. Placas abstratas e impactos distribuídos precisam sobreviver ao teste de reconhecimento.

## 7. Matriz de cobertura e lacunas

| Necessidade | Opções planejadas | Lacuna a observar |
|---|---|---|
| iniciador acessível | Punho do Eclipse, Bastião Mutável | falta suporte inicial simples |
| zoner | Nexo Inalcançável, Regente Celeste | risco de excesso de VFX |
| anti-zoner | Lâmina Nula, Andarilho Oblíquo | Contrafluxo tem só uma identidade |
| mobilidade | Condutor de Âmbar, Navegante Abissal, Riscador Áureo | três rotas precisam parecer diferentes |
| suporte | Jardineiro Primevo, Navegante Abissal | cura não pode alongar TTK indefinidamente |
| pressão melee | Punho do Eclipse, Monarca da Ruína | nenhum grappler planejado |
| leitura/counter | Oráculo Cinerário, Lâmina Nula | janela mobile exige teste específico |
| transformação | Bastião Mutável | quarta família fica pós-lançamento e depende de uma única identidade |

Antes de promover qualquer identidade do backlog, avaliar se é melhor preencher Contrafluxo, Ímpeto, suporte inicial ou grappler do que repetir Fluxo Vital. Sete das treze propostas pertencem a Fluxo Vital; essa concentração é herança do briefing e é inadequada para um sistema que pretende diversidade de família. Para uma equipe de 1–3 pessoas, não se produz o backlog em sequência: escolhe-se uma lacuna, valida-se o kit e só então se agenda a próxima identidade.

## 8. Gates de originalidade e lançamento

### P0 — texto interno

- codinome marcado como não exportável;
- nome público, família e técnicas sem termo bloqueado;
- descrição sem nome de franquia, personagem, técnica ou citação;
- busca interna confirma ausência fora desta coluna controlada.

### P1 — conceito jurídico e de design

- confirmar que a aprovação de planejamento não foi tratada como parecer jurídico;
- revisão conjunta de nome, fantasia e combinação mecânica;
- teste cego de reconhecimento com pessoas não envolvidas;
- pesquisa de nomes e marcas pelo responsável jurídico;
- aprovação ou pedido documentado de transformação;
- somente depois, concept art recebe sinal verde.

### P2 — arte, animação, VFX e áudio

- comparação lado a lado de silhueta, paleta, roupa, arma, pose e sequência;
- ícones e telegraphs próprios;
- nenhum áudio, voz, frase, tipografia ou símbolo imitativo;
- revisão de conjunto: elementos comuns também podem formar apresentação reconhecível.

### P3 — pré-publicação

- varredura do build, assets, localização, analytics e metadados;
- revisão de screenshots, thumbnail, trailer e texto da página;
- confirmação de licenças de todo asset de terceiro;
- registro da aprovação e da versão exata analisada.

Falhar em qualquer gate bloqueia a identidade, não apenas o asset apontado.

## 9. Critério de pronto de uma identidade

Uma identidade está pronta para entrar numa onda somente quando:

- as três técnicas e a ultimate funcionam isoladamente e em combinações permitidas;
- capacidade total é no máximo 4 e impacto total no máximo 12;
- no máximo uma técnica normal está marcada como `Definidora` no kit completo;
- custos, recargas, dano, controle, tags e contra-jogo estão declarados;
- existe ao menos um matchup favorável e dois tipos de resposta adversária;
- telegraph continua legível em celular de baixo desempenho, controle e PC;
- nenhum efeito depende de cor isolada;
- uso significativo, maestria e variantes têm regras anti-farm;
- métricas identificam a técnica e a combinação sem expor codinome canônico;
- P0–P2 foram aprovados para teste fechado; P3 foi aprovado para publicação;
- o kit não exige ramificação em sistemas compartilhados.

## 10. Hipóteses de balanceamento a validar

- Capacidade 4 e impacto 12 são suficientes para diferenciar kits sem criar escolha falsa.
- Ultimates entre impacto 4 e 5 podem coexistir com kits completos; impacto 6 deve ser exceção severa.
- Dano máximo de ultimate entre 24 e 32 preserva o TTK alvo.
- Técnicas definidoras com recarga de 16–18 s têm janela de punição perceptível.
- Estruturas de 20–50 de durabilidade não congestionam combate em grupo.
- F1 consegue validar três famílias com três identidades completas sem exigir uma quarta linha de conteúdo.
- O custo observado de produzir, localizar e validar uma identidade é sustentável por uma equipe de 1–3 pessoas antes de promover o backlog.
- Os novos conceitos passam por reconhecimento cego sem associação específica; hoje isso **não está comprovado**.

Esses valores e nomes não são finais. Mudança posterior precisa manter o ID da decisão relacionada, registrar hipótese e voltar ao gate aplicável quando alterar identidade pública ou conjunto mecânico.

# 07 — Segurança e anti-exploit

## 1. Objetivo e postura

O objetivo não é provar que o cliente é honesto; é construir o jogo de forma que um cliente arbitrário não consiga criar valor, escolher resultados ou corromper outros jogadores. Exploit prevention, detecção de abuso econômico e resposta operacional são partes do design, não uma camada adicionada no fim.

Princípios:

1. **Cliente é não confiável.** Remote, input, física sob network ownership, UI e relógio podem ser fabricados.
2. **Servidor decide efeitos.** O cliente expressa intenção; servidor valida contexto, resolve e replica resultado.
3. **Falhar fechado.** Payload inválido, perfil indisponível ou estado ambíguo não concede recompensa.
4. **Defesa em profundidade.** Schema, taxa, autorização, estado, espaço, economia e telemetria se complementam.
5. **Sanção proporcional.** Um sinal isolado causa rejeição/telemetria; banimento exige evidência correlacionada ou revisão.
6. **Economia auditável.** Criação, transferência e consumo têm origem e operationId.
7. **Operação reversível.** Sistemas de risco possuem kill switch e modo somente leitura.

Este é um plano. Limites e ferramentas citados precisam ser medidos e implementados em fases.

## 2. Ativos e fronteiras de confiança

### 2.1 Ativos protegidos

- integridade de dano, vida, recurso, cooldown e posição válida;
- inventário, moedas, materiais, upgrades e direitos cosméticos;
- progressão, unlocks, maestria, reputação, bounty e MMR;
- associação, cargos, banco, guerra e território de clã;
- bracket, resultado, prêmio e leaderboard;
- disponibilidade de servidores e budgets de DataStore/MemoryStore;
- dados e evidências operacionais;
- confiança do jogador em zonas seguras, telegraphs e regras de PvP.

### 2.2 Fronteiras

| Origem → destino | Confiança | Regra |
|---|---|---|
| Cliente → RemoteGateway | Hostil | Validar tudo, limitar antes de trabalho caro |
| Física com network ownership → domínio | Não confiável | Sanity checks e resultado server-side |
| Servidor → cliente | Visível ao atacante | Não enviar segredos ou perfil bruto |
| Servidor → DataStore | Confiável apenas após resultado confirmado | Retry/idempotência e validação de revisão |
| Servidor → MemoryStore | Temporário e falível | Coordenação, nunca única prova de posse |
| Servidor de origem → arena reservada | Parcialmente confiável | Token de uso único ligado a UserId/match |
| Catálogo/build → runtime | Confiável após validação | Assinatura/release e schema conhecido |
| Ferramenta/admin → produção | Alto privilégio | Menor privilégio, auditoria e dupla confirmação em ações destrutivas |

## 3. Adversários e hipóteses

- exploiter comum que chama remotes, altera velocidade, teleporta ou falsifica input;
- bot/macro que automatiza farm e congestiona endpoints;
- grupo coordenado com contas alternativas para bounty, MMR, boss, território ou economia;
- jogador legítimo sob alta latência, perda de pacotes ou dispositivo fraco, que não pode ser confundido automaticamente com ataque;
- falha acidental: retry, servidor encerrado, lock expirado, duplicação de mensagem ou versão incompatível;
- abuso interno/operacional de ferramenta administrativa.

Não assumir acesso confiável a IP, hardware fingerprint ou identidade real. Detecção de contas relacionadas usa comportamento e evidência agregada, nunca um único identificador invasivo.

## 4. Pipeline obrigatório para todo remote

1. Resolver o contrato pelo registry e verificar direção/protocolVersion.
2. Rejeitar payload acima do tamanho, profundidade ou contagem permitidos.
3. Decodificar por schema fechado; campos e enums desconhecidos não são executados.
4. Confirmar sessão pronta, jogador vivo/conectado e perfil lockado quando necessário.
5. Aplicar token bucket por jogador, família de ação e peso; limitar antes de consultas caras.
6. Verificar sequência/replay e idempotência quando aplicável.
7. Autorizar posse, cargo e estado atual a partir do servidor.
8. Validar cooldown, locks, modo, zona e janela temporal.
9. Validar distância, linha de visão, alvo e deslocamento quando aplicável.
10. Executar caso de uso uma vez, sob revisão/lock do agregado.
11. Emitir resultado mínimo e telemetria estruturada.

Falhas esperadas retornam códigos estáveis e não revelam detalhes internos. Exceções inesperadas são capturadas no limite do gateway; não repetem mutação automaticamente sem operationId.

## 5. Matriz de remotes e validações

Nomes são contratos lógicos; a implementação futura pode agrupá-los sem enfraquecer as regras.

| Remote/ação | Payload aceito | Validações obrigatórias | Resultado proibido vindo do cliente |
|---|---|---|---|
| AbilityIntent.Start | abilityId, inputMode, alvo/ponto limitado quando exigido, requestId | Sessão, vivo, unlock, loadout, estado, recurso, cooldown, zona, range inicial, rate, sequência | Dano, vítimas, custo, cooldown final, hit confirmado |
| AbilityIntent.Hold/Release/Cancel | executionId, estado de input | Execução pertence ao jogador, fase/janela, sequência, duração máxima | Tempo autoritativo, reembolso, efeito final |
| BasicAttackIntent | estado press/release ou sequência mínima | Cadência server-side, combo atual, stun/recovery, alvo resolvido pelo servidor | Vítima, dano, combo arbitrário |
| GuardIntent | begin/end | Estado, stamina/recurso, transição mínima, rate | Bloqueio retroativo ou dano negado |
| MovementAbilityIntent | abilityId/direção quantizada | Estado, cooldown, recurso, velocidade/deslocamento máximo, colisão, zona | CFrame final, distância livre, invulnerabilidade |
| InteractionIntent | entityId, action enum | Entidade server-side, distância, linha de visão, estado, zona, permissão | Recompensa, preço, quest progress |
| LoadoutCommand | IDs de slots, ultimate, equipamento, revisão | Posse, unlock, custo de slots, ressonância recalculada, fora de combate, local permitido | Stats calculados, bônus, família declarada |
| InventoryCommand.Equip | itemInstanceId, slot, revisão | Propriedade, estado Owned, compatibilidade, trade lock, modo, revisão | Modificadores e atributos finais |
| Craft/UpgradeCommand | recipeId, itemInstanceId, quantidade, operationId | Receita, materiais, saldo, cap, lock, RNG server-side, idempotência | Chance/roll, resultado, custo |
| TradeCommand | tradeId, ação, oferta por IDs/quantidades, revisão | Participante, proximidade/contexto se exigido, ownership, escrow, confirmação exata, lock, idempotência | Novo proprietário, saldo final, commit unilateral |
| QuestCommand.Accept | questId, NPC/entityId | Pré-requisito, distância, janela, capacidade, estado | Quest arbitrária/etapa concluída |
| QuestCommand.Claim | questId, stepRevision, operationId | Objetivos derivados, não reclamado, recompensa de catálogo, idempotência | Contadores, itemId/quantidade desejada |
| ClanCommand.Invite/Role | clanId, targetUserId, roleId, revisão | Membership atual, permissão do ClanRecord, caps, filtro, cooldown | Cargo do emissor ou permissão declarada |
| ClanBankCommand | operação, IDs/quantidades, revisão, operationId | Membership/cargo atuais, saldo/posse, bankRevision, limites, ledger | Saldo final ou saque sem recibo |
| ClanWarCommand | adversário, janela/objetivo permitido | Cargo, temporada, custos, conflito, janela e território válidos | Vencedor, score ou território final |
| TournamentCommand.Register | tournamentId/loadoutId, requestId | Janela, elegibilidade, rank, ausência de conflito, loadout reconstruído | MMR, seed, equipamento normalizado |
| TournamentCommand.Ready/Forfeit | matchId, token/contexto | Participante, servidor/estado, janela, sequência | Resultado arbitrário ou prêmio |
| SpectateCommand | matchId/targetUserId | Match visível, alvo participante, atraso/política competitiva | Câmera/posição usada como ação de jogo |
| SettingsCommand | campos permitidos e revisão | Schema, tamanho, frequência, filtro quando texto | Qualquer campo de perfil fora de settings |
| ClientTelemetry | enum e medidas limitadas | Allowlist, tamanho, rate; nunca vira prova isolada | Sanção, recompensa ou estado de jogo |

Não criar remote genérico de “UpdateProfile”, “DealDamage”, “GiveItem”, “SetPosition”, “CompleteQuest” ou “SetRank”.

## 6. Rate limits conceituais

Token buckets são por UserId/sessão, por família e com um teto global do servidor. Os valores abaixo são ponto de partida de playtest, não garantias públicas. Cooldown de habilidade continua sendo uma validação separada.

| Família | Sustentado inicial | Burst | Payload máximo inicial | Excesso |
|---|---:|---:|---:|---|
| Combate/input | 12 ações/s | 20 | 512 B | Descartar excedente, preservar último estado begin/end quando seguro |
| Movimento especial | 10 ações/s | 16 | 512 B | Rejeitar e elevar sinal se persistente |
| Interação/missão | 4 ações/s | 8 | 1 KiB | Rejeitar antes de spatial query/quest lookup |
| Loadout/inventário/forja | 2 ações/s | 5 | 4 KiB | Rejeitar; mutações persistentes também têm limite por minuto |
| Trade | 1 ação/s | 3 | 4 KiB | Throttle por trade e participante |
| Clã/banco/guerra | 0,5 ação/s | 2 | 4 KiB | Throttle por jogador e agregado do clã |
| Torneio/teleporte | 1 ação/s | 3 | 2 KiB | Rejeitar replay; token é uso único |
| Espectador | 2 ações/s | 5 | 512 B | Throttle sem afetar partida |
| Settings/telemetria | 2 ações/s | 5 | 2 KiB | Amostrar/descartar; nunca bloquear gameplay |

Controles complementares:

- custo ponderado: consulta de leaderboard, banco ou forja custa mais tokens que cancelamento;
- limite por agregado impede cem contas de martelarem o mesmo clã/trade;
- limite global protege CPU e budget externo;
- reconnect não deve zerar limites econômicos multi-servidor; operações caras usam janela compartilhada quando necessário;
- payload inválido consome tokens para impedir fuzz gratuito;
- cliente legítimo recebe backoff/código de rate limit, mas não detalhes da heurística de risco.

## 7. Modelo de ameaça por sistema

| Sistema | Ataques prováveis | Controles preventivos/detectivos | Risco residual |
|---|---|---|---|
| Combate | Spoof de dano/alvo, ataque através de parede, spam, cancelar recovery, multi-hit | Cliente envia intenção; hitbox, LOS, fases, máximo de alvos e dano no servidor; sequência e telemetria | Lag compensation mal calibrada pode parecer injusta |
| Movimento | Speed/fly, CFrame teleport, noclip, dash infinito, network ownership abuse | Envelope de movimento, estado permitido, spatial checks, tolerância por latência, rollback seguro, tokens de teleporte | Física Roblox pode gerar falso positivo; não banir por amostra única |
| Recurso/cooldown | Energia infinita, regen acelerada, reset de cooldown | Pools/timers no servidor, modifiers com fonte, caps absolutos, snapshots/deltas | Dessync visual requer resync claro |
| Zona/PvP | Entrar em alto nível, atacar da zona segura, evitar penalidade cruzando borda | Zona calculada no servidor, grace/telegraph confirmado, regra fixada no instante do evento | Geometria de borda precisa de teste extensivo |
| Progressão/quest | Completar etapa, farm por macro, repetir reward, falso boss contribution | Objetivos por eventos server-side, elegibilidade, operationId, contribuição limitada, padrões de automação | Bots podem imitar humanos; exigir sinais combinados |
| Inventário/forja | GiveItem, saldo negativo, roll escolhido, item fantasma, overflow | IDs únicos, caps, revisão, RNG server-side, ledger, schema e reconciliação | Falhas cross-profile exigem operação manual segura |
| Trade | Dupe por retry/disconnect, troca de oferta após confirmação, item em duas trades, scam de UI | Escrow, revision, confirmação invalidada, idempotência, resumo final explícito, cooldown, logs | Scam social fora do contrato; UX precisa mostrar oferta final claramente |
| Persistência | Dupla sessão, overwrite por default, replay de receipt, save antigo | Session lock, fencing, migração validada, revisão, hash da intenção, quarentena | Indisponibilidade pode exigir modo restrito |
| Bounty/reputação | Kill trading, contas alt, farm de novato, spawn camping, suicídio combinado | Diminishing returns por par/janela, diferença de poder, proteção de spawn, grafo de reciprocidade, recompensa pendente | Grupos legítimos podem se enfrentar repetidamente |
| Clã/banco | Escalada de cargo, saque concorrente, convite forjado, dois donos de território | ClanRecord autoriza, revisão, ledger, cooldown de cargo/saque, fencing, TerritoryRecord único | Conta de líder comprometida; considerar dupla aprovação para grandes saques |
| Guerra/território | Roster de última hora, contas alt, score fabricado, dupla ocupação | Roster congelado, eventos server-side, janela UTC, operationId de settlement | Coordenação fora do jogo não é totalmente evitável |
| Torneio/ranking | Win trading, disconnect tático, token replay, arena falsa, spectator info | Token de uso único, match state, reconexão, forfeit formal, detecção de pares/grupos, atraso de espectador | Conluio sofisticado exige revisão de temporada |
| Boss/loot | Tag-and-leave, clone de contribuição, reward múltiplo, server hopping | Contribution ledger em sessão, thresholds, killId único, claim idempotente, cooldown compartilhado em evento raro | Server hopping precisa de estado compartilhado bem dimensionado |
| Chat/social | Texto não filtrado, phishing, spam de convite, emblema impróprio | TextChatService/filtro Roblox, rate limit, allowlist de assets, report/block | Moderação de contexto continua necessária |
| Admin/operação | GiveItem acidental/malicioso, vazamento de token, kill switch sem auditoria | Menor privilégio, ações assinadas/auditadas, dupla confirmação, ambientes separados | Insider com acesso amplo; revisar permissões regularmente |

## 8. Controles específicos

### 8.1 Dano e hit validation

- cliente nunca envia valor de dano nem conjunto final de vítimas;
- servidor mantém fase da habilidade e só abre hitbox na janela ativa;
- origem, alcance, ângulo, linha de visão, collision group e máximo de alvos vêm da definição;
- cada execução mantém conjunto de alvos já atingidos conforme hitPolicy;
- lag compensation, se adotada, usa histórico curto server-side e clamp de rewind; timestamp do cliente é apenas pista;
- dano registra atacante, habilidade, execução, alvo e modificadores relevantes para investigação;
- ragdoll, knockback e invulnerabilidade são estados do servidor, ainda que VFX seja previsto.

### 8.2 Movimento, teleporte e zonas

- comparar deslocamento com envelope permitido pelo estado atual, incluindo dash, knockback e plataforma móvel;
- teleporte legítimo cria permissão server-side com origem, destino permitido, TTL e uso único;
- ao detectar anomalia, cancelar dano/interaction associados e corrigir para última posição segura;
- uma anomalia física gera score e correção; repetição impossível e correlacionada pode remover da sessão;
- entrada em zona livre/alto risco tem preaviso visual e confirmação server-side antes de habilitar PvP;
- spawn protection não é flag do cliente e termina por tempo ou ação ofensiva confirmada.

### 8.3 Anti-dupe e economia

- todo item único possui `itemInstanceId`, origem e último operationId;
- emissão e consumo usam delta, nunca “set balance” enviado pelo cliente;
- operationId igual + intenção igual retorna recibo; igual + intenção diferente é sinal crítico;
- escrow remove disponibilidade antes da confirmação final;
- revisão evita last-write-wins silencioso;
- rotina de reconciliação procura item com dois donos, estado impossível, saldo negativo e saga expirada;
- ativo em conflito vai para `Quarantined`; não é deletado nem liberado automaticamente;
- kill switch permite congelar trade, banco, forja, claims ou uma fonte específica sem derrubar combate.

### 8.4 Bounty, kill trading e spawn camping

Sinais planejados:

- kills repetidas do mesmo par em janelas curta e longa;
- alternância A↔B, reciprocidade anormal e grupos fechados;
- diferença de poder, tempo desde spawn, distância do spawn e duração do combate;
- vítima sem reação/dano, rotas repetidas e sessões sincronizadas;
- concentração de bounty/MMR por poucos oponentes;
- contas novas transferindo valor para a mesma rede comportamental.

Resposta de reward:

- primeira kill elegível usa valor normal;
- repetição próxima tem retorno decrescente até zero;
- kill em proteção de spawn ou oponente inelegível não rende bounty/maestria;
- recompensas suspeitas de alto valor podem ficar pendentes para liquidação;
- reputação por atacar novato é calculada independentemente de haver bounty;
- nenhuma heurística individual bane automaticamente.

### 8.5 Win trading e ranking

- matchmaking evita pares recentes quando população permite;
- resultado carrega matchId, roster, duração, rounds e motivo de término;
- forfeit e disconnect têm regras previsíveis; reconexão possui janela e token;
- partidas anormalmente curtas, alternadas ou concentradas reduzem confiança e podem reter projeção de leaderboard;
- revisão de temporada analisa clusters, não só pares;
- correção remove MMR/recompensa pela operação de origem, preservando ledger; não edita leaderboard isoladamente.

### 8.6 Clã e banco

- cada ação lê cargo/permissão atuais do ClanRecord;
- promoção, remoção e saque têm cooldown e revisionamento;
- saque de alto valor pode exigir proposta e segunda aprovação por cargo distinto;
- líder não pode apagar ledger; transferência de liderança tem janela de segurança;
- território é liquidado no registro da região antes de atualizar caches dos clãs;
- falha parcial não concede bônus a dois donos.

### 8.7 Chat, nomes e conteúdo do jogador

- usar serviços de filtro e chat da plataforma; não criar canal que contorne filtragem;
- nome de loadout, clã, tag e mensagens customizadas passam por filtro e limites;
- emblemas e assets são allowlisted/revisados;
- UI de troca e convite mostra UserId/display name vindo do servidor e evita links externos;
- report e block precisam ser acessíveis em PC, mobile e console.

## 9. Sinais, enforcement e falsos positivos

### 9.1 Score de risco

Sinais têm categoria, peso, confiança, janela e evidência. Pontuação não é uma verdade única permanente: decai quando apropriado e separa combate, economia, movimento e social. Bugs de uma versão podem ser excluídos por releaseId.

### 9.2 Escada de resposta

1. Rejeitar comando sem efeito colateral.
2. Ressincronizar/corrigir estado e registrar sinal.
3. Throttle adaptativo na família abusada.
4. Bloquear temporariamente a função de risco, como trade ou ranked.
5. Remover da sessão quando repetição torna o servidor indisponível ou há estado impossível confirmado.
6. Quarentena de ativo/recompensa e revisão.
7. Suspensão/banimento somente por evidência correlacionada e política de recurso.

Não usar ban automático por velocidade isolada, ping, erro de versão, alta habilidade, hardware fraco ou denúncia sem evidência.

### 9.3 Evidência mínima

- UserId, sessionId/JobId e releaseId;
- contrato/ação e códigos de rejeição;
- sequências e timestamps do servidor;
- posição/estado resumidos quando relevantes;
- operationId, revisões e receipts para economia;
- matchId/killId e participantes para abuso competitivo;
- decisão aplicada e versão da regra.

Payload integral e conteúdo pessoal não são coletados por padrão. Acesso, retenção e exclusão das evidências devem ter política operacional.

## 10. Disponibilidade e abuso de recursos

- rate limit ocorre antes de raycasts, busca espacial, catálogo complexo ou persistência;
- listas, strings, tabelas aninhadas e pontos de alvo têm caps rígidos;
- nenhuma ação do cliente dispara loop proporcional a inventário/clã sem paginação e limite;
- requests concorrentes do mesmo agregado são serializados ou retornam conflito;
- DataStore/MemoryStore têm circuit breaker e backoff;
- leaderboards e histórico são paginados, cacheados e limitados;
- VFX/eventos server→client são filtrados por relevância e agregados;
- falha de serviço externo coloca função econômica em somente leitura, não cria defaults.

Ataque de spam não deve consumir budget de save. Rejeições repetidas são amostradas em logs para evitar que a própria telemetria vire DoS.

## 11. Segredos, dependências e CI — plano futuro

- nenhum segredo, token de place, chave de API ou credencial em repositório, atributo replicado ou log;
- CI usa permissões mínimas, dependências fixadas e revisão de atualização;
- Wally packages passam por revisão de licença, manutenção e superfície de código;
- build falha em lint/type/schema/test; publicação não é automática na Fase 0;
- ambientes de desenvolvimento, staging e produção usam identificadores e stores separados;
- ferramentas administrativas não rodam por remote público genérico;
- mudanças de regra econômica e segurança exigem revisão de outro responsável.

## 12. Resposta a incidentes

### 12.1 Severidade

| Nível | Exemplo | Resposta inicial |
|---|---|---|
| SEV-1 | Dupe ativo em escala, perda/corrupção de save, privilégio admin comprometido | Congelar função/economia afetada, preservar evidência e formar responsável único |
| SEV-2 | Exploit de dano/ranking reproduzível, bypass de território, premiação duplicada limitada | Desabilitar habilidade/modo/fonte, conter rewards e investigar |
| SEV-3 | Spam, falso positivo elevado, falha de telegraph/zone | Ajustar limite/regra, monitorar e corrigir na próxima release segura |

### 12.2 Runbook

1. Detectar e abrir incidente com horário UTC, releaseId, impacto e responsável.
2. Conter com kill switch mais estreito: habilidade, receita, trade, banco, reward, ranked ou teleporte.
3. Preservar receipts, revisões, métricas e amostra de eventos; não editar evidência original.
4. Reproduzir em ambiente isolado e distinguir exploit, bug de versão e falha de plataforma.
5. Corrigir regra no servidor e adicionar teste de regressão/fuzz.
6. Publicar de forma gradual, monitorando rejeições e economia.
7. Reconciliar a partir do ledger: remover ganhos indevidos por operationId, restaurar perdas comprovadas e reconstruir projeções.
8. Comunicar impacto e compensação sem divulgar técnica explorável antes da contenção.
9. Fazer post-mortem com causa, janela, controles que falharam e ações com dono/prazo.

Nunca fazer rollback cego de perfis: jogadores podem ter progresso legítimo após o snapshot. Reversão é por operação/ledger e sob session lock.

### 12.3 Kill switches necessários

- habilidade/efeito/item/receita por ID;
- fonte de loot ou reward;
- trade, banco de clã, upgrade e respec;
- bounty e ganho de MMR;
- inscrição/premiação de torneio;
- teleporte para região/arena;
- modo somente leitura econômico global;
- bloqueio de uma versão de cliente/protocolo incompatível.

Kill switch não pode conceder fallback recompensador. Toda ativação é auditada e possui plano de reabertura.

## 13. Testes de segurança

| Teste | Cenários mínimos | Resultado esperado |
|---|---|---|
| Fuzz de remotes | Tipos errados, NaN/infinito, strings/listas enormes, campos extras, enum desconhecido | Rejeição limitada sem exceção ou trabalho caro |
| Replay/idempotência | Mesmo request/operationId antes, durante e depois de disconnect | Um único efeito e mesmo recibo |
| Combate hostil | Dano/targets falsos, ataque fora de fase/range/LOS, cancel spam | Zero efeito não autorizado |
| Movimento | Speed, fly, noclip, teleporte e física legítima extrema | Correção/rejeição com tolerância; sem ban por caso isolado |
| Economia com crash | Crash em cada passo de craft, reward, trade, banco e torneio | Commit único ou compensação/quarentena |
| Concorrência | Dois servidores no mesmo perfil/clã/território | Um escritor válido; conflito não duplica |
| Bounty/ranking | Pares repetidos, alternância, alts, disconnect tático | Reward reduzido/retido e sinal correlacionado |
| Disponibilidade | Spam distribuído e budget baixo | Gameplay essencial preservado; função de risco degrada segura |
| Migração maliciosa/corrupta | Campos extremos, IDs órfãos, versões desconhecidas | Quarentena; nunca default overwrite |
| Privacidade/logs | Busca por token, chat e payload bruto | Nenhum dado proibido em logs normais |

Testes de exploit em experiência publicada privada e contas de teste são obrigatórios; Studio isolado não representa teleport, DataStore, network ownership ou múltiplos servidores com fidelidade suficiente.

## 14. Critérios de segurança por gate

### Gate da Fase 0

- registry contém todos os remotes e nenhum endpoint genérico de mutação;
- matriz de validação tem teste de contrato para cada ação;
- dano, recurso, cooldown, hitbox, zona e reward são server-side;
- perfil usa session lock, migração e falha sem default overwrite;
- rate limits e métricas de rejeição funcionam sob carga;
- speed/teleport spoof não permite dano, acesso ou recompensa;
- save/rejoin preserva estado e retry não duplica recompensa.

### Gate antes de inventário/equipamento

- IDs únicos, caps, revisão e invariantes são testados;
- emissão/consumo têm operationId e ledger apropriado;
- upgrade sob retry/crash não duplica nem perde item silenciosamente;
- combinação de modifiers respeita ordem e caps absolutos.

### Gate antes de trade ou banco de clã

- saga/escrow passa por crash injection em todas as transições;
- concorrência multi-servidor e fencing são demonstrados;
- rotina de reconciliação e quarentena existe;
- kill switch e modo somente leitura foram exercitados;
- UX de confirmação mostra revisão final e invalida aceite alterado.

### Gate antes de torneio/ranking público

- token de teleporte é de uso único e ligado à partida;
- reconexão, forfeit, servidor órfão e resultado disputado têm estados explícitos;
- reward/MMR são idempotentes e leaderboard é reconstruível;
- sinais de win trading foram testados com dados sintéticos;
- espectador não vaza informação competitiva fora da política.

### Critério operacional contínuo

- alertas têm responsável e runbook;
- falso positivo é acompanhado por release e plataforma;
- permissões administrativas são revisadas;
- dependências e versões de protocolo são inventariadas;
- incidentes geram teste de regressão e ação preventiva, não apenas banimentos.

## 15. Riscos e decisões pendentes

| Risco/decisão | Recomendação |
|---|---|
| Network ownership produzir falsos positivos | Correção e score gradual; nunca ban automático por um salto |
| Lag compensation ampliar alcance injusto | Histórico curto, clamp e telemetria por ping; validar em playtest |
| Trade/banco exceder capacidade de consistência | Adiar feature, não simplificar removendo escrow/ledger |
| Anti-boost punir comunidade pequena | Retorno decrescente transparente no reward e revisão antes de sanção |
| Espectador vazar posição | Atraso no topo ranqueado e dados limitados |
| Admin concentrar poder | Menor privilégio, dupla aprovação e ledger imutável |
| Logging excessivo criar risco de privacidade/DoS | Amostragem, schema mínimo e retenção explícita |
| Kill switch virar estado permanente não documentado | Dono, motivo, métrica de saída e prazo de revisão |


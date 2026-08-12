# 05 — Schemas de dados

## 1. Escopo e princípios

Este documento define os contratos-alvo de dados. O repositório já possui tipos e catálogos do esqueleto F0, mas ainda não implementa nem valida em runtime todos os agregados descritos aqui. O schema de F0 começa em `ProfileSchemaVersion = 1` e contém somente o necessário para a fatia vertical. Extensões entram por migração na fase dona da feature; troca e território são opcionais, pós-lançamento, e não condicionam F0–F6 nem o soft launch. Mudanças de balanceamento usam versões de catálogo separadas e não exigem migrar perfil quando a estrutura não muda.

Princípios:

- cliente nunca escreve estado persistente nem fornece saldo, dano, recompensa ou revisão final;
- IDs internos são estáveis, opacos e independentes do nome público/localizado;
- dados de definição são imutáveis durante uma sessão publicada e validados antes de entrar no jogo;
- perfil de jogador, clã, território, trade, torneio e ranking são agregados separados;
- toda mutação crítica possui `operationId`, revisão esperada e resultado idempotente;
- valores monetários e quantidades usam inteiros; percentuais usam basis points quando precisão for necessária;
- timestamps usam UTC Unix em milissegundos, gerados ou validados pelo servidor;
- vetores livres e CFrames não são persistidos como spawn; apenas IDs de âncoras permitidas;
- ausência de campo opcional significa default do schema, não “confiar no cliente”.

## 2. Convenções comuns

| Conceito | Formato planejado | Regra |
|---|---|---|
| ID de definição | string ASCII estável, até 64 caracteres | Nunca reutilizar para outro significado |
| ID de instância | ID global aleatório/ordenável, até 64 caracteres | Único para item, operação, partida ou guerra |
| Versão estrutural | inteiro positivo | Migração somente para frente |
| Revisão do agregado | inteiro monotônico | Incrementada no commit autoritativo |
| Quantidade | inteiro não negativo | Limite por campo e por inventário |
| Multiplicador | basis points, onde 10.000 = 100% | Ordem de aplicação documentada |
| Data/hora | inteiro UTC Unix ms | Nunca derivar de relógio do cliente |
| Enum | string de conjunto fechado | Valor desconhecido falha validação ou migra de forma explícita |
| Conjunto | mapa ID → `true` ou registro pequeno | Evitar arrays duplicados e busca linear |
| RNG | seed/resultado somente quando auditoria exigir | Loot aleatório é server-side; forja é determinística e não usa RNG |

Campos de nome público são chaves de localização, não texto canônico. Isso permite revisão legal e localização sem alterar chaves de save. PT-BR e inglês têm revisão manual no soft launch Brasil-first; outros idiomas podem usar tradução automática. Datas são persistidas em UTC e apenas formatadas no locale/fuso do jogador.

### 2.1 Famílias de energia aprovadas para o planejamento

| ID interno estável | Nome público provisório | Conceito substituído no prompt |
|---|---|---|
| `umbral_aether` | Éter Umbral | Energia amaldiçoada |
| `vital_flow` | Fluxo Vital | Chakra |
| `counterflow` | Contrafluxo | Mana inversa/antimagia |
| `metamorphic_drive` | Ímpeto Metamórfico | Vigor/transformação |

Os nomes públicos ainda passam pelo gate jurídico P1. Alterá-los troca apenas localização/apresentação; IDs e saves permanecem iguais.

## 3. Agregados e armazenamento

| Agregado | Chave conceitual | Dono de escrita | Consistência |
|---|---|---|---|
| Perfil de jogador | `player:{userId}` | Servidor com session lock do perfil | Um escritor por sessão |
| Clã | `clan:{clanId}` | ClanRepository | Update atômico por revisão |
| Índice de nome/tag de clã | `clan-index:{normalizedName}` | ClanRepository | Reserva única e compensável |
| Território futuro | `territory:{seasonId}:{regionId}` | TerritoryRepository | F7 opcional; um dono por região/revisão |
| Trade futuro | `trade:{tradeId}` | TradeService | F7 opcional; máquina de estados durável |
| Operação econômica | `operation:{operationId}` ou ledger particionado | OperationLedger | Resultado imutável/idempotente |
| Pity de boss | `boss-pity:{userId}:{bossId}:{lootTableId}` | BossLootService | Separado do item e da forja; um escritor por operação de claim |
| Torneio/partida | `match:{matchId}` | TournamentService | Estado versionado e lease ativo |
| Temporada/ranking-fonte | `season-result:{seasonId}:{userId}` | RankingService | Revisão e histórico mínimo |
| Leaderboard | chave OrderedDataStore | Projetor assíncrono | Projeção, nunca fonte de verdade |
| Moderação/risco | armazenamento operacional separado | SecurityService autorizado | Nunca dentro do payload do cliente |

MemoryStore pode manter fila, cache, rate limit multi-servidor e lease temporário. Perder MemoryStore não pode criar item, transferir território ou confirmar vitória sem fonte durável.

## 4. ProfileRoot modular

Em F0/v1 existem envelope, progressão mínima, personagens/habilidades da fatia, settings e recibos mínimos de save/reward. Os demais blocos são adicionados por migração somente quando a fase correspondente começa; não se persistem contêineres vazios de features distantes apenas para “reservar espaço”.

| Campo | Tipo conceitual | Introdução | Regras |
|---|---|---|---|
| `schemaVersion` | inteiro | F0/v1 | Começa em 1; migrado antes de expor a sessão |
| `userId` | inteiro | F0/v1 | Deve coincidir com a chave carregada |
| `revision` | inteiro | F0/v1 | Monotônico; não vem do cliente |
| `createdAt` | timestamp | F0/v1 | Imutável |
| `updatedAt` | timestamp | F0/v1 | Atualizado somente em commit |
| `lastServerSessionId` | ID | F0/v1 | Diagnóstico de lock, não autorização isolada |
| `progression` | PlayerProgression | F0/v1 mínimo; amplia F2 | Nível/XP da fatia; pontos e consolidação entram com progressão |
| `characters` | mapa characterId → CharacterProgress | F0/v1 | Um estilo em F0; mapa já evita schema descartável |
| `abilities` | mapa abilityId → AbilityProgress | F0/v1 mínimo; amplia F2 | Três habilidades em F0; maestria entra em F2 |
| `settings` | PlayerSettings | F0/v1 | Preferências não sensíveis e schema próprio |
| `recentOperations` | anel de OperationReceipt | F0/v1 mínimo; amplia F2 | Idempotência de save/reward; economia amplia retenção |
| `loadouts` / `activeLoadoutId` | mapa + ID | F1 | Referências desbloqueadas; Ressonância é recalculada |
| `wallet` | Wallet | F2 | Moeda e materiais; inteiros com caps |
| `familyMastery` | mapa família → MasteryProgress | F2 | Somente IDs das quatro famílias aprovadas |
| `inventory` / `equipment` | estados versionados | F2 | Posse, capacidade e referências coerentes |
| `inFlightOperations` | mapa operationId → PendingOperation | F2 | Somente operações econômicas interrompíveis |
| `quests` | QuestState | F3 | Ativas, concluídas e flags compactas; o objetivo único F0 usa `tutorialFlags` + receipt, sem antecipar o agregado completo |
| `reputation` | ReputationState | F4 | Valor, estado e cooldowns de recuperação |
| `clanMembership` | ClanMembershipRef opcional | F5 | Referência; ClanRecord é autoridade social |
| `ranked` | mapa seasonId → PlayerSeasonState | F6 | Histórico limitado às temporadas retidas |
| `entitlements` | EntitlementState | Hardening/soft launch | Cosméticos, emotes e +3 presets; nenhum poder ou inventário funcional pago |

Não guardar display name, chat, lista completa de kills ou telemetria bruta no perfil. Históricos sem uso transacional têm retenção externa e limitada.

### 4.1 PlayerProgression

| Campo | Tipo | Regras |
|---|---|---|
| `accountLevel` | inteiro | Derivado de XP ou validado contra a curva do catálogo |
| `consolidatedXp` | inteiro | Não é perdido na morte |
| `unconsolidatedXp` | inteiro | Parte elegível à penalidade, com cap |
| `unspentProgressionPoints` | inteiro | Emissão e consumo entram no ledger |
| `lastConsolidationAt` | timestamp opcional | Servidor controla janela/ritual de consolidação |
| `tutorialFlags` | conjunto de IDs | Flags conhecidas e limitadas |

Política aprovada para morte: treino/zona segura não perde nada; PvE livre perde 10% do `unconsolidatedXp`; PvP livre perde 15% desse XP e 5% dos materiais comuns carregados; alto risco perde 30% e 15%, respectivamente. O cap equivale a cinco minutos de ganho em zona livre e dez em alto risco. Equipamento, moeda, maestria, itens de missão, cosméticos e itens pagos nunca são perdidos. Frações e caps ficam no catálogo de regras de zona versionado.

### 4.2 Wallet

| Campo | Tipo | Regras |
|---|---|---|
| `softCurrency` | inteiro | Cap explícito; nenhum float |
| `upgradeMaterials` | mapa materialId → inteiro | Material precisa existir e respeitar stack cap |
| `recentRespecs` | anel limitado de timestamps/abilityId | Calcula os respecs dos últimos sete dias; não é produto pago no soft launch |
| `lifetimeEarnedBySource` | mapa fonte agregada → inteiro | Opcional e limitado; detecção de anomalia, não extrato completo |

Robux e recibos de Developer Product não são tratados como saldo enviado pelo cliente. Processamento futuro precisa seguir recibos idempotentes da plataforma e conceder somente benefícios permitidos. Respec usa moeda do jogo: teste gratuito por 30 minutos, primeira troca permanente gratuita por técnica e, depois, custo `min(3000, 500 + 150 × nível + 250 × respecs nos últimos 7 dias)`, com cooldown de cinco minutos e apenas em contexto seguro.

### 4.3 PlayerSettings e EntitlementState

`PlayerSettings` contém apenas preferências não sensíveis: `localeId`, acessibilidade, redução de efeitos, volumes, esquema de input e preferência de exibição de horário. `localeId` nunca muda regra, preço, agenda ou autorização; o servidor mantém UTC e envia a janela efetiva.

`EntitlementState` guarda recibos/referências verificadas da plataforma para cosméticos, emotes/finalizadores, servidor privado de treino sem progresso e `extraPresetCapacity` limitado a 3. O total de presets continua limitado a 6. Boost, respec pago, expansão funcional de inventário, moeda, gacha e material não possuem entitlement no soft launch.

## 5. Schemas de definição

### 5.1 CharacterDefinition

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID estável | Chave interna; nunca depende do nome público |
| `contentVersion` | inteiro | Versão do conteúdo para auditoria |
| `displayNameKey` / `descriptionKey` | chaves de localização | Revisão legal antes de publicação |
| `energyFamilyId` | ID de EnergyFamilyDefinition | Exatamente uma família nativa |
| `combatArchetype` | enum | Tags de balanceamento, não regra hardcoded |
| `baseStatProfileId` | ID | Perfil de stats limitado pelo modo |
| `abilityIds` | lista de IDs | Referências existentes, inclusive ultimate |
| `passiveModifierIds` | lista | Modificadores rastreáveis |
| `unlockRequirements` | expressão de requisitos validada | Missão/maestria; habilidade não é vendida por Robux |
| `presentationId` | ID | Assets/UI separados da lógica |
| `legalReviewStatus` | enum interno | Conteúdo não aprovado não entra em build pública |
| `enabled` | booleano | Kill switch de conteúdo |

### 5.2 EnergyFamilyDefinition

O conjunto aprovado de IDs aceita somente `umbral_aether`, `vital_flow`, `counterflow` e `metamorphic_drive`. O catálogo habilitado em F1 contém os três primeiros; `metamorphic_drive` entra apenas na onda pós-lançamento aprovada. Nome público vem de localização e continua sujeito a P1.

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID | Família estável |
| `poolBase` / `poolCap` | inteiro | Limites autoritativos |
| `regenRules` | registro | Em combate, fora de combate e condições |
| `depletionEffects` | lista de modificadores | Fonte e expiração explícitas |
| `gainTriggers` | lista fechada | Ex.: timing correto ou anulação validada no servidor |
| `pureResonanceProfileId` | ID | Bônus de build pura |
| `hybridDissonanceProfileId` | ID | Penalidade por mistura |
| `modifierCaps` | mapa stat → limites | Impede empilhamento ilimitado |

### 5.3 AbilityDefinition

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID estável | Nenhum sistema faz `if` por personagem |
| `contentVersion` | inteiro | Alteração de tuning rastreável |
| `displayNameKey` / `descriptionKey` | chaves | Sem nomes canônicos de terceiros |
| `sourceCharacterId` | ID | Origem de desbloqueio, não trava uso se loadout permitir |
| `energyFamilyId` | ID | Usado por ressonância e custo |
| `kind` | enum | Basic, Skill ou Ultimate |
| `slotCost` | inteiro 1–2 | Ultimate ocupa slot próprio; regra validada |
| `impactCost` | inteiro 1–12 | Soma do loadout não pode exceder o teto 12 definido pelo GDD |
| `tags` | conjunto fechado | Movimento, projétil, controle, cancelável etc. |
| `inputMode` | enum | Press, Hold, Release ou TargetPoint limitado |
| `phaseTimingsMs` | registro | Startup, active, recovery e cancel windows |
| `resourceCosts` | lista | Custo nativo por fase e política de reembolso |
| `foreignResourceCost` | inteiro positivo opcional | Obrigatório quando a técnica for importável; ausente quando a política bloqueia importação |
| `foreignFallbackPolicy` | enum/registro | `Neutral` converte para fallback registrado; `Blocked` proíbe importação explicitamente |
| `cooldown` | registro | Base, grupo e início da contagem |
| `rangePolicy` | registro | Distância, ângulo, linha de visão e alvo permitido |
| `hitPolicy` | registro | Shape, máximo de alvos e hits por alvo |
| `effectIds` | lista ordenada | Dano, controle e modificadores conhecidos |
| `masteryLevels` | níveis 1–10 | Curva exata de XP; breakpoints comportamentais em 3/6/9 e nível 10 cosmético/QoL |
| `serverRunnerId` | ID | Implementação server-side permitida |
| `clientPresentationId` | ID | VFX/animação sem regra de autoridade |
| `securityLimits` | registro | Deslocamento, duração e frequência máximos absolutos |
| `enabled` | booleano | Kill switch por habilidade |

Decisão de progressão alinhada ao GDD: dez níveis de maestria por técnica. Níveis 3, 6 e 9 liberam variações comportamentais; o nível 10 é cosmético ou qualidade de vida, sem pico de poder competitivo. Ajustes numéricos intermediários são pequenos e limitados. Os thresholds exatos de XP pertencem ao catálogo/GDD versionado e serão validados por playtest, preservando a meta de progresso útil sem grind obrigatório de centenas de horas.

### 5.3.1 ResonancePolicyDefinition

| Campo | Tipo | Regra |
|---|---|---|
| `loadoutImpactCap` | inteiro | 12 no baseline aprovado |
| `capacityUnits` | inteiro | Exatamente 4 no baseline aprovado |
| `maxDefiningTechniques` | inteiro | 1; a técnica Definidora é opcional |
| `foreignSlotWeight` | inteiro | Cada unidade de `slotCost` normal estrangeira soma 1 a D |
| `foreignUltimateWeight` | inteiro | Ultimate estrangeira soma mais 2 a D |
| `extraForeignFamilyWeight` | inteiro | Cada família estrangeira adicional soma 1 a D |
| `maxDissonance` | inteiro | 3; valor bruto acima disso invalida o loadout |
| `dissonanceProfiles` | mapa D → perfil | Pool, regen e custo de ultimate derivados pelo servidor |
| `pureResonanceProfileId` | ID | Aplicado somente quando não há técnica estrangeira |

Fórmula autoritativa: `rawD = slots estrangeiros + 2 se a ultimate for estrangeira + famílias estrangeiras adicionais`. “Estrangeiro” é comparado à família nativa do corpo ativo. O servidor rejeita o loadout quando `rawD > maxDissonance`; não existe `min(3, rawD)` como autorização. Depois do aceite, `D = rawD` seleciona o perfil correspondente. O servidor também valida capacidade total de no máximo quatro unidades, uma ultimate, no máximo uma técnica Definidora, impacto total até 12, famílias e `foreignResourceCost`; o cliente apenas exibe o resumo. Técnica nativa com custo zero precisa de custo estrangeiro positivo ou de política que proíba importação, para não virar utilidade grátis em build híbrida.

### 5.4 EffectDefinition e ModifierDefinition

Todo efeito referencia operações permitidas, sem executar script arbitrário vindo de dado.

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID | Único e versionado |
| `operation` | enum fechado | Damage, Heal, ApplyModifier, Displace, SpawnServerProjectile etc. |
| `parameters` | registro por operação | Schema específico e caps absolutos |
| `scalingProfileId` | ID opcional | Fórmula server-side conhecida |
| `targetPolicy` | enum/registro | Self, confirmedHit, areaCandidates filtrados |
| `sourceAttribution` | política | Mantém abilityId, playerId e operationId |

ModifierDefinition inclui stat, operação de combinação, prioridade, magnitude, cap, política de stack, duração e tags de dispel. A ordem recomendada é: base → aditivos → multiplicativos limitados → override explicitamente permitido → clamp final.

### 5.5 ItemDefinition

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID estável | Define tipo; item instanciado recebe outro ID |
| `contentVersion` | inteiro | Auditoria de balanceamento |
| `displayNameKey` / `descriptionKey` | chaves | Localização e revisão legal |
| `itemType` | enum | Equipment, Material, Cosmetic, Consumable |
| `rarityId` | ID | Não implica poder sem caps |
| `stackLimit` | inteiro | 1 para instâncias únicas |
| `slotType` | enum opcional | Compatível com EquipmentState |
| `abilityModifierIds` | lista | Direção principal de equipamento |
| `minorStatModifiers` | lista 0–1 | No máximo um bônus bruto por item, até 2%; conjunto até 5 p.p. positivos e atributo até 3%; removido no ranked |
| `upgradeTrack` | registro | Cinco graus determinísticos: potência 60/70/80/90/100% e custo relativo 1/2/3/5/8 |
| `sourceRules` | lista | Drop, forja, boss ou torneio |
| `tradePolicy` | enum | Bound, tradable ou cooldown de trade |
| `destroyPolicy` | enum | Confirmação/recuperação quando aplicável |
| `rankedPolicy` | enum | Permitido, normalizado ou cosmético |
| `enabled` | booleano | Kill switch |

Forja é totalmente determinística. Não há chance, roll, falha de design, destruição, rebaixamento nem pity. Uma falha técnica anterior ao commit não consome materiais; retry do mesmo `operationId` retorna o mesmo grau/recibo. Um item não pode aumentar simultaneamente ataque e sobrevivência. Pity existe somente no loot pessoal raro de boss, no agregado próprio da seção 6.11.

### 5.6 QuestDefinition

Campos: ID, versão de conteúdo, cadeia/pré-requisitos, NPC/âncora, faixa recomendada, objetivos tipados, condições de zona, janela, recompensas, política de repetição, cooldown e flags de unlock. Progresso deriva de eventos confirmados no servidor; não existe remote “somar progresso”.

## 6. Schemas de progresso do jogador

### 6.1 CharacterProgress

| Campo | Tipo | Regras |
|---|---|---|
| `unlockedAt` | timestamp | Só existe após unlock idempotente |
| `characterLevel` | inteiro | Se mantido, não duplica autoridade da maestria |
| `characterXp` | inteiro | Curva do catálogo |
| `questUnlockIds` | conjunto limitado | Referências válidas |
| `selectedCosmeticIds` | conjunto/lista | Posse verificada em entitlements/inventory |

### 6.2 AbilityProgress

| Campo | Tipo | Regras |
|---|---|---|
| `unlockedAt` | timestamp | Habilidade se conquista no jogo |
| `masteryLevel` | inteiro 1–10 | Consistente com masteryXp e com a curva versionada |
| `masteryXp` | inteiro | Incremento agregado e validado por uso elegível |
| `upgradeMaterialsSpent` | inteiro agregado opcional | Auditoria resumida |
| `behaviorUnlocks` | conjunto derivável opcional | Derivar dos níveis 3/6/9; persistir só exceções |
| `lastEligibleUseAt` | timestamp opcional | Anti-macro/telemetria com retenção mínima |

Uso contra alvos inválidos, aliados, bonecos não elegíveis ou repetição artificial não concede maestria. Os níveis 2/5/8 concedem no máximo 2% cada (6% total), removidos em ranked; o nível 10 concede apenas cosmético ou qualidade de vida. Maestria de técnica mira 3,4–4,9 horas até o nível 10; maestria de família usa 20 níveis e mira 18–24 horas em build pura ou 24–32 em híbrida.

### 6.3 MasteryProgress

Campos: `level` (1–20 para família), `xp`, `unlockedMilestones` e `lastGainAt`. O servidor atribui a família pela habilidade efetivamente resolvida. Não aceitar `familyId` livre do cliente para conceder XP. Técnica usa `AbilityProgress.masteryLevel` de 1–10; os dois limites não são intercambiáveis.

### 6.4 SavedLoadout

| Campo | Tipo | Regras |
|---|---|---|
| `id` | ID | Único dentro do perfil |
| `name` | string filtrada/limitada | Não usada como chave |
| `presetKind` | enum | PvE, World, Arena ou Custom; os três primeiros são criados como presets-base |
| `abilitySlots` | lista de 0–4 entradas | Cada entrada referencia `abilityId` e posição; a soma de `slotCost` deve ser ≤4 |
| `ultimateAbilityId` | ID | Exatamente uma ultimate elegível |
| `definingAbilityId` | ID opcional | Zero ou uma técnica Definidora elegível do loadout |
| `equipmentInstanceIds` | lista por slot | Pertence ao jogador e é compatível |
| `computedSignature` | hash/revisão opcional | Cache invalidável, nunca fonte de autoridade |
| `updatedAt` | timestamp | Servidor |

O servidor sempre recalcula capacidade, impacto, famílias, `rawD`, Ressonância/Dissonância e modificadores ao ativar. `rawD > 3` rejeita a ativação. Uma técnica normal pode consumir duas unidades, portanto `abilitySlots` não é preenchido artificialmente até quatro entradas: a soma de `slotCost`, e não a cardinalidade da lista, autoriza capacidade. O resumo calculado não precisa ser persistido. Cada perfil recebe três presets-base (`PvE`, `Mundo`, `Arena`) e pode salvar no máximo seis com entitlement de +3; o entitlement não altera as quatro unidades, o impacto ou a Dissonância.

### 6.5 InventoryState e ItemInstance

InventoryState contém `capacity`, `stackables` por definitionId, `instances` por itemInstanceId e `inventoryRevision`.

| Campo de ItemInstance | Tipo | Regras |
|---|---|---|
| `instanceId` | ID global | Nunca muda nem é reutilizado |
| `definitionId` | ID | ItemDefinition existente |
| `createdAt` | timestamp | Servidor |
| `originOperationId` | ID | Liga à fonte econômica |
| `boundToUserId` | inteiro opcional | Impede trade se bound |
| `upgradeGrade` | inteiro 1–5 | Grau determinístico dentro do track |
| `forgeReceiptOperationId` | ID opcional | Prova a última forja comprometida; retry não consome duas vezes |
| `rolledModifiers` | lista limitada | Se originados no loot, são auditáveis e imutáveis pela forja |
| `tradeLockUntil` | timestamp opcional | Servidor |
| `state` | enum | Owned, Escrow, Consumed ou Quarantined |
| `lastMutationOperationId` | ID | Diagnóstico e idempotência |

Um item em `Escrow` não pode ser equipado, consumido, destruído nem entrar em outra troca.

### 6.6 EquipmentState

Mapa de exatamente três `slotType → itemInstanceId`, mais `revision`. Invariantes: item pertence ao inventário, está `Owned`, slot é compatível, não aparece em dois slots exclusivos e respeita regras do modo. Cada item concede no máximo 2% de bônus bruto; o conjunto tem teto de 5 pontos percentuais positivos e um atributo tem teto de 3%. Um item não aumenta simultaneamente ataque e sobrevivência. Stats/modificadores derivados não são persistidos. Ranked remove bônus brutos e normaliza modificadores comportamentais ao grau 3.

### 6.7 QuestState

| Seção | Conteúdo | Limite |
|---|---|---|
| `active` | questId, definitionVersion, etapa, contadores e startedAt | Número máximo de missões ativas |
| `completed` | questId → contagem/data resumida | Compactado por política |
| `chainFlags` | conjunto de marcos | Somente IDs conhecidos |
| `scheduledEncounters` | IDs/estado estritamente necessários | Expiram e são limpos |

### 6.8 ReputationState

Campos: `score` limitado de -1.000 a +1.000, `band`, `outlawUntil`, `recoveryProgress`, `lastDecayAt` e `recentPenaltyReceipts` limitados. A reputação é por conta e compartilhada entre estilos/loadouts. O estado recente decai; histórico privado antiabuso fica fora do perfil. Bounty ativo é projeção derivada do score/regras ou registro separado; o cliente não define alvo nem valor.

O poder efetivo **não é persistido**. O servidor deriva um score 0–100 por versão de regra: 30% progressão da zona, 25% completude do loadout, 20% maestria, 15% equipamento e 10% desempenho PvP com incerteza. O grupo agressor acrescenta até 30 pontos. Um alvo é muito inferior quando a diferença ajustada é pelo menos 25 e o agressor possui pelo menos 1,35× o poder; autodefesa, bounty, duelo aceito, guerra e evento formal são exceções.

### 6.9 PlayerSeasonState

Campos: `seasonId`, `glickoRating` (inicial 1.500), `ratingDeviation` (inicial 350), `volatility` (inicial 0,06), `tau` (0,5 na política da temporada), `divisionId`, `placementMatches` (10), `wins`, `losses`, `lastRankedAt`, `decayAppliedThrough`, `normalizationVersion`, `resultRevision` e sinais agregados sob acesso restrito. OrderedDataStore contém apenas score de projeção e referência de revisão.

### 6.10 ClanMembershipRef

Campos: `clanId`, `membershipId`, `joinedAt` e `lastKnownClanRevision`. Cargo e permissões atuais vêm do agregado do clã; o cache no perfil nunca autoriza saque de banco ou declaração de guerra.

### 6.11 BossLootPityState

Registro separado por `userId + bossId + lootTableId`: `eligibleFailures` (0–9), `lastEligibleClearAt`, `lastKillId`, `lastClaimOperationId` e `lootTableVersion`. Somente clear elegível atualiza o contador. A chance rara começa em 5%, sobe 5 pontos percentuais por falha e é garantida no décimo clear elegível; obter o raro zera o contador. Material básico e ficha são garantidos. MVP/contribuição acima do mínimo não aumenta chance rara. Esse estado nunca aparece em `ItemInstance` nem no track de forja.

A contribuição de boss é estado de sessão server-side: dano, cura efetiva, mitigação, controle, interrupções, objetivos e presença. O claim é elegível ao atingir primeiro 40% da duração do encontro ou 90 segundos de presença, mais contribuição equivalente a 1% da vida do boss. O cliente não envia score agregado nem escolhe a tabela.

## 7. ClanRecord v1

| Campo | Tipo | Regras |
|---|---|---|
| `schemaVersion` | inteiro | Migração independente do perfil |
| `clanId` | ID global | Imutável |
| `revision` | inteiro | Controle otimista/fencing |
| `normalizedName` / `normalizedTag` | string | Reserva única, filtro e limites |
| `displayName` / `tag` | string filtrada | Nunca concede unicidade por capitalização |
| `emblemId` | ID permitido | Sem asset arbitrário não revisado |
| `createdAt` / `createdBy` | timestamp/UserId | Auditoria |
| `level` / `xp` | inteiros | Curva de clã |
| `members` | mapa userId → ClanMember | Cap de membros |
| `roles` | três cargos públicos | Líder, Oficial e Membro, com permissões granulares de conjunto fechado |
| `perks` | mapa perkId → nível | Validação de pré-requisito |
| `bank` | ClanBankState limitado | F5 aceita apenas suprimentos vinculados; sem saque livre ou bens pessoais |
| `territoryRefs` | conjunto de regionIds | Vazio até F7 opcional; depois, cache da fonte autoritativa |
| `activeWarIds` | conjunto limitado | WarRecord é fonte de verdade |
| `settings` | registro | Convites e políticas permitidas |
| `recentOperations` | anel de recibos | Idempotência limitada |

ClanMember inclui `membershipId`, `roleId`, `joinedAt`, `contribution` agregado e `lastRoleChangeAt`. ClanRole usa apenas Líder, Oficial ou Membro e permissões fechadas. Transferência de liderança espera 72 horas, dissolução espera sete dias e gasto acima de 25% dos suprimentos espera 24 horas. Nenhum cargo pode conceder permissão fora do enum do servidor.

ClanBankState contém saldos, itens em instância, capacidade, `bankRevision` e ponteiro para ledger. Saque e depósito usam operação durável; “alterar saldo para X” não é um comando válido.

## 8. TerritoryRecord e WarRecord — F7 opcional pós-lançamento

### 8.1 TerritoryRecord

Campos: `schemaVersion`, `seasonId`, `regionId`, `revision`, `ownerClanId`, `ownershipStartedAt`, `ownershipEndsAt`, `warId`, `bonusProfileId` e `lastOperationId`. A região tem um único registro autoritativo; a lista no clã é apenas cache reconciliável. O bônus concede no máximo 5% de material comum e nunca item raro ou poder.

### 8.2 WarRecord

Campos: `warId`, `schemaVersion`, `revision`, `attackerClanId`, `defenderClanId`, janela UTC, objetivo/regionId, roster congelado, estado, scores confirmados, servidores de partida, resultado, operationId de liquidação e timestamps. Transições permitidas: Scheduled → Locked → Active → Resolving → Settled, com Cancelled/Disputed por caminhos explícitos.

## 9. TradeRecord e saga anti-dupe — F7 opcional pós-lançamento

Roblox não fornece uma transação global simples entre dois perfis. A troca deve ser uma saga com escrow e compensação, não dois saves independentes “quase ao mesmo tempo”.

| Campo | Tipo | Regra |
|---|---|---|
| `tradeId` | ID | Também funciona como operationId raiz |
| `schemaVersion` / `revision` | inteiros | Estado versionado |
| `participantUserIds` | dois UserIds | Congelado ao criar |
| `offers` | mapa UserId → itens/moedas | IDs e quantidades reservados |
| `offerRevisions` | mapa | Qualquer alteração invalida confirmações |
| `confirmations` | mapa | Ligadas à revisão exata da oferta |
| `escrowReceipts` | mapa | Prova de reserva em cada perfil |
| `state` | enum | Draft, Locked, Escrowing, Committing, Committed, Compensating, Cancelled, Disputed |
| `createdAt` / `expiresAt` | timestamps | Expiração server-side |
| `commitReceipts` | mapa | Retry retorna resultado anterior |
| `failureReason` | enum opcional | Sem dados sensíveis para cliente |

Invariantes:

- um itemInstanceId só pode estar Owned por um perfil ou em um escrow, nunca ambos;
- confirmação é anulada por qualquer mudança de oferta;
- disconnect não confirma trade;
- retry de reserva, commit ou compensação é idempotente;
- operação inconclusiva bloqueia os ativos envolvidos e vai para reconciliação;
- histórico visível usa resumo; ledger técnico fica separado e com retenção controlada.

Não existe troca, presente, empréstimo ou drop de item no lançamento. O mercado futuro começa apenas com materiais e projetos não vinculados e só depois de 30 dias sem dupe crítico, retries/reconexões reconciliados e menos de 0,1% das operações exigindo reparo manual. Além disso, testes devem injetar crash após cada transição e provar ausência de dupe/perda.

## 10. TournamentMatchRecord

Campos: `matchId`, `tournamentId`, `seasonId`, `schemaVersion`, `revision`, modo, faixa, participantes, snapshot permitido de loadout, `normalizationVersion`, servidor reservado, hashes de tokens de teleporte, presença, rounds, resultado, motivo de encerramento, estado de disputa, `rewardOperationIds` e timestamps.

Ranked e torneio normalizam HP, dano, guarda, recurso, ganhos numéricos de maestria, atributos brutos e refinamento; preservam habilidades desbloqueadas, composição do loadout, Dissonância e variantes comportamentais legais. Modificadores de equipamento preservados são normalizados ao grau 3. O snapshot versionado é reconstruído pelo servidor; o cliente nunca envia o equipamento “que deveria valer”. Dois loadouts de empréstimo versionados ficam disponíveis como fallback competitivo.

## 11. Versionamento de catálogo

Cada pacote de conteúdo possui:

- `catalogSchemaVersion`: estrutura das definições;
- `contentReleaseId`: release publicada e imutável;
- `balanceVersion`: tuning usado por telemetria/replay;
- hashes por definição ou pacote;
- data de ativação e conjunto de flags/kill switches.

Uma execução de habilidade retém a versão com que começou até terminar, evitando mudar regra no meio do cast. Servidores não misturam releases incompatíveis em torneio.

Remover definição segue três etapas: desabilitar aquisição, migrar/reembolsar referências existentes e somente depois retirar do catálogo suportado. ID removido nunca é reciclado.

## 12. Migrações

### 12.1 Regras

1. Migrações são ordenadas, determinísticas e somente `N → N+1`.
2. O perfil é copiado em memória, migrado e validado antes de substituir o estado da sessão.
3. Migração não chama remote, não depende de relógio do cliente e não concede recompensa sem operationId.
4. Repetir a mesma migração produz o mesmo resultado lógico.
5. Campo desconhecido não é descartado silenciosamente sem decisão de compatibilidade.
6. Falha coloca o perfil em quarentena operacional; nunca carrega defaults sobre a chave existente.
7. Cada versão tem fixtures de casos mínimo, típico, máximo e parcialmente legado.
8. Métricas registram versão de origem, destino, duração e motivo de falha.

### 12.2 Fluxo de load

Load com session lock → validar chave/UserId → detectar versão → executar cadeia → validar invariantes/tamanho → reconciliar operações pendentes → expor sessão → salvar no próximo commit seguro.

### 12.3 Exemplo de evolução planejada

| Mudança | Estratégia |
|---|---|
| Array de habilidades vira mapa | Deduplicar por ID, preservar maior progresso válido e registrar conflito |
| Item stackável vira instanciado | Criar IDs determinísticos a partir de operationId de migração e índice, com cap |
| Reputação ganha bandas | Manter score e derivar banda; nenhum reset |
| Item removido por balance/legal | Converter por tabela explícita ou reembolsar via operação idempotente |
| Loadout passa a usar custo 2 | Manter como inválido-inativo e pedir ajuste; não apagar escolhas |

Rollback de código precisa continuar lendo a última versão já escrita ou ser impedido por gate de deploy. Não existe “desmigrar” automaticamente saves de produção.

## 13. Locking, revisão e idempotência

### 13.1 Perfil

- session lock via ProfileStore/equivalente;
- lease pertence a um JobId/sessionId e é liberado em saída normal;
- takeover somente pelas regras seguras da biblioteca e após timeout confirmado;
- perfil sem lock não aceita mutação;
- `revision` aumenta no commit lógico e aparece nos deltas ao cliente.

### 13.2 Agregados multi-servidor

- `UpdateAsync`/operação atômica equivalente valida revisão atual;
- lease em MemoryStore reduz contenção, mas um fencing token impede escritor antigo após expiração;
- toda decisão compara revisão/fencing dentro da escrita durável;
- conflito recarrega e reavalia o comando; não reaplica deltas cegamente.

### 13.3 Idempotência

OperationReceipt contém `operationId`, tipo, estado, hash canônico da intenção, revisões antes/depois, deltas resumidos e timestamps. Reusar ID com payload diferente é rejeitado e sinalizado. Reusar com payload igual retorna o resultado anterior.

Retenção:

- anel pequeno no perfil para operações recentes;
- ledger durável particionado para compra, trade, banco, boss raro, torneio e respec;
- operações triviais de combate não geram recibo persistente individual;
- TTL só remove recibo quando nenhuma saga ou retry válido ainda depende dele.

## 14. Budgets e limites internos

| Item | Budget inicial | Comportamento ao atingir |
|---|---:|---|
| Perfil serializado | alvo 256 KiB; alerta em 80% | Compactar histórico e bloquear expansão não essencial |
| Loadouts salvos | 3 base; máximo 6 com entitlement de +3 | Rejeitar novo sem apagar antigo; nunca ampliar slots/impacto |
| Item instances | 200 base por perfil | Capacidade/depósito futuro; nunca truncar |
| Tipos stackáveis | 256 IDs ativos | Catálogo/itens obsoletos são convertidos explicitamente |
| Missões ativas | 20 | Exigir abandonar/concluir |
| Recibos recentes no perfil | 128 | Arquivar críticos e remover apenas finalizados |
| Operações em voo | 16 | Bloquear nova operação econômica e alertar |
| Membros de clã | 20 iniciais; máximo 40 por progressão | Rejeitar convite antes de cobrar custo |
| Itens no banco | Hard cap explícito por clã | Rejeitar depósito sem mover ativo |

Metas de capacidade são hipóteses de lançamento e precisam de teste com serialização real. Caps nunca autorizam truncamento automático de ativo econômico.

Budget de requisições:

- um load principal por join e saves coalescidos;
- autosave com jitter e prioridade para perfis dirty;
- sem escrita por uso de habilidade, hit, tick de maestria ou atualização de UI;
- acumular XP/maestria em sessão e persistir em lote com limites anti-abuso;
- OrderedDataStore atualizado por projeção limitada, não a cada mudança de MMR;
- retries exponenciais com jitter e deadline; falha encerrada não vira sucesso local;
- quando budget estiver baixo, mercado/troca/banco podem ficar somente leitura antes de arriscar integridade.

## 15. Validação e reparo

Ao carregar, validar:

- tipos, profundidade, quantidade de chaves e tamanho total;
- UserId/chave e versões;
- números finitos, inteiros e dentro de caps;
- referências a catálogo e unicidade de IDs;
- item em exatamente um estado/proprietário;
- equipamento contido no inventário;
- loadout sem duplicação proibida e com referências desbloqueadas;
- loadout com capacidade total até quatro unidades, impacto até 12, no máximo uma técnica Definidora e `rawD <= 3`;
- saldos não negativos e operações em voo reconhecidas;
- membership coerente com ClanRecord por reconciliação assíncrona.

Reparo automático só ocorre quando existe regra inequívoca e sem criação de valor, como remover referência cosmética inexistente. Conflito econômico, item duplicado ou migração ambígua entra em quarentena e ferramenta operacional auditada.

## 16. Exclusão, privacidade e recuperação

- armazenar apenas dados necessários ao jogo e segurança;
- fornecer fluxo operacional de exclusão por UserId que percorra perfil, índices e referências permitidas;
- contribuição histórica de clã/leaderboard pode ser anonimizada conforme política, sem quebrar contabilidade;
- backups e snapshots operacionais têm acesso restrito e retenção definida;
- restauração nunca copia perfil antigo sobre um perfil ativo sem lock, revisão e reconciliação de operações posteriores;
- logs não contêm payload integral, chat, tokens ou dados pessoais desnecessários.

## 17. Critérios de pronto para schemas

- todos os campos têm tipo, default, cap, dono e regra de validação;
- catálogos recusam ID duplicado, referência órfã, ciclo inválido e valor fora dos limites;
- fixtures de todas as versões migram e reabrem com invariantes válidas;
- serialização máxima fica dentro do budget interno;
- retries de compra, reward, respec, forja determinística, trade futuro e banco não duplicam valor;
- concorrência de dois servidores não produz dupla sessão, dois donos de item ou dois donos de território;
- falha em qualquer ponto da saga de trade é compensada ou fica bloqueada para reconciliação;
- OrderedDataStore pode ser reconstruído a partir da fonte de verdade;
- nomes públicos/localização podem mudar sem tocar em IDs persistidos.
- nenhum campo de item/forja contém pity; pity raro existe apenas em `BossLootPityState`.

## 18. Riscos de implementação monitorados

| Risco | Decisão/mitigação |
|---|---|
| Perfil crescer com inventário e histórico | Caps desde o início; históricos/ledger separados |
| Cross-profile trade não ser atômico | Manter fora do lançamento; F7 usa saga com escrow somente após gates |
| Cache de cargo no perfil autorizar ação indevida | ClanRecord sempre decide permissão |
| Catálogo remover conteúdo possuído | Processo de depreciação e reembolso idempotente |
| Migração irreversível bloquear rollback | Gate de deploy compatível e rollout gradual |
| Maestria por uso incentivar macro | Elegibilidade por evento confirmado e ganho limitado por contexto |
| ProfileService/equivalente mudar | Adaptador e testes de contrato da persistência |

# 10 — Referências de mercado e critérios de produto

## 1. Objetivo e limites

Este documento registra a evidência usada para consolidar as decisões de produto em
2026-08-12. Ele não transforma concorrentes em especificação e não autoriza copiar
personagens, roupas, silhuetas, golpes, VFX, áudio, narrativa ou interface.

Os números de concorrência mudam a cada minuto; visitas e favoritos são cumulativos.
Por isso, a tabela é um **snapshot datado**, não um dashboard nem uma promessa de
escala. A fonte de verdade das decisões continua sendo
[09-OPEN-QUESTIONS.md](09-OPEN-QUESTIONS.md).

## 2. Snapshot oficial — 2026-08-12, aproximadamente 13:52 BRT

Dados consultados no endpoint público da Roblox:
[API de experiências](https://games.roblox.com/v1/games?universeIds=994732206,3808081382,3508322461,5578556129,6325068386)
e [API de votos](https://games.roblox.com/v1/games/votes?universeIds=994732206,3808081382,3508322461,5578556129,6325068386).

| Experiência | Jogando no snapshot | Visitas | Favoritos | Aprovação | Máx. por servidor |
|---|---:|---:|---:|---:|---:|
| Blox Fruits | ~372 mil | 63,42 bi | 19,58 mi | 92,22% | 12 |
| Jujutsu Shenanigans | ~140 mil | 6,77 bi | 2,86 mi | 86,62% | 20 |
| The Strongest Battlegrounds | ~60 mil | 18,94 bi | 7,50 mi | 83,88% | 15 |
| Anime Vanguards | ~21 mil | 2,01 bi | 1,98 mi | 96,74% | 24 |
| Blue Lock: Rivals | ~21 mil | 4,88 bi | 6,18 mi | 96,63% | 10 |

Blox Fruits venceu Best Action RPG e The Strongest Battlegrounds venceu Best Fighting
Experience no Roblox Innovation Awards 2024, conforme o
[registro oficial no Developer Forum](https://devforum.roblox.com/t/roblox-innovation-awards-2024-winners/3152047).
Prêmios e visitas demonstram alcance, não provam que toda mecânica desses jogos seja
adequada a este produto.

## 3. Padrões aproveitados

### 3.1 Ação antes da complexidade

Jogos de combate bem-sucedidos comunicam controles e fantasia rapidamente. A Roblox
recomenda que o first-time user experience leve o usuário à parte divertida em até
cinco minutos, e relaciona D1 ao onboarding e D7 ao sistema de progressão:
[Retention](https://create.roblox.com/docs/production/analytics/retention).

Aplicação no projeto:

- primeiro combate em até 60 segundos;
- objetivo de progressão visível em até 3 minutos;
- primeira técnica permanente em até 5 minutos;
- sistemas de build, equipamento e economia aparecem gradualmente;
- o jogador começa limitado, mas não começa sem uma fantasia de ação.

### 3.2 Servidores compactos

O snapshot mostra líderes usando 10–24 pessoas por servidor. O plano, portanto, inicia
em 16, mede encontros de 6–8 combatentes e só promove 20/24 após profiling. “MMO” é
persistência, mundo e relações duradouras; não exige colocar dezenas de avatares na
mesma simulação física.

### 3.3 Progressão persistente com expressão

Blox Fruits evidencia demanda por exploração, treino, bosses e descoberta; TSB/JJS
evidenciam demanda por combate legível, dash, guarda, kits e estados de despertar. A
síntese escolhida é Action RPG persistente com combate de battlegrounds, e não dois
jogos separados.

O gênero público recomendado é **RPG → Action RPG**, definido pela Roblox como RPG
focado em combate em tempo real:
[Experience genres](https://create.roblox.com/docs/production/publishing/experience-genres).
“Battlegrounds” permanece no nome, mas store page, ícone e primeiros minutos precisam
deixar claro que há progressão e mundo.

### 3.4 Retenção e descoberta por qualidade de sessão

Visitas históricas isoladas não medem saúde atual. A Roblox descreve sinais como
qualified play-through rate, tempo em sete dias, dias jogados e co-play intencional:
[Discovery](https://create.roblox.com/docs/production/promotion/discovery).

O plano mede:

- abandono em 60 segundos, 3 minutos e 5 minutos;
- conclusão do primeiro objetivo;
- D1, D7 e D30 por plataforma/coorte;
- dias jogados e sessões qualificadas;
- entrada voluntária com amigos e participação em party/clã;
- percepção correta de “Action RPG persistente”, não arena de round.

### 3.5 Conteúdo sustentável

Para 1–3 pessoas, live ops não pode depender de personagem semanal. Depois do
lançamento, o baseline é:

- melhoria pequena, rotação ou qualidade de vida a cada 4–6 semanas;
- expansão maior a cada 3–4 meses, somente se a capacidade observada permitir;
- eventos construídos sobre sistemas existentes;
- nenhum calendário público antes de medir o custo completo de uma habilidade.

A documentação da Roblox recomenda combinar conteúdo, expansões, correções e QoL,
ajustando a frequência à capacidade da equipe:
[LiveOps essentials](https://create.roblox.com/docs/production/game-design/liveops-essentials).

## 4. Padrões que não serão copiados

- gacha ou rolagem paga de personagem/poder;
- grind usado para esconder falta de conteúdo;
- status vertical sem teto que decide PvP;
- servidor grande à custa de frame, legibilidade ou latência;
- troca direta antes de ledger, escrow, suporte e anti-dupe;
- urgência falsa, countdown reiniciado ou oferta que explora menores;
- dependência de expressão protegida como único motivo de interesse.

Itens aleatórios pagos exigem odds reais e tratamento por usuário via PolicyService:
[Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items).
A direção inicial exclui esse modelo.

## 5. Propriedade intelectual e licenciamento

A decisão do dono aceita conscientemente o risco de manter kits e apresentação
próximos das referências. Este benchmark não chama essa escolha de segura. P1 continua
bloqueando assets públicos, marketing e publicação até revisão especializada.

A Roblox oferece License Manager e catálogo de licenças para acordos formais com
detentores de IP:
[Roblox licensing platform](https://about.roblox.com/newsroom/2025/07/roblox-launches-new-licensing-platform-for-experiences).
Licença disponível, parecer jurídico ou redesign são rotas possíveis; trocar só nomes
não é evidência suficiente de autorização.

## 6. Localização e operação

O soft launch é Brasil-first, com PT-BR e inglês revisados manualmente. Strings usam
chaves desde F0, imagens não embutem texto crítico e datas são armazenadas em UTC.
Tradução automática pode ampliar acesso sem criar promessa de suporte:
[Localization](https://create.roblox.com/docs/production/localization) e
[Automatic translations](https://create.roblox.com/docs/production/localization/automatic-translations).

## 7. Quando atualizar este snapshot

Atualizar a tabela somente em marcos:

1. aprovação final de P0;
2. entrada no soft launch;
3. gate de lançamento público;
4. revisão anual de posicionamento.

Cada atualização preserva a data anterior ou o commit que a continha. Não reescrever
retrospectivamente a evidência usada para tomar uma decisão antiga.

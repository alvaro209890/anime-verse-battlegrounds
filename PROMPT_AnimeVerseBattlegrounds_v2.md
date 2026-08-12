# PROMPT v2 — Anime Verse Battlegrounds (planejamento inicial)

---

## PAPEL

Você é um engenheiro sênior de Roblox (Luau) + game designer. Você tem acesso de escrita à pasta deste repositório (`Anime-Verse-Battlegrounds`). Sua tarefa **nesta rodada** é produzir o **plano de desenvolvimento inicial** e o **esqueleto do projeto** — não é implementar o jogo inteiro.

Trabalhe de forma incremental e commitável: muitos arquivos pequenos e bem nomeados, não poucos arquivos gigantes.

---

## O QUE ESTE JOGO É

**Nome:** Anime Verse Battlegrounds
**Plataforma:** Roblox (Luau), PC + mobile + console
**Gênero real:** action MMO de mundo aberto com combate estilo battlegrounds

Atenção: apesar do nome, **isto não é um arena fighter puro**. É um MMO de progressão com PvP de mundo aberto, loadout customizável, equipamento, clãs e reputação. O nome é escolha de marketing (busca no Roblox), não descrição de gênero. Planeje como MMO.

**Referências:** Deepwoken e Blox Fruits (estrutura, progressão, PvP de mundo aberto) + The Strongest Battlegrounds e Jujutsu Shenanigans (feeling do combate)

**Loop principal:**
> explorar mundo aberto → fazer missões e derrotar bosses → desbloquear e upar habilidades → montar loadout → comprar/forjar equipamento → testar em PvP de mundo aberto → provar valor em torneio ranqueado → subir no ranking e no clã → repetir com build nova

**Curva de poder:** o jogador **começa fraco de propósito**. Minuto 1 ele tem soco básico e um dash. Hora 20 ele tem loadout montado, equipamento upado e identidade de build própria. A progressão é o produto.

---

## RESTRIÇÃO LEGAL — LEIA ANTES DE TUDO

Os personagens são **inspirados** em animes existentes. **Nunca** use no jogo, na UI, nos assets, nos nomes públicos ou no título:

- Nomes reais de personagens (Gojo, Naruto, Sukuna, Eren, Kashimo...)
- Nomes de franquias (Jujutsu Kaisen, Naruto, Attack on Titan, Black Clover...)
- Nomes canônicos de técnicas (Rasengan, Hollow Purple, Amaterasu, Malevolent Shrine...)

**Regra:** nomes reais existem **somente como codinome interno** em comentário e chave de dado, como referência de balanceamento. Tudo que o jogador vê é renomeado.

Se algum nome sugerido abaixo ainda soar arriscado, **troque e me avise**.

---

## ROSTER INICIAL

`codinome interno` → `nome público` → família de energia → fantasia de combate

| Codinome | Nome público | Energia | Fantasia |
|---|---|---|---|
| gojo | **Ilimitado** | Energia Amaldiçoada | zoner/controle, barreira que nega contato, vácuo, ult devastadora |
| sukuna | **Rei das Maldições** | Energia Amaldiçoada | melee brutal, cortes à distância, domínio de área |
| yuji | **Recipiente** | Energia Amaldiçoada | bruiser, combos rápidos, crítico por timing perfeito |
| kashimo | **Âmbar** | Energia Amaldiçoada | eletricidade, velocidade extrema, descarga em área, alto risco/alta recompensa |
| asta | **Antimagia** | Mana (inversa) | anti-caster: nega e absorve habilidade inimiga, espada pesada, sem regen próprio |
| eren | **Colosso** | Vigor / Transformação | tanque transformável, muda de escala, endurecimento, ult de pouco controle |
| naruto | **Vórtice** | Chakra | clones, esfera de energia, modo desperto (buff temporário) |
| sasuke | **Presságio** | Chakra | precisão, perfuração elétrica, contra-ataque por leitura, chama negra |
| hashirama | **Arvoredo** | Chakra | controle de mapa, cura, estruturas invocadas |
| tobirama | **Maré** | Chakra | água, teleporte por marcador, aliados temporários |
| minato | **Fulgor** | Chakra | mobilidade extrema, teleporte marcado, burst rápido |
| obito | **Fenda** | Chakra | intangibilidade temporária, reposicionamento, sucção de área |
| madara | **Soberano** | Chakra | late game, avatar gigante defensivo, ult de meteoro |

O roster fica em **arquivo de dado**, nunca hardcoded. Adicionar personagem novo não pode exigir tocar em sistema.

---

## SISTEMA DE ENERGIA

Um `ResourceSystem` genérico, com perfis configuráveis por família:

**Chakra** — pool grande, regen constante e moderada, custo previsível. Zerar causa exaustão: dano recebido sobe, velocidade cai.

**Energia Amaldiçoada** — pool menor, regen lenta em combate e rápida fora. Tem **fluxo**: acertar golpe no timing certo devolve energia e habilita variação mais forte da habilidade. Premia jogador bom, pune spam.

**Mana / Antimagia** — não regenera passivamente. Enche ao **anular ou tankar** habilidade inimiga. O kit inteiro gira em torno disso.

**Vigor / Transformação** — barra que drena enquanto transformado. Fora da transformação, é stamina de movimento e guarda.

Requisitos técnicos:
- Autoridade **100% no servidor**. Cliente só prevê visual.
- Custo, cooldown e regen todos em data. Zero número mágico no meio da lógica.
- Modificador empilhável (buff/debuff/equipamento/passiva) com fonte rastreável e expiração.
- Eventos observáveis (`ResourceChanged`, `ResourceDepleted`) pra UI e VFX reagirem sem polling.

---

## LOADOUT E RESSONÂNCIA — sistema central, resolva isso primeiro

O jogador **mistura habilidades de vários personagens** que desbloqueou. Sem freio, isso quebra o jogo: Ilimitado (barreira que nega contato) + Fulgor (teleporte) + Soberano (ult gigante) num build só é fim de jogo.

**Solução proposta — Ressonância.** Cada personagem pertence a uma família de energia. O corpo do jogador não é nativo de duas ao mesmo tempo.

- Loadout tem **4 slots de habilidade + 1 ultimate**
- Cada habilidade tem **custo de slot** (habilidades definidoras custam 2 slots)
- **Build pura** (tudo da mesma família): ganha bônus de ressonância — regen melhor, cooldown reduzido, passiva da família liberada
- **Build híbrida**: paga taxa de dissonância — pool menor, regen pior, ultimate mais caro. Continua viável e é a build de utilidade, mas nunca domina o topo

Isso resolve o balanceamento **e** mantém a lógica dos animes que eu pedi: chakra e energia amaldiçoada são sistemas incompatíveis, e o jogo trata assim.

Avalie essa proposta criticamente. Se tiver alternativa melhor (orçamento de pontos, restrição por classe, decaimento de sinergia), argumente e me apresente as duas.

**Progressão de habilidade:** habilidade sobe de nível com uso e com item de upgrade.
- Defina se o nível muda **só número** (dano/cooldown) ou **destrava comportamento** (na maestria, o dash vira dash duplo). Recomendação: comportamento, porque número puro deixa build antiga obsoleta.
- Defina o teto e a curva. Precisa ser caro subir, mas nunca "grind de 200h ou você é inútil".
- Precisa existir **respec** pago. Jogador vai errar build e não pode ficar preso.

---

## MUNDO ABERTO

### Zonas
- Regiões temáticas por nível recomendado (não copiar nome de anime)
- **Zonas seguras**: PvP desligado, guarda NPC, ponto de spawn, forja, mercado, quadro de missão, entrada de torneio. É onde o jogador respira e socializa.
- **Zonas livres**: PvP ligado, loot melhor, boss de mundo, evento raro. Risco alto, recompensa alta.
- **Zonas de alto risco**: PvP ligado + penalidade de morte aumentada + o melhor loot do jogo
- A transição entre zona segura e livre precisa ser **óbvia e visível**. Ninguém pode ser morto sem saber que entrou em área PvP.

### Missões
- NPCs com cadeia de missão que **desbloqueiam habilidade** — habilidade se conquista, nunca se compra com Robux
- Tipos: caça, boss de mundo, coleta, desafio de tempo, encontro raro com spawn agendado, escolta
- **Maestria de família**: usar chakra sobe maestria em chakra, o que barateia desbloqueio de personagens da mesma família. Reforça o incentivo de build pura.

### Equipamento
Escolha uma direção e defenda no doc:
- **(A)** Equipamento dá status bruto (ATK/DEF/vida) — simples, mas gera power creep e mata o PvP
- **(B)** Equipamento **modifica habilidade** (ex: "seu dash deixa rastro elétrico", "sua barreira reflete 20%") — mais trabalhoso, muito melhor pro PvP e pra identidade de build

**Recomendação forte: (B)**, ou (B) com uma pitada mínima de (A).

Cobrir: fonte (drop, forja, boss, torneio), raridade, upgrade com risco de falha, troca entre jogadores (e o risco de scam e de economia inflacionada que isso traz), e limite de slot.

---

## PvP, REPUTAÇÃO E PENALIDADE DE MORTE

PvP acontece **no mundo aberto e nas arenas**. São contextos diferentes e precisam de regras diferentes.

**Reputação** — resolve o problema de veterano farmando novato:
- Matar jogador muito abaixo do seu nível derruba reputação com força
- Reputação baixa = marcado como fora da lei: guarda ataca em zona segura, acesso a mercado bloqueado, recompensa (bounty) na sua cabeça que qualquer um pode caçar
- Reputação alta = desconto de vendedor, missão exclusiva, cosmético de status
- Recuperar reputação leva tempo, não Robux

**Penalidade de morte no mundo aberto:** defina e justifique. Opções: perde parte do XP não consolidado, dropa recurso (não equipamento), timer de respawn crescente. **Não drope equipamento** — mata a retenção.

**Anti-abuso:** detectar farm de bounty combinado, kill trading e camping de spawn.

---

## CLÃS E GUILDAS

- Criação de clã com custo, hierarquia de cargo, banco compartilhado, emblema e tag
- Progressão de clã: nível, perk desbloqueável, buff pros membros
- **Guerra de clã**: declaração, janela agendada, objetivo de território
- **Território**: clã dono de uma região ganha bônus de recurso e chance de drop. Dá motivo real pra guerra.
- Leaderboard de clã separado do individual
- Chat e sistema de convite dentro do jogo

---

## TORNEIOS

- Agendados por horário real (ex: a cada 2h) com contagem regressiva global visível
- Inscrição, bracket, matchmaking por faixa de rank
- Servidor de arena dedicado, modo espectador, premiação (cosmético e material de upgrade — **nunca poder direto**)
- **Decisão a tomar:** o torneio usa o loadout e equipamento que o jogador construiu, ou **normaliza** tudo pra medir só habilidade? Argumente. Meio-termo possível: casual usa build própria, ranqueado de topo normaliza equipamento mas mantém loadout.
- Definir forfeit, reconexão e o que acontece quando jogador some no meio do bracket

---

## RANKING

- MMR/ELO por temporada, com decaimento por inatividade
- Divisão visível (Bronze → topo), leaderboard global via OrderedDataStore
- Leaderboard separados: torneio, ranked casual, clã, bounty
- Anti-boost: detectar conluio e win trading

---

## PERSISTÊNCIA

Esse jogo tem estado **muito** mais pesado do que um battlegrounds. Perfil precisa guardar: personagens desbloqueados, nível de cada habilidade, loadouts salvos, inventário e equipamento, moeda, progresso de missão, reputação, MMR, clã, maestria por família.

- **ProfileService** ou equivalente com session locking. Nunca DataStore cru.
- Schema **versionado com migration path** desde o dia 1 — ele vai mudar, e perder save de jogador é morte súbita do jogo
- Nunca confiar em dado vindo do cliente
- Planejar limite de requisição do DataStore com esse volume de dado

---

## ANTI-EXPLOIT

- Modelo de ameaça escrito: o que um exploiter tentaria em cada sistema
- Validação de distância, cooldown e rate limit em **todo** remote
- Sanity check de posição e velocidade
- Atenção especial: duplicação de item, teleporte pra zona de nível alto, spoof de dano

---

## MONETIZAÇÃO (só planejar, não implementar)

Cosmético, skin, slot extra de loadout, boost de XP, expansão de inventário, ticket de respec.
**Regra dura:** nada que venda poder direto em PvP ranqueado.

---

## STACK TÉCNICA

Use e justifique no doc de arquitetura:

- **Rojo** — sync filesystem ↔ Studio
- **Wally** — gerenciador de pacote
- **luau-lsp** — type checking, `--!strict` nos módulos core
- **Selene + StyLua** — lint e format, config commitada
- **ProfileService** — persistência
- Framework: avalie **Knit** vs arquitetura própria service/controller. Escolha uma e explique.
- GitHub Actions com lint + type check no push

---

## ENTREGÁVEIS DESTA RODADA

```
docs/
  00-VISION.md            visão, pilares, público, loop principal, curva de poder
  01-GDD.md               combate, energia, loadout/ressonância, progressão, equipamento
  02-WORLD.md             zonas, zona segura, missão, boss, economia de recurso
  03-SOCIAL.md            reputação, clã, guerra, território, torneio, ranking
  04-ARCHITECTURE.md      módulos, fluxo cliente/servidor, decisões e trade-offs
  05-DATA-SCHEMA.md       perfil, habilidade, personagem, item, clã, versionamento
  06-ROADMAP.md           fases, dependências, critério de pronto
  07-SECURITY.md          modelo de ameaça e regras de validação
  08-ROSTER.md            codinome → nome público → kit → notas de balanceamento
  09-OPEN-QUESTIONS.md    o que ficou indefinido e precisa de decisão minha
src/
  server/
  client/
  shared/
default.project.json
wally.toml
selene.toml
stylua.toml
.luaurc
README.md
.github/workflows/ci.yml
```

Além dos docs:

1. **Esqueleto de código que compila** — services vazios com assinatura e contrato comentado, sem implementação completa
2. **Uma habilidade completa de exemplo** (sugestão: dash-strike do Recipiente), do `AbilityDefinition` até o runner no servidor. Vira o molde de todas as outras.
3. **Spec do formato de habilidade** documentada, pra qualquer pessoa adicionar habilidade nova só escrevendo data
4. **Protótipo em papel do sistema de ressonância**: uma tabela mostrando 3 builds puras e 3 híbridas com os números resultantes, provando que híbrido é viável mas não dominante

---

## ROADMAP — exigência de escopo

Este projeto é grande demais pra atacar de frente. O roadmap **precisa** começar por uma fatia vertical:

**Fase 0 (fatia vertical):** 1 personagem, 3 habilidades, 1 sistema de energia, 1 zona pequena com 1 zona segura, PvP funcionando, save funcionando. Ponta a ponta, jogável.

Só depois: mais personagens → loadout e ressonância → progressão de habilidade → equipamento → missão e mundo → reputação → clã → torneio → ranking.

Se você achar que alguma coisa deste documento é escopo demais até pra fase 2, **diga**. Prefiro plano honesto a plano bonito.

---

## COMO TRABALHAR

- **Não invente decisão silenciosamente.** Onde houver escolha relevante, liste as opções, recomende uma e explique o trade-off.
- **Discorde de mim quando eu estiver errado.** Se algum sistema daqui conflita com outro ou é furada, fala. Especialmente se ressonância não fechar a conta.
- **Nada de código placeholder que finge funcionar.** Incompleto leva `-- TODO:` explícito.
- Direto. Sem preâmbulo, sem "ótima ideia!".
- Docs em **português do Brasil**. Código, variável e comentário técnico em **inglês**.

Pode começar. Se surgir dúvida bloqueante, pergunta antes de escrever arquivo — o resto joga em `09-OPEN-QUESTIONS.md`.

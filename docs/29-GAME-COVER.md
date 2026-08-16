# Capa do jogo

![Capa conceitual do Anime Verse: Battlegrounds](assets/anime-verse-battlegrounds-cover.png)

## Finalidade

`anime-verse-battlegrounds-cover.png` é a capa conceitual geral do **Anime Verse: Battlegrounds**. Ela apresenta a arena de batalha, o contraste cromático do projeto e a escala emocional pretendida para a experiência: energia ciano, violeta e âmbar sobre uma arena de bastião ao entardecer.

A imagem serve para documentação, planejamento visual, README, tickets e futuras peças de divulgação. Ela não representa uma captura de runtime e não é um mapa navegável, um decal, uma textura, um modelo 3D ou uma prova de que o cenário já foi validado no Roblox Studio.

## Conteúdo visual

A composição usa uma arena central com fissuras de energia, iluminação quente nas estruturas do bastião, cristais ciano/violeta e três combatentes originais vistos em silhueta. O título gerado na própria imagem é `ANIME VERSE: BATTLEGROUNDS`.

Os personagens, a arena e os efeitos foram gerados como conceito original para este repositório. Não há intenção de representar personagens, franquias, logos ou designs protegidos de terceiros.

## Procedência e estado

| Campo | Valor |
|---|---|
| Arquivo | `docs/assets/anime-verse-battlegrounds-cover.png` |
| Formato | PNG, 2560 × 1440 px, proporção 16:9 |
| Estado | **Conceito** |
| Uso permitido | Documentação, planejamento, capa de README e comunicação do projeto |
| Uso não permitido sem nova validação | Runtime, decal, textura, thumbnail oficial publicada ou asset 3D |
| Referência visual | `docs/assets/domain-expansion-concept.png` |

A imagem foi gerada para este projeto e deve permanecer acompanhada desta documentação. Qualquer adaptação para thumbnail, loading screen ou publicação externa deve preservar a procedência e ser revisada separadamente para o meio de destino. A decisão de **usar agora como vitrine, não como runtime** está em [`docs/33-ASSET-USABILITY.md`](33-ASSET-USABILITY.md).

## Peças derivadas para a vitrine — 2026-08-15

`scripts/prepare_store_art.py` deriva os dois formatos da plataforma a partir
**desta mesma capa**, sem fonte externa e sem ID inventado:

| Peça | Arquivo | Tamanho | Como é feita |
|---|---|---|---|
| Thumbnail | `docs/assets/roblox-ready/store/avb_thumbnail_1920x1080.jpg` | 1920 × 1080 | redução direta; a capa já é 16:9 |
| Ícone | `docs/assets/roblox-ready/store/avb_icon_512.png` | 512 × 512 | recorte quadrado **abaixo da faixa do título** |

O recorte do ícone não é centrado de propósito: o título está desenhado dentro
da capa e ocupa a largura inteira, então um quadrado central cortaria as duas
palavras no meio. Ícone aparece pequeno na plataforma, onde texto não se lê de
qualquer jeito — o recorte pega arena, cristal e o combatente central, que é o
que precisa ser reconhecível em 150 px.

Hashes e dimensões ficam em `store-art-manifest.json`, com `published: false`
em todas as peças. **Nada disso está publicado**, e promover exige a decisão de
§"Critério de promoção" mais o Gate P1.

## Texto da página da experiência (rascunho para P1)

> ⚠️ **Rascunho, não publicado.** A experiência é privada e não listada
> (`docs/13` §18), o nome depende de busca de marca (VISION-DEC-007) e todo
> texto público passa pelo Gate P1 (`docs/06` §3). O que segue descreve **o que
> existe hoje em código** — nada de feature futura escrita no presente.

### Título

`Anime Verse: Battlegrounds` — mantido por VISION-DEC-007, condicionado à busca
de marca. Sem subtítulo: a página da Roblox trunca cedo em telas pequenas.

### Descrição curta (até ~200 caracteres)

> RPG de ação em mundo aberto. Você começa só com soco, esquiva e guarda —
> cada técnica é conquistada jogando. Saia da vila segura por sua conta e risco:
> lá fora o PvP é opcional, mas real.

### Descrição longa

> **Anime Verse: Battlegrounds** é um RPG de ação em que a sua força é o que
> você aprendeu, não o que você comprou.
>
> Você acorda no Bastião do Limiar sabendo três coisas: socar, se defender e
> desviar. Nada mais. O Instrutor do Limiar aponta o caminho, e a partir daí o
> jogo é seu: cace Estilhaços na planície, leia o telegraph antes do golpe
> chegar, consolide o que ganhou no Marco de Retorno — e decida quando vale
> arriscar.
>
> **O que você faz aqui**
> • Combate corpo a corpo com cadeia de quatro golpes, ataque pesado, quebra de
>   guarda, aparo e dash com i-frames.
> • Três técnicas do Punho do Eclipse, todas conquistadas em jogo: Ombro Cometa,
>   Cadência Quebrada e Retorno de Pulso.
> • Éter Umbral como recurso: gasta, regenera e recompensa quem acerta o timing.
> • Uma cadeia de objetivos que ensina o loop — caçar, enfrentar o elite da
>   cratera e acertar o eco da Cadência.
> • PvP **opcional por geografia**: a vila é segura, a planície não. A fronteira
>   avisa de cinco formas diferentes antes de você cruzar.
> • Progresso persistente com consolidação: morrer na zona livre custa XP não
>   consolidado, nunca o que você já guardou.
>
> **O que ainda NÃO existe:** clãs, ranking, torneio, troca entre jogadores,
> múltiplos personagens e loadouts configuráveis. Estão no plano, não no jogo.
>
> Poder competitivo não é vendido. Técnica se conquista.

O último parágrafo é deliberado: dizer o que não existe evita a review de uma
estrela de quem entrou esperando clã e ranked.

### Gênero e classificação

| Campo | Valor | Origem |
|---|---|---|
| Gênero | RPG / Action RPG (**não** arena fighter) | VISION-DEC-001 |
| Subgênero de vitrine | Fighting / Adventure, se a plataforma exigir dois | — |
| Faixa etária pretendida | 13+, tom sombrio, gore leve dentro das políticas da Roblox | VISION-DEC-008 |
| Idiomas com revisão manual | PT-BR e inglês | `docs/06` §13 |
| Servidor | um World Place compacto; sem Arena Place na F0 | VISION-DEC-010, `docs/13` §18 |

### Tags sugeridas

`rpg` · `action rpg` · `anime` · `combate` · `pvp opcional` · `progressão` ·
`mundo aberto` · `boss` · `co-op leve` · `brasil`

Fora da lista de propósito: `simulator`, `tycoon`, `battle royale`, `ranked`,
`clãs`, `trade` — nada disso existe no jogo, e tag mentirosa traz o jogador
errado.

### Dispositivos — a decisão que importa

| Dispositivo | Existe em código | Validado em aparelho | Habilitar na página? |
|---|---|---|---|
| PC (teclado/mouse) | sim | não | **sim**, é onde o playtest vai acontecer |
| Toque (celular/tablet) | sim (HUD com no máx. 2 botões simultâneos, hold de fronteira) | **não** | **não até o W2** |
| Gamepad | sim (magnetismo 8° até 25 studs) | **não** | **não até o W2** |
| Console | não | não | não |
| VR | não | não | não |

Habilitar um dispositivo que nunca rodou no aparelho é a forma mais barata de
comprar review de uma estrela. A matriz de `docs/12` §7 e o passo `w2_perf` do
`docs/32-STUDIO-PLAYTEST-RUNBOOK.md` são o que destrava as duas linhas de cima.

### Antes de publicar qualquer uma dessas linhas

1. Gate P1 — revisão jurídica de nome, silhuetas, termos e arte (`docs/06` §3).
2. Busca de marca para "Anime Verse Battlegrounds" (VISION-DEC-007).
3. Gate W1 executado, para a descrição descrever algo que já rodou.
4. Teste de leitura do thumbnail e do ícone em tamanho pequeno.
5. Política de privacidade e termos, se houver qualquer coleta além da
   telemetria mínima de `docs/13` §15.

## Critério de promoção

A capa só deve ser considerada parte de uma experiência publicada depois de uma decisão separada sobre formato, compressão, leitura em telas pequenas, direitos de uso, acessibilidade e adequação à plataforma. A validação do mundo no Roblox Studio permanece independente desta imagem e segue o Gate W1 em [`docs/15-WORLD-PRESENTATION.md`](15-WORLD-PRESENTATION.md).

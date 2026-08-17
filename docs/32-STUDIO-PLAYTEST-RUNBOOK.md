# 32 — Runbook do playtest no Studio (W1 · A1 · W2 · R1)

> **Estado em 2026-08-15.** Este documento é o roteiro do dia em que o Studio
> abrir. Ele **não** é evidência de runtime e não fecha gate nenhum: fechar um
> gate exige a sessão executada e a captura anexada. O que existe hoje é
> validação headless — 241 casos de domínio, 73 de animação/apresentação, 67 de
> fuzz e 19 de simulação de combate ponta a ponta.

O mesmo roteiro existe em forma executável:

```bash
lune run scripts/avb-debug.luau runbook            # todos os passos
lune run scripts/avb-debug.luau runbook --gate W1  # só um gate
lune run scripts/avb-debug.luau home               # atalho de 3 passos (Studio fechado)
```

O catálogo vive em `scripts/StudioEvidence.luau` e é validado por teste. Mudou
o roteiro? Mude lá e este documento junto, no mesmo commit.

## 0. Quando chegar em casa

Três passos. Uma janela do Studio. O único place é `anime-verse-battlegrounds.rbxl`.
Isto **não** fecha W1/A1 — só tira o Play do artefato errado e chega perto o
bastante para a camada de impacto existir.

```powershell
.\scripts\build-studio.ps1
lune run scripts/avb-debug.luau sync    # exit 0 segue · exit 2 = reabra, não meça
```

Depois: Play, encostar no dummy (≤ 6 studs), acertar leve, pesado e Ombro Cometa
(passo `a1_impact`). Com o Studio fechado, o mesmo atalho imprime em JSON:

```bash
lune run scripts/avb-debug.luau home
```

Lock órfão o `build-studio.ps1` remove; lock de Studio vivo aborta. Abrir outro
`.rbxl` na raiz é o defeito de 14/08.

## 1. Regra zero: fora de sync, não se mede

```bash
lune run scripts/avb-debug.luau sync    # exit 0 = pode medir · exit 2 = pare
```

Em 14/08 três commits de correção de animação ficaram invisíveis porque o Play
rodava um `.rbxl` anterior a todos eles, aberto numa segunda janela do Studio
(`docs/12` §2). Medir naquele estado produziu três diagnósticos errados
seguidos. Por isso:

- **exit 2 encerra a sessão.** Não se anota nada, não se conclui nada, não se
  abre issue. Rebuilde (`scripts/build-studio.ps1`), reabra e rode de novo.
- **Uma janela do Studio por vez.** `list_roblox_studios` identifica cada
  janela pelo arquivo carregado; a antiga segura o place velho em memória mesmo
  com o arquivo apagado do disco.
- `avb-debug evidence` aplica esse porteiro sozinho: se estiver fora de sync,
  ele sai com 2 **sem coletar nada** em vez de devolver uma folha bonita e
  falsa.

## 2. Preparo (antes de abrir o Studio)

| Passo | Comando | Esperado |
|---|---|---|
| Gates headless verdes | as cinco linhas de `docs/12` §2 | tudo verde; um gate vermelho invalida a sessão antes dela começar |
| Snapshot do place | `scripts/build-studio.ps1` | `anime-verse-battlegrounds.rbxl` com bytes/hash impressos |
| Ponte de debug | `lune run scripts/debug-bridge.luau` | gera `.avb-debug/bridge.json` com o `X-Avb-Token` |
| Plugin | `scripts/install-plugin.ps1` | `AvbDebug` aparece na barra do Studio |
| Roteiro na mão | `avb-debug runbook` | funciona com o Studio fechado, de propósito |

Registre no topo da ficha: commit, SHA-256 do `.rbxl`, plataforma, resolução,
preset gráfico e se o atributo `F0Debug` está ligado.

## 3. Ordem de execução no Play

A ordem é a do roteiro de 20 min (`docs/13` §10). Cada passo tem critério de
aprovação em uma linha — ambíguo aqui vira discussão depois.

### W1 — leitura do mundo

| # | Passo | O que fazer | Capturar | Passa quando |
|---|---|---|---|---|
| 1 | Boot limpo | Play solo, ler o Output inteiro | Output, `avb-debug studioerrors` | nenhum erro Luau do jogo e o bootstrap chega ao fim (`[Bootstrap] servidor pronto (F0)`) |
| 2 | Spawn | parado no spawn, girar a câmera 360° | print frontal, perfil e três quartos; `avb-debug greybox` | piso sem z-fighting, teto sem escurecer a cena, praça e as duas rotas legíveis sem minimapa |
| 3 | Instrutora | chegar perto, aceitar o objetivo, depois tentar de 15 studs | print do prompt, tracker no HUD, recusa `too_far` no Output | um único prompt, aceite abre o tracker, interação distante recusada pelo servidor |
| 4 | Marco de Retorno | segurar a interação fora de combate; soltar antes no 1º teste | print do hold, recibo no Output | soltar cedo não consolida; 1,5 s medidos pelo servidor consolidam com recibo idempotente |
| 5 | Saídas norte e oeste | sair e voltar pelos dois portões | vídeo curto, os cinco sinais, Output do `ZoneEvent` | nenhum buraco de piso nem snag; hold de 0,6 s exigido na primeira ida; faixa de PvP visível |
| 6 | Morte e retorno | morrer na planície | Output da perda de XP, posição do respawn | respawn no Marco com a perda da zona aplicada **uma** vez |
| 7 | Elite | ir à cratera, sobreviver a um combo e um slam | vídeo do telegraph de 700 ms, print da coroa | telegraph legível antes do golpe, ringue livre de decoração, coroa lê à distância |

### A1 — o golpe

| # | Passo | O que fazer | Capturar | Passa quando |
|---|---|---|---|---|
| 8 | **Impacto de verdade** | **encostar** no boneco (≤ 6 studs) e acertar leve, pesado e Ombro Cometa | vídeo 60 fps, número de dano na tela, Output **sem** `[Combat] ... errou` | os três conectam e a camada de impacto aparece: hit-stop, tremida, luz, som e número |
| 9 | Cadeia leve | quatro cliques dentro de 0,65 s | vídeo dos quatro degraus, `props` da junta Root durante o golpe | silhueta distinta por degrau e `Root.Transform.Z` ≠ 0 |

> O passo 8 é o item 1 do recorte executivo (`docs/06` §5) e existe por um
> motivo específico: **a camada de impacto nunca rodou**. No playtest de 14/08
> o jogador estava a 41,2 studs do único alvo e o alcance do leve é 9, então
> nenhum acerto aconteceu e a conclusão "não tem luz nem tremida" era sobre
> código que jamais executou (`docs/14` §4.8). **Encostar no alvo não é
> detalhe: é o passo.** A simulação headless em `tests/combat_e2e.luau` já roda
> essa cadeia inteira em contrato — o que falta é vê-la.

> No passo 9, `Root.Transform.Z = 0` em todos os quadros é a assinatura exata
> do defeito de anexo de `docs/14` §4.7 (o rig R15 não existe no
> `CharacterAdded`). Se aparecer, siga a receita de seis passos daquela seção
> antes de mexer em pose.

### W2 — desempenho

Repetir o roteiro com 4 Estilhaços vivos e o elite, medindo com o
MicroProfiler separado em `stepAnimation`, script e render.

```bash
lune run scripts/avb-debug.luau evidence   # sync + perf + erros + players + greybox
```

Limites de `docs/14` §8, **F0-BASELINE** — número inicial para medir, não
promessa de produto. Estourar não reprova sozinho: obriga a registrar
dispositivo, cenário e decisão.

| Campo | Teto |
|---|---:|
| `heartbeatTimeMs` | 16,6 |
| `physicsStepTimeMs` | 8 |
| `totalMemoryMb` | 1400 |
| `workspaceParts` | 6000 |

Alvos de plataforma: PC integrado 60 FPS com frame pacing estável; Android de
entrada 30 FPS sustentados por 15 min sem degradação térmica progressiva.

Ordem de corte se estourar no Android: **sombra e partícula antes de leitura
cromática ou densidade de decoração** (`docs/31` §7).

### R1 — adversarial com dois clientes

O que já está travado em código (não repetir à mão): envelope/payload hostil,
replay de `requestId` e de sequência, rate limit por classe com janela de 1 s,
hold de fronteira declarado pelo cliente, e a soma dos eventos batendo com a
vida perdida — 67 casos em `tests/security_fuzz.luau` e 3 casos de dois
fighters em `tests/combat_e2e.luau`.

O que **só** o Studio prova, e é o que a sessão R1 deve fazer:

- dois clientes de verdade, com latência simulada (50/100/180/250 ms);
- network ownership hostil: mover a `HumanoidRootPart` pelo cliente e conferir
  a reconciliação de zona (`ZoneService.reconcile`);
- spam de remote por `RemoteEvent` real, medindo o custo do lado do servidor;
- travessia simultânea dos dois no mesmo portão;
- PvP na livre com morte e perda de XP dos dois lados.

## 4. Ficha da sessão

Preencher `docs/26-VISUAL-VALIDATION-CHECKLIST.md` (a ficha obrigatória já está
lá) e anexar, por passo: capturas, trecho do Output e o JSON de
`avb-debug evidence`. Um passo sem captura conta como **não executado** — não
como aprovado.

Divergência se descreve pelo que foi observado, nunca como "ficou diferente".

## 5. Depois da sessão

1. Atualizar `docs/12` §7 (matriz runtime) marcando só o que foi realmente
   executado.
2. Atualizar `docs/23` (snapshot canônico) com commit, artefato e resultado.
3. Abrir os defeitos com o passo do runbook no título — `a1_impact`,
   `w1_gates` — para o próximo ciclo saber o que reexecutar.
4. Se algum número de feel mudar, registrar em `docs/17` a medição que
   motivou. A regra de `docs/14` §4.8 continua valendo: **não se calibra feel
   no escuro.**

## 6. Achado headless em aberto para esta sessão

A simulação de combate de 15/08 registrou um comportamento que só o Play
resolve: o perfil de câmera é escolhido por **desfecho**, e a lista
`HEAVY_ABILITIES` do `CombatCameraController` só contém técnicas. O pesado
básico chega como `abilityId = "heavy"` e recebe **o mesmo trauma do jab**,
apesar de causar o dobro de dano e ser a ferramenta de quebra de guarda.

O teste fixava o comportamento atual em vez de mascarar. No passo 8, comparar
lado a lado o leve e o pesado e decidir com o olho: se o pesado precisar pesar
mais, entra na lista com o número medido — não com um palpite.

**✅ Resolvido em 17/08 (decisão do Álvaro no playtest W1/A1):** `heavy = true`
entrou em `HEAVY_ABILITIES`, usando o multiplicador já existente da lista
(trauma 0,5→0,8, FOV 2,6→3,64 no acerto). O Cometa continua sendo o golpe mais
pesado do kit (trauma 0,85). O teste foi atualizado para exigir
`pesado > jab` em vez de fixar a igualdade.

## Referências

- [`docs/12-TESTING.md`](12-TESTING.md) §2 (gates) e §7 (matriz runtime)
- [`docs/13-F0-SLICE.md`](13-F0-SLICE.md) §10 (roteiro de 20 min)
- [`docs/14-ANIMATION-PLAN.md`](14-ANIMATION-PLAN.md) §4.7–4.9 e §8
- [`docs/15-WORLD-PRESENTATION.md`](15-WORLD-PRESENTATION.md) (Gate W1)
- [`docs/19-DEBUG-BRIDGE.md`](19-DEBUG-BRIDGE.md) §5 (receitas do bridge)
- [`docs/26-VISUAL-VALIDATION-CHECKLIST.md`](26-VISUAL-VALIDATION-CHECKLIST.md) (ficha)
- [`scripts/StudioEvidence.luau`](../scripts/StudioEvidence.luau) (roteiro como dado)
- [`tests/combat_e2e.luau`](../tests/combat_e2e.luau) (a cadeia já exercida headless)

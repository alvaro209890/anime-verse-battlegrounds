# 33 — W2 no Studio: passo a passo do gate de desempenho

> Estado: criado em 2026-08-17 (Hermes-server), código atual `48ff2e3`.
> Este é o guia OPERACIONAL do gate W2 do [`docs/32`](32-STUDIO-PLAYTEST-RUNBOOK.md).
> O docs/32 define o porquê e os tetos; aqui está o como, na ordem.

## O que o W2 prova

Repetir o roteiro de 20 min (`docs/13` §10) com **4 Estilhaços vivos + o elite**
na cena, medindo com o MicroProfiler separado em `stepAnimation`, `script` e
`render`. Tetos F0-BASELINE (estourar **não** reprova sozinho — obriga a
registrar dispositivo, cenário e decisão):

| Campo | Teto |
|---|---:|
| `heartbeatTimeMs` | 16,6 |
| `physicsStepTimeMs` | 8 |
| `totalMemoryMb` | 1400 |
| `workspaceParts` | 6000 |

Alvos de plataforma: PC integrado **60 FPS** com frame pacing estável; Android
de entrada **30 FPS sustentados por 15 min** sem degradação térmica progressiva.

Auditoria de parts de 17/08 (docs/23): o mundo materializa ~1.220 parts
(vegetação = 914, 74%), ou seja ~5× abaixo do teto — **parts não é o gargalo
provável**; olhe primeiro heartbeat/`stepAnimation` com os NPCs animando.

---

## Passo a passo (PC Windows — `C:\GIS\anime-verse-battlegrounds`)

### Fase 0 — preparo (PowerShell, ~2 min)

```powershell
git pull                                # garante o código mais novo (faça sempre)
.\scripts\build-studio.ps1              # snapshot canônico anime-verse-battlegrounds.rbxl
lune run scripts/debug-bridge.luau      # sobe a ponte (gera .avb-debug/bridge.json + token)
.\scripts\install-plugin.ps1            # garante o plugin AvbDebug na barra do Studio
lune run scripts/avb-debug.luau runbook # roteiro na mão (funciona com Studio fechado)
```

Regra zero: **uma janela do Studio por vez** e **fora de sync não se mede**.

### Fase 1 — abrir e sincronizar

1. Abra `anime-verse-battlegrounds.rbxl` (só ele — feche qualquer outra aba).
2. No terminal: `lune run scripts/avb-debug.luau sync` → **exit 0 = pode medir**;
   exit 2 = reabra e rode de novo, não meça fora de sync.
3. Dê **Play** (solo).

### Fase 2 — boot limpo e cena de estresse

4. Leia o **Output** inteiro: nenhum erro Luau do jogo e o bootstrap chega ao
   fim — `[Bootstrap] servidor pronto (F0)`.
5. Monte a cena de estresse: vá até a **planície** (Portão Norte) e depois à
   **cratera** — os 4 Estilhaços Errante (cap 4) + o Ancorado (elite) precisam
   estar vivos e animando. Confirme 5 NPCs antes de medir.
6. Abra o **MicroProfiler** (menu View → MicroProfiler) e agrupe por
   `stepAnimation`, `script` e `render`.

### Fase 3 — roteiro medido

7. Rode o roteiro de 20 min na ordem do `docs/13` §10 (o runbook na mão):
   spawn → Instrutora → Marco de Retorno → saída norte → fronteira (hold
   0,6 s) → planície (estilhaços) → cratera (elite: telegraph 700 ms, combo,
   slam) → morrer na planície → respawn no Marco → voltar. Enquanto roda,
   observe o MicroProfiler ao vivo (onde o pico mora: stepAnimation? script?
   render?).
8. Com o Studio em Play e o bridge de pé, colete a folha:
   ```powershell
   lune run scripts/avb-debug.luau evidence
   ```
   Ela aplica o porteiro de sync, coleta perf + erros + players + greybox e
   devolve `perfWithinBudget` + `perfBreaches`.

### Fase 4 — registrar e decidir

9. Anote os **4 números** do evidence + FPS médio/mínimo do PC e frame pacing.
10. Estourou algum teto? **Não reprova sozinho**: registre dispositivo,
    cenário e a decisão (ex.: "Android de entrada: 26 FPS → corte 1 = densidade
    da vegetação, ordem do `docs/31` §7").
11. Print do MicroProfiler (stepAnimation/script/render) + trecho do Output.
12. Preencha a ficha em `docs/26-VISUAL-VALIDATION-CHECKLIST.md` (um passo sem
    captura conta como **não executado**).

### Fase 5 — fechar

13. Atualize `docs/12` §7 (matriz runtime) marcando só o que foi executado e
    `docs/23` (snapshot) com commit/artefato/números.
14. Commit + push (ou peça ao Hermes que faça). Abra defeitos com o passo do
    runbook no título (`w2_perf`, `w2_heartbeat`).

---

## Ordem de corte se o Android sofrer (docs/31 §7)

1. **Sombra e partícula** (itens mais caros) — antes de qualquer leitura
   cromática.
2. **Densidade da decoração** — a vegetação é 74% das parts; reduzir densidade
   primeiro, nunca a legibilidade do ringue/cratera.
3. Só depois mexer em leitura cromática/iluminação.

## Referências

- [`docs/32`](32-STUDIO-PLAYTEST-RUNBOOK.md) — gates W1/A1/W2/R1 e o porquê de cada passo
- [`docs/13`](13-F0-SLICE.md) §10 — roteiro de 20 min
- [`docs/12`](12-TESTING.md) §2 (gates) e §7 (matriz runtime)
- [`docs/26`](26-VISUAL-VALIDATION-CHECKLIST.md) — ficha obrigatória
- [`docs/23`](23-DOCUMENTATION-SNAPSHOT.md) — auditoria de parts de 17/08

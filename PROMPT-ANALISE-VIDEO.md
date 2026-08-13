# PROMPT — Análise e melhoria do jogo a partir do vídeo

> Este arquivo é um PROMPT pronto para ser enviado ao **Claude Code** junto com
> o vídeo do jogo rodando no Studio. O vídeo será adicionado a este
> repositório (procure por `video/` na raiz ou o arquivo `.mp4`/`.mov` mais
> recente). Leia o prompt abaixo e execute.

---

## Contexto do projeto

Você está no repositório **Anime Verse Battlegrounds** (Roblox/Luau), um
RPG/Action RPG de mundo aberto estilo anime. Repo público:
`github.com/alvaro209890/anime-verse-battlegrounds` (branch `main`).

Stack e regras fundamentais (leia a skill do projeto antes de começar):

- **100% procedural em código (Motor6D) e VFX dirigido por dados.** Não existem
  clipes, keyframes, assets nem Animation Editor. Nada de meshes/roupas.
- **`--!strict`** em todo o código; arquitetura server (autoritativo) / client
  (apresentação local). Nenhuma decisão de jogo no cliente.
- **Honestidade visual:** raio de efeito nunca passa do alcance real; efeito de
  acerto (flash/onda/ring) só aparece com confirmação do servidor, nunca em
  whiff.
- **Docs junto do código:** toda mudança de regra/número atualiza o doc no
  MESMO commit (`docs/00-VISION` .. `docs/17-COMBAT-FEEL`).
- **Segundo Cérebro compartilhado** (fonte de verdade de projetos) fica no
  server (`/home/server/Downloads/Segundo-Cerebro`,
  `02-projetos/anime-verse-battlegrounds.md`) — documente o que puder lá se
  tiver acesso; no mínimo, mantenha os docs do repo impecáveis.
- **Skill local:** `~/.claude/skills/anime-verse-battlegrounds/SKILL.md` tem a
  toolchain, a suite de validação e os pitfalls. Carregue-a primeiro.
- Direção de cenário (VISION-DEC-013): mundo aberto com várias cidades
  (Distrito Lumen, Vila Sombria, Porto Ferro, Setor Cinza, Academia Alvorada,
  Arquipélago da Tormenta) — nomes originais obrigatórios (Gate P1).

## O que você vai receber

**Um vídeo do jogo rodando no Studio** (F0: Bastião do Limiar, combate contra
Estilhaços, técnicas Ombro Cometa / Cadência Quebrada / Retorno de Pulso,
NPCs de missão e dummy de treino).

## Tarefa 1 — Análise do vídeo (antes de tocar em qualquer código)

1. Extraia frames do vídeo (ffmpeg, ~1 frame por segundo) e analise
   **animação a animação**:
   - Cadeia leve (jab → direto → chute → finalizador): antecipação, peso,
     follow-through, sincronia com o hit, retorno ao neutro.
   - Pesado, Ombro Cometa (carga/avanço/impacto), Cadência Quebrada
     (1º golpe, 2º golpe, eco) e Retorno de Pulso (postura + contra).
   - Animações dos NPCs (instrutor, dummy, estilhaços: telegraph/ataque/queda).
2. Avalie o **cenário do spawn** (Bastião): leitura visual, decoração,
   iluminação, portões, obstáculos, "cara de anime".
3. Cace **bugs visíveis**: poses travadas, deslocamentos errados, VFX fora de
   sincronia, números de dano/barras estranhas, clipes de câmera, colisões
   visíveis.
4. Produza um relatório curto e objetivo (em português) no arquivo
   `docs/18-ANALISE-VIDEO.md` com: o que está bom, o que está quebrado,
   o que falta, priorizado por impacto visual.

## Tarefa 2 — Implementação (após o relatório)

Melhore, na ordem:

1. **Animações** — refine as poses procedurais (PlayerCombatAnimator e
   ActorAnimator) com base no que o vídeo revelou: mais antecipação, mais
   peso no impacto, mais follow-through. Ajuste timings SÓ se a mudança não
   quebrar o autoritativo (startup/active/recovery vivem em `Abilities.luau`
   e são regra de jogo — mudar timing de regra exige atualizar docs + testes
   da cascata).
2. **Cenário** — melhore a área do spawn (SpawnDecorations.luau: dados puros;
   WorldService materializa) e o que mais o vídeo mostrar de feio/quebrado.
3. **Game feel** — números de dano, barras, câmera, hit-stop, VFX, áudio.
4. **Bugs** — tudo que o vídeo revelar, com teste de regressão quando a lógica
   for testável (funções puras).

Restrições absolutas:

- Preservar funcionalidades; nenhuma mudança de regra de jogo sem doc + teste.
- Não quebrar contratos de evento existentes (CombatEvent, StateDelta,
  EnemyEvent) sem atualizar TODOS os consumidores e os testes.
- Não usar assets/Animation Editor (Gate P1). Tudo Parts/Motor6D/partículas
  dirigidas por dados.

## Tarefa 3 — Validação e entrega

1. Rode a suite COMPLETA antes de commitar (skill §2), conferindo a saída
   completa do selene (não só a última linha):
   `lune run tests/run.luau` · `lune run tests/animation.luau` ·
   `selene src tests` · `stylua --check src tests` ·
   `mkdir Packages -Force; rojo build -o build.rbxl`
2. Atualize os docs afetados no MESMO commit (12-TESTING, 13-F0-SLICE,
   14-ANIMATION-PLAN, 15-WORLD-PRESENTATION, 17-COMBAT-FEEL e
   18-ANALISE-VIDEO).
3. Commits pequenos e descritivos, push para `main` e confirme o CI verde
   (`gh run list -R alvaro209890/anime-verse-battlegrounds --limit 1`).
4. Se o CI ficar vermelho, corrija ANTES de avisar o Álvaro.

## Entrega final

Resumo em português, curto e direto: o que o vídeo revelou, o que foi
melhorado (com commits), o que ficou pendente e como ver no Studio
(`rojo build` + Play). Sem textão.

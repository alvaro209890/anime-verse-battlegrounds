# Anime Verse Battlegrounds

RPG / Action RPG de mundo aberto no Roblox (Luau) — combate estilo battlegrounds com
progressão persistente, loadout customizável e ressonância de famílias de energia.

> **Status em 2026-08-13 (17h):** itens 1–13 do backlog F0 fechados em código/headless. **Skins do spawn:** Instrutor do Limiar com cabeça visível, rosto em peças, capuz, cabelo e casaco umbral; dummy de treino com cabeça, palha, alvo de três anéis e poste. As cabeças anteriores usavam um FileMesh que não carregava (NPCs sem cabeça) e nasciam de costas para a praça.
> **Runtime:** pare o Play e rode de novo para recarregar o `WorldService`. Correções da rodada anterior seguem valendo: chegue no vão do portão norte e **SEGURE E**.

![Capa conceitual do Anime Verse: Battlegrounds](docs/assets/anime-verse-battlegrounds-cover.png)

> **Capa conceitual:** a imagem é uma referência original de direção de arte para a arena e a identidade do jogo; ela não é um asset de runtime. Consulte [`docs/29-GAME-COVER.md`](docs/29-GAME-COVER.md) para procedência e limites de uso.

O pacote visual F0 de texturas, props, VFX e boards de animação está catalogado em [`docs/30-VISUAL-ASSET-PACK.md`](docs/30-VISUAL-ASSET-PACK.md). Todos os PNGs permanecem no estado **Conceito** até conversão, otimização e validação separadas.

As variantes técnicas para importação no Roblox estão em [`docs/assets/roblox-ready/`](docs/assets/roblox-ready/), com manifesto PBR, previews e scripts reproduzíveis. Elas continuam sem ligação automática ao runtime.

## Estado comprovado

| Camada | Estado |
|---|---|
| Produto | Q-001 a Q-030 decididas; `docs/09-OPEN-QUESTIONS.md` é o registro canônico |
| Planejamento | visão, GDD, mundo, social, arquitetura, schemas, segurança, roster, roadmap, benchmark e plano de animação documentados |
| Implementado | domínio F0, mundo greybox com rotas/marcos/modelos low-poly, animação procedural de NPCs e do jogador, interações semânticas com Instrutor/Marco, save/ProfileStore, cliente Input/HUD, envelope v2, `SecurityService` e `TelemetryService` mínimo |
| Validado automaticamente | 235/235 testes em `tests/run.luau` + 73/73 em `tests/animation.luau` + 29/29 no fuzz de segurança, Selene limpo, StyLua canônico, Wally e build Rojo |
| Ainda não comprovado | roteiro Play no Studio, physics/collision groups, DataStore real, dois clientes, latência, mobile, gamepad, performance, UX visual e assets de animação |

O CI em pushes para `main` valida contratos headless e a árvore Rojo; não substitui playtest. O snapshot e os links de evidência ficam em `docs/12-TESTING.md`.

## Stack

| Ferramenta | Uso | Config |
|---|---|---|
| Rojo | sync filesystem ↔ Studio | `default.project.json` |
| Wally | gerenciador de pacotes | `wally.toml` |
| luau-lsp | type checking (`--!strict`) | `.luaurc` + VS Code |
| Selene | lint | `selene.toml` |
| StyLua | formatador | `stylua.toml` |
| Lune | testes headless | `tests/run.luau` |
| Aftman | toolchain manager | `aftman.toml` |

## Desenvolvimento

No PowerShell, gere sempre um snapshot novo antes de abrir o projeto no Studio:

```powershell
aftman install
.\scripts\build-studio.ps1
```

O script instala as dependências Wally, garante `Packages/`, sobrescreve exatamente
`anime-verse-battlegrounds.rbxl` e imprime tamanho, data e SHA256 para confirmar que
o arquivo não é um build antigo. Feche o place que já estiver aberto no Studio e
reabra esse `.rbxl` antes de clicar em **Play**.

Esse `.rbxl` é um artefato local ignorado pelo Git: atualizar ou baixar a branch
`main` não reconstrói o arquivo. Rode o script novamente depois de cada atualização.

Snapshot histórico gerado no Windows em 2026-08-14 13:53:05 -03: `275301` bytes,
SHA256 `B90E9417A1CB59D3B372CFCEB2DD831FB5C58274971F716071AE379A1072C697`.

O check headless de 2026-08-15 (`rojo build -o build.rbxl`, commit `86228ee`)
produziu `318988` bytes, SHA256
`bc6b5056f238787ce2e857f835a1486b193f4f08db7a38bdccb4878d7f83bff4`. Esses
dados comprovam a geração do arquivo, não a execução dele no Studio.

**`anime-verse-battlegrounds.rbxl` é o único place que se abre.** Qualquer outro
`.rbxl` na raiz é descartável e não recebe as mudanças do repositório — abrir um
deles é jogar código velho achando que é o atual. O gate de tronco escreve em
`.rojo-tree-check.rbxl` justamente para não parecer um place de trabalho.

Enquanto o Studio está com o place aberto, ele mantém ao lado um
`anime-verse-battlegrounds.rbxl.lock`. Fechamento no tapa, crash ou reboot deixam
esse lock para trás; nesse caso o `build-studio.ps1` confirma pelo PID que a
sessão morreu, remove o lock e segue. Lock de Studio vivo continua abortando o
build, para nunca sobrescrever um place em uso.

**Build não é Play:** o build apenas copia o estado atual de `src/` para um arquivo
`.rbxl`; ele não inicia o jogo nem atualiza um place que já está aberto. O **Play**
executa o snapshot atualmente carregado no Studio. Portanto, depois de mudar código,
rode novamente o script e reabra o arquivo — ou use uma sessão Rojo live-sync
configurada separadamente.

O atributo `F0Debug=true` do snapshot libera o kit de teste somente no Studio. O
servidor ainda exige `RunService:IsStudio()`, então o mesmo atributo não ativa esse
atalho em uma experiência publicada.

Outros gates locais:

```powershell
lune run tests/run.luau
selene src tests
stylua --check --line-endings Windows src tests
rojo build -o .rojo-tree-check.rbxl
```

O CI (`.github/workflows/ci.yml`) roda lint + format + testes + build em todo push
(`src`, `tests`, `plugins` e `scripts`).

### Live sync: manter o Studio sempre com o código atual

`build-studio.ps1` gera um snapshot novo, mas **não** atualiza um place já
aberto. Para editar código e ver no Studio sem reabrir nada, use o Rojo:

```powershell
.\scripts\serve.ps1
```

No Studio: aba **Plugins → Rojo → Connect**. Enquanto o serve roda, salvar um
arquivo em `src/` atualiza o place aberto. O plugin do Rojo é instalado com
`rojo plugin install` (já instalado nesta máquina).

Para saber se o Studio está mesmo com o código do repo:

```bash
lune run scripts/avb-debug.luau sync
```

### Debug do Studio por agentes (plugin AvbDebug)

O que acontece dentro do Studio deixou de ser invisível para os agentes. O plugin
`AvbDebug` conversa com uma ponte local (só `127.0.0.1`) e qualquer agente
consulta a árvore, as propriedades, o Output e o estado do playtest pelo CLI:

```powershell
.\scripts\install-plugin.ps1            # uma vez; reabra o Studio depois
lune run scripts/debug-bridge.luau      # terminal 1, deixa rodando
lune run scripts/avb-debug.luau ping    # terminal 2
lune run scripts/avb-debug.luau sync    # o Studio está com o código do repo?
lune run scripts/avb-debug.luau errors  # erros do último playtest
```

Detalhes, comandos e limites em [docs/19-DEBUG-BRIDGE.md](docs/19-DEBUG-BRIDGE.md).

## Estrutura

```
src/
  shared/            módulos compartilhados (dados, contratos, tipos, geometria)
    Data/            catálogos dirigidos por dados (personagens, habilidades, famílias, NPCs, zonas, objetivos, locale)
  server/            services (domínio F0, save, rede, segurança e telemetria)
  client/            controllers (bootstrap de apresentação)
tests/               harness Lune + 249 testes unitários (214 run.luau + 35 animation.luau)
docs/                produto, arquitetura, decisões, testes e planos (00 a 19)
lib/                 bibliotecas pinadas (ProfileStore)
plugins/AvbDebug/    plugin de Studio: ponte de debug usada pelos agentes
scripts/             build do snapshot, ponte de debug e CLI dos agentes
```

## Docs principais

- [docs/00-VISION.md](docs/00-VISION.md) — visão, pilares, público, curva de poder
- [docs/04-ARCHITECTURE.md](docs/04-ARCHITECTURE.md) — arquitetura service/controller, ADRs
- [docs/05-DATA-SCHEMA.md](docs/05-DATA-SCHEMA.md) — schemas de dados e de definição
- [docs/06-ROADMAP.md](docs/06-ROADMAP.md) — fases e gates
- [docs/09-OPEN-QUESTIONS.md](docs/09-OPEN-QUESTIONS.md) — fonte canônica de decisões
- [docs/10-MARKET-BENCHMARKS.md](docs/10-MARKET-BENCHMARKS.md) — evidência de mercado datada e limites de uso
- [docs/11-ABILITY-SPEC.md](docs/11-ABILITY-SPEC.md) — como adicionar habilidade (spec do formato)
- [docs/12-TESTING.md](docs/12-TESTING.md) — como rodar e o que cobre os testes
- [docs/13-F0-SLICE.md](docs/13-F0-SLICE.md) — spec de execução da fatia vertical (kit, mapa, roteiro, backlog)
- [docs/14-ANIMATION-PLAN.md](docs/14-ANIMATION-PLAN.md) — pipeline, qualidade, budgets e gates das animações
- [docs/15-WORLD-PRESENTATION.md](docs/15-WORLD-PRESENTATION.md) — mundo procedural, modelos greybox, animação dos atores e roteiro de validação
- [docs/16-COMBAT-AUDIO.md](docs/16-COMBAT-AUDIO.md) — áudio de combate: catálogo, player, integração e pendência de upload
- [docs/17-COMBAT-FEEL.md](docs/17-COMBAT-FEEL.md) — game-feel: easing, follow-through, idle, wrist snap, hit-stop e câmera de impacto
- [docs/18-ANALISE-VIDEO.md](docs/18-ANALISE-VIDEO.md) — playtest 13/08: golpes invisíveis, mira e overlay de comandos
- [docs/19-DEBUG-BRIDGE.md](docs/19-DEBUG-BRIDGE.md) — plugin AvbDebug e ponte local: como qualquer agente debuga o Studio

`PROMPT_AnimeVerseBattlegrounds_v2.md` é o briefing histórico que originou o
planejamento. Em conflito, os documentos canônicos em `docs/` prevalecem.

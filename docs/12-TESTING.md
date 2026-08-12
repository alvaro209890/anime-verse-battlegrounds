# 12 — Testes e evidências

> **Snapshot:** 2026-08-12. `tests/run.luau` declara 22 testes F0. O HEAD anterior a esta revisão documental, `33eca73`, teve [CI verde](https://github.com/alvaro209890/anime-verse-battlegrounds/actions/runs/31618843968); isso não certifica mudanças posteriores no worktree.
> **Limite da evidência:** não há prova registrada de execução no Roblox Studio, servidor publicado privado, Android, gamepad ou múltiplos clientes reais.

### Evidência local desta revisão documental

Em 2026-08-12, no worktree Windows ainda não commitado, foram executados: StyLua 2.5.2 sobre os bytes LF canônicos do Git e, separadamente, sobre o checkout CRLF com override de line ending; Selene 0.31.0; os 22 testes Lune 0.10.5; `wally install` 0.3.2; e build Rojo 7.7.0 após criar a pasta vazia `Packages`, como faz o CI. Todos passaram. O hash de `wally.lock` permaneceu igual antes/depois do Wally. Essa evidência valida somente o código já existente e a árvore do projeto; não transforma os contratos documentais novos em implementação nem substitui o CI de um commit futuro.

## 1. Gates reproduzíveis

Depois de instalar o toolchain, a verificação completa do repositório é:

```bash
aftman install
stylua --check src tests
selene src tests
lune run tests/run.luau
wally install
mkdir -p Packages
rojo build -o build.rbxl
```

O CI executa StyLua, Selene, os testes Lune, a instalação Wally e o build Rojo em todo pull request e em pushes para `main` (`.github/workflows/ci.yml`). Cada resultado precisa registrar commit, ambiente e saída; “verde no CI” não significa “testado no runtime Roblox”. O `.rbxl` gerado pelo Rojo é artefato de validação da árvore, não prova de jogabilidade.

Em checkout Windows com `core.autocrlf=true`, os arquivos de trabalho podem estar em CRLF enquanto `stylua.toml` exige `Unix`; nesse caso, o check direto acusa somente final de linha. Para reproduzir o CI, use uma cópia com bytes LF canônicos do Git (`git -c core.autocrlf=false archive ...`) ou execute o diagnóstico local equivalente com `stylua --check --line-endings Windows src tests`. Não reformatar código só para mascarar essa conversão do checkout.

## 2. Cobertura existente: exatamente 22 testes

| Área | Cobertura |
|---|---|
| **Dados** (4) | roster → Punho do Eclipse com 4 habilidades F0; `dash_strike` como molde (custo 15, cooldown 4 s, runner); 4 famílias cadastradas; contratos de remote registrados |
| **CooldownService** (3) | inicia zerado; `start` aplica e expira; `clear` zera |
| **CombatService** (3) | dano reduz vida; dano letal mata; dano negativo não cura |
| **ResourceService** (4) | cria estado com pool da família; `trySpend` deduz/nega; `grantFlowGain` respeita cap; família desconhecida retorna `nil` |
| **AbilityService** (5) | ativação válida (dano 12 + custo 15 − fluxo +6); recusa sem recurso; recusa em cooldown; habilidade desconhecida; morto não ativa |
| **CatalogService** (2) | dados reais passam na validação F0; personagem sem habilidade falha |
| **PlayerSessionService** (1) | join cria estado com personagem padrão; leave limpa estado e libera perfil |

Esses testes cobrem o esqueleto F0 atualmente implementado. Eles não cobrem os contratos futuros de Ressonância, `impactCost`, custo/fallback estrangeiro, maestria, save real, streaming, arena ou competitivo.

## 3. Arquitetura do harness

- **`tests/harness.luau`** simula o mínimo que o Lune não fornece: `_G.game`, `_G.Instance`, `_G.task` e resolução de `require(script.Parent.X)` no filesystem.
- **`tests/run.luau`** contém os 22 casos e usa módulos reais de `src/`, com um miniframework de asserts.
- **Services testáveis por injeção** recebem dependências em `init()`: `CatalogService`, `AbilityService`, `ResourceService` e `PlayerSessionService`. O bootstrap Roblox monta o grafo real.
- **`src/shared/TaskCompat.luau`** usa `task` nativo no Roblox e o polyfill somente no harness.

Os módulos de dados declaram tipos inline porque o Lune não resolve `script.Parent` como o Roblox. `src/shared/Types.luau` continua sendo o contrato canônico para tooling, mas a duplicação precisa ser comparada em revisão sempre que o tipo evoluir.

## 4. Evidência por camada

| Camada | O que demonstra | O que não demonstra |
|---|---|---|
| lint + 22 testes Lune | sintaxe, estilo e comportamento unitário coberto no ambiente simulado | física, replicação, UI, input ou serviços Roblox reais |
| Wally + build Rojo | dependências resolvidas e árvore de projeto montável | que o place abre sem erro ou que um fluxo é jogável |
| Studio | bootstrap, UI/input, câmera, física e replicação no cenário testado | DataStore/teleport/rede pública com fidelidade total |
| publicado privado | serviços reais, múltiplos servidores, reconnect, teleport e condições reais de rede | cobertura de dispositivo que não foi executada |

Uma entrega deve dizer explicitamente quais camadas foram executadas, em vez de resumir tudo como “testado”.

## 5. Casos obrigatórios antes de F1/F2

Os testes abaixo são backlog, não parte dos 22 existentes:

- catálogo rejeita `impactCost` ausente, não inteiro ou fora do intervalo;
- validador de loadout aceita capacidade 4/impacto 12 e rejeita qualquer excesso;
- loadout ativo exige exatamente uma ultimate e aceita no máximo uma técnica normal `defining`;
- `rawD = 3` é válido e `rawD > 3` é rejeitado, sem clamp que transforme o valor em 3;
- técnica estrangeira exige `foreignResourceCost > 0`; fallback neutro não gera recurso da família original e política `Blocked` impede equipar;
- maestria contém exatamente níveis 1–10, breakpoints comportamentais em 3/6/9, bônus numéricos somente em 2/5/8 e soma máxima de 6%;
- normalização competitiva remove bônus numéricos de maestria e preserva apenas variantes permitidas pela versão do snapshot;
- IDs de runner/fallback ausentes derrubam validação, e falha não debita recurso nem inicia cooldown.

## 6. Matriz runtime ainda pendente

Antes de chamar F0 de jogável ou liberar a fase seguinte, registrar evidência para:

- Studio solo: boot limpo, spawn, três técnicas, morte/respawn, save simulado e desconexão;
- Studio server + pelo menos dois clientes: autoridade de dano/custo/cooldown, latência, spam de remote e estado após morte;
- Android de entrada, telefone mediano, PC integrado e gamepad: input, HUD, câmera, telegraph e orçamento de frame/memória;
- experiência publicada privada: DataStore com session lock, reconnect, shutdown, múltiplos servidores e, quando existir, teleport para Arena Place;
- teste adversarial: payload malformado, alvo/alcance falsos, replay, spam, velocidade e network ownership.

Até essas execuções existirem, a formulação correta é **“esqueleto F0 com testes unitários e build de árvore”**, não “runtime validado”.

## 7. Checklist de consistência documental

Antes de fechar uma revisão de planejamento:

```bash
rg -n "masteryTiers|5 tiers|tiers 1–5|breakpoints? 2/4" docs
rg -n "min\(3, rawD\)|D = min\(3" docs
rg -n "upgradePity|pity.*forja|forja.*pity" docs
rg -n "recomendação provisória|\| Proposta \|" docs/09-OPEN-QUESTIONS.md
rg -n "\\x{FFFD}" README.md docs
```

- os quatro primeiros comandos devem ficar sem ocorrência normativa obsoleta; menção histórica só permanece se estiver marcada como revogada;
- `rawD > 3` deve ser inválido em schema, GDD, spec e testes planejados;
- pity pertence somente ao loot pessoal de boss, nunca à forja;
- maestria usa níveis 1–10, breakpoints 3/6/9 e ganho numérico total máximo de 6%;
- todos os documentos devem distinguir decisão aprovada, baseline de playtest, implementação existente e gate ainda pendente;
- revisar UTF-8, links, tabelas, âncoras e referências cruzadas após renomear seções;
- confirmar a terminologia transversal: RPG / Action RPG, três presets gratuitos e seis máximos, soft launch Brasil-first e território/F7 pós-lançamento.

## 8. Pitfalls conhecidos

- `task.wait` real em teste cria loop infinito se o polyfill síncrono for usado no `spawn`; o harness injeta `spawn = noop` para o loop de regen.
- Busy-wait curto com `os.clock` substitui `task.wait` nos testes de expiração de cooldown.
- Selene permite `global_usage` e `empty_loop` no `selene.toml` porque o harness usa `_G` e busy-waits deliberadamente.
- Contar casos pelo resumo pode mascarar erro: a fonte é a quantidade real de chamadas `test(...)` em `tests/run.luau`; nesta versão são 22.

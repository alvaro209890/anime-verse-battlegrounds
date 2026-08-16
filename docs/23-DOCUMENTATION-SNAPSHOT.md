# Snapshot Canônico da Documentação — 16/08/2026

Este arquivo é a referência única para o estado técnico atual do repositório. Os demais documentos preservam decisões e histórico de implementação, mas afirmações antigas sobre commits, contagens de testes ou artefatos devem ser interpretadas como registros históricos quando divergirem deste snapshot.

## Estado atual

| Campo | Estado canônico |
|---|---|
| Branch publicado | `main` (esta rodada entra por PR) |
| Commit-base do código de jogo | `2a713af` (`src/` inalterado nesta rodada) |
| Estado deste documento | snapshot após validação total: docs alinhados ao catálogo, porteiro `scripts/audit_snapshot.py`, dummy fora do Heartbeat travado por teste |
| Data do commit | 2026-08-16 |
| Última alteração | `scripts/audit_snapshot.py` + `docs/ci-snapshot.json`; docs/13 §6.1/§9, docs/16, README, docs/12 e docs/08 alinhados ao catálogo; teste do dummy usa dano 5; Heartbeat não chama `tryDummyAttack` |
| Testes de domínio | 241 passaram, 0 falharam |
| Testes de animação/apresentação | 76 passaram, 0 falharam |
| Fuzz headless de segurança | 67 passaram, 0 falharam |
| Simulação de combate ponta a ponta | 19 passaram, 0 falharam |
| Auditoria visual | `python3 scripts/audit_visual_assets.py --check` — 31 conceitos, zip Kenney, 13 arquivos de VFX de catálogo, 305 `.ogg` |
| Snapshot canônico | `python3 scripts/audit_snapshot.py --check` — 403 casos, NPCs, 15 deixas / 33 ogg, dummy fora do Heartbeat, frases obsoletas recusadas |
| Selene | 0 erros, 0 warnings, 0 parse errors nesta rodada |
| StyLua | passou nesta rodada (`--check` limpo em `src tests plugins scripts`) |
| Rojo | build aprovado; check local de 318.988 bytes em `/tmp/build.rbxl` (SHA256 `bc6b5056f238787ce2e857f835a1486b193f4f08db7a38bdccb4878d7f83bff4`) — igual ao snapshot anterior porque `src/` não mudou |
| Runtime Roblox Studio | ainda não validado neste snapshot |
| Dispositivos reais | Android, gamepad e PC integrado ainda não validados neste snapshot |
| DataStore publicado | ainda não validado em place privado |
| Múltiplos clientes | isolamento de sequência/orçamento coberto headless; latência real, spam, network ownership e dois clientes ainda não validados |

## O que está implementado

O repositório contém a fatia de combate server-authoritative, as três habilidades F0, progressão e quests, inimigo comum e elite, VFX de jogador e inimigos, skins procedurais, defesa e dash com apresentação procedural em fases, receitas locais de impacto de chão, paredes decoradas, teto translúcido no spawn, terreno contínuo, rochas e grama procedurais, referências visuais originais, índice visual na raiz, checklist de validação em `docs/26`, catálogo de habilidades futuras em `docs/27`, reforma visual do spawn em `docs/28`, reforma do mundo aberto e das skins de inimigo em `docs/31`, runbook do playtest em `docs/32`, matriz de usabilidade dos assets em `docs/33`, inventário com hashes em `docs/assets/visual-inventory.json`, atalho de três passos para o PC de casa (`avb-debug home`) e o script `scripts/ci.sh` na ordem do GitHub Actions (incluindo a auditoria visual e o snapshot canônico). O pacote público Kenney está arquivado em `docs/assets/open-candidates/`; um subconjunto já extraído serve o VFX de inimigo com `assetId = nil`. Nenhuma imagem gerada está ligada ao place.

O build e os testes automatizados demonstram integridade de código, contratos puros, catálogos, geometria, segurança modelada, apresentação procedural e árvore Rojo. Eles não demonstram que Parts, joints, iluminação, prompts, física, câmera, replicação, DataStore ou dispositivos reais funcionam como esperado dentro do Roblox Studio.

## Próximo estado recomendado

A ordem oficial continua sendo **sincronização do Studio → W1 de leitura do mundo → impacto real dos golpes → A1 do Ombro Cometa → R1 adversarial → W2 de performance e dispositivos → fechamento da F0**. No PC: `.\scripts\build-studio.ps1` → `avb-debug sync` → Play encostado no dummy (`a1_impact`). A F1 de loadout, Ressonância e múltiplas identidades só deve começar depois dos gates da F0 ou de uma decisão explícita de escopo.

## Regra de leitura dos documentos

Quando um documento mencionar commits como `108be31`, `d0f6f8d`, `b529c5e`, `0b96d82`, `86228ee`, contagens como 166, 169, 238, 239 ou 49 testes, 14 casos de combate e2e, 73 testes de animação ou 400 casos, ou artefatos antigos de 160.553/128.744 bytes, essas referências são históricas e não representam o snapshot atual. Para esta consolidação, usar o commit final informado no GitHub, 241 testes de domínio, 76 de animação/apresentação, 67 de fuzz, 19 de combate ponta a ponta (403 casos) e a ausência de validação de runtime. Contagens de 227/62 e artefatos de 297.737 bytes pertencem à rodada de 14/08; 235/73/29 e 337 casos pertencem à rodada da manhã de 15/08; 239/73/67/14 e 393 casos pertencem à tarde de 15/08; 241/73/67/19 e 400 casos pertencem à rodada do CI Linux no início de 16/08.

## Consolidação automatizada adicional

Após o snapshot `d7c44e8`, foram adicionadas validações puras em `SceneryPresentation.validateLayout(Zones)`. Elas verificam paletas RGB, limites de densidade de rochas e grama, transparência e altura do teto, fontes CC0 auditáveis, âncoras obrigatórias em suas zonas, distância mínima entre shards e distância mínima dos shards aos portões. Essas regras não tocam Instances e podem ser executadas no harness Lune.

Também foi adicionada uma regressão A1 para o blocking procedural do **Ombro Cometa**. O teste fixa o instante autoritativo de impacto em 0,40 s, verifica recolhimento corporal, inclinação do ombro, rotação do tronco, braço fechado para diferenciar a técnica de um soco e retorno visual ao neutro. O teste não declara que existe um clipe final nem substitui o gate A1 no Roblox Studio.

A receita de build existente em `scripts/build-studio.ps1` continua sendo a fonte de geração do artefato de Play. `scripts/ci.sh` só valida a árvore em `/tmp/build.rbxl` e não deve ser aberto no Studio. O bridge permanece limitado a sincronização e inspeção; não foi alegado que ele executa Play, tira screenshots ou mede dispositivos reais.

Nesta rodada, o domínio passou com **241 casos**, a animação/apresentação com **76**, o fuzz de segurança com **67** e a simulação de combate ponta a ponta com **19**. A validação total alinhou a spec ao catálogo travado (dummy 5 / Estilhaço 60-8-4 / elite 120-14 / Cometa 14 / Cadência 7+9 eco 6 / Pulso contra 10), corrigiu o doc de áudio (15 deixas, 33 ogg, 305 no banco Kenney, placeholders tocáveis) e passou a recusar frases obsoletas via `scripts/audit_snapshot.py --check`. O dummy **não** ataca no Heartbeat: a função existe, o teste de domínio a cobre, o bootstrap não liga — isso fica travado até o Play. O total automatizado atual é **403 casos**. Selene, StyLua, Rojo, as duas auditorias e as quatro suítes Lune passaram. Isso continua sendo evidência de contratos, apresentação pura, integridade de arquivo e árvore de build; não é evidência de boot, colisão, replicação, latência, Android, gamepad, DataStore real, upload de textura/áudio CC0 ou qualidade visual final. Nenhuma imagem gerada foi ligada ao place.

O achado da câmera do pesado básico (`abilityId = "heavy"` fora de `HEAVY_ABILITIES`) permanece pinado: o teste fixa o trauma igual ao jab. Só o Play decide se isso muda.

A conclusão recomendada permanece: no PC, `lune run scripts/avb-debug.luau home`, abrir o place canônico, executar W1, registrar evidência de runtime, depois A1/R1/W2. Nenhuma dessas validações externas deve ser marcada como concluída apenas por estes testes.

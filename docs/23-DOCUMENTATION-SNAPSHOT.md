# Snapshot Canônico da Documentação — 14/08/2026

Este arquivo é a referência única para o estado técnico atual do repositório. Os demais documentos preservam decisões e histórico de implementação, mas afirmações antigas sobre commits, contagens de testes ou artefatos devem ser interpretadas como registros históricos quando divergirem deste snapshot.

## Estado atual

| Campo | Estado canônico |
|---|---|
| Branch publicado | `main` |
| Commit-base do código | `d7c44e8` + cobertura adversarial headless desta rodada; hash final será registrado no release commit |
| Estado deste documento | consolidação posterior de documentação, testes e pré-cobertura R1; o hash final é informado no release commit |
| Data do commit | 2026-08-14 |
| Última alteração de código-base | `feat(scene): expand walls spawn roof and terrain` |
| Testes de domínio | 226 passaram, 0 falharam |
| Testes de animação/apresentação | 55 passaram, 0 falharam |
| Selene | 0 erros, 0 warnings, 0 parse errors nesta rodada |
| StyLua | não executado nesta rodada: binário não disponível no ambiente |
| Rojo | build aprovado; check local de 293.560 bytes |
| Runtime Roblox Studio | ainda não validado neste snapshot |
| Dispositivos reais | Android, gamepad e PC integrado ainda não validados neste snapshot |
| DataStore publicado | ainda não validado em place privado |
| Múltiplos clientes | isolamento de sequência/orçamento coberto headless; latência real, spam, network ownership e dois clientes ainda não validados |

## O que está implementado

O repositório contém a fatia de combate server-authoritative, as três habilidades F0, progressão e quests, inimigo comum e elite, VFX de jogador e inimigos, skins procedurais, paredes decoradas, teto translúcido no spawn, terreno contínuo, rochas e grama procedurais, além da documentação de assets CC0.

O build e os testes automatizados demonstram integridade de código, contratos puros, catálogos, geometria, segurança modelada, apresentação procedural e árvore Rojo. Eles não demonstram que Parts, joints, iluminação, prompts, física, câmera, replicação, DataStore ou dispositivos reais funcionam como esperado dentro do Roblox Studio.

## Próximo estado recomendado

A ordem oficial continua sendo **sincronização do Studio → W1 de leitura do mundo → impacto real dos golpes → A1 do Ombro Cometa → R1 adversarial → W2 de performance e dispositivos → fechamento da F0**. A F1 de loadout, Ressonância e múltiplas identidades só deve começar depois dos gates da F0 ou de uma decisão explícita de escopo.

## Regra de leitura dos documentos

Quando um documento mencionar commits como `108be31`, `d0f6f8d`, contagens como 166, 169, 238 ou 49 testes, ou artefatos antigos de 160.553/128.744 bytes, essas referências são históricas e não representam o snapshot atual. Para esta consolidação, usar o commit final informado no GitHub, 226 testes de domínio, 55 testes de animação/apresentação e a ausência de validação de runtime.

## Consolidação automatizada adicional

Após o snapshot `d7c44e8`, foram adicionadas validações puras em `SceneryPresentation.validateLayout(Zones)`. Elas verificam paletas RGB, limites de densidade de rochas e grama, transparência e altura do teto, fontes CC0 auditáveis, âncoras obrigatórias em suas zonas, distância mínima entre shards e distância mínima dos shards aos portões. Essas regras não tocam Instances e podem ser executadas no harness Lune.

Também foi adicionada uma regressão A1 para o blocking procedural do **Ombro Cometa**. O teste fixa o instante autoritativo de impacto em 0,40 s, verifica recolhimento corporal, inclinação do ombro, rotação do tronco, braço fechado para diferenciar a técnica de um soco e retorno visual ao neutro. O teste não declara que existe um clipe final nem substitui o gate A1 no Roblox Studio.

A receita de build existente em `scripts/build-studio.ps1` continua sendo a fonte de geração do artefato: instala Wally, respeita lock vivo do Studio, remove apenas lock órfão, gera o `.rbxl` esperado, verifica tamanho/data e imprime SHA-256. O bridge permanece limitado a sincronização e inspeção; não foi alegado que ele executa Play, tira screenshots ou mede dispositivos reais.

Nesta rodada, a suíte de animação passou com **55 casos**, a suíte de domínio passou com **226 casos**, e foram adicionados dois cenários headless de dois jogadores para o Gate R1. O total automatizado atual é **281 casos**. Selene, Rojo e `git diff --check` passaram; StyLua não foi executado porque o binário não está disponível neste ambiente. Isso continua sendo evidência de contratos, apresentação pura e árvore de build; não é evidência de boot, colisão, replicação, latência, Android, gamepad, DataStore real ou qualidade visual final.

A conclusão recomendada permanece: preparar e abrir o artefato atual no Studio, executar W1, registrar evidência de runtime, depois A1/R1/W2. Nenhuma dessas validações externas deve ser marcada como concluída apenas por estes testes.

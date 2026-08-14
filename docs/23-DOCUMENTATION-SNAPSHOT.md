# Snapshot Canônico da Documentação — 14/08/2026

Este arquivo é a referência única para o estado técnico atual do repositório. Os demais documentos preservam decisões e histórico de implementação, mas afirmações antigas sobre commits, contagens de testes ou artefatos devem ser interpretadas como registros históricos quando divergirem deste snapshot.

## Estado atual

| Campo | Estado canônico |
|---|---|
| Branch publicado | `main` |
| Commit atual | `d7c44e811d3f168526f1ea63d0de9d93e7c7c7bb` |
| Data do commit | 2026-08-14 |
| Última alteração | `feat(scene): expand walls spawn roof and terrain` |
| Testes de domínio | 224 passaram, 0 falharam |
| Testes de animação/apresentação | 54 passaram, 0 falharam |
| Selene | 0 erros, 0 warnings, 0 parse errors |
| StyLua | check aprovado |
| Rojo | build aprovado; artefato local de 292.019 bytes |
| Runtime Roblox Studio | ainda não validado neste snapshot |
| Dispositivos reais | Android, gamepad e PC integrado ainda não validados neste snapshot |
| DataStore publicado | ainda não validado em place privado |
| Múltiplos clientes | ainda não validados com latência e spam adversarial |

## O que está implementado

O repositório contém a fatia de combate server-authoritative, as três habilidades F0, progressão e quests, inimigo comum e elite, VFX de jogador e inimigos, skins procedurais, paredes decoradas, teto translúcido no spawn, terreno contínuo, rochas e grama procedurais, além da documentação de assets CC0.

O build e os testes automatizados demonstram integridade de código, contratos puros, catálogos, geometria, segurança modelada, apresentação procedural e árvore Rojo. Eles não demonstram que Parts, joints, iluminação, prompts, física, câmera, replicação, DataStore ou dispositivos reais funcionam como esperado dentro do Roblox Studio.

## Próximo estado recomendado

A ordem oficial continua sendo **sincronização do Studio → W1 de leitura do mundo → impacto real dos golpes → A1 do Ombro Cometa → R1 adversarial → W2 de performance e dispositivos → fechamento da F0**. A F1 de loadout, Ressonância e múltiplas identidades só deve começar depois dos gates da F0 ou de uma decisão explícita de escopo.

## Regra de leitura dos documentos

Quando um documento mencionar commits como `108be31`, `d0f6f8d`, contagens como 166, 169, 238 ou 49 testes, ou artefatos antigos de 160.553/128.744 bytes, essas referências são históricas e não representam o snapshot atual. Para o estado atual, usar sempre este arquivo e registrar o commit `d7c44e8`, 224 testes de domínio, 54 testes de animação/apresentação e a ausência de validação de runtime.

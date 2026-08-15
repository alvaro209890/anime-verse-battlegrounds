# 25 — Plano de apresentação de combate e assets abertos

> **Estado:** proposta implementável e referências visuais geradas; a validação em Roblox Studio ainda não foi executada.

## 1. Objetivo

Este documento define a próxima melhoria visual do F0 para três ações que precisam ser legíveis sem alterar a autoridade do servidor: **defesa**, **dash de corrida** e **impacto de chão quebrando**. A regra, o dano, o alcance, o cooldown, a posição final e a confirmação de bloqueio continuam server-side. O cliente apenas antecipa uma apresentação local de baixa consequência e só apresenta contato confirmado quando recebe `CombatEvent`.

A direção visual combina **slate escuro**, energia **ciano** para proteção e deslocamento, e **âmbar** para atrito, estilhaço e impacto. O objetivo é densidade antes de tamanho: poucos elementos, mas cada elemento comunica uma fase de ação.

## 2. Diagnóstico do código atual

| Área | Situação encontrada | Decisão desta rodada |
|---|---|---|
| `PlayerCombatAnimator` | Defesa e dash já são poses puras, mas o dash usa uma única pose sustentada e não comunica preparação, aceleração e recuperação separadamente | Adicionar fases de pose mais distintas e manter a raiz visual sem escrever posição física |
| `AbilityVfx` | O player já resolve receitas por `action`, com envelopes de intensidade, luz, assets opcionais e validação de raio | Adicionar receitas locais `GuardDown` e `Dash`, reutilizando o mesmo contrato testado |
| `AbilityVfxPlayer` | Camadas locais podem ser planejadas sem confirmação; camadas de contato exigem confirmação autoritativa | Usar apenas camadas não-confirmadas para guarda/dash e não declarar bloqueio ou acerto |
| `init.client.lua` | Ativação de habilidade chama VFX; ações de defesa/dash chamam apenas animação | Conectar defesa/dash ao mesmo player de VFX no callback de input |
| Assets Roblox | IDs publicados não são necessários para o fallback procedural | Manter `assetId` vazio e usar chaves preparadas somente como costura futura |

## 3. Receitas de apresentação

### 3.1 Defesa

Ao pressionar defesa, a pose fecha os braços, dobra joelhos e reduz a silhueta. A apresentação recebe uma casca ciano curta no torso e um anel de base. Esses elementos não significam que o jogador bloqueou um golpe; são apenas o estado visual de postura. O resultado confirmado de `guard` continua vindo do servidor e mantém seu próprio feedback.

### 3.2 Dash de corrida

O dash será lido em três momentos: preparação curta com compressão do corpo, aceleração com inclinação e passada, e recuperação com peso retornando ao centro. O VFX local usa um rastro ciano próximo ao torso, um anel âmbar nos pés e um burst curto de atrito no chão. Nenhum elemento cria teleport, hitbox, deslocamento autoritativo ou colisão.

### 3.3 Chão quebrando

O chão quebrando é uma **camada de apresentação temporária**, não uma alteração do mapa. A receita usa anel, faíscas, poeira e estilhaços; a materialização futura deverá usar pool de Parts ou partículas para não criar e destruir Instances a cada frame. A imagem conceitual mostra a leitura desejada, mas o jogo deve manter o piso intacto e navegável.

## 4. Referências visuais geradas

| Arquivo | Uso planejado |
|---|---|
| `docs/assets/combat-presentation-reference.png` | Referência de paleta, escala, câmera e linguagem de materiais para todo o pacote |
| `docs/assets/defense-guard-presentation.png` | Silhueta da defesa, casca ciano, órbitas e faíscas de deflexão |
| `docs/assets/dash-run-presentation.png` | Poses de preparação, corrida, afterimage, rastro de pé e atrito |
| `docs/assets/ground-break-impact-presentation.png` | Sequência de anel, crack, estilhaços, poeira e dissipação |
| `docs/assets/impact-vfx-micro-library.png` | Biblioteca visual de motivos pequenos para futura composição procedural |

As imagens acima são **referências conceituais originais geradas por IA**. Elas não são Roblox decals, não foram publicadas como IDs e não comprovam integração no runtime.

## 5. Assets abertos candidatos

| Fonte | Material útil | Licença verificada | Uso futuro planejado |
|---|---|---|---|
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | 80 sprites, cookies de luz e elementos VFX 2D | Creative Commons CC0 | Flipbooks de poeira, faíscas e anéis depois de preparação e upload |
| [ambientCG Concrete 039](https://ambientcg.com/view?id=Concrete039) | Concreto quebrado/áspero, mapas 1K–8K | Creative Commons CC0 | Material de piso e células de ruína, preferencialmente versão 1K para teste |
| [ambientCG Ground 072](https://ambientcg.com/view?id=Ground072) | Terra, areia, folhas e gravetos, mapas 1K–8K | Creative Commons CC0 | Base de terreno e variações de solo no Distrito Lumen |
| [Poly Haven](https://polyhaven.com/) | Biblioteca de texturas, HDRIs e modelos | CC0 | Materiais de cenário e iluminação de referência, sempre com registro do asset específico |

Nenhuma fonte externa foi copiada para o place nesta rodada. O catálogo é uma lista auditável de candidatos; qualquer download futuro deverá registrar URL, nome exato, versão, hash do arquivo, licença e preparação realizada.

## 6. Limites de integração

O cliente pode iniciar a pose e as camadas de antecipação ao receber o input local, mas o servidor continua sendo a única fonte para dano, alcance, cooldown, custo, guarda confirmada, posição e resultado. Camadas de impacto que possam ser interpretadas como acerto devem permanecer atrás de confirmação de `CombatEvent`.

A animação procedural não escreve `HumanoidRootPart.CFrame`, não concede deslocamento e não muda hitbox. O dash visual apenas acompanha o `DashIntent`; o `PlayerMotionGuard` e o `SpatialService` continuam validando e aplicando o movimento autoritativo.

## 7. Gates

O recorte está pronto para lint, testes de amostragem, validação de catálogo e build Rojo. O Gate A1 visual, o Gate W1 de cenário e o Gate R1 de dois clientes reais continuam pendentes até abrir o artefato no Roblox Studio.

## Referências

[1]: https://kenney.nl/assets/particle-pack "Kenney Particle Pack"

[2]: https://ambientcg.com/view?id=Concrete039 "ambientCG Concrete 039"

[3]: https://ambientcg.com/view?id=Ground072 "ambientCG Ground 072"

[4]: https://polyhaven.com/ "Poly Haven — CC0 public asset library"

[5]: https://creativecommons.org/publicdomain/zero/1.0/ "Creative Commons CC0 1.0"

## 8. Manifesto de integridade das referências

Os hashes abaixo identificam exatamente os PNGs presentes neste commit. Eles servem para detectar substituição acidental antes de qualquer recorte, atlas ou upload futuro.

| Arquivo | Dimensão | SHA-256 |
|---|---:|---|
| `combat-presentation-reference.png` | 2560×1440 | `703ff24cb722725d8e38a859478266713c738c999f54aa95a3266f1dee2e4a6f` |
| `defense-guard-presentation.png` | 2176×1632 | `d869d34a51c445cd4a4a6e85991cf4b06fcb0c27a53ef8bfe6264f30f72bac0c` |
| `dash-run-presentation.png` | 2176×1632 | `f3523f39ddcff2d40f681cb18071359a9dd6cb6a5ecb9267a47dfb535f8301d8` |
| `ground-break-impact-presentation.png` | 2176×1632 | `5528ddee28adcf057cfac5df42e52bdee18a500ac6ae3dbe72ca56154775f60a` |
| `impact-vfx-micro-library.png` | 2560×1440 | `64afdbef9cd9f36bb2199904f22cec030b62ba3c15223238edd1824ce8873f2c` |


## 9. Matriz de validação visual e uso futuro

As imagens deste pacote deixam de ser apenas moodboards e passam a ter um uso documental controlado: cada uma serve como referência de comparação, mas sua aprovação depende de critérios observáveis e de evidência real no Studio. O índice navegável está em `../VISUAL-REFERENCE-INDEX.md` e o protocolo reproduzível está em `26-VISUAL-VALIDATION-CHECKLIST.md`.

| Imagem | Critério visual primário | Código/receita relacionada | Uso futuro possível | Gate obrigatório |
|---|---|---|---|---|
| `combat-presentation-reference.png` | Escala, contraste, câmera e hierarquia | `PlayerCombatAnimator`, `AbilityVfx` | Direção de arte, loading e review interno | A0/A1 |
| `defense-guard-presentation.png` | Postura fechada, mãos/cotovelos e leitura de estado | `PlayerCombatAnimator`, `guard_raise` | Preview de defesa e tutorial | A1 + evento server-side para confirmar bloqueio |
| `dash-run-presentation.png` | Quatro fases, passada e recuperação | `PlayerCombatAnimator`, `dash_run` | Tutorial, preview e guia de movimento | A1/R1 |
| `ground-break-impact-presentation.png` | Ordem temporal de crack, poeira e debris | `dash_run`, futuras receitas de impacto | VFX temporário e guia de chão destruível | A1/W1/W2 |
| `impact-vfx-micro-library.png` | Reuso de motivos sem excesso de partículas | `AbilityVfx` e futuro pool de VFX | Biblioteca de telegraphs e feedback confirmado | A0/W2 |

### Estados de promoção

Cada referência deve avançar por estados explícitos: **Conceito**, **Receita headless**, **Candidato de produção** e **Runtime validado**. A transição para Candidato de produção exige decisão de formato (mesh, textura, sprite ou somente direção), revisão de licença, orçamento mobile e plano de integração. A transição para Runtime validado exige captura no Studio, verificação de câmera, colisão, performance e comportamento sob latência.

### Critérios visuais fixados

A comparação deve incluir frente, perfil e três quartos, além de uma captura sem VFX e outra com efeitos reduzidos. A defesa precisa manter mãos e cotovelos legíveis e retornar ao neutro. O dash precisa mostrar compressão, aceleração, passada e recuperação sem teleporte visual ou foot sliding grave. O chão quebrando precisa seguir marcação → anel → crack → poeira/debris → dissipação, sem alterar colisão por conta própria.

As imagens não autorizam dano, bloqueio, deslocamento, alteração de piso, persistência de debris ou recompensa. Esses efeitos só podem ser promovidos com contratos server-side próprios. O checklist completo de captura e decisão está em `docs/26-VISUAL-VALIDATION-CHECKLIST.md`.

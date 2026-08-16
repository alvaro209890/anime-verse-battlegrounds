# 26 — Checklist de validação visual

## Objetivo

Este documento transforma as imagens conceituais em um protocolo de comparação reproduzível. Ele separa três evidências que não podem ser confundidas: **referência artística**, **invariante headless** e **comportamento observado no Roblox Studio**.

> Uma imagem pode orientar uma decisão visual, mas não prova que uma pose, VFX, colisão, câmera ou regra de combate funciona no runtime.

> **A ordem de execução da sessão está em [`docs/32-STUDIO-PLAYTEST-RUNBOOK.md`](32-STUDIO-PLAYTEST-RUNBOOK.md)**, com o porteiro de sincronia (fora de sync não se mede), o que capturar por passo e os limites de desempenho. Este documento continua sendo a FICHA e os critérios visuais; o runbook é a ordem do dia.

## Ficha obrigatória da sessão

Preencher uma ficha por ação ou cenário validado.

| Campo | Valor |
|---|---|
| Commit/hash do build | preencher antes da captura |
| Arquivo `.rbxl` e SHA-256 | preencher antes da captura |
| Referência visual | caminho exato do PNG e hash |
| Documento de origem | `docs/25`, `docs/14`, `docs/15` ou `docs/24` |
| Sistema observado | pose, VFX, HUD, mundo ou combinação |
| Plataforma | PC, Android ou gamepad |
| Resolução e escala | preencher |
| Preset gráfico | preencher |
| FPS e frame time | preencher |
| Câmera | frente, perfil, três quartos ou padrão de jogo |
| Ação executada | sequência exata de inputs |
| Resultado | aprovado, retrabalhar ou cortar |
| Divergência | descrever sem usar “ficou diferente” isoladamente |
| Evidência | capturas/vídeo e Output relevante |

## Critérios gerais de aprovação

A referência deve orientar a decisão, mas a aprovação depende do comportamento observado. Marcar cada item como `passou`, `falhou` ou `não aplicável`.

| Critério | Passa quando | Falha quando |
|---|---|---|
| Silhueta | A ação é reconhecível em até 0,25 s nas três câmeras | A pose parece idle, ataque ou corrida diferente |
| Fases | Entrada, sustentação/passada e recuperação são distinguíveis | O efeito é uma pose única ou corta no meio |
| Raiz física | A apresentação não escreve a posição autoritativa | A animação teleporta, desloca hitbox ou mascara correção |
| Foot sliding | Pés acompanham o deslocamento observado | Pés escorregam ou ficam presos no solo |
| Interseção | Não há clipping grave entre braços, torso, chão e VFX | Partes atravessam o corpo ou o chão de forma evidente |
| Contraste | Telegráfico e personagem permanecem legíveis no fundo | Efeito some ou satura a silhueta |
| Acessibilidade | Não depende apenas de cor; há forma, símbolo ou timing | Jogador não distingue estado sem cor específica |
| Escala | Raio, duração e densidade respeitam o envelope da receita | Efeito domina a cena, cobre HUD ou gera spam visual |
| Recuperação | O estado volta ao neutro sem pose congelada | Personagem permanece inclinado ou com VFX órfão |
| Desempenho | FPS/frame time ficam dentro do alvo da plataforma | Há spike, queda sustentada ou degradação térmica |

## Defesa

Referência: `docs/assets/defense-guard-presentation.png`.

Executar `GuardDown`, sustentar por uma janela curta e liberar. Capturar entrada, sustentação e saída em frente, perfil e três quartos, primeiro sem VFX e depois com efeitos reduzidos.

A postura deve comunicar absorção: braços fechados, cotovelos e punhos legíveis, joelhos estáveis e retorno ao neutro. A casca ciano e o anel são apenas feedback local antecipado. A aprovação de **bloqueio** exige evento confirmado pelo servidor; VFX local sozinho não pode ser usado como prova.

## Dash de corrida

Referência: `docs/assets/dash-run-presentation.png`.

Executar o dash em espaço livre e próximo de uma borda segura. Capturar quatro momentos: compressão, aceleração, passada e recuperação. Comparar o deslocamento observado com o movimento autorizado pelo servidor e registrar qualquer correção de rede.

O rastro, afterimage, anel de atrito e burst de chão devem seguir o personagem, terminar por duração finita e não alterar colisão. Falha de leitura, teleporte visual, foot sliding forte ou debris permanente exige retrabalho.

## Chão quebrando e impacto

Referência: `docs/assets/ground-break-impact-presentation.png` e `docs/assets/impact-vfx-micro-library.png`.

Registrar a ordem temporal: marcação do ponto, anel, crack, poeira, debris e dissipação. Confirmar que o efeito é temporário, usa pool quando implementado e não cria/destrói objetos a cada frame.

A referência não autoriza buraco, alteração de colisão ou dano ambiental. Qualquer mudança de chão deve ter contrato próprio no servidor, teste de geometria e gate separado de mundo/performance.

## Integração com mundo e HUD

Para `domain-expansion-safe-plaza.png`, `domain-expansion-border-gate.png` e `domain-expansion-district-lumen.png`, executar W1: spawn, praça, portões, rotas, transição entre zonas, prompts, cobertura e leitura dos materiais. Registrar também uma captura com efeitos de combate reduzidos para verificar se a navegação continua clara.

Para previews de habilidade, tutorial ou loading screen, usar as referências apenas como direção. A tela final deve ter composição própria, texto localizado e versão adequada ao dispositivo; um PNG conceitual não é automaticamente UI de produção.

## Matriz de evidência

| Gate | O que a referência ajuda a avaliar | Evidência que ainda é obrigatória |
|---|---|---|
| A0 | Direção, originalidade e coerência visual | Review de referência e decisão de escopo |
| A1 | Pose, fases, VFX e leitura do poder | Play no Studio, capturas, profiling e três câmeras |
| W1 | Densidade, rotas, spawn, portões e cenário | Build aberto no Studio e checklist de navegação |
| R1 | Separação entre feedback e autoridade | Dois clientes, latência, spam, rejeições e network ownership |
| W2 | Performance e degradação por plataforma | PC/Android/gamepad, MicroProfiler e sessão sustentada |

## Registro de divergência

Descrever divergências em termos observáveis: “o rastro termina 0,3 s depois da recuperação”, “o punho esquerdo atravessa o torso no perfil”, “o crack cobre a rota do portão”, “o VFX local aparece sem `CombatEvent` confirmado” ou “o frame time excede o alvo no Android”. Evitar conclusões vagas como “a imagem não ficou igual”.

## Limites de licença e procedência

PNG gerado por IA permanece conceito original do projeto e deve ser referenciado por hash. Assets externos abertos devem ter licença, URL, versão, data de acesso e localização documentados antes de integração. O protocolo visual não substitui revisão de licença, otimização ou aprovação de produção. A matriz de promoção (vitrine vs. PBR vs. F1-only vs. não importar) está em [`docs/33-ASSET-USABILITY.md`](33-ASSET-USABILITY.md); os hashes conferidos no CI estão em [`docs/assets/visual-inventory.json`](assets/visual-inventory.json).


## Habilidades futuras

As imagens do catálogo `docs/27-FUTURE-ABILITY-ASSET-CATALOG.md` orientam somente revisão e planejamento. Quando uma habilidade futura receber uma spec server-side, aplicar os critérios abaixo antes de considerá-la pronta para produção.

| Família | Evidência visual mínima | Risco a observar |
|---|---|---|
| Projétil | Carga, lançamento, trajetória, impacto confirmado e dissipação | Trail pode sugerir acerto ou alcance que o servidor não autorizou |
| Área/domínio | Perímetro, pulsos, centro e saída legíveis em câmera distante | Anel visual pode ser confundido com zona PvP ou colisão |
| Mobilidade | Preparação, burst, chegada e recuperação com correção de rede visível | Afterimage pode mascarar teleporte, invulnerabilidade ou posição inválida |
| Constructo | Spawn, idle, telegraph, despawn e limite de quantidade | Silhueta não prova ownership, vida, dano ou persistência |
| Barreira/parry | Postura, janela, deflexão e quebra em três câmeras | Escudo local não prova bloqueio ou dano negado |
| Ultimate | Charge, assinatura, impacto contido, recuperação e efeitos reduzidos | Excesso de partículas, câmera incapacitante e degradação mobile |
| Ruptura de cenário | Marca, crack, debris, poeira, restauração e navegação contínua | VFX pode parecer alteração persistente de colisão ou mapa |

Toda nova ficha precisa registrar a referência usada, o hash, o build, a plataforma e o evento server-side que confirma qualquer efeito de gameplay. Antes desse evento existir, somente a camada de antecipação visual pode ser avaliada.

# 27 — Catálogo de assets para habilidades futuras

## Objetivo e limites

Este catálogo prepara a produção de habilidades ainda não implementadas sem antecipar regras de combate. Ele conecta referências visuais, assets públicos candidatos, possíveis receitas de apresentação, locais de uso no jogo e gates necessários.

> **Estado atual:** as imagens geradas são conceitos; o pacote Kenney é candidato externo arquivado; nenhuma habilidade desta página está integrada ao runtime ou autorizada a alterar dano, alcance, cooldown, custo, posição, colisão ou PvP.

O índice geral está em [`VISUAL-REFERENCE-INDEX.md`](../VISUAL-REFERENCE-INDEX.md). O protocolo de captura está em [`26-VISUAL-VALIDATION-CHECKLIST.md`](26-VISUAL-VALIDATION-CHECKLIST.md).

## Estados de promoção

| Estado | O que significa | Evidência mínima |
|---|---|---|
| **Conceito** | Imagem original para direção de arte e discussão | Arquivo, hash e finalidade documentados |
| **Candidato externo** | Asset público separado do runtime | URL oficial, licença, versão, hash e conteúdo inspecionado |
| **Receita headless** | Parâmetros visuais puros, sem Instances | Testes de envelope, fases e autoridade |
| **Asset de produção** | Conversão otimizada para Roblox | Formato, tamanho, atlas/pooling, licença e revisão |
| **Runtime validado** | Observado no Studio e nos dispositivos-alvo | Capturas, profiling, replicação e gate aprovado |

## Matriz de habilidades futuras

| Família | Referência | Apresentação futura | Possível uso dentro do jogo | Gate |
|---|---|---|---|---|
| Projétil energético | `assets/ability-future-energy-projectile.png` | Carga → núcleo → trail → impacto → dissipação | Preview de habilidade, tutorial, telegraph e VFX de runtime futuro | Spec server-side + A1/W2 |
| Área/domínio temporário | `assets/ability-future-area-domain.png` | Perímetro, pulsos, centro seguro, borda de risco | Tutorial de zona, preview e evento de domínio futuro | Spec de zona/PvP + R1/W2 |
| Mobilidade avançada | `assets/ability-future-mobility-burst.png` | Preparação → burst → afterimage → chegada → recuperação | Tutorial de movimento e preview | Movimento autoritativo + R1/A1 |
| Constructo invocado | `assets/ability-future-summon-construct.png` | Spawn → idle → telegraph → despawn | Preview, loading e futuro NPC temporário | Contrato de ownership, despawn e segurança |
| Barreira/parry | `assets/ability-future-barrier-parry.png` | Arco → janela → deflexão → quebra | Tutorial de defesa e feedback confirmado | Evento server-side de bloqueio + A1/R1 |
| Ultimate | `assets/ability-future-ultimate-composition.png` | Charge → assinatura → impacto controlado → recuperação | Loading, preview de ultimate e telegraph futuro | F1/F2, orçamento mobile e spec completa |
| Ruptura de cenário | `assets/ability-future-environment-break.png` | Marca → crack → debris → poeira → restauração | VFX temporário e futuro evento de cenário | Colisão/estado no servidor + W1/W2 |
| Microbiblioteca | `assets/ability-future-vfx-micro-library.png` | Anéis, trails, escudos, shards, cracks e poeira | Base de receitas procedurais e telegraphs | Revisão de reuso, densidade e acessibilidade |

## Fichas de uso

### Projétil energético

A referência orienta uma assinatura compacta e legível em linha reta. A futura receita deverá separar visualmente carga, lançamento e impacto, mas não poderá sugerir acerto antes de um evento confirmado. O Kenney Particle Pack pode fornecer círculos, trails e sparks como camadas auxiliares, sempre sob uma receita própria e com orçamento limitado.

### Área ou domínio temporário

A referência mostra uma fronteira que pode ser lida por forma, timing e contraste, não apenas por cor. Antes de implementação é necessário definir se a área é telegraph, zona de combate, buff ou domínio; cada opção terá autoridade e contrato diferentes. Nenhum círculo da imagem deve virar automaticamente uma região PvP.

### Mobilidade avançada

A referência deve ser usada para comparar preparação, direção e recuperação. A camada visual nunca escreve `CFrame` autoritativo nem confirma invulnerabilidade. A implementação futura precisa de limites server-side de velocidade, distância, colisão e correção de latência.

### Constructo invocado

O constructo é apenas uma silhueta de direção. Qualquer NPC futuro precisa de definição de ownership, vida, despawn, limite por jogador, telemetria, segurança e comportamento de late join antes de receber VFX ou modelo final.

### Barreira e parry

O arco da barreira pode orientar postura e janela visual, mas só o servidor pode confirmar bloqueio, aparo, dano negado ou contra-ataque. A imagem não deve ser usada para decidir a janela temporal sem uma spec de combate.

### Ultimate

A composição serve para direção cinematográfica e de câmera, não para criar uma ultimate automaticamente. A futura habilidade deverá respeitar loadout, impacto, recurso, cooldown, telemetria, acessibilidade, efeitos reduzidos e limites de dispositivos móveis.

### Ruptura de cenário

O crack, debris e poeira são candidatos a VFX temporário. Alteração persistente de piso, colisão ou navegação exige uma feature de mundo separada, com estado autoritativo, restauração, late join e testes de geometria.

## Assets públicos registrados

### Kenney Particle Pack

| Campo | Registro |
|---|---|
| Fonte oficial | [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) |
| Licença | Creative Commons CC0 |
| Escopo | 80 arquivos 2D/VFX, incluindo círculos, dirt, fire, flame e outros motivos |
| Arquivo local | `assets/open-candidates/kenney_particle-pack.zip` |
| SHA-256 | `b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958` |
| Tamanho local | 15.001.764 bytes |
| Uso planejado | Protótipos de anéis, poeira, trails e sparks após conversão/seleção |
| Estado | Candidato externo; não integrado ao Rojo, não executado e não usado pelo runtime |

O repositório alternativo [Calinou/kenney-particle-pack](https://github.com/Calinou/kenney-particle-pack) foi registrado apenas como empacotamento auxiliar; a licença deve ser conferida no arquivo `LICENSE.txt` antes de redistribuir qualquer subconjunto.

### ambientCG Concrete 006

| Campo | Registro |
|---|---|
| Fonte oficial | [Concrete 006](https://ambientcg.com/view?id=Concrete006) |
| Licença | CC0, conforme a página do asset e a licença do ambientCG |
| Formatos | 1K/2K/4K/8K em JPG ou PNG, com pacotes PBR |
| Uso planejado | Material de piso, laje, ruína e célula urbana futura |
| Estado | Candidato não baixado; selecionar 1K para mobile antes de qualquer integração |

### Poly Haven

| Campo | Registro |
|---|---|
| Fonte oficial | [Poly Haven License](https://polyhaven.com/license) |
| Licença | CC0 para HDRIs, texturas e modelos do acervo |
| Uso planejado | Materiais de pedra, concreto, solo e referências de iluminação |
| Limite | Usar somente páginas/arquivos oficiais; logos, renders de exemplo e conteúdo do site não são automaticamente CC0 |
| Estado | Candidato não baixado; asset específico deve ser registrado antes de uso |

## Regras de licença e integração

Cada asset externo deve entrar com URL oficial, licença do item específico, data de acesso, versão, hash e finalidade. Não copiar arquivos de Roblox Toolbox ou repositórios de terceiros sem verificar procedência. O pacote local de candidatos permanece fora de `src/` e não será referenciado automaticamente pelo place.

A conversão para Roblox deve documentar redução de resolução, formato, transparência, atlas, pooling, tamanho de memória, efeito no Android e qualquer atribuição exigida. A aprovação visual não substitui revisão de licença, e a licença não substitui aprovação de runtime.

## Testes e próximos gates

Antes de criar uma habilidade futura, adicionar spec server-side, dados, contrato de intenção, validações, cooldown, recurso, telemetria e testes de domínio. As receitas visuais só poderão ser adicionadas depois que o contrato existir. O catálogo pode ser validado headless quanto a arquivos, hashes e categorias; leitura estética, colisão, câmera, replicação e desempenho continuam gates A1/R1/W1/W2 no Studio.


## Manifesto de integridade

Todos os oito PNGs foram gerados como referências originais em 2560×1440. O candidato externo foi baixado da URL oficial do Kenney e permanece arquivado sem execução ou integração.

| Arquivo | Dimensão/tamanho | SHA-256 |
|---|---:|---|
| `assets/ability-future-area-domain.png` | 2560×1440 | `69f2dc66f1929d824b6c753733f53a3e8848683458d2c765fda12c20fcbbb1d3` |
| `assets/ability-future-barrier-parry.png` | 2560×1440 | `ad0334d176c3204ce73b29eebfc2988d32ac0c09c73a907834124d44a3b002c0` |
| `assets/ability-future-energy-projectile.png` | 2560×1440 | `aaac4a581409d9e69647432d0aae93d69828ad1d9670926aa365ac08dadbbe11` |
| `assets/ability-future-environment-break.png` | 2560×1440 | `ebb1e426b2bd3422a6788c3fcc3b68d68e353736468bdcccbe6e3df8ab3dd7e5` |
| `assets/ability-future-mobility-burst.png` | 2560×1440 | `49ceea65f975d8f2aadc7e715f6696b63002821a170c9c4abd0420323a6f2f7c` |
| `assets/ability-future-summon-construct.png` | 2560×1440 | `a8fbe1a0916933325210dfde99fffac52c13e399c571fe48cf7fc8de455ca6ba` |
| `assets/ability-future-ultimate-composition.png` | 2560×1440 | `df56f6713d7190c8f0b55f4019193e6a97ef8f9e11fd90364463d0834cd268ff` |
| `assets/ability-future-vfx-micro-library.png` | 2560×1440 | `14d15739c011032933d80e5cdb076f92dd12ece5c4b810622017e1576f5aa90e` |
| `assets/open-candidates/kenney_particle-pack.zip` | 15.001.764 bytes | `b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958` |

## Referências verificadas

[1] [Kenney Particle Pack — página oficial](https://kenney.nl/assets/particle-pack), Creative Commons CC0, 80 arquivos 2D/VFX.

[2] [Kenney Particle Pack — empacotamento auxiliar](https://github.com/Calinou/kenney-particle-pack), registrado apenas como fonte alternativa e sujeito à conferência do `LICENSE.txt`.

[3] [ambientCG Concrete 006](https://ambientcg.com/view?id=Concrete006), material PBR disponível em múltiplas resoluções, publicado sob CC0.

[4] [Poly Haven — licença](https://polyhaven.com/license), acervo de HDRIs, texturas e modelos sob CC0, com conteúdo do site separado dos assets.

# Atlas Visual — Expansão de Domínio

**Projeto:** Anime Verse Battlegrounds  
**Estado:** primeira célula urbana densa do Distrito Lumen materializada em dados (17/08/2026); imagens de conceito continuam referência, não asset jogável

**Escopo:** Bastião do Limiar → Planície Estilhaçada → Distrito Lumen  
**Autor:** Manus AI  
**Data:** 2026-08-14 (célula F1: 2026-08-17)

> Este documento é uma ilustração de direção de arte e composição de mundo. As imagens geradas por IA abaixo são referências originais de conceito; elas **não são textura nem planta importada**. A primeira célula do Lumen existe como catálogo em `BiomeDecorations.luau` (ver §7). Volumes de zona, streaming e gates W2 de memória/render continuam independentes desta arte.

## 1. Visão geral

A expansão de domínio transforma o mapa inicial em uma sequência visual legível: o jogador começa no **Bastião do Limiar**, atravessa uma saída segura com aviso redundante, percorre a **Planície Estilhaçada** e avista o **Distrito Lumen** como primeiro grande destino urbano. A composição preserva as regras do planejamento: pelo menos duas saídas, rotas de retirada, fronteira de risco impossível de confundir com decoração, densidade antes de tamanho e expansão por células.

![Ilustração geral da expansão de domínio](assets/domain-expansion-concept.png)

A imagem geral deve ser usada como **capa do planejamento de mundo**, referência para escala e revisão de identidade visual. Ela não deve ser importada como textura de terreno ou usada como mapa navegável.

## 2. Imagens e aplicação planejada

| Arquivo | Uso no projeto | Fase | Status |
|---|---|---:|---|
| `domain-expansion-concept.png` | Capa do atlas, escala entre Bastião, planície, fronteira e Distrito Lumen | F0 → F1/F2 | Referência original |
| `domain-expansion-district-lumen.png` | Direção de arte do primeiro centro urbano: ruas, vielas, passarelas, praça e marco vertical | F1/F2 | Referência original |
| `domain-expansion-safe-plaza.png` | Planejamento da praça coberta, spawn, treinamento, serviços e duas saídas do Bastião | F0 → F1 | Referência original |
| `domain-expansion-border-gate.png` | Especificação visual da transição segura/livre: portão, beacons, material de solo e rota de retorno | F0 | Referência original |
| `domain-expansion-modular-ruins.png` | Biblioteca conceitual de paredes, torres, pontes, plataformas, cristais e ruínas reutilizáveis | F1/F2 | Referência original |
| `domain-expansion-vfx-moodboard.png` | Direção de telegraphs, fronteiras, marcadores de rota, impactos e alertas de risco | F0 → F2 | Referência original |

### Distrito Lumen

![Distrito Lumen](assets/domain-expansion-district-lumen.png)

Esta imagem define a linguagem de uma cidade densa sem exigir que a primeira implementação já seja uma cidade completa. A primeira célula (17/08, §7) contém uma rua principal, duas vielas com linha de visão quebrada, uma praça, o marco `LumenTower`+coroa e dois postos visuais (Mercado e Forja). A verticalidade é só silhueta — sem plataformas de luta em altura. A imagem **não** foi copiada como asset.

### Praça segura

![Praça segura](assets/domain-expansion-safe-plaza.png)

A praça serve como referência para o spawn e para a área de serviços do Bastião. O teto translúcido continua sendo visual e sem colisão, conforme `docs/22-SCENERY-EXPANSION.md`. A versão de produção deve preservar o espaço de treino sem dano, o Instrutor, o Marco de Retorno, o quadro de missões, a forja e duas saídas legíveis.

### Portão de transição

![Portão de transição](assets/domain-expansion-border-gate.png)

O portão é o componente mais importante para a leitura de risco. A implementação futura deve combinar forma física, mudança de material, iluminação, posts repetidos, UI, áudio e confirmação de entrada. A cor nunca deve ser o único sinal. Projéteis, áreas, empurrões e teletransportes hostis não podem atravessar a fronteira causando dano.

### Biblioteca modular

![Biblioteca modular de ruínas](assets/domain-expansion-modular-ruins.png)

A imagem é uma referência de kit, não um atlas importável. Cada módulo futuro deve ser convertido em peça Roblox nativa ou modelo importado com escala, pivô, colisão, atributo de zona e orçamento de draw calls definidos. As peças não podem ocupar âncoras de NPC, volumes de transição ou corredores de combate sem uma regra explícita.

### Moodboard de VFX

![Moodboard de VFX](assets/domain-expansion-vfx-moodboard.png)

O moodboard organiza a hierarquia visual dos efeitos: **ciano** para rotas e fronteiras, **violeta** para domínio e energia, **âmbar** para alerta e impacto. O objetivo é orientar futuras receitas de `EnemyVfxPlayer`, `AbilityVfxPlayer` e telegraphs de zona, sem copiar efeitos de franquias existentes e sem deixar partículas substituírem texto ou ícones de risco.

## 3. Mapa conceitual da expansão

```mermaid
flowchart LR
    A[Spawn interno<br/>Bastião do Limiar] --> B[Praça segura<br/>treino e serviços]
    B --> C1[Portão norte<br/>transição de risco]
    B --> C2[Saída oeste<br/>rota alternativa]
    C1 --> D[Planície Estilhaçada<br/>zona livre / onboarding]
    C2 --> D
    D --> E1[Distrito Lumen<br/>cidade segura + borda livre]
    D --> E2[Cratera futura<br/>alto risco, pós-lançamento]
    E1 --> F[Praça central e serviços<br/>F1/F2]
    E1 --> G[Passarelas e vielas<br/>rotas com visão quebrada]
```

O diagrama é estrutural: ele orienta zonas, rotas e dependências; não é uma planta final com escala. O Bastião e a Planície continuam sendo o escopo de F0. O Distrito Lumen é o primeiro alvo pós-F0 e só deve avançar depois dos gates de runtime e densidade.

## 4. Inventário visual recomendado

| Categoria | Referência externa gratuita | Uso recomendado | Condição |
|---|---|---|---|
| Rochas, grama e natureza | Kenney Nature Kit, CC0 [1] | Prototipar rochas, vegetação e bordas naturais | Importar/publicar no Studio antes de usar como referência de runtime |
| Modelos modulares e natureza | Quaternius, catálogo de assets gratuitos [2] | Avaliar kits de cidade, ruína, natureza e props | Confirmar licença do pacote específico antes de copiar para o repositório |
| Materiais e modelos PBR | Poly Haven, CC0 [3] | Texturas de pedra, solo, metal e referências de iluminação | Converter para um orçamento compatível com Roblox/mobile |
| Assets 3D low-poly | OpenGameArt CC0 [4] | Buscar alternativas e comparar estilo | Verificar a licença do item individual e registrar créditos |
| Imagens de conceito deste documento | Geradas por IA para este projeto | Direção de arte, moodboard, revisão de composição | Não tratar como asset jogável ou garantia de licença de modelo 3D |

## 5. Ordem de produção futura

A primeira etapa deve ser consolidar a praça coberta do Bastião e o portão norte usando peças nativas e os parâmetros já existentes em `SceneryPresentation`. A segunda deve produzir a rota oeste e o terreno externo da Planície sem alterar os volumes de zona. A terceira — **feita em 17/08** — prototipa uma única célula do Distrito Lumen com uma rua, uma praça, dois postos visuais e duas vielas. A quarta deve medir streaming, memória, render, física e legibilidade em PC integrado, Android e gamepad antes de duplicar módulos.

A expansão não deve começar por uma grande cidade completa. O critério correto é uma célula urbana pequena, densa e com função sistêmica. Se essa célula não sustentar rotas, serviços, leitura de risco e combate legível, a arte deve ser reduzida antes de ampliar o mapa.

## 6. Limites e não-alucinação

As imagens deste documento **não** são evidência de runtime nem planta para copiar. A célula da §7 existe como dados e testes; Play no Studio e profiling de streaming/memória/câmera/gamepad continuam evidência à parte. As imagens também não definem hitbox, pathfinding, DataStore ou telemetria.

## 7. Célula urbana Lumen (F1, 17/08/2026)

Terceira etapa da §5. Catálogo puro em `src/shared/Data/BiomeDecorations.luau`; `WorldService` só materializa. Zona `zone_lumen_safe` inalterada: box(-160, -700, 160, -460), kind safe, piso Asphalt {28,24,42}. Âncoras, spawn de inimigo e números de combate não mudaram.

O que a célula contém:

| Elemento | Onde / como | Colisão | Luz real |
|---|---|---|---|
| Rua principal | eixo X=0, livre abs(x)<13, Z -470..-670 (praça no meio) | não | lampiões emissivos |
| Fachadas | 14 prédios ocos (W01-W07, E01-E07), alturas 11-26, variantes distintas | não | letreiros Neon |
| Skyline | 8 prédios altos (28-40) longe da rua — só silhueta | não | nervura Neon |
| Viela oeste | abertura z≈-508..-493 → jog em (-104, -548) → praça | não | 2 bolas emissivas |
| Viela leste | abertura z≈-523..-511 → jog em (116, -576) → praça | não | 2 bolas emissivas |
| Praça | disco asfalto 40 + cruz de inlay (não é anel de alcance) | não | cristal 16 studs |
| Marco | `LumenTower` 9×50×9, coroa, 4 nervuras, flecha | não | coroa 28 studs |
| Mercado | leste da praça (x≈54, z≈-598): bancada, toldo, caixas, letreiro | não | só Neon |
| Forja | oeste da praça (x≈-54, z≈-598): lar, chaminé, brasa bola, letreiro | não | só Neon |
| Borda sul | vão x -24..24, postes ±28, lintel, 6 postes de orla | não | caps Neon |

Contagens **medidas** no catálogo (não chutadas):

| Conjunto | Peças | PointLights | Sombras |
|---|---:|---:|---:|
| Prefixo `Lumen*` | 494 | 2 (`LumenCrown` 28 studs, `LumenPlazaCrystal` 16 studs) | 0 |
| `BiomeDecorations.all()` | 788 | 5 (teto 16) | 0 no Lumen |
| `WildDecorations.all()` | 1269 | 7 | — |
| Soma dos dois catálogos | 2057 | 12 | — |

Teto W2 do Workspace: 6000. Greybox (pisos, muros, atores, spawn) soma por cima destes 2057 e continua abaixo do teto. Letreiros e lampiões de rua **não** ganharam `PointLight` — só material Neon. Nenhuma luz declara alcance maior que o campo `rangeStuds`. Decoração não desenha anel lido como hitbox (praça deixou de ser disco Neon).

Suite no mesmo commit: 270 domínio + 79 animação + 71 fuzz; Selene 0/0/0; StyLua nos arquivos tocados; `rojo build -o build.rbxl` 407.098 B.

O que **não** entrou (de propósito):

- prompt / remote / sistema de compra ou forja — os postos são leitura visual;
- verticalidade de combate (passarelas `CanCollide=false`, sem piso de luta em altura);
- medição de streaming, memória, render, câmera ou gamepad — isso é a quarta etapa;
- segunda célula ou outra cidade;
- nome ou silhueta de cidade real.

Em 18/08 as outras quatro células ganharam densidade de leitura (sem
segunda célula urbana nem sistema de compra). O profiling de streaming
(§5 etapa 4) continua o próximo gate de mundo antes de duplicar o Lumen.

Os assets externos citados são candidatos de pesquisa. A presença de um link ou imagem de referência não significa que o arquivo foi importado, publicado, licenciado por uma conta Roblox ou adicionado ao place. Para produção, cada modelo deve ter origem, licença, escala, colisão, triagem de segurança e custo registrados.

## Referências

[1]: https://kenney.nl/assets/nature-kit "Kenney Nature Kit — CC0"
[2]: https://quaternius.com/ "Quaternius — Free Game Assets"
[3]: https://polyhaven.com/ "Poly Haven — CC0 3D Asset Library"
[4]: https://opengameart.org/content/cc0-assets-3d-low-poly "OpenGameArt — CC0 Assets 3D Low Poly"

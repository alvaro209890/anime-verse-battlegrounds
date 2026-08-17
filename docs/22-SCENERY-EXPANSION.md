# Expansão Visual do Cenário — 14/08/2026

> **Ampliação de 17/08, e por que não há modelo de catálogo aqui.**
>
> A planície foi de 160×120 para **480×400** e ganhou ~210 peças de vegetação
> (árvore frondosa, conífera, tronco morto, arbusto e pedra musgosa), geradas
> por LCG de **semente fixa** — determinístico, revisável no diff e idêntico
> entre máquinas. Sorteio real tornaria a validação intermitente, que é o pior
> estado possível para um gate.
>
> **Relevo (17/08):** serras e colinas entram no mesmo catálogo `WildDecorations`
> / `BiomeDecorations` — Blocks e WedgeParts grandes, sem colisão, sem luz nova.
> 1269 peças na planície (7 luzes) + 352 de bioma (10 luzes). O piso jogável
> permanece Y=0; o horizonte deixa de ser um campo vazio.

> Custo de contagem de partes da ampliação em si: **zero**. `buildFloors` cria
> uma Part por volume de zona, então o piso apenas fica maior. O que a
> ampliação cobra é decoração — campo vazio grande é pior que campo pequeno
> cheio.
>
> **Modelo grátis do Toolbox não sobrevive neste projeto.** O place é BUILDADO a
> partir do código (`rojo build`): qualquer coisa inserida à mão no Studio é
> apagada no próximo `build-studio.ps1`. Não é política, é o pipeline — inserir
> árvore do catálogo daria um mundo bonito que some no build seguinte.
>
> O caminho que funciona para asset externo é **referência por ID no código**:
> `MeshPart` com `MeshId`/`TextureId`, declarado em `WildDecorations` como
> qualquer outra receita. Hoje `deco()` só aceita `Part`/`WedgePart`; suportar
> `MeshPart` é uma extensão pequena e é o próximo passo natural se a vegetação
> primitiva não bastar. Referenciar só a MALHA (em vez de inserir o modelo
> inteiro) também evita o vetor conhecido de script malicioso em modelo grátis.

Esta atualização prepara o mundo existente para a próxima etapa de construção. A lógica de zonas, âncoras, portões, hitboxes e autoridade de combate permanece inalterada; a mudança atua na camada de materialização visual do `WorldService`.

## O que foi adicionado

| Área | Implementação |
|---|---|
| Paredes do Bastião | Revestimento Slate, tampas superiores, painéis verticais Neon e contraste de pedra escura. Os vãos dos portões continuam preservados. |
| Teto do spawn | Painel de vidro translúcido em `Y=22`, quatro vigas estruturais e duas linhas Neon orientando a praça. O teto não possui colisão para não prender jogadores ou invalidar o fluxo de câmera. |
| Terreno externo | Base visual contínua `PlainTerrain_Base`, com material Ground, rochas procedurais e tufos de grama distribuídos na planície. |
| Dados | Novo `SceneryPresentation.luau`, com cores, transparência, quantidades e fontes de assets. |
| Assets | Licença e manifesto do Kenney Nature Kit adicionados em `AVB-free-vfx-assets/assets/scenery/kenney_nature_kit/`. |
| Testes | Regressão para teto translúcido, tampas de parede, rochas, grama e fontes CC0. |

## Decisões de integração

A versão atual usa peças nativas do Roblox como materialização final porque o projeto é sincronizado por Rojo e os modelos DAE do Nature Kit precisam ser importados/publicados no Roblox Studio antes de serem referências válidas em runtime. O Nature Kit foi selecionado como fonte visual CC0 para rochas, grama e elementos naturais [1]. Para superfícies de rocha mais realistas, o Rock035 do ambientCG também foi catalogado como opção futura CC0 [2].

> A base de terreno é visual e contínua, mas as colisões autoritativas continuam vindo dos volumes das zonas e dos pisos existentes. Isso permite construir estruturas depois sem redefinir o domínio de navegação.

## Próximos passos estruturais

A sequência recomendada é construir primeiro a praça coberta do Bastião, depois o caminho norte e o portão, em seguida o corredor oeste e, por fim, a planície externa ao redor da cratera. Estruturas maiores devem ser adicionadas em pastas próprias e receber atributos de identificação, sem ocupar as âncoras existentes ou os volumes de transição.

> **Atualização 15/08/2026 — sequência concluída em código.** A praça coberta saiu em `docs/28-SPAWN-VISUAL-PASS.md`; caminho norte, corredor oeste e planície ao redor da cratera saíram em `docs/31-WILD-VISUAL-PASS.md`, como `src/shared/Data/WildDecorations.luau` (80 peças, 7 luzes) materializado em uma pasta própria `WildDecorations`. As regras pedidas acima viraram gate headless: nada colide, nada invade transição, nada entra no ringue do elite nem na faixa de caminhada e nada encosta em âncora de spawn. O Playtest visual no Studio continua pendente.

O Playtest visual no Roblox Studio deve verificar: entrada e saída do teto sem colisão, leitura dos dois portões, ausência de rochas sobre âncoras de inimigos, continuidade do piso até a cratera e espaço suficiente para os ataques do boss.

## Referências

[1]: https://kenney.nl/assets/nature-kit "Kenney Nature Kit — CC0"
[2]: https://ambientcg.com/view?id=Rock035 "ambientCG Rock035 — CC0"

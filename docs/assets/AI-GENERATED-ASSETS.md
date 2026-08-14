# Assets visuais gerados por IA

Este diretório contém imagens originais geradas por IA para a direção de arte e o planejamento da expansão de domínio do Anime Verse Battlegrounds. Elas são referências conceituais do projeto, não modelos 3D publicados, não texturas de runtime e não substituem a validação de licença de qualquer asset externo usado na implementação.

## Convenção

Os arquivos `domain-expansion-*.png` usam a paleta conceitual do mundo: Slate escuro, ciano para rotas e fronteiras, violeta para domínio/energia e âmbar para serviços e alertas. Os nomes são estáveis para permitir que documentos, tickets e futuras revisões apontem para a mesma referência.

| Arquivo | Função | Não usar como |
|---|---|---|
| `domain-expansion-concept.png` | Capa e escala geral Bastião → Planície → Distrito Lumen | Mapa navegável ou textura |
| `domain-expansion-district-lumen.png` | Direção da cidade, ruas e passarelas | Planta final ou cenário já implementado |
| `domain-expansion-safe-plaza.png` | Praça segura, spawn, treino e serviços | Guia de colisão ou layout autoritativo |
| `domain-expansion-border-gate.png` | Referência da fronteira e duas rotas | Contrato de dano ou regra de PvP |
| `domain-expansion-modular-ruins.png` | Biblioteca de peças para futura modelagem | Atlas Roblox ou malha 3D importável |
| `domain-expansion-vfx-moodboard.png` | Hierarquia cromática de telegraphs e VFX | Partículas prontas para produção |

## Licença e procedência

As imagens desta lista foram geradas para este projeto e devem ser tratadas como **conceito visual original**. Não foram baixadas de uma franquia, personagem ou pacote comercial. Assets externos gratuitos continuam documentados separadamente em `docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md`; cada pacote externo precisa ser verificado individualmente antes de entrar no repositório ou no Roblox Studio.

## Pipeline futuro

Quando uma imagem for aprovada como referência, a produção deve separar: conceito, modelagem/peça Roblox, colisão, textura, iluminação, otimização mobile, integração por Rojo e teste de runtime. Nenhuma imagem deste diretório deve ser ligada automaticamente ao place por nome de arquivo.

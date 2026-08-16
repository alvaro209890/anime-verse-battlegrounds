# 34 — Skins por código e assets grátis (sem clique no Studio)

> **Estado em 2026-08-16:** plano. Não implementa receita nova, não liga PNG ao place, não preenche `rbxassetid`, não começa F1 e não substitui W1. As quatro skins F0 **já** nascem de dados; este arquivo fecha *como* melhorá-las sem Blender, sem Toolbox e sem soldar peça à mão.

Este documento prevalece, em conflito de **pipeline de skin**, sobre o “preencha o ID no Dashboard” de `docs/21` e sobre o “importe no Studio” de `docs/assets/roblox-ready/README.md` quando o objetivo for **roupa de NPC**. Textura de chão/vitrine continua em `docs/33`. Loadout do jogador continua F1.

## 1. Contrato

| Tipo | Significado |
|---|---|
| Skin F0 | Roupa dos quatro atores: Instrutora, dummy, Estilhaço Errante, Estilhaço Ancorado |
| S0 | Só primitivas + `Enum.Material` + `rbxasset://` do motor. Zero upload. Zero conta |
| S1 | Arquivo CC0 no Git + `assetId`. Vazio é válido (a peça fica Material+Cor, como o áudio mudo) |
| Manual proibido | Soldar no Studio, importar `.fbx`, vestir item do catálogo Roblox, pintar Part na viewport |

O corpo dos bots do spawn **já** é o rig R15 oficial (`Players:CreateHumanoidModelFromDescription`). A roupa **já** é `WorldPresentation.rigFor`. Os Estilhaços **já** são `shardGearFor`. O `WorldService` só materializa. Qualquer `if npcId` de aparência nesse serviço é regressão (`docs/13` §2, `docs/31` §1).

## 2. O loop que já existe (e é o único caminho S0)

```text
editar src/shared/Data/WorldPresentation.luau
    → stylua / selene / lune run tests/animation.luau
    → .\scripts\build-studio.ps1   (ou Rojo live-sync)
    → Play só para OLHAR
```

Não há passo “abrir o modelo e ajustar”. Offset, tamanho, primitiva e material são números. O teste `rig_too_boxy` recusa receita com mais de 25% de `Block`. O rosto só aceita `rbxasset://`. O envelope dos Estilhaços não pode passar do `attackRange` real.

O que o Play faz neste loop: **julgar silhueta**. Não autoriza solda, Union, MeshPart nem Decal pintado na viewport. Se a peça ficou errada, o patch é no Luau.

## 3. O que asset grátis pode (e não pode) virar em skin

O Roblox não reproduz PNG do Git num `Part`. É a mesma restrição do áudio (`docs/16`): arquivo local ≠ runtime. Por isso “usar Kenney na skin” **não** é colar `slash_01.png` no peito.

| Faixa | Fonte no repo / licença | Como vira skin | Trabalho humano |
|---|---|---|---|
| **S0 motor** | `rbxasset://textures/face.png`, `Enum.Material` (Fabric, Leather, Neon, Slate, Basalt, Grass…) | Já no código | Nenhum |
| **S0 reconstrução** | Conceito em `docs/assets` (boards, props) e silhuetas CC0 (Kenney Nature *como referência de forma*, não como malha) | `blob` / `band` / `spike` em studs | Só editar a receita |
| **S1 ligação** | ColorMap CC0 (ambientCG, slate/muro já em `roblox-ready/textures/`), atlas Kenney **só em VFX** | `sourceFile` + `assetId`, idêntico a `CombatAudio` | Upload por script, nunca Dashboard clique a clique |
| **Proibido** | Particle Pack no corpo; Nature Kit sem malha versionada; acessório do catálogo Roblox; PNG de IA como `MeshPart` | — | — |

O Particle Pack Kenney (`slash_01`, `spark_01`, `scorch_01`) continua **VFX de golpe** (`docs/21`, `EnemyVfxAssets`). Nature Kit no Git é só licença (`docs/33`): não há malha para anexar. Props conceituais (beacon, arandela) já tinham o veredito certo: reconstruir com Part, não importar.

## 4. Faixa S0 — o que melhorar em cada ator, só com código

Números atuais (travados por teste, não por gosto): Instrutora 33 peças, dummy 34, Errante 13, Ancorado 23. Envelope: Errante 2,43 de 4 studs; Ancorado 4,46 de 8. Neon só em acento. `Block` ≤ 25%.

Antes de qualquer patch visual: **W1** fotografa os quatro de frente, perfil e três quartos (`docs/15`, `docs/32`). Sem essas capturas, não se acrescenta peça “no escuro”.

### 4.1 Campos novos na receita (sem mudar aparência)

Entram no mesmo commit de schema, com default, para o CI passar a recusar receita opaca:

| Campo | Onde | Para quê |
|---|---|---|
| `layer` | `RigGear` e `ShardPiece` | `"silhouette"` \| `"accent"` \| `"emissive"` \| `"prop"`. Orçamento: emissive tem teto; silhouette não pode ser 100% Neon |
| `token` | peça | Nome na paleta do *ator* (`coat`, `umbralTrim`, `burlap`…). Literal RGB continua válido; o token evita copiar `{118,84,158}` em 12 linhas |
| `builtinDecal` | `RigGear` opcional | Só prefixo `rbxasset://`. Mesma regra do `faceTexture` |

Não unificar os três `UMBRAL_CORE` globais nesta faixa (`docs/33` §3). Token é **por ator**.

### 4.2 Passada de receita (depois do W1)

Cada item só entra se a captura correspondente falhar. Não é backlog para executar agora.

| Ator | Se o W1 mostrar | Patch S0 (Luau) | Não fazer |
|---|---|---|---|
| Instrutora | de perfil some o cabelo / capuz vira capacete | um `blob` extra em `HairSide*` ou `HoodCheek`; `gearClearsFace` tem de continuar verde | cobrir a faixa dos olhos; casaco inteiro Neon |
| Instrutora | de longe não lê “mensageiro” | aumentar `Emblem`/`CollarGlow`, não o casaco | nova malha de cabelo |
| Dummy | alvo ilegível a 24 studs (pad de treino) | `TargetRing` / `TargetCore` maiores; palha já é `spike` | textura de palha CC0 no saco |
| Dummy | parece personagem, não saco | mais `BURLAP`, menos proporção Rthro no dummy se o W1 pedir | vestir R15 “bonito” |
| Errante | igual ao elite de longe | silhueta (casca/halo), não só matiz | peça que estoure 4 studs |
| Ancorado | coroa some na cratera / clipping | baixar `offsetStuds` da coroa; envelope 8 studs | Kenney scorch como decal na pedra |

Teto de densidade (CI, quando S0-LAYERS existir): Instrutora ≤ 40, dummy ≤ 40, Errante ≤ 16, Ancorado ≤ 28. Subir o teto exige W2, não opinião.

## 5. Faixa S1 — CC0 de verdade, sem Dashboard

Contrato copiado de `CombatAudio` de propósito, para um único hábito:

```text
sourceFile  → rastreio (o .png CC0 no Git)
assetId     → ""  = ignore, peça fica Material+Cor
            → rbxassetid://N = Decal ou SurfaceAppearance na peça
```

Regras:

1. `WorldService` não baixa arquivo. Sem ID, a skin S0 continua intacta — o jogo nunca fica “sem roupa”.
2. `validateGear` recusa `MeshPart`, recusa `assetId` que não seja vazio ou `rbxassetid://%d+`, recusa `sourceFile` ausente no disco.
3. Publicar **não** entra no CI (`docs/04`: CI sem credencial de produção). Script local, no mesmo espírito de `lune run scripts/audio-manifest.luau`:
   - lê o catálogo de bindings
   - chama Open Cloud Assets API
   - escreve os IDs de volta no Luau
   - falha se a licença do arquivo não for CC0 declarada no manifesto
4. Primeira ligação: **uma** peça de teste no spawn (ColorMap slate já derivado em `roblox-ready/textures/`), nunca o volume inteiro do greybox — é a ordem de `docs/33` §6.
5. Atlas Kenney preparado (`AbilityVfx`) continua VFX, não vira camisa.

ambientCG (CC0, já citado em `docs/21`) só entra como `sourceFile` de Estilhaço **depois** do W1 dizer “a pedra está plástica”. Até lá, `Basalt`/`Slate`/`Rock` no `Enum.Material` são o S0 correto.

## 6. Sequência técnica

Ordem fechada. Pular S0 porque “temos PNG” produz Decal em caixa e o defeito de 14/08 (roupa quadrada) volta.

1. **W1** — capturas dos quatro atores; ficha `docs/26`. Sem isso, nenhuma peça nova.
2. **S0-LAYERS** — `layer` / `token` / tetos; testes; **zero** mudança visível.
3. **S0-PASS** — só os patches da tabela §4.2 que o W1 marcou FAIL; `tests/animation.luau` + envelope.
4. **S1-BIND** — campo `sourceFile`/`assetId` na peça; vazio = noop; manifesto tipo áudio.
5. **S1-ONE** — um ColorMap CC0 numa peça de teste, upload por script, ID no catálogo.
6. **W2** — se a densidade S0 ou o SurfaceAppearance estourar Android: cortar `emissive` e sombra antes de cor.

Não há S2 “importar personagem Kenney”. Personagem de terceiros, mesmo CC0, passa por P1 de silhueta (`docs/06` Gate P1) e por envelope de alcance. Até lá, o rig oficial + receita própria é a identidade.

## 7. O que este plano recusa

- Editar skin na viewport e “depois a gente copia os números”.
- `HumanoidDescription` com acessório do catálogo (não é nosso, não é CC0 auditável, some por moderação).
- Recolorir runtime com a paleta extraída do quadro-mãe (`docs/33` §3).
- Unificar `UMBRAL_CORE` sem Play.
- Skin de jogador / loadout (F1).
- Preencher `EnemyVfxAssets.assetId` à mão — VFX usa o mesmo padrão S1, não um Dashboard paralelo (`docs/16` §5).

## 8. Relação com os planos que isto substitui em parte

| Documento | O que continua | O que muda |
|---|---|---|
| `docs/15` §4 | Rig R15 + receita; sem `.fbx` | Evolução = este arquivo, não produção de malha |
| `docs/21` | Kenney CC0, poses, VFX de golpe | “Preencher IDs” vira S1 mecânico; corpo de monstro não recebe sprite 2D |
| `docs/28` | Skin da Instrutora é apresentação | Próximo ganho de silhueta = S0-PASS, não Mesh |
| `docs/31` | `shardGearFor`, envelope | Próxima peça do elite = dados, nunca `if` no `WorldService` |
| `docs/33` | Veredito de PNG/PBR/vitrine | Skins F0 saem da fila “importe no Studio” e entram em S0/S1 |
| `docs/16` | `sourceFile` + `assetId` vazio | S1 copia este contrato; não inventa um segundo |

## 9. Verificação (quando o código existir)

Headless, na suíte de animação, além do que já passa:

- toda peça declara `layer` válida;
- tetos de §4.2;
- `builtinDecal` / `faceTexture` só `rbxasset://`;
- binding com `sourceFile` aponta arquivo existente;
- `assetId` vazio não quebra materialização (teste de noop);
- envelope dos Estilhaços inalterado ou ainda `< attackRange`;
- `init.server.lua` / `WorldService` continuam sem `if npcId` de coroa/roupa.

Play continua sendo a prova de beleza. CI verde nesta faixa prova contrato, não que o capuz leu de perfil.
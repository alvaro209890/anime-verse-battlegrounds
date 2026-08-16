#!/usr/bin/env python3
"""Inventário e auditoria dos assets visuais do Anime Verse Battlegrounds.

Stdlib apenas: existência, SHA-256, dimensões PNG/JPEG, zip Kenney, catálogos
Luau e veredito de usabilidade. Não publica IDs, não liga PNG ao place e não
precisa de Pillow.

Uso:
  python3 scripts/audit_visual_assets.py --write   # gera o JSON canônico
  python3 scripts/audit_visual_assets.py --check   # falha se o JSON estiver velho
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "docs" / "assets" / "visual-inventory.json"
PALETTE_PATH = ROOT / "docs" / "assets" / "art-direction-palette.json"
ASSETS_DIR = ROOT / "docs" / "assets"
ROBLOX_READY = ASSETS_DIR / "roblox-ready"
KENNEY_ZIP = ASSETS_DIR / "open-candidates" / "kenney_particle-pack.zip"
ROBLOX_MANIFEST = ROBLOX_READY / "roblox-asset-manifest.json"
STORE_MANIFEST = ROBLOX_READY / "store" / "store-art-manifest.json"
ABILITY_VFX = ROOT / "src" / "shared" / "Data" / "AbilityVfx.luau"
ENEMY_VFX = ROOT / "src" / "shared" / "Data" / "EnemyVfxAssets.luau"

# Vereditos estáveis. Qualquer PNG novo em docs/assets/ (fora de roblox-ready)
# precisa entrar aqui — senão o --check falha.
CONCEPT_CATALOG: dict[str, dict[str, str]] = {
    "docs/assets/anime-verse-battlegrounds-cover.png": {
        "verdict": "store_candidate",
        "phase": "F0",
        "canonicalDoc": "docs/29-GAME-COVER.md",
        "useAs": "Capa, README e fonte das peças de vitrine (thumbnail 16:9 e ícone 512).",
        "doNotUseAs": "Mapa, decal, textura, mesh ou evidência de Play.",
        "nextStep": "Gate P1 + teste de leitura em 150 px antes de publicar.",
    },
    "docs/assets/asset-pack-art-direction-board.png": {
        "verdict": "art_direction",
        "phase": "F0",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Quadro-mãe de paleta, materiais e consistência do pacote F0.",
        "doNotUseAs": "Screenshot de runtime ou atlas importável.",
        "nextStep": "Comparar qualquer produção nova com este quadro antes de converter.",
    },
    "docs/assets/texture-slate-cracked-floor.png": {
        "verdict": "texture_candidate",
        "phase": "F0",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Briefing de piso slate; ColorMap PBR 1024 já derivado em roblox-ready.",
        "doNotUseAs": "Textura ligada automaticamente ao greybox.",
        "nextStep": "Importar ColorMap no Studio, tiling, depois SurfaceAppearance completo no W1.",
    },
    "docs/assets/texture-runed-stone-wall.png": {
        "verdict": "texture_candidate",
        "phase": "F0/F1",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Briefing de muro modular com runas; ColorMap PBR 1024 já derivado.",
        "doNotUseAs": "Atlas de parede ou colisão.",
        "nextStep": "Importar em MeshPart de teste; não substituir wallColor procedural sem Play.",
    },
    "docs/assets/texture-crystal-emissive-strip.png": {
        "verdict": "texture_candidate",
        "phase": "F0/F1",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Trim/faixa emissiva e motivos de cristal; máscara derivada como referência.",
        "doNotUseAs": "Atlas final de flipbook ou decal de chão.",
        "nextStep": "Usar como trim em borda/marco depois de medir bloom no mobile.",
    },
    "docs/assets/prop-energy-crystal-beacon.png": {
        "verdict": "prop_concept",
        "phase": "F0/F1",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Silhueta de beacon/marco para modelagem nativa (Part + Neon).",
        "doNotUseAs": "Mesh publicável ou hitbox.",
        "nextStep": "Reconstruir com peças Roblox; colisão e orçamento no W1.",
    },
    "docs/assets/prop-amber-lantern-sconce.png": {
        "verdict": "prop_concept",
        "phase": "F0",
        "canonicalDoc": "docs/30-VISUAL-ASSET-PACK.md",
        "useAs": "Silhueta de arandela âmbar para luz de serviço do Bastião.",
        "doNotUseAs": "Fonte de iluminação final (o catálogo spawnLights já existe).",
        "nextStep": "Prop nativo + PointLight âmbar, sem aumentar o orçamento de sombras.",
    },
    "docs/assets/vfx-guard-orbit-shell.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Receita em camadas da guarda (casca, órbitas, motes, anel de base).",
        "doNotUseAs": "Decal, bloqueio confirmado ou spritesheet.",
        "nextStep": "Comparar com AbilityVfx.guard_raise no Play; não importar o PNG.",
    },
    "docs/assets/vfx-dash-afterimage-trail.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Receita de dash: afterimages, esteira, faíscas de pé.",
        "doNotUseAs": "Teleporte, i-frame visual ou deslocamento autoritativo.",
        "nextStep": "Comparar com AbilityVfx.dash_run no Play.",
    },
    "docs/assets/vfx-ground-break-impact.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Sequência contato → crack → poeira → debris → flash → dissipação.",
        "doNotUseAs": "Alteração permanente de piso ou colisão.",
        "nextStep": "VFX temporário com pooling; chão continua navegável.",
    },
    "docs/assets/animation-combat-poses-board.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/14-ANIMATION-PLAN.md",
        "useAs": "Referência de pose R15 para defesa, dash e idle de combate.",
        "doNotUseAs": "Clip publicado ou KeyframeSequence.",
        "nextStep": "A1 no Studio contra PlayerCombatAnimator; catálogo de clipes continua vazio de propósito.",
    },
    "docs/assets/animation-heavy-strike-poses-board.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/14-ANIMATION-PLAN.md",
        "useAs": "Referência de peso: antecipação, avanço, impacto e recuperação do pesado.",
        "doNotUseAs": "Clip final ou prova de câmera.",
        "nextStep": "Play a1_impact; a câmera do pesado básico permanece pinada no headless.",
    },
    "docs/assets/combat-presentation-reference.png": {
        "verdict": "recipe_board",
        "phase": "F0/A0",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Referência-mãe de defesa, dash, impacto, materiais e escala.",
        "doNotUseAs": "Captura de runtime ou thumbnail oficial (a capa cobre a vitrine).",
        "nextStep": "Checklist docs/26 nas três câmeras.",
    },
    "docs/assets/defense-guard-presentation.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Silhueta da defesa, casca ciano e faíscas de deflexão.",
        "doNotUseAs": "Prova de bloqueio.",
        "nextStep": "A1 + CombatEvent de guarda.",
    },
    "docs/assets/dash-run-presentation.png": {
        "verdict": "recipe_board",
        "phase": "F0/A1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Quatro fases do dash e afterimage.",
        "doNotUseAs": "Animação publicada ou movimento server-side.",
        "nextStep": "A1/R1: passada vs correção de rede.",
    },
    "docs/assets/ground-break-impact-presentation.png": {
        "verdict": "recipe_board",
        "phase": "F0 → F1",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Ordem temporal de crack, poeira e debris.",
        "doNotUseAs": "Buraco no mapa.",
        "nextStep": "A1/W1/W2 com pooling.",
    },
    "docs/assets/impact-vfx-micro-library.png": {
        "verdict": "recipe_board",
        "phase": "F0 → F2",
        "canonicalDoc": "docs/25-COMBAT-PRESENTATION-PLAN.md",
        "useAs": "Motivos reutilizáveis (anel, rastro, crack, debris) para AbilityVfx.",
        "doNotUseAs": "Spritesheet de produção sem recorte.",
        "nextStep": "Reuso nas receitas existentes; não criar habilidade nova.",
    },
    "docs/assets/domain-expansion-concept.png": {
        "verdict": "world_concept",
        "phase": "F0 → F2",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Capa do atlas Bastião → Planície → Distrito Lumen.",
        "doNotUseAs": "Mapa navegável ou textura de terreno.",
        "nextStep": "W1 no Bastião/Planície; Distrito Lumen só depois da F0.",
    },
    "docs/assets/domain-expansion-district-lumen.png": {
        "verdict": "world_concept",
        "phase": "F1/F2",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Direção da primeira célula urbana.",
        "doNotUseAs": "Cidade já implementada.",
        "nextStep": "Uma célula densa após W1/W2 da F0 — não começar F1 agora.",
    },
    "docs/assets/domain-expansion-safe-plaza.png": {
        "verdict": "world_concept",
        "phase": "F0/F1",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Praça coberta, spawn, treino e duas saídas.",
        "doNotUseAs": "Layout de colisão autoritativo.",
        "nextStep": "Comparar com o greybox no W1.",
    },
    "docs/assets/domain-expansion-border-gate.png": {
        "verdict": "world_concept",
        "phase": "F0",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Leitura da fronteira segura/livre (forma + material + luz, não só cor).",
        "doNotUseAs": "Contrato de dano ou regra de PvP.",
        "nextStep": "W1/R1: telegraph redundante já existe em código.",
    },
    "docs/assets/domain-expansion-modular-ruins.png": {
        "verdict": "world_concept",
        "phase": "F1/F2",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Biblioteca conceitual de peças de ruína.",
        "doNotUseAs": "Atlas Roblox ou malha importável.",
        "nextStep": "Kit nativo depois da F0; cada peça com colisão própria.",
    },
    "docs/assets/domain-expansion-vfx-moodboard.png": {
        "verdict": "recipe_board",
        "phase": "F0 → F2",
        "canonicalDoc": "docs/24-DOMAIN-EXPANSION-ILLUSTRATION.md",
        "useAs": "Hierarquia cromática: ciano rota, violeta domínio, âmbar serviço/alerta.",
        "doNotUseAs": "Partículas prontas.",
        "nextStep": "Manter a paleta de runtime; não copiar RGB da imagem sem Play.",
    },
    "docs/assets/ability-future-energy-projectile.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção de projétil futuro (carga, trail, impacto).",
        "doNotUseAs": "Habilidade F0 ou dano confirmado.",
        "nextStep": "Não implementar agora. Spec server-side primeiro.",
    },
    "docs/assets/ability-future-area-domain.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção de área/domínio temporário.",
        "doNotUseAs": "Zona PvP.",
        "nextStep": "Não implementar agora.",
    },
    "docs/assets/ability-future-mobility-burst.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção de burst de mobilidade avançada.",
        "doNotUseAs": "Teleporte ou i-frame.",
        "nextStep": "Não implementar agora.",
    },
    "docs/assets/ability-future-summon-construct.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Silhueta de constructo temporário.",
        "doNotUseAs": "NPC jogável.",
        "nextStep": "Não implementar agora. Ownership e despawn primeiro.",
    },
    "docs/assets/ability-future-barrier-parry.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção de barreira/parry futuro.",
        "doNotUseAs": "Bloqueio confirmado.",
        "nextStep": "Não implementar agora. A guarda F0 já tem receita.",
    },
    "docs/assets/ability-future-ultimate-composition.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção cinematográfica de ultimate futura.",
        "doNotUseAs": "Ultimate ligada (eclipse_beat continua enabled=false).",
        "nextStep": "Não implementar agora.",
    },
    "docs/assets/ability-future-environment-break.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Direção de ruptura temporária de cenário.",
        "doNotUseAs": "Alteração persistente de chão.",
        "nextStep": "Não implementar agora.",
    },
    "docs/assets/ability-future-vfx-micro-library.png": {
        "verdict": "f1_only",
        "phase": "F1/F2",
        "canonicalDoc": "docs/27-FUTURE-ABILITY-ASSET-CATALOG.md",
        "useAs": "Motivos futuros (orbe, anel, spike, dome) nas quatro cores do projeto.",
        "doNotUseAs": "Spritesheet de produção ou kit F0 novo.",
        "nextStep": "Reuso seletivo nas receitas F0 existentes, sem habilidade nova.",
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        signature = handle.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"PNG inválido: {path}")
        length = int.from_bytes(handle.read(4), "big")
        chunk = handle.read(4)
        if chunk != b"IHDR" or length < 8:
            raise ValueError(f"IHDR ausente: {path}")
        width = int.from_bytes(handle.read(4), "big")
        height = int.from_bytes(handle.read(4), "big")
        return width, height


def jpeg_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        data = handle.read()
    if data[:2] != b"\xff\xd8":
        raise ValueError(f"JPEG inválido: {path}")
    index = 2
    while index + 9 < len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        marker = data[index + 1]
        if marker in {0xC0, 0xC1, 0xC2}:
            height = int.from_bytes(data[index + 5 : index + 7], "big")
            width = int.from_bytes(data[index + 7 : index + 9], "big")
            return width, height
        if marker in {0xD8, 0x01} or 0xD0 <= marker <= 0xD7:
            index += 2
            continue
        if marker == 0xD9:
            break
        length = int.from_bytes(data[index + 2 : index + 4], "big")
        index += 2 + length
    raise ValueError(f"SOF ausente: {path}")


def image_record(rel: str, extra: dict[str, str] | None = None) -> dict[str, object]:
    path = ROOT / rel
    suffix = path.suffix.lower()
    if suffix == ".png":
        width, height = png_size(path)
        fmt = "PNG"
    elif suffix in {".jpg", ".jpeg"}:
        width, height = jpeg_size(path)
        fmt = "JPEG"
    else:
        raise ValueError(f"formato não suportado: {rel}")
    record: dict[str, object] = {
        "path": rel,
        "format": fmt,
        "width": width,
        "height": height,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "runtimeLinked": False,
    }
    if extra:
        record.update(extra)
    return record


def luau_quoted_fields(path: Path, field: str) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return re.findall(rf'{field}\s*=\s*"([^"]+)"', text)


def luau_rgb_literal(path: Path, name: str) -> list[int]:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        rf"{re.escape(name)}(?:\s*:\s*\w+)?\s*=\s*\{{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}}",
        text,
    )
    if not match:
        raise SystemExit(f"literal RGB {name} ausente em {path.relative_to(ROOT)}")
    return [int(match.group(1)), int(match.group(2)), int(match.group(3))]


def kenney_archive() -> dict[str, object]:
    if not KENNEY_ZIP.is_file():
        raise SystemExit(f"zip Kenney ausente: {KENNEY_ZIP.relative_to(ROOT)}")
    with zipfile.ZipFile(KENNEY_ZIP) as archive:
        names = archive.namelist()
        pngs = [name for name in names if name.lower().endswith(".png")]
        has_license = any(Path(name).name.lower() == "license.txt" for name in names)
    return {
        "path": KENNEY_ZIP.relative_to(ROOT).as_posix(),
        "verdict": "external_archive",
        "license": "CC0",
        "sourceUrl": "https://kenney.nl/assets/particle-pack",
        "bytes": KENNEY_ZIP.stat().st_size,
        "sha256": sha256(KENNEY_ZIP),
        "zipEntries": len(names),
        "pngCount": len(pngs),
        "hasLicenseTxt": has_license,
        "runtimeLinked": False,
        "note": (
            "Arquivo canônico em docs/assets/open-candidates/. "
            "Um subconjunto (slash/spark/scorch) já está extraído em "
            "AVB-free-vfx-assets/assets/vfx/kenney/; o zip inteiro não entra no Rojo."
        ),
    }


def vfx_catalog() -> list[dict[str, object]]:
    sources = luau_quoted_fields(ABILITY_VFX, "sourceFile")
    prepared = luau_quoted_fields(ABILITY_VFX, "preparedFile")
    keys = luau_quoted_fields(ABILITY_VFX, "key")
    enemy = luau_quoted_fields(ENEMY_VFX, "sourceFile")
    records: list[dict[str, object]] = []
    for rel in sources + prepared + enemy:
        path = ROOT / rel
        if not path.is_file():
            raise SystemExit(f"arquivo de VFX do catálogo ausente: {rel}")
        records.append(
            {
                "path": rel,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
                "assetId": None,
                "runtimeLinked": False,
            }
        )
    return {
        "abilityKeys": keys,
        "abilitySourceCount": len(sources),
        "abilityPreparedCount": len(prepared),
        "enemySourceCount": len(enemy),
        "files": records,
    }


def audio_summary() -> dict[str, object]:
    audio_root = ROOT / "assets" / "audio"
    oggs = sorted(audio_root.rglob("*.ogg"))
    packs: dict[str, int] = {}
    for ogg in oggs:
        pack = ogg.relative_to(audio_root).parts[0]
        packs[pack] = packs.get(pack, 0) + 1
    music_root = ROOT / "assets" / "music"
    music = sorted(p for p in music_root.rglob("*") if p.is_file() and p.suffix.lower() in {".ogg", ".mp3", ".wav"})
    return {
        "oggCount": len(oggs),
        "oggBytes": sum(path.stat().st_size for path in oggs),
        "packs": packs,
        "musicFiles": len(music),
        "runtime": "placeholder rbxassetid do criador Roblox até o upload; .ogg local não toca",
    }


def nature_kit() -> dict[str, object]:
    folder = ROOT / "AVB-free-vfx-assets" / "assets" / "scenery" / "kenney_nature_kit"
    files = sorted(path.relative_to(ROOT).as_posix() for path in folder.rglob("*") if path.is_file())
    meshes = [name for name in files if Path(name).suffix.lower() in {".fbx", ".obj", ".dae", ".gltf", ".glb"}]
    return {
        "path": folder.relative_to(ROOT).as_posix(),
        "files": files,
        "meshCount": len(meshes),
        "verdict": "license_only",
        "note": (
            "Só README e License.txt estão versionados. O greybox usa peças nativas; "
            "malhas do Nature Kit não foram baixadas e não devem ser inventadas."
        ),
    }


def derived_from_manifest(path: Path, expected_schema: int) -> dict[str, object]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != expected_schema:
        raise SystemExit(f"schemaVersion inesperado em {path}: {manifest.get('schemaVersion')}")
    assets = []
    for entry in manifest["assets"]:
        output = entry["output"]
        file_path = ROOT / output
        if not file_path.is_file():
            raise SystemExit(f"output do manifesto ausente: {output}")
        digest = sha256(file_path)
        if digest != entry["sha256"]:
            raise SystemExit(f"hash divergente de {output}")
        if entry.get("runtime_linked") is True or entry.get("published") is True:
            raise SystemExit(f"manifesto marca runtime/publicado em {output}")
        assets.append(
            {
                "path": output,
                "kind": entry.get("kind") or entry.get("role"),
                "sha256": digest,
                "bytes": file_path.stat().st_size,
                "runtimeLinked": False,
            }
        )
    return {
        "manifest": path.relative_to(ROOT).as_posix(),
        "schemaVersion": expected_schema,
        "assets": assets,
    }


def concept_images() -> list[dict[str, object]]:
    found: set[str] = set()
    for path in ASSETS_DIR.glob("*.png"):
        found.add(path.relative_to(ROOT).as_posix())
    extra = found - set(CONCEPT_CATALOG)
    missing = set(CONCEPT_CATALOG) - found
    if extra:
        raise SystemExit("PNG conceitual sem veredito: " + ", ".join(sorted(extra)))
    if missing:
        raise SystemExit("veredito órfão, arquivo ausente: " + ", ".join(sorted(missing)))
    records = []
    for rel, meta in sorted(CONCEPT_CATALOG.items()):
        records.append(image_record(rel, meta))
    return records


def build_inventory() -> dict[str, object]:
    palette = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    return {
        "schemaVersion": 1,
        "generatedBy": "scripts/audit_visual_assets.py",
        "policy": (
            "Inventário de conceito, candidatos técnicos e arquivos de catálogo. "
            "Nenhum path daqui é rbxassetid. PNG local não é textura jogável. "
            "Não ligar automaticamente ao place."
        ),
        "canonicalUsabilityDoc": "docs/33-ASSET-USABILITY.md",
        "palette": palette["source"] if "source" in palette else PALETTE_PATH.relative_to(ROOT).as_posix(),
        "palettePath": PALETTE_PATH.relative_to(ROOT).as_posix(),
        "runtimeLinked": False,
        "conceptImages": concept_images(),
        "kenneyParticlePack": kenney_archive(),
        "kenneyNatureKit": nature_kit(),
        "vfxCatalog": vfx_catalog(),
        "audio": audio_summary(),
        "robloxReady": derived_from_manifest(ROBLOX_MANIFEST, 2),
        "storeArt": derived_from_manifest(STORE_MANIFEST, 1),
    }


def canonical_dump(payload: dict[str, object]) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def check_runtime_palette_lock() -> None:
    palette = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    expected = {
        ("AbilityVfx.luau", "UMBRAL_CORE"): luau_rgb_literal(ABILITY_VFX, "UMBRAL_CORE"),
        ("AbilityVfx.luau", "UMBRAL_EDGE"): luau_rgb_literal(ABILITY_VFX, "UMBRAL_EDGE"),
        ("AbilityVfx.luau", "RETURN_CORE"): luau_rgb_literal(ABILITY_VFX, "RETURN_CORE"),
        ("AbilityVfx.luau", "RETURN_EDGE"): luau_rgb_literal(ABILITY_VFX, "RETURN_EDGE"),
        ("SceneryPresentation.luau", "wallColor"): luau_rgb_literal(
            ROOT / "src" / "shared" / "Data" / "SceneryPresentation.luau", "wallColor"
        ),
        ("SceneryPresentation.luau", "lightColor"): luau_rgb_literal(
            ROOT / "src" / "shared" / "Data" / "SceneryPresentation.luau", "lightColor"
        ),
        ("SceneryPresentation.luau", "fillLightColor"): luau_rgb_literal(
            ROOT / "src" / "shared" / "Data" / "SceneryPresentation.luau", "fillLightColor"
        ),
        ("WorldPresentation.luau", "UMBRAL_CORE"): luau_rgb_literal(
            ROOT / "src" / "shared" / "Data" / "WorldPresentation.luau", "UMBRAL_CORE"
        ),
        ("SpawnDecorations.luau", "UMBRAL_CORE"): luau_rgb_literal(
            ROOT / "src" / "shared" / "Data" / "SpawnDecorations.luau", "UMBRAL_CORE"
        ),
    }
    by_key = {(item["module"], item["name"]): item["rgb"] for item in palette["runtimeTokens"]}
    for key, rgb in expected.items():
        if by_key.get(key) != rgb:
            raise SystemExit(f"paleta dessincronizada de {key[0]} {key[1]}: doc={by_key.get(key)} código={rgb}")
    if palette.get("doNotRecolorRuntimeWithoutPlay") is not True:
        raise SystemExit("paleta precisa travar doNotRecolorRuntimeWithoutPlay=true")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="reescreve docs/assets/visual-inventory.json")
    mode.add_argument("--check", action="store_true", help="confere o JSON canônico contra o disco")
    args = parser.parse_args()

    if not PALETTE_PATH.is_file():
        raise SystemExit(f"paleta ausente: {PALETTE_PATH.relative_to(ROOT)}")
    check_runtime_palette_lock()
    inventory = build_inventory()
    rendered = canonical_dump(inventory)

    if args.write:
        INVENTORY_PATH.write_text(rendered, encoding="utf-8")
        print(
            f"OK write: {len(inventory['conceptImages'])} conceitos, "
            f"{inventory['kenneyParticlePack']['pngCount']} PNG no zip Kenney, "
            f"{len(inventory['vfxCatalog']['files'])} arquivos de VFX de catálogo"
        )
        print(f"inventário: {INVENTORY_PATH.relative_to(ROOT)}")
        return 0

    if not INVENTORY_PATH.is_file():
        print("inventário ausente; rode python3 scripts/audit_visual_assets.py --write", file=sys.stderr)
        return 1
    stored = INVENTORY_PATH.read_text(encoding="utf-8")
    if stored != rendered:
        print("docs/assets/visual-inventory.json está desatualizado em relação ao disco.", file=sys.stderr)
        print("Rode: python3 scripts/audit_visual_assets.py --write", file=sys.stderr)
        return 1
    print(
        f"OK check: {len(inventory['conceptImages'])} conceitos, "
        f"Kenney {inventory['kenneyParticlePack']['sha256'][:12]}…, "
        f"VFX {len(inventory['vfxCatalog']['files'])} arquivos, "
        f"áudio {inventory['audio']['oggCount']} ogg"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

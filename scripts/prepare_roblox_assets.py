#!/usr/bin/env python3
"""Prepara o pacote visual conceitual para o pipeline de assets Roblox.

A conversão é determinística e conservadora: normaliza dimensões, formato e
compressão e deriva mapas PBR de referência para texturas. Nenhum arquivo é
ligado automaticamente ao runtime.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs" / "assets"
OUTPUT_DIR = SOURCE_DIR / "roblox-ready"
TEXTURE_DIR = OUTPUT_DIR / "textures"
REFERENCE_DIR = OUTPUT_DIR / "references"

TEXTURE_TARGETS = {
    "texture-slate-cracked-floor.png": ("avb_slate_cracked_floor", (1024, 1024)),
    "texture-runed-stone-wall.png": ("avb_runed_stone_wall", (1024, 1024)),
    "texture-crystal-emissive-strip.png": ("avb_crystal_emissive_strip", (1024, 683)),
}

REFERENCE_SOURCES = [
    "asset-pack-art-direction-board.png",
    "anime-verse-battlegrounds-cover.png",
    "prop-energy-crystal-beacon.png",
    "prop-amber-lantern-sconce.png",
    "vfx-guard-orbit-shell.png",
    "vfx-dash-afterimage-trail.png",
    "vfx-ground-break-impact.png",
    "animation-combat-poses-board.png",
    "animation-heavy-strike-poses-board.png",
    "combat-presentation-reference.png",
    "defense-guard-presentation.png",
    "dash-run-presentation.png",
    "ground-break-impact-presentation.png",
    "impact-vfx-micro-library.png",
    "domain-expansion-concept.png",
    "domain-expansion-district-lumen.png",
    "domain-expansion-safe-plaza.png",
    "domain-expansion-border-gate.png",
    "domain-expansion-modular-ruins.png",
    "domain-expansion-vfx-moodboard.png",
    "ability-future-energy-projectile.png",
    "ability-future-area-domain.png",
    "ability-future-mobility-burst.png",
    "ability-future-summon-construct.png",
    "ability-future-barrier-parry.png",
    "ability-future-ultimate-composition.png",
    "ability-future-environment-break.png",
    "ability-future-vfx-micro-library.png",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def save_png_array(array, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(array.astype("uint8"), mode="RGB" if array.ndim == 3 else "L").save(
        destination, format="PNG", optimize=True
    )


def save_pbr_maps(source: Path, stem: str, size: tuple[int, int]) -> list[tuple[Path, str, str]]:
    """Gera mapas candidatos para SurfaceAppearance e uma máscara de emissão de referência."""
    import numpy as np

    with Image.open(source) as image:
        rgb = image.convert("RGB").resize(size, Image.Resampling.LANCZOS)
        color = np.asarray(rgb, dtype=np.float32) / 255.0

    luminance = 0.2126 * color[:, :, 0] + 0.7152 * color[:, :, 1] + 0.0722 * color[:, :, 2]
    emission = np.max(color, axis=2) - np.min(color, axis=2)
    emission = np.clip((emission * 1.8 + luminance * 0.45) * (luminance > 0.2), 0.0, 1.0)

    # Sobel simples com bordas replicadas; produz uma normal de referência estável.
    padded = np.pad(luminance, 1, mode="edge")
    gx = (
        padded[:-2, 2:]
        + 2.0 * padded[1:-1, 2:]
        + padded[2:, 2:]
        - padded[:-2, :-2]
        - 2.0 * padded[1:-1, :-2]
        - padded[2:, :-2]
    )
    gy = (
        padded[2:, :-2]
        + 2.0 * padded[2:, 1:-1]
        + padded[2:, 2:]
        - padded[:-2, :-2]
        - 2.0 * padded[:-2, 1:-1]
        - padded[:-2, 2:]
    )
    strength = 2.25
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(luminance)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack(
        [
            ((nx / norm) * 0.5 + 0.5) * 255.0,
            ((ny / norm) * 0.5 + 0.5) * 255.0,
            ((nz / norm) * 0.5 + 0.5) * 255.0,
        ],
        axis=2,
    )

    # Pedra permanece predominantemente áspera e não metálica; linhas emissivas
    # recebem menor roughness apenas como candidato inicial para revisão manual.
    roughness = np.clip(0.82 - emission * 0.35, 0.0, 1.0) * 255.0
    metalness = np.zeros_like(luminance) * 255.0

    outputs = [
        (TEXTURE_DIR / f"{stem}_color.png", "color_map", color * 255.0),
        (TEXTURE_DIR / f"{stem}_normal.png", "normal_map_candidate", normal),
        (TEXTURE_DIR / f"{stem}_roughness.png", "roughness_map_candidate", roughness),
        (TEXTURE_DIR / f"{stem}_metalness.png", "metalness_map_candidate", metalness),
        (REFERENCE_DIR / f"{stem}_emissive_mask.png", "emissive_mask_reference", emission * 255.0),
    ]
    for path, _, array in outputs:
        save_png_array(array, path)
    return [(path, kind, path.suffix.upper().lstrip(".")) for path, kind, _ in outputs]


def save_jpeg(source: Path, destination: Path, max_dimension: int = 1280) -> None:
    with Image.open(source) as image:
        rgb = image.convert("RGB")
        scale = min(1.0, max_dimension / max(rgb.size))
        size = (max(1, round(rgb.width * scale)), max(1, round(rgb.height * scale)))
        if size != rgb.size:
            rgb = rgb.resize(size, Image.Resampling.LANCZOS)
        destination.parent.mkdir(parents=True, exist_ok=True)
        rgb.save(destination, format="JPEG", quality=90, optimize=True, progressive=True)


def record_asset(assets: list[dict[str, object]], source: Path, output: Path, kind: str, roblox_use: str) -> None:
    with Image.open(output) as image:
        dimensions = {"width": image.width, "height": image.height}
    assets.append(
        {
            "source": source.relative_to(ROOT).as_posix(),
            "output": output.relative_to(ROOT).as_posix(),
            "kind": kind,
            "dimensions": dimensions,
            "format": f"{image_format(output)}/{image_mode(output)}",
            "roblox_use": roblox_use,
            "runtime_linked": False,
            "sha256": sha256(output),
        }
    )


def image_format(path: Path) -> str:
    with Image.open(path) as image:
        return image.format or "PNG"


def image_mode(path: Path) -> str:
    with Image.open(path) as image:
        return image.mode


def load_existing_manifest() -> dict[str, object]:
    manifest_path = OUTPUT_DIR / "roblox-asset-manifest.json"
    if not manifest_path.is_file():
        return {"textureSets": [], "assets": []}
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", action="store_true", help="remove o diretório de saída antes de gerar")
    parser.add_argument(
        "--previews-only",
        action="store_true",
        help="gera só JPEGs de briefing que faltam; não regenera mapas PBR (hashes estáveis)",
    )
    args = parser.parse_args()

    if args.clean and args.previews_only:
        raise SystemExit("--clean e --previews-only não combinam: --clean apagaria os PBR")

    if args.clean and OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)

    existing = load_existing_manifest()
    assets: list[dict[str, object]] = []
    texture_sets: list[dict[str, object]] = []

    if args.previews_only:
        texture_sets = list(existing.get("textureSets") or [])
        assets.extend(
            entry
            for entry in existing.get("assets") or []
            if entry.get("kind") != "reference_preview"
        )
    else:
        for source_name, (stem, size) in TEXTURE_TARGETS.items():
            source = SOURCE_DIR / source_name
            outputs = save_pbr_maps(source, stem, size)
            output_by_kind = {kind: output.relative_to(ROOT).as_posix() for output, kind, _ in outputs}
            texture_sets.append(
                {
                    "source": source.relative_to(ROOT).as_posix(),
                    "baseName": stem,
                    "colorMap": output_by_kind["color_map"],
                    "normalMap": output_by_kind["normal_map_candidate"],
                    "roughnessMap": output_by_kind["roughness_map_candidate"],
                    "metalnessMap": output_by_kind["metalness_map_candidate"],
                    "emissiveMaskReference": output_by_kind["emissive_mask_reference"],
                    "runtimeLinked": False,
                }
            )
            for output, kind, _ in outputs:
                if kind == "color_map":
                    use = "candidato a ColorMap para SurfaceAppearance; requer importação e teste no Studio"
                elif kind == "normal_map_candidate":
                    use = "candidato a NormalMap; requer revisão de intensidade e teste em MeshPart"
                elif kind == "roughness_map_candidate":
                    use = "candidato a RoughnessMap; valor inicial derivado de brilho e material"
                elif kind == "metalness_map_candidate":
                    use = "candidato a MetalnessMap; pedra configurada como não metálica"
                else:
                    use = "máscara emissiva de referência; Roblox não a liga automaticamente ao runtime"
                record_asset(assets, source, output, kind, use)

    existing_previews = {
        entry["output"]: entry
        for entry in existing.get("assets") or []
        if entry.get("kind") == "reference_preview"
    }

    for source_name in REFERENCE_SOURCES:
        source = SOURCE_DIR / source_name
        if not source.is_file():
            raise SystemExit(f"referência ausente: {source}")
        output = REFERENCE_DIR / f"{source.stem}_preview.jpg"
        rel = output.relative_to(ROOT).as_posix()
        if args.previews_only and output.is_file() and rel in existing_previews:
            assets.append(existing_previews[rel])
            continue
        save_jpeg(source, output)
        record_asset(
            assets,
            source,
            output,
            "reference_preview",
            "briefing visual; não é decal, mesh, partícula ou animação publicada",
        )

    manifest = {
        "schemaVersion": 2,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sourcePolicy": "Conversão determinística de PNG conceitual; nenhum output é ligado automaticamente ao runtime.",
        "robloxImportPolicy": "Color, Normal, Roughness e Metalness são candidatos a SurfaceAppearance; previews e máscaras são referências. IDs, materiais, meshes, partículas e animações exigem validação separada no Roblox Studio.",
        "textureSets": texture_sets,
        "assets": assets,
    }
    manifest_path = OUTPUT_DIR / "roblox-asset-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Gerados {len(assets)} outputs em {OUTPUT_DIR.relative_to(ROOT)}")
    print(f"Manifesto: {manifest_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

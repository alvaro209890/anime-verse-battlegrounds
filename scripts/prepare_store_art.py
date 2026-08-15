#!/usr/bin/env python3
"""Deriva as peças de vitrine da Roblox a partir da capa conceitual do repo.

Determinístico e conservador: só redimensiona e recorta
`docs/assets/anime-verse-battlegrounds-cover.png`, que já é asset deste
repositório. Nenhuma fonte externa entra aqui, nenhum ID de asset é inventado e
nada é publicado — a promoção para thumbnail/ícone oficial continua sendo
decisão separada (docs/29 §"Critério de promoção", Gate P1).

Formatos da plataforma:
  * thumbnail 1920 × 1080 (16:9) — a capa cabe sem recorte, só reduz;
  * ícone 512 × 512 — recorte quadrado ABAIXO da faixa do título: a capa tem o
    título desenhado dentro dela e um recorte centrado cortaria as palavras no
    meio. Ícone aparece pequeno, onde texto não se lê de qualquer jeito.

Uso: python3 scripts/prepare_store_art.py [--clean]
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
SOURCE = ROOT / "docs" / "assets" / "anime-verse-battlegrounds-cover.png"
OUTPUT_DIR = ROOT / "docs" / "assets" / "roblox-ready" / "store"

THUMBNAIL_SIZE = (1920, 1080)
ICON_SIZE = (512, 512)
# Faixa superior ocupada pelo título desenhado na capa; o ícone começa abaixo.
TITLE_BAND_RATIO = 0.41


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_thumbnail(image: Image.Image, destination: Path) -> None:
    resized = image.resize(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
    resized.save(destination, format="JPEG", quality=92, optimize=True, progressive=True)


def build_icon(image: Image.Image, destination: Path) -> None:
    """Recorte quadrado ABAIXO da faixa do título.

    A capa tem o título desenhado dentro dela, ocupando a largura inteira. Um
    recorte quadrado centrado corta as duas palavras no meio — e ícone de
    plataforma aparece pequeno, onde texto não se lê de qualquer jeito. O
    recorte começa em 41% da altura: pega arena, cristal central e os três
    combatentes, que é o que precisa ser reconhecível em 150 px.
    """
    top = round(image.height * TITLE_BAND_RATIO)
    side = image.height - top
    left = (image.width - side) // 2
    square = image.crop((left, top, left + side, top + side))
    square.resize(ICON_SIZE, Image.Resampling.LANCZOS).save(destination, format="PNG", optimize=True)


def describe(path: Path, role: str, usage: str) -> dict[str, object]:
    with Image.open(path) as image:
        dimensions = {"width": image.width, "height": image.height}
        image_format = image.format or path.suffix.upper().lstrip(".")
    return {
        "output": path.relative_to(ROOT).as_posix(),
        "role": role,
        "dimensions": dimensions,
        "format": image_format,
        "roblox_use": usage,
        "published": False,
        "sha256": sha256(path),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", action="store_true", help="remove o diretório de saída antes de gerar")
    args = parser.parse_args()

    if not SOURCE.exists():
        raise SystemExit(f"capa conceitual ausente: {SOURCE}")
    if args.clean and OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with Image.open(SOURCE) as raw:
        image = raw.convert("RGB")
        thumbnail_path = OUTPUT_DIR / "avb_thumbnail_1920x1080.jpg"
        icon_path = OUTPUT_DIR / "avb_icon_512.png"
        build_thumbnail(image, thumbnail_path)
        build_icon(image, icon_path)

    manifest = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": SOURCE.relative_to(ROOT).as_posix(),
        "sourceSha256": sha256(SOURCE),
        "policy": (
            "Derivado de asset já existente no repositório. Conceito, não captura de runtime; "
            "publicar exige decisão separada de formato, leitura em tela pequena e Gate P1."
        ),
        "assets": [
            describe(
                thumbnail_path,
                "thumbnail",
                "candidato a thumbnail 16:9 da página da experiência; requer revisão de leitura e P1",
            ),
            describe(
                icon_path,
                "icon",
                "candidato a ícone 512x512; recorte quadrado abaixo da faixa do título, requer teste em tamanho pequeno",
            ),
        ],
    }
    manifest_path = OUTPUT_DIR / "store-art-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for asset in manifest["assets"]:
        print(f"{asset['role']:>9}: {asset['output']} ({asset['dimensions']['width']}x{asset['dimensions']['height']})")
    print(f"manifesto: {manifest_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

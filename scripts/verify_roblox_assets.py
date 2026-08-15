#!/usr/bin/env python3
"""Valida o pacote de outputs do conversor Roblox-ready."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "docs" / "assets" / "roblox-ready"
MANIFEST_PATH = PACKAGE / "roblox-asset-manifest.json"


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            sha.update(chunk)
    return sha.hexdigest()


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    assert manifest["schemaVersion"] == 2
    assert manifest["assets"]
    assert len(manifest["textureSets"]) == 3

    seen: set[str] = set()
    for entry in manifest["assets"]:
        output = ROOT / entry["output"]
        assert output.exists(), output
        assert entry["output"] not in seen, entry["output"]
        seen.add(entry["output"])
        assert digest(output) == entry["sha256"], output
        with Image.open(output) as image:
            assert image.width == entry["dimensions"]["width"]
            assert image.height == entry["dimensions"]["height"]
            assert image.mode in {"RGB", "L"}, (output, image.mode)
        assert entry["runtime_linked"] is False

    for texture_set in manifest["textureSets"]:
        for key in ("colorMap", "normalMap", "roughnessMap", "metalnessMap", "emissiveMaskReference"):
            assert (ROOT / texture_set[key]).exists(), texture_set[key]
        assert texture_set["runtimeLinked"] is False

    print(f"OK: {len(manifest['assets'])} outputs, {len(manifest['textureSets'])} texture sets, hashes e dimensões válidos")


if __name__ == "__main__":
    main()

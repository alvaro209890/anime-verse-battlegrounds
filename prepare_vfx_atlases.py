"""
Prepara atlases de VFX a partir das fontes gratuitas (docs/20).

Uso:
    python3 prepare_vfx_atlases.py [RAIZ_DO_VFX]

RAIZ_DO_VFX default: <repo>/AVB-free-vfx-assets/assets/vfx (mesma pasta do
script). Antes o caminho era hardcoded (/home/ubuntu/...) e quebrava fora da
máquina do autor (alerta 14/08).

Correções aplicadas em 14/08:
- Composição com alpha_composite (ou máscara 'L') em vez de paste(im, im):
  paste com máscara RGBA premultiplica RGB×α e escurece as bordas
  semi-transparentes (halo escuro no Roblox).
- Grade do energy ball corrigida: a fonte é 299×387 com orbes de ~34-67 px em
  pitch ~104 px (não 96). Os 9 orbes são recortados pelas bounding boxes reais
  e centralizados em células de 96 px; a coluna 3 (antes vazia = 25% de frames
  em branco) agora repete a coluna 0 e a linha 4 repete a linha 0, fechando o
  loop do flipbook sem célula transparente.
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "AVB-free-vfx-assets" / "assets" / "vfx"
if len(sys.argv) > 1:
    ROOT = Path(sys.argv[1])

source = ROOT / "free_sources"
prepared = ROOT / "prepared"
prepared.mkdir(parents=True, exist_ok=True)

CELL = 96
ATLAS = 384  # Grid4x4


def paste_centered(atlas: Image.Image, frame: Image.Image, cell_col: int, cell_row: int) -> None:
    """Recorta nada: cola `frame` (já recortado) centralizado na célula."""
    x = cell_col * CELL + (CELL - frame.width) // 2
    y = cell_row * CELL + (CELL - frame.height) // 2
    atlas.alpha_composite(frame, (x, y))


def crop_padded(im: Image.Image, box: tuple[int, int, int, int], pad: int = 3) -> Image.Image:
    x0, y0, x1, y1 = box
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


# ── Energy Ball: 9 orbes em grade 3x3 (a fonte 299x387 não tem pitch fixo de
# 96 px — os orbes pulsam entre ~34 e ~67 px em pitch ~104 px). Recorta cada
# orbe pela bounding box real e centraliza nas células; linha 4 = linha 0 e
# coluna 4 = coluna 0 para o loop do flipbook não ter célula vazia.
energy = Image.open(source / "energy_ball_ccby30.png").convert("RGBA")
# (linha, coluna) -> bbox real do orbe na fonte (medido em 14/08).
ORB_BOXES = {
    (0, 0): (18, 9, 84, 74),
    (0, 1): (125, 11, 186, 72),
    (0, 2): (228, 12, 290, 73),
    (1, 0): (24, 118, 80, 173),
    (1, 1): (129, 120, 181, 171),
    (1, 2): (236, 122, 282, 168),
    (2, 0): (29, 229, 71, 271),
    (2, 1): (136, 230, 174, 267),
    (2, 2): (243, 233, 276, 266),
}
frames = {}
for (row, col), box in ORB_BOXES.items():
    frames[(row, col)] = crop_padded(energy, box)

atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
for row in range(4):
    for col in range(4):
        frame = frames[(row % 3, col % 3)]
        paste_centered(atlas, frame, col, row)
atlas.save(prepared / "energy_ball_4x4.png", optimize=True)

# ── Power Rings: quatro frames horizontais de 64 px reorganizados em 2x2.
rings = Image.open(source / "power_ring_cc0.png").convert("RGBA")
atlas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
for index in range(4):
    frame = rings.crop((index * 64, 0, (index + 1) * 64, 64))
    atlas.alpha_composite(frame, ((index % 2) * 64, (index // 2) * 64))
atlas.save(prepared / "power_ring_2x2.png", optimize=True)

# ── Lightning: a origem tem 4x8 frames. Duplicamos o bloco de 32 para preencher
# um atlas 8x8; o efeito só vive ~120 ms e usa o início do flipbook.
lightning = Image.open(prepared / "lightning_shock_8bit.png").convert("RGBA")
atlas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
atlas.alpha_composite(lightning, (0, 0))
atlas.alpha_composite(lightning, (256, 0))
atlas.save(prepared / "lightning_shock_8x8.png", optimize=True)

# ── Explosões: a origem preparada é 8x7. Oitava linha transparente é adicionada
# para satisfazer o layout Grid8x8 do ParticleEmitter.
for name in ("explosion_0003_cc0_1024px", "explosion_0005_cc0_1024px"):
    image = Image.open(prepared / f"{name}.png").convert("RGBA")
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    atlas.alpha_composite(image, (0, 0))
    atlas.save(prepared / f"{name}_8x8.png", optimize=True)

# ── verificação pós-geração ──────────────────────────────────────────────────
ok = True
for name in ("energy_ball_4x4.png", "power_ring_2x2.png", "lightning_shock_8x8.png",
             "explosion_0003_cc0_1024px_8x8.png", "explosion_0005_cc0_1024px_8x8.png"):
    path = prepared / name
    with Image.open(path) as im:
        im.verify()
    im = Image.open(path).convert("RGBA")
    if im.width % 4 != 0 or im.height % 4 != 0:
        print(f"ERRO: {name} tem dimensão não múltipla de 4 ({im.width}x{im.height})")
        ok = False
    else:
        print(f"ok: {name} {im.width}x{im.height}")
if not ok:
    raise SystemExit(1)
print("atlases regenerados em", prepared)

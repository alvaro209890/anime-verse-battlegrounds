from pathlib import Path
from PIL import Image

root = Path('/home/ubuntu/anime-verse-battlegrounds/AVB-free-vfx-assets/assets/vfx')
source = root / 'free_sources'
prepared = root / 'prepared'
prepared.mkdir(parents=True, exist_ok=True)

# Energy Ball: os nove orbes da grade superior viram um atlas 4x4; a primeira
# linha é repetida na quarta para não introduzir células transparentes no loop.
energy = Image.open(source / 'energy_ball_ccby30.png').convert('RGBA')
atlas = Image.new('RGBA', (384, 384), (0, 0, 0, 0))
for row in range(3):
    for col in range(3):
        frame = energy.crop((col * 96, row * 96, (col + 1) * 96, (row + 1) * 96))
        atlas.paste(frame, (col * 96, row * 96), frame)
for col in range(4):
    frame = atlas.crop((col * 96, 0, (col + 1) * 96, 96))
    atlas.paste(frame, (col * 96, 288), frame)
atlas.save(prepared / 'energy_ball_4x4.png', optimize=True)

# Power Rings: quatro frames horizontais de 64 px reorganizados em 2x2.
rings = Image.open(source / 'power_ring_cc0.png').convert('RGBA')
atlas = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
for index in range(4):
    frame = rings.crop((index * 64, 0, (index + 1) * 64, 64))
    atlas.paste(frame, ((index % 2) * 64, (index // 2) * 64), frame)
atlas.save(prepared / 'power_ring_2x2.png', optimize=True)

# Lightning: a origem tem 4x8 frames. Duplicamos o bloco de 32 para preencher
# um atlas 8x8; o efeito só vive ~120 ms e usa o início do flipbook.
lightning = Image.open(prepared / 'lightning_shock_8bit.png').convert('RGBA')
atlas = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
atlas.paste(lightning, (0, 0), lightning)
atlas.paste(lightning, (256, 0), lightning)
atlas.save(prepared / 'lightning_shock_8x8.png', optimize=True)

# Explosões: a origem preparada é 8x7. Oitava linha transparente é adicionada
# para satisfazer o layout Grid8x8 do ParticleEmitter.
for name in ('explosion_0003_cc0_1024px', 'explosion_0005_cc0_1024px'):
    image = Image.open(prepared / f'{name}.png').convert('RGBA')
    atlas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    atlas.paste(image, (0, 0), image)
    atlas.save(prepared / f'{name}_8x8.png', optimize=True)

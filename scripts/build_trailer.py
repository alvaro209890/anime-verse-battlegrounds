#!/usr/bin/env python3
"""Monta o trailer do site (web/assets/video/anime-verse-trailer-animated.mp4).

Tudo é gerado por código: os cortes são calculados sobre a grade de compasso da
trilha `web/assets/audio/jackpot.mp3` (129,35 BPM, compasso de 1,8554 s) e as
cartelas de texto são desenhadas com Pillow. Nenhum arquivo é editado à mão.

Fontes de imagem:
  * `2026-08-13 14-26-49.mp4` (raiz)  — gravação real do jogo no Roblox Studio.
    A gravação é de tela cheia; recortamos só o viewport (716x403 em 212,161),
    o que também remove a topbar do Roblox, e ampliamos para 1280x720.
  * `media/trailer-combat-animated-source.mp4` (o trailer anterior, preservado
    fora de `web/`) — banco de planos de combate animados. Fica fora do site
    porque não é publicado: existe só para a montagem continuar reproduzível.
  * `web/assets/video/trailer-domain-expansion-vfx.mp4` e
    `web/assets/video/trailer-violet-pulse-vfx.mp4` — VFX de domínio/pulso.

Regra dura: o stream de vídeo e o de áudio terminam juntos. O vídeo é montado
em contagem de QUADROS (1002 @ 30 fps = 33,40 s) e o áudio é cortado no mesmo
tempo; `--check` reprova se as durações divergirem mais de 0,1 s.

Uso:
    python3 scripts/build_trailer.py            # monta e valida
    python3 scripts/build_trailer.py --reuse    # reaproveita planos já rendered
    python3 scripts/build_trailer.py --check    # só valida o arquivo existente
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

GAMEPLAY = os.path.join(ROOT, "2026-08-13 14-26-49.mp4")
ANIMATED = os.path.join(ROOT, "media/trailer-combat-animated-source.mp4")
DOMAIN = os.path.join(ROOT, "web/assets/video/trailer-domain-expansion-vfx.mp4")
PULSE = os.path.join(ROOT, "web/assets/video/trailer-violet-pulse-vfx.mp4")
TRACK = os.path.join(ROOT, "web/assets/audio/jackpot.mp3")
OUT = os.path.join(ROOT, "web/assets/video/anime-verse-trailer-animated.mp4")
POSTER = os.path.join(ROOT, "web/assets/images/anime-verse-trailer-animated-poster.jpg")

FPS = 30
W, H = 1280, 720

# Grade musical medida em scripts/build_trailer (fluxo espectral + autocorrelação):
BPM = 129.35
BEAT = 60.0 / BPM  # 0,463857 s
MUSIC_IN = 7.7237  # tempo forte da trilha; a virada entra 2 compassos depois
TOTAL_BEATS = 72  # 18 compassos
TOTAL_FRAMES = 1002  # 33,40 s @ 30 fps
DURATION = TOTAL_FRAMES / FPS

FONT_DISPLAY = "/usr/share/fonts/opentype/urw-base35/NimbusSansNarrow-Bold.otf"
FONT_MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

REUSE = "--reuse" in sys.argv  # reaproveita os planos já rendered no cache

VIOLET = (185, 140, 255)
BLUE = (90, 214, 255)
MUTED = (157, 164, 192)

# --------------------------------------------------------------------------
# EDL — (beats de duração, fonte, ponto de entrada, opções)
# "fit" estica/comprime o trecho para caber no corte; sem "fit" a velocidade é 1x.
# "card" põe uma cartela de texto DENTRO do plano (cada cartela cabe inteira em
# um único corte, então a sobreposição é local e o passe final fica simples).
# --------------------------------------------------------------------------
EDL = [
    # ATO 1 — abertura: o domínio abre e estoura exatamente na virada (3,71 s)
    (8, DOMAIN, 2.00, {"fit": 5.00, "zoom": (1.00, 1.06), "card": "kicker"}),
    # ATO 2 — combate, cortes de 2 tempos
    (2, ANIMATED, 1.42, {"flash": 0.55}),
    (2, ANIMATED, 2.88, {}),
    (2, ANIMATED, 3.90, {}),
    (2, ANIMATED, 25.95, {"flash": 0.35}),
    (4, GAMEPLAY, 14.80, {"card": "tag"}),
    (2, ANIMATED, 6.45, {"zoom": (1.00, 1.05)}),
    (2, GAMEPLAY, 1.20, {}),  # corrida/câmera em movimento (18.30 ficava parado)
    (2, ANIMATED, 23.30, {"flash": 0.45}),
    (2, ANIMATED, 24.35, {}),
    (2, GAMEPLAY, 25.10, {}),
    (2, ANIMATED, 25.45, {}),
    # rajada de 1 tempo
    (1, ANIMATED, 1.05, {}),
    (1, GAMEPLAY, 4.90, {}),
    (1, ANIMATED, 3.95, {"flash": 0.4}),
    (1, ANIMATED, 26.05, {"flash": 0.5}),
    (2, GAMEPLAY, 26.30, {}),
    (2, ANIMATED, 7.55, {}),
    # ATO 3 — pico: o golpe volta em câmera lenta, o domínio estoura de novo
    (4, ANIMATED, 25.95, {"fit": 0.93, "zoom": (1.12, 1.02), "smooth": True}),
    (2, DOMAIN, 4.50, {"fit": 2.50, "flash": 0.5}),
    (2, ANIMATED, 27.05, {}),
    (4, GAMEPLAY, 16.60, {"card": "tag"}),
    # ATO 4 — fecho
    (2, ANIMATED, 6.60, {"zoom": (1.02, 1.10)}),
    (2, ANIMATED, 23.95, {}),
    (2, ANIMATED, 4.35, {"fit": 0.47, "zoom": (1.18, 1.06), "smooth": True}),
    (2, DOMAIN, 6.07, {"flash": 0.45}),
    # o zoom precisa ser largo: uma deriva de 0,10 em 5,5 s fica sub-pixel e a
    # cartela final vira uma imagem parada
    (12, PULSE, 0.00, {"fit": 5.00, "zoom": (1.22, 1.00), "dark": 0.13, "card": "endcard"}),
]


def run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n" + proc.stderr[-4000:] + "\n")
        raise SystemExit(f"ffmpeg falhou ({proc.returncode})")


def probe(path: str) -> dict:
    out = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries",
            "stream=index,codec_type,codec_name,width,height,duration,nb_frames,r_frame_rate",
            "-show_entries", "format=duration,size", "-of", "json", path,
        ],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)


# --------------------------------------------------------------------------
# Cartelas de texto (Pillow)
# --------------------------------------------------------------------------
def tracked(draw: ImageDraw.ImageDraw, xy, text, font, spacing, fill) -> None:
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + spacing


def tracked_width(draw: ImageDraw.ImageDraw, text, font, spacing) -> float:
    if not text:
        return 0.0
    return sum(draw.textlength(c, font=font) for c in text) + spacing * (len(text) - 1)


def glow(layer: Image.Image, color, radius: int, strength: float) -> Image.Image:
    alpha = layer.split()[3].filter(ImageFilter.GaussianBlur(radius))
    alpha = alpha.point(lambda v: int(v * strength))
    halo = Image.new("RGBA", layer.size, color + (0,))
    halo.putalpha(alpha)
    return Image.alpha_composite(halo, layer)


def make_kicker(path: str) -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_DISPLAY, 46)
    fm = ImageFont.truetype(FONT_MONO, 13)

    top = 556
    w1 = tracked_width(d, "ANIME VERSE", f, 13)
    tracked(d, ((W - w1) / 2, top), "ANIME VERSE", f, 13, (247, 247, 251, 255))
    w2 = tracked_width(d, "BATTLEGROUNDS", f, 13)
    tracked(d, ((W - w2) / 2, top + 46), "BATTLEGROUNDS", f, 13, VIOLET + (255,))

    d.line([(W / 2 - 90, top - 20), (W / 2 + 90, top - 20)], fill=VIOLET + (110,), width=1)
    kick = "RPG DE AÇÃO / ROBLOX"
    w3 = tracked_width(d, kick, fm, 4)
    tracked(d, ((W - w3) / 2, top + 108), kick, fm, 4, MUTED + (200,))
    glow(img, VIOLET, 18, 0.55).save(path)


def make_tag(path: str) -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fm = ImageFont.truetype(FONT_MONO, 15)
    text = "GAMEPLAY REAL  ·  ROBLOX STUDIO"
    tw = tracked_width(d, text, fm, 2)
    x, y = 52, 512  # acima da HUD do jogo (barras de vida/guarda/umbral)
    d.rounded_rectangle([x - 16, y - 11, x + tw + 34, y + 28], radius=4, fill=(8, 10, 22, 165))
    d.ellipse([x, y + 6, x + 8, y + 14], fill=VIOLET + (255,))
    tracked(d, (x + 20, y), text, fm, 2, (247, 247, 251, 235))
    img.save(path)


def make_endcard(path: str) -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(FONT_DISPLAY, 92)
    fm = ImageFont.truetype(FONT_MONO, 15)
    fs = ImageFont.truetype(FONT_MONO, 13)

    # véu escuro atrás do bloco de texto para o logo não brigar com o VFX
    scrim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scrim)
    y0, y1 = 176, 584
    for y in range(y0, y1):
        t = (y - y0) / (y1 - y0)
        a = int(150 * (1 - abs(t * 2 - 1) ** 1.6))
        sd.line([(0, y), (W, y)], fill=(6, 8, 18, a))
    # o texto vive numa camada própria: o brilho não pode contaminar o véu
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    top = 236
    w1 = tracked_width(d, "ANIME VERSE", big, 20)
    tracked(d, ((W - w1) / 2, top), "ANIME VERSE", big, 20, (247, 247, 251, 255))

    # segunda linha com gradiente violeta -> azul, via máscara de texto
    mask = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(mask)
    w2 = tracked_width(dm, "BATTLEGROUNDS", big, 20)
    tracked(dm, ((W - w2) / 2, top + 88), "BATTLEGROUNDS", big, 20, 255)
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    for x in range(W):
        t = x / (W - 1)
        gd.line(
            [(x, 0), (x, H)],
            fill=(
                int(VIOLET[0] + (BLUE[0] - VIOLET[0]) * t),
                int(VIOLET[1] + (BLUE[1] - VIOLET[1]) * t),
                int(VIOLET[2] + (BLUE[2] - VIOLET[2]) * t),
                255,
            ),
        )
    grad.putalpha(mask)
    img = Image.alpha_composite(img, grad)
    d = ImageDraw.Draw(img)

    d.line([(W / 2 - 210, top + 212), (W / 2 + 210, top + 212)], fill=VIOLET + (95,), width=1)
    l1 = "RPG DE AÇÃO  ·  EM DESENVOLVIMENTO  ·  2026.08"
    w3 = tracked_width(d, l1, fm, 3)
    tracked(d, ((W - w3) / 2, top + 236), l1, fm, 3, MUTED + (225,))
    l2 = "github.com/alvaro209890/anime-verse-battlegrounds"
    w4 = tracked_width(d, l2, fs, 2)
    tracked(d, ((W - w4) / 2, top + 266), l2, fs, 2, VIOLET + (205,))
    Image.alpha_composite(scrim, glow(img, VIOLET, 26, 0.5)).save(path)


# --------------------------------------------------------------------------
# Montagem
# --------------------------------------------------------------------------
def shot_chain(src: str, frames: int, opts: dict) -> str:
    out_dur = frames / FPS
    parts = []

    if src == GAMEPLAY:
        # recorta o viewport da gravação de tela (tira topbar do Roblox e a
        # interface do Studio) e amplia 1,79x com lanczos + realce
        parts.append("crop=716:403:212:161")
        parts.append("scale=1920:1080:flags=lanczos")
        parts.append("unsharp=5:5:0.9:5:5:0")
        parts.append("eq=contrast=1.10:saturation=1.16:brightness=-0.015")
        parts.append("colorbalance=rs=-0.02:bs=0.07:bh=0.05")
        native_fps = 30.0
    elif src == ANIMATED:
        # tira a topbar do Roblox do trailer anterior com um leve punch-in
        parts.append("crop=1228:691:26:28")
        parts.append("scale=1920:1080:flags=lanczos")
        parts.append("eq=contrast=1.05:saturation=1.12")
        native_fps = 24.0
    else:
        parts.append("scale=1920:1080:flags=lanczos")
        native_fps = 24.0

    if opts.get("dark"):
        parts.append(f"eq=brightness=-{opts['dark']}:saturation=0.92")

    fit = opts.get("fit")
    if fit:
        parts.append(f"setpts={out_dur / fit:.6f}*PTS")

    if opts.get("smooth") or native_fps != FPS:
        parts.append(f"framerate=fps={FPS}")  # mistura quadros (24->30 e câmera lenta)
    else:
        parts.append(f"fps={FPS}")

    zoom = opts.get("zoom")
    if zoom:
        z0, z1 = zoom
        parts.append(
            f"zoompan=z='{z0:.4f}+({z1 - z0:.4f})*on/{max(frames - 1, 1)}':d=1"
            f":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={W}x{H}:fps={FPS}"
        )
    else:
        parts.append(f"scale={W}:{H}:flags=lanczos")

    flash = opts.get("flash")
    if flash:
        parts.append(f"eq=brightness='max(0,{flash}*(1-n/3))':eval=frame")

    parts.append("format=yuv420p")
    return ",".join(parts)


def card_filter(kind: str, dur: float) -> str:
    """Fades em ALFA da cartela, no relógio local do plano.

    A cartela entra como segunda entrada com a mesma linha de tempo do plano —
    nada de `setpts` deslocando timestamps (isso trava o grafo do ffmpeg). Antes
    do `st` do fade-in o alfa já é zero, então o atraso sai de graça.
    """
    if kind == "kicker":
        return ("format=rgba,fade=t=in:st=0.95:d=0.55:alpha=1,"
                "fade=t=out:st=2.95:d=0.55:alpha=1")
    if kind == "tag":
        return ("format=rgba,fade=t=in:st=0.18:d=0.32:alpha=1,"
                f"fade=t=out:st={dur - 0.45:.3f}:d=0.35:alpha=1")
    return ("format=rgba,fade=t=in:st=0.20:d=0.75:alpha=1,"  # endcard
            f"fade=t=out:st={dur - 0.30:.3f}:d=0.25:alpha=1")


def build(tmp: str) -> None:
    # limites de corte em quadros (a batida não cai em quadro inteiro; arredondar
    # cada limite mantém o erro abaixo de meio quadro e o total exato)
    bounds, acc = [0], 0
    for beats, *_ in EDL:
        acc += beats
        bounds.append(round(acc * BEAT * FPS))
    assert bounds[-1] == TOTAL_FRAMES, f"total {bounds[-1]} != {TOTAL_FRAMES}"

    cards = {"kicker": os.path.join(tmp, "kicker.png"),
             "tag": os.path.join(tmp, "tag.png"),
             "endcard": os.path.join(tmp, "endcard.png")}
    make_kicker(cards["kicker"])
    make_tag(cards["tag"])
    make_endcard(cards["endcard"])

    files = []
    for i, (beats, src, tin, opts) in enumerate(EDL):
        frames = bounds[i + 1] - bounds[i]
        out_dur = frames / FPS
        take = opts.get("fit", out_dur) + 0.6  # folga para o framerate/blend
        # a chave do cache carrega a definição do plano: mexer na EDL invalida
        key = hashlib.md5(repr((src, tin, frames, sorted(opts.items()))).encode()).hexdigest()[:8]
        dst = os.path.join(tmp, f"shot_{i:02d}_{key}.mp4")
        card = opts.get("card")
        if REUSE and os.path.exists(dst):
            try:
                if int(probe(dst)["streams"][0]["nb_frames"]) == frames:
                    files.append(dst)
                    print(f"  plano {i:02d}  reaproveitado")
                    continue
            except Exception:  # noqa: BLE001 - cache inválido, refaz o plano
                pass
        chain = shot_chain(src, frames, opts)
        cmd = ["ffmpeg", "-y", "-v", "error",
               "-ss", f"{tin:.4f}", "-t", f"{take:.4f}", "-i", src]
        if card:
            cmd += ["-loop", "1", "-framerate", str(FPS),
                    "-t", f"{out_dur + 0.2:.4f}", "-i", cards[card]]
            cmd += ["-filter_complex",
                    f"[0:v]{chain}[base];"
                    f"[1:v]{card_filter(card, out_dur)}[ov];"
                    f"[base][ov]overlay=0:0:eof_action=pass,format=yuv420p[v]",
                    "-map", "[v]"]
        else:
            cmd += ["-vf", chain]
        run(cmd + [
            "-an", "-frames:v", str(frames), "-r", str(FPS),
            "-c:v", "libx264", "-crf", "15", "-preset", "medium", "-pix_fmt", "yuv420p",
            dst,
        ])
        got = int(probe(dst)["streams"][0]["nb_frames"])
        if got != frames:
            raise SystemExit(f"plano {i}: {got} quadros, esperado {frames}")
        files.append(dst)
        print(f"  plano {i:02d}  {bounds[i] / FPS:6.2f}s  {frames:3d}q  "
              f"{os.path.basename(src)[:34]}{'  +' + card if card else ''}")

    listfile = os.path.join(tmp, "list.txt")
    with open(listfile, "w", encoding="utf-8") as fh:
        for f in files:
            fh.write(f"file '{f}'\n")

    # Vídeo e áudio são finalizados em passes SEPARADOS e só então unidos por
    # cópia. Num passe único, o vídeo e o mp3 disputam o mesmo relógio e o
    # ffmpeg encerra quando o vídeo acaba — o áudio saía truncado (~26 s de 33 s,
    # variando a cada execução). Separado, cada stream tem 33,40 s exatos.
    vtmp = os.path.join(tmp, "video.mp4")
    atmp = os.path.join(tmp, "audio.m4a")

    run([
        "ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", listfile,
        "-an", "-vf",
        "eq=contrast=1.03:saturation=1.05,vignette=PI/6,"
        f"fade=t=in:st=0:d=0.55,fade=t=out:st={DURATION - 1.15:.3f}:d=1.15",
        "-frames:v", str(TOTAL_FRAMES), "-r", str(FPS),
        "-c:v", "libx264", "-crf", "23", "-preset", "slow", "-profile:v", "high",
        "-level", "4.0", "-pix_fmt", "yuv420p", "-g", "60", vtmp,
    ])

    # o recorte da trilha vai no atrim, em tempo absoluto do mp3: `-ss` na
    # entrada não zera o relógio que o filtro enxerga e o corte sai errado
    run([
        "ffmpeg", "-y", "-v", "error", "-i", TRACK, "-filter_complex",
        f"[0:a]atrim=start={MUSIC_IN:.4f}:end={MUSIC_IN + DURATION:.4f},"
        f"asetpts=N/SR/TB,afade=t=in:st=0:d=0.35,"
        f"afade=t=out:st={DURATION - 1.6:.3f}:d=1.6,alimiter=limit=0.95[a]",
        "-map", "[a]", "-t", f"{DURATION:.4f}",
        "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2", atmp,
    ])

    run([
        "ffmpeg", "-y", "-v", "error", "-i", vtmp, "-i", atmp,
        "-map", "0:v:0", "-map", "1:a:0", "-c", "copy",
        "-movflags", "+faststart", OUT + ".tmp.mp4",
    ])
    shutil.move(OUT + ".tmp.mp4", OUT)


def make_poster(at: float) -> None:
    run(["ffmpeg", "-y", "-v", "error", "-ss", f"{at:.2f}", "-i", OUT,
         "-frames:v", "1", "-q:v", "2", POSTER])


def check() -> bool:
    info = probe(OUT)
    ok = True
    durs = {}
    for st in info["streams"]:
        durs[st["codec_type"]] = float(st["duration"])
        print(f"  {st['codec_type']:5} {st['codec_name']:5} "
              f"{st.get('width', '')}x{st.get('height', '')} "
              f"dur={st['duration']}s frames={st.get('nb_frames', '?')}")
    print(f"  container dur={info['format']['duration']}s "
          f"size={int(info['format']['size']) / 1e6:.2f} MB")
    delta = abs(durs["video"] - durs["audio"])
    print(f"  |video - audio| = {delta * 1000:.0f} ms")
    if delta > 0.1:
        print("  FALHA: streams com durações diferentes (congelamento no fim)")
        ok = False
    if abs(float(info["format"]["duration"]) - durs["video"]) > 0.1:
        print("  FALHA: container diverge do stream de vídeo")
        ok = False
    frames = int(next(s for s in info["streams"] if s["codec_type"] == "video")["nb_frames"])
    if frames != TOTAL_FRAMES:
        print(f"  FALHA: {frames} quadros, esperado {TOTAL_FRAMES}")
        ok = False
    if int(info["format"]["size"]) > 10.5e6:
        print("  AVISO: acima de 10 MB")
    return ok


def main() -> None:
    if "--check" not in sys.argv:
        for p in (GAMEPLAY, ANIMATED, DOMAIN, PULSE, TRACK):
            if not os.path.exists(p):
                raise SystemExit(f"faltando: {p}")
        tmp = (os.path.join(tempfile.gettempdir(), "avb-trailer-cache") if REUSE
               else tempfile.mkdtemp(prefix="avb-trailer-"))
        os.makedirs(tmp, exist_ok=True)
        try:
            print("montando planos…")
            build(tmp)
        finally:
            if not REUSE:
                shutil.rmtree(tmp, ignore_errors=True)
        make_poster(float(os.environ.get("AVB_POSTER_AT", "6.70")))  # o estouro vermelho
        print("poster:", os.path.relpath(POSTER, ROOT))
    print("validando", os.path.relpath(OUT, ROOT))
    raise SystemExit(0 if check() else 1)


if __name__ == "__main__":
    main()

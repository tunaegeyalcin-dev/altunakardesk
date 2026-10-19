#!/usr/bin/env python3
"""AB isaretinden (siyah yuvarlak kare, kirmizi A, sari B) AltunakarDesk'in butun simge
dosyalarini uretir ve ozetlerini altunakar/marka/uretilen.txt'ye yazar (marka_denetimi okur)."""
import base64, hashlib, io, pathlib, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont

KOK = pathlib.Path(__file__).resolve().parents[2]
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
KIRMIZI, SARI, SIYAH = (0xE4, 0x1E, 0x2B, 255), (0xF5, 0xC5, 0x18, 255), (0, 0, 0, 255)
yazilan = []

def ab(boyut, zemin=True, tek_renk=None):
    n = boyut * 4  # buyuk ciz, sonra kucult: puruzsuz kenar
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if zemin:
        d.rounded_rectangle((0, 0, n - 1, n - 1), radius=int(n * 0.22), fill=SIYAH)
    f = ImageFont.truetype(FONT, int(n * (0.52 if zemin else 0.72)))
    aw, bw = d.textlength("A", font=f), d.textlength("B", font=f)
    x = (n - (aw + bw)) / 2
    sol, ust, sag, alt = f.getbbox("AB")
    y = (n - (alt - ust)) / 2 - ust
    d.text((x, y), "A", font=f, fill=tek_renk or KIRMIZI)
    d.text((x + aw, y), "B", font=f, fill=tek_renk or SARI)
    return im.resize((boyut, boyut), Image.LANCZOS)

def mac_ikon(boyut):
    """Mac simgeleri kenarda bosluk ister: 1024'te 824'luk kare."""
    tuval = Image.new("RGBA", (boyut, boyut), (0, 0, 0, 0))
    ic = round(boyut * 824 / 1024)
    tuval.paste(ab(ic), ((boyut - ic) // 2, (boyut - ic) // 2))
    return tuval

def kaydet(im, yol, **kw):
    hedef = KOK / yol
    hedef.parent.mkdir(parents=True, exist_ok=True)
    im.save(hedef, **kw)
    yazilan.append(yol)

def svg(yol, boyut=512):
    tampon = io.BytesIO(); ab(boyut).save(tampon, "PNG")
    veri = base64.b64encode(tampon.getvalue()).decode()
    (KOK / yol).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{boyut}" height="{boyut}" viewBox="0 0 {boyut} {boyut}">'
        f'<image width="{boyut}" height="{boyut}" xlink:href="data:image/png;base64,{veri}"/></svg>\n')
    yazilan.append(yol)

ICO = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
kaydet(ab(1024), "res/icon.png")
kaydet(mac_ikon(1024), "res/mac-icon.png")
for b, yol in [(32, "res/32x32.png"), (64, "res/64x64.png"), (128, "res/128x128.png"), (256, "res/128x128@2x.png")]:
    kaydet(ab(b), yol)
for yol in ["res/icon.ico", "res/tray-icon.ico", "flutter/windows/runner/resources/app_icon.ico"]:
    kaydet(ab(256), yol, format="ICO", sizes=ICO)
kaydet(ab(60, zemin=False, tek_renk=SIYAH), "res/mac-tray-dark-x2.png")  # sablon: renk onemsiz (ozgun boyut 60)
kaydet(ab(60, zemin=False, tek_renk=(255, 255, 255, 255)), "res/mac-tray-light-x2.png")
kaydet(ab(256), "flutter/assets/icon.png")
kaydet(ab(256), "flutter/assets/logo.png")
svg("flutter/assets/icon.svg")
svg("res/scalable.svg")

with tempfile.TemporaryDirectory() as t:
    iconset = pathlib.Path(t) / "AppIcon.iconset"
    iconset.mkdir()
    for b in (16, 32, 128, 256, 512):
        mac_ikon(b).save(iconset / f"icon_{b}x{b}.png")
        mac_ikon(b * 2).save(iconset / f"icon_{b}x{b}@2x.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(KOK / "flutter/macos/Runner/AppIcon.icns")], check=True)
    yazilan.append("flutter/macos/Runner/AppIcon.icns")

satirlar = [f"{hashlib.sha256((KOK / y).read_bytes()).hexdigest()}  {y}" for y in yazilan]
(KOK / "altunakar/marka/uretilen.txt").write_text("\n".join(satirlar) + "\n")
print(f"{len(yazilan)} simge dosyasi uretildi")

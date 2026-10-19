#!/usr/bin/env python3
"""Gorunur yerlerde RustDesk adi, rustdesk.com baglantisi ya da eski simge kalmadigini denetler.
Cikis 0: temiz. Lisans geregi korunan telif satiri (Purslane) serbesttir."""
import hashlib, pathlib, re, sys

KOK = pathlib.Path(__file__).resolve().parent.parent
sorunlar = []

def oku(yol):
    return (KOK / yol).read_text(encoding="utf-8", errors="replace")

def iste(kosul, mesaj):
    if not kosul:
        sorunlar.append(mesaj)

xc = oku("flutter/macos/Runner/Configs/AppInfo.xcconfig")
iste("PRODUCT_NAME = AltunakarDesk" in xc, "AppInfo.xcconfig: PRODUCT_NAME AltunakarDesk degil")
iste("PRODUCT_BUNDLE_IDENTIFIER = com.altunakar.desk" in xc, "AppInfo.xcconfig: paket kimligi com.altunakar.desk degil")
iste("com.carriez" not in oku("flutter/macos/Runner/Info.plist"), "Info.plist: com.carriez kaldi")

rc = oku("flutter/windows/runner/Runner.rc")
for satir in rc.splitlines():
    if "RustDesk" in satir and "Purslane" not in satir:
        sorunlar.append("Runner.rc: " + satir.strip())
iste('"ProductName", "AltunakarDesk"' in rc, "Runner.rc: ProductName AltunakarDesk degil")

for d in ("res/rustdesk.desktop", "res/rustdesk-link.desktop"):
    iste("Name=RustDesk" not in oku(d), d + ": Name=RustDesk kaldi")

for yol in sorted((KOK / "flutter/lib").rglob("*.dart")) + [KOK / "src/client.rs"]:
    for no, satir in enumerate(yol.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        s = satir.strip()
        if s.startswith("//"):
            continue
        goreli = yol.relative_to(KOK)
        if re.search(r"https?://(www\.)?rustdesk\.com", s):
            sorunlar.append(f"{goreli}:{no}: rustdesk.com baglantisi")
        # ad karsilastirmasi (ornek: != "RustDesk") gorunur metin degildir
        if re.search(r"""["']RustDesk["']""", s) and not re.search(r"""[!=]=\s*["']RustDesk["']""", s):
            sorunlar.append(f"{goreli}:{no}: 'RustDesk' metni")

hakkinda = oku("flutter/lib/desktop/pages/desktop_setting_page.dart")
iste("github.com/tunaegeyalcin-dev/altunakardesk" in hakkinda, "Hakkinda: kaynak kod baglantisi yok")
iste("Purslane Tech Pte. Ltd." in hakkinda, "Hakkinda: RustDesk telif satiri silinmis (AGPL)")

manifest = KOK / "altunakar/marka/uretilen.txt"
if not manifest.exists():
    sorunlar.append("simgeler uretilmemis (altunakar/marka/uretilen.txt yok)")
else:
    for satir in manifest.read_text().splitlines():
        ozet, yol = satir.split("  ", 1)
        dosya = KOK / yol
        if not dosya.exists() or hashlib.sha256(dosya.read_bytes()).hexdigest() != ozet:
            sorunlar.append(f"simge degismis ya da eksik: {yol}")

for s in sorunlar:
    print("MARKA:", s)
print("marka temiz" if not sorunlar else f"{len(sorunlar)} sorun")
sys.exit(1 if sorunlar else 0)

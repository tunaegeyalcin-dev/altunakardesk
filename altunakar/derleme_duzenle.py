#!/usr/bin/env python3
"""flutter-build.yml ve Mac derleme dosyalarini AltunakarDesk icin duzenler.
Tekrar calistirmak zararsizdir; RustDesk guncellemesinde beklenen satir kaybolursa durur."""
import pathlib, re, sys

KOK = pathlib.Path(__file__).resolve().parent.parent
AD = "AltunakarDesk"

def dosya_degistir(yol, eski, yeni):
    p = KOK / yol
    s = p.read_text(encoding="utf-8")
    if eski not in s and yeni in s:
        return
    if eski not in s:
        sys.exit(f"{yol}: '{eski}' bulunamadi")
    p.write_text(s.replace(eski, yeni), encoding="utf-8")

# Mac: uygulama paketi adi
dosya_degistir("build.py", "./build/macos/Build/Products/Release/RustDesk.app", f"./build/macos/Build/Products/Release/{AD}.app")
dosya_degistir("flutter/macos/Runner.xcodeproj/project.pbxproj", "RustDesk.app", f"{AD}.app")
dosya_degistir("flutter/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme", "RustDesk.app", f"{AD}.app")
# Xcode projesi paket kimligini her yapilandirmada ayrica yazar (AppInfo.xcconfig'i ezer)
dosya_degistir("flutter/macos/Runner.xcodeproj/project.pbxproj",
               "PRODUCT_BUNDLE_IDENTIFIER = com.carriez.rustdesk;", "PRODUCT_BUNDLE_IDENTIFIER = com.altunakar.desk;")

YML = KOK / ".github/workflows/flutter-build.yml"
s = YML.read_text(encoding="utf-8")

def is_araligi(ad):
    m = re.search(rf"^  {re.escape(ad)}:\n", s, re.M)
    if not m:
        sys.exit(f"is bulunamadi: {ad}")
    son = re.search(r"^  [A-Za-z0-9_-]+:\n", s[m.end():], re.M)
    return m.start(), (m.end() + son.start()) if son else len(s)

def is_kapat(ad):
    global s
    a, b = is_araligi(ad)
    govde = s[a:b]
    ust_son = govde.find("\n    steps:")
    ust = govde if ust_son < 0 else govde[:ust_son]
    if re.search(r"^    if: false$", ust, re.M):
        return
    if re.search(r"^    if: .*$", ust, re.M):
        ust = re.sub(r"^    if: .*$", "    if: false", ust, count=1, flags=re.M)
    else:
        bas = ust.index("\n") + 1
        ust = ust[:bas] + "    if: false\n" + ust[bas:]
    s = s[:a] + ust + (govde[ust_son:] if ust_son >= 0 else "") + s[b:]

def iste_degistir(ad, eski, yeni):
    global s
    a, b = is_araligi(ad)
    govde = s[a:b]
    if yeni in govde:  # daha once uygulanmis
        return
    if eski not in govde:
        sys.exit(f"{ad}: '{eski}' bulunamadi")
    s = s[:a] + govde.replace(eski, yeni) + s[b:]

def adim_kapat(ad, adim):
    global s
    a, b = is_araligi(ad)
    govde = s[a:b]
    i = govde.find(f"      - name: {adim}\n")
    if i < 0:
        sys.exit(f"{ad}: adim yok: {adim}")
    j = govde.find("\n      - name:", i + 1)
    adim_govde = govde[i:j if j > 0 else len(govde)]
    yeni = re.sub(r"^        if: .*$", "        if: false", adim_govde, count=1, flags=re.M)
    if yeni == adim_govde and "        if: false" not in adim_govde:
        yeni = adim_govde.replace("\n", "\n        if: false\n", 1)
    s = s[:a] + govde.replace(adim_govde, yeni) + s[b:]

for ad in ["build-for-windows-sciter", "build-rustdesk-ios", "build-rustdesk-android",
           "build-rustdesk-android-universal", "build-rustdesk-linux-drm", "build-rustdesk-linux-sciter",
           "build-appimage", "build-flatpak", "build-rustdesk-web", "publish_unsigned"]:
    is_kapat(ad)

W = "build-for-windows-flutter"
iste_degistir(W, "runner/Release ./rustdesk\n",
              f"runner/Release ./rustdesk\n          mv ./rustdesk/rustdesk.exe ./rustdesk/{AD}.exe\n")
iste_degistir(W, "-e ../../rustdesk/rustdesk.exe", f"-e ../../rustdesk/{AD}.exe")
iste_degistir(W, "python preprocess.py --arp -d ../../rustdesk\n", f"python preprocess.py --arp -d ../../rustdesk --app-name {AD}\n")
iste_degistir(W, "SignOutput/rustdesk-", f"SignOutput/{AD}-")
adim_kapat(W, "Build pre-built MSI template")
adim_kapat(W, "Upload unsigned msi template")

M = "build-for-macOS"
iste_degistir(M, "RustDesk.app", f"{AD}.app")
iste_degistir(M, "rustdesk-${{ env.VERSION }}", f"{AD}-${{{{ env.VERSION }}}}")
iste_degistir(M, "rustdesk*??.dmg", f"{AD}*??.dmg")
iste_degistir(M, "rustdesk*-${{ matrix.job.arch }}.dmg", f"{AD}*-${{{{ matrix.job.arch }}}}.dmg")
# imzasiz dmg zaten mimari ekiyle uretilir; yeniden adlandirma dongusu eki ikilemesin
iste_degistir(M, "for name in AltunakarDesk*??.dmg; do\n",
              "for name in AltunakarDesk*??.dmg; do\n              case \"$name\" in *-${{ matrix.job.arch }}.dmg) continue ;; esac\n")

YML.write_text(s, encoding="utf-8")
print("derleme duzeni hazir")

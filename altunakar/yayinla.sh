#!/bin/bash
# Bir etiket derlemesini sitedeki sabit indirme baglantilarina baglar:
#   AltunakarDesk-Windows.exe / -Windows.msi / -Mac-Apple.dmg / -Mac-Intel.dmg
# adli kopyalari surume ekler ve surumu "tam surum + en son" yapar
# (GitHub /releases/latest/ on surumleri saymaz).
# Kullanim: altunakar/yayinla.sh 1.5.0-5
set -euo pipefail
ETIKET="$1"
DEPO=tunaegeyalcin-dev/altunakardesk
GECICI=$(mktemp -d)
trap 'rm -rf "$GECICI"' EXIT
# "desen hedef" ciftleri (macOS bash 3.2: iliskisel dizi yok)
CIFTLER="AltunakarDesk-*-x86_64.exe AltunakarDesk-Windows.exe
AltunakarDesk-*-x86_64.msi AltunakarDesk-Windows.msi
AltunakarDesk-*-aarch64.dmg AltunakarDesk-Mac-Apple.dmg
AltunakarDesk-*-x86_64.dmg AltunakarDesk-Mac-Intel.dmg"
echo "$CIFTLER" | while read -r desen hedef; do
  gh release download "$ETIKET" -R "$DEPO" -p "$desen" -D "$GECICI" --clobber
  kaynak=$(ls "$GECICI"/$desen | head -1)
  cp "$kaynak" "$GECICI/$hedef"
  gh release upload "$ETIKET" -R "$DEPO" "$GECICI/$hedef" --clobber
  echo "yuklendi: $hedef <- $(basename "$kaynak")"
done
# Imzali surum bildirimi: programlar guncellemeyi YALNIZ bu imza gecerse ve indirdikleri dosyanin
# SHA-256'si buradakiyle ayniysa kurar (libs/hbb_common/src/altunakar_guncelleme.rs).
# Ozel anahtar anahtar zincirinde; diske yalniz bu islem boyunca, yalniz sahibin okuyabildigi
# gecici dosyaya yazilir ve hemen silinir.
OPENSSL=/opt/homebrew/bin/openssl
ACIK_ANAHTAR="lkjbJ+eUO233PPPvfWTpzePqpuqvDlPu4iO3NDN8fa8="
python3 - "$ETIKET" "$GECICI" > "$GECICI/AltunakarDesk-surum.json" <<'PY_BILDIRIM'
import hashlib, json, os, sys
etiket, klasor = sys.argv[1], sys.argv[2]
adlar = ["AltunakarDesk-Windows.exe", "AltunakarDesk-Windows.msi",
         "AltunakarDesk-Mac-Apple.dmg", "AltunakarDesk-Mac-Intel.dmg"]
dosyalar = {}
for ad in adlar:
    h = hashlib.sha256()
    with open(os.path.join(klasor, ad), "rb") as f:
        for parca in iter(lambda: f.read(1 << 20), b""):
            h.update(parca)
    dosyalar[ad] = h.hexdigest()
sys.stdout.write(json.dumps({"etiket": etiket, "dosyalar": dosyalar}, separators=(",", ":")))
PY_BILDIRIM
(
  umask 077
  security find-generic-password -s altunakardesk-guncelleme-anahtar -a altunakardesk -w | base64 -d > "$GECICI/k.pem"
  gercek=$("$OPENSSL" pkey -in "$GECICI/k.pem" -pubout -outform DER | tail -c 32 | base64)
  if [ "$gercek" != "$ACIK_ANAHTAR" ]; then rm -f "$GECICI/k.pem"; echo "HATA: anahtar zincirindeki anahtar programdakiyle eslesmiyor" >&2; exit 1; fi
  "$OPENSSL" pkeyutl -sign -inkey "$GECICI/k.pem" -rawin -in "$GECICI/AltunakarDesk-surum.json" -out "$GECICI/imza.bin"
  rm -f "$GECICI/k.pem"
)
base64 < "$GECICI/imza.bin" | tr -d '\n' > "$GECICI/AltunakarDesk-surum.json.imza"
gh release upload "$ETIKET" -R "$DEPO" "$GECICI/AltunakarDesk-surum.json" "$GECICI/AltunakarDesk-surum.json.imza" --clobber
echo "yuklendi: imzali surum bildirimi ($(wc -c < "$GECICI/AltunakarDesk-surum.json") bayt)"
gh release edit "$ETIKET" -R "$DEPO" --prerelease=false --latest
for ad in AltunakarDesk-Windows.exe AltunakarDesk-Windows.msi AltunakarDesk-Mac-Apple.dmg AltunakarDesk-Mac-Intel.dmg AltunakarDesk-surum.json AltunakarDesk-surum.json.imza; do
  # GitHub depolamasi HEAD (-I) istegine 404 doner; ilk baytin GET'i dogru denetimdir (206/200).
  kod=$(curl -s -o /dev/null -w "%{http_code}" -L -r 0-0 "https://github.com/$DEPO/releases/latest/download/$ad")
  echo "$kod  $ad"
done

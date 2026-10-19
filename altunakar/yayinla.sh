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
gh release edit "$ETIKET" -R "$DEPO" --prerelease=false --latest
for ad in AltunakarDesk-Windows.exe AltunakarDesk-Windows.msi AltunakarDesk-Mac-Apple.dmg AltunakarDesk-Mac-Intel.dmg; do
  kod=$(curl -s -o /dev/null -w "%{http_code}" -L -I "https://github.com/$DEPO/releases/latest/download/$ad")
  echo "$kod  $ad"
done

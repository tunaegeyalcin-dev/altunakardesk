#!/bin/bash
# hbb_common testlerini GUVENLI calistirir.
# - RustDesk testleri Config::set ile GERCEK ayar dosyasina yazar (macOS:
#   ~/Library/Preferences/com.altunakar.AltunakarDesk). Bu yuzden HOME gecici klasore verilir;
#   yoksa bu makinedeki AltunakarDesk numarasi deneme numarasiyla (987654321) ezilir.
# - Paralel calismada (macOS) anahtar onbellegi yarisi bazi testleri rastgele dusurur; sirayla calistirilir.
set -euo pipefail
GERCEK_HOME="$HOME"
GECICI=$(mktemp -d)
trap 'rm -rf "$GECICI"' EXIT
cd "$(dirname "$0")/../libs/hbb_common"
env HOME="$GECICI" CARGO_HOME="${CARGO_HOME:-$GERCEK_HOME/.cargo}" RUSTUP_HOME="${RUSTUP_HOME:-$GERCEK_HOME/.rustup}" \
  PATH="$GERCEK_HOME/.cargo/bin:$PATH" cargo test --lib "$@" -- --test-threads=1

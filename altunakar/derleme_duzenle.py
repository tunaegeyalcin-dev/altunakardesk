#!/usr/bin/env python3
"""flutter-build.yml, bridge.yml ve Mac derleme dosyalarini AltunakarDesk icin duzenler.
Tekrar calistirmak zararsizdir; RustDesk guncellemesinde beklenen satir kaybolursa durur."""
import pathlib, re, sys

KOK = pathlib.Path(__file__).resolve().parent.parent
AD = "AltunakarDesk"

def dosya_degistir(yol, eski, yeni):
    p = KOK / yol
    s = p.read_text(encoding="utf-8")
    if yeni in s and (eski not in s or eski in yeni):  # daha once uygulanmis (ekleme de olabilir)
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
# Mac Intel paketi Apple islemcili kosucuda capraz derlenir (CARGO_BUILD_TARGET=x86_64-apple-darwin):
# cargo ciktisi target/<hedef>/release'e duser, sonraki adimlar target/release bekler
dosya_degistir("build.py",
               "    if not skip_cargo:\n"
               "        # set minimum osx build target, now is 10.14, which is the same as the flutter xcode project\n"
               "        system2(\n"
               "            f'MACOSX_DEPLOYMENT_TARGET=10.14 cargo build --locked --features {features} --release')\n",
               "    capraz = os.environ.get('CARGO_BUILD_TARGET', '')  # AltunakarDesk: Intel paketi capraz derleme\n"
               "    if not skip_cargo:\n"
               "        # set minimum osx build target, now is 10.14, which is the same as the flutter xcode project\n"
               "        system2(\n"
               "            f'MACOSX_DEPLOYMENT_TARGET=10.14 cargo build --locked --features {features} --release')\n"
               "        if capraz:\n"
               "            system2(f'mkdir -p target/release && cp target/{capraz}/release/liblibrustdesk.dylib '\n"
               "                    f'target/{capraz}/release/service target/release/')\n")
# etkin mimari (arm64) ARCHS'ta olmadigindan ONLY_ACTIVE_ARCH=YES iken x86_64 hic derlenmez
dosya_degistir("build.py",
               "    mac_arch = 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x86_64'\n"
               "    system2(\n"
               "        f'FLUTTER_XCODE_ARCHS={mac_arch} FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES flutter build macos --release')\n",
               "    mac_arch = 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x86_64'\n"
               "    tek_mimari = 'YES'\n"
               "    if capraz.startswith('x86_64'):\n"
               "        mac_arch, tek_mimari = 'x86_64', 'NO'\n"
               "    system2(\n"
               "        f'FLUTTER_XCODE_ARCHS={mac_arch} FLUTTER_XCODE_ONLY_ACTIVE_ARCH={tek_mimari} flutter build macos --release')\n")

# Gereksiz paketler (Tuna 10-19): Windows ARM ve Linux yok. Kalanlar: Windows x64 exe/msi, Mac Apple + Intel dmg.
def girdi_sil(govde, anahtar):
    """Matristen 'anahtar' satirini iceren '- {' ... '}' girdisini ustundeki yorumlarla birlikte siler."""
    satirlar = govde.split("\n")
    i = next((n for n, x in enumerate(satirlar) if x.strip() == anahtar), None)
    if i is None:
        return govde  # daha once silinmis
    bas = i
    while satirlar[bas].strip() != "- {":
        bas -= 1
    while satirlar[bas - 1].strip().startswith("#"):
        bas -= 1
    son = i
    while satirlar[son].strip() != "}":
        son += 1
    return "\n".join(satirlar[:bas] + satirlar[son + 1:])

KOPRU = KOK / ".github/workflows/bridge.yml"
KOPRU.write_text(girdi_sil(KOPRU.read_text(encoding="utf-8"), 'artifact-name: "bridge-artifact-flutter-3.44",'),
                 encoding="utf-8")

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
           "build-appimage", "build-flatpak", "build-rustdesk-web", "publish_unsigned",
           "build-rustdesk-linux"]:
    is_kapat(ad)

def matris_sil(ad, anahtar):
    global s
    a, b = is_araligi(ad)
    s = s[:a] + girdi_sil(s[a:b], anahtar) + s[b:]

matris_sil("build-for-windows-flutter", "target: aarch64-pc-windows-msvc,")
matris_sil("build-RustDeskTempTopMostWindow", "target: windows-11-arm,")

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
# Imza kimligi yoksa paket ad-hoc ve BUTUNUYLE imzalanir: aksi halde ana dosya ad-hoc, FlutterMacOS
# Google imzali kalir ve macOS "farkli Team ID" diyerek acilista durdurur (1.5.0-3'te goruldu).
DMG_SATIRI = ('          create-dmg --icon "AltunakarDesk.app" 200 190 --hide-extension "AltunakarDesk.app" '
              '--window-size 800 400 --app-drop-link 600 185 AltunakarDesk-${{ env.VERSION }}-${{ matrix.job.arch }}.dmg')
iste_degistir(M, DMG_SATIRI,
              "          codesign --force --deep --sign - ./flutter/build/macos/Build/Products/Release/AltunakarDesk.app\n"
              "          codesign --verify --deep --strict ./flutter/build/macos/Build/Products/Release/AltunakarDesk.app\n" + DMG_SATIRI)
# imzasiz dmg zaten mimari ekiyle uretilir; yeniden adlandirma dongusu eki ikilemesin
iste_degistir(M, "for name in AltunakarDesk*??.dmg; do\n",
              "for name in AltunakarDesk*??.dmg; do\n              case \"$name\" in *-${{ matrix.job.arch }}.dmg) continue ;; esac\n")
# Intel kosucu yavas (bagimliliklar 15-23 dk) ve 10-19'da 'Build rustdesk'te 2+ saat takildi (varsayilan sinir 6 sa).
# Intel paketi Apple islemcili kosucuda capraz derlenir; olagan sure ~35 dk.
iste_degistir(M, "    runs-on: ${{ matrix.job.os }}\n    needs: [generate-bridge]\n",
              "    runs-on: ${{ matrix.job.os }}\n    timeout-minutes: 120\n    needs: [generate-bridge]\n")
INTEL_ESKI = re.compile(r"^              os: macos-15-intel,.*$", re.M)
INTEL_YENI = "              os: macos-14, # Intel paketi de Apple islemcili kosucuda (capraz derleme; eski: macos-15-intel)"
a, b = is_araligi(M)
if INTEL_YENI not in s[a:b]:
    if not INTEL_ESKI.search(s[a:b]):
        sys.exit(f"{M}: macos-15-intel satiri bulunamadi")
    s = s[:a] + INTEL_ESKI.sub(INTEL_YENI, s[a:b], count=1) + s[b:]
# iki Mac isi ayni kosucu turunde: onbellek anahtari hedefe gore ayrilsin
iste_degistir(M, "          prefix-key: ${{ matrix.job.os }}\n",
              "          prefix-key: ${{ matrix.job.os }}\n          key: ${{ matrix.job.target }}\n")
# vcpkg yardimci araclari (host) x86_64 derlenir ve Rosetta ile calisir
iste_degistir(M, "          brew install llvm create-dmg\n",
              "          brew install llvm create-dmg\n"
              "          if [ \"$(uname -m)\" = arm64 ] && [ \"${{ matrix.job.arch }}\" = x86_64 ]; then\n"
              "            sudo softwareupdate --install-rosetta --agree-to-license || true\n"
              "            arch -x86_64 /usr/bin/true\n"
              "          fi\n")
# ffmpeg vcpkg.json'da yalniz "host" bagimliligi: hedef ve host uclusu ayni (x64-osx) olmazsa Intel pakete girmez
# (asagida env'e VCPKG_BINARY_SOURCES de eklenir; tekrar calismada bu yuzden satirin varligina bakilir)
if "          VCPKG_DEFAULT_TRIPLET: ${{ matrix.job.vcpkg-triplet }}\n" not in s[slice(*is_araligi(M))]:
    iste_degistir(M, "      - name: Install vcpkg dependencies\n        run: |\n",
                  "      - name: Install vcpkg dependencies\n"
                  "        env:\n"
                  "          VCPKG_DEFAULT_TRIPLET: ${{ matrix.job.vcpkg-triplet }}\n"
                  "          VCPKG_DEFAULT_HOST_TRIPLET: ${{ matrix.job.vcpkg-triplet }}\n"
                  "        run: |\n")
iste_degistir(M, "      - name: Build rustdesk\n        run: |\n",
              "      - name: Build rustdesk\n        run: |\n"
              "          if [ \"$(uname -m)\" = arm64 ] && [ \"${{ matrix.job.arch }}\" = x86_64 ]; then\n"
              "            export CARGO_BUILD_TARGET=x86_64-apple-darwin  # build.py ciktiyi target/release'e alir\n"
              "          fi\n")

# Onbellek (10-19): GitHub bir etiketin onbellegini baska etikete vermez, yalniz ayni ref ve varsayilan dal
# okunur. Onbellegi altunakar dalinda 'Onbellek isit' (altunakar-onbellek.yml) yazar; etiket derlemeleri
# yalniz okur, kaydetmez (yoksa etiket kapsaminda 2 GB'lik kayitlar 10 GB siniri doldurur).
KAYDET = "${{ github.ref_type == 'branch' }}"
iste_degistir(W, "          prefix-key: ${{ matrix.job.os }}\n",
              "          prefix-key: ${{ matrix.job.os }}\n          save-if: " + KAYDET + "\n")
iste_degistir(M, "          key: ${{ matrix.job.target }}\n",
              "          key: ${{ matrix.job.target }}\n          save-if: " + KAYDET + "\n")
dosya_degistir(".github/workflows/bridge.yml", "          prefix-key: bridge-${{ matrix.job.os }}\n",
               "          prefix-key: bridge-${{ matrix.job.os }}\n          save-if: " + KAYDET + "\n")

# vcpkg 'x-gha' ikili onbellegi vcpkg'den kaldirildi (ffmpeg/aom/libvpx her iste kaynaktan derleniyordu):
# 'files' saglayici + actions/cache. Yalniz yeni paket derlendiyse ve dal kosusundaysa kaydedilir; kayittan once
# bu derlemede kullanilmayan paketler silinir (eskiler birikmesin).
ONBELLEK = "actions/cache/{}@caa296126883cff596d87d8935842f9db880ef25 # v5.1.0"
VCPKG_DIZIN = "${{ runner.temp }}/vcpkg-ikili"
VCPKG_ONCE = (
    "      - name: Restore vcpkg binary cache\n"
    "        id: vcpkg-geri\n"
    "        uses: " + ONBELLEK.format("restore") + "\n"
    "        with:\n"
    "          path: " + VCPKG_DIZIN + "\n"
    "          key: vcpkg-${{ matrix.job.os }}-${{ matrix.job.vcpkg-triplet }}-${{ env.VCPKG_COMMIT_ID }}-${{ github.run_id }}\n"
    "          restore-keys: vcpkg-${{ matrix.job.os }}-${{ matrix.job.vcpkg-triplet }}-${{ env.VCPKG_COMMIT_ID }}-\n"
    "\n"
    "      - name: Count vcpkg binary cache\n"
    "        id: vcpkg-once\n"
    "        shell: bash\n"
    "        run: |\n"
    "          d=\"${RUNNER_TEMP//\\\\//}/vcpkg-ikili\"\n"
    "          mkdir -p \"$d\"\n"
    "          echo \"sayi=$(find \"$d\" -name '*.zip' | wc -l | tr -d ' ')\" >> \"$GITHUB_OUTPUT\"\n"
    "\n")
VCPKG_SONRA = (
    "      - name: Prepare vcpkg binary cache\n"
    "        id: vcpkg-ayikla\n"
    "        if: " + KAYDET + "\n"
    "        shell: bash\n"
    "        run: |\n"
    "          d=\"${RUNNER_TEMP//\\\\//}/vcpkg-ikili\"\n"
    "          once=${{ steps.vcpkg-once.outputs.sayi }}\n"
    "          sonra=$(find \"$d\" -name '*.zip' | wc -l | tr -d ' ')\n"
    "          echo \"vcpkg ikili onbellek: once $once, sonra $sonra paket\"\n"
    "          [ \"$sonra\" -gt \"$once\" ] || exit 0\n"
    "          tr -d '\\r' < \"$VCPKG_ROOT/installed/vcpkg/status\" | sed -n 's/^Abi: //p' | sort -u > \"$d.abi\"\n"
    "          if [ -s \"$d.abi\" ]; then\n"
    "            find \"$d\" -name '*.zip' | while read -r z; do\n"
    "              grep -qxF \"$(basename \"$z\" .zip)\" \"$d.abi\" || rm -f \"$z\"\n"
    "            done\n"
    "          fi\n"
    "          echo \"kaldi $(find \"$d\" -name '*.zip' | wc -l | tr -d ' ') paket\"\n"
    "          echo kaydet=true >> \"$GITHUB_OUTPUT\"\n"
    "\n"
    "      - name: Save vcpkg binary cache\n"
    "        if: steps.vcpkg-ayikla.outputs.kaydet == 'true'\n"
    "        uses: " + ONBELLEK.format("save") + "\n"
    "        with:\n"
    "          path: " + VCPKG_DIZIN + "\n"
    "          key: ${{ steps.vcpkg-geri.outputs.cache-primary-key }}\n"
    "\n")
KURULUM = "      - name: Install vcpkg dependencies\n"
for ad in (W, M):
    iste_degistir(ad, KURULUM + "        env:\n",
                  KURULUM + "        env:\n"
                  "          VCPKG_BINARY_SOURCES: clear;files," + VCPKG_DIZIN + ",readwrite\n")
    a, b = is_araligi(ad)
    govde = s[a:b]
    if "      - name: Restore vcpkg binary cache\n" not in govde:
        i = govde.index(KURULUM)
        j = i + re.search(r"^      - ", govde[i + 1:], re.M).start() + 1
        govde = govde[:i] + VCPKG_ONCE + govde[i:j] + VCPKG_SONRA + govde[j:]
        s = s[:a] + govde + s[b:]

YML.write_text(s, encoding="utf-8")
print("derleme duzeni hazir")

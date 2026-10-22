// Altunakar: adres defteri gorunumu (Asama 2, 2026-10-21 yeniden tasarim).
// Solda firmalar (firma = RustDesk etiketi; ekip defterinde), sagda secili
// firmanin cihaz tablosu: durum, ad, numara, Baglan / Dosya aktar / menu.
// Satira cift tik baglanir, sag tik RustDesk'in adres defteri menusunu acar
// (ad degistir, firmaya tasi, sifre, not, sil). Arama butun firmalarda
// kelime kelime arar ("fortan gizem"). Bos defterde, bos firmada ve sonucsuz
// aramada ne yapilacagini soyleyen ekran cikar. Kisisel defterde ayni gorunum
// "Gruplar" adiyla kullanilir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/altunakar_arama.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

String altunakarFirmaOf(Peer p) => p.tags.isEmpty ? '' : p.tags.first.toString();

String altunakarCihazAdi(Peer p) =>
    p.alias.isNotEmpty ? p.alias : (p.hostname.isNotEmpty ? p.hostname : p.id);

/// Ortak defterin aramada bakilan alanlari: numara, cihaz adi, bilgisayar,
/// kullanici, not, firma.
List<String> altunakarAramaAlanlari(Peer p) =>
    [p.id, p.alias, p.hostname, p.username, p.note, ...p.tags.map((e) => e.toString())];

bool _ekipDefteri() => gFFI.abModel.currentName.value == kAltunakarEkipDefteri;

String _metin(String ekip, String kisisel) => translate(_ekipDefteri() ? ekip : kisisel);

class AltunakarDefterGorunumu extends StatefulWidget {
  final VoidCallback cihazEkle;
  final VoidCallback firmaEkle;
  final Widget defterSecici;
  final Widget yetki;

  const AltunakarDefterGorunumu(
      {Key? key,
      required this.cihazEkle,
      required this.firmaEkle,
      required this.defterSecici,
      required this.yetki})
      : super(key: key);

  @override
  State<AltunakarDefterGorunumu> createState() => _AltunakarDefterGorunumuState();
}

class _AltunakarDefterGorunumuState extends State<AltunakarDefterGorunumu> {
  Timer? _zamanlayici;
  // Arama yerel: genel peerSearchText kullanilsaydi defterde yazilan arama
  // ust cubugu gizli oldugu icin gorunmeden Son baglantilar sekmesini suzerdi.
  final _arama = TextEditingController();
  final _aramaMetni = ''.obs;

  @override
  void initState() {
    super.initState();
    _cevrimiciSor();
    _zamanlayici = Timer.periodic(const Duration(seconds: 30), (_) => _cevrimiciSor());
    gFFI.abModel.peersModel.addListener(_yenile);
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    gFFI.abModel.peersModel.removeListener(_yenile);
    _arama.dispose();
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  // RustDesk yalniz ekranda gorunen kartlarin cevrimici durumunu sorar; firma
  // sayilari icin defterin TAMAMI 30 sn'de bir merkeze sorulur.
  void _cevrimiciSor() {
    final ids = gFFI.abModel.currentAbPeers.map((p) => p.id).toList();
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  /// '' = tum cihazlar, kUntagged = firmasiz, digeri firma adi.
  String get _secili {
    final s = gFFI.abModel.selectedTags;
    return s.length == 1 ? s.first.toString() : '';
  }

  void _sec(String ad) {
    final s = gFFI.abModel.selectedTags;
    s.clear();
    if (ad.isNotEmpty) s.add(ad);
  }

  void _aramayiTemizle() {
    _arama.clear();
    _aramaMetni.value = '';
  }

  static bool _firmada(Peer p, String ad) =>
      ad == kUntagged ? p.tags.isEmpty : p.tags.any((t) => t.toString() == ad);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final arama = _aramaMetni.value.trim();
      final peers = gFFI.abModel.currentAbPeers.toList();
      final firmalar = gFFI.abModel.currentAbTags.map((e) => e.toString()).toList()
        ..sort((a, b) => altunakarKatla(a).compareTo(altunakarKatla(b)));
      var secili = _secili;
      if (secili.isNotEmpty && secili != kUntagged && !firmalar.contains(secili)) secili = '';
      final List<Peer> liste;
      if (arama.isNotEmpty) {
        liste = peers.where((p) => altunakarAramaEslesir(arama, altunakarAramaAlanlari(p))).toList();
      } else if (secili.isEmpty) {
        liste = peers;
      } else {
        liste = peers.where((p) => _firmada(p, secili)).toList();
      }
      liste.sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return altunakarKatla(altunakarCihazAdi(a)).compareTo(altunakarKatla(altunakarCihazAdi(b)));
      });
      final duzenlenir = gFFI.abModel.current.canWrite();
      final sol = _solPanel(context, peers, firmalar, secili, arama.isNotEmpty, duzenlenir);
      final ana = _anaAlan(context, liste, peers.isEmpty, secili, arama, duzenlenir);
      final kenar = Theme.of(context).dividerColor.withOpacity(0.12);
      final kart = BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kenar),
      );
      if (stateGlobal.isPortrait.isTrue) {
        return Container(
          decoration: kart,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            widget.defterSecici.marginSymmetric(horizontal: 12),
            _firmaSeridi(context, peers, firmalar, secili),
            Divider(height: 1, color: kenar),
            Expanded(child: ana),
          ]),
        );
      }
      return Container(
        decoration: kart,
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          SizedBox(width: 240, child: sol),
          VerticalDivider(width: 1, color: kenar),
          Expanded(child: ana),
        ]),
      );
    });
  }

  // ---------------------------------------------------------------- sol panel

  Widget _solPanel(BuildContext context, List<Peer> peers, List<String> firmalar, String secili,
      bool aramaVar, bool duzenlenir) {
    final ipucu = Theme.of(context).hintColor;
    final firmasiz = peers.where((p) => p.tags.isEmpty).toList();
    final kenar = Theme.of(context).dividerColor.withOpacity(0.12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.defterSecici.marginSymmetric(horizontal: 12),
        Divider(height: 1, color: kenar),
        Row(children: [
          Text(_metin('altunakar_firmalar', 'altunakar_gruplar'),
              style: TextStyle(fontSize: 12, color: ipucu, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('${firmalar.length}', style: TextStyle(fontSize: 12, color: ipucu)),
        ]).paddingOnly(left: 16, top: 12, right: 16, bottom: 6),
        _firmaSatiri(context,
            ad: '',
            baslik: translate('altunakar_tum_cihazlar'),
            ikon: Icons.view_list_rounded,
            cihazlar: peers,
            secili: secili.isEmpty && !aramaVar,
            duzenlenir: false),
        Expanded(
          child: firmalar.isEmpty
              ? _bosFirmalar(context, duzenlenir)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: firmalar.length,
                  itemBuilder: (context, i) {
                    final f = firmalar[i];
                    return _firmaSatiri(context,
                        ad: f,
                        baslik: f,
                        cihazlar: peers.where((p) => _firmada(p, f)).toList(),
                        secili: secili == f && !aramaVar,
                        duzenlenir: duzenlenir);
                  }),
        ),
        if (firmasiz.isNotEmpty) ...[
          Divider(height: 1, color: kenar),
          _firmaSatiri(context,
              ad: kUntagged,
              baslik: _metin('altunakar_firmasiz', 'altunakar_grupsuz'),
              ikon: Icons.help_outline_rounded,
              cihazlar: firmasiz,
              secili: secili == kUntagged && !aramaVar,
              duzenlenir: false),
        ],
        widget.yetki.paddingOnly(right: 12, bottom: 6),
      ],
    );
  }

  Widget _bosFirmalar(BuildContext context, bool duzenlenir) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_metin('altunakar_bos_firmalar', 'altunakar_bos_gruplar'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
        if (duzenlenir)
          TextButton.icon(
            onPressed: widget.firmaEkle,
            icon: const Icon(Icons.add, size: 16),
            label: Text(_metin('altunakar_firma_ekle', 'altunakar_grup_ekle')),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
      ],
    ).paddingOnly(left: 16, top: 10, right: 16);
  }

  Widget _firmaSatiri(BuildContext context,
      {required String ad,
      required String baslik,
      IconData? ikon,
      required List<Peer> cihazlar,
      required bool secili,
      required bool duzenlenir}) {
    final vurgu = Theme.of(context).colorScheme.primary;
    final ipucu = Theme.of(context).hintColor;
    final acik = cihazlar.where((p) => p.online).length;
    var konum = RelativeRect.fill;
    void konumAl(TapDownDetails e) {
      final x = e.globalPosition.dx, y = e.globalPosition.dy;
      konum = RelativeRect.fromLTRB(x, y, x, y);
    }

    final renk = ad.isEmpty || ad == kUntagged ? ipucu : gFFI.abModel.getCurrentAbTagColor(ad);
    final rozet = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: renk.withOpacity(0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: ikon != null
          ? Icon(ikon, size: 16, color: renk)
          : Text(_basHarfler(baslik),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: renk)),
    );
    return Material(
      color: secili ? vurgu.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _aramayiTemizle();
          _sec(ad);
        },
        onTapDown: duzenlenir ? konumAl : null,
        onSecondaryTapDown: duzenlenir ? konumAl : null,
        onSecondaryTap: duzenlenir ? () => altunakarFirmaMenusu(context, ad, konum) : null,
        onLongPress: duzenlenir ? () => altunakarFirmaMenusu(context, ad, konum) : null,
        child: Row(children: [
          rozet,
          const SizedBox(width: 10),
          Expanded(
            child: Text(baslik,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    color: secili ? vurgu : null,
                    fontWeight: secili ? FontWeight.w600 : FontWeight.normal)),
          ),
          if (acik > 0)
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ).marginOnly(right: 5),
          Text('$acik/${cihazlar.length}', style: TextStyle(fontSize: 12, color: ipucu)),
        ]).paddingSymmetric(horizontal: 10, vertical: 7),
      ),
    ).marginSymmetric(horizontal: 8, vertical: 1);
  }

  static String _basHarfler(String ad) {
    final parca = ad.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parca.isEmpty) return '?';
    final h = parca.length == 1
        ? parca.first.characters.take(2).toString()
        : parca.take(2).map((s) => s.characters.first).join();
    return h.toUpperCase();
  }

  // Dik ekranda firmalar yatay serit olur.
  Widget _firmaSeridi(BuildContext context, List<Peer> peers, List<String> firmalar, String secili) {
    final secenekler = <MapEntry<String, String>>[
      MapEntry('', translate('altunakar_tum_cihazlar')),
      ...firmalar.map((f) => MapEntry(f, f)),
      if (peers.any((p) => p.tags.isEmpty))
        MapEntry(kUntagged, _metin('altunakar_firmasiz', 'altunakar_grupsuz')),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (final s in secenekler)
            ChoiceChip(
              label: Text(s.value),
              selected: secili == s.key,
              onSelected: (_) {
                _aramayiTemizle();
                _sec(s.key);
              },
            ).marginSymmetric(horizontal: 3),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- ana alan

  Widget _anaAlan(BuildContext context, List<Peer> liste, bool defterBos, String secili,
      String arama, bool duzenlenir) {
    final ipucu = Theme.of(context).hintColor;
    final kenar = Theme.of(context).dividerColor.withOpacity(0.12);
    final String baslik;
    if (arama.isNotEmpty) {
      baslik = translate('altunakar_arama_sonucu').replaceAll('{q}', arama);
    } else if (secili.isEmpty) {
      baslik = translate('altunakar_tum_cihazlar');
    } else if (secili == kUntagged) {
      baslik = _metin('altunakar_firmasiz', 'altunakar_grupsuz');
    } else {
      baslik = secili;
    }
    final acik = liste.where((p) => p.online).length;
    final sayi = translate('altunakar_cihaz_sayisi')
        .replaceAll('{n}', '${liste.length}')
        .replaceAll('{m}', '$acik');
    final firmaSecili = arama.isEmpty && secili.isNotEmpty && secili != kUntagged;
    var konum = RelativeRect.fill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ustCubuk(context, duzenlenir),
        Divider(height: 1, color: kenar),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sayi, style: TextStyle(fontSize: 12, color: ipucu)),
            ]),
          ),
          if (arama.isNotEmpty)
            TextButton(onPressed: _aramayiTemizle, child: Text(translate('altunakar_aramayi_temizle'))),
          if (firmaSecili && duzenlenir)
            Tooltip(
              message: _metin('altunakar_firmayi_duzenle', 'altunakar_grubu_duzenle'),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTapDown: (e) {
                  final x = e.globalPosition.dx, y = e.globalPosition.dy;
                  konum = RelativeRect.fromLTRB(x, y, x, y);
                },
                onTap: () => altunakarFirmaMenusu(context, secili, konum),
                child: Icon(Icons.edit_outlined, size: 18, color: ipucu).paddingAll(6),
              ),
            ),
        ]).paddingOnly(left: 18, top: 12, right: 12, bottom: 10),
        if (liste.isNotEmpty) ...[
          _sutunBasliklari(context),
          Divider(height: 1, color: kenar),
          Expanded(
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: kenar),
              itemBuilder: (context, i) => _CihazSatiri(
                  peer: liste[i], firmaGoster: secili.isEmpty || arama.isNotEmpty),
            ),
          ),
          Divider(height: 1, color: kenar),
          Text(translate('altunakar_ipucu_satir'), style: TextStyle(fontSize: 11.5, color: ipucu))
              .paddingSymmetric(horizontal: 18, vertical: 7),
        ] else
          Expanded(child: _bosEkran(context, defterBos, firmaSecili, arama.isNotEmpty, duzenlenir)),
      ],
    );
  }

  Widget _ustCubuk(BuildContext context, bool duzenlenir) {
    final ipucu = Theme.of(context).hintColor;
    final arama = SizedBox(
      height: 36,
      child: TextField(
        controller: _arama,
        onChanged: (v) => _aramaMetni.value = v,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: _metin('altunakar_ara_ipucu', 'altunakar_ara_ipucu_kisisel'),
          hintStyle: TextStyle(fontSize: 13, color: ipucu),
          prefixIcon: Icon(Icons.search, size: 18, color: ipucu),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: _arama.text.isEmpty
              ? null
              : InkWell(onTap: _aramayiTemizle, child: Icon(Icons.close, size: 16, color: ipucu)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ).workaroundFreezeLinuxMint(),
    );
    if (!duzenlenir) return arama.paddingSymmetric(horizontal: 14, vertical: 10);
    // Düğmeler arama kutusuyla aynı boyda, sayfanın öbür düğmeleriyle aynı yazıda (tema
    // varsayılanı belirgin büyük kalıyordu). Dar alanda yalnız simge kalır; arama kutusu
    // tek simgeye inmesin.
    const yazi = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
    final kose = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final firmaAdi = _metin('altunakar_firma_ekle', 'altunakar_grup_ekle');
    final cihazAdi = translate('altunakar_cihaz_ekle');
    return LayoutBuilder(builder: (context, c) {
      final dar = c.maxWidth < 520;
      final firma = dar
          ? OutlinedButton(
              onPressed: widget.firmaEkle,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(36, 36), padding: EdgeInsets.zero, shape: kose),
              child: const Icon(Icons.business_outlined, size: 17),
            )
          : OutlinedButton.icon(
              onPressed: widget.firmaEkle,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: kose,
                  textStyle: yazi),
              icon: const Icon(Icons.business_outlined, size: 16),
              label: Text(firmaAdi),
            );
      final cihaz = dar
          ? ElevatedButton(
              onPressed: widget.cihazEkle,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(36, 36), padding: EdgeInsets.zero, shape: kose),
              child: const Icon(Icons.add, size: 18),
            )
          : ElevatedButton.icon(
              onPressed: widget.cihazEkle,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: kose,
                  textStyle: yazi),
              icon: const Icon(Icons.add, size: 18),
              label: Text(cihazAdi),
            );
      return Row(children: [
        Expanded(child: arama),
        const SizedBox(width: 10),
        SizedBox(height: 36, child: dar ? Tooltip(message: firmaAdi, child: firma) : firma),
        const SizedBox(width: 8),
        SizedBox(height: 36, child: dar ? Tooltip(message: cihazAdi, child: cihaz) : cihaz),
      ]);
    }).paddingSymmetric(horizontal: 14, vertical: 10);
  }

  Widget _sutunBasliklari(BuildContext context) {
    final s = TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor, fontWeight: FontWeight.w500);
    return Row(children: [
      const SizedBox(width: 22),
      Expanded(child: Text(translate('altunakar_sutun_cihaz'), style: s)),
      SizedBox(width: _CihazSatiri.numaraGenisligi, child: Text(translate('ID'), style: s)),
      SizedBox(width: _CihazSatiri.durumGenisligi, child: Text(translate('altunakar_sutun_durum'), style: s)),
      const SizedBox(width: _CihazSatiri.islemGenisligi),
    ]).paddingSymmetric(horizontal: 18, vertical: 6);
  }

  Widget _bosEkran(BuildContext context, bool defterBos, bool firmaSecili, bool aramaVar, bool duzenlenir) {
    final String baslik, metin;
    IconData ikon = Icons.devices_other_outlined;
    if (aramaVar) {
      ikon = Icons.search_off_rounded;
      baslik = translate('altunakar_bos_arama_baslik');
      metin = translate('altunakar_bos_arama_metin');
    } else if (defterBos) {
      baslik = _metin('altunakar_bos_defter_baslik', 'altunakar_bos_kisisel_baslik');
      metin = _metin('altunakar_bos_defter_metin', 'altunakar_bos_kisisel_metin');
    } else {
      baslik = _metin('altunakar_bos_firma_baslik', 'altunakar_bos_grup_baslik');
      metin = translate('altunakar_bos_firma_metin');
    }
    // Alan kısaysa ortalı kalır ama kayar; düğme ve açıklama kesilmesin.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(child: _bosEkranIcerik(context, ikon, baslik, metin, aramaVar, duzenlenir)),
        ),
      ),
    );
  }

  Widget _bosEkranIcerik(BuildContext context, IconData ikon, String baslik, String metin,
      bool aramaVar, bool duzenlenir) {
    final ipucu = Theme.of(context).hintColor;
    const yazi = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
    final kose = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(ikon, size: 26, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 14),
        Text(baslik,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(metin, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ipucu, height: 1.4)),
        const SizedBox(height: 16),
        if (aramaVar)
          OutlinedButton(
              onPressed: _aramayiTemizle,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), shape: kose, textStyle: yazi),
              child: Text(translate('altunakar_aramayi_temizle')))
        else if (duzenlenir)
          ElevatedButton.icon(
            onPressed: widget.cihazEkle,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), shape: kose, textStyle: yazi),
            icon: const Icon(Icons.add, size: 18),
            label: Text(translate('altunakar_cihaz_ekle')),
          ),
      ]).paddingAll(24),
    );
  }
}

class _CihazSatiri extends StatefulWidget {
  static const double numaraGenisligi = 118;
  static const double durumGenisligi = 92;
  static const double islemGenisligi = 166;

  final Peer peer;
  final bool firmaGoster;

  const _CihazSatiri({required this.peer, required this.firmaGoster});

  @override
  State<_CihazSatiri> createState() => _CihazSatiriState();
}

class _CihazSatiriState extends State<_CihazSatiri> {
  var _konum = RelativeRect.fill;
  var _uzerinde = false;

  void _konumAl(Offset o) => _konum = RelativeRect.fromLTRB(o.dx, o.dy, o.dx, o.dy);

  void _menu() => altunakarCihazMenusu(context, widget.peer, _konum);

  @override
  Widget build(BuildContext context) {
    final p = widget.peer;
    final ipucu = Theme.of(context).hintColor;
    final altBilgi = [
      if (widget.firmaGoster && p.tags.isNotEmpty) altunakarFirmaOf(p),
      if (p.platform.isNotEmpty) p.platform,
      if (p.hostname.isNotEmpty && p.hostname != altunakarCihazAdi(p)) p.hostname,
      if (p.username.isNotEmpty) p.username,
    ].join(' · ');
    return MouseRegion(
      onEnter: (_) => setState(() => _uzerinde = true),
      onExit: (_) => setState(() => _uzerinde = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => connectInPeerTab(context, p, PeerTabIndex.ab),
        onSecondaryTapDown: (e) => _konumAl(e.globalPosition),
        onSecondaryTap: _menu,
        onLongPressStart: (e) {
          _konumAl(e.globalPosition);
          _menu();
        },
        child: Container(
          color: _uzerinde ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(children: [
            Tooltip(
              message: translate(p.online ? 'altunakar_cevrimici' : 'altunakar_kapali'),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: p.online ? Colors.green : ipucu.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ).marginOnly(right: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(altunakarCihazAdi(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                if (altBilgi.isNotEmpty)
                  Text(altBilgi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: ipucu)),
              ]),
            ),
            SizedBox(
              width: _CihazSatiri.numaraGenisligi,
              child: SelectableText(formatID(p.id),
                  maxLines: 1, style: TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: ipucu)),
            ),
            SizedBox(
              width: _CihazSatiri.durumGenisligi,
              child: Text(translate(p.online ? 'altunakar_cevrimici' : 'altunakar_kapali'),
                  style: TextStyle(fontSize: 12, color: p.online ? Colors.green : ipucu)),
            ),
            SizedBox(
              width: _CihazSatiri.islemGenisligi,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => connectInPeerTab(context, p, PeerTabIndex.ab),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(translate('Connect')),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: translate('Transfer file'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: () => connectInPeerTab(context, p, PeerTabIndex.ab, isFileTransfer: true),
                ),
                Listener(
                  onPointerDown: (e) => _konumAl(e.position),
                  child: IconButton(
                    tooltip: translate('altunakar_diger_islemler'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: const Icon(Icons.more_horiz),
                    onPressed: _menu,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

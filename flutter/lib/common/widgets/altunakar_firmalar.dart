// Altunakar: ortak defterin sol paneli (Asama 2). Firmalar acilir-kapanir;
// basliginda "cevrimici/toplam"; acilan firmanin altinda cihazlar (cift tik:
// baglan). Firma basligina tiklamak sagdaki listeyi o firmaya suzer; sag tik
// RustDesk'in etiket menusu (yeniden adlandir, renk, sil). Arama kutusu
// doluysa yalniz eslesen cihazi olan firmalar gorunur ve kendiliginden acilir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/altunakar_arama.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

String altunakarFirmaOf(Peer p) => p.tags.isEmpty ? '' : p.tags.first.toString();

String altunakarCihazAdi(Peer p) =>
    p.alias.isNotEmpty ? p.alias : (p.hostname.isNotEmpty ? p.hostname : p.id);

/// Ortak defterin aramada bakilan alanlari: numara, cihaz adi, bilgisayar,
/// kullanici, not, firma.
List<String> altunakarAramaAlanlari(Peer p) =>
    [p.id, p.alias, p.hostname, p.username, p.note, ...p.tags.map((e) => e.toString())];

class AltunakarFirmaListesi extends StatefulWidget {
  const AltunakarFirmaListesi({Key? key}) : super(key: key);

  @override
  State<AltunakarFirmaListesi> createState() => _AltunakarFirmaListesiState();
}

class _AltunakarFirmaListesiState extends State<AltunakarFirmaListesi> {
  Timer? _zamanlayici;
  final _acik = <String>{};

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
    super.dispose();
  }

  void _yenile() {
    if (mounted) setState(() {});
  }

  // RustDesk yalniz ekranda gorunen kartlarin cevrimici durumunu sorar; kapali
  // firmalarin sayilari icin defterin TAMAMI 30 sn'de bir merkeze sorulur.
  void _cevrimiciSor() {
    final ids = gFFI.abModel.currentAbPeers.map((p) => p.id).toList();
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  void _firmaSec(String ad) {
    final secili = gFFI.abModel.selectedTags;
    final etiket = ad.isEmpty ? kUntagged : ad;
    final zatenSecili = secili.length == 1 && secili.first == etiket;
    secili.clear();
    if (!zatenSecili) secili.add(etiket);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final arama = peerSearchText.value.trim();
      final peers = gFFI.abModel.currentAbPeers.toList();
      var gruplar = firmalaraGore<Peer>(peers, gFFI.abModel.currentAbTags.toList(),
          firmaOf: altunakarFirmaOf, adOf: altunakarCihazAdi, cevrimiciMi: (p) => p.online);
      if (arama.isNotEmpty) {
        gruplar = gruplar.where((g) {
          g.cihazlar.retainWhere((p) => altunakarAramaEslesir(arama, altunakarAramaAlanlari(p)));
          g.cevrimici = g.cihazlar.where((p) => p.online).length;
          return g.cihazlar.isNotEmpty;
        }).toList();
      }
      final secili = gFFI.abModel.selectedTags.toList();
      final duzenlenir = gFFI.abModel.current.canWrite();
      final cevrimici = peers.where((p) => p.online).length;
      return ListView(
        children: [
          ListTile(
            dense: true,
            selected: secili.isEmpty,
            title: Text(translate('altunakar_tum_firmalar')),
            trailing: Text('$cevrimici/${peers.length}'),
            onTap: () => gFFI.abModel.selectedTags.clear(),
          ),
          for (final g in gruplar) ..._firma(context, g, secili, duzenlenir, arama.isNotEmpty),
        ],
      );
    });
  }

  List<Widget> _firma(BuildContext context, FirmaGrubu<Peer> g, List<dynamic> secili,
      bool duzenlenir, bool aramaVar) {
    final acik = aramaVar || _acik.contains(g.ad);
    return [
      Row(
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(acik ? Icons.expand_more : Icons.chevron_right),
            onPressed: () => setState(() => acik ? _acik.remove(g.ad) : _acik.add(g.ad)),
          ),
          Expanded(
            child: g.ad.isEmpty
                ? InkWell(
                    onTap: () => _firmaSec(''),
                    child: Text(translate('Untagged'), overflow: TextOverflow.ellipsis))
                : AddressBookTag(
                    name: g.ad,
                    tags: gFFI.abModel.selectedTags,
                    onTap: () => _firmaSec(g.ad),
                    showActionMenu: duzenlenir),
          ),
          Text('${g.cevrimici}/${g.cihazlar.length}',
                  style: TextStyle(
                      fontSize: 12,
                      color: g.cevrimici > 0 ? Colors.green : Theme.of(context).hintColor))
              .marginOnly(left: 4, right: 8),
        ],
      ),
      if (acik)
        for (final p in g.cihazlar)
          GestureDetector(
            onDoubleTap: () => connectInPeerTab(context, p, PeerTabIndex.ab),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.only(left: 40, right: 8),
              leading: Icon(Icons.circle, size: 10, color: p.online ? Colors.green : Colors.grey),
              minLeadingWidth: 10,
              title: Text(altunakarCihazAdi(p), overflow: TextOverflow.ellipsis),
              subtitle: Text(p.id, style: const TextStyle(fontSize: 11)),
            ),
          ),
    ];
  }
}

// Ücretsiz mod tanıtım beklemesi (spec 2026-10-23): 5 dakikalık ücretsiz
// bağlantı dolduktan sonra yeni bağlantı isteği HEMEN verilebilir, ama önce
// 5 dakikalık bekleme ekranı çalışır. Ekranda Altunakar tanıtım görseli
// (siteden indirilen döngülü WebP; inmemişse markalı sayaç) ve geri sayım
// gösterilir; süre bitince bekleyen bağlantı kendiliğinden kurulur.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common.dart';
import '../utils/http_service.dart' as http;
import 'altunakar_lisans.dart';

const String _kTanitimAdresi =
    'https://www.altunakar.net/img/altunakardesk/bekleme.webp';

File? _gorselOnbellek;
bool _gorselDenendi = false;

/// Tanıtım görselini bir kez indirir ve geçici klasörde saklar; inmezse null
/// (bekleme ekranı görselsiz, sayaçla çalışır).
Future<File?> _tanitimGorseli() async {
  if (_gorselDenendi) return _gorselOnbellek;
  _gorselDenendi = true;
  try {
    final f = File('${Directory.systemTemp.path}/altunakardesk-bekleme.webp');
    if (!await f.exists() || await f.length() == 0) {
      final r = await http
          .get(Uri.parse(_kTanitimAdresi))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      await f.writeAsBytes(r.bodyBytes);
    }
    _gorselOnbellek = f;
  } catch (_) {}
  return _gorselOnbellek;
}

/// Uzak masaüstü bağlantısından önce çağrılır: bekleme yoksa (ya da lisans
/// varsa) [devam] hemen çalışır; varsa bekleme ekranı gösterilir ve süre
/// bitince [devam] kendiliğinden çağrılır. Vazgeçilirse bağlantı kurulmaz.
void altunakarBeklemeKapisi(VoidCallback devam) {
  if (altunakarLisansli() || altunakarBeklemeKalanSn() == 0) {
    devam();
    return;
  }
  Timer? sayac;
  gFFI.dialogManager.show((setState, close, context) {
    sayac ??= Timer.periodic(const Duration(seconds: 1), (t) {
      if (altunakarBeklemeKalanSn() <= 0) {
        t.cancel();
        close();
        devam();
      } else {
        setState(() {});
      }
    });
    kapat() {
      sayac?.cancel();
      close();
    }

    final kalan = altunakarBeklemeKalanSn();
    final mmss =
        '${(kalan ~/ 60).toString().padLeft(2, '0')}:${(kalan % 60).toString().padLeft(2, '0')}';
    return CustomAlertDialog(
      title: Text(translate('altunakar-bekleme-baslik')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<File?>(
              future: _tanitimGorseli(),
              builder: (c, s) => s.data == null
                  ? const Offstage()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      // Tanıtım dikey (9:16): yüksekliği sınırla, enine sığdır.
                      child: Image.file(s.data!,
                          height: 340,
                          fit: BoxFit.contain,
                          gaplessPlayback: true),
                    ).marginOnly(bottom: 12),
            ),
            Text(translate('altunakar-bekleme-aciklama'),
                textAlign: TextAlign.center),
            Text(mmss,
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]))
                .marginOnly(top: 8),
            TextButton(
              onPressed: () => launchUrl(
                  Uri.parse(
                      'https://www.altunakar.net/uzak-destek/fiyatlandirma'),
                  mode: LaunchMode.externalApplication),
              child: Text(translate('altunakar-fiyat-baglanti')),
            ).marginOnly(top: 4),
          ],
        ),
      ),
      actions: [
        dialogButton('Cancel', onPressed: kapat, isOutline: true),
      ],
      onCancel: kapat,
    );
  });
}

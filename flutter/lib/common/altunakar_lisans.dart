// AltunakarDesk abonelik/lisans yardımcıları (spec 2026-10-23, Bina deposu
// docs/superpowers/specs/2026-10-23-altunakardesk-lisans.md).
//
// Durum TEK kaynaktan okunur: Rust LocalConfig'teki imzalı belge
// (bind.mainAltunakarLisansDurum). Ayrı penceredeki Dart motorları da aynı
// çağrıyı yapar; Dart tarafında durum tutulmaz. Ücretsiz modda GİDEN uzak
// masaüstü bağlantısı 5 dakikada kesilir; hemen yeni istek verilebilir ama
// önce 5 dakikalık tanıtım beklemesi çalışır (bekleme bitişi LocalConfig'te).
import 'dart:convert';
import 'dart:io';

import '../models/platform_model.dart';
import '../utils/http_service.dart' as http;

const String kAltunakarLisansAnahtar = 'altunakar-lisans-anahtar';
const String kAltunakarLisansBelge = 'altunakar-lisans-belge';
const String kAltunakarLisansOzet = 'altunakar-lisans-ozet';
const String kAltunakarBeklemeBitis = 'altunakar-bekleme-bitis';
const int kAltunakarUcretsizSn = 300; // ücretsiz bağlantı süresi (5 dk)
const int kAltunakarBeklemeSn = 300; // tanıtım beklemesi (5 dk)

int _simdiSn() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// İmzalı belgeden lisans durumu: {'durum':'yok'} ya da
/// {'durum':'etkin|esneme','firma','paket','koltuk','son','bitis','kalan_gun'}.
Map<String, dynamic> altunakarLisansDurum() {
  try {
    final m = jsonDecode(bind.mainAltunakarLisansDurum());
    if (m is Map<String, dynamic>) return m;
  } catch (_) {}
  return {'durum': 'yok'};
}

bool altunakarLisansli() => altunakarLisansDurum()['durum'] != 'yok';

Future<Map<String, dynamic>> _lisansIstegi(String anahtar) async {
  final url = await bind.mainGetApiServer();
  final resp = await http
      .post(Uri.parse('$url/api/altunakar/lisans/dogrula'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'anahtar': anahtar,
            'no': await bind.mainGetMyId(),
            'ad': Platform.localHostname,
            'platform': Platform.operatingSystem,
          }))
      .timeout(const Duration(seconds: 15));
  Map<String, dynamic> govde = {};
  try {
    final m = jsonDecode(utf8.decode(resp.bodyBytes));
    if (m is Map<String, dynamic>) govde = m;
  } catch (_) {}
  govde['_kod'] = resp.statusCode;
  return govde;
}

Future<void> _lisansYaz(String anahtar, Map<String, dynamic> govde) async {
  await bind.mainSetLocalOption(
      key: kAltunakarLisansAnahtar, value: anahtar.trim());
  await bind.mainSetLocalOption(
      key: kAltunakarLisansBelge, value: govde['belge'] as String);
  final ozet = Map<String, dynamic>.from(govde)
    ..remove('belge')
    ..remove('_kod');
  await bind.mainSetLocalOption(
      key: kAltunakarLisansOzet, value: jsonEncode(ozet));
}

/// Anahtarı sunucuda doğrular ve yerel kayıtları yazar. Hata durumunda
/// sunucunun Türkçe iletisini (ya da genel ağ iletisini) fırlatır.
Future<Map<String, dynamic>> altunakarLisansDogrula(String anahtar) async {
  final govde = await _lisansIstegi(anahtar);
  if (govde['_kod'] == 200 && govde['belge'] is String) {
    await _lisansYaz(anahtar, govde);
    return govde;
  }
  throw (govde['error'] ?? 'Sunucuya ulaşılamadı; bağlantınızı denetleyin')
      .toString();
}

/// Açılışta ve 12 saatte bir: kayıtlı anahtar varsa belgeyi tazeler.
/// Sunucu anahtarı reddederse (yenilendi, cihaz düşürüldü, lisans kapandı)
/// yerel kayıt silinir; ağ hatasında dokunulmaz (belge 7 gün çevrimdışı yeter).
Future<void> altunakarLisansTazele() async {
  final anahtar = bind.mainGetLocalOption(key: kAltunakarLisansAnahtar);
  if (anahtar.isEmpty) return;
  try {
    final govde = await _lisansIstegi(anahtar);
    if (govde['_kod'] == 200 && govde['belge'] is String) {
      await _lisansYaz(anahtar, govde);
    } else if (govde['_kod'] == 403) {
      await altunakarLisansKaldir();
    }
  } catch (_) {}
}

Future<void> altunakarLisansKaldir() async {
  for (final k in [
    kAltunakarLisansAnahtar,
    kAltunakarLisansBelge,
    kAltunakarLisansOzet
  ]) {
    await bind.mainSetLocalOption(key: k, value: '');
  }
}

/// Tanıtım beklemesinden kalan saniye (0: bekleme yok).
int altunakarBeklemeKalanSn() {
  final bitis =
      int.tryParse(bind.mainGetLocalOption(key: kAltunakarBeklemeBitis)) ?? 0;
  final kalan = bitis - _simdiSn();
  return kalan > 0 ? kalan : 0;
}

/// 5 dk ücretsiz bağlantı dolunca çağrılır: yeni bağlantıdan önce 5 dk
/// tanıtım beklemesi başlar.
void altunakarBeklemeBaslat() {
  bind.mainSetLocalOption(
      key: kAltunakarBeklemeBitis, value: '${_simdiSn() + kAltunakarBeklemeSn}');
}

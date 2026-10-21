import 'package:flutter_hbb/common/altunakar_arama.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cihaz {
  final String id, ad, firma;
  final bool cevrimici;
  _Cihaz(this.id, this.ad, this.firma, this.cevrimici);
}

void main() {
  test('Turkce harf duyarsiz katlama', () {
    expect(altunakarKatla('IŞIK Yapı'), altunakarKatla('ışık yapı'));
    expect(altunakarKatla('GİZEM HANIM'), 'gizem hanim');
    expect(altunakarKatla('  Fortan   Bilişim '), 'fortan bilisim');
  });

  test('kelime kelime arama: firma + cihaz adi', () {
    final alanlar = ['66095676', "Gizem Hanım'ın bilgisayarı", 'GIZEM-PC', 'gizem', '', 'Fortan'];
    expect(altunakarAramaEslesir('Fortan Gizem', alanlar), isTrue);
    expect(altunakarAramaEslesir('fortan gİzem', alanlar), isTrue);
    expect(altunakarAramaEslesir('FORTAN GIZEM', alanlar), isTrue);
    expect(altunakarAramaEslesir('Fortan Ahmet', alanlar), isFalse);
    expect(altunakarAramaEslesir('66 095 676', alanlar), isTrue);
    expect(altunakarAramaEslesir('   ', alanlar), isTrue);
  });

  test('firmalara gore gruplama', () {
    final g = firmalaraGore<_Cihaz>([
      _Cihaz('1', 'Zeynep', 'Fortan', true),
      _Cihaz('2', 'Ahmet', 'Fortan', false),
      _Cihaz('3', 'Kasa', '', true),
      _Cihaz('4', 'Ofis', 'Bilinmeyen', false),
    ], ['Fortan', 'Çağ Yapı', 'Kalyon'],
        firmaOf: (c) => c.firma, adOf: (c) => c.ad, cevrimiciMi: (c) => c.cevrimici);
    expect(g.map((e) => e.ad).toList(), ['Çağ Yapı', 'Fortan', 'Kalyon', '']);
    expect(g[1].cihazlar.map((c) => c.ad).toList(), ['Ahmet', 'Zeynep']);
    expect(g[1].cevrimici, 1);
    expect(g[0].cihazlar, isEmpty, reason: 'cihazsiz firma da listelenir');
    expect(g[3].cihazlar.length, 2, reason: 'firmasiz + defterde olmayan firma en sonda');
  });
}

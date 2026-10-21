// Altunakar: ortak defterde arama ve firmaya gore gruplama (Asama 2).
// Saf Dart; Flutter'a ve FFI'a bagli degil (birim testi hizli kossun).

const Map<String, String> _katlama = {
  'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c', 'â': 'a', 'î': 'i', 'û': 'u',
  '̇': '', // Dart "İ".toLowerCase() = "i" + birlesik nokta
};

/// Turkce buyuk/kucuk ve noktali/sapkali harf farkini yok sayar; ekip
/// sunucusundaki `katla` ile ayni kural ("IŞIK" = "Işık" = "isik").
String altunakarKatla(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_katlama[c] ?? c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Arama metni kelimelere bolunur; HER kelime alanlardan en az birinde
/// gecmelidir. "Fortan Gizem" -> firma "Fortan" + cihaz "Gizem Hanım'ın bilgisayarı".
bool altunakarAramaEslesir(String arama, List<String> alanlar) {
  final kelimeler = altunakarKatla(arama).split(' ').where((k) => k.isNotEmpty);
  if (kelimeler.isEmpty) return true;
  final metin = alanlar.map(altunakarKatla).join('\n');
  return kelimeler.every(metin.contains);
}

/// Bir firma ve altindaki cihazlar. `ad` bos: firmasiz cihazlar.
class FirmaGrubu<T> {
  final String ad;
  final List<T> cihazlar = [];
  int cevrimici = 0;
  FirmaGrubu(this.ad);
}

/// Cihazlari firmalarina dagitir. Firmalar ve cihazlar Turkce harf duyarsiz
/// alfabetik; cihazi olmayan firma da listelenir (yeni acilmis firma);
/// firmasiz cihazlar en sonda.
List<FirmaGrubu<T>> firmalaraGore<T>(
  List<T> cihazlar,
  List<String> firmalar, {
  required String Function(T) firmaOf,
  required String Function(T) adOf,
  required bool Function(T) cevrimiciMi,
}) {
  final gruplar = <String, FirmaGrubu<T>>{for (final f in firmalar) f: FirmaGrubu<T>(f)};
  final firmasiz = FirmaGrubu<T>('');
  for (final c in cihazlar) {
    final g = gruplar[firmaOf(c)] ?? firmasiz;
    g.cihazlar.add(c);
    if (cevrimiciMi(c)) g.cevrimici++;
  }
  final liste = gruplar.values.toList()
    ..sort((a, b) => altunakarKatla(a.ad).compareTo(altunakarKatla(b.ad)));
  if (firmasiz.cihazlar.isNotEmpty) liste.add(firmasiz);
  for (final g in liste) {
    g.cihazlar.sort((a, b) => altunakarKatla(adOf(a)).compareTo(altunakarKatla(adOf(b))));
  }
  return liste;
}

// Altunakar: giris penceresinde "Hesap olusturun" ve "Sifremi unuttum"
// baglantilari (tasarim 3.5, 3.6). Ekip sunucusu adresleri tarayicida
// www.altunakar.net/uzak-destek'teki hesap sayfalarina yonlendirir; orada
// kisisel hesap aninda acilir, ekip hesabi yonetici onayiyla istenir.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AltunakarHesapBaglantilari extends StatelessWidget {
  const AltunakarHesapBaglantilari({Key? key}) : super(key: key);

  Future<void> _ac(String yol) async {
    final kok = (await bind.mainGetApiServer()).trim();
    if (kok.isEmpty) return;
    try {
      await launchUrl(Uri.parse('$kok$yol'), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('hesap sayfasi acilamadi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
        fontSize: 13, color: Theme.of(context).colorScheme.primary);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 6,
        children: [
          InkWell(
              onTap: () => _ac('/hesap-olustur'),
              child: Text(translate('altunakar_hesap_olustur'), style: stil)),
          InkWell(
              onTap: () => _ac('/hesap-sifre'),
              child: Text(translate('altunakar_sifremi_unuttum'), style: stil)),
        ],
      ),
    );
  }
}

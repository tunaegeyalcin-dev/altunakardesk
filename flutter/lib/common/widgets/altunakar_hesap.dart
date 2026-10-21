// Altunakar: giris penceresinde "Hesap isteyin" ve "Sifremi unuttum"
// baglantilari (tasarim 3.5). Hesabi yonetici acar; bu sayfalar istegi ekip
// sunucusu uzerinden yoneticiye iletir, tarayicida acilir.
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
              onTap: () => _ac('/hesap-iste'),
              child: Text(translate('altunakar_hesap_iste'), style: stil)),
          InkWell(
              onTap: () => _ac('/sifremi-unuttum'),
              child: Text(translate('altunakar_sifremi_unuttum'), style: stil)),
        ],
      ),
    );
  }
}

// Altunakar: baglanti istegi penceresindeki dogrulama isareti (Asama 2).
// Bilet dogrulandiysa yesil "Altunakar teknisyeni (dogrulandi): <ad>"; yoksa
// sari uyari. Ad, baglananin kendi yazdigi ad DEGIL, ekip sunucusunun imzali
// biletindeki addir (src/server/connection.rs, hbb_common/src/altunakar.rs).
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

Widget altunakarDogrulamaRozeti(String teknisyen) {
  final dogrulandi = teknisyen.isNotEmpty;
  final renk = dogrulandi ? const Color(0xFF1B7F3B) : const Color(0xFFB26A00);
  return Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: renk.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(dogrulandi ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 16, color: renk),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            dogrulandi
                ? '${translate("altunakar_dogrulandi")}: $teknisyen'
                : translate("altunakar_dogrulanmadi"),
            style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

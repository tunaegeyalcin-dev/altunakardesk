import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// Altunakar: beyaz tahta. Teknisyen çizim modunda sürükleyince şekil karşı ekrana çizilir
/// (karşı tarafta hbb_common::altunakar_cizim + whiteboard katmanı). Noktalar fare
/// olaylarıyla aynı uzak ekran koordinatındadır. Oturum başına bir model.
class AltunakarCizimModel {
  static const int kalem = 1;
  static const int cizgi = 2;
  static const int ok = 3;
  static const int dikdortgen = 4;
  static const int elips = 5;

  /// (renk ARGB, çeviri anahtarı)
  static const List<(int, String)> renkler = [
    (0xFFE53935, 'Red'),
    (0xFFFFB300, 'Yellow'),
    (0xFF43A047, 'Green'),
    (0xFF1E88E5, 'Blue'),
    (0xFF212121, 'Black'),
    (0xFFFFFFFF, 'White'),
  ];

  /// (kalınlık piksel, çeviri anahtarı)
  static const List<(int, String)> kalinliklar = [
    (3, 'Thin'),
    (6, 'Medium'),
    (12, 'Thick'),
  ];

  static final Map<String, AltunakarCizimModel> _hepsi = {};

  static AltunakarCizimModel of(SessionID sessionId) => _hepsi.putIfAbsent(
      sessionId.toString(), () => AltunakarCizimModel._(sessionId));

  static AltunakarCizimModel? bul(SessionID sessionId) =>
      _hepsi[sessionId.toString()];

  static void birak(SessionID sessionId) =>
      _hepsi.remove(sessionId.toString())?._zaman?.cancel();

  AltunakarCizimModel._(this.sessionId);

  final SessionID sessionId;
  final etkin = false.obs;
  final arac = kalem.obs;
  final renk = renkler.first.$1.obs;
  final kalinlik = kalinliklar.first.$1.obs;

  int _kimlik = 0;
  Point<int>? _baslangic;
  Point<int>? _son;
  final List<int> _bekleyen = [];
  Timer? _zaman;

  void basla(Point<double> p) {
    _zaman?.cancel();
    _zaman = null;
    _kimlik++;
    final q = _tam(p);
    _baslangic = q;
    _son = q;
    _bekleyen.clear();
    if (arac.value == kalem) {
      _gonder([q.x, q.y], ekle: false);
    } else {
      _gonder([q.x, q.y, q.x, q.y], ekle: false);
    }
  }

  void surukle(Point<double> p) {
    if (_baslangic == null) return;
    final q = _tam(p);
    if (q == _son) return;
    _son = q;
    if (arac.value == kalem) {
      _bekleyen.addAll([q.x, q.y]);
    }
    // Kalemde noktalar toplu, şekillerde son hali 40 ms'de bir gider (ağı boğmasın).
    _zaman ??= Timer(const Duration(milliseconds: 40), () {
      _zaman = null;
      _gonderBekleyen();
    });
  }

  void bitir(Point<double>? p) {
    if (_baslangic == null) return;
    if (p != null) surukle(p);
    _zaman?.cancel();
    _zaman = null;
    _gonderBekleyen();
    _baslangic = null;
    _son = null;
  }

  void temizle() {
    _gonder(const [], temizle: true);
  }

  void _gonderBekleyen() {
    final a = _baslangic, b = _son;
    if (a == null || b == null) return;
    if (arac.value == kalem) {
      if (_bekleyen.isEmpty) return;
      final v = List<int>.from(_bekleyen);
      _bekleyen.clear();
      _gonder(v, ekle: true);
    } else {
      _gonder([a.x, a.y, b.x, b.y], ekle: false);
    }
  }

  void _gonder(List<int> noktalar, {bool ekle = false, bool temizle = false}) {
    bind.sessionAltunakarCizim(
      sessionId: sessionId,
      kimlik: _kimlik,
      arac: arac.value,
      argb: renk.value,
      kalinlik: kalinlik.value,
      noktalar: noktalar.join(','),
      ekle: ekle,
      temizle: temizle,
    );
  }

  static Point<int> _tam(Point<double> p) => Point(p.x.round(), p.y.round());

  static Color renkOf(int argb) => Color(argb);
}

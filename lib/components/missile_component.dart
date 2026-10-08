import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Güdümlü mod / nişan alma sırasında hazır okun üzerine biniyor.
/// Kozy mutfak temasına uyacak şekilde reskin edildi: metalik gri gövde
/// yerine ahşap tonları, kırmızı panel yerine bal (honey) panelleri, ve
/// terracotta (biber kırmızısı → bal) motor alevi.
///
/// Pozisyon/rotasyon tamamen parent (ArrowComponent) tarafından
/// belirlenir — bu component'in kendi hareket mantığı yoktur, sadece
/// render() içinde görsel çizer. Geometri (gövde/kanat/alev yerleşimi)
/// önceki versiyonla birebir aynı — sadece renk paleti değişti.
class MissileComponent extends PositionComponent {
  MissileComponent({required Vector2 position})
      : super(
    position: position,
    anchor: Anchor.center,
    priority: 1000, // arrow üzerindeki her şeyin önünde çizilsin
    size: Vector2(0, 0),
  );

  double _time = 0.0;
  final math.Random _rng = math.Random();

  // --- Gövde: ahşap gradyan (sol koyu / orta açık / sağ koyu) ---
  static final Paint _bodyPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF6B4423),
        Color(0xFFC9A877),
        Color(0xFF3E2723),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(const Rect.fromLTWH(-11, -38, 22, 76));

  static final Paint _bodyStrokePaint = Paint()
    ..color = const Color(0xFF2C1C14)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  // --- Burun konisi: koyu ahşap, oluklu ---
  static final Paint _noseFillPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF3E2723),
        Color(0xFF8D5B3A),
        Color(0xFF2C1C14),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(const Rect.fromLTWH(-9, -46, 18, 20));

  static final Paint _grooveStrokePaint = Paint()
    ..color = const Color(0xFF2C1C14)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  // --- Küçük yuvarlak "pencere" (spec: small round window) ---
  static final Paint _windowPaint = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0xFFF3D48A), Color(0xFFB5791D)],
    ).createShader(const Rect.fromLTWH(-5, -5, 10, 10));
  static final Paint _windowStrokePaint = Paint()
    ..color = const Color(0xFF7A4F11)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  // --- Bal (honey) panel şeritleri (gövde üzerindeki accent bloklar) ---
  static final Paint _honeyPanelPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0C878), Color(0xFFB5791D)],
    ).createShader(const Rect.fromLTWH(-9, -22, 18, 16));

  static final Paint _honeyPanelStrokePaint = Paint()
    ..color = const Color(0xFF7A4F11)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  // --- Kanatçıklar: koyu ahşap gövde + pepper-red uç ---
  static final Paint _finBasePaint = Paint()..color = const Color(0xFF6B4423);
  static final Paint _finTipPaint = Paint()..color = const Color(0xFFC1440E);
  static final Paint _finStrokePaint = Paint()
    ..color = const Color(0xFF2C1C14)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // --- Orta gövdedeki ince bal bandı (eskiden cyan enerji bandı) ---
  static final Paint _honeyBandPaint = Paint()
    ..color = const Color(0xFFF0C878).withOpacity(0.85);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // --- Titreyen motor alevi için 0.0-1.0 aralığında yanıp sönen değer ---
    final flicker =
        0.55 + 0.35 * (math.sin(_time * 22) * 0.5 + 0.5) + _rng.nextDouble() * 0.10;
    final flameLength = 14 + 9 * flicker;
    final flameWidth = 5 + 2 * flicker;
    const flameTopY = 38.0; // gövdenin alt kenarı

    // Bal bandındaki nabız (pulse) — bandın parlaklığı zamanla dalgalanır
    final pulse = 0.5 + 0.5 * math.sin(_time * 4);

    // --- Dış motor parlaması (glow) — terracotta ---
    final glowPaint = Paint()
      ..color = const Color(0xFFE3A93B).withOpacity(0.30 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(0, flameTopY + flameLength * 0.5),
      15 + 6 * flicker,
      glowPaint,
    );

    // --- Kanatçıklar (gövdenin arkasında kalsın diye önce çiziliyor) ---
    _drawSweptFin(canvas, isLeft: true);
    _drawSweptFin(canvas, isLeft: false);

    // --- Motor alevi: honey -> pepper-red (terracotta) ---
    final flameRect = Rect.fromLTWH(
      -flameWidth,
      flameTopY,
      flameWidth * 2,
      flameLength,
    );
    final flamePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0C878), Color(0xFFC1440E)],
      ).createShader(flameRect);
    final flamePath = Path()
      ..moveTo(-flameWidth, flameTopY)
      ..quadraticBezierTo(
          0, flameTopY + flameLength * 0.6, 0, flameTopY + flameLength)
      ..quadraticBezierTo(
          0, flameTopY + flameLength * 0.6, flameWidth, flameTopY)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    // --- Ana gövde (silindirik, ahşap gradyan) ---
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -20, 22, 58),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);
    canvas.drawRRect(bodyRect, _bodyStrokePaint);

    // --- Bal panel şeritleri ---
    for (final dy in [-14.0, -2.0]) {
      final panelRect = Rect.fromLTWH(-8, dy, 16, 8);
      canvas.drawRect(panelRect, _honeyPanelPaint);
      canvas.drawRect(panelRect, _honeyPanelStrokePaint);
    }

    // --- Orta gövdede bal bandı (pulse ile parlıyor) ---
    final bandGlow = Paint()
      ..color = const Color(0xFFF0C878).withOpacity(0.25 + 0.25 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(const Rect.fromLTWH(-9, 10, 18, 5), bandGlow);
    canvas.drawRect(
      const Rect.fromLTWH(-9, 10, 18, 5),
      _honeyBandPaint..color = const Color(0xFFF0C878).withOpacity(0.5 + 0.5 * pulse),
    );

    // --- Burun konisi (sivri, oluklu) ---
    final nosePath = Path()
      ..moveTo(0, -46)
      ..lineTo(-9, -26)
      ..lineTo(-9, -20)
      ..lineTo(9, -20)
      ..lineTo(9, -26)
      ..close();
    canvas.drawPath(nosePath, _noseFillPaint);
    canvas.drawPath(nosePath, _bodyStrokePaint);

    // Burun üzerindeki oluk (panel) çizgileri
    for (final dy in [-34.0, -29.0, -24.0]) {
      final t = ((dy + 46) / 26).clamp(0.15, 1.0);
      final halfW = 9 * t;
      canvas.drawLine(
        Offset(-halfW, dy),
        Offset(halfW, dy),
        _grooveStrokePaint,
      );
    }

    // --- Küçük yuvarlak pencere ---
    canvas.drawCircle(const Offset(0, -30), 3.2, _windowPaint);
    canvas.drawCircle(const Offset(0, -30), 3.2, _windowStrokePaint);

    // Burun ucunda küçük bir parlaklık vuruşu
    canvas.drawLine(
      const Offset(-3, -40),
      const Offset(-1, -30),
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Arkaya süpürülmüş (swept-back), ucu pepper-red kanatçık.
  /// isLeft true ise sol tarafa, false ise sağ tarafa çizilir.
  void _drawSweptFin(Canvas canvas, {required bool isLeft}) {
    final dir = isLeft ? -1.0 : 1.0;

    final finPath = Path()
      ..moveTo(dir * 9, -4)
      ..lineTo(dir * 26, 18)
      ..lineTo(dir * 22, 30)
      ..lineTo(dir * 9, 22)
      ..close();
    canvas.drawPath(finPath, _finBasePaint);
    canvas.drawPath(finPath, _finStrokePaint);

    final tipPath = Path()
      ..moveTo(dir * 26, 18)
      ..lineTo(dir * 22, 30)
      ..lineTo(dir * 17, 27)
      ..lineTo(dir * 20, 19)
      ..close();
    canvas.drawPath(tipPath, _finTipPaint);
  }
}
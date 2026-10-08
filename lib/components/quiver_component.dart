import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Şarjördeki (magazine) okların dibinde duran, sıcak mutfak temasına uygun
/// bir kavanoz (mason jar) görseli — kapağından şiş demeti çıkıyor.
/// Sadece görsel — collision yok. API (constructor, position, angle) önceki
/// QuiverComponent ile birebir aynı, bu yüzden fruit_hit_game.dart'ta hiçbir
/// değişiklik gerekmiyor.
class QuiverComponent extends PositionComponent {
  static final Vector2 _size = Vector2(78, 104);

  // Kapaktan çıkan 5 şişin gövde renkleri (ahşap tonları)
  static const List<Color> _stickColors = [
    Color(0xFF8A5F30),
    Color(0xFFA8672F),
    Color(0xFF8A5F30),
    Color(0xFFA8672F),
    Color(0xFF8A5F30),
  ];

  // Şişlerin ucundaki kurdele/bant renkleri — pepper-red / sage / honey
  static const List<Color> _flagColors = [
    Color(0xFFC1440E),
    Color(0xFF7C9070),
    Color(0xFFE3A93B),
    Color(0xFFC1440E),
    Color(0xFF7C9070),
  ];

  static final Paint _lidPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFA8672F), Color(0xFF8A5F30)],
    ).createShader(const Rect.fromLTWH(-39, 0, 78, 16));

  static final Paint _lidCapPaint = Paint()..color = const Color(0xFF6B4423);

  static final Paint _jarBodyPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6E9D7), Color(0xFFEFDCC0)],
    ).createShader(const Rect.fromLTWH(-39, 12, 78, 92));

  static final Paint _jarStrokePaint = Paint()
    ..color = const Color(0xFFC9A877)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  static final Paint _jarShinePaint = Paint()
    ..color = Colors.white.withOpacity(0.35);

  static final Paint _spiceDotPaint1 = Paint()..color = const Color(0xFFC1440E);
  static final Paint _spiceDotPaint2 = Paint()..color = const Color(0xFF7C9070);
  static final Paint _spiceDotPaint3 = Paint()..color = const Color(0xFF8F2F0A);

  /// angle artık varsayılan olarak 0 — kavanoz eski sadak gibi eğik değil,
  /// tezgahın üstünde dimdik duruyor (mockup ile birebir).
  QuiverComponent({required Vector2 position, double angle = 0})
      : super(
    position: position,
    size: _size,
    anchor: Anchor.topCenter,
    angle: angle,
    priority: 5,
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // --- Kapaktan çıkan şiş demeti (kavanozun arkasında/üstünde) ---
    for (int i = 0; i < 5; i++) {
      final dx = -28.0 + i * 14;
      final tilt = (i - 2) * 0.14;
      canvas.save();
      canvas.translate(dx, 14);
      canvas.rotate(tilt);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -34, 4, 40),
          const Radius.circular(2),
        ),
        Paint()..color = _stickColors[i],
      );

      final flagPath = Path()
        ..moveTo(-2, -34)
        ..lineTo(2, -34)
        ..lineTo(0, -46)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = _flagColors[i]);

      canvas.restore();
    }

    // --- Kavanoz gövdesi ---
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-39, 12, 78, 92),
      const Radius.circular(14),
    );
    canvas.drawRRect(bodyRRect, _jarBodyPaint);
    canvas.drawRRect(bodyRRect, _jarStrokePaint);

    // --- Kapak ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-39, 0, 78, 16),
        const Radius.circular(6),
      ),
      _lidPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -4, 70, 10),
        const Radius.circular(4),
      ),
      _lidCapPaint,
    );

    // --- Cam parlaklığı (üst kısımda hafif ışık vurgusu) ---
    canvas.save();
    canvas.translate(0, 18);
    canvas.rotate(-0.05);
    canvas.drawOval(const Rect.fromLTWH(-31, -3, 34, 8), _jarShinePaint);
    canvas.restore();

    // --- Camın içinden görünen baharat noktaları ---
    canvas.drawCircle(const Offset(-9, 48), 4.2, _spiceDotPaint1);
    canvas.drawCircle(const Offset(10, 62), 3.6, _spiceDotPaint2);
    canvas.drawCircle(const Offset(-2, 38), 3, _spiceDotPaint3);
  }
}

/// Kavanoz ağzının ön kenarı — oklardan/şişlerden SONRA çizilir ki şişler
/// gerçekten kavanozun içinden çıkıyormuş gibi görünsün. Önceki
/// QuiverFrontRim ile aynı API (position, angle).
class QuiverFrontRim extends PositionComponent {
  static final Vector2 _size = Vector2(78, 20);

  static final Paint _rimPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFA8672F), Color(0xFF6B4423)],
    ).createShader(const Rect.fromLTWH(-39, 0, 78, 16));

  static final Paint _rimStrokePaint = Paint()
    ..color = const Color(0xFF4A2C18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  QuiverFrontRim({required Vector2 position, double angle = 0})
      : super(
    position: position,
    size: _size,
    anchor: Anchor.topCenter,
    angle: angle,
    priority: 20,
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rimPath = Path()
      ..moveTo(-35, 4)
      ..quadraticBezierTo(0, 16, 35, 4)
      ..lineTo(35, 12)
      ..quadraticBezierTo(0, 22, -35, 12)
      ..close();

    canvas.drawPath(rimPath, _rimPaint);
    canvas.drawPath(rimPath, _rimStrokePaint);
  }
}
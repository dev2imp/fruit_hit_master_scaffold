import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BackgroundComponent extends PositionComponent {
  BackgroundComponent({required Vector2 size}) : super(size: size, priority: -10);

  // Sıcak, açık gökyüzü tonları — kılıfın tilki-derisi paletiyle uyumlu
  static const Color _topColor = Color(0xFFFFF3E2);    // Üst: sıcak krem/şeftali
  static const Color _midColor = Color(0xFFFFDDB8);    // Orta: yumuşak şeftali-turuncu
  static const Color _bottomColor = Color(0xFFFFC994); // Alt: doygun amber-turuncu

  // Hafif vignette (kenarlar biraz koyulaşsın, merkeze odak versin)
  static final Paint _vignettePaint = Paint()
    ..color = const Color(0xFF7A4A24).withOpacity(0.10);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Yukarıdan aşağıya sıcak gradyan
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [_topColor, _midColor, _bottomColor],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Yumuşak radyal vignette — kenarlarda hafif koyulaşma
    final vignetteShader = RadialGradient(
      center: Alignment.center,
      radius: 0.95,
      colors: [
        Colors.transparent,
        _vignettePaint.color,
      ],
      stops: const [0.6, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignetteShader);
  }
}
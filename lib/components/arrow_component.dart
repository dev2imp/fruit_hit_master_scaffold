import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/fruit_hit_game.dart';
import 'fruit_component.dart';

// Şarjör durumunu destekleyen kararlı enum yapısı
enum ArrowState { inMagazine, flying, stuck }

/// A single arrow shot from the bottom of the screen.
class ArrowComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<FruitHitGame> {
  // Ok boyutları (Büyük ok boyutunuz tam korundu)
  static final Vector2 _size = Vector2(20, 92);

  /// Upward flight speed in pixels/second.
  final double flightSpeed;

  // Başlangıç durumunu tutan değişken
  ArrowState state;

  late final RectangleHitbox hitbox;

  // --- Saplanma Sonrası Pozisyon Takibi İçin Değişkenler ---
  double _stuckDistance = 0.0;
  double _stuckAngleRelativeToFruit = 0.0;
  FruitComponent? _targetFruit;

  // ---------------------------------------------------------------------
  // GÖRSEL: Aşağıdaki tüm Paint/Path/Shader nesneleri sadece render()
  // içinde kullanılır ve _size sabit olduğu için tek seferlik hesaplanıp
  // static final olarak cache'lenir — performans mevcut haliyle aynı
  // kalır, hiçbir gameplay/collision/state mantığı değişmedi.
  // ---------------------------------------------------------------------

  static final double _halfWidth = _size.x / 2;
  static final double _headHeight = _size.y * 0.30;
  static final double _shaftWidth = _size.x * 0.42;
  static final double _shaftHalfWidth = _shaftWidth / 2;
  static final double _finTop = _size.y * 0.70;
  static final double _wrapY = _finTop - 6;

  // Yumuşak, gövdenin arkasında kalan gölge (derinlik hissi verir)
  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.28)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  // Metalik ok ucu: koyu gri -> açık gri -> koyu gri gradyan (parlak metal hissi)
  static final Paint _headPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF9AA0A6),
        Color(0xFFF2F3F5),
        Color(0xFFBDC2C7),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(-_halfWidth, 0, _size.x, _headHeight));

  static final Paint _headStrokePaint = Paint()
    ..color = const Color(0xFF54595E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round;

  // Ok ucunun üstünde ince parlak highlight çizgisi (cam/metal parıltısı)
  static final Paint _headShinePaint = Paint()
    ..color = Colors.white.withOpacity(0.55)
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Ahşap gövde: koyudan açığa gradyan + sağ kenarda ince highlight şeridi
  static final Paint _shaftPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF6D4C41),
        Color(0xFFA1785F),
        Color(0xFF5D4037),
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(
      Rect.fromLTWH(-_shaftHalfWidth, _headHeight, _shaftWidth,
          _size.y - _headHeight),
    );

  static final Paint _shaftHighlightPaint = Paint()
    ..color = Colors.white.withOpacity(0.18)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  // Kanatçıklar: kırmızıdan koyu kırmızıya gradyan (hacimli görünüm)
  static final Paint _finPaintLeft = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
    ).createShader(
      Rect.fromLTWH(-_halfWidth, _finTop, _halfWidth - _shaftHalfWidth,
          _size.y - _finTop),
    );

  static final Paint _finPaintRight = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
    ).createShader(
      Rect.fromLTWH(_shaftHalfWidth, _finTop, _halfWidth - _shaftHalfWidth,
          _size.y - _finTop),
    );

  static final Paint _finStrokePaint = Paint()
    ..color = const Color(0xFF7F0000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // Kanatçıkların gövdeye bağlandığı noktadaki ip sarımı (nock wrap)
  static final Paint _wrapPaint = Paint()
    ..color = const Color(0xFFFFC107)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  // Uçuş sırasında arkada bırakılan hafif ışık izi (motion trail)
  static final Paint _trailPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.35),
        Colors.white.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(-_shaftHalfWidth, 0, _shaftWidth, 46));

  // Meyveye saplandığında gövdenin ne kadarının "içeride" (görünmez)
  // sayılacağını belirler — sadece görsel bir kısaltma, gerçek pozisyon/
  // hitbox/state mantığına dokunmaz.
  static const double _embedDepth = 16.0;

  ArrowComponent({
    required Vector2 startPosition,
    this.flightSpeed = 900,
    this.state = ArrowState.inMagazine, // Varsayılan olarak şarjörde bekler
  }) : super(
    position: startPosition,
    size: _size,
    anchor: Anchor.topCenter,
    angle: 0.0,
    priority: 10,
  );

  @override
  Future<void> onLoad() async {
    // Hitbox bileşenin kendi içinde oluşturuluyor.
    // Eğer ok şarjördeyse kazara havadakilere çarpmasın diye pasif (inactive) başlar.
    hitbox = RectangleHitbox(
      size: size,
      position: Vector2.zero(),
      collisionType: state == ArrowState.inMagazine
          ? CollisionType.inactive
          : CollisionType.active,
    );
    add(hitbox);
  }

  /// Oku güvenle fırlatmak ve hata almadan çarpışmayı açmak için tetiklenen metot
  void shoot() {
    state = ArrowState.flying;
    hitbox.collisionType = CollisionType.active;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final halfWidth = _halfWidth;
    final headHeight = _headHeight;
    final shaftHalfWidth = _shaftHalfWidth;
    final finTop = _finTop;

    // Saplanmışsa gövdenin/kanatçıkların alt ucunu görsel olarak
    // "meyvenin içine gömülmüş" gibi kısaltıyoruz. Bu SADECE çizimi
    // etkiler — gerçek position/hitbox/state mantığı hiç değişmiyor.
    final bool isEmbedded = state == ArrowState.stuck;
    final double bottomEdge = isEmbedded ? size.y - _embedDepth : size.y;

    // --- Uçuş izi (motion trail): sadece havadayken, kuyruğun hemen
    // arkasında yukarı doğru sönümlenen hafif bir ışık şeridi ---
    if (state == ArrowState.flying) {
      canvas.save();
      canvas.translate(0, size.y);
      canvas.drawRect(
        Rect.fromLTWH(-shaftHalfWidth, 0, _shaftWidth, 46),
        _trailPaint,
      );
      canvas.restore();
    }

    // --- Gölge: gövdenin hemen sağ-altına düşen hafif blur'lu şerit ---
    // Uçuş sırasında derinlik/hacim hissi verir, saplanmış oklarda da
    // meyvenin üstünde hafif bir kontrast yaratır.
    canvas.save();
    canvas.translate(1.5, 1.5);
    final shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-halfWidth, headHeight)
      ..lineTo(-shaftHalfWidth, headHeight)
      ..lineTo(-shaftHalfWidth, bottomEdge)
      ..lineTo(-halfWidth, bottomEdge)
      ..lineTo(-shaftHalfWidth, math.min(finTop, bottomEdge))
      ..lineTo(shaftHalfWidth, math.min(finTop, bottomEdge))
      ..lineTo(halfWidth, bottomEdge)
      ..lineTo(shaftHalfWidth, bottomEdge)
      ..lineTo(shaftHalfWidth, headHeight)
      ..lineTo(halfWidth, headHeight)
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);
    canvas.restore();

    // --- Ok Ucu (Yukarı bakan üçgen, metalik gradyan + parlaklık) ---
    final headPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-halfWidth, headHeight)
      ..lineTo(halfWidth, headHeight)
      ..close();
    canvas.drawPath(headPath, _headPaint);
    canvas.drawPath(headPath, _headStrokePaint);

    // Ok ucu üstünde küçük bir parlaklık vuruşu (sol kenara yakın)
    canvas.drawLine(
      Offset(-halfWidth * 0.45, headHeight * 0.35),
      Offset(-halfWidth * 0.1, headHeight * 0.75),
      _headShinePaint,
    );

    // --- Gövde (ahşap gradyan) — saplandıysa alt ucu kısaltılmış ---
    final shaftRect = Rect.fromLTRB(
      -shaftHalfWidth,
      headHeight,
      shaftHalfWidth,
      bottomEdge,
    );
    canvas.drawRect(shaftRect, _shaftPaint);

    // Gövdenin sağ kenarında ince ışık şeridi (silindirik hacim hissi)
    canvas.drawLine(
      Offset(shaftHalfWidth - 1.5, headHeight + 2),
      Offset(shaftHalfWidth - 1.5, math.max(bottomEdge - 2, headHeight + 2)),
      _shaftHighlightPaint,
    );

    // --- Kanatçıklar (iki tonlu kırmızı gradyan) ---
    // Saplandığında kanatçıklar embed sınırının içinde kalıyorsa hiç
    // çizilmiyor (tamamen "gömülmüş" görünüyor); kısmen kalıyorsa
    // kısaltılmış haliyle çiziliyor.
    if (finTop < bottomEdge) {
      final finPathLeft = Path()
        ..moveTo(-shaftHalfWidth, finTop)
        ..lineTo(-halfWidth, bottomEdge)
        ..lineTo(-shaftHalfWidth, bottomEdge)
        ..close();
      final finPathRight = Path()
        ..moveTo(shaftHalfWidth, finTop)
        ..lineTo(halfWidth, bottomEdge)
        ..lineTo(shaftHalfWidth, bottomEdge)
        ..close();

      canvas.drawPath(finPathLeft, _finPaintLeft);
      canvas.drawPath(finPathLeft, _finStrokePaint);
      canvas.drawPath(finPathRight, _finPaintRight);
      canvas.drawPath(finPathRight, _finStrokePaint);
    }

    // --- Kanatçık bağlantı noktasında altın rengi ip sarımı (nock wrap) ---
    // Sadece hâlâ görünür durumdaysa (embed sınırının üstünde kaldıysa) çizilir.
    if (_wrapY < bottomEdge) {
      canvas.drawLine(
        Offset(-shaftHalfWidth - 0.5, _wrapY),
        Offset(shaftHalfWidth + 0.5, _wrapY),
        _wrapPaint,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Şarjörde bekleyen yedek oklar uçmaz
    if (state == ArrowState.inMagazine) return;

    // 1. Durum: Ok havada uçuyor
    if (state == ArrowState.flying) {
      position.y -= flightSpeed * dt;

      if (position.y < -size.y) {
        removeFromParent();
      }
    }
    // 2. Durum: Ok meyveye saplandı
    else if (state == ArrowState.stuck && _targetFruit != null) {
      final fruitCenter = _targetFruit!.worldCenter;
      final currentAngle = _targetFruit!.angle + _stuckAngleRelativeToFruit;

      position.x = fruitCenter.x + math.cos(currentAngle) * _stuckDistance;
      position.y = fruitCenter.y + math.sin(currentAngle) * _stuckDistance;

      angle = currentAngle - math.pi / 2;
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints,
      PositionComponent other,
      ) {
    super.onCollisionStart(intersectionPoints, other);

    if (state != ArrowState.flying) return;

    if (other is FruitComponent) {
      _stickIntoFruit(other, intersectionPoints);
    } else if (other is ArrowComponent && other.state == ArrowState.stuck) {
      state = ArrowState.stuck;
      game.onArrowCollision();
    }
  }

  void _stickIntoFruit(
      FruitComponent fruit,
      Set<Vector2> intersectionPoints,
      ) {
    state = ArrowState.stuck;
    _targetFruit = fruit;

    final Vector2 fixedImpactPoint = intersectionPoints.isNotEmpty
        ? intersectionPoints.first
        : absolutePosition;

    final fruitCenter = fruit.worldCenter;
    final delta = fixedImpactPoint - fruitCenter;
    _stuckDistance = delta.length;

    final absoluteImpactAngle = math.atan2(delta.y, delta.x);
    _stuckAngleRelativeToFruit = absoluteImpactAngle - fruit.angle;

    hitbox.collisionType = CollisionType.passive;
    fruit.stuckArrowCount++;

    game.onArrowStuck(fixedImpactPoint);
  }
}
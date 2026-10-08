import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../game/level_config.dart';

/// Internal state used only by [RotationBehavior.hard] to decide, at
/// random intervals, whether the fruit should currently be spinning,
/// paused, or ramping speed up/down — and which direction it spins in.
enum _HardPhase { spinning, paused, ramping }

/// The rotating fruit/vegetable in the middle of the screen.
///
/// Handles:
///  - Loading the correct sprite for the current [LevelConfig].
///  - Driving rotation speed/direction according to the level's
///    [RotationBehavior] (constant / dynamic / hard).
///  - Exposing a [CircleHitbox] that is intentionally smaller than the
///    sprite (85% of the sprite radius) so stuck arrows visually appear
///    to pierce *into* the fruit rather than just touching its edge.
///  - Owning stuck [ArrowComponent]s as children so they rotate
///    perfectly in lock-step with the fruit for free.
class FruitComponent extends SpriteComponent
    with HasGameReference, CollisionCallbacks {
  final LevelConfig levelConfig;

  /// Current angular velocity in radians/second. Sign determines
  /// direction: positive = clockwise, negative = counter-clockwise.
  double _angularVelocity = 0;

  /// Random generator reused across the lifetime of this fruit for all
  /// difficulty-specific randomness (hard mode timers, direction flips).
  final Random _random = Random();

  // --- Dynamic (levels 6-15) state ---
  double _dynamicElapsed = 0;

  // --- Hard (levels 16-50) state ---
  _HardPhase _hardPhase = _HardPhase.spinning;
  double _hardPhaseTimeRemaining = 0;
  double _hardTargetVelocity = 0;
  double _hardCurrentVelocity = 0;

  /// How many arrows are currently embedded in this fruit. Tracked here
  /// (in addition to the game's own counter) so external systems can
  /// query fruit-local state if needed.
  int stuckArrowCount = 0;

  late final CircleHitbox hitbox;

  FruitComponent({
    required this.levelConfig,
    required Vector2 position,
    required Vector2 size,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
          priority: 5,
        );

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('fruits/${levelConfig.fruitAsset}');

    // The fruit image asset is a square, but we deliberately shrink the
    // collision circle to 85% of the visual radius. This is the key trick
    // that makes arrows look like they're piercing *into* the flesh of
    // the fruit instead of just grazing its outer silhouette.
    final visualRadius = size.x / 2;
    final hitboxRadius = visualRadius * 0.85;

    hitbox = CircleHitbox(
      radius: hitboxRadius,
      position: size / 2,
      anchor: Anchor.center,
    );
    add(hitbox);

    _initRotationState();
  }

  void _initRotationState() {
    switch (levelConfig.rotationBehavior) {
      case RotationBehavior.constant:
        // Single fixed direction, chosen once per level, never changes.
        final direction = _random.nextBool() ? 1.0 : -1.0;
        _angularVelocity = levelConfig.baseRotationSpeed * direction;
        break;

      case RotationBehavior.dynamic:
        _dynamicElapsed = 0;
        // Direction stays fixed for the whole level in "dynamic" tier —
        // only the *speed* oscillates.
        final direction = _random.nextBool() ? 1.0 : -1.0;
        _angularVelocity = levelConfig.baseRotationSpeed * direction;
        _dynamicDirection = direction;
        break;

      case RotationBehavior.hard:
        _hardCurrentVelocity =
            levelConfig.baseRotationSpeed * (_random.nextBool() ? 1.0 : -1.0);
        _hardTargetVelocity = _hardCurrentVelocity;
        _hardPhase = _HardPhase.spinning;
        _hardPhaseTimeRemaining = _randomRange(1.0, 2.5);
        break;
    }
  }

  double _dynamicDirection = 1.0;

  @override
  void update(double dt) {
    super.update(dt);

    switch (levelConfig.rotationBehavior) {
      case RotationBehavior.constant:
        angle += _angularVelocity * dt;
        break;

      case RotationBehavior.dynamic:
        _updateDynamic(dt);
        break;

      case RotationBehavior.hard:
        _updateHard(dt);
        break;
    }
  }

  /// Smooth sinusoidal speed oscillation, direction locked for the level.
  /// Speed breathes between ~40% and 160% of the base speed so it feels
  /// alive without ever fully reversing.
  void _updateDynamic(double dt) {
    _dynamicElapsed += dt;
    const oscillationPeriod = 2.4; // seconds per full breathe cycle
    final t = (_dynamicElapsed / oscillationPeriod) * 2 * pi;
    final speedMultiplier = 1.0 + 0.6 * sin(t); // ranges 0.4 .. 1.6
    _angularVelocity =
        levelConfig.baseRotationSpeed * speedMultiplier * _dynamicDirection;
    angle += _angularVelocity * dt;
  }

  /// State machine that randomly cycles between:
  ///  - spinning at a (randomized) target velocity,
  ///  - pausing completely,
  ///  - ramping smoothly toward a new target velocity (which may reverse
  ///    direction).
  void _updateHard(double dt) {
    _hardPhaseTimeRemaining -= dt;

    if (_hardPhaseTimeRemaining <= 0) {
      _pickNextHardPhase();
    }

    switch (_hardPhase) {
      case _HardPhase.spinning:
        _hardCurrentVelocity = _hardTargetVelocity;
        break;
      case _HardPhase.paused:
        _hardCurrentVelocity = 0;
        break;
      case _HardPhase.ramping:
        // Smoothly interpolate current velocity toward the target so
        // direction reversals never look like a jarring snap.
        final lerpSpeed = 3.0; // higher = snappier ramp
        _hardCurrentVelocity +=
            (_hardTargetVelocity - _hardCurrentVelocity) * lerpSpeed * dt;
        break;
    }

    angle += _hardCurrentVelocity * dt;
  }

  void _pickNextHardPhase() {
    final roll = _random.nextDouble();

    // Olasılıkları yeniden dengeledik:
    // %15 ihtimalle kısa duraklama, %55 ihtimalle ani hız değişimi/yön değiştirme, %30 ihtimalle normal dönme.
    if (roll < 0.15) {
      _hardPhase = _HardPhase.paused;
      // Durma süresini çok kısalttık (0.15 - 0.4 saniye). Oyuncu gözünü açıp kapayana kadar bitmeli.
      _hardPhaseTimeRemaining = _randomRange(0.15, 0.4);
    }
    else if (roll < 0.70) {
      _hardPhase = _HardPhase.ramping;

      // Hızın sıfıra çakılmasını engellemek için yönü tamamen bağımsız rastgele seçiyoruz
      final isClockwise = _random.nextBool();
      final directionSign = isClockwise ? 1.0 : -1.0;

      // Meyve kesinlikle hareket etsin diye taban hız çarpanını yüksek tutuyoruz (1.2 ile 2.2 katı)
      final magnitude = levelConfig.baseRotationSpeed * _randomRange(1.2, 2.2);

      _hardTargetVelocity = magnitude * directionSign;
      _hardPhaseTimeRemaining = _randomRange(0.4, 1.0); // Geçiş sürelerini kısalttık
    }
    else {
      _hardPhase = _HardPhase.spinning;

      // Eğer mevcut hız sıfırsa (paused modundan çıkıyorsa) dönmeye başlaması için zorla hız veriyoruz
      if (_hardCurrentVelocity.abs() < 0.1) {
        _hardCurrentVelocity = levelConfig.baseRotationSpeed * (_random.nextBool() ? 1.0 : -1.0);
      }

      _hardTargetVelocity = _hardCurrentVelocity;
      _hardPhaseTimeRemaining = _randomRange(0.6, 1.5);
    }
  }


  double _randomRange(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  /// Called by [FruitHitGame] right before this fruit is removed (either
  /// because it exploded on level-complete, or because the level is being
  /// restarted after a game-over) so callers can grab its world position
  /// for spawning effects.
  Vector2 get worldCenter => absoluteCenter;
}

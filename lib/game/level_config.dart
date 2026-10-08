import 'dart:math';
import 'package:flutter/material.dart';

/// Defines how the fruit is allowed to rotate for a given difficulty tier.
enum RotationBehavior {
  /// Levels 1-5: constant angular speed, single direction, no surprises.
  constant,

  /// Levels 6-15: speed accelerates/decelerates smoothly (sine-driven),
  /// but the direction of rotation never changes.
  dynamic,

  /// Levels 16-50: the fruit can randomly pause, suddenly accelerate,
  /// and reverse its spin direction (clockwise <-> counter-clockwise).
  hard,
}

/// Immutable configuration describing everything needed to build a single
/// playable level.
@immutable
class LevelConfig {
  final int level;
  final String fruitAsset; // filename inside assets/images/fruits/
  final String fruitName; // human-readable display name (English)
  final int arrowsRequired; // how many arrows must be stuck to win
  final RotationBehavior rotationBehavior;
  final double baseRotationSpeed; // radians/sec
  final Color themeColor; // used for juice particle color

  const LevelConfig({
    required this.level,
    required this.fruitAsset,
    required this.fruitName,
    required this.arrowsRequired,
    required this.rotationBehavior,
    required this.baseRotationSpeed,
    required this.themeColor,
  });
}

/// Central provider that builds and caches the full 50-level progression.
///
/// This keeps all "game design" numbers (difficulty curve, arrow counts,
/// speeds) in one place so they're easy to tune without touching gameplay
/// code.
class LevelConfigProvider {
  LevelConfigProvider._();

  static const int totalLevels = 50;

  /// Pool of fruit/vegetable image assets (English filenames + names).
  /// Cycled (modulo) across all 50 levels. Add more entries here any time
  /// to reduce repetition — nothing else needs to change.
  static const List<_FruitDef> _fruitPool = [
    _FruitDef('pear.png', 'Pear', Color(0xFF8BC34A)),
    _FruitDef('apple.png', 'Apple', Color(0xFFE53935)),
    _FruitDef('watermelon.png', 'Watermelon', Color(0xFFD32F2F)),
    _FruitDef('lettuce.png', 'Lettuce', Color(0xFF7CB342)),
    _FruitDef('banana.png', 'Banana', Color(0xFFFDD835)),
    _FruitDef('strawberry.png', 'Strawberry', Color(0xFFE91E63)),
    _FruitDef('orange.png', 'Orange', Color(0xFFFB8C00)),
    _FruitDef('grape.png', 'Grape', Color(0xFF8E24AA)),
    _FruitDef('pineapple.png', 'Pineapple', Color(0xFFFFC107)),
    _FruitDef('mango.png', 'Mango', Color(0xFFFF9800)),
    _FruitDef('cherry.png', 'Cherry', Color(0xFFC2185B)),
    _FruitDef('eggplant.png', 'Eggplant', Color(0xFF6A1B9A)),
    _FruitDef('pepper.png', 'Pepper', Color(0xFF43A047)),
    _FruitDef('carrot.png', 'Carrot', Color(0xFFF4511E)),
    _FruitDef('tomato.png', 'Tomato', Color(0xFFE53935)),
    _FruitDef('cucumber.png', 'Cucumber', Color(0xFF66BB6A)),
  ];

  static List<LevelConfig>? _cache;

  /// Returns the full, ordered list of 50 level configs (built once,
  /// cached thereafter).
  static List<LevelConfig> get levels {
    _cache ??= List.generate(totalLevels, (i) => _buildLevel(i + 1));
    return _cache!;
  }

  static LevelConfig getLevel(int levelNumber) {
    final idx = (levelNumber - 1).clamp(0, totalLevels - 1);
    return levels[idx];
  }

  static LevelConfig _buildLevel(int level) {
    final fruit = _fruitPool[(level - 1) % _fruitPool.length];

    // Arrows required scales from 4 (level 1) up to 12 (level 50), linear.
    final arrowsRequired =
        (4 + ((level - 1) * (12 - 4) / (totalLevels - 1))).round();

    late final RotationBehavior behavior;
    late final double baseSpeed;

    if (level <= 5) {
      // Onboarding: constant, gentle, single-direction spin.
      behavior = RotationBehavior.constant;
      baseSpeed = 1.0 + (level - 1) * 0.15; // 1.0 -> 1.6 rad/s
    } else if (level <= 15) {
      // Medium: smooth acceleration/deceleration.
      behavior = RotationBehavior.dynamic;
      baseSpeed = 1.6 + (level - 6) * 0.12; // grows gently
    } else {
      // Hard: random stop/accelerate/direction-flip state machine.
      behavior = RotationBehavior.hard;
      final clampedLevel = min(level, totalLevels);
      baseSpeed = 2.2 + (clampedLevel - 16) * 0.05; // grows slowly, capped
    }

    return LevelConfig(
      level: level,
      fruitAsset: fruit.asset,
      fruitName: fruit.name,
      arrowsRequired: arrowsRequired,
      rotationBehavior: behavior,
      baseRotationSpeed: baseSpeed,
      themeColor: fruit.color,
    );
  }
}

class _FruitDef {
  final String asset;
  final String name;
  final Color color;
  const _FruitDef(this.asset, this.name, this.color);
}

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Small factory helpers that build juicy `ParticleSystemComponent`s.
///
/// Kept as static builders (rather than a PositionComponent subclass)
/// because particle systems are self-removing/short-lived — there's no
/// need for persistent state or a component tree entry beyond the burst
/// itself.
class JuiceEffect {
  JuiceEffect._();

  static final Random _random = Random();

  /// Small "splash" burst played every time an arrow successfully sticks
  /// into the fruit. Spawns a handful of small circles that fly outward
  /// from [position] and fade out, tinted with the fruit's [color].
  static ParticleSystemComponent createHitSplash({
    required Vector2 position,
    required Color color,
    int particleCount = 14,
  }) {
    return ParticleSystemComponent(
      position: position,
      priority: 50,
      particle: Particle.generate(
        count: particleCount,
        lifespan: 0.6,
        generator: (i) {
          // Random direction & speed for each droplet.
          final angle = _random.nextDouble() * 2 * pi;
          final speed = 60 + _random.nextDouble() * 90;
          final velocity = Vector2(cos(angle), sin(angle)) * speed;

          // Slight per-particle color variance for a livelier splash.
          final variedColor = _varyColor(color);

          return AcceleratedParticle(
            acceleration: Vector2(0, 220), // gravity pulls droplets down
            speed: velocity,
            position: Vector2.zero(),
            child: CircleParticle(
              radius: 2.5 + _random.nextDouble() * 2.5,
              paint: Paint()..color = variedColor.withOpacity(0.9),
            ),
          );
        },
      ),
    );
  }

  /// Bigger "explosion" burst played when a fruit is fully cleared
  /// (all required arrows have been stuck) — simulates the fruit
  /// shattering into juice before the level transitions.
  static ParticleSystemComponent createFruitExplosion({
    required Vector2 position,
    required Color color,
    int particleCount = 40,
  }) {
    return ParticleSystemComponent(
      position: position,
      priority: 60,
      particle: Particle.generate(
        count: particleCount,
        lifespan: 0.9,
        generator: (i) {
          final angle = _random.nextDouble() * 2 * pi;
          final speed = 100 + _random.nextDouble() * 220;
          final velocity = Vector2(cos(angle), sin(angle)) * speed;
          final variedColor = _varyColor(color);

          return AcceleratedParticle(
            acceleration: Vector2(0, 300),
            speed: velocity,
            position: Vector2.zero(),
            child: ScalingCircleParticle(
              baseRadius: 3.0 + _random.nextDouble() * 4.0,
              color: variedColor,
            ),
          );
        },
      ),
    );
  }

  static Color _varyColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    final lightnessDelta = (_random.nextDouble() - 0.5) * 0.2;
    final newLightness =
        (hsl.lightness + lightnessDelta).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(newLightness).toColor();
  }
}

/// A small circle particle that shrinks to zero over its lifetime, giving
/// a nicer "pop" look than a static-size circle for the explosion burst.
class ScalingCircleParticle extends Particle {
  final double baseRadius;
  final Color color;

  ScalingCircleParticle({required this.baseRadius, required this.color});

  @override
  void render(Canvas canvas) {
    final t = progress.clamp(0.0, 1.0);
    final radius = baseRadius * (1 - t);
    if (radius <= 0) return;
    final paint = Paint()..color = color.withOpacity((1 - t).clamp(0.0, 1.0));
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}

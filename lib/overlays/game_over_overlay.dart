import 'package:flutter/material.dart';

import '../game/fruit_hit_game.dart';

/// Shown the instant an arrow collides with an already-stuck arrow.
/// Offers a single, obvious "Restart Level" action.
class GameOverOverlay extends StatelessWidget {
  final FruitHitGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.close_rounded, color: Colors.redAccent, size: 72),
          const SizedBox(height: 12),
          const Text(
            'GAME OVER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level ${game.currentLevelNumber} — ${game.currentLevelConfig.fruitName}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: game.restartLevel,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
            ),
            child: const Text(
              'RESTART LEVEL',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

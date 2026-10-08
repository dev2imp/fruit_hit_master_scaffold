import 'package:flutter/material.dart';

import '../game/fruit_hit_game.dart';

/// Shown once the required number of arrows has been successfully stuck
/// into the fruit and the fruit-explosion effect has played. Offers a
/// "Next Level" action that advances (and wraps back to level 1 after
/// level 50).
class LevelCompleteOverlay extends StatelessWidget {
  final FruitHitGame game;

  const LevelCompleteOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final isFinalLevel = game.currentLevelNumber >= 50;

    return Container(
      color: Colors.black.withOpacity(0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 80),
          const SizedBox(height: 12),
          Text(
            isFinalLevel ? 'ALL LEVELS CLEARED!' : 'LEVEL COMPLETE!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level ${game.currentLevelNumber} — ${game.currentLevelConfig.fruitName}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: game.goToNextLevel,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
            ),
            child: Text(
              isFinalLevel ? 'PLAY AGAIN' : 'NEXT LEVEL',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

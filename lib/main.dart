import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/fruit_hit_game.dart';
import 'overlays/game_over_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/level_complete_overlay.dart';
import 'services/points_service.dart'; // Yeni puan servisimizi ekledik
import 'package:google_mobile_ads/google_mobile_ads.dart';
Future<void> main() async {
  // Required before calling any Flutter/Flame engine APIs.
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  // Elmas veri tabanı hafızasını oyun başlamadan önce başlatıyoruz
  await PointsService.init();

  // Lock the game to portrait mode (typical for this type of casual game).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Go fully immersive: hide status bar & navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Flame.device.fullScreen();

  final game = FruitHitGame();

  // Letterbox / arka plan boşluklarında kullanılacak ortak renk —
  // BackgroundComponent içindeki _midColor ile aynı, böylece kenarlar
  // oyun içi gradyanla kaynaşıyor, siyah bant olarak görünmüyor.
  const letterboxColor = Color(0xFFFFDDB8);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fruit Hit Master',
      home: Scaffold(
        backgroundColor: letterboxColor,
        body: SafeArea(
          child: Column(
            children: [
              // Oyun Ekranı (Üst taraftan başlar ve kalan tüm alanı kaplar)
              Expanded(
                child: GameWidget<FruitHitGame>(
                  game: game,
                  overlayBuilderMap: {
                    'Hud': (context, FruitHitGame game) => HudOverlay(game: game),
                    'GameOver': (context, FruitHitGame game) =>
                        GameOverOverlay(game: game),
                    'LevelComplete': (context, FruitHitGame game) =>
                        LevelCompleteOverlay(game: game),
                  },
                  initialActiveOverlays: const ['Hud'],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
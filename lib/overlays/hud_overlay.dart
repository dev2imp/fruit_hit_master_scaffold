import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ads/rewarded_ad_service.dart';
import '../game/fruit_hit_game.dart';
import '../services/points_service.dart'; // Elmas verisini okumak için ekledik

/// Always-on top HUD, reskinned to the cozy-kitchen theme:
///  - top: wood "shelf" bar with level title + gem/diamond chip + fruit
///    name subtitle
///  - below that: a progress strip (dot row + "N left to shoot")
///  - bottom right: the rocket power-up button (functionality untouched,
///    recolored to wood/honey/terracotta)
///  - bottom right (while aiming): numbered target buttons, recolored to
///    match the honey/pepper-red palette instead of cyan
///
/// NOTE: the wood *counter* bar behind the jar/nocked-arrow at the bottom
/// of the screen is intentionally NOT painted here — those are Flame world
/// components (QuiverComponent / arrow) and this overlay renders on top of
/// the game canvas, so a solid bar here would cover them. That bar belongs
/// in BackgroundComponent instead.
class HudOverlay extends StatefulWidget {
  final FruitHitGame game;

  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // ---- Cozy kitchen palette ----
  static const _woodDark = Color(0xFF3E2723);
  static const _woodMid = Color(0xFF6B4423);
  static const _honey = Color(0xFFE3A93B);
  static const _honeyLight = Color(0xFFF0C878);
  static const _tan = Color(0xFFD8B98A);
  static const _pepperRed = Color(0xFFC1440E);

  @override
  void initState() {
    super.initState();
    // A cheap repaint ticker guarantees the overlay stays in sync with game
    // state and local diamond storage numbers perfectly without extra plumbing.
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final config = game.currentLevelConfig;
    final totalArrows = config.arrowsRequired;
    final stuck = game.arrowsStuckCount;
    final remaining = game.arrowsRemainingToShoot;

    // Yerel hafızadaki güncel elmas puanını çekiyoruz
    final currentDiamonds = PointsService.getDiamonds();
    final canActivateGuided = currentDiamonds >= 2 && game.state == GameState.playing;
    final isGuiding = game.isGuidedModeActive;

    //popup for add watch
    void _showNoDiamondsDialog() {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4A2F22), _woodDark],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _honey, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍯', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const Text(
                    'Yetersiz Elmas!',
                    style: TextStyle(
                      color: _honeyLight,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Güdümlü ok için en az 2 elmas gerekir.\n'
                        'Kısa bir reklam izle, 10 elmas (5 roket hakkı) kazan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _tan, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text(
                            'Vazgeç',
                            style: TextStyle(color: _tan, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _honey,
                            foregroundColor: _woodDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text(
                            'Reklam izle +10',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();

                            final shown = RewardedAdService.instance.show(
                              onReward: () async {
                                await PointsService.addDiamonds(10);
                              },
                            );

                            if (!shown && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reklam henüz hazır değil, birazdan tekrar dene',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return Stack(
      children: [
        // 1. KATMAN: Ahşap raf (shelf) + ilerleme şeridi
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // --- Wood shelf bar ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4A2F22), _woodDark, Color(0xFF2C1C14)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'LEVEL ${game.currentLevelNumber}',
                            style: const TextStyle(
                              color: _honeyLight,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2))],
                            ),
                          ),
                          // Gem / diamond chip
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF5A3826), Color(0xFF432616)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF7A4F30), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🍯', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 6),
                                Text(
                                  '$currentDiamonds',
                                  style: const TextStyle(
                                    color: _honeyLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        config.fruitName,
                        style: const TextStyle(
                          color: _tan,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Progress strip (dots + "N left to shoot") ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2C1C14), Color(0xFFEFDCC0)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(totalArrows, (i) {
                          final isStuck = i < stuck;
                          return _ArrowPip(filled: isStuck);
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$remaining left to shoot',
                        style: const TextStyle(
                          color: Color(0xFF7A5A3A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. KATMAN: NİŞAN MODUNDA 1 / 2 / 3 HEDEF BUTONLARI
        // Meyve dönerken doğru noktaya dokunmak zor olabildiği için,
        // kullanıcı bunun yerine doğrudan numaralı butona basarak hedefi
        // seçebilir. Sadece isGuidedModeActive true iken görünür.
        if (isGuiding)
          Positioned(
            bottom: 150,
            right: 14,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(game.guidedTargetCount, (i) {
                  final number = i + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TargetNumberButton(
                      number: number,
                      onTap: () => game.selectGuidedTargetByNumber(number),
                    ),
                  );
                }),
              ),
            ),
          ),

        // 3. KATMAN: SAĞ ALT GÜDÜMLÜ FÜZE (ROKET) BUTONU
        Positioned(
          bottom: 75,
          right: 20,
          child: SafeArea(
            child: _MissileButton(
              enabled: canActivateGuided,
              active: isGuiding,
              onPressed: () {
                if (isGuiding) return; // nişan alırken tekrar tetiklenmesin
                if (game.state != GameState.playing) return;

                if (currentDiamonds >= 2) {
                  game.activateGuidedMode();
                } else {
                  _showNoDiamondsDialog();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Meyve üzerindeki numaralı hedef noktalarına karşılık gelen dairesel
/// buton. Artık cyan yerine bal/pepper-red temasıyla eşleşiyor.
class _TargetNumberButton extends StatelessWidget {
  final int number;
  final VoidCallback onTap;

  const _TargetNumberButton({required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3E2723),
            border: Border.all(color: const Color(0xFFF0C878), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE3A93B).withOpacity(0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Color(0xFFF0C878),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gerçek bir füze/roket fırlatma butonu — artık ahşap gövde + bal camı +
/// terracotta alev ile mockup'taki roket ikonuna uyumlu.
class _MissileButton extends StatelessWidget {
  final bool enabled;
  final bool active;
  final VoidCallback onPressed;

  const _MissileButton({
    required this.enabled,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = active
        ? const Color(0xFFC1440E)
        : (enabled ? const Color(0xFFE3A93B) : Colors.transparent);

    return Opacity(
      opacity: enabled || active ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFF0C878), Color(0xFFB5791D)],
            ),
            border: Border.all(
              color: active ? const Color(0xFFC1440E) : const Color(0xFF7A4F11),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A5A12),
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: glowColor.withOpacity(0.55),
                blurRadius: 16,
                spreadRadius: active ? 4 : 2,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _MissileIconPainter(active: active),
          ),
        ),
      ),
    );
  }
}

class _MissileIconPainter extends CustomPainter {
  final bool active;
  _MissileIconPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final bodyPaint = Paint()..color = const Color(0xFF4A2C18);
    final windowColor = const Color(0xFFF0C878);
    final finPaint = Paint()..color = const Color(0xFF3E2723);

    // Gövde (dikdörtgen — rocket body)
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -6, 12, 26),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Burun konisi
    final nosePath = Path()
      ..moveTo(-8, -6)
      ..lineTo(8, -6)
      ..lineTo(0, -22)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFF4A2C18));

    // Küçük yuvarlak pencere
    canvas.drawCircle(const Offset(0, 4), 3, Paint()..color = windowColor);

    // Sol kanatçık
    final leftFin = Path()
      ..moveTo(-6, 12)
      ..lineTo(-16, 22)
      ..lineTo(-6, 18)
      ..close();
    canvas.drawPath(leftFin, finPaint);

    // Sağ kanatçık
    final rightFin = Path()
      ..moveTo(6, 12)
      ..lineTo(16, 22)
      ..lineTo(6, 18)
      ..close();
    canvas.drawPath(rightFin, finPaint);

    // Terracotta alev
    final flamePath = Path()
      ..moveTo(-4, 18)
      ..lineTo(4, 18)
      ..lineTo(0, 28)
      ..close();
    canvas.drawPath(
      flamePath,
      Paint()..color = active ? const Color(0xFFC1440E) : const Color(0xFFC1440E).withOpacity(0.55),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MissileIconPainter oldDelegate) =>
      oldDelegate.active != active;
}

class _ArrowPip extends StatelessWidget {
  final bool filled;
  const _ArrowPip({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled
            ? const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFF3D48A), Color(0xFFE3A93B), Color(0xFFB8791F)],
          stops: [0.0, 0.6, 1.0],
        )
            : null,
        color: filled ? null : const Color(0xFFE7D3AE),
        border: Border.all(
          color: filled ? const Color(0xFFB8791F) : const Color(0xFFC9A877),
          width: 1.5,
        ),
        boxShadow: filled
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
    );
  }
}
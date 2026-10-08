import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  static final String _adUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Google test ID
      : 'ca-app-pub-1991602581634793/2204975944'; // Gerçek ID

  RewardedAd? _ad;
  bool _loading = false;

  bool get isReady => _ad != null;

  void load() {
    if (_loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
          debugPrint('Reklam yüklenemedi: $error');
        },
      ),
    );
  }

  /// Reklam hazırsa gösterir ve true döner, değilse yeniden yükler ve false döner.
  bool show({required VoidCallback onReward}) {
    final ad = _ad;
    if (ad == null) {
      load();
      return false;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        load();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onReward());
    return true;
  }
}
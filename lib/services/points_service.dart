import 'package:shared_preferences/shared_preferences.dart';

class PointsService {
  static const String _keyDiamonds = 'user_diamonds_count';
  static const int maxDiamonds = 15;
  //later we will change to 10
  static const int defaultDiamonds = 4;

  static SharedPreferences? _prefs;

  // Uygulama başlarken hafızayı yükler
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Eğer telefonda hiç veri yoksa ilk açılışa özel 10 elmas tanımlar
    if (_prefs!.get(_keyDiamonds) == null) {
      await _prefs!.setInt(_keyDiamonds, defaultDiamonds);
    }
  }

  // Mevcut elmas sayısını getirir
  static int getDiamonds() {
    return _prefs?.getInt(_keyDiamonds) ?? defaultDiamonds;
  }

  // Puan harcama kontrolü (Güdümlü ok için 2 elmas keser)
  static Future<bool> spendDiamonds(int amount) async {
    final current = getDiamonds();
    if (current >= amount) {
      final newValue = current - amount;
      await _prefs!.setInt(_keyDiamonds, newValue);
      return true; // Harcama başarılı
    }
    return false; // Elmas yetersiz
  }

  // Elmas ekleme fonksiyonu (Daha sonra eklenecek ödüllü reklam veya ödüller için hazır)
  static Future<bool> addDiamonds(int amount) async {
    final current = getDiamonds();
    if (current >= maxDiamonds) return false; // Sınır doldu, daha fazla ekleme yapma

    int newValue = current + amount;
    if (newValue > maxDiamonds) {
      newValue = maxDiamonds; // Taşmayı önle, sınıra sabitle
    }

    await _prefs!.setInt(_keyDiamonds, newValue);
    return true;
  }
}

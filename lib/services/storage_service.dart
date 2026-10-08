import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Seviye bilgisini telefona kalıcı olarak kaydeder
  static Future<void> saveLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_fruit_hit_level', level);
  }

  // Telefondan kayıtlı olan seviyeyi yükler (Kayıt yoksa 1 döner)
  static Future<int> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('saved_fruit_hit_level') ?? 1;
  }
}

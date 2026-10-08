import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/text.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../components/missile_component.dart';
import '../components/arrow_component.dart';
import '../components/background_component.dart';
import '../components/fruit_component.dart';
import '../components/juice_particle.dart';
import '../services/storage_service.dart';
import '../services/points_service.dart';
import 'level_config.dart';
import '../components/quiver_component.dart';

enum GameState { playing, levelComplete, gameOver }

class FruitHitGame extends FlameGame
    with HasCollisionDetection, TapDetector {
  static final Vector2 designSize = Vector2(480, 854);

  FruitHitGame()
      : super(
    camera: CameraComponent.withFixedResolution(
      width: 480,
      height: 854,
    ),
  );

  int currentLevelNumber = 1;
  late LevelConfig currentLevelConfig;

  int arrowsRemainingToShoot = 0;
  int arrowsStuckCount = 0;

  GameState state = GameState.playing;

  bool isGuidedModeActive = false;
  final List<PositionComponent> _activeReticles = [];

  // --- Güdümlü Uçuş Animasyon Değişkenleri ---
  ArrowComponent? _guidedFlyingArrow;
  Vector2? _guidedTargetWorldPos;
  double _guidedFlightProgress = 0.0;
  Vector2? _guidedStartPos;
  Vector2? _guidedControlPoint; // Kusursuz sağ/sol yay kontrol noktası
  PositionComponent? _selectedXReticle; // Kilitlenen X işareti reference'ı

  // Nişan alma / güdümlü mod sırasında hazır okun üzerine binen görsel
  // "füze" bileşeni. Ok'un child'ı olduğu için ok hareket ettikçe (bezier
  // uçuşu dahil) otomatik olarak onunla birlikte hareket eder.
  PositionComponent? _missileMarker;

  final List<ArrowComponent> _magazineArrows = [];
  QuiverComponent? _quiver;
  QuiverFrontRim? _quiverFrontRim;
  ArrowComponent? _readyArrow;

  FruitComponent? _fruit;
  late BackgroundComponent _background;

  late final AudioPool _hitSoundPool;
  late final AudioPool _missileLaunchPool;
  late final AudioPool _impactHitPool;
  late final AudioPool _arrowReleasePool;

  Vector2 get _quiverPosition => Vector2(85, designSize.y - 100);
  Vector2 get _quiverMouthPoint => _quiverPosition + Vector2(-46, 46);

  Vector2 get _arrowSpawnPoint =>
      Vector2(designSize.x / 2, designSize.y - 120);

  Vector2 get _fruitCenter => Vector2(designSize.x / 2, designSize.y * 0.38);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.topLeft;

    _hitSoundPool = await FlameAudio.createPool(
      'cik.mp3',
      minPlayers: 1,
      maxPlayers: 2,
    );

    _missileLaunchPool = await FlameAudio.createPool(
      '1_missile_launch.mp3',
      minPlayers: 1,
      maxPlayers: 1,
    );

    _impactHitPool = await FlameAudio.createPool(
      '3_impact_hit.mp3',
      minPlayers: 1,
      maxPlayers: 2,
    );

    _arrowReleasePool = await FlameAudio.createPool(
      '4_arrow_release.mp3',
      minPlayers: 1,
      maxPlayers: 2,
    );

    _background = BackgroundComponent(size: designSize.clone());
    world.add(_background);

    final savedLevel = await StorageService.loadLevel();
    currentLevelNumber = savedLevel;

    _startLevel(currentLevelNumber);

    overlays.add('Hud');
  }

  void _startLevel(int levelNumber) {
    currentLevelConfig = LevelConfigProvider.getLevel(levelNumber);
    arrowsRemainingToShoot = currentLevelConfig.arrowsRequired;
    arrowsStuckCount = 0;
    state = GameState.playing;
    isGuidedModeActive = false;
    _guidedFlyingArrow = null;
    _guidedTargetWorldPos = null;
    _selectedXReticle = null;
    _missileMarker = null;
    _clearReticles();

    _spawnFruit();
    _buildMagazine();
  }

  Future<void> _spawnFruit() async {
    final fruitSize = Vector2.all(220);

    final fruit = FruitComponent(
      levelConfig: currentLevelConfig,
      position: _fruitCenter,
      size: fruitSize,
    );
    _fruit = fruit;
    world.add(fruit);
  }
  void _buildMagazine() {
    for (var arrow in _magazineArrows) {
      arrow.removeFromParent();
    }
    _magazineArrows.clear();
    _readyArrow?.removeFromParent();
    _readyArrow = null;

    if (arrowsRemainingToShoot <= 0) {
      _quiver?.removeFromParent();
      _quiver = null;
      return;
    }

    _quiver ??= QuiverComponent(position: _quiverPosition);
    if (_quiver!.parent == null) {
      world.add(_quiver!);
    }

    _quiverFrontRim ??= QuiverFrontRim(position: _quiverPosition);
    if (_quiverFrontRim!.parent == null) {
      world.add(_quiverFrontRim!);
    }
    _readyArrow = ArrowComponent(
      startPosition: _arrowSpawnPoint.clone(),
      state: ArrowState.inMagazine,
    );
    world.add(_readyArrow!);

    final totalRemainingInMag = arrowsRemainingToShoot - 1;

    for (int i = 0; i < totalRemainingInMag; i++) {
      final magArrow = ArrowComponent(
        startPosition: Vector2.zero(), // gerçek konum layout fonksiyonunda verilecek
        state: ArrowState.inMagazine,
      );

      _magazineArrows.add(magArrow);
      world.add(magArrow);
    }

    _layoutMagazineFan();
  }

  /// Sadaktaki okları düz sıra yerine, kılıfın ağzından çıkıyormuş gibi
  /// hafif açılı bir yelpaze düzeninde diziyor.
  void _layoutMagazineFan() {
    final count = _magazineArrows.length;
    if (count == 0) return;

    const angleStep = 0.08; // her ok arasındaki açı farkı (radyan)
    const xSpacing = 1.0;   // uçların yatayda ne kadar ayrılacağı
    final mouth = _quiverMouthPoint;

    for (int i = 0; i < count; i++) {
      final centered = i - (count - 1) / 2;
      final arrow = _magazineArrows[i];
      arrow.position = mouth + Vector2(centered * xSpacing, 0);
      arrow.angle =math.pi + (centered * angleStep); // baş aşağı + yelpaze açısı
    }
  }

  void _advanceMagazine() {
    if (_magazineArrows.isEmpty) {
      _readyArrow = null;
      _quiver?.removeFromParent();
      _quiver = null;
      _quiverFrontRim?.removeFromParent();
      _quiverFrontRim = null;
      return;
    }

    final nextArrow = _magazineArrows.removeAt(0);
    nextArrow.position = _arrowSpawnPoint.clone();
    nextArrow.angle = 0;
    nextArrow.scale = Vector2(1.0, 1.0);
    nextArrow.state = ArrowState.inMagazine;
    _readyArrow = nextArrow;

    _layoutMagazineFan();
  }

  void activateGuidedMode() {
    if (state != GameState.playing || isGuidedModeActive) return;
    if (_readyArrow == null || arrowsRemainingToShoot <= 0) return;

    final anyFlying = world.children
        .whereType<ArrowComponent>()
        .any((a) => a.state == ArrowState.flying || _guidedFlyingArrow != null);
    if (anyFlying) return;

    isGuidedModeActive = true;
    _spawnTargetReticles();

    // Hazır okun üzerine görsel füze biniyor; ok fırlatılana veya nişan
    // iptal olana kadar okla birlikte görünür kalır.
    _missileMarker?.removeFromParent();
    _missileMarker = _buildMissileMarker();
    _readyArrow!.add(_missileMarker!);
  }

  /// Hud'daki 1/2/3 numaralı butonların çağıracağı public API. Kullanıcı
  /// dönen meyve üzerindeki noktaya dokunmakta zorlanıyorsa, bunun yerine
  /// doğrudan numarayla hedef seçebilir. number 1 tabanlıdır (1, 2, 3...).
  void selectGuidedTargetByNumber(int number) {
    if (!isGuidedModeActive) return;
    final index = number - 1;
    if (index < 0 || index >= _activeReticles.length) return;
    _launchGuidedArrow(_activeReticles[index]);
  }

  /// Hud'un kaç numaralı buton göstereceğini bilmesi için (şu an sabit 3).
  int get guidedTargetCount => _activeReticles.length;

  void _spawnTargetReticles() {
    _clearReticles();
    if (_fruit == null) return;

    final random = math.Random();
    final radius = 110.0;

    for (int i = 0; i < 3; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final localPos = Vector2(math.cos(angle), math.sin(angle)) * radius;

      final reticle = CircleComponent(
        radius: 12,
        position: localPos + Vector2(110, 110),
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      // Nokta üzerine 1/2/3 etiketi: fruit dönerken de noktayla birlikte
      // döner, böylece kullanıcı hangi butonun hangi noktaya karşılık
      // geldiğini görebilir.
      final label = TextComponent(
        text: '${i + 1}',
        anchor: Anchor.center,
        position: Vector2.zero(),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      reticle.add(label);

      _activeReticles.add(reticle);
      _fruit!.add(reticle);
    }
  }

  /// Basit şekillerden oluşan bir "füze" görseli — kılavuz mod aktifken
  /// hazır okun üzerine biniyor ve ok fırlatıldığında onunla birlikte uçuyor.
  /// NOT: (0, -70) ofseti, oku görmeden tahmini verildi — kendi
  /// ArrowComponent'inizin boyutuna/anchor'una göre bu değeri ayarlamanız
  /// gerekebilir ki füze tam okun ucuna otursun.
  PositionComponent _buildMissileMarker() {
     return MissileComponent(position: Vector2(0, 40));
  }

  void _clearReticles() {
    for (var r in _activeReticles) {
      if (r != _selectedXReticle) {
        r.removeFromParent();
      }
    }
    _activeReticles.clear();
  }

  void _clearBoard() {
    _fruit?.removeFromParent();
    _fruit = null;
    _quiver?.removeFromParent();
    _quiver = null;
    _quiverFrontRim?.removeFromParent();
    _quiverFrontRim = null;

    world.children.whereType<ArrowComponent>().toList().forEach(
          (arrow) => arrow.removeFromParent(),
    );

    _magazineArrows.clear();
    _readyArrow = null;
    _selectedXReticle?.removeFromParent();
    _selectedXReticle = null;
    _clearReticles();
    _guidedFlyingArrow = null;
    _guidedTargetWorldPos = null;
    _missileMarker = null;
  }

  void restartLevel() {
    overlays.remove('GameOver');
    _clearBoard();
    _startLevel(currentLevelNumber);
  }

  void goToNextLevel() {
    overlays.remove('LevelComplete');
    _clearBoard();
    final next = currentLevelNumber >= LevelConfigProvider.totalLevels
        ? 1
        : currentLevelNumber + 1;
    currentLevelNumber = next;

    StorageService.saveLevel(currentLevelNumber);
    _startLevel(currentLevelNumber);
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);

    if (isGuidedModeActive) {
      _handleGuidedTargetTap(info.eventPosition.global);
      return;
    }

    _shootArrow();
  }

  void _handleGuidedTargetTap(Vector2 clickGlobalPos) {
    PositionComponent? clickedReticle;
    double minDistance = 50.0;

    for (var reticle in _activeReticles) {
      final reticleWorldPos = reticle.absolutePosition;
      final dist = reticleWorldPos.distanceTo(clickGlobalPos);
      if (dist < minDistance) {
        clickedReticle = reticle;
        break;
      }
    }

    if (clickedReticle != null) {
      _launchGuidedArrow(clickedReticle);
    }
  }

  Future<void> _launchGuidedArrow(PositionComponent reticleComponent) async {
    final success = await PointsService.spendDiamonds(2);
    if (!success) {
      isGuidedModeActive = false;
      _clearReticles();
      _missileMarker?.removeFromParent();
      _missileMarker = null;
      return;
    }

    isGuidedModeActive = false;

    // YENİLİK 2: Seçilen noktayı Kırmızı X işaretine dönüştürme mantığı
    _selectedXReticle = reticleComponent;
    if (_selectedXReticle is CircleComponent) {
      // Çember stilini silip kırmızı bir çarpı (X) görünümü veriyoruz
      (_selectedXReticle as CircleComponent).paint.color = Colors.redAccent;
      (_selectedXReticle as CircleComponent).paint.style = PaintingStyle.fill;
    }

    // Seçilmeyen diğer 2 hedef çemberini temizliyoruz
    _clearReticles();

    if (_readyArrow == null || state != GameState.playing) return;

    arrowsRemainingToShoot--;

    _arrowReleasePool.start();
    _missileLaunchPool.start();

    // Dinamik anlık hedef konumunu kilitliyoruz
    final targetWorldPos = reticleComponent.absolutePosition.clone();

    _guidedStartPos = _arrowSpawnPoint.clone();
    _guidedTargetWorldPos = targetWorldPos;
    _guidedFlightProgress = 0.0;

    // DÜZELTME: Kontrol noktasını, meyve merkezinden hedefe uzanan
    // doğrultunun DIŞINA (hedefin ötesine) yerleştiriyoruz. Quadratic
    // Bezier'in matematiği gereği bu, eğrinin hedefe varan son teğetinin
    // KESİNLİKLE bu radyal doğrultuya paralel olmasını garanti eder —
    // yani ok her zaman yüzeye dik (perpendicular) saplanır.
    final outwardNormal = (targetWorldPos - _fruitCenter).normalized();
    const approachOffset = 140.0; // eğrinin ne kadar "kavis" yapacağını belirler

    _guidedControlPoint = targetWorldPos + outwardNormal * approachOffset;

    _guidedFlyingArrow = _readyArrow;
    _guidedFlyingArrow!.state = ArrowState.flying;

    // DÜZELTME: Güdümlü uçuş süresince ArrowComponent'in KENDİ iç
    // çarpışma/fizik mantığının bu oku "sekme" efektiyle ekrandan
    // fırlatmasını önlemek için çarpışma kutularını devre dışı
    // bırakıyoruz. Konumu artık tamamen bizim bezier döngümüz kontrol
    // ediyor, Flame'in kendi collision resolve mantığı devreye girmemeli.
    for (final hitbox
    in _guidedFlyingArrow!.children.whereType<ShapeHitbox>()) {
      hitbox.collisionType = CollisionType.inactive;
    }

    _advanceMagazine();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Kavisli füze takip döngüsü
    if (_guidedFlyingArrow != null &&
        _guidedTargetWorldPos != null &&
        _guidedStartPos != null &&
        _guidedControlPoint != null) {
      // FIX 3: Kırmızı X işareti meyvenin child'ı olduğu için meyve
      // dönerken o da dönüyor. Hedefi sadece fırlatma anında DONDURUP
      // kullanmaya devam edersek, ok uçuş sırasında meyvenin döndüğü
      // kadar "geride kalmış" bir noktaya varır — yani kullanıcının
      // seçtiği yer değil, o anda dokunduğu (artık eskimiş) yere saplanır.
      // Bunu önlemek için hedefin dünya konumunu HER KAREDE yeniden
      // örnekliyoruz, böylece ok her zaman işaretin GÜNCEL konumunu
      // takip edip tam üstüne iniyor.
      if (_selectedXReticle != null && _selectedXReticle!.isMounted) {
        final liveTarget = _selectedXReticle!.absolutePosition;
        _guidedTargetWorldPos = liveTarget;

        final outwardNormal = (liveTarget - _fruitCenter).normalized();
        const approachOffset = 140.0;
        _guidedControlPoint = liveTarget + outwardNormal * approachOffset;
      }

      // Uçuş süresi 0.5 saniye olarak optimize edildi (Kavisin net görünmesi için)
      _guidedFlightProgress += dt / 0.5;

      if (_guidedFlightProgress >= 1.0) {
        final rawTarget = _guidedTargetWorldPos!;

        // FIX 4: Ok, meyve yüzeyine sadece "değmiş" gibi değil, birkaç
        // piksel daha GÖMÜLÜ görünsün diye hedefi merkeze doğru azıcık
        // içeri kaydırıyoruz. Bu kaydırma, kullanıcının seçtiği noktayı
        // DEĞİŞTİRMEZ — sadece görsel saplanma derinliğini ayarlar.
        final embedNormal = (rawTarget - _fruitCenter).normalized();
        const embedDepth = 14.0;
        final finalPos = rawTarget - embedNormal * embedDepth;

        final stuckArrow = _guidedFlyingArrow!;

        // Füze görseli sadece uçuş sırasında görünür; saplandıktan sonra
        // normal ok görünümüne dönüyoruz.
        _missileMarker?.removeFromParent();
        _missileMarker = null;

        stuckArrow.position = finalPos;

        // FIX: Normal (güdümsüz) atışlarda ok, meyveyle çarpıştığında
        // kendi çarpışma callback'i üzerinden state'ini "stuck" yapıp
        // yerinde sabit kalıyor. Güdümlü uçuşta hitbox'ları bilerek
        // inactive yaptığımız için o callback HİÇBİR ZAMAN tetiklenmiyor
        // ve ok "flying" state'inde asılı kalıyor — bu yüzden ok az
        // sonra kayboluyor / yerinde durmuyordu. Burada elle aynı
        // "stuck" state geçişini yaparak oku kalıcı biçimde sabitliyoruz.
        stuckArrow.state = ArrowState.stuck;

        // FIX 2: Normal oklar çarpışma anında meyvenin child'ı olarak
        // yeniden ebeveynleniyor olmalı ki meyve dönerken/hareket ederken
        // onunla birlikte dönsün. Güdümlü ok şu ana kadar world'ün child'ı
        // olarak kalıyordu, bu yüzden meyveyle birlikte spin olmuyordu.
        // Burada world konumunu/açısını meyvenin local uzayına çevirip
        // oku meyveye child olarak taşıyoruz; böylece görsel olarak aynı
        // noktada kalırken artık meyvenin rotasyonunu miras alıyor.
        final fruit = _fruit;
        if (fruit != null) {
          final localPos = fruit.absoluteToLocal(finalPos);
          final localAngle = stuckArrow.angle - fruit.angle;

          stuckArrow.removeFromParent();
          stuckArrow.position = localPos;
          stuckArrow.angle = localAngle;
          fruit.add(stuckArrow);
        }

        _guidedFlyingArrow = null;
        _guidedTargetWorldPos = null;
        _guidedControlPoint = null;

        // Çarpışma anında Kırmızı X işareti imha edilir
        _selectedXReticle?.removeFromParent();
        _selectedXReticle = null;

        onArrowStuck(finalPos);
      } else {
        final start = _guidedStartPos!;
        final target = _guidedTargetWorldPos!;
        final control = _guidedControlPoint!;

        // Quadratic Bezier Formülü ile meyvenin etrafından dolaşan rotayı çiziyoruz
        final t = _guidedFlightProgress;
        final x = (1 - t) * (1 - t) * start.x +
            2 * (1 - t) * t * control.x +
            t * t * target.x;
        final y = (1 - t) * (1 - t) * start.y +
            2 * (1 - t) * t * control.y +
            t * t * target.y;

        final nextPos = Vector2(x, y);

        // Okun burnunun uçtuğu yöne (hedefe) doğru bakmasını sağlayan rotasyon açısı
        final angle =
            math.atan2(target.y - nextPos.y, target.x - nextPos.x) +
                (math.pi / 2);

        _guidedFlyingArrow!.position = nextPos;
        _guidedFlyingArrow!.angle = angle;
      }
    }
  }

  void _shootArrow() {
    if (state != GameState.playing || _guidedFlyingArrow != null) return;
    if (_readyArrow == null || arrowsRemainingToShoot <= 0) return;

    final anyFlying = world.children
        .whereType<ArrowComponent>()
        .any((a) => a.state == ArrowState.flying);
    if (anyFlying) return;

    arrowsRemainingToShoot--;

    _arrowReleasePool.start();
    _readyArrow!.shoot();

    _advanceMagazine();
  }

  void onArrowStuck(Vector2 worldImpactPoint) {
    if (state != GameState.playing) return;

    arrowsStuckCount++;

    _impactHitPool.start();

    world.add(
      JuiceEffect.createHitSplash(
        position: worldImpactPoint,
        color: currentLevelConfig.themeColor,
      ),
    );

    if (arrowsStuckCount >= currentLevelConfig.arrowsRequired) {
      _completeLevel();
    }
  }

  void onArrowCollision() {
    if (state != GameState.playing) return;

    state = GameState.gameOver;
    overlays.add('GameOver');
  }

  void _completeLevel() {
    state = GameState.levelComplete;

    final fruit = _fruit;
    if (fruit != null) {
      world.add(
        JuiceEffect.createFruitExplosion(
          position: fruit.worldCenter,
          color: currentLevelConfig.themeColor,
        ),
      );
      fruit.removeFromParent();
      _fruit = null;
    }

    _selectedXReticle?.removeFromParent();
    _selectedXReticle = null;

    overlays.add('LevelComplete');
  }
}
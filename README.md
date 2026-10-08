# Fruit Hit Master 🎯🍉

A casual 2D fruit-shooting game (Twisty Arrow / Knife Hit style) built with
**Flutter** + **Flame**. Tap to shoot arrows into a rotating fruit — avoid
hitting arrows you've already stuck in, clear 50 progressively harder
levels.

- **Android package (Bundle ID):** `com.devos.fruithitmaster`
- **Engine:** Flame ^1.18.0 (`flame_audio` ^2.1.0 for SFX)

---

## Quick Start

1. Make sure Flutter is installed (`flutter doctor`).
2. From the project root:
   ```bash
   flutter pub get
   flutter run
   ```
3. To build a release APK:
   ```bash
   flutter build apk --release
   ```

The project already builds and runs out of the box — placeholder fruit
artwork (`assets/images/fruits/*.png`) and a placeholder hit sound
(`assets/audio/cik.mp3`) are included so there's nothing missing. **Swap
in your real art/audio** at any time; filenames are already wired up in
`pubspec.yaml` and `lib/game/level_config.dart`.

---

## Project Structure

```
lib/
├── main.dart                       # App entrypoint, overlays, fullscreen/orientation setup
├── game/
│   ├── fruit_hit_game.dart         # Core FlameGame: state machine, spawning, input, level flow
│   └── level_config.dart           # 50-level progression data (difficulty, arrow count, fruit)
├── components/
│   ├── fruit_component.dart        # Rotating fruit: 3-tier rotation behavior + 85% hitbox
│   ├── arrow_component.dart        # Flying/stuck arrow, collision handling
│   ├── juice_particle.dart         # Hit-splash & fruit-explosion particle bursts
│   └── background_component.dart   # Simple gradient backdrop
└── overlays/
    ├── hud_overlay.dart            # Level number, fruit name, arrow pips
    ├── game_over_overlay.dart      # "Restart Level" screen
    └── level_complete_overlay.dart # "Next Level" screen
```

## Gameplay / Difficulty Curve

| Levels | Rotation Behavior | Description |
|--------|-------------------|--------------|
| 1–5    | `constant`        | Fixed speed, single direction — onboarding |
| 6–15   | `dynamic`         | Smooth sine-driven acceleration/deceleration, direction locked |
| 16–50  | `hard`             | Random stop/ramp/direction-reversal state machine |

Arrows required per level scales linearly from **4 → 12** across the 50
levels (`level_config.dart`, `arrowsRequired`).

## Key Implementation Details

- **Visual depth trick:** the fruit's `CircleHitbox` radius is set to 85%
  of the sprite's visual radius (`fruit_component.dart`), so arrows visibly
  "sink into" the flesh rather than stopping at the image edge.
- **Reparenting on stick:** when an arrow collides with the fruit, it's
  converted from world-space to the fruit's local coordinate space and
  added as a *child* of `FruitComponent` — it then rotates perfectly with
  the fruit for free, no manual per-frame syncing needed.
- **Arrow-vs-arrow collisions:** stuck arrows keep a `passive`
  `RectangleHitbox` so future flying arrows can still detect them and
  trigger game over.
- **One arrow in flight at a time** — classic Knife-Hit fairness rule,
  enforced in `FruitHitGame._shootArrow()`.
- **Fixed-resolution camera** (`480×854`) keeps gameplay layout consistent
  across all device aspect ratios — all world positions are expressed in
  this design-space, not raw device pixels (see `designSize` in
  `fruit_hit_game.dart`).

## Swapping In Real Assets

Replace any file under `assets/images/fruits/` with real artwork (keep the
same filename, ideally square, transparent PNG, ~256×256 or larger) and
replace `assets/audio/cik.mp3` with your real hit SFX. No code changes
needed — `pubspec.yaml` and `level_config.dart` already reference exactly
these 16 filenames, cycled across all 50 levels. Add more filenames to the
`_fruitPool` list in `level_config.dart` (and to `pubspec.yaml`'s asset
list) any time to reduce repetition.

## Notes on the Android Bundle ID

`com.devos.fruithitmaster` is set in three places — already done for you:
- `android/app/build.gradle` (`namespace` + `applicationId`)
- `android/app/src/main/AndroidManifest.xml` (`package`)
- `android/app/src/main/kotlin/com/devos/fruithitmaster/MainActivity.kt`
  (Kotlin `package` declaration + folder path)

If you ever rename the package, all three must be updated together (and
the `MainActivity.kt` folder path must match).

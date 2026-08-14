# AGENTS.md

Instructions for AI agents (and humans) working in this repository.

## What this is

`tessera` — a Flutter match-3 game shipped as **Tessera** by VibeByteForge. Swap adjacent
tiles, line up three or more, collect them. Three game modes, three procedurally-drawn skins,
no backend.

The Dart package, the Android `applicationId`, the iOS bundle id and the Windows binary are all
`tessera` / `com.vibebyteforge.tessera`. Anything still saying `collect_three` is stale.

Read before touching code:

- [`docs/CONCEPT.md`](docs/CONCEPT.md) — rules, modes, scoring, scope
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — layering and module map
- [`docs/SKINS.md`](docs/SKINS.md) — skin contract and palettes
- [`docs/TASKS.md`](docs/TASKS.md) — the task board; keep statuses current

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/engine/          # fast: pure-Dart rules only
flutter test test/skins/          # skin contract (palettes, painters)
flutter test test/levels/         # re-proves every shipped level is solvable
flutter run -d chrome             # or -d windows / -d <device>

# On-device: drives the real app with real gestures
flutter test integration_test -d windows
flutter test integration_test -d <device-id>      # flutter devices for ids

# Regenerate the Clear the Board pack (only ships layouts the solver beat)
dart run tool/generate_levels.dart --count 30 --out assets/levels/pack_01.json
```

`flutter analyze` and `flutter test` must both be clean before any change is considered done.

## The one rule that matters most

**`lib/engine/` is pure Dart.** It must never import `package:flutter/*`, `dart:ui`, or any
plugin. No `Color`, no `Widget`, no `DateTime.now()`, no `Random()` without a seed. All game
rules live there so they can be tested headlessly and reused by every mode.

`test/engine/purity_test.dart` enforces this. If it fails, the fix is to move the offending
code up a layer — never to weaken the test.

## Layering

```
ui/  →  skins/  →  game/  →  services/  →  engine/
```

Dependencies point right/down only. In particular: `engine/` knows nothing about anything
else, and `game/` (controllers) is the only place allowed to translate engine events into
animation.

## Conventions

- **Determinism.** Everything random goes through `SeededRandom`. A game is reproducible from
  `(seed, mode, move list)`. Never call `DateTime.now()` inside `engine/`.
- **Tile identity.** `Tile.id` is stable for the lifetime of a tile and is what the UI animates.
  Never recreate a tile that merely moved.
- **Events describe animation.** `Resolver` emits an ordered list of `BoardEvent`s that fully
  describes what happened. UI replays them; it never re-derives game state.
- **Board values.** Board mutations return a new `Board`. Undo relies on this.
- **Sealed events.** `BoardEvent` is sealed — add a variant and fix every `switch` the compiler
  points at. Do not add a `default:` branch to those switches.
- **Naming.** `Pos(row, col)` — always row first. Kinds are `int` indices into the skin's
  `kinds` list, never colour names.
- **No new dependencies** without justification in the PR description. Current runtime deps:
  `shared_preferences` only.
- **Style.** Follow `analysis_options.yaml`; `dart format` before committing. Comments explain
  *why*, not *what* — match the density of surrounding code.

## Tests

- Every engine change ships with unit tests in the mirrored path under `test/engine/`.
- Rule changes need a table-driven case, not just one example.
- Generators and resolvers get property tests over many seeds (see
  `test/engine/generation/board_generator_test.dart` for the pattern).
- Widget tests cover input handling and input locking, not pixel appearance.

## How to add things

**A game mode:** implement `GameMode` in `lib/engine/modes/`, register it in
`mode_registry.dart`, add an integration suite in `test/engine/modes/`, add a mode card to the
mode-select screen, and document it in `docs/CONCEPT.md §3`.

**A skin:** add a `Skin` constant to `lib/skins/skin_registry.dart` and, if it needs a new
silhouette, a path in `tile_shapes.dart` — there is one `TilePainter` for all skins, so a new
painter class is almost never the answer. Add the palette table to `docs/SKINS.md`. The
contract test picks it up automatically — if it fails on luminance or contrast, fix the
palette, not the test.

**A Clear the Board level pack:** run `tool/generate_levels.dart`, which solves every candidate
before writing it. Point `LevelRepository` at the new file and extend
`test/levels/level_pack_test.dart`. Never hand-edit a pack: the tests re-solve it and will
reject a layout that cannot be cleared.

**A tile behaviour (power-ups etc.):** extend `Tile` and the resolver, keep it opt-in per mode
so existing modes stay unchanged.

## Commits and PRs

- Commit subject: `CT-0xx: short imperative summary`.
- One task per commit where practical; keep engine and UI changes separable.
- Update the status column in `docs/TASKS.md` in the same change.
- PR description: what changed, which task, how it was tested, any new dependency and why.

## Gotchas

- `flutter_test` exports its own `MatchFinder` (a widget finder) which collides with the
  engine's. Engine tests import it as
  `import 'package:flutter_test/flutter_test.dart' hide MatchFinder;`.
- Widget tests: `GameController` plays events on `Future.delayed` timers that outlive the last
  scheduled frame, so `pumpAndSettle()` alone can leave a pending timer. Follow it with a
  `pump(Duration(milliseconds: 500))` — see `_settle` in `test/ui/board_view_test.dart`.
- Building for **Windows desktop** needs Developer Mode enabled (plugin symlinks), because of
  the `shared_preferences` plugin. `flutter test`, `flutter build web` and Android builds are
  unaffected.
- **Android + Kotlin incremental caches**: `:shared_preferences_android:compileDebugKotlin`
  fails on this machine with "Could not close incremental caches". `kotlin.incremental=false`
  in `android/gradle.properties` is the fix — do not remove it without re-testing the build.
- **Device testing needs an unlocked screen.** A locked phone leaves the app un-resumed:
  `flutter test integration_test -d <id>` installs and then hangs, and screenshots come back
  black with `FlutterRenderer: Width is zero` in logcat.
- **MIUI/HyperOS** phones reject `adb install` with `INSTALL_FAILED_USER_RESTRICTED` until
  "Install via USB" is enabled in Developer options.
- **Impeller crashes on old Adreno GPUs.** The Galaxy S5 (Adreno 330, Android 11) has no
  Vulkan driver, so Impeller falls back to OpenGLES and then dies on the first frame:
  `Fatal signal 11 (SIGSEGV) ... in tid N (1.raster)`, fault address 0x4. It is the backend,
  not our drawing — disabling every blur mask filter did not help. The fix is
  `res/values/bools.xml` (`enable_impeller=false`) with `res/values-v31/bools.xml` overriding
  it to true, wired to the `io.flutter.embedding.android.EnableImpeller` manifest entry, so
  only pre-Android-12 devices fall back to Skia. Verify a build with
  `aapt2 dump resources <apk> | grep -A2 enable_impeller` — it should print `() false` and
  `(v31) true`. **This opt-out is deprecated** and Flutter intends to remove it; when that
  happens these devices need the upstream GLES fix instead.
- **`flutter test integration_test -d <id>` rebuilds `app-debug.apk` for that device's ABI
  only.** After a run against the 32-bit S5, `build/app/outputs/flutter-apk/app-debug.apk`
  contains just `lib/armeabi-v7a/`, and installing it on the 64-bit phone gives a silent
  failure: the activity starts, the process dies immediately, and logcat says
  `dlopen failed: library "libflutter.so" not found`. Rebuild with `flutter build apk --debug`
  before installing on the other device, and check with
  `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libflutter` — a fat APK lists
  arm64-v8a, armeabi-v7a and x86_64.
- **Debug builds do not present on the Galaxy S5** — the app starts, logs no error, and shows
  a blank white window; release builds render fine. Use
  `flutter run --release -d 18f62439` when testing there. Note that
  `flutter test integration_test` still passes on that device because it asserts on the widget
  tree, not on pixels — a green run there is not proof that anything was drawn.
- Performance mode in Settings drops the blur mask filters, which are the most expensive part
  of drawing a tile; it is the lever for slow-but-working devices.
- `GridConfig` asserts `kindCount` is 3–7; skins ship art for 7.
- Windows + Flutter: use forward slashes in Dart paths; tests read assets via `rootBundle`,
  not `dart:io`.
- `Clear the Board` gravity is **down, then left**, and columns shift only when *fully* empty —
  this is easy to get subtly wrong; see `test/engine/gravity/`.
- `Rising Tide` inserts rows at the **bottom** and pushes the stack **up**; gravity is still
  down. A no-move state forces a rise instead of ending the run.
- Cascade multiplier resets per player move, not per level.

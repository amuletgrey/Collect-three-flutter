# AGENTS.md

Instructions for AI agents (and humans) working in this repository.

## What this is

`collect_three` — a Flutter match-3 game. Swap adjacent tiles, line up three or more, collect
them. Three game modes, three procedurally-drawn skins, no backend.

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
- The **Galaxy S5 has no Vulkan driver** (`vulkan.msm8974.so` missing). Flutter falls back to
  Impeller on OpenGLES by itself — no flag needed. If that ever regresses, run with
  `--enable-impeller=false`. Performance mode in Settings is the other lever: it drops the
  blur mask filters, which are by far the most expensive part of drawing a tile.
- `GridConfig` asserts `kindCount` is 3–7; skins ship art for 7.
- Windows + Flutter: use forward slashes in Dart paths; tests read assets via `rootBundle`,
  not `dart:io`.
- `Clear the Board` gravity is **down, then left**, and columns shift only when *fully* empty —
  this is easy to get subtly wrong; see `test/engine/gravity/`.
- `Rising Tide` inserts rows at the **bottom** and pushes the stack **up**; gravity is still
  down. A no-move state forces a rise instead of ending the run.
- Cascade multiplier resets per player move, not per level.

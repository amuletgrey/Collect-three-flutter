# Architecture

## 1. Guiding principle

> The rules of the game do not know that Flutter exists.

Everything about *what happens* lives in `lib/engine/` as pure, deterministic Dart with no
`package:flutter` import. Everything about *what it looks like* lives above it. This split is
the single most important constraint in the codebase — it is what makes the game testable
without a device, lets three modes share one rule set, and lets skins be swapped without
touching logic. It is enforced by a test (`test/engine/purity_test.dart`).

## 2. Layers

```
┌──────────────────────────────────────────────────────────┐
│  ui/            screens, widgets, painters, animations   │  Flutter
├──────────────────────────────────────────────────────────┤
│  skins/         skin data + procedural tile painters     │  Flutter (painting only)
├──────────────────────────────────────────────────────────┤
│  game/          controllers: engine -> animation -> UI   │  Flutter (ChangeNotifier)
├──────────────────────────────────────────────────────────┤
│  services/      storage, audio, haptics                  │  Flutter + plugins
├──────────────────────────────────────────────────────────┤
│  engine/        board, matching, gravity, modes, scoring │  PURE DART
└──────────────────────────────────────────────────────────┘
```

Dependencies point downward only. `engine/` depends on nothing but `dart:math`/`dart:core`.

## 3. Directory layout

```
lib/
  main.dart                     app entry
  app.dart                      MaterialApp, routes, theme
  engine/
    models/
      tile.dart                 Tile (id, kind), TileKind
      position.dart             Pos (row, col) value type
      board.dart                immutable-ish grid, cell access, clone
      grid_config.dart          rows, cols, kindCount
    random/seeded_random.dart   deterministic RNG wrapper
    matching/
      match_finder.dart         finds all lines >= 3
      match_line.dart           lines + union of cells
      move_finder.dart          enumerates legal moves, hasValidMove()
    gravity/
      gravity_rule.dart         GravityRule strategy (down / downThenLeft)
      refill_rule.dart          RefillRule strategy (fromTop / none / risingRow)
    resolution/
      resolver.dart             cascade loop -> ordered BoardEvent phases
      board_event.dart          sealed event types consumed by the UI
      move_result.dart          outcome of one player swap
    scoring/score_rules.dart    line score, cascade multiplier
    modes/
      game_mode.dart            GameMode interface + GameStatus
      infinite_hunt_mode.dart
      clear_board_mode.dart
      rising_tide_mode.dart
    generation/
      board_generator.dart      seeded boards satisfying §invariants
      clear_board_solver.dart   proves a layout can actually be emptied
      level.dart                Level / LevelPack data + JSON codec
    game_engine.dart            facade: state + applyMove + undo + snapshots
  app.dart / main.dart          app shell and entry point
  app_settings.dart             skin, accessibility toggles, records (ChangeNotifier)
  game/
    game_controller.dart        ChangeNotifier: engine + event playback + input lock
    motion.dart                 every duration and curve, with a reduced-motion mode
  skins/
    skin.dart                   Skin, TileArt, SkinPalette, TileVisualState
    skin_registry.dart          the three shipped skins, lookup by id
    tile_shapes.dart            silhouette paths for every TileShape
    tile_painter.dart           one painter covering all skins
    skin_background.dart        per-skin backdrop
  ui/
    screens/  home_screen, level_select_screen, game_screen
    widgets/  board_view, tile_view, hud, skin_switcher
  services/
    storage_service.dart        shared_preferences: bests, stars, skin, settings
    level_repository.dart       loads the shipped level pack
    haptics_service.dart        platform haptics, scaled to the event
tool/
  generate_levels.dart          offline Clear-the-Board level generator + solver
assets/levels/                  generated level packs (JSON)
test/                           mirrors lib/ ; engine tests are the bulk
docs/
```

## 4. Engine model

### Board

`Board` holds `List<Tile?> cells` in row-major order plus `rows`/`cols`. Cells are nullable
because *Clear the Board* and *Rising Tide* genuinely have holes. `Tile` carries a stable
`id` (monotonic int) alongside its `kind` — the id is what lets the UI animate a specific
tile from A to B instead of cross-fading the whole grid.

Boards are treated as values: mutating operations return a new `Board`, and the engine keeps
old ones for undo. At 8x10 this is cheap and buys correctness.

### Resolution pipeline

One player swap produces a `MoveResult` containing an **ordered list of phases**. The engine
runs the whole cascade to completion synchronously; the UI then replays it as animation.

```
applyMove(a, b)
  ├─ swap not adjacent / tile missing        -> MoveResult.rejected
  ├─ swap creates no match                   -> [SwapPerformed, SwapReverted]
  └─ swap creates match
       [SwapPerformed]
       loop step = 1, 2, 3, ...
         ├─ TilesCleared(cells, lines, score, multiplier)
         ├─ TilesMoved(list of id: from -> to)     (gravity rule)
         ├─ TilesSpawned(list of id/kind/at)       (refill rule)
         └─ any new matches? continue : break
       [ModeEvent...]   e.g. RowInserted for Rising Tide
       [GameEnded(reason)] if the mode says so
```

`BoardEvent` is a sealed class hierarchy; adding an event forces every consumer to handle it.
The important property: **the event list is a complete description of the animation**. No UI
code re-derives what happened, and a headless test can assert on the exact same list.

### Mode strategy

```dart
abstract class GameMode {
  String get id;
  GridConfig get grid;
  GravityRule get gravity;
  RefillRule get refill;
  int get undoBudget;                          // 0 disables undo
  int? get moveLimit;
  Board createBoard(SeededRandom rng, TileFactory tiles);
  ModeStepOutcome afterMove(ModeContext ctx);  // the tide rises here
  ModeEvaluation evaluate(ModeContext ctx);    // playing / won / lost + reason
  GameMode fresh();                            // clean instance for a restart
}
```

Undo is only offered by modes that draw no randomness during play — `SeededRandom` cannot be
rewound, so a refilling mode would desync on the way back.

Modes compose existing rules rather than reimplementing matching. Adding *Relic Dig* later
means writing one file, registering it, and writing its tests — no engine surgery.

### Determinism

All randomness flows through `SeededRandom`. Given `(seed, mode, inputs)` the entire game is
reproducible, which makes bug reports actionable ("seed 8412, moves [...]") and lets tests
pin exact boards. `DateTime.now()` is never read inside `engine/`.

## 5. Presentation

**Rendering.** `BoardView` is a `Stack` of `Positioned` tile widgets keyed by `ValueKey(tile.id)`,
each drawing itself with the active skin's `CustomPainter`. 64–80 tiles is well within
widget-tree budget and keeps hit-testing, semantics and testing simple. Positions animate with
`AnimatedPositioned`, using the duration the controller publishes for the current step — see
event playback below.

**Event playback.** `GameController` walks the engine's event list one entry at a time,
updating a tile-id → position map and publishing the duration the current step should take
(`stepDuration`). `AnimatedPositioned` in `BoardView` uses exactly that duration, so the
visuals finish when the controller stops waiting. Input is locked for the whole sequence
(`busy`), and playback always ends by re-syncing from the engine board — the engine is the
source of truth even if a frame is dropped.

**Skins.** A `Skin` is data: palette plus a `TileArt` per kind (colour, family, silhouette,
optional glyph). A single `TilePainter` renders every skin, switching on the art's family and
shape, so a new skin is a data entry and at most a new path in `tile_shapes.dart` — never a
new painter class. Switching skins touches no game state and is safe mid-run.

**State management.** Flutter built-ins only — `ChangeNotifier` + `ListenableBuilder`,
propagated with a small `InheritedNotifier`. No Provider/Riverpod/Bloc dependency; the app has
exactly two long-lived notifiers (`GameController`, `AppSettings`) and adding a framework
would cost more than it saves.

## 6. Dependencies

Deliberately near-zero:

| Package | Why |
| --- | --- |
| `shared_preferences` | best scores, chosen skin, settings |
| `flutter_lints` (dev) | lint baseline |
| `flutter_test` (dev) | tests |

Audio is stubbed behind `AudioService` in v1 so adding `audioplayers` later is a one-file change.
Any new runtime dependency needs a justification in the PR description.

## 7. Testing strategy

| Level | What | Where |
| --- | --- | --- |
| Unit | match finding, gravity, left-shift, scoring, move enumeration, generation invariants | `test/engine/**` |
| Property | random boards: generator never produces free matches or dead boards; resolver always terminates | `test/engine/property/**` |
| Mode | full scripted runs per mode, asserting status transitions and event order | `test/engine/modes/**` |
| Golden-ish | skin painters render without exceptions at several sizes | `test/skins/**` |
| Widget | board renders, tap-tap and drag both swap, input locks during animation | `test/ui/**` |
| Level pack | every shipped level re-solved, par verified, replayed through the engine | `test/levels/**` |
| On-device | the real app driven by real gestures on a real rendering backend | `integration_test/**` |

Engine tests must not import `package:flutter/*`. Target: engine logic at high coverage
before any UI polish work starts — the UI is cheap to change, the rules are not.

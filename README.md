# Collect Three

A Flutter tile-matching game: swap adjacent objects, line up **three or more**, collect them.

Three ways to play the same rules:

- **Infinite Hunt** — tiles refill from the top forever; the run ends when no legal move is left.
- **Clear the Board** — no refills, tiles fall down *and* shift left, and you must plan far
  enough ahead to remove every last tile.
- **Rising Tide** — a new row pushes up from the bottom every few moves; survive as long as
  you can.

Three procedurally drawn skins: **Classic Arcade** (glossy balls), **Treasure Hunt** (cut
gemstones), **Candy Shop** (sweets). No image assets — everything is painted at runtime, so it
stays sharp at any resolution.

## Status

Playable: all three modes, all three skins, 30 hand-verified Clear the Board levels with stars,
best scores saved locally, tap-tap and drag input, haptics, and a performance mode for older
phones.

Every shipped level is **provably solvable** — `tool/generate_levels.dart` only writes a layout
after `ClearBoardSolver` has actually cleared it, and `flutter test test/levels/` re-proves the
whole pack on every run.

Still to come (see [docs/TASKS.md](docs/TASKS.md)): sound, particles, an invalid-swap shake, a
dedicated settings screen, and a screen-reader pass.

## Getting started

```bash
flutter pub get
flutter test
flutter run
```

## Documentation

| Document | Contents |
| --- | --- |
| [docs/CONCEPT.md](docs/CONCEPT.md) | rules, modes, scoring, screens, scope |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | layering, engine model, testing strategy |
| [docs/SKINS.md](docs/SKINS.md) | skin contract, palettes, accessibility rules |
| [docs/TASKS.md](docs/TASKS.md) | milestone/task board |
| [AGENTS.md](AGENTS.md) | working conventions for contributors and AI agents |

## Project shape

```
lib/engine/   pure Dart rules — no Flutter imports, fully deterministic, heavily tested
lib/game/     controllers bridging engine events to animation
lib/skins/    skin data + CustomPainters
lib/ui/       screens and widgets
tool/         offline level generator for Clear the Board
```

The engine is deliberately framework-free: the same rules drive all three modes and can be
tested without a device.

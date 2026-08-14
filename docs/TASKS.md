# Task breakdown

Work is grouped into milestones. Each milestone is independently shippable and testable.
Task IDs are stable — reference them in commits (`CT-012: add match finder`).

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done

Current state: **M0–M6 and M9 are done, M7 is in progress.** The game is playable in all three
modes with all three skins, and Clear the Board now runs on a 30-level pack where every level
was solved by the generator before shipping. It ships as **Tessera** under
`com.vibebyteforge.tessera` with icons and CI-built artifacts for Android, web and Windows.
What remains in M7 is audio, particles, the invalid-swap shake, and a dedicated pause/settings
screen.

---

## M0 — Foundation

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-001 | Flutter scaffold (`tessera`, android/ios/web/windows) | `flutter analyze` clean, app builds | [x] |
| CT-002 | Design docs: concept, architecture, skins, tasks, AGENTS.md | reviewed and merged | [x] |
| CT-003 | Lints tightened, `analysis_options.yaml` project rules | analyzer clean with stricter rules | [x] |

## M1 — Engine core (pure Dart)

No Flutter imports anywhere in this milestone. Every task lands with its own tests.

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-010 | `Pos`, `Tile`, `GridConfig`, `Board` (row-major, nullable cells, value semantics) | equality/clone/bounds tested | [x] |
| CT-011 | `SeededRandom` deterministic wrapper | same seed ⇒ same sequence | [x] |
| CT-012 | `MatchFinder`: all horizontal/vertical lines >= 3, L/T grouping | table-driven tests incl. 5-in-row, L, T, cross | [x] |
| CT-013 | `MoveFinder`: enumerate legal swaps, `hasValidMove`, hint | dead board detected, hint is always legal | [x] |
| CT-014 | `GravityRule`: `down`, `downThenLeft` (column compaction) | left-shift only when a column is fully empty | [x] |
| CT-015 | `RefillRule`: `fromTop`, `none`, `risingRow` | spawn ids unique, kinds from rng | [x] |
| CT-016 | `ScoreRules`: line score, cascade multiplier cap | matches formulas in CONCEPT §2 | [x] |
| CT-017 | `Resolver` + sealed `BoardEvent` + `MoveResult` | event list fully describes the cascade; terminates | [x] |
| CT-018 | `BoardGenerator`: no free matches, at least one move | property test over 500 seeds | [x] |
| CT-019 | `GameEngine` facade: state, `applyMove`, undo stack, snapshots | undo restores exact board + score | [x] |
| CT-01A | Purity test: `engine/` never imports Flutter | fails if a Flutter import is added | [x] |

## M2 — Game modes

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-020 | `GameMode` interface, `GameStatus`, mode registry | modes resolvable by id | [x] |
| CT-021 | Infinite Hunt: down + refill-from-top, ends on no moves | scripted run reaches `lost` only when dead | [x] |
| CT-022 | Clear the Board: no refill, down-then-left, win on empty | win/lose transitions correct; undo enabled | [x] |
| CT-023 | Rising Tide: bottom row insert every N moves, lose on overflow | no-move ⇒ forced rise, never stalls | [x] |
| CT-024 | Per-mode integration suites (long seeded runs) | 1000-move fuzz run per mode, no exceptions | [x] |

## M3 — Skins

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-030 | `Skin`, `TileArt`, `SkinPalette`, `TileVisualState`, registry | registry lookup + default fallback | [x] |
| CT-031 | Classic Arcade art (sphere + optional symbol) | renders 7 kinds, all states | [x] |
| CT-032 | Treasure Hunt art (7 gem cuts, gold rim) | distinct silhouettes verified | [x] |
| CT-033 | Candy Shop art (7 candy shapes) | distinct silhouettes verified | [x] |
| CT-034 | Skin contract tests (luminance, contrast, distinctness, no-throw paint) | all registered skins pass automatically | [x] |
| CT-035 | Per-skin backdrops (scanlines / torch glow / stripes) | static, reduced-motion safe | [x] |

## M4 — Game shell

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-040 | `GameController`: event playback, `stepDuration`, input lock | input locked while events play; widget-tested | [x] |
| CT-041 | Run stats: score, moves, best chain, tiles collected | results overlay data complete | [x] |
| CT-042 | `StorageService` (shared_preferences): bests, skin, settings | survives restart; namespaced keys | [x] |
| CT-043 | Run duration + longest-line stats on the results screen | shown after every run | [ ] |

## M5 — UI

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-050 | Motion constants (durations/curves, reduced-motion) | one source of truth for timings | [x] |
| CT-051 | `BoardView`/`TileView`, drag + tap-tap input | widget test: both input styles swap; input locks | [x] |
| CT-052 | HUD with per-mode slots (moves / tide meter / tiles left) | correct slot per mode | [x] |
| CT-053 | Home + mode select with personal bests | navigates to a running game | [x] |
| CT-054 | Skin switcher with live sample tiles | switching mid-game keeps state | [x] |
| CT-055 | Result overlay (win/lose variants) | retry and change-mode paths work | [x] |
| CT-056 | Invalid-swap shake and selection polish | reverted swap reads as a rejection | [ ] |
| CT-057 | Juice: particles, cascade chime hooks, danger pulse | 60 fps on a mid-range device | [ ] |
| CT-058 | Pause overlay + dedicated settings screen | toggles currently live on the home screen | [ ] |

## M6 — Clear-the-Board levels

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-060 | `Level` / `LevelPack` model + JSON codec | round-trips | [x] |
| CT-061 | `ClearBoardSolver` + `tool/generate_levels.dart` | only emits layouts the solver actually beat | [x] |
| CT-062 | Ship 30-level pack with par move counts | every level re-proven solvable by the test suite | [x] |
| CT-063 | Level select grid with stars + progress persistence | stars stored per level, levels unlock in order | [x] |

## M8 — Device verification

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-080 | `integration_test` suite driving the real app with real gestures | plays every mode end to end | [x] |
| CT-081 | Windows desktop build + integration run | 8/8 green | [x] |
| CT-082 | Android debug + release builds | both build clean | [x] |
| CT-083 | Galaxy S5 (ARMv7, Lineage 18) verification | release build plays; Impeller opt-out required; debug builds do not present | [x] |
| CT-084 | Xiaomi 24115RA8EG verification | installs, plays, 8/8 integration tests green | [x] |
| CT-085 | Per-API-level Impeller opt-out for old Adreno GPUs | S5 no longer segfaults; API 31+ keeps Impeller | [x] |
| CT-086 | Investigate why debug builds show a blank window on the S5 | root cause found, or documented as a device limitation | [ ] |

## M9 — Name, icon and release artifacts

Details in [`docs/RELEASE.md`](RELEASE.md).

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-090 | Name the app and roll it across every platform namespace | nothing anywhere still says `collect_three` | [x] |
| CT-091 | App icon: 1024 master, scaled to every platform's slots | adaptive + themed on Android, alpha-free on iOS, multi-size .ico | [x] |
| CT-092 | Android release signing from key.properties or CI env, with a debug fallback | a fresh clone still builds release | [x] |
| CT-093 | Artifacts: 3 split APKs, a universal APK, an AAB, web zip, Windows zip | every ABI verified present in the universal APK | [x] |
| CT-094 | CI: verify on every push, build artifacts on main/tag, release on `v*` | green run on this branch | [x] |
| CT-095 | Written store listing: descriptions, screenshots, data-safety answers | Play listing can be submitted | [ ] |
| CT-096 | iOS: Apple account, signing, macOS runner in the matrix | an installable .ipa | [ ] |

## M7 — Polish and release

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-070 | `HapticsService` (platform haptics, no plugin) | scales with the moment; respects the setting | [x] |
| CT-071 | Accessibility pass: semantics labels, symbols, reduced motion | board navigable by screen reader | [ ] |
| CT-072 | Performance mode: drop blur mask filters and backdrop decoration | the setting old phones need | [x] |
| CT-073 | App icons, splash, store metadata, release build configs | done in M9; splash and the written store listing remain | [~] |
| CT-074 | `AudioService` + a sound pack | mute respected everywhere | [ ] |

---

## Backlog

Agreed direction, in priority order. M9 is reserved for the CI/release workstream, which is
being handled separately — see that milestone before touching `android/`, `ios/`, `web/`,
`windows/` or the workflow files.

| Priority | Item | Notes |
| --- | --- | --- |
| 1 | **M10 — Special tiles** | 4- and 5-matches create powers. Rules, art and device checks done; CT-107/CT-108 remain. |
| 2 | M11 — Feel and feedback | Particles on collect, cascade chimes via an `AudioService`, Rising Tide danger pulse, pause/settings screen. Covers the open CT-057/CT-058/CT-074. |
| 3 | M12 — Relic Dig, a fourth mode | Escort heavy relic tiles to the bottom row. Self-contained: a tile behaviour plus one `GameMode`. |
| 4 | M13 — Content and progression | More level packs and tiers, daily seeded challenge, level-select polish. **Deliberately last** — not yet decided that we want to go there. |

## M10 — Special tiles

Powers are **opt-in per mode**. They stay off in Clear the Board: `ClearBoardSolver` reasons
about plain matches only, so enabling them there would invalidate every shipped level's par
and the solvability guarantee behind the pack.

| ID | Task | Acceptance | Status |
| --- | --- | --- | --- |
| CT-100 | `TilePower` on `Tile`; creation rules for 4-line, 5-line and L/T | table-driven tests per shape | [x] |
| CT-101 | Detonation: line clear, 3x3 bomb, colour bomb, with chain reactions | a detonation that hits another special sets it off; terminates | [x] |
| CT-102 | Colour bomb activates on swap, not only when matched | swapping it with a plain tile clears that kind | [x] |
| CT-103 | Scoring for powers and combos | documented in CONCEPT §2; deterministic | [x] |
| CT-104 | `GameMode.allowsSpecials`; on for Infinite Hunt and Rising Tide, off for Clear the Board | level pack tests still pass unchanged | [x] |
| CT-105 | Artwork for every power, shared across skins | reads on all three skins; see docs/images/powers.png | [x] |
| CT-106 | Board feedback when a power fires | flash on detonation; widget + on-device tests | [x] |
| CT-107 | Combo art: show what a paired power will do before it fires | player can tell a combo from a plain swap | [ ] |
| CT-108 | Surface powers on the results screen | "3 powers fired" alongside best chain | [ ] |

---

## Suggested order and parallelism

```
M0 ──▶ M1 ──▶ M2 ──┬──▶ M4 ──▶ M5 ──▶ M7
                   ├──▶ M3 ──────────┘
                   └──▶ M6 (needs M2 clear-board rules only)
```

M3 (skins) and M6 (level generation) are the natural places to work in parallel with the UI —
both depend only on finished engine rules and touch no shared files.

## Definition of done for any task

1. Code + tests in the same change.
2. `flutter analyze` clean, `flutter test` green.
3. Engine changes keep determinism (seeded, no wall-clock reads).
4. Docs updated when behaviour or a rule changes.
5. Status ticked in this table.

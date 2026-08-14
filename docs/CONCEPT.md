# Collect Three — Game Design Document

## 1. Elevator pitch

A tile-matching puzzle game where you swap neighbouring objects to line up **three or more**
of a kind and collect them. One engine, three very different ways to play, and three
hand-painted skins that change the whole feel of the board without changing the rules.

Target platforms: Android, iOS, Web, Windows. Portrait-first, single-hand play.

## 2. Core rules (shared by every mode)

These are the "classic" match-3 rules; every mode below inherits them and only overrides
what is listed in its own section.

| Rule | Definition |
| --- | --- |
| Board | Rectangular grid of cells. Each cell holds one tile or is empty. Default 8x8. |
| Tile kinds | 6 by default (per-mode configurable, 4–7 supported). |
| Input | Drag or tap-tap to swap two **orthogonally adjacent** tiles. Diagonals are not allowed. |
| Valid move | A swap that produces at least one line of 3+ identical kinds. |
| Invalid move | The swap animates, then reverts. It costs no moves and no time. |
| Match | 3 or more identical tiles in a contiguous horizontal **or** vertical line. |
| L / T shapes | Two intersecting lines are collected together as one match group; each line scores separately. |
| Collection | Matched tiles are removed, awarding score and mode-specific progress. |
| Gravity | Tiles fall into empty cells. Direction and refill are mode-specific. |
| Cascade | If falling/refilling creates new matches, they resolve automatically with a rising multiplier. |
| Move consumed | A move counter increments only for *accepted* swaps. |

### Scoring

```
lineScore(n) = 10 * n * (n - 2)      // 3 -> 30, 4 -> 80, 5 -> 150, 6 -> 240
cascadeMultiplier(step) = min(step, 8)   // first resolution = x1, next = x2, ...
moveScore = sum(lineScore) * cascadeMultiplier
```

Cascade multiplier resets at the start of every player move. This is what makes setting up
chain reactions the main skill expression in all three modes.

### Board generation invariants

Every freshly generated board must satisfy:

1. **No free matches** — no line of 3+ exists before the player touches anything.
2. **At least one valid move** exists.
3. For *Clear the Board*, additionally: the layout is **provably solvable** (see §3.2).

Generation is driven by a seeded RNG so any board can be reproduced from `(seed, mode, config)`.
This is what makes the engine testable and makes daily/shared challenges possible later.

## 3. Game modes

### 3.1 Infinite Hunt — endless score attack

> The board never runs dry. You do.

- **Gravity:** down. **Refill:** new random tiles drop in from the top edge.
- **Goal:** score as much as possible.
- **End condition:** the board reaches a state with **no valid moves**. No shuffles, no
  rescue — that dead board *is* the ending. Final score is banked to the leaderboard.
- **Tension:** because refills are random, a well-played board stays alive far longer than a
  greedy one. Clearing everything as fast as possible is *not* optimal play.
- **Feedback:** a subtle "moves available" pulse when the count of legal moves drops to 1–2.

### 3.2 Clear the Board — the thinking mode

> Every tile on the screen must go. There are no more coming.

- **Gravity:** down, **then left**. After tiles fall, any column that has become completely
  empty is removed and all columns to its right shift left. This is the twist that makes
  the mode a real puzzle: clearing a match changes the *geometry* of everything to the right,
  not just the column above it.
- **Refill:** none. What you see is all you get.
- **Goal:** empty the board completely.
- **Loss:** tiles remain but no valid move exists, or the move budget runs out.
- **Aids:** limited **undo** (default 3 per level, engine keeps full snapshots) and instant
  restart. Undo is essential — the mode asks you to plan several moves ahead and it must be
  fair to explore.
- **Par:** each level ships with a par move count; finishing at or under par awards 3 stars.

**Solvability.** Random layouts are usually unsolvable, so levels are not generated at
runtime. A generator under `tool/generate_levels.dart` builds candidate layouts (tile counts
per kind always divisible by 3), runs a depth- and node-bounded search over legal move
sequences, and only emits layouts where a full clear was actually found. Output is a JSON
level pack in `assets/levels/`, storing the grid, the seed, par moves and the solution length.
The runtime never has to solve anything — it just loads a level that is known to be winnable.

### 3.3 Rising Tide — survival under pressure

> The floor keeps handing you more work.

- **Board:** taller than the others (default 8 columns x 10 rows), starting with only the
  bottom 5 rows filled.
- **Gravity:** down. **Refill:** none from the top.
- **The tide:** every `N` accepted moves, a fresh row is inserted at the **bottom** and the
  whole stack is pushed **up** by one row. `N` starts at 5 and decreases by 1 every 8 rows,
  to a floor of 2.
- **Loss:** a tile is pushed above the top row.
- **No valid moves?** Instead of ending the run, the tide rises immediately — new tiles mean
  new options. The mode can only be lost by drowning, never by stalling.
- **Danger zone:** the top two rows are tinted; entering them triggers a heartbeat pulse and
  (optionally) haptics.
- **Skill:** clearing low keeps the stack short; clearing high scores more via cascades but
  buys you nothing. Risk/reward every single move.

### 3.4 Mode comparison

| | Infinite Hunt | Clear the Board | Rising Tide |
| --- | --- | --- | --- |
| Refill | from top | none | from bottom (row push) |
| Gravity | down | down, then left | down |
| Win | — | board empty | — |
| Lose | no moves | no moves / out of moves | stack overflows top |
| Undo | no | yes (3) | no |
| Session | 3–10 min | 1–4 min per level | 2–8 min |

## 4. Skins

A skin changes tile artwork, board frame, background, particle colours and HUD accents.
It never changes rules, board size, or tile-kind count. Skins are selectable at any time,
including mid-game, and are drawn **procedurally** (no bitmap assets) so they stay crisp at
every resolution.

1. **Classic Arcade** — glossy colourful balls with a specular highlight, dark cabinet-style
   background, chunky neon HUD.
2. **Treasure Hunt** — cut gemstones (round brilliant, emerald, marquise, trillion, pear,
   heart) with gold rims on a carved-stone board, torch-lit warm background.
3. **Candy Shop** — lollipop swirl, wrapped hard candy, jelly bean, gumdrop, chocolate square,
   peppermint, on pastel stripes with a bright, soft look.

**Accessibility.** Each kind is identified by hue *and* by silhouette. Treasure Hunt and Candy
Shop have naturally distinct shapes; Classic Arcade, whose tiles are all spheres, additionally
supports a "symbols" toggle that stamps a small glyph on each ball. Palettes are checked for
protanopia/deuteranopia separability. See `docs/SKINS.md`.

## 5. Screens

```
Home ──▶ Mode select ──▶ Game ──▶ Results
 │                        │
 └──▶ Skin gallery        └──▶ Pause (resume / restart / skin / quit)
 └──▶ Settings (sound, haptics, symbols, reduced motion)
```

- **Home** — logo, Play, mode cards showing personal bests, skin gallery, settings.
- **Game** — board, score, mode-specific HUD (moves left / tide meter / tiles remaining),
  pause. HUD is one shared widget with per-mode slots.
- **Results** — score, best, cascade highlight ("best chain: x5"), retry / change mode.

## 6. Feel and feedback

Matching has to feel good or nothing else matters.

- Swap: 120 ms ease-out; invalid swap reverts with a short shake.
- Collect: tiles scale up 10% then pop with a particle burst tinted by the skin.
- Fall: gravity-like ease-in, per-tile stagger, ~90 ms per cell travelled.
- Cascades: each step slightly faster than the previous, with a rising pitch chime.
- Haptics: light on collect, medium on cascade >= x3, heavy on game over.
- **Reduced motion** setting collapses all of the above to quick cross-fades.

## 7. Scope

**v1 (this milestone plan):** three modes, three skins, local persistence of best scores,
level pack of 30 Clear-the-Board levels, no accounts, no ads, no IAP, offline only.

**Explicitly out of v1, kept possible by the architecture:**
power-ups / special tiles from 4- and 5-matches, daily seeded challenge, level editor,
online leaderboards, sound pack beyond stubs, a 4th "Neon Lab" skin, and a *Relic Dig* mode
(escort a heavy relic tile to the bottom row) that already fits the mode strategy interface.

# Tessera — Game Design Document

## 1. Elevator pitch

A tile-matching puzzle game where you swap neighbouring objects to line up **three or more**
of a kind and collect them. One engine, three very different ways to play, and three
hand-painted skins that change the whole feel of the board without changing the rules.

Target platforms: Android, iOS, Web, Windows.

**Orientation.** The game is not locked. A tall screen stacks the chrome above and below the
board — one-handed play, the board as wide as the screen allows. A wide screen (a rotated
phone, a tablet, a desktop window) moves the readouts into a column on the left and the
controls into a column on the right, leaving the board the full height. The board is a square
grid that wants to be as large as it can, so on a wide screen everything else belongs beside
it rather than above and below, which is what pinched it into a small square before.

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
blastScore   = 20 per tile removed by a power that was not already in a matched line
cascadeMultiplier(step) = min(step, 8)   // first resolution = x1, next = x2, ...
moveScore = (sum(lineScore) + blastScore) * cascadeMultiplier
```

A tile taken out by a blast is worth more than one taken out by a plain three, which is what
makes setting powers off deliberately worth doing.

Cascade multiplier resets at the start of every player move. This is what makes setting up
chain reactions the main skill expression in all three modes.

### Special tiles

Matching more than three creates a tile with a **power**. Powers are opt-in per mode: they are
on in Infinite Hunt and Rising Tide, and **off in Clear the Board**, whose levels are shipped
with a proven solution that assumes plain matches only.

| Made by | Power | What it does |
| --- | --- | --- |
| A line of exactly 4 | **Line clear** | Clears the whole row (from a horizontal match) or column (from a vertical one). |
| A line of 5 or more | **Colour bomb** | Clears every tile of one kind. |
| Two intersecting lines (L or T) | **Bomb** | Clears the 3x3 block around itself. |

Only one power is created per match group; if several rules apply, the stronger one wins
(colour bomb > bomb > line clear). It appears on the cell the player actually moved when that
cell is part of the group, otherwise on the intersection of an L/T, otherwise in the middle of
the line.

**Firing.** A power goes off when it is collected — either because it was part of a match, or
because another power's blast caught it. Blasts therefore chain: one line clear can set off
every special it sweeps through. Each tile is only ever detonated once, so a chain always ends.

**The colour bomb is different**: it will rarely find itself in a match, so it also fires when
you *swap* it with anything, clearing every tile of that neighbour's kind. That makes a swap
involving a colour bomb always legal, even though it forms no line — the engine's move
validation and its "no moves left" check both account for this.

**Combos.** Swapping two powers sets off both where they stand. A colour bomb swapped with
another power first clears that power's whole kind, so the two effects compound.

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
- **Opening levels:** the pack starts on a 3x3 with three colours — nine tiles, cleared in two
  moves. Those first few levels exist to teach the one rule that makes this mode different
  (nothing refills, so every tile has to go) before the board is big enough to get lost on.
- **Next level:** clearing a level offers to go straight on to the next one.

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

### 3.4 Relic Dig — escort the cargo

> Dig the relics out. Matching is just the shovel.

- **Board:** 8x8, refilling from the top, exactly like Infinite Hunt.
- **The relics:** three tiles start buried in the top two rows, one per column.
  A relic falls with gravity like anything else, but it never matches, cannot be
  swapped, and no blast can take it. The only way to move one is to clear what is
  underneath it.
- **Goal:** walk every relic down to the bottom row, where it is collected for 500 points —
  far more than any match, because it is the actual objective.
- **Loss:** the board runs out of legal moves.
- **Skill:** this mode inverts the usual instinct. Clearing greedily near the top scores
  points and achieves nothing; the board just refills. The tiles worth taking are the ones
  under the cargo. The engine tests play the same seed both ways to keep that true.

### 3.5 Mode comparison

| | Infinite Hunt | Clear the Board | Rising Tide | Relic Dig |
| --- | --- | --- | --- | --- |
| Refill | from top | none | from bottom (row push) | from top |
| Gravity | down | down, then left | down | down |
| Win | — | board empty | — | all relics delivered |
| Lose | no moves | no moves / out of moves | stack overflows top | no moves |
| Powers | yes | no | yes | yes |
| Undo | no | yes (3) | no | no |
| Session | 3–10 min | 1–4 min per level | 2–8 min | 3–8 min |

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
- **Sound:** the collect chime climbs a pentatonic scale with the chain — first clear is the
  root, a x4 chain is four notes up. The sound tells you how good the chain was before the
  score has finished counting. Powers get a noise burst, a delivered relic a low struck tone,
  the tide a rising sweep. Everything is synthesised by `tool/generate_sounds.dart` rather than
  recorded: a match-3's sounds are tones and envelopes, so they belong in code where they can
  be retuned by editing numbers.
- **Hint:** a ring in the skin's own hint colour, breathing in and out. It is bracketed by a
  light and a dark edge, because no single colour contrasts with both the lightest and the
  darkest tile in a skin.
- **The end of a run** waits: the board finishes every animation, holds for half a second, and
  only then does the banner appear. Landing it on top of the last cascade robs the player of
  watching their own final move. This applies to every mode, win or lose.

### Picking a run back up

A run is saved after every move and offered back on the home screen ("Continue · 1 240 pts,
move 18"). The whole board goes into the save — tile ids, powers and the random generator's
state — so resuming deals exactly the tiles the run would have dealt anyway, rather than
restarting the sequence. A finished run has nothing worth keeping, so its save is dropped.

High scores are banked as a run goes, not only when it ends: walking away from a good Infinite
Hunt run still keeps the score.

## 7. Scope

**v1 (this milestone plan):** three modes, three skins, local persistence of best scores,
level pack of 30 Clear-the-Board levels, no accounts, no ads, no IAP, offline only.

**Explicitly out of v1, kept possible by the architecture:**
daily seeded challenge, level editor,
online leaderboards, sound pack beyond stubs, a 4th "Neon Lab" skin, and a *Relic Dig* mode
(escort a heavy relic tile to the bottom row) that already fits the mode strategy interface.

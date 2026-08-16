import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/match_finder.dart';
import '../models/board.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../models/tile_motion.dart';
import '../random/seeded_random.dart';
import '../scoring/score_rules.dart';
import '../specials/special_rules.dart';
import 'board_event.dart';

class ResolutionOutcome {
  const ResolutionOutcome({
    required this.board,
    required this.events,
    required this.score,
    required this.cascadeCount,
    required this.tilesCleared,
    required this.longestLine,
    required this.specialsCreated,
    required this.specialsFired,
    this.clearedByKind = const {},
    this.clearedCells = const {},
    this.blastCleared = 0,
    this.rotCleared = 0,
  });

  final Board board;
  final List<BoardEvent> events;
  final int score;

  /// Number of resolution steps that actually cleared something.
  final int cascadeCount;
  final int tilesCleared;
  final int longestLine;
  final int specialsCreated;
  final int specialsFired;

  /// How many tiles of each kind went out, across the whole cascade. Modes with
  /// collection goals count from this rather than re-reading the board, which
  /// has already refilled by the time they see it.
  final Map<int, int> clearedByKind;

  /// Every cell emptied during the move. Positions from different cascade
  /// steps, so this describes where the action was, not a single board state.
  final Set<Pos> clearedCells;

  /// Tiles taken by a power rather than by being part of a line.
  final int blastCleared;

  /// Rot tiles a blast destroyed outright.
  final int rotCleared;

  bool get clearedAnything => cascadeCount > 0;
}

/// Runs the clear → settle → refill loop until the board is stable.
///
/// The whole cascade is computed synchronously; the caller replays the emitted
/// events as animation afterwards. Gravity, refill and whether powers exist are
/// injected, which is all that separates the three game modes at this level.
class Resolver {
  const Resolver({
    required this.gravity,
    required this.refill,
    required this.kindCount,
    this.allowsSpecials = false,
  });

  final GravityRule gravity;
  final RefillRule refill;
  final int kindCount;

  /// Off for Clear the Board, whose shipped levels are solved assuming plain
  /// matches only.
  final bool allowsSpecials;

  /// Safety net: a rule bug that keeps producing matches should fail loudly in
  /// tests rather than hang the game loop.
  static const int _maxCascades = 200;

  ResolutionOutcome resolve({
    required Board board,
    required SeededRandom rng,
    required TileFactory tiles,
    int startStep = 1,

    /// The two cells the player's swap touched, so a new power lands under
    /// their finger rather than in the middle of the line.
    Set<Pos> origins = const {},

    /// Overrides how many kinds refills draw from, for a mode whose palette
    /// grows during a run.
    int? kindCount,

    /// Powers to fire before any matching happens — how a colour bomb goes off
    /// when it is swapped rather than matched.
    Set<Pos> primed = const {},
    Map<Pos, int> primedKinds = const {},

    /// Drop and refill before looking for matches. Modes that remove tiles
    /// themselves — Relic Dig delivering cargo — use this to hand the board
    /// back settled, with the fall and the refill in the event list.
    bool settleFirst = false,
  }) {
    final events = <BoardEvent>[];
    var current = board;
    var score = 0;
    var cleared = 0;
    var longest = 0;
    var created = 0;
    var fired = 0;
    var blasted = 0;
    var rotted = 0;
    final byKind = <int, int>{};
    final clearedCells = <Pos>{};
    var step = startStep;
    var pendingPrimed = primed;
    final kinds = kindCount ?? this.kindCount;

    if (settleFirst) {
      final settled = gravity.apply(current);
      current = settled.board;
      for (final batch in settled.steps) {
        if (batch.isNotEmpty) events.add(TilesMoved(batch));
      }
      final refilled = refill.apply(
        board: current,
        rng: rng,
        tiles: tiles,
        kindCount: kinds,
      );
      current = refilled.board;
      if (refilled.spawnedAnything) events.add(TilesSpawned(refilled.spawned));
    }

    while (true) {
      final matches = MatchFinder.find(current);
      if (matches.isEmpty && pendingPrimed.isEmpty) break;
      if (step - startStep >= _maxCascades) {
        throw StateError('cascade did not terminate after $_maxCascades steps');
      }

      // Powers are granted before anything is removed, and the tile that earns
      // one survives the clear so the power stays where the player made it.
      final spawns = allowsSpecials
          ? SpecialRules.spawnsFor(
              matches,
              origins: step == startStep ? origins : const {},
            )
          : const <SpecialSpawn>[];
      final protected = {for (final spawn in spawns) spawn.at};

      final initial = {
        ...matches.cells.where((cell) => !protected.contains(cell)),
        ...pendingPrimed,
      };
      final blast = allowsSpecials
          ? SpecialRules.resolveBlasts(
              current,
              initial,
              swappedKinds: primedKinds,
            )
          : (cells: initial, detonated: const <Pos>[]);
      pendingPrimed = const {};

      // A power that fired must go with its blast, even if it was protected.
      //
      // Cargo survives a blast — the only way to be rid of a relic is to walk
      // it to the bottom, and a bomb that vaporised the thing you were escorting
      // would be a bad joke. Rot does not: a power going off is exactly the
      // moment a player expects the board to be cleaned up, and rot that shrugged
      // off a bomb made powers feel useless in the one mode built around them.
      final clearCells = {...blast.cells}
        ..removeWhere(
          (cell) =>
              (current.at(cell)?.isRelic ?? false) ||
              (protected.contains(cell) && !blast.detonated.contains(cell)),
        );

      for (final cell in clearCells) {
        final kind = current.kindAt(cell);
        if (kind != null) byKind[kind] = (byKind[kind] ?? 0) + 1;
      }
      clearedCells.addAll(clearCells);

      // Rot taken by a blast is reported separately and left out of the blast
      // tally, so the mode that cares about it can pay for it once, at its own
      // rate, rather than it being scored twice.
      final rotCells = {
        for (final cell in clearCells)
          if (current.at(cell)?.isRot ?? false) cell,
      };
      rotted += rotCells.length;

      final blastOnly = clearCells
          .difference(matches.cells)
          .difference(rotCells)
          .length;
      blasted += blastOnly;
      final stepScore = ScoreRules.stepScore(
        matches.lines,
        step,
        blastTiles: blastOnly,
      );
      score += stepScore;
      cleared += clearCells.length;
      fired += blast.detonated.length;
      if (matches.longestLine > longest) longest = matches.longestLine;

      if (blast.detonated.isNotEmpty) {
        events.add(SpecialsFired(blast.detonated));
      }
      events.add(
        TilesCleared(
          cells: clearCells.toList(),
          lines: matches.lines,
          scoreDelta: stepScore,
          cascadeStep: step,
          multiplier: ScoreRules.cascadeMultiplier(step),
        ),
      );
      current = current.withCleared(clearCells);

      final upgrades = <UpgradedTile>[];
      for (final spawn in spawns) {
        final tile = current.at(spawn.at);
        // Skip a power whose own tile was swallowed by a blast this step.
        if (tile == null) continue;
        final upgraded = tile.withPower(spawn.power);
        current = current.withTile(spawn.at, upgraded);
        upgrades.add(UpgradedTile(upgraded, spawn.at));
      }
      if (upgrades.isNotEmpty) {
        created += upgrades.length;
        events.add(SpecialsCreated(upgrades));
      }

      final settled = gravity.apply(current);
      current = settled.board;
      for (final batch in settled.steps) {
        if (batch.isNotEmpty) events.add(TilesMoved(batch));
      }

      final refilled = refill.apply(
        board: current,
        rng: rng,
        tiles: tiles,
        kindCount: kinds,
      );
      current = refilled.board;
      if (refilled.spawnedAnything) {
        events.add(TilesSpawned(refilled.spawned));
      }

      step++;
    }

    return ResolutionOutcome(
      board: current,
      events: events,
      score: score,
      cascadeCount: step - startStep,
      tilesCleared: cleared,
      longestLine: longest,
      specialsCreated: created,
      specialsFired: fired,
      clearedByKind: Map.unmodifiable(byKind),
      clearedCells: Set.unmodifiable(clearedCells),
      blastCleared: blasted,
      rotCleared: rotted,
    );
  }
}

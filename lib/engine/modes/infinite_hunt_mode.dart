import '../generation/board_generator.dart';
import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import 'game_mode.dart';

/// Endless score attack. Tiles refill from the top forever; the run ends the
/// moment the board has no legal move left. There is no shuffle rescue — the
/// dead board is the ending, so keeping the board alive is the real skill.
///
/// The palette widens as the run goes on: six colours to start, then one more
/// at 12,000, 24,000 and 36,000 points. A mode with no ending needs something
/// that gets harder, and an extra colour means fewer accidental lines and a
/// board that dies sooner — the difficulty knob that costs the player nothing
/// to understand. Nine is the ceiling, because nine is what the skins draw and
/// roughly where a colour stops being tellable at a glance on a small phone.
class InfiniteHuntMode extends GameMode {
  InfiniteHuntMode({
    this.grid = const GridConfig(rows: 8, cols: 8, kindCount: 6),
    this.pointsPerKind = 12000,
    this.maxKinds = 9,
  }) : assert(maxKinds <= 9, 'the skins only draw nine colours');

  @override
  final GridConfig grid;

  /// Score between one new colour and the next.
  final int pointsPerKind;

  /// The palette stops widening here.
  final int maxKinds;

  int _kindsUnlocked = 0;

  /// New colours added so far — the HUD announces each one as it lands.
  int get kindsUnlocked => _kindsUnlocked;

  @override
  int get activeKindCount => _clampKinds(_kindsUnlocked);

  /// Pure form of the ramp: how wide the palette is at a given score. Shares
  /// its arithmetic with [activeKindCount], so the curve can be reasoned about
  /// (and tested) without driving a whole run.
  int kindCountAt(int score) => _clampKinds(score ~/ pointsPerKind);

  int _clampKinds(int extra) =>
      (grid.kindCount + extra).clamp(grid.kindCount, maxKinds);

  /// Points still to score before the palette widens again, or null once it has
  /// reached [maxKinds].
  int? pointsToNextKind(int score) {
    if (activeKindCount >= maxKinds) return null;
    return (_kindsUnlocked + 1) * pointsPerKind - score;
  }

  /// True when this move earned a colour. Read straight after [afterMove].
  bool get justUnlockedKind => _justUnlocked;
  bool _justUnlocked = false;

  @override
  String? get announcement =>
      _justUnlocked ? 'New colour — $activeKindCount in play' : null;

  @override
  ModeStepOutcome afterMove(ModeContext ctx) {
    _justUnlocked = false;
    // The new colour only reaches the board through later refills: recolouring
    // tiles that are already down would be indistinguishable from a bug.
    final earned = ctx.score ~/ pointsPerKind;
    if (earned > _kindsUnlocked && activeKindCount < maxKinds) {
      _kindsUnlocked = earned;
      _justUnlocked = true;
    }
    return ModeStepOutcome(board: ctx.board);
  }

  @override
  String get id => 'infinite_hunt';

  @override
  String get name => 'Infinite Hunt';

  @override
  String get tagline => 'The board never runs dry. You do.';

  @override
  GravityRule get gravity => GravityRule.down;

  @override
  RefillRule get refill => RefillRule.fromTop;

  @override
  bool get allowsSpecials => true;

  @override
  Board createBoard(SeededRandom rng, TileFactory tiles) =>
      BoardGenerator.generate(grid: grid, rng: rng, tiles: tiles);

  @override
  ModeEvaluation evaluate(ModeContext ctx) =>
      MoveFinder.hasLegalMove(ctx.board, specials: allowsSpecials)
      ? const ModeEvaluation.playing()
      : const ModeEvaluation.lost(GameEndReason.noMovesLeft);

  @override
  GameMode fresh() => InfiniteHuntMode(
    grid: grid,
    pointsPerKind: pointsPerKind,
    maxKinds: maxKinds,
  );

  @override
  Map<String, Object?> saveState() => {'kindsUnlocked': _kindsUnlocked};

  @override
  void restoreState(Map<String, Object?> state) {
    _kindsUnlocked = state['kindsUnlocked'] as int? ?? 0;
  }
}

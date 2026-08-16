import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../matching/move_finder.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/hint.dart';
import '../models/position.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import '../resolution/resolver.dart';

enum GameStatus { playing, won, lost }

/// What the move that just resolved actually did.
///
/// The board has already settled and refilled by the time a mode is asked
/// anything, so a mode that scores progress — collect thirty blue, burn the rot
/// you cleared next to — cannot work it out by looking. This is the record.
class MoveSummary {
  const MoveSummary({
    required this.tilesCleared,
    required this.clearedByKind,
    required this.clearedCells,
    required this.cascadeCount,
    required this.longestLine,
    required this.blastCleared,
    required this.specialsFired,
    required this.specialsCreated,
  });

  final int tilesCleared;

  /// Tiles taken, by kind. Roles that never match — cargo, rot — are absent.
  final Map<int, int> clearedByKind;

  /// Where tiles went out. Cells from different cascade steps, so treat it as
  /// "where the action was" rather than as one board state.
  final Set<Pos> clearedCells;

  final int cascadeCount;
  final int longestLine;

  /// Tiles taken by a power rather than by a line.
  final int blastCleared;

  final int specialsFired;
  final int specialsCreated;

  int clearedOf(int kind) => clearedByKind[kind] ?? 0;
}

/// Read-only view of the run handed to a mode when it is asked to decide
/// something. Modes never reach into the engine directly.
class ModeContext {
  const ModeContext({
    required this.board,
    required this.score,
    required this.movesMade,
    required this.rng,
    required this.tiles,
    required this.resolver,
    this.move,
  });

  final Board board;
  final int score;
  final int movesMade;
  final SeededRandom rng;
  final TileFactory tiles;
  final Resolver resolver;

  /// The move being reacted to, when there is one. Null at the start of a run,
  /// after an undo, and any other time the mode is asked to look at a board
  /// that nobody just played into.
  final MoveSummary? move;

  ModeContext withBoard(Board next) => ModeContext(
    board: next,
    score: score,
    movesMade: movesMade,
    rng: rng,
    tiles: tiles,
    resolver: resolver,
    move: move,
  );
}

/// One line of a mode's goal readout: "24 / 40 Blue".
///
/// Modes expose these rather than the HUD reaching in and type-checking, so a
/// new mode with goals gets the readout for free.
class ModeGoal {
  const ModeGoal({
    required this.label,
    required this.progress,
    required this.target,
    this.tileKind,
  });

  final String label;
  final int progress;
  final int target;

  /// The tile kind this goal is about, when it is about one. The HUD draws the
  /// active skin's artwork for it — the engine has never known what a kind
  /// looks like, and a goal readout is no reason to start.
  final int? tileKind;

  bool get isDone => progress >= target;
  double get fraction => target == 0 ? 1 : (progress / target).clamp(0, 1);
}

/// What a mode did after the player's move resolved.
class ModeStepOutcome {
  const ModeStepOutcome({
    required this.board,
    this.events = const [],
    this.scoreDelta = 0,
  });

  final Board board;
  final List<BoardEvent> events;
  final int scoreDelta;
}

class ModeEvaluation {
  const ModeEvaluation._(this.status, this.reason);

  const ModeEvaluation.playing() : this._(GameStatus.playing, null);
  const ModeEvaluation.won(GameEndReason reason)
    : this._(GameStatus.won, reason);
  const ModeEvaluation.lost(GameEndReason reason)
    : this._(GameStatus.lost, reason);

  final GameStatus status;
  final GameEndReason? reason;

  bool get isOver => status != GameStatus.playing;
}

/// A way to play. Modes compose the shared rules — matching and scoring are
/// never reimplemented here — and only decide how the board is seeded, what
/// happens between moves, and when the run is over.
abstract class GameMode {
  const GameMode();

  String get id;
  String get name;
  String get tagline;

  GridConfig get grid;
  GravityRule get gravity;
  RefillRule get refill;

  /// How many times the player may take a move back. 0 disables undo.
  ///
  /// Undo can only be offered by modes that draw no randomness during play —
  /// [SeededRandom] cannot be rewound, so a mode that refills would desync.
  int get undoBudget => 0;

  bool get allowsUndo => undoBudget > 0;

  /// Optional cap on accepted moves.
  int? get moveLimit => null;

  /// Hints the player starts a run with.
  ///
  /// Hints are a resource, not a button you can lean on: an endless mode with
  /// unlimited hints plays itself.
  int get startingHints => 3;

  /// Score needed to earn one more hint.
  int get pointsPerHint => 1000;

  /// How many tile kinds are actually in play right now.
  ///
  /// Fixed for most modes. Infinite Hunt raises it as the run goes on, which is
  /// what stops a long run from getting easier as the player gets better.
  int get activeKindCount => grid.kindCount;

  /// The move to show when the player spends a hint.
  ///
  /// The default is *a* legal move drawn at random, not the first one found:
  /// scanning order means the first is nearly always in the top-left corner,
  /// which makes repeated hints look broken and quietly teaches the player to
  /// only look there. [rng] is the engine's hint generator, deliberately not
  /// the one the board draws from — a hint must not change what falls next.
  ///
  /// A mode that can say more should override this. Clear the Board does.
  Hint? hintFor(Board board, SeededRandom rng) {
    final moves = MoveFinder.legalMoves(board, specials: allowsSpecials);
    return moves.isEmpty ? null : Hint(rng.pick(moves));
  }

  /// What the player is working towards, for the HUD to draw. Empty for the
  /// modes whose only goal is to keep going.
  List<ModeGoal> get goals => const [];

  /// A short line for the HUD to flash after a move, when a rule has just
  /// changed under the player. Null for the great majority of moves.
  String? get announcement => null;

  /// Whether matches of four or more create powers.
  ///
  /// Off by default, and deliberately off in Clear the Board: its levels ship
  /// with a solution proven under plain-match rules, and powers would make
  /// every par meaningless.
  bool get allowsSpecials => false;

  Board createBoard(SeededRandom rng, TileFactory tiles);

  /// Runs after the player's cascade has fully settled — the tide rises here.
  ModeStepOutcome afterMove(ModeContext ctx) =>
      ModeStepOutcome(board: ctx.board);

  ModeEvaluation evaluate(ModeContext ctx);

  /// A clean instance for a restart. Stateless modes may return themselves.
  GameMode fresh();

  /// Per-run state that has to survive being saved and reloaded. Stateless
  /// modes need neither of these; Rising Tide keeps its tide counters here.
  Map<String, Object?> saveState() => const {};

  void restoreState(Map<String, Object?> state) {}
}

import '../gravity/gravity_rule.dart';
import '../gravity/refill_rule.dart';
import '../models/board.dart';
import '../models/grid_config.dart';
import '../models/tile.dart';
import '../random/seeded_random.dart';
import '../resolution/board_event.dart';
import '../resolution/resolver.dart';

enum GameStatus { playing, won, lost }

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
  });

  final Board board;
  final int score;
  final int movesMade;
  final SeededRandom rng;
  final TileFactory tiles;
  final Resolver resolver;

  ModeContext withBoard(Board next) => ModeContext(
    board: next,
    score: score,
    movesMade: movesMade,
    rng: rng,
    tiles: tiles,
    resolver: resolver,
  );
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
}

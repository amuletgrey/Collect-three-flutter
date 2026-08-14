import 'matching/match_finder.dart';
import 'matching/move_finder.dart';
import 'models/board.dart';
import 'models/move.dart';
import 'models/position.dart';
import 'models/tile.dart';
import 'modes/game_mode.dart';
import 'persistence/run_snapshot.dart';
import 'random/seeded_random.dart';
import 'resolution/board_event.dart';
import 'resolution/move_result.dart';
import 'resolution/resolver.dart';

/// One run of the game: the board, the score, and the only entry point for
/// changing either.
///
/// Everything here is deterministic — `(seed, mode, list of moves)` reproduces a
/// run exactly. Nothing in this file knows how anything looks or how long an
/// animation takes.
class GameEngine {
  GameEngine({required GameMode mode, required int seed})
    : _mode = mode,
      _rng = SeededRandom(seed),
      _tiles = TileFactory() {
    _buildResolver();
    _board = mode.createBoard(_rng, _tiles);
    _undosRemaining = mode.undoBudget;
    _hintsRemaining = mode.startingHints;
    _applyEvaluation(mode.evaluate(_context));
  }

  /// Picks a saved run back up exactly where it stopped.
  ///
  /// [mode] must be a fresh instance of the mode named in the snapshot; its
  /// own state is restored from [RunSnapshot.modeState].
  GameEngine.restore({required GameMode mode, required RunSnapshot snapshot})
    : assert(mode.id == snapshot.modeId, 'snapshot belongs to another mode'),
      _mode = mode,
      _rng = SeededRandom(
        snapshot.seed,
        state: snapshot.rngState,
        drawCount: snapshot.rngDraws,
      ),
      _tiles = TileFactory(snapshot.nextTileId) {
    _buildResolver();
    _board = snapshot.toBoard();
    _score = snapshot.score;
    _movesMade = snapshot.movesMade;
    _tilesCollected = snapshot.tilesCollected;
    _bestChain = snapshot.bestChain;
    _longestLine = snapshot.longestLine;
    _specialsFired = snapshot.specialsFired;
    _undosRemaining = mode.undoBudget;
    _hintsRemaining = snapshot.hintsRemaining ?? mode.startingHints;
    _hintsEarned = snapshot.hintsEarned;
    mode.restoreState(snapshot.modeState);
    _applyEvaluation(mode.evaluate(_context));
  }

  void _buildResolver() {
    _resolver = Resolver(
      gravity: _mode.gravity,
      refill: _mode.refill,
      kindCount: _mode.grid.kindCount,
      allowsSpecials: _mode.allowsSpecials,
    );
  }

  /// Freezes the run so it can be stored and resumed later.
  RunSnapshot snapshot({int? levelNumber, String? packId}) => RunSnapshot(
    version: RunSnapshot.currentVersion,
    modeId: _mode.id,
    rows: _board.rows,
    cols: _board.cols,
    cells: RunSnapshot.cellsOf(_board),
    seed: _rng.seed,
    rngState: _rng.state,
    rngDraws: _rng.drawCount,
    nextTileId: _tiles.nextId,
    score: _score,
    movesMade: _movesMade,
    tilesCollected: _tilesCollected,
    bestChain: _bestChain,
    longestLine: _longestLine,
    specialsFired: _specialsFired,
    hintsRemaining: _hintsRemaining,
    hintsEarned: _hintsEarned,
    modeState: _mode.saveState(),
    levelNumber: levelNumber,
    packId: packId,
  );

  final GameMode _mode;
  final SeededRandom _rng;
  final TileFactory _tiles;
  late final Resolver _resolver;

  late Board _board;
  int _score = 0;
  int _movesMade = 0;
  int _tilesCollected = 0;
  int _bestChain = 0;
  int _longestLine = 0;
  int _specialsFired = 0;
  int _undosRemaining = 0;
  int _hintsRemaining = 0;
  int _hintsEarned = 0;
  int _hintsJustEarned = 0;
  GameStatus _status = GameStatus.playing;
  GameEndReason? _endReason;

  final List<_Snapshot> _undoStack = [];

  GameMode get mode => _mode;
  Board get board => _board;
  int get score => _score;
  int get movesMade => _movesMade;
  int get tilesCollected => _tilesCollected;

  /// Longest cascade of the run so far — the results screen's headline stat.
  int get bestChain => _bestChain;
  int get longestLine => _longestLine;

  /// Powers set off across the whole run — a results-screen stat.
  int get specialsFired => _specialsFired;
  int get seed => _rng.seed;
  GameStatus get status => _status;
  GameEndReason? get endReason => _endReason;
  bool get isOver => _status != GameStatus.playing;
  int get undosRemaining => _undosRemaining;

  /// Hints the player can still spend.
  int get hintsRemaining => _hintsRemaining;

  /// Hints handed out by the last move, for the UI to announce.
  int get hintsJustEarned => _hintsJustEarned;

  /// Points still to score before the next hint arrives.
  int get pointsToNextHint =>
      (_hintsEarned + 1) * _mode.pointsPerHint - _score;
  bool get canUndo =>
      _mode.allowsUndo && _undosRemaining > 0 && _undoStack.isNotEmpty;

  /// Moves left, for modes with a budget.
  int? get movesRemaining {
    final limit = _mode.moveLimit;
    return limit == null ? null : (limit - _movesMade).clamp(0, limit);
  }

  List<Move> get legalMoves =>
      MoveFinder.legalMoves(_board, specials: _mode.allowsSpecials);

  /// Peeks at a legal move without spending anything. This is the solver's
  /// entry point — [useHint] is the player's.
  Move? hint() =>
      MoveFinder.firstLegalMove(_board, specials: _mode.allowsSpecials);

  /// Spends a hint. Returns null — and costs nothing — when the player has
  /// none left or the board has nothing to show.
  Move? useHint() {
    if (_hintsRemaining <= 0) return null;
    final move = hint();
    if (move == null) return null;
    _hintsRemaining--;
    return move;
  }

  /// One hint per [GameMode.pointsPerHint], caught up in a loop because a big
  /// cascade can cross several milestones at once.
  void _awardHints() {
    final earned = _score ~/ _mode.pointsPerHint;
    if (earned <= _hintsEarned) return;
    _hintsJustEarned = earned - _hintsEarned;
    _hintsRemaining += _hintsJustEarned;
    _hintsEarned = earned;
  }

  ModeContext get _context => ModeContext(
    board: _board,
    score: _score,
    movesMade: _movesMade,
    rng: _rng,
    tiles: _tiles,
    resolver: _resolver,
  );

  MoveResult applyMove(Pos a, Pos b) {
    _hintsJustEarned = 0;
    if (isOver) return MoveResult.rejected(MoveRejection.gameOver);
    if (!a.isAdjacentTo(b)) {
      return MoveResult.rejected(MoveRejection.notAdjacent);
    }

    final tileA = _board.at(a);
    final tileB = _board.at(b);
    if (tileA == null || tileB == null) {
      return MoveResult.rejected(MoveRejection.emptyCell);
    }
    // A colour bomb goes off on contact, so its swap is legal even between two
    // tiles of the same kind and even though it forms no line.
    final fires = _mode.allowsSpecials && MoveFinder.firesOnSwap(tileA, tileB);
    if (!fires && tileA.kind == tileB.kind) {
      return MoveResult.rejected(MoveRejection.sameKind);
    }

    final swapped = _board.withSwap(a, b);
    if (!fires &&
        !MatchFinder.hasMatchThrough(swapped, a) &&
        !MatchFinder.hasMatchThrough(swapped, b)) {
      // Shown to the player as a swap that snaps back. Costs nothing.
      return MoveResult.reverted([SwapPerformed(a, b), SwapReverted(a, b)]);
    }

    _pushSnapshot();
    _board = swapped;
    _movesMade++;

    final events = <BoardEvent>[SwapPerformed(a, b)];
    // After the swap the tiles have traded places: what was at `a` is now at `b`.
    final primed = <Pos>{};
    final primedKinds = <Pos, int>{};
    if (fires) {
      if (tileA.power == TilePower.colourBomb) {
        primed.add(b);
        primedKinds[b] = tileB.kind;
      }
      if (tileB.power == TilePower.colourBomb) {
        primed.add(a);
        primedKinds[a] = tileA.kind;
      }
      if (primed.isEmpty) primed.addAll({a, b});
    }

    final resolution = _resolver.resolve(
      board: _board,
      rng: _rng,
      tiles: _tiles,
      origins: {a, b},
      kindCount: _mode.activeKindCount,
      primed: primed,
      primedKinds: primedKinds,
    );
    _board = resolution.board;
    _score += resolution.score;
    _tilesCollected += resolution.tilesCleared;
    events.addAll(resolution.events);
    if (resolution.cascadeCount > _bestChain) {
      _bestChain = resolution.cascadeCount;
    }
    if (resolution.longestLine > _longestLine) {
      _longestLine = resolution.longestLine;
    }
    _specialsFired += resolution.specialsFired;

    final step = _mode.afterMove(_context);
    _board = step.board;
    _score += step.scoreDelta;
    events.addAll(step.events);

    _awardHints();

    final evaluation = _mode.evaluate(_context);
    _applyEvaluation(evaluation);
    if (evaluation.isOver && evaluation.reason != null) {
      events.add(GameEnded(evaluation.reason!));
    }

    return MoveResult.accepted(
      events: events,
      scoreDelta: resolution.score + step.scoreDelta,
      cascadeCount: resolution.cascadeCount,
      tilesCleared: resolution.tilesCleared,
      longestLine: resolution.longestLine,
      specialsCreated: resolution.specialsCreated,
      specialsFired: resolution.specialsFired,
    );
  }

  /// Takes the last accepted move back. Only offered by modes that draw no
  /// randomness during play — see [GameMode.undoBudget].
  bool undo() {
    if (!canUndo) return false;
    final snapshot = _undoStack.removeLast();
    _board = snapshot.board;
    _score = snapshot.score;
    _movesMade = snapshot.movesMade;
    _tilesCollected = snapshot.tilesCollected;
    _tiles.restore(snapshot.nextTileId);
    _undosRemaining--;
    _applyEvaluation(_mode.evaluate(_context));
    return true;
  }

  void _pushSnapshot() {
    if (!_mode.allowsUndo) return;
    _undoStack.add(
      _Snapshot(
        board: _board,
        score: _score,
        movesMade: _movesMade,
        tilesCollected: _tilesCollected,
        nextTileId: _tiles.nextId,
      ),
    );
    // Only as deep as the budget allows, so a long level does not accumulate
    // snapshots nobody can ever use.
    while (_undoStack.length > _mode.undoBudget) {
      _undoStack.removeAt(0);
    }
  }

  void _applyEvaluation(ModeEvaluation evaluation) {
    _status = evaluation.status;
    _endReason = evaluation.isOver ? evaluation.reason : null;
  }
}

class _Snapshot {
  const _Snapshot({
    required this.board,
    required this.score,
    required this.movesMade,
    required this.tilesCollected,
    required this.nextTileId,
  });

  final Board board;
  final int score;
  final int movesMade;
  final int tilesCollected;
  final int nextTileId;
}

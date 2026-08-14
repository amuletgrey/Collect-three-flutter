import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../engine/engine.dart';
import '../services/haptics_service.dart';
import 'motion.dart';

/// Bridges the engine to the screen.
///
/// The engine resolves a whole move synchronously and hands back an ordered
/// list of events; this class replays that list as visual state over time. It
/// is the only place allowed to translate engine events into animation, and it
/// never re-derives what happened — it just plays what it was given.
class GameController extends ChangeNotifier {
  GameController({
    required GameMode mode,
    required int seed,
    Motion motion = const Motion(),
  }) : _engine = GameEngine(mode: mode, seed: seed) {
    _motion = motion;
    _syncFromBoard(_engine.board);
  }

  GameEngine _engine;
  Motion _motion = const Motion();
  HapticsService _haptics = const HapticsService(enabled: false);

  /// Where each live tile is drawn, by tile id. Diverges from the engine board
  /// only while a move is being animated.
  final Map<int, Pos> _positions = {};
  final Map<int, Tile> _tiles = {};
  final Set<int> _clearing = {};

  Pos? _selected;
  Move? _hint;
  Set<Pos> _rejected = const {};
  Set<Pos> _firing = const {};
  bool _busy = false;
  bool _disposed = false;
  Duration _stepDuration = Duration.zero;

  GameEngine get engine => _engine;
  GameMode get mode => _engine.mode;
  Board get board => _engine.board;
  int get score => _engine.score;
  int get movesMade => _engine.movesMade;
  GameStatus get status => _engine.status;
  GameEndReason? get endReason => _engine.endReason;
  bool get isOver => _engine.isOver;
  int get bestChain => _engine.bestChain;
  int get undosRemaining => _engine.undosRemaining;
  bool get canUndo => _engine.canUndo && !_busy;

  /// True while events are being played out — input is ignored.
  bool get busy => _busy;

  /// How long the tiles should take to reach the positions they were just
  /// given. The board view animates with exactly this, so the visuals finish
  /// when the controller stops waiting.
  Duration get stepDuration => _stepDuration;

  Pos? get selected => _selected;
  Move? get hint => _hint;

  /// Cells that just refused a swap. The board wiggles them, which is the only
  /// feedback the player gets for a move the engine threw away outright.
  bool isRejected(Pos pos) => _rejected.contains(pos);

  /// Cells whose power is going off right now — the board flashes them.
  bool isFiring(Pos pos) => _firing.contains(pos);

  Iterable<int> get tileIds => _tiles.keys;
  Tile tileById(int id) => _tiles[id]!;
  Pos positionOf(int id) => _positions[id]!;
  bool isClearing(int id) => _clearing.contains(id);

  set motion(Motion value) => _motion = value;
  set haptics(HapticsService value) => _haptics = value;

  /// Tap-to-select input: the second tap on a neighbour plays the move.
  Future<void> tap(Pos pos) async {
    if (_busy || isOver) return;
    final current = _selected;
    if (current == null) {
      if (board.isEmptyAt(pos)) return;
      _selected = pos;
      notifyListeners();
      return;
    }
    if (current == pos) {
      _selected = null;
      notifyListeners();
      return;
    }
    if (!current.isAdjacentTo(pos)) {
      _selected = board.isEmptyAt(pos) ? null : pos;
      notifyListeners();
      return;
    }
    await swap(current, pos);
  }

  /// Drag input: swipe a tile towards its neighbour.
  Future<void> swipe(Pos from, Pos to) async {
    if (_busy || isOver) return;
    await swap(from, to);
  }

  Future<void> swap(Pos a, Pos b) async {
    if (_busy || isOver) return;
    _selected = null;
    _hint = null;

    final result = _engine.applyMove(a, b);
    if (!result.hasEvents) {
      // Refused before anything moved — same kind, a hole, or the run is over.
      await _flashRejection({a, b});
      return;
    }
    await _play(result.events);
  }

  void showHint() {
    if (_busy || isOver) return;
    _hint = _engine.hint();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _engine.undo();
    _selected = null;
    _hint = null;
    _syncFromBoard(_engine.board);
    notifyListeners();
  }

  void restart({int? seed}) {
    _engine = GameEngine(
      mode: _engine.mode.fresh(),
      seed: seed ?? _engine.seed,
    );
    _selected = null;
    _hint = null;
    _busy = false;
    _syncFromBoard(_engine.board);
    notifyListeners();
  }

  // --------------------------------------------------------------- playback

  Future<void> _play(List<BoardEvent> events) async {
    _busy = true;
    notifyListeners();

    for (final event in events) {
      if (_disposed) return;
      _haptics.forEvent(event);
      switch (event) {
        case SwapPerformed(:final a, :final b):
          _stepDuration = _motion.swap;
          _swapPositions(a, b);
          await _wait(_motion.swap);
        case SwapReverted(:final a, :final b):
          _stepDuration = _motion.revert;
          _rejected = {a, b};
          _swapPositions(a, b);
          await _wait(_motion.revert);
          _rejected = const {};
          notifyListeners();
        case TilesCleared(:final cells):
          _stepDuration = _motion.clear;
          _clearing.addAll(cells.map(_idAt).whereType<int>());
          notifyListeners();
          await _wait(_motion.clear);
          for (final id in _clearing) {
            _positions.remove(id);
            _tiles.remove(id);
          }
          _clearing.clear();
          notifyListeners();
        case TilesMoved(:final moves):
          var longest = 1;
          for (final move in moves) {
            _positions[move.tileId] = move.to;
            final distance = move.rowsTravelled + move.colsTravelled;
            if (distance > longest) longest = distance;
          }
          _stepDuration = _motion.fallPerCell * longest;
          notifyListeners();
          await _wait(_stepDuration);
        case TilesSpawned(:final tiles):
          await _spawn(tiles, _motion.spawn);
        case RowInserted(:final pushed, :final spawned):
          _stepDuration = _motion.rowInsert;
          for (final move in pushed) {
            _positions[move.tileId] = move.to;
          }
          notifyListeners();
          await _spawn(spawned, _motion.rowInsert);
        case SpecialsFired(:final origins):
          _stepDuration = _motion.clear;
          _firing = origins.toSet();
          notifyListeners();
          await _wait(_motion.blast);
          _firing = const {};
          notifyListeners();
        case SpecialsCreated(:final tiles):
          for (final upgraded in tiles) {
            _tiles[upgraded.tile.id] = upgraded.tile;
            _positions[upgraded.tile.id] = upgraded.at;
          }
          _stepDuration = _motion.clear;
          notifyListeners();
          await _wait(_motion.specialBirth);
        case GameEnded():
          notifyListeners();
      }
      await _wait(_motion.cascadeGap);
    }

    // The engine is the source of truth; make sure playback left us on it.
    _syncFromBoard(_engine.board);
    _busy = false;
    notifyListeners();
  }

  Future<void> _flashRejection(Set<Pos> cells) async {
    _rejected = cells;
    notifyListeners();
    await _wait(_motion.revert);
    if (_disposed) return;
    _rejected = const {};
    notifyListeners();
  }

  /// Places new tiles off-board, lets one frame render, then slides them in.
  Future<void> _spawn(List<SpawnedTile> spawned, Duration duration) async {
    _stepDuration = duration;
    for (final spawn in spawned) {
      _tiles[spawn.tile.id] = spawn.tile;
      _positions[spawn.tile.id] = spawn.from;
    }
    notifyListeners();
    await SchedulerBinding.instance.endOfFrame;
    if (_disposed) return;
    for (final spawn in spawned) {
      _positions[spawn.tile.id] = spawn.at;
    }
    notifyListeners();
    await _wait(duration);
  }

  void _swapPositions(Pos a, Pos b) {
    final idA = _idAt(a);
    final idB = _idAt(b);
    if (idA != null) _positions[idA] = b;
    if (idB != null) _positions[idB] = a;
    notifyListeners();
  }

  int? _idAt(Pos pos) {
    for (final entry in _positions.entries) {
      if (entry.value == pos && !_clearing.contains(entry.key)) {
        return entry.key;
      }
    }
    return null;
  }

  void _syncFromBoard(Board board) {
    _positions
      ..clear()
      ..addEntries(
        board.positions
            .where((p) => !board.isEmptyAt(p))
            .map((p) => MapEntry(board.at(p)!.id, p)),
      );
    _tiles
      ..clear()
      ..addEntries(board.tiles.map((t) => MapEntry(t.id, t)));
    _clearing.clear();
    _firing = const {};
  }

  Future<void> _wait(Duration duration) async {
    if (duration == Duration.zero) return;
    await Future<void>.delayed(duration);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

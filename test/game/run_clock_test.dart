import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';
import 'package:tessera/game/game_controller.dart';
import 'package:tessera/game/motion.dart';

/// Clear the Board never refills, so playing a move here does not wait on a
/// frame — these are plain unit tests with no widget binding to pump one.
const _mode = ClearBoardMode(
  grid: GridConfig(rows: 3, cols: 4, kindCount: 3),
  layoutSketch: '1102\n2210\n0021',
);

GameController _controller() =>
    GameController(mode: _mode, seed: 4, motion: const Motion(reduced: true));

/// The one legal opening on that layout.
Future<void> _playAMove(GameController controller) =>
    controller.swap(const Pos(0, 2), const Pos(1, 2));

void main() {
  test('the clock does not run before the first move', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.elapsed, Duration.zero);
  });

  test('it runs once play starts', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await _playAMove(controller);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.elapsed, greaterThan(Duration.zero));
  });

  test('a resumed run keeps the time it had already banked', () {
    final base = _controller();
    addTearDown(base.dispose);
    final snapshot = base.snapshot();

    final carried = RunSnapshot(
      version: snapshot.version,
      modeId: snapshot.modeId,
      rows: snapshot.rows,
      cols: snapshot.cols,
      cells: snapshot.cells,
      seed: snapshot.seed,
      rngState: snapshot.rngState,
      rngDraws: snapshot.rngDraws,
      nextTileId: snapshot.nextTileId,
      score: snapshot.score,
      movesMade: snapshot.movesMade,
      tilesCollected: snapshot.tilesCollected,
      bestChain: snapshot.bestChain,
      longestLine: snapshot.longestLine,
      specialsFired: snapshot.specialsFired,
      elapsedSeconds: 125,
    );

    final resumed = GameController.resume(mode: _mode, snapshot: carried);
    addTearDown(resumed.dispose);

    expect(resumed.elapsed.inSeconds, greaterThanOrEqualTo(125));
  });

  test('a snapshot carries the elapsed time out again', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await _playAMove(controller);
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(controller.snapshot().elapsedSeconds, greaterThanOrEqualTo(1));
  });

  test('restarting puts the clock back to zero', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await _playAMove(controller);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.elapsed, greaterThan(Duration.zero));

    controller.restart();

    expect(controller.elapsed, Duration.zero);
  });

  test('an old save without a time reads as zero, not as a crash', () {
    final json = {
      ...GameEngine(
        mode: InfiniteHuntMode(),
        seed: 1,
      ).snapshot().toJson(),
    }..remove('elapsed');

    expect(RunSnapshot.fromJson(json).elapsedSeconds, 0);
  });
}

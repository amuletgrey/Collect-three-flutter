import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';
import 'package:tessera/game/game_controller.dart';
import 'package:tessera/game/motion.dart';

/// Clear the Board never refills, so a move here plays out without a frame to
/// pump — these stay plain unit tests. The layout has one legal opening.
const _grid = GridConfig(rows: 3, cols: 4, kindCount: 3);
const _sketch = '1102\n2210\n0021';
const _opening = Move(Pos(0, 2), Pos(1, 2));

/// Hints cheap enough that the single opening move earns some.
class _CheapHints extends ClearBoardMode {
  const _CheapHints() : super(grid: _grid, layoutSketch: _sketch);

  @override
  int get pointsPerHint => 10;
}

/// One hint exactly: the opening move scores 30, and the milestone matches.
class _OneHint extends ClearBoardMode {
  const _OneHint() : super(grid: _grid, layoutSketch: _sketch);

  @override
  int get pointsPerHint => 30;
}

/// Seven legal moves and no winning line — the state a careless clear leaves
/// behind in a mode with no refills.
class _Wrecked extends ClearBoardMode {
  const _Wrecked()
    : super(
        grid: const GridConfig(rows: 4, cols: 4, kindCount: 3),
        layoutSketch: '0201\n2122\n0020\n2200',
      );
}

/// Known solvable: two moves clear it.
class _Winnable extends ClearBoardMode {
  const _Winnable()
    : super(
        grid: const GridConfig(rows: 3, cols: 3, kindCount: 3),
        layoutSketch: '110\n011\n101',
      );
}

/// Adds a mode announcement on top, standing in for Infinite Hunt's new
/// colour — the controller should relay whatever the mode says.
class _Chatty extends _CheapHints {
  const _Chatty();

  @override
  String? get announcement => 'New colour — 7 in play';
}

GameController _controller({GameMode mode = const _CheapHints()}) =>
    GameController(mode: mode, seed: 4, motion: const Motion(reduced: true));

void main() {
  test('a fresh run is not announcing anything', () {
    final controller = _controller();
    addTearDown(controller.dispose);

    expect(controller.notices, isEmpty);
    expect(controller.noticeTick, 0);
  });

  test('earning a hint says so, once the board has settled', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await controller.swap(_opening.a, _opening.b);

    expect(controller.notices, hasLength(1));
    expect(controller.notices.single, matches(RegExp(r'^\+\d+ hints?$')));
    expect(controller.noticeTick, 1);
    expect(controller.busy, isFalse, reason: 'raised after playback, not during');
  });

  test('one earned hint is not pluralised', () async {
    final controller = _controller(mode: const _OneHint());
    addTearDown(controller.dispose);

    await controller.swap(_opening.a, _opening.b);

    expect(controller.notices.single, '+1 hint');
  });

  test('a mode announcement is relayed, and leads', () async {
    final controller = _controller(mode: const _Chatty());
    addTearDown(controller.dispose);

    await controller.swap(_opening.a, _opening.b);

    expect(controller.notices.first, 'New colour — 7 in play');
    expect(controller.notices, hasLength(2));
  });

  test('a refused swap announces nothing', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await controller.swap(const Pos(0, 0), const Pos(0, 1));

    expect(controller.notices, isEmpty);
    expect(controller.noticeTick, 0);
  });

  test('spending a hint marks a move, and running out shows nothing', () {
    final controller = _controller();
    addTearDown(controller.dispose);

    expect(controller.hintsRemaining, 3);
    controller.showHint();
    expect(controller.hint, isNotNull);
    expect(controller.hintsRemaining, 2);

    controller
      ..showHint()
      ..showHint()
      ..showHint();

    expect(controller.hintsRemaining, 0);
    expect(controller.canHint, isFalse);
  });

  test('a hint on a level that cannot be won says so', () {
    final controller = _controller(mode: const _Wrecked());
    addTearDown(controller.dispose);

    controller.showHint();

    expect(controller.hint, isNotNull, reason: 'still shows a legal move');
    expect(controller.hintKind, HintKind.deadEnd);
    expect(controller.notices.single, contains('No winning path'));
    expect(controller.noticeTick, 1);
  });

  test('a hint on a level that can still be won stays quiet', () {
    final controller = _controller(mode: const _Winnable());
    addTearDown(controller.dispose);

    controller.showHint();

    expect(controller.hintKind, HintKind.winningLine);
    expect(controller.notices, isEmpty);
    expect(controller.noticeTick, 0);
  });

  test('playing a move puts the hint away, kind and all', () async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.showHint();
    expect(controller.hintKind, isNotNull);

    await controller.swap(_opening.a, _opening.b);

    expect(controller.hint, isNull);
    expect(controller.hintKind, isNull);
  });

  test('restarting clears the notice board', () async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.swap(_opening.a, _opening.b);
    expect(controller.notices, isNotEmpty);

    controller.restart();

    expect(controller.notices, isEmpty);
    expect(controller.hintsRemaining, 3);
  });
}

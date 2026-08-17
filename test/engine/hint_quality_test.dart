import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// Six 1s and three 0s — two moves clear the lot. Borrowed from the solver's
/// own tests, so it is known-good.
const _solvable = '110\n011\n101';

/// Has seven legal moves and no winning line at all. Found by brute force; the
/// point of the fixture is that a hint here has something to show and still
/// must not pretend the level can be finished.
const _deadEnd = '0201\n2122\n0020\n2200';

/// No legal move anywhere.
const _stuck = '012\n120\n201';

/// Hints on tap rather than three a run, so a test can follow them to the end.
class _Guided extends ClearBoardMode {
  _Guided(String sketch)
    : super(
        grid: GridConfig(
          rows: sketch.split('\n').length,
          cols: sketch.split('\n').first.length,
          kindCount: 3,
        ),
        layoutSketch: sketch,
      );

  @override
  int get startingHints => 99;
}

GameEngine _clearBoard(String sketch) =>
    GameEngine(mode: _Guided(sketch), seed: 1);

void main() {
  group('Clear the Board steers towards a win', () {
    test('following the hints actually empties the board', () {
      final engine = _clearBoard(_solvable);

      var guard = 0;
      while (!engine.board.isEmpty && guard++ < 20) {
        final hint = engine.useHint();
        expect(hint, isNotNull, reason: 'ran out of suggestions mid-level');
        expect(
          hint!.kind,
          HintKind.winningLine,
          reason: 'a solvable level should promise a win',
        );
        expect(engine.applyMove(hint.move.a, hint.move.b).accepted, isTrue);
      }

      expect(engine.board.isEmpty, isTrue);
      expect(engine.status, GameStatus.won);
    });

    test('a level that can no longer be won says so', () {
      final engine = _clearBoard(_deadEnd);

      final hint = engine.useHint();

      expect(hint, isNotNull);
      expect(hint!.kind, HintKind.deadEnd);
      expect(hint.isDeadEnd, isTrue);
      expect(hint.leadsToWin, isFalse);
    });

    test('even a dead end hands back a move that can be played', () {
      final engine = _clearBoard(_deadEnd);

      final hint = engine.useHint()!;

      expect(engine.applyMove(hint.move.a, hint.move.b).accepted, isTrue);
    });

    test('a board with no moves costs nothing and shows nothing', () {
      final engine = _clearBoard(_stuck);

      expect(engine.useHint(), isNull);
      expect(engine.hintsRemaining, 99);
    });

    test('the solver only runs for the player, never for a peek', () {
      // `hint()` is called in loops by tests and by anything driving the game,
      // so it must stay the cheap scan rather than a search.
      final engine = _clearBoard(_deadEnd);

      final peeked = engine.hint();

      expect(peeked, isNotNull);
      expect(engine.hintsRemaining, 99);
    });
  });

  group('every other mode shows a move at random', () {
    test('repeated hints do not all point at the same tile', () {
      final mode = InfiniteHuntMode();
      final board = mode.createBoard(SeededRandom(5), TileFactory());
      final rng = SeededRandom(1);

      final seen = <Move>{};
      for (var i = 0; i < 60; i++) {
        final hint = mode.hintFor(board, rng);
        if (hint != null) seen.add(hint.move);
      }

      expect(
        seen.length,
        greaterThan(1),
        reason:
            'a hint that never moves teaches the player to stare at one '
            'corner',
      );
    });

    test('and it is not always the top-left one', () {
      final mode = InfiniteHuntMode();
      final board = mode.createBoard(SeededRandom(5), TileFactory());
      final first = MoveFinder.firstLegalMove(board, specials: true);
      final rng = SeededRandom(1);

      final differed = [
        for (var i = 0; i < 60; i++) mode.hintFor(board, rng)!.move,
      ].any((move) => move != first);

      expect(differed, isTrue);
    });

    test('every move it offers is one the engine will accept', () {
      final mode = InfiniteHuntMode();
      final engine = GameEngine(mode: mode, seed: 12);
      final rng = SeededRandom(3);

      for (var i = 0; i < 40; i++) {
        final hint = mode.hintFor(engine.board, rng);
        if (hint == null) continue;
        expect(
          MoveFinder.createsMatch(
            engine.board,
            hint.move.a,
            hint.move.b,
            specials: mode.allowsSpecials,
          ),
          isTrue,
          reason: 'offered an illegal move: ${hint.move}',
        );
      }
    });

    test('a plain mode promises nothing beyond legality', () {
      final mode = InfiniteHuntMode();
      final board = mode.createBoard(SeededRandom(5), TileFactory());

      expect(mode.hintFor(board, SeededRandom(1))!.kind, HintKind.legalMove);
    });
  });

  test('asking for hints does not change how the run plays out', () {
    // The hint generator is deliberately separate from the board's. A run has
    // to replay identically whether or not the player asked for help.
    final plain = GameEngine(mode: InfiniteHuntMode(), seed: 21);
    final helped = GameEngine(mode: InfiniteHuntMode(), seed: 21);

    for (var i = 0; i < 12; i++) {
      helped
        ..useHint()
        ..useHint();
      final move = plain.hint();
      if (move == null) break;
      plain.applyMove(move.a, move.b);
      helped.applyMove(move.a, move.b);
    }

    expect(helped.board.toSketch(), plain.board.toSketch());
    expect(helped.score, plain.score);
    expect(helped.snapshot().rngState, plain.snapshot().rngState);
  });
}

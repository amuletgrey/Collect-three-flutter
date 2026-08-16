import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';

/// No lines anywhere, so nothing happens except what the test asks for.
const _quiet = '01201\n12012\n20120\n01201\n12012';

const _bombAt = Pos(2, 2);
const _victim = Pos(2, 3);

const _resolver = Resolver(
  gravity: GravityRule.down,
  refill: RefillRule.none,
  kindCount: 3,
  allowsSpecials: true,
);

/// Sets a bomb next to a tile in the given role and sets it off.
ResolutionOutcome _detonate(Tile Function(Tile) role) {
  final tiles = TileFactory(100);
  var board = Board.parse(_quiet, tiles: tiles);
  board = board
      .withTile(_bombAt, board.at(_bombAt)!.withPower(TilePower.bomb))
      .withTile(_victim, role(board.at(_victim)!));

  return _resolver.resolve(
    board: board,
    rng: SeededRandom(1),
    tiles: tiles,
    primed: {_bombAt},
  );
}

int _countWhere(Board board, bool Function(Tile) test) {
  var count = 0;
  for (final pos in board.positions) {
    final tile = board.at(pos);
    if (tile != null && test(tile)) count++;
  }
  return count;
}

void main() {
  test('a blast takes rot with it', () {
    final outcome = _detonate((tile) => tile.asRot());

    expect(_countWhere(outcome.board, (tile) => tile.isRot), 0);
    expect(outcome.rotCleared, 1);
  });

  test('rot taken by a blast is not also counted as a blasted tile', () {
    // Creeping Rot pays its own bonus for rot, so counting it here as well
    // would pay twice for one tile.
    final withRot = _detonate((tile) => tile.asRot());
    final withPlain = _detonate((tile) => tile);

    expect(withRot.blastCleared, withPlain.blastCleared - 1);
  });

  test('cargo still shrugs a blast off', () {
    // The only way to be rid of a relic is to walk it to the bottom row; a
    // bomb that vaporised the thing you were escorting would be a bad joke,
    // and Relic Dig would be unplayable.
    final outcome = _detonate((tile) => tile.asRelic());

    expect(_countWhere(outcome.board, (tile) => tile.isRelic), 1);
    expect(outcome.rotCleared, 0);
  });

  test('neither role is ever counted as a colour that was collected', () {
    for (final role in [(Tile t) => t.asRot(), (Tile t) => t.asRelic()]) {
      final outcome = _detonate(role);
      final counted = outcome.clearedByKind.values.fold(0, (a, b) => a + b);

      expect(
        counted,
        lessThan(outcome.tilesCleared + 1),
        reason: 'an inert tile has no colour, so it cannot be collected',
      );
    }
  });
}

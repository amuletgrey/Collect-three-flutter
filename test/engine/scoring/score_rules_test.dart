import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/engine/engine.dart';

void main() {
  group('lineScore', () {
    test('follows 10 * n * (n - 2)', () {
      expect(ScoreRules.lineScore(3), 30);
      expect(ScoreRules.lineScore(4), 80);
      expect(ScoreRules.lineScore(5), 150);
      expect(ScoreRules.lineScore(6), 240);
    });

    test('is zero below the minimum match length', () {
      expect(ScoreRules.lineScore(2), 0);
      expect(ScoreRules.lineScore(0), 0);
    });

    test('rewards one long line over two short ones', () {
      expect(ScoreRules.lineScore(6), greaterThan(ScoreRules.lineScore(3) * 2));
    });
  });

  group('cascadeMultiplier', () {
    test('starts at x1 and grows with the chain', () {
      expect(ScoreRules.cascadeMultiplier(1), 1);
      expect(ScoreRules.cascadeMultiplier(3), 3);
    });

    test('is capped', () {
      expect(ScoreRules.cascadeMultiplier(20), ScoreRules.maxCascadeMultiplier);
    });
  });

  test('stepScore multiplies the summed lines', () {
    final lines = [
      MatchLine(
        kind: 0,
        orientation: MatchOrientation.horizontal,
        cells: const [Pos(0, 0), Pos(0, 1), Pos(0, 2)],
      ),
      MatchLine(
        kind: 1,
        orientation: MatchOrientation.vertical,
        cells: const [Pos(0, 3), Pos(1, 3), Pos(2, 3), Pos(3, 3)],
      ),
    ];

    expect(ScoreRules.stepScore(lines, 1), 110);
    expect(ScoreRules.stepScore(lines, 2), 220);
  });
}

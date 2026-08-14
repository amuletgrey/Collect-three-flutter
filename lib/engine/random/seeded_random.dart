import 'dart:math' as math;

/// Every random decision in the engine goes through this.
///
/// A run is reproducible from `(seed, mode, move list)`, which makes bug reports
/// actionable and lets tests pin exact boards. The engine never constructs a
/// bare `Random()` and never reads the clock.
class SeededRandom {
  SeededRandom(this.seed) : _random = math.Random(seed);

  final int seed;
  final math.Random _random;

  /// Number of values drawn so far — part of the snapshot taken for undo.
  int get drawCount => _drawCount;
  int _drawCount = 0;

  int nextInt(int max) {
    _drawCount++;
    return _random.nextInt(max);
  }

  double nextDouble() {
    _drawCount++;
    return _random.nextDouble();
  }

  bool nextBool() => nextInt(2) == 0;

  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('cannot pick from an empty list');
    return items[nextInt(items.length)];
  }

  /// Fisher-Yates, in place.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// A fresh generator derived from this one — used when a subsystem needs its
  /// own stream without perturbing the main one.
  SeededRandom fork() => SeededRandom(nextInt(1 << 31));

  @override
  String toString() => 'SeededRandom(seed: $seed, draws: $_drawCount)';
}

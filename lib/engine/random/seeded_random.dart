/// Every random decision in the engine goes through this.
///
/// A run is reproducible from `(seed, mode, move list)`, which makes bug reports
/// actionable and lets tests pin exact boards. The engine never constructs a
/// bare `Random()` and never reads the clock.
///
/// This is a 32-bit xorshift rather than `dart:math`'s generator for two
/// reasons: its whole state is one integer, so a half-finished run can be saved
/// and picked up exactly where it left off, and 32-bit arithmetic behaves the
/// same on the VM and on the web, where `int` is a JavaScript number.
class SeededRandom {
  SeededRandom(this.seed, {int? state, int drawCount = 0})
    : _state = state ?? _scramble(seed) {
    _drawCount = drawCount;
  }

  final int seed;
  int _state;
  int _drawCount = 0;

  /// The whole generator state. Store this with [seed] and hand both back to
  /// the constructor to carry on mid-sequence.
  int get state => _state;

  /// Number of values drawn so far — a cheap sanity check on a restore.
  int get drawCount => _drawCount;

  /// Never let the state reach zero: xorshift is stuck there forever.
  static int _scramble(int seed) {
    final mixed = (seed ^ 0x9E3779B9) & 0xFFFFFFFF;
    return mixed == 0 ? 0x1A2B3C4D : mixed;
  }

  int _next() {
    var x = _state & 0xFFFFFFFF;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    _drawCount++;
    return _state;
  }

  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return _next() % max;
  }

  double nextDouble() => _next() / 0x100000000;

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
  SeededRandom fork() => SeededRandom(nextInt(1 << 30));

  @override
  String toString() => 'SeededRandom(seed: $seed, draws: $_drawCount)';
}

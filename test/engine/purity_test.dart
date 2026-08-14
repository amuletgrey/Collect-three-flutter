import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rule that keeps the game testable: `lib/engine/` is pure Dart.
///
/// If this fails, the fix is to move the offending code up a layer — never to
/// weaken the test. See AGENTS.md.
void main() {
  final engineDir = Directory('lib/engine');

  List<File> dartFiles() => engineDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the engine directory exists and has content', () {
    expect(engineDir.existsSync(), isTrue);
    expect(dartFiles(), isNotEmpty);
  });

  test('no Flutter, no dart:ui, no plugins', () {
    for (final file in dartFiles()) {
      final source = file.readAsStringSync();
      expect(
        source.contains('package:flutter'),
        isFalse,
        reason: '${file.path} imports Flutter',
      );
      expect(
        source.contains('dart:ui'),
        isFalse,
        reason: '${file.path} imports dart:ui',
      );
    }
  });

  test('no wall-clock reads — a run must be reproducible from its seed', () {
    for (final file in dartFiles()) {
      final source = file.readAsStringSync();
      expect(
        source.contains('DateTime.now'),
        isFalse,
        reason: '${file.path} reads the clock',
      );
      expect(
        source.contains('Stopwatch'),
        isFalse,
        reason: '${file.path} measures time',
      );
    }
  });

  test('randomness only ever comes from SeededRandom', () {
    for (final file in dartFiles()) {
      final normalised = file.path.replaceAll(r'\', '/');
      if (normalised.endsWith('random/seeded_random.dart')) continue;

      // dart:math itself is fine (min, max, sqrt); only its generator is not.
      // Uses of SeededRandom are exactly what this rule is asking for.
      final source = file.readAsStringSync().replaceAll(
        'SeededRandom',
        'Seeded',
      );
      expect(
        source.contains('Random('),
        isFalse,
        reason: '${file.path} constructs its own Random',
      );
    }
  });
}

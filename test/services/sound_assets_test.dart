import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every sound the AudioService can ask for has to be in the bundle, and has to
/// be a real WAV. A mapping test alone would happily point at nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expected = [
    'collect_1',
    'collect_2',
    'collect_3',
    'collect_4',
    'collect_5',
    'collect_6',
    'swap',
    'reject',
    'special_create',
    'special_fire',
    'relic',
    'tide',
    'level_win',
    'game_over',
  ];

  for (final name in expected) {
    test('$name.wav ships and is playable PCM', () async {
      final data = await rootBundle.load('assets/audio/$name.wav');
      final bytes = data.buffer.asUint8List();

      expect(bytes.length, greaterThan(1000), reason: 'suspiciously short');
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

      final header = ByteData.sublistView(Uint8List.fromList(bytes));
      expect(header.getUint16(20, Endian.little), 1, reason: 'uncompressed');
      expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(header.getUint32(24, Endian.little), 22050);
      expect(header.getUint16(34, Endian.little), 16, reason: '16-bit');

      // Silence would pass every check above.
      var peak = 0;
      for (var i = 44; i + 1 < bytes.length; i += 2) {
        final sample = header.getInt16(i, Endian.little).abs();
        if (sample > peak) peak = sample;
      }
      expect(peak, greaterThan(3000), reason: 'the file is near-silent');
    });
  }
}

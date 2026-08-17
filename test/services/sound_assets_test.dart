import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every sound the AudioService can ask for has to be in the bundle, and has to
/// be a real WAV. A mapping test alone would happily point at nothing.
///
/// Every skin ships a full set under its own id, so a skin missing one file is
/// a silent event rather than a build failure — which is exactly the sort of
/// thing nobody notices until it is in someone's hands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const skins = ['classic_arcade', 'treasure_hunt', 'candy_shop'];

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
    'rot',
    'burn',
  ];

  for (final skin in skins) {
    for (final name in expected) {
      test('$skin/$name.wav ships and is playable PCM', () async {
        final data = await rootBundle.load('assets/audio/$skin/$name.wav');
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

  test('the sets are actually different sounds, not one set copied', () async {
    // Cheap but decisive: the same event on two skins must not be byte for
    // byte the same file.
    final sets = <String, List<int>>{};
    for (final skin in skins) {
      final data = await rootBundle.load('assets/audio/$skin/collect_1.wav');
      sets[skin] = data.buffer.asUint8List().toList();
    }

    expect(sets['classic_arcade'], isNot(equals(sets['treasure_hunt'])));
    expect(sets['treasure_hunt'], isNot(equals(sets['candy_shop'])));
    expect(sets['candy_shop'], isNot(equals(sets['classic_arcade'])));
  });

  test('no skin is much louder than another', () async {
    // Switching skin should change what the game sounds like, not how loud it
    // is — every file is normalised to the same peak on the way out.
    for (final skin in skins) {
      final data = await rootBundle.load('assets/audio/$skin/level_win.wav');
      final bytes = data.buffer.asUint8List();
      final header = ByteData.sublistView(Uint8List.fromList(bytes));
      var peak = 0;
      for (var i = 44; i + 1 < bytes.length; i += 2) {
        final sample = header.getInt16(i, Endian.little).abs();
        if (sample > peak) peak = sample;
      }
      expect(
        peak,
        inInclusiveRange(25000, 28000),
        reason: '$skin is off level',
      );
    }
  });
}

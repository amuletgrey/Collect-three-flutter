import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart' hide MatchFinder;
import 'package:tessera/engine/engine.dart';
import 'package:tessera/services/audio_service.dart';

/// Records what it was asked to play instead of touching an audio device.
class _FakePlayer implements SoundPlayer {
  final List<({String asset, double volume})> played = [];

  @override
  Future<void> play(String asset, {double volume = 1}) async {
    played.add((asset: asset, volume: volume));
  }

  @override
  Future<void> dispose() async {}

  List<String> get assets => [for (final p in played) p.asset];
}

TilesCleared _cleared({int step = 1, ClearCause cause = ClearCause.matched}) =>
    TilesCleared(
      cells: const [Pos(0, 0)],
      lines: const [],
      scoreDelta: 30,
      cascadeStep: step,
      multiplier: 1,
      cause: cause,
    );

void main() {
  test('the chime climbs with the chain', () {
    final player = _FakePlayer();
    final service = AudioService(player: player);
    expect(service.enabled, isTrue, reason: 'sound is on unless muted');

    for (var step = 1; step <= 4; step++) {
      service.forEvent(_cleared(step: step));
    }

    expect(player.assets, [
      'audio/collect_1.wav',
      'audio/collect_2.wav',
      'audio/collect_3.wav',
      'audio/collect_4.wav',
    ]);
  });

  test('a chain longer than the scale stays on the top note', () {
    final player = _FakePlayer();
    AudioService(player: player).forEvent(_cleared(step: 12));

    expect(player.assets.single, 'audio/collect_6.wav');
  });

  test('a delivered relic sounds different from a match', () {
    final player = _FakePlayer();
    AudioService(player: player)
      ..forEvent(_cleared())
      ..forEvent(_cleared(cause: ClearCause.delivered));

    expect(player.assets, ['audio/collect_1.wav', 'audio/relic.wav']);
  });

  test('winning and losing are told apart', () {
    for (final entry in {
      GameEndReason.boardCleared: 'audio/level_win.wav',
      GameEndReason.relicsDelivered: 'audio/level_win.wav',
      GameEndReason.noMovesLeft: 'audio/game_over.wav',
      GameEndReason.overflow: 'audio/game_over.wav',
      GameEndReason.outOfMoves: 'audio/game_over.wav',
    }.entries) {
      final player = _FakePlayer();
      AudioService(player: player).forEvent(GameEnded(entry.key));
      expect(player.assets.single, entry.value, reason: entry.key.name);
    }
  });

  test('every other event that should make a noise does', () {
    final player = _FakePlayer();
    AudioService(player: player)
      ..forEvent(const SwapPerformed(Pos(0, 0), Pos(0, 1)))
      ..forEvent(const SwapReverted(Pos(0, 0), Pos(0, 1)))
      ..forEvent(const SpecialsCreated([]))
      ..forEvent(const SpecialsFired([]))
      ..forEvent(const RowInserted(pushed: [], spawned: []));

    expect(player.assets, [
      'audio/swap.wav',
      'audio/reject.wav',
      'audio/special_create.wav',
      'audio/special_fire.wav',
      'audio/tide.wav',
    ]);
  });

  test('falling and refilling are silent', () {
    final player = _FakePlayer();
    AudioService(player: player)
      ..forEvent(const TilesMoved([]))
      ..forEvent(const TilesSpawned([]));

    expect(player.played, isEmpty);
  });

  test('muted means muted', () {
    final player = _FakePlayer();
    AudioService(player: player, enabled: false)
      ..forEvent(_cleared())
      ..forEvent(const GameEnded(GameEndReason.noMovesLeft));

    expect(player.played, isEmpty);
  });

  test('volumes stay in range and matches sit below the big moments', () {
    final player = _FakePlayer();
    AudioService(player: player)
      ..forEvent(_cleared())
      ..forEvent(const SpecialsFired([]))
      ..forEvent(const SwapPerformed(Pos(0, 0), Pos(0, 1)));

    for (final sound in player.played) {
      expect(sound.volume, inInclusiveRange(0, 1));
    }
    final byAsset = {for (final s in player.played) s.asset: s.volume};
    expect(
      byAsset['audio/swap.wav'],
      lessThan(byAsset['audio/collect_1.wav']!),
    );
    expect(
      byAsset['audio/collect_1.wav'],
      lessThan(byAsset['audio/special_fire.wav']!),
    );
  });

  // Regression test for the focus thrash described on PooledSoundPlayer.
  // Building the context touches no plugin, so this runs without a device.
  group('the pool asks for no audio focus', () {
    final android = PooledSoundPlayer.gameAudio.android;

    test('so a chime never pauses the music the player had on', () {
      expect(android.audioFocus, AndroidAudioFocus.none);
    });

    test('and the voices cannot steal focus from each other', () {
      // With any `gain` variant, voice N takes focus from voice N-1 and the
      // platform stops it mid-chime — the pool stops overlapping at all.
      expect(android.audioFocus, isNot(AndroidAudioFocus.gain));
      expect(android.audioFocus, isNot(AndroidAudioFocus.gainTransient));
      expect(android.audioFocus, isNot(AndroidAudioFocus.gainTransientMayDuck));
    });

    test('and declares itself as game sound, not as music', () {
      expect(android.contentType, AndroidContentType.sonification);
      expect(android.usageType, AndroidUsageType.game);
    });

    test('iOS mixes with other audio via the ambient category', () {
      // `ambient` implies mixWithOthers; passing that option alongside it
      // trips an assertion inside the plugin, so it must stay unset.
      expect(
        PooledSoundPlayer.gameAudio.iOS.category,
        AVAudioSessionCategory.ambient,
      );
      expect(PooledSoundPlayer.gameAudio.iOS.options, isEmpty);
    });
  });
}

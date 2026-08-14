import 'package:audioplayers/audioplayers.dart';

import '../engine/engine.dart';

/// Plays one short sound. Abstracted so the mapping from game events to sounds
/// can be tested without a working audio device.
abstract class SoundPlayer {
  Future<void> play(String asset, {double volume});
  Future<void> dispose();
}

/// The real thing, on `audioplayers`.
///
/// Sounds overlap constantly in a cascade, so this keeps a small pool of
/// players and cycles through them: a single player would cut off the previous
/// chime every time the next one landed, which is precisely backwards for a
/// chain reaction.
class PooledSoundPlayer implements SoundPlayer {
  PooledSoundPlayer({int voices = 6})
    : _players = List.generate(
        voices,
        (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      );

  final List<AudioPlayer> _players;
  int _next = 0;

  @override
  Future<void> play(String asset, {double volume = 1}) async {
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } on Object {
      // A missing codec or a busy device must never take the game down with
      // it; sound is the least important thing on screen.
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
  }
}

/// Turns board events into sound.
///
/// The cascade chime climbs a pentatonic scale with the chain, which is the
/// whole reward for setting one up — the sound tells you how well it went
/// before the score has finished counting.
class AudioService {
  const AudioService({required this.player, this.enabled = true});

  final SoundPlayer player;
  final bool enabled;

  static const String _dir = 'audio';
  static const int _chimeSteps = 6;

  void forEvent(BoardEvent event) {
    if (!enabled) return;
    switch (event) {
      case TilesCleared(:final cascadeStep, :final cause):
        if (cause == ClearCause.delivered) {
          _play('relic', volume: 0.9);
        } else {
          final step = cascadeStep.clamp(1, _chimeSteps);
          _play('collect_$step', volume: 0.55);
        }
      case SwapPerformed():
        _play('swap', volume: 0.35);
      case SwapReverted():
        _play('reject', volume: 0.5);
      case SpecialsCreated():
        _play('special_create', volume: 0.7);
      case SpecialsFired():
        _play('special_fire', volume: 0.8);
      case RowInserted():
        _play('tide', volume: 0.6);
      case GameEnded(:final reason):
        final won =
            reason == GameEndReason.boardCleared ||
            reason == GameEndReason.relicsDelivered;
        _play(won ? 'level_win' : 'game_over', volume: 0.85);
      case TilesMoved():
      case TilesSpawned():
        break;
    }
  }

  void _play(String name, {required double volume}) {
    // Deliberately not awaited: the board must not wait on the speaker.
    player.play('$_dir/$name.wav', volume: volume);
  }
}

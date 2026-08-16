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
      ) {
    _ready = _configure();
  }

  /// How these sounds present themselves to the platform's audio system.
  ///
  /// `audioplayers` defaults every player to `usageType: media`,
  /// `contentType: music`, `audioFocus: gain` — the profile of a music app.
  /// Two things follow, both observed in logcat on a real device:
  ///
  /// 1. Every chime takes audio focus, so it pauses whatever the player had
  ///    running in Spotify — once per match, which is unusable.
  /// 2. Each voice in this pool requests focus of its own, so voice N takes it
  ///    from voice N-1, which is then told to stop. That is precisely the
  ///    cut-off the pool exists to prevent.
  ///
  /// Game sonification that requests no focus fixes both. On iOS, `ambient`
  /// already implies `mixWithOthers` — passing that option explicitly with this
  /// category trips an assertion in the plugin — and is silenced by the ring
  /// switch, which is what a player expects of game audio.
  static final AudioContext gameAudio = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  final List<AudioPlayer> _players;
  late final Future<void> _ready;
  int _next = 0;

  /// Applied per player rather than through `AudioPlayer.global`, because the
  /// pool is built before this runs and the global context only seeds players
  /// created after it is set.
  Future<void> _configure() async {
    for (final player in _players) {
      try {
        await player.setAudioContext(gameAudio);
      } on Object {
        // Desktop and web have no audio session to configure, and a platform
        // that refuses one must not cost us the sound.
      }
    }
  }

  @override
  Future<void> play(String asset, {double volume = 1}) async {
    // The very first chime would otherwise race the session setup and still go
    // out holding focus.
    await _ready;
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
        } else if (cause == ClearCause.burned) {
          _play('burn', volume: 0.75);
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
      case TilesTransformed():
        _play('rot', volume: 0.7);
      case GameEnded(:final reason):
        final won =
            reason == GameEndReason.boardCleared ||
            reason == GameEndReason.relicsDelivered ||
            reason == GameEndReason.orderFilled;
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

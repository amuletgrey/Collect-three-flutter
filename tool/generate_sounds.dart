// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Writes the game's sound effects — one full set per skin.
///
///     dart run tool/generate_sounds.dart
///
/// The set is synthesised rather than recorded: every sound here is a short
/// tone, a chord or a filtered noise burst, which is exactly what a match-3
/// needs and what a synthesiser is good at. It keeps the whole thing at a few
/// hundred kilobytes, license-free, and tunable by editing numbers instead of
/// re-recording.
///
/// Each skin gets its own voice, because a skin is not just a palette — a
/// cabinet full of glossy balls, a torchlit cave and a sweet shop do not sound
/// alike, and the chime is as much a part of the skin as the artwork:
///
/// * **Classic Arcade** — chiptune. Square waves, hard edges, bit-crushed, with
///   the coin blip and the descending fail glissando every cabinet had.
/// * **Treasure Hunt** — struck metal and stone in a big room. Inharmonic bell
///   partials, long decays, everything echoing off the walls.
/// * **Candy Shop** — soft mallets and bubbles. Sines and triangles, gentle
///   vibrato, pitch bends that bounce. Nothing with a hard edge anywhere.
///
/// Output: mono 16-bit PCM WAV at 22.05 kHz into assets/audio/`skin_id`/.
void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args.first : 'assets/audio');

  var written = 0;
  var bytes = 0;
  for (final voice in [_arcade, _treasure, _candy]) {
    final dir = Directory('${root.path}/${voice.id}')
      ..createSync(recursive: true);
    print('\n${voice.id}  — ${voice.blurb}');
    voice.build().forEach((name, samples) {
      final file = _write(dir, name, samples);
      written++;
      bytes += file;
    });
  }
  print('\nWrote $written sounds, ${(bytes / 1024).round()} kB total.');
}

const int _rate = 22050;

/// The names every voice has to provide. The audio service asks for these by
/// name whichever skin is on, so a voice that misses one is a silent event.
const List<String> requiredSounds = [
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

/// A pentatonic run, so any two chimes that overlap still sound consonant.
const List<double> _pentatonic = [
  523.25,
  587.33,
  698.46,
  783.99,
  880.0,
  1046.50,
];

class _Voice {
  const _Voice({required this.id, required this.blurb, required this.build});

  final String id;
  final String blurb;
  final Map<String, List<double>> Function() build;
}

// ---------------------------------------------------------------- waveforms

double _sine(double phase) => math.sin(phase);

/// Hard-edged and buzzy: the sound of a cabinet.
double _square(double phase) => math.sin(phase) >= 0 ? 1 : -1;

/// Softer than a square, warmer than a sine — a sweet-shop mallet.
double _triangle(double phase) =>
    2 / math.pi * math.asin(math.sin(phase).clamp(-1.0, 1.0));

/// Runs an oscillator at a fixed or gliding pitch.
List<double> _tone({
  required double from,
  double? to,
  required double seconds,
  double Function(double phase) wave = _sine,
  double attack = 0.01,
  double curve = 2.4,
  double gain = 0.6,
  double vibratoHz = 0,
  double vibratoDepth = 0,
}) {
  final samples = (seconds * _rate).round();
  final out = List<double>.filled(samples, 0);
  var phase = 0.0;
  for (var i = 0; i < samples; i++) {
    final progress = i / samples;
    var freq = to == null ? from : from + (to - from) * progress;
    if (vibratoHz > 0) {
      freq *= 1 + vibratoDepth * math.sin(2 * math.pi * vibratoHz * i / _rate);
    }
    phase += 2 * math.pi * freq / _rate;
    out[i] = wave(phase) * _attackDecay(progress, attack, curve) * gain;
  }
  return out;
}

double _attackDecay(double progress, double attack, double curve) {
  if (progress < attack) return progress / attack;
  final tail = (progress - attack) / (1 - attack);
  return math.pow(1 - tail, curve).toDouble();
}

/// Filtered noise. [colour] from 0 (dark) to 1 (bright).
List<double> _noise({
  required double seconds,
  double colour = 0.3,
  double curve = 1.8,
  double gain = 0.6,
  int seed = 11,
}) {
  final samples = (seconds * _rate).round();
  final random = math.Random(seed);
  var previous = 0.0;
  return [
    for (var i = 0; i < samples; i++)
      () {
        final white = random.nextDouble() * 2 - 1;
        previous = previous * (1 - colour) + white * colour;
        return previous * _attackDecay(i / samples, 0.005, curve) * gain;
      }(),
  ];
}

/// A struck bell: partials at inharmonic ratios, which is what stops it
/// sounding like an organ. The ratios are the classic ones for a cast bell.
List<double> _bell({
  required double freq,
  required double seconds,
  double gain = 0.5,
}) {
  const partials = [
    (1.0, 1.0),
    (2.0, 0.6),
    (2.76, 0.45),
    (5.4, 0.25),
    (8.93, 0.12),
  ];
  final samples = (seconds * _rate).round();
  final out = List<double>.filled(samples, 0);
  for (final (ratio, weight) in partials) {
    for (var i = 0; i < samples; i++) {
      final progress = i / samples;
      // Higher partials die away first, the way a real bell does.
      final decay = math.pow(1 - progress, 1.6 + ratio * 0.5).toDouble();
      out[i] +=
          math.sin(2 * math.pi * freq * ratio * i / _rate) *
          weight *
          decay *
          gain;
    }
  }
  return out;
}

// --------------------------------------------------------------- processing

/// Quantises amplitude to a handful of steps. The grit that says "8-bit".
List<double> _crush(List<double> samples, {int levels = 12}) => [
  for (final sample in samples) (sample * levels).roundToDouble() / levels,
];

/// A big room. Cheap feedback delay rather than a real reverb, which is all a
/// short sound needs to sound like it happened underground.
List<double> _echo(
  List<double> samples, {
  double delay = 0.11,
  double feedback = 0.45,
  int repeats = 3,
}) {
  final step = (delay * _rate).round();
  final out = List<double>.filled(samples.length + step * repeats, 0);
  for (var i = 0; i < samples.length; i++) {
    out[i] += samples[i];
  }
  var gain = feedback;
  for (var r = 1; r <= repeats; r++) {
    final offset = step * r;
    for (var i = 0; i < samples.length; i++) {
      out[offset + i] += samples[i] * gain;
    }
    gain *= feedback;
  }
  return out;
}

/// Lays sounds out in time, overlapping where they want to.
List<double> _sequence(List<(double at, List<double> sound)> parts) {
  var length = 0;
  for (final (at, sound) in parts) {
    final end = (at * _rate).round() + sound.length;
    if (end > length) length = end;
  }
  final out = List<double>.filled(length, 0);
  for (final (at, sound) in parts) {
    final offset = (at * _rate).round();
    for (var i = 0; i < sound.length; i++) {
      out[offset + i] += sound[i];
    }
  }
  return out;
}

List<double> _mix(List<List<double>> layers) =>
    _sequence([for (final layer in layers) (0.0, layer)]);

// ------------------------------------------------------------------ arcade

final _Voice _arcade = _Voice(
  id: 'classic_arcade',
  blurb: 'chiptune: squares, bit-crush, coin blips',
  build: () {
    final out = <String, List<double>>{};

    for (var step = 0; step < _pentatonic.length; step++) {
      final freq = _pentatonic[step];
      // A blip that starts a fifth high and snaps down: the classic pickup.
      out['collect_${step + 1}'] = _crush(
        _sequence([
          (0.0, _tone(from: freq * 1.5, seconds: 0.03, wave: _square, gain: 0.4)),
          (
            0.03,
            _tone(from: freq, seconds: 0.13, wave: _square, gain: 0.45, curve: 3),
          ),
        ]),
      );
    }

    out['swap'] = _crush(
      _tone(from: 880, seconds: 0.04, wave: _square, gain: 0.3, curve: 4),
    );
    out['reject'] = _crush(
      _tone(from: 300, to: 110, seconds: 0.16, wave: _square, gain: 0.45),
    );
    // Power-up: a fast run up the scale.
    out['special_create'] = _crush(
      _sequence([
        for (var i = 0; i < 4; i++)
          (
            i * 0.045,
            _tone(
              from: 523.25 * math.pow(1.26, i).toDouble(),
              seconds: 0.09,
              wave: _square,
              gain: 0.35,
              curve: 3,
            ),
          ),
      ]),
    );
    out['special_fire'] = _crush(
      _mix([
        _noise(seconds: 0.3, colour: 0.55, gain: 0.5),
        _tone(from: 400, to: 60, seconds: 0.3, wave: _square, gain: 0.35),
      ]),
    );
    // Two notes, the shape every cabinet used for a coin.
    out['relic'] = _crush(
      _sequence([
        (0.0, _tone(from: 987.77, seconds: 0.07, wave: _square, gain: 0.4)),
        (
          0.07,
          _tone(from: 1318.51, seconds: 0.34, wave: _square, gain: 0.4, curve: 3),
        ),
      ]),
    );
    out['tide'] = _crush(
      _tone(from: 130, to: 330, seconds: 0.45, wave: _square, gain: 0.4),
    );
    out['level_win'] = _crush(
      _sequence([
        for (final (i, freq) in [
          523.25,
          659.25,
          783.99,
          1046.50,
          1318.51,
        ].indexed)
          (
            i * 0.08,
            _tone(
              from: freq,
              seconds: i == 4 ? 0.4 : 0.12,
              wave: _square,
              gain: 0.35,
              curve: 2.5,
            ),
          ),
      ]),
    );
    out['game_over'] = _crush(
      _tone(
        from: 440,
        to: 90,
        seconds: 0.75,
        wave: _square,
        gain: 0.4,
        vibratoHz: 9,
        vibratoDepth: 0.03,
      ),
    );
    out['rot'] = _crush(
      _mix([
        _tone(from: 220, to: 92, seconds: 0.3, wave: _square, gain: 0.35),
        // A semitone off, so it grates rather than resolves.
        _tone(from: 233, to: 98, seconds: 0.3, wave: _square, gain: 0.2),
      ]),
    );
    out['burn'] = _crush(_noise(seconds: 0.22, colour: 0.7, gain: 0.45));
    return out;
  },
);

// ---------------------------------------------------------------- treasure

final _Voice _treasure = _Voice(
  id: 'treasure_hunt',
  blurb: 'struck metal and stone, echoing off the walls',
  build: () {
    final out = <String, List<double>>{};

    for (var step = 0; step < _pentatonic.length; step++) {
      // An octave down from the arcade run: a cave is a big place.
      out['collect_${step + 1}'] = _echo(
        _bell(freq: _pentatonic[step] * 0.5, seconds: 0.5),
        delay: 0.09,
        feedback: 0.3,
        repeats: 2,
      );
    }

    out['swap'] = _noise(seconds: 0.05, colour: 0.25, gain: 0.35, curve: 3);
    out['reject'] = _mix([
      _tone(from: 120, to: 82, seconds: 0.2, gain: 0.5, curve: 2),
      _noise(seconds: 0.12, colour: 0.15, gain: 0.25),
    ]);
    // Three bells a beat apart, slightly detuned: a seam catching the light.
    out['special_create'] = _echo(
      _sequence([
        (0.0, _bell(freq: 659.25, seconds: 0.4, gain: 0.35)),
        (0.06, _bell(freq: 987.77, seconds: 0.4, gain: 0.3)),
        (0.12, _bell(freq: 1322.0, seconds: 0.45, gain: 0.28)),
      ]),
    );
    out['special_fire'] = _echo(
      _mix([
        _noise(seconds: 0.35, colour: 0.2, gain: 0.55),
        _tone(from: 180, to: 45, seconds: 0.4, gain: 0.5),
      ]),
      delay: 0.13,
      feedback: 0.4,
    );
    // The big one: a struck gong, left to ring.
    out['relic'] = _echo(
      _bell(freq: 98, seconds: 1.1, gain: 0.6),
      delay: 0.16,
      feedback: 0.45,
    );
    out['tide'] = _echo(
      _mix([
        _tone(from: 70, to: 150, seconds: 0.55, gain: 0.5),
        _noise(seconds: 0.5, colour: 0.1, gain: 0.3),
      ]),
    );
    out['level_win'] = _echo(
      _sequence([
        for (final (i, freq) in [261.63, 329.63, 392.0, 523.25].indexed)
          (i * 0.12, _bell(freq: freq, seconds: 0.7, gain: 0.35)),
      ]),
      delay: 0.14,
      feedback: 0.4,
    );
    out['game_over'] = _echo(
      _mix([
        _bell(freq: 73, seconds: 1.2, gain: 0.5),
        _tone(from: 160, to: 55, seconds: 0.9, gain: 0.3),
      ]),
      delay: 0.19,
      feedback: 0.5,
    );
    out['rot'] = _echo(
      _mix([
        _noise(seconds: 0.3, colour: 0.12, gain: 0.4),
        _tone(from: 140, to: 70, seconds: 0.35, gain: 0.35),
      ]),
      feedback: 0.3,
      repeats: 2,
    );
    out['burn'] = _echo(
      _noise(seconds: 0.3, colour: 0.45, gain: 0.4),
      delay: 0.08,
      feedback: 0.3,
      repeats: 2,
    );
    return out;
  },
);

// ------------------------------------------------------------------- candy

final _Voice _candy = _Voice(
  id: 'candy_shop',
  blurb: 'soft mallets, bubbles and bounce',
  build: () {
    final out = <String, List<double>>{};

    for (var step = 0; step < _pentatonic.length; step++) {
      final freq = _pentatonic[step];
      // Marimba: a triangle fundamental with a soft octave above, no edge.
      out['collect_${step + 1}'] = _mix([
        _tone(
          from: freq,
          seconds: 0.3,
          wave: _triangle,
          gain: 0.5,
          curve: 3,
          vibratoHz: 5,
          vibratoDepth: 0.006,
        ),
        _tone(from: freq * 2, seconds: 0.16, gain: 0.16, curve: 3.5),
      ]);
    }

    // A bubble: a quick bend upwards, and gone.
    out['swap'] = _tone(
      from: 420,
      to: 760,
      seconds: 0.07,
      gain: 0.35,
      curve: 3,
    );
    out['reject'] = _tone(
      from: 380,
      to: 190,
      seconds: 0.18,
      wave: _triangle,
      gain: 0.4,
      curve: 2,
    );
    out['special_create'] = _sequence([
      for (var i = 0; i < 3; i++)
        (
          i * 0.06,
          _tone(
            from: 880 * math.pow(1.2, i).toDouble(),
            seconds: 0.22,
            gain: 0.3,
            curve: 3,
            vibratoHz: 7,
            vibratoDepth: 0.01,
          ),
        ),
    ]);
    // Fizz rather than a bang.
    out['special_fire'] = _mix([
      _noise(seconds: 0.28, colour: 0.75, gain: 0.35, curve: 2.2),
      _tone(from: 620, to: 300, seconds: 0.25, wave: _triangle, gain: 0.25),
    ]);
    out['relic'] = _tone(
      from: 200,
      to: 320,
      seconds: 0.45,
      wave: _triangle,
      gain: 0.5,
      vibratoHz: 6,
      vibratoDepth: 0.03,
    );
    out['tide'] = _tone(
      from: 180,
      to: 420,
      seconds: 0.5,
      wave: _triangle,
      gain: 0.4,
      vibratoHz: 4,
      vibratoDepth: 0.02,
    );
    out['level_win'] = _sequence([
      for (final (i, freq) in [523.25, 659.25, 783.99, 1046.50].indexed)
        (
          i * 0.1,
          _tone(
            from: freq,
            seconds: i == 3 ? 0.5 : 0.2,
            wave: _triangle,
            gain: 0.35,
            curve: 2.5,
            vibratoHz: 5,
            vibratoDepth: 0.008,
          ),
        ),
    ]);
    out['game_over'] = _tone(
      from: 520,
      to: 130,
      seconds: 0.8,
      wave: _triangle,
      gain: 0.4,
      vibratoHz: 4,
      vibratoDepth: 0.04,
    );
    // Squelch: a wobble that sags.
    out['rot'] = _tone(
      from: 260,
      to: 110,
      seconds: 0.34,
      wave: _triangle,
      gain: 0.4,
      vibratoHz: 11,
      vibratoDepth: 0.06,
    );
    out['burn'] = _noise(seconds: 0.24, colour: 0.85, gain: 0.35, curve: 2.4);
    return out;
  },
);

// ------------------------------------------------------------------ writing

int _write(Directory dir, String name, List<double> samples) {
  final peak = samples.fold<double>(0, (a, b) => math.max(a, b.abs()));
  // Normalise to a common loudness, so switching skin does not change how loud
  // the game is — only what it sounds like.
  final scale = peak == 0 ? 1.0 : 0.82 / peak;
  final file = File('${dir.path}/$name.wav')
    ..writeAsBytesSync(_wav([for (final s in samples) s * scale]));
  final size = file.lengthSync();
  print('  ${name.padRight(16)} ${(size / 1024).round()} kB');
  return size;
}

/// Mono 16-bit PCM. Written by hand because a WAV header is 44 bytes and not
/// worth a dependency.
Uint8List _wav(List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      data.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  final dataBytes = samples.length * 2;
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little) // PCM header size
    ..setUint16(20, 1, Endian.little) // uncompressed
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, _rate, Endian.little)
    ..setUint32(28, _rate * 2, Endian.little) // byte rate
    ..setUint16(32, 2, Endian.little) // block align
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

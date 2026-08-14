// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Writes the game's sound effects.
///
///     dart run tool/generate_sounds.dart
///
/// The set is synthesised rather than recorded: every sound here is a short
/// tone, a chord or a filtered noise burst, which is exactly what a match-3
/// needs and what a synthesiser is good at. It keeps the whole set at a few
/// tens of kilobytes, license-free, and tunable by editing numbers instead of
/// re-recording — the cascade chime in particular is literally a rising scale,
/// so it belongs in code.
///
/// Output: mono 16-bit PCM WAV at 22.05 kHz into assets/audio/.
void main(List<String> args) {
  final outDir = Directory(args.isNotEmpty ? args.first : 'assets/audio')
    ..createSync(recursive: true);

  // A pentatonic run, so any two chimes that overlap still sound consonant.
  const pentatonic = [523.25, 587.33, 698.46, 783.99, 880.0, 1046.50];
  for (var step = 0; step < pentatonic.length; step++) {
    _write(
      outDir,
      'collect_${step + 1}',
      _chime(pentatonic[step], seconds: 0.28),
    );
  }

  _write(outDir, 'swap', _click(freq: 660, seconds: 0.07));
  _write(outDir, 'reject', _thud(freq: 150, seconds: 0.16));
  _write(outDir, 'special_create', _arpeggio(const [659.25, 987.77, 1318.51]));
  _write(outDir, 'special_fire', _burst(seconds: 0.32));
  _write(outDir, 'relic', _thud(freq: 98, seconds: 0.55, harmonics: 4));
  _write(outDir, 'tide', _sweep(from: 110, to: 320, seconds: 0.5));
  _write(
    outDir,
    'level_win',
    _arpeggio(const [523.25, 659.25, 783.99, 1046.50]),
  );
  _write(outDir, 'game_over', _sweep(from: 392, to: 130, seconds: 0.7));

  print('Wrote ${outDir.listSync().length} sounds to ${outDir.path}');
}

const int _rate = 22050;

/// A struck tone: a few harmonics with a fast attack and a long tail. This is
/// the workhorse — it is what a collected tile sounds like.
List<double> _chime(double freq, {required double seconds}) {
  final samples = (seconds * _rate).round();
  return [
    for (var i = 0; i < samples; i++)
      () {
        final t = i / _rate;
        final envelope = _attackDecay(i / samples, attack: 0.01);
        return envelope *
            (0.6 * math.sin(2 * math.pi * freq * t) +
                0.25 * math.sin(4 * math.pi * freq * t) +
                0.1 * math.sin(6 * math.pi * freq * t));
      }(),
  ];
}

/// Several tones one after another, overlapping slightly.
List<double> _arpeggio(List<double> freqs) {
  const gap = 0.075;
  final total = ((freqs.length * gap + 0.3) * _rate).round();
  final out = List<double>.filled(total, 0);
  for (var n = 0; n < freqs.length; n++) {
    final note = _chime(freqs[n], seconds: 0.3);
    final offset = (n * gap * _rate).round();
    for (var i = 0; i < note.length && offset + i < total; i++) {
      out[offset + i] += note[i] * 0.7;
    }
  }
  return out;
}

/// A tick: one cycle or two, gone almost immediately.
List<double> _click({required double freq, required double seconds}) {
  final samples = (seconds * _rate).round();
  return [
    for (var i = 0; i < samples; i++)
      math.sin(2 * math.pi * freq * i / _rate) *
          math.pow(1 - i / samples, 3).toDouble() *
          0.5,
  ];
}

/// Low and blunt: a refused swap, or something heavy landing.
List<double> _thud({
  required double freq,
  required double seconds,
  int harmonics = 2,
}) {
  final samples = (seconds * _rate).round();
  return [
    for (var i = 0; i < samples; i++)
      () {
        final t = i / _rate;
        final decay = math.pow(1 - i / samples, 2.2).toDouble();
        var value = 0.0;
        for (var h = 1; h <= harmonics; h++) {
          value += math.sin(2 * math.pi * freq * h * t) / (h * 1.5);
        }
        return value * decay * 0.55;
      }(),
  ];
}

/// Filtered noise — a power going off.
List<double> _burst({required double seconds}) {
  final samples = (seconds * _rate).round();
  final random = math.Random(11);
  var previous = 0.0;
  return [
    for (var i = 0; i < samples; i++)
      () {
        final white = random.nextDouble() * 2 - 1;
        // A one-pole low pass turns hiss into something with body.
        previous = previous * 0.72 + white * 0.28;
        final decay = math.pow(1 - i / samples, 1.8).toDouble();
        final body = math.sin(2 * math.pi * 180 * i / _rate) * 0.35;
        return (previous * 0.8 + body) * decay * 0.7;
      }(),
  ];
}

/// A glide between two pitches: the tide coming up, or a run running out.
List<double> _sweep({
  required double from,
  required double to,
  required double seconds,
}) {
  final samples = (seconds * _rate).round();
  var phase = 0.0;
  return [
    for (var i = 0; i < samples; i++)
      () {
        final progress = i / samples;
        final freq = from + (to - from) * progress;
        phase += 2 * math.pi * freq / _rate;
        final envelope = _attackDecay(progress, attack: 0.08);
        return (math.sin(phase) * 0.6 + math.sin(phase * 2) * 0.15) * envelope;
      }(),
  ];
}

double _attackDecay(double progress, {required double attack}) {
  if (progress < attack) return progress / attack;
  final tail = (progress - attack) / (1 - attack);
  return math.pow(1 - tail, 2.4).toDouble();
}

void _write(Directory dir, String name, List<double> samples) {
  final file = File('${dir.path}/$name.wav')..writeAsBytesSync(_wav(samples));
  print('${file.path.padRight(34)} ${(file.lengthSync() / 1024).round()} kB');
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

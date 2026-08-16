import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../services/level_repository.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
import '../widgets/level_grid.dart';
import 'game_screen.dart';

/// Level picker for Clear the Board.
///
/// Levels unlock in order: the pack ramps from a 5x5 with three colours to a
/// 7x6 with four, and playing them out of order would skip the teaching.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final LevelRepository _repository = LevelRepository();
  late Future<LevelPack> _pack;

  @override
  void initState() {
    super.initState();
    _pack = _repository.load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final skin = settings.skin;

    return SkinBackground(
      skin: skin,
      simplified: settings.performanceMode,
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: SafeArea(
          child: FutureBuilder<LevelPack>(
            future: _pack,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Message(
                  text: 'Could not load the level pack.',
                  skin: skin,
                );
              }
              final pack = snapshot.data;
              if (pack == null) {
                return Center(
                  child: CircularProgressIndicator(color: skin.palette.accent),
                );
              }
              return _Grid(pack: pack, skin: skin, settings: settings);
            },
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.pack, required this.skin, required this.settings});

  final LevelPack pack;
  final Skin skin;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => LevelGrid(
    title: 'Clear the Board',
    skin: skin,
    entries: [
      for (final level in pack.levels)
        LevelEntry(
          number: level.number,
          stars: settings.starsFor(pack.id, level.number),
          subtitle: '${level.rows}x${level.cols}',
        ),
    ],
    onOpen: (number) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          modeId: ModeRegistry.clearBoardId,
          level: pack.byNumber(number),
          packId: pack.id,
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.skin});

  final String text;
  final Skin skin;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: TextStyle(color: skin.palette.textPrimary)),
  );
}

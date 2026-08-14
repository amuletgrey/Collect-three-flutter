import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../services/level_repository.dart';
import '../../skins/skin.dart';
import '../../skins/skin_background.dart';
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
  Widget build(BuildContext context) {
    // The next unplayed level is the only locked one you can reach.
    var unlockedUpTo = 1;
    for (final level in pack.levels) {
      if (settings.starsFor(pack.id, level.number) > 0) {
        unlockedUpTo = level.number + 1;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: skin.palette.textPrimary,
              ),
              Expanded(
                child: Text(
                  'Clear the Board',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: skin.palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: pack.length,
            itemBuilder: (context, index) {
              final level = pack.levels[index];
              return _LevelTile(
                level: level,
                packId: pack.id,
                skin: skin,
                stars: settings.starsFor(pack.id, level.number),
                locked: level.number > unlockedUpTo,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.packId,
    required this.skin,
    required this.stars,
    required this.locked,
  });

  final Level level;
  final String packId;
  final Skin skin;
  final int stars;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked
          ? skin.palette.boardCell.withValues(alpha: 0.4)
          : skin.palette.boardCell,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: locked
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GameScreen(
                    modeId: ModeRegistry.clearBoardId,
                    level: level,
                    packId: packId,
                  ),
                ),
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              Icon(
                Icons.lock_outline_rounded,
                color: skin.palette.textSecondary,
                size: 20,
              )
            else
              Text(
                '${level.number}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: skin.palette.textPrimary,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 3; i++)
                  Icon(
                    i <= stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 13,
                    color: i <= stars
                        ? skin.palette.accent
                        : skin.palette.textSecondary.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

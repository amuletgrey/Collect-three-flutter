import 'package:flutter/material.dart';

import '../../app_settings.dart';
import '../../engine/engine.dart';
import '../../services/order_repository.dart';
import '../../skins/skin_background.dart';
import '../widgets/level_grid.dart';
import 'game_screen.dart';

/// Level picker for Work Order.
///
/// The pack ramps three things in turn — how much is asked for, how many lines
/// at once, and how many colours are on the board — so it unlocks in order, the
/// same as Clear the Board.
class OrderSelectScreen extends StatefulWidget {
  const OrderSelectScreen({super.key});

  @override
  State<OrderSelectScreen> createState() => _OrderSelectScreenState();
}

class _OrderSelectScreenState extends State<OrderSelectScreen> {
  final OrderRepository _repository = OrderRepository();
  late Future<OrderPack> _pack;

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
          child: FutureBuilder<OrderPack>(
            future: _pack,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load the order pack.',
                    style: TextStyle(color: skin.palette.textPrimary),
                  ),
                );
              }
              final pack = snapshot.data;
              if (pack == null) {
                return Center(
                  child: CircularProgressIndicator(color: skin.palette.accent),
                );
              }
              return LevelGrid(
                title: 'Work Order',
                skin: skin,
                entries: [
                  for (final level in pack.levels)
                    LevelEntry(
                      number: level.number,
                      stars: settings.starsFor(pack.id, level.number),
                      // The shape of the job at a glance: how many lines, and
                      // how many moves to do them in.
                      subtitle:
                          '${level.lines.length} × ${level.moveBudget} moves',
                    ),
                ],
                onOpen: (number) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(
                      modeId: ModeRegistry.workOrderId,
                      level: pack.byNumber(number),
                      packId: pack.id,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

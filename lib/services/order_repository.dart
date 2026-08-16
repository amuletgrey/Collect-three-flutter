import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../engine/engine.dart';

/// Loads the shipped Work Order levels.
///
/// The pack is generated offline by `tool/generate_orders.dart`; every order in
/// it was played to completion by [OrderBot] across a cohort of seeds before
/// being written, so the runtime can trust its budgets and pars blindly.
class OrderRepository {
  OrderRepository({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/orders/pack_01.json';

  final String assetPath;

  OrderPack? _cached;

  Future<OrderPack> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final pack = OrderPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
    return _cached = pack;
  }
}

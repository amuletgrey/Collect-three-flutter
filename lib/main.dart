import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_settings.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.open();
  runApp(CollectThreeApp(settings: AppSettings(storage)));
}

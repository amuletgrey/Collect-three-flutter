import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'ui/screens/home_screen.dart';

class CollectThreeApp extends StatelessWidget {
  const CollectThreeApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      notifier: settings,
      // Screens paint themselves from the active skin, so the Material theme
      // only has to supply sensible defaults for stock widgets.
      child: MaterialApp(
        title: 'Collect Three',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF21E6C1),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0x00000000),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

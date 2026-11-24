/// toadLAUNCHER root — theme scope + home routing (pond vs sketchbook).
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/launcher_settings.dart';
import 'core/theme/toad_theme.dart';
import 'features/home/home_screen.dart';
import 'features/pond/pond_home.dart';

class ToadLauncherApp extends ConsumerWidget {
  const ToadLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(launcherSettingsProvider);

    return MaterialApp(
      title: 'toadLAUNCHER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: _SkinGate(pondPro: settings.pondPro),
    );
  }
}

/// Edge-to-edge, then resolve skin + pick the home variant.
class _SkinGate extends StatelessWidget {
  const _SkinGate({required this.pondPro});

  final bool pondPro;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return ToadThemeScope(
      child: pondPro ? const PondHome() : const HomeScreen(),
    );
  }
}

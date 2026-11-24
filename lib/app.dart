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
      // The skin scope wraps the navigator so pushed pages (settings hub,
      // wallpaper & style) and modal sheets share the same tokens.
      builder: (context, child) =>
          ToadThemeScope(child: child ?? const SizedBox.shrink()),
      home: _SkinGate(pondPro: settings.pondPro),
    );
  }
}

/// Edge-to-edge, then pick the home variant (the skin scope comes from the
/// app builder above).
class _SkinGate extends StatelessWidget {
  const _SkinGate({required this.pondPro});

  final bool pondPro;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return pondPro ? const PondHome() : const HomeScreen();
  }
}

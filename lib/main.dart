import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/reliability/crash_guard.dart';
import 'features/safe_mode/safe_mode_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashGuard.install();
  final safeMode = await CrashGuard.verdict();

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          child: safeMode ? const SafeModeApp() : const ToadLauncherApp(),
        ),
      );
    },
    (error, stackTrace) {
      CrashGuard.record('zone', error, stackTrace);
    },
  );
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/reliability/crash_guard.dart';
import 'features/safe_mode/safe_mode_screen.dart';

/// REL-01 — a Home app must never crash-loop its user into a corner.
/// Startup order:
///   1. install the crash ledger (Flutter + platform + zone errors)
///   2. read the verdict — ≥3 crashing boots inside 5 minutes = safe mode
///   3. run the normal launcher inside a guarded zone; uncaught errors are
///      recorded and the app keeps running (honest degradation, not a
///      silent grey screen)
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

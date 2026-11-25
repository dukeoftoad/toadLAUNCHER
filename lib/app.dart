/// toadLAUNCHER root — theme scope + home routing (pond vs sketchbook).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/device/device_bridge.dart';
import 'core/device/update_engine.dart';
import 'core/repositories/app_repository.dart' show deviceCapabilityProvider;
import 'core/settings/launcher_settings.dart';
import 'core/theme/toad_theme.dart';
import 'core/theme/toad_tokens.dart';
import 'features/home/home_controller.dart';
import 'features/home/home_screen.dart';
import 'features/intro/intro_screen.dart';
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
      builder: (context, child) => ToadThemeScope(
        child: _StartupCheck(
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const UpdateBannerHost(),
            ],
          ),
        ),
      ),
      home: _FirstRunGate(pondPro: settings.pondPro, introSeen: settings.introSeen),
    );
  }
}

/// One silent update check per process (toadFILES v1.7.1 behavior).
class _StartupCheck extends ConsumerStatefulWidget {
  const _StartupCheck({required this.child});

  final Widget child;

  @override
  ConsumerState<_StartupCheck> createState() => _StartupCheckState();
}

class _StartupCheckState extends ConsumerState<_StartupCheck> {
  Timer? _refreshDebounce;

  void _onPackagesChanged(String packageId, String action) {
    // The index refreshes live when apps install / update / remove.
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final settings = ref.read(launcherSettingsProvider);
      if (!settings.deviceMode) return;
      ref.invalidate(deviceCapabilityProvider);
      ref.invalidate(homeLayoutProvider);
    });
  }

  void _refreshFromResume() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final settings = ref.read(launcherSettingsProvider);
      if (!settings.deviceMode) return;
      ref.invalidate(deviceCapabilityProvider);
      ref.invalidate(isDefaultHomeProvider);
      ref.invalidate(notificationAccessProvider);
      ref.invalidate(homeLayoutProvider);
    });
  }

  late final AppLifecycleListener _lifecycle;

  void _onNotificationCounts(Map<String, int> counts) {
    ref.read(notificationCountsProvider.notifier).state = counts;
  }

  @override
  void initState() {
    super.initState();
    final bridge = ref.read(deviceBridgeProvider);
    bridge.addPackagesChangedListener(_onPackagesChanged);
    bridge.addNotificationCountsListener(_onNotificationCounts);
    _lifecycle = AppLifecycleListener(onResume: _refreshFromResume);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(updateEngineProvider.notifier).silentStartupCheck();
    });
  }

  @override
  void dispose() {
    final bridge = ref.read(deviceBridgeProvider);
    bridge.removePackagesChangedListener(_onPackagesChanged);
    bridge.removeNotificationCountsListener(_onNotificationCounts);
    _refreshDebounce?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Slim, dismissable banner card floating over home when the engine has
/// something honest to say (update available / downloading / permission).
class UpdateBannerHost extends ConsumerWidget {
  const UpdateBannerHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateEngineProvider);
    final visible = switch (state) {
      UpdateAvailable() ||
      UpdateDownloading() ||
      UpdateReadyToInstall() ||
      UpdateNeedsInstallPermission() ||
      UpdateChecksumFailed() ||
      UpdateUnverified() ||
      UpdateFailed() => true,
      _ => false,
    };
    if (!visible) return const SizedBox.shrink();

    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    final (String label, VoidCallback onTap) = switch (state) {
      UpdateAvailable(:final release) => (
        'toadLAUNCHER ${release.tagName} available — tap to update',
        () => ref.read(updateEngineProvider.notifier).download(),
      ),
      UpdateDownloading(:final fraction) => (
        fraction == null
            ? 'Downloading update…'
            : 'Downloading update ${(fraction * 100).round()}%',
        () {},
      ),
      UpdateReadyToInstall() => (
        'Update ready — installing',
        () {},
      ),
      UpdateNeedsInstallPermission() => (
        'Grant "Install unknown apps", then retry',
        () => ref.read(updateEngineProvider.notifier).retryInstall(),
      ),
      UpdateChecksumFailed() => (
        'Checksum failed — try again from Settings',
        () {},
      ),
      UpdateUnverified(:final release) => (
        '${release.tagName} could not be verified — refused. Tap for the '
            'release page',
        () => ref.read(updateEngineProvider.notifier).openReleasePage(),
      ),
      UpdateFailed(:final message) => (
        message,
        () {},
      ),
      _ => ('', () {}),
    };

    return Positioned(
      left: 14,
      right: 14,
      top: 52,
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(ToadRadii.card),
              border: Border.all(color: palette.hairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 6),
                  blurRadius: 16,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ToadType.hand(13.5, color: ink),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      ref.read(updateEngineProvider.notifier).dismiss(),
                  child: Text(
                    '✕',
                    style: ToadType.hand(
                      14,
                      color: ink.withValues(alpha: ink.a * 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First run → the intro; after that, the home. The intro replays from
/// Settings → About, so "welcome to the pond" is never lost forever.
class _FirstRunGate extends StatelessWidget {
  const _FirstRunGate({required this.pondPro, required this.introSeen});

  final bool pondPro;
  final bool introSeen;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!introSeen) return const IntroScreen();
    return pondPro ? const PondHome() : const HomeScreen();
  }
}

library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/device/device_bridge.dart';
import '../../core/reliability/crash_guard.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../home/widgets/hero_zone.dart' show buildHeroData;

class SafeModeApp extends StatelessWidget {
  const SafeModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _SafeModeRoot());
  }
}

class _SafeModeRoot extends StatelessWidget {
  const _SafeModeRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'toadLAUNCHER — safe mode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: ToadThemeScope(child: const SafeModeScreen()),
    );
  }
}

class SafeModeScreen extends ConsumerStatefulWidget {
  const SafeModeScreen({super.key});

  @override
  ConsumerState<SafeModeScreen> createState() => _SafeModeScreenState();
}

class _SafeModeScreenState extends ConsumerState<SafeModeScreen> {
  bool _layoutReset = false;

  Future<void> _tryAgain() async {
    await CrashGuard.clear();
    runApp(const ToadLauncherApp());
  }

  Future<void> _resetLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('toadlauncher.hosted.widgets.v1');
    } catch (_) {}
    if (mounted) setState(() => _layoutReset = true);
  }

  Future<void> _shareLog() async {
    final path = await CrashGuard.exportLogFile();
    final bridge = ref.read(deviceBridgeProvider);
    final ok = path != null && await bridge.shareDiagnosticsFile(path);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The crash log could not be shared here.'),
        ),
      );
    }
  }

  Future<void> _chooseAnotherHome() async {
    await ref.read(deviceBridgeProvider).openHomeSettings();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final data = buildHeroData(DateTime.now(), pond: false, pondNight: false);
    final apps = ref.watch(appRepositoryProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.time,
                    style: ToadType.caveat(
                      ToadMetrics.heroClockSize,
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    data.dateLine,
                    style: ToadType.hand(
                      ToadMetrics.heroDateSize,
                      color: palette.ink.withValues(alpha: palette.ink.a * 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'the pond needs a moment',
                    style: ToadType.caveat(22, color: palette.accentInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Something kept going wrong, so toadLAUNCHER opened in '
                    'safe mode — calm paper, no pond, no widgets. Your apps '
                    'are all here and everything you set up is saved.',
                    style: ToadType.inter(
                      13,
                      color: palette.ink.withValues(alpha: palette.ink.a * 0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        label: 'try again',
                        primary: true,
                        onTap: _tryAgain,
                      ),
                      _Pill(
                        label: _layoutReset ? 'layout reset ✓' : 'reset layout',
                        onTap: _resetLayout,
                      ),
                      _Pill(label: 'share crash log', onTap: _shareLog),
                      _Pill(
                        label: 'choose another Home',
                        onTap: _chooseAnotherHome,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: apps.loadHomeLayout(columnsPerRow: 4),
                builder: (context, snapshot) {
                  final layout = snapshot.data;
                  if (layout == null) {
                    return Center(
                      child: Text(
                        'gathering your apps…',
                        style: ToadType.hand(
                          14,
                          color: palette.ink.withValues(
                            alpha: palette.ink.a * 0.6,
                          ),
                        ),
                      ),
                    );
                  }
                  final all = layout.allApps;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: all.length,
                    itemBuilder: (context, index) {
                      final app = all[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(ToadRadii.iconTile),
                        onTap: () => apps.launch(app),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: palette.accentWash,
                                borderRadius: BorderRadius.circular(
                                  ToadRadii.iconTile,
                                ),
                                border: Border.all(color: palette.hairline),
                              ),
                              child: Center(
                                child: Text(
                                  app.name.isNotEmpty
                                      ? app.name[0].toUpperCase()
                                      : '?',
                                  style: ToadType.hand(
                                    20,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ToadType.inter(
                                10.5,
                                color: palette.ink.withValues(
                                  alpha: palette.ink.a * 0.85,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: primary ? palette.accentInk : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.hairline),
        ),
        child: Text(
          label,
          style: ToadType.hand(
            14,
            color: primary ? palette.surface : palette.ink,
          ),
        ),
      ),
    );
  }
}

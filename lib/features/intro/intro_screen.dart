/// The first-run intro — "welcome to the pond".
///
/// Four paper pages, shown once (Settings → About replays them):
///   1. what this is — a hand-made home screen, part of the toad family
///   2. the promise — offline-first, no analytics, no INTERNET permission
///   3. make it yours — four skins, accents, Pond Pro, widgets, edit mode
///   4. a real launcher — permissions are asked by the app, updates ride
///      the system, gestures are yours
///
/// The last page hands over to the permissions page — the ask comes
/// immediately after, not buried three settings deep.
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../settings/permissions_page.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({bool openPermissions = false}) {
    ref.read(launcherSettingsProvider.notifier).setIntroSeen();
    if (openPermissions && mounted) {
      // The ask happens right away — nothing silently denied on day one.
      Navigator.of(context)
          .push(MaterialPageRoute<void>(
            builder: (_) => const PermissionsPage(),
          ))
          .whenComplete(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final softInk = ink.withValues(alpha: ink.a * 0.62);

    final isLast = _page == 3;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.statusIconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: palette.statusIconBrightness,
      ),
      child: Scaffold(
        backgroundColor: palette.paper,
        body: SafeArea(
          child: Column(
            children: [
              // Skip pill, top-right.
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: GestureDetector(
                    onTap: () => _finish(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.hairline),
                      ),
                      child: Text(
                        'skip',
                        style: ToadType.hand(13, color: softInk),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _IntroPage(
                      palette: palette,
                      ink: ink,
                      softInk: softInk,
                      glyph: '⌂',
                      title: 'welcome to the pond',
                      lines: [
                        'This is toadLAUNCHER — a hand-made home screen '
                        'with a handwritten clock, honest snapping and a '
                        'resident toad.',
                        'Part of the toad family, with toadGALLERY and '
                        'toadPLAYER. No ads, no analytics, no accounts.',
                      ],
                    ),
                    _IntroPage(
                      palette: palette,
                      ink: ink,
                      softInk: softInk,
                      glyph: '∅',
                      title: 'everything stays here',
                      lines: [
                        'The app index, your settings, your list — all '
                        'local. The APK holds no INTERNET permission at '
                        'all; Android guarantees it, not a policy.',
                        'Update checks ride the system download service, '
                        'so the launcher itself never touches the network.',
                      ],
                    ),
                    _IntroPage(
                      palette: palette,
                      ink: ink,
                      softInk: softInk,
                      glyph: '✎',
                      title: 'make it yours',
                      lines: [
                        'Four skins (Light, Night, AMOLED, Pond Pro), six '
                        'accent inks, squircle or circle icons — everything '
                        'applies live.',
                        'Long-press for edit mode, resize the clock, place '
                        'real widgets, group apps into folders. And keep a '
                        'todo list right on the launcher (the drawer\'s '
                        'toadLIST).',
                      ],
                    ),
                    _IntroPage(
                      palette: palette,
                      ink: ink,
                      softInk: softInk,
                      glyph: '◔',
                      title: 'a real launcher',
                      lines: [
                        'Swipe up for the drawer, down for the shade, '
                        'double-tap to sleep, pinch for edit mode.',
                        'When a feature needs a special access — dots, '
                        'lock, usage — the app ASKS with one calm dialog '
                        'and opens the exact toggle. Nothing is denied '
                        'silently.',
                      ],
                    ),
                  ],
                ),
              ),
              // Dots + next/finish.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: i == _page ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? palette.accent
                              : palette.hairline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Row(
                  children: [
                    if (_page > 0)
                      GestureDetector(
                        onTap: () => _pages.previousPage(
                          duration: ToadMotion.sharedAxisFolderOpen,
                          curve: Curves.easeOutCubic,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.hairline),
                          ),
                          child: Text(
                            'back',
                            style: ToadType.hand(14, color: softInk),
                          ),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        if (isLast) {
                          _finish(openPermissions: true);
                        } else {
                          _pages.nextPage(
                            duration: ToadMotion.sharedAxisFolderOpen,
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isLast ? 'set up access' : 'next',
                          style: ToadType.hand(15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One intro page — big glyph chip, Caveat title, Patrick Hand lines.
class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.palette,
    required this.ink,
    required this.softInk,
    required this.glyph,
    required this.title,
    required this.lines,
  });

  final ToadPalette palette;
  final Color ink;
  final Color softInk;
  final String glyph;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accentWash,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.hairline),
                ),
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontFamily: ToadType.fontHand,
                    color: palette.accentInk,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(title, style: ToadType.caveat(42, color: ink)),
              const SizedBox(height: 14),
              for (final line in lines) ...[
                Text(
                  line,
                  style: ToadType.hand(
                    15,
                    height: 1.5,
                    color: softInk,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

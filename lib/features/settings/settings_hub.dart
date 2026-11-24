/// Launcher settings — screen 10 of the proposal.
///
/// "The same hub-plus-pages pattern as toadGALLERY's beta.1 settings: a
/// calm list, honest subtitles, handwriting titles."
///
///   · grouped cards, one-line honest subtitles — the value you get is
///     written out, not hidden behind a tap
///   · Privacy is a first-class row stating the promise: no analytics, no
///     network permission, offline-first
///   · every switch applies live (no save button, no hidden traps)
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../wallpaper_style/wallpaper_style_screen.dart'
    show ToadSwitch, WallpaperStyleScreen;

/// Entry point — pushes the hub. Called from the empty-space menu, the
/// edit strip and the dock long-press demo paths.
Future<void> openSettingsHub(BuildContext context) {
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsHub()));
}

class SettingsHub extends ConsumerWidget {
  const SettingsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);

    final appearanceSubtitle =
        '${settings.pondPro ? 'Pond Pro scene' : 'Sketchbook'} · '
        '${switch (settings.skinMode) {
          SkinMode.system => 'auto',
          SkinMode.light => 'light',
          SkinMode.dark => 'dark',
          SkinMode.amoled => 'amoled',
        }} · '
        '${switch (settings.iconShape) {
          IconShape.squircle => 'squircle icons',
          IconShape.circle => 'circle icons',
          IconShape.rounded => 'rounded icons',
        }}';

    final gesturesSubtitle = [
      if (settings.doubleTapSleep) 'double-tap sleeps',
      if (settings.swipeDownNotifications) 'swipe down notifies',
      if (!settings.doubleTapSleep && !settings.swipeDownNotifications)
        'all optional gestures off',
    ].join(' · ');

    return _SettingsScaffold(
      title: 'toadLAUNCHER',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: '▤',
              title: 'Appearance',
              subtitle: appearanceSubtitle,
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const WallpaperStyleScreen()),
            ),
            _SetRow(
              icon: '▦',
              title: 'Home screen',
              subtitle:
                  'Hero widget · ${settings.gridColumns} columns · 3 pages',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const HomeScreenSettingsPage()),
            ),
            _SetRow(
              icon: '☰',
              title: 'Dock & drawer',
              subtitle:
                  'A–Z list · search ${settings.drawerSearch ? 'on' : 'off'} · '
                  'recents ${settings.drawerRecents ? 'on' : 'off'}',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const DockDrawerSettingsPage()),
            ),
          ],
        ),
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: '✍',
              title: 'Gestures',
              subtitle: gesturesSubtitle,
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const GesturesSettingsPage()),
            ),
            _SetRow(
              icon: '◔',
              title: 'Notifications',
              subtitle:
                  'Dots ${settings.notificationDots ? 'on' : 'off'} · '
                  'badges ${settings.badges ? 'on' : 'off'}',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const NotificationsSettingsPage()),
            ),
            _SetRow(
              icon: '∅',
              title: 'Privacy',
              subtitle: 'No analytics · no network permission',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const PrivacyPage()),
            ),
          ],
        ),
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: 'ⓘ',
              title: 'About toadLAUNCHER',
              subtitle: 'v0.1.0-alpha.1 · part of the toad family',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const AboutPage()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'toadLAUNCHER · one family with toadGALLERY & toadPLAYER',
          textAlign: TextAlign.center,
          style: ToadType.inter(
            10.5,
            color: ink.withValues(alpha: ink.a * 0.5),
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

// ---------------------------------------------------------------------------
// Sub-pages
// ---------------------------------------------------------------------------

/// Home screen — grid density and the hero extras.
class HomeScreenSettingsPage extends ConsumerWidget {
  const HomeScreenSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);

    return _SettingsScaffold(
      title: 'Home screen',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _ChoiceRow(
              title: 'Grid columns',
              subtitle: '4 is the sketchbook default — 5 for dense homes',
              options: const ['4', '5'],
              selectedIndex: settings.gridColumns - 4,
              accent: palette.accent,
              accentWash: palette.accentWash,
              ink: ink,
              hairline: palette.hairline,
              onSelect: (i) => notifier.setGridColumns(4 + i),
            ),
            _SwitchRow(
              title: 'Memories card',
              subtitle: 'toadGALLERY\'s on-this-day strip on the home screen',
              value: settings.showMemoriesCard,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.setShowMemoriesCard,
            ),
          ],
        ),
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: '✎',
              title: 'Resize the clock',
              subtitle:
                  'Edit mode → tap the clock → pull a corner — it re-renders '
                  'live at every size (${settings.clockSpanW}×${settings.clockSpanH} now)',
              ink: ink,
              palette: palette,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dock & drawer — what the drawer shows.
class DockDrawerSettingsPage extends ConsumerWidget {
  const DockDrawerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);

    return _SettingsScaffold(
      title: 'Dock & drawer',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Search in the drawer',
              subtitle: 'The pill filters apps + contacts as you type',
              value: settings.drawerSearch,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.setDrawerSearch,
            ),
            _SwitchRow(
              title: 'Recents row',
              subtitle: 'Last 4 launched apps, newest first',
              value: settings.drawerRecents,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.setDrawerRecents,
            ),
          ],
        ),
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Swipe down on the dock opens search',
              subtitle:
                  'Opens the drawer with search focused instead of the '
                  'notification shade — off by default',
              value: settings.dockAreaSwipeSearch,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.patchDockAreaSwipeSearch,
            ),
          ],
        ),
      ],
    );
  }
}

/// Gestures — screen 10's sub-page: "every gesture is a switch with a
/// one-line effect description".
class GesturesSettingsPage extends ConsumerWidget {
  const GesturesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);

    return _SettingsScaffold(
      title: 'Gestures',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Swipe up for drawer',
              subtitle: 'Always available on home',
              value: settings.swipeUpDrawer,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.patchSwipeUpDrawer(v),
            ),
            _SwitchRow(
              title: 'Double-tap to sleep',
              subtitle: 'Requires write-settings permission',
              value: settings.doubleTapSleep,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.patchDoubleTapSleep(v),
            ),
            _SwitchRow(
              title: 'Swipe down opens notifications',
              subtitle: 'On home and drawer',
              value: settings.swipeDownNotifications,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.patchSwipeDownNotifications(v),
            ),
            _SwitchRow(
              title: 'Two-finger screenshot',
              subtitle: 'Off by default — can clash with system shortcuts',
              value: settings.twoFingerScreenshot,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.patchTwoFingerScreenshot(v),
            ),
            _SwitchRow(
              title: 'Pinch for edit mode',
              subtitle: 'Same as long-press → Edit home screen',
              value: settings.pinchEditMode,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.patchPinchEditMode(v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'changes apply live',
          textAlign: TextAlign.center,
          style: ToadType.inter(
            10.5,
            color: ink.withValues(alpha: ink.a * 0.5),
          ),
        ),
      ],
    );
  }
}

/// Notifications — dots and badges, honest about demo scope.
class NotificationsSettingsPage extends ConsumerWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);

    return _SettingsScaffold(
      title: 'Notifications',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Notification dots',
              subtitle:
                  'Dots on icons when something waits — live notifications '
                  'arrive with device mode',
              value: settings.notificationDots,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.setNotificationDots,
            ),
            _SwitchRow(
              title: 'Badges',
              subtitle: 'Written counts, like Contacts · 2 missed',
              value: settings.badges,
              accent: palette.accent,
              ink: ink,
              onChanged: notifier.setBadges,
            ),
          ],
        ),
      ],
    );
  }
}

/// Privacy — the product promise, stated as rows.
class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return _SettingsScaffold(
      title: 'Privacy',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _PromiseRow(
              icon: '∅',
              title: 'No INTERNET permission',
              subtitle:
                  'The APK never asks for network access — the system '
                  'guarantees it, not a policy',
              ink: ink,
              palette: palette,
            ),
            _PromiseRow(
              icon: '◔',
              title: 'No analytics',
              subtitle: 'Nothing phones home — there is no home to phone',
              ink: ink,
              palette: palette,
            ),
            _PromiseRow(
              icon: '▤',
              title: 'Offline-first',
              subtitle: 'Every feature works in airplane mode',
              ink: ink,
              palette: palette,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'the promise lives in the AndroidManifest',
          textAlign: TextAlign.center,
          style: ToadType.inter(
            10.5,
            color: ink.withValues(alpha: ink.a * 0.5),
          ),
        ),
      ],
    );
  }
}

/// About — version + family.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return _SettingsScaffold(
      title: 'About toadLAUNCHER',
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('toadLAUNCHER', style: ToadType.caveat(34, color: ink)),
              const SizedBox(height: 6),
              Text(
                'v0.1.0-alpha.1 · stage 3',
                style: ToadType.inter(
                  11,
                  color: ink.withValues(alpha: ink.a * 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'An offline-first Android home screen with honest snapping, '
                'a handwritten clock and a resident toad. One family with '
                'toadGALLERY & toadPLAYER.',
                style: ToadType.hand(
                  14,
                  height: 1.4,
                  color: ink.withValues(alpha: ink.a * 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'no ads · no tracking · no network permission',
          textAlign: TextAlign.center,
          style: ToadType.inter(
            10.5,
            color: ink.withValues(alpha: ink.a * 0.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final dark = ToadTheme.of(context).isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

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
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.accentWash,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: palette.hairline),
                          ),
                          child: Text(
                            '‹',
                            style: ToadType.hand(22, color: palette.accentInk),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: ToadType.caveat(34, color: ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.palette, required this.children});

  final ToadPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: children),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.palette,
    this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color ink;
  final ToadPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accentWash,
                borderRadius: BorderRadius.circular(
                  ToadRadii.settingsIconChip + 1,
                ),
              ),
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontFamily: ToadType.fontHand,
                  color: palette.accentInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ToadType.hand(15, color: ink)),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: ToadType.inter(
                      10.5,
                      height: 1.3,
                      color: ink.withValues(alpha: ink.a * 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '›',
                style: ToadType.hand(
                  18,
                  color: ink.withValues(alpha: ink.a * 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings row whose whole trailing side is a switch (gestures page).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.ink,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final Color ink;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ToadType.hand(15, color: ink)),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ToadSwitch(value: value, accent: accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A static promise row (Privacy page) — no chevron, no switch.
class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.palette,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color ink;
  final ToadPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accentWash,
              borderRadius: BorderRadius.circular(
                ToadRadii.settingsIconChip + 1,
              ),
            ),
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontFamily: ToadType.fontHand,
                color: palette.accentInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ToadType.hand(15, color: ink)),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2-option inline choice (grid columns).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedIndex,
    required this.accent,
    required this.accentWash,
    required this.ink,
    required this.hairline,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final int selectedIndex;
  final Color accent;
  final Color accentWash;
  final Color ink;
  final Color hairline;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ToadType.hand(15, color: ink)),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accentWash,
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: i == selectedIndex ? accent : Colors.transparent,
                      ),
                      child: Text(
                        options[i],
                        style: ToadType.hand(
                          13,
                          color: i == selectedIndex
                              ? Colors.white
                              : ink.withValues(alpha: ink.a * 0.75),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
import '../../core/device/battery_monitor.dart' show batteryMonitorProvider;
import '../../core/device/device_bridge.dart';
import '../../core/device/update_engine.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_ask.dart';
import '../todo/todo_screen.dart' show openTodoList;
import '../todo/todo_store.dart' show todoListProvider;
import '../wallpaper_style/wallpaper_style_screen.dart'
    show ToadSwitch, WallpaperStyleScreen;
import 'battery_page.dart';
import 'permissions_page.dart';

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
              icon: '✓',
              title: 'toadLIST',
              subtitle: _todoSubtitle(ref),
              ink: ink,
              palette: palette,
              onTap: () => openTodoList(context),
            ),
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
              icon: '⚿',
              title: 'Permissions & access',
              subtitle:
                  'The one page where nothing stays silently denied — '
                  'dots, lock, usage, Home role',
              ink: ink,
              palette: palette,
              onTap: () => openPermissionsPage(context),
            ),
            _SetRow(
              icon: '∅',
              title: 'Privacy',
              subtitle: 'No analytics · no network permission',
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const PrivacyPage()),
            ),
            _SetRow(
              icon: '⇄',
              title: 'Device & updates',
              subtitle: _deviceSubtitle(ref),
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const DeviceUpdatesSettingsPage()),
            ),
            _SetRow(
              icon: '◔',
              title: 'Battery & pond guard',
              subtitle: _batterySubtitle(ref),
              ink: ink,
              palette: palette,
              onTap: () => _push(context, const BatteryPage()),
            ),
          ],
        ),
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: 'ⓘ',
              title: 'About toadLAUNCHER',
              subtitle: _aboutSubtitle(ref),
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

  String _deviceSubtitle(WidgetRef ref) {
    final settings = ref.watch(launcherSettingsProvider);
    final reachable = ref.watch(deviceCapabilityProvider).value ?? false;
    final mode = settings.deviceMode && reachable
        ? 'device mode'
        : 'demo mode';
    return '$mode · updates ${settings.updatePolicy.label.toLowerCase()}';
  }

  String _todoSubtitle(WidgetRef ref) {
    final tasks = ref.watch(todoListProvider);
    if (tasks.isEmpty) {
      return 'your launcher-native list — notes under every fly';
    }
    final open = tasks.where((t) => !t.done).length;
    final notes = tasks.fold<int>(0, (n, t) => n + t.comments.length);
    return '$open open · $notes notes · all local';
  }

  String _batterySubtitle(WidgetRef ref) {
    final battery = ref.watch(batteryMonitorProvider);
    if (battery.level < 0) return 'watching the pond\'s energy';
    final rate = battery.drainPerHour();
    final ratePart = rate == null
        ? ''
        : ' · −${rate.toStringAsFixed(1)}%/h';
    return '${battery.level}%${battery.charging ? ' · charging' : ratePart}';
  }

  String _aboutSubtitle(WidgetRef ref) {
    final version = ref.watch(currentVersionProvider).valueOrNull;
    return '${version ?? 'the toad build'} · part of the toad family';
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
              title: 'Hero clock style',
              subtitle:
                  'The pond wears four faces — hand-lettered, a drawn '
                  'dial, wordy, or flip cards',
              options: [
                for (final s in HeroClockStyle.values) s.label,
              ],
              selectedIndex: settings.clockStyle.index,
              accent: palette.accent,
              accentWash: palette.accentWash,
              ink: ink,
              hairline: palette.hairline,
              onSelect: (i) =>
                  notifier.setClockStyle(HeroClockStyle.values[i]),
            ),
            _ChoiceRow(
              title: 'Clock hour format',
              subtitle: '12-hour adds am/pm; system follows your phone',
              options: [
                for (final f in ClockHourFormat.values) f.label,
              ],
              selectedIndex: settings.clockHourFormat.index,
              accent: palette.accent,
              accentWash: palette.accentWash,
              ink: ink,
              hairline: palette.hairline,
              onSelect: (i) =>
                  notifier.setClockHourFormat(ClockHourFormat.values[i]),
            ),
          ],
        ),
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
              subtitle: 'Locks through the tiny accessibility service — '
                  'turning it on asks for the exact toggle',
              value: settings.doubleTapSleep,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) async {
                notifier.patchDoubleTapSleep(v);
                if (!v) return;
                final reachable =
                    ref.read(deviceCapabilityProvider).value ?? false;
                if (!reachable) return;
                final enabled = await ref
                    .read(deviceBridgeProvider)
                    .isLockServiceEnabled();
                if (enabled || !context.mounted) return;
                await showToadAsk(
                  context,
                  askLockService(
                    () => ref
                        .read(deviceBridgeProvider)
                        .openAccessibilitySettings(),
                  ),
                );
              },
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
              subtitle:
                  'Off by default — takes the shot through the screen-lock '
                  'service (same consent as double-tap sleep, Android 9+)',
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
/// Turning dots/badges on ASKS for Notification access when it is not
/// granted yet — the app asks, the user decides, nothing stays silent.
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

    Future<void> ensureDotsAccess() async {
      final reachable = ref.read(deviceCapabilityProvider).value ?? false;
      if (!reachable) return;
      final granted =
          await ref.read(deviceBridgeProvider).hasNotificationAccess();
      if (granted) {
        ref.invalidate(notificationAccessProvider);
        return;
      }
      if (!context.mounted) return;
      await showToadAsk(
        context,
        askNotificationAccess(
          () => ref
              .read(deviceBridgeProvider)
              .openNotificationListenerSettings(),
        ),
      );
      ref.invalidate(notificationAccessProvider);
    }

    return _SettingsScaffold(
      title: 'Notifications',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Notification dots',
              subtitle:
                  'Dots on icons when something waits — real counts live '
                  'with Notification access',
              value: settings.notificationDots,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) {
                notifier.setNotificationDots(v);
                if (v) ensureDotsAccess();
              },
            ),
            _SwitchRow(
              title: 'Badges',
              subtitle: 'Written counts, like Contacts · 2 missed',
              value: settings.badges,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) {
                notifier.setBadges(v);
                if (v) {
                  if (!settings.notificationDots) {
                    notifier.setNotificationDots(true);
                  }
                  ensureDotsAccess();
                }
              },
            ),
            const _NotificationAccessRow(),
          ],
        ),
      ],
    );
  }
}

/// Notification access — the one special access the dots service needs.
/// The counts service reads package names only, never message content.
class _NotificationAccessRow extends ConsumerWidget {
  const _NotificationAccessRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final reachable = ref.watch(deviceCapabilityProvider).value ?? false;
    final hasAccess = ref.watch(notificationAccessProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notification access', style: ToadType.hand(15, color: ink)),
                const SizedBox(height: 2),
                Text(
                  !reachable
                      ? 'Unknown while Android is not answering'
                      : hasAccess
                          ? 'Granted — dots show live counts; the service '
                              'reads package names only'
                          : 'Not granted — dots stay quiet until you flip '
                              'the exact toggle',
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (reachable && !hasAccess)
            const SizedBox(width: 10)
          else
            const SizedBox.shrink(),
          if (reachable && !hasAccess)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await ref
                    .read(deviceBridgeProvider)
                    .openNotificationListenerSettings();
                ref.invalidate(notificationAccessProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: palette.accentWash,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'open settings',
                  style: ToadType.hand(13, color: palette.accentInk),
                ),
              ),
            ),
        ],
      ),
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

/// About — live version + family + intro replay.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final version = ref.watch(currentVersionProvider).valueOrNull ??
        kFallbackVersion;

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
                '$version · asks for access, updates itself quietly',
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
        const SizedBox(height: 4),
        _GroupCard(
          palette: palette,
          children: [
            _SetRow(
              icon: '⌂',
              title: 'Watch the intro again',
              subtitle:
                  'The four welcome pages — the pond, the promise, '
                  'making it yours, the gestures',
              ink: ink,
              palette: palette,
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ref.read(launcherSettingsProvider.notifier).replayIntro();
              },
            ),
            _CertFingerprintRow(ink: ink, palette: palette),
          ],
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

/// Device & updates — real backend, silent self-update (toadFILES flow),
/// usage-access opt-in. Everything stated plainly, nothing hidden.
class DeviceUpdatesSettingsPage extends ConsumerWidget {
  const DeviceUpdatesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);
    final update = ref.watch(updateEngineProvider);
    final reachable = ref.watch(deviceCapabilityProvider).value ?? false;

    return _SettingsScaffold(
      title: 'Device & updates',
      children: [
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Device mode',
              subtitle: reachable
                  ? 'Real apps from this phone · falls back to demo if '
                        'Android ever stops answering'
                  : 'Android is not answering — demo mode stays on',
              value: settings.deviceMode && reachable,
              accent: palette.accent,
              ink: ink,
              onChanged: reachable
                  ? (v) => notifier.setDeviceMode(v)
                  : null,
            ),
            const _DefaultHomeRow(),
            _SwitchRow(
              title: 'Usage-based recents',
              subtitle:
                  'Opt-in special access. Off keeps the launcher\'s own '
                  'launch history — off never nags',
              value: settings.usageRecentsOptIn,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) async {
                notifier.setUsageRecentsOptIn(v);
                if (!v) return;
                final granted = await ref
                    .read(deviceBridgeProvider)
                    .hasUsageAccess();
                if (granted || !context.mounted) return;
                await showToadAsk(
                  context,
                  askUsageAccess(
                    () => ref
                        .read(deviceBridgeProvider)
                        .openUsageAccessSettings(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GroupCard(
          palette: palette,
          children: [
            _SwitchRow(
              title: 'Check for updates on start',
              subtitle:
                  'Silent, at most as often as the policy below allows. '
                  'Runs through the system download service — the launcher '
                  'itself has no INTERNET permission (same flow as '
                  'toadFILES)',
              value: settings.autoUpdateCheck,
              accent: palette.accent,
              ink: ink,
              onChanged: (v) => notifier.setAutoUpdateCheck(v),
            ),
            _ChoiceRow(
              title: 'How often',
              subtitle:
                  'Manual only = never check silently — the button below '
                  'always works. Releases are verified with a signature '
                  'before anything is offered',
              options: [for (final p in UpdatePolicy.values) p.label],
              selectedIndex: settings.updatePolicy.index,
              accent: palette.accent,
              accentWash: palette.accentWash,
              ink: ink,
              hairline: palette.hairline,
              onSelect: (i) => notifier.setUpdatePolicy(UpdatePolicy.values[i]),
            ),
            _UpdateCheckRow(state: update, ink: ink, palette: palette),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'updates come from github.com/dukeoftoad/toadLAUNCHER releases — '
          'one endpoint, nothing else',
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

/// The HOME-role row — P0 of the launcher checklist: the user must be
/// able to SEE whether toadLAUNCHER is the actual home app and fix it in
/// one tap (the system role dialog).
class _DefaultHomeRow extends ConsumerWidget {
  const _DefaultHomeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final reachable = ref.watch(deviceCapabilityProvider).value ?? false;
    final isHome = ref.watch(isDefaultHomeProvider).value ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Default home screen', style: ToadType.hand(15, color: ink)),
                const SizedBox(height: 2),
                Text(
                  !reachable
                      ? 'Unknown while Android is not answering'
                      : isHome
                          ? 'toadLAUNCHER is your Home — widgets, shortcuts '
                              'and shade are unlocked'
                          : 'Another app is Home — real widgets, app '
                              'shortcuts and pinned widgets need the HOME '
                              'role',
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (reachable && !isHome)
            const SizedBox(width: 10)
          else
            const SizedBox.shrink(),
          if (reachable && !isHome)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await ref.read(deviceBridgeProvider).requestDefaultHome();
                ref.invalidate(isDefaultHomeProvider);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: palette.accentWash,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'make Home',
                  style: ToadType.hand(13, color: palette.accentInk),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The manual check row + inline flow state (checking / up to date /
/// available → download / progress / install handoff / errors).
class _UpdateCheckRow extends StatelessWidget {
  const _UpdateCheckRow({required this.state, required this.ink, required this.palette});

  final UpdateState state;
  final Color ink;
  final ToadPalette palette;

  @override
  Widget build(BuildContext context) {
    final ctl = ProviderScope.containerOf(context).read(updateEngineProvider.notifier);

    final (String title, String subtitle, String? action) = switch (state) {
      UpdateIdle() => (
        'Check for updates now',
        'Current build vs the newest release',
        null,
      ),
      UpdateChecking() => ('Checking the pond…', 'Asking GitHub releases', null),
      UpdateUpToDate(:final version) => (
        'Up to date',
        'v$version is the newest build',
        'check again',
      ),
      UpdateAvailable(:final release) => (
        'Update available',
        '${release.tagName} · ${_fmtSize(release.apkSizeBytes)} · '
            '${release.notes == null ? 'release notes on GitHub' : 'notes below'}',
        'download & install',
      ),
      UpdateDownloading(:final fraction, :final snapshot) => (
        'Downloading…',
        fraction == null
            ? '${_fmtSize(snapshot.bytesSoFar)} — total size unknown'
            : '${(fraction * 100).round()}% of ${_fmtSize(snapshot.totalBytes)}',
        null,
      ),
      UpdateReadyToInstall() => ('Ready', 'Handing it to the installer…', null),
      UpdateNeedsInstallPermission() => (
        'Install permission needed',
        '"Install unknown apps" is off for the launcher — the exact '
            'settings toggle was opened; grant it and retry',
        'retry install',
      ),
      UpdateChecksumFailed() => (
        'Checksum mismatch',
        'The download failed the SHA-256 gate — nothing was installed. '
            'Try again or grab the APK from the release page',
        null,
      ),
      UpdateUnverified(:final release) => (
        'Release not verified',
        '${release.tagName} could not be proven ours (missing or invalid '
            'signature) — refused. Open the release page in the browser '
            'if you still want it',
        'open release page',
      ),
      UpdateFailed(:final message) => ('Update check', message, 'check again'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ToadType.hand(15, color: ink)),
                    const SizedBox(height: 2),
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
              if (action != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onAction(ctl, action),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentWash,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      action,
                      style: ToadType.hand(
                        13,
                        color: palette.accentInk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // The promised "notes below" — release notes actually rendered
          // when the release carries them (v0.12 fixed the old lie).
          if (state is UpdateAvailable &&
              (state as UpdateAvailable).release.notes != null &&
              (state as UpdateAvailable).release.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.accentWash,
                borderRadius: BorderRadius.circular(ToadRadii.inner + 2),
              ),
              child: Text(
                _trimNotes((state as UpdateAvailable).release.notes!),
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: ToadType.hand(
                  12.5,
                  height: 1.4,
                  color: ink.withValues(alpha: ink.a * 0.8),
                ),
              ),
            ),
          ],
          if (state is UpdateDownloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (state as UpdateDownloading).fraction,
                minHeight: 4,
                backgroundColor: palette.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Release bodies arrive as raw markdown; strip the noisier markup so
  /// the pond reads clean sentences.
  String _trimNotes(String notes) {
    final lines = notes
        .split('\n')
        .map((l) => l
            .replaceAll(RegExp(r'^#{1,6}\s*'), '')
            .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
            .replaceAll(RegExp(r'^[-*]\s+'), '· ')
            .trim())
        .where((l) => l.isNotEmpty)
        .take(14)
        .toList();
    return lines.join('\n');
  }

  void _onAction(UpdateEngine ctl, String action) {
    if (action == 'check again') {
      ctl.manualCheck();
    } else if (action == 'download & install') {
      ctl.download();
    } else if (action == 'retry install') {
      ctl.retryInstall();
    } else if (action == 'open release page') {
      ctl.openReleasePage();
    }
  }
}

String _fmtSize(int bytes) {
  if (bytes <= 0) return 'unknown size';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// SEC-01 — the installed build's signing certificate fingerprint, so
/// anyone can cross-check the APK in hand against SECURITY.md.
class _CertFingerprintRow extends ConsumerWidget {
  const _CertFingerprintRow({required this.ink, required this.palette});

  final Color ink;
  final ToadPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fingerprint = ref.watch(_certFingerprintProvider).valueOrNull;
    final pretty = fingerprint == null
        ? 'unavailable here (demo surface)'
        : _groupHex(fingerprint);
    return _SetRow(
      icon: '⚿',
      title: 'Signing certificate',
      subtitle:
          'SHA-256 of the key that signed this build — compare it with '
          'SECURITY.md on GitHub:\n$pretty',
      ink: ink,
      palette: palette,
      onTap: () {},
    );
  }

  static String _groupHex(String hex) {
    final out = StringBuffer();
    for (var i = 0; i + 4 <= hex.length; i += 4) {
      if (i > 0 && i % 28 == 0) {
        out.write('\n');
      } else if (i > 0) {
        out.write(':');
      }
      out.write(hex.substring(i, i + 4).toUpperCase());
    }
    return out.toString();
  }
}

final FutureProvider<String?> _certFingerprintProvider =
    FutureProvider<String?>(
      (ref) => ref.watch(deviceBridgeProvider).signingCertFingerprint(),
    );

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
/// [onChanged] null disables the switch — the row then explains why.
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
  final ValueChanged<bool>? onChanged;

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
          onChanged == null
              ? Opacity(
                  opacity: 0.45,
                  child: ToadSwitch(
                    value: value,
                    accent: accent,
                    onChanged: (_) {},
                  ),
                )
              : ToadSwitch(value: value, accent: accent, onChanged: onChanged!),
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

/// Permissions & access — the one page that never lets a special access
/// stay silently denied.
///
/// v0.11's flaw: every special access hid inside a different sub-page
/// (dots inside Notifications, the lock inside Gestures, usage inside
/// Device & updates), so a fresh install read "denied" everywhere and
/// the app never asked. This page lists all five, states the live status
/// in plain words, and asks — the calm dialog first, then the EXACT
/// Android toggle, then an automatic re-check when the user returns.
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/device/device_bridge.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_ask.dart';
import '../../shared/widgets/toad_toast.dart';
import '../home/home_controller.dart' show ToastEvent;

/// Entry point — Settings hub row + the first-run banner.
Future<void> openPermissionsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PermissionsPage()),
  );
}

class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  bool _checking = true;
  bool _reachable = true;
  bool _isHome = false;
  bool _notifs = false;
  bool _lock = false;
  bool _usage = false;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    final bridge = ref.read(deviceBridgeProvider);
    final reachable = await bridge.available();
    if (!mounted) return;
    if (!reachable) {
      setState(() {
        _reachable = false;
        _checking = false;
      });
      return;
    }
    final results = await Future.wait([
      bridge.isDefaultHome(),
      bridge.hasNotificationAccess(),
      bridge.isLockServiceEnabled(),
      bridge.hasUsageAccess(),
    ]);
    if (!mounted) return;
    setState(() {
      _reachable = true;
      _isHome = results[0];
      _notifs = results[1];
      _lock = results[2];
      _usage = results[3];
      _checking = false;
    });
  }

  /// Open a toggle, wait for the user to flip it there, then re-check.
  /// The user coming back to the launcher is the signal Android gave us;
  /// a short settle delay keeps ROMs that write the setting late honest.
  Future<void> _askAndGrant(ToadAsk Function(Future<void>) make) async {
    final proceeded = await showToadAsk(
      context,
      make(() async {
        // The concrete deep-link fires here, via the bridge — every ask
        // factory receives the exact open action for its access.
        await _openToggleFor(make);
      }),
    );
    if (!proceeded || !mounted) return;
    // Re-check shortly after return — toggles sometimes lag a beat.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _checkAll();
    if (!mounted) return;
    final status = _statusOf(make);
    if (status == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        toadToast(
          context,
          ToastEvent(
            status
                ? 'Granted — thank you'
                : 'Still off — flip the toggle and come back',
          ),
        ),
      );
  }

  /// The exact toggle per ask — the deep-link Android needs.
  Future<void> _openToggleFor(ToadAsk Function(Future<void>) make) async {
    final bridge = ref.read(deviceBridgeProvider);
    if (make == askDefaultHome) {
      await bridge.requestDefaultHome();
    } else if (make == askNotificationAccess) {
      await bridge.openNotificationListenerSettings();
    } else if (make == askLockService) {
      await bridge.openAccessibilitySettings();
    } else if (make == askUsageAccess) {
      await bridge.openUsageAccessSettings();
    }
  }

  /// Map the ask factory back to its live status for the post-grant toast.
  bool? _statusOf(ToadAsk Function(Future<void>) make) {
    // The five rows are identified by their factories; simple equality
    // keeps the mapping honest without extra machinery.
    if (make == askDefaultHome) return _isHome;
    if (make == askNotificationAccess) return _notifs;
    if (make == askLockService) return _lock;
    if (make == askUsageAccess) return _usage;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
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
                        child: Text('Permissions & access',
                            style: ToadType.caveat(32, color: ink)),
                      ),
                      if (!_checking)
                        GestureDetector(
                          onTap: () {
                            setState(() => _checking = true);
                            _checkAll();
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
                              're-check',
                              style: ToadType.hand(13, color: palette.accentInk),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Everything Android gates behind special access — '
                      'each row asks first, then opens the exact toggle.',
                      style: ToadType.inter(
                        11,
                        height: 1.4,
                        color: ink.withValues(alpha: ink.a * 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_checking)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'asking the phone…',
                          style: ToadType.hand(
                            14,
                            color: ink.withValues(alpha: ink.a * 0.5),
                          ),
                        ),
                      ),
                    )
                  else if (!_reachable)
                    _GroupCard(
                      palette: palette,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Android is not answering — statuses come back '
                          'once the bridge does. Demo mode never pretends.',
                          style: ToadType.hand(
                            13.5,
                            height: 1.4,
                            color: ink.withValues(alpha: ink.a * 0.75),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    _PermCard(
                      palette: palette,
                      ink: ink,
                      icon: '⌂',
                      title: 'Default home screen',
                      status: _isHome,
                      statusOn: 'toadLAUNCHER is your Home — widgets, '
                          'shortcuts and shade are unlocked',
                      statusOff: 'Another app is Home — real widgets and '
                          'app shortcuts stay locked',
                      ask: askDefaultHome,
                      onGrant: () => _askAndGrant(askDefaultHome),
                    ),
                    _PermCard(
                      palette: palette,
                      ink: ink,
                      icon: '◔',
                      title: 'Notification access',
                      status: _notifs,
                      statusOn: 'Granted — live dots per app; package '
                          'names only, never message text',
                      statusOff: 'Not granted — dots stay quiet until you '
                          'flip the exact toggle',
                      ask: askNotificationAccess,
                      onGrant: () => _askAndGrant(askNotificationAccess),
                    ),
                    _PermCard(
                      palette: palette,
                      ink: ink,
                      icon: '⌾',
                      title: 'Screen lock service',
                      status: _lock,
                      statusOn: 'Granted — double-tap on home locks the '
                          'screen (Android 9+)',
                      statusOff: 'Not granted — double-tap says so honestly '
                          'until you flip the accessibility entry',
                      ask: askLockService,
                      onGrant: () => _askAndGrant(askLockService),
                    ),
                    _PermCard(
                      palette: palette,
                      ink: ink,
                      icon: '◷',
                      title: 'Usage access',
                      status: _usage,
                      statusOn: 'Granted — the drawer recents row follows '
                          'real usage (opt-in)',
                      statusOff: 'Not granted — recents use the launcher\'s '
                          'own launch history instead',
                      ask: askUsageAccess,
                      onGrant: () => _askAndGrant(askUsageAccess),
                    ),
                    const SizedBox(height: 4),
                    _GroupCard(
                      palette: palette,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Install unknown apps',
                              style: ToadType.hand(15, color: ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Asked only when an update download is ready '
                              '— the installer handoff opens the exact '
                              'toggle for toadLAUNCHER, never a blanket '
                              'grant.',
                              style: ToadType.inter(
                                10.5,
                                height: 1.35,
                                color: ink.withValues(alpha: ink.a * 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _GroupCard(
                      palette: palette,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Never asked, never granted',
                              style: ToadType.hand(15, color: ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'INTERNET — the APK holds no network '
                              'permission; updates ride the system download '
                              'service. Location, contacts, storage — no. '
                              'The manifest is the promise.',
                              style: ToadType.inter(
                                10.5,
                                height: 1.35,
                                color: ink.withValues(alpha: ink.a * 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One special access: icon, name, honest status line, grant pill.
class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.palette,
    required this.ink,
    required this.icon,
    required this.title,
    required this.status,
    required this.statusOn,
    required this.statusOff,
    required this.ask,
    required this.onGrant,
  });

  final ToadPalette palette;
  final Color ink;
  final String icon;
  final String title;
  final bool status;
  final String statusOn;
  final String statusOff;
  final ToadAsk Function(Future<void> Function()) ask;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return _GroupCard(
      palette: palette,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    status ? statusOn : statusOff,
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
            status
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Text(
                      'granted',
                      style: ToadType.hand(13, color: palette.accentInk),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onGrant,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'grant',
                        style: ToadType.hand(13, color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Shared group card (mirrors the settings hub's).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.palette, required this.child});

  final ToadPalette palette;
  final Widget child;

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
      child: child,
    );
  }
}

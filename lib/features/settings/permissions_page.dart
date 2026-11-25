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

  Future<void> _askAndGrant(
    ToadAsk Function(Future<void> Function()) make,
  ) async {
    final bridge = ref.read(deviceBridgeProvider);

    final restrictedProne =
        make == askNotificationAccess || make == askLockService;
    var guideShown = false;
    if (restrictedProne && mounted) {
      final sdk = await bridge.osSdkInt();
      final currentlyGranted = _statusOf(make) == true;
      if (sdk >= 33 && !currentlyGranted && mounted) {
        guideShown = true;
        final unlocked = await showToadAsk(
          context,
          askRestrictedSettings(
            () => bridge.appDetails('family.toad.launcher'),
          ),
        );
        if (!unlocked || !mounted) return;
      }
    }

    if (!mounted) return;
    final proceeded = await showToadAsk(
      context,
      make(() async {
        await _openToggleFor(make);
      }),
    );
    if (!proceeded || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _checkAll();
    if (!mounted) return;
    final status = _statusOf(make);
    if (status == null) return;
    final retryTip = !status && guideShown
        ? 'If the switch was greyed out: App info → ⋮ → "Allow restricted '
              'settings", then try again'
        : 'Still off — flip the toggle and come back';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        toadToast(
          context,
          ToastEvent(status ? 'Granted — thank you' : retryTip),
        ),
      );
  }

  Future<void> _openToggleFor(
    ToadAsk Function(Future<void> Function()) make,
  ) async {
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

  bool? _statusOf(ToadAsk Function(Future<void> Function()) make) {
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

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.palette,
    required this.ink,
    required this.icon,
    required this.title,
    required this.status,
    required this.statusOn,
    required this.statusOff,
    required this.onGrant,
  });

  final ToadPalette palette;
  final Color ink;
  final String icon;
  final String title;
  final bool status;
  final String statusOn;
  final String statusOff;
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

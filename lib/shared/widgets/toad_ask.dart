/// Ask-by-app permission flow — the anti-silent-denial.
///
/// The old flaw: special accesses (Notification listener, Accessibility
/// lock service, Usage stats, install permission, HOME role) sat behind
/// buried settings rows, so on a fresh install everything read "denied"
/// and nothing asked. Fixed with one calm, hand-made dialog:
///
///   1. the app explains WHAT it needs and WHY (honest, one paragraph)
///   2. "grant now" opens the EXACT Android toggle (deep-link, never a
///      settings scavenger hunt)
///   3. when the user comes back, the caller re-checks and reports —
///      nothing pretends it was granted
///
/// Every ask is reversible: "not now" closes and the feature keeps
/// degrading honestly (never nagging twice for the same denial in a row).
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

/// One ask: what the app needs, why it is needed, and the deep-link
/// action that opens the exact system toggle.
class ToadAsk {
  const ToadAsk({
    required this.icon,
    required this.title,
    required this.reason,
    required this.openToggle,
    this.toggleLabel = 'open the toggle',
  });

  final String icon;
  final String title;
  final String reason;

  /// Opens the exact Android settings screen; resolves when the screen
  /// is launched.
  final Future<void> Function() openToggle;
  final String toggleLabel;
}

/// Shows the calm ask dialog. Resolves `true` when the user chose to
/// open the toggle (so the caller knows to re-check on return), `false`
/// when they declined or Android refused to open the screen.
Future<bool> showToadAsk(BuildContext context, ToadAsk ask) async {
  final palette = ToadTheme.of(context).palette;
  final dark = ToadTheme.of(context).isDark;
  final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
  final softInk = ink.withValues(alpha: ink.a * 0.62);

  final proceed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black38,
    builder: (dialogContext) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.statusIconBrightness,
      ),
      child: AlertDialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
          side: BorderSide(color: palette.hairline),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accentWash,
                    borderRadius: BorderRadius.circular(
                      ToadRadii.settingsIconChip + 2,
                    ),
                  ),
                  child: Text(
                    ask.icon,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1,
                      fontFamily: ToadType.fontHand,
                      color: palette.accentInk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ask.title,
                    style: ToadType.caveat(24, color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ask.reason,
              style: ToadType.hand(14, height: 1.45, color: softInk),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: softInk),
            child: Text('not now', style: ToadType.hand(14)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(ask.toggleLabel, style: ToadType.hand(14)),
          ),
        ],
      ),
    ),
  );

  if (proceed != true) return false;
  await ask.openToggle();
  return true;
}

// ---------------------------------------------------------------------------
// The five asks — one factory per special access. Keep the copy honest:
// what is read, what is done, and what the app never does.
// ---------------------------------------------------------------------------

/// Notification access — feeds the live dots. Reads package names only.
ToadAsk askNotificationAccess(Future<void> Function() open) => ToadAsk(
  icon: '◔',
  title: 'Notification access',
  reason:
      'Notification dots light up when something waits for you. '
      'Android only allows this through Notification access — '
      'toadLAUNCHER reads package names and counts, never message '
      'titles or text. The exact toggle opens on the next tap; flip '
      '"toadLAUNCHER" on and come back.',
  toggleLabel: 'open Notification access',
  openToggle: open,
);

/// Accessibility (lock service) — double-tap-to-sleep's engine.
ToadAsk askLockService(Future<void> Function() open) => ToadAsk(
  icon: '⌾',
  title: 'Screen lock service',
  reason:
      'Double-tap to sleep works through one tiny accessibility '
      'service — the only action it can perform is locking the '
      'screen. It watches nothing: no window content, no events, no '
      'feedback. The exact entry opens pre-selected; flip '
      '"toadLAUNCHER screen lock" on and come back.',
  toggleLabel: 'open Accessibility',
  openToggle: open,
);

/// Usage access — drawer recents from real usage, opt-in.
ToadAsk askUsageAccess(Future<void> Function() open) => ToadAsk(
  icon: '◷',
  title: 'Usage access',
  reason:
      'The recents row can show the apps Android saw you actually '
      'use. That needs the special "Usage access" toggle — the '
      'launcher reads last-use times only, never screens or '
      'contents. Off keeps the launcher\'s own launch history.',
  toggleLabel: 'open Usage access',
  openToggle: open,
);

/// Install unknown apps — the self-update handoff.
ToadAsk askInstallPermission(Future<void> Function() open) => ToadAsk(
  icon: '⬒',
  title: 'Install unknown apps',
  reason:
      'Updates install through the system installer, and Android '
      'asks for "Install unknown apps" once per app. The APK comes '
      'from the official GitHub release and passes a SHA-256 gate '
      'before the installer ever sees it.',
  toggleLabel: 'open the toggle',
  openToggle: open,
);

/// HOME role — real widgets, shortcuts, shade.
ToadAsk askDefaultHome(Future<void> Function() open) => ToadAsk(
  icon: '⌂',
  title: 'Make toadLAUNCHER your Home',
  reason:
      'Android binds real widgets, app shortcuts and pinned widgets '
      'to the actual Home app. While another app is Home, those stay '
      'locked — one system dialog settles it, and you can switch '
      'back any time.',
  toggleLabel: 'open the system dialog',
  openToggle: open,
);

library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../home/home_controller.dart' show toastProvider;

/// FEAT-10: one quiet focus session. While it runs the pond calms, rain
/// stops, notification dots and the memories card hide — the launcher
/// stays fully usable, it just stops shouting. The session always ends on
/// time (a real timer, not a clock poll), tap the chip to end early.
class FocusSessionState {
  const FocusSessionState({this.endsAt});

  final DateTime? endsAt;

  bool get active => endsAt != null;
}

class FocusSessionController extends Notifier<FocusSessionState> {
  Timer? _endTimer;

  @override
  FocusSessionState build() {
    ref.onDispose(() => _endTimer?.cancel());
    return const FocusSessionState();
  }

  void start(int minutes) {
    final clean = minutes.clamp(5, 120);
    _endTimer?.cancel();
    final endsAt = DateTime.now().add(Duration(minutes: clean));
    state = FocusSessionState(endsAt: endsAt);
    _endTimer = Timer(Duration(minutes: clean), () {
      end(completed: true);
    });
    ref
        .read(toastProvider.notifier)
        .show('Focus — $clean quiet minutes. The pond goes still.');
  }

  void end({bool completed = false}) {
    _endTimer?.cancel();
    _endTimer = null;
    if (!state.active) return;
    state = const FocusSessionState();
    ref
        .read(toastProvider.notifier)
        .show(completed ? 'Focus complete — welcome back' : 'Focus ended');
  }
}

final NotifierProvider<FocusSessionController, FocusSessionState>
focusSessionProvider =
    NotifierProvider<FocusSessionController, FocusSessionState>(
      FocusSessionController.new,
    );

/// The settings the launcher should honor right now: during a focus
/// session the calm overrides are forced on top of the user's choices.
/// Consumers of dots, badges, memories and pond motion read this instead
/// of the raw settings.
final Provider<LauncherSettings> focusAwareSettingsProvider =
    Provider<LauncherSettings>((ref) {
      final settings = ref.watch(launcherSettingsProvider);
      final focus = ref.watch(focusSessionProvider);
      if (!focus.active) return settings;
      return settings.copyWith(
        calmPond: true,
        pondRain: false,
        notificationDots: false,
        badges: false,
        showMemoriesCard: false,
      );
    });

/// The one visible trace of a running session: a small countdown chip.
/// Tapping it ends the session early.
class FocusChip extends ConsumerWidget {
  const FocusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusSessionProvider);
    if (!focus.active) return const SizedBox.shrink();

    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final remaining = focus.endsAt!.difference(now);
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final mm = clamped.inMinutes;
    final ss = clamped.inSeconds % 60;

    final palette = ToadTheme.of(context).palette;

    return Semantics(
      button: true,
      label:
          'Focus session, $mm minutes ${ss.toString().padLeft(2, '0')} '
          'seconds remaining. Tap to end.',
      child: GestureDetector(
        onTap: () => ref.read(focusSessionProvider.notifier).end(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: palette.surface.a * 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: palette.accent.withValues(alpha: palette.accent.a * 0.6),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26140F05),
                offset: Offset(0, 4),
                blurRadius: 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size.square(12),
                painter: _LeafPainter(color: palette.accent),
              ),
              const SizedBox(width: 8),
              Text(
                '$mm:${ss.toString().padLeft(2, '0')}',
                style: ToadType.hand(13.5, color: palette.accentInk),
              ),
              const SizedBox(width: 8),
              Text(
                'end',
                style: ToadType.inter(
                  10.5,
                  color: palette.ink.withValues(alpha: palette.ink.a * 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.85, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.1,
        size.height * 0.3,
        size.width * 0.15,
        size.height * 0.85,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.7,
        size.width * 0.85,
        size.height * 0.15,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) => oldDelegate.color != color;
}

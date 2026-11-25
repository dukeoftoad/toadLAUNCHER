/// Battery & pond guard — the drain page.
///
/// The pond watches its own energy: live level, measured %/hour (summed
/// over unplugged spans only), an honest runtime estimate when data
/// exists, the local history sparkline, and the low-battery calm switch
/// (≤ 15 % and unplugged → the pond falls night and freezes, exactly
/// like Calm-pond but driven by the drain).
///
/// Demo honesty: when the OS does not answer, the simulated pond battery
/// says so right in the header — nothing pretends to be a real phone.
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/device/battery_monitor.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../wallpaper_style/wallpaper_style_screen.dart' show ToadSwitch;

class BatteryPage extends ConsumerWidget {
  const BatteryPage({super.key});

  String _fmtHours(double h) {
    if (h >= 24) return 'more than a day';
    final hours = h.floor();
    final minutes = ((h - hours) * 60).round();
    if (hours == 0) return 'about $minutes min';
    return minutes == 0
        ? 'about $hours h'
        : 'about $hours h $minutes min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final softInk = ink.withValues(alpha: ink.a * 0.55);
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);
    final battery = ref.watch(batteryMonitorProvider);
    final monitor = ref.read(batteryMonitorProvider.notifier);

    final rate = battery.drainPerHour();
    final estimate = battery.estimatedHoursLeft();
    final lowBattery = battery.lowBattery;
    final calmNow = ref.watch(pondCalmProvider);

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
                        child: Text('Battery & pond guard',
                            style: ToadType.caveat(32, color: ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Live status card.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius:
                          BorderRadius.circular(ToadRadii.settingsGroup),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              battery.level >= 0 ? '${battery.level}%' : '—',
                              style: ToadType.caveat(
                                56,
                                color: lowBattery
                                    ? palette.danger
                                    : palette.ink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                switch ((
                                  charging: battery.charging,
                                  full: battery.full,
                                  unknown: battery.level < 0,
                                )) {
                                  (unknown: true) => 'waiting for the OS…',
                                  (full: true) => 'the frog is full',
                                  (charging: true) => 'charging',
                                  _ => lowBattery
                                      ? 'low — the pond guards itself'
                                      : 'unplugged',
                                },
                                style: ToadType.hand(15, color: softInk),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          battery.demo
                              ? 'demo battery — no OS behind the channel, '
                                  'the pond simulates. On a phone these are '
                                  'real readings.'
                              : 'Readings come from the OS battery broadcast '
                                  '— level and plugged state only.',
                          style: ToadType.inter(
                            10.5,
                            height: 1.35,
                            color: softInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Drain math.
                  _GroupCard(
                    palette: palette,
                    children: [
                      _Row(
                        title: 'Drain rate',
                        subtitle: rate == null
                            ? 'not enough unplugged history yet — it shows '
                                'once 12+ minutes are measured'
                            : '−${rate.toStringAsFixed(1)}% per hour '
                                '(measured while unplugged)',
                        trailing: rate == null
                            ? null
                            : _rateChip(rate, palette),
                        ink: ink,
                        palette: palette,
                      ),
                      _Row(
                        title: 'Runtime estimate',
                        subtitle: estimate == null
                            ? rate == null
                                ? 'waiting for a measured rate'
                                : 'charging — estimates resume unplugged'
                            : _fmtHours(estimate),
                        ink: ink,
                        palette: palette,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // History sparkline.
                  _GroupCard(
                    palette: palette,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Last 6 hours',
                                style: ToadType.hand(15, color: ink)),
                            const SizedBox(height: 3),
                            Text(
                              'Local samples only — ${battery.samples.length} '
                              'kept on this device, never sent anywhere.',
                              style: ToadType.inter(
                                10.5,
                                color: softInk,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 72,
                              width: double.infinity,
                              child: battery.samples.length < 2
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'the sparkline appears as samples '
                                        'arrive',
                                        style: ToadType.hand(
                                          13,
                                          color: softInk,
                                        ),
                                      ),
                                    )
                                  : CustomPaint(
                                      painter: _DrainSparklinePainter(
                                        samples: battery.samples,
                                        accent: palette.accent,
                                        hairline: palette.hairline,
                                        ink: ink,
                                        chargingColor: palette.gold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // The guard.
                  _GroupCard(
                    palette: palette,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Low-battery calm',
                                      style:
                                          ToadType.hand(15, color: ink)),
                                  const SizedBox(height: 1),
                                  Text(
                                    'When the battery reads ≤ 15% and '
                                    'unplugged, night falls instantly and '
                                    'the ambient loop freezes — Calm-pond, '
                                    'driven by the drain',
                                    style: ToadType.inter(
                                      10.5,
                                      height: 1.3,
                                      color: softInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ToadSwitch(
                              value: settings.lowBatteryCalm,
                              accent: palette.accent,
                              onChanged: notifier.setLowBatteryCalm,
                            ),
                          ],
                        ),
                      ),
                      _Row(
                        title: 'Pond right now',
                        subtitle: calmNow
                            ? lowBattery
                                ? 'frozen by the drain guard — every pixel '
                                    'is resting'
                                : 'calm (Calm-pond is on or the pond is '
                                    'asleep)'
                            : 'animating',
                        ink: ink,
                        palette: palette,
                      ),
                      _Row(
                        title: 'Forget the history',
                        subtitle:
                            'Wipes the local samples and starts measuring '
                            'over — settings and everything else stay',
                        trailing: Text(
                          'clear',
                          style: ToadType.hand(13, color: palette.accentInk),
                        ),
                        onTrailingTap: () async {
                          await monitor.clearHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: palette.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: palette.hairline),
                                ),
                                content: Text(
                                  'battery history cleared',
                                  style: ToadType.hand(
                                    13.5,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        ink: ink,
                        palette: palette,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'no battery-history permission — the samples are the '
                    'launcher\'s own',
                    textAlign: TextAlign.center,
                    style: ToadType.inter(
                      10.5,
                      color: softInk.withValues(alpha: softInk.a * 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rateChip(double rate, ToadPalette palette) {
    final hot = rate > 12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: hot
            ? palette.danger.withValues(alpha: palette.danger.a * 0.14)
            : palette.accentWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hot ? 'thirsty frog' : 'healthy',
        style: ToadType.hand(
          13,
          color: hot ? palette.danger : palette.accentInk,
        ),
      ),
    );
  }
}

/// One settings row (mirrors the hub's) with an optional trailing widget.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.palette,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final Color ink;
  final ToadPalette palette;

  /// Trailing widget — a pill/chip; wrap plain strings in the caller.
  final Widget? trailing;
  final VoidCallback? onTrailingTap;

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
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: palette.accentWash,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: trailing,
              ),
            ),
        ],
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

/// The drain sparkline — level over the trailing 6 h. Charging spans get
/// a gold underwash so a charge session reads as a rise, not a lie.
class _DrainSparklinePainter extends CustomPainter {
  _DrainSparklinePainter({
    required this.samples,
    required this.accent,
    required this.hairline,
    required this.ink,
    required this.chargingColor,
  });

  final List<BatterySample> samples;
  final Color accent;
  final Color hairline;
  final Color ink;
  final Color chargingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final window = const Duration(hours: 6);
    final inWindow = samples
        .where((s) => now.difference(s.at) <= const Duration(hours: 7))
        .toList();
    if (inWindow.length < 2) return;

    final t0 = inWindow.first.at;
    double xOf(BatterySample s) {
      final t = s.at.difference(t0).inMicroseconds /
          window.inMicroseconds;
      return t.clamp(0.0, 1.0) * size.width;
    }

    double yOf(BatterySample s) =>
        size.height - ((s.level.clamp(0, 100)) / 100) * (size.height - 8) - 4;

    // Charging underwash.
    final wash = Paint();
    for (var i = 1; i < inWindow.length; i++) {
      final prev = inWindow[i - 1];
      final cur = inWindow[i];
      if (!cur.charging) continue;
      wash.color = chargingColor.withValues(
        alpha: chargingColor.a * 0.18,
      );
      canvas.drawRect(
        Rect.fromLTRB(xOf(prev), 0, xOf(cur), size.height),
        wash,
      );
    }

    // Baseline grid at 25/50/75.
    final grid = Paint()
      ..color = hairline.withValues(alpha: hairline.a * 0.6)
      ..strokeWidth = 1;
    for (final p in const [0.25, 0.5, 0.75]) {
      final y = size.height - p * (size.height - 8) - 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // The curve itself.
    final line = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(xOf(inWindow.first), yOf(inWindow.first));
    for (var i = 1; i < inWindow.length; i++) {
      path.lineTo(xOf(inWindow[i]), yOf(inWindow[i]));
    }
    canvas.drawPath(path, line);

    // Latest point, filled.
    final last = inWindow.last;
    canvas.drawCircle(
      Offset(xOf(last), yOf(last)),
      4,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(xOf(last), yOf(last)),
      7,
      Paint()
        ..color = ink.withValues(alpha: ink.a * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DrainSparklinePainter old) =>
      old.samples.length != samples.length ||
      old.samples.lastOrNull?.level != samples.lastOrNull?.level ||
      old.accent != accent;
}

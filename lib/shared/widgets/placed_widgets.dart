library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/device/battery_monitor.dart' show batteryMonitorProvider;
import '../../core/settings/launcher_settings.dart' show clockProvider, launcherSettingsProvider;
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../features/home/widgets/hero_zone.dart' show buildHeroData;
import '../../features/settings/battery_page.dart';
import '../../features/todo/todo_store.dart' show todoListProvider;
import 'android_widget_view.dart';
import 'clock_faces.dart';

double clockScale(int w, int h) => (w / 4 * h).clamp(0.55, 1.7);

double widgetZoneHeight(int h) => 64.0 + h * 48;

class PlacedWidgetView extends ConsumerWidget {
  const PlacedWidgetView({
    super.key,
    required this.widget,
    this.memory,
    this.height,
  });

  final PlacedWidget widget;
  final MemoryCardData? memory;

  /// Explicit pixel height (FEAT-01 canvas). Null falls back to the
  /// legacy zone height so picker previews keep their sizing.
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    switch (widget.kind) {
      case WidgetKind.clock:
        return ClockWidgetView(
          now: now,
          w: widget.w,
          h: widget.h,
          height: height,
        );
      case WidgetKind.memories:
        return MemoriesWidgetView(memory: memory, h: widget.h, height: height);
      case WidgetKind.calendar:
        return CalendarWidgetView(now: now, h: widget.h, height: height);
      case WidgetKind.sticky:
        return StickyWidgetView(h: widget.h, height: height);
      case WidgetKind.androidHosted:
        return AndroidHostedWidgetView(widget: widget, height: height);
    }
  }
}

class ClockWidgetView extends ConsumerWidget {
  const ClockWidgetView({
    super.key,
    required this.now,
    required this.w,
    required this.h,
    this.height,
  });

  final DateTime now;
  final int w;
  final int h;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ToadTheme.of(context).palette;
    final settings = ref.watch(launcherSettingsProvider);
    final data = buildHeroData(now, pond: false, pondNight: false);
    final scale = clockScale(w, h);
    final battery = ref.watch(batteryMonitorProvider);

    return SizedBox(
      height: height ?? widgetZoneHeight(h),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeroClockFace(
                        now: now,
                        style: settings.clockStyle,
                        format: settings.clockHourFormat,
                        system24: MediaQuery.alwaysUse24HourFormatOf(context),
                        size: ToadMetrics.heroClockSize * scale,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.dateLine,
                        style: ToadType.hand(
                          ToadMetrics.heroDateSize * scale,
                          color: palette.ink.withValues(
                            alpha: palette.ink.a * 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (w >= 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data.noteTop,
                      textAlign: TextAlign.right,
                      style: ToadType.inter(
                        ToadMetrics.heroSideSize,
                        color: palette.ink.withValues(
                          alpha: palette.ink.a * 0.65,
                        ),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      data.noteBottom,
                      textAlign: TextAlign.right,
                      style: ToadType.inter(
                        ToadMetrics.heroSideSize,
                        color: palette.ink.withValues(
                          alpha: palette.ink.a * 0.65,
                        ),
                        height: 1.5,
                      ),
                    ),
                    if (battery.level >= 0) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BatteryPage(),
                              ),
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentWash,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: palette.hairline.withValues(
                                alpha: palette.hairline.a * 0.8,
                              ),
                            ),
                          ),
                          child: Text(
                            battery.heroLine,
                            style: ToadType.inter(
                              ToadMetrics.heroSideSize - 0.5,
                              color: palette.accentInk,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MemoriesWidgetView extends StatelessWidget {
  const MemoriesWidgetView({
    super.key,
    required this.memory,
    required this.h,
    this.height,
  });

  final MemoryCardData? memory;
  final int h;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final data = memory;

    return SizedBox(
      height: height ?? widgetZoneHeight(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: palette.surface.a * 0.85),
            borderRadius: BorderRadius.circular(ToadRadii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: data == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'toadGALLERY · Memories',
                    style: ToadType.hand(16, color: palette.ink),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.title,
                            style: ToadType.caveat(
                              ToadMetrics.memoryTitleSize,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        Text(
                          data.meta,
                          style: ToadType.inter(
                            10.5,
                            color: palette.ink.withValues(
                              alpha: palette.ink.a * 0.62,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: ToadMetrics.memoryPhotoHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ToadMetrics.memoryPhotoRadius,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors:
                                      AppIconGradients.memoryPhotos[i %
                                          AppIconGradients.memoryPhotos.length],
                                  transform: const GradientRotation(
                                    145 * 3.14159 / 180,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CalendarWidgetView extends StatelessWidget {
  const CalendarWidgetView({
    super.key,
    required this.now,
    required this.h,
    this.height,
  });

  final DateTime now;
  final int h;
  final double? height;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1;

    return SizedBox(
      height: height ?? widgetZoneHeight(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: palette.surface.a * 0.85),
            borderRadius: BorderRadius.circular(ToadRadii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_months[now.month - 1]} ${now.year}',
                style: ToadType.caveat(24, color: palette.ink),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 2,
                  children: [
                    for (final d in _weekdays)
                      Center(
                        child: Text(
                          d,
                          style: ToadType.inter(
                            9,
                            weight: 600,
                            color: palette.ink.withValues(
                              alpha: palette.ink.a * 0.5,
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
                    for (var day = 1; day <= daysInMonth; day++)
                      Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: day == now.day
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.accent,
                                )
                              : null,
                          child: Text(
                            '$day',
                            style: ToadType.inter(
                              9.5,
                              weight: day == now.day ? 700 : 400,
                              color: day == now.day
                                  ? Colors.white
                                  : palette.ink.withValues(
                                      alpha: palette.ink.a * 0.78,
                                    ),
                            ),
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

class StickyWidgetView extends ConsumerWidget {
  const StickyWidgetView({super.key, required this.h, this.height});

  final int h;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ToadTheme.of(context).palette;
    final tasks = ref.watch(todoListProvider);
    final open = tasks.where((t) => !t.done).toList();

    final String body;
    if (open.isEmpty) {
      body = tasks.isEmpty
          ? 'toadLIST\n\nnothing to catch —\nadd flies in the drawer'
          : 'toadLIST\n\nevery fly is caught ✓';
    } else {
      final lines = open.take(3).map((t) {
        final prefix = t.comments.isEmpty ? '' : ' (${t.comments.length})';
        return '· ${_clip(t.title, 16)}$prefix';
      }).join('\n');
      body = open.length <= 3
          ? lines
          : '$lines\n…and ${open.length - 3} more';
    }

    return SizedBox(
      height: height ?? widgetZoneHeight(h),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
              decoration: BoxDecoration(
                color: palette.gold.withValues(alpha: palette.gold.a * 0.22),
                borderRadius: BorderRadius.circular(ToadRadii.inner + 2),
                border: Border.all(
                  color: palette.hairline.withValues(
                    alpha: palette.hairline.a * 0.8,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  body,
                  style: ToadType.hand(
                    15,
                    height: 1.35,
                    color: palette.ink.withValues(alpha: palette.ink.a * 0.9),
                  ),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 14,
              decoration: BoxDecoration(
                color: palette.surface2.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clip(String s, [int max = 16]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

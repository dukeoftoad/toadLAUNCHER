/// Hero zone — "hero widget first": Caveat clock + Patrick Hand date on the
/// left, decorative two-line side note on the right. Tapping the clock opens
/// the Clock app (device mode); the zone is swappable/removable (stage 2).
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/toad_theme.dart';
import '../../../core/theme/toad_tokens.dart';

class HeroClockData {
  const HeroClockData({
    required this.time,
    required this.dateLine,
    required this.noteTop,
    required this.noteBottom,
  });

  final String time; // "10:42"
  final String dateLine; // "Sunday · 23 November"
  final String noteTop;
  final String noteBottom;
}

/// Pure formatting so the widget stays dumb and testable.
HeroClockData buildHeroData(
  DateTime now, {
  required bool pond,
  required bool pondNight,
}) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
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

  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  final dateLine =
      '${weekdays[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';

  // Days until the 1st of the next month ("3 days to December").
  final nextMonth = DateTime(now.year, now.month + 1, 1);
  final daysTo = nextMonth
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  final monthNote =
      '$daysTo ${daysTo == 1 ? 'day' : 'days'} to ${months[nextMonth.month - 1]}';

  if (pond) {
    if (pondNight) {
      return HeroClockData(
        time: time,
        dateLine: dateLine,
        noteTop: 'the pond is asleep',
        noteBottom: 'alarm 6:45',
      );
    }
    return HeroClockData(
      time: time,
      dateLine: dateLine,
      noteTop: 'the pond is calm',
      noteBottom: monthNote,
    );
  }

  final String greeting;
  if (now.hour >= 5 && now.hour < 12) {
    greeting = 'good morning';
  } else if (now.hour >= 12 && now.hour < 17) {
    greeting = 'good afternoon';
  } else if (now.hour >= 17 && now.hour < 21) {
    greeting = 'good evening';
  } else {
    greeting = 'good night';
  }

  final bottom = (now.hour >= 21 || now.hour < 5)
      ? 'wind down soon'
      : monthNote;

  return HeroClockData(
    time: time,
    dateLine: dateLine,
    noteTop: greeting,
    noteBottom: bottom,
  );
}

class HeroZone extends StatelessWidget {
  const HeroZone({
    super.key,
    required this.data,
    this.batteryLine,
    this.onBatteryTap,
  });

  final HeroClockData data;

  /// The pond battery pill — one honest line from the drain monitor
  /// ("battery 76% · −6.2%/h"). Null renders nothing (unknown/hidden).
  final String? batteryLine;

  /// Tapping the pill opens Settings → Battery (the drain page).
  final VoidCallback? onBatteryTap;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The clock itself: Caveat 700 · 78px · lh .9 · ls 1.
                Text(
                  data.time,
                  style: ToadType.caveat(
                    ToadMetrics.heroClockSize,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.dateLine,
                  style: ToadType.hand(
                    ToadMetrics.heroDateSize,
                    color: palette.ink.withValues(alpha: palette.ink.a * 0.75),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.noteTop,
                  textAlign: TextAlign.right,
                  style: ToadType.inter(
                    ToadMetrics.heroSideSize,
                    color: palette.ink.withValues(alpha: palette.ink.a * 0.65),
                    height: 1.5,
                  ),
                ),
                Text(
                  data.noteBottom,
                  textAlign: TextAlign.right,
                  style: ToadType.inter(
                    ToadMetrics.heroSideSize,
                    color: palette.ink.withValues(alpha: palette.ink.a * 0.65),
                    height: 1.5,
                  ),
                ),
                if (batteryLine != null) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBatteryTap,
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
                        batteryLine!,
                        textAlign: TextAlign.right,
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
    );
  }
}

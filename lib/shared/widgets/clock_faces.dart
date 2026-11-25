/// The pond wears four faces — CLOCK work (roadmap §6 “hero clock styles”).
///
/// One file holds every clock face + the pure formatting helpers so the
/// hero zone and the placed clock widget share exactly the same code:
///   hand   — the original Caveat lettering (default, stage-1 look)
///   analog — a hand-drawn dial (CustomPainter, palette-aware)
///   word   — “twenty to eleven” phrasing (rounds to the nearest five)
///   flip   — flip-card digits (AnimatedSwitcher, calm motion)
///
/// Hour format is a setting (system / 12 h / 24 h — PLT-13). Pure helpers
/// live at the top; widgets below. Everything here is offline and local.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

// ---------------------------------------------------------------------------
// Pure formatting — unit-testable, no widgets.
// ---------------------------------------------------------------------------

const List<String> _hourWords = [
  'twelve',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
];

/// Digital time for the chosen format. `system24` is the platform truth
/// (MediaQuery.alwaysUse24HourFormat) resolved by the caller.
String formatClockTime(DateTime now, ClockHourFormat format, bool system24) {
  final use24 = switch (format) {
    ClockHourFormat.system => system24,
    ClockHourFormat.h12 => false,
    ClockHourFormat.h24 => true,
  };
  if (use24) {
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
  final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
  return '$hour12:${now.minute.toString().padLeft(2, '0')} '
      '${now.hour < 12 ? 'am' : 'pm'}';
}

/// The word-clock phrase — “quarter past ten”, “twenty to eleven”. Rounds
/// to the nearest five minutes the way word clocks do; midnight and noon
/// are themselves.
String wordClockPhrase(DateTime now) {
  // Round to the nearest five (this can roll into the next hour/day —
  // 23:58 becomes midnight, 11:59 becomes noon).
  final rounded = DateTime(now.year, now.month, now.day, now.hour)
      .add(Duration(minutes: (now.minute / 5).round() * 5));
  if (rounded.hour == 0 && rounded.minute == 0) return 'midnight';
  if (rounded.hour == 12 && rounded.minute == 0) return 'noon';

  var hour = rounded.hour;
  var minute = rounded.minute;

  var nextHour = false;
  if (minute > 30) nextHour = true;
  final displayHour =
      _hourWords[(nextHour ? hour + 1 : hour) % 12].toString();

  if (minute == 0) return '$displayHour o\'clock';
  if (minute == 15) return 'quarter past $displayHour';
  if (minute == 30) return 'half past $displayHour';
  if (minute == 45) return 'quarter to $displayHour';

  final List<String> minuteWords = [
    '',
    'five',
    'ten',
    'quarter',
    'twenty',
    'twenty-five',
    'half',
    'twenty-five',
    'twenty',
    'quarter',
    'ten',
    'five',
  ];
  final word = minuteWords[(minute / 5).round()];
  return nextHour ? '$word to $displayHour' : '$word past $displayHour';
}

/// Digits split for the flip cards (“10”, “42”).
(String, String) flipClockParts(DateTime now, ClockHourFormat format) {
  final text = formatClockTime(now, format, true);
  final parts = text.split(':');
  return (parts.first, parts.last);
}

// ---------------------------------------------------------------------------
// The faces.
// ---------------------------------------------------------------------------

/// The big time text in the active style. Used by both the hero zone and
/// the placed clock widget (same engine, same look).
class HeroClockFace extends StatelessWidget {
  const HeroClockFace({
    super.key,
    required this.now,
    required this.style,
    required this.format,
    required this.system24,
    this.size,
    this.color,
  });

  final DateTime now;
  final HeroClockStyle style;
  final ClockHourFormat format;
  final bool system24;

  /// Base font/painter size; the hero passes the token, the placed widget
  /// scales it by span.
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final ink = color ?? palette.ink;
    final effectiveSize = size ?? ToadMetrics.heroClockSize;

    switch (style) {
      case HeroClockStyle.hand:
        return Text(
          formatClockTime(now, format, system24),
          style: ToadType.caveat(effectiveSize, color: ink),
        );
      case HeroClockStyle.word:
        return Text(
          wordClockPhrase(now),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ToadType.caveat(effectiveSize * 0.82, color: ink),
        );
      case HeroClockStyle.analog:
        return AnalogClockFace(
          now: now,
          size: effectiveSize * 1.06,
          ink: ink,
          accent: palette.accentInk,
          paper: palette.surface,
          hairline: palette.hairline,
        );
      case HeroClockStyle.flip:
        return FlipClockFace(
          now: now,
          format: format,
          system24: system24,
          height: effectiveSize * 0.78,
          ink: ink,
          paper: palette.surface,
          hairline: palette.hairline,
        );
    }
  }
}

/// A hand-drawn analog dial — ticks like ink strokes, a toad-accent hour
/// hand, no second hand (the pond is calm; minute precision is the truth).
class AnalogClockFace extends StatelessWidget {
  const AnalogClockFace({
    super.key,
    required this.now,
    required this.size,
    required this.ink,
    required this.accent,
    required this.paper,
    required this.hairline,
  });

  final DateTime now;
  final double size;
  final Color ink;
  final Color accent;
  final Color paper;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AnalogClockPainter(this)),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  _AnalogClockPainter(this.face);

  final AnalogClockFace face;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = canvasSize.center(Offset.zero);
    final radius = canvasSize.shortestSide / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    // Dial: paper disc with a hand-drawn hairline rim (double stroke,
    // slightly offset — the sketchbook wobble).
    paint.color = face.hairline;
    paint.strokeWidth = radius * 0.035;
    canvas.drawCircle(center, radius * 0.96, paint);
    canvas.drawCircle(
      center + Offset(radius * 0.015, radius * 0.02),
      radius * 0.96,
      paint..strokeWidth = radius * 0.015,
    );

    // Ticks: 12 ink strokes; the quarters are longer and heavier.
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 - math.pi / 2;
      final isQuarter = i % 3 == 0;
      final outer = radius * (isQuarter ? 0.80 : 0.84);
      final inner = radius * (isQuarter ? 0.66 : 0.74);
      paint.color = face.ink;
      paint.strokeWidth = radius * (isQuarter ? 0.045 : 0.025);
      paint.strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        paint,
      );
    }

    // Hour hand — the toad accent, short and confident.
    final hourAngle =
        (face.now.hour % 12 + face.now.minute / 60) * math.pi / 6 -
        math.pi / 2;
    paint.color = face.accent;
    paint.strokeWidth = radius * 0.075;
    canvas.drawLine(
      center,
      center + Offset(
        math.cos(hourAngle) * radius * 0.48,
        math.sin(hourAngle) * radius * 0.48,
      ),
      paint,
    );

    // Minute hand — ink, long and light.
    final minuteAngle = face.now.minute * math.pi / 30 - math.pi / 2;
    paint.color = face.ink;
    paint.strokeWidth = radius * 0.04;
    canvas.drawLine(
      center,
      center + Offset(
        math.cos(minuteAngle) * radius * 0.70,
        math.sin(minuteAngle) * radius * 0.70,
      ),
      paint,
    );

    // Center dot.
    canvas.drawCircle(center, radius * 0.05, Paint()..color = face.accent);
  }

  @override
  bool shouldRepaint(_AnalogClockPainter oldDelegate) =>
      oldDelegate.face.now != face.now || oldDelegate.face.ink != face.ink;
}

/// Flip cards — one card per digit pair, paper surfaces, hairline split,
/// calm crossfade+slide when the digits change.
class FlipClockFace extends StatelessWidget {
  const FlipClockFace({
    super.key,
    required this.now,
    required this.format,
    required this.system24,
    required this.height,
    required this.ink,
    required this.paper,
    required this.hairline,
  });

  final DateTime now;
  final ClockHourFormat format;
  final bool system24;
  final double height;
  final Color ink;
  final Color paper;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    final (hours, minutes) = flipClockParts(now, format);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _FlipCard(text: hours, height: height, ink: ink, paper: paper, hairline: hairline),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: height * 0.09),
          child: Text(
            ':',
            style: ToadType.inter(height * 0.62, color: ink, height: 1.1),
          ),
        ),
        _FlipCard(text: minutes, height: height, ink: ink, paper: paper, hairline: hairline),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.text,
    required this.height,
    required this.ink,
    required this.paper,
    required this.hairline,
  });

  final String text;
  final double height;
  final Color ink;
  final Color paper;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: height * 0.78,
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(height * 0.14),
        border: Border.all(color: hairline, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 3),
            blurRadius: 6,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.14),
        child: Stack(
          children: [
            // The flip split across the middle.
            Align(
              alignment: Alignment.center,
              child: Container(height: 1, color: hairline),
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: ToadType.inter(
                    height * 0.52,
                    color: ink,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

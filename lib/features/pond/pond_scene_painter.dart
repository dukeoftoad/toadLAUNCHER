/// Pond scene background painter — sky gradient, sun/moon, clouds/stars,
/// water streaks, glitter path, reeds — plus the ambient loops driven by
/// the shared elapsed clock: ripple idle (4.4 s, 3 concurrent), rising
/// bubbles, night fireflies (7.5 s drift + 2.3 s flicker), the dragonfly
/// flyby (45–90 s patrol · 2.4 s crossing) and the manual rain shower
/// (1.1 s drops, ripple density ×3, sky dim).
///
/// All coordinates are in the 352x786 reference space and scaled to the
/// actual canvas. Ripple amplitude halves at night "so the pond is quieter
/// when you are".
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_tokens.dart';
import 'pond_ambient.dart';

class PondScenePainter extends CustomPainter {
  PondScenePainter({
    required this.palette,
    this.elapsed = Duration.zero,
    this.rain = false,
    ValueListenable<Duration>? clock,
  }) : super(repaint: clock);

  final PondPalette palette;
  final Duration elapsed;
  final bool rain;

  // Reference-space furniture (from the proposal's screen 11 / 12 markup).
  static const _streaksDay = [
    (150.0, 214.0, 120.0, false), // light streak
    (60.0, 252.0, 90.0, true), // dark streak
    (190.0, 530.0, 110.0, false),
    (100.0, 612.0, 130.0, true),
  ];

  static const _streaksNight = [
    (150.0, 214.0, 120.0, false),
    (60.0, 252.0, 90.0, false),
    (190.0, 530.0, 110.0, false),
  ];

  /// (x, y, phase-offset seconds) — from the mockup's animation-delay trio.
  static const _ripplesDay = [
    (100.0, 560.0, 0.0),
    (250.0, 600.0, -2.1),
    (320.0, 545.0, -3.4),
    (70.0, 635.0, -1.2),
  ];
  static const _ripplesNight = [(100.0, 560.0, 0.0), (250.0, 600.0, -2.1)];
  static const _bubbles = [(180.0, 615.0, 0.0), (300.0, 630.0, -2.6)];
  static const _stars = [
    (150.0, 52.0),
    (250.0, 96.0),
    (300.0, 70.0),
    (60.0, 120.0),
    (210.0, 150.0),
    (250.0, 44.0),
  ];
  static const _fireflies = [
    (80.0, 430.0, 0.0),
    (300.0, 470.0, -1.3),
    (240.0, 380.0, -2.6),
    (130.0, 520.0, -3.9),
    (340.0, 410.0, -5.2),
  ];

  /// Rain columns (left %, delay seconds) — the animation board's six.
  static const _rainColumns = [
    (0.10, 0.0),
    (0.24, -0.3),
    (0.40, -0.7),
    (0.55, -0.15),
    (0.70, -0.5),
    (0.86, -0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final kx = size.width / ToadMetrics.referenceScreen.width;
    final ky = size.height / ToadMetrics.referenceScreen.height;
    final k = (kx + ky) / 2;

    // --- Sky gradient -------------------------------------------------------
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: p.skyStops.map(((double, Color) e) => e.$2).toList(),
        stops: p.skyStops.map(((double, Color) e) => e.$1).toList(),
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, skyPaint);

    // --- Sun / moon ---------------------------------------------------------
    if (!p.isNight && p.sun != null) {
      final sunCenter = Offset(281 * kx, 61 * ky); // top 36 · right 46 · 50px
      canvas.drawCircle(
        sunCenter,
        25 * k,
        Paint()
          ..shader = RadialGradient(
            colors: [
              p.sun!,
              p.sunEdge ?? p.sun!,
              (p.sunEdge ?? p.sun!).withValues(alpha: 0),
            ],
            stops: const [0.28, 0.58, 0.71],
          ).createShader(Rect.fromCircle(center: sunCenter, radius: 25 * k)),
      );

      // Clouds — two blurred pills.
      final cloudPaint = Paint()
        ..color = p.cloud ?? const Color(0xD9FFFFFB)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1 * k);
      _pill(canvas, Offset(200 * kx, 55 * ky), 60 * kx, 13 * ky, cloudPaint);
      _pill(canvas, Offset(216 * kx, 76 * ky), 36 * kx, 13 * ky, cloudPaint);
    }

    if (p.isNight && p.moon != null) {
      final moonCenter = Offset(281 * kx, 53 * ky); // top 32 · right 50 · 42px
      final moonRect = Rect.fromCircle(center: moonCenter, radius: 21 * k);
      canvas.drawCircle(
        moonCenter,
        21 * k,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.24, -0.32), // 38% / 34%
            radius: 1.2,
            colors: [p.moon!, p.moonEdge ?? p.moon!, const Color(0xFFD6D0B2)],
            stops: const [0, 0.66, 1],
          ).createShader(moonRect),
      );
      // Glow.
      canvas.drawCircle(
        moonCenter,
        26 * k,
        Paint()
          ..color = const Color(0x66F4F0C8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * k),
      );
      // Craters.
      canvas.drawCircle(
        Offset(273 * kx, 47 * ky),
        4 * k,
        Paint()..color = (p.moonCrater ?? Colors.grey).withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        Offset(288 * kx, 60 * ky),
        3 * k,
        Paint()..color = (p.moonCrater ?? Colors.grey).withValues(alpha: 0.40),
      );

      // Stars.
      final star = Paint()..color = p.star ?? const Color(0xFFF4EFD6);
      for (final (x, y) in _stars) {
        canvas.drawCircle(Offset(x * kx, y * ky), 1.25 * k, star);
      }
    }

    // --- Rain dimming ("sky dims") + drops ----------------------------------
    if (rain) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x2E23443C),
      );
      final drop = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x00C8E4DC), const Color(0xD9C8E4DC)],
        ).createShader(Rect.fromLTWH(0, 0, 2 * kx, 15 * ky));
      final fallSpan = 180 * ky;
      for (final (fx, delay) in _rainColumns) {
        final phase = ((elapsed.inMicroseconds / 1e6 + delay) / 1.1) % 1;
        final x = fx * size.width;
        final y = -18 * ky + phase * fallSpan;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 2 * kx, 15 * ky),
            const Radius.circular(2),
          ),
          drop,
        );
      }
    }

    // --- Water streaks ------------------------------------------------------
    final streaks = p.isNight ? _streaksNight : _streaksDay;
    final streakPaint = Paint()
      ..color = p.streak
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1 * k);
    final streakDarkPaint = Paint()
      ..color = p.streakDark
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1 * k);
    for (final (x, y, w, dark) in streaks) {
      _pill(
        canvas,
        Offset(x * kx, y * ky),
        w * kx,
        3 * ky,
        dark ? streakDarkPaint : streakPaint,
      );
    }

    // --- Glitter path -------------------------------------------------------
    // Vertical strip right 60 · top 196 → bottom 130 · width 54.
    const glitterX = 352.0 - 60 - 54;
    const glitterTop = 196.0;
    const glitterBottom = 786.0 - 130;
    const dashH = 4.0;
    const gap = 13.0;
    var gy = glitterTop;
    var i = 0;
    final shimmer =
        0.75 +
        0.25 * math.sin((elapsed.inMicroseconds / 1e6) * 2 * math.pi / 3);
    while (gy < glitterBottom) {
      final fade = 1.0 - ((gy - glitterTop) / (glitterBottom - glitterTop));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(glitterX * kx, gy * ky, 54 * kx, dashH * ky),
          const Radius.circular(3),
        ),
        Paint()
          ..color = p.glitter.withValues(
            alpha:
                p.glitter.a *
                (0.35 + 0.65 * fade) *
                (i % 2 == 0 ? 1 : 0.6) *
                shimmer,
          ),
      );
      gy += gap;
      i++;
    }

    // --- Ripple idle — 4.4 s loop, expanding strokes ------------------------
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..color = p.rippleRing;
    final positions = p.isNight
        ? _ripplesNight
        : (rain ? _rippleRainField : _ripplesDay);
    final amp = p.isNight ? 0.5 : 1.0; // halved at night
    final t = elapsed.inMicroseconds / 1e6;
    for (final (x, y, delay) in positions) {
      final phase = ((t + delay) / 4.4) % 1;
      // scale .35 → 6.2 ease-out · opacity .9 → .3 (70%) → 0.
      final eased = 1 - math.pow(1 - phase, 2).toDouble();
      final radius = 14 * k * (0.35 + (6.2 - 0.35) * eased * 0.55 * amp);
      final opacity = phase < 0.7
          ? 0.9 - (0.9 - 0.3) * phase / 0.7
          : 0.3 * (1 - (phase - 0.7) / 0.3);
      canvas.drawCircle(
        Offset(x * kx, y * ky),
        radius,
        ring..color = p.rippleRing.withValues(alpha: p.rippleRing.a * opacity),
      );
    }

    // --- Bubbles — 6 s rise, 90 px ------------------------------------------
    if (!p.isNight) {
      final bubble = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * k
        ..color = p.streak;
      for (final (x, y, delay) in _bubbles) {
        final phase = ((t + delay) / 6.0) % 1;
        final rise = phase * 90 * ky;
        final opacity = phase < 0.15
            ? phase / 0.15 * 0.8
            : 0.8 * (1 - (phase - 0.15) / 0.85);
        canvas.drawCircle(
          Offset(x * kx + math.sin(phase * 6) * 3 * kx, y * ky - rise),
          3 * k,
          bubble..color = p.streak.withValues(alpha: p.streak.a * opacity),
        );
      }
    }

    // --- Fireflies (night) — 7.5 s drift + 2.3 s flicker --------------------
    if (p.isNight) {
      for (final (x, y, delay) in _fireflies) {
        final dt = t + delay;
        // drift: (16,-12) at 30% · (-12,-5) at 62%, ease-in-out 7.5 s.
        final dp = (dt / 7.5) % 1;
        final drift = _driftOffset(dp);
        // flicker: .95 → .12 (45%) → .8 (70%), 2.3 s linear.
        final fp = (dt / 2.3) % 1;
        final flick = _flickerAlpha(fp);
        final cx = (x + drift.dx) * kx;
        final cy = (y + drift.dy) * ky;
        canvas.drawCircle(
          Offset(cx, cy),
          3 * k,
          Paint()
            ..color = p.firefly.withValues(alpha: p.firefly.a * flick)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          2.2 * k,
          Paint()..color = p.firefly.withValues(alpha: p.firefly.a * flick),
        );
      }
    }

    // --- Flyby — dragonfly crossing every 45–90 s, 2.4 s --------------------
    final fly = flybyProgressAt(elapsed);
    if (fly != null) {
      _paintDragonfly(canvas, fly, kx, ky, p);
    }

    // --- Reeds (sway ±1.7°/1.9°, 5.6 s, bottom origin) ----------------------
    final sway = math.sin((t / 5.6) * 2 * math.pi);
    canvas.save();
    _paintReeds(
      canvas,
      kx,
      ky,
      p,
      swayLeft: sway * -1.7,
      swayRight: sway * 1.9,
    );
    canvas.restore();
  }

  static const _rippleRainField = [
    (100.0, 560.0, 0.0),
    (250.0, 600.0, -2.1),
    (320.0, 545.0, -3.4),
    (70.0, 635.0, -1.2),
    (180.0, 520.0, -0.8),
    (290.0, 655.0, -2.9),
    (40.0, 500.0, -3.7),
    (200.0, 660.0, -0.4),
    (140.0, 585.0, -1.9),
    (330.0, 610.0, -4.1),
    (60.0, 570.0, -2.4),
    (260.0, 540.0, -0.6),
  ];

  /// drift keyframes (0,0) → (16,-12)@30% → (-12,-5)@62% → (0,0).
  Offset _driftOffset(double phase) {
    Offset lerpTo(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    if (phase < 0.30) {
      return lerpTo(
        Offset.zero,
        const Offset(16, -12),
        Curves.easeInOut.transform(phase / 0.30),
      );
    }
    if (phase < 0.62) {
      return lerpTo(
        const Offset(16, -12),
        const Offset(-12, -5),
        Curves.easeInOut.transform((phase - 0.30) / 0.32),
      );
    }
    return lerpTo(
      const Offset(-12, -5),
      Offset.zero,
      Curves.easeInOut.transform((phase - 0.62) / 0.38),
    );
  }

  /// flicker keyframes: .95 → .12 (45%) → .8 (70%) → .95.
  double _flickerAlpha(double phase) {
    if (phase < 0.45) return 0.95 + (0.12 - 0.95) * (phase / 0.45);
    if (phase < 0.70) return 0.12 + (0.8 - 0.12) * ((phase - 0.45) / 0.25);
    return 0.8 + (0.95 - 0.8) * ((phase - 0.70) / 0.30);
  }

  /// The dragonfly sprite — wings, body, head — on the board's keyframe
  /// path, normalized into the 2.4 s crossing, with a hover pause over a
  /// pad around mid-crossing.
  void _paintDragonfly(
    Canvas canvas,
    double progress,
    double kx,
    double ky,
    PondPalette p,
  ) {
    final eased = Curves.linear.transform(progress);
    // Hover pause: slow down 45–65% of the way.
    double t = eased;
    if (t > 0.45 && t < 0.65) {
      t = 0.45 + (t - 0.45) * 0.35;
    } else if (t >= 0.65) {
      t = 0.52 + (t - 0.65) * 1.0;
    }

    const keys = <(double, double, double)>[
      (-56.0, 0.0, 0.0),
      (120.0, -16.0, 0.28),
      (214.0, 8.0, 0.52),
      (300.0, -12.0, 0.78),
      (428.0, 4.0, 1.0),
    ];
    var (x, y, _) = keys.last;
    for (var i = 0; i < keys.length - 1; i++) {
      final (x0, y0, t0) = keys[i];
      final (x1, y1, t1) = keys[i + 1];
      if (t >= t0 && t <= t1) {
        final f = (t - t0) / (t1 - t0);
        x = x0 + (x1 - x0) * f;
        y = y0 + (y1 - y0) * f;
        break;
      }
    }
    // The crossing spans the 352-wide reference; wrap around the right edge.
    final cx = ((x + 56) % 460) * kx;
    final cy = (236 + y) * ky;

    final wing = Paint()..color = const Color(0xCCE8F4F0);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.08 + math.sin(progress * 22) * 0.06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-6 * kx, -4 * ky),
        width: 20 * kx,
        height: 5 * ky,
      ),
      wing,
    );
    canvas.save();
    canvas.rotate(0.26);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-4 * kx, 4 * ky),
        width: 18 * kx,
        height: 4.6 * ky,
      ),
      Paint()..color = const Color(0xA6E8F4F0),
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2 * kx, -1.7 * ky, 16 * kx, 3.4 * ky),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF4E7A8C),
    );
    canvas.drawCircle(
      Offset(15 * kx, 0.2 * ky),
      3 * kx,
      Paint()..color = const Color(0xFF39596B),
    );
    canvas.restore();
  }

  void _pill(Canvas canvas, Offset center, double w, double h, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: h),
        Radius.circular((w + h) / 4),
      ),
      paint,
    );
  }

  void _paintReeds(
    Canvas canvas,
    double kx,
    double ky,
    PondPalette p, {
    required double swayLeft,
    required double swayRight,
  }) {
    final refH = ToadMetrics.referenceScreen.height;

    void clump({
      required double x0,
      required double yTop,
      required double scaleW,
      required double scaleH,
      required double swayDeg,
      required List<(String, double)> stems,
      required List<(double, double, double, double, Color)> heads,
    }) {
      double sx(double v) => x0 + v * scaleW;
      double sy(double v) => yTop + v * scaleH;

      canvas.save();
      canvas.translate(sx(35), sy(120));
      canvas.rotate(swayDeg * math.pi / 180);
      canvas.translate(-sx(35), -sy(120));

      final stem = Paint()
        ..color = p.reedStem
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final (d, width) in stems) {
        stem.strokeWidth = width * kx;
        canvas.drawPath(_bezier(d, sx, sy), stem);
      }
      for (final (cx, cy, w, h, color) in heads) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(sx(cx), sy(cy)),
            width: w * kx,
            height: h * ky,
          ),
          Paint()..color = color,
        );
      }
      canvas.restore();
    }

    // Left clump — rendered 64x112, left 6, bottom edge 100 above bottom.
    clump(
      x0: 6 * kx,
      yTop: (refH - 100 - 112) * ky,
      scaleW: 64 / 70,
      scaleH: 112 / 120,
      swayDeg: swayLeft,
      stems: const [
        ('M14 120 C12 80 16 56 14 30', 3.0),
        ('M34 120 C36 86 30 66 34 44', 2.6),
        ('M54 120 C50 92 58 72 54 54', 2.4),
      ],
      heads: [
        (14.0, 24.0, 10.0, 28.0, p.reedHead),
        (34.0, 38.0, 9.0, 24.0, p.reedHead2),
      ],
    );

    // Right clump — rendered 56x96, right 6, bottom edge 100 above bottom.
    clump(
      x0: (ToadMetrics.referenceScreen.width - 6 - 56) * kx,
      yTop: (refH - 100 - 96) * ky,
      scaleW: 56 / 70,
      scaleH: 96 / 120,
      swayDeg: swayRight,
      stems: const [
        ('M20 120 C18 84 22 62 20 38', 2.8),
        ('M44 120 C46 92 40 70 44 52', 2.4),
      ],
      heads: [(20.0, 32.0, 9.2, 26.0, p.reedHead2)],
    );
  }

  /// Parses the proposal's simple `M x y C ...` reed stems.
  Path _bezier(
    String d,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    final path = Path();
    final nums = RegExp(r'-?\d+\.?\d*')
        .allMatches(d)
        .map((m) => double.parse(m.group(0)!))
        .toList();
    if (nums.length >= 8) {
      path.moveTo(sx(nums[0]), sy(nums[1]));
      path.cubicTo(
        sx(nums[2]),
        sy(nums[3]),
        sx(nums[4]),
        sy(nums[5]),
        sx(nums[6]),
        sy(nums[7]),
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(PondScenePainter oldDelegate) =>
      oldDelegate.palette.isNight != palette.isNight ||
      oldDelegate.rain != rain ||
      oldDelegate.elapsed != elapsed;
}

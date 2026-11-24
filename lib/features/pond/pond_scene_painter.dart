/// Pond scene background painter — sky gradient, sun/moon, clouds/stars,
/// water streaks, glitter path, static ripples & bubbles, reeds.
///
/// All coordinates are in the 352x786 reference space and scaled to the
/// actual canvas. Ambient animation (ripple/bubble/firefly loops) arrives
/// in stage 4; this painter draws the still scene.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_tokens.dart';

class PondScenePainter extends CustomPainter {
  PondScenePainter({required this.palette});

  final PondPalette palette;

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

  static const _ripplesDay = [
    (100.0, 560.0), (250.0, 600.0), (320.0, 545.0), (70.0, 635.0),
  ];
  static const _ripplesNight = [(100.0, 560.0), (250.0, 600.0)];
  static const _bubbles = [(180.0, 615.0), (300.0, 630.0)];
  static const _stars = [
    (150.0, 52.0), (250.0, 96.0), (300.0, 70.0),
    (60.0, 120.0), (210.0, 150.0), (250.0, 44.0),
  ];
  static const _fireflies = [
    (80.0, 430.0), (300.0, 470.0), (240.0, 380.0),
    (130.0, 520.0), (340.0, 410.0),
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
        Paint()
          ..color = (p.moonCrater ?? Colors.grey).withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        Offset(288 * kx, 60 * ky),
        3 * k,
        Paint()
          ..color = (p.moonCrater ?? Colors.grey).withValues(alpha: 0.40),
      );

      // Stars.
      final star = Paint()..color = p.star ?? const Color(0xFFF4EFD6);
      for (final (x, y) in _stars) {
        canvas.drawCircle(Offset(x * kx, y * ky), 1.25 * k, star);
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
    while (gy < glitterBottom) {
      final fade = 1.0 - ((gy - glitterTop) / (glitterBottom - glitterTop));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(glitterX * kx, gy * ky, 54 * kx, dashH * ky),
          const Radius.circular(3),
        ),
        Paint()
          ..color = p.glitter.withValues(
            alpha: p.glitter.a * (0.35 + 0.65 * fade) * (i % 2 == 0 ? 1 : 0.6),
          ),
      );
      gy += gap;
      i++;
    }

    // --- Static ripple rings ------------------------------------------------
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..color = p.rippleRing;
    for (final (x, y) in (p.isNight ? _ripplesNight : _ripplesDay)) {
      canvas.drawCircle(Offset(x * kx, y * ky), 14 * k, ripple);
    }

    // --- Bubbles ------------------------------------------------------------
    if (!p.isNight) {
      final bubble = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * k
        ..color = p.streak;
      for (final (x, y) in _bubbles) {
        canvas.drawCircle(Offset(x * kx, y * ky), 3 * k, bubble);
      }
    }

    // --- Fireflies (night, static positions — drift arrives in stage 4) -----
    if (p.isNight) {
      for (final (x, y) in _fireflies) {
        canvas.drawCircle(
          Offset(x * kx, y * ky),
          3 * k,
          Paint()
            ..color = p.firefly
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k),
        );
        canvas.drawCircle(
          Offset(x * kx, y * ky),
          3 * k,
          Paint()..color = p.firefly,
        );
      }
    }

    // --- Reeds --------------------------------------------------------------
    _paintReeds(canvas, kx, ky, p);
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

  void _paintReeds(Canvas canvas, double kx, double ky, PondPalette p) {
    final refH = ToadMetrics.referenceScreen.height;

    // Left clump — rendered 64x112, left 6, bottom edge 100 above bottom.
    final lx0 = 6 * kx;
    final lyTop = (refH - 100 - 112) * ky;
    double lx(double v) => lx0 + v * (64 / 70);
    double ly(double v) => lyTop + v * (112 / 120);

    final stem = Paint()
      ..color = p.reedStem
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Left stems.
    stem.strokeWidth = 3.0 * kx;
    canvas.drawPath(_bezier('M14 120 C12 80 16 56 14 30', lx, ly), stem);
    stem.strokeWidth = 2.6 * kx;
    canvas.drawPath(_bezier('M34 120 C36 86 30 66 34 44', lx, ly), stem);
    stem.strokeWidth = 2.4 * kx;
    canvas.drawPath(_bezier('M54 120 C50 92 58 72 54 54', lx, ly), stem);

    // Left cattail heads.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(lx(14), ly(24)),
        width: 10 * kx,
        height: 28 * ky,
      ),
      Paint()..color = p.reedHead,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(lx(34), ly(38)),
        width: 9 * kx,
        height: 24 * ky,
      ),
      Paint()..color = p.reedHead2,
    );

    // Right clump — rendered 56x96, right 6, bottom edge 100 above bottom.
    final rx0 = (ToadMetrics.referenceScreen.width - 6 - 56) * kx;
    final ryTop = (refH - 100 - 96) * ky;
    double rx(double v) => rx0 + v * (56 / 70);
    double ry(double v) => ryTop + v * (96 / 120);

    stem.strokeWidth = 2.8 * kx;
    canvas.drawPath(_bezier('M20 120 C18 84 22 62 20 38', rx, ry), stem);
    stem.strokeWidth = 2.4 * kx;
    canvas.drawPath(_bezier('M44 120 C46 92 40 70 44 52', rx, ry), stem);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rx(20), ry(32)),
        width: 9.2 * kx,
        height: 26 * ky,
      ),
      Paint()..color = p.reedHead2,
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
        sx(nums[2]), sy(nums[3]),
        sx(nums[4]), sy(nums[5]),
        sx(nums[6]), sy(nums[7]),
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(PondScenePainter oldDelegate) =>
      oldDelegate.palette.isNight != palette.isNight;
}

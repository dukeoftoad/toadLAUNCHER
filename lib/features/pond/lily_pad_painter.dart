/// Lily pad painter — exact geometry from the proposal's `padD`/`padN` SVG
/// symbols (viewBox 0 0 120 84).
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_tokens.dart';

class LilyPadPainter extends CustomPainter {
  LilyPadPainter({required this.palette});

  final PondPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 84;

    // Pad body: M114.5 28.3 A58 40 0 1 0 114.5 55.7 L78 42 Z
    final pad = Path()
      ..moveTo(114.5 * sx, 28.3 * sy)
      ..arcToPoint(
        Offset(114.5 * sx, 55.7 * sy),
        radius: Radius.elliptical(58 * sx, 40 * sy),
        largeArc: true,
        clockwise: false,
      )
      ..lineTo(78 * sx, 42 * sy)
      ..close();

    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4), // 35% / 30%
        radius: 1.35,
        colors: palette.padFill.map(((double, Color) e) => e.$2).toList(),
        stops: palette.padFill.map(((double, Color) e) => e.$1).toList(),
      ).createShader(rect);

    canvas.drawPath(pad, paint);

    // Veins: five spokes from the notch hub.
    final vein = Paint()
      ..color = palette.padVein.withValues(alpha: palette.padVeinOpacity)
      ..strokeWidth = 1.4 * (sx + sy) / 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const hubs = [
      Offset(44, 14),
      Offset(26, 42),
      Offset(54, 74),
      Offset(100, 72),
      Offset(98, 18),
    ];
    for (final hub in hubs) {
      canvas.drawLine(
        Offset(78 * sx, 42 * sy),
        Offset(hub.dx * sx, hub.dy * sy),
        vein,
      );
    }
  }

  @override
  bool shouldRepaint(LilyPadPainter oldDelegate) =>
      oldDelegate.palette.padFill != palette.padFill;
}

/// Static pad shadow — the soft dark pool under each pad.
class PadShadowPainter extends CustomPainter {
  PadShadowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.72),
        width: size.width * 0.86,
        height: size.height * 0.5,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(PadShadowPainter oldDelegate) =>
      oldDelegate.color != color;
}

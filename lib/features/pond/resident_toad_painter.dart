library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_tokens.dart';

class ResidentToadPainter extends CustomPainter {
  ResidentToadPainter({
    required this.palette,
    this.blinking = false,
    this.croak = 0,
    this.awake = false,
    this.grumpy = false,
  });

  final PondPalette palette;

  final bool blinking;

  final double croak;

  final bool awake;

  final bool grumpy;

  static double throatScale(double t) {
    if (t <= 0 || t >= 1) return 1;
    if (t < 0.45) return 1 + (1.9 - 1) * (t / 0.45);
    if (t < 0.55) return 1.9 + (0.75 - 1.9) * ((t - 0.45) / 0.10);
    if (t < 0.75) return 0.75 + (1.45 - 0.75) * ((t - 0.55) / 0.20);
    return 1.45 + (1 - 1.45) * ((t - 0.75) / 0.25);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 80;
    final p = palette;
    final nightAsleep = p.isNight && !awake;

    final fill = Paint();

    fill.color = p.toadFeet;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(26 * sx, 66 * sy),
        width: 30 * sx,
        height: 14 * sy,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(94 * sx, 66 * sy),
        width: 30 * sx,
        height: 14 * sy,
      ),
      fill,
    );

    final body = Path()
      ..moveTo(16 * sx, 56 * sy)
      ..cubicTo(12 * sx, 30 * sy, 34 * sx, 16 * sy, 60 * sx, 16 * sy)
      ..cubicTo(86 * sx, 16 * sy, 108 * sx, 30 * sy, 104 * sx, 56 * sy)
      ..cubicTo(102 * sx, 66 * sy, 92 * sx, 72 * sy, 60 * sx, 72 * sy)
      ..cubicTo(28 * sx, 72 * sy, 18 * sx, 66 * sy, 16 * sx, 56 * sy)
      ..close();
    fill.color = p.toadBody;
    canvas.drawPath(body, fill);

    fill.color = p.toadBelly;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(60 * sx, 57 * sy),
        width: 66 * sx,
        height: 26 * sy,
      ),
      fill,
    );

    fill.color = p.toadBody;
    canvas.drawCircle(Offset(37 * sx, 19 * sy), 13 * sx, fill);
    canvas.drawCircle(Offset(83 * sx, 19 * sy), 13 * sx, fill);

    final eyesShut = nightAsleep || blinking;
    if (eyesShut) {
      final lid = Paint()
        ..color = p.toadDetail
        ..strokeWidth = 2.4 * sx
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final left = Path()
        ..moveTo(29 * sx, 18 * sy)
        ..quadraticBezierTo(37 * sx, 25 * sy, 45 * sx, 18 * sy);
      final right = Path()
        ..moveTo(75 * sx, 18 * sy)
        ..quadraticBezierTo(83 * sx, 25 * sy, 91 * sx, 18 * sy);
      canvas.drawPath(left, lid);
      canvas.drawPath(right, lid);
    } else {
      fill.color = p.toadEye;
      canvas.drawCircle(Offset(37 * sx, 18 * sy), 8.5 * sx, fill);
      canvas.drawCircle(Offset(83 * sx, 18 * sy), 8.5 * sx, fill);

      fill.color = p.toadPupil;
      canvas.drawCircle(Offset(38 * sx, 19 * sy), 4 * sx, fill);
      canvas.drawCircle(Offset(84 * sx, 19 * sy), 4 * sx, fill);

      fill.color = Colors.white;
      canvas.drawCircle(Offset(36 * sx, 16.5 * sy), 1.6 * sx, fill);
      canvas.drawCircle(Offset(82 * sx, 16.5 * sy), 1.6 * sx, fill);
    }

    fill.color = p.toadDetail;
    canvas.drawCircle(Offset(54 * sx, 30 * sy), 1.5 * sx, fill);
    canvas.drawCircle(Offset(66 * sx, 30 * sy), 1.5 * sx, fill);

    canvas.drawCircle(
      Offset(28 * sx, 38 * sy),
      4 * sx,
      Paint()..color = p.toadSpot.withValues(alpha: 0.65),
    );
    canvas.drawCircle(
      Offset(88 * sx, 36 * sy),
      3.4 * sx,
      Paint()..color = p.toadSpot.withValues(alpha: 0.65),
    );
    if (!p.isNight) {
      canvas.drawCircle(
        Offset(74 * sx, 26 * sy),
        2.6 * sx,
        Paint()..color = p.toadSpot.withValues(alpha: 0.5),
      );
    }

    final mouth = Paint()
      ..color = p.toadDetail
      ..strokeWidth = 2 * sx
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mouthPath = grumpy
        ? (Path()
            ..moveTo(40 * sx, 45 * sy)
            ..quadraticBezierTo(60 * sx, 44 * sy, 80 * sx, 45 * sy))
        : (Path()
            ..moveTo(38 * sx, 42 * sy)
            ..quadraticBezierTo(60 * sx, 50 * sy, 82 * sx, 42 * sy));
    canvas.drawPath(mouthPath, mouth);

    final throatVisible = !nightAsleep;
    if (throatVisible) {
      final scale = throatScale(croak);
      canvas.save();
      canvas.translate(60 * sx, 63 * sy);
      canvas.scale(1, scale);
      fill
        ..color = p.toadThroat
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 30 * sx, height: 13 * sy),
        fill,
      );
      canvas.restore();

      if (croak > 0.55 && croak < 1) {
        final noteT = (croak - 0.55) / 0.45;
        final opacity = noteT < 0.3 ? noteT / 0.3 : 1 - (noteT - 0.3) / 0.7;
        _paintNote(
          canvas,
          Offset(96 * sx, (46 - 30 * noteT) * sy),
          22 * sx,
          const Color(0xFFFFF3C4).withValues(alpha: opacity.clamp(0, 1)),
          sx,
          sy,
        );
      }
    }
  }

  void _paintNote(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double sx,
    double sy,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * sx
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy + 8 * sy),
      Offset(center.dx, center.dy - 8 * sy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8 * sy),
      Offset(center.dx + 8 * sx, center.dy - 5 * sy),
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx - 2.4 * sx, center.dy + 7.4 * sy),
      3.4 * sx,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(ResidentToadPainter oldDelegate) =>
      oldDelegate.palette.isNight != palette.isNight ||
      oldDelegate.blinking != blinking ||
      oldDelegate.croak != croak ||
      oldDelegate.awake != awake ||
      oldDelegate.grumpy != grumpy;
}

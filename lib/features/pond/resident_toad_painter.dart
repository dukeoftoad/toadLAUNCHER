/// The resident toad — exact geometry from the proposal's SVG
/// (viewBox 0 0 120 80). Day awake with open eyes; night asleep with
/// curved-lid strokes. Blink and croak animation hooks arrive in stage 4.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_tokens.dart';

class ResidentToadPainter extends CustomPainter {
  ResidentToadPainter({required this.palette});

  final PondPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 80;
    final p = palette;

    final fill = Paint();

    // Feet.
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

    // Body: M16 56 C12 30 34 16 60 16 C86 16 108 30 104 56
    //       C102 66 92 72 60 72 C28 72 18 66 16 56 Z
    final body = Path()
      ..moveTo(16 * sx, 56 * sy)
      ..cubicTo(12 * sx, 30 * sy, 34 * sx, 16 * sy, 60 * sx, 16 * sy)
      ..cubicTo(86 * sx, 16 * sy, 108 * sx, 30 * sy, 104 * sx, 56 * sy)
      ..cubicTo(102 * sx, 66 * sy, 92 * sx, 72 * sy, 60 * sx, 72 * sy)
      ..cubicTo(28 * sx, 72 * sy, 18 * sx, 66 * sy, 16 * sx, 56 * sy)
      ..close();
    fill.color = p.toadBody;
    canvas.drawPath(body, fill);

    // Belly.
    fill.color = p.toadBelly;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(60 * sx, 57 * sy),
        width: 66 * sx,
        height: 26 * sy,
      ),
      fill,
    );

    // Eye bumps.
    fill.color = p.toadBody;
    canvas.drawCircle(Offset(37 * sx, 19 * sy), 13 * sx, fill);
    canvas.drawCircle(Offset(83 * sx, 19 * sy), 13 * sx, fill);

    if (p.isNight) {
      // Asleep: curved closed lids instead of eyeballs.
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
      // Awake: eyeballs, pupils, shines.
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

    // Nostrils.
    fill.color = p.toadDetail;
    canvas.drawCircle(Offset(54 * sx, 30 * sy), 1.5 * sx, fill);
    canvas.drawCircle(Offset(66 * sx, 30 * sy), 1.5 * sx, fill);

    // Spots.
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

    // Smile: M38 42 Q60 50 82 42.
    final smile = Paint()
      ..color = p.toadDetail
      ..strokeWidth = 2 * sx
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(38 * sx, 42 * sy)
      ..quadraticBezierTo(60 * sx, 50 * sy, 82 * sx, 42 * sy);
    canvas.drawPath(smilePath, smile);

    // Throat (day only; croak animation arrives in stage 4).
    if (!p.isNight) {
      fill
        ..color = p.toadThroat
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(60 * sx, 63 * sy),
          width: 30 * sx,
          height: 13 * sy,
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(ResidentToadPainter oldDelegate) =>
      oldDelegate.palette.isNight != palette.isNight;
}

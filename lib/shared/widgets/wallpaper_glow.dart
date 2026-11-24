/// Sketchbook wallpaper glow — the three radial washes behind every
/// sketchbook skin (Light / Dark / AMOLED), per proposal section 2.
///
/// Light:  rgba(122,166,84,.16) @ 88%/6%  (140x110)
///         rgba(201,162,39,.10) @ 8%/40%  (200x160)
///         rgba(79,122,56,.14)  @ 90%/92% (220x220)
/// Dark:   rgba(147,196,109,.10) @ 88%/8%  · gold .06 @ 6%/60% · .10 @ 92%/94%
/// AMOLED: rgba(147,196,109,.09) @ 88%/8%  · .08 @ 92%/94%
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

class WallpaperGlow extends StatelessWidget {
  const WallpaperGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = ToadTheme.of(context);
    return CustomPaint(
      foregroundPainter: WallpaperGlowPainter(data: data),
      child: child,
    );
  }
}

class WallpaperGlowPainter extends CustomPainter {
  WallpaperGlowPainter({required this.data});

  final ToadSkinData data;

  @override
  void paint(Canvas canvas, Size size) {
    final s = data.skin;
    if (s == ResolvedSkin.pondDay || s == ResolvedSkin.pondNight) {
      return; // Pond replaces glow with scene lighting.
    }

    // Reference surface scaling.
    final k = size.width / ToadMetrics.referenceScreen.width;
    final strength = data.palette.wallpaperGlowStrength;

    void radial({
      required Alignment center,
      required double rx,
      required double ry,
      required Color color,
    }) {
      final c = center.withinRect(Offset.zero & size);
      final rect = Rect.fromCenter(
        center: c,
        width: rx * 2 * k,
        height: ry * 2 * k,
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: color.a * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    if (s == ResolvedSkin.light) {
      radial(
        center: const Alignment(0.76, -0.88),
        rx: 140,
        ry: 110,
        color: const Color(0xFF7AA654).withValues(alpha: 0.16),
      );
      radial(
        center: const Alignment(-0.84, -0.20),
        rx: 200,
        ry: 160,
        color: const Color(0xFFC9A227).withValues(alpha: 0.10),
      );
      radial(
        center: const Alignment(0.80, 0.84),
        rx: 220,
        ry: 220,
        color: const Color(0xFF4F7A38).withValues(alpha: 0.14),
      );
    } else if (s == ResolvedSkin.dark) {
      radial(
        center: const Alignment(0.76, -0.84),
        rx: 150,
        ry: 120,
        color: const Color(0xFF93C46D).withValues(alpha: 0.10),
      );
      radial(
        center: const Alignment(-0.88, 0.20),
        rx: 230,
        ry: 200,
        color: const Color(0xFFC9A227).withValues(alpha: 0.06),
      );
      radial(
        center: const Alignment(0.84, 0.88),
        rx: 240,
        ry: 200,
        color: const Color(0xFF93C46D).withValues(alpha: 0.10),
      );
    } else {
      // AMOLED.
      radial(
        center: const Alignment(0.76, -0.84),
        rx: 150,
        ry: 120,
        color: const Color(0xFF93C46D).withValues(alpha: 0.09),
      );
      radial(
        center: const Alignment(0.84, 0.88),
        rx: 240,
        ry: 200,
        color: const Color(0xFF93C46D).withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(WallpaperGlowPainter oldDelegate) =>
      oldDelegate.data.skin != data.skin ||
      oldDelegate.data.palette.paper != data.palette.paper;
}

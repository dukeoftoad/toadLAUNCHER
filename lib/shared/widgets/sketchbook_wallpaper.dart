/// Bundled sketchbook wallpaper — the chosen paper painted under the glow.
///
/// "Everything here is offline; wallpapers ship inside the APK (~2 MB) to
/// honor the no-network promise." The bundled papers are soft sketchbook
/// gradients blended over the skin's paper; Pond Pro replaces the whole
/// underlay with the scene.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

class SketchbookWallpaper extends StatelessWidget {
  const SketchbookWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = ToadTheme.of(context);
    if (data.skin.isPond) return child; // the scene owns the stage

    final palette = data.palette;
    final index = WallpaperIndexScope.of(context);

    return CustomPaint(
      painter: _PaperPainter(paper: palette.paper, index: index),
      child: child,
    );
  }
}

/// Paints the chosen bundled paper as a full-bleed 145° gradient wash over
/// the skin paper.
class _PaperPainter extends CustomPainter {
  _PaperPainter({required this.paper, required this.index});

  final Color paper;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    // Paper base first — never transparent (AMOLED keeps true black).
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);

    final papers = AppIconGradients.wallpapers;
    final colors = papers[index.clamp(0, papers.length - 1)];
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: colors.first.a * 0.30),
            colors[colors.length > 2 ? 1 : 0].withValues(
              alpha: colors[1].a * 0.16,
            ),
            colors.last.withValues(alpha: colors.last.a * 0.34),
          ],
          stops: const [0.0, 0.55, 1.0],
          transform: const GradientRotation(145 * 3.14159 / 180),
        ).createShader(rect),
    );

    // Soft top wash so the hero text keeps its sketchbook calm.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            paper.withValues(alpha: paper.a * 0.55),
            paper.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.paper != paper;
}

/// Carries the settings wallpaper index down to the underlay without
/// rebuilding every ToadTheme consumer.
class WallpaperIndexScope extends InheritedWidget {
  const WallpaperIndexScope({
    super.key,
    required this.index,
    required super.child,
  });

  final int index;

  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WallpaperIndexScope>()
          ?.index ??
      0;

  @override
  bool updateShouldNotify(WallpaperIndexScope oldWidget) =>
      oldWidget.index != index;
}

library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/device_bridge.dart' show notificationCountsProvider;
import '../../core/models/models.dart';
import '../../core/repositories/device_app_repository.dart';
import '../../core/theme/toad_tokens.dart';
import '../../core/theme/toad_theme.dart';
import '../../features/focus/focus_controller.dart'
    show focusAwareSettingsProvider;

class ToadAppIcon extends ConsumerWidget {
  const ToadAppIcon({
    super.key,
    required this.app,
    this.size = ToadMetrics.gridIconSize,
    this.radius = ToadRadii.iconTile,
    this.glyphSize = ToadMetrics.gridGlyphSize,
    this.shape = IconShape.squircle,
  });

  final AppEntry app;
  final double size;
  final double radius;
  final double glyphSize;
  final IconShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double effectiveRadius = switch (shape) {
      IconShape.squircle => radius,
      IconShape.circle => size / 2,
      IconShape.rounded => size * 0.38,
    };

    final settings = ref.watch(focusAwareSettingsProvider);
    final realIcon = app.packageName == null
        ? null
        : ref.watch(deviceIconsProvider)[app.packageName!];
    final monoIcon = settings.themedIcons && app.packageName != null
        ? ref.watch(deviceIconsMonoProvider)[app.packageName!]
        : null;

    final gradient = app.isFamilyToad && realIcon == null
        ? AppIconGradients.toad
        : AppIconGradients.all[app.gradientIndex % AppIconGradients.all.length];

    final count = settings.notificationDots && app.packageName != null
        ? (ref.watch(notificationCountsProvider)[app.packageName!] ?? 0)
        : 0;

    final Widget tile = monoIcon != null
        ? _ThemedMonoIcon(
            bytes: monoIcon,
            size: size,
            radius: effectiveRadius,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(effectiveRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
                transform: const GradientRotation(145 * 3.14159 / 180),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47000000),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Center(
              child: realIcon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(effectiveRadius),
                      child: Image.memory(
                        realIcon,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : app.isFamilyToad
                  ? CustomPaint(
                      size: Size.square(size * 0.5),
                      painter: ToadFacePainter(),
                    )
                  : Text(
                      app.glyph,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: glyphSize,
                        height: 1,
                        color: Colors.white,
                        fontFamily: ToadType.fontHand,
                      ),
                    ),
            ),
          );

    if (count <= 0) return tile;

    final palette = ToadTheme.of(context).palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 15,
              minHeight: 15,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: palette.accent,
              shape: settings.badges ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: settings.badges
                  ? BorderRadius.circular(999)
                  : null,
              border: Border.all(
                color: palette.paper,
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: settings.badges
                ? Text(
                    count > 99 ? '99+' : '$count',
                    style: ToadType.inter(
                      8.5,
                      weight: 700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _ThemedMonoIcon extends ConsumerWidget {
  const _ThemedMonoIcon({
    required this.bytes,
    required this.size,
    required this.radius,
  });

  final Uint8List bytes;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ToadTheme.of(context).palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.surface.a * 0.9),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: palette.hairline.withValues(alpha: palette.hairline.a * 0.9),
        ),
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(<double>[
          0, 0, 0, 0, palette.ink.r * 255,
          0, 0, 0, 0, palette.ink.g * 255,
          0, 0, 0, 0, palette.ink.b * 255,
          0, 0, 0, 1, 0,
        ]),
        child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }
}

class ToadFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26;
    final sy = size.height / 26;

    const paper = Color(0xFFF7F1E6);
    const inkDot = Color(0xFF2B2924);
    final paint = Paint()..color = paper;

    canvas.drawCircle(Offset(8.2 * sx, 7.6 * sy), 3.5 * sx, paint);
    canvas.drawCircle(Offset(17.8 * sx, 7.6 * sy), 3.5 * sx, paint);

    paint.color = inkDot;
    canvas.drawCircle(Offset(8.2 * sx, 7.6 * sy), 1.5 * sx, paint);
    canvas.drawCircle(Offset(17.8 * sx, 7.6 * sy), 1.5 * sx, paint);

    final body = Path()
      ..moveTo(4 * sx, 15.2 * sy)
      ..relativeCubicTo(0, -1.2 * sy, 0.9 * sx, -2.1 * sy, 2.3 * sx, -2.1 * sy)
      ..relativeLineTo(13.4 * sx, 0)
      ..relativeCubicTo(1.4 * sx, 0, 2.3 * sx, 0.9 * sy, 2.3 * sx, 2.1 * sy)
      ..relativeLineTo(0, 2.6 * sy)
      ..relativeCubicTo(0, 3.8 * sy, -3.2 * sx, 6.8 * sy, -9 * sx, 6.8 * sy)
      ..relativeCubicTo(-5.8 * sx, 0, -9 * sx, -3 * sy, -9 * sx, -6.8 * sy)
      ..close();

    paint.color = paper;
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant ToadFacePainter oldDelegate) => false;
}

class ToadAppLabel extends StatelessWidget {
  const ToadAppLabel({
    super.key,
    required this.text,
    required this.color,
    required this.haloColor,
    this.fontSize = ToadMetrics.appNameSize,
    this.opacity,
    this.maxWidth = 70,
  });

  final String text;
  final Color color;
  final Color haloColor;
  final double fontSize;
  final double? opacity;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final effective = opacity == null
        ? color
        : color.withValues(alpha: color.a * opacity!);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ToadType.hand(fontSize, color: effective, height: 1.15).copyWith(
          shadows: [
            Shadow(color: haloColor, offset: const Offset(0, 1), blurRadius: 3),
          ],
        ),
      ),
    );
  }
}

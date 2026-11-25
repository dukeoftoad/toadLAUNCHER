library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../home/grid_flow.dart' show canvasRowPitch, canvasGutter;
import '../home/home_controller.dart' show editModeProvider;

class GridSkeletonPainter extends CustomPainter {
  GridSkeletonPainter({required this.color, this.columns = ToadMetrics.defaultColumns});

  final Color color;
  final int columns;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = color.withValues(alpha: color.a * 0.12);
    final paint = Paint()
      ..strokeWidth = 1
      ..color = ink;

    final cellW = (size.width - canvasGutter * 2) / columns;
    for (var i = 0; i <= columns; i++) {
      final x = canvasGutter + i * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = canvasRowPitch; y < size.height; y += canvasRowPitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridSkeletonPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.columns != columns;
}

class DashedSelectionPainter extends CustomPainter {
  DashedSelectionPainter({required this.color, this.radius = 14});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    const dash = 6.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dash;
      }
    }
  }

  @override
  bool shouldRepaint(DashedSelectionPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class EditBottomStrip extends StatelessWidget {
  const EditBottomStrip({
    super.key,
    required this.onWallpapers,
    required this.onWidgets,
    required this.onSettings,
    required this.onDone,
  });

  final VoidCallback onWallpapers;
  final VoidCallback onWidgets;
  final VoidCallback onSettings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return Container(
      margin: ToadMetrics.dockMargin,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.surface.a * 0.72),
        borderRadius: BorderRadius.circular(ToadRadii.dock),
        border: Border.all(
          color: palette.hairline.withValues(alpha: palette.hairline.a * 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StripItem(
              icon: '▤',
              label: 'Wallpapers',
              ink: ink,
              chip: palette.accentWash,
              onTap: onWallpapers,
            ),
          ),
          Expanded(
            child: _StripItem(
              icon: '▦',
              label: 'Widgets',
              ink: ink,
              chip: palette.accentWash,
              onTap: onWidgets,
            ),
          ),
          Expanded(
            child: _StripItem(
              icon: '⚙',
              label: 'Settings',
              ink: ink,
              chip: palette.accentWash,
              onTap: onSettings,
            ),
          ),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Done',
                style: ToadType.hand(14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.icon,
    required this.label,
    required this.ink,
    required this.chip,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color ink;
  final Color chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chip,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  fontFamily: ToadType.fontHand,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ToadType.hand(11.5, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

class EditHintBubble extends ConsumerWidget {
  const EditHintBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(launcherSettingsProvider);
    if (!ref.watch(editModeProvider) || settings.editHintDismissed) {
      return const SizedBox.shrink();
    }
    final palette = ToadTheme.of(context).palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ToadRadii.card),
        border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33140F05),
            offset: Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Drag a widget anywhere on the canvas — pull a corner to '
              'resize. Apps flow around it.',
              style: ToadType.hand(
                13,
                height: 1.25,
                color: palette.ink.withValues(alpha: palette.ink.a * 0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref
                .read(launcherSettingsProvider.notifier)
                .setEditHintDismissed(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.accentWash,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Got it',
                style: ToadType.hand(12.5, color: palette.accentInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

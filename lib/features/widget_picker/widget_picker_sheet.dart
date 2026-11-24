/// Widget picker — screen 8 of the proposal.
///
/// "A bottom sheet with live mini-previews. toadGALLERY's Memories widget
/// is the featured first citizen of the toad family."
///
///   · previews are real renders — the same engines as the placed widget
///   · choosing a widget drops straight into edit mode with the widget
///     attached: drag it onto home, it snaps to the grid
///   · the featured Memories card appears only when toadGALLERY is
///     installed; otherwise the slot quietly explains how to get it
///   · the sheet supports drag-to-dismiss and follows the drawer's blur
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart' show clockProvider;
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../home/home_controller.dart';

/// Opens the picker sheet. Call from the edit strip, the context menus or
/// the empty-space menu.
Future<void> showWidgetPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black26,
    builder: (_) => const WidgetPickerSheet(),
  );
}

class WidgetPickerSheet extends ConsumerWidget {
  const WidgetPickerSheet({super.key});

  bool _installed(HomeLayout? layout, String appId) =>
      layout?.allApps.any((a) => a.id == appId) ?? false;

  bool _placed(HomeLayout? layout, WidgetKind kind) =>
      layout?.widgets.any((w) => w.kind == kind) ?? false;

  void _pick(BuildContext context, WidgetRef ref, WidgetKind kind) {
    Navigator.of(context).pop();
    ref.read(placementProvider.notifier).begin(kind);
    ref.read(editModeProvider.notifier).enter();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final layout = ref.watch(homeLayoutProvider).valueOrNull;
    final dark = skin.isDark;
    final rowInk = dark ? const Color(0xFFE8E2D4) : palette.ink;

    final galleryInstalled = _installed(layout, 'family.toad.gallery');
    final memoriesPlaced = _placed(layout, WidgetKind.memories);
    final clockPlaced = _placed(layout, WidgetKind.clock);
    final calendarPlaced = _placed(layout, WidgetKind.calendar);
    final stickyPlaced = _placed(layout, WidgetKind.sticky);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ToadRadii.sheetTop),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: palette.paper.withValues(alpha: palette.paper.a * 0.92),
                borderRadius: BorderRadius.circular(ToadRadii.sheetTop),
                border: Border.all(color: palette.hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grabber — drag-to-dismiss.
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.ink.withValues(
                        alpha: palette.ink.a * 0.25,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Widgets',
                        style: ToadType.caveat(30, color: palette.ink),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                      child: Column(
                        children: [
                          // Featured — family first, never nagging.
                          _WidgetRow(
                            preview: const _MemoriesPreview(),
                            title: 'toadGALLERY · Memories',
                            subtitle: !galleryInstalled
                                ? 'Featured when toadGALLERY is installed — '
                                      'the family gallery carries it'
                                : memoriesPlaced
                                ? 'On-this-day strip · 4×2 · featured — '
                                      'already on your home'
                                : 'On-this-day strip · 4×2 · featured',
                            ink: rowInk,
                            accent: palette.accent,
                            featured: true,
                            dimmed: !galleryInstalled,
                            onTap: galleryInstalled
                                ? (memoriesPlaced
                                      ? () => _toast(
                                          context,
                                          ref,
                                          'Memories is already pinned on your home',
                                        )
                                      : () => _pick(
                                          context,
                                          ref,
                                          WidgetKind.memories,
                                        ))
                                : null,
                          ),
                          _WidgetRow(
                            preview: _ClockPreview(),
                            title: 'Caveat clock',
                            subtitle: clockPlaced
                                ? 'Handwritten time · resizable 2×1 to 4×4 — '
                                      'already placed'
                                : 'Handwritten time · 2×2 · resizable to 4×4',
                            ink: rowInk,
                            accent: palette.accent,
                            dimmed: clockPlaced,
                            onTap: clockPlaced
                                ? () => _toast(
                                    context,
                                    ref,
                                    'The clock is already on your home',
                                  )
                                : () => _pick(context, ref, WidgetKind.clock),
                          ),
                          _WidgetRow(
                            preview: const _CalendarPreview(),
                            title: 'Month calendar',
                            subtitle: calendarPlaced
                                ? 'Local events only · 4×4 — already placed'
                                : 'Local events only · 4×4',
                            ink: rowInk,
                            accent: palette.accent,
                            dimmed: calendarPlaced,
                            onTap: calendarPlaced
                                ? () => _toast(
                                    context,
                                    ref,
                                    'The calendar is already on your home',
                                  )
                                : () =>
                                      _pick(context, ref, WidgetKind.calendar),
                          ),
                          _WidgetRow(
                            preview: const _StickyPreview(),
                            title: 'Sticky note',
                            subtitle: stickyPlaced
                                ? 'Patrick Hand scribble · 2×2 — already placed'
                                : 'Patrick Hand scribble · 2×2',
                            ink: rowInk,
                            accent: palette.accent,
                            dimmed: stickyPlaced,
                            onTap: stickyPlaced
                                ? () => _toast(
                                    context,
                                    ref,
                                    'The sticky note is already on your home',
                                  )
                                : () => _pick(context, ref, WidgetKind.sticky),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context, WidgetRef ref, String message) {
    Navigator.of(context).pop();
    ref.read(toastProvider.notifier).show(message);
  }
}

/// One picker row: live preview tile + name + honest size/subtitle.
class _WidgetRow extends StatelessWidget {
  const _WidgetRow({
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.accent,
    this.dimmed = false,
    required this.onTap,
    this.featured = false,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final Color ink;
  final Color accent;
  final bool dimmed;
  final VoidCallback? onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Opacity(
      opacity: dimmed ? 0.62 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: featured
                ? palette.accentWash
                : palette.surface.withValues(alpha: palette.surface.a * 0.9),
            borderRadius: BorderRadius.circular(ToadRadii.card - 4),
            border: Border.all(
              color: featured
                  ? palette.accent.withValues(alpha: palette.accent.a * 0.4)
                  : palette.hairline,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: ToadMetrics.widgetPreviewWidth,
                height: ToadMetrics.widgetPreviewHeight,
                child: preview,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ToadType.hand(14.5, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ToadType.inter(
                        10.5,
                        height: 1.3,
                        color: ink.withValues(alpha: ink.a * 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live previews — scaled-down real renders (never stock images)
// ---------------------------------------------------------------------------

class _MemoriesPreview extends StatelessWidget {
  const _MemoriesPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppIconGradients.memoryPhotos[i][0].withValues(
                  alpha: 0.85,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockPreview extends StatelessWidget {
  const _ClockPreview();

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return Center(
      child: Consumer(
        builder: (context, ref, _) {
          final now = ref.watch(clockProvider).value ?? DateTime.now();
          final hh = now.hour.toString().padLeft(2, '0');
          final mm = now.minute.toString().padLeft(2, '0');
          return Text(
            '$hh:$mm',
            style: ToadType.caveat(26, color: palette.ink),
          );
        },
      ),
    );
  }
}

class _CalendarPreview extends StatelessWidget {
  const _CalendarPreview();

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Center(
      child: SizedBox(
        width: 70,
        child: Wrap(
          spacing: 1,
          runSpacing: 1,
          children: [
            for (final l in letters)
              SizedBox(
                width: 9,
                height: 9,
                child: Center(
                  child: Text(
                    l,
                    style: ToadType.inter(
                      6,
                      weight: 600,
                      color: palette.ink.withValues(alpha: palette.ink.a * 0.5),
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < 21; i++)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.ink.withValues(alpha: palette.ink.a * 0.14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StickyPreview extends StatelessWidget {
  const _StickyPreview();

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return Center(
      child: Container(
        width: 64,
        height: 40,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: palette.gold.withValues(alpha: palette.gold.a * 0.22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: palette.hairline.withValues(alpha: palette.hairline.a * 0.8),
          ),
        ),
        child: Text(
          'buy milk…',
          style: ToadType.hand(
            12,
            color: palette.ink.withValues(alpha: palette.ink.a * 0.9),
          ),
        ),
      ),
    );
  }
}

/// Pick-to-place ghost — "choosing a widget drops the user straight into
/// edit mode with the widget attached to the finger". The ghost rides at
/// the bottom; drag it onto home and it snaps into the page's widget stack.
class PlacementGhost extends ConsumerWidget {
  const PlacementGhost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(placementProvider);
    if (kind == null) return const SizedBox.shrink();

    final palette = ToadTheme.of(context).palette;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 118,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<WidgetKind>(
              data: kind,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Opacity(
                opacity: 0.92,
                child: _GhostPreview(kind: kind),
              ),
              childWhenDragging: const SizedBox.shrink(),
              onDragCompleted: () {
                // Dropped on the page's DragTarget — it places the widget.
              },
              onDraggableCanceled: (velocity, offset) {
                // Released off-target: keep the ghost (still in edit mode).
              },
              // The grabbable chip — the widget "attached to the finger".
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.accent, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29140F05),
                      offset: Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: ToadMetrics.widgetPreviewWidth,
                  height: ToadMetrics.widgetPreviewHeight,
                  child: _GhostPreview(kind: kind),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.hairline),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29140F05),
                    offset: Offset(0, 8),
                    blurRadius: 20,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Text(
                'Drag onto home to place — it snaps to the grid',
                style: ToadType.hand(12.5, color: palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dragged chip — a small render of the picked widget's engine.
class _GhostPreview extends StatelessWidget {
  const _GhostPreview({required this.kind});

  final WidgetKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return Container(
      width: 120,
      height: 72,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.accent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40140F05),
            offset: Offset(0, 14),
            blurRadius: 28,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 92,
          height: 56,
          child: switch (kind) {
            WidgetKind.clock => const _ClockPreview(),
            WidgetKind.memories => const _MemoriesPreview(),
            WidgetKind.calendar => const _CalendarPreview(),
            WidgetKind.sticky => const _StickyPreview(),
          },
        ),
      ),
    );
  }
}

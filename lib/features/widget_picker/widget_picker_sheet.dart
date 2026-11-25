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
import '../../core/device/device_bridge.dart';
import '../../core/device/toad_family.dart';
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
                            title: 'toadLIST note',
                            subtitle: stickyPlaced
                                ? 'Your live list · 2×2 — already placed'
                                : 'Your live list, top flies · 2×2',
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
                          const _AndroidWidgetsSection(),
                          const _FamilyWidgetsSection(),
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
          '✓ list…',
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
            // Real widgets never ride the ghost — they land instantly.
            WidgetKind.androidHosted => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

/// Real home-screen widgets published by installed toad family apps —
/// discovered through the platform channel; pinning goes through the
/// system's own confirmation. Hidden entirely when nothing is offered
/// (or when the channel is not in device mode).
class _FamilyWidgetsSection extends ConsumerStatefulWidget {
  const _FamilyWidgetsSection();

  @override
  ConsumerState<_FamilyWidgetsSection> createState() =>
      _FamilyWidgetsSectionState();
}

class _FamilyWidgetsSectionState extends ConsumerState<_FamilyWidgetsSection> {
  late Future<List<ToadWidgetInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(deviceBridgeProvider)
        .toadWidgets([
          for (final app in kToadFamilyApps) app.packageId,
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return FutureBuilder<List<ToadWidgetInfo>>(
      future: _future,
      builder: (context, snap) {
        final widgets = snap.data ?? const <ToadWidgetInfo>[];
        if (snap.connectionState != ConnectionState.done || widgets.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'from the toad family',
                    style: ToadType.caveat(21, color: palette.ink),
                  ),
                ),
              ),
              for (final w in widgets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ToadType.hand(14.5, color: ink),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'real home-screen widget · ${w.packageName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ToadType.inter(
                                10.5,
                                color: ink.withValues(alpha: ink.a * 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await ref
                              .read(deviceBridgeProvider)
                              .pinWidget(w.providerId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentWash,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'pin',
                            style: ToadType.hand(13, color: palette.accentInk),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The v0.11 shelf — every real home-screen widget provider on the phone,
/// listed from the actual AppWidgetManager. "Add" allocates an id from
/// OUR AppWidgetHost, binds it (Android allows the default Home app to
/// bind), and lands it straight on the current page. When the launcher
/// is not yet Home, the row explains exactly that — never a silent lie.
class _AndroidWidgetsSection extends ConsumerStatefulWidget {
  const _AndroidWidgetsSection();

  @override
  ConsumerState<_AndroidWidgetsSection> createState() =>
      _AndroidWidgetsSectionState();
}

class _AndroidWidgetsSectionState extends ConsumerState<_AndroidWidgetsSection> {
  late Future<List<HostableWidgetInfo>> _future;
  bool _hosting = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(deviceBridgeProvider).listHostableWidgets();
  }

  Future<void> _add(BuildContext context, HostableWidgetInfo info) async {
    if (_hosting) return;
    _hosting = true;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final bridge = ref.read(deviceBridgeProvider);
      final isHome = await bridge.isDefaultHome();
      if (isHome) {
        final appWidgetId = await bridge.hostWidget(info.providerId);
        if (appWidgetId == null) {
          messenger
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(
              'Android refused the binding — make toadLAUNCHER your Home '
              'and try again',
            )));
          return;
        }
        final page = ref.read(currentPageProvider);
        final placed = ref.read(homeLayoutProvider.notifier).placeHostedWidget(
          page: page,
          index: 0,
          providerId: info.providerId,
          label: info.label,
          packageName: info.packageName,
          appWidgetId: appWidgetId,
        );
        if (placed) {
          ref
              .read(homeLayoutProvider.notifier)
              .commitAction(null, message: '${info.label} placed — a real, '
                  'live Android widget');
          navigator.pop();
        }
      } else {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(
            'toadLAUNCHER must be your Home to host real widgets — the '
            'choice dialog is opening',
          )));
        await bridge.requestDefaultHome();
      }
    } finally {
      _hosting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return FutureBuilder<List<HostableWidgetInfo>>(
      future: _future,
      builder: (context, snap) {
        final widgets = snap.data ?? const <HostableWidgetInfo>[];
        if (snap.connectionState != ConnectionState.done || widgets.isEmpty) {
          return const SizedBox.shrink();
        }
        final sorted = [...widgets]..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'real Android widgets — live from this phone',
                    style: ToadType.caveat(21, color: palette.ink),
                  ),
                ),
              ),
              for (final w in sorted)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _add(context, w),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surface
                            .withValues(alpha: palette.surface.a * 0.9),
                        borderRadius: BorderRadius.circular(ToadRadii.card - 4),
                        border: Border.all(color: palette.hairline),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: ToadMetrics.widgetPreviewWidth,
                            height: ToadMetrics.widgetPreviewHeight,
                            child: w.previewPng != null
                                ? Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        w.previewPng!,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      '▦',
                                      style: ToadType.hand(
                                        24,
                                        color: ink.withValues(
                                          alpha: ink.a * 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ToadType.hand(14.5, color: ink),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  w.packageName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ToadType.inter(
                                    10.5,
                                    color: ink.withValues(alpha: ink.a * 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accentWash,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'add',
                              style: ToadType.hand(
                                13,
                                color: palette.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: Text(
                  'real widgets need toadLAUNCHER as your Home — Android '
                  'binds them to the Home app',
                  style: ToadType.inter(
                    10.5,
                    height: 1.3,
                    color: ink.withValues(alpha: ink.a * 0.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

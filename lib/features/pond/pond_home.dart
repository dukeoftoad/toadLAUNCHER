/// Pond home — Pond Pro scene skin (screens 11 & 12).
///
/// The whole scene is one CustomPainter; icons, labels and widgets are real
/// composited widgets, so hit-testing and accessibility never change.
/// Static build for stage 1 — ambient loop (bob/croak/ripple) lands in
/// stage 4 per the milestone plan.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_app_icon.dart';
import '../home/home_controller.dart';
import '../home/widgets/app_grid.dart' show PageDots;
import '../home/widgets/hero_zone.dart';
import 'lily_pad_painter.dart';
import 'pond_scene_painter.dart';
import 'resident_toad_painter.dart';

class PondHome extends ConsumerStatefulWidget {
  const PondHome({super.key});

  @override
  ConsumerState<PondHome> createState() => _PondHomeState();
}

class _PondHomeState extends ConsumerState<PondHome> {
  late final PageController _pageController;
  final int _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (ref.read(currentPageProvider) != page) {
        ref.read(currentPageProvider.notifier).set(page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final pond = skin.pond;
    final settings = ref.watch(launcherSettingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final layoutAsync = ref.watch(homeLayoutProvider);
    final repo = ref.watch(appRepositoryProvider);

    final hero = buildHeroData(now, pond: true, pondNight: pond.isNight);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            pond.isNight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            pond.isNight ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Scene background (one painter).
            CustomPaint(painter: PondScenePainter(palette: pond)),

            // Live widgets layer.
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  HeroZone(data: hero),

                  // The clock's shimmering reflection.
                  _ClockReflection(
                    time: hero.time,
                    opacity: pond.reflectionOpacity,
                    color: pond.clockLabel,
                  ),

                  const SizedBox(height: 18),

                  // Lily-pad rows (static; bob animation stage 4).
                  layoutAsync.maybeWhen(
                    data: (layout) => Expanded(
                      child: FutureBuilder<List<List<AppEntry>>>(
                        future: repo.loadPondRows(),
                        builder: (context, snapshot) {
                          final rows =
                              snapshot.data ?? const <List<AppEntry>>[];
                          return PageView.builder(
                            controller: _pageController,
                            itemCount: _pageCount,
                            itemBuilder: (context, pageIndex) {
                              final apps = pageIndex == 0
                                  ? rows
                                  : _chunk(
                                      layout.pages.elementAtOrNull(pageIndex),
                                      3,
                                    );
                              return _PondRows(
                                rows: apps,
                                pond: pond,
                                iconShape: settings.iconShape,
                                onAppTap: (app) => ref
                                    .read(homeLayoutProvider.notifier)
                                    .launch(app),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    orElse: () => const Spacer(),
                  ),

                  // Page dots become firefly embers (glow at night).
                  PageDots(
                    count: _pageCount,
                    activeIndex: ref.watch(currentPageProvider),
                    dotColor: pond.isNight
                        ? pond.firefly.withValues(alpha: 0.85)
                        : pond.ink,
                  ),

                  // Log dock.
                  _LogDock(
                    apps: layoutAsync.maybeWhen(
                      data: (l) => l.dock,
                      orElse: () => const [],
                    ),
                    iconShape: settings.iconShape,
                    pond: pond,
                    onAppTap: (app) =>
                        ref.read(homeLayoutProvider.notifier).launch(app),
                    onDrawerTap: () {}, // Mouth drawer arrives in stage 4.
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chunk a flat page into rows of 3 pads.
List<List<AppEntry>> _chunk(List<AppEntry>? apps, int size) {
  if (apps == null) return const [];
  final out = <List<AppEntry>>[];
  for (var i = 0; i < apps.length; i += size) {
    out.add(apps.sublist(i, (i + size).clamp(0, apps.length)));
  }
  return out;
}

class _PondRows extends StatelessWidget {
  const _PondRows({
    required this.rows,
    required this.pond,
    required this.iconShape,
    required this.onAppTap,
  });

  final List<List<AppEntry>> rows;
  final PondPalette pond;
  final IconShape iconShape;
  final void Function(AppEntry) onAppTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: ToadMetrics.pondRowGapExtra - 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  rows[r][c].id == 'resident'
                      ? _ResidentPadCell(pond: pond)
                      : _PadCell(
                          app: rows[r][c],
                          pond: pond,
                          iconShape: iconShape,
                          onTap: () => onAppTap(rows[r][c]),
                        ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PadCell extends StatelessWidget {
  const _PadCell({
    required this.app,
    required this.pond,
    required this.iconShape,
    required this.onTap,
  });

  final AppEntry app;
  final PondPalette pond;
  final IconShape iconShape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: ToadMetrics.pondCellWidth,
        child: Column(
          children: [
            SizedBox(
              width: ToadMetrics.pondPadWidth,
              height: ToadMetrics.pondPadHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(
                      ToadMetrics.pondPadWidth,
                      ToadMetrics.pondPadHeight,
                    ),
                    painter: LilyPadPainter(palette: pond),
                  ),
                  ToadAppIcon(
                    app: app,
                    size: ToadMetrics.pondIconSize,
                    radius: ToadRadii.pondIconTile,
                    glyphSize: 21,
                    shape: iconShape,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            ToadAppLabel(
              text: app.name,
              color: pond.appLabel,
              haloColor: Colors.transparent,
              fontSize: ToadMetrics.pondAppNameSize,
              opacity: pond.isNight ? 0.8 : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The resident — the toad himself resting on the last pad. Night shows
/// closed eyes and three drifting z's (drift animation stage 4).
class _ResidentPadCell extends StatelessWidget {
  const _ResidentPadCell({required this.pond});

  final PondPalette pond;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ToadMetrics.pondCellWidth,
      child: Column(
        children: [
          SizedBox(
            width: ToadMetrics.pondPadWidth,
            height: ToadMetrics.pondPadHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(
                    ToadMetrics.pondPadWidth,
                    ToadMetrics.pondPadHeight,
                  ),
                  painter: LilyPadPainter(palette: pond),
                ),
                CustomPaint(
                  size: const Size(
                    ToadMetrics.toadWidth,
                    ToadMetrics.toadHeight,
                  ),
                  painter: ResidentToadPainter(palette: pond),
                ),
                if (pond.isNight)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _z(15),
                        const SizedBox(width: 2),
                        _z(21),
                        const SizedBox(width: 2),
                        _z(27),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          ToadAppLabel(
            text: pond.isNight ? 'the resident · asleep' : 'the resident',
            color: pond.appLabel,
            haloColor: Colors.transparent,
            fontSize: ToadMetrics.pondAppNameSize,
            opacity: pond.isNight ? 0.8 : null,
          ),
        ],
      ),
    );
  }

  Widget _z(double size) => Text(
        'z',
        style: ToadType.caveat(size, color: pond.zzz ?? pond.appLabel),
      );
}

class _ClockReflection extends StatelessWidget {
  const _ClockReflection({
    required this.time,
    required this.opacity,
    required this.color,
  });

  final String time;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 30, top: 4),
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1),
              child: Text(
                time,
                style: ToadType.caveat(
                  ToadMetrics.reflectionClockSize,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Log dock — wooden gradient + grain overlay, replaces the frosted dock.
class _LogDock extends StatelessWidget {
  const _LogDock({
    required this.apps,
    required this.iconShape,
    required this.pond,
    required this.onAppTap,
    required this.onDrawerTap,
  });

  final List<AppEntry> apps;
  final IconShape iconShape;
  final PondPalette pond;
  final void Function(AppEntry) onAppTap;
  final VoidCallback onDrawerTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: pond.logBrightness,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ToadRadii.dock),
          boxShadow: [
            BoxShadow(
              color: const Color(0x99060818).withValues(alpha: 0.6),
              offset: const Offset(0, 12),
              blurRadius: 20,
              spreadRadius: -8,
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: _LogGrainPainter(pond: pond),
          child: Row(
            children: [
              for (var i = 0; i < apps.take(4).length; i++)
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onAppTap(apps[i]),
                      child: ToadAppIcon(
                        app: apps[i],
                        size: ToadMetrics.dockIconSize,
                        shape: iconShape,
                        glyphSize: 21,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDrawerTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⌃',
                          style: ToadType.hand(
                            13,
                            color: const Color(0xFFF3E9D2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'APPS',
                          style: ToadType.inter(
                            9,
                            weight: 500,
                            tracking: 0.72,
                            color:
                                const Color(0xFFF3E9D2).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wood gradient + grain stripes + edge highlights painted over the dock.
class _LogGrainPainter extends CustomPainter {
  _LogGrainPainter({required this.pond});

  final PondPalette pond;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(ToadRadii.dock),
    );

    // Wood body: 180deg #8A6242 → #6E4C33 58% → #5B3D2A.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pond.logTop, pond.logMid, pond.logBottom],
          stops: const [0, 0.58, 1],
        ).createShader(rect),
    );

    // Grain: repeating 2px/9px stripes.
    canvas.save();
    canvas.clipRRect(rrect);
    final grain = Paint()..color = Colors.black.withValues(alpha: 0.5);
    var y = 0.0;
    var stripeOn = false;
    while (y < size.height) {
      if (stripeOn) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), grain);
      }
      y += 9;
      stripeOn = !stripeOn;
    }
    canvas.restore();

    // Inset top highlight / bottom shadow.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFEECC8F).withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LogGrainPainter oldDelegate) =>
      oldDelegate.pond.isNight != pond.isNight;
}

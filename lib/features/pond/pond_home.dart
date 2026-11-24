/// Pond home — Pond Pro scene skin (screens 11 & 12) with the full M4
/// ambient loop.
///
/// The scene painters repaint through the shared ambient clock (no widget
/// rebuilds); pad bob and toad bob are transform-only compositor moves; the
/// resident blinks, croaks when tapped (grumpily at night), and swiping up
/// opens the mouth showcase drawer — "the drawer is the toad".
/// Calm pond (or an active battery guard on device) freezes the loop into
/// a still painting.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_app_icon.dart';
import '../../shared/widgets/toad_toast.dart';
import '../context_menu/app_context_menu.dart';
import '../home/home_controller.dart';
import '../home/widgets/app_grid.dart' show PageDots;
import '../home/widgets/hero_zone.dart';
import 'lily_pad_painter.dart';
import 'mouth_drawer.dart' show MouthDrawer;
import 'pond_ambient.dart';
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

  /// Long-press menu raised from a lily pad (pondApp variant).
  MenuRequest? _menu;

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

  void _showPadMenu(AppEntry app, Offset anchor) {
    void dismiss() => setState(() => _menu = null);
    void toast(String message) {
      dismiss();
      ref.read(toastProvider.notifier).show(message);
    }

    setState(() {
      _menu = MenuRequest(
        context: MenuContext.pondApp,
        anchor: anchor,
        app: app,
        actions: MenuActions(
          onAppInfo: () =>
              toast('App info is a device feature — demo stays offline'),
          onWidgets: () => toast(
            'Widgets are placed from the sketchbook skins — the pond hosts '
            'them with its ambient loop',
          ),
          onShare: () =>
              toast('Share is a device feature — demo stays offline'),
          onUninstall: () =>
              toast('Uninstall needs a real device — demo keeps everything'),
        ),
      );
    });
  }

  void _closeTopOverlay() {
    if (_menu != null) {
      setState(() => _menu = null);
    } else if (ref.read(drawerOpenProvider)) {
      ref.read(drawerOpenProvider.notifier).close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final pond = skin.pond;
    final settings = ref.watch(launcherSettingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final layoutAsync = ref.watch(homeLayoutProvider);
    final repo = ref.watch(appRepositoryProvider);
    final drawerOpen = ref.watch(drawerOpenProvider);

    final hero = buildHeroData(now, pond: true, pondNight: pond.isNight);

    ref.listen<ToastEvent?>(toastProvider, (prev, event) {
      if (event == null || identical(event, prev)) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(toadToast(context, event));
      ref.read(toastProvider.notifier).consume();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_menu != null || ref.read(drawerOpenProvider)) _closeTopOverlay();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: pond.isNight
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: pond.isNight
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // The pond is the one screen that must never freeze silently:
          // ambient loop + mouth drawer own their tickers.
          body: TickerMode(
            enabled: true,
            child: PondAmbient(
              builder: (context, elapsed) => Stack(
                fit: StackFit.expand,
                children: [
                  // Scene background — repaints off the ambient clock; the
                  // day→night hand-off crossfades over 2 s.
                  AnimatedSwitcher(
                    duration: ToadMotion.dayNightCrossfade,
                    child: CustomPaint(
                      key: ValueKey(pond.isNight),
                      painter: PondScenePainter(
                        palette: pond,
                        clock: elapsed,
                        rain: settings.pondRain,
                      ),
                    ),
                  ),

                  // Live widgets layer.
                  SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      // "Swipe up on the log — the drawer is the toad."
                      onVerticalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (settings.swipeUpDrawer &&
                            v < -320 &&
                            !drawerOpen &&
                            _menu == null) {
                          ref.read(drawerOpenProvider.notifier).open();
                        }
                      },
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

                          // Lily-pad rows — the bob rides the ambient clock.
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
                                              _flatPondApps(layout, pageIndex),
                                              3,
                                            );
                                      return _PondRows(
                                        rows: apps,
                                        pond: pond,
                                        elapsed: elapsed,
                                        iconShape: settings.iconShape,
                                        onAppTap: (app) => ref
                                            .read(homeLayoutProvider.notifier)
                                            .launch(app),
                                        onAppLongPress: _showPadMenu,
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
                            onAppTap: (app) => ref
                                .read(homeLayoutProvider.notifier)
                                .launch(app),
                            onDrawerTap: () =>
                                ref.read(drawerOpenProvider.notifier).open(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---- The mouth showcase drawer (screen 13) ----
                  if (drawerOpen)
                    const TickerMode(enabled: true, child: MouthDrawer()),

                  // ---- Long-press menu ----
                  if (_menu != null)
                    ContextMenuLayer(
                      request: _menu!,
                      onDismissed: () => setState(() => _menu = null),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pond pages 2+ reuse the sketchbook pages' plain apps (folders stay
  /// home-only in this stage).
  List<AppEntry> _flatPondApps(HomeLayout layout, int pageIndex) {
    final page = layout.pages.elementAtOrNull(pageIndex) ?? const <HomeCell>[];
    return [
      for (final cell in page)
        if (cell is AppCell) cell.app,
    ];
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
    required this.elapsed,
    required this.iconShape,
    required this.onAppTap,
    required this.onAppLongPress,
  });

  final List<List<AppEntry>> rows;
  final PondPalette pond;
  final ValueListenable<Duration> elapsed;
  final IconShape iconShape;
  final void Function(AppEntry) onAppTap;
  final void Function(AppEntry app, Offset anchor) onAppLongPress;

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
                      ? _ResidentPadCell(pond: pond, elapsed: elapsed)
                      : _PadCell(
                          app: rows[r][c],
                          pond: pond,
                          elapsed: elapsed,
                          phaseIndex: r * 3 + c,
                          iconShape: iconShape,
                          onTap: () => onAppTap(rows[r][c]),
                          onLongPress: (anchor) =>
                              onAppLongPress(rows[r][c], anchor),
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

/// Pad bob — 4.8 s, phase-offset per pad, transform-only.
class _PadBob extends StatelessWidget {
  const _PadBob({
    required this.elapsed,
    required this.phaseIndex,
    required this.night,
    required this.child,
  });

  final ValueListenable<Duration> elapsed;
  final int phaseIndex;
  final bool night;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: elapsed,
      builder: (context, _) {
        final t = elapsed.value.inMicroseconds / 1e6;
        // 4.8 s loop; each pad owns a phase slice of it.
        final phase =
            ((t + phaseIndex * 0.8) / ToadMotion.padBob.inMicroseconds / 1e6)
                .clamp(0, 1);
        final amp = night ? 2.0 : 3.0;
        return Transform.translate(
          offset: Offset(0, -amp * math.sin(phase * 2 * math.pi)),
          child: child,
        );
      },
    );
  }
}

class _PadCell extends ConsumerStatefulWidget {
  const _PadCell({
    required this.app,
    required this.pond,
    required this.elapsed,
    required this.phaseIndex,
    required this.iconShape,
    required this.onTap,
    required this.onLongPress,
  });

  final AppEntry app;
  final PondPalette pond;
  final ValueListenable<Duration> elapsed;
  final int phaseIndex;
  final IconShape iconShape;
  final VoidCallback onTap;
  final void Function(Offset anchor) onLongPress;

  @override
  ConsumerState<_PadCell> createState() => _PadCellState();
}

class _PadCellState extends ConsumerState<_PadCell>
    with TickerProviderStateMixin {
  late final AnimationController _hop;

  @override
  void initState() {
    super.initState();
    // Hop — 320 ms arc, "single sprite translate + squash".
    _hop = AnimationController(vsync: this, duration: ToadMotion.hop, value: 0);
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: (details) {
        // The hop accompanies the long-press (gesture map, screen 11).
        _hop.forward(from: 0);
        widget.onLongPress(details.globalPosition);
      },
      child: SizedBox(
        width: ToadMetrics.pondCellWidth,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_hop, widget.elapsed]),
              builder: (context, child) {
                final t = _hop.value;
                final dx = 48 * t;
                final dy = -math.sin(t * math.pi) * 30;
                final squash = 1 + 0.06 * math.sin(t * math.pi * 2);
                return _PadBob(
                  elapsed: widget.elapsed,
                  phaseIndex: widget.phaseIndex,
                  night: widget.pond.isNight,
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.scale(scale: squash, child: child),
                  ),
                );
              },
              child: SizedBox(
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
                      painter: LilyPadPainter(palette: widget.pond),
                    ),
                    ToadAppIcon(
                      app: widget.app,
                      size: ToadMetrics.pondIconSize,
                      radius: ToadRadii.pondIconTile,
                      glyphSize: 21,
                      shape: widget.iconShape,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            ToadAppLabel(
              text: widget.app.name,
              color: widget.pond.appLabel,
              haloColor: Colors.transparent,
              fontSize: ToadMetrics.pondAppNameSize,
              opacity: widget.pond.isNight ? 0.8 : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The resident — blinks on the ambient schedule, croaks (900 ms, once)
/// when tapped, and wakes grumpily before sunrise.
class _ResidentPadCell extends ConsumerStatefulWidget {
  const _ResidentPadCell({required this.pond, required this.elapsed});

  final PondPalette pond;
  final ValueListenable<Duration> elapsed;

  @override
  ConsumerState<_ResidentPadCell> createState() => _ResidentPadCellState();
}

class _ResidentPadCellState extends ConsumerState<_ResidentPadCell>
    with TickerProviderStateMixin {
  late final AnimationController _croak;
  bool _awakeOverride = false;

  @override
  void initState() {
    super.initState();
    _croak = AnimationController(
      vsync: this,
      duration: ToadMotion.croak, // 900 ms, plays once
    );
  }

  @override
  void dispose() {
    _croak.dispose();
    super.dispose();
  }

  void _pat() {
    // Night tap: "he blinks awake with a grumpy croak."
    if (widget.pond.isNight && !_awakeOverride) {
      setState(() => _awakeOverride = true);
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (mounted) setState(() => _awakeOverride = false);
      });
    }
    _croak.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pond = widget.pond;
    final asleep = pond.isNight && !_awakeOverride;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pat,
      child: SizedBox(
        width: ToadMetrics.pondCellWidth,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([widget.elapsed, _croak]),
              builder: (context, _) {
                final t = widget.elapsed.value.inMicroseconds / 1e6;
                // Toad bob — 5.4 s day, slower (7.6 s) asleep.
                final period = asleep ? 7.6 : 5.4;
                final phase = (t / period) % 1;
                final amp = asleep ? 2.0 : 3.0;
                return _PadBob(
                  elapsed: widget.elapsed,
                  phaseIndex: 5,
                  night: pond.isNight,
                  child: Transform.translate(
                    offset: Offset(0, -amp * math.sin(phase * 2 * math.pi)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(
                            ToadMetrics.toadWidth,
                            ToadMetrics.toadHeight,
                          ),
                          painter: ResidentToadPainter(
                            palette: pond,
                            blinking: blinkAt(widget.elapsed.value) && !asleep,
                            croak: _croak.value,
                            awake: _awakeOverride,
                            grumpy: _awakeOverride && pond.isNight,
                          ),
                        ),
                        // Drifting z's while asleep.
                        if (asleep)
                          Positioned(
                            right: -4,
                            top: -8,
                            child: _DriftingZs(
                              elapsed: widget.elapsed,
                              color: pond.zzz ?? pond.appLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 3),
            ToadAppLabel(
              text: asleep ? 'the resident · asleep' : 'the resident',
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

/// Drifting z's at night — three Caveat z's on staggered 4.5 s loops.
class _DriftingZs extends StatelessWidget {
  const _DriftingZs({required this.elapsed, required this.color});

  final ValueListenable<Duration> elapsed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: elapsed,
      builder: (context, _) {
        final t = elapsed.value.inMicroseconds / 1e6;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Builder(
                builder: (context) {
                  final phase = ((t + i * 1.5) / 4.5) % 1;
                  final opacity = phase < 0.25
                      ? phase / 0.25 * 0.85
                      : 0.85 * (1 - (phase - 0.25) / 0.75);
                  return Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(phase * 14, 4 - phase * 38),
                      child: Text(
                        'z',
                        style: ToadType.caveat(15 + i * 6.0, color: color),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
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
                            color: const Color(0xFFF3E9D2)
                                .withValues(alpha: 0.7),
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

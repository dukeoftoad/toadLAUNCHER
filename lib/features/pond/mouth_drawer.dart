/// The mouth showcase drawer — screen 13, "the drawer is the toad".
///
/// Signature moment: swiping up on the log, the resident leaps to the
/// bottom of the screen and opens his mouth wide — the app drawer is the
/// maw. The bulging eyes peek over the jaw and blink while you browse.
///
///   · the tongue is the search bar — "what fly do you seek?"
///   · a 4-column icon grid on the deep moss interior; it scrolls inside
///     the mouth; the A–Z rail hugs the jaw's right edge for quick jumps
///   · it tracks your finger: drag opens 0→100%; release below 40% and it
///     swallows shut (260 ms) with a gulp bounce and a satisfied blink;
///     pull past the top and it hiccups a bubble
///   · same app index and search logic as the sketchbook drawer — only the
///     stage changes
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_app_icon.dart';
import '../home/home_controller.dart';
import 'pond_ambient.dart' show PondAmbient, PondTickerProvider, blinkAt;

/// Maw furniture tokens (from the proposal's CSS, screen 13).
abstract final class MawColors {
  static const scrimTop = Color(0x6B0A1414); // rgba(10,26,20,.42)
  static const scrimMid = Color(0x9E06120E); // rgba(6,18,14,.62)
  static const scrimEnd = Color(0xB8040C0A); // rgba(4,12,10,.72)
  static const domeTop = Color(0xFF67A052);
  static const domeBottom = Color(0xFF4E7F3E);
  static const bumpCenter = Color(0xFF71A85C);
  static const bumpEdge = Color(0xFF517F41);
  static const ball = Color(0xFFF6F2DC);
  static const pupil = Color(0xFF20261A);
  static const interior = Color(0xFF22352B);
  static const interiorTop = Color(0xFF2A3F31);
  static const interiorMid = Color(0xFF1F3227);
  static const interiorBottom = Color(0xFF182B21);
  static const upperLipTop = Color(0xFF6BA355);
  static const upperLipBottom = Color(0xFF4E7F3E);
  static const jawTop = Color(0xFF557F42);
  static const jawBottom = Color(0xFF3E6331);
  static const tongueTop = Color(0xFFE8A7B0);
  static const tongueBottom = Color(0xFFD98F9C);
  static const tongueInk = Color(0xFF5E2F38);
  static const tongueShadow = Color(0x59963C4B);
  static const gridInk = Color(0xFFE4EDDF);
  static const railInk = Color(0xFFBFD3BF);
  static const hintInk = Color(0xFFD8E6D4);
}

class MouthDrawer extends ConsumerStatefulWidget {
  const MouthDrawer({super.key});

  @override
  ConsumerState<MouthDrawer> createState() => _MouthDrawerState();
}

class _MouthDrawerState extends ConsumerState<MouthDrawer> {
  final PondTickerProvider _vsync = PondTickerProvider();

  /// Openness 0→1 — "drag-tracked, not timed".
  late final AnimationController _open;
  late final AnimationController _swallow;
  late final AnimationController _hiccup;
  final TextEditingController _search = TextEditingController();
  final ScrollController _grid = ScrollController();
  String _query = '';
  String? _railLetter;
  double _overpull = 0;
  bool _hiccups = false;

  /// The satisfied blink right after the swallow.
  bool _satisfiedBlink = false;
  DateTime _satisfiedUntil = DateTime.now();

  /// The 40% swallow threshold from the proposal.
  static const double _swallowThreshold = 0.4;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(vsync: _vsync, value: 0.06)
      ..duration = ToadMotion.mouthOpen; // 380 ms
    _swallow = AnimationController(
      vsync: _vsync,
      duration: ToadMotion.swallow, // 260 ms
    );
    _hiccup = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 900),
    );
    _search.addListener(() {
      if (_query != _search.text) setState(() => _query = _search.text);
    });
    // The initial swipe-up opens the mouth wide.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open.forward();
    });
  }

  @override
  void dispose() {
    _open.dispose();
    _swallow.dispose();
    _hiccup.dispose();
    _vsync.dispose();
    _search.dispose();
    _grid.dispose();
    super.dispose();
  }

  void _launch(AppEntry app) {
    ref.read(homeLayoutProvider.notifier).launch(app);
    _swallowShut();
  }

  /// "release below 40% and it swallows shut (260 ms) with a gulp bounce
  /// and a satisfied blink".
  void _swallowShut() {
    _satisfiedBlink = true;
    _satisfiedUntil = DateTime.now().add(const Duration(milliseconds: 700));
    _swallow.forward(from: 0);
    _open
        .animateTo(0, duration: ToadMotion.swallow, curve: Curves.easeInCubic)
        .whenComplete(() {
          if (mounted) ref.read(drawerOpenProvider.notifier).close();
        });
  }

  void _release() {
    if (_open.value < _swallowThreshold) {
      _swallowShut();
    } else {
      _open.animateTo(1, duration: ToadMotion.mouthOpen);
    }
  }

  void _pullPastTop(double dy) {
    if (_open.value >= 0.995 && dy < 0) {
      _overpull += -dy;
      if (_overpull > 70 && !_hiccups) {
        _hiccups = true;
        _hiccup.forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _hiccups = false);
        });
      }
    } else {
      _overpull = 0;
    }
  }

  List<AppEntry> _hits(List<AppEntry> all) {
    final q = _query.trim().toLowerCase();
    var apps = [
      for (final app in all)
        if (q.isEmpty || app.name.toLowerCase().contains(q)) app,
    ];
    final letter = _railLetter;
    if (letter != null && q.isEmpty) {
      final exact = [
        for (final app in apps)
          if (app.name.toUpperCase().startsWith(letter)) app,
      ];
      if (exact.isNotEmpty) apps = exact;
    }
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final pond = skin.pond;
    final layoutAsync = ref.watch(homeLayoutProvider);
    final layout = layoutAsync.valueOrNull;
    final hits = _hits(layout?.allApps ?? const []);
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _swallowShut();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _swallowShut,
        },
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: AnimatedBuilder(
            animation: Listenable.merge([_open, _swallow]),
            builder: (context, _) {
              final o = _open.value;
              final gulp = 1 + 0.06 * math.sin(_swallow.value * math.pi);

              // The maw slides up with openness; 1 = seated at the mockup
              // position (head top 196 of 786).
              const mawTopRef = 196.0;
              final restOffset = size.height * 0.92;
              final seatedTop =
                  mawTopRef / ToadMetrics.referenceScreen.height * size.height;
              final dy = (1 - o) * (restOffset - seatedTop);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Scrim — tap the palate to close.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _swallowShut,
                    onVerticalDragUpdate: (d) {
                      _open.value =
                          (_open.value - d.delta.dy / (size.height * 0.55))
                              .clamp(0.0, 1.0);
                      _pullPastTop(d.delta.dy);
                    },
                    onVerticalDragEnd: (_) => _release(),
                    child: Opacity(
                      opacity: (0.62 * o).clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.45, 1],
                            colors: [
                              MawColors.scrimTop,
                              MawColors.scrimMid,
                              MawColors.scrimEnd,
                            ],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),

                  // Drag hint while the finger leads the mouth.
                  if (o < 0.985)
                    Positioned(
                      top: size.height * 0.19,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Text(
                          'pull up to open wider · release to swallow',
                          textAlign: TextAlign.center,
                          style: ToadType.hand(
                            13.5,
                            color: MawColors.hintInk.withValues(
                              alpha: MawColors.hintInk.a * 0.9 * (1 - o * 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // The head + maw column — the mouth tracks your finger
                  // over its whole surface, not just the backdrop.
                  Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: gulp,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (d) {
                          _open.value =
                              (_open.value - d.delta.dy / (size.height * 0.55))
                                  .clamp(0.0, 1.0);
                          _pullPastTop(d.delta.dy);
                        },
                        onVerticalDragEnd: (_) => _release(),
                        child: Column(
                          children: [
                            SizedBox(height: seatedTop - 120),
                            // Head — dome + blinking eyes peek over the jaw.
                            PondAmbient(
                              builder: (context, elapsed) => _MawHead(
                                elapsed: elapsed,
                                extraBlink: _satisfiedBlink,
                                extraBlinkUntil: _satisfiedUntil,
                              ),
                            ),
                            // The maw itself.
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  30,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  16,
                                ),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(44),
                                    bottom: Radius.circular(52),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0, 0.4, 1],
                                    colors: [
                                      MawColors.interiorTop,
                                      MawColors.interiorMid,
                                      MawColors.interiorBottom,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x8C000000),
                                      offset: Offset(0, -8),
                                      blurRadius: 24,
                                      spreadRadius: -12,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      children: [
                                        // Upper lip — rides over the maw's
                                        // top edge (lifted via transform).
                                        Transform.translate(
                                          offset: const Offset(0, -12),
                                          child: Container(
                                            height: 20,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            decoration: const BoxDecoration(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(99),
                                              ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  MawColors.upperLipTop,
                                                  MawColors.upperLipBottom,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Tongue — the search bar.
                                        _TongueSearch(
                                          controller: _search,
                                          hintColor: MawColors.tongueInk,
                                          cursor: pond.appLabel,
                                        ),
                                        const SizedBox(height: 14),
                                        // Showcase grid — scrolls inside.
                                        Expanded(
                                          child: GridView.builder(
                                            controller: _grid,
                                            padding: const EdgeInsets.only(
                                              right: 36,
                                              bottom: 8,
                                            ),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 4,
                                                  mainAxisSpacing: 8,
                                                  mainAxisExtent: 88,
                                                ),
                                            itemCount: hits.length,
                                            itemBuilder: (context, i) =>
                                                _MawApp(
                                                  app: hits[i],
                                                  onTap: () => _launch(hits[i]),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // A–Z rail on the jaw's right edge.
                                    Positioned(
                                      right: -12,
                                      top: 76,
                                      bottom: 8,
                                      child: _AzRail(
                                        apps: hits,
                                        active: _railLetter,
                                        onPick: (letter) {
                                          setState(() {
                                            _railLetter = _railLetter == letter
                                                ? null
                                                : letter;
                                          });
                                          _jumpTo(letter, hits);
                                        },
                                      ),
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

                  // Hiccup bubble — "pull past the top and it hiccups".
                  if (_hiccups)
                    AnimatedBuilder(
                      animation: _hiccup,
                      builder: (context, _) {
                        final t = _hiccup.value;
                        return Positioned(
                          left: size.width * 0.62,
                          bottom: size.height * 0.42 + t * 90,
                          child: Opacity(
                            opacity: t < 0.2
                                ? t / 0.2
                                : (1 - (t - 0.2) / 0.8).clamp(0.0, 1.0),
                            child: Container(
                              width: 16 + 8 * t,
                              height: 16 + 8 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x99DCE8DC),
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _jumpTo(String letter, List<AppEntry> hits) {
    final index = hits.indexWhere(
      (a) => a.name.toUpperCase().startsWith(letter),
    );
    if (index < 0 || !_grid.hasClients) return;
    final row = index ~/ 4;
    final target = (row * (88 + 8)).toDouble().clamp(
      0.0,
      _grid.position.maxScrollExtent,
    );
    _grid.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Dome + two bulging eyes — the blink loop rides the ambient clock.
class _MawHead extends StatelessWidget {
  const _MawHead({
    required this.elapsed,
    required this.extraBlink,
    required this.extraBlinkUntil,
  });

  final ValueListenable<Duration> elapsed;
  final bool extraBlink;
  final DateTime extraBlinkUntil;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: AnimatedBuilder(
        animation: elapsed,
        builder: (context, _) {
          final scheduleBlink = blinkAt(elapsed.value) || extraBlink;
          return CustomPaint(
            size: Size.infinite,
            painter: _MawHeadPainter(
              blinking: scheduleBlink,
              satisfied: extraBlink && DateTime.now().isBefore(extraBlinkUntil),
            ),
          );
        },
      ),
    );
  }
}

class _MawHeadPainter extends CustomPainter {
  _MawHeadPainter({required this.blinking, this.satisfied = false});

  final bool blinking;

  /// The swallow's contented blink — eyes curve the happy way.
  final bool satisfied;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final k = w / 352;

    // Dome — 330 wide, top 26.
    final domeRect = Rect.fromLTWH((w - 330 * k) / 2, 26 * k, 330 * k, 110 * k);
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        domeRect.left,
        domeRect.top,
        domeRect.right,
        domeRect.bottom,
        topLeft: const Radius.circular(60),
        topRight: const Radius.circular(60),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MawColors.domeTop, MawColors.domeBottom],
        ).createShader(domeRect),
    );

    // Eyes — 78x64 bumps at 50%-130 / 50%+52.
    final eyeW = 78 * k;
    final eyeH = 64 * k;
    final leftCx = w / 2 - 130 * k + eyeW / 2;
    final rightCx = w / 2 + 52 * k + eyeW / 2;

    for (final cx in [leftCx, rightCx]) {
      final bumpRect = Rect.fromCenter(
        center: Offset(cx, eyeH - 6 * k),
        width: eyeW,
        height: 58 * k,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bumpRect, Radius.elliptical(eyeW / 2, 58 * k)),
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.6),
            radius: 1.1,
            colors: [MawColors.bumpCenter, MawColors.bumpEdge],
          ).createShader(bumpRect),
      );

      final ballR = 17 * k;
      final ballC = Offset(cx, eyeH - 16 * k - ballR + 8 * k);
      if (blinking) {
        // Two-frame eyelid swap — a relaxed curved lid (happy arc when
        // the swallow was satisfying).
        final lid = Paint()
          ..color = MawColors.bumpEdge
          ..strokeWidth = 3.4 * k
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(cx - ballR * 0.8, ballC.dy + (satisfied ? 0 : 2))
          ..quadraticBezierTo(
            cx,
            ballC.dy + (satisfied ? -7 : 2),
            cx + ballR * 0.8,
            ballC.dy + (satisfied ? 0 : 2),
          );
        canvas.drawPath(path, lid);
      } else {
        canvas.drawCircle(
          ballC,
          ballR,
          Paint()
            ..color = MawColors.ball
            ..shader = null,
        );
        canvas.drawCircle(
          Offset(ballC.dx, ballC.dy - 6 * k),
          6.5 * k,
          Paint()..color = MawColors.pupil,
        );
        canvas.drawCircle(
          Offset(ballC.dx - 4 * k, ballC.dy - 9 * k),
          3.5 * k,
          Paint()..color = const Color(0xE6FFFFFF),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MawHeadPainter oldDelegate) =>
      oldDelegate.blinking != blinking || oldDelegate.satisfied != satisfied;
}

/// The tongue is the search bar — pink pill, magnifier glyph, "what fly do
/// you seek?".
class _TongueSearch extends StatelessWidget {
  const _TongueSearch({
    required this.controller,
    required this.hintColor,
    required this.cursor,
  });

  final TextEditingController controller;
  final Color hintColor;
  final Color cursor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MawColors.tongueTop, MawColors.tongueBottom],
        ),
        boxShadow: const [
          BoxShadow(
            color: MawColors.tongueShadow,
            offset: Offset(0, -4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 4),
            blurRadius: 10,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size.square(15),
            painter: _MagnifierGlyph(color: MawColors.tongueInk),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              style: ToadType.hand(15, color: MawColors.tongueInk),
              cursorColor: cursor,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'what fly do you seek?',
                hintStyle: ToadType.hand(15, color: MawColors.tongueInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagnifierGlyph extends CustomPainter {
  _MagnifierGlyph({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.42),
      size.width * 0.3,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.64, size.height * 0.64),
      Offset(size.width * 0.9, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MagnifierGlyph oldDelegate) => oldDelegate.color != color;
}

/// One app inside the maw — grid icon + pale label with shadow.
class _MawApp extends StatelessWidget {
  const _MawApp({required this.app, required this.onTap});

  final AppEntry app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          ToadAppIcon(
            app: app,
            size: 46,
            radius: 14,
            glyphSize: 20,
            shape: IconShape.squircle,
          ),
          const SizedBox(height: 5),
          ToadAppLabel(
            text: app.name,
            color: MawColors.gridInk,
            haloColor: Colors.transparent,
            fontSize: 10.5,
          ),
        ],
      ),
    );
  }
}

/// The A–Z rail hugging the jaw's right edge.
class _AzRail extends StatelessWidget {
  const _AzRail({
    required this.apps,
    required this.active,
    required this.onPick,
  });

  final List<AppEntry> apps;
  final String? active;
  final void Function(String letter) onPick;

  @override
  Widget build(BuildContext context) {
    final letters = [
      ...{for (final app in apps) app.name.toUpperCase()[0]},
    ]..sort();

    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final letter in letters)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(letter),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Text(
                  letter,
                  style: ToadType.hand(
                    11,
                    height: 1.05,
                    color: active == letter
                        ? Colors.white
                        : MawColors.railInk.withValues(
                            alpha: MawColors.railInk.a * 0.8,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

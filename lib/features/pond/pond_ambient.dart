/// Pond ambient engine — one ticker, one elapsed clock, zero widget
/// rebuilds. Every ambient loop reads the same `ValueListenable<Duration>`
/// and repaints through `CustomPainter(repaint: …)` or tiny AnimatedBuilder
/// transforms, exactly how the proposal keeps the loop cheap:
///
///   ripple idle   4.4 s loop · 3 concurrent max    (expanding strokes)
///   blink         random 5–8 s · 180 ms            (two-frame eyelid swap)
///   croak         tap · 900 ms once                (throat scale + ♪)
///   pad bob       4.8 s · phase-offset per pad     (transform-only)
///   toad bob      5.4 s day · slower at night
///   hop           320 ms arc                       (translate + squash)
///   flyby         every 45–90 s · 2.4 s crossing   (one sprite path)
///   fireflies     night · 7.5 s drift + 2.3 s flicker (five dots)
///   rain          manual toggle · 1.1 s drops
///
/// Calm pond (or an active battery guard on device) never starts the
/// ticker: "the whole loop freezes into a still painting — zero animation
/// cost".
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/device/battery_monitor.dart' show pondCalmProvider;
import '../../core/theme/toad_tokens.dart';

/// A raw-ticker provider: the pond owns its time. TickerMode cannot mute
/// these (the proposal's ambient loop is "always on" until Calm-pond
/// deliberately freezes it) — overlay/stack subtleties must never silently
/// freeze the resident.
class PondTickerProvider implements TickerProvider {
  final Set<Ticker> _tickers = <Ticker>{};
  bool _disposed = false;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(() {
      if (_disposed) {
        throw StateError('PondTickerProvider used after disposal');
      }
      return true;
    }());
    final ticker = Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }

  void dispose() {
    _disposed = true;
    for (final ticker in _tickers) {
      ticker.dispose();
    }
    _tickers.clear();
  }
}

/// Blink schedule — deterministic from the elapsed clock so painters and
/// tests agree without storing state: cycle i starts at t_i and blinks for
/// 180 ms; cycle lengths wander 5–8 s via a hash of the cycle index.
double blinkCycleLength(int cycle) {
  final h = math.Random(cycle * 7919 + 13).nextDouble();
  return 5.0 + h * 3.0; // seconds
}

/// True while the resident's eyelids are shut at [elapsed].
bool blinkAt(Duration elapsed) {
  var t = elapsed.inMicroseconds / 1e6;
  var cycle = 0;
  while (t >= blinkCycleLength(cycle)) {
    t -= blinkCycleLength(cycle);
    cycle++;
    if (cycle > 100000) return false; // safety valve for huge clocks
  }
  return t < ToadMotion.blink.inMicroseconds / 1e6;
}

/// Flyby schedule — the dragonfly crosses every 45–90 s for 2.4 s.
double flybyCycleLength(int cycle) {
  final h = math.Random(cycle * 104729 + 7).nextDouble();
  return 45.0 + h * 45.0;
}

/// Progress [0,1) through the current 2.4 s crossing, or null when the
/// dragonfly is resting between patrols.
double? flybyProgressAt(Duration elapsed) {
  var t = elapsed.inMicroseconds / 1e6;
  var cycle = 0;
  while (t >= flybyCycleLength(cycle)) {
    t -= flybyCycleLength(cycle);
    cycle++;
    if (cycle > 100000) return null;
  }
  const crossing = ToadMotion.flyby; // 2.4 s
  if (t >= crossing.inMicroseconds / 1e6) return null;
  return t / (crossing.inMicroseconds / 1e6);
}

/// Provides the ambient elapsed clock to every pond painter below it.
class PondAmbient extends ConsumerStatefulWidget {
  const PondAmbient({super.key, required this.builder});

  /// Frozen when calm — the painter still paints one still frame.
  final Widget Function(BuildContext context, ValueListenable<Duration> elapsed)
  builder;

  @override
  ConsumerState<PondAmbient> createState() => _PondAmbientState();
}

class _PondAmbientState extends ConsumerState<PondAmbient> {
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );
  final PondTickerProvider _vsync = PondTickerProvider();
  Ticker? _ticker;

  @override
  void dispose() {
    _ticker?.dispose();
    _vsync.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _sync(bool calm) {
    if (calm) {
      _ticker?.stop();
      _elapsed.value = const Duration(milliseconds: 900); // a pretty phase
      return;
    }
    _ticker ??= _vsync.createTicker((tick) => _elapsed.value = tick);
    if (!_ticker!.isActive) _ticker!.start();
  }

  @override
  Widget build(BuildContext context) {
    // Calm = the manual switch OR the drain (low-battery calm). Both go
    // through one provider so the pond never argues with the skin scope.
    final calm = ref.watch(pondCalmProvider);
    _sync(calm);
    return widget.builder(context, _elapsed);
  }
}

/// Deterministic pseudo-random per index — keeps painter schedules stable
/// across repaints without state.
int hashOf(int index) => (index * 2654435761) % 4294967296;

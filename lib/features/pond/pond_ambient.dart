library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/device/battery_monitor.dart' show pondCalmProvider;
import '../../core/theme/toad_tokens.dart';

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

double blinkCycleLength(int cycle) {
  final h = math.Random(cycle * 7919 + 13).nextDouble();
  return 5.0 + h * 3.0;
}

bool blinkAt(Duration elapsed) {
  var t = elapsed.inMicroseconds / 1e6;
  var cycle = 0;
  while (t >= blinkCycleLength(cycle)) {
    t -= blinkCycleLength(cycle);
    cycle++;
    if (cycle > 100000) return false;
  }
  return t < ToadMotion.blink.inMicroseconds / 1e6;
}

double flybyCycleLength(int cycle) {
  final h = math.Random(cycle * 104729 + 7).nextDouble();
  return 45.0 + h * 45.0;
}

double? flybyProgressAt(Duration elapsed) {
  var t = elapsed.inMicroseconds / 1e6;
  var cycle = 0;
  while (t >= flybyCycleLength(cycle)) {
    t -= flybyCycleLength(cycle);
    cycle++;
    if (cycle > 100000) return null;
  }
  const crossing = ToadMotion.flyby;
  if (t >= crossing.inMicroseconds / 1e6) return null;
  return t / (crossing.inMicroseconds / 1e6);
}

class PondAmbient extends ConsumerStatefulWidget {
  const PondAmbient({super.key, required this.builder});

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
      _elapsed.value = const Duration(milliseconds: 900);
      return;
    }
    _ticker ??= _vsync.createTicker((tick) => _elapsed.value = tick);
    if (!_ticker!.isActive) _ticker!.start();
  }

  @override
  Widget build(BuildContext context) {
    final calm = ref.watch(pondCalmProvider);
    _sync(calm);
    return widget.builder(context, _elapsed);
  }
}

int hashOf(int index) => (index * 2654435761) % 4294967296;

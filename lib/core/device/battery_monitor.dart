/// Battery drain system — the pond watches its own energy honestly.
///
/// The OS gives two facts (level, plugged) through the bridge; everything
/// else is computed here, in Dart:
///   · samples — every reading lands in a local history (persisted)
///   · drain rate — %/hour summed over unplugged spans only (a charge
///     session never pretends to be negative drain)
///   · runtime estimate — level ÷ drain, shown only when data exists
///   · low-battery calm — ≤ 15 % and unplugged freezes the pond exactly
///     like Calm-pond, when the switch allows it
///
/// Demo honesty: when the OS does not answer (no channel — tests, web,
/// desktop), the monitor runs a simulated pond battery and [demo] says
/// so; nothing pretends the numbers came from a real phone.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/launcher_settings.dart';
import 'device_bridge.dart';

const String _kPrefsKey = 'toadlauncher.battery.v1';

/// One local sample of the battery. History is ours, never the OS's.
@immutable
class BatterySample {
  const BatterySample({
    required this.at,
    required this.level,
    required this.charging,
  });

  final DateTime at;
  final int level;
  final bool charging;

  Map<String, Object> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'level': level,
    'charging': charging,
  };

  factory BatterySample.fromJson(Map<dynamic, dynamic> json) =>
      BatterySample(
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0,
        ),
        level: (json['level'] as num?)?.toInt() ?? -1,
        charging: (json['charging'] as bool?) ?? false,
      );
}

/// The whole battery picture the UI needs. Immutable; the monitor emits.
@immutable
class BatteryData {
  const BatteryData({
    this.level = -1,
    this.charging = false,
    this.full = false,
    this.demo = false,
    this.samples = const [],
  });

  /// 0–100; -1 = unknown (the OS has not answered yet).
  final int level;
  final bool charging;
  final bool full;

  /// True when the OS does not answer and the pond battery is simulated.
  final bool demo;

  /// Local history, oldest first, capped (see the monitor).
  final List<BatterySample> samples;

  BatteryData copyWith({
    int? level,
    bool? charging,
    bool? full,
    bool? demo,
    List<BatterySample>? samples,
  }) => BatteryData(
    level: level ?? this.level,
    charging: charging ?? this.charging,
    full: full ?? this.full,
    demo: demo ?? this.demo,
    samples: samples ?? this.samples,
  );

  /// %/hour lost while unplugged, averaged over the trailing window.
  /// Null when there is not enough unplugged history yet (< 12 min) —
  /// an estimate without data would be a lie.
  double? drainPerHour({Duration window = const Duration(hours: 6)}) {
    return BatteryMath.drainPerHour(samples, window: window);
  }

  /// Hours of unplugged runtime left at the measured rate. Null when no
  /// rate is known; capped at 99 so "47 hours" never becomes a dare.
  double? estimatedHoursLeft({Duration window = const Duration(hours: 6)}) {
    final rate = drainPerHour(window: window);
    if (rate == null || rate <= 0.01) return null;
    if (level < 0) return null;
    return (level / rate).clamp(0.0, 99.0);
  }

  /// Low battery: ≤ 15 % and unplugged. Drives low-battery calm.
  bool get lowBattery => level >= 0 && level <= 15 && !charging;

  /// Human one-liner for the hero pill — same honesty as everywhere.
  String get heroLine {
    if (level < 0) return 'battery unknown';
    if (full) return 'battery full';
    final rate = drainPerHour();
    if (charging) return 'battery $level% · charging';
    if (rate != null && rate >= 0.5) {
      return 'battery $level% · −${rate.toStringAsFixed(1)}%/h';
    }
    return 'battery $level%';
  }
}

/// Pure math so the monitor stays thin and tests stay cheap.
class BatteryMath {
  /// %/hour lost across unplugged spans in the trailing window. Charging
  /// spans are skipped, never counted as negative drain. Requires at
  /// least 12 minutes of unplugged span to answer.
  static double? drainPerHour(
    List<BatterySample> samples, {
    required Duration window,
  }) {
    if (samples.length < 2) return null;
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    double dropSum = 0;
    var spanSum = Duration.zero;
    for (var i = 1; i < samples.length; i++) {
      final prev = samples[i - 1];
      final cur = samples[i];
      if (prev.charging || cur.charging) continue;
      if (!cur.at.isAfter(cutoff)) continue; // span fully outside window
      final span = cur.at.difference(prev.at);
      if (span <= Duration.zero) continue;
      final drop = prev.level - cur.level;
      // A rise while unplugged is sensor noise or a gauge recalibration;
      // neither is drain — skip the drop but keep the span.
      dropSum += (drop > 0 ? drop : 0);
      spanSum += span;
    }
    final hours = spanSum.inMicroseconds / Duration.microsecondsPerHour;
    if (hours < 0.2) return null; // < 12 min of unplugged evidence
    return dropSum / hours;
  }
}

/// Riverpod state holder — samples, live status, drain math, demo sim.
class BatteryMonitor extends Notifier<BatteryData> {
  Timer? _demoTimer;
  bool _listenerAttached = false;
  bool _disposed = false;

  @override
  BatteryData build() {
    ref.onDispose(() => _disposed = true);
    _restore().then((_) {
      if (_disposed) return;
      _bootstrap();
    });
    // Answer immediately with "unknown" — the UI renders honestly while
    // the first reading arrives.
    return const BatteryData();
  }

  Future<void> _bootstrap() async {
    final bridge = ref.read(deviceBridgeProvider);
    final status = await bridge.batteryStatus();
    if (_disposed) return;

    if (status == null || status.level < 0) {
      // No OS behind the channel — run the honest simulated pond battery.
      _startDemo();
      return;
    }

    _attachListener(bridge);
    record(BatterySample(
      at: DateTime.now(),
      level: status.level,
      charging: status.charging,
    ));
  }

  void _attachListener(DeviceBridge bridge) {
    if (_listenerAttached) return;
    _listenerAttached = true;
    bridge.addBatteryListener(_onBattery);
    ref.onDispose(() => bridge.removeBatteryListener(_onBattery));
  }

  void _onBattery(BatteryStatus status) {
    if (status.level < 0) return;
    _cancelDemo();
    record(BatterySample(
      at: DateTime.now(),
      level: status.level,
      charging: status.charging,
    ));
  }

  // -------------------------------------------------------------------------
  // The honest simulated pond battery (demo mode)
  // -------------------------------------------------------------------------

  /// Demo battery: seeds ~5 h of gentle drain (88 → 78) so the drain
  /// page shows real math on first open, then keeps draining at ~8 %/h.
  void _startDemo() {
    if (_demoTimer != null) return;
    final now = DateTime.now();
    final seeded = <BatterySample>[
      for (var i = 5; i >= 0; i--)
        BatterySample(
          at: now.subtract(Duration(minutes: 50 * i)),
          level: 88 - (10 - (i * 2)).clamp(0, 10),
          charging: false,
        ),
    ];
    state = state.copyWith(
      level: 78,
      charging: false,
      full: false,
      demo: true,
      samples: [...state.samples, ...seeded],
    );
    _demoTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.level <= 0) return;
      // 8 %/h ≈ 1 % every 7.5 min; tick each minute, drain on every 8th.
      final last = state.samples.isNotEmpty ? state.samples.last : null;
      final step = last != null &&
          DateTime.now().difference(last.at).inMinutes >= 7;
      if (!step) return;
      record(BatterySample(
        at: DateTime.now(),
        level: (state.level - 1).clamp(0, 100),
        charging: false,
      ));
    });
    ref.onDispose(_cancelDemo);
  }

  void _cancelDemo() {
    _demoTimer?.cancel();
    _demoTimer = null;
  }

  // -------------------------------------------------------------------------
  // Recording + persistence
  // -------------------------------------------------------------------------

  /// Land a fresh reading: dedupe rapid repeats, cap the history, persist.
  void record(BatterySample sample) {
    final samples = List<BatterySample>.from(state.samples);
    final last = samples.isNotEmpty ? samples.last : null;
    // The OS can re-broadcast the same reading; identical consecutive
    // samples within 90 s are one sample.
    if (last != null &&
        last.level == sample.level &&
        last.charging == sample.charging &&
        sample.at.difference(last.at).inSeconds < 90) {
      return;
    }
    samples.add(sample);
    while (samples.length > 240) {
      samples.removeAt(0);
    }

    state = state.copyWith(
      level: sample.level,
      charging: sample.charging,
      demo: state.demo,
      samples: samples,
    );
    _persist(samples);
  }

  Future<void> _persist(List<BatterySample> samples) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode([for (final s in samples) s.toJson()]),
      );
    } catch (_) {
      // Offline-first promise: history loss must never crash the launcher.
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<dynamic, dynamic>>();
      final samples = [
        for (final item in list)
          BatterySample.fromJson(item),
      ]..removeWhere((s) => s.level < 0 || s.level > 100);
      if (samples.isEmpty) return;
      state = state.copyWith(samples: samples);
    } catch (_) {
      // Corrupt history = no history; the monitor starts fresh.
    }
  }

  /// Settings → Battery: forget the history and start over.
  Future<void> clearHistory() async {
    state = state.copyWith(samples: const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
    } catch (_) {}
  }
}

/// The monitor as a provider.
final NotifierProvider<BatteryMonitor, BatteryData> batteryMonitorProvider =
    NotifierProvider<BatteryMonitor, BatteryData>(BatteryMonitor.new);

/// Calm decision for the pond, shared by the skin scope (night falls) and
/// the ambient ticker (loop freezes): the manual switch OR the drain.
final Provider<bool> pondCalmProvider = Provider<bool>((ref) {
  final settings = ref.watch(launcherSettingsProvider);
  if (settings.calmPond) return true;
  if (!settings.lowBatteryCalm) return false;
  final battery = ref.watch(batteryMonitorProvider);
  return battery.lowBattery;
});

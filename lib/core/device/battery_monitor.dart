library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/launcher_settings.dart';
import 'device_bridge.dart';

const String _kPrefsKey = 'toadlauncher.battery.v1';

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

@immutable
class BatteryData {
  const BatteryData({
    this.level = -1,
    this.charging = false,
    this.full = false,
    this.demo = false,
    this.samples = const [],
  });

  final int level;
  final bool charging;
  final bool full;

  final bool demo;

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

  double? drainPerHour({Duration window = const Duration(hours: 6)}) {
    return BatteryMath.drainPerHour(samples, window: window);
  }

  double? estimatedHoursLeft({Duration window = const Duration(hours: 6)}) {
    final rate = drainPerHour(window: window);
    if (rate == null || rate <= 0.01) return null;
    if (level < 0) return null;
    return (level / rate).clamp(0.0, 99.0);
  }

  bool get lowBattery => level >= 0 && level <= 15 && !charging;

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

class BatteryMath {
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
      if (!cur.at.isAfter(cutoff)) continue;
      final span = cur.at.difference(prev.at);
      if (span <= Duration.zero) continue;
      final drop = prev.level - cur.level;
      dropSum += (drop > 0 ? drop : 0);
      spanSum += span;
    }
    final hours = spanSum.inMicroseconds / Duration.microsecondsPerHour;
    if (hours < 0.2) return null;
    return dropSum / hours;
  }
}

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
    return const BatteryData();
  }

  Future<void> _bootstrap() async {
    final bridge = ref.read(deviceBridgeProvider);
    final status = await bridge.batteryStatus();
    if (_disposed) return;

    if (status == null || status.level < 0) {
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

  void record(BatterySample sample) {
    final samples = List<BatterySample>.from(state.samples);
    final last = samples.isNotEmpty ? samples.last : null;
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
    }
  }

  Future<void> clearHistory() async {
    state = state.copyWith(samples: const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
    } catch (_) {}
  }
}

final NotifierProvider<BatteryMonitor, BatteryData> batteryMonitorProvider =
    NotifierProvider<BatteryMonitor, BatteryData>(BatteryMonitor.new);

final Provider<bool> pondCalmProvider = Provider<bool>((ref) {
  final settings = ref.watch(launcherSettingsProvider);
  if (settings.calmPond) return true;
  if (!settings.lowBatteryCalm) return false;
  final battery = ref.watch(batteryMonitorProvider);
  return battery.lowBattery;
});

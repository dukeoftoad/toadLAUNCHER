/// toadLAUNCHER settings — Riverpod state with persistence.
///
/// Every value maps 1:1 to a switch/row in the design proposal:
/// Gestures sub-page, Wallpaper & style, Home screen, Dock & drawer,
/// Notifications, Privacy.
library;

import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/skins.dart';
import '../theme/toad_tokens.dart';

/// Accent options from Wallpaper & style (screen 9).
enum AccentOption { toad, clay, steel, plum, gold, ink }

extension AccentOptionX on AccentOption {
  Color get color => kAccentOptions[index];
  String get label => switch (this) {
        AccentOption.toad => 'Toad green',
        AccentOption.clay => 'Clay',
        AccentOption.steel => 'Steel',
        AccentOption.plum => 'Plum',
        AccentOption.gold => 'Gold',
        AccentOption.ink => 'Ink',
      };
}

/// The full settings model. Immutable; patch via [LauncherSettingsController].
@immutable
class LauncherSettings {
  const LauncherSettings({
    this.skinMode = SkinMode.system,
    this.pondPro = false,
    this.accent = AccentOption.toad,
    this.iconShape = IconShape.squircle,
    this.gridColumns = 4,
    this.showMemoriesCard = true,
    this.swipeUpDrawer = true,
    this.doubleTapSleep = true,
    this.swipeDownNotifications = true,
    this.twoFingerScreenshot = false,
    this.pinchEditMode = true,
    this.dockAreaSwipeSearch = false,
    this.notificationDots = true,
    this.badges = false,
    this.calmPond = false,
    this.pondRain = false,
    this.sunsetHour = 19,
    this.sunsetMinute = 30,
    this.sunriseHour = 6,
    this.sunriseMinute = 30,
  });

  // Wallpaper & style.
  final SkinMode skinMode;
  final bool pondPro;
  final AccentOption accent;
  final IconShape iconShape;

  // Home screen.
  final int gridColumns; // 4 default, 5 optional
  final bool showMemoriesCard; // hero widget removable

  // Gestures sub-page.
  final bool swipeUpDrawer;
  final bool doubleTapSleep; // ON per mockup
  final bool swipeDownNotifications;
  final bool twoFingerScreenshot; // OFF by default
  final bool pinchEditMode;
  final bool dockAreaSwipeSearch; // OFF by default

  // Notifications.
  final bool notificationDots;
  final bool badges;

  // Pond pack.
  final bool calmPond; // freezes ambient loop (accessibility)
  final bool pondRain; // manual weather toggle — never a weather feed

  // Day/night anchors (clock-driven, never location).
  final int sunsetHour;
  final int sunsetMinute;
  final int sunriseHour;
  final int sunriseMinute;

  LauncherSettings copyWith({
    SkinMode? skinMode,
    bool? pondPro,
    AccentOption? accent,
    IconShape? iconShape,
    int? gridColumns,
    bool? showMemoriesCard,
    bool? swipeUpDrawer,
    bool? doubleTapSleep,
    bool? swipeDownNotifications,
    bool? twoFingerScreenshot,
    bool? pinchEditMode,
    bool? dockAreaSwipeSearch,
    bool? notificationDots,
    bool? badges,
    bool? calmPond,
    bool? pondRain,
    int? sunsetHour,
    int? sunsetMinute,
    int? sunriseHour,
    int? sunriseMinute,
  }) {
    return LauncherSettings(
      skinMode: skinMode ?? this.skinMode,
      pondPro: pondPro ?? this.pondPro,
      accent: accent ?? this.accent,
      iconShape: iconShape ?? this.iconShape,
      gridColumns: gridColumns ?? this.gridColumns,
      showMemoriesCard: showMemoriesCard ?? this.showMemoriesCard,
      swipeUpDrawer: swipeUpDrawer ?? this.swipeUpDrawer,
      doubleTapSleep: doubleTapSleep ?? this.doubleTapSleep,
      swipeDownNotifications:
          swipeDownNotifications ?? this.swipeDownNotifications,
      twoFingerScreenshot: twoFingerScreenshot ?? this.twoFingerScreenshot,
      pinchEditMode: pinchEditMode ?? this.pinchEditMode,
      dockAreaSwipeSearch: dockAreaSwipeSearch ?? this.dockAreaSwipeSearch,
      notificationDots: notificationDots ?? this.notificationDots,
      badges: badges ?? this.badges,
      calmPond: calmPond ?? this.calmPond,
      pondRain: pondRain ?? this.pondRain,
      sunsetHour: sunsetHour ?? this.sunsetHour,
      sunsetMinute: sunsetMinute ?? this.sunsetMinute,
      sunriseHour: sunriseHour ?? this.sunriseHour,
      sunriseMinute: sunriseMinute ?? this.sunriseMinute,
    );
  }

  Map<String, Object> toJson() => {
        'skinMode': skinMode.index,
        'pondPro': pondPro,
        'accent': accent.index,
        'iconShape': iconShape.index,
        'gridColumns': gridColumns,
        'showMemoriesCard': showMemoriesCard,
        'swipeUpDrawer': swipeUpDrawer,
        'doubleTapSleep': doubleTapSleep,
        'swipeDownNotifications': swipeDownNotifications,
        'twoFingerScreenshot': twoFingerScreenshot,
        'pinchEditMode': pinchEditMode,
        'dockAreaSwipeSearch': dockAreaSwipeSearch,
        'notificationDots': notificationDots,
        'badges': badges,
        'calmPond': calmPond,
        'pondRain': pondRain,
        'sunsetHour': sunsetHour,
        'sunsetMinute': sunsetMinute,
        'sunriseHour': sunriseHour,
        'sunriseMinute': sunriseMinute,
      };

  factory LauncherSettings.fromJson(Map<String, Object?> json) {
    return LauncherSettings(
      skinMode: SkinMode.values[(json['skinMode'] as int?) ?? 0],
      pondPro: (json['pondPro'] as bool?) ?? false,
      accent: AccentOption.values[(json['accent'] as int?) ?? 0],
      iconShape: IconShape.values[(json['iconShape'] as int?) ?? 0],
      gridColumns: (json['gridColumns'] as int?) ?? 4,
      showMemoriesCard: (json['showMemoriesCard'] as bool?) ?? true,
      swipeUpDrawer: (json['swipeUpDrawer'] as bool?) ?? true,
      doubleTapSleep: (json['doubleTapSleep'] as bool?) ?? true,
      swipeDownNotifications: (json['swipeDownNotifications'] as bool?) ?? true,
      twoFingerScreenshot: (json['twoFingerScreenshot'] as bool?) ?? false,
      pinchEditMode: (json['pinchEditMode'] as bool?) ?? true,
      dockAreaSwipeSearch: (json['dockAreaSwipeSearch'] as bool?) ?? false,
      notificationDots: (json['notificationDots'] as bool?) ?? true,
      badges: (json['badges'] as bool?) ?? false,
      calmPond: (json['calmPond'] as bool?) ?? false,
      pondRain: (json['pondRain'] as bool?) ?? false,
      sunsetHour: (json['sunsetHour'] as int?) ?? 19,
      sunsetMinute: (json['sunsetMinute'] as int?) ?? 30,
      sunriseHour: (json['sunriseHour'] as int?) ?? 6,
      sunriseMinute: (json['sunriseMinute'] as int?) ?? 30,
    );
  }
}

const String _kPrefsKey = 'toadlauncher.settings.v1';

/// Settings controller: loads on init, applies live, persists each patch.
class LauncherSettingsController extends Notifier<LauncherSettings> {
  @override
  LauncherSettings build() {
    _restore();
    return const LauncherSettings();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) return;
      // Only apply if user has not already patched during this session.
      if (state != const LauncherSettings()) return;
      state = LauncherSettings.fromJson(
        (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, Object?>(),
      );
    } catch (_) {
      // Offline-first promise: settings loss must never crash the launcher.
    }
  }

  /// Replace the whole model and persist. "changes apply live".
  Future<void> patch(LauncherSettings next) async {
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(next.toJson()));
    } catch (_) {
      // Persistence is best-effort; the session keeps running.
    }
  }

  void setSkinMode(SkinMode mode) => patch(state.copyWith(skinMode: mode));
  void setPondPro(bool v) => patch(state.copyWith(pondPro: v));
  void setAccent(AccentOption a) => patch(state.copyWith(accent: a));
  void setIconShape(IconShape s) => patch(state.copyWith(iconShape: s));
  void setGridColumns(int c) =>
      patch(state.copyWith(gridColumns: c.clamp(4, 5)));
  void setShowMemoriesCard(bool v) =>
      patch(state.copyWith(showMemoriesCard: v));
  void setCalmPond(bool v) => patch(state.copyWith(calmPond: v));
  void setPondRain(bool v) => patch(state.copyWith(pondRain: v));
}

/// Ticker for the hero clock and pond day/night anchors.
/// Emits every 5 seconds — minute-precision UI never lags, cost is nil.
final StreamProvider<DateTime> clockProvider = StreamProvider<DateTime>(
  (ref) async* {
    while (true) {
      yield DateTime.now();
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  },
);

final NotifierProvider<LauncherSettingsController, LauncherSettings>
    launcherSettingsProvider = NotifierProvider<LauncherSettingsController,
        LauncherSettings>(LauncherSettingsController.new);

library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reliability/safe_store.dart';
import '../theme/skins.dart';
import '../theme/toad_tokens.dart';

enum AccentOption { toad, clay, steel, plum, gold, ink }

enum HeroClockStyle { hand, analog, word, flip }

extension HeroClockStyleX on HeroClockStyle {
  String get label => switch (this) {
    HeroClockStyle.hand => 'Hand-lettered',
    HeroClockStyle.analog => 'Analog dial',
    HeroClockStyle.word => 'Word clock',
    HeroClockStyle.flip => 'Flip cards',
  };
}

enum ClockHourFormat { system, h12, h24 }

extension ClockHourFormatX on ClockHourFormat {
  String get label => switch (this) {
    ClockHourFormat.system => 'Follow system',
    ClockHourFormat.h12 => '12-hour',
    ClockHourFormat.h24 => '24-hour',
  };
}

enum UpdatePolicy { off, manual, daily, weekly }

extension UpdatePolicyX on UpdatePolicy {
  String get label => switch (this) {
    UpdatePolicy.off => 'Never (off)',
    UpdatePolicy.manual => 'Manual only',
    UpdatePolicy.daily => 'Once a day',
    UpdatePolicy.weekly => 'Once a week',
  };

  Duration? get minInterval => switch (this) {
    UpdatePolicy.off => null,
    UpdatePolicy.manual => null,
    UpdatePolicy.daily => const Duration(days: 1),
    UpdatePolicy.weekly => const Duration(days: 7),
  };
}

extension WallpaperX on int {
  String get wallpaperLabel => switch (this) {
    0 => 'Sage',
    1 => 'Gold',
    2 => 'Rose',
    3 => 'Steel',
    4 => 'Charcoal',
    5 => 'AMOLED',
    6 => 'Forest',
    _ => 'Paper',
  };
}

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
    this.batteryGuard = true,
    this.sunsetHour = 19,
    this.sunsetMinute = 30,
    this.sunriseHour = 6,
    this.sunriseMinute = 30,
    this.wallpaperIndex = 0,
    this.clockSpanW = 4,
    this.clockSpanH = 1,
    this.editHintDismissed = false,
    this.drawerSearch = true,
    this.drawerRecents = true,
    this.deviceMode = true,
    this.autoUpdateCheck = true,
    this.updatePolicy = UpdatePolicy.daily,
    this.usageRecentsOptIn = false,
    this.introSeen = false,
    this.lowBatteryCalm = true,
    this.clockStyle = HeroClockStyle.hand,
    this.clockHourFormat = ClockHourFormat.system,
    this.themedIcons = false,
    this.focusMinutes = 25,
  });

  final SkinMode skinMode;
  final bool pondPro;
  final AccentOption accent;
  final IconShape iconShape;

  final int gridColumns;
  final bool showMemoriesCard;

  final bool swipeUpDrawer;
  final bool doubleTapSleep;
  final bool swipeDownNotifications;
  final bool twoFingerScreenshot;
  final bool pinchEditMode;
  final bool dockAreaSwipeSearch;

  final bool notificationDots;
  final bool badges;

  final bool calmPond;
  final bool pondRain;

  final bool batteryGuard;

  final int sunsetHour;
  final int sunsetMinute;
  final int sunriseHour;
  final int sunriseMinute;

  final int wallpaperIndex;

  final int clockSpanW;
  final int clockSpanH;

  final bool editHintDismissed;

  final bool drawerSearch;
  final bool drawerRecents;

  final bool deviceMode;

  final bool autoUpdateCheck;

  final UpdatePolicy updatePolicy;

  final HeroClockStyle clockStyle;

  final ClockHourFormat clockHourFormat;

  final bool themedIcons;

  final int focusMinutes;

  final bool usageRecentsOptIn;

  final bool introSeen;

  final bool lowBatteryCalm;

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
    bool? batteryGuard,
    int? sunsetHour,
    int? sunsetMinute,
    int? sunriseHour,
    int? sunriseMinute,
    int? wallpaperIndex,
    int? clockSpanW,
    int? clockSpanH,
    bool? editHintDismissed,
    bool? drawerSearch,
    bool? drawerRecents,
    bool? deviceMode,
    bool? autoUpdateCheck,
    UpdatePolicy? updatePolicy,
    bool? usageRecentsOptIn,
    bool? introSeen,
    bool? lowBatteryCalm,
    HeroClockStyle? clockStyle,
    ClockHourFormat? clockHourFormat,
    bool? themedIcons,
    int? focusMinutes,
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
      batteryGuard: batteryGuard ?? this.batteryGuard,
      sunsetHour: sunsetHour ?? this.sunsetHour,
      sunsetMinute: sunsetMinute ?? this.sunsetMinute,
      sunriseHour: sunriseHour ?? this.sunriseHour,
      sunriseMinute: sunriseMinute ?? this.sunriseMinute,
      wallpaperIndex: wallpaperIndex ?? this.wallpaperIndex,
      clockSpanW: clockSpanW ?? this.clockSpanW,
      clockSpanH: clockSpanH ?? this.clockSpanH,
      editHintDismissed: editHintDismissed ?? this.editHintDismissed,
      drawerSearch: drawerSearch ?? this.drawerSearch,
      drawerRecents: drawerRecents ?? this.drawerRecents,
      deviceMode: deviceMode ?? this.deviceMode,
      autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
      updatePolicy: updatePolicy ?? this.updatePolicy,
      usageRecentsOptIn: usageRecentsOptIn ?? this.usageRecentsOptIn,
      introSeen: introSeen ?? this.introSeen,
      lowBatteryCalm: lowBatteryCalm ?? this.lowBatteryCalm,
      clockStyle: clockStyle ?? this.clockStyle,
      clockHourFormat: clockHourFormat ?? this.clockHourFormat,
      themedIcons: themedIcons ?? this.themedIcons,
      focusMinutes: focusMinutes ?? this.focusMinutes,
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
    'batteryGuard': batteryGuard,
    'sunsetHour': sunsetHour,
    'sunsetMinute': sunsetMinute,
    'sunriseHour': sunriseHour,
    'sunriseMinute': sunriseMinute,
    'wallpaperIndex': wallpaperIndex,
    'clockSpanW': clockSpanW,
    'clockSpanH': clockSpanH,
    'editHintDismissed': editHintDismissed,
    'drawerSearch': drawerSearch,
    'drawerRecents': drawerRecents,
    'deviceMode': deviceMode,
    'autoUpdateCheck': autoUpdateCheck,
    'updatePolicy': updatePolicy.index,
    'usageRecentsOptIn': usageRecentsOptIn,
    'introSeen': introSeen,
    'lowBatteryCalm': lowBatteryCalm,
    'clockStyle': clockStyle.index,
    'clockHourFormat': clockHourFormat.index,
    'themedIcons': themedIcons,
    'focusMinutes': focusMinutes,
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
      batteryGuard: (json['batteryGuard'] as bool?) ?? true,
      sunsetHour: (json['sunsetHour'] as int?) ?? 19,
      sunsetMinute: (json['sunsetMinute'] as int?) ?? 30,
      sunriseHour: (json['sunriseHour'] as int?) ?? 6,
      sunriseMinute: (json['sunriseMinute'] as int?) ?? 30,
      wallpaperIndex: (json['wallpaperIndex'] as int?) ?? 0,
      clockSpanW: (json['clockSpanW'] as int?) ?? 4,
      clockSpanH: (json['clockSpanH'] as int?) ?? 1,
      editHintDismissed: (json['editHintDismissed'] as bool?) ?? false,
      drawerSearch: (json['drawerSearch'] as bool?) ?? true,
      drawerRecents: (json['drawerRecents'] as bool?) ?? true,
      deviceMode: (json['deviceMode'] as bool?) ?? true,
      autoUpdateCheck: (json['autoUpdateCheck'] as bool?) ?? true,
      updatePolicy: UpdatePolicy.values[(json['updatePolicy'] as int?) ?? 2],
      usageRecentsOptIn: (json['usageRecentsOptIn'] as bool?) ?? false,
      introSeen: (json['introSeen'] as bool?) ?? false,
      lowBatteryCalm: (json['lowBatteryCalm'] as bool?) ?? true,
      clockStyle: HeroClockStyle.values[(json['clockStyle'] as int?) ?? 0],
      clockHourFormat: ClockHourFormat.values[(json['clockHourFormat'] as int?) ?? 0],
      themedIcons: (json['themedIcons'] as bool?) ?? false,
      focusMinutes: ((json['focusMinutes'] as num?)?.toInt() ?? 25).clamp(5, 120),
    );
  }
}

const String _kPrefsKey = 'toadlauncher.settings.v1';
final SafeStore _kSettingsStore = SafeStore(_kPrefsKey, schemaVersion: 2);

class LauncherSettingsController extends Notifier<LauncherSettings> {
  @override
  LauncherSettings build() {
    _restore();
    return const LauncherSettings();
  }

  Future<void> _restore() async {
    try {
      final restored = await _kSettingsStore.read<LauncherSettings>(
        (json) {
          if (json is! Map) return null;
          try {
            return LauncherSettings.fromJson(
              json.cast<String, Object?>(),
            );
          } catch (_) {
            return null;
          }
        },
      );
      if (restored == null) return;
      if (state != const LauncherSettings()) return;
      state = restored;
    } catch (_) {
    }
  }

  Future<void> patch(LauncherSettings next) async {
    state = next;
    try {
      await _kSettingsStore.write(next.toJson());
    } catch (_) {
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
  void setBatteryGuard(bool v) => patch(state.copyWith(batteryGuard: v));
  void setWallpaperIndex(int i) =>
      patch(state.copyWith(wallpaperIndex: i.clamp(0, 6)));
  void setClockSpan({int? w, int? h}) => patch(
    state.copyWith(
      clockSpanW: (w ?? state.clockSpanW).clamp(2, 4),
      clockSpanH: (h ?? state.clockSpanH).clamp(1, 4),
    ),
  );
  void setEditHintDismissed() => patch(state.copyWith(editHintDismissed: true));
  void setDrawerSearch(bool v) => patch(state.copyWith(drawerSearch: v));
  void setDrawerRecents(bool v) => patch(state.copyWith(drawerRecents: v));
  void setNotificationDots(bool v) =>
      patch(state.copyWith(notificationDots: v));
  void setBadges(bool v) => patch(state.copyWith(badges: v));

  void patchSwipeUpDrawer(bool v) => patch(state.copyWith(swipeUpDrawer: v));
  void patchDoubleTapSleep(bool v) => patch(state.copyWith(doubleTapSleep: v));
  void patchSwipeDownNotifications(bool v) =>
      patch(state.copyWith(swipeDownNotifications: v));
  void patchTwoFingerScreenshot(bool v) =>
      patch(state.copyWith(twoFingerScreenshot: v));
  void patchPinchEditMode(bool v) => patch(state.copyWith(pinchEditMode: v));
  void patchDockAreaSwipeSearch(bool v) =>
      patch(state.copyWith(dockAreaSwipeSearch: v));

  void setDeviceMode(bool v) => patch(state.copyWith(deviceMode: v));
  void setAutoUpdateCheck(bool v) => patch(state.copyWith(autoUpdateCheck: v));
  void setUsageRecentsOptIn(bool v) =>
      patch(state.copyWith(usageRecentsOptIn: v));

  void setUpdatePolicy(UpdatePolicy p) => patch(state.copyWith(updatePolicy: p));

  void setClockStyle(HeroClockStyle s) => patch(state.copyWith(clockStyle: s));
  void setClockHourFormat(ClockHourFormat f) =>
      patch(state.copyWith(clockHourFormat: f));

  void setThemedIcons(bool v) => patch(state.copyWith(themedIcons: v));

  void setFocusMinutes(int m) =>
      patch(state.copyWith(focusMinutes: m.clamp(5, 120)));

  void setIntroSeen() => patch(state.copyWith(introSeen: true));

  void replayIntro() => patch(state.copyWith(introSeen: false));

  void setLowBatteryCalm(bool v) =>
      patch(state.copyWith(lowBatteryCalm: v));
}

final StreamProvider<DateTime> clockProvider = StreamProvider<DateTime>((
  ref,
) async* {
  while (true) {
    yield DateTime.now();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final NotifierProvider<LauncherSettingsController, LauncherSettings>
launcherSettingsProvider =
    NotifierProvider<LauncherSettingsController, LauncherSettings>(
      LauncherSettingsController.new,
    );

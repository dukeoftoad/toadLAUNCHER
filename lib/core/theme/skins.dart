/// Skin enums + resolution — neutral module shared by settings and theme.
library;

import 'dart:ui' show Brightness;

import 'toad_tokens.dart';

/// Appearance modes selected in Wallpaper & style.
enum SkinMode { system, light, dark, amoled }

/// Fully-resolved skin — what a screen should paint with right now.
enum ResolvedSkin { light, dark, amoled, pondDay, pondNight }

/// Icon shape override applied to adaptive icons uniformly.
enum IconShape { squircle, circle, rounded }

/// Skin predicates used across the app.
extension ResolvedSkinX on ResolvedSkin {
  bool get isPond =>
      this == ResolvedSkin.pondDay || this == ResolvedSkin.pondNight;
}

/// Resolve the effective skin from settings + system brightness + clock.
///
/// Day/night on Pond Pro is clock-driven only: after the sunset anchor
/// (default 19:30) until the sunrise anchor (default 6:30).
ResolvedSkin resolveSkin({
  required SkinMode mode,
  required bool pondPro,
  required Brightness systemBrightness,
  required DateTime now,
  required int sunsetHour,
  required int sunsetMinute,
  required int sunriseHour,
  required int sunriseMinute,
}) {
  if (pondPro) {
    final minutes = now.hour * 60 + now.minute;
    final sunset = sunsetHour * 60 + sunsetMinute;
    final sunrise = sunriseHour * 60 + sunriseMinute;
    final isNight = minutes >= sunset || minutes < sunrise;
    return isNight ? ResolvedSkin.pondNight : ResolvedSkin.pondDay;
  }
  switch (mode) {
    case SkinMode.light:
      return ResolvedSkin.light;
    case SkinMode.dark:
      return ResolvedSkin.dark;
    case SkinMode.amoled:
      return ResolvedSkin.amoled;
    case SkinMode.system:
      return systemBrightness == Brightness.dark
          ? ResolvedSkin.dark
          : ResolvedSkin.light;
  }
}

/// Base palette for a resolved skin (before user accent override).
ToadPalette paletteFor(ResolvedSkin skin) {
  switch (skin) {
    case ResolvedSkin.light:
      return kLightPalette;
    case ResolvedSkin.dark:
      return kDarkPalette;
    case ResolvedSkin.amoled:
      return kAmoledPalette;
    case ResolvedSkin.pondDay:
      return kLightPalette; // Pond surfaces still use sketchbook cards.
    case ResolvedSkin.pondNight:
      return kDarkPalette;
  }
}

PondPalette pondPaletteFor(ResolvedSkin skin) =>
    skin == ResolvedSkin.pondNight ? kPondNight : kPondDay;

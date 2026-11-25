library;

import 'dart:ui' show Brightness;

import 'toad_tokens.dart';

enum SkinMode { system, light, dark, amoled }

enum ResolvedSkin { light, dark, amoled, pondDay, pondNight }

enum IconShape { squircle, circle, rounded }

extension ResolvedSkinX on ResolvedSkin {
  bool get isPond =>
      this == ResolvedSkin.pondDay || this == ResolvedSkin.pondNight;
}

ResolvedSkin resolveSkin({
  required SkinMode mode,
  required bool pondPro,
  required Brightness systemBrightness,
  required DateTime now,
  required int sunsetHour,
  required int sunsetMinute,
  required int sunriseHour,
  required int sunriseMinute,
  bool pondCalm = false,
}) {
  if (pondPro) {
    if (pondCalm) return ResolvedSkin.pondNight;
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

ToadPalette paletteFor(ResolvedSkin skin) {
  switch (skin) {
    case ResolvedSkin.light:
      return kLightPalette;
    case ResolvedSkin.dark:
      return kDarkPalette;
    case ResolvedSkin.amoled:
      return kAmoledPalette;
    case ResolvedSkin.pondDay:
      return kLightPalette;
    case ResolvedSkin.pondNight:
      return kDarkPalette;
  }
}

PondPalette pondPaletteFor(ResolvedSkin skin) =>
    skin == ResolvedSkin.pondNight ? kPondNight : kPondDay;

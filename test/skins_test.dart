/// Skin resolution tests — the theme engine's decision table.
library;

import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:toadlauncher/core/theme/skins.dart';

void main() {
  final noon = DateTime(2026, 11, 24, 12, 0);
  final evening = DateTime(2026, 11, 24, 20, 0);
  final night = DateTime(2026, 11, 24, 23, 58);
  final earlyMorning = DateTime(2026, 11, 24, 5, 0);

  ResolvedSkin resolve({
    SkinMode mode = SkinMode.system,
    bool pondPro = false,
    Brightness brightness = Brightness.light,
    DateTime? now,
  }) => resolveSkin(
    mode: mode,
    pondPro: pondPro,
    systemBrightness: brightness,
    now: now ?? noon,
    sunsetHour: 19,
    sunsetMinute: 30,
    sunriseHour: 6,
    sunriseMinute: 30,
  );

  test('explicit modes override system', () {
    expect(
      resolve(mode: SkinMode.light, brightness: Brightness.dark),
      ResolvedSkin.light,
    );
    expect(
      resolve(mode: SkinMode.dark, brightness: Brightness.light),
      ResolvedSkin.dark,
    );
    expect(resolve(mode: SkinMode.amoled), ResolvedSkin.amoled);
  });

  test('system mode follows platform brightness', () {
    expect(
      resolve(mode: SkinMode.system, brightness: Brightness.dark),
      ResolvedSkin.dark,
    );
    expect(
      resolve(mode: SkinMode.system, brightness: Brightness.light),
      ResolvedSkin.light,
    );
  });

  test('pond day before sunset anchor', () {
    expect(resolve(pondPro: true, now: noon), ResolvedSkin.pondDay);
    expect(
      resolve(pondPro: true, now: DateTime(2026, 11, 24, 19, 29)),
      ResolvedSkin.pondDay,
    );
  });

  test('pond night from sunset anchor onward', () {
    // Exactly 19:30 — night falls.
    expect(
      resolve(pondPro: true, now: DateTime(2026, 11, 24, 19, 30)),
      ResolvedSkin.pondNight,
    );
    expect(resolve(pondPro: true, now: evening), ResolvedSkin.pondNight);
    expect(resolve(pondPro: true, now: night), ResolvedSkin.pondNight);
  });

  test('pond night wraps past midnight until sunrise anchor', () {
    expect(resolve(pondPro: true, now: earlyMorning), ResolvedSkin.pondNight);
    expect(
      resolve(pondPro: true, now: DateTime(2026, 11, 24, 6, 29)),
      ResolvedSkin.pondNight,
    );
    expect(
      resolve(pondPro: true, now: DateTime(2026, 11, 24, 6, 30)),
      ResolvedSkin.pondDay,
    );
  });

  test('pond pro wins over explicit mode (scene skin)', () {
    expect(
      resolve(pondPro: true, mode: SkinMode.amoled, now: night),
      ResolvedSkin.pondNight,
    );
  });

  test('palette dispatch pairs pond with sketchbook card palettes', () {
    expect(paletteFor(ResolvedSkin.pondDay), paletteFor(ResolvedSkin.light));
    expect(paletteFor(ResolvedSkin.pondNight), paletteFor(ResolvedSkin.dark));
    expect(pondPaletteFor(ResolvedSkin.pondNight).isNight, isTrue);
    expect(pondPaletteFor(ResolvedSkin.pondDay).isNight, isFalse);
  });
}

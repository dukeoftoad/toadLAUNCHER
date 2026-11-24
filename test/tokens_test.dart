/// Token contract tests — the spec hex values are the law.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toadlauncher/core/theme/toad_tokens.dart';

void main() {
  group('sketchbook palettes', () {
    test('light matches proposal section 2', () {
      expect(kLightPalette.paper, const Color(0xFFF7F1E6));
      expect(kLightPalette.surface, const Color(0xFFFFFCF5));
      expect(kLightPalette.surface2, const Color(0xFFF1E9D8));
      expect(kLightPalette.ink, const Color(0xFF2B2924));
      expect(kLightPalette.inkSoft, const Color(0xFF7A7365));
      expect(kLightPalette.accent, const Color(0xFF4F7A38));
      expect(kLightPalette.accentWash, const Color(0xFFE9EFDF));
      expect(kLightPalette.hairline, const Color(0xFFE5DCC8));
      expect(kLightPalette.gold, const Color(0xFFC9A227));
      expect(kLightPalette.danger, const Color(0xFFB4552D));
    });

    test('dark matches proposal section 2', () {
      expect(kDarkPalette.paper, const Color(0xFF171613));
      expect(kDarkPalette.surface, const Color(0xFF201E1A));
      expect(kDarkPalette.surface2, const Color(0xFF2A2723));
      expect(kDarkPalette.ink, const Color(0xFFEFE9DB));
      expect(kDarkPalette.accent, const Color(0xFF93C46D));
      expect(kDarkPalette.accentWash, const Color(0xFF2E3427));
      expect(kDarkPalette.hairline, const Color(0xFF3A362F));
    });

    test('amoled is true black with deep surfaces', () {
      expect(kAmoledPalette.paper, const Color(0xFF000000));
      expect(kAmoledPalette.surface, const Color(0xFF12110F));
      expect(kAmoledPalette.hairline, const Color(0xFF2A2824));
    });

    test('glow strength dial 1 / .5 / .35', () {
      expect(kLightPalette.wallpaperGlowStrength, 1.0);
      expect(kDarkPalette.wallpaperGlowStrength, 0.5);
      expect(kAmoledPalette.wallpaperGlowStrength, 0.35);
    });

    test('custom accent re-tint keeps paper-derived wash', () {
      final retinted = kLightPalette.withAccent(const Color(0xFF3F6E8E));
      expect(retinted.accent, const Color(0xFF3F6E8E));
      // Wash blends accent over paper — visibly different from toad wash.
      expect(retinted.accentWash, isNot(kLightPalette.accentWash));
    });
  });

  group('pond palettes', () {
    test('day sky gradient stops match spec', () {
      expect(kPondDay.skyStops.first.$1, 0.0);
      expect(kPondDay.skyStops.first.$2, const Color(0xFFDCE9D4));
      expect(kPondDay.skyStops[3].$1, 0.24);
      expect(kPondDay.skyStops[3].$2, const Color(0xFF74AB96));
      expect(kPondDay.skyStops.last.$2, const Color(0xFF2B564A));
      expect(kPondDay.isNight, isFalse);
    });

    test('night sky gradient stops match spec', () {
      expect(kPondNight.skyStops.first.$2, const Color(0xFF101722));
      expect(kPondNight.skyStops.last.$2, const Color(0xFF0B1F28));
      expect(kPondNight.isNight, isTrue);
      expect(kPondNight.logBrightness, 0.82);
      expect(kPondNight.appLabelOpacity, 0.80);
    });

    test('firefly and pad tokens', () {
      expect(kPondDay.firefly, const Color(0xFFFFE58A));
      expect(kPondDay.padFill[0].$2, const Color(0xFF82AB5F));
      expect(kPondDay.padFill[1].$2, const Color(0xFF5E8C4A));
      expect(kPondDay.padFill[2].$2, const Color(0xFF486E3A));
    });
  });

  group('radii + motion contract', () {
    test('radius scale: 22 card / 17 icon / 12 inner / 999 pill', () {
      expect(ToadRadii.card, 22);
      expect(ToadRadii.iconTile, 17);
      expect(ToadRadii.inner, 12);
      expect(ToadRadii.pill, 999);
    });

    test('motion table from section 14', () {
      expect(ToadMotion.blink, const Duration(milliseconds: 180));
      expect(ToadMotion.croak, const Duration(milliseconds: 900));
      expect(ToadMotion.hop, const Duration(milliseconds: 320));
      expect(ToadMotion.mouthOpen, const Duration(milliseconds: 380));
      expect(ToadMotion.swallow, const Duration(milliseconds: 260));
      expect(ToadMotion.dayNightCrossfade, const Duration(seconds: 2));
      expect(ToadMotion.padBob, const Duration(milliseconds: 4800));
    });
  });
}

/// toadLAUNCHER theme engine — typography and the [ToadTheme] scope.
///
/// The four approved looks are expressed as skins over one token set:
/// Light Sketchbook / Dark Night sketchbook / AMOLED / Pond Pro (day+night).
/// Pond Pro is a scene skin: it overrides wallpaper + accent visuals and
/// follows the clock (sunset/sunrise anchors), never location.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../device/battery_monitor.dart' show pondCalmProvider;
import '../settings/launcher_settings.dart';
import 'skins.dart';
import 'toad_tokens.dart';

export 'skins.dart';

/// Typography helpers. Fonts are bundled TTFs (offline-first — no
/// google_fonts runtime fetch).
///
/// Caveat ships as a variable font: weight is driven by the `wght` axis via
/// [FontVariation]. Inter ships as a variable font with `opsz` and `wght`.
abstract final class ToadType {
  static const String fontCaveat = 'Caveat';
  static const String fontHand = 'Patrick Hand';
  static const String fontInter = 'Inter';

  /// Caveat display text (hero clock, card titles, section letters).
  /// [weight] 400–700 via variable axis.
  static TextStyle caveat(
    double size, {
    Color? color,
    int weight = 700,
    double height = 0.9,
    double letterSpacing = 1,
  }) {
    return TextStyle(
      fontFamily: fontCaveat,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// Patrick Hand — labels, rows, buttons.
  static TextStyle hand(
    double size, {
    Color? color,
    double? height,
    double? letterSpacing,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: fontHand,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: weight,
    );
  }

  /// Inter — dense meta text only (11px kickers, badges, statusbar).
  static TextStyle inter(
    double size, {
    Color? color,
    int weight = 400,
    double? tracking,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontInter,
      fontSize: size,
      height: height,
      letterSpacing: tracking,
      color: color,
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    );
  }

  /// Uppercase meta kicker: Inter 11 / +12% tracking.
  static TextStyle kicker(Color color, {double size = 11}) =>
      inter(size, color: color, weight: 600, tracking: size * 0.12);
}

/// Fully-resolved skin bundle for the current frame.
@immutable
class ToadSkinData {
  const ToadSkinData({
    required this.skin,
    required this.palette,
    required this.pond,
  });

  final ResolvedSkin skin;
  final ToadPalette palette;
  final PondPalette pond;

  bool get isPond => skin.isPond;

  bool get isDark =>
      skin == ResolvedSkin.dark ||
      skin == ResolvedSkin.amoled ||
      skin == ResolvedSkin.pondNight;
}

/// InheritedWidget carrying the resolved skin. Rebuilt by the root whenever
/// settings, system brightness, or the clock changes.
class ToadTheme extends InheritedWidget {
  const ToadTheme({super.key, required this.data, required super.child});

  final ToadSkinData data;

  static ToadSkinData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToadTheme>()!.data;

  @override
  bool updateShouldNotify(ToadTheme oldWidget) =>
      oldWidget.data.skin != data.skin ||
      oldWidget.data.palette != data.palette;
}

/// Root helper that resolves the skin from Riverpod settings and provides
/// both [ToadTheme] and the Material theme.
class ToadThemeScope extends ConsumerWidget {
  const ToadThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(launcherSettingsProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    final skin = resolveSkin(
      mode: settings.skinMode,
      pondPro: settings.pondPro,
      systemBrightness: brightness,
      now: now,
      sunsetHour: settings.sunsetHour,
      sunsetMinute: settings.sunsetMinute,
      sunriseHour: settings.sunriseHour,
      sunriseMinute: settings.sunriseMinute,
      // Calm pond — the manual switch OR the drain (low-battery calm):
      // "night falls instantly" and the loop freezes below.
      pondCalm: ref.watch(pondCalmProvider),
    );

    var palette = paletteFor(skin);
    // Pond Pro owns its accent look; sketchbook skins accept user accents.
    if (!skin.isPond) {
      palette = palette.withAccent(settings.accent.color);
    }

    final data = ToadSkinData(
      skin: skin,
      palette: palette,
      pond: pondPaletteFor(skin),
    );

    final materialTheme = ThemeData(
      brightness: data.isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: data.isDark ? Brightness.dark : Brightness.light,
        surface: palette.surface,
      ).copyWith(surface: palette.surface),
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: ToadType.fontInter,
    );

    return ToadTheme(
      data: data,
      child: Theme(data: materialTheme, child: child),
    );
  }
}

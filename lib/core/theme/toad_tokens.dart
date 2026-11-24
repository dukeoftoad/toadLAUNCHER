/// toadLAUNCHER design tokens — Section 2 of the design proposal v1.1.
///
/// Single source of truth for every colour, gradient, radius and
/// type-scale value used by the launcher. Do not hard-code hex values
/// elsewhere; import this file instead.
library;

import 'package:material_ui/material_ui.dart';

/// ---------------------------------------------------------------------------
/// SKETCHBOOK SKINS (Light / Dark / AMOLED)
/// ---------------------------------------------------------------------------

/// Light "Sketchbook".
const ToadPalette kLightPalette = ToadPalette(
  paper: Color(0xFFF7F1E6),
  surface: Color(0xFFFFFCF5),
  surface2: Color(0xFFF1E9D8),
  ink: Color(0xFF2B2924),
  inkSoft: Color(0xFF7A7365),
  accent: Color(0xFF4F7A38),
  accentInk: Color(0xFF3C5E2A),
  accentWash: Color(0xFFE9EFDF),
  hairline: Color(0xFFE5DCC8),
  gold: Color(0xFFC9A227),
  danger: Color(0xFFB4552D),
  labelHalo: Color(0xE6FFFCF5),
  wallpaperGlowStrength: 1.0,
  statusIconBrightness: Brightness.dark,
);

/// Dark "Night sketchbook".
const ToadPalette kDarkPalette = ToadPalette(
  paper: Color(0xFF171613),
  surface: Color(0xFF201E1A),
  surface2: Color(0xFF2A2723),
  ink: Color(0xFFEFE9DB),
  inkSoft: Color(0xFFA39C8D),
  accent: Color(0xFF93C46D),
  accentInk: Color(0xFFC4E3A6),
  accentWash: Color(0xFF2E3427),
  hairline: Color(0xFF3A362F),
  gold: Color(0xFFC9A227),
  danger: Color(0xFFB4552D),
  labelHalo: Color(0xCC000000),
  wallpaperGlowStrength: 0.5,
  statusIconBrightness: Brightness.light,
);

/// AMOLED "black paper".
const ToadPalette kAmoledPalette = ToadPalette(
  paper: Color(0xFF000000),
  surface: Color(0xFF12110F),
  surface2: Color(0xFF1A1916),
  ink: Color(0xFFEFE9DB),
  inkSoft: Color(0xFFA39C8D),
  accent: Color(0xFF93C46D),
  accentInk: Color(0xFFC4E3A6),
  accentWash: Color(0xFF2E3427),
  hairline: Color(0xFF2A2824),
  gold: Color(0xFFC9A227),
  danger: Color(0xFFB4552D),
  labelHalo: Color(0xE6000000),
  wallpaperGlowStrength: 0.35,
  statusIconBrightness: Brightness.light,
);

/// ---------------------------------------------------------------------------
/// POND PRO "live water" — scene skin (day + night)
/// ---------------------------------------------------------------------------

/// Pond Pro day scene tokens.
const PondPalette kPondDay = PondPalette(
  skyStops: <(double, Color)>[
    (0.00, Color(0xFFDCE9D4)),
    (0.09, Color(0xFFC6DFCE)),
    (0.16, Color(0xFFA3CEBD)),
    (0.24, Color(0xFF74AB96)),
    (0.32, Color(0xFF5E9C86)),
    (0.58, Color(0xFF48816C)),
    (0.82, Color(0xFF38695A)),
    (1.00, Color(0xFF2B564A)),
  ],
  ink: Color(0xFF1C332B),
  appLabel: Color(0xFF17302A),
  appLabelShadow: Color(0x8CE6F4EC),
  padFill: <(double, Color)>[
    (0.00, Color(0xFF82AB5F)),
    (0.62, Color(0xFF5E8C4A)),
    (1.00, Color(0xFF486E3A)),
  ],
  padVein: Color(0xFF446F39),
  padVeinOpacity: 0.45,
  toadFeet: Color(0xFF4A723C),
  toadBody: Color(0xFF5E8C4A),
  toadBelly: Color(0xFFEDEFC0),
  toadEye: Color(0xFFF6F2DC),
  toadPupil: Color(0xFF20261A),
  toadDetail: Color(0xFF3C5E2A),
  toadSpot: Color(0xFF446B37),
  toadThroat: Color(0xFFDCD9A0),
  logTop: Color(0xFF8A6242),
  logMid: Color(0xFF6E4C33),
  logBottom: Color(0xFF5B3D2A),
  logEdgeTint: Color(0xFF3B2A1E),
  streak: Color(0x42D8F0E4),
  streakDark: Color(0x29081E18),
  glitter: Color(0x29FAF4D6),
  rippleRing: Color(0x80E0F3EB),
  firefly: Color(0xFFFFE58A),
  sun: Color(0xFFFFF7D9),
  sunEdge: Color(0xFFF2D584),
  cloud: Color(0xD9FFFFFB),
  reedStem: Color(0xFF20402C),
  reedHead: Color(0xFF4A3A26),
  reedHead2: Color(0xFF54422B),
  reflectionOpacity: 0.16,
  clockLabel: Color(0xFFEAF2EA),
  isNight: false,
);

/// Pond Pro night scene tokens.
const PondPalette kPondNight = PondPalette(
  skyStops: <(double, Color)>[
    (0.00, Color(0xFF101722)),
    (0.09, Color(0xFF131E2C)),
    (0.17, Color(0xFF1A2C3E)),
    (0.24, Color(0xFF1E3744)),
    (0.36, Color(0xFF173440)),
    (0.64, Color(0xFF122B34)),
    (1.00, Color(0xFF0B1F28)),
  ],
  ink: Color(0xFFE9E4D2),
  appLabel: Color(0xFFCFE2D6),
  appLabelShadow: Color(0xB3000000),
  padFill: <(double, Color)>[
    (0.00, Color(0xFF3E5C3C)),
    (0.62, Color(0xFF2A462B)),
    (1.00, Color(0xFF1F3722)),
  ],
  padVein: Color(0xFF1C3220),
  padVeinOpacity: 0.60,
  toadFeet: Color(0xFF3B5B31),
  toadBody: Color(0xFF4A7440),
  toadBelly: Color(0xFFD3D6A4),
  toadEye: Color(0xFFF6F2DC),
  toadPupil: Color(0xFF20261A),
  toadDetail: Color(0xFF2C4525),
  toadSpot: Color(0xFF35512C),
  toadThroat: Color(0xFFDCD9A0),
  logTop: Color(0xFF8A6242),
  logMid: Color(0xFF6E4C33),
  logBottom: Color(0xFF5B3D2A),
  logEdgeTint: Color(0xFF3B2A1E),
  logBrightness: 0.82,
  streak: Color(0x1FB4D2C8),
  streakDark: Color(0x29081E18),
  glitter: Color(0x29FAF4D6),
  rippleRing: Color(0x80E0F3EB),
  firefly: Color(0xFFFFE58A),
  moon: Color(0xFFFDFBEF),
  moonEdge: Color(0xFFE6E0C6),
  moonCrater: Color(0xFFB0AA8A),
  star: Color(0xFFF4EFD6),
  zzz: Color(0xFFDCE8DC),
  reedStem: Color(0xFF12271B),
  reedHead: Color(0xFF33281A),
  reedHead2: Color(0xFF3B2E1E),
  reflectionOpacity: 0.10,
  clockLabel: Color(0xFFEAF2EA),
  appLabelOpacity: 0.80,
  isNight: true,
);

/// ---------------------------------------------------------------------------
/// TOKEN MODELS
/// ---------------------------------------------------------------------------

/// Colour tokens shared by the three sketchbook skins.
class ToadPalette {
  const ToadPalette({
    required this.paper,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentInk,
    required this.accentWash,
    required this.hairline,
    required this.gold,
    required this.danger,
    required this.labelHalo,
    required this.wallpaperGlowStrength,
    required this.statusIconBrightness,
  });

  final Color paper;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color accentInk;
  final Color accentWash;
  final Color hairline;
  final Color gold;
  final Color danger;

  /// Soft halo colour painted behind app labels for wallpaper contrast.
  final Color labelHalo;

  /// Strength multiplier for the wallpaper glow radials (1 / .5 / .35).
  final double wallpaperGlowStrength;

  final Brightness statusIconBrightness;

  /// Palette with the user-chosen accent re-tinted in (highlights, toggles,
  /// badges). Wash and accent-ink are derived so custom accents still feel
  /// sketchbook.
  ToadPalette withAccent(Color accent) {
    final wash = Color.alphaBlend(accent.withValues(alpha: 0.14), paper);
    final accentInk = Color.alphaBlend(accent.withValues(alpha: 0.72), ink);
    return ToadPalette(
      paper: paper,
      surface: surface,
      surface2: surface2,
      ink: ink,
      inkSoft: inkSoft,
      accent: accent,
      accentInk: accentInk,
      accentWash: wash,
      hairline: hairline,
      gold: gold,
      danger: danger,
      labelHalo: labelHalo,
      wallpaperGlowStrength: wallpaperGlowStrength,
      statusIconBrightness: statusIconBrightness,
    );
  }
}

/// Pond Pro scene tokens (day or night).
class PondPalette {
  const PondPalette({
    required this.skyStops,
    required this.ink,
    required this.appLabel,
    required this.appLabelShadow,
    required this.padFill,
    required this.padVein,
    required this.padVeinOpacity,
    required this.toadFeet,
    required this.toadBody,
    required this.toadBelly,
    required this.toadEye,
    required this.toadPupil,
    required this.toadDetail,
    required this.toadSpot,
    required this.toadThroat,
    required this.logTop,
    required this.logMid,
    required this.logBottom,
    required this.logEdgeTint,
    required this.streak,
    required this.streakDark,
    required this.glitter,
    required this.rippleRing,
    required this.firefly,
    required this.reedStem,
    required this.reedHead,
    required this.reedHead2,
    required this.reflectionOpacity,
    required this.clockLabel,
    required this.isNight,
    this.logBrightness = 1.0,
    this.sun,
    this.sunEdge,
    this.cloud,
    this.moon,
    this.moonEdge,
    this.moonCrater,
    this.star,
    this.zzz,
    this.appLabelOpacity = 1.0,
  });

  final List<(double, Color)> skyStops;
  final Color ink;
  final Color appLabel;
  final Color appLabelShadow;
  final List<(double, Color)> padFill;
  final Color padVein;
  final double padVeinOpacity;
  final Color toadFeet;
  final Color toadBody;
  final Color toadBelly;
  final Color toadEye;
  final Color toadPupil;
  final Color toadDetail;
  final Color toadSpot;
  final Color toadThroat;
  final Color logTop;
  final Color logMid;
  final Color logBottom;
  final Color logEdgeTint;
  final double logBrightness;
  final Color streak;
  final Color streakDark;
  final Color glitter;
  final Color rippleRing;
  final Color firefly;
  final Color? sun;
  final Color? sunEdge;
  final Color? cloud;
  final Color? moon;
  final Color? moonEdge;
  final Color? moonCrater;
  final Color? star;
  final Color? zzz;
  final Color reedStem;
  final Color reedHead;
  final Color reedHead2;
  final double reflectionOpacity;
  final Color clockLabel;
  final double appLabelOpacity;
  final bool isNight;
}

/// ---------------------------------------------------------------------------
/// RADII, SIZES, MOTION
/// ---------------------------------------------------------------------------

/// Corner radius scale: 22 card · 17 icon tile · 12 inner · 999 pill.
abstract final class ToadRadii {
  static const double card = 22;
  static const double iconTile = 17;
  static const double pondIconTile = 15;
  static const double drawerIconTile = 14;
  static const double inner = 12;
  static const double dock = 26;
  static const double folder = 26;
  static const double sheetTop = 30;
  static const double popover = 20;
  static const double settingsGroup = 20;
  static const double popoverItem = 13;
  static const double settingsIconChip = 11;
  static const double squircleIcon = 9; // "square-ish" icon shape option
  static const double pill = 999;
}

/// Fixed layout metrics from the proposal (352x786 reference surface).
abstract final class ToadMetrics {
  /// Reference design surface used to scale relative artwork positions.
  static const Size referenceScreen = Size(352, 786);

  // Hero.
  static const double heroClockSize = 78;
  static const double heroDateSize = 16.5;
  static const double heroSideSize = 11.5;
  static const double reflectionClockSize = 58;

  // App grid.
  static const double gridIconSize = 54;
  static const double dockIconSize = 48;
  static const double pondIconSize = 48;
  static const double gridGlyphSize = 24;
  static const double appNameSize = 12.5;
  static const double pondAppNameSize = 12;
  static const double gridRowGap = 14;
  static const int defaultColumns = 4;
  static const int optionalColumns = 5;

  /// Grid cell pitch used by edit mode ("honest snapping").
  static const double editRowPitch = 136;

  // Memories card.
  static const double memoryPhotoHeight = 64;
  static const double memoryPhotoRadius = 14;
  static const double memoryTitleSize = 23;

  // Dock.
  static const double dockRadius = ToadRadii.dock;
  static const EdgeInsets dockMargin = EdgeInsets.fromLTRB(12, 0, 12, 14);
  static const EdgeInsets dockPadding = EdgeInsets.fromLTRB(10, 12, 10, 10);

  // Page dots.
  static const double pageDotSize = 6.5;
  static const double pageDotActiveWidth = 18;

  // Pond.
  static const double pondCellWidth = 104;
  static const double pondPadWidth = 100;
  static const double pondPadHeight = 71;
  static const double pondRowsTop = 272;
  static const double pondRowGapExtra = 34;
  static const double pondSunSize = 50;
  static const double pondMoonSize = 42;
  static const double toadWidth = 82;
  static const double toadHeight = 55;

  // Widget picker previews (stage 3).
  static const double widgetPreviewWidth = 92;
  static const double widgetPreviewHeight = 56;

  // Edit-mode selection handles (stage 3).
  static const double resizeHandleSize = 15;
}

/// Motion timings — Section 14 timing table (authoritative).
abstract final class ToadMotion {
  static const Duration sharedAxisFolderOpen = Duration(milliseconds: 240);
  static const Duration popoverScaleIn = Duration(milliseconds: 180);
  static const Duration blink = Duration(milliseconds: 180);
  static const Duration croak = Duration(milliseconds: 900);
  static const Duration hop = Duration(milliseconds: 320);
  static const Duration flyby = Duration(milliseconds: 2400);
  static const Duration rainDrop = Duration(milliseconds: 1100);
  static const Duration dayNightCrossfade = Duration(seconds: 2);
  static const Duration mouthOpen = Duration(milliseconds: 380);
  static const Duration swallow = Duration(milliseconds: 260);
  static const Duration padBob = Duration(milliseconds: 4800);
  static const Duration rippleLoop = Duration(milliseconds: 4400);
  static const Duration fireflyDrift = Duration(milliseconds: 7500);
  static const Duration fireflyFlicker = Duration(milliseconds: 2300);
  static const Duration toadBob = Duration(milliseconds: 5400);
  static const Duration reedSway = Duration(milliseconds: 5600);
}

/// ---------------------------------------------------------------------------
/// DEMO APP ICON GRADIENTS (g1..g8 + the toad-family green)
/// ---------------------------------------------------------------------------

/// 145-degree gradients per the proposal's icon palette.
abstract final class AppIconGradients {
  /// toad family — toadGALLERY and family apps.
  static const List<Color> toad = [Color(0xFF6B9E47), Color(0xFF3C5E2A)];

  static const List<List<Color>> all = [
    [Color(0xFF69A05E), Color(0xFF3E6E3A)], // g1 green
    [Color(0xFF5B9BD5), Color(0xFF2F5E8F)], // g2 blue
    [Color(0xFFE0B04E), Color(0xFFA97424)], // g3 amber
    [Color(0xFFDF7E5B), Color(0xFFA34526)], // g4 orange
    [Color(0xFF9E7BD5), Color(0xFF5F3E9C)], // g5 purple
    [Color(0xFF58AFAE), Color(0xFF266B6C)], // g6 teal
    [Color(0xFFD56E8E), Color(0xFF94355A)], // g7 pink
    [Color(0xFF8A929E), Color(0xFF4C5361)], // g8 grey
  ];

  /// Memories-strip photo placeholders (amber / green / steel-blue).
  static const List<List<Color>> memoryPhotos = [
    [Color(0xFFD9A441), Color(0xFF8A5A2B)],
    [Color(0xFF7FA45B), Color(0xFF3F5E2C)],
    [Color(0xFF6E8FAF), Color(0xFF39536E)],
  ];

  /// Bundled sketchbook wallpapers (screen 9). Selected = index 0.
  static const List<List<Color>> wallpapers = [
    [Color(0xFFB7C9A0), Color(0xFF5F8746), Color(0xFF33502A)], // sage
    [Color(0xFFEAD9B0), Color(0xFFC9A227), Color(0xFF8A6C1B)], // gold
    [Color(0xFFD9A8A0), Color(0xFFA45C50)], // rose
    [Color(0xFF9FB6C9), Color(0xFF4E6B84)], // steel
    [Color(0xFF3E3B33), Color(0xFF191813)], // charcoal
    [Color(0xFF101010), Color(0xFF000000)], // amoled
    [Color(0xFF57624B), Color(0xFF1D2318)], // forest
  ];
}

/// The six accent options from Wallpaper & style.
const List<Color> kAccentOptions = [
  Color(0xFF4F7A38), // toad green (default)
  Color(0xFFB4552D), // clay
  Color(0xFF3F6E8E), // steel
  Color(0xFF8A5A9C), // plum
  Color(0xFFC9A227), // gold
  Color(0xFF2B2924), // ink
];

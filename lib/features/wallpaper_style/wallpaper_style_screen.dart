/// Wallpaper & style — screen 9 of the proposal.
///
/// "One screen to choose the paper, the ink and the stickers: wallpaper,
/// theme mode, accent color, icon shape."
///
///   · wallpaper grid: bundled sketchbook papers (+ an honest slot for user
///     photos, which arrive with device mode)
///   · theme mode: Auto / Light / Dark / AMOLED segmented control — mirrors
///     toadGALLERY's appearance selector
///   · accent: six sticker colors; switching re-tints highlights, toggles
///     and badges instantly (live preview)
///   · icon shape: squircle / circle / rounded-square, applied uniformly
///   · everything offline; papers ship inside the APK
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

class WallpaperStyleScreen extends ConsumerWidget {
  const WallpaperStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final settings = ref.watch(launcherSettingsProvider);
    final notifier = ref.read(launcherSettingsProvider.notifier);
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.statusIconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: palette.statusIconBrightness,
      ),
      child: Scaffold(
        backgroundColor: palette.paper,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  // Header.
                  Row(
                    children: [
                      _BackChip(onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Wallpaper & style',
                          style: ToadType.caveat(34, color: ink),
                        ),
                      ),
                    ],
                  ),

                  // Paper hero — the current choice, named.
                  Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 14),
                    height: 96,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ToadRadii.card),
                      border: Border.all(color: palette.hairline),
                      gradient: _paperGradient(settings.wallpaperIndex),
                    ),
                    child: Text(
                      '${settings.wallpaperIndex.wallpaperLabel.toLowerCase()} paper',
                      style: ToadType.caveat(
                        30,
                        color: Colors.white.withValues(alpha: 0.94),
                      ),
                    ),
                  ),

                  // Wallpaper grid — 7 bundled papers + user photos slot.
                  _SectionLabel('Wallpaper', ink),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      for (
                        var i = 0;
                        i < AppIconGradients.wallpapers.length;
                        i++
                      )
                        _PaperThumb(
                          key: ValueKey('paper-$i'),
                          index: i,
                          selected: settings.wallpaperIndex == i,
                          accent: palette.accent,
                          onTap: () => notifier.setWallpaperIndex(i),
                        ),
                      _PhotosTile(ink: ink, hairline: palette.hairline),
                    ],
                  ),

                  // Pond Pro — the live skin, opt-in.
                  _SectionLabel('Pond Pro', ink),
                  _GroupCard(
                    palette: palette,
                    children: [
                      _SwitchRow(
                        key: const ValueKey('switch-pond'),
                        title: 'Pond Pro scene',
                        subtitle:
                            'Replaces papers with the living pond — day & night '
                            'follow the clock',
                        value: settings.pondPro,
                        accent: palette.accent,
                        ink: ink,
                        onChanged: notifier.setPondPro,
                      ),
                      _SwitchRow(
                        key: const ValueKey('switch-rain'),
                        title: 'Rain shower',
                        subtitle:
                            'Manual weather toggle — ripple density ×3 and the '
                            'sky dims; never a weather feed',
                        value: settings.pondRain,
                        accent: palette.accent,
                        ink: ink,
                        onChanged: notifier.setPondRain,
                      ),
                      _SwitchRow(
                        key: const ValueKey('switch-calm'),
                        title: 'Calm pond',
                        subtitle:
                            'Night falls instantly and the whole loop freezes '
                            'into a still painting — zero animation cost',
                        value: settings.calmPond,
                        accent: palette.accent,
                        ink: ink,
                        onChanged: notifier.setCalmPond,
                      ),
                      _SwitchRow(
                        key: const ValueKey('switch-battery'),
                        title: 'Battery guard',
                        subtitle:
                            'When battery saver is active, the pond freezes the '
                            'same way — read on device, never faked in demo',
                        value: settings.batteryGuard,
                        accent: palette.accent,
                        ink: ink,
                        onChanged: notifier.setBatteryGuard,
                      ),
                    ],
                  ),

                  // Theme mode.
                  _SectionLabel('Theme mode', ink),
                  _Segmented(
                    options: const ['Auto', 'Light', 'Dark', 'AMOLED'],
                    selectedIndex: switch (settings.skinMode) {
                      SkinMode.system => 0,
                      SkinMode.light => 1,
                      SkinMode.dark => 2,
                      SkinMode.amoled => 3,
                    },
                    accent: palette.accent,
                    ink: ink,
                    hairline: palette.hairline,
                    surface: palette.surface,
                    onSelect: (i) => notifier.setSkinMode(switch (i) {
                      0 => SkinMode.system,
                      1 => SkinMode.light,
                      2 => SkinMode.dark,
                      _ => SkinMode.amoled,
                    }),
                  ),

                  // Accent — live re-tint.
                  _SectionLabel('Accent', ink),
                  Row(
                    children: [
                      for (final option in AccentOption.values) ...[
                        Expanded(
                          child: Center(
                            child: _AccentSwatch(
                              key: ValueKey('accent-${option.name}'),
                              color: option.color,
                              selected: settings.accent == option,
                              accent: palette.accent,
                              onTap: () => notifier.setAccent(option),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'switching re-tints highlights, toggles and badges instantly',
                    style: ToadType.inter(
                      10.5,
                      color: ink.withValues(alpha: ink.a * 0.55),
                    ),
                  ),

                  // Icon shape.
                  _SectionLabel('Icon shape', ink),
                  Row(
                    children: [
                      for (final shape in IconShape.values)
                        Expanded(
                          child: _ShapeChip(
                            key: ValueKey('shape-${shape.name}'),
                            shape: shape,
                            selected: settings.iconShape == shape,
                            accent: palette.accent,
                            accentWash: palette.accentWash,
                            ink: ink,
                            hairline: palette.hairline,
                            onTap: () => notifier.setIconShape(shape),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Text(
                    'papers ship inside the APK — zero network, as always',
                    textAlign: TextAlign.center,
                    style: ToadType.inter(
                      10.5,
                      color: ink.withValues(alpha: ink.a * 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _paperGradient(int index) {
    final papers = AppIconGradients.wallpapers;
    final colors = papers[index.clamp(0, papers.length - 1)];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
      transform: const GradientRotation(145 * 3.14159 / 180),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.accentWash,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.hairline),
        ),
        child: Text('‹', style: ToadType.hand(22, color: palette.accentInk)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.ink);

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: ToadType.kicker(ink.withValues(alpha: ink.a * 0.55)),
      ),
    );
  }
}

class _PaperThumb extends StatelessWidget {
  const _PaperThumb({
    super.key,
    required this.index,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppIconGradients.wallpapers[index];
    final label = index.wallpaperLabel;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : Colors.transparent,
                width: selected ? 2.5 : 0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
                transform: const GradientRotation(145 * 3.14159 / 180),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ToadType.inter(
              9.5,
              weight: selected ? 700 : 400,
              color: selected ? accent : inkSoft(context),
            ),
          ),
        ],
      ),
    );
  }

  Color inkSoft(BuildContext context) =>
      ToadTheme.of(context).palette.ink
          .withValues(alpha: ToadTheme.of(context).palette.ink.a * 0.55);
}

/// The honest "user photos" slot — bundled papers only in demo mode.
class _PhotosTile extends StatelessWidget {
  const _PhotosTile({required this.ink, required this.hairline});

  final Color ink;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.hairline),
            ),
            duration: const Duration(seconds: 2),
            content: Text(
              'Your photos arrive with device mode — the demo ships bundled '
              'papers only',
              style: ToadType.hand(13, color: palette.ink),
            ),
          ),
        ),
      child: Column(
        children: [
          Container(
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hairline,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Text('＋', style: ToadType.hand(20, color: ink)),
          ),
          const SizedBox(height: 4),
          Text(
            'your photos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ToadType.inter(
              9.5,
              color: ink.withValues(alpha: ink.a * 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.palette, required this.children});

  final ToadPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.ink,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final Color ink;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ToadType.hand(15, color: ink)),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: ToadType.inter(
                      10.5,
                      height: 1.3,
                      color: ink.withValues(alpha: ink.a * 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ToadSwitch(value: value, accent: accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The sketchbook switch — re-tints with the chosen accent ("live apply").
class ToadSwitch extends StatelessWidget {
  const ToadSwitch({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: value
              ? accent
              : palette.ink.withValues(alpha: palette.ink.a * 0.18),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selectedIndex,
    required this.accent,
    required this.ink,
    required this.hairline,
    required this.surface,
    required this.onSelect,
  });

  final List<String> options;
  final int selectedIndex;
  final Color accent;
  final Color ink;
  final Color hairline;
  final Color surface;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: i == selectedIndex ? accent : Colors.transparent,
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: ToadType.hand(
                      13,
                      color: i == selectedIndex
                          ? Colors.white
                          : ink.withValues(alpha: ink.a * 0.75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}

class _ShapeChip extends StatelessWidget {
  const _ShapeChip({
    super.key,
    required this.shape,
    required this.selected,
    required this.accent,
    required this.accentWash,
    required this.ink,
    required this.hairline,
    required this.onTap,
  });

  final IconShape shape;
  final bool selected;
  final Color accent;
  final Color accentWash;
  final Color ink;
  final Color hairline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (shape) {
      IconShape.squircle => 'squircle',
      IconShape.circle => 'circle',
      IconShape.rounded => 'rounded',
    };
    final radius = switch (shape) {
      IconShape.squircle => 9.0,
      IconShape.circle => 99.0,
      IconShape.rounded => 10.0,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? accentWash : Colors.transparent,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: accent.a * 0.6)
                : hairline,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? accent : ink.withValues(alpha: ink.a * 0.25),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: ToadType.hand(
                12.5,
                color: selected ? accent : ink.withValues(alpha: ink.a * 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

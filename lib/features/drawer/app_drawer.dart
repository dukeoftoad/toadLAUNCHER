/// App drawer — screen 4 of the proposal ("A–Z + search").
///
/// Opens over the home as a frosted-paper sheet (22 px blur + paper wash).
/// The search pill is sticky on top, the recents row holds the last four
/// launches, and the alphabetical index uses Caveat section letters with
/// Patrick Hand rows. Typing filters instantly; swipe-down on the header,
/// back, or Esc closes. Local index only — nothing leaves the device.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_app_icon.dart';
import '../home/home_controller.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, this.startWithSearch = false});

  /// Dock-area swipe-down opens the drawer with search focused instead of
  /// the notification shade (opt-in switch).
  final bool startWithSearch;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: ToadMotion.sharedAxisFolderOpen, // 240 ms, shared-axis family
    )..forward();
    _search.addListener(() {
      if (_query != _search.text) setState(() => _query = _search.text);
    });
    if (widget.startWithSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Play the exit, then tell the host to unmount.
  void _close() {
    if (!_entrance.isCompleted) return;
    _entrance.reverse().then((_) {
      if (mounted) ref.read(drawerOpenProvider.notifier).close();
    });
  }

  void _launch(AppEntry app) {
    ref.read(homeLayoutProvider.notifier).launch(app);
    ref.read(drawerOpenProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final layoutAsync = ref.watch(homeLayoutProvider);
    final layout = layoutAsync.valueOrNull;
    if (layout == null) return const SizedBox.shrink();

    final settings = ref.watch(launcherSettingsProvider);

    // Exact drawer-wash values per skin (CSS .drawer-bg).
    final double washAlpha = switch (skin.skin) {
      ResolvedSkin.light => 0.82,
      ResolvedSkin.pondDay => 0.82,
      ResolvedSkin.dark => 0.86,
      ResolvedSkin.pondNight => 0.86,
      ResolvedSkin.amoled => 0.88,
    };
    final rowColor = skin.isDark ? const Color(0xFFE8E2D4) : palette.ink;
    final hintColor = skin.isDark
        ? const Color(0xFFA39C8D)
        : const Color(0xFF6F6A5E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: FadeTransition(
            opacity: _entrance,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _entrance,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    color: palette.paper.withValues(
                      alpha: palette.paper.a * washAlpha,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: _DrawerHooks(
                        onLaunch: _launch,
                        onAppLongPress: (app, anchor) {
                          ref
                              .read(drawerMenuBridgeProvider.notifier)
                              .raise(app: app, anchor: anchor);
                        },
                        showBadges: settings.badges,
                        child: _Body(
                          layout: layout,
                          query: _query,
                          searchController: _search,
                          searchFocus: _searchFocus,
                          showSearch: settings.drawerSearch,
                          showRecents: settings.drawerRecents,
                          showBadges: settings.badges,
                          rowColor: rowColor,
                          hintColor: hintColor,
                          onClose: _close,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bridge so drawer rows can raise the host's context menu without
/// threading callbacks through every widget.
final StateNotifierProvider<DrawerMenuBridge, DrawerMenuRequest?>
drawerMenuBridgeProvider =
    StateNotifierProvider<DrawerMenuBridge, DrawerMenuRequest?>(
      (ref) => DrawerMenuBridge(),
    );

@immutable
class DrawerMenuRequest {
  const DrawerMenuRequest({required this.app, required this.anchor});

  final AppEntry app;
  final Offset anchor;
}

class DrawerMenuBridge extends StateNotifier<DrawerMenuRequest?> {
  DrawerMenuBridge() : super(null);

  void raise({required AppEntry app, required Offset anchor}) {
    state = DrawerMenuRequest(app: app, anchor: anchor);
  }

  void consume() => state = null;
}

/// Search pill + recents + the index itself.
class _Body extends StatelessWidget {
  const _Body({
    required this.layout,
    required this.query,
    required this.searchController,
    required this.searchFocus,
    required this.showSearch,
    required this.showRecents,
    required this.showBadges,
    required this.rowColor,
    required this.hintColor,
    required this.onClose,
  });

  final HomeLayout layout;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool showSearch;
  final bool showRecents;
  final bool showBadges;
  final Color rowColor;
  final Color hintColor;
  final VoidCallback onClose;

  bool get _searching => showSearch && query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Header zone: swipe down here closes the drawer.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 120) onClose();
          },
          child: Column(
            children: [
              if (showSearch) ...[
                _SearchPill(
                  controller: searchController,
                  focusNode: searchFocus,
                  hintColor: hintColor,
                ),
                if (showRecents && !_searching) const SizedBox(height: 12),
              ],
              if (showRecents && !_searching)
                _RecentsRow(recents: layout.recents),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _searching
              ? _SearchResults(query: query, apps: layout.allApps)
              : _AzIndex(apps: layout.allApps, showBadges: showBadges),
        ),
        const PageDotsMini(),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// ⌕ Search apps — sticky pill, Patrick Hand 15.
class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.controller,
    required this.focusNode,
    required this.hintColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: palette.surface.a * 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            Text('⌕', style: ToadType.hand(17, color: hintColor)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: ToadType.hand(15, color: hintColor),
                cursorColor: palette.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search apps',
                  hintStyle: ToadType.hand(15, color: hintColor),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: controller.clear,
                child: Text('✕', style: ToadType.hand(14, color: hintColor)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Recents — last 4 launched, 44 px icons, hand-jump back into them.
class _RecentsRow extends StatelessWidget {
  const _RecentsRow({required this.recents});

  final List<AppEntry> recents;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
      child: Row(
        children: [
          for (var i = 0; i < recents.take(4).length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _RecentTile(
                app: recents[i],
                labelColor: palette.ink.withValues(alpha: palette.ink.a * 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.app, required this.labelColor});

  final AppEntry app;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _DrawerHooks.of(context)?.onLaunch(app),
      child: Column(
        children: [
          ToadAppIcon(
            app: app,
            size: 44,
            radius: 14,
            glyphSize: 18,
            shape: IconShape.squircle,
          ),
          const SizedBox(height: 4),
          ToadAppLabel(
            text: app.name,
            color: labelColor,
            haloColor: Colors.transparent,
            fontSize: 10.5,
          ),
        ],
      ),
    );
  }
}

/// The A–Z index: Caveat letters as section headers.
class _AzIndex extends StatelessWidget {
  const _AzIndex({required this.apps, required this.showBadges});

  final List<AppEntry> apps;
  final bool showBadges;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    String? currentLetter;

    for (final app in apps) {
      final letter = app.name.isEmpty ? '#' : app.name[0].toUpperCase();
      if (letter != currentLetter) {
        currentLetter = letter;
        rows.add(_SectionLetter(letter: letter));
      }
      rows.add(_AzRow(app: app));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      children: rows,
    );
  }
}

class _SectionLetter extends StatelessWidget {
  const _SectionLetter({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Opacity(
          opacity: 0.55,
          child: Text(
            letter,
            style: ToadType.caveat(22, height: 1, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

class _AzRow extends StatelessWidget {
  const _AzRow({required this.app});

  final AppEntry app;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final rowColor = ToadTheme.of(context).isDark
        ? const Color(0xFFE8E2D4)
        : palette.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _DrawerHooks.of(context)?.onLaunch(app),
      onLongPressStart: (details) =>
          _DrawerHooks.of(context)?.onAppLongPress(app, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            ToadAppIcon(
              app: app,
              size: 44,
              radius: ToadRadii.drawerIconTile,
              glyphSize: 18,
              shape: IconShape.squircle,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ToadType.hand(15, color: rowColor),
              ),
            ),
            if (app.badge != null &&
                (_DrawerHooks.of(context)?.showBadges ?? true))
              _BadgePill(text: app.badge!),
          ],
        ),
      ),
    );
  }
}

/// Local-state-only badge (missed calls, updates) — accent wash pill.
class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: palette.accent.withValues(
          alpha: palette.accent.a * (skin.isDark ? 0.16 : 0.14),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: ToadType.inter(10, color: palette.accentInk, weight: 600),
      ),
    );
  }
}

/// Flat, letter-less results list while searching.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query, required this.apps});

  final String query;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final rowColor = ToadTheme.of(context).isDark
        ? const Color(0xFFE8E2D4)
        : palette.ink;
    final q = query.trim().toLowerCase();
    final hits = [
      for (final app in apps)
        if (app.name.toLowerCase().contains(q)) app,
    ];

    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No apps for "$query"',
              style: ToadType.hand(15, color: rowColor),
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: 0.55,
              child: Text(
                'the pond is quiet',
                style: ToadType.caveat(20, color: palette.ink),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      children: [for (final app in hits) _AzRow(app: app)],
    );
  }
}

/// The drawer mockup keeps a single dot under the index (page 1 of 1).
class PageDotsMini extends StatelessWidget {
  const PageDotsMini({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: ToadMetrics.pageDotActiveWidth,
          height: ToadMetrics.pageDotSize,
          decoration: BoxDecoration(
            color: palette.ink.withValues(alpha: palette.ink.a * 0.85),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

/// Launch/long-press hooks routed without threading callbacks through
/// every row widget.
class _DrawerHooks extends InheritedWidget {
  const _DrawerHooks({
    required this.onLaunch,
    required this.onAppLongPress,
    this.showBadges = true,
    required super.child,
  });

  final void Function(AppEntry app) onLaunch;
  final void Function(AppEntry app, Offset anchor) onAppLongPress;

  /// Settings › Notifications › badges — hides the written counts live.
  final bool showBadges;

  static _DrawerHooks? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DrawerHooks>();

  @override
  bool updateShouldNotify(_DrawerHooks oldWidget) =>
      oldWidget.showBadges != showBadges;
}

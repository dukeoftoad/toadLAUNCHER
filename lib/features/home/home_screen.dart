/// Home screen — sketchbook skins (Light / Dark / AMOLED).
///
/// Layout top→bottom: hero zone → memories card → paged app grid →
/// page dots → dock. Swipe up anywhere opens the drawer (stage 2).
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../shared/widgets/wallpaper_glow.dart';
import 'home_controller.dart';
import 'widgets/app_grid.dart';
import 'widgets/dock_bar.dart';
import 'widgets/hero_zone.dart';
import 'widgets/memories_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  int _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (ref.read(currentPageProvider) != page) {
        ref.read(currentPageProvider.notifier).set(page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final settings = ref.watch(launcherSettingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final layoutAsync = ref.watch(homeLayoutProvider);

    final hero = buildHeroData(now, pond: false, pondNight: false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: skin.palette.statusIconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: skin.palette.statusIconBrightness,
      ),
      child: Scaffold(
        backgroundColor: skin.palette.paper,
        body: WallpaperGlow(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                HeroZone(data: hero),
                if (settings.showMemoriesCard)
                  layoutAsync.maybeWhen(
                    data: (layout) => MemoriesCard(
                      data: layout.memory,
                      onOpen: () => _launch(layout.allApps.firstWhere(
                        (a) => a.id == 'family.toad.gallery',
                        orElse: () => layout.allApps.first,
                      )),
                    ),
                    orElse: () => const SizedBox(
                      height: 118,
                      width: double.infinity,
                    ),
                  ),
                Expanded(
                  child: layoutAsync.maybeWhen(
                    data: (layout) {
                      if (_pageCount != layout.pages.length) {
                        _pageCount = layout.pages.length;
                      }
                      return AppGridPageView(
                        pages: layout.pages,
                        controller: _pageController,
                        columns: settings.gridColumns,
                        iconShape: settings.iconShape,
                        onAppTap: _launch,
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
                PageDots(
                  count: _pageCount,
                  activeIndex: ref.watch(currentPageProvider),
                ),
                layoutAsync.maybeWhen(
                  data: (layout) => DockBar(
                    apps: layout.dock,
                    iconShape: settings.iconShape,
                    onAppTap: _launch,
                    onDrawerTap: () {}, // Drawer arrives in stage 2.
                  ),
                  orElse: () => const SizedBox(height: 84),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launch(AppEntry app) {
    ref.read(homeLayoutProvider.notifier).launch(app);
  }
}

/// Stage 2 feature tests — drawer, search, recents, folders, context menu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/core/theme/toad_theme.dart';
import 'package:toadlauncher/features/home/home_controller.dart';
import 'package:toadlauncher/features/home/home_screen.dart';
import 'package:toadlauncher/features/pond/pond_home.dart';

Future<void> pumpHome(WidgetTester tester, {bool pondPro = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            ToadThemeScope(child: child ?? const SizedBox.shrink()),
        home: pondPro ? const PondHome() : const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Open the drawer through the dock handle.
Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('APPS'));
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'drawer opens from the dock handle: search pill, recents, A-Z, badge',
    (tester) async {
      await pumpHome(tester);

      // Badges are off by default (screen 10); this user turned them on.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      container.read(launcherSettingsProvider.notifier).setBadges(true);
      await tester.pump();

      await openDrawer(tester);

      expect(find.text('Search apps'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // Caveat section letters
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      // Recents seeded from the repo (toadGALLERY also lives on the grid).
      expect(find.text('toadGALLERY'), findsWidgets);

      // Contacts sits below the fold — scroll the index to it.
      await tester.scrollUntilVisible(
        find.text('2 missed'),
        80,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('2 missed'), findsOneWidget);
    },
  );

  testWidgets('drawer also opens over Pond Pro and shows the wash', (
    tester,
  ) async {
    await pumpHome(tester, pondPro: true);
    await openDrawer(tester);

    expect(find.text('Search apps'), findsOneWidget);
    expect(find.text('the resident'), findsOneWidget); // pond still behind
  });

  testWidgets('search filters instantly and restores on clear', (tester) async {
    await pumpHome(tester);
    await openDrawer(tester);

    await tester.enterText(find.byType(TextField), 'clo');
    await tester.pump();

    // One result row + the Clock still on the home grid behind the drawer.
    expect(find.text('Clock'), findsNWidgets(2));
    expect(find.text('Alarm'), findsNothing);
    expect(find.text('A'), findsNothing); // letters hidden while searching

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text('Alarm'), findsOneWidget);
  });

  testWidgets('empty search shows the quiet state', (tester) async {
    await pumpHome(tester);
    await openDrawer(tester);

    await tester.enterText(find.byType(TextField), 'frog');
    await tester.pump();

    expect(find.text('No apps for "frog"'), findsOneWidget);
    expect(find.text('the pond is quiet'), findsOneWidget);
  });

  testWidgets('swipe-down on the header closes the drawer', (tester) async {
    await pumpHome(tester);
    await openDrawer(tester);

    // Fling down on a recents tile (inside the header gesture zone) — a
    // real velocity so primaryVelocity clears the 120 threshold.
    await tester.fling(
      find.text('toadGALLERY').last,
      const Offset(0, 160),
      600,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Search apps'), findsNothing);
  });

  testWidgets('drawer row long-press shows the drawer variant (no Remove)', (
    tester,
  ) async {
    await pumpHome(tester);
    await openDrawer(tester);

    await tester.longPress(find.text('Alarm'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('App info'), findsOneWidget);
    expect(find.text('Remove'), findsNothing); // drawer shows everything
  });

  group('HomeController mutations', () {
    Future<HomeLayout> seeded(ProviderContainer container) async {
      final layout = await container.read(homeLayoutProvider.future);
      return layout;
    }

    test('recordLaunch moves an app to the front of recents, cap 4', () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final layout = await seeded(container);
      expect(layout.recents.first.id, 'family.toad.gallery');

      final camera = layout.allApps.firstWhere((a) => a.id == 'camera');
      container.read(homeLayoutProvider.notifier).recordLaunch(camera);

      final after = container.read(homeLayoutProvider).value!;
      expect(after.recents.first.id, 'camera');
      expect(after.recents.length, 4);
      expect(after.recents.any((a) => a.id == 'family.toad.gallery'), isTrue);
    });

    test('removePageCell drops the app; an emptied page disappears', () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await seeded(container);
      final notifier = container.read(homeLayoutProvider.notifier);

      notifier.removePageCell(0, 1); // Phone
      var layout = container.read(homeLayoutProvider).value!;
      expect(layout.pages[0].length, 7);
      expect(layout.pages.length, 3);

      // Remove every app of page 3 → the page disappears.
      for (var i = layout.pages[2].length - 1; i >= 0; i--) {
        notifier.removePageCell(2, i);
      }
      layout = container.read(homeLayoutProvider).value!;
      expect(layout.pages.length, 2);
    });

    test('renameFolder patches the folders list and the page tile', () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await seeded(container);

      container
          .read(homeLayoutProvider.notifier)
          .renameFolder('media', 'Pond media');

      final layout = container.read(homeLayoutProvider).value!;
      expect(layout.folderById('media')!.title, 'Pond media');
      final tile = layout.pages[1].first as FolderCell;
      expect(tile.folder.title, 'Pond media');
    });

    test(
      'removeAppFromFolder removes the app; empty folders come off',
      () async {
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWith(
              (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
            ),
          ],
        );
        addTearDown(container.dispose);
        await seeded(container);
        final notifier = container.read(homeLayoutProvider.notifier);

        notifier.removeAppFromFolder('media', 'youtube');
        var layout = container.read(homeLayoutProvider).value!;
        expect(layout.folderById('media')!.apps.length, 7);
        expect((layout.pages[1].first as FolderCell).folder.apps.length, 7);

        // Drain the whole folder → the tile leaves the page.
        for (final app in layout.folderById('media')!.apps.toList()) {
          notifier.removeAppFromFolder('media', app.id);
        }
        layout = container.read(homeLayoutProvider).value!;
        expect(layout.folderById('media'), isNull);
        expect(layout.pages[1].first, isA<AppCell>());
      },
    );
  });

  testWidgets('long-press on a grid icon raises the menu; Remove works', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.longPress(find.text('Phone'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('App info'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Edit home screen'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Uninstall…'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Phone'), findsNothing); // gone from page 1
    expect(find.text('Uninstall…'), findsNothing); // menu dismissed
    expect(find.text('Removed "Phone" from this page'), findsOneWidget);
  });

  testWidgets('uninstall is a two-step confirm and can be declined', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.longPress(find.text('Phone'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.text('Uninstall…'));
    await tester.pumpAndSettle();

    expect(find.text('Uninstall "Phone"?'), findsOneWidget);
    expect(find.text('Yes, uninstall it'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(find.text('App info'), findsOneWidget); // back to the items
  });

  testWidgets('empty-space long-press shows the smaller menu', (tester) async {
    await pumpHome(tester);

    // Long-press the hero date — empty space with no child recognizers.
    await tester.longPress(find.text('Tuesday · 24 November'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Wallpaper & style'), findsOneWidget);
    expect(find.text('Home settings'), findsOneWidget);
  });

  testWidgets('folder tile opens the card; rename commits inline', (
    tester,
  ) async {
    await pumpHome(tester);

    // Swipe to page 2 where the Media folder tile leads the grid.
    await tester.drag(find.text('Clock'), const Offset(-420, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('toadPLAYER'), findsOneWidget); // folder content
    expect(find.text('Add app'), findsOneWidget);
    expect(
      find.text('8 apps · long-press an icon to drag out'),
      findsOneWidget,
    );

    // Tap the Caveat title → inline rename.
    await tester.tap(find.text('Media').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pond media');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Pond media'), findsWidgets); // card title updated

    // Tap-outside (scrim above the card) closes.
    await tester.tapAt(const Offset(400, 30));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('Add app'), findsNothing);
  });

  testWidgets('folder item long-press offers "Remove from folder"', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.drag(find.text('Clock'), const Offset(-420, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await tester.longPress(find.text('YouTube'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Remove from folder'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });
}

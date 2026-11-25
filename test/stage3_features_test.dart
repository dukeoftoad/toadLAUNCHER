/// Stage 3 feature tests — edit mode (grid skeleton, selection, resize,
/// hint bubble, undo), widget picker (live previews, pick-to-place),
/// wallpaper & style (papers, theme, accent, shape, Pond Pro), settings
/// hub + sub-pages, and the gesture map (pinch, double-tap, swipes).
library;

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/device/device_bridge.dart'
    show kFallbackVersion;
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/core/theme/toad_theme.dart';
import 'package:toadlauncher/core/theme/toad_tokens.dart';
import 'package:toadlauncher/features/edit/edit_mode.dart'
    show DashedSelectionPainter, GridSkeletonPainter;
import 'package:toadlauncher/features/home/home_controller.dart';
import 'package:toadlauncher/features/home/home_screen.dart';
import 'package:toadlauncher/features/wallpaper_style/wallpaper_style_screen.dart'
    show ToadSwitch;

final DateTime _fixedNow = DateTime(2026, 11, 24, 10, 42); // Tuesday

Future<void> pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWith((ref) => Stream.value(_fixedNow))],
      child: MaterialApp(
        builder: (context, child) =>
            ToadThemeScope(child: child ?? const SizedBox.shrink()),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen, skipOffstage: false)),
);

/// Phone-like surface — the pushed pages are capped at 440 and every
/// assertion target must sit inside one phone viewport.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('APPS'));
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

/// Finds the screen-space rect of the clock widget's dashed selection.
Rect selectionRect(WidgetTester tester) {
  final painter = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is DashedSelectionPainter,
  );
  return tester.getRect(painter);
}

void main() {
  group('settings model — stage 3 fields', () {
    test('json roundtrip keeps wallpaper, clock span, drawer toggles', () {
      const settings = LauncherSettings(
        wallpaperIndex: 3,
        clockSpanW: 2,
        clockSpanH: 4,
        editHintDismissed: true,
        drawerSearch: false,
        drawerRecents: false,
      );
      final restored = LauncherSettings.fromJson(settings.toJson());
      expect(restored.wallpaperIndex, 3);
      expect(restored.clockSpanW, 2);
      expect(restored.clockSpanH, 4);
      expect(restored.editHintDismissed, isTrue);
      expect(restored.drawerSearch, isFalse);
      expect(restored.drawerRecents, isFalse);
    });

    test('clock span clamps to 2..4 × 1..4', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(launcherSettingsProvider.notifier);
      notifier.setClockSpan(w: 9, h: 9);
      expect(container.read(launcherSettingsProvider).clockSpanW, 4);
      expect(container.read(launcherSettingsProvider).clockSpanH, 4);
      notifier.setClockSpan(w: 1, h: 0);
      expect(container.read(launcherSettingsProvider).clockSpanW, 2);
      expect(container.read(launcherSettingsProvider).clockSpanH, 1);
    });
  });

  group('HomeController widget engine', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith((ref) => Stream.value(_fixedNow)),
        ],
      );
    });
    tearDown(() => container.dispose);

    Future<HomeLayout> seeded() => container.read(homeLayoutProvider.future);

    test('clock + memories seeded on page 0; one per kind', () async {
      final layout = await seeded();
      expect(layout.widgetsOnPage(0).first.kind, WidgetKind.clock);
      expect(layout.widgetsOnPage(0)[1].kind, WidgetKind.memories);

      // A second clock is refused.
      expect(
        container
            .read(homeLayoutProvider.notifier)
            .placeWidget(WidgetKind.clock, page: 0),
        isFalse,
      );
    });

    test('place → resize → move → undo restores layout + settings', () async {
      await seeded();
      final notifier = container.read(homeLayoutProvider.notifier);

      expect(notifier.placeWidget(WidgetKind.calendar, page: 0), isTrue);
      var layout = container.read(homeLayoutProvider).value!;
      expect(layout.widgetsOnPage(0).length, 3);
      expect(layout.widgetsOnPage(0).last.kind, WidgetKind.calendar);

      // Resize the clock to 2×4 — the UI snapshots at gesture start and
      // commits at gesture end; mirror that protocol here.
      final preResize = notifier.snapshot();
      notifier.resizeWidget('widget-clock', w: 2, h: 4);
      notifier.commitAction(preResize);
      expect(container.read(launcherSettingsProvider).clockSpanW, 2);
      expect(container.read(launcherSettingsProvider).clockSpanH, 4);

      // Move calendar to the top of the stack.
      final calendarId = container
          .read(homeLayoutProvider)
          .value!
          .widgetsOnPage(0)
          .last
          .id;
      final preMove = notifier.snapshot();
      notifier.moveWidget(calendarId, newIndex: 0);
      notifier.commitAction(preMove);
      expect(
        container.read(homeLayoutProvider).value!.widgetsOnPage(0).first.kind,
        WidgetKind.calendar,
      );

      // Undo thrice → stack order back, then clock span back, then un-place.
      notifier.undo();
      expect(
        container.read(homeLayoutProvider).value!.widgetsOnPage(0).last.kind,
        WidgetKind.calendar,
      );
      notifier.undo();
      expect(container.read(launcherSettingsProvider).clockSpanH, 1);
      notifier.undo();
      expect(
        container
            .read(homeLayoutProvider)
            .value!
            .widgets
            .any((w) => w.kind == WidgetKind.calendar),
        isFalse,
      );
    });

    test('removeWidget takes it off the page', () async {
      await seeded();
      final notifier = container.read(homeLayoutProvider.notifier);
      notifier.removeWidget('widget-memories', message: 'Widget removed');
      expect(
        container
            .read(homeLayoutProvider)
            .value!
            .widgets
            .any((w) => w.kind == WidgetKind.memories),
        isFalse,
      );
    });
  });

  testWidgets('edit mode: entry from the menu, skeleton, strip, done', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.longPress(find.text('Phone'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('Edit home screen'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Bottom strip replaced the dock; Done pill present.
    expect(find.text('Wallpapers'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Honest grid skeleton painted over the page area.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is GridSkeletonPainter,
      ),
      findsOneWidget,
    );

    // The hint bubble teaches once.
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Got it'), findsNothing);
    expect(
      containerOf(tester).read(launcherSettingsProvider).editHintDismissed,
      isTrue,
    );

    // Done exits back to the dock.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Done'), findsNothing);
    expect(find.text('APPS'), findsOneWidget);
  });

  testWidgets('clock selection shows dashed outline; resize re-renders live', (
    tester,
  ) async {
    await pumpHome(tester);

    final container = containerOf(tester);
    container.read(editModeProvider.notifier).enter();
    await tester.pumpAndSettle();

    await tester.tap(find.text('10:42'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedSelectionPainter,
      ),
      findsOneWidget,
    );
    expect(find.text('Remove'), findsOneWidget);

    // Drag the bottom-right handle down by ~3 rows → the clock re-renders.
    final rect = selectionRect(tester);
    final corner = rect.bottomRight - const Offset(4, 4);
    final gesture = await tester.startGesture(corner);
    await gesture.moveBy(const Offset(0, 90));
    await gesture.moveBy(const Offset(0, 90));
    await gesture.moveBy(const Offset(0, 90));
    await gesture.up();
    // Let the snackbar slide fully in before reaching for its Undo pill.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(launcherSettingsProvider).clockSpanH, 4);

    // The clock text scaled up past the hero size.
    final timeStyle = tester.widget<Text>(find.text('10:42')).style!;
    expect(timeStyle.fontSize, greaterThan(ToadMetrics.heroClockSize));

    // Per-action undo restores the hero span.
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(launcherSettingsProvider).clockSpanH, 1);
  });

  testWidgets('widget picker: live previews, honest states, pick-to-place', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpHome(tester);

    final container = containerOf(tester);
    container.read(editModeProvider.notifier).enter();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Widgets'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Featured family citizen + the honest sizes.
    expect(find.text('toadGALLERY · Memories'), findsOneWidget);
    expect(find.textContaining('already on your home'), findsOneWidget);
    expect(find.text('Caveat clock'), findsOneWidget);
    expect(find.textContaining('already placed'), findsOneWidget);
    expect(find.text('Month calendar'), findsOneWidget);
    expect(find.text('toadLIST note'), findsOneWidget);

    // Featured tap (already placed) → calm toast, no crash.
    await tester.tap(find.text('toadGALLERY · Memories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Memories is already pinned on your home'),
      findsOneWidget,
    );

    // Let the toast retire so it no longer covers the bottom strip.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    // Pick the calendar → straight into edit mode with the ghost.
    container.read(editModeProvider.notifier).enter();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Widgets'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.tap(find.text('Month calendar'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Drag onto home to place — it snaps to the grid'),
      findsOneWidget,
    );

    // Drag the ghost chip onto the page area → it snaps into the stack.
    final chip = find.byType(Draggable<WidgetKind>);
    final chipRect = tester.getRect(chip);
    await gestureDrag(tester, chipRect.center, const Offset(0, -180));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.textContaining('Placed on page 1'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget); // live render
    expect(
      container
          .read(homeLayoutProvider)
          .value!
          .widgetsOnPage(0)
          .any((w) => w.kind == WidgetKind.calendar),
      isTrue,
    );
  });

  testWidgets('wallpaper & style: papers, theme, accent, shape, pond', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpHome(tester);

    await tester.longPress(find.text('Tuesday · 24 November'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('Wallpaper & style'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final container = containerOf(tester);
    // The pushed page — back to HomeScreen's container works through the
    // scope (same ProviderScope).
    expect(find.text('POND PRO'), findsOneWidget);
    expect(find.text('WALLPAPER'), findsOneWidget);
    expect(find.text('sage paper'), findsOneWidget);

    // Theme mode → Dark, live (scroll — the pond pack rows sit above it).
    await tester.scrollUntilVisible(
      find.text('Dark'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).skinMode, SkinMode.dark);

    // Wallpaper thumb → gold (scroll back up).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('paper-1')),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('paper-1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).wallpaperIndex, 1);
    // The hero banner lives at the top of the (lazy) ListView — assert its
    // label through the scope instead of the tree.

    // Accent → clay, live re-tint.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accent-clay')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('accent-clay')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).accent, AccentOption.clay);

    // Icon shape → circle.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shape-circle')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('shape-circle')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container.read(launcherSettingsProvider).iconShape,
      IconShape.circle,
    );

    // Pond Pro switch flips the whole home into the scene skin (the pond's
    // ambient loop keeps running below, so pump fixed steps, never settle).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('switch-pond')),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(ToadSwitch).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(launcherSettingsProvider).pondPro, isTrue);

    // The pond pack rows — rain, calm, battery guard — all live here.
    await tester.scrollUntilVisible(
      find.text('Calm pond'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Rain shower'), findsOneWidget);
    expect(find.text('Calm pond'), findsOneWidget);
    expect(find.text('Battery guard'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('switch-calm')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).calmPond, isTrue);
  });

  testWidgets('settings hub: honest subtitles + gestures apply live', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpHome(tester);

    await tester.longPress(find.text('Tuesday · 24 November'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('Home settings'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Sketchbook · auto · squircle icons'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('No analytics · no network permission'), findsOneWidget);
    // v0.12 added Permissions & Battery rows — the About row and the
    // family footer now sit below the fold on phone surfaces; scroll to
    // them, then back up for the Gestures tap.
    await tester.scrollUntilVisible(
      find.text('$kFallbackVersion · part of the toad family'),
      60,
    );
    expect(
      find.text('$kFallbackVersion · part of the toad family'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('toadLAUNCHER · one family with toadGALLERY & toadPLAYER'),
      60,
    );
    expect(
      find.text('toadLAUNCHER · one family with toadGALLERY & toadPLAYER'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Gestures'), 100);

    // Gestures sub-page.
    await tester.tap(find.text('Gestures'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Double-tap to sleep'), findsOneWidget);
    expect(find.textContaining('Off by default — can clash'), findsOneWidget);

    final container = containerOf(tester);
    // Toggle the double-tap switch off (the first ToadSwitch row).
    await tester.tap(find.byType(ToadSwitch).at(1));
    await tester.pumpAndSettle();
    expect(container.read(launcherSettingsProvider).doubleTapSleep, isFalse);

    // Back to the hub, then Dock & drawer: turn search off live.
    await tester.tap(find.text('‹').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('Dock & drawer'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await tester.tap(find.byType(ToadSwitch).first);
    await tester.pumpAndSettle();
    expect(container.read(launcherSettingsProvider).drawerSearch, isFalse);

    await tester.tap(find.text('‹').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.text('‹').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    await openDrawer(tester);
    expect(find.text('Search apps'), findsNothing); // honest live apply
    expect(find.text('A'), findsOneWidget); // the index still there
  });

  testWidgets('pinch-in enters edit mode (opt-out switch)', (tester) async {
    await pumpHome(tester);

    final center = tester.getCenter(find.text('10:42'));
    final g1 = await tester.startGesture(center - const Offset(90, 0));
    final g2 = await tester.startGesture(center + const Offset(90, 0));
    // Interleaved small steps toward each other — a pinch-in measured by
    // the raw-pointer detector (distance shrinks past 25%).
    for (var i = 0; i < 6; i++) {
      await g1.moveBy(const Offset(14, -4));
      await g2.moveBy(const Offset(-14, -4));
    }
    await tester.pump(const Duration(milliseconds: 50));
    await g1.up();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('double-tap sleep + swipe-down shade stay honest in demo', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('10:42'), warnIfMissed: false);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('10:42'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Double-tap sleep needs a real device'),
      findsOneWidget,
    );

    // Swipe down on the hero → notifications demo toast.
    await tester.fling(
      find.text('Tuesday · 24 November'),
      const Offset(0, 220),
      700,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(
      find.textContaining('notification shade is a system surface'),
      findsOneWidget,
    );
  });

  testWidgets('dock-area swipe down opens the drawer with search (opt-in)', (
    tester,
  ) async {
    await pumpHome(tester);

    final container = containerOf(tester);
    container
        .read(launcherSettingsProvider.notifier)
        .patchDockAreaSwipeSearch(true);
    await tester.pump();

    await tester.fling(find.text('APPS'), const Offset(0, 180), 700);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Search apps'), findsOneWidget);
  });
}

/// Drag helper that survives Draggable's touch slop.
Future<void> gestureDrag(WidgetTester tester, Offset from, Offset delta) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.up();
}

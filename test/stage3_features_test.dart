library;

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/device/device_bridge.dart'
    show DeviceBridge, kFallbackVersion;
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

final DateTime _fixedNow = DateTime(2026, 11, 24, 10, 42);

Future<void> pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'toadlauncher.settings.v1': '{"clockHourFormat": 2}',
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel(DeviceBridge.channelName),
        (call) async => null,
      );
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

void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('APPS'));
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

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

      final preResize = notifier.snapshot();
      notifier.resizeWidget('widget-clock', w: 2, h: 4);
      notifier.commitAction(preResize);
      expect(container.read(launcherSettingsProvider).clockSpanW, 2);
      expect(container.read(launcherSettingsProvider).clockSpanH, 4);

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

    expect(find.text('Wallpapers'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is GridSkeletonPainter,
      ),
      findsOneWidget,
    );

    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Got it'), findsNothing);
    expect(
      containerOf(tester).read(launcherSettingsProvider).editHintDismissed,
      isTrue,
    );

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

    final rect = selectionRect(tester);
    final corner = rect.bottomRight - const Offset(4, 4);
    final gesture = await tester.startGesture(corner);
    await gesture.moveBy(const Offset(0, 90));
    await gesture.moveBy(const Offset(0, 90));
    await gesture.moveBy(const Offset(0, 90));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(launcherSettingsProvider).clockSpanH, 4);

    final timeStyle = tester.widget<Text>(find.text('10:42')).style!;
    expect(timeStyle.fontSize, greaterThan(ToadMetrics.heroClockSize));

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

    expect(find.text('toadGALLERY · Memories'), findsOneWidget);
    expect(find.textContaining('already on your home'), findsOneWidget);
    expect(find.text('Caveat clock'), findsOneWidget);
    expect(find.textContaining('already placed'), findsOneWidget);
    expect(find.text('Month calendar'), findsOneWidget);
    expect(find.text('toadLIST note'), findsOneWidget);

    await tester.tap(find.text('toadGALLERY · Memories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Memories is already pinned on your home'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

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

    final chip = find.byType(Draggable<WidgetKind>);
    final chipRect = tester.getRect(chip);
    await gestureDrag(tester, chipRect.center, const Offset(0, -180));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.textContaining('Placed on page 1'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
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
    expect(find.text('POND PRO'), findsOneWidget);
    expect(find.text('WALLPAPER'), findsOneWidget);
    expect(find.text('sage paper'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dark'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).skinMode, SkinMode.dark);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('paper-1')),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('paper-1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).wallpaperIndex, 1);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accent-clay')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('accent-clay')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(launcherSettingsProvider).accent, AccentOption.clay);

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
    await tester.scrollUntilVisible(find.text('‹'), -100);

    await tester.tap(find.text('Gestures'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Double-tap to sleep'), findsOneWidget);
    expect(find.textContaining('Off by default — takes the shot'), findsOneWidget);

    final container = containerOf(tester);
    await tester.tap(find.byType(ToadSwitch).at(1));
    await tester.pumpAndSettle();
    expect(container.read(launcherSettingsProvider).doubleTapSleep, isFalse);

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
    expect(find.text('Search apps'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('pinch-in enters edit mode (opt-out switch)', (tester) async {
    await pumpHome(tester);

    final center = tester.getCenter(find.text('10:42'));
    final g1 = await tester.startGesture(center - const Offset(90, 0));
    final g2 = await tester.startGesture(center + const Offset(90, 0));
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

Future<void> gestureDrag(WidgetTester tester, Offset from, Offset delta) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.moveBy(delta * 0.25);
  await gesture.up();
}

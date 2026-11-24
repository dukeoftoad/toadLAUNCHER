/// Stage 4 feature tests — the ambient engine (blink schedule, calm
/// freeze, rain flag, croak on tap), calm-pond night fall, and the
/// drag-tracked mouth drawer thresholds (release ≥40% keeps it open).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/core/theme/toad_theme.dart';
import 'package:toadlauncher/features/pond/mouth_drawer.dart' show MouthDrawer;
import 'package:toadlauncher/features/pond/pond_ambient.dart';
import 'package:toadlauncher/features/pond/pond_scene_painter.dart';
import 'package:toadlauncher/features/pond/pond_home.dart';
import 'package:toadlauncher/features/pond/resident_toad_painter.dart';

final DateTime _noon = DateTime(2026, 11, 24, 12, 0); // broad daylight

Future<void> pumpPond(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWith((ref) => Stream.value(_noon))],
      child: MaterialApp(
        builder: (context, child) =>
            ToadThemeScope(child: child ?? const SizedBox.shrink()),
        home: const PondHome(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('ambient engine', () {
    test('blink schedule: blinks at cycle starts, 5–8 s apart', () {
      expect(blinkAt(Duration.zero), isTrue);
      expect(blinkAt(const Duration(seconds: 1)), isFalse);
      // Cycles stay within the 5–8 s band.
      for (var i = 0; i < 50; i++) {
        final len = blinkCycleLength(i);
        expect(len, greaterThanOrEqualTo(5.0));
        expect(len, lessThanOrEqualTo(8.0));
      }
      // Two frames only — the 180 ms eyelid swap.
      expect(blinkAt(const Duration(milliseconds: 180)), isFalse);
    });

    testWidgets('the ambient clock advances while awake', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      Duration? seen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWith((ref) => Stream.value(_noon))],
          child: MaterialApp(
            builder: (context, child) =>
                ToadThemeScope(child: child ?? const SizedBox.shrink()),
            home: PondAmbient(
              builder: (context, elapsed) => AnimatedBuilder(
                animation: elapsed,
                builder: (context, _) {
                  seen = elapsed.value;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final first = seen ?? Duration.zero;
      await tester.pump(const Duration(milliseconds: 600));
      expect(seen, isNot(first));
      expect(seen!, greaterThan(first));
    });

    testWidgets('calm pond freezes the clock', (tester) async {
      // Calm arrives through persisted settings — restored on provider build.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'toadlauncher.settings.v1': jsonEncode(
          const LauncherSettings(calmPond: true).toJson(),
        ),
      });

      Duration? seen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWith((ref) => Stream.value(_noon))],
          child: MaterialApp(
            builder: (context, child) =>
                ToadThemeScope(child: child ?? const SizedBox.shrink()),
            home: PondAmbient(
              builder: (context, elapsed) => AnimatedBuilder(
                animation: elapsed,
                builder: (context, _) {
                  seen = elapsed.value;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final frozen = seen;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(seen, frozen); // "a still painting — zero animation cost"
    });
  });

  group('calm pond + battery guard', () {
    test('calm falls night instantly, battery guard is honest', () {
      final calm = resolveSkin(
        mode: SkinMode.system,
        pondPro: true,
        systemBrightness: Brightness.light,
        now: _noon,
        sunsetHour: 19,
        sunsetMinute: 30,
        sunriseHour: 6,
        sunriseMinute: 30,
        pondCalm: true,
      );
      expect(calm, ResolvedSkin.pondNight); // night falls instantly

      // Battery guard alone never fakes night in demo — device reads it.
      final guardOnly = resolveSkin(
        mode: SkinMode.system,
        pondPro: true,
        systemBrightness: Brightness.light,
        now: _noon,
        sunsetHour: 19,
        sunsetMinute: 30,
        sunriseHour: 6,
        sunriseMinute: 30,
      );
      expect(guardOnly, ResolvedSkin.pondDay);
    });

    testWidgets('rain toggle reaches the scene painter', (tester) async {
      await pumpPond(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PondHome)),
      );
      container.read(launcherSettingsProvider.notifier).setPondRain(true);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is PondScenePainter,
                    ),
                  )
                  .painter!
              as PondScenePainter;
      expect(painter.rain, isTrue);
    });
  });

  testWidgets('tapping the resident croaks — throat scale 900 ms', (
    tester,
  ) async {
    await pumpPond(tester);

    await tester.tap(find.text('the resident'));
    await tester.pump(const Duration(milliseconds: 120)); // anchor tick
    await tester.pump(const Duration(milliseconds: 120)); // mid-croak

    // The croak drives the painter mid-throat-puff.
    final painters = tester.widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ResidentToadPainter,
      ),
    );
    final croaking = painters.any(
      (w) => (w.painter! as ResidentToadPainter).croak > 0,
    );
    expect(croaking, isTrue);
  });

  testWidgets('mouth release above 40% stays open; below swallows', (
    tester,
  ) async {
    await pumpPond(tester);

    await tester.tap(find.text('APPS'));
    await tester.pump(const Duration(milliseconds: 500)); // mount
    await tester.pump(const Duration(milliseconds: 380)); // anchor
    await tester.pump(const Duration(milliseconds: 380)); // wide open
    expect(find.text('what fly do you seek?'), findsOneWidget);

    // Drag partway down (≈180 px of the 55%-height track) → openness ≈ 0.55
    // → above the 40% threshold → the mouth stays seated.
    await tester.dragFrom(const Offset(60, 80), const Offset(0, 180));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 380));
    expect(find.byType(MouthDrawer), findsOneWidget);
    expect(find.text('what fly do you seek?'), findsOneWidget);

    // Now drag the rest of the way — release below 40% → swallow.
    await tester.dragFrom(const Offset(60, 80), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('what fly do you seek?'), findsNothing);
  });
}

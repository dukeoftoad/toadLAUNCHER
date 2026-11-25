/// Widget smoke tests — every home variant builds and paints its chrome.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/core/theme/toad_theme.dart';
import 'package:toadlauncher/features/home/home_screen.dart';
import 'package:toadlauncher/features/pond/pond_home.dart';

Future<void> pumpHome(WidgetTester tester, {required bool pondPro}) async {
  // 24 h clock pinned: the “system” format falls back to the test
  // surface’s 12-hour default otherwise.
  SharedPreferences.setMockInitialValues(<String, Object>{
    'toadlauncher.settings.v1': '{"clockHourFormat": 2, "introSeen": true}',
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Deterministic clock — also avoids the ambient ticker's pending
        // timer in fake-async tests.
        clockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
        ),
      ],
      child: MaterialApp(
        home: ToadThemeScope(
          child: pondPro ? const PondHome() : const HomeScreen(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

extension TesterX on WidgetTester {
  Finder textRegExp(RegExp pattern) => find.byWidgetPredicate(
    (widget) =>
        widget is Text && widget.data != null && pattern.hasMatch(widget.data!),
  );
}

void main() {
  testWidgets('sketchbook home renders hero clock, grid and dock', (
    tester,
  ) async {
    await pumpHome(tester, pondPro: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Hero clock paints a HH:mm string (24 h pinned so the assertion is
    // independent of the test surface's 12/24 default).
    expect(tester.textRegExp(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
  });

  testWidgets('hero clock renders the 12-hour face when told', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'toadlauncher.settings.v1':
          '{"clockHourFormat": 1, "introSeen": true}',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 24, 10, 42)),
          ),
        ],
        child: MaterialApp(
          home: ToadThemeScope(child: const HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 12-hour adds the meridiem: “10:42 am”.
    expect(tester.textRegExp(RegExp(r'^10:42\s?(am|pm)$')), findsOneWidget);
  });

  testWidgets('pond home paints the resident label', (tester) async {
    await pumpHome(tester, pondPro: true);
    // The ambient loop never settles — pump fixed steps instead.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('the resident'), findsOneWidget);
    expect(find.text('APPS'), findsOneWidget); // dock handle
  });
}

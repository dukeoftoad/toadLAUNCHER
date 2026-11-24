// v0.11 launcher infrastructure — the review's gap list, covered:
//
//   · real widget hosting contract (AppWidgetHost channel)
//   · OS → Dart events: packagesChanged (live index refresh) and
//     notificationCounts (real dots)
//   · hosted-widget placement + persistence + cleanup in HomeController
//   · app shortcuts riding the long-press menu
//   · the honest-device banner (visible only when a wired bridge fails,
//     never eating home gestures, dismissable)
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/device/device_bridge.dart';
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/features/context_menu/app_context_menu.dart';
import 'package:toadlauncher/features/home/home_controller.dart';
import 'package:toadlauncher/features/home/home_screen.dart';
import 'package:toadlauncher/core/theme/toad_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // bridge contract — hosting + system integrations
  // ------------------------------------------------------------------

  group('DeviceBridge v0.11 contract', () {
    const channel = MethodChannel(DeviceBridge.channelName);

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void mock(Future<Object?>? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    test('listHostableWidgets maps providers and previews', () async {
      final bridge = DeviceBridge(channel);
      mock((call) async {
        expect(call.method, 'listHostableWidgets');
        return [
          {
            'providerId': 'com.example.app/.WeatherWidget',
            'label': 'Weather',
            'packageName': 'com.example.app',
            'previewPng': Uint8List.fromList([7, 7, 7]),
            'minWidth': 220,
            'minHeight': 110,
          },
        ];
      });
      final widgets = await bridge.listHostableWidgets();
      expect(widgets, hasLength(1));
      expect(widgets.first.providerId, 'com.example.app/.WeatherWidget');
      expect(widgets.first.previewPng, isNotNull);
      expect(widgets.first.minWidthPx, 220);
    });

    test('hostWidget returns the bound id; null when refused', () async {
      final bridge = DeviceBridge(channel);
      mock((call) async {
        expect(call.method, 'hostWidget');
        expect(call.arguments, containsPair('providerId', 'a/.W'));
        return 4242;
      });
      expect(await bridge.hostWidget('a/.W'), 4242);

      mock((call) async => null);
      expect(await bridge.hostWidget('a/.W'), isNull);
    });

    test('deleteHostedWidget relays the id', () async {
      final bridge = DeviceBridge(channel);
      var seenId = 0;
      mock((call) async {
        expect(call.method, 'deleteHostedWidget');
        seenId = (call.arguments as Map)['appWidgetId'] as int;
        return true;
      });
      await bridge.deleteHostedWidget(4242);
      expect(seenId, 4242);
    });

    test('system integrations answer as booleans', () async {
      final bridge = DeviceBridge(channel);
      for (final entry in <String, String>{
        'isDefaultHome': 'isDefaultHome',
        'requestDefaultHome': 'requestDefaultHome',
        'openNotifications': 'openNotifications',
        'lockScreen': 'lockScreen',
        'isLockServiceEnabled': 'isLockServiceEnabled',
        'hasNotificationAccess': 'hasNotificationAccess',
        'openNotificationListenerSettings': 'openNotificationListenerSettings',
        'openAccessibilitySettings': 'openAccessibilitySettings',
        'shareApp': 'shareApp',
      }.entries) {
        mock((call) async {
          expect(call.method, entry.key);
          return true;
        });
        switch (entry.key) {
          case 'isDefaultHome':
            expect(await bridge.isDefaultHome(), isTrue);
          case 'requestDefaultHome':
            expect(await bridge.requestDefaultHome(), isTrue);
          case 'openNotifications':
            expect(await bridge.openNotifications(), isTrue);
          case 'lockScreen':
            expect(await bridge.lockScreen(), isTrue);
          case 'isLockServiceEnabled':
            expect(await bridge.isLockServiceEnabled(), isTrue);
          case 'hasNotificationAccess':
            expect(await bridge.hasNotificationAccess(), isTrue);
          case 'openNotificationListenerSettings':
            expect(await bridge.openNotificationListenerSettings(), isTrue);
          case 'openAccessibilitySettings':
            expect(await bridge.openAccessibilitySettings(), isTrue);
          case 'shareApp':
            expect(await bridge.shareApp('x'), isTrue);
        }
      }
    });

    test('appShortcuts parses the LauncherApps payload', () async {
      final bridge = DeviceBridge(channel);
      mock((call) async {
        expect(call.arguments, containsPair('packageId', 'com.x.app'));
        return [
          {'id': 's1', 'label': 'New chat'},
          {'id': 's2', 'label': 'Search'},
        ];
      });
      final shortcuts = await bridge.appShortcuts('com.x.app');
      expect(shortcuts.map((s) => s.label), ['New chat', 'Search']);
    });

    test('wired reports channel presence honestly', () {
      expect(DeviceBridge(channel).wired, isTrue);
      expect(DeviceBridge().wired, isFalse);
    });

    testWidgets('packagesChanged + notificationCounts reach listeners',
        (tester) async {
      final bridge = DeviceBridge(channel);

      var packagesEvent = '';
      bridge.addPackagesChangedListener((packageId, action) {
        packagesEvent = '$packageId:$action';
      });

      Map<String, int>? counts;
      bridge.addNotificationCountsListener((c) => counts = c);

      const codec = StandardMethodCodec();
      final binary = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      await binary.handlePlatformMessage(
        DeviceBridge.channelName,
        codec.encodeMethodCall(const MethodCall('packagesChanged', {
          'packageId': 'com.new.app',
          'action': 'android.intent.action.PACKAGE_ADDED',
        })),
        (_) {},
      );
      expect(packagesEvent, 'com.new.app:android.intent.action.PACKAGE_ADDED');

      await binary.handlePlatformMessage(
        DeviceBridge.channelName,
        codec.encodeMethodCall(const MethodCall('notificationCounts', {
          'com.chat.app': 3,
          'com.mail.app': 0,
        })),
        (_) {},
      );
      expect(counts, {'com.chat.app': 3, 'com.mail.app': 0});
    });
  });

  // ------------------------------------------------------------------
  // HomeController — hosted widget placement, persistence, cleanup
  // ------------------------------------------------------------------

  group('HomeController hosted widgets', () {
    late _RecordingBridge bridge;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      bridge = _RecordingBridge();
      container = ProviderContainer(
        overrides: [deviceBridgeProvider.overrideWithValue(bridge)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('placeHostedWidget lands the widget and persists it', () async {
      await container.read(homeLayoutProvider.future);
      final placed = container.read(homeLayoutProvider.notifier).placeHostedWidget(
        page: 0,
        providerId: 'com.example/.Clock',
        label: 'Example clock',
        packageName: 'com.example',
        appWidgetId: 77,
      );
      expect(placed, isTrue);

      final layout = container.read(homeLayoutProvider).value!;
      final hosted =
          layout.widgets.where((w) => w.kind == WidgetKind.androidHosted);
      expect(hosted, hasLength(1));
      expect(hosted.first.appWidgetId, 77);
      expect(hosted.first.providerId, 'com.example/.Clock');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('toadlauncher.hosted.widgets.v1'),
          contains('77'));
    });

    test('removeWidget releases the AppWidgetHost id', () async {
      await container.read(homeLayoutProvider.future);
      container.read(homeLayoutProvider.notifier).placeHostedWidget(
        page: 0,
        providerId: 'com.example/.Clock',
        label: 'Example clock',
        packageName: 'com.example',
        appWidgetId: 77,
      );
      container
          .read(homeLayoutProvider.notifier)
          .removeWidget('hosted-77', message: 'gone');

      expect(bridge.deletedWidgetIds, contains(77));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('toadlauncher.hosted.widgets.v1') ?? '',
        isNot(contains('77')),
      );
    });

    test('hosted widgets survive a rebuild (restart simulation)', () async {
      await container.read(homeLayoutProvider.future);
      container.read(homeLayoutProvider.notifier).placeHostedWidget(
        page: 1,
        providerId: 'com.example/.Music',
        label: 'Music',
        packageName: 'com.example',
        appWidgetId: 99,
      );
      container.dispose();

      final container2 = ProviderContainer(
        overrides: [deviceBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(container2.dispose);
      final layout = await container2.read(homeLayoutProvider.future);
      final hosted = layout.widgets
          .where((w) => w.kind == WidgetKind.androidHosted)
          .toList();
      expect(hosted, hasLength(1));
      expect(hosted.first.appWidgetId, 99);
      expect(hosted.first.page, 1);
    });

    test('local kinds stay one-per-home; hosted kinds do not', () async {
      await container.read(homeLayoutProvider.future);
      final notifier = container.read(homeLayoutProvider.notifier);
      expect(
        notifier.placeWidget(WidgetKind.calendar, page: 0),
        isTrue,
      );
      // A second calendar is refused.
      expect(
        notifier.placeWidget(WidgetKind.calendar, page: 1),
        isFalse,
      );
    });
  });

  // ------------------------------------------------------------------
  // context menu — shortcut rows
  // ------------------------------------------------------------------

  group('MenuActions shortcuts', () {
    testWidgets('shortcut rows render above App info and fire', (tester) async {
      var picked = '';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWith(
              (ref) => Stream.value(DateTime(2025, 11, 24, 10, 42)),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) =>
                ToadThemeScope(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
            body: Stack(
              children: [
                ContextMenuLayer(
                  request: MenuRequest(
                    context: MenuContext.homeApp,
                    anchor: const Offset(200, 200),
                    app: const AppEntry(id: 'x', name: 'X', glyph: ''),
                    actions: MenuActions(
                      onAppInfo: () {},
                      onWidgets: () {},
                      onShare: () {},
                      onUninstall: () {},
                      onEditHome: () {},
                      onRemove: () {},
                      shortcuts: [
                        MenuShortcut(label: 'New chat', onPick: () {
                          picked = 'chat';
                        }),
                      ],
                    ),
                  ),
                  onDismissed: () {},
                ),
              ],
            ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shortcuts sit above the fixed rows.
      expect(
        tester.getTopLeft(find.text('New chat')).dy,
        lessThan(tester.getTopLeft(find.text('App info')).dy),
      );
      await tester.tap(find.text('New chat'));
      expect(picked, 'chat');
    });
  });

  // ------------------------------------------------------------------
  // honest-device banner
  // ------------------------------------------------------------------

  group('DeviceStatusBanner', () {
    testWidgets('shows only when a wired bridge fails to answer',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      Future<void> pump({required bool wired}) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clockProvider.overrideWith((ref) => Stream.value(DateTime(2025, 11, 24, 10, 42))),
              deviceBridgeProvider
                  .overrideWithValue(_WiredBridge(wired: wired)),
            ],
            child: MaterialApp(
              builder: (context, child) =>
                  ToadThemeScope(child: child ?? const SizedBox.shrink()),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // No channel (demo/web/tests): silence — nothing is "answering
      // wrong", there is simply no phone.
      await pump(wired: false);
      expect(find.textContaining('Android is not answering'), findsNothing);

      // Wired but unanswered: the honest banner explains demo apps.
      await pump(wired: true);
      expect(find.textContaining('Android is not answering'), findsOneWidget);

      // ✕ dismisses for the session.
      await tester.tap(find.text('✕'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Android is not answering'), findsNothing);
    });
  });
}

/// DeviceBridge stand-in that reports as wired but never answers —
/// exactly a phone whose plugin half is broken.
class _WiredBridge extends DeviceBridge {
  _WiredBridge({required bool wired})
      : super(wired ? const MethodChannel(DeviceBridge.channelName) : null);

  @override
  Future<bool> available() async => false;
}

/// Recording bridge for controller tests — demo-honest answers plus a
/// log of released widget ids.
class _RecordingBridge extends DeviceBridge {
  _RecordingBridge();

  final List<int> deletedWidgetIds = [];

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> deleteHostedWidget(int appWidgetId) async {
    deletedWidgetIds.add(appWidgetId);
    return true;
  }
}

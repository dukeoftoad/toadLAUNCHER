library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/device/device_bridge.dart';
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/reliability/safe_store.dart';
import 'package:toadlauncher/core/repositories/app_snapshot_store.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/features/focus/focus_controller.dart';
import 'package:toadlauncher/features/home/grid_flow.dart';
import 'package:toadlauncher/features/home/home_controller.dart';

void main() {
  group('REL-02 SafeStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('write envelopes the payload with a version; read decodes it',
        () async {
      final store = SafeStore('x.v1', schemaVersion: 2);
      await store.write(<String, Object>{'a': 1});

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('x.v1')!;
      expect(jsonDecode(raw)['v'], 2);

      final read = await store.read<Map>((json) => json is Map ? json : null);
      expect(read!['a'], 1);
    });

    test('write demotes the previous primary to the mirror slot', () async {
      final store = SafeStore('x.v1', schemaVersion: 2);
      await store.write(<String, Object>{'a': 1});
      await store.write(<String, Object>{'a': 2});

      final prefs = await SharedPreferences.getInstance();
      final mirror = jsonDecode(prefs.getString('x.v1.bak')!) as Map;
      expect(mirror['data']['a'], 1);
    });

    test('corrupt primary falls back to the mirror', () async {
      final store = SafeStore('x.v1', schemaVersion: 2);
      await store.write(<String, Object>{'a': 'one'});
      await store.write(<String, Object>{'a': 'two'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('x.v1', '{not json');

      final read = await store.read<Map>((json) => json is Map ? json : null);
      expect(read!['a'], 'one');
    });

    test('semantically invalid primary falls back to the mirror', () async {
      final store = SafeStore('x.v1', schemaVersion: 2);
      await store.write(<String, Object>{'a': 'one'});
      await store.write(<String, Object>{'a': 'two'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('x.v1', jsonEncode({'v': 2, 'data': 'junk'}));

      final read = await store.read<Map>(
        (json) => json is Map && json['a'] != null ? json : null,
      );
      expect(read!['a'], 'one');
    });

    test('legacy payloads without a version are accepted (migration path)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'toadlauncher.settings.v1',
        '{"introSeen": true}',
      );
      final store = SafeStore('toadlauncher.settings.v1', schemaVersion: 2);
      final read = await store.read<LauncherSettings>(
        (json) => json is Map
            ? LauncherSettings.fromJson(json.cast<String, Object?>())
            : null,
      );
      expect(read!.introSeen, isTrue);
    });

    test('newer-than-known versions are rejected', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('x.v1', jsonEncode({'v': 99, 'data': {'a': 1}}));
      final store = SafeStore('x.v1', schemaVersion: 2);
      final read = await store.read<Map>((json) => json is Map ? json : null);
      expect(read, isNull);
    });

    test('wipe clears both slots', () async {
      final store = SafeStore('x.v1', schemaVersion: 2);
      await store.write(<String, Object>{'a': 1});
      await store.write(<String, Object>{'a': 2});
      await store.wipe();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('x.v1'), isNull);
      expect(prefs.getString('x.v1.bak'), isNull);
    });
  });

  group('FEAT-01 grid flow', () {
    AppEntry app(String id) =>
        AppEntry(id: id, name: id, glyph: 'x', packageName: id);

    test('widgets claim spans; apps flow into the remaining cells', () {
      final flow = computeGridFlow(
        cells: [for (var i = 0; i < 8; i++) AppCell(app('a$i'))],
        widgets: [
          const PlacedWidget(
            id: 'w',
            kind: WidgetKind.clock,
            page: 0,
            row: 0,
            col: 0,
            w: 4,
            h: 2,
          ),
        ],
        columns: 4,
      );

      expect(flow.slotOf('w'), const GridSlot(0, 0));
      expect(
        flow.cellSlots.map((s) => (s.row, s.col)).toSet(),
        {
          (2, 0), (2, 1), (2, 2), (2, 3),
          (3, 0), (3, 1), (3, 2), (3, 3),
        },
      );
      expect(flow.rows, 4);
    });

    test('legacy widgets without a position settle first-fit', () {
      final flow = computeGridFlow(
        cells: const [],
        widgets: [
          const PlacedWidget(
            id: 'clock',
            kind: WidgetKind.clock,
            page: 0,
            w: 4,
            h: 1,
          ),
          const PlacedWidget(
            id: 'sticky',
            kind: WidgetKind.sticky,
            page: 0,
            w: 2,
            h: 2,
          ),
        ],
        columns: 4,
      );

      expect(flow.slotOf('clock'), const GridSlot(0, 0));
      expect(flow.slotOf('sticky'), const GridSlot(1, 0));
    });

    test('colliding anchors slide down, never overlap', () {
      final flow = computeGridFlow(
        cells: const [],
        widgets: [
          const PlacedWidget(
            id: 'a',
            kind: WidgetKind.sticky,
            page: 0,
            row: 0,
            col: 0,
            w: 2,
            h: 2,
          ),
          const PlacedWidget(
            id: 'b',
            kind: WidgetKind.sticky,
            page: 0,
            row: 1,
            col: 1,
            w: 2,
            h: 1,
          ),
        ],
        columns: 4,
      );

      expect(flow.slotOf('a'), const GridSlot(0, 0));
      expect(flow.slotOf('b'), const GridSlot(2, 1));
    });

    test('resolveDropAnchor slides below an existing widget', () {
      final slot = resolveDropAnchor(
        existing: [
          const PlacedWidget(
            id: 'clock',
            kind: WidgetKind.clock,
            page: 0,
            row: 0,
            col: 0,
            w: 4,
            h: 1,
          ),
        ],
        row: 0,
        col: 0,
        w: 2,
        h: 2,
        columns: 4,
      );
      expect(slot, const GridSlot(1, 0));
    });

    test('moveWidgetTo re-anchors a placed widget', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final layout = await container.read(homeLayoutProvider.future);
      expect(layout.allApps, isNotEmpty);

      final notifier = container.read(homeLayoutProvider.notifier);
      notifier.placeWidget(WidgetKind.calendar, page: 0, row: 0, col: 0);
      final id = container
          .read(homeLayoutProvider)
          .value!
          .widgets
          .last
          .id;

      container.read(homeLayoutProvider.notifier).moveWidgetTo(
        id,
        row: 3,
        col: 1,
      );

      final moved = container.read(homeLayoutProvider).value!.widgets.last;
      expect(moved.row, 3);
      expect(moved.col, 0);
    });
  });

  group('PERF-01 AppSnapshotStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('toad-snap');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('save then load round-trips apps, icons, dock and recents',
        () async {
      final store = AppSnapshotStore(resolveDir: () async => tempDir.path);
      await store.save(
        apps: [
          DeviceApp(
            packageId: 'com.a',
            label: 'A',
            iconPng: Uint8List.fromList([1, 2, 3]),
            iconMonoPng: Uint8List.fromList([9]),
          ),
          const DeviceApp(packageId: 'com.b', label: 'B'),
        ],
        dockIds: const ['com.a'],
        recentIds: const ['com.b'],
      );

      final index = await store.load();
      expect(index, isNotNull);
      expect(index!.apps, hasLength(2));
      expect(index.apps.first.packageId, 'com.a');
      expect(index.apps.first.iconPng, Uint8List.fromList([1, 2, 3]));
      expect(index.apps.first.iconMonoPng, Uint8List.fromList([9]));
      expect(index.dockIds, ['com.a']);
      expect(index.recentIds, ['com.b']);
      expect(index.fresh, isTrue);
    });

    test('a corrupt snapshot returns null instead of crashing', () async {
      final store = AppSnapshotStore(resolveDir: () async => tempDir.path);
      await store.save(
        apps: [const DeviceApp(packageId: 'com.a', label: 'A')],
        dockIds: const [],
        recentIds: const [],
      );
      File('${tempDir.path}/index.json').writeAsStringSync('{broken');

      expect(await store.load(), isNull);
    });

    test('wrong schema version is rejected', () async {
      final store = AppSnapshotStore(resolveDir: () async => tempDir.path);
      Directory('${tempDir.path}/icons').createSync(recursive: true);
      File('${tempDir.path}/index.json').writeAsStringSync(
        jsonEncode({'v': 99, 'apps': []}),
      );

      expect(await store.load(), isNull);
    });

    test('clear removes the whole snapshot dir', () async {
      final store = AppSnapshotStore(resolveDir: () async => tempDir.path);
      await store.save(
        apps: [const DeviceApp(packageId: 'com.a', label: 'A')],
        dockIds: const [],
        recentIds: const [],
      );
      await store.clear();

      expect(tempDir.existsSync(), isFalse);
    });
  });

  group('FEAT-10 focus session', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('start arms the timer state; focus overrides apply; end clears',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(focusSessionProvider).active, isFalse);
      expect(
        container.read(focusAwareSettingsProvider).notificationDots,
        isTrue,
      );

      container.read(focusSessionProvider.notifier).start(25);
      expect(container.read(focusSessionProvider).active, isTrue);
      expect(
        container.read(focusSessionProvider).endsAt!.difference(
              DateTime.now(),
            ).inMinutes,
        inInclusiveRange(24, 25),
      );

      final during = container.read(focusAwareSettingsProvider);
      expect(during.notificationDots, isFalse);
      expect(during.badges, isFalse);
      expect(during.calmPond, isTrue);
      expect(during.pondRain, isFalse);
      expect(during.showMemoriesCard, isFalse);

      container.read(focusSessionProvider.notifier).end();
      expect(container.read(focusSessionProvider).active, isFalse);
      expect(
        container.read(focusAwareSettingsProvider).notificationDots,
        isTrue,
      );
    });

    test('starting a session while one runs re-arms it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(focusSessionProvider.notifier);
      notifier.start(15);
      final firstEnd = container.read(focusSessionProvider).endsAt!;
      notifier.start(60);
      final secondEnd = container.read(focusSessionProvider).endsAt!;

      expect(secondEnd.isAfter(firstEnd), isTrue);
    });
  });

  group('PLT-07/08 bridge contract', () {
    const channel = MethodChannel(DeviceBridge.channelName);

    testWidgets('homePressed reaches listeners', (tester) async {
      final bridge = DeviceBridge(channel);

      var pressed = 0;
      bridge.addHomePressedListener(() => pressed++);

      const codec = StandardMethodCodec();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        DeviceBridge.channelName,
        codec.encodeMethodCall(const MethodCall('homePressed')),
        (data) {},
      );
      await tester.pump();

      expect(pressed, 1);
    });

    testWidgets('launchWidgetConfigure relays the id as a boolean result',
        (tester) async {
      final channel = MethodChannel('test/channel');
      final bridge = DeviceBridge(channel);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          expect(call.method, 'launchWidgetConfigure');
          expect((call.arguments as Map)['appWidgetId'], 42);
          return true;
        },
      );
      expect(await bridge.launchWidgetConfigure(42), isTrue);
    });

    testWidgets('hostedAppWidgetIds parses the host list', (tester) async {
      final channel = MethodChannel('test/channel');
      final bridge = DeviceBridge(channel);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          expect(call.method, 'hostedAppWidgetIds');
          return [7, 8, 9];
        },
      );
      expect(await bridge.hostedAppWidgetIds(), [7, 8, 9]);
    });

    test('WidgetBindResult parses configure components', () {
      const bound = WidgetBindResult(
        appWidgetId: 5,
        configure: 'com.x/.Cfg',
      );
      expect(bound.bound, isTrue);
      expect(bound.needsConfigure, isTrue);

      const bare = WidgetBindResult(appWidgetId: 5, configure: null);
      expect(bare.needsConfigure, isFalse);

      const none = WidgetBindResult();
      expect(none.bound, isFalse);
    });
  });
}

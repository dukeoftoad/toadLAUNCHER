// v0.10 device layer — bridge contract, family registry, version
// compare, the device repository, and the update engine state machine.
//
// The bridge talks to Android through one MethodChannel; every test here
// mocks that channel or fakes the bridge, so the whole device layer is
// exercised without an emulator (CI builds, no device runs).
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/device/device_bridge.dart';
import 'package:toadlauncher/core/device/toad_family.dart';
import 'package:toadlauncher/core/device/update_engine.dart';
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/repositories/app_repository.dart';
import 'package:toadlauncher/core/repositories/device_app_repository.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart'
    show UpdatePolicy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // toad family registry
  // ------------------------------------------------------------------

  group('toad family registry', () {
    test('recognizes every sibling by its real applicationId', () {
      expect(isToadFamilyPackage('com.toadgallery.app'), isTrue);
      expect(isToadFamilyPackage('com.toadfiles.app'), isTrue);
      expect(isToadFamilyPackage('com.toadplayer.app'), isTrue);
      expect(isToadFamilyPackage('com.toadhealth.app'), isTrue);
      expect(isToadFamilyPackage('dev.toad.toadtimer'), isTrue);
      expect(isToadFamilyPackage('com.toadcalculator'), isTrue);
      expect(isToadFamilyPackage('com.toadlight.filter'), isTrue);
      // toadNOTES ships as an unrelated-looking id — the explicit list
      // is the only honest way to know.
      expect(isToadFamilyPackage('com.nestnote.app'), isTrue);
    });

    test('recognizes the launcher namespace by prefix', () {
      expect(isToadFamilyPackage('family.toad.launcher'), isTrue);
      expect(isToadFamilyPackage('family.toad.something-new'), isTrue);
    });

    test('unknown packages are not family', () {
      expect(isToadFamilyPackage('com.google.chrome'), isFalse);
      expect(isToadFamilyPackage('family.toad'), isFalse);
    });

    test('display names come from the registry', () {
      expect(toadFamilyDisplayName('com.nestnote.app'), 'toadNOTES');
      expect(toadFamilyDisplayName('dev.toad.toadtimer'), 'toadTIMER');
      expect(toadFamilyDisplayName('family.toad.clock'), 'toadClock');
      expect(toadFamilyDisplayName('com.android.chrome'), isNull);
    });
  });

  // ------------------------------------------------------------------
  // version compare (update gate)
  // ------------------------------------------------------------------

  group('compareVersions', () {
    test('newer release wins', () {
      expect(compareVersions('v0.10.0-beta', '0.9.0-beta'), greaterThan(0));
      expect(compareVersions('v0.10.0', 'v0.10.0-beta'), greaterThan(0));
    });

    test('equal builds compare equal (suffixes normalize)', () {
      expect(compareVersions('v0.10.0-beta', '0.10.0-beta+30'), 0);
      expect(compareVersions('0.9.0-beta', 'v0.9.0-beta'), 0);
    });

    test('older release loses', () {
      expect(compareVersions('v0.9.0-beta', '0.10.0-beta'), lessThan(0));
    });
  });

  // ------------------------------------------------------------------
  // bridge contract over a mocked channel
  // ------------------------------------------------------------------

  group('DeviceBridge channel contract', () {
    const channel = MethodChannel(DeviceBridge.channelName);
    late DeviceBridge bridge;

    setUp(() {
      bridge = DeviceBridge(channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('available: true when Android answers', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);
      expect(await bridge.available(), isTrue);
    });

    test('available: false when the plugin is missing', () async {
      final plain = DeviceBridge(null);
      expect(await plain.available(), isFalse);
    });

    test('listApps maps the channel payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'listApps');
        return [
          {
            'packageId': 'com.toadgallery.app',
            'label': 'toadGALLERY',
            'iconPng': Uint8List.fromList([1, 2, 3]),
          },
          {'packageId': 'com.other.app', 'label': 'Other', 'iconPng': null},
        ];
      });
      final apps = await bridge.listApps();
      expect(apps, hasLength(2));
      expect(apps[0].packageId, 'com.toadgallery.app');
      expect(apps[0].iconPng, isNotNull);
      expect(apps[1].iconPng, isNull);
    });

    test('usageRecents: PlatformException(noAccess) → null, not a lie',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'noAccess');
      });
      expect(await bridge.usageRecents(), isNull);
    });

    test('checkLatestRelease: rateLimit code → typed exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'checkLatestRelease');
        expect(call.arguments, containsPair('repo', 'dukeoftoad/toadLAUNCHER'));
        throw PlatformException(code: 'rateLimit');
      });
      expect(
        bridge.checkLatestRelease(),
        throwsA(isA<UpdateRateLimitException>()),
      );
    });

    test('checkLatestRelease: maps the release payload', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return {
          'tagName': 'v0.11.0-beta',
          'htmlUrl': 'https://github.com/x/releases/tag/v0.11.0-beta',
          'notes': 'calmer pond',
          'apkName': 'toadlauncher-v0.11.0-beta-universal-install.apk',
          'apkUrl': 'https://example.com/apk',
          'apkSizeBytes': 52000000,
          'sha256': 'abc123',
        };
      });
      final release = await bridge.checkLatestRelease();
      expect(release.tagName, 'v0.11.0-beta');
      expect(release.sha256, 'abc123');
    });

    test('installDownloadedApk: handoff strings → enum', () async {
      for (final entry in <String, InstallHandoff>{
        'started': InstallHandoff.started,
        'needsPermission': InstallHandoff.needsPermission,
        'checksumFailed': InstallHandoff.checksumFailed,
        'failed': InstallHandoff.failed,
      }.entries) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => entry.key);
        expect(
          await bridge.installDownloadedApk(id: 1),
          entry.value,
        );
      }
    });
  });

  // ------------------------------------------------------------------
  // device repository — index, family folder, dock, recents
  // ------------------------------------------------------------------

  group('DeviceAppRepository', () {
    late _FakeBridge fake;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      fake = _FakeBridge();
    });

    test('builds a sorted index with family flags and icons', () async {
      final repo = DeviceAppRepository(fake);
      final layout = await repo.loadHomeLayout();

      expect(layout.allApps.first.name.toLowerCase().codeUnitAt(0), lessThan(0x7b));
      // Sorted alphabetically (case-insensitive).
      final names = [
        for (final a in layout.allApps) a.name.toLowerCase(),
      ];
      final sorted = [...names]..sort();
      expect(names, sorted);

      final gallery =
          layout.allApps.where((a) => a.id == 'com.toadgallery.app').first;
      expect(gallery.isFamilyToad, isTrue);
      expect(gallery.name, 'toadGALLERY');

      final chrome =
          layout.allApps.where((a) => a.id == 'com.android.chrome').first;
      expect(chrome.isFamilyToad, isFalse);
      expect(chrome.packageName, 'com.android.chrome');

      expect(repo.iconBytes['com.toadgallery.app'], isNotNull);
    });

    test('family folder leads page 2 when two siblings exist', () async {
      final repo = DeviceAppRepository(fake);
      final layout = await repo.loadHomeLayout();

      expect(layout.folders.map((f) => f.id), contains('toad-family'));
      final folder = layout.folderById('toad-family')!;
      expect(
        folder.apps.map((a) => a.id).toSet(),
        {'com.toadgallery.app', 'com.nestnote.app'},
      );

      final page2 = layout.pages.length >= 2
          ? layout.pages[1]
          : layout.pages[0]; // a tiny index fits on one page — the folder
      // then leads the only page it has.
      expect(page2.first, isA<FolderCell>());
      expect((page2.first as FolderCell).folder.id, 'toad-family');
    });

    test('dock fills from known packages then the index', () async {
      final repo = DeviceAppRepository(fake);
      final layout = await repo.loadHomeLayout();
      expect(layout.dock, hasLength(4));
      expect(layout.dock.every((a) => a.id != 'resident'), isTrue);
    });

    test('launch fires the bridge and persists local history', () async {
      final repo = DeviceAppRepository(fake);
      final layout = await repo.loadHomeLayout();
      final target = layout.allApps.first;

      await repo.launch(target);

      expect(fake.launched, contains(target.id));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('toadlauncher.recents.v1'), contains(target.id));

      final layout2 = await repo.loadHomeLayout();
      expect(layout2.recents.first.id, target.id);
    });

    test('demo repo answers false honestly for device actions', () async {
      const demo = DemoAppRepository();
      expect(
        await demo.uninstallApp(
          const AppEntry(id: 'x', name: 'x', glyph: ''),
        ),
        isFalse,
      );
    });
  });

  // ------------------------------------------------------------------
  // update engine state machine (faked bridge)
  // ------------------------------------------------------------------

  group('UpdateEngine', () {
    late _FakeBridge fake;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      fake = _FakeBridge();
      container = ProviderContainer(
        overrides: [deviceBridgeProvider.overrideWithValue(fake)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('manualCheck: newer release → available', () async {
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'https://example.com/r',
        apkUrl: 'https://example.com/apk',
        sha256: 'abc',
        sig: 'valid-signature',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();

      final state = container.read(updateEngineProvider);
      expect(state, isA<UpdateAvailable>());
      expect((state as UpdateAvailable).release.tagName, 'v99.0.0');
    });

    test('manualCheck: same version → up to date', () async {
      fake.runningVersion = '1.2.3';
      fake.release = ReleaseInfo(
        tagName: 'v1.2.3',
        htmlUrl: 'u',
        apkUrl: 'a',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();

      expect(
        container.read(updateEngineProvider),
        isA<UpdateUpToDate>(),
      );
    });

    test('manualCheck: failure surfaces the typed message', () async {
      fake.throwOnCheck = UpdateRateLimitException();
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();

      final state = container.read(updateEngineProvider);
      expect(state, isA<UpdateFailed>());
      expect((state as UpdateFailed).message, contains('rate limit'));
    });

    test('silentStartupCheck: swallows failures and stays quiet', () async {
      fake.throwOnCheck = UpdateUnreachableException();
      final engine = container.read(updateEngineProvider.notifier);
      await engine.silentStartupCheck();
      expect(container.read(updateEngineProvider), isA<UpdateIdle>());
    });

    test('silentStartupCheck: older release never banners', () async {
      fake.runningVersion = '9.9.9';
      fake.release = ReleaseInfo(
        tagName: 'v0.9.0-beta',
        htmlUrl: 'u',
        apkUrl: 'a',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.silentStartupCheck();
      expect(container.read(updateEngineProvider), isA<UpdateIdle>());
    });

    test(
        'download → progress → install handoff lands back in idle '
        '(started)', () async {
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'https://example.com/r',
        apkUrl: 'https://example.com/apk',
        sha256: 'cafe',
        sig: 'valid-signature',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();
      expect(container.read(updateEngineProvider), isA<UpdateAvailable>());

      await engine.download();

      // First poll tick runs at 500 ms — let it drive the flow.
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(fake.enqueuedUrl, 'https://example.com/apk');
      expect(fake.installSha256, 'cafe');
      expect(container.read(updateEngineProvider), isA<UpdateIdle>());
    });

    test('checksum failure lands in the honest state', () async {
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'u',
        apkUrl: 'a',
        sha256: 'cafe',
        sig: 'valid-signature',
      );
      fake.installResult = 'checksumFailed';
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();
      await engine.download();
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(container.read(updateEngineProvider), isA<UpdateChecksumFailed>());
    });

    // -- SEC-02: the signature gate --------------------------------------

    test('SEC-02: unsigned release is refused (never banners)', () async {
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'u',
        apkUrl: 'a',
        sha256: 'abc',
        // no sig — releases without the detached signature are refused
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();

      expect(container.read(updateEngineProvider), isA<UpdateUnverified>());
    });

    test('SEC-02: invalid signature is refused', () async {
      fake.signatureValid = false;
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'u',
        apkUrl: 'a',
        sha256: 'abc',
        sig: 'tampered-signature',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();

      expect(container.read(updateEngineProvider), isA<UpdateUnverified>());
    });

    test('SEC-02: wrong-cert APK handoff is refused honestly', () async {
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'u',
        apkUrl: 'a',
        sha256: 'cafe',
        sig: 'valid-signature',
      );
      fake.installResult = 'wrongCertificate';
      final engine = container.read(updateEngineProvider.notifier);
      await engine.manualCheck();
      await engine.download();
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      final state = container.read(updateEngineProvider);
      expect(state, isA<UpdateFailed>());
      expect((state as UpdateFailed).message, contains('refused'));
    });

    // -- SEC-04: the policy throttle ---------------------------------------

    test('SEC-04: policy gates the silent check', () async {
      final engine = container.read(updateEngineProvider.notifier);
      final day = const Duration(days: 1).inMilliseconds;
      final now = 100 * day;

      // off / manual never check silently.
      expect(engine.silentCheckAllowed(UpdatePolicy.off, 0, now), isFalse);
      expect(engine.silentCheckAllowed(UpdatePolicy.manual, 0, now), isFalse);

      // daily: too soon → no; a day passed → yes.
      expect(
        engine.silentCheckAllowed(UpdatePolicy.daily, now - 1000, now),
        isFalse,
      );
      expect(
        engine.silentCheckAllowed(UpdatePolicy.daily, now - day, now),
        isTrue,
      );

      // weekly: a day is not enough.
      expect(
        engine.silentCheckAllowed(UpdatePolicy.weekly, now - day, now),
        isFalse,
      );
      expect(
        engine.silentCheckAllowed(
          UpdatePolicy.weekly,
          now - const Duration(days: 7).inMilliseconds,
          now,
        ),
        isTrue,
      );
    });

    test('SEC-04: silent check honors the daily throttle', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'toadlauncher.update.lastcheck',
        DateTime.now().millisecondsSinceEpoch - 1000, // checked moments ago
      );
      fake.release = ReleaseInfo(
        tagName: 'v99.0.0',
        htmlUrl: 'u',
        apkUrl: 'a',
        sha256: 'abc',
        sig: 'valid-signature',
      );
      final engine = container.read(updateEngineProvider.notifier);
      await engine.silentStartupCheck();
      // Throttled: nothing happened at all.
      expect(container.read(updateEngineProvider), isA<UpdateIdle>());
      expect(fake.checkCount, 0);
    });
  });
}

/// Channel-free fake — the update engine and repository talk to this.
class _FakeBridge extends DeviceBridge {
  _FakeBridge();

  ReleaseInfo? release;
  String runningVersion = '0.10.0-beta';
  UpdateCheckException? throwOnCheck;
  String installResult = 'started';
  bool signatureValid = true;
  int checkCount = 0;
  final List<String> launched = [];
  String? enqueuedUrl;
  String? installSha256;

  @override
  Future<bool> available() async => true;

  @override
  Future<VersionInfo> versionInfo() async =>
      VersionInfo(versionName: runningVersion, versionCode: 30);

  @override
  Future<List<DeviceApp>> listApps() async => [
    const DeviceApp(
      packageId: 'com.android.chrome',
      label: 'Chrome',
      isFamily: false,
    ),
    DeviceApp(
      packageId: 'com.toadgallery.app',
      label: 'Gallery', // registry name should override
      iconPng: Uint8List.fromList([9, 9, 9]),
    ),
    const DeviceApp(packageId: 'com.nestnote.app', label: 'Notes'),
    const DeviceApp(packageId: 'zpkg', label: 'Alarm'),
    const DeviceApp(packageId: 'apkg', label: 'Banking'),
  ];

  @override
  Future<bool> launch(String packageId) async {
    launched.add(packageId);
    return true;
  }

  @override
  Future<List<String>?> usageRecents() async => null;

  @override
  Future<ReleaseInfo> checkLatestRelease() async {
    checkCount++;
    if (throwOnCheck case final UpdateCheckException e) throw e;
    return release!;
  }

  @override
  Future<bool> verifyUpdateSignature(String message, String signature) async {
    // The fake mirrors the embedded-key contract: only the fixed test
    // signature verifies, and only when the fake has not been told to
    // break it (SEC-02 negative paths).
    return signatureValid && signature == 'valid-signature';
  }

  @override
  Future<int> enqueueApkDownload({
    required String url,
    required String fileName,
  }) async {
    enqueuedUrl = url;
    return 42;
  }

  @override
  Future<DownloadSnapshot> downloadProgress(int id) async =>
      const DownloadSnapshot(status: 'successful', bytesSoFar: 9, totalBytes: 9);

  @override
  Future<InstallHandoff> installDownloadedApk({
    required int id,
    String? expectedSha256,
  }) async {
    installSha256 = expectedSha256;
    return InstallHandoff.values
        .where((v) => v.name == installResult)
        .first;
  }
}

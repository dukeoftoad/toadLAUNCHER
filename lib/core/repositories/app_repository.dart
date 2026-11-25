library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_bridge.dart';
import '../models/models.dart';
import '../settings/launcher_settings.dart';
import 'device_app_repository.dart';

abstract class AppRepository {
  const AppRepository();

  Future<HomeLayout> loadHomeLayout({int columnsPerRow});

  Future<List<List<AppEntry>>> loadPondRows();

  Future<void> launch(AppEntry app);

  Future<bool> uninstallApp(AppEntry app) async => false;

  Future<bool> openAppDetails(AppEntry app) async => false;
}

class DemoAppRepository extends AppRepository {
  const DemoAppRepository();

  static const AppEntry _toadGallery = AppEntry(
    id: 'family.toad.gallery',
    name: 'toadGALLERY',
    glyph: '',
    isFamilyToad: true,
  );

  static const List<AppEntry> _page1 = [
    _toadGallery,
    AppEntry(id: 'phone', name: 'Phone', glyph: '✆', gradientIndex: 0),
    AppEntry(id: 'messages', name: 'Messages', glyph: '✉', gradientIndex: 1),
    AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
    AppEntry(id: 'chrome', name: 'Chrome', glyph: '◍', gradientIndex: 7),
    AppEntry(id: 'maps', name: 'Maps', glyph: '➤', gradientIndex: 5),
    AppEntry(id: 'youtube', name: 'YouTube', glyph: '▶', gradientIndex: 2),
    AppEntry(id: 'clock', name: 'Clock', glyph: '◷', gradientIndex: 6),
  ];

  static const List<AppEntry> _page2 = [
    AppEntry(id: 'photos', name: 'Photos', glyph: '❖', gradientIndex: 5),
    AppEntry(id: 'notes', name: 'Notes', glyph: '✎', gradientIndex: 2),
    AppEntry(id: 'music', name: 'Music', glyph: '♪', gradientIndex: 6),
    AppEntry(id: 'files', name: 'Files', glyph: '▤', gradientIndex: 7),
    AppEntry(id: 'weather', name: 'Weather', glyph: '☂', gradientIndex: 1),
    AppEntry(id: 'wallet', name: 'Wallet', glyph: '▥', gradientIndex: 3),
    AppEntry(id: 'store', name: 'Store', glyph: '⬒', gradientIndex: 4),
    AppEntry(id: 'settings', name: 'Settings', glyph: '⚙', gradientIndex: 7),
  ];

  static const List<AppEntry> _page3 = [
    AppEntry(id: 'banking', name: 'Banking', glyph: '⌂', gradientIndex: 5),
    AppEntry(
      id: 'authenticator',
      name: 'Authenticator',
      glyph: '✓',
      gradientIndex: 0,
    ),
    AppEntry(id: 'alarm', name: 'Alarm', glyph: '⏰', gradientIndex: 2),
    AppEntry(
      id: 'calculator',
      name: 'Calculator',
      glyph: '＋',
      gradientIndex: 7,
    ),
    AppEntry(id: 'calendar', name: 'Calendar', glyph: '▤', gradientIndex: 3),
    AppEntry(id: 'contacts', name: 'Contacts', glyph: '☺', gradientIndex: 1),
    AppEntry(id: 'recorder', name: 'Recorder', glyph: '◉', gradientIndex: 6),
    AppEntry(id: 'casts', name: 'Casts', glyph: '↗', gradientIndex: 4),
  ];

  static const List<AppEntry> _dock = [
    AppEntry(id: 'phone', name: 'Phone', glyph: '✆', gradientIndex: 0),
    AppEntry(id: 'messages', name: 'Messages', glyph: '✉', gradientIndex: 1),
    AppEntry(id: 'chrome', name: 'Chrome', glyph: '◍', gradientIndex: 7),
    AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
  ];

  static const FolderData _mediaFolder = FolderData(
    id: 'media',
    title: 'Media',
    apps: [
      _toadGallery,
      AppEntry(id: 'youtube', name: 'YouTube', glyph: '▶', gradientIndex: 2),
      AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
      AppEntry(id: 'music', name: 'Music', glyph: '♪', gradientIndex: 6),
      AppEntry(
        id: 'family.toad.player',
        name: 'toadPLAYER',
        glyph: '',
        isFamilyToad: true,
      ),
      AppEntry(id: 'recorder', name: 'Recorder', glyph: '◉', gradientIndex: 6),
      AppEntry(id: 'files', name: 'Files', glyph: '▤', gradientIndex: 7),
      AppEntry(id: 'casts', name: 'Casts', glyph: '↗', gradientIndex: 4),
    ],
  );

  static const List<AppEntry> _drawerApps = [
    AppEntry(id: 'alarm', name: 'Alarm', glyph: '⏰', gradientIndex: 2),
    AppEntry(
      id: 'authenticator',
      name: 'Authenticator',
      glyph: '✓',
      gradientIndex: 0,
    ),
    AppEntry(id: 'banking', name: 'Banking', glyph: '⌂', gradientIndex: 5),
    AppEntry(
      id: 'calculator',
      name: 'Calculator',
      glyph: '＋',
      gradientIndex: 7,
    ),
    AppEntry(id: 'calendar', name: 'Calendar', glyph: '▤', gradientIndex: 3),
    AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
    AppEntry(id: 'chrome', name: 'Chrome', glyph: '◍', gradientIndex: 7),
    AppEntry(id: 'clock', name: 'Clock', glyph: '◷', gradientIndex: 6),
    AppEntry(
      id: 'contacts',
      name: 'Contacts',
      glyph: '☺',
      gradientIndex: 1,
      badge: '2 missed',
    ),
    AppEntry(id: 'files', name: 'Files', glyph: '▤', gradientIndex: 7),
    AppEntry(id: 'maps', name: 'Maps', glyph: '➤', gradientIndex: 5),
    AppEntry(id: 'messages', name: 'Messages', glyph: '✉', gradientIndex: 1),
    AppEntry(id: 'music', name: 'Music', glyph: '♪', gradientIndex: 6),
    AppEntry(id: 'notes', name: 'Notes', glyph: '✎', gradientIndex: 2),
    AppEntry(id: 'phone', name: 'Phone', glyph: '✆', gradientIndex: 0),
    AppEntry(id: 'photos', name: 'Photos', glyph: '❖', gradientIndex: 5),
    AppEntry(id: 'settings', name: 'Settings', glyph: '⚙', gradientIndex: 7),
    AppEntry(id: 'store', name: 'Store', glyph: '⬒', gradientIndex: 4),
    AppEntry(id: 'wallet', name: 'Wallet', glyph: '▥', gradientIndex: 3),
    AppEntry(id: 'weather', name: 'Weather', glyph: '☂', gradientIndex: 1),
    AppEntry(id: 'youtube', name: 'YouTube', glyph: '▶', gradientIndex: 2),
    _toadGallery,
  ];

  @override
  Future<HomeLayout> loadHomeLayout({int columnsPerRow = 4}) async {
    final all = List<AppEntry>.from(_drawerApps)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return HomeLayout(
      pages: [
        [for (final a in _page1) AppCell(a)],
        [const FolderCell(_mediaFolder), for (final a in _page2) AppCell(a)],
        [for (final a in _page3) AppCell(a)],
      ],
      dock: _dock,
      recents: const [
        _toadGallery,
        AppEntry(id: 'chrome', name: 'Chrome', glyph: '◍', gradientIndex: 7),
        AppEntry(id: 'clock', name: 'Clock', glyph: '◷', gradientIndex: 6),
        AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
      ],
      allApps: all,
      folders: const [_mediaFolder],
      memory: MemoryCardData(
        title: 'On this day',
        meta: '3 photos · 2025',
        photoCount: 3,
        year: 2025,
      ),
    );
  }

  @override
  Future<List<List<AppEntry>>> loadPondRows() async => const [
    [
      _toadGallery,
      AppEntry(id: 'phone', name: 'Phone', glyph: '✆', gradientIndex: 0),
      AppEntry(id: 'messages', name: 'Messages', glyph: '✉', gradientIndex: 1),
    ],
    [
      AppEntry(id: 'camera', name: 'Camera', glyph: '◉', gradientIndex: 3),
      AppEntry(id: 'chrome', name: 'Chrome', glyph: '◍', gradientIndex: 7),
      AppEntry(id: 'resident', name: 'the resident', glyph: ''),
    ],
  ];

  @override
  Future<void> launch(AppEntry app) async {
  }
}

final Provider<AppRepository> appRepositoryProvider = Provider<AppRepository>(
  (ref) {
    final reachable = ref.watch(deviceCapabilityProvider).value ?? false;
    final settings = ref.watch(launcherSettingsProvider);
    if (reachable && settings.deviceMode) {
      return DeviceAppRepository(
        ref.watch(deviceBridgeProvider),
        usageOptIn: settings.usageRecentsOptIn,
      );
    }
    return const DemoAppRepository();
  },
);

final FutureProvider<bool> deviceCapabilityProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceBridgeProvider).available(),
);

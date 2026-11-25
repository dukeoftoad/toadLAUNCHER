library;

import 'package:flutter_test/flutter_test.dart';
import 'package:toadlauncher/core/models/models.dart';
import 'package:toadlauncher/core/repositories/app_repository.dart';
import 'package:toadlauncher/features/home/widgets/hero_zone.dart';

void main() {
  group('buildHeroData', () {
    test('formats 24h clock and long date', () {
      final data = buildHeroData(
        DateTime(2026, 11, 23, 10, 42),
        pond: false,
        pondNight: false,
      );
      expect(data.time, '10:42');
      expect(data.dateLine, 'Monday · 23 November');
    });

    test('zero-pads single-digit hours and minutes', () {
      final data = buildHeroData(
        DateTime(2026, 3, 5, 7, 5),
        pond: false,
        pondNight: false,
      );
      expect(data.time, '07:05');
      expect(data.dateLine, 'Thursday · 5 March');
    });

    test('greetings follow the hour', () {
      expect(
        buildHeroData(
          DateTime(2026, 11, 24, 8),
          pond: false,
          pondNight: false,
        ).noteTop,
        'good morning',
      );
      expect(
        buildHeroData(
          DateTime(2026, 11, 24, 14),
          pond: false,
          pondNight: false,
        ).noteTop,
        'good afternoon',
      );
      expect(
        buildHeroData(
          DateTime(2026, 11, 24, 18),
          pond: false,
          pondNight: false,
        ).noteTop,
        'good evening',
      );
      expect(
        buildHeroData(
          DateTime(2026, 11, 24, 22),
          pond: false,
          pondNight: false,
        ).noteTop,
        'good night',
      );
    });

    test('late night swaps bottom note to wind down', () {
      final data = buildHeroData(
        DateTime(2026, 11, 24, 23, 0),
        pond: false,
        pondNight: false,
      );
      expect(data.noteBottom, 'wind down soon');
    });

    test('pond day uses pond voice', () {
      final data = buildHeroData(
        DateTime(2026, 11, 24, 10, 42),
        pond: true,
        pondNight: false,
      );
      expect(data.noteTop, 'the pond is calm');
    });

    test('pond night uses the asleep line', () {
      final data = buildHeroData(
        DateTime(2026, 11, 24, 22, 17),
        pond: true,
        pondNight: true,
      );
      expect(data.noteTop, 'the pond is asleep');
      expect(data.noteBottom, 'alarm 6:45');
    });
  });

  group('DemoAppRepository', () {
    final repo = const DemoAppRepository();

    test('home layout: 3 pages, 4 dock apps, toadGALLERY first', () async {
      final layout = await repo.loadHomeLayout();
      expect(layout.pages.length, 3);
      expect(layout.pages.first.length, 8);
      expect(layout.dock.length, 4);
      final first = layout.pages.first.first;
      expect(first, isA<AppCell>());
      expect((first as AppCell).app.id, 'family.toad.gallery');
      expect(layout.memory.title, 'On this day');
    });

    test('page 2 leads with the Media folder tile (stage 2)', () async {
      final layout = await repo.loadHomeLayout();
      final lead = layout.pages[1].first;
      expect(lead, isA<FolderCell>());
      expect((lead as FolderCell).folder.id, 'media');
    });

    test('drawer index is alphabetically sorted', () async {
      final layout = await repo.loadHomeLayout();
      final names = layout.allApps.map((a) => a.name.toLowerCase()).toList();
      final sorted = List<String>.from(names)..sort();
      expect(names, sorted);
    });

    test('contacts carries the demo missed-calls badge', () async {
      final layout = await repo.loadHomeLayout();
      final contacts = layout.allApps.firstWhere((a) => a.id == 'contacts');
      expect(contacts.badge, '2 missed');
    });

    test('pond rows: 2 rows x 3 pads, resident last', () async {
      final rows = await repo.loadPondRows();
      expect(rows.length, 2);
      expect(rows.first.length, 3);
      expect(rows.last.length, 3);
      expect(rows.last.last.id, 'resident');
    });

    test('media folder matches screen 5', () async {
      final layout = await repo.loadHomeLayout();
      final media = layout.folders.firstWhere((f) => f.id == 'media');
      expect(media.title, 'Media');
      expect(media.apps.length, 8);
    });

    test('launch is a safe no-op in demo mode', () async {
      final layout = await repo.loadHomeLayout();
      await repo.launch(layout.dock.first);
    });
  });
}

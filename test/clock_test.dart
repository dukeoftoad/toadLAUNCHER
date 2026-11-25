/// CLOCK (roadmap §6 + PLT-13) — the four faces and their formatting:
/// word-clock phrasing, 12/24-hour formats, flip parts, settings
/// round-trips for style/format/policy (SEC-04 ships with the same
/// settings surface).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:toadlauncher/core/settings/launcher_settings.dart';
import 'package:toadlauncher/shared/widgets/clock_faces.dart';

void main() {
  group('formatClockTime', () {
    test('24 h pads and joins', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 9, 5), ClockHourFormat.h24, false),
        '09:05',
      );
      expect(
        formatClockTime(DateTime(2026, 1, 1, 23, 59), ClockHourFormat.h24, true),
        '23:59',
      );
    });

    test('12 h renders meridiem and 12 for midnight/noon hours', () {
      expect(
        formatClockTime(DateTime(2026, 1, 1, 0, 42), ClockHourFormat.h12, false),
        '12:42 am',
      );
      expect(
        formatClockTime(DateTime(2026, 1, 1, 12, 42), ClockHourFormat.h12, true),
        '12:42 pm',
      );
      expect(
        formatClockTime(DateTime(2026, 1, 1, 15, 7), ClockHourFormat.h12, false),
        '3:07 pm',
      );
    });

    test('system follows the platform truth (PLT-13)', () {
      final now = DateTime(2026, 1, 1, 18, 30);
      expect(
        formatClockTime(now, ClockHourFormat.system, true),
        formatClockTime(now, ClockHourFormat.h24, true),
      );
      expect(
        formatClockTime(now, ClockHourFormat.system, false),
        formatClockTime(now, ClockHourFormat.h12, false),
      );
    });
  });

  group('wordClockPhrase', () {
    test('on-the-hour phrases', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 0)), "five o'clock");
      expect(wordClockPhrase(DateTime(2026, 1, 1, 11, 0)), "eleven o'clock");
    });

    test('quarters and halves', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 15)), 'quarter past five');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 30)), 'half past five');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 45)), 'quarter to six');
    });

    test('five-minute steps past and to', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 5)), 'five past five');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 20)), 'twenty past five');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 25)), 'twenty-five past five');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 35)), 'twenty-five to six');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 40)), 'twenty to six');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 50)), 'ten to six');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 55)), 'five to six');
    });

    test('rounds odd minutes to the nearest five', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 43)), 'quarter to six');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 5, 58)), "six o'clock");
    });

    test('midnight and noon are themselves', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 0, 0)), 'midnight');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 12, 1)), 'noon');
    });

    test('23:58 rounds into midnight; 11:59 into noon', () {
      expect(wordClockPhrase(DateTime(2026, 1, 1, 23, 58)), 'midnight');
      expect(wordClockPhrase(DateTime(2026, 1, 1, 11, 59)), 'noon');
    });
  });

  group('flipClockParts', () {
    test('splits the pairs', () {
      final (h, m) = flipClockParts(DateTime(2026, 1, 1, 10, 42), ClockHourFormat.h24);
      expect(h, '10');
      expect(m, '42');
    });
  });

  group('settings round-trips (CLOCK + SEC-04)', () {
    test('clock style, hour format and update policy persist', () {
      const settings = LauncherSettings(
        clockStyle: HeroClockStyle.flip,
        clockHourFormat: ClockHourFormat.h12,
        updatePolicy: UpdatePolicy.weekly,
      );
      final json = settings.toJson();
      final restored = LauncherSettings.fromJson(
        json.cast<String, Object?>(),
      );
      expect(restored.clockStyle, HeroClockStyle.flip);
      expect(restored.clockHourFormat, ClockHourFormat.h12);
      expect(restored.updatePolicy, UpdatePolicy.weekly);
    });

    test('defaults: hand clock, system hours, daily policy', () {
      const settings = LauncherSettings();
      expect(settings.clockStyle, HeroClockStyle.hand);
      expect(settings.clockHourFormat, ClockHourFormat.system);
      expect(settings.updatePolicy, UpdatePolicy.daily);
      expect(
        settings.clockSpanH,
        LauncherSettings.fromJson(const {}).clockSpanH,
        reason: 'restore default must equal constructor default (NEW-05)',
      );
    });

    test('labels are present for every option', () {
      for (final s in HeroClockStyle.values) {
        expect(s.label, isNotEmpty);
      }
      for (final f in ClockHourFormat.values) {
        expect(f.label, isNotEmpty);
      }
      for (final p in UpdatePolicy.values) {
        expect(p.label, isNotEmpty);
      }
    });
  });
}

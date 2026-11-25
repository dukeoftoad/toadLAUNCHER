library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toadlauncher/core/reliability/crash_guard.dart';

CrashEntry e(int atMs, String boot) =>
    CrashEntry(atMs: atMs, boot: boot, kind: 'flutter', message: 'boom');

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);
  final nowMs = now.millisecondsSinceEpoch;
  final window = CrashGuard.kWindow.inMilliseconds;

  group('shouldEnterSafeMode (pure verdict)', () {
    test('empty ledger → normal start', () {
      expect(shouldEnterSafeMode(const [], now), isFalse);
    });

    test('crashes from one boot that recovered → NOT a loop', () {
      expect(
        shouldEnterSafeMode([
          e(nowMs - 1000, 'a'),
          e(nowMs - 2000, 'a'),
          e(nowMs - 3000, 'a'),
        ], now),
        isFalse,
        reason: 'one process surviving three errors is recovered, not looping',
      );
    });

    test('crashes from three distinct boots inside the window → safe mode', () {
      expect(
        shouldEnterSafeMode([
          e(nowMs - 1000, 'a'),
          e(nowMs - 2000, 'b'),
          e(nowMs - 3000, 'c'),
        ], now),
        isTrue,
      );
    });

    test('crashes from two distinct boots → not yet (one more restart)', () {
      expect(
        shouldEnterSafeMode([
          e(nowMs - 1000, 'a'),
          e(nowMs - 2000, 'b'),
        ], now),
        isFalse,
      );
    });

    test('old crashes age out of the window', () {
      expect(
        shouldEnterSafeMode([
          e(nowMs - window - 1, 'a'),
          e(nowMs - window - 2, 'b'),
          e(nowMs - window - 3, 'c'),
        ], now),
        isFalse,
      );
    });
  });

  group('ledger (mocked prefs)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('verdict is false on a clean install', () async {
      expect(await CrashGuard.verdict(), isFalse);
    });

    test('record → verdict flips after three boots; clear resets', () async {
      await CrashGuard.record('flutter', 'first', StackTrace.current);
      await CrashGuard.record('platform', 'second', StackTrace.current);
      await CrashGuard.record('zone', 'third', null);
      expect(await CrashGuard.verdict(), isFalse);

      await CrashGuard.clear();
      expect(await CrashGuard.verdict(), isFalse);
      expect(await CrashGuard.ledgerText(), 'no crashes recorded');
    });

    test('ledger text lists the recorded entries', () async {
      await CrashGuard.record('flutter', StateError('kaboom'), null);
      final text = await CrashGuard.ledgerText();
      expect(text, contains('toadLAUNCHER crash log'));
      expect(text, contains('kaboom'));
      expect(text, contains('flutter'));
    });
  });
}

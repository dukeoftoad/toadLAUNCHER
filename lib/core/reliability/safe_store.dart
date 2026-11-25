library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// REL-02: two-generation, versioned, validated persistence for JSON blobs.
///
/// SharedPreferences keys are atomic per write, but a corrupt or
/// half-migrated payload used to fall through a silent catch to defaults —
/// real data loss. SafeStore wraps one logical key with:
///
///   * a schema version stamped inside the payload (`v`),
///   * a last-good mirror slot (`.bak`) holding the previous payload,
///   * validation on read: primary → mirror → null (caller keeps defaults),
///   * legacy acceptance: payloads without a `v` field (v1.1.0 and older,
///     bare JSON) are read and migrated to the enveloped form on next save.
///
/// The storage substrate stays SharedPreferences so existing data, backups
/// and tests keep working; nothing is lost if this layer is removed.
class SafeStore {
  SafeStore(this._key, {required this.schemaVersion});

  /// Logical key, same string the blob used before wrapping.
  final String _key;

  /// Bump when the payload shape changes incompatibly; readers reject
  /// payloads whose version is newer or unknown.
  final int schemaVersion;

  String get _mirrorKey => '$_key.bak';

  /// Reads the newest valid payload.
  ///
  /// Returns the decoded JSON (map or list) or null when both slots are
  /// missing or invalid. [decode] converts the raw JSON value into the
  /// caller's model; returning null marks the payload semantically invalid
  /// and falls through to the mirror slot.
  Future<T?> read<T>(
    T? Function(Object? json) decode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_key, _mirrorKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final decoded = _decodeEnvelope(raw);
      if (decoded == null) continue;
      final model = decode(decoded);
      if (model != null) return model;
    }
    return null;
  }

  Object? _decodeEnvelope(String raw) {
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (json is Map && json['v'] is num) {
      final version = (json['v'] as num).toInt();
      if (version > schemaVersion) return null;
      return json['data'];
    }
    return json;
  }

  /// Writes [data] as an enveloped payload, demoting the current primary
  /// to the mirror slot first.
  ///
  /// The demotion happens before the primary overwrite, so a crash between
  /// the two writes leaves the previous good payload in the mirror.
  Future<void> write(Object? data) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key);
    if (previous != null && previous.isNotEmpty) {
      await prefs.setString(_mirrorKey, previous);
    }
    final envelope = jsonEncode(<String, Object?>{
      'v': schemaVersion,
      'at': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    await prefs.setString(_key, envelope);
  }

  /// Removes both slots (explicit user action only — history clears).
  Future<void> wipe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_mirrorKey);
  }
}

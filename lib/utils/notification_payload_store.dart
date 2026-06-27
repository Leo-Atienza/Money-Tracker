import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background-isolate handler for notification taps.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')`
/// so the engine can resolve it across the isolate boundary when the app is
/// terminated/backgrounded. It cannot navigate (no live UI), so it just
/// persists the payload; the foreground reads it back via
/// [NotificationPayloadStore.consumePendingPayloads] on resume.
///
/// Lives here (not in `main.dart`) so [NotificationHelper] can wire it into
/// `flutter_local_notifications` without importing the app entrypoint (a
/// forbidden self-import).
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationPayloadStore.storePendingPayload(response.payload);
}

/// Stores notification payloads for background tap handling.
///
/// When the user taps a notification while the app is in the background, the
/// `@pragma('vm:entry-point')` handler in `main.dart` runs in a tiny isolate
/// and can't navigate. It stores the payload here, and the foreground reads
/// it back on resume.
///
/// Phase 3.1: the underlying store is now a queue (JSON array) rather than a
/// single-string slot. If two notifications arrive between foreground checks,
/// both survive — the previous implementation lost the older payload when the
/// second one wrote.
class NotificationPayloadStore {
  static const String _queueKey = 'pending_notification_payloads';

  /// Legacy single-slot key. Migrated to the queue on the next read so any
  /// payload that landed under the old key is still delivered exactly once.
  static const String _legacyKey = 'pending_notification_payload';

  /// Append [payload] to the pending queue. No-op when [payload] is null or
  /// empty.
  static Future<void> storePendingPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs)..add(payload);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Atomically read all pending payloads (in arrival order) and clear the
  /// queue. Returns an empty list if nothing is pending.
  static Future<List<String>> consumePendingPayloads() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);

    // Pick up any legacy single-slot payload that predates the queue.
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      queue.insert(0, legacy);
    }

    if (queue.isEmpty) {
      // Still clean up the legacy key on every read so a stale value can't
      // resurface if the user upgrades, never opens the app, then upgrades
      // again.
      if (legacy != null) await prefs.remove(_legacyKey);
      return const [];
    }

    await prefs.remove(_queueKey);
    if (legacy != null) await prefs.remove(_legacyKey);
    return queue;
  }

  /// Convenience for callers that only care about the first payload. Drains
  /// the entire queue (so a second pending payload is not lost), returns the
  /// oldest. Prefer [consumePendingPayloads] when the caller can route every
  /// payload.
  static Future<String?> consumePendingPayload() async {
    final all = await consumePendingPayloads();
    return all.isEmpty ? null : all.first;
  }

  /// Clear every pending payload without reading.
  static Future<void> clearPendingPayloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    await prefs.remove(_legacyKey);
  }

  /// Back-compat alias for [clearPendingPayloads]. Callers that pre-date the
  /// queue still expect the singular name.
  static Future<void> clearPendingPayload() => clearPendingPayloads();

  static List<String> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Malformed data — treat as empty rather than crashing the entire
      // resume flow. The clobbering store on the next write will replace it.
    }
    return <String>[];
  }
}

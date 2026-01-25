import 'package:shared_preferences/shared_preferences.dart';

/// Stores notification payloads for background tap handling
/// When a user taps a notification while the app is in background,
/// we can't navigate immediately. This stores the payload so we can
/// navigate when the app resumes in the foreground.
class NotificationPayloadStore {
  static const String _key = 'pending_notification_payload';

  /// Store a notification payload for processing when app resumes
  static Future<void> storePendingPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, payload);
  }

  /// Retrieve and clear the pending notification payload
  /// Returns null if no pending payload exists
  static Future<String?> consumePendingPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_key);

    if (payload != null) {
      await prefs.remove(_key);
    }

    return payload;
  }

  /// Clear the pending payload without returning it
  static Future<void> clearPendingPayload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

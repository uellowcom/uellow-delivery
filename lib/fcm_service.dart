// =============================================================================
// FcmService — Firebase Cloud Messaging glue (fleet push, v1.1.0).
// Background/killed messages are shown by the Android tray automatically
// (the server sends a `notification` block). The FCM token is registered
// with the backend on startup, after login and on every token refresh so
// the Uellow push engine can target this carrier.
// =============================================================================
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Notification-type messages are displayed by the system tray itself.
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      fm.onTokenRefresh.listen(_register);
      final t = await fm.getToken();
      if (t != null && t.isNotEmpty) await _register(t);
      _inited = true;
    } catch (_) {
      // Devices without Google services land here — app works regardless.
    }
  }

  /// Re-send the current token (call after login so the backend links
  /// the token to this account).
  Future<void> register() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null && t.isNotEmpty) await _register(t);
    } catch (_) {}
  }

  Future<void> _register(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('fcm_device_id_v1') ?? '';
      if (id.isEmpty) {
        id = 'dev_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
        await prefs.setString('fcm_device_id_v1', id);
      }
      await CarrierApi.instance.registerPushToken(id, token);
    } catch (_) {}
  }
}

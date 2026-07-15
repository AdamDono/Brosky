import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Request permission
    await requestPermission();

    // 2. Set up token refresh listener
    _fcm.onTokenRefresh.listen((token) async {
      debugPrint('*** FCM Token Refreshed: $token');
      await _uploadToken(token);
    });

    // 3. Set up message handlers
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('*** Foreground message received: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('*** Notification message clicked/opened app');
    });

    // 4. Listen to auth state changes to upload/clear token dynamically
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        await getAndStoreToken();
      } else if (event == AuthChangeEvent.signedOut) {
        await clearToken();
      }
    });

    // 5. Initial upload if user already logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await getAndStoreToken();
    }
  }

  Future<void> requestPermission() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('*** User notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('*** Error requesting notification permissions: $e');
    }
  }

  Future<void> getAndStoreToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('*** FCM Token acquired: $token');
        await _uploadToken(token);
      }
    } catch (e) {
      debugPrint('*** Error getting FCM device token: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', user.id);
          
      debugPrint('*** FCM Token cleared from profile.');
    } catch (e) {
      debugPrint('*** Error clearing FCM token: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint('*** FCM Token stored successfully in Supabase.');
    } catch (e) {
      debugPrint('*** Error updating FCM token in database: $e');
    }
  }
}

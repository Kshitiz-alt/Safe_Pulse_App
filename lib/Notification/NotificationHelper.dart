import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Safe_pulse/services/background_services.dart';

class NotificationHelper {
  static Future<void> setupNotificationHandlers() async {
    // Background handler (already set in main)

    // Foreground handler
    FirebaseMessaging.onMessage.listen((message) async {
      // await initializeService();
      _showLocalNotification(message);
    });

    // Opened from background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      // await initializeService();
      _handleNotificationData(message.data);
    });

    // Initial message (app terminated)
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    // Implement local notification display if needed
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    // Handle notification data (e.g., navigation)
  }
}

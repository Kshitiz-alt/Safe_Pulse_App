import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class FirebaseNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(BuildContext context) async {
    _handleTokenRefresh();
    print('FCM Token refreshed: fghngfjhgjhgkii');
    await _requestPermission();
    await _handleInitialMessage(context);
    _handleForegroundMessages(context);
    _handleOnMessageOpenedApp(context);
  }

  Future<void> _requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _handleTokenRefresh() async {
    print('FCM Token refreshed: 111111');
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken != null) {
        await _sendTokenToServer(newToken, accessToken);
      }
    });
  }

  Future<void> _handleInitialMessage(BuildContext context) async {
    final message = await _firebaseMessaging.getInitialMessage();
    if (message?.notification != null) {
      _showCustomDialog(
        context,
        title: message!.notification!.title ?? 'Notification',
        message: message.notification!.body ?? '',
      );
    }
  }

  void _handleForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        _showCustomDialog(
          context,
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
        );
      }
    });
  }

  void _handleOnMessageOpenedApp(BuildContext context) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.notification != null) {
        _showCustomDialog(
          context,
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
        );
      }
    });
  }

  Future<void> _sendTokenToServer(String token, String accessToken) async {
    try {
      final body = jsonEncode({'fcm_token': token});
      print("fdshgfhfgjhfgjgfjh $token");
      final response = await http.post(
        Uri.parse('url/update-fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token successfully sent to server');
      } else {
        debugPrint('❌ Failed to send FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔥 Error sending token: $e');
    }
  }

  Future<void> _showCustomDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK', style: TextStyle(color: Colors.blue)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:Safe_pulse/Completeprofile.dart';
import 'package:Safe_pulse/firebase_options.dart';

// import 'package:Safe_pulse/services/background_services.dart';
// import 'package:Safe_pulse/services/permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Safe_pulse/Signup/onboarding_view.dart';
import 'package:Safe_pulse/Signup/LoginPage.dart';
import 'package:Safe_pulse/BottomPages/BottomNav.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // await initializeService();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Ensure Firebase is initialized
  // debugPrint("✅ Background message received: ${message.messageId}");

  // You can also display a local notification here if needed
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Set up foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    //debugPrint("Foreground message: ${message.messageId}");
    // await initializeService();
    // You can also show a local notification here
  });
  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_service',
    'Location Service',
    // 'Location Service',
    importance: Importance.low,
  );

 

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  // await PermissionHelper.requestPermissions();

  // if (Platform.isAndroid) {
  //   bool isRunning = await FlutterBackgroundService().isRunning();

  //   if (!isRunning) {
  //     await initializeService();
  //   }
  // }
  // await initializeService();

  // if (Platform.isAndroid) {
  //   bool isRunning = await FlutterBackgroundService().isRunning();
  //   if (!isRunning) {
  //     await initializeService();
  //   }
  // }

  final prefs = await SharedPreferences.getInstance();
  final onboarding = prefs.getBool("onboarding") ?? false;
  final jwtToken = prefs.getString("jwtToken");

  runApp(O2IKidSecureApp(onboarding: onboarding, jwtToken: jwtToken));
}

class O2IKidSecureApp extends StatelessWidget {
  final bool onboarding;
  final String? jwtToken;

  const O2IKidSecureApp({super.key, this.onboarding = false, this.jwtToken});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Pulse',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: onboarding
          ? (jwtToken != null && jwtToken!.isNotEmpty
              ? BottomNav()
              // : BottomNav())
              : LoginPage())
          : const OnboardingView(),
    );
  }
}

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

// import 'package:http/http.dart' as http;
// import 'package:Safe_pulse/Signup/LoginPage.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({super.key});

//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }

// class _AuthWrapperState extends State<AuthWrapper> {
//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   bool _isLoading = true;
//   Widget? _initialScreen;

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//     _setupPushNotifications();
//   }

//   Future<void> _showCustomDialog(
//     BuildContext context, {
//     required String title,
//     required String message,
//     bool isSuccess = false,
//     Function()? onConfirm,
//     bool showCancel = false,
//     Function()? onCancel,
//   }) async {
//     await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         title: Text(
//           title,
//           style: TextStyle(
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         content: Text(
//           message,
//           style: TextStyle(color: Colors.black87.withOpacity(0.8)),
//         ),
//         actions: [
//           if (showCancel)
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 if (onCancel != null) onCancel();
//               },
//               child: Text(
//                 'Cancel',
//                 style: TextStyle(
//                   color: Colors.red,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               if (onConfirm != null) onConfirm();
//             },
//             child: Text(
//               'OK',
//               style: TextStyle(
//                 color: Colors.blue,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _initializeApp() async {
//     try {
//       // Request notification permissions
//       await _firebaseMessaging.requestPermission(
//         alert: true,
//         announcement: false,
//         badge: true,
//         carPlay: false,
//         criticalAlert: false,
//         provisional: false,
//         sound: true,
//       );

//       // Get FCM token and save it
//       final token = await FirebaseMessaging.instance.getToken();
//       debugPrint('Initial FCM Token: $token');

//       // Check auth status
//       final prefs = await SharedPreferences.getInstance();
//       final accessToken = prefs.getString('access_token');

//       if (accessToken == null) {
//         setState(() {
//           _initialScreen = LoginPage();
//           _isLoading = false;
//         });
//         return;
//       }




//       setState(() {
      
//       });
//     } catch (e) {
//       debugPrint('Initialization error: $e');
//       setState(() {
//         _initialScreen =  LoginPage();
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _sendTokenToServer(String token, String accessToken) async {
//     try {
//       final body = jsonEncode({'fcm_token': token});
//       debugPrint(
//           'Sending FCM update..............................................: $body');
//       final response = await http.post(
//         Uri.parse('url/update-fcm-token'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json',
//         },
//         body: body,
//       );

//       if (response.statusCode == 200) {
//         debugPrint('✅ FCM token successfully sent to server');
//       } else {
//         debugPrint(
//             '❌ Failed to send FCM token: ${response.statusCode} - ${response.body}');
//       }
//     } catch (e) {
//       debugPrint('🔥 Error sending token to server: $e');
//     }
//   }

//   void _setupPushNotifications() {
//     // Handle token refresh
//     _firebaseMessaging.onTokenRefresh.listen((newToken) async {
//       debugPrint('FCM Token refreshed: $newToken');
//       final prefs = await SharedPreferences.getInstance();
//       final accessToken = prefs.getString('access_token');
//       if (accessToken != null) {
//         await _sendTokenToServer(newToken, accessToken);
//       }
//     });

//     // Handle foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       if (message.notification != null && mounted) {
//         _showCustomDialog(
//           context,
//           title: message.notification?.title ?? 'Notification',
//           message: message.notification?.body ?? '',
//           isSuccess: true,
//         );
//       }
//     });

//     // Handle when app is opened from terminated state
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       if (message.notification != null && mounted) {
//         _showCustomDialog(
//           context,
//           title: message.notification?.title ?? 'Notification',
//           message: message.notification?.body ?? '',
//           isSuccess: true,
//         );
//       }
//     });

//     // Get initial message if app was launched from notification
//     FirebaseMessaging.instance
//         .getInitialMessage()
//         .then((RemoteMessage? message) {
//       if (message != null && mounted) {
//         _showCustomDialog(
//           context,
//           title: message.notification?.title ?? 'Notification',
//           message: message.notification?.body ?? '',
//           isSuccess: true,
//         );
//       }
//     });
//   }

// }

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:Safe_pulse/Signup/LoginPage.dart';
// import 'package:Safe_pulse/firebase_options.dart';
// import 'package:Safe_pulse/services/background_services.dart';

// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:http/http.dart' as http;

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(); // Ensure Firebase is initialized
//   debugPrint("✅ Background message received: ${message.messageId}");
//   await initializeService();
//   // You can also display a local notification here if needed
// }

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // await Firebase.initializeApp();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//   // Create notification channel
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'location_service',
//     'Location Service',
//     importance: Importance.low,
//   );

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
//   // await PermissionHelper.requestPermissions();

//   // try {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   if (prefs.getString("username") != null) await initializeService();
//   // } catch (e) {}
//   // await initializeService();

//   // if (Platform.isAndroid) {
//   //   bool isRunning = await FlutterBackgroundService().isRunning();
//   //   if (!isRunning) {
//   //     await initializeService();
//   //   }
//   // }

//   final prefs = await SharedPreferences.getInstance();
//   final onboarding = prefs.getBool("onboarding") ?? false;
//   final jwtToken = prefs.getString("jwtToken");
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Service Selector',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         scaffoldBackgroundColor: Colors.grey[50],
//         textSelectionTheme: TextSelectionThemeData(
//           cursorColor: Colors.blue,
//           selectionColor: Colors.blue.withOpacity(0.4),
//           selectionHandleColor: Colors.blue,
//         ),
//         progressIndicatorTheme: const ProgressIndicatorThemeData(
//           color: Colors.blue, // 👈 Applies to all CircularProgressIndicators
//         ),
//       ),
//       home: const AuthWrapper(),
//     );
//   }
// }

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

//       final username = prefs.getString('username') ?? '';
//       final userId = prefs.getInt('user_id')?.toString() ?? '0';
//       final role = prefs.getString('role') ?? '';

//       // Update token for the current user - use accessToken instead of newAccessToken
//       if (token != null) {
//         await _sendTokenToServer(
//             token, accessToken); // Changed from newAccessToken to accessToken
//       }

//       setState(() {
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint('Initialization error: $e');
//       setState(() {
//         _initialScreen = LoginPage();
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
//         Uri.parse('fhd/update-fcm-token'),
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
//       print(
//           '✅ Notification opened from background/terminated state and displayed');
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
//       print(
//           '✅ Notification opened from background/terminated state and displayed2');
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

//   @override
//   Widget build(BuildContext context) {
//     return _isLoading
//         ? const Scaffold(
//             body: Center(
//               child: CircularProgressIndicator(
//                 color: Colors.blue, // 👈 Set the loading indicator color
//               ),
//             ),
//           )
//         : LoginPage();
//   }
// }

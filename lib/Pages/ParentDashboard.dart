import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Notification/firebase_notification_service.dart';

import 'package:Safe_pulse/Pages/LocationHistoryPage.dart';
import 'package:Safe_pulse/Pages/UserRelationsPage.dart';
import 'package:Safe_pulse/Pages/UserRelationsPageRaj.dart';

import 'package:Safe_pulse/other%20pages/BackgroundRuncheck.dart';
import 'package:Safe_pulse/other%20pages/LiveTrackingPage.dart';
import 'package:Safe_pulse/screens/landing_page.dart';
import 'package:Safe_pulse/services/permission_helper.dart';
import 'package:Safe_pulse/services/wergfredfhgfgj.dart';
import 'package:Safe_pulse/working%20location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentDashboard extends StatefulWidget {
  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final ApiService _apiService = ApiService();
  Future<void> _requestPermissions() async {
    await PermissionHelper.requestPermissions(context);
  }

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String _fcmToken = "";

  void initState() {
    super.initState();
    _requestPermissions(); // Call the method here
    disableBatteryOptimization();

    _initializeApp();
    _setupPushNotifications();
  }

  Future<void> _showCustomDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isSuccess = false,
    Function()? onConfirm,
    bool showCancel = false,
    Function()? onCancel,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.black87.withOpacity(0.8)),
        ),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onCancel != null) onCancel();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm();
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeApp() async {
    try {
      // Request notification permissions
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Get FCM token and save it
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token!;
      });
      _apiService.updateNotificationToken(token!);
      debugPrint('Initial FCM Token: $token');

      // Check auth status
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      final username = prefs.getString('username') ?? '';
      final userId = prefs.getInt('user_id')?.toString() ?? '0';
      final role = prefs.getString('role') ?? '';
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  void _setupPushNotifications() {
    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      // _apiService.updateNotificationToken(newToken);
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken != null) {
        // await _sendTokenToServer(newToken, accessToken);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showCustomDialog(
          context,
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
          isSuccess: true,
        );
      }
      print(
          '✅ Notification opened from background/terminated state and displayed');
    });

    // Handle when app is opened from terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showCustomDialog(
          context,
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
          isSuccess: true,
        );
      }
      print(
          '✅ Notification opened from background/terminated state and displayed2');
    });

    // Get initial message if app was launched from notification
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null && mounted) {
        _showCustomDialog(
          context,
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
          isSuccess: true,
        );
      }
    });
  }

  void disableBatteryOptimization() {
    if (Platform.isAndroid) {
      AndroidIntent intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.otoi.safe_pulse', // Replace with your package name
      );
      intent.launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (OverscrollIndicatorNotification overscroll) {
            overscroll.disallowIndicator();
            return true;
          },
          child: ListView(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            children: <Widget>[
              // Header Section
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Parent Dashboard",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    IconButton(
                      splashRadius: 20,
                      icon: const Icon(Icons.notifications_active),
                      onPressed: () {
                        // Navigate to notifications
                      },
                    ),
                  ],
                ),
              ),

              // Welcome Message
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, Abhi!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Keep track of your children's activities and ensure their safety.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Child Profiles Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Child Profiles",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    // Example Child Profile Cards
                    _buildChildProfileCard(
                        "Alice", "assets/person.jpg", "Last seen: 10 mins ago"),
                    _buildChildProfileCard(
                        "Bob", "assets/person.jpg", "Last seen: 5 mins ago"),
                  ],
                ),
              ),

              // Quick Actions Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickActionButton(
                            Icons.location_on, "Live Tracking"),
                        _buildQuickActionButton(Icons.fence, "Geofence"),
                        _buildQuickActionButton(Icons.chat, "Chat"),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Alerts Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recent Alerts",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildAlertCard("Alice left the geofence", "10 mins ago"),
                    _buildAlertCard("Bob entered the geofence", "15 mins ago"),
                  ],
                ),
              ),

              // Emergency Contacts Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Emergency Contacts",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildEmergencyContact(
                        "Jane Doe", "Mother", "123-456-7890"),
                    _buildEmergencyContact(
                        "John Doe", "Father", "987-654-3210"),
                  ],
                ),
              ),

              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RealTimeLocationTracking()),
                    );
                  },
                  child: Text('START WALKING'),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveTrackingPagemain(
                          // requestingUserId: '67eb925ec887865e445fbe33',
                          // userIdToTrack: '67eb9013c887865e445fbe30',
                          requestingUserId:
                              '67eb925ec887865e445fbe33', // Replace with actual ID
                          userIdsToTrack: [
                            '67eb9013c887865e445fbe30',
                            '67ef7a413fb07f131c1a1ad4',
                          ],
                          userNames: {
                            '67eb9013c887865e445fbe30': 'Rahul',
                            '67ef7a413fb07f131c1a1ad4': 'Aman',
                          },
                        ),
                      ),
                    );
                  },
                  child: Text('TRACK WALIKING'),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationHistoryPage(mail: ""),
                      ),
                    );
                  },
                  child: Text('TRACK PREVIOUS DAYS'),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserRelationsPage(),
                      ),
                    );
                  },
                  child: Text('UserRelationsPage'),
                ),
              ),

//Raj Test
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserRelationsPageRaj(),
                      ),
                    ).then((_) {
                      // This will show the bottom sheet when returning from UserRelationsPageRaj
                      // if you want that behavior
                    });
                  },
                  child: Text('Raj Test'),
                ),
              ),
              // Center(
              //   child: ElevatedButton(
              //     onPressed: () {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => LandingPage(),
              //         ),
              //       );
              //     },
              //     child: Text('bacground run check'),
              //   ),
              // ),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SendLocationPage(),
                      ),
                    );
                  },
                  child: Text('Testing'),
                ),
              ),
              // Center(
              //   child: ElevatedButton(
              //     child: Text('Start Hourly Notifications'),
              //     onPressed: () =>
              //         NotificationService().scheduleHourlyNotification(
              //       title: 'Hourly Alert',
              //       body: 'This is your hourly notification!',
              //     ),
              //   ),
              // )

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    SelectableText(
                      _fcmToken ?? 'Fetching token...',
                      style: TextStyle(color: Colors.black87),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _fcmToken != null
                          ? () {
                              Clipboard.setData(ClipboardData(text: _fcmToken));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Token copied to clipboard')),
                              );
                            }
                          : null,
                      icon: Icon(Icons.copy),
                      label: Text('Copy Token'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildProfileCard(
      String name, String imagePath, String lastSeen) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: AssetImage(imagePath),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(lastSeen),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          // Navigate to child profile
        },
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 30, color: Colors.blue[800]),
          onPressed: () {
            // Handle quick action
          },
        ),
        Text(label, style: TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _buildAlertCard(String message, String time) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(Icons.warning, color: Colors.orange),
        title: Text(message),
        subtitle: Text(time),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          // Navigate to alert details
        },
      ),
    );
  }

  Widget _buildEmergencyContact(String name, String relation, String phone) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(Icons.contact_phone, color: Colors.blue[800]),
        title: Text(name),
        subtitle: Text("$relation - $phone"),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          // Navigate to contact details
        },
      ),
    );
  }
}

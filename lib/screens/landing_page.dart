// // import 'package:flutter/material.dart';
// // import 'package:Safe_pulse/screens/home_page.dart';
// // import 'package:permission_handler/permission_handler.dart';

// // class LandingPage extends StatefulWidget {
// //   const LandingPage({Key? key}) : super(key: key);

// //   @override
// //   _LandingPageState createState() => _LandingPageState();
// // }

// // class _LandingPageState extends State<LandingPage> {
// //   @override
// //   void initState() {
// //     super.initState();
// //     _requestPermissions();
// //   }

// //   Future<void> _requestPermissions() async {
// //     // Request Notification Permission first
// //     PermissionStatus notificationStatus =
// //         await Permission.notification.request();

// //     if (notificationStatus.isDenied) {
// //       _showPermissionDeniedDialog("Notification Permission is required.");
// //       return; // Stop further execution if denied
// //     }

// //     // If notification permission is granted, request Location Permission
// //     PermissionStatus locationStatus = await Permission.location.request();

// //     if (locationStatus.isDenied) {
// //       _showPermissionDeniedDialog("Location Permission is required.");
// //       return;
// //     }

// //     // If location permission is granted, request Location Always Permission
// //     PermissionStatus locationAlwaysStatus =
// //         await Permission.locationAlways.request();

// //     if (locationAlwaysStatus.isGranted) {
// //       _navigateToHomePage();
// //     } else {
// //       _showPermissionDeniedDialog("Location Permission is required.");
// //       return;
// //     }
// //   }

// //   void _navigateToHomePage() {
// //     Navigator.pushReplacement(
// //       context,
// //       MaterialPageRoute(builder: (context) => const HomePage()),
// //     );
// //   }

// //   void _showPermissionDeniedDialog(String message) {
// //     showDialog(
// //       context: context,
// //       builder: (context) => AlertDialog(
// //         title: const Text("Permission Required"),
// //         content: Text(message),
// //         actions: [
// //           TextButton(
// //             onPressed: () {
// //               Navigator.pop(context); // Close the dialog
// //             },
// //             child: const Text("Dismiss"),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return const Scaffold(
// //       body: Center(child: Text("Checking Permissions...")),
// //     );
// //   }
// // }





// import 'package:flutter/material.dart';
// import 'package:Safe_pulse/screens/home_page.dart';
// import 'package:permission_handler/permission_handler.dart';

// class LandingPage extends StatefulWidget {
//   const LandingPage({Key? key}) : super(key: key);

//   @override
//   _LandingPageState createState() => _LandingPageState();
// }

// class _LandingPageState extends State<LandingPage> {
//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//   }

//   Future<void> _requestPermissions() async {
//     // First request Notification Permission
//     await _requestNotificationPermission();
//   }

//   Future<void> _requestNotificationPermission() async {
//     PermissionStatus notificationStatus = await Permission.notification.status;
    
//     if (!notificationStatus.isGranted) {
//       notificationStatus = await Permission.notification.request();
//     }

//     if (notificationStatus.isDenied) {
//       _showPermissionDeniedDialog("Notification Permission is required.");
//       return;
//     }

//     // If notification permission is granted, show location explanation dialog
//     await _showLocationPermissionExplanation();
//   }

//   Future<void> _showLocationPermissionExplanation() async {
//     bool proceed = await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: const Text("Location Permission Needed"),
//         content: const Text(
//           "Safe Pulse collects your location data to enable real-time location tracking and emergency safety alerts, even when the app is closed or not in use.",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text("Continue"),
//           ),
//         ],
//       ),
//     );

//     if (proceed == true) {
//       await _requestLocationPermissions();
//     } else {
//       _showPermissionDeniedDialog("Location Permission is required for the app to function properly.");
//     }
//   }

//   Future<void> _requestLocationPermissions() async {
//     // Request Location Permission
//     PermissionStatus locationStatus = await Permission.location.request();

//     if (locationStatus.isDenied) {
//       _showPermissionDeniedDialog("Location Permission is required.");
//       return;
//     }

//     // Request Location Always Permission
//     PermissionStatus locationAlwaysStatus = await Permission.locationAlways.request();

//     if (locationAlwaysStatus.isGranted) {
//       _navigateToHomePage();
//     } else {
//       _showPermissionDeniedDialog("Background Location Permission is required for safety alerts.");
//     }
//   }

//   void _navigateToHomePage() {
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const HomePage()),
//     );
//   }

//   void _showPermissionDeniedDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Permission Required"),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context); // Close the dialog
//             },
//             child: const Text("Dismiss"),
//           ),
//           TextButton(
//             onPressed: () => openAppSettings(),
//             child: const Text("Open Settings"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 20),
//             Text("Checking Permissions..."),
//           ],
//         ),
//       ),
//     );
//   }
// }
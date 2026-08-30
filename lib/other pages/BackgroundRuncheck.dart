// import 'dart:async';
// import 'dart:convert';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:stomp_dart_client/stomp_dart_client.dart';
// import 'package:location/location.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: true,
//       isForegroundMode: true,
//       foregroundServiceNotificationId: 888,
//       initialNotificationTitle: 'Location Tracking',
//       initialNotificationContent: 'Tracking your location in background',
//     ),
//     iosConfiguration: IosConfiguration(),
//   );
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   if (service is AndroidServiceInstance) {
//     service.setAsForegroundService();
//   }

//   // Declare stompClient at the start of the function
//   late StompClient stompClient;

//   final location = Location();
//   bool serviceEnabled = await location.serviceEnabled();
//   if (!serviceEnabled) {
//     serviceEnabled = await location.requestService();
//     if (!serviceEnabled) {
//       return;
//     }
//   }

//   var permissionGranted = await location.hasPermission();
//   if (permissionGranted == PermissionStatus.denied) {
//     permissionGranted = await location.requestPermission();
//     if (permissionGranted != PermissionStatus.granted) {
//       return;
//     }
//   }

//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   final userid = prefs.getString("userId");
//   final userEmail = prefs.getString("username");

//   stompClient = StompClient(
//     config: StompConfig.sockJS(
//       url: '${ApiService.baseUrl}/ws-location',
//       onConnect: (StompFrame frame) {
//         location.onLocationChanged.listen((LocationData locationData) {
//           if (locationData.latitude != null && locationData.longitude != null) {
//             final location = {
//               'latitude': locationData.latitude,
//               'longitude': locationData.longitude,
//               'timestamp': DateTime.now().toIso8601String(),
//               'userId': userid,
//             };

//             stompClient.send(
//               destination: '/app/update-location',
//               body: jsonEncode(location),
//             );

//             if (service is AndroidServiceInstance) {
//               service.setForegroundNotificationInfo(
//                 title: "Location Tracking",
//                 content:
//                     "Lat: ${locationData.latitude!.toStringAsFixed(4)}, Lng: ${locationData.longitude!.toStringAsFixed(4)}",
//               );
//             }
//           }
//         });
//       },
//     ),
//   );

//   stompClient.activate();

//   service.on('stopService').listen((event) {
//     stompClient.deactivate();
//     service.stopSelf();
//   });
// }

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   initializeService();
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Background Location Tracker',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: BackgroundRunCheck(),
//     );
//   }
// }

// class BackgroundRunCheck extends StatefulWidget {
//   @override
//   _BackgroundRunCheckState createState() => _BackgroundRunCheckState();
// }

// class _BackgroundRunCheckState extends State<BackgroundRunCheck> {
//   late GoogleMapController _mapController;
//   late StompClient _stompClient;
//   final Set<Marker> _markers = {};
//   final Set<Polyline> _polylines = {};
//   final List<LatLng> _travelPath = [];
//   String? userid = "";
//   String? userEmail = "";
//   bool _isTracking = false;

//   @override
//   void initState() {
//     super.initState();
//     getuserid().then((_) {
//       _connectWebSocket();
//       _checkServiceRunning();
//     });
//   }

//   Future<void> getuserid() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       userid = prefs.getString("userId");
//       userEmail = prefs.getString("username");
//     });
//   }

//   Future<void> _checkServiceRunning() async {
//     final service = FlutterBackgroundService();
//     bool isRunning = await service.isRunning();
//     setState(() {
//       _isTracking = isRunning;
//     });
//   }

//   void _connectWebSocket() {
//     _stompClient = StompClient(
//       config: StompConfig.sockJS(
//         url: '${ApiService.baseUrl}/ws-location',
//         onConnect: _onWebSocketConnected,
//       ),
//     );
//     _stompClient.activate();
//   }

//   void _onWebSocketConnected(StompFrame frame) {
//     _stompClient.subscribe(
//       destination: '/topic/location-updates',
//       callback: (frame) {
//         if (frame.body != null) {
//           final locationData = jsonDecode(frame.body!);
//           final user = locationData['user'];
//           if (user != null && user['email'] == userEmail) {
//             final latitude = locationData['latitude'];
//             final longitude = locationData['longitude'];
//             setState(() => _updateMap(LatLng(latitude, longitude)));
//           }
//         }
//       },
//     );
//   }

//   void _updateMap(LatLng newLocation) {
//     setState(() {
//       _markers.clear();
//       _markers.add(Marker(
//         markerId: MarkerId(newLocation.toString()),
//         position: newLocation,
//         infoWindow: InfoWindow(title: 'Current Location'),
//       ));

//       _travelPath.add(newLocation);
//       _polylines.clear();
//       _polylines.add(Polyline(
//         polylineId: PolylineId('travelPath'),
//         points: _travelPath,
//         color: Colors.red,
//         width: 5,
//       ));

//       _mapController.animateCamera(CameraUpdate.newLatLng(newLocation));
//     });
//   }

//   Future<void> _toggleTracking() async {
//     final service = FlutterBackgroundService();
//     if (_isTracking) {
//       service.invoke('stopService');
//     } else {
//       await service.startService();
//     }
//     setState(() => _isTracking = !_isTracking);
//   }

//   @override
//   void dispose() {
//     _stompClient.deactivate();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Real-Time Location Tracking'),
//         actions: [
//           IconButton(
//             icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
//             onPressed: _toggleTracking,
//           ),
//         ],
//       ),
//       body: GoogleMap(
//         onMapCreated: (controller) => _mapController = controller,
//         initialCameraPosition: CameraPosition(
//           target: LatLng(28.5892, 77.3176),
//           zoom: 13,
//         ),
//         markers: _markers,
//         polylines: _polylines,
//       ),
//     );
//   }
// }

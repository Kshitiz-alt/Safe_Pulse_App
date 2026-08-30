// // ignore_for_file: avoid_unnecessary_containers

// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:latlong2/latlong.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   String stopServiceButtonText = 'Stop Services';
//   final service = FlutterBackgroundService();
//   final MapController _mapController = MapController();
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FutureBuilder(
//           future: getCurrentLocation(),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData) {
//               return const Center(
//                 child: CircularProgressIndicator(),
//               );
//             }
//             return FlutterMap(
//               mapController: _mapController,
//               options: const MapOptions(
//                 initialCenter: LatLng(20.5937, 78.9629),
//                 initialZoom: 4,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                   userAgentPackageName: 'com.example.services',
//                 ),
//                 MarkerLayer(markers: [
//                   Marker(
//                       point: LatLng(snapshot.data!["latitude"]!,
//                           snapshot.data!["longitude"]!),
//                       child: Container(
//                         child: const Icon(
//                           Icons.location_on,
//                           size: 40,
//                           color: Colors.red,
//                         ),
//                       ))
//                 ])
//               ],
//             );
//           }),
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           InkWell(
//             onTap: () {
//               service.invoke('setAsForeground');
//               SnackBar snackBar =
//                   const SnackBar(content: Text("Foreground services active"));
//               ScaffoldMessenger.of(context).showSnackBar(snackBar);
//             },
//             child: Container(
//                 height: 55,
//                 width: 55,
//                 decoration: BoxDecoration(
//                     color: Colors.green,
//                     borderRadius: BorderRadius.circular(12)),
//                 child: const Center(child: Icon(Icons.add))),
//           ),
//           const SizedBox(height: 10),
//           InkWell(
//             onTap: () {
//               service.invoke('setAsBackground');
//               SnackBar snackBar =
//                   const SnackBar(content: Text("Background services active"));
//               ScaffoldMessenger.of(context).showSnackBar(snackBar);
//             },
//             //dfgfdhgfjghjhgk new appproject
//             child: Container(
//                 height: 55,
//                 width: 55,
//                 decoration: BoxDecoration(
//                     color: Colors.yellow,
//                     borderRadius: BorderRadius.circular(12)),
//                 child: const Center(child: Icon(Icons.remove))),
//           ),
//           const SizedBox(height: 10),
//           InkWell(
//             onTap: () async {
//               bool isRunning = await service.isRunning();
//               if (isRunning) {
//                 service.invoke('stopService');
//               } else {
//                 service.startService();
//               }
//               setState(() {
//                 if (!isRunning) {
//                   stopServiceButtonText = 'Stop Services';
//                 } else {
//                   stopServiceButtonText = 'Start Services';
//                 }
//               });
//               SnackBar snackBar =
//                   SnackBar(content: Text(stopServiceButtonText));
//               ScaffoldMessenger.of(context).showSnackBar(snackBar);
//             },
//             child: Container(
//                 height: 55,
//                 width: 55,
//                 decoration: BoxDecoration(
//                     color: Colors.red, borderRadius: BorderRadius.circular(12)),
//                 child: const Center(child: Icon(Icons.stop))),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<Map<String, double>> getCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//     return {"latitude": position.latitude, "longitude": position.longitude};
//   }
// }

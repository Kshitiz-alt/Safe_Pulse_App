// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:Safe_pulse/Api/ApiService.dart';
// import 'package:Safe_pulse/Pages/LocationHistoryPage.dart';
// import 'package:Safe_pulse/Pages/locationhistory24.dart';
// import 'package:Safe_pulse/other%20pages/LiveTrackingPage.dart';
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

// class UserRelationsPageRaj extends StatefulWidget {
//   const UserRelationsPageRaj({Key? key}) : super(key: key);

//   @override
//   _UserRelationsPageRajState createState() => _UserRelationsPageRajState();
// }

// class _UserRelationsPageRajState extends State<UserRelationsPageRaj> {
//   List<dynamic> _relations = [];
//   bool _isLoading = false;
//   String _errorMessage = "";
//   String? _requestingUserId;
//   String? _userEmail;
//   List<String> _userIdsToTrack = [];

//   // For map
//   late GoogleMapController _mapController;
//   final Set<Marker> _markers = {};
//   LatLng? _currentLocation;
//   bool _showUserList = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//     // Default location (you can change this)
//     _currentLocation = const LatLng(28.6139, 77.2090); // Delhi coordinates
//   }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _requestingUserId = prefs.getString("userId");
//       _userEmail = prefs.getString("username");
//     });

//     if (_userEmail != null) {
//       _fetchRelations();
//     } else {
//       setState(() {
//         _errorMessage = "User email not found";
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _fetchRelations() async {
//     if (_userEmail == null) return;

//     setState(() {
//       _isLoading = true;
//       _errorMessage = "";
//     });

//     try {
//       final response = await http.get(Uri.parse(
//           '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$_userEmail'));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           _relations = data;
//           _userIdsToTrack = data
//               .where((relation) =>
//                   (relation['activityStatus'] == 'Not Active' ||
//                       relation['activityStatus'] == null) &&
//                   relation['relationDirection'] == 'connected')
//               .map<String>((relation) => relation['userRelationId'].toString())
//               .toList();
//         });
//       } else {
//         setState(() {
//           _errorMessage =
//               "Failed to fetch relations. Status code: ${response.statusCode}";
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = "Error fetching relations: $e";
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _navigateToTrackingPage(List<String> userIdsToTrack) {
//     if (_requestingUserId == null || userIdsToTrack.isEmpty) return;

//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LiveTrackingPagemain(
//           requestingUserId: _requestingUserId!,
//           userIdsToTrack: userIdsToTrack,
//         ),
//       ),
//     );
//   }

//   void movetohistory(String mail) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LocationHistoryPage(
//           mail: mail,
//         ),
//       ),
//     );
//   }

//   Widget _buildRelationCard(
//       Map<String, dynamic> relation, Color color, bool isTrackable) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: color,
//           child: Text(
//             relation['relationName']?.toString().substring(0, 1) ?? '?',
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//         title: Text(relation['otherUserEmail'] ?? 'Unknown email'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Relation: ${relation['relationName'] ?? 'Unknown'}'),
//           ],
//         ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (isTrackable)
//               IconButton(
//                 icon: Icon(Icons.location_on, color: Colors.blue),
//                 onPressed: () {
//                   // When clicked, show this user's location on the map
//                   // This is a placeholder - you'll need to implement actual location fetching
//                   _showUserOnMap(relation['userRelationId'].toString(),
//                                relation['otherUserEmail'] ?? 'User');
//                 },
//                 tooltip: 'Show on map',
//               ),
//             IconButton(
//               icon: Icon(Icons.history, color: Colors.black),
//               onPressed: () =>
//                   movetohistory(relation['otherUserEmail'] ?? 'Unknown email'),
//               tooltip: 'View history',
//             ),
//             relation['isLinked'] == 1.0
//                 ? Icon(Icons.check_circle, color: Colors.green)
//                 : Icon(Icons.pending, color: Colors.orange),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showUserOnMap(String userId, String userName) {
//     // This is a placeholder - you should fetch the actual location from your API
//     // For now, we'll just simulate a location near the current position
//     if (_currentLocation == null) return;

//     final newLocation = LatLng(
//       _currentLocation!.latitude + (Random().nextDouble() * 0.01 - 0.005),
//       _currentLocation!.longitude + (Random().nextDouble() * 0.01 - 0.005),
//     );

//     setState(() {
//       _markers.clear();
//       _markers.add(Marker(
//         markerId: MarkerId(userId),
//         position: newLocation,
//         infoWindow: InfoWindow(title: userName),
//       ));
//       _currentLocation = newLocation;
//       _mapController.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 15));
//       _showUserList = false; // Hide user list when showing a specific user
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final trackableRelations = _relations
//         .where((relation) =>
//             (relation['activityStatus'] == 'Not Active' ||
//                 relation['activityStatus'] == null) &&
//             relation['relationDirection'] == 'connected')
//         .toList();

//     final otherRelations = _relations
//         .where((relation) => !((relation['activityStatus'] == 'Not Active' ||
//                 relation['activityStatus'] == null) &&
//             relation['relationDirection'] == 'connected'))
//         .toList();

//     return Scaffold(
//       body: Stack(
//         children: [
//           // Google Map
//           GoogleMap(
//             onMapCreated: (controller) => _mapController = controller,
//             initialCameraPosition: CameraPosition(
//               target: _currentLocation ?? const LatLng(28.6139, 77.2090),
//               zoom: 12,
//             ),
//             markers: _markers,
//             myLocationEnabled: true,
//             myLocationButtonEnabled: false,
//           ),

//           // User list panel
//           if (_showUserList)
//             Positioned(
//               bottom: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 height: MediaQuery.of(context).size.height * 0.5,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(20),
//                     topRight: Radius.circular(20),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 10,
//                       spreadRadius: 0,
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     // Draggable handle
//                     GestureDetector(
//                       onVerticalDragUpdate: (details) {
//                         // Handle swipe up/down to expand/collapse
//                       },
//                       child: Container(
//                         width: 40,
//                         height: 5,
//                         margin: EdgeInsets.symmetric(vertical: 10),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[400],
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                     ),

//                     // Title
//                     Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 16),
//                       child: Text(
//                         'Trackable Users',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),

//                     // Relations list
//                     Expanded(
//                       child: _isLoading
//                           ? Center(child: CircularProgressIndicator())
//                           : _errorMessage.isNotEmpty
//                               ? Center(child: Text(_errorMessage))
//                               : ListView(
//                                   children: [
//                                     if (trackableRelations.isNotEmpty) ...[
//                                       ...trackableRelations.map((relation) =>
//                                           _buildRelationCard(
//                                               relation, Colors.blue, true)),
//                                     ],
//                                     if (trackableRelations.isEmpty)
//                                       Center(
//                                         child: Padding(
//                                           padding: EdgeInsets.all(16),
//                                           child: Text('No trackable users found'),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           // Map controls
//           Positioned(
//             top: 40,
//             right: 16,
//             child: Column(
//               children: [
//                 FloatingActionButton(
//                   mini: true,
//                   heroTag: 'trackAll',
//                   onPressed: _userIdsToTrack.isNotEmpty && _requestingUserId != null
//                       ? () => _navigateToTrackingPage(_userIdsToTrack)
//                       : null,
//                   child: Icon(Icons.track_changes),
//                   tooltip: 'Track All',
//                 ),
//                 SizedBox(height: 8),
//                 FloatingActionButton(
//                   mini: true,
//                   heroTag: 'toggleList',
//                   onPressed: () {
//                     setState(() {
//                       _showUserList = !_showUserList;
//                     });
//                   },
//                   child: Icon(_showUserList ? Icons.map : Icons.list),
//                   tooltip: _showUserList ? 'Hide list' : 'Show list',
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // import 'dart:math';

// // import 'package:flutter/material.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:Safe_pulse/Api/ApiService.dart';
// // import 'package:Safe_pulse/Pages/LocationHistoryPage.dart';
// // import 'package:Safe_pulse/Pages/locationhistory24.dart';
// // import 'package:Safe_pulse/other%20pages/LiveTrackingPage.dart';
// // import 'dart:convert';
// // import 'package:shared_preferences/shared_preferences.dart';

// // class UserRelationsPageRaj extends StatefulWidget {
// //   const UserRelationsPageRaj({Key? key}) : super(key: key);

// //   @override
// //   _UserRelationsPageRajState createState() => _UserRelationsPageRajState();
// // }

// // class _UserRelationsPageRajState extends State<UserRelationsPageRaj> with SingleTickerProviderStateMixin {
// //   List<dynamic> _relations = [];
// //   bool _isLoading = false;
// //   String _errorMessage = "";
// //   String? _requestingUserId;
// //   String? _userEmail;
// //   List<String> _userIdsToTrack = [];

// //   // For map
// //   late GoogleMapController _mapController;
// //   final Set<Marker> _markers = {};
// //   LatLng? _currentLocation;

// //   // For sliding panel
// //   late AnimationController _animationController;
// //   late Animation<double> _panelAnimation;
// //   double _panelHeightClosed = 25.0; // Just the handle visible
// //   double _panelHeightOpen = 0.5; // Fraction of screen height when open
// //   bool get _isPanelOpen => _panelAnimation.value > 0.5;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadUserData();
// //     // Default location (you can change this)
// //     _currentLocation = const LatLng(28.6139, 77.2090); // Delhi coordinates

// //     // Initialize animation controller
// //     _animationController = AnimationController(
// //       duration: const Duration(milliseconds: 300),
// //       vsync: this,
// //     );

// //     _panelAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
// //       CurvedAnimation(
// //         parent: _animationController,
// //         curve: Curves.easeInOut,
// //       ),
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     _animationController.dispose();
// //     super.dispose();
// //   }

// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     setState(() {
// //       _requestingUserId = prefs.getString("userId");
// //       _userEmail = prefs.getString("username");
// //     });

// //     if (_userEmail != null) {
// //       _fetchRelations();
// //     } else {
// //       setState(() {
// //         _errorMessage = "User email not found";
// //         _isLoading = false;
// //       });
// //     }
// //   }

// //   Future<void> _fetchRelations() async {
// //     if (_userEmail == null) return;

// //     setState(() {
// //       _isLoading = true;
// //       _errorMessage = "";
// //     });

// //     try {
// //       final response = await http.get(Uri.parse(
// //           '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$_userEmail'));

// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);
// //         setState(() {
// //           _relations = data;
// //           _userIdsToTrack = data
// //               .where((relation) =>
// //                   (relation['activityStatus'] == 'Not Active' ||
// //                       relation['activityStatus'] == null) &&
// //                   relation['relationDirection'] == 'connected')
// //               .map<String>((relation) => relation['userRelationId'].toString())
// //               .toList();
// //         });
// //       } else {
// //         setState(() {
// //           _errorMessage =
// //               "Failed to fetch relations. Status code: ${response.statusCode}";
// //         });
// //       }
// //     } catch (e) {
// //       setState(() {
// //         _errorMessage = "Error fetching relations: $e";
// //       });
// //     } finally {
// //       setState(() {
// //         _isLoading = false;
// //       });
// //     }
// //   }

// //   void _navigateToTrackingPage(List<String> userIdsToTrack) {
// //     if (_requestingUserId == null || userIdsToTrack.isEmpty) return;

// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => LiveTrackingPagemain(
// //           requestingUserId: _requestingUserId!,
// //           userIdsToTrack: userIdsToTrack,
// //         ),
// //       ),
// //     );
// //   }

// //   void movetohistory(String mail) {
// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => LocationHistoryPage(
// //           mail: mail,
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildRelationCard(
// //       Map<String, dynamic> relation, Color color, bool isTrackable) {
// //     return Card(
// //       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
// //       child: ListTile(
// //         leading: CircleAvatar(
// //           backgroundColor: color,
// //           child: Text(
// //             relation['relationName']?.toString().substring(0, 1) ?? '?',
// //             style: TextStyle(color: Colors.white),
// //           ),
// //         ),
// //         title: Text(relation['otherUserEmail'] ?? 'Unknown email'),
// //         subtitle: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text('Relation: ${relation['relationName'] ?? 'Unknown'}'),
// //           ],
// //         ),
// //         trailing: Row(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             if (isTrackable)
// //               IconButton(
// //                 icon: Icon(Icons.location_on, color: Colors.blue),
// //                 onPressed: () {
// //                   _showUserOnMap(relation['userRelationId'].toString(),
// //                                relation['otherUserEmail'] ?? 'User');
// //                 },
// //                 tooltip: 'Show on map',
// //               ),
// //             IconButton(
// //               icon: Icon(Icons.history, color: Colors.black),
// //               onPressed: () =>
// //                   movetohistory(relation['otherUserEmail'] ?? 'Unknown email'),
// //               tooltip: 'View history',
// //             ),
// //             relation['isLinked'] == 1.0
// //                 ? Icon(Icons.check_circle, color: Colors.green)
// //                 : Icon(Icons.pending, color: Colors.orange),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   void _showUserOnMap(String userId, String userName) {
// //     if (_currentLocation == null) return;

// //     final newLocation = LatLng(
// //       _currentLocation!.latitude + (Random().nextDouble() * 0.01 - 0.005),
// //       _currentLocation!.longitude + (Random().nextDouble() * 0.01 - 0.005),
// //     );

// //     setState(() {
// //       _markers.clear();
// //       _markers.add(Marker(
// //         markerId: MarkerId(userId),
// //         position: newLocation,
// //         infoWindow: InfoWindow(title: userName),
// //       ));
// //       _currentLocation = newLocation;
// //       _mapController.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 15));
// //       _togglePanel(open: false); // Hide panel when showing a specific user
// //     });
// //   }

// //   void _togglePanel({bool? open}) {
// //     if (open != null) {
// //       open ? _animationController.forward() : _animationController.reverse();
// //     } else {
// //       _isPanelOpen ? _animationController.reverse() : _animationController.forward();
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final screenHeight = MediaQuery.of(context).size.height;
// //     final panelHeightOpen = screenHeight * _panelHeightOpen;

// //     final trackableRelations = _relations
// //         .where((relation) =>
// //             (relation['activityStatus'] == 'Not Active' ||
// //                 relation['activityStatus'] == null) &&
// //             relation['relationDirection'] == 'connected')
// //         .toList();

// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           // Google Map
// //           GoogleMap(
// //             onMapCreated: (controller) => _mapController = controller,
// //             initialCameraPosition: CameraPosition(
// //               target: _currentLocation ?? const LatLng(28.6139, 77.2090),
// //               zoom: 12,
// //             ),
// //             markers: _markers,
// //             myLocationEnabled: true,
// //             myLocationButtonEnabled: false,
// //           ),

// //           // Sliding panel
// //           Positioned(
// //             bottom: 0,
// //             left: 0,
// //             right: 0,
// //             child: GestureDetector(
// //               onVerticalDragUpdate: (details) {
// //                 // Calculate drag direction and update panel position
// //                 final newHeight = (_panelHeightClosed - details.primaryDelta!).clamp(
// //                   _panelHeightClosed,
// //                   panelHeightOpen
// //                 );
// //                 final fraction = 1 - (newHeight - _panelHeightClosed) / (panelHeightOpen - _panelHeightClosed);
// //                 _animationController.value = fraction;
// //               },
// //               onVerticalDragEnd: (details) {
// //                 // Determine if user swiped up or down
// //                 if (details.primaryVelocity! < 0) {
// //                   // Swiped up - open panel
// //                   _animationController.forward();
// //                 } else if (details.primaryVelocity! > 0) {
// //                   // Swiped down - close panel
// //                   _animationController.reverse();
// //                 } else {
// //                   // No significant velocity - snap to nearest position
// //                   if (_animationController.value > 0.5) {
// //                     _animationController.forward();
// //                   } else {
// //                     _animationController.reverse();
// //                   }
// //                 }
// //               },
// //               child: AnimatedBuilder(
// //                 animation: _panelAnimation,
// //                 builder: (context, child) {
// //                   final height = _panelHeightClosed +
// //                       (_panelAnimation.value * (panelHeightOpen - _panelHeightClosed));

// //                   return Container(
// //                     height: height,
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.only(
// //                         topLeft: Radius.circular(20),
// //                         topRight: Radius.circular(20),
// //                       ),
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: Colors.black26,
// //                           blurRadius: 10,
// //                           spreadRadius: 0,
// //                         ),
// //                       ],
// //                     ),
// //                     child: Column(
// //                       children: [
// //                         // Draggable handle
// //                         GestureDetector(
// //                           onTap: () => _togglePanel(),
// //                           child: Container(
// //                             width: 40,
// //                             height: 5,
// //                             margin: EdgeInsets.symmetric(vertical: 10),
// //                             decoration: BoxDecoration(
// //                               color: Colors.grey[400],
// //                               borderRadius: BorderRadius.circular(2),
// //                             ),
// //                           ),
// //                         ),

// //                         // Only show content if panel is open enough
// //                         if (_panelAnimation.value > 0.3) ...[
// //                           // Title
// //                           Padding(
// //                             padding: EdgeInsets.symmetric(horizontal: 16),
// //                             child: Text(
// //                               'Trackable Users',
// //                               style: TextStyle(
// //                                 fontSize: 18,
// //                                 fontWeight: FontWeight.bold,
// //                               ),
// //                             ),
// //                           ),

// //                           // Relations list
// //                           Expanded(
// //                             child: _isLoading
// //                                 ? Center(child: CircularProgressIndicator())
// //                                 : _errorMessage.isNotEmpty
// //                                     ? Center(child: Text(_errorMessage))
// //                                     : ListView(
// //                                         children: [
// //                                           if (trackableRelations.isNotEmpty) ...[
// //                                             ...trackableRelations.map((relation) =>
// //                                                 _buildRelationCard(
// //                                                     relation, Colors.blue, true)),
// //                                           ],
// //                                           if (trackableRelations.isEmpty)
// //                                             Center(
// //                                               child: Padding(
// //                                                 padding: EdgeInsets.all(16),
// //                                                 child: Text('No trackable users found'),
// //                                               ),
// //                                             ),
// //                                         ],
// //                                       ),
// //                           ),
// //                         ],
// //                       ],
// //                     ),
// //                   );
// //                 },
// //               ),
// //             ),
// //           ),

// //           // Map controls
// //           Positioned(
// //             top: 40,
// //             right: 16,
// //             child: Column(
// //               children: [
// //                 FloatingActionButton(
// //                   mini: true,
// //                   heroTag: 'trackAll',
// //                   onPressed: _userIdsToTrack.isNotEmpty && _requestingUserId != null
// //                       ? () => _navigateToTrackingPage(_userIdsToTrack)
// //                       : null,
// //                   child: Icon(Icons.track_changes),
// //                   tooltip: 'Track All',
// //                 ),
// //                 SizedBox(height: 8),
// //                 FloatingActionButton(
// //                   mini: true,
// //                   heroTag: 'toggleList',
// //                   onPressed: () => _togglePanel(),
// //                   child: Icon(_isPanelOpen ? Icons.map : Icons.list),
// //                   tooltip: _isPanelOpen ? 'Hide list' : 'Show list',
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // @override
// // // Widget build(BuildContext context) {
// // //   final screenHeight = MediaQuery.of(context).size.height;
// // //   final panelHeightOpen = screenHeight * _panelHeightOpen;

// // //   final trackableRelations = _relations
// // //       .where((relation) =>
// // //           (relation['activityStatus'] == 'Not Active' ||
// // //               relation['activityStatus'] == null) &&
// // //           relation['relationDirection'] == 'connected')
// // //       .toList();

// // //   return Scaffold(
// // //     body: Stack(
// // //       children: [
// // //         // Google Map
// // //         GoogleMap(
// // //           onMapCreated: (controller) => _mapController = controller,
// // //           initialCameraPosition: CameraPosition(
// // //             target: _currentLocation ?? const LatLng(28.6139, 77.2090),
// // //             zoom: 12,
// // //           ),
// // //           markers: _markers,
// // //           myLocationEnabled: true,
// // //           myLocationButtonEnabled: false,
// // //         ),

// // //         // Sliding panel
// // //         Positioned(
// // //           bottom: 0,
// // //           left: 0,
// // //           right: 0,
// // //           child: GestureDetector(
// // //             behavior: HitTestBehavior.opaque,
// // //             onVerticalDragUpdate: (details) {
// // //               // Calculate drag direction and update panel position
// // //               final newHeight = (_panelHeightClosed - details.primaryDelta!).clamp(
// // //                 _panelHeightClosed,
// // //                 panelHeightOpen
// // //               );
// // //               final fraction = 1 - (newHeight - _panelHeightClosed) / (panelHeightOpen - _panelHeightClosed);
// // //               _animationController.value = fraction;
// // //             },
// // //             onVerticalDragEnd: (details) {
// // //               // Determine if user swiped up or down
// // //               if (details.primaryVelocity! < -500) {
// // //                 // Fast swipe up - open panel
// // //                 _animationController.forward();
// // //               } else if (details.primaryVelocity! > 500) {
// // //                 // Fast swipe down - close panel
// // //                 _animationController.reverse();
// // //               } else {
// // //                 // No fast swipe - check position
// // //                 if (_animationController.value > 0.5) {
// // //                   _animationController.forward();
// // //                 } else {
// // //                   _animationController.reverse();
// // //                 }
// // //               }
// // //             },
// // //             child: AnimatedBuilder(
// // //               animation: _panelAnimation,
// // //               builder: (context, child) {
// // //                 final height = _panelHeightClosed +
// // //                     (_panelAnimation.value * (panelHeightOpen - _panelHeightClosed));

// // //                 return Container(
// // //                   height: height,
// // //                   decoration: BoxDecoration(
// // //                     color: Colors.white,
// // //                     borderRadius: BorderRadius.only(
// // //                       topLeft: Radius.circular(20),
// // //                       topRight: Radius.circular(20),
// // //                     ),
// // //                     boxShadow: [
// // //                       BoxShadow(
// // //                         color: Colors.black26,
// // //                         blurRadius: 10,
// // //                         spreadRadius: 0,
// // //                       ),
// // //                     ],
// // //                   ),
// // //                   child: Column(
// // //                     children: [
// // //                       // Draggable handle (now acts as gesture detector)
// // //                       Container(
// // //                         width: double.infinity,
// // //                         height: 30,  // Increased height for better touch area
// // //                         alignment: Alignment.center,
// // //                         child: Container(
// // //                           width: 40,
// // //                           height: 5,
// // //                           margin: EdgeInsets.symmetric(vertical: 10),
// // //                           decoration: BoxDecoration(
// // //                             color: Colors.grey[400],
// // //                             borderRadius: BorderRadius.circular(2),
// // //                           ),
// // //                         ),
// // //                       ),

// // //                       // Only show content if panel is open enough
// // //                       if (_panelAnimation.value > 0.3) ...[
// // //                         // Title
// // //                         Padding(
// // //                           padding: EdgeInsets.symmetric(horizontal: 16),
// // //                           child: Text(
// // //                             'Trackable Users',
// // //                             style: TextStyle(
// // //                               fontSize: 18,
// // //                               fontWeight: FontWeight.bold,
// // //                             ),
// // //                           ),
// // //                         ),

// // //                         // Relations list
// // //                         Expanded(
// // //                           child: _isLoading
// // //                               ? Center(child: CircularProgressIndicator())
// // //                               : _errorMessage.isNotEmpty
// // //                                   ? Center(child: Text(_errorMessage))
// // //                                   : ListView(
// // //                                       children: [
// // //                                         if (trackableRelations.isNotEmpty) ...[
// // //                                           ...trackableRelations.map((relation) =>
// // //                                               _buildRelationCard(
// // //                                                   relation, Colors.blue, true)),
// // //                                         ],
// // //                                         if (trackableRelations.isEmpty)
// // //                                           Center(
// // //                                             child: Padding(
// // //                                               padding: EdgeInsets.all(16),
// // //                                               child: Text('No trackable users found'),
// // //                                             ),
// // //                                           ),
// // //                                       ],
// // //                                     ),
// // //                         ),
// // //                       ],
// // //                     ],
// // //                   ),
// // //                 );
// // //               },
// // //             ),
// // //           ),
// // //         ),

// // //         // Only keep the track all button
// // //         Positioned(
// // //           top: 40,
// // //           right: 16,
// // //           child: FloatingActionButton(
// // //             mini: true,
// // //             heroTag: 'trackAll',
// // //             onPressed: _userIdsToTrack.isNotEmpty && _requestingUserId != null
// // //                 ? () => _navigateToTrackingPage(_userIdsToTrack)
// // //                 : null,
// // //             child: Icon(Icons.track_changes),
// // //             tooltip: 'Track All',
// // //           ),
// // //         ),
// // //       ],
// // //     ),
// // //   );
// // // }}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Pages/LocationHistoryPage.dart';
import 'package:Safe_pulse/Pages/locationhistory24.dart';
import 'package:Safe_pulse/other%20pages/LiveTrackingPage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserRelationsPageRaj extends StatefulWidget {
  const UserRelationsPageRaj({Key? key}) : super(key: key);

  @override
  _UserRelationsPageRajState createState() => _UserRelationsPageRajState();
}

class _UserRelationsPageRajState extends State<UserRelationsPageRaj> {
  List<dynamic> _relations = [];
  bool _isLoading = false;
  String _errorMessage = "";
  String? _requestingUserId;
  String? userIdToName;
  String? _userEmail;
  List<String> _userIdsToTrack = [];

  // Map related variables
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  LatLng? _currentLocation;
  bool _showUserList = true;
  double _panelHeight = 300;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _currentLocation = const LatLng(28.6139, 77.2090); // Default to Delhi
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _requestingUserId = prefs.getString("userId");
      _userEmail = prefs.getString("username");
    });

    if (_userEmail != null) {
      _fetchRelations();
    } else {
      setState(() {
        _errorMessage = "User email not found";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRelations() async {
    if (_userEmail == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final response = await http.get(Uri.parse(
          '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$_userEmail'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _relations = data;
          _userIdsToTrack = data
              .where((relation) =>
                  (relation['activityStatus'] == 'Not Active' ||
                      relation['activityStatus'] == null) &&
                  relation['relationDirection'] == 'connected')
              .map<String>((relation) => relation['userRelationId'].toString())
              .toList();
        });
      } else {
        setState(() {
          _errorMessage =
              "Failed to fetch relations. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching relations: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToTrackingPage(List<String> userIdsToTrack) {
    if (_requestingUserId == null || userIdsToTrack.isEmpty) return;

    Map<String, String> userIdToName = {};

    for (var relation in _relations) {
      final id = relation['userRelationId'].toString();

      final name = (relation['relationName'] ?? '').toString().isNotEmpty
          ? relation['relationName']
          : relation['otherUserEmail'];

      userIdToName[id] = name;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingPagemain(
          requestingUserId: _requestingUserId!,
          userIdsToTrack: userIdsToTrack,
          userNames: userIdToName,
        ),
      ),
    );
  }

  void _moveToHistory(String mail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationHistoryPage(
          mail: mail,
        ),
      ),
    );
  }

  void _moveTo24HourHistory(String mail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationHistoryPageWF(
          mail: mail,
        ),
      ),
    );
  }

  Widget _buildRelationCard(Map<String, dynamic> relation, bool isTrackable) {
    final relationName = relation['relationName'] ?? 'Unknown';
    final email = relation['otherUserEmail'] ?? 'Unknown email';
    final isConnected = relation['isLinked'] == 1.0;
    final color = isTrackable ? Colors.blue[800]! : Colors.green[700]!;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isTrackable
            ? () => _showUserOnMap(relation['userRelationId'].toString(),
                relation['otherUserEmail'] ?? 'User')
            : null,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _getRelationIcon(relationName),
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relationName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTrackable)
                    IconButton(
                      icon:
                          Icon(Icons.location_on, size: 20, color: Colors.blue),
                      onPressed: () => _showUserOnMap(
                          relation['userRelationId'].toString(),
                          relation['otherUserEmail'] ?? 'User'),
                    ),
                  IconButton(
                    icon: Icon(Icons.history, size: 20, color: Colors.purple),
                    onPressed: () => _moveToHistory(email),
                  ),
                  Icon(
                    isConnected ? Icons.check_circle : Icons.pending,
                    size: 20,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRelationIcon(String relationName) {
    switch (relationName.toLowerCase()) {
      case 'child':
        return Icons.child_care;
      case 'parent':
        return Icons.family_restroom;
      case 'spouse':
        return Icons.favorite;
      case 'friend':
        return Icons.people;
      default:
        return Icons.person;
    }
  }

  void _showUserOnMap(String userId, String userName) {
    if (_currentLocation == null) return;

    final newLocation = LatLng(
      _currentLocation!.latitude + (Random().nextDouble() * 0.01 - 0.005),
      _currentLocation!.longitude + (Random().nextDouble() * 0.01 - 0.005),
    );

    setState(() {
      _markers.clear();
      _markers.add(Marker(
        markerId: MarkerId(userId),
        position: newLocation,
        infoWindow: InfoWindow(title: userName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
      _currentLocation = newLocation;
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 15));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackableRelations = _relations
        .where((relation) =>
            (relation['activityStatus'] == 'Not Active' ||
                relation['activityStatus'] == null) &&
            relation['relationDirection'] == 'connected')
        .toList();

    final screenHeight = MediaQuery.of(context).size.height;
    final panelMaxHeight = screenHeight * 0.7;
    final panelMinHeight = screenHeight * 0.3;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map Background
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _currentLocation!,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Draggable Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _panelHeight -= details.primaryDelta!;
                  if (_panelHeight > panelMaxHeight)
                    _panelHeight = panelMaxHeight;
                  if (_panelHeight < panelMinHeight)
                    _panelHeight = panelMinHeight;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                height: _panelHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Panel Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Panel Header
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Trackable Connections',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          if (_userIdsToTrack.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  _navigateToTrackingPage(_userIdsToTrack),
                              child: Text(
                                'TRACK ALL',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue[800]!),
                              ),
                            )
                          : _errorMessage.isNotEmpty
                              ? Center(
                                  child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ))
                              : trackableRelations.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.group_off,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No trackable connections',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.only(bottom: 16),
                                      itemCount: trackableRelations.length,
                                      itemBuilder: (context, index) {
                                        return _buildRelationCard(
                                            trackableRelations[index], true);
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Map Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'myLocation',
                  onPressed: () {
                    if (_currentLocation != null) {
                      _mapController.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                      );
                    }
                  },
                  child: Icon(Icons.my_location, size: 20),
                  backgroundColor: Colors.white,
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'togglePanel',
                  onPressed: () {
                    setState(() {
                      _panelHeight = _panelHeight > panelMinHeight + 100
                          ? panelMinHeight
                          : panelMaxHeight;
                    });
                  },
                  child: Icon(
                    _panelHeight > panelMinHeight + 100
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 20,
                  ),
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

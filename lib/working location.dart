import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:location/location.dart';

class RealTimeLocationTracking extends StatefulWidget {
  @override
  _RealTimeLocationTrackingState createState() =>
      _RealTimeLocationTrackingState();
}

class _RealTimeLocationTrackingState extends State<RealTimeLocationTracking> {
  late GoogleMapController _mapController;
  late StompClient _stompClient;
  final Location _location = Location();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _travelPath = [];
  List<Map<String, dynamic>> pendingLocations = [];

  String? userid = "";
  String? userEmail = "";
  @override
  void initState() {
    super.initState();
    getuserid().then((_) {
      _connectWebSocket();
      _initializeLocation();
    });
  }

  Future<void> getuserid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userid = prefs.getString("userId");
      userEmail = prefs.getString("username");
    });
  }

  void _connectWebSocket() {
    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url:
            '${ApiService.baseUrl}/ws-location', // Replace with your backend URL
        onConnect: _onWebSocketConnected,
        onDisconnect: (frame) => print("Disconnected"),
        onWebSocketError: (dynamic error) => print("Error: $error"),
      ),
    );
    _stompClient.activate();
  }

  void _onWebSocketConnected(StompFrame frame) {
    _stompClient.subscribe(
      destination: '/topic/location-updates',
      callback: (StompFrame frame) {
        print("grdfgfdhjfjgfg ${jsonDecode(frame.body!)}");
        if (frame.body != null) {
          final locationData = jsonDecode(frame.body!);
          final user = locationData['user'];
          final latitude = locationData['latitude'];
          final longitude = locationData['longitude'];

          print("HMMMMMMMMMMMMM$locationData");

          // Check if this update is for the current user
          if (user != null) {
            final userId = user['userId'];

            if (userId != userid) {
              _updateOtherUserLocation(userId, latitude, longitude);
            }
          }
        }
      },
    );
  }

  void _updateOtherUserLocation(String userId, double lat, double lng) {
    final markerId = MarkerId(userId);

    setState(() {
      _markers.removeWhere((m) => m.markerId == markerId);

      _markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: "User $userId"),
        ),
      );
    });
  }

  void _initializeLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        final latLng = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );

        // ✅ SHOW YOUR LOCATION instantly
        _updateMap(latLng);

        // ✅ SEND to backend
        _sendLocation(locationData.latitude!, locationData.longitude!);
      }
    });
  }

  void _sendLocation(double latitude, double longitude) {
    print("FDGHFHJGJGHKJHK ${latitude},${longitude}");
    final location = {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': userid,
    };

   try{

    _stompClient.send(
      destination: '/app/update-location',
      body: jsonEncode(location),
    );
   }catch(e){
    pendingLocations.add(location);

   }
  }

  void _retryPending() {
    for (var loc in pendingLocations) {
      _stompClient.send(
        destination: '/app/update-location',
        body: jsonEncode(loc),
      );
    }
    pendingLocations.clear();
  }

  void _updateMap(LatLng newLocation) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == "me");

      _markers.add(
        Marker(
          markerId: MarkerId("me"),
          position: newLocation,
          infoWindow: InfoWindow(title: 'You'),
        ),
      );

      _travelPath.add(newLocation);

      _polylines.add(
        Polyline(
          polylineId: PolylineId('travelPath'),
          points: _travelPath,
          color: Colors.red,
          width: 5,
        ),
      );

      _mapController.animateCamera(
        CameraUpdate.newLatLng(newLocation),
      );
    });
  }

  @override
  void dispose() {
    _stompClient.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Real-Time Location Tracking'),
      ),
      body: GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target:
              LatLng(28.5892, 77.3176), // Initial map center (Noida Sector 6)
          zoom: 13,
        ),
        markers: _markers,
        polylines: _polylines,
      ),
    );
  }
}

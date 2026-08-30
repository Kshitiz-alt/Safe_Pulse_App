import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:Safe_pulse/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationHistoryPageWF extends StatefulWidget {
  final String mail;

  LocationHistoryPageWF({required this.mail});
  @override
  _LocationHistoryPageWFState createState() => _LocationHistoryPageWFState();
}

class _LocationHistoryPageWFState extends State<LocationHistoryPageWF> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  final List<LatLng> _travelPath = [];

  double _scrubValue = 0; // 0.0 → 1.0
  List<LatLng> _scrubPoints = [];

  DateTime _selectedDate = DateTime.now();
  String? _fromEmail;
  String? _toEmail;
  bool _isLoading = false;
  double _totalDistance = 0.0;
  final Map<LatLng, Duration> _timeSpentAtLocations = {};
  final List<Map<String, dynamic>> _locationZones = [];
  BitmapDescriptor? _arrowIcon;
  BitmapDescriptor? _redMarkerIcon;
  BitmapDescriptor? _greenMarkerIcon;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime? _tripStartTime;
  DateTime? _tripEndTime;
  // bool _isMapExpanded = false;

  DateTime _parseServerTimestamp(dynamic ts) {
    if (ts is String) {
      return DateTime.parse(ts).toLocal();
    } else if (ts is num) {
      // convert seconds → milliseconds
      return DateTime.fromMillisecondsSinceEpoch(
        (ts * 1000).toInt(),
        isUtc: true,
      ).toLocal();
    } else {
      throw Exception("Invalid timestamp type: ${ts.runtimeType}");
    }
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _createCustomIcons();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _createCustomIcons() async {
    final Uint8List arrowIcon = await getBytesFromAsset('assets/arrow.png', 20);
    final Uint8List redMarker =
        await getBytesFromAsset('assets/red_marker.png', 90);
    final Uint8List greenMarker =
        await getBytesFromAsset('assets/green_marker.png', 90);

    setState(() {
      _arrowIcon = BitmapDescriptor.bytes(arrowIcon);
      _redMarkerIcon = BitmapDescriptor.bytes(redMarker);
      _greenMarkerIcon = BitmapDescriptor.bytes(greenMarker);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fromEmail = prefs.getString('username');
      print("fdgfdghhfhfg $_fromEmail");
      _toEmail = widget.mail;
    });
    _fetchLocationHistory();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchLocationHistory();
    }
  }

  // Add this to your state class variables
  String _selectedTimeRange = '2 hours';
  final List<String> _timeRanges = [
    '2 hours',
    '6 hours',
    '12 hours',
    '24 hours'
  ];

  // Replace your _fetchLocationHistory function with this:
  Future<void> _fetchLocationHistory() async {
    if (_fromEmail == null || _toEmail == null) return;

    setState(() {
      _isLoading = true;
      _markers.clear();
      _polylines.clear();
      _circles.clear();
      _travelPath.clear();
      _totalDistance = 0.0;
      _timeSpentAtLocations.clear();
      _locationZones.clear();
      _currentPage = 0;
      _tripStartTime = null;
      _tripEndTime = null;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

// STEP 1: decide end time
      // DateTime endDateTime;

      DateTime startTime;
      DateTime endDateTime;

      final isToday = _selectedDate.year == DateTime.now().year &&
          _selectedDate.month == DateTime.now().month &&
          _selectedDate.day == DateTime.now().day;

      if (isToday) {
        endDateTime = DateTime.now();
        switch (_selectedTimeRange) {
          case '6 hours':
            startTime = endDateTime.subtract(Duration(hours: 6));
            break;
          case '12 hours':
            startTime = endDateTime.subtract(Duration(hours: 12));
            break;
          case '24 hours':
            startTime = endDateTime.subtract(Duration(hours: 24));
            break;
          default:
            startTime = endDateTime.subtract(Duration(hours: 2));
        }
      } else {
        // Past date: always show the FULL day, ignore the hour-range dropdown
        startTime = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, 0, 0, 0);
        endDateTime = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, 23, 59, 59);
      }

// STEP 4: format
      final formattedStartTime = DateFormat('HH:mm:ss').format(startTime);
      final currentTime = DateFormat('HH:mm:ss').format(endDateTime);

      print("ACTUAL DATA TIME SHOULD BE BETWEEN:");
      print("$formattedDate $formattedStartTime → $formattedDate $currentTime");

      print("START: $formattedStartTime");
      print("END: $currentTime");
      print("DATE: $formattedDate");
      print(
          'gdsgdfhgdfhdfjfdjfgj ${ApiService.baseUrl}/api/relationships/get-data-by-time-range'
          '?fromEmail=${Uri.encodeComponent(_fromEmail!)}'
          '&toEmail=${Uri.encodeComponent(_toEmail!)}'
          '&date=$formattedDate'
          '&startTime=${Uri.encodeComponent(formattedStartTime)}'
          '&endTime=${Uri.encodeComponent(currentTime)}');
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/relationships/get-data-by-time-range'
          '?fromEmail=${Uri.encodeComponent(_fromEmail!)}'
          '&toEmail=${Uri.encodeComponent(_toEmail!)}'
          '&date=$formattedDate'
          '&startTime=${Uri.encodeComponent(formattedStartTime)}'
          '&endTime=${Uri.encodeComponent(currentTime)}');

      final response = await http.get(url);
      print("URL: $url");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final locations = _prepareLocations(json.decode(response.body));
        if (locations.isNotEmpty) {
          _processLocationData(locations);
          _updateMapWithHistory(locations);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No location data available for selected date')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load location history')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _prepareLocations(dynamic responseBody) {
    if (responseBody is! List) return <dynamic>[];

    final locations = responseBody.where((location) {
      if (location is! Map) return false;

      final latitude = location['latitude'];
      final longitude = location['longitude'];
      return latitude is num &&
          longitude is num &&
          latitude.toDouble().isFinite &&
          longitude.toDouble().isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList();

    locations.sort((a, b) => _parseServerTimestamp(a['timestamp'])
        .compareTo(_parseServerTimestamp(b['timestamp'])));

    return locations;
  }

  List<LatLng> smoothPath(List<LatLng> points) {
    if (points.length < 3) return points;

    List<LatLng> smooth = [];
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final avgLat = (prev.latitude + curr.latitude + next.latitude) / 3;
      final avgLng = (prev.longitude + curr.longitude + next.longitude) / 3;

      smooth.add(LatLng(avgLat, avgLng));
    }

    return smooth;
  }

  // Future<void> _fetchLocationHistory() async {
  //   if (_fromEmail == null || _toEmail == null) return;

  //   setState(() {
  //     _isLoading = true;
  //     _markers.clear();
  //     _polylines.clear();
  //     _circles.clear();
  //     _travelPath.clear();
  //     _totalDistance = 0.0;
  //     _timeSpentAtLocations.clear();
  //     _locationZones.clear();
  //     _currentPage = 0;
  //   });

  //   try {
  //     final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
  //     final url = Uri.parse(
  //         '${ApiService.baseUrl}/api/relationships/get-data-without-filter?fromEmail=${Uri.encodeComponent(_fromEmail!)}&toEmail=${Uri.encodeComponent(_toEmail!)}&date=$formattedDate');

  //     final response = await http.get(url);

  //     if (response.statusCode == 200) {
  //       print("bvfdhngfjhhgjkhghgjk  fil ${response.body}");
  //       final List<dynamic> locations = json.decode(response.body);
  //       // locations.sort((a, b) => DateTime.parse(a['timestamp'])
  //       //     .compareTo(DateTime.parse(b['timestamp'])));
  //       if (locations.isNotEmpty) {
  //         _processLocationData(locations);
  //         _updateMapWithHistory(locations);
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //               content: Text('No location data available for selected date')),
  //         );
  //       }
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to load location history')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error: ${e.toString()}')),
  //     );
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  void _processLocationData(List<dynamic> locations) {
    for (int i = 1; i < locations.length; i++) {
      final lat1 = (locations[i - 1]['latitude'] as num).toDouble();
      final lon1 = (locations[i - 1]['longitude'] as num).toDouble();
      final lat2 = (locations[i]['latitude'] as num).toDouble();
      final lon2 = (locations[i]['longitude'] as num).toDouble();
      _totalDistance += _calculateDistance(lat1, lon1, lat2, lon2);
    }

    final List<List<dynamic>> locationGroups = [];
    List<dynamic> currentGroup = [locations.first];

    for (int i = 1; i < locations.length; i++) {
      final lastInGroup = currentGroup.last;
      final current = locations[i];
      final distance = _calculateDistance(
        (lastInGroup['latitude'] as num).toDouble(),
        (lastInGroup['longitude'] as num).toDouble(),
        (current['latitude'] as num).toDouble(),
        (current['longitude'] as num).toDouble(),
      );

      if (distance <= 30)
        currentGroup.add(current);
      else {
        locationGroups.add(currentGroup);
        currentGroup = [current];
      }
    }
    locationGroups.add(currentGroup);

    for (final group in locationGroups) {
      if (group.length > 1) {
        final firstTime = _parseServerTimestamp(group.first['timestamp']);
        final lastTime = _parseServerTimestamp(group.last['timestamp']);
        final duration = lastTime.difference(firstTime);
        final avgLat = group
                .map((e) => (e['latitude'] as num).toDouble())
                .reduce((a, b) => a + b) /
            group.length;
        final avgLon = group
                .map((e) => (e['longitude'] as num).toDouble())
                .reduce((a, b) => a + b) /
            group.length;
        _timeSpentAtLocations[LatLng(avgLat, avgLon)] = duration;
      }
    }

    final significantLocations = _timeSpentAtLocations.entries
        .where((entry) => entry.value.inMinutes >= 1)
        .toList();

    for (final entry in significantLocations) {
      final matchingLocation = locations.firstWhere(
        (loc) =>
            _calculateDistance(
              loc['latitude'],
              loc['longitude'],
              entry.key.latitude,
              entry.key.longitude,
            ) <=
            30,
        orElse: () => locations.first,
      );

      _locationZones.add({
        'position': entry.key,
        'duration': entry.value,
        'radius': 30.0,
        'timestamp': DateFormat('HH:mm:ss').format(
          _parseServerTimestamp(matchingLocation['timestamp']),
        ),
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  void _updateMapWithHistory(List<dynamic> locations) {
    final rawPoints = locations
        .map((loc) => LatLng(
              (loc['latitude'] as num).toDouble(),
              (loc['longitude'] as num).toDouble(),
            ))
        .toList();

    final points = rawPoints;
    _buildScrubPath(points);
    print("========== HISTORY MAP ==========");
    print("locations: ${locations.length}");

    for (final loc in locations.take(5)) {
      print("LAT=${loc['latitude']} "
          "LNG=${loc['longitude']} "
          "TIME=${loc['timestamp']}");
    }
    print("=================================");

    setState(() {
      if (locations.isNotEmpty) {
        _tripStartTime = _parseServerTimestamp(locations.first['timestamp']);
        _tripEndTime = _parseServerTimestamp(locations.last['timestamp']);
      }
      if (points.isNotEmpty &&
          _redMarkerIcon != null &&
          _greenMarkerIcon != null) {
        // Start Marker
        _markers.add(Marker(
          markerId: MarkerId('start'),
          position: offset(points.first, -0.00005, -0.00005),
          icon: _greenMarkerIcon!,
          infoWindow: InfoWindow(
            title: 'Start Point',
            snippet:
                'Time: ${DateFormat('HH:mm:ss').format(_parseServerTimestamp(locations.first['timestamp']))}',
          ),
        ));

// End Marker
        _markers.add(Marker(
          markerId: MarkerId('end'),
          position: offset(points.last, 0.00005, 0.00005),
          icon: _redMarkerIcon!,
          infoWindow: InfoWindow(
            title: 'End Point',
            snippet:
                'Time: ${DateFormat('HH:mm:ss').format(_parseServerTimestamp(locations.last['timestamp']))}',
          ),
        ));

        // Direction Arrows
        if (_arrowIcon != null) {
          for (int i = 1; i < points.length; i += 5) {
            final point1 = points[i - 1];
            final point2 = points[i];
            final midpoint = LatLng(
              (point1.latitude + point2.latitude) / 2,
              (point1.longitude + point2.longitude) / 2,
            );

            _markers.add(Marker(
              markerId: MarkerId('arrow_$i'),
              position: midpoint,
              rotation: _calculateBearing(
                point1.latitude,
                point1.longitude,
                point2.latitude,
                point2.longitude,
              ),
              icon: _arrowIcon!,
              anchor: Offset(0.5, 0.5),
            ));
          }
        }

        // Zone Markers
        for (int i = 0; i < _locationZones.length; i++) {
          final zone = _locationZones[i];
          final position = zone['position'] as LatLng;

          _markers.add(Marker(
            markerId:
                MarkerId('zone_${position.latitude}_${position.longitude}'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Stop ${i + 1}',
              snippet:
                  'Duration: ${_formatDuration(zone['duration'])}\nTime: ${zone['timestamp']}',
            ),
          ));

          _circles.add(Circle(
            circleId:
                CircleId('circle_${position.latitude}_${position.longitude}'),
            center: position,
            radius: zone['radius'],
            strokeWidth: 1,
            strokeColor: Colors.orange,
            fillColor: Colors.orange.withOpacity(0.15),
          ));
        }
      }

      _polylines.add(Polyline(
        polylineId: PolylineId('historyPath'),
        points: points,
        color: Colors.blueAccent,
        width: 4,
        geodesic: true,
      ));

      _travelPath.addAll(points);
    });

    if (_travelPath.isNotEmpty) {
      _adjustCameraToFitPath();
    }
  }

  void _buildScrubPath(List<LatLng> points) {
    _scrubPoints.clear();

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];

      final steps = 5; // controls smoothness (increase = smoother)

      for (int j = 0; j < steps; j++) {
        final t = j / steps;

        final lat = start.latitude + (end.latitude - start.latitude) * t;
        final lng = start.longitude + (end.longitude - start.longitude) * t;

        _scrubPoints.add(LatLng(lat, lng));
      }
    }

    _scrubPoints.add(points.last);
  }

  void _updateScrubMap() {
    if (_scrubPoints.isEmpty) return;

    final pos = _currentScrubPosition;

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == "scrub");

      _markers.add(
        Marker(
          markerId: const MarkerId("scrub"),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });

    _mapController.animateCamera(
      CameraUpdate.newLatLng(pos),
    );
  }

  LatLng get _currentScrubPosition {
    if (_scrubPoints.isEmpty) return const LatLng(0, 0);

    final index = (_scrubValue * (_scrubPoints.length - 1)).round();
    return _scrubPoints[index.clamp(0, _scrubPoints.length - 1)];
  }

  LatLng offset(LatLng p, double dx, double dy) {
    return LatLng(p.latitude + dx, p.longitude + dy);
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * pi / 180;
    final lon1Rad = lon1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    final lon2Rad = lon2 * pi / 180;

    final y = sin(lon2Rad - lon1Rad) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(lon2Rad - lon1Rad);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _adjustCameraToFitPath() {
    if (_travelPath.isEmpty) return;

    if (_travelPath.length == 1) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_travelPath.first, 18),
      );
      return;
    }

    final bounds = _boundsFromLatLngList(_travelPath);

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      x0 = x0 == null ? latLng.latitude : min(x0, latLng.latitude);
      x1 = x1 == null ? latLng.latitude : max(x1, latLng.latitude);
      y0 = y0 == null ? latLng.longitude : min(y0, latLng.longitude);
      y1 = y1 == null ? latLng.longitude : max(y1, latLng.longitude);
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  // void _toggleMapSize() {
  //   setState(() => _isMapExpanded = !_isMapExpanded);
  //   if (_isMapExpanded) {
  //     _scrollController.animateTo(0,
  //         duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
  //   }
  // }

  List<LatLng> reducePoints(List<LatLng> points) {
    List<LatLng> result = [];

    for (int i = 0; i < points.length; i++) {
      if (i == 0 || i == points.length - 1) {
        result.add(points[i]);
        continue;
      }

      final prev = points[i - 1];
      final curr = points[i];

      final distance = _calculateDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      if (distance > 2) {
        // tweak this value
        result.add(curr);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// 🗺️ FULL MAP
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(28.5892, 77.3176),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            myLocationEnabled: true,
          ),

          /// 🔝 TOP CONTROLS (GLASS UI)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildTopControls(),
          ),

          /// ⏳ LOADER
          if (_isLoading) Center(child: CircularProgressIndicator()),

          /// 👇 TIMELINE PANEL
          _buildBottomTimeline(),

          /// 🎯 FLOATING BUTTONS
          Positioned(
            bottom: 140,
            right: 16,
            child: Column(
              children: [
                _buildFAB(Icons.refresh, _fetchLocationHistory),
                SizedBox(height: 10),
                _buildFAB(Icons.zoom_out_map, _adjustCameraToFitPath),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSummaryInfo() {
  //   return Padding(
  //     padding: EdgeInsets.all(16),
  //     child: Column(
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
  //             Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
  //           ],
  //         ),
  //         SizedBox(height: 8),
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text('Total Distance:',
  //                 style: TextStyle(fontWeight: FontWeight.bold)),
  //             Text('${(_totalDistance / 1000).toStringAsFixed(2)} km'),
  //           ],
  //         ),
  //         SizedBox(height: 8),
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text('Total Stops:',
  //                 style: TextStyle(fontWeight: FontWeight.bold)),
  //             Text('${_locationZones.length}'),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildLocationCard({
  //   required String title,
  //   required String time,
  //   required Color color,
  // }) {
  //   return Container(
  //     width: MediaQuery.of(context).size.width * 0.8,
  //     margin: EdgeInsets.symmetric(horizontal: 8),
  //     child: Card(
  //       color: color.withOpacity(0.1),
  //       child: Padding(
  //         padding: EdgeInsets.all(12),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(title,
  //                 style: TextStyle(
  //                     fontSize: 16, fontWeight: FontWeight.bold, color: color)),
  //             SizedBox(height: 8),
  //             Text('Time: $time', style: TextStyle(color: Colors.grey[700])),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildStopCard({
  //   required Duration duration,
  //   required String time,
  //   required int index,
  // }) {
  //   return Container(
  //     width: MediaQuery.of(context).size.width * 0.8,
  //     margin: EdgeInsets.symmetric(horizontal: 8),
  //     child: Card(
  //       child: Padding(
  //         padding: EdgeInsets.all(12),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text('Stop $index',
  //                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //             SizedBox(height: 8),
  //             Text('Duration: ${_formatDuration(duration)}'),
  //             Text('Time: $time'),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildTopControls() {
    final userName = (_toEmail != null) ? getNameFromEmail(_toEmail!) : "User";
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          /// 📅 DATE
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  SizedBox(width: 8),
                  Text(DateFormat('MMM d').format(_selectedDate)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          /// ⏱️ TIME RANGE
          DropdownButton<String>(
            value: _selectedTimeRange,
            underline: SizedBox(),
            onChanged: (val) {
              setState(() => _selectedTimeRange = val!);
              _fetchLocationHistory();
            },
            items: _timeRanges
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTimeline() {
    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.15,
      maxChildSize: 0.5,
      builder: (context, controller) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            children: [
              /// HANDLE
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              SizedBox(height: 12),

              /// SUMMARY
              _buildSummaryCard(),

              SizedBox(height: 12),

              /// SLIDER
              Slider(
                value: _scrubValue,
                min: 0,
                max: 1,
                divisions: 1000,
                label: "${(_scrubValue * 100).toInt()}%",
                onChanged: (v) {
                  setState(() => _scrubValue = v);
                  _updateScrubMap();
                },
              ),

              Text("Timeline", style: TextStyle(fontWeight: FontWeight.bold)),

              SizedBox(height: 10),

              /// START
              /// START
              _buildTimelineTile(
                "Start",
                Colors.green,
                _tripStartTime != null
                    ? DateFormat('HH:mm').format(_tripStartTime!)
                    : "--:--",
              ),

              /// STOPS
              ..._locationZones.map((zone) => _buildTimelineTile(
                    "Stop (${_formatDuration(zone['duration'])})",
                    Colors.orange,
                    zone['timestamp'],
                  )),

              /// END
              _buildTimelineTile(
                "End",
                Colors.red,
                _tripEndTime != null
                    ? DateFormat('HH:mm').format(_tripEndTime!)
                    : "--:--",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
              "Distance", "${(_totalDistance / 1000).toStringAsFixed(2)} km"),
          _summaryItem("Stops", "${_locationZones.length}"),
          _summaryItem("Date", DateFormat('MMM d').format(_selectedDate)),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTimelineTile(String title, Color color, String time) {
    return ListTile(
      leading: CircleAvatar(
        radius: 8,
        backgroundColor: color,
      ),
      title: Text(title),
      subtitle: Text(time),
    );
  }

  Widget _buildFAB(IconData icon, VoidCallback onTap) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.white,
      onPressed: onTap,
      child: Icon(icon, color: Colors.black),
    );
  }
}

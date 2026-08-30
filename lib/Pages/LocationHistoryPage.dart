import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationHistoryPage extends StatefulWidget {
  final String mail;

  LocationHistoryPage({required this.mail});
  @override
  _LocationHistoryPageState createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  final List<LatLng> _travelPath = [];
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
  bool _isMapExpanded = false;
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
    final Uint8List arrowIcon = await getBytesFromAsset('assets/arrow.png', 60);
    final Uint8List redMarker =
        await getBytesFromAsset('assets/red_marker.png', 200);
    final Uint8List greenMarker =
        await getBytesFromAsset('assets/green_marker.png', 200);

    setState(() {
      _arrowIcon = BitmapDescriptor.fromBytes(arrowIcon);
      _redMarkerIcon = BitmapDescriptor.fromBytes(redMarker);
      _greenMarkerIcon = BitmapDescriptor.fromBytes(greenMarker);
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
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/relationships/getToUserLocationHistory?fromEmail=${Uri.encodeComponent(_fromEmail!)}&toEmail=${Uri.encodeComponent(_toEmail!)}&date=$formattedDate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        print("bvfdhngfjhhgjkhghgjk ${response.body}");
        final List<dynamic> locations = json.decode(response.body);
        // locations.sort((a, b) => DateTime.parse(a['timestamp'])
        //     .compareTo(DateTime.parse(b['timestamp'])));
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

  void _processLocationData(List<dynamic> locations) {
    for (int i = 1; i < locations.length; i++) {
      final lat1 = locations[i - 1]['latitude'];
      final lon1 = locations[i - 1]['longitude'];
      final lat2 = locations[i]['latitude'];
      final lon2 = locations[i]['longitude'];
      _totalDistance += _calculateDistance(lat1, lon1, lat2, lon2);
    }

    final List<List<dynamic>> locationGroups = [];
    List<dynamic> currentGroup = [locations.first];

    for (int i = 1; i < locations.length; i++) {
      final lastInGroup = currentGroup.last;
      final current = locations[i];
      final distance = _calculateDistance(
        lastInGroup['latitude'],
        lastInGroup['longitude'],
        current['latitude'],
        current['longitude'],
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
        final firstTime = DateTime.parse(group.first['timestamp']);
        final lastTime = DateTime.parse(group.last['timestamp']);
        final duration = lastTime.difference(firstTime);
        final avgLat = group.map((e) => e['latitude']).reduce((a, b) => a + b) /
            group.length;
        final avgLon =
            group.map((e) => e['longitude']).reduce((a, b) => a + b) /
                group.length;
        _timeSpentAtLocations[LatLng(avgLat, avgLon)] = duration;
      }
    }

    final significantLocations = _timeSpentAtLocations.entries
        .where((entry) => entry.value.inMinutes >= 5)
        .toList();

    for (final entry in significantLocations) {
      _locationZones.add({
        'position': entry.key,
        'duration': entry.value,
        'radius': 30.0,
        'timestamp': DateFormat('HH:mm:ss').format(DateTime.parse(
            locations.firstWhere((loc) =>
                _calculateDistance(loc['latitude'], loc['longitude'],
                    entry.key.latitude, entry.key.longitude) <=
                30)['timestamp'])),
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
    final List<LatLng> points = locations
        .map((loc) => LatLng(loc['latitude'], loc['longitude']))
        .toList();

    setState(() {
      if (points.isNotEmpty &&
          _redMarkerIcon != null &&
          _greenMarkerIcon != null) {
        // Start Marker
        _markers.add(Marker(
          markerId: MarkerId('start'),
          position: points.first,
          icon: _greenMarkerIcon!,
          infoWindow: InfoWindow(
            title: 'Start Point',
            snippet: 'Time: ${locations.first['timestamp']}',
          ),
        ));

        // End Marker
        _markers.add(Marker(
          markerId: MarkerId('end'),
          position: points.last,
          icon: _redMarkerIcon!,
          infoWindow: InfoWindow(
            title: 'End Point',
            snippet: 'Time: ${locations.last['timestamp']}',
          ),
        ));

        // Direction Arrows
        if (_arrowIcon != null) {
          for (int i = 1; i < points.length; i++) {
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
            strokeWidth: 2,
            strokeColor: Colors.orange,
            fillColor: Colors.orange.withOpacity(0.2),
          ));
        }
      }

      _polylines.add(Polyline(
        polylineId: PolylineId('historyPath'),
        points: points,
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ));

      _travelPath.addAll(points);
    });

    if (_travelPath.isNotEmpty && _mapController != null) {
      _adjustCameraToFitPath();
    }
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
    final bounds = _boundsFromLatLngList(_travelPath);
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      x0 = x0 == null ? latLng.latitude : min(x0!, latLng.latitude);
      x1 = x1 == null ? latLng.latitude : max(x1!, latLng.latitude);
      y0 = y0 == null ? latLng.longitude : min(y0!, latLng.longitude);
      y1 = y1 == null ? latLng.longitude : max(y1!, latLng.longitude);
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  void _toggleMapSize() {
    setState(() => _isMapExpanded = !_isMapExpanded);
    if (_isMapExpanded) {
      _scrollController.animateTo(0,
          duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final mapHeight = _isMapExpanded ? screenHeight * 0.9 : screenHeight * 0.7;

    return Scaffold(
      appBar: AppBar(
        title: Text('Location History'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: mapHeight,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(28.5892, 77.3176),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                if (_isLoading) Center(child: CircularProgressIndicator()),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _toggleMapSize,
                    child:
                        Icon(_isMapExpanded ? Icons.minimize : Icons.maximize),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Container(
                    height: 120,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 2 + _locationZones.length,
                      itemBuilder: (context, index) {
                        if (index == 0)
                          return _buildLocationCard(
                            title: 'Start Point',
                            time: _travelPath.isNotEmpty
                                ? DateFormat('HH:mm:ss').format(_selectedDate)
                                : '--:--:--',
                            color: Colors.green,
                          );
                        if (index == 1)
                          return _buildLocationCard(
                            title: 'End Point',
                            time: _travelPath.isNotEmpty
                                ? DateFormat('HH:mm:ss').format(
                                    _selectedDate.add(Duration(
                                        minutes: _travelPath.length ~/ 5)))
                                : '--:--:--',
                            color: Colors.red,
                          );
                        final zone = _locationZones[index - 2];
                        return _buildStopCard(
                          duration: zone['duration'],
                          time: zone['timestamp'],
                          index: index - 1,
                        );
                      },
                    ),
                  ),
                  _buildSummaryInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _fetchLocationHistory,
            child: Icon(Icons.refresh),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => _adjustCameraToFitPath(),
            child: Icon(Icons.zoom_out_map),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryInfo() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Distance:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${(_totalDistance / 1000).toStringAsFixed(2)} km'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Stops:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_locationZones.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String time,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              SizedBox(height: 8),
              Text('Time: $time', style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopCard({
    required Duration duration,
    required String time,
    required int index,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stop $index',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Duration: ${_formatDuration(duration)}'),
              Text('Time: $time'),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

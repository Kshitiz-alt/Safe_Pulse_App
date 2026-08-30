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

class MultilePeoplesHistory extends StatefulWidget {
  final List<String> emailsToTrack;
  final String duration;
  final String requestingUserId;

  const MultilePeoplesHistory({
    Key? key,
    required this.emailsToTrack,
    required this.duration,
    required this.requestingUserId,
  }) : super(key: key);

  @override
  _MultilePeoplesHistoryState createState() => _MultilePeoplesHistoryState();
}

class _MultilePeoplesHistoryState extends State<MultilePeoplesHistory> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  final Map<String, List<LatLng>> _travelPaths = {};
  final Map<String, double> _totalDistances = {};
  final Map<String, Duration> _totalDurations = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  final Map<String, Color> _userColors = {};
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isMapExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeUserColors();
    _createCustomIcons();
    _fetchLocationHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initializeUserColors() {
    for (int i = 0; i < widget.emailsToTrack.length; i++) {
      _userColors[widget.emailsToTrack[i]] =
          _availableColors[i % _availableColors.length];
    }
  }

  Future<void> _createCustomIcons() async {
    for (String email in widget.emailsToTrack) {
      final color = _userColors[email]!;
      final Uint8List icon = await _getBitmapDescriptorFromColor(color, 200);
      setState(() {
        _markerIcons[email] = BitmapDescriptor.fromBytes(icon);
      });
    }
  }

  Future<Uint8List> _getBitmapDescriptorFromColor(Color color, int size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    final radius = size / 2;

    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final image = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return data!.buffer.asUint8List();
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
    if (widget.requestingUserId.isEmpty || widget.emailsToTrack.isEmpty) return;

    setState(() {
      _isLoading = true;
      _markers.clear();
      _polylines.clear();
      _circles.clear();
      _travelPaths.clear();
      _totalDistances.clear();
      _totalDurations.clear();
      _currentPage = 0;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final now = DateTime.now();
      final currentTime = DateFormat('HH:mm:ss').format(now);

      // Calculate start time based on selected duration
      DateTime startTime;
      switch (widget.duration) {
        case '6 hours':
          startTime = now.subtract(Duration(hours: 6));
          break;
        case '12 hours':
          startTime = now.subtract(Duration(hours: 12));
          break;
        case '24 hours':
          startTime = now.subtract(Duration(hours: 24));
          break;
        default: // 2 hours
          startTime = now.subtract(Duration(hours: 2));
      }

      final formattedStartTime = DateFormat('HH:mm:ss').format(startTime);
      final toEmails = widget.emailsToTrack.join(',');

      final url = Uri.parse(
          '${ApiService.baseUrl}/api/relationships/get-data-by-time-range-multiple-user'
          '?fromEmail=${Uri.encodeComponent(widget.requestingUserId)}'
          '&toEmails=${Uri.encodeComponent(toEmails)}'
          '&date=$formattedDate'
          '&startTime=${Uri.encodeComponent(formattedStartTime)}'
          '&endTime=${Uri.encodeComponent(currentTime)}');
      print(
          'gsfdgfdhfdhjdhj  ${ApiService.baseUrl}/api/relationships/get-data-by-time-range-multiple-user'
          '?fromEmail=${Uri.encodeComponent(widget.requestingUserId)}'
          '&toEmails=${Uri.encodeComponent(toEmails)}'
          '&date=$formattedDate'
          '&startTime=${Uri.encodeComponent(formattedStartTime)}'
          '&endTime=${Uri.encodeComponent(currentTime)}');
      final response = await http.get(url);
      print("fsdfgdsghfdghgf ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> locationData = json.decode(response.body);
        _processLocationData(locationData);
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

  void _processLocationData(Map<String, dynamic> locationData) {
    locationData.forEach((email, locations) {
      if (locations is List && locations.isNotEmpty) {
        final List<LatLng> points = (locations as List<dynamic>)
            .map((loc) => LatLng(loc['latitude'], loc['longitude']))
            .toList();

        _travelPaths[email] = points;

        // Calculate distance
        double distance = 0.0;
        for (int i = 1; i < points.length; i++) {
          distance += _calculateDistance(
            points[i - 1].latitude,
            points[i - 1].longitude,
            points[i].latitude,
            points[i].longitude,
          );
        }
        _totalDistances[email] = distance;

        // Calculate duration
        final firstTime = DateTime.parse(locations.first['timestamp']);
        final lastTime = DateTime.parse(locations.last['timestamp']);
        _totalDurations[email] = lastTime.difference(firstTime);

        // Add markers and polyline
        _addUserPathToMap(email, points);
      }
    });

    if (_travelPaths.isNotEmpty) {
      _adjustCameraToFitAllPaths();
    }
  }

  void _addUserPathToMap(String email, List<LatLng> points) {
    final color = _userColors[email] ?? Colors.blue;

    // Add start and end markers
    if (points.isNotEmpty && _markerIcons.containsKey(email)) {
      _markers.add(Marker(
        markerId: MarkerId('${email}_start'),
        position: points.first,
        icon: _markerIcons[email]!,
        infoWindow: InfoWindow(
          title: 'Start - $email',
          snippet: 'Time: ${_formatTime(points.first)}',
        ),
      ));

      _markers.add(Marker(
        markerId: MarkerId('${email}_end'),
        position: points.last,
        icon: _markerIcons[email]!,
        infoWindow: InfoWindow(
          title: 'End - $email',
          snippet: 'Time: ${_formatTime(points.last)}',
        ),
      ));
    }

    // Add polyline
    _polylines.add(Polyline(
      polylineId: PolylineId(email),
      points: points,
      color: color,
      width: 5,
      geodesic: true,
    ));

    setState(() {});
  }

  String _formatTime(LatLng point) {
    // This is a placeholder - in a real app you'd get the actual timestamp
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  void _adjustCameraToFitAllPaths() {
    if (_travelPaths.isEmpty) return;

    final allPoints = _travelPaths.values.expand((path) => path).toList();
    if (allPoints.isEmpty) return;

    final bounds = _boundsFromLatLngList(allPoints);
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
    final mapHeight = _isMapExpanded ? screenHeight * 0.9 : screenHeight * 0.7;

    return Scaffold(
      appBar: AppBar(
        title: Text('Location History - ${widget.duration}'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchLocationHistory,
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
                  _buildUserLegend(),
                  _buildSummaryCards(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adjustCameraToFitAllPaths(),
        child: Icon(Icons.zoom_out_map),
      ),
    );
  }

  Widget _buildUserLegend() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracked Users:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.emailsToTrack.map((email) {
                  final color = _userColors[email] ?? Colors.blue;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        email,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: widget.emailsToTrack.map((email) {
          final color = _userColors[email] ?? Colors.blue;
          final distance = _totalDistances[email] ?? 0.0;
          final duration = _totalDurations[email] ?? Duration.zero;
          final hasData = _travelPaths.containsKey(email);

          return Card(
            color: color.withOpacity(0.1),
            margin: EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        email,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (hasData) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Distance:'),
                        Text('${(distance / 1000).toStringAsFixed(2)} km'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Duration:'),
                        Text(_formatDuration(duration)),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'No location data available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
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

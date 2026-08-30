import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Safe_pulse/Api/ApiService.dart';

class ZoneHistoryPage extends StatefulWidget {
  @override
  _ZoneHistoryPageState createState() => _ZoneHistoryPageState();
}

class _ZoneHistoryPageState extends State<ZoneHistoryPage> {
  List<Map<String, dynamic>> _userZones = [];
  bool _isLoading = true;
  String? _userEmail;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString("username");
    });

    if (_userEmail != null) {
      _fetchUserZones();
    } else {
      setState(() {
        _errorMessage = "User email not found";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserZones() async {
    if (_userEmail == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final zones = await ApiService().getUserZones(_userEmail!);
      setState(() {
        _userZones = zones;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching zones: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteZone(String zoneId) async {
    if (_userEmail == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("SDfhdfhfdhdfhfdhd $zoneId $_userEmail ");
      await ApiService().deleteZoneById(zoneId, _userEmail!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zone deleted successfully')),
      );
      _fetchUserZones(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete zone: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final zoneType = zone['type']?.toString().toLowerCase() ?? 'safe';
    final isSafeZone = zoneType == 'safe';
    final sharedWith = (zone['sharedWith'] as List<dynamic>?)?.join(', ') ?? '';

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  zone['name'] ?? 'Unnamed Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSafeZone ? Colors.green : Colors.red,
                  ),
                ),
                Chip(
                  label: Text(
                    isSafeZone ? 'Safe Zone' : 'Danger Zone',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: isSafeZone ? Colors.green : Colors.red,
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Location: ${zone['latitude']}, ${zone['longitude']}'),
            Text('Radius: ${zone['radius']} meters'),
            if (sharedWith.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Shared with:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(sharedWith),
            ],
            SizedBox(height: 8),
            Text(
              'SOS Settings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (zone['sosSettings'] != null) ...[
              Row(
                children: [
                  Icon(Icons.notifications,
                      color: zone['sosSettings']['alert'] == true
                          ? Colors.green
                          : Colors.grey),
                  SizedBox(width: 8),
                  Icon(Icons.call,
                      color: zone['sosSettings']['call'] == true
                          ? Colors.green
                          : Colors.grey),
                  SizedBox(width: 8),
                  Icon(Icons.message,
                      color: zone['sosSettings']['message'] == true
                          ? Colors.green
                          : Colors.grey),
                ],
              ),
            ],
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(zone['id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String zoneId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Zone'),
        content: Text('Are you sure you want to delete this zone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteZone(zoneId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneMapPreview(Map<String, dynamic> zone) {
    final center = LatLng(
      zone['latitude'] as double,
      zone['longitude'] as double,
    );
    final radius = zone['radius'] as double;
    final isSafeZone = zone['type']?.toString().toLowerCase() == 'safe';

    return SizedBox(
      height: 200,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: center,
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId('zone-center'),
            position: center,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSafeZone
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueRed,
            ),
          ),
        },
        circles: {
          Circle(
            circleId: CircleId('zone-radius'),
            center: center,
            radius: radius,
            strokeWidth: 2,
            strokeColor: isSafeZone ? Colors.green : Colors.red,
            fillColor: isSafeZone
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Safety Zones'),
        backgroundColor: Color(0xFF5C6BC0),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchUserZones,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _userZones.isEmpty
                  ? Center(child: Text('No zones created yet'))
                  : RefreshIndicator(
                      onRefresh: _fetchUserZones,
                      child: ListView.builder(
                        itemCount: _userZones.length,
                        itemBuilder: (context, index) {
                          final zone = _userZones[index];
                          return Column(
                            children: [
                              _buildZoneMapPreview(zone),
                              _buildZoneCard(zone),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
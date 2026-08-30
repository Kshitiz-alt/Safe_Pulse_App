import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeofenceSetupPage extends StatefulWidget {
  @override
  _GeofenceSetupPageState createState() => _GeofenceSetupPageState();
}

class _GeofenceSetupPageState extends State<GeofenceSetupPage> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _geofenceCircles = {};
  double _radius = 100.0;
  String _locationType = "Home";
  bool _enableAlerts = true;
  
  // Default coordinates (example: Delhi coordinates)
  double currentLat = 28.6139;
  double currentLng = 77.2090;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Geofence Setup",
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
          
          // Map Preview
          Container(
            height: 200,
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: LatLng(currentLat, currentLng),
                zoom: 14,
              ),
              markers: _markers,
              circles: _geofenceCircles,
              myLocationEnabled: true,
            ),
          ),
          
          // Geofence Form
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                children: [
                  // Child selection dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Select Child",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "child1",
                        child: Text("Rahul Sharma"),
                      ),
                      DropdownMenuItem(
                        value: "child2",
                        child: Text("Priya Patel"),
                      ),
                    ],
                    onChanged: (value) {
                      // Handle child selection
                    },
                  ),
                  SizedBox(height: 20),
                  
                  // Location type selector
                  Text("Location Type:", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text("Home"),
                        selected: _locationType == "Home",
                        onSelected: (val) {
                          setState(() => _locationType = "Home");
                        },
                      ),
                      ChoiceChip(
                        label: Text("School"),
                        selected: _locationType == "School",
                        onSelected: (val) {
                          setState(() => _locationType = "School");
                        },
                      ),
                      ChoiceChip(
                        label: Text("Other"),
                        selected: _locationType == "Other",
                        onSelected: (val) {
                          setState(() => _locationType = "Other");
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  
                  // Radius slider
                  Text("Geofence Radius: ${_radius.round()} meters", 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_radius.round()} meters',
                    onChanged: (value) {
                      setState(() => _radius = value);
                      _updateGeofenceCircle();
                    },
                  ),
                  SizedBox(height: 20),
                  
                  // Notification settings
                  SwitchListTile(
                    title: Text("Enable Entry/Exit Alerts"),
                    value: _enableAlerts,
                    onChanged: (val) {
                      setState(() => _enableAlerts = val);
                    },
                  ),
                  SizedBox(height: 20),
                  
                  // Save button
                  ElevatedButton(
                    onPressed: _saveGeofence,
                    child: Text("Save Geofence"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateGeofenceCircle() {
    setState(() {
      _geofenceCircles.clear();
      _geofenceCircles.add(Circle(
        circleId: CircleId("current_geofence"),
        center: LatLng(currentLat, currentLng),
        radius: _radius,
        strokeWidth: 2,
        strokeColor: Colors.blue,
        fillColor: Colors.blue.withOpacity(0.2),
      ));
    });
  }

  void _saveGeofence() {
    // Implement geofence saving logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Geofence saved successfully")),
    );
  }
}
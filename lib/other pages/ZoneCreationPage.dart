import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:Safe_pulse/other%20pages/ZoneHistoryPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:Safe_pulse/Api/ApiService.dart';

/// -----------------------------------------------------------------------
/// Design tokens — shared visual language with the rest of the app
/// (see UserRelationsPage / ContactPage).
/// -----------------------------------------------------------------------
class _AppColors {
  static const primary = Color(0xFF5C6BC0);
  static const primaryDark = Color(0xFF3F4BA0);
  static const primarySoft = Color(0xFFE8EAF9);
  static const success = Color(0xFF2E9E5B);
  static const successSoft = Color(0xFFE3F6EA);
  static const danger = Color(0xFFE0433D);
  static const dangerSoft = Color(0xFFFCEAE9);
  static const surface = Colors.white;
  static const background = Color(0xFFF6F7FB);
  static const textPrimary = Color(0xFF1F2333);
  static const textSecondary = Color(0xFF7B8094);
}

class ZoneCreationPage extends StatefulWidget {
  @override
  _ZoneCreationPageState createState() => _ZoneCreationPageState();
}

class _ZoneCreationPageState extends State<ZoneCreationPage> {
  late GoogleMapController mapController;
  final Location _location = Location();
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  double _radius = 100.0;
  String _zoneType = 'SAFE';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _locationServiceEnabled = false;
  final TextEditingController _nameController = TextEditingController();
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // User connection variables
  List<dynamic> _activeConnections = [];
  List<String> _selectedUserEmails = [];
  String? _userEmail;
  String _errorMessage = "";

  // SOS options
  bool _enableSOSAlert = true;
  bool _enableCall = true;
  bool _enableNotification = true;
  bool _enableMessage = true;

  // Panel control
  bool _showDetailsPanel = true;
  final _panelScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkLocationPermission();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString("username");
    });

    if (_userEmail != null) {
      _fetchActiveConnections();
    } else {
      setState(() {
        _errorMessage = "User email not found";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchActiveConnections() async {
    if (_userEmail == null) return;

    try {
      final response = await http.get(Uri.parse(
          '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$_userEmail'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _activeConnections = data
              .where((relation) =>
                  (relation['activityStatus'] == 'Not Active' ||
                      relation['activityStatus'] == null) &&
                  relation['relationDirection'] == 'connected')
              .toList();
        });
      } else {
        setState(() {
          _errorMessage =
              "Failed to fetch connections. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching connections: $e";
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      _locationServiceEnabled = await _location.serviceEnabled();
      if (!_locationServiceEnabled) {
        _locationServiceEnabled = await _location.requestService();
        if (!_locationServiceEnabled) {
          throw Exception('Location services disabled');
        }
      }

      var permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          throw Exception('Location permissions denied');
        }
      }

      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _selectedLocation = _currentLocation;
        _isLoading = false;
        _updateMarkerAndCircle();
      });

      _location.onLocationChanged.listen((LocationData currentLocation) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Location error: $e";
        _isLoading = false;
      });
    }
  }

  void _updateMarkerAndCircle() {
    if (_selectedLocation == null) return;

    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId('selected-location'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(title: 'Selected Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _zoneType == 'SAFE' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
        ),
      };

      _circles = {
        Circle(
          circleId: CircleId('zone-radius'),
          center: _selectedLocation!,
          radius: _radius,
          strokeWidth: 2,
          strokeColor: _zoneType == 'SAFE' ? _AppColors.success : _AppColors.danger,
          fillColor: (_zoneType == 'SAFE' ? _AppColors.success : _AppColors.danger)
              .withOpacity(0.15),
        ),
      };
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_selectedLocation != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 15));
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarkerAndCircle();
    });
    // Give the user a moment to see the pin move before the panel comes
    // back up, but don't fight them if they intentionally hid it.
    if (!_showDetailsPanel) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _showDetailsPanel = true);
      });
    }
  }

  Future<void> _saveZone() async {
    if (_selectedLocation == null || _nameController.text.trim().isEmpty) {
      _showSnack('Please select a location and name your zone', isError: true);
      return;
    }

    if (_selectedUserEmails.isEmpty) {
      _showSnack('Select at least one person to share this zone with', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final zoneData = {
        'name': _nameController.text.trim(),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'radius': _radius,
        'type': _zoneType,
        'createdBy': _userEmail,
        'sharedWith': _selectedUserEmails,
        'sosSettings': {
          'alert': _enableSOSAlert,
          'call': _enableCall,
          'notification': _enableNotification,
          'message': _enableMessage,
        }
      };

      await ApiService().createSafeZone(zoneData);

      _showSnack('Zone created successfully!');
      // Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error creating zone: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _AppColors.danger : _AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Panel sections
  // ---------------------------------------------------------------------
  Widget _sectionLabel(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _AppColors.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: _AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Zone name',
        hintText: 'e.g. Home, School, Grandma\'s house',
        prefixIcon: const Icon(Icons.label_outline_rounded, color: _AppColors.primary),
        filled: true,
        fillColor: _AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildZoneTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _zoneTypeCard(
            label: 'Safe Zone',
            subtitle: 'Alert when leaving',
            icon: Icons.verified_user_rounded,
            color: _AppColors.success,
            selected: _zoneType == 'SAFE',
            onTap: () => setState(() {
              _zoneType = 'SAFE';
              _updateMarkerAndCircle();
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _zoneTypeCard(
            label: 'Danger Zone',
            subtitle: 'Alert when entering',
            icon: Icons.warning_amber_rounded,
            color: _AppColors.danger,
            selected: _zoneType == 'DANGER',
            onTap: () => setState(() {
              _zoneType = 'DANGER';
              _updateMarkerAndCircle();
            }),
          ),
        ),
      ],
    );
  }

  Widget _zoneTypeCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : _AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.6),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: selected ? color : _AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: _AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusSlider() {
    final radiusLabel = _radius >= 1000
        ? '${(_radius / 1000).toStringAsFixed(1)} km'
        : '${_radius.round()} m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('ZONE RADIUS', icon: Icons.radar_rounded),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                radiusLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _AppColors.primary,
            inactiveTrackColor: _AppColors.primarySoft,
            thumbColor: _AppColors.primary,
            overlayColor: _AppColors.primary.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: _radius,
            min: 50,
            max: 1000,
            divisions: 19,
            onChanged: (value) {
              setState(() {
                _radius = value;
                _updateMarkerAndCircle();
              });
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('50 m', style: TextStyle(fontSize: 11, color: _AppColors.textSecondary)),
              Text('1 km', style: TextStyle(fontSize: 11, color: _AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserSelection() {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          title: Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 18, color: _AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share with',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedUserEmails.isEmpty
                      ? Colors.grey.shade200
                      : _AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedUserEmails.length} selected',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _selectedUserEmails.isEmpty
                        ? _AppColors.textSecondary
                        : _AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          children: _activeConnections.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Text(
                      'No active connections found. Add and connect with someone first.',
                      style: TextStyle(color: _AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ]
              : _activeConnections.map((connection) {
                  final email = connection['otherUserEmail'].toString();
                  final name = connection['relationName']?.toString() ?? email;
                  final selected = _selectedUserEmails.contains(email);
                  return CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    secondary: CircleAvatar(
                      radius: 16,
                      backgroundColor: _AppColors.primarySoft,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: _AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                    value: selected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedUserEmails.add(email);
                        } else {
                          _selectedUserEmails.remove(email);
                        }
                      });
                    },
                  );
                }).toList(),
        ),
      ),
    );
  }

  Widget _buildSOSOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active_rounded, size: 18, color: _AppColors.primary),
              SizedBox(width: 8),
              Text('When this zone is triggered', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          _sosSwitch('Send SOS alert', Icons.campaign_rounded, _enableSOSAlert,
              (v) => setState(() => _enableSOSAlert = v)),
          _sosSwitch('Place emergency call', Icons.call_rounded, _enableCall,
              (v) => setState(() => _enableCall = v)),
          _sosSwitch('Send push notification', Icons.notifications_rounded, _enableNotification,
              (v) => setState(() => _enableNotification = v)),
          _sosSwitch('Send text message', Icons.sms_rounded, _enableMessage,
              (v) => setState(() => _enableMessage = v)),
        ],
      ),
    );
  }

  Widget _sosSwitch(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: _AppColors.primary,
      secondary: Icon(icon, size: 19, color: _AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveZone,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(_isSaving ? 'Saving…' : 'Save Zone',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primary,
          disabledBackgroundColor: _AppColors.primary.withOpacity(0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _showDetailsPanel ? 0 : -520,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 6) {
            setState(() => _showDetailsPanel = false);
          } else if (details.primaryDelta! < -6) {
            setState(() => _showDetailsPanel = true);
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 38,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _panelScrollController,
                      child: SingleChildScrollView(
                        controller: _panelScrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add_location_alt_rounded,
                                      color: _AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'New Safety Zone',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.only(left: 42),
                              child: Text(
                                'Tap the map to place your zone, then fine-tune it below',
                                style: TextStyle(fontSize: 12.5, color: _AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildNameField(),
                            const SizedBox(height: 18),
                            _sectionLabel('ZONE TYPE'),
                            _buildZoneTypeSelector(),
                            const SizedBox(height: 18),
                            _buildRadiusSlider(),
                            const SizedBox(height: 18),
                            _buildUserSelection(),
                            const SizedBox(height: 14),
                            _buildSOSOptions(),
                            const SizedBox(height: 20),
                            _buildSaveButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Map overlay controls
  // ---------------------------------------------------------------------
  Widget _buildMapFab({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: _AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildPeekHandle() {
    return Positioned(
      bottom: 14,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _showDetailsPanel = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: _AppColors.primary),
                SizedBox(width: 4),
                Text('Zone details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        title: const Text('Create Safety Zone', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: _AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Zone history',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ZoneHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_selectedLocation != null)
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _selectedLocation!, zoom: 15),
              onTap: _onMapTapped,
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _AppColors.primary),
                  SizedBox(height: 12),
                  Text('Finding your location…', style: TextStyle(color: _AppColors.textSecondary)),
                ],
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_rounded, color: _AppColors.textSecondary, size: 40),
                    const SizedBox(height: 12),
                    const Text('Couldn\'t get your location', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(_errorMessage, style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _checkLocationPermission();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Map controls (top-right, above the panel)
          if (_selectedLocation != null)
            Positioned(
              right: 14,
              top: 14,
              child: Column(
                children: [
                  _buildMapFab(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Center on my location',
                    onPressed: () {
                      if (_currentLocation != null) {
                        setState(() {
                          _selectedLocation = _currentLocation;
                          _updateMarkerAndCircle();
                        });
                        mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
                      }
                    },
                  ),
                ],
              ),
            ),

          if (!_showDetailsPanel && _selectedLocation != null) _buildPeekHandle(),

          if (_selectedLocation != null) _buildDetailsPanel(),

          if (_errorMessage.isNotEmpty && _selectedLocation != null)
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_rounded, color: _AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage, style: const TextStyle(color: _AppColors.danger, fontSize: 13)),
                    ),
                    InkWell(
                      onTap: () => setState(() => _errorMessage = ""),
                      child: const Icon(Icons.close_rounded, size: 18, color: _AppColors.danger),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }
}
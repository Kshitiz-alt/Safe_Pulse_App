import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:Safe_pulse/Pages/LinkUserPage.dart';
import 'package:Safe_pulse/Pages/locationhistory24.dart';
import 'package:Safe_pulse/services/permission_helper.dart';
import 'package:Safe_pulse/utils/utils.dart';

/// -----------------------------------------------------------------------
/// Design tokens
/// -----------------------------------------------------------------------
class _AppColors {
  static const primary = Color(0xFF5C6BC0);
  static const primaryDark = Color(0xFF3F4BA0);
  static const primarySoft = Color(0xFFE8EAF9);
  static const success = Color(0xFF2E9E5B);
  static const successSoft = Color(0xFFE3F6EA);
  static const warning = Color(0xFFE8912D);
  static const warningSoft = Color(0xFFFCEFDD);
  static const danger = Color(0xFFE0433D);
  static const dangerSoft = Color(0xFFFCEAE9);
  static const surface = Colors.white;
  static const background = Color(0xFFF6F7FB);
  static const textPrimary = Color(0xFF1F2333);
  static const textSecondary = Color(0xFF7B8094);
}

class _Gap {
  static const xs = SizedBox(height: 4, width: 4);
  static const sm = SizedBox(height: 8, width: 8);
  static const md = SizedBox(height: 16, width: 16);
  static const lg = SizedBox(height: 24, width: 24);
}

class _FootprintIconFactory {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> get(
    Color color, {
    required bool isLeft,
  }) async {
    final key = '${color.value}_$isLeft';
    if (_cache.containsKey(key)) return _cache[key]!;

    const width = 60.0;
    const height = 100.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final paint = Paint()..color = color.withOpacity(0.85);

    // Mirror horizontally for the right foot so the arch curves the other way
    canvas.save();
    if (!isLeft) {
      canvas.translate(width, 0);
      canvas.scale(-1, 1);
    }

    // Sole (heel narrow, forefoot wider) using a tapered oval path
    final sole = Path()
      ..moveTo(width * 0.5, height * 0.98)
      ..cubicTo(
        width * 0.1,
        height * 0.85,
        width * 0.15,
        height * 0.45,
        width * 0.35,
        height * 0.32,
      )
      ..cubicTo(
        width * 0.15,
        height * 0.22,
        width * 0.2,
        height * 0.02,
        width * 0.5,
        height * 0.02,
      )
      ..cubicTo(
        width * 0.8,
        height * 0.02,
        width * 0.85,
        height * 0.22,
        width * 0.65,
        height * 0.32,
      )
      ..cubicTo(
        width * 0.85,
        height * 0.45,
        width * 0.9,
        height * 0.85,
        width * 0.5,
        height * 0.98,
      )
      ..close();
    canvas.drawPath(sole, paint);

    // Toe cluster — 5 small circles arced across the top
    final toeCenters = [
      Offset(width * 0.20, height * 0.10),
      Offset(width * 0.36, height * 0.02),
      Offset(width * 0.52, height * -0.02),
      Offset(width * 0.68, height * 0.02),
      Offset(width * 0.82, height * 0.12),
    ];
    final toeRadii = [5.0, 6.5, 7.0, 6.0, 4.5];
    for (var i = 0; i < toeCenters.length; i++) {
      canvas.drawCircle(toeCenters[i], toeRadii[i], paint);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
    );

    _cache[key] = descriptor;
    return descriptor;
  }
}

/// A Life360-style home screen: the map is always the base layer, and the
/// list of connections lives in a draggable bottom sheet. Tapping "track"
/// on a connection doesn't navigate anywhere — it just starts pulling that
/// person's live location and focuses the camera on them.
class UserRelationsPage extends StatefulWidget {
  const UserRelationsPage({Key? key}) : super(key: key);

  @override
  _UserRelationsPageState createState() => _UserRelationsPageState();
}

class _UserRelationsPageState extends State<UserRelationsPage> {
  // ---------------------------------------------------------------------
  // Account / relations state (from UserRelationsPage)
  // ---------------------------------------------------------------------
  final ApiService _apiService = ApiService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  List<dynamic> _relations = [];
  bool _isLoading = false;
  String _errorMessage = "";
  String? _userId; // own login user id (prefs "userId")
  String? _userEmail;
  String? _userName;
  Map<String, dynamic>? _userProfile;
  String _fcmToken = "";
  String? _focusedUserId;
  // maps real userId -> relationId (what your UI uses)
  final Map<String, String> _userIdToRelationId = {};

  // ---------------------------------------------------------------------
  // Live tracking state (from LiveTrackingPagemain)
  // ---------------------------------------------------------------------
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  // final Set<Circle> _footprints = {};

  //Footprint markers are used instead of circles to allow for custom icons and better performance with many footprints.
  final Set<Marker> _footprintMarkers = {};
  final Map<String, List<MarkerId>> _userFootprintIds = {};
  final Map<String, bool> _userNextFootIsLeft = {};

  final Map<String, Set<Polyline>> _userPathLines = {};
  final Map<String, List<LatLng>> _userPathPoints = {};
  final Map<String, double> _userDistances = {};
  final Map<String, DateTime?> _userLastUpdateTimes = {};
  final Map<String, Color> _userColors = {};
  final Map<String, LatLng?> _userLastPositions = {};
  // final Map<String, String> _relationIdToUserId = {};

  // Ids of relations currently considered "trackable" (Active + connected),
  // and a lookup for the friendly name to show for each one.
  List<String> _userIdsToTrack = [];
  Map<String, String> _userNames = {};

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAlertSound = false;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  StompClient? _stompClient;
  bool _isConnected = false;
  final Set<String> _locationSubscribedUserIds = {};
  final Set<String> _alertSubscribedUserIds = {};

  final List<Map<String, dynamic>> _alerts = [];
  bool _showAlertPanel = false;
  bool _showConnectionsSheet = true;
  final _alertController = ScrollController();

  final List<Color> _colorPalette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
  ];

  static const LatLng _defaultCenter = LatLng(28.5892, 77.3176);

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _requestPermissions();
    // _disableBatteryOptimization();
    _initializePushSetup();
    _setupPushNotifications();
    _loadUserData();
    _loadProfile();
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    _alertController.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await PermissionHelper.requestPermissions(context);
  }

  // void _disableBatteryOptimization() {
  //   if (Platform.isAndroid) {
  //     AndroidIntent intent = AndroidIntent(
  //       action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
  //       data: 'package:com.otoi.safe_pulse',
  //     );
  //     intent.launch();
  //   }
  // }

  Future<void> _initializeTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _initializePushSetup() async {
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        setState(() => _fcmToken = token);
        _apiService.updateNotificationToken(token);
      }
      debugPrint('Initial FCM Token: $token');

      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('userId') ?? _userId;
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  void _setupPushNotifications() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      _apiService.updateNotificationToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showCustomDialog(
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showCustomDialog(
          title: message.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
        );
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message?.notification != null && mounted) {
        _showCustomDialog(
          title: message!.notification?.title ?? 'Notification',
          message: message.notification?.body ?? '',
        );
      }
    });
  }

  Future<void> _showCustomDialog({
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: _AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: _AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------
  Future<void> _loadProfile() async {
    try {
      final profile = await _apiService.getUserProfile();
      if (!mounted) return;
      setState(() => _userProfile = profile);
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString("userId") ?? _userId;
      _userEmail = prefs.getString("username");
      _userName = prefs.getString("name") ?? "User";
    });

    if (_userEmail != null) {
      await _fetchRelations();
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
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$_userEmail',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _relations = data);
        _initializeTrackingFromRelations(data);
      } else {
        setState(() {
          _errorMessage =
              "Failed to fetch relations. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Error fetching relations: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Sets up local per-user tracking state for every "Active + connected"
  /// relation, then (re)opens the socket so their live locations start
  /// flowing straight into the map — no separate tracking page required.
  // void _initializeTrackingFromRelations(List<dynamic> data) {
  //   final trackable = data.where((relation) =>
  //       relation['activityStatus'] == 'Active' &&
  //       relation['relationDirection'] == 'connected');

  //   final ids = <String>{};
  //   final names = <String, String>{};

  //   for (var relation in trackable) {
  //     final relationId = relation['userRelationId'].toString();
  //     final realUserId = relation['otherUserId'].toString(); // ⚠️ IMPORTANT

  //     ids.add(relationId);
  //     names[relationId] = getDisplayName(relation);
  //     _userIdToRelationId[realUserId] = relationId;
  //     _relationIdToUserId[relationId] = realUserId; // ✅ ADD THIS // 🔥 mapping

  //     _userPathPoints.putIfAbsent(relationId, () => []);
  //     _userPathLines.putIfAbsent(relationId, () => {});
  //     _userDistances.putIfAbsent(relationId, () => 0.0);
  //     _userLastUpdateTimes.putIfAbsent(relationId, () => null);
  //     _userLastPositions.putIfAbsent(relationId, () => null);
  //     _userColors[relationId] =
  //         _colorPalette[ids.indexOf(relationId) % _colorPalette.length];
  //   }

  //   setState(() {
  //     _userIdsToTrack = ids.toList();
  //     _userNames = names;
  //   });

  //   if (ids.isEmpty) return;

  //   if (_stompClient == null) {
  //     _connectWebSocket();
  //   } else if (_isConnected) {
  //     _sendTrackingRequests();
  //     _subscribeNewAlerts();
  //   }
  // }

  void _initializeTrackingFromRelations(List<dynamic> data) {
    final trackable = data.where(
      (relation) =>
          relation['activityStatus'] == 'Active' &&
          relation['relationDirection'] == 'connected',
    );

    final ids = <String>{};
    final names = <String, String>{};

    for (var relation in trackable) {
      final relationId = relation['userRelationId'].toString();
      final realUserId = relation['otherUserId'].toString();

      ids.add(realUserId);
      names[realUserId] = (relation['username'] ?? '').toString().isNotEmpty
          ? relation['username']
          : getDisplayName(relation);

      _userIdToRelationId[realUserId] = relationId;
      // _relationIdToUserId[relationId] = realUserId;

      _userPathPoints.putIfAbsent(realUserId, () => []);
      _userPathLines.putIfAbsent(realUserId, () => {});
      _userDistances.putIfAbsent(realUserId, () => 0.0);
      _userLastUpdateTimes.putIfAbsent(realUserId, () => null);
      _userLastPositions.putIfAbsent(realUserId, () => null);

      final idList = ids.toList();
      for (int i = 0; i < idList.length; i++) {
        final id = idList[i];
        _userColors[id] = _colorPalette[i % _colorPalette.length];
      }
    }

    // ✅ CALL ONCE PER USER
    Future.delayed(Duration(milliseconds: 300), () {
      for (var id in ids) {
        _fetchLatestHistory(id);
      }
    });

    setState(() {
      _userIdsToTrack = ids.toList(); // ✅ now real userIds
      _userNames = names;
    });

    if (_stompClient == null) {
      _connectWebSocket();
    } else if (_isConnected) {
      _sendTrackingRequests();
      _subscribeNewAlerts();
    }

    if (ids.isEmpty) return;
  }

  Future<void> _fetchLatestHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/api/location/history/latest?userId=$userId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final rawPoints = <LatLng>[];
        final rawAccuracies = <double>[];
        final rawTimes = <DateTime>[];

        for (var loc in data) {
          final lat = (loc['latitude']).toDouble();
          final lng = (loc['longitude']).toDouble();
          final accuracy = (loc['accuracy'] ?? 0).toDouble();
          final ts = (loc['timestamp'] as num).toDouble();
          final time = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());

          rawPoints.add(LatLng(lat, lng));
          rawAccuracies.add(accuracy);
          rawTimes.add(time);
        }

        // Filter out GPS-noise points before ever drawing anything --
        // same logic as the live path: skip a point if it's within the
        // accuracy radius (or a 15m floor) of the last accepted point.
        final points = <LatLng>[];
        final times = <DateTime>[];

        for (var i = 0; i < rawPoints.length; i++) {
          if (points.isEmpty) {
            points.add(rawPoints[i]);
            times.add(rawTimes[i]);
            continue;
          }
          final prev = points.last;
          final distance = _calculateDistance(
            prev.latitude,
            prev.longitude,
            rawPoints[i].latitude,
            rawPoints[i].longitude,
          );
          final noiseFloor = rawAccuracies[i] > 0 ? rawAccuracies[i] : 15.0;
          if (distance > noiseFloor) {
            points.add(rawPoints[i]);
            times.add(rawTimes[i]);
          }
        }

        if (points.isNotEmpty) {
          setState(() {
            _userPathPoints[userId] = points;
            _userLastPositions[userId] = points.last;
            _userLastUpdateTimes[userId] = times.last;

            // Recompute distance from the filtered points only
            double dist = 0;
            for (var i = 1; i < points.length; i++) {
              dist += _calculateDistance(
                points[i - 1].latitude,
                points[i - 1].longitude,
                points[i].latitude,
                points[i].longitude,
              );
            }
            _userDistances[userId] = dist;
          });

          _userPathLines[userId]?.clear();
          _userPathLines[userId]?.add(
            Polyline(
              polylineId: PolylineId('${userId}_history'),
              points: points,
              color: _userColors[userId] ?? Colors.blue,
              width: 4,
            ),
          );

          for (var p in points) {
            _addFootprint(userId, p);
          }

          if (_mapController != null && points.length > 1) {
            final bounds = _boundsFromLatLngList(points);
            _mapController!
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
          } else {
            _updateMap(userId, points.last);
          }
        }
      }
    } catch (e) {
      print("Error fetching history: $e");
    }
  }

  /// The signed-in user's own display name for the greeting in the top bar —
  /// prefers first/last name from the profile, falls back to the cached name.
  String _getOwnDisplayName() {
    final profileName = _userProfile != null
        ? "${_userProfile!['firstName'] ?? ''} ${_userProfile!['lastName'] ?? ''}"
            .trim()
        : '';
    if (profileName.isNotEmpty) return profileName;
    return _userName ?? "there";
  }

  String getDisplayName(Map<String, dynamic> relation) {
    final relationName = (relation['relationName'] ?? '').toString().trim();

    final username = (relation['username'] ?? '').toString().trim();
    final fallbackEmail = relation['otherUserEmail'] ?? '';

    String display = username.isNotEmpty
        ? username
        : (fallbackEmail.contains('@')
            ? fallbackEmail.split('@')[0]
            : fallbackEmail);

    if (display.isNotEmpty) {
      display = display[0].toUpperCase() + display.substring(1);
    }

    return relationName.isNotEmpty ? "$display ($relationName)" : display;
  }

  // ---------------------------------------------------------------------
  // WebSocket / live tracking (from LiveTrackingPagemain)
  // ---------------------------------------------------------------------
  void _connectWebSocket() {
    print("🔥 CONNECT WEBSOCKET CALLEDDDDDDDDDDDDDDDDDDD");

    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: 'http://147.93.108.99:7072/ws-location',
        onConnect: (frame) {
          print("✅ STOMP CONNECTED");
          print("User: $_userId");
          print("Tracking: $_userIdsToTrack");
          // setState(() => _isConnected = true);
          setState(() => _isConnected = true);
          _sendTrackingRequests();
          _subscribeToLocationUpdatesHistory();
          _subscribeToLocationUpdates();
          _subscribeNewAlerts();
        },
        stompConnectHeaders: {
          'userId': _userId.toString(), // 🔥 REQUIRED
        },
        webSocketConnectHeaders: {
          'userId': _userId.toString(), // 🔥 REQUIRED (for safety)
        },
        onDisconnect: (frame) {
          print("⚠️ DISCONNECTED");
          if (mounted) {
            setState(() => _isConnected = false);
          }
        },
        onStompError: (frame) {
          print("❌ STOMP ERROR: ${frame.body}");
          if (mounted) {
            setState(() => _isConnected = false);
          }
        },
        onWebSocketError: (error) {
          print("❌ WS ERROR: $error");
          if (mounted) {
            setState(() => _isConnected = false);
          }
        },
        reconnectDelay: Duration(seconds: 5),
        heartbeatOutgoing: Duration(seconds: 10),
        heartbeatIncoming: Duration(seconds: 10),
      ),
    );
    _stompClient!.activate();
  }

  void _sendTrackingRequests() {
    if (_userId == null) return;

    for (var realUserId in _userIdsToTrack) {
      // if (realUserId == _userId) continue; // 🔥 IGNORE YOUR OWN LOCATION
      _stompClient?.send(
        destination: '/app/subscribe-to-user',
        body: jsonEncode({
          'requestingUserId': _userId,
          'userIdToTrack': realUserId,
          // 'relationId': _userIdToRelationId[realUserId], // 🔥 ADD THIS
        }),
      );
    }
  }

  void _subscribeToLocationUpdates() {
    for (var userId in _userIdsToTrack) {
      if (_locationSubscribedUserIds.contains(userId)) continue;
      _locationSubscribedUserIds.add(userId);

      _stompClient?.subscribe(
        destination: '/topic/user-locations-$userId',
        callback: (frame) {
          if (frame.body == null) return;

          try {
            final data = jsonDecode(frame.body!);

            final incomingUserId = data['userId']?.toString();
            if (incomingUserId == null) return;
            if (incomingUserId == _userId) return;

            final lat = parseDouble(data['latitude']);
            final lng = parseDouble(data['longitude']);
            final accuracy = parseDouble(data['accuracy']);
            final position = LatLng(lat, lng);

            final prevPosition = _userLastPositions[incomingUserId];
            final noiseFloor = accuracy > 0 ? accuracy : 15.0; // meters

            final isRealMovement = prevPosition == null ||
                _calculateDistance(
                      prevPosition.latitude,
                      prevPosition.longitude,
                      position.latitude,
                      position.longitude,
                    ) >
                    noiseFloor;

            // Always refresh the "last seen" timestamp so stationary-detection
            // and "last update" times stay accurate, even when we skip the
            // marker/path/footprint update below for a noisy point.
            _userLastUpdateTimes[incomingUserId] = DateTime.now();

            if (!isRealMovement)
              return; // treat as GPS noise, skip visuals entirely

            _userLastPositions[incomingUserId] = position;

            _updatePath(incomingUserId, position, accuracy: accuracy);
            _updateMap(incomingUserId, position);
            _addFootprint(incomingUserId, position);

            if (_focusedUserId == incomingUserId) {
              _mapController?.animateCamera(CameraUpdate.newLatLng(position));
            }
          } catch (e) {
            debugPrint('Error processing location: $e');
          }
        },
      );
    }
  }

  double parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _subscribeToLocationUpdatesHistory() {
    _stompClient?.subscribe(
      destination: '/topic/user-locations-$_userId',
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final decoded = jsonDecode(frame.body!);
          debugPrint(
            'user-locations frame keys=${decoded is Map ? decoded.keys.toList() : decoded} | tracking=$_userIdsToTrack',
          );
          if (decoded is Map && decoded.containsKey('error')) {
            debugPrint("Backend error: ${decoded['error']}");
            return;
          }
          if (decoded is! Map<String, dynamic>) return;

          setState(() {
            for (var userId in _userIdsToTrack) {
              if (!decoded.containsKey(userId)) continue;
              final locationsRaw = decoded[userId];
              if (locationsRaw is! List) continue;

              _userPathPoints[userId]?.clear();
              _userPathLines[userId]?.clear();
              _userDistances[userId] = 0;

              for (final location in locationsRaw) {
                if (location is! Map) continue;
                final lat = parseDouble(location['latitude']);
                final lng = parseDouble(location['longitude']);
                _userPathPoints[userId]?.add(LatLng(lat, lng));
              }

              if (_userPathPoints[userId]!.isNotEmpty) {
                _userLastPositions[userId] = _userPathPoints[userId]!.last;
              }
            }
          });
        } catch (e) {
          debugPrint('Error processing location history: $e');
        }
      },
    );
  }

  /// Subscribes to alerts only for ids we haven't already subscribed to,
  /// so re-running this after the relations list refreshes doesn't create
  /// duplicate subscriptions.
  void _subscribeNewAlerts() {
    for (var userId in _userIdsToTrack) {
      if (_alertSubscribedUserIds.contains(userId)) continue;
      _alertSubscribedUserIds.add(userId);

      _stompClient?.subscribe(
        destination: '/topic/alerts-$userId',
        callback: (frame) {
          if (frame.body == null) return;
          try {
            final alert = jsonDecode(frame.body!);
            _handleNewAlert(alert);
          } catch (e) {
            debugPrint('Error processing alert: $e');
          }
        },
      );
    }
  }

  void _handleNewAlert(Map<String, dynamic> alert) {
    final message = alert['message'] ?? 'Alert';
    final userId = alert['userId'] ?? 'user@gmail.com';
    final isDanger = message.toString().toLowerCase().contains('danger');

    DateTime? timestamp;
    if (alert['timestamp'] is List) {
      final tsList = alert['timestamp'] as List;
      timestamp = DateTime(
        tsList[0],
        tsList[1],
        tsList[2],
        tsList[3],
        tsList[4],
        tsList[5],
      );
    }

    final formattedAlert = {
      'message': message,
      'timestamp': timestamp ?? DateTime.now(),
      'userId': userId,
      'isDanger': isDanger,
    };

    setState(() {
      _alerts.insert(0, formattedAlert);
      _showAlertPanel = true;
    });

    _speakAlert(message.toString(), userId.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString()),
        backgroundColor: isDanger ? Colors.red : Colors.green,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => setState(() => _showAlertPanel = true),
        ),
      ),
    );

    _alertController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _speakAlert(String message, String userId) async {
    if (_isSpeaking) {
      await _tts.stop();
      await Future.delayed(Duration(milliseconds: 500));
    }

    try {
      _isSpeaking = true;

      final nameMatch = RegExp(r'User\s(.+?)\s').firstMatch(message);
      final userName = nameMatch?.group(1) ?? 'User';
      final isDanger = message.toLowerCase().contains('danger');
      final zone = _extractZoneName(message);

      await _tts.setLanguage("en-IN");
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      final alertMessage = isDanger
          ? "Hey. $userName. has Entered danger zone. $zone."
          : "Hey. $userName. has Left safe zone. $zone.";

      for (int i = 0; i < 3; i++) {
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [500, 500]);
        }

        await _tts.speak(alertMessage);
        await _tts.awaitSpeakCompletion(true);

        if (i < 2) {
          await Vibration.cancel();
          await Future.delayed(Duration(milliseconds: 800));
        }
      }
    } catch (e) {
      debugPrint('Alert error: $e');
      await _tts.speak("New alert received");
    } finally {
      await Vibration.cancel();
      _isSpeaking = false;
    }
  }

  String _extractZoneName(String message) {
    final zoneMatch = RegExp(
      r"zone\s'(.+?)'|zone\s(.+?)\s\d",
    ).firstMatch(message);
    return zoneMatch?.group(1) ?? zoneMatch?.group(2) ?? 'the area';
  }

  Future<void> _playAlertSound(bool isDanger) async {
    if (_isPlayingAlertSound) return;
    try {
      _isPlayingAlertSound = true;
      if (isDanger && await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }
      final soundFile = isDanger ? 'danger_alert.mp3' : 'safe_alert.mp3';
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlayingAlertSound = false;
      });
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _isPlayingAlertSound = false;
    }
  }

  // ---------------------------------------------------------------------
  // Map helpers
  // ---------------------------------------------------------------------
  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  void _updatePath(String userId, LatLng newPosition, {double accuracy = 0}) {
    if (_userPathPoints[userId]!.length > 100) {
      _userPathPoints[userId]!.removeAt(0);
    }

    if ((_userPathPoints[userId]?.length ?? 0) > 0) {
      final prev = _userPathPoints[userId]!.last;
      final distance = _calculateDistance(
        prev.latitude,
        prev.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      // Minimum-movement threshold: ignore deltas smaller than plausible
      // GPS noise (accuracy radius, or a flat floor if accuracy is unknown).
      // Without this, stationary jitter accumulates into large fake distances.
      final noiseFloor = accuracy > 0 ? accuracy : 15.0; // meters
      if (distance > noiseFloor) {
        _userDistances[userId] = (_userDistances[userId] ?? 0) + distance;
        _userPathPoints[userId]!.add(newPosition);
      }
      // else: treat as noise -- don't add to path or distance, so the
      // polyline doesn't zigzag either.
    } else {
      _userPathPoints[userId]!.add(newPosition);
    }

    _userPathLines[userId]?.clear();
    if ((_userPathPoints[userId]?.length ?? 0) > 1) {
      _userPathLines[userId]?.add(
        Polyline(
          polylineId: PolylineId('${userId}_path'),
          points: List<LatLng>.from(_userPathPoints[userId]!),
          color: _userColors[userId] ?? Colors.blue,
          width: 3,
        ),
      );
    }
  }

  void _updateMap(String userId, LatLng position) async {
    final markerId = MarkerId(userId);

    final isStopped = _isUserStationary(userId);
    final name = _userNames[userId] ?? 'User';

    BitmapDescriptor icon;

    if (isStopped) {
      final relationId = _userIdToRelationId[userId];
      final relation = _relations.firstWhere(
        (r) => r['userRelationId'].toString() == relationId,
        orElse: () => {},
      );

      final imageUrl = relation['imageUrl'] ?? '';

      if (imageUrl.isNotEmpty) {
        final fullUrl = imageUrl.startsWith('http')
            ? imageUrl
            : '${ApiService.baseUrl}/$imageUrl';

        icon = await _createUserImageMarker(fullUrl);
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          _getHueForColor(_userColors[userId] ?? Colors.blue),
        );
      }
    } else {
      icon = BitmapDescriptor.defaultMarkerWithHue(
        _getHueForColor(_userColors[userId] ?? Colors.blue),
      );
    }

    final lastTime = _userLastUpdateTimes[userId];

    setState(() {
      _markers.removeWhere((m) => m.markerId == markerId);

      _markers.add(
        Marker(
          markerId: markerId,
          position: position,
          icon: icon,
          anchor: isStopped ? Offset(0.5, 0.5) : Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: name,
            snippet: isStopped && lastTime != null
                ? "User is here • ${DateFormat('hh:mm a').format(lastTime)}"
                : "Moving...",
          ),
        ),
      );
    });
  }

  Future<BitmapDescriptor> _createUserImageMarker(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;

    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    const size = 120.0;
    final radius = size / 2;

    // Draw circular clip
    final rect = Rect.fromLTWH(0, 0, size, size);
    canvas.clipPath(Path()..addOval(rect));

    // Draw image
    paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.cover);

    // Optional: white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(Offset(radius, radius), radius - 3, borderPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  static const int _stationaryThresholdSeconds = 30; // tweak (20–60 sec)

  bool _isUserStationary(String userId) {
    final lastTime = _userLastUpdateTimes[userId];
    if (lastTime == null) return false;

    final diff = DateTime.now().difference(lastTime).inSeconds;
    return diff > _stationaryThresholdSeconds;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371e3;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // void _updateMap(String userId, LatLng position) {
  //   final markerId = MarkerId(userId);
  //   setState(() {
  //     _markers.removeWhere((marker) => marker.markerId == markerId);
  //     _markers.add(Marker(
  //       markerId: markerId,
  //       position: position,
  //       icon: BitmapDescriptor.defaultMarkerWithHue(
  //         _getHueForColor(_userColors[userId] ?? Colors.blue),
  //       ),
  //       infoWindow: InfoWindow(
  //         title: _userNames[userId] ?? 'User',
  //         snippet:
  //             '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
  //       ),
  //     ));
  //   });
  // }

  double _bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> _addFootprint(String userId, LatLng position) async {
    final prev = _userLastPositions[userId];
    final bearing = prev != null ? _bearingBetween(prev, position) : 0.0;

    final isLeft = _userNextFootIsLeft[userId] ?? true;
    _userNextFootIsLeft[userId] = !isLeft;

    final icon = await _FootprintIconFactory.get(
      _userColors[userId] ?? Colors.blue,
      isLeft: isLeft,
    );

    final id = MarkerId(
      '${userId}_fp_${DateTime.now().millisecondsSinceEpoch}',
    );

    final ids = _userFootprintIds.putIfAbsent(userId, () => []);
    ids.add(id);

    const maxFootprints = 15;
    List<MarkerId>? toRemove;
    if (ids.length > maxFootprints) {
      toRemove = ids.sublist(0, ids.length - maxFootprints);
      ids.removeRange(0, ids.length - maxFootprints);
    }

    if (!mounted) return;
    setState(() {
      if (toRemove != null) {
        _footprintMarkers.removeWhere((m) => toRemove!.contains(m.markerId));
      }

      // Fade older footprints for this user as new ones are added
      final updated = <Marker>{};
      for (final m in _footprintMarkers) {
        if (!ids.contains(m.markerId)) {
          updated.add(m);
          continue;
        }
        final age = ids.indexOf(m.markerId);
        final alpha = (0.15 + 0.85 * (age / ids.length)).clamp(0.15, 1.0);
        updated.add(m.copyWith(alphaParam: alpha));
      }
      _footprintMarkers
        ..clear()
        ..addAll(updated);

      _footprintMarkers.add(
        Marker(
          markerId: id,
          position: position,
          icon: icon,
          rotation: bearing,
          anchor: const Offset(0.5, 0.9),
          flat: true,
          zIndex: 1,
          alpha: 1.0,
        ),
      );
    });
  }

  // void _addFootprint(String userId, LatLng position) {
  //   setState(() {
  //     _footprints.add(Circle(
  //       circleId: CircleId('${userId}_${Uuid().v4()}'),
  //       center: position,
  //       radius: 5,
  //       strokeWidth: 0,
  //       fillColor: (_userColors[userId] ?? Colors.blue).withOpacity(0.7),
  //     ));
  //   });
  // }

  void _moveToUserLocation(String userId) {
    final position = _userLastPositions[userId];
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
      setState(() {
        _showConnectionsSheet = false;
        _focusedUserId = userId;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No location data available for this user'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  double _getHueForColor(Color color) {
    return HSLColor.fromColor(color).hue;
  }

  void _focusAllUsers() {
    final positions = _userLastPositions.values
        .where((pos) => pos != null)
        .cast<LatLng>()
        .toList();

    if (positions.isEmpty || _mapController == null) {
      print("I AM IN USER_RELATIONS_PAGE");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No user locations available"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 15),
      );
      return;
    }

    final bounds = _boundsFromLatLngList(positions);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _moveTo24HourHistory(String mail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationHistoryPageWF(mail: mail),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Emergency alert
  // ---------------------------------------------------------------------
  void _showEmergencyConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Send emergency alert?'),
          content: const Text(
            'This will immediately notify all of your connections. Only proceed if this is a real emergency.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendEmergencyAlert();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Send alert'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendEmergencyAlert() async {
    if (_userEmail == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/emergency/sendAlert'),
        body: json.encode({
          'userEmail': _userEmail,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 200
                ? 'Emergency alert sent successfully!'
                : 'Failed to send emergency alert. Please try again.',
          ),
          backgroundColor: response.statusCode == 200
              ? _AppColors.success
              : _AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending alert: $e'),
          backgroundColor: _AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _dedupedActiveRelations() {
    final Map<String, Map<String, dynamic>> byUserId = {};

    for (final r in _relations) {
      final userId = r['otherUserId']?.toString();
      if (userId == null) continue;

      final isActive = r['activityStatus'] == 'Active' &&
          r['relationDirection'] == 'connected';
      if (!isActive) continue;

      if (!byUserId.containsKey(userId)) {
        byUserId[userId] = Map<String, dynamic>.from(r);
      } else {
        // Merge relationship labels instead of dropping the second one silently
        final existingName =
            byUserId[userId]!['relationName']?.toString().trim() ?? '';
        final newName = r['relationName']?.toString().trim() ?? '';
        if (newName.isNotEmpty &&
            !existingName.toLowerCase().contains(newName.toLowerCase())) {
          byUserId[userId]!['relationName'] = '$existingName & $newName';
        }
      }
    }

    return byUserId.values.toList();
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final trackableRelations = _dedupedActiveRelations();

    final otherRelations = _relations
        .where(
          (relation) => !(relation['activityStatus'] == 'Active' &&
              relation['relationDirection'] == 'connected'),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// 🗺️ MAP (always the base layer, Life360-style)
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 15,
            ),
            markers: {..._markers, ..._footprintMarkers},
            polylines: _userPathLines.values.expand((lines) => lines).toSet(),
            myLocationButtonEnabled: false,
          ),

          /// 🔝 GLASS TOP BAR
          Positioned(top: 40, left: 16, right: 16, child: _buildTopBar()),

          /// 🚨 DANGER BANNER (highest priority)
          if (_alerts.isNotEmpty && _alerts.first['isDanger'] == true)
            _buildDangerBanner(),

          /// 🎯 FLOATING ACTION BUTTONS
          Positioned(
            bottom: 140,
            right: 16,
            child: Column(
              children: [
                _buildFAB(Icons.my_location, _focusAllUsers),
                const SizedBox(height: 12),
                // _buildFAB(
                //   Icons.warning_amber_rounded,
                //   _showEmergencyConfirmationDialog,
                //   color: _AppColors.danger,
                // ),
                const SizedBox(height: 12),
                _buildFAB(
                  _showConnectionsSheet
                      ? Icons.keyboard_arrow_down
                      : Icons.people_alt_rounded,
                  () => setState(
                    () => _showConnectionsSheet = !_showConnectionsSheet,
                  ),
                ),
              ],
            ),
          ),

          /// 👇 DRAGGABLE CONNECTIONS SHEET (replaces the separate list page)
          if (_showConnectionsSheet)
            _buildConnectionsSheet(trackableRelations, otherRelations),

          /// 🔔 ALERT PANEL
          _buildAlertPanel(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "Hi, ${_getOwnDisplayName()} 👋",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _buildConnectionChip(),
              const SizedBox(width: 10),
              _buildNotificationIcon(),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                onPressed: () async {
                  if (_userEmail != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LinkUserPage(userEmail: _userEmail!),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 5),
          Text(
            _isConnected ? "Live" : "Offline",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => setState(() => _showAlertPanel = !_showAlertPanel),
        ),
        if (_alerts.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _alerts.any((a) => a['isDanger'] == true)
                    ? Colors.red
                    : Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${_alerts.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDangerBanner() {
    final alert = _alerts.first;
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                alert['message'].toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(IconData icon, VoidCallback onTap, {Color? color}) {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Colors.white,
      onPressed: onTap,
      child: Icon(icon, color: color ?? Colors.black),
    );
  }

  Widget _buildConnectionsSheet(
    List<dynamic> trackableRelations,
    List<dynamic> otherRelations,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _isLoading && _relations.isEmpty
              ? _buildLoadingSkeleton()
              : _errorMessage.isNotEmpty && _relations.isEmpty
                  ? _buildErrorState()
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const SizedBox(height: 10),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Your Circle",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _AppColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 20),
                                onPressed: _fetchRelations,
                              ),
                            ],
                          ),
                        ),
                        if (_relations.isEmpty)
                          _buildEmptyState()
                        else ...[
                          if (trackableRelations.isNotEmpty) ...[
                            _sectionHeader(
                              'ACTIVE NOW',
                              Icons.location_on_outlined,
                            ),
                            ...trackableRelations.map(
                              (r) => _buildConnectionCard(r, true),
                            ),
                          ],
                          if (otherRelations.isNotEmpty) ...[
                            _sectionHeader(
                              'OTHER CONNECTIONS',
                              Icons.people_outline,
                            ),
                            ...otherRelations.map(
                              (r) => _buildConnectionCard(r, false),
                            ),
                          ],
                        ],
                      ],
                    ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(Map<String, dynamic> relation, bool isTrackable) {
    final email = relation['otherUserEmail'] ?? '';
    final status = relation['activityStatus'] ?? 'Unknown';
    final imageUrl = relation['imageUrl'] ?? '';

    final name = (relation['username'] ?? '').toString().trim().isNotEmpty
        ? relation['username']
        : getNameFromEmail(email);
    // final trackId = relation['userRelationId']?.toString();
    final realUserId = relation['otherUserId']?.toString();

    final fullImageUrl = imageUrl.isNotEmpty
        ? (imageUrl.startsWith('http')
            ? imageUrl
            : '${ApiService.baseUrl}/$imageUrl')
        : '';

    final bool isActive = status == 'Active';
    final Color statusColor =
        isActive ? _AppColors.success : _AppColors.textSecondary;
    final Color statusBg =
        isActive ? _AppColors.successSoft : Colors.grey.shade100;

    final distanceKm = realUserId != null
        ? ((_userDistances[realUserId] ?? 0) / 1000).toStringAsFixed(2)
        : null;
    final lastUpdate =
        realUserId != null ? _userLastUpdateTimes[realUserId] : null;

    print("RELATION DEBUG:");
    print("Status: ${relation['activityStatus']}");
    print("Direction: ${relation['relationDirection']}");
    print("UserId: ${relation['otherUserId']}");
    print("imageUrl: ${relation['imageUrl']}");
    print("Full image URL: $fullImageUrl");
    print("isTrackable: $isTrackable");
    print("FULL RELATION: $relation");
    print("Using ID for tracking: $realUserId");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isTrackable && realUserId != null
              ? () => _moveToUserLocation(realUserId)
              : () => _moveTo24HourHistory(email),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _AppColors.primarySoft,
                      backgroundImage: fullImageUrl.isNotEmpty
                          ? NetworkImage(fullImageUrl)
                          : null,
                      child: fullImageUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: _AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    if (isActive)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 12,
                          width: 12,
                          decoration: BoxDecoration(
                            color: _AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (distanceKm != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$distanceKm km',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (lastUpdate != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a').format(lastUpdate),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (realUserId != null)
                  _circleIconButton(
                    icon: Icons.my_location_rounded,
                    color: _AppColors.primary,
                    tooltip: 'Center on map',
                    onPressed: () => _moveToUserLocation(realUserId),
                  ),
                const SizedBox(width: 6),
                _circleIconButton(
                  icon: Icons.history_rounded,
                  color: _AppColors.textSecondary,
                  tooltip: 'Location history',
                  onPressed: () => _moveTo24HourHistory(email),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        height: 76,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 100,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 70,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: _AppColors.danger,
                size: 36,
              ),
            ),
            _Gap.md,
            const Text(
              "Something went wrong",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage,
              style: const TextStyle(color: _AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            _Gap.lg,
            ElevatedButton.icon(
              onPressed: _fetchRelations,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: _AppColors.primary,
              size: 40,
            ),
          ),
          _Gap.md,
          const Text(
            'No connections yet',
            style: TextStyle(
              fontSize: 18,
              color: _AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add family members or friends so you can keep an eye on each other.',
            style: TextStyle(fontSize: 14, color: _AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          _Gap.lg,
          ElevatedButton.icon(
            onPressed: () async {
              if (_userEmail != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LinkUserPage(userEmail: _userEmail!),
                  ),
                );
              }
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertPanel() {
    if (!_showAlertPanel || _alerts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.25 + 20,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showAlertPanel = false),
                  ),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  controller: _alertController,
                  shrinkWrap: true,
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    final alert = _alerts[index];
                    final isDanger = alert['isDanger'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDanger ? Colors.red[50] : Colors.green[50],
                      child: ListTile(
                        leading: Icon(
                          Icons.warning,
                          color: isDanger ? Colors.red : Colors.green,
                        ),
                        title: Text(
                          alert['message'] ?? 'Alert',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isDanger ? Colors.red[800] : Colors.green[800],
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, hh:mm a').format(
                            alert['timestamp'] is DateTime
                                ? (alert['timestamp'] as DateTime).toLocal()
                                : DateTime.now().toLocal(),
                          ),
                          style: TextStyle(
                            color:
                                isDanger ? Colors.red[600] : Colors.green[600],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_alerts.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _alerts.clear()),
                  child: const Text('Clear All Alerts'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:Safe_pulse/Api/ApiService.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

// Hive box names
const String pendingLocationsBoxName = 'pending_locations';
const String lastLocationBoxName = 'last_location';
const String connectionStatusBoxName = 'connection_status';
const String relatedUsersBoxName = 'related_users';

// TTS and Audio constants
const double _slowSpeechRate = 0.4;
const double _normalSpeechRate = 0.5;
const double _volume = 1.0;

// Global instances for audio and TTS
final AudioPlayer _audioPlayer = AudioPlayer();
final FlutterTts _tts = FlutterTts();
bool _isSpeaking = false;
bool _isPlayingAlertSound = false;

// Initialize Hive
Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<List<dynamic>>(pendingLocationsBoxName);
  await Hive.openBox<Map<String, dynamic>>(lastLocationBoxName);
  await Hive.openBox<bool>(connectionStatusBoxName);
  await Hive.openBox<List<String>>(relatedUsersBoxName);
}

Future<void> initializeService() async {
  await initHive();
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: 'location_service',
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Running in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Helper functions
Future<void> _initializeTts() async {
  await _tts.setLanguage("en-IN");
  await _tts.setSpeechRate(0.45);
  await _tts.setVolume(1.0);
}

String _extractZoneName(String message) {
  final zoneMatch =
      RegExp(r"zone\s'(.+?)'|zone\s(.+?)\s\d").firstMatch(message);
  return zoneMatch?.group(1) ?? zoneMatch?.group(2) ?? 'the area';
}

Future<void> _playAlertSound(bool isDanger) async {
  if (_isPlayingAlertSound) return;

  try {
    _isPlayingAlertSound = true;

    if (isDanger && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 500);
    }

    final soundFile = isDanger ? 'danger_alert.mp3' : 'safe_alert.mp3';
    await _audioPlayer.play(AssetSource('sounds/$soundFile'));

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlayingAlertSound = false;
    });
  } catch (e) {
    log("Error playing sound: $e");
    _isPlayingAlertSound = false;
  }
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
    log("Alert error: $e");
    await _tts.speak("New alert received");
  } finally {
    await Vibration.cancel();
    _isSpeaking = false;
  }
}

Future<List<String>> getRelatedUserIds(String email) async {
  final relatedUsersBox = Hive.box<List<String>>(relatedUsersBoxName);
  final cachedUsers = relatedUsersBox.get('userIds');
  if (cachedUsers != null) {
    return cachedUsers;
  }

  try {
    final url = Uri.parse(
        '${ApiService.baseUrl}/api/relationships/getUserRelations?email=$email');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> relations = jsonDecode(response.body);
      final userIds = relations
          .map<String>((relation) => relation['userRelationId'] as String)
          .toList();
      await relatedUsersBox.put('userIds', userIds);
      return userIds;
    }
    return [];
  } catch (e) {
    log("Error fetching related users: $e");
    return [];
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await initHive();
  await _initializeTts();

  // Get Hive boxes
  final Box<List<dynamic>> pendingLocationsBox =
      Hive.box<List<dynamic>>(pendingLocationsBoxName);
  final Box<Map<String, dynamic>> lastLocationBox =
      Hive.box<Map<String, dynamic>>(lastLocationBoxName);
  final Box<bool> connectionStatusBox = Hive.box<bool>(connectionStatusBoxName);
  final Box<List<String>> relatedUsersBox =
      Hive.box<List<String>>(relatedUsersBoxName);

  // WebSocket client and connection state
  StompClient? stompClient;
  String? userEmail;
  String? userId;
  bool isWebSocketConnected = false;
  bool isUserConnected = false;

  // Track last saved location and time
  Position? lastSavedPosition;
  DateTime? lastSavedTime;

  StreamSubscription<Position>? positionStream;
  DateTime? lastSentTime;
// Position? lastSavedPosition;

  Future<void> savePendingLocation(Map<String, dynamic> location) async {
    try {
      final pending = pendingLocationsBox
          .get('locations', defaultValue: <dynamic>[]) as List<dynamic>;
      final newPending = List<dynamic>.from(pending)..add(location);
      await pendingLocationsBox.put('locations', newPending);
    } catch (e) {
      log("Error saving pending location: $e");
    }
  }

  Future<void> saveLastSavedData(Position position) async {
    try {
      await lastLocationBox.putAll({
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'userId': userId,
        },
      });
    } catch (e) {
      log("Error saving last saved data: $e");
    }
  }

  void startLocationTracking() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // 🔋 huge battery saver
        distanceFilter: 2, // only trigger when moved 30m
      ),
    ).listen((Position position) async {
      try {
        final now = DateTime.now();

        final distance = lastSavedPosition == null
            ? 100
            : Geolocator.distanceBetween(
                lastSavedPosition!.latitude,
                lastSavedPosition!.longitude,
                position.latitude,
                position.longitude,
              );

        // 🚫 ignore tiny movement
        if (distance < 2) return;

        // 🚫 throttle network calls
        if (lastSentTime != null &&
            now.difference(lastSentTime!) < const Duration(seconds: 3)) {
          return;
        }

        lastSentTime = now;
        
        log("Saved: ${position.latitude}, ${position.longitude}");

        final location = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': now.toIso8601String(),
          'userId': userId,
        };

        if (isWebSocketConnected) {
          stompClient?.send(
            destination: '/app/update-location',
            headers: {'userId': userId!},
            body: jsonEncode(location),
          );
        } else {
          await savePendingLocation(location);
        }

        lastSavedPosition = position;
        await saveLastSavedData(position);
      } catch (e) {
        log("Stream error: $e");
      }
    });
  }

  // // Get user data from SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString("username");
    userId = prefs.getString("userId");
    log("User data loaded: userId=$userId, userEmail=$userEmail");
  } catch (e) {
    log("Error getting user data: $e");
  }

  if (userId != null) {
    startLocationTracking();
    log("Location tracking started");
  }

  // Function to send pending locations via API
  Future<void> sendPendingLocations() async {
    final pending = pendingLocationsBox
        .get('locations', defaultValue: <dynamic>[]) as List<dynamic>;
    if (pending.isEmpty || userEmail == null) return;

    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/rest/bulk-location-save?username=$userEmail');
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(pending);

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        log("Successfully sent ${pending.length} pending locations");
        await pendingLocationsBox.put('locations', <dynamic>[]);
      } else {
        log("Failed to send pending locations: ${response.statusCode}");
      }
    } catch (e) {
      log("Error sending pending locations: $e");
    }
  }

  // Update connection status in Hive
  Future<void> updateConnectionStatus(bool connected) async {
    try {
      await connectionStatusBox.put('isConnected', connected);
      isUserConnected = connected;
      log("Connection status updated: $connected");
    } catch (e) {
      log("Error updating connection status: $e");
    }
  }

  // Handle new alerts
  Future<void> _handleNewAlert(Map<String, dynamic> alert) async {
    final message = alert['message'] ?? 'Alert';
    final alertUserId = alert['userId'] ?? 'user';
    final user = alert['username'] ?? 'User';
    // final isDanger = message.toLowerCase().contains('danger');

    _speakAlert(message, alertUserId);
    // _playAlertSound(isDanger);

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Alert from $user",
          content: message,
        );
      }
    }
  }

  // Subscribe to alerts for all related users
  Future<void> subscribeToAlerts() async {
    if (userId == null || userEmail == null) {
      return;
    }

    final relatedUserIds = await getRelatedUserIds(userEmail!);
    final allUserIds = [...relatedUserIds, userId!];
    log("Subscribing to alerts for user IDs: $allUserIds");

    for (final id in allUserIds) {
      stompClient?.subscribe(
        destination: '/topic/alerts-$id',
        callback: (frame) {
          if (frame.body != null) {
            try {
              final alert = jsonDecode(frame.body!);
              log("Received alert for user $id: $alert");
              _handleNewAlert(alert);
            } catch (e) {
              log("Error processing alert: $e");
            }
          }
        },
      );
    }
  }

  // Setup WebSocket connection
  void connectWebSocket() {
    if (userId == null) {
      log("Cannot connect WebSocket - userId is null");
      return;
    }

    stompClient = StompClient(
      config: StompConfig.sockJS(
        url: '${ApiService.baseUrl}/ws-location',
        onConnect: (StompFrame frame) async {
          log("WebSocket connected");
          isWebSocketConnected = true;

          stompClient?.send(
            destination: '/app/user-connect',
            headers: {'userId': userId!},
            body: jsonEncode({'timestamp': DateTime.now().toIso8601String()}),
          );

          await subscribeToAlerts();
          await updateConnectionStatus(true);
          await sendPendingLocations();
        },
        onDisconnect: (frame) {
          log("WebSocket disconnected");
          isWebSocketConnected = false;
          updateConnectionStatus(false);
        },
        onWebSocketError: (dynamic error) {
          log("WebSocket error: $error");
          isWebSocketConnected = false;
          updateConnectionStatus(false);
        },
        reconnectDelay: const Duration(seconds: 5),
        connectionTimeout: const Duration(seconds: 10),
        stompConnectHeaders: {'userId': userId!},
      ),
    );
    stompClient?.activate();
  }

  // Connect to WebSocket if we have user data
  if (userId != null && userEmail != null) {
    connectWebSocket();
  }

  // Service control handlers
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    log("Stopping service...");
    stompClient?.deactivate();
    service.stopSelf();
  });
}

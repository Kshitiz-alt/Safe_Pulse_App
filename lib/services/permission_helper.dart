import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Requests notification + location permissions, but only prompts the
  /// user (system dialog or our custom explanation dialog) when a
  /// permission is genuinely not yet granted. Safe to call on every
  /// `initState` — repeat calls after permissions are already granted
  /// are now no-ops.
  static Future<bool> requestPermissions(BuildContext context) async {
    await _ensureNotificationPermission();

    final locationGranted = await _ensureLocationPermission(context);
    if (!locationGranted) return false;

    await _ensureLocationAlwaysPermission(context);
    return true;
  }

  // -----------------------------------------------------------------
  // Notifications
  // -----------------------------------------------------------------
  static Future<void> _ensureNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isGranted) return;

    if (status.isPermanentlyDenied) {
      debugPrint("Notification permission permanently denied.");
      return;
    }

    final result = await Permission.notification.request();
    if (!result.isGranted) {
      debugPrint("Notification permission denied.");
    }
  }

  // -----------------------------------------------------------------
  // Location (foreground)
  // -----------------------------------------------------------------
  static Future<bool> _ensureLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      // The system dialog won't appear again — request() would be a no-op.
      // Send the user to Settings instead, but don't force it on every
      // visit; just log it so it's obvious in debugging.
      debugPrint("Location permission permanently denied. User must enable it from Settings.");
      return false;
    }

    // Only show our explanation dialog when we're actually about to ask.
    final proceed = await _showLocationPermissionDialog(context);
    if (proceed != true) {
      debugPrint("User canceled location permission request.");
      return false;
    }

    final result = await Permission.location.request();
    if (!result.isGranted) {
      debugPrint("Location permission denied.");
      return false;
    }
    return true;
  }

  // -----------------------------------------------------------------
  // Location (always / background)
  // -----------------------------------------------------------------
  static Future<void> _ensureLocationAlwaysPermission(BuildContext context) async {
    final status = await Permission.locationAlways.status;

    if (status.isGranted) {
      debugPrint("All required permissions granted.");
      return;
    }

    if (status.isPermanentlyDenied) {
      debugPrint("Location Always permission permanently denied. User must enable it from Settings.");
      return;
    }

    final result = await Permission.locationAlways.request();
    if (!result.isGranted) {
      debugPrint("Location Always permission denied.");
      return;
    }

    debugPrint("All required permissions granted.");
  }

  // -----------------------------------------------------------------
  // Explanation dialog — only ever called right before an actual
  // permission prompt, never unconditionally.
  // -----------------------------------------------------------------
  static Future<bool?> _showLocationPermissionDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Safe Pulse collects your location data to enable real-time location tracking and emergency safety alerts, even when the app is closed or not in use.\n\n'
            'Note: By clicking Allow/Accept, you are giving permission to the Safe Pulse app to access location data.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Allow'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  /// Optional helper if you want a settings-redirect button somewhere in
  /// your UI (e.g. a banner: "Location permanently denied — Open Settings").
  static Future<void> openSettings() => openAppSettings();
}
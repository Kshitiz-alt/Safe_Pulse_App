import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OemAutostartHelper {
  static const platform = MethodChannel('safe_pulse/location');

  // Future<void> requestBatteryOptimization() async {
  //   try {
  //     await platform.invokeMethod('requestBatteryOptimizationExemption');
  //     await platform.invokeMethod('requestExactAlarmPermission'); 
  //   } catch (e) {
  //     print("Error: $e");
  //   }
  // }

  static const _relevantManufacturers = [
    'xiaomi',
    'oppo',
    'vivo',
    'oneplus',
    'huawei',
    'honor',
    'asus'
  ];

  static Future<void> promptIfNeeded(BuildContext context) async {
    try {
      final manufacturer =
          (await platform.invokeMethod<String>('getManufacturer'))
                  ?.toLowerCase() ??
              '';

      final needsPrompt =
          _relevantManufacturers.any((m) => manufacturer.contains(m));

      if (!needsPrompt || !context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("One more step for reliable tracking"),
          content: const Text(
            "Your phone's manufacturer restricts background apps by default. "
            "To keep live location tracking running reliably, please enable "
            "'Autostart' or 'Background activity' for Safe Pulse in the "
            "screen that opens next.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await platform.invokeMethod('openAutostartSettings');
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Fail silently — this is a best-effort nudge, not critical path
    }
  }
}

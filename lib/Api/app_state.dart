 import 'package:flutter/services.dart';

const MethodChannel platform = MethodChannel('safe_pulse/location');

Future<void> setAppState(bool isForeground) async {
  await platform.invokeMethod('isForeground', isForeground);
  
}


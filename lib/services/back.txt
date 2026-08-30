import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        // notificationChannelId: 'my_foreground',
        // initialNotificationTitle: 'Service Running',
        // initialNotificationContent: 'Starting service...',
        // foregroundServiceNotificationId: 888,
      ));
  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  log('Service is running in the background');
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  log('Service started');
  DartPluginRegistrant.ensureInitialized();
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
    service.stopSelf();
  });
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (await Permission.locationAlways.isDenied) {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await service.setForegroundNotificationInfo(
            title: "Permission Denied",
            content: "Waiting for location permission",
          );
        }
      }

      log("Waiting for location permission");
      service.invoke('update');
    } else {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await service.setForegroundNotificationInfo(
            title: "Your location",
            content: "${position.latitude},${position.longitude}",
          );
        }
      }

      log("Background service running: ${position.latitude},${position.longitude}");
      service.invoke('update');
    }
  });
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // User will start it manually
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Cognitive Memory Tracker',
      initialNotificationContent: 'Tracking active app...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), // Not used as requested Android-only
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
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

  // Track app usage every 20 seconds
  Timer.periodic(const Duration(seconds: 20), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    print("Background service: Tracking event...");

    try {
      DateTime now = DateTime.now();
      DateTime startDate = now.subtract(const Duration(minutes: 1));
      
      // Query events from the last minute
      List<EventUsageInfo> events = await UsageStats.queryEvents(startDate, now);
      
      if (events.isNotEmpty) {
        // Find the last event that is a MOVE_TO_FOREGROUND (1) or just the latest event
        // In some cases, we just want the latest active app.
        // For simplicity, we can also use queryUsageStats but queryEvents is more granular.
        
        // Sorting events by timestamp descending
        events.sort((a, b) => b.timeStamp!.compareTo(a.timeStamp!));
        
        String? foregroundApp;
        for (var event in events) {
          if (event.eventType == '1') { // 1 is MOVE_TO_FOREGROUND
            foregroundApp = event.packageName;
            break;
          }
        }
        
        // If no explicit foreground transition found in last minute, take the top one
        foregroundApp ??= events.first.packageName;

        if (foregroundApp != null && foregroundApp != "com.example.cognitive_memory_tracker") {
          final db = DatabaseHelper();
          String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
          
          await db.insertEvent({
            'app_name': foregroundApp,
            'activity': 'App active',
            'timestamp': formattedDate,
          });
          
          print("Saved event for: $foregroundApp");
          
          // Notify the UI (if alive) to refresh
          service.invoke('update');
        }
      }
    } catch (e) {
      print("Error in background tracking: $e");
    }
  });
}

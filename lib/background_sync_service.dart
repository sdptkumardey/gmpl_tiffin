// background_sync_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart'; // ✅ your existing file

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Timer? _timer;

  /// Starts background sync every few minutes
  void start() {
    // Avoid starting multiple timers
    if (_timer != null && _timer!.isActive) {
      debugPrint("⏳ BackgroundSyncService already running");
      return;
    }

    _timer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      await _runSyncTasks();
    });

    debugPrint("🚀 BackgroundSyncService started (runs every 3 min)");
  }

  /// Stops the background sync timer
  void stop() {
    _timer?.cancel();
    debugPrint("🛑 BackgroundSyncService stopped");
  }

  /// Internal method that runs both sync jobs
  Future<void> _runSyncTasks() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        debugPrint("⚠️ No internet — skipping sync");
        return;
      }

      // Run both sync operations asynchronously (non-blocking)
      final results = await Future.wait([
        SyncService.syncEmployees(),
        SyncService.syncAttendance(),
      ]);

      for (var r in results) {
        debugPrint("☁️ Sync result → $r");
      }
    } catch (e) {
      debugPrint("❌ Background sync error: $e");
    }
  }
}

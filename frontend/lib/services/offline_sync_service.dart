import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_db_service.dart';

/// Manages offline-first operation: queues mutations to SQLite and syncs
/// them to the remote API when connectivity is restored.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final LocalDbService _localDb = LocalDbService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  // Stream that emits true when all pending mutations have been synced
  final _syncedController = StreamController<bool>.broadcast();
  Stream<bool> get onSynced => _syncedController.stream;

  // ─── Connectivity Listener ──────────────────────────────────────────────

  void startListening(ApiService apiService) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        await syncPendingMutations(apiService);
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ─── Queue Helpers (SQLite-backed) ─────────────────────────────────────

  Future<void> queueAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    await _localDb.enqueueMutation(action, payload);
    debugPrint('[OfflineSync] Queued: $action');
  }

  // ─── Sync Engine ───────────────────────────────────────────────────────

  Future<bool> syncPendingMutations(ApiService apiService) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final mutations = await _localDb.getPendingMutations();
      if (mutations.isEmpty) {
        _isSyncing = false;
        return true;
      }

      debugPrint('[OfflineSync] Syncing ${mutations.length} pending mutations...');
      bool allSuccess = true;

      for (final mutation in mutations) {
        final id = mutation['id'] as int;
        final action = mutation['action'] as String;
        final payload = mutation['payload'] as Map<String, dynamic>;

        try {
          await _executeAction(apiService, action, payload);
          await _localDb.deleteMutation(id);
          debugPrint('[OfflineSync] ✅ Synced: $action');
        } catch (e) {
          await _localDb.incrementRetry(id);
          allSuccess = false;
          debugPrint('[OfflineSync] ❌ Failed ($action): $e');
        }
      }

      if (allSuccess) _syncedController.add(true);
      return allSuccess;
    } catch (e) {
      debugPrint('[OfflineSync] Sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _executeAction(
    ApiService apiService,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case 'completeTask':
        await apiService.completeTask(payload['taskId'] as String);
        break;
      case 'addTimeSlot':
        await apiService.createSlotRaw(payload);
        break;
      case 'updateTimeSlot':
        await apiService.updateSlot(
          payload['id'] as String,
          taskSelected: payload['taskSelected'] as String?,
          category: payload['category'] as String?,
          productivityType: payload['productivityType'] as String?,
        );
        break;
      case 'deleteTimeSlot':
        await apiService.deleteSlot(payload['id'] as String);
        break;
      case 'batchAddTimeSlots':
        await apiService.batchUpdateSlots(
          date: payload['date'] as String,
          timeRanges: List<String>.from(payload['timeRanges'] as List),
          taskSelected: payload['taskSelected'] as String,
          category: payload['category'] as String,
          productivityType: payload['productivityType'] as String,
        );
        break;
      default:
        debugPrint('[OfflineSync] Unknown action: $action');
    }
  }

  // ─── Daily Data Cache (SharedPreferences for analytics/summary) ────────

  static Future<void> cacheDailyData(
      DateTime date, String dataKey, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = date.toIso8601String().split('T')[0];
      await prefs.setString('daily_${dataKey}_$dateStr', jsonEncode(data));
    } catch (e) {
      debugPrint('[OfflineSync] Cache write error: $e');
    }
  }

  static Future<dynamic> getOfflineDailyData(
      DateTime date, String dataKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = date.toIso8601String().split('T')[0];
      final raw = prefs.getString('daily_${dataKey}_$dateStr');
      if (raw != null) return jsonDecode(raw);
    } catch (e) {
      debugPrint('[OfflineSync] Cache read error: $e');
    }
    return null;
  }

  Future<int> getPendingCount() => _localDb.pendingMutationCount();

  void dispose() {
    stopListening();
    _syncedController.close();
  }
}

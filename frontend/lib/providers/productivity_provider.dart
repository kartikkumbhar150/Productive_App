import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/task.dart';
import '../models/time_slot.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/local_db_service.dart';

class ProductivityProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final OfflineSyncService _syncService = OfflineSyncService();
  final LocalDbService _localDb = LocalDbService();

  List<Task> _tasks = [];
  List<TimeSlot> _slots = [];
  List<String> _categories = [
    'Study', 'DSA', 'Work', 'Gym', 'Sleep', 'Social Media', 'Gaming', 'Rest', 'Other'
  ];
  bool _isLoading = false;
  bool _isBackgroundRefreshing = false;
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  String? _error;

  // Analytics
  Map<String, dynamic> _categoryBreakdown = {};
  Map<String, dynamic> _taskBreakdown = {};
  Map<String, dynamic> _productivityByCategory = {};
  String _aiInsights = '';
  double _productivityPercentage = 0;
  int _productivityIndex = 0;
  int _totalMinutes = 0;
  int _productiveMinutes = 0;
  int _wastedMinutes = 0;
  int _neutralMinutes = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;

  // Weekly trend
  List<Map<String, dynamic>> _weeklyTrend = [];
  List<Map<String, dynamic>> _cumulativeFocus = [];
  bool _weeklyTrendLoaded = false;

  // AI Insights
  Map<String, dynamic> _aiInsightsData = {};
  bool _aiInsightsLoaded = false;

  // Heatmap
  Map<String, dynamic> _heatmapData = {};
  bool _heatmapLoaded = false;

  // Periodic sync timer
  Timer? _syncTimer;

  // Getters
  List<Task> get tasks => _tasks;
  List<TimeSlot> get slots => _slots;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isBackgroundRefreshing => _isBackgroundRefreshing;
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  String? get error => _error;
  Map<String, dynamic> get categoryBreakdown => _categoryBreakdown;
  Map<String, dynamic> get taskBreakdown => _taskBreakdown;
  Map<String, dynamic> get productivityByCategory => _productivityByCategory;
  String get aiInsights => _aiInsights;
  double get productivityPercentage => _productivityPercentage;
  int get productivityIndex => _productivityIndex;
  int get totalMinutes => _totalMinutes;
  int get productiveMinutes => _productiveMinutes;
  int get wastedMinutes => _wastedMinutes;
  int get neutralMinutes => _neutralMinutes;
  int get totalTasks => _totalTasks;
  int get completedTasks => _completedTasks;
  List<Map<String, dynamic>> get weeklyTrend => _weeklyTrend;
  List<Map<String, dynamic>> get cumulativeFocus => _cumulativeFocus;
  bool get weeklyTrendLoaded => _weeklyTrendLoaded;
  Map<String, dynamic> get aiInsightsData => _aiInsightsData;
  bool get aiInsightsLoaded => _aiInsightsLoaded;
  Map<String, dynamic> get heatmapData => _heatmapData;
  bool get heatmapLoaded => _heatmapLoaded;

  // ─── Initialization ─────────────────────────────────────────────────────

  void init() {
    _syncService.startListening(_apiService);
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _refreshPendingCount();
      if (_isOnline) {
        await _syncService.syncPendingMutations(_apiService);
      }
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = _resultsAreOnline(result);
    _pendingSyncCount = await _syncService.getPendingCount();
    notifyListeners();
  }

  Future<void> _refreshPendingCount() async {
    final count = await _syncService.getPendingCount();
    if (count != _pendingSyncCount) {
      _pendingSyncCount = count;
      notifyListeners();
    }
  }

  bool _resultsAreOnline(dynamic result) {
    if (result is List) {
      return result.any((r) => r != ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  Future<bool> _isOffline() async {
    final result = await Connectivity().checkConnectivity();
    final online = _resultsAreOnline(result);
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
    return !online;
  }

  // ─── Load Daily Data ─────────────────────────────────────────────────────

  Future<void> loadDailyData(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];

    // 1. Serve from SQLite immediately
    final localSlots = await _localDb.getTimeSlotsByDate(dateStr);
    final localTasks = await _localDb.getTasksByDate(dateStr);
    if (localSlots.isNotEmpty || localTasks.isNotEmpty) {
      _slots = localSlots;
      _tasks = localTasks;
      _isBackgroundRefreshing = true;
      _isLoading = false;
      notifyListeners();
    } else {
      // Fall back to SharedPreferences cache
      final cachedSlotsRaw =
          await OfflineSyncService.getOfflineDailyData(date, 'slots');
      final cachedTasksRaw =
          await OfflineSyncService.getOfflineDailyData(date, 'tasks');
      if (cachedSlotsRaw != null) {
        _slots =
            (cachedSlotsRaw as List).map((e) => TimeSlot.fromJson(e)).toList();
      }
      if (cachedTasksRaw != null) {
        _tasks =
            (cachedTasksRaw as List).map((e) => Task.fromJson(e)).toList();
      }
      _isLoading = _slots.isEmpty && _tasks.isEmpty;
      _isBackgroundRefreshing = !_isLoading;
      notifyListeners();
    }

    _error = null;

    try {
      final offline = await _isOffline();
      if (!offline) {
        // Sync pending mutations first
        await _syncService.syncPendingMutations(_apiService);
        // Then fetch fresh data
        _tasks = await _apiService.getTasks(date);
        _slots = await _apiService.getTimeSlots(date);

        // Persist to SQLite
        for (final slot in _slots) {
          await _localDb.upsertTimeSlot(slot);
        }
        for (final task in _tasks) {
          await _localDb.upsertTask(task);
        }

        // Also cache for analytics
        await OfflineSyncService.cacheDailyData(
            date, 'tasks', _tasks.map((t) => t.toJson()).toList());
        await OfflineSyncService.cacheDailyData(
            date, 'slots', _slots.map((s) => s.toJson()).toList());

        // Categories
        try {
          _categories = await _apiService.getCategories();
        } catch (e) {
          debugPrint('Using default categories: $e');
        }

        // Analytics
        try {
          final analytics = await _apiService.getAnalytics('day', date: date);
          _totalMinutes = _parseInt(analytics['totalMinutes']);
          _productiveMinutes = _parseInt(analytics['productiveMinutes']);
          _wastedMinutes = _parseInt(analytics['wastedMinutes']);
          _neutralMinutes = _parseInt(analytics['neutralMinutes']);
          _productivityPercentage =
              double.tryParse(analytics['productivityPercentage']?.toString() ?? '0') ?? 0;
          _productivityIndex = _parseInt(analytics['productivityIndex']);
          _totalTasks = _parseInt(analytics['totalTasks']);
          _completedTasks = _parseInt(analytics['completedTasks']);
          _categoryBreakdown =
              Map<String, dynamic>.from(analytics['categoryBreakdown'] ?? {});
          _taskBreakdown =
              Map<String, dynamic>.from(analytics['taskBreakdown'] ?? {});
          _productivityByCategory =
              Map<String, dynamic>.from(analytics['productivityByCategory'] ?? {});
          _aiInsights = analytics['insights']?.toString() ?? '';
        } catch (e) {
          debugPrint('Analytics fetch failed: $e');
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load data: $e');
    }

    _isLoading = false;
    _isBackgroundRefreshing = false;
    _pendingSyncCount = await _syncService.getPendingCount();
    notifyListeners();
  }

  // ─── Weekly Trend ────────────────────────────────────────────────────────

  Future<void> loadWeeklyTrend({DateTime? date}) async {
    try {
      final data = await _apiService.getWeeklyTrend(date: date);
      _weeklyTrend =
          List<Map<String, dynamic>>.from(data['trend'] ?? []);
      _cumulativeFocus =
          List<Map<String, dynamic>>.from(data['cumulativeFocus'] ?? []);
      _weeklyTrendLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Weekly trend failed: $e');
    }
  }

  Future<void> loadAIInsights() async {
    try {
      _aiInsightsData = await _apiService.getAIInsights();
      _aiInsightsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AI insights failed: $e');
    }
  }

  Future<void> loadHeatmap({int? month, int? year}) async {
    try {
      _heatmapData =
          await _apiService.getHeatmapData(month: month, year: year);
      _heatmapLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Heatmap failed: $e');
    }
  }

  // ─── Tasks ───────────────────────────────────────────────────────────────

  Future<void> addTask(String name, DateTime date) async {
    final now = DateTime.now();
    final cleanDate = DateTime(now.year, now.month, now.day, 12, 0, 0);
    final newTask = Task(taskName: name, date: cleanDate.toIso8601String());

    try {
      final created = await _apiService.createTask(newTask);
      _tasks.add(created);
      await _localDb.upsertTask(created);
      notifyListeners();
    } catch (e) {
      // Optimistically add with temp id
      final temp = Task(
        id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
        taskName: name,
        date: cleanDate.toIso8601String(),
      );
      _tasks.add(temp);
      await _localDb.upsertTask(temp, isSynced: false);
      notifyListeners();
      debugPrint('Failed to create task online, saved locally: $e');
    }
  }

  Future<void> completeTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      final updated = Task(
        id: task.id,
        taskName: task.taskName,
        date: task.date,
        isCompleted: true,
      );
      _tasks[index] = updated;
      await _localDb.upsertTask(updated);
      notifyListeners();

      try {
        final offline = await _isOffline();
        if (offline) {
          await _syncService.queueAction('completeTask', {'taskId': task.id});
        } else {
          await _apiService.completeTask(task.id!);
        }
      } catch (e) {
        await _syncService.queueAction('completeTask', {'taskId': task.id});
        debugPrint('Queued completeTask: $e');
      }
      await _refreshPendingCount();
    }
  }

  // ─── Time Slots ──────────────────────────────────────────────────────────

  Future<void> addTimeSlot(TimeSlot slot) async {
    // Optimistic update — replace existing slot for the same timeRange
    _slots.removeWhere((s) => s.timeRange == slot.timeRange);
    _slots.add(slot);
    notifyListeners();

    // Persist locally with temp id
    final tempId = 'tmp_${slot.timeRange}_${DateTime.now().millisecondsSinceEpoch}';
    final localSlot = TimeSlot(
      id: tempId,
      date: slot.date,
      timeRange: slot.timeRange,
      taskSelected: slot.taskSelected,
      category: slot.category,
      type: slot.type,
    );
    await _localDb.upsertTimeSlot(localSlot, isSynced: false);

    try {
      final offline = await _isOffline();
      if (offline) {
        await _syncService.queueAction('addTimeSlot', slot.toJson());
      } else {
        final created = await _apiService.createSlot(slot);
        // Replace the temp slot with the real one
        final idx = _slots.indexWhere((s) => s.timeRange == slot.timeRange);
        if (idx >= 0) _slots[idx] = created;
        await _localDb.upsertTimeSlot(created);
        notifyListeners();
      }
    } catch (e) {
      await _syncService.queueAction('addTimeSlot', slot.toJson());
      debugPrint('Queued addTimeSlot: $e');
    }
    await _refreshPendingCount();
  }

  /// Update a time slot in-place — NO page reload.
  Future<void> updateTimeSlot(
    String id, {
    String? taskSelected,
    String? category,
    String? productivityType,
  }) async {
    // Optimistic in-place update
    final index = _slots.indexWhere((s) => s.id == id);
    if (index >= 0) {
      final old = _slots[index];
      final typeEnum = productivityType != null
          ? ProductivityType.values.firstWhere(
              (e) => e.name.toLowerCase() == productivityType.toLowerCase(),
              orElse: () => old.type)
          : old.type;
      final updated = TimeSlot(
        id: id,
        date: old.date,
        timeRange: old.timeRange,
        taskSelected: taskSelected ?? old.taskSelected,
        category: category ?? old.category,
        type: typeEnum,
      );
      _slots[index] = updated;
      await _localDb.upsertTimeSlot(updated);
      notifyListeners(); // ← UI updates immediately, NO reload
    }

    try {
      final offline = await _isOffline();
      if (offline) {
        await _syncService.queueAction('updateTimeSlot', {
          'id': id,
          'taskSelected': taskSelected,
          'category': category,
          'productivityType': productivityType,
        });
      } else {
        final remote = await _apiService.updateSlot(id,
            taskSelected: taskSelected,
            category: category,
            productivityType: productivityType);
        final idx = _slots.indexWhere((s) => s.id == id);
        if (idx >= 0) {
          _slots[idx] = remote;
          await _localDb.upsertTimeSlot(remote);
        }
        notifyListeners();
      }
    } catch (e) {
      await _syncService.queueAction('updateTimeSlot', {
        'id': id,
        'taskSelected': taskSelected,
        'category': category,
        'productivityType': productivityType,
      });
      debugPrint('Queued updateTimeSlot: $e');
    }
    await _refreshPendingCount();
  }

  Future<void> deleteTimeSlot(String id) async {
    _slots.removeWhere((s) => s.id == id);
    await _localDb.deleteLocalTimeSlot(id);
    notifyListeners();

    try {
      final offline = await _isOffline();
      if (offline) {
        await _syncService.queueAction('deleteTimeSlot', {'id': id});
      } else {
        await _apiService.deleteSlot(id);
      }
    } catch (e) {
      await _syncService.queueAction('deleteTimeSlot', {'id': id});
      debugPrint('Queued deleteTimeSlot: $e');
    }
    await _refreshPendingCount();
  }

  /// Batch-assign task to multiple time ranges optimistically.
  Future<void> addBatchTimeSlots({
    required List<String> timeRanges,
    required String taskSelected,
    required String category,
    required ProductivityType type,
  }) async {
    final now = DateTime.now();
    final cleanDate = DateTime(now.year, now.month, now.day, 12, 0, 0);
    final dateStr = cleanDate.toIso8601String();

    // Optimistic update for all ranges
    for (final range in timeRanges) {
      _slots.removeWhere((s) => s.timeRange == range);
      final slot = TimeSlot(
        id: 'tmp_${range}_${DateTime.now().millisecondsSinceEpoch}',
        date: dateStr,
        timeRange: range,
        taskSelected: taskSelected,
        category: category,
        type: type,
      );
      _slots.add(slot);
      await _localDb.upsertTimeSlot(slot, isSynced: false);
    }
    notifyListeners();

    final typeName = type.name[0].toUpperCase() + type.name.substring(1);

    try {
      final offline = await _isOffline();
      if (offline) {
        await _syncService.queueAction('batchAddTimeSlots', {
          'date': dateStr,
          'timeRanges': timeRanges,
          'taskSelected': taskSelected,
          'category': category,
          'productivityType': typeName,
        });
      } else {
        final created = await _apiService.batchUpdateSlots(
          date: dateStr,
          timeRanges: timeRanges,
          taskSelected: taskSelected,
          category: category,
          productivityType: typeName,
        );
        // Replace temp slots with real ones
        for (final real in created) {
          final idx = _slots.indexWhere((s) => s.timeRange == real.timeRange);
          if (idx >= 0) {
            _slots[idx] = real;
            await _localDb.upsertTimeSlot(real);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      await _syncService.queueAction('batchAddTimeSlots', {
        'date': dateStr,
        'timeRanges': timeRanges,
        'taskSelected': taskSelected,
        'category': category,
        'productivityType': typeName,
      });
      debugPrint('Queued batchAddTimeSlots: $e');
    }
    await _refreshPendingCount();
  }

  // ─── Categories ──────────────────────────────────────────────────────────

  Future<void> addCategory(String category) async {
    if (category.trim().isEmpty) return;
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
      try {
        await _apiService.updateCategories(_categories);
      } catch (e) {
        _categories.remove(category);
        notifyListeners();
      }
    }
  }

  Future<void> removeCategory(String category) async {
    if (_categories.contains(category)) {
      final old = List<String>.from(_categories);
      _categories.remove(category);
      notifyListeners();
      try {
        await _apiService.updateCategories(_categories);
      } catch (e) {
        _categories = old;
        notifyListeners();
      }
    }
  }

  // ─── Cleanup ─────────────────────────────────────────────────────────────

  void clearData() {
    _tasks = [];
    _slots = [];
    _categoryBreakdown = {};
    _taskBreakdown = {};
    _productivityByCategory = {};
    _aiInsights = '';
    _productivityPercentage = 0;
    _productivityIndex = 0;
    _totalMinutes = 0;
    _productiveMinutes = 0;
    _wastedMinutes = 0;
    _neutralMinutes = 0;
    _totalTasks = 0;
    _completedTasks = 0;
    _weeklyTrend = [];
    _cumulativeFocus = [];
    _weeklyTrendLoaded = false;
    _aiInsightsData = {};
    _aiInsightsLoaded = false;
    _heatmapData = {};
    _heatmapLoaded = false;
    _error = null;
    _syncTimer?.cancel();
    _syncService.stopListening();
    notifyListeners();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

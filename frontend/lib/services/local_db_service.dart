import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/time_slot.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (!kIsWeb) {
      _db = await _initDb();
    }
    if (_db == null) throw Exception('SQLite not available on Web');
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'productivity_v2.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        taskName TEXT NOT NULL,
        date TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE time_slots (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        timeRange TEXT NOT NULL,
        taskSelected TEXT,
        category TEXT,
        productivityType TEXT,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_mutations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        retries INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_slots_date ON time_slots(date)');
    await db.execute('CREATE INDEX idx_tasks_date ON tasks(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add is_synced columns if upgrading from v1
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE time_slots ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_mutations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          payload TEXT NOT NULL,
          retries INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ─── Pending Mutations Queue ──────────────────────────────────────────────

  Future<void> enqueueMutation(String action, Map<String, dynamic> payload) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('pending_mutations', {
      'action': action,
      'payload': jsonEncode(payload),
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    debugPrint('[SQLite] Queued mutation: $action');
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    if (kIsWeb) return [];
    final db = await database;
    final rows = await db.query(
      'pending_mutations',
      where: 'retries < ?',
      whereArgs: [4], // Skip after 3 failed retries
      orderBy: 'id ASC',
    );
    return rows.map((r) => {
      'id': r['id'],
      'action': r['action'] as String,
      'payload': jsonDecode(r['payload'] as String) as Map<String, dynamic>,
      'retries': r['retries'] as int,
    }).toList();
  }

  Future<void> incrementRetry(int mutationId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_mutations SET retries = retries + 1 WHERE id = ?',
      [mutationId],
    );
  }

  Future<void> deleteMutation(int mutationId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('pending_mutations', where: 'id = ?', whereArgs: [mutationId]);
  }

  Future<int> pendingMutationCount() async {
    if (kIsWeb) return 0;
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_mutations WHERE retries < 4');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ─── Time Slots ───────────────────────────────────────────────────────────

  Future<void> upsertTimeSlot(TimeSlot slot, {bool isSynced = true}) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('time_slots', {
      'id': slot.id ?? '${slot.timeRange}_${DateTime.now().millisecondsSinceEpoch}',
      'date': slot.date,
      'timeRange': slot.timeRange,
      'taskSelected': slot.taskSelected,
      'category': slot.category,
      'productivityType': slot.type.name,
      'is_synced': isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLocalSlotId(String tempId, String realId) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'time_slots',
      {'id': realId, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [tempId],
    );
  }

  Future<void> deleteLocalTimeSlot(String id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('time_slots', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TimeSlot>> getTimeSlotsByDate(String dateStr) async {
    if (kIsWeb) return [];
    final db = await database;
    // Match date prefix (YYYY-MM-DD)
    final prefix = dateStr.substring(0, 10);
    final rows = await db.query(
      'time_slots',
      where: "date LIKE ?",
      whereArgs: ['$prefix%'],
      orderBy: 'timeRange ASC',
    );
    return rows.map(_rowToTimeSlot).toList();
  }

  TimeSlot _rowToTimeSlot(Map<String, dynamic> m) => TimeSlot(
    id: m['id'] as String?,
    date: m['date'] as String,
    timeRange: m['timeRange'] as String,
    taskSelected: m['taskSelected'] as String? ?? '',
    category: m['category'] as String? ?? 'Other',
    type: ProductivityType.values.firstWhere(
      (e) => e.name == (m['productivityType'] as String? ?? 'neutral'),
      orElse: () => ProductivityType.neutral,
    ),
  );

  // ─── Tasks ────────────────────────────────────────────────────────────────

  Future<void> upsertTask(Task task, {bool isSynced = true}) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('tasks', {
      'id': task.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'taskName': task.taskName,
      'date': task.date,
      'isCompleted': task.isCompleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Task>> getTasksByDate(String dateStr) async {
    if (kIsWeb) return [];
    final db = await database;
    final prefix = dateStr.substring(0, 10);
    final rows = await db.query(
      'tasks',
      where: "date LIKE ?",
      whereArgs: ['$prefix%'],
      orderBy: 'taskName ASC',
    );
    return rows.map((m) => Task(
      id: m['id'] as String?,
      taskName: m['taskName'] as String,
      date: m['date'] as String,
      isCompleted: (m['isCompleted'] as int) == 1,
    )).toList();
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  Future<void> clearOldData({int keepDays = 7}) async {
    if (kIsWeb) return;
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffStr = cutoff.toIso8601String().substring(0, 10);
    await db.delete('time_slots', where: "date < ? AND is_synced = 1", whereArgs: ['$cutoffStr%']);
    await db.delete('tasks', where: "date < ? AND is_synced = 1", whereArgs: ['$cutoffStr%']);
  }
}

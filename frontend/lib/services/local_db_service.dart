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
    return _db ?? throw Exception('Web mock');
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'productivity.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            taskName TEXT,
            date TEXT,
            isCompleted INTEGER
          )
        ''');
        
        await db.execute('''
          CREATE TABLE time_slots (
            id TEXT PRIMARY KEY,
            date TEXT,
            timeRange TEXT,
            taskSelected TEXT,
            category TEXT,
            productivityType TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveTask(Task task) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('tasks', {
      'id': task.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'taskName': task.taskName,
      'date': task.date,
      'isCompleted': task.isCompleted ? 1 : 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Task>> getPendingLocalTasks() async {
    if (kIsWeb) return [];
    final db = await database;
    final res = await db.query('tasks', where: 'isCompleted = ?', whereArgs: [0]);
    return res.map((m) => Task(
      id: m['id'] as String,
      taskName: m['taskName'] as String,
      date: m['date'] as String,
      isCompleted: (m['isCompleted'] as int) == 1,
    )).toList();
  }

  Future<void> saveTimeSlot(TimeSlot slot) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('time_slots', {
      'id': slot.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'date': slot.date,
      'timeRange': slot.timeRange,
      'taskSelected': slot.taskSelected,
      'category': slot.category,
      'productivityType': slot.type.toString().split('.').last,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TimeSlot>> getLocalTimeSlots() async {
    if (kIsWeb) return [];
    final db = await database;
    final res = await db.query('time_slots');
    return res.map((m) => TimeSlot(
      id: m['id'] as String,
      date: m['date'] as String,
      timeRange: m['timeRange'] as String,
      taskSelected: m['taskSelected'] as String,
      category: m['category'] as String,
      type: ProductivityType.values.firstWhere(
        (e) => e.toString().split('.').last == m['productivityType'] as String,
        orElse: () => ProductivityType.neutral
      ),
    )).toList();
  }
}

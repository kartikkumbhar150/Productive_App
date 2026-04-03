import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/time_slot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';

class ApiService {
  String get baseUrl => ApiConfig.baseUrl;

  static const _timeout = Duration(seconds: 10);

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  DateTime _cleanDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, 12, 0, 0);

  // ─── AUTH ───────────────────────────────────────────────

  Future<Map<String, dynamic>> registerWithEmail(
      String name, String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(_timeout);
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      await prefs.setString('user_name', data['name']);
      await prefs.setString('user_email', data['email']);
      return data;
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> loginWithEmail(
      String email, String password) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      await prefs.setString('user_name', data['name']);
      await prefs.setString('user_email', data['email']);
      return data;
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['message'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }

  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── PROFILE ────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http
        .get(Uri.parse('$baseUrl/users/profile'), headers: await _getHeaders())
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch profile');
  }

  Future<Map<String, dynamic>> updateProfile(
      {String? name, String? profilePhoto}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profilePhoto != null) body['profilePhoto'] = profilePhoto;

    final res = await http
        .put(
          Uri.parse('$baseUrl/users/profile'),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', data['name']);
      return data;
    }
    throw Exception('Failed to update profile');
  }

  // ─── TASKS ──────────────────────────────────────────────

  Future<List<Task>> getTasks(DateTime date) async {
    final cleanDate = _cleanDate(date);
    final res = await http
        .get(
          Uri.parse('$baseUrl/tasks?date=${cleanDate.toIso8601String()}'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => Task.fromJson(json)).toList();
    }
    throw Exception('Failed to load tasks');
  }

  Future<Task> createTask(Task task) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/tasks'),
          headers: await _getHeaders(),
          body: jsonEncode(task.toJson()),
        )
        .timeout(_timeout);
    if (res.statusCode == 201) return Task.fromJson(jsonDecode(res.body));
    throw Exception('Failed to create task');
  }

  Future<void> completeTask(String id) async {
    final res = await http
        .put(
          Uri.parse('$baseUrl/tasks/$id/complete'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Failed to complete task');
  }

  // ─── TIME SLOTS ─────────────────────────────────────────

  Future<List<TimeSlot>> getTimeSlots(DateTime date) async {
    final cleanDate = _cleanDate(date);
    final res = await http
        .get(
          Uri.parse('$baseUrl/slots?date=${cleanDate.toIso8601String()}'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => TimeSlot.fromJson(json)).toList();
    }
    throw Exception('Failed to load slots');
  }

  Future<TimeSlot> createSlot(TimeSlot slot) async {
    final headers = await _getHeaders();
    final body = jsonEncode(slot.toJson());
    final res = await http
        .post(
          Uri.parse('$baseUrl/slots'),
          headers: headers,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return TimeSlot.fromJson(jsonDecode(res.body));
    }
    throw Exception(
        'Failed to create time slot (${res.statusCode}): ${res.body}');
  }

  Future<void> createSlotRaw(Map<String, dynamic> payload) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/slots'),
          headers: await _getHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to create slot raw (${res.statusCode})');
    }
  }

  Future<TimeSlot> updateSlot(String id,
      {String? taskSelected,
      String? category,
      String? productivityType}) async {
    final body = <String, dynamic>{};
    if (taskSelected != null) body['taskSelected'] = taskSelected;
    if (category != null) body['category'] = category;
    if (productivityType != null) body['productivityType'] = productivityType;

    final res = await http
        .put(
          Uri.parse('$baseUrl/slots/$id'),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return TimeSlot.fromJson(jsonDecode(res.body));
    throw Exception('Failed to update time slot (${res.statusCode})');
  }

  Future<void> deleteSlot(String id) async {
    final res = await http
        .delete(
          Uri.parse('$baseUrl/slots/$id'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Failed to delete time slot');
  }

  /// Batch-assign task/category to multiple time ranges at once.
  Future<List<TimeSlot>> batchUpdateSlots({
    required String date,
    required List<String> timeRanges,
    required String taskSelected,
    required String category,
    required String productivityType,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$baseUrl/slots/batch'),
          headers: await _getHeaders(),
          body: jsonEncode({
            'date': date,
            'timeRanges': timeRanges,
            'taskSelected': taskSelected,
            'category': category,
            'productivityType': productivityType,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((j) => TimeSlot.fromJson(j)).toList();
    }
    throw Exception('Batch update failed (${res.statusCode})');
  }

  // ─── CATEGORIES ─────────────────────────────────────────

  Future<List<String>> getCategories() async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/users/categories'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<void> updateCategories(List<String> categories) async {
    final res = await http
        .put(
          Uri.parse('$baseUrl/users/categories'),
          headers: await _getHeaders(),
          body: jsonEncode({'categories': categories}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Failed to update categories');
  }

  // ─── ANALYTICS ──────────────────────────────────────────

  Future<Map<String, dynamic>> getAnalytics(String period,
      {DateTime? date}) async {
    final queryDate = date ?? DateTime.now();
    final cleanDate = _cleanDate(queryDate);
    final res = await http
        .get(
          Uri.parse(
              '$baseUrl/analytics/$period?date=${cleanDate.toIso8601String()}'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch analytics');
  }

  Future<Map<String, dynamic>> getWeeklyTrend({DateTime? date}) async {
    final queryDate = date ?? DateTime.now();
    final cleanDate = _cleanDate(queryDate);
    final res = await http
        .get(
          Uri.parse(
              '$baseUrl/analytics/weekly-trend?date=${cleanDate.toIso8601String()}'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch weekly trend');
  }

  Future<Map<String, dynamic>> getHeatmapData(
      {int? month, int? year}) async {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final res = await http
        .get(
          Uri.parse('$baseUrl/analytics/heatmap?month=$m&year=$y'),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch heatmap');
  }

  // ─── AI INSIGHTS ────────────────────────────────────────

  Future<Map<String, dynamic>> getAIInsights() async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/ai/insights'),
          headers: await _getHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch AI insights');
  }

  // ─── REPORTS ───────────────────────────────────────────

  Future<Map<String, dynamic>> getReport(
      DateTime startDate, DateTime endDate) async {
    final res = await http
        .get(
          Uri.parse(
            '$baseUrl/reports?startDate=${startDate.toIso8601String()}&endDate=${endDate.toIso8601String()}',
          ),
          headers: await _getHeaders(),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch report');
  }
}

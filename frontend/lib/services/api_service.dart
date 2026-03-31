import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/time_slot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';

class ApiService {
  String get baseUrl => ApiConfig.baseUrl;

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

  // ─── AUTH ───────────────────────────────────────────────

  Future<Map<String, dynamic>> registerWithEmail(String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
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

  Future<Map<String, dynamic>> loginWithEmail(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
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
    final res = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to fetch profile');
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? profilePhoto}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profilePhoto != null) body['profilePhoto'] = profilePhoto;

    final res = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
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
    final res = await http.get(
      Uri.parse('$baseUrl/tasks?date=${date.toIso8601String()}'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => Task.fromJson(json)).toList();
    }
    throw Exception('Failed to load tasks');
  }

  Future<Task> createTask(Task task) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: await _getHeaders(),
      body: jsonEncode(task.toJson()),
    );
    if (res.statusCode == 201) return Task.fromJson(jsonDecode(res.body));
    throw Exception('Failed to create task');
  }

  Future<void> completeTask(String id) async {
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/$id/complete'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to complete task');
  }

  // ─── TIME SLOTS ─────────────────────────────────────────

  Future<List<TimeSlot>> getTimeSlots(DateTime date) async {
    final res = await http.get(
      Uri.parse('$baseUrl/slots?date=${date.toIso8601String()}'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => TimeSlot.fromJson(json)).toList();
    }
    throw Exception('Failed to load slots');
  }

  Future<TimeSlot> createSlot(TimeSlot slot) async {
    final res = await http.post(
      Uri.parse('$baseUrl/slots'),
      headers: await _getHeaders(),
      body: jsonEncode(slot.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return TimeSlot.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create time slot');
  }

  Future<TimeSlot> updateSlot(String id, {String? taskSelected, String? category, String? productivityType}) async {
    final body = <String, dynamic>{};
    if (taskSelected != null) body['taskSelected'] = taskSelected;
    if (category != null) body['category'] = category;
    if (productivityType != null) body['productivityType'] = productivityType;

    final res = await http.put(
      Uri.parse('$baseUrl/slots/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return TimeSlot.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update time slot');
  }

  Future<void> deleteSlot(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/slots/$id'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete time slot');
    }
  }

  // ─── CATEGORIES ─────────────────────────────────────────

  Future<List<String>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/categories'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<void> updateCategories(List<String> categories) async {
    final res = await http.put(
      Uri.parse('$baseUrl/users/categories'),
      headers: await _getHeaders(),
      body: jsonEncode({'categories': categories}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update categories');
    }
  }

  // ─── ANALYTICS ──────────────────────────────────────────

  Future<Map<String, dynamic>> getAnalytics(String period, {DateTime? date}) async {
    final queryDate = date ?? DateTime.now();
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/$period?date=${queryDate.toIso8601String()}'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to fetch analytics');
  }
}

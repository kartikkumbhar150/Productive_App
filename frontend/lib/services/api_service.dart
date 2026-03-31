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

  Future<void> loginWithGoogle(String idToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
    } else {
      throw Exception('Failed to sign in via Google');
    }
  }

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
    // Note: No edit/delete API mapping, ensuring immutability
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/$id/complete'),
      headers: await _getHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to complete task');
  }

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

  Future<void> syncSlots(List<TimeSlot> slots) async {
    // Loops over local slots and sends them to server sequentially or via batching...
    for (var slot in slots) {
      await http.post(
        Uri.parse('$baseUrl/slots'),
        headers: await _getHeaders(),
        body: jsonEncode(slot.toJson()),
      );
    }
  }

  Future<Map<String, dynamic>> getAnalytics(String period) async {
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/$period'),
      headers: await _getHeaders(),
    );
     if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to fetch analytics');
  }
}

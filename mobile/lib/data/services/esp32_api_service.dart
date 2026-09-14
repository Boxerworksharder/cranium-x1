import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/device_status.dart';
import '../models/task_item.dart';
import '../models/reminder_item.dart';
import '../../core/constants/app_constants.dart';

class Esp32ApiService {
  String _host;
  final http.Client _client;

  Esp32ApiService({
    String host = AppConstants.defaultEspIp,
    http.Client? client,
  })  : _host = host,
        _client = client ?? http.Client();

  String get host => _host;

  set host(String newHost) {
    _host = newHost.trim().replaceAll('http://', '').replaceAll('https://', '');
    if (_host.endsWith('/')) {
      _host = _host.substring(0, _host.length - 1);
    }
  }

  Uri _uri(String path) {
    return Uri.parse('http://$_host$path');
  }

  Future<bool> testConnection() async {
    try {
      final res = await _client
          .get(_uri(AppConstants.epStatus))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceStatus> fetchStatus() async {
    final res = await _client
        .get(_uri(AppConstants.epStatus))
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return DeviceStatus.fromJson(data);
    } else {
      throw Exception('Failed to fetch status (HTTP ${res.statusCode})');
    }
  }

  Future<List<TaskItem>> fetchTasks() async {
    final res = await _client
        .get(_uri(AppConstants.epTasks))
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((t) => TaskItem.fromJson(t as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch tasks (HTTP ${res.statusCode})');
    }
  }

  Future<int?> addTask(String text, int stars) async {
    final res = await _client
        .post(
          _uri(AppConstants.epTaskAdd),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'stars': stars}),
        )
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id'] as int?;
    }
    return null;
  }

  Future<bool> toggleTask(int id) async {
    final res = await _client
        .post(
          _uri(AppConstants.epTaskToggle),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 4));

    return res.statusCode == 200;
  }

  Future<bool> deleteTask(int id) async {
    final res = await _client
        .post(
          _uri(AppConstants.epTaskDelete),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 4));

    return res.statusCode == 200;
  }

  Future<bool> updateTask(int id, {String? text, int? stars, bool? done}) async {
    try {
      final payload = <String, dynamic>{'id': id};
      if (text != null) payload['text'] = text;
      if (stars != null) payload['stars'] = stars.clamp(1, 3);
      if (done != null) payload['done'] = done;

      final res = await _client
          .post(
            _uri(AppConstants.epTaskUpdate),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<ReminderItem>> fetchReminders() async {
    final res = await _client
        .get(_uri(AppConstants.epReminders))
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((r) => ReminderItem.fromJson(r as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch reminders (HTTP ${res.statusCode})');
    }
  }

  Future<int?> addReminder(String text) async {
    final res = await _client
        .post(
          _uri(AppConstants.epReminderAdd),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 4));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id'] as int?;
    }
    return null;
  }

  Future<bool> deleteReminder(int id) async {
    final res = await _client
        .post(
          _uri(AppConstants.epReminderDelete),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 4));

    return res.statusCode == 200;
  }

  Future<bool> updateReminder(int id, String text) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epReminderUpdate),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id, 'text': text}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<int?> addSection(String name, {bool isNegative = false}) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epClientAdd),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'isNegative': isNegative}),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['id'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateSectionNegative(int id, bool isNegative) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epClientUpdate),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id, 'isNegative': isNegative}),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSection(int id) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epClientDelete),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> selectSection(int clientId) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'select', 'id': clientId}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startSession(int clientId) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'start', 'id': clientId}),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseSession() async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'pause'}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resumeSession() async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'resume'}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopSession() async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'stop'}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> triggerStressBuster() async {
    try {
      final res = await _client
          .post(
            _uri('/api/stress_buster'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> adjustRep({required bool increment}) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epAction),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': increment ? 'rep_plus' : 'rep_minus'}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBrightness(int brightness) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epBrightness),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'level': brightness}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetAll() async {
    try {
      final res = await _client
          .post(
            _uri('/api/reset'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreBackup(String jsonPayload) async {
    try {
      final res = await _client
          .post(
            _uri('/api/restore.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonPayload,
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] restoreBackup error: $e');
      return false;
    }
  }

  Future<String?> getBackupJson() async {
    try {
      final res = await _client.get(_uri('/api/backup.json')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return res.body;
      }
    } catch (e) {
      debugPrint('[API] getBackupJson error: $e');
    }
    return null;
  }

  Future<bool> updateWellness({
    bool? enabled,
    int? interval,
    int? mode,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (enabled != null) body['enabled'] = enabled;
      if (interval != null) body['interval'] = interval;
      if (mode != null) body['mode'] = mode;

      final res = await _client
          .post(
            _uri(AppConstants.epWellness),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] updateWellness error: $e');
      return false;
    }
  }

  Future<bool> testWellnessAlert({int kind = 0}) async {
    try {
      final res = await _client
          .post(
            _uri(AppConstants.epWellnessTest),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'kind': kind}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] testWellnessAlert error: $e');
      return false;
    }
  }

  Future<bool> setPowerBankKeepAlive(bool enabled) async {
    try {
      final res = await _client
          .post(
            _uri('/api/powerbank'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'powerbank': enabled}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] setPowerBankKeepAlive error: $e');
      return false;
    }
  }

  Future<bool> syncTime(int epochSeconds) async {
    try {
      final res = await _client
          .post(
            _uri('/api/time'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'epoch': epochSeconds}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[API] syncTime error: $e');
      return false;
    }
  }
}

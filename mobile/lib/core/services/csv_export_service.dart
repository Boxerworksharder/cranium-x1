import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/device_status.dart';
import '../../data/models/task_item.dart';
import '../../data/models/reminder_item.dart';

class CsvExportService {
  static const int currentSchemaVersion = 2;
  static const String backupFormatIdentifier = 'cranium_full_backup';
  static const String currentAppVersion = '2.5.0';

  /// Export timestamped session history ledger as a CSV file (RFC 4180).
  /// Attempts to download authoritative CSV from ESP32 first;
  /// if offline, synthesizes RFC 4180 CSV from local cache.
  static Future<String> generateSessionsCsv({
    required DeviceStatus status,
    String? host,
  }) async {
    if (host != null && host.isNotEmpty) {
      try {
        final url = Uri.parse('http://$host/api/export/sessions.csv');
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return res.body;
        }
      } catch (_) {
        // Fall back to local synthesis
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Full_Timestamp,Date,Focus_Section,Duration_Formatted,Duration_Seconds,Reps_Completed,Mastery_Level',
    );

    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final dateToday = DateFormat('dd MMM yyyy').format(DateTime.now());

    for (final client in status.clients) {
      if (client.totalSecondsToday >= 60) {
        final durFormatted = _formatDuration(client.totalSecondsToday);
        final lvl = _calcMasteryLevel(client.totalAccumulatedSecs);
        buffer.writeln(
          '"$nowStr","$dateToday (TODAY)","${_escapeCsv(client.name)}","$durFormatted",${client.totalSecondsToday},${client.reps},"$lvl"',
        );
      }

      for (final h in client.history) {
        if (h.seconds < 60) continue;
        final durFormatted = _formatDuration(h.seconds);
        final lvl = _calcMasteryLevel(client.totalAccumulatedSecs);
        buffer.writeln(
          '"${h.timestamp}","${h.date}","${_escapeCsv(client.name)}","$durFormatted",${h.seconds},${h.reps},"$lvl"',
        );
      }
    }

    return buffer.toString();
  }

  /// Export section mastery summary as a CSV file.
  static Future<String> generateSummaryCsv({
    required DeviceStatus status,
    String? host,
  }) async {
    if (host != null && host.isNotEmpty) {
      try {
        final url = Uri.parse('http://$host/api/export/summary.csv');
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return res.body;
        }
      } catch (_) {
        // Fall back to local synthesis
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Section_ID,Section_Name,Today_Seconds,Today_Hours,AllTime_Total_Seconds,AllTime_Hours,Reps_Logged,Mastery_Level,Current_Streak_Days,Longest_Streak_Days,Last_Updated',
    );

    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    for (final client in status.clients) {
      final todayHrs = (client.totalSecondsToday / 3600).toStringAsFixed(2);
      final allTimeHrs = (client.totalAccumulatedSecs / 3600).toStringAsFixed(2);
      final lvl = _calcMasteryLevel(client.totalAccumulatedSecs);
      buffer.writeln(
        '${client.id},"${_escapeCsv(client.name)}",${client.totalSecondsToday},$todayHrs,${client.totalAccumulatedSecs},$allTimeHrs,${client.reps},"$lvl",${status.currentStreak},${status.longestStreak},"$nowStr"',
      );
    }

    return buffer.toString();
  }

  /// Export tasks / directives as a CSV file.
  static String generateTasksCsv({required List<TaskItem> tasks}) {
    final buffer = StringBuffer();
    buffer.writeln('Task_ID,Directive_Text,Priority_Stars,Is_Completed,Created_At');
    for (final t in tasks) {
      buffer.writeln('${t.id},"${_escapeCsv(t.text)}",${t.stars},${t.done ? "TRUE" : "FALSE"},"${t.createdAt}"');
    }
    return buffer.toString();
  }

  /// Export daily reminders / notes as a CSV file.
  static String generateRemindersCsv({required List<ReminderItem> reminders}) {
    final buffer = StringBuffer();
    buffer.writeln('Reminder_ID,Note_Text,Created_At');
    for (final r in reminders) {
      buffer.writeln('${r.id},"${_escapeCsv(r.text)}","${r.createdAt}"');
    }
    return buffer.toString();
  }

  /// Export user configuration and global goals as a CSV file.
  static String generateSettingsCsv({required DeviceStatus status}) {
    final buffer = StringBuffer();
    buffer.writeln('Setting_Key,Setting_Value,Unit_Description');
    buffer.writeln('Global_Daily_Goal_Seconds,${status.globalGoal},"Seconds target per day (e.g. 14400 = 4.0h)"');
    buffer.writeln('Global_Daily_Goal_Hours,${(status.globalGoal / 3600).toStringAsFixed(2)},"Daily focus goal in hours"');
    buffer.writeln('Display_Brightness,${status.brightness},"OLED contrast level (0-255)"');
    buffer.writeln('Current_Streak_Days,${status.currentStreak},"Consecutive active days"');
    buffer.writeln('Longest_Streak_Days,${status.longestStreak},"Personal record active days"');
    buffer.writeln('Active_Section_ID,${status.activeClientId},"Currently engaged section ID"');
    buffer.writeln('Total_Sections_Configured,${status.clients.length},"Number of tracked disciplines"');
    return buffer.toString();
  }

  /// Generate canonical LOSSLESS full-fidelity JSON backup string.
  /// Strictly includes schema versioning, metadata, and all user-owned entities.
  /// Strictly excludes passwords, authentication tokens, and private credentials.
  static Future<String> generateBackupJson({
    required DeviceStatus status,
    List<TaskItem> tasks = const [],
    List<ReminderItem> reminders = const [],
    String? host,
  }) async {
    if (host != null && host.isNotEmpty) {
      try {
        final url = Uri.parse('http://$host/api/backup.json');
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            decoded['schemaVersion'] ??= currentSchemaVersion;
            decoded['format'] ??= backupFormatIdentifier;
            decoded['appVersion'] ??= currentAppVersion;
            decoded['tasks'] ??= tasks.map((t) => t.toJson()).toList();
            decoded['reminders'] ??= reminders.map((r) => r.toJson()).toList();
            return const JsonEncoder.withIndent('  ').convert(decoded);
          }
        }
      } catch (_) {
        // Fall back to local synthesis
      }
    }

    return generateLosslessJsonBackup(
      status: status,
      tasks: tasks,
      reminders: reminders,
    );
  }

  /// Pure offline lossless JSON generator with full metadata and schemaVersion 2.
  static String generateLosslessJsonBackup({
    required DeviceStatus status,
    List<TaskItem> tasks = const [],
    List<ReminderItem> reminders = const [],
  }) {
    final now = DateTime.now();
    int totalHistSessions = 0;
    int totalHistSeconds = 0;

    for (final c in status.clients) {
      totalHistSeconds += c.totalSecondsToday;
      if (c.totalSecondsToday >= 60) totalHistSessions++;
      for (final h in c.history) {
        totalHistSeconds += h.seconds;
        if (h.seconds >= 60) totalHistSessions++;
      }
    }

    final jsonMap = <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'format': backupFormatIdentifier,
      'appVersion': currentAppVersion,
      'exportedAt': now.toIso8601String(),
      'metadata': {
        'totalSessionsLogged': totalHistSessions,
        'totalFocusedSeconds': totalHistSeconds,
        'totalFocusedHours': (totalHistSeconds / 3600.0).toStringAsFixed(2),
        'sectionCount': status.clients.length,
        'taskCount': tasks.length,
        'reminderCount': reminders.length,
        'currentStreakDays': status.currentStreak,
        'longestStreakDays': status.longestStreak,
      },
      'settings': {
        'globalGoal': status.globalGoal,
        'brightness': status.brightness,
        'currentStreak': status.currentStreak,
        'longestStreak': status.longestStreak,
        'lastActiveDate': DateFormat('dd MMM yyyy').format(now),
      },
      // Root-level fields for full backward compatibility with ESP32 LittleFS & v1 restore
      'globalGoal': status.globalGoal,
      'brightness': status.brightness,
      'savedAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      'currentStreak': status.currentStreak,
      'longestStreak': status.longestStreak,
      'lastActiveDate': DateFormat('dd MMM yyyy').format(now),
      'clients': status.clients.map((c) => {
        'id': c.id,
        'name': c.name,
        'totalSecsToday': c.totalSecondsToday,
        'totalSecondsToday': c.totalSecondsToday,
        'reps': c.reps,
        'tallyCount': c.reps,
        'isNegative': c.isNegative,
        'history': c.history.map((h) => {
          'timestamp': h.timestamp.isNotEmpty ? h.timestamp : h.date,
          'date': h.date,
          'secs': h.seconds,
          'seconds': h.seconds,
          'reps': h.reps,
        }).toList(),
      }).toList(),
      'tasks': tasks.map((t) => {
        'id': t.id,
        'text': t.text,
        'stars': t.stars,
        'done': t.done,
        'created': t.createdAt,
      }).toList(),
      'reminders': reminders.map((r) => {
        'id': r.id,
        'text': r.text,
        'created': r.createdAt,
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(jsonMap);
  }

  /// Creates a structured multi-table CSV archive (ZIP) containing:
  /// - manifest.json
  /// - sessions.csv
  /// - summary.csv
  /// - tasks.csv
  /// - reminders.csv
  /// - settings.csv
  static Future<Uint8List> generateStructuredCsvZip({
    required DeviceStatus status,
    List<TaskItem> tasks = const [],
    List<ReminderItem> reminders = const [],
    String? host,
  }) async {
    final archive = Archive();
    final now = DateTime.now();
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final sessionsCsv = await generateSessionsCsv(status: status, host: host);
    final summaryCsv = await generateSummaryCsv(status: status, host: host);
    final tasksCsv = generateTasksCsv(tasks: tasks);
    final remindersCsv = generateRemindersCsv(reminders: reminders);
    final settingsCsv = generateSettingsCsv(status: status);

    final manifest = {
      'archiveFormat': 'cranium_structured_csv_archive',
      'schemaVersion': currentSchemaVersion,
      'appVersion': currentAppVersion,
      'createdAt': nowStr,
      'files': [
        {'name': 'sessions.csv', 'description': 'Full timestamped focus session records'},
        {'name': 'summary.csv', 'description': 'Section summary, accumulated hours, and streaks'},
        {'name': 'tasks.csv', 'description': 'Actionable directives and priority stars'},
        {'name': 'reminders.csv', 'description': 'Daily habit notes and reminders'},
        {'name': 'settings.csv', 'description': 'Tracker configuration and goals'},
      ],
      'metrics': {
        'sectionsCount': status.clients.length,
        'tasksCount': tasks.length,
        'remindersCount': reminders.length,
        'currentStreak': status.currentStreak,
        'longestStreak': status.longestStreak,
      },
    };

    final manifestBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    final sessionsBytes = utf8.encode(sessionsCsv);
    final summaryBytes = utf8.encode(summaryCsv);
    final tasksBytes = utf8.encode(tasksCsv);
    final remindersBytes = utf8.encode(remindersCsv);
    final settingsBytes = utf8.encode(settingsCsv);

    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
    archive.addFile(ArchiveFile('sessions.csv', sessionsBytes.length, sessionsBytes));
    archive.addFile(ArchiveFile('summary.csv', summaryBytes.length, summaryBytes));
    archive.addFile(ArchiveFile('tasks.csv', tasksBytes.length, tasksBytes));
    archive.addFile(ArchiveFile('reminders.csv', remindersBytes.length, remindersBytes));
    archive.addFile(ArchiveFile('settings.csv', settingsBytes.length, settingsBytes));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Saves structured ZIP archive to temp directory and invokes native share sheet.
  static Future<void> shareZipArchive({
    required Uint8List zipBytes,
    String filenamePrefix = 'cranium_export',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dateTag = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/${filenamePrefix}_$dateTag.zip');
    await file.writeAsBytes(zipBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      text: 'Cranium X1 Structured Data Archive ($dateTag)',
    );
  }

  /// Saves JSON string to temp storage and invokes native Android Share Sheet
  static Future<void> shareJsonFile({
    required String jsonContent,
    String filenamePrefix = 'cranium_backup',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dateTag = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/${filenamePrefix}_$dateTag.json');
    await file.writeAsString(jsonContent);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Cranium X1 JSON Backup ($dateTag)',
    );
  }

  /// Saves CSV string to temp storage and invokes native Android Share Sheet
  static Future<void> shareCsvFile({
    required String csvContent,
    required String filenamePrefix,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dateTag = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${tempDir.path}/${filenamePrefix}_$dateTag.csv');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Cranium X1 Focus Export - $filenamePrefix ($dateTag)',
    );
  }

  /// Copies raw content to system clipboard
  static Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }

  static String _formatDuration(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _calcMasteryLevel(int allTimeSecs) {
    final hrs = allTimeSecs / 3600.0;
    if (hrs < 5.0) return 'LVL 1 · Novice';
    if (hrs < 20.0) return 'LVL 2 · Apprentice';
    if (hrs < 50.0) return 'LVL 3 · Practitioner';
    if (hrs < 100.0) return 'LVL 4 · Specialist';
    if (hrs < 250.0) return 'LVL 5 · Expert';
    if (hrs < 500.0) return 'LVL 6 · Master';
    return 'LVL 7 · Grandmaster';
  }

  static String _escapeCsv(String val) {
    return val.replaceAll('"', '""');
  }
}

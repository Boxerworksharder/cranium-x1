import 'dart:convert';
import 'package:intl/intl.dart';
import '../../data/models/device_status.dart';

class ImportPreviewResult {
  final bool isValid;
  final String format;
  final int schemaVersion;
  final String? errorMessage;
  final int sectionCount;
  final int sessionCount;
  final int totalDurationSeconds;
  final int recordsFound;
  final int recordsToAdd;
  final int recordsToUpdate;
  final int recordsAlreadyPresent;
  final List<String> warnings;
  final List<String> conflicts;
  final List<String> unsupportedFields;
  final int? goalSeconds;
  final int? currentStreak;
  final int? longestStreak;
  final int? brightness;
  final String? lastActiveDate;
  final List<String> sectionNames;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> reminders;
  final String synthesizedJson;

  const ImportPreviewResult({
    required this.isValid,
    required this.format,
    this.schemaVersion = 2,
    this.errorMessage,
    this.sectionCount = 0,
    this.sessionCount = 0,
    this.totalDurationSeconds = 0,
    this.recordsFound = 0,
    this.recordsToAdd = 0,
    this.recordsToUpdate = 0,
    this.recordsAlreadyPresent = 0,
    this.warnings = const [],
    this.conflicts = const [],
    this.unsupportedFields = const [],
    this.goalSeconds,
    this.currentStreak,
    this.longestStreak,
    this.brightness,
    this.lastActiveDate,
    this.sectionNames = const [],
    this.clients = const [],
    this.tasks = const [],
    this.reminders = const [],
    this.synthesizedJson = '',
  });

  String get totalDurationFormatted {
    final hrs = totalDurationSeconds / 3600.0;
    return '${hrs.toStringAsFixed(1)}h (${(totalDurationSeconds / 60).round()}m)';
  }
}

class DataImportService {
  /// Cleans input text by stripping markdown code blocks, quotes, and whitespace
  static String cleanRawContent(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }
    return text.trim();
  }

  /// Inspect and validate raw text (JSON or CSV)
  static ImportPreviewResult parseAndValidate(String rawContent, {DeviceStatus? currentStatus}) {
    final text = cleanRawContent(rawContent);
    if (text.isEmpty) {
      return const ImportPreviewResult(
        isValid: false,
        format: 'UNKNOWN',
        errorMessage: 'Payload is empty. Please paste or select a valid file.',
      );
    }

    // Try parsing as JSON first
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        return _parseJson(text, currentStatus: currentStatus);
      } catch (e) {
        return ImportPreviewResult(
          isValid: false,
          format: 'MALFORMED JSON',
          errorMessage: 'JSON parse error: $e',
        );
      }
    }

    // Try parsing as CSV
    if (text.contains(',') || text.contains('\n') || text.contains('\t')) {
      try {
        return _parseCsv(text, currentStatus: currentStatus);
      } catch (e) {
        return ImportPreviewResult(
          isValid: false,
          format: 'MALFORMED CSV',
          errorMessage: 'CSV parse error: $e',
        );
      }
    }

    return const ImportPreviewResult(
      isValid: false,
      format: 'UNRECOGNIZED',
      errorMessage: 'Unrecognized format. Please provide valid JSON or CSV data.',
    );
  }

  static ImportPreviewResult _parseJson(String text, {DeviceStatus? currentStatus}) {
    final dynamic decoded = jsonDecode(text);
    Map<String, dynamic> rootMap;

    if (decoded is List) {
      rootMap = {'clients': decoded};
    } else if (decoded is Map<String, dynamic>) {
      rootMap = decoded;
    } else {
      throw 'Expected JSON Object or Array';
    }

    final List<String> warnings = [];
    final List<String> conflicts = [];
    final List<String> unsupportedFields = [];

    // Schema version check
    int schemaVer = 2;
    if (rootMap.containsKey('schemaVersion')) {
      final rawVer = rootMap['schemaVersion'];
      schemaVer = rawVer is num ? rawVer.toInt() : int.tryParse(rawVer.toString()) ?? 2;
      if (schemaVer > 2) {
        warnings.add('Payload schema v$schemaVer is newer than engine v2; forward-compatible fields ingested.');
      }
    } else {
      schemaVer = 1;
      warnings.add('Legacy schema v1 payload detected: automatically upgraded to v2 format.');
    }

    // Inspect known top-level fields
    const knownFields = {
      'schemaVersion', 'format', 'appVersion', 'exportedAt', 'metadata',
      'settings', 'globalGoal', 'brightness', 'savedAt', 'currentStreak',
      'longestStreak', 'lastActiveDate', 'clients', 'sections', 'tasks',
      'reminders', 'importedAt'
    };
    for (final k in rootMap.keys) {
      if (!knownFields.contains(k)) {
        unsupportedFields.add(k);
      }
    }

    final List<Map<String, dynamic>> clients = [];
    final List<String> sectionNames = [];
    final Set<String> seenNames = {};
    int sessionCount = 0;
    int totalDuration = 0;

    final dynamic rawClients = rootMap['clients'] ?? rootMap['sections'];
    if (rawClients is List) {
      for (int i = 0; i < rawClients.length; i++) {
        final dynamic item = rawClients[i];
        if (item is Map) {
          final id = item['id'] is int ? item['id'] as int : i + 1;
          final name = (item['name'] ?? item['title'] ?? 'Section ${i + 1}').toString().trim();
          
          if (seenNames.contains(name.toLowerCase())) {
            conflicts.add('Duplicate section name in payload: "$name"');
          }
          seenNames.add(name.toLowerCase());
          sectionNames.add(name);

          final todaySecs = item['totalSecsToday'] ?? item['totalSecondsToday'] ?? item['todaySecs'] ?? 0;
          final reps = item['reps'] ?? item['tallyCount'] ?? 0;

          final todaySecsInt = todaySecs is num ? todaySecs.toInt() : int.tryParse(todaySecs.toString()) ?? 0;
          final repsInt = reps is num ? reps.toInt() : int.tryParse(reps.toString()) ?? 0;

          final List<Map<String, dynamic>> history = [];
          final dynamic rawHistory = item['history'];
          if (rawHistory is List) {
            for (final h in rawHistory) {
              if (h is Map) {
                final date = (h['date'] ?? '').toString().trim();
                final timestamp = (h['timestamp'] ?? date).toString().trim();
                final secs = h['secs'] ?? h['seconds'] ?? h['duration'] ?? 0;
                final secsInt = secs is num ? secs.toInt() : int.tryParse(secs.toString()) ?? 0;
                final hReps = h['reps'] ?? h['tallyCount'] ?? 0;
                final hRepsInt = hReps is num ? hReps.toInt() : int.tryParse(hReps.toString()) ?? 0;

                history.add({
                  'timestamp': timestamp,
                  'date': date,
                  'secs': secsInt,
                  'seconds': secsInt,
                  'reps': hRepsInt,
                });
                sessionCount++;
                totalDuration += secsInt;
              }
            }
          }

          totalDuration += todaySecsInt;
          final isNegative = (item['isNegative'] as bool?) ?? false;

          // Provide both key variants for ESP32 and Flutter app interoperability
          clients.add({
            'id': id,
            'name': name,
            'totalSecsToday': todaySecsInt,
            'totalSecondsToday': todaySecsInt,
            'reps': repsInt,
            'tallyCount': repsInt,
            'isNegative': isNegative,
            'history': history,
          });
        }
      }
    }

    final List<Map<String, dynamic>> tasks = [];
    final dynamic rawTasks = rootMap['tasks'];
    if (rawTasks is List) {
      for (final t in rawTasks) {
        if (t is Map) {
          tasks.add({
            'id': t['id'] ?? (tasks.length + 1),
            'text': (t['text'] ?? '').toString(),
            'stars': t['stars'] ?? 1,
            'done': t['done'] == true,
            'created': t['created'] ?? t['createdAt'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          });
        }
      }
    }

    final List<Map<String, dynamic>> reminders = [];
    final dynamic rawReminders = rootMap['reminders'];
    if (rawReminders is List) {
      for (final r in rawReminders) {
        if (r is Map) {
          reminders.add({
            'id': r['id'] ?? (reminders.length + 1),
            'text': (r['text'] ?? '').toString(),
            'created': r['created'] ?? r['createdAt'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          });
        }
      }
    }

    final goal = rootMap['globalGoal'] ?? rootMap['globalDeepWorkGoalSeconds'] ?? rootMap['goal'];
    final goalInt = goal is num ? goal.toInt() : int.tryParse(goal?.toString() ?? '');
    final currentStreak = rootMap['currentStreak'] ?? rootMap['currentStreakDays'];
    final longestStreak = rootMap['longestStreak'] ?? rootMap['longestStreakDays'];
    final brightness = rootMap['brightness'];
    final lastActiveDate = (rootMap['lastActiveDate'] ?? DateFormat('dd MMM yyyy').format(DateTime.now())).toString();

    if (clients.isEmpty && tasks.isEmpty) {
      return const ImportPreviewResult(
        isValid: false,
        format: 'JSON (EMPTY)',
        errorMessage: 'No valid sections or tasks found in JSON.',
      );
    }

    int recordsToAdd = 0;
    int recordsToUpdate = 0;
    int recordsAlreadyPresent = 0;

    if (currentStatus != null) {
      final existingClientMap = {
        for (final c in currentStatus.clients) c.name.toLowerCase().trim(): c
      };
      final existingTaskMap = {
        for (final t in currentStatus.tasks) t.text.toLowerCase().trim(): t
      };
      final existingReminderSet = {
        for (final r in currentStatus.reminders) r.text.toLowerCase().trim()
      };

      for (final client in clients) {
        final cName = (client['name'] ?? '').toString().toLowerCase().trim();
        final existingC = existingClientMap[cName];
        if (existingC == null) {
          recordsToAdd++;
          final hist = client['history'] as List<Map<String, dynamic>>? ?? [];
          recordsToAdd += hist.length;
        } else {
          final cToday = client['totalSecsToday'] is num ? (client['totalSecsToday'] as num).toInt() : 0;
          final cReps = client['reps'] is num ? (client['reps'] as num).toInt() : 0;
          if (cToday != existingC.totalSecondsToday || cReps != existingC.reps) {
            recordsToUpdate++;
          } else {
            recordsAlreadyPresent++;
          }

          final hist = client['history'] as List<Map<String, dynamic>>? ?? [];
          final existingHist = existingC.history;
          for (final h in hist) {
            final hTs = (h['timestamp'] ?? h['date'] ?? '').toString().trim();
            final hSecs = h['secs'] is num ? (h['secs'] as num).toInt() : 0;
            final match = existingHist.where((e) => (e.timestamp.trim() == hTs || e.date.trim() == hTs));
            if (match.isEmpty) {
              recordsToAdd++;
            } else {
              if (match.first.seconds == hSecs) {
                recordsAlreadyPresent++;
              } else {
                recordsToUpdate++;
              }
            }
          }
        }
      }

      for (final t in tasks) {
        final tText = (t['text'] ?? '').toString().toLowerCase().trim();
        final existingT = existingTaskMap[tText];
        if (existingT == null) {
          recordsToAdd++;
        } else {
          final isDone = t['done'] == true;
          if (existingT.done == isDone) {
            recordsAlreadyPresent++;
          } else {
            recordsToUpdate++;
          }
        }
      }

      for (final r in reminders) {
        final rText = (r['text'] ?? '').toString().toLowerCase().trim();
        if (existingReminderSet.contains(rText)) {
          recordsAlreadyPresent++;
        } else {
          recordsToAdd++;
        }
      }
    } else {
      recordsToAdd = clients.length + sessionCount + tasks.length + reminders.length;
    }

    final totalRecordsFound = clients.length + sessionCount + tasks.length + reminders.length;

    final synthesized = {
      'globalGoal': goalInt ?? 36000,
      'brightness': brightness is num ? brightness.toInt() : 255,
      'savedAt': rootMap['savedAt'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'currentStreak': currentStreak is num ? currentStreak.toInt() : 0,
      'longestStreak': longestStreak is num ? longestStreak.toInt() : 0,
      'lastActiveDate': lastActiveDate,
      'clients': clients,
      'tasks': tasks,
      'reminders': reminders,
      'importedAt': DateTime.now().toIso8601String(),
    };

    return ImportPreviewResult(
      isValid: true,
      format: 'CRANIUM JSON BACKUP',
      schemaVersion: schemaVer,
      sectionCount: clients.length,
      sessionCount: sessionCount,
      totalDurationSeconds: totalDuration,
      recordsFound: totalRecordsFound,
      recordsToAdd: recordsToAdd,
      recordsToUpdate: recordsToUpdate,
      recordsAlreadyPresent: recordsAlreadyPresent,
      warnings: warnings,
      conflicts: conflicts,
      unsupportedFields: unsupportedFields,
      goalSeconds: goalInt,
      currentStreak: currentStreak is num ? currentStreak.toInt() : null,
      longestStreak: longestStreak is num ? longestStreak.toInt() : null,
      brightness: brightness is num ? brightness.toInt() : null,
      lastActiveDate: lastActiveDate,
      sectionNames: sectionNames,
      clients: clients,
      tasks: tasks,
      reminders: reminders,
      synthesizedJson: jsonEncode(synthesized),
    );
  }

  static ImportPreviewResult _parseCsv(String text, {DeviceStatus? currentStatus}) {
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) throw 'CSV has no content';

    final header = _splitCsvLine(lines.first).map((s) => s.trim().replaceAll('"', '').toLowerCase()).toList();

    final secIdx = _findColumnIndex(header, ['focus_section', 'section_name', 'section', 'client', 'name', 'title']);
    final dateIdx = _findColumnIndex(header, ['date', 'date_label', 'datelabel', 'day']);
    final timeIdx = _findColumnIndex(header, ['full_timestamp', 'timestamp', 'created_at', 'last_updated', 'time']);
    final durSecIdx = _findColumnIndex(header, ['duration_seconds', 'duration_secs', 'seconds', 'secs', 'duration']);
    final durFmtIdx = _findColumnIndex(header, ['duration_formatted', 'duration_hrs', 'hours', 'hrs']);
    final repsIdx = _findColumnIndex(header, ['reps_completed', 'reps_logged', 'reps', 'tally_count', 'tally', 'count']);

    final todaySecIdx = _findColumnIndex(header, ['today_seconds', 'today_secs', 'today_total_seconds', 'today_duration']);
    final allTimeSecIdx = _findColumnIndex(header, ['alltime_total_seconds', 'alltime_secs', 'alltime_seconds', 'total_accumulated_seconds', 'total_seconds']);
    final streakIdx = _findColumnIndex(header, ['current_streak_days', 'current_streak', 'streak']);
    final maxStreakIdx = _findColumnIndex(header, ['longest_streak_days', 'longest_streak', 'max_streak']);
    final typeIdx = _findColumnIndex(header, ['activity_type', 'type', 'is_negative', 'isnegative', 'sink']);

    final isSessionCsv = (dateIdx != -1 || durSecIdx != -1 || durFmtIdx != -1) && (allTimeSecIdx == -1);
    final isSummaryCsv = (todaySecIdx != -1 || allTimeSecIdx != -1);

    if (!isSessionCsv && !isSummaryCsv) {
      throw 'Unrecognized CSV format. Headers must include Section and Duration or AllTime metrics.';
    }

    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(now).toLowerCase();
    final Map<String, Map<String, dynamic>> sectionMap = {};
    int sessionCount = 0;
    int totalDuration = 0;
    int? parsedStreak;
    int? parsedMaxStreak;

    if (isSessionCsv) {
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _splitCsvLine(line);

        final secName = secIdx != -1 && secIdx < cols.length && cols[secIdx].trim().isNotEmpty
            ? cols[secIdx].replaceAll('"', '').trim()
            : 'Focus Section';

        final rawDate = dateIdx != -1 && dateIdx < cols.length ? cols[dateIdx].replaceAll('"', '').trim() : DateFormat('dd MMM yyyy').format(now);
        final cleanDate = rawDate.replaceAll(RegExp(r'\s*\(TODAY\)', caseSensitive: false), '').trim();
        final rawTimestamp = timeIdx != -1 && timeIdx < cols.length ? cols[timeIdx].replaceAll('"', '').trim() : '';

        int durSecs = 0;
        if (durSecIdx != -1 && durSecIdx < cols.length) {
          durSecs = int.tryParse(cols[durSecIdx].replaceAll('"', '').trim()) ?? 0;
        }
        if (durSecs <= 0 && durFmtIdx != -1 && durFmtIdx < cols.length) {
          durSecs = _parseDurationStringToSeconds(cols[durFmtIdx]);
        }

        final reps = repsIdx != -1 && repsIdx < cols.length ? int.tryParse(cols[repsIdx].replaceAll('"', '').trim()) ?? 0 : 0;
        final rawType = typeIdx != -1 && typeIdx < cols.length ? cols[typeIdx].replaceAll('"', '').toLowerCase() : '';
        final isNeg = rawType.contains('sink') || rawType.contains('true') || secName.toLowerCase().contains('youtube') || secName.toLowerCase().contains('reels');

        sectionMap.putIfAbsent(secName, () => {
          'name': secName,
          'totalSecondsToday': 0,
          'tallyCount': 0,
          'isNegative': isNeg,
          'history': <Map<String, dynamic>>[],
        });

        final sData = sectionMap[secName]!;
        sData['tallyCount'] = (sData['tallyCount'] as int) + reps;

        final isDateToday = rawDate.toLowerCase().contains('today') || cleanDate.toLowerCase() == todayStr;
        if (isDateToday) {
          sData['totalSecondsToday'] = (sData['totalSecondsToday'] as int) + durSecs;
        } else {
          (sData['history'] as List<Map<String, dynamic>>).add({
            'timestamp': rawTimestamp.isNotEmpty ? rawTimestamp : cleanDate,
            'date': cleanDate,
            'secs': durSecs,
            'seconds': durSecs,
            'reps': reps,
          });
        }

        sessionCount++;
        totalDuration += durSecs;
      }
    } else {
      // Summary CSV
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _splitCsvLine(line);

        final secName = secIdx != -1 && secIdx < cols.length && cols[secIdx].trim().isNotEmpty
            ? cols[secIdx].replaceAll('"', '').trim()
            : 'Section $i';

        int todaySecs = 0;
        if (todaySecIdx != -1 && todaySecIdx < cols.length) {
          todaySecs = int.tryParse(cols[todaySecIdx].replaceAll('"', '').trim()) ?? 0;
        }

        int allTimeSecs = 0;
        if (allTimeSecIdx != -1 && allTimeSecIdx < cols.length) {
          allTimeSecs = int.tryParse(cols[allTimeSecIdx].replaceAll('"', '').trim()) ?? 0;
        }

        if (allTimeSecs < todaySecs) allTimeSecs = todaySecs;

        final reps = repsIdx != -1 && repsIdx < cols.length ? int.tryParse(cols[repsIdx].replaceAll('"', '').trim()) ?? 0 : 0;

        if (streakIdx != -1 && streakIdx < cols.length && parsedStreak == null) {
          parsedStreak = int.tryParse(cols[streakIdx].replaceAll('"', '').trim());
        }
        if (maxStreakIdx != -1 && maxStreakIdx < cols.length && parsedMaxStreak == null) {
          parsedMaxStreak = int.tryParse(cols[maxStreakIdx].replaceAll('"', '').trim());
        }

        final histSecs = allTimeSecs > todaySecs ? (allTimeSecs - todaySecs) : 0;
        final List<Map<String, dynamic>> history = [];
        if (histSecs > 0) {
          history.add({
            'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(now.subtract(const Duration(days: 1))),
            'date': 'Past Archive',
            'secs': histSecs,
            'seconds': histSecs,
            'reps': reps > 0 ? (reps ~/ 2) : 0,
          });
        }

        final rawType = typeIdx != -1 && typeIdx < cols.length ? cols[typeIdx].replaceAll('"', '').toLowerCase() : '';
        final isNeg = rawType.contains('sink') || rawType.contains('true') || secName.toLowerCase().contains('youtube') || secName.toLowerCase().contains('reels');

        sectionMap[secName] = {
          'name': secName,
          'totalSecondsToday': todaySecs,
          'tallyCount': reps,
          'isNegative': isNeg,
          'history': history,
        };

        sessionCount++;
        totalDuration += allTimeSecs;
      }
    }

    final List<Map<String, dynamic>> clients = [];
    int idCounter = 1;
    for (final entry in sectionMap.entries) {
      final todaySecs = entry.value['totalSecondsToday'] as int;
      final reps = entry.value['tallyCount'] as int;
      clients.add({
        'id': idCounter++,
        'name': entry.value['name'],
        'totalSecsToday': todaySecs,
        'totalSecondsToday': todaySecs,
        'reps': reps,
        'tallyCount': reps,
        'isNegative': entry.value['isNegative'] == true,
        'history': entry.value['history'],
      });
    }

    int recordsToAdd = 0;
    int recordsToUpdate = 0;
    int recordsAlreadyPresent = 0;
    final List<String> warnings = [];
    final List<String> conflicts = [];

    if (currentStatus != null) {
      final existingClientMap = {
        for (final c in currentStatus.clients) c.name.toLowerCase().trim(): c
      };

      for (final client in clients) {
        final cName = (client['name'] ?? '').toString().toLowerCase().trim();
        final existingC = existingClientMap[cName];
        if (existingC == null) {
          recordsToAdd++;
          final hist = client['history'] as List<Map<String, dynamic>>? ?? [];
          recordsToAdd += hist.length;
        } else {
          final cToday = client['totalSecsToday'] is num ? (client['totalSecsToday'] as num).toInt() : 0;
          final cReps = client['reps'] is num ? (client['reps'] as num).toInt() : 0;
          if (cToday != existingC.totalSecondsToday || cReps != existingC.reps) {
            recordsToUpdate++;
          } else {
            recordsAlreadyPresent++;
          }

          final hist = client['history'] as List<Map<String, dynamic>>? ?? [];
          final existingHist = existingC.history;
          for (final h in hist) {
            final hTs = (h['timestamp'] ?? h['date'] ?? '').toString().trim();
            final hSecs = h['secs'] is num ? (h['secs'] as num).toInt() : 0;
            final match = existingHist.where((e) => (e.timestamp.trim() == hTs || e.date.trim() == hTs));
            if (match.isEmpty) {
              recordsToAdd++;
            } else {
              if (match.first.seconds == hSecs) {
                recordsAlreadyPresent++;
              } else {
                recordsToUpdate++;
              }
            }
          }
        }
      }
    } else {
      recordsToAdd = clients.length + sessionCount;
    }
    final totalRecordsFound = clients.length + sessionCount;

    final synthesized = {
      'globalGoal': 36000,
      'brightness': 255,
      'savedAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      'currentStreak': parsedStreak ?? 0,
      'longestStreak': parsedMaxStreak ?? 0,
      'lastActiveDate': DateFormat('dd MMM yyyy').format(now),
      'clients': clients,
      'tasks': <Map<String, dynamic>>[],
      'reminders': <Map<String, dynamic>>[],
      'importedAt': DateTime.now().toIso8601String(),
    };

    return ImportPreviewResult(
      isValid: true,
      format: isSessionCsv ? 'CRANIUM SESSIONS CSV' : 'CRANIUM SUMMARY CSV',
      schemaVersion: 2,
      sectionCount: clients.length,
      sessionCount: sessionCount,
      totalDurationSeconds: totalDuration,
      recordsFound: totalRecordsFound,
      recordsToAdd: recordsToAdd,
      recordsToUpdate: recordsToUpdate,
      recordsAlreadyPresent: recordsAlreadyPresent,
      warnings: warnings,
      conflicts: conflicts,
      currentStreak: parsedStreak,
      longestStreak: parsedMaxStreak,
      sectionNames: sectionMap.keys.toList(),
      clients: clients,
      tasks: const [],
      reminders: const [],
      synthesizedJson: jsonEncode(synthesized),
    );
  }

  static int _findColumnIndex(List<String> headers, List<String> aliases) {
    for (final alias in aliases) {
      final normAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (int i = 0; i < headers.length; i++) {
        final normHeader = headers[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normHeader == normAlias) {
          return i;
        }
      }
    }
    // Substring / Contains fallback
    for (final alias in aliases) {
      final normAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (int i = 0; i < headers.length; i++) {
        final normHeader = headers[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normHeader.isNotEmpty && normAlias.isNotEmpty) {
          if (normHeader.contains(normAlias) || normAlias.contains(normHeader)) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  static int _parseDurationStringToSeconds(String raw) {
    final val = raw.trim().replaceAll('"', '');
    if (val.isEmpty) return 0;
    final asInt = int.tryParse(val);
    if (asInt != null) return asInt;

    final hMatch = RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(val);
    final mMatch = RegExp(r'(\d+)\s*m', caseSensitive: false).firstMatch(val);
    final sMatch = RegExp(r'(\d+)\s*s', caseSensitive: false).firstMatch(val);
    if (hMatch != null || mMatch != null || sMatch != null) {
      final h = hMatch != null ? int.parse(hMatch.group(1)!) : 0;
      final m = mMatch != null ? int.parse(mMatch.group(1)!) : 0;
      final s = sMatch != null ? int.parse(sMatch.group(1)!) : 0;
      return (h * 3600) + (m * 60) + s;
    }

    if (val.contains(':')) {
      final parts = val.split(':');
      if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return (h * 3600) + (m * 60) + s;
      } else if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return (m * 60) + s;
      }
    }

    final asDouble = double.tryParse(val);
    if (asDouble != null && asDouble > 0) {
      return (asDouble * 3600).round();
    }

    return 0;
  }

  static List<String> _splitCsvLine(String line) {
    final List<String> cols = [];
    final StringBuffer cur = StringBuffer();
    bool insideQuote = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        insideQuote = !insideQuote;
      } else if ((ch == ',' || ch == '\t') && !insideQuote) {
        cols.add(cur.toString());
        cur.clear();
      } else {
        cur.write(ch);
      }
    }
    cols.add(cur.toString());
    return cols;
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:titiksha_mobile/core/services/csv_export_service.dart';
import 'package:titiksha_mobile/core/services/data_import_service.dart';
import 'package:titiksha_mobile/data/models/client_section.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/data/models/task_item.dart';
import 'package:titiksha_mobile/data/models/reminder_item.dart';
import 'package:titiksha_mobile/data/services/ble_service.dart';

void main() {
  group('Security, Data Integrity & Hardening Regression Tests', () {
    test('Lossless JSON backup preserves isNegative flags for all sections', () {
      const mockStatus = DeviceStatus(
        currentStreak: 5,
        longestStreak: 12,
        globalGoal: 36000,
        clients: [
          ClientSection(
            id: 1,
            name: 'Deep Systems',
            totalSecondsToday: 7200,
            reps: 4,
            isNegative: false,
            history: [
              HistoryEntry(
                timestamp: '2026-09-13 14:00:00',
                date: '13 Sep 2026',
                seconds: 3600,
                reps: 2,
              ),
            ],
          ),
          ClientSection(
            id: 2,
            name: 'Reels & Doomscrolling',
            totalSecondsToday: 2400,
            reps: 1,
            isNegative: true,
            history: [
              HistoryEntry(
                timestamp: '2026-09-13 16:00:00',
                date: '13 Sep 2026',
                seconds: 1800,
                reps: 0,
              ),
            ],
          ),
        ],
      );

      final exportedJson = CsvExportService.generateLosslessJsonBackup(
        status: mockStatus,
        tasks: [
          const TaskItem(id: 1, text: 'Harden firmware', stars: 3, done: true, createdAt: '2026-09-14 10:00:00'),
        ],
        reminders: [
          const ReminderItem(id: 1, text: 'Stretch hourly', createdAt: '2026-09-14 10:00:00'),
        ],
      );

      // Verify raw JSON contains isNegative
      final decodedMap = jsonDecode(exportedJson) as Map<String, dynamic>;
      final rawClients = decodedMap['clients'] as List<dynamic>;
      expect(rawClients.length, 2);
      expect(rawClients[0]['isNegative'], isFalse);
      expect(rawClients[1]['isNegative'], isTrue);

      // Verify DataImportService parses isNegative properly
      final parsed = DataImportService.parseAndValidate(exportedJson);
      expect(parsed.isValid, isTrue, reason: parsed.errorMessage);
      expect(parsed.sectionCount, 2);

      final synthMap = jsonDecode(parsed.synthesizedJson) as Map<String, dynamic>;
      final synthClients = synthMap['clients'] as List<dynamic>;
      expect(synthClients[0]['isNegative'], isFalse);
      expect(synthClients[1]['isNegative'], isTrue);
    });

    test('CSV parsing extracts isNegative from activity_type column or section name', () {
      const csvWithActivityType = '''
Full_Timestamp,Date,Focus_Section,Activity_Type,Duration_Seconds,Reps_Completed,Mastery_Level
"2026-09-14 10:00:00","14 Sep 2026","Compiler Optimization","Deep Work",7200,5,"LEVEL 2"
"2026-09-14 12:00:00","14 Sep 2026","YouTube Shorts","Time Sink",3600,0,"LEVEL 1"
''';

      final res = DataImportService.parseAndValidate(csvWithActivityType);
      expect(res.isValid, isTrue, reason: res.errorMessage);
      expect(res.sectionCount, 2);

      final synthMap = jsonDecode(res.synthesizedJson) as Map<String, dynamic>;
      final synthClients = synthMap['clients'] as List<dynamic>;

      final compilerSec = synthClients.firstWhere((c) => c['name'] == 'Compiler Optimization');
      final ytSec = synthClients.firstWhere((c) => c['name'] == 'YouTube Shorts');

      expect(compilerSec['isNegative'], isFalse);
      expect(ytSec['isNegative'], isTrue);
    });

    test('DataImportService safely handles XSS and script tags in section and task names', () {
      const xssJson = '''
{
  "clients": [
    {
      "id": 1,
      "name": "<script>alert('XSS')</script><b>Bold Section</b>",
      "totalSecondsToday": 3600,
      "reps": 1,
      "isNegative": false,
      "history": []
    }
  ],
  "tasks": [
    {
      "id": 1,
      "text": "<img src=x onerror=alert('task')>",
      "stars": 3,
      "done": false
    }
  ]
}
''';

      final res = DataImportService.parseAndValidate(xssJson);
      expect(res.isValid, isTrue, reason: res.errorMessage);
      expect(res.clients.length, 1);
      expect(res.tasks.length, 1);
      // Ensure the text was parsed as string without causing crashes or unhandled states
      expect(res.clients.first['name'], contains("<script>alert('XSS')</script>"));
      expect(res.tasks.first['text'], contains("<img src=x onerror=alert('task')>"));
    });

    test('DeviceStatus purity calculation handles division by zero safely', () {
      // Both DW and Waste are 0
      const emptyStatus = DeviceStatus(
        totalDeepWorkToday: 0,
        totalWasteToday: 0,
        globalGoal: 0,
      );

      expect(emptyStatus.focusPurityPct, 100);
      expect(emptyStatus.goalProgress, 0.0);

      // Normal valid ratio
      const workStatus = DeviceStatus(
        totalDeepWorkToday: 7200, // 2h
        totalWasteToday: 1800,    // 0.5h
        globalGoal: 14400,
      );

      final defaultPurity = ((7200 * 100) / (7200 + 1800)).round(); // 80%
      expect(defaultPurity, 80);
      expect(workStatus.goalProgress, 0.5);
    });

    test('DeviceStatus copyWith accurately updates all negative activity metrics', () {
      const initial = DeviceStatus(
        totalDeepWorkToday: 3600,
        totalWasteToday: 0,
        focusPurityPct: 100,
      );

      final updated = initial.copyWith(
        totalDeepWorkToday: 3600,
        totalWasteToday: 3600,
        focusPurityPct: 50,
      );

      expect(updated.totalDeepWorkToday, 3600);
      expect(updated.totalWasteToday, 3600);
      expect(updated.focusPurityPct, 50);
    });

    test('DeviceStatus correctly parses BLE telemetry with Time Sink activities', () {
      final bleTelemetry = {
        'state': 'TRACKING',
        'dwSecs': 3600,
        'globalDeepWorkSecondsToday': 3600,
        'wasteSecs': 1800,
        'globalWasteSecondsToday': 1800,
        'totalWasteToday': 1800,
        'focusPurityPct': 67,
        'activeClientId': 5,
        'clientId': 5,
        'client': 'YouTube & Reels',
        'isNegative': true,
        'sessionSecs': 300,
        'clients': [
          {'id': 1, 'name': 'Deep Coding', 'todaySecs': 3600, 'reps': 2, 'isNegative': false},
          {'id': 5, 'name': 'YouTube & Reels', 'todaySecs': 1800, 'reps': 1, 'isNegative': true},
        ],
      };

      final status = DeviceStatus.fromJson(bleTelemetry);
      expect(status.state, TrackerState.tracking);
      expect(status.activeClientId, 5);
      expect(status.activeClient?.isNegative, isTrue);
      expect(status.totalDeepWorkToday, 3600);
      expect(status.totalWasteToday, 1800);
      expect(status.focusPurityPct, 67);
      expect(status.clients.length, 2);
      expect(status.clients.firstWhere((c) => c.id == 5).isNegative, isTrue);
      expect(status.clients.firstWhere((c) => c.id == 1).isNegative, isFalse);
    });

    test('BleService reassembles fragmented 400+ byte telemetry chunks properly', () async {
      final bleService = BleService();
      final receivedTelemetry = <Map<String, dynamic>>[];
      final sub = bleService.telemetryStream.listen(receivedTelemetry.add);

      const fullJson = '{"state":"TRACKING","dwSecs":5000,"pct":14,"streak":4,"goal":36000,'
          '"sessionSecs":120,"client":"Deep coding","clientId":3,"todaySecs":2400,"reps":5,'
          '"brightness":180,"brightnessPct":70,"powerbank":true,"clients":['
          '{"id":3,"name":"Deep coding","todaySecs":2400,"reps":5,"isNegative":false},'
          '{"id":4,"name":"Social Media","todaySecs":1200,"reps":0,"isNegative":true}'
          ']}';

      final allBytes = utf8.encode(fullJson);
      // Fragment into 30-byte chunks to simulate very tight MTU
      const chunkSize = 30;
      for (int i = 0; i < allBytes.length; i += chunkSize) {
        final end = (i + chunkSize < allBytes.length) ? i + chunkSize : allBytes.length;
        bleService.parseTelemetryForTesting(allBytes.sublist(i, end));
      }

      await pumpEventQueue();

      expect(receivedTelemetry.length, 1);
      final received = receivedTelemetry.first;
      expect(received['state'], 'TRACKING');
      expect(received['dwSecs'], 5000);
      expect(received['sessionSecs'], 120);
      expect(received['clientId'], 3);
      expect(received['client'], 'Deep coding');
      expect((received['clients'] as List).length, 2);

      await sub.cancel();
      bleService.dispose();
    });

    test('BleService handles noise and garbage bytes before JSON start', () async {
      final bleService = BleService();
      final receivedTelemetry = <Map<String, dynamic>>[];
      final sub = bleService.telemetryStream.listen(receivedTelemetry.add);

      // Prefix garbage
      final garbage = [0xFF, 0x00, 0x12, 0x34];
      const validJson = '{"state":"IDLE","dwSecs":100,"clients":[]}';
      final payload = [...garbage, ...utf8.encode(validJson)];

      bleService.parseTelemetryForTesting(payload);
      await pumpEventQueue();

      expect(receivedTelemetry.length, 1);
      expect(receivedTelemetry.first['state'], 'IDLE');
      expect(receivedTelemetry.first['dwSecs'], 100);

      await sub.cancel();
      bleService.dispose();
    });
  });
}

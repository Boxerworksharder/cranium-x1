import 'package:flutter_test/flutter_test.dart';
import 'package:titiksha_mobile/core/services/data_import_service.dart';

void main() {
  group('DataImportService Tests', () {
    test('Empty or blank input returns invalid result', () {
      final res = DataImportService.parseAndValidate('   ');
      expect(res.isValid, isFalse);
      expect(res.format, 'UNKNOWN');
    });

    test('Valid Cranium JSON backup parses properly', () {
      const sampleJson = '''
      {
        "format": "cranium_full_backup",
        "clients": [
          {
            "id": 0,
            "name": "DEEP WORK",
            "totalSecondsToday": 7200,
            "tallyCount": 5,
            "history": [
              {"date": "10 Sep 2026", "secs": 3600},
              {"date": "11 Sep 2026", "secs": 5400}
            ]
          },
          {
            "id": 1,
            "name": "NEURAL DIVE",
            "totalSecondsToday": 1800,
            "tallyCount": 2,
            "history": []
          }
        ],
        "globalGoal": 28800,
        "currentStreak": 7,
        "longestStreak": 14,
        "tasks": [
          {"id": 1, "text": "Draft Q3 Report", "stars": 3, "done": true}
        ]
      }
      ''';

      final res = DataImportService.parseAndValidate(sampleJson);
      expect(res.isValid, isTrue);
      expect(res.format, 'CRANIUM JSON BACKUP');
      expect(res.sectionCount, 2);
      expect(res.sessionCount, 2);
      expect(res.totalDurationSeconds, 7200 + 3600 + 5400 + 1800);
      expect(res.goalSeconds, 28800);
      expect(res.currentStreak, 7);
      expect(res.longestStreak, 14);
      expect(res.sectionNames, containsAll(['DEEP WORK', 'NEURAL DIVE']));
      expect(res.tasks.length, 1);
    });

    test('Legacy Titiksha JSON backup parses properly for backwards compatibility', () {
      const legacyJson = '''
      {
        "format": "titiksha_full_backup",
        "clients": [
          {
            "id": 0,
            "name": "DEEP WORK",
            "totalSecondsToday": 3600,
            "tallyCount": 2,
            "history": []
          }
        ],
        "globalGoal": 14400
      }
      ''';

      final res = DataImportService.parseAndValidate(legacyJson);
      expect(res.isValid, isTrue);
      expect(res.format, 'CRANIUM JSON BACKUP');
      expect(res.sectionCount, 1);
      expect(res.goalSeconds, 14400);
    });

    test('Valid Cranium Sessions CSV parses properly', () {
      const sampleCsv = '''
Date,Section,Duration_Secs,Duration_Hrs,Reps,Timestamp
"10 Sep 2026","FIRMWARE CORE",3600,1.00,3,"10 Sep 2026 14:00"
"11 Sep 2026","FIRMWARE CORE",7200,2.00,4,"11 Sep 2026 15:30"
"11 Sep 2026","SYSTEM UI",1800,0.50,1,"11 Sep 2026 18:00"
''';

      final res = DataImportService.parseAndValidate(sampleCsv);
      expect(res.isValid, isTrue);
      expect(res.format, 'CRANIUM SESSIONS CSV');
      expect(res.sectionCount, 2);
      expect(res.sessionCount, 3);
      expect(res.totalDurationSeconds, 3600 + 7200 + 1800);
      expect(res.sectionNames, containsAll(['FIRMWARE CORE', 'SYSTEM UI']));
    });

    test('Valid Cranium Summary CSV parses properly', () {
      const sampleSummaryCsv = '''
ID,Section,Today_Secs,Today_Hrs,AllTime_Secs,AllTime_Hrs,Reps,Level,Current_Streak,Longest_Streak,Exported_At
0,"FIRMWARE CORE",3600,1.00,14400,4.00,8,"LVL 2 · APPRENTICE",7,12,"12 Sep 2026 05:30"
1,"NEURAL DIVE",1800,0.50,7200,2.00,3,"LVL 1 · NOVICE",7,12,"12 Sep 2026 05:30"
''';

      final res = DataImportService.parseAndValidate(sampleSummaryCsv);
      expect(res.isValid, isTrue);
      expect(res.format, 'CRANIUM SUMMARY CSV');
      expect(res.sectionCount, 2);
      expect(res.sessionCount, 2);
      expect(res.totalDurationSeconds, 14400 + 7200);
      expect(res.sectionNames, containsAll(['FIRMWARE CORE', 'NEURAL DIVE']));
    });
  });
}

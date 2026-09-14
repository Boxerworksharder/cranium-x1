import 'package:flutter_test/flutter_test.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/data/models/task_item.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('TaskItem fromJson and starsDisplay', () {
      final json = {
        'id': 101,
        'text': 'Design Firmware Architecture',
        'stars': 3,
        'done': false,
        'created': '2026-09-11 22:30:00',
      };

      final task = TaskItem.fromJson(json);
      expect(task.id, 101);
      expect(task.text, 'Design Firmware Architecture');
      expect(task.stars, 3);
      expect(task.done, false);
      expect(task.starsDisplay, '★★★');

      final toggled = task.copyWith(done: true);
      expect(toggled.done, true);
      expect(toggled.id, 101);
    });

    test('DeviceStatus and ClientSection parsing', () {
      final json = {
        'state': 'TRACKING',
        'activeClientId': 1,
        'sessionSeconds': 1500,
        'totalDeepWorkToday': 7200,
        'globalGoal': 14400,
        'brightness': 200,
        'currentStreak': 5,
        'longestStreak': 12,
        'clients': [
          {
            'id': 1,
            'name': 'Deep Work',
            'totalSecsToday': 7200,
            'reps': 4,
            'history': [
              {
                'timestamp': '10:00:00',
                'date': '11 Sep 2026',
                'secs': 3600,
                'reps': 2,
              }
            ],
          }
        ],
        'tasks': [
          {
            'id': 1,
            'text': 'Test GPIO 20',
            'stars': 3,
            'done': false,
          }
        ],
      };

      final status = DeviceStatus.fromJson(json);
      expect(status.state, TrackerState.tracking);
      expect(status.state.label, 'FOCUSING');
      expect(status.activeClientId, 1);
      expect(status.goalProgress, 0.5); // 7200 / 14400 = 50%
      expect(status.clients.length, 1);
      expect(status.clients.first.name, 'Deep Work');
      expect(status.clients.first.formattedTodayTime, '2h 0m');
      expect(status.tasks.length, 1);
      expect(status.tasks.first.text, 'Test GPIO 20');
    });

    test('Stress Buster state parsing and label', () {
      final state = TrackerState.fromString('STRESS_BUSTER');
      expect(state, TrackerState.stressBuster);
      expect(state.label, 'ZEN RESET');
    });

    test('PowerBank KeepAlive and AwayMode parsing and defaults', () {
      const defaultStatus = DeviceStatus();
      expect(defaultStatus.powerbankKeepAlive, isTrue);
      expect(defaultStatus.isAwayMode, isFalse);

      final json = {
        'state': 'IDLE',
        'powerbank': false,
        'awayMode': true,
      };
      final status = DeviceStatus.fromJson(json);
      expect(status.powerbankKeepAlive, isFalse);
      expect(status.isAwayMode, isTrue);

      final modified = status.copyWith(powerbankKeepAlive: true, isAwayMode: false);
      expect(modified.powerbankKeepAlive, isTrue);
      expect(modified.isAwayMode, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Down-Timer & Countdown Mode Tests', () {
    test('Default timer mode is countUp with 25 minute target', () {
      final tracker = TrackerProvider();
      expect(tracker.timerMode, equals(TimerMode.countUp));
      expect(tracker.countdownTargetMinutes, equals(25));
      expect(tracker.countdownTargetSeconds, equals(1500));
    });

    test('Toggling timer mode switches between countUp and countDown', () {
      final tracker = TrackerProvider();
      tracker.toggleTimerMode();
      expect(tracker.timerMode, equals(TimerMode.countDown));

      tracker.toggleTimerMode();
      expect(tracker.timerMode, equals(TimerMode.countUp));
    });

    test('Remaining seconds calculates properly in countdown mode', () {
      final tracker = TrackerProvider();
      tracker.setTimerMode(TimerMode.countDown);
      tracker.setCountdownDuration(25); // 1500 seconds

      expect(tracker.remainingSeconds, equals(1500));
      expect(tracker.displaySeconds, equals(1500));

      // Simulate 300 seconds elapsed
      final status = tracker.status.copyWith(
        sessionSeconds: 300,
        state: TrackerState.tracking,
      );
      // Verify countdown displays 1200 seconds remaining
      final rem = (tracker.countdownTargetSeconds - status.sessionSeconds).clamp(0, tracker.countdownTargetSeconds);
      expect(rem, equals(1200));
    });

    test('Remaining seconds does not go negative when exceeding target duration', () {
      final tracker = TrackerProvider();
      tracker.setTimerMode(TimerMode.countDown);
      tracker.setCountdownDuration(15); // 900 seconds target

      // Simulate 1000 seconds elapsed (overtime)
      final rem = (tracker.countdownTargetSeconds - 1000).clamp(0, tracker.countdownTargetSeconds);
      expect(rem, equals(0));
    });
  });

  group('Offline Operations & Robustness Tests', () {
    test('Start session initiates tracking state with 0 elapsed seconds', () async {
      final tracker = TrackerProvider();
      await tracker.startSession(1);

      expect(tracker.status.state, equals(TrackerState.tracking));
      expect(tracker.status.sessionSeconds, equals(0));
      expect(tracker.status.activeClientId, equals(1));
    });

    test('Pause and resume session update state cleanly', () async {
      final tracker = TrackerProvider();
      await tracker.startSession(1);
      expect(tracker.status.state, equals(TrackerState.tracking));

      await tracker.pauseSession();
      expect(tracker.status.state, equals(TrackerState.paused));

      await tracker.resumeSession();
      expect(tracker.status.state, equals(TrackerState.tracking));
    });

    test('Stop session resets session seconds and records history locally', () async {
      final tracker = TrackerProvider();
      // Add a client first
      await tracker.addSection('Deep Work Test');
      final clientId = tracker.status.clients.first.id;

      await tracker.startSession(clientId);

      await tracker.stopSession();
      expect(tracker.status.state, equals(TrackerState.idle));
      expect(tracker.status.sessionSeconds, equals(0));
    });

    test('Adjust rep increments and decrements reps offline', () async {
      final tracker = TrackerProvider();
      await tracker.addSection('Rep Test');
      final clientId = tracker.status.clients.first.id;
      await tracker.selectSection(clientId);

      await tracker.adjustRep(increment: true);
      final c1 = tracker.status.clients.firstWhere((c) => c.id == clientId);
      expect(c1.reps, equals(1));

      await tracker.adjustRep(increment: true);
      final c2 = tracker.status.clients.firstWhere((c) => c.id == clientId);
      expect(c2.reps, equals(2));

      await tracker.adjustRep(increment: false);
      final c3 = tracker.status.clients.firstWhere((c) => c.id == clientId);
      expect(c3.reps, equals(1));
    });

    test('Add, toggle, and delete tasks work offline with optimistic IDs', () async {
      final tracker = TrackerProvider();
      expect(tracker.tasks.isEmpty, isTrue);

      await tracker.addTask('Write Offline Tests', 3);
      expect(tracker.tasks.length, equals(1));
      expect(tracker.tasks.first.text, equals('Write Offline Tests'));
      expect(tracker.tasks.first.stars, equals(3));
      expect(tracker.tasks.first.done, isFalse);

      final taskId = tracker.tasks.first.id;
      await tracker.toggleTask(taskId);
      expect(tracker.tasks.first.done, isTrue);

      await tracker.deleteTask(taskId);
      expect(tracker.tasks.isEmpty, isTrue);
    });

    test('Update task modifies text and stars offline', () async {
      final tracker = TrackerProvider();
      await tracker.addTask('Draft initial plan', 1);
      final taskId = tracker.tasks.first.id;

      await tracker.updateTask(taskId, text: 'Execute polished implementation', stars: 3);
      expect(tracker.tasks.first.text, equals('Execute polished implementation'));
      expect(tracker.tasks.first.stars, equals(3));
      expect(tracker.tasks.first.done, isFalse);

      // Partial update
      await tracker.updateTask(taskId, stars: 2);
      expect(tracker.tasks.first.text, equals('Execute polished implementation'));
      expect(tracker.tasks.first.stars, equals(2));
    });

    test('Add and delete reminders work offline', () async {
      final tracker = TrackerProvider();
      expect(tracker.reminders.isEmpty, isTrue);

      await tracker.addReminder('Drink Water Every Hour');
      expect(tracker.reminders.length, equals(1));
      expect(tracker.reminders.first.text, equals('Drink Water Every Hour'));

      final remId = tracker.reminders.first.id;
      await tracker.deleteReminder(remId);
      expect(tracker.reminders.isEmpty, isTrue);
    });

    test('Update reminder modifies note text offline', () async {
      final tracker = TrackerProvider();
      await tracker.addReminder('Drink Water Every Hour');
      final remId = tracker.reminders.first.id;

      await tracker.updateReminder(remId, 'Hydrate 3L Electrolytes Daily');
      expect(tracker.reminders.first.text, equals('Hydrate 3L Electrolytes Daily'));
    });

    test('Wellness reminders defaults, toggle, interval clamping, and mode switches', () async {
      final tracker = TrackerProvider();
      // Defaults
      expect(tracker.wellnessEnabled, isTrue);
      expect(tracker.wellnessIntervalMinutes, equals(45));
      expect(tracker.wellnessMode, equals(0)); // 0 = Alternating

      // Toggle ON/OFF
      await tracker.toggleWellness();
      expect(tracker.wellnessEnabled, isFalse);

      await tracker.toggleWellness();
      expect(tracker.wellnessEnabled, isTrue);

      // Interval adjustment with boundary clamping
      await tracker.setWellnessInterval(30);
      expect(tracker.wellnessIntervalMinutes, equals(30));

      await tracker.setWellnessInterval(10); // Below min 15
      expect(tracker.wellnessIntervalMinutes, equals(15));

      await tracker.setWellnessInterval(300); // Above max 180
      expect(tracker.wellnessIntervalMinutes, equals(180));

      // Mode adjustment (0: Alternating, 1: Water Only, 2: Stretch Only)
      await tracker.setWellnessMode(1);
      expect(tracker.wellnessMode, equals(1));

      await tracker.setWellnessMode(2);
      expect(tracker.wellnessMode, equals(2));

      await tracker.setWellnessMode(10); // Clamped to 2
      expect(tracker.wellnessMode, equals(2));
    });

    test('PowerBank KeepAlive toggle and activeTransportLabel states', () async {
      final tracker = TrackerProvider();
      expect(tracker.status.powerbankKeepAlive, isTrue);

      // Toggle PowerBank KeepAlive
      await tracker.togglePowerBankKeepAlive(false);
      expect(tracker.status.powerbankKeepAlive, isFalse);

      await tracker.togglePowerBankKeepAlive(true);
      expect(tracker.status.powerbankKeepAlive, isTrue);

      // Active transport label logic
      expect(tracker.activeTransportLabel, equals('OFFLINE'));

      await tracker.setHost('192.168.4.1');
      expect(tracker.host, equals('192.168.4.1'));
    });
  });

  group('Negative Activity & Time Sink Isolation Tests', () {
    test('Default clients contains YouTube & Reels with isNegative true', () {
      final tracker = TrackerProvider();
      final reels = tracker.status.clients.firstWhere((c) => c.name == 'YouTube & Reels');
      expect(reels.isNegative, isTrue);
    });

    test('Adding a negative section creates client with isNegative true', () async {
      final tracker = TrackerProvider();
      await tracker.addSection('Gaming Binge', isNegative: true);
      final gaming = tracker.status.clients.firstWhere((c) => c.name == 'Gaming Binge');
      expect(gaming.isNegative, isTrue);
    });

    test('Toggling section negative updates status and recomputes purity', () async {
      final tracker = TrackerProvider();
      // Initially client 1 is Deep Coding (isNegative: false)
      expect(tracker.status.clients.first.isNegative, isFalse);

      await tracker.toggleSectionNegative(1, true);
      expect(tracker.status.clients.first.isNegative, isTrue);

      await tracker.toggleSectionNegative(1, false);
      expect(tracker.status.clients.first.isNegative, isFalse);
    });

    test('Local ticker isolates deep work from negative activity', () async {
      final tracker = TrackerProvider();
      // Select the negative activity (id: 5, YouTube & Reels)
      await tracker.selectSection(5);
      expect(tracker.activeClient?.isNegative, isTrue);

      final initialDw = tracker.status.totalDeepWorkToday;
      final initialWaste = tracker.status.totalWasteToday;

      // Start session on negative section
      await tracker.startSession(5);
      expect(tracker.status.state, equals(TrackerState.tracking));

      // Wait 2 seconds for ticker to tick
      await Future.delayed(const Duration(milliseconds: 2100));
      await tracker.stopSession();

      // Verify Deep Work did NOT increase, but Waste DID increase
      expect(tracker.status.totalDeepWorkToday, equals(initialDw));
      expect(tracker.status.totalWasteToday, greaterThan(initialWaste));
    });
  });
}

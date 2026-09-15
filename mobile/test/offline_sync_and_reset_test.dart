import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titiksha_mobile/data/models/client_section.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/data/models/task_item.dart';
import 'package:titiksha_mobile/data/models/reminder_item.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';
import 'package:titiksha_mobile/ui/screens/analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Sync & Reset Robustness Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ClientSection.totalAccumulatedSecs avoids double-counting today sessions', () {
      final now = DateTime.now();
      final todayStr = DateFormat('dd MMM yyyy').format(now);
      final yesterdayStr = DateFormat('dd MMM yyyy').format(now.subtract(const Duration(days: 1)));

      final section = ClientSection(
        id: 1,
        name: 'Coding',
        totalSecondsToday: 1800, // 30 mins today
        reps: 5,
        history: [
          HistoryEntry(timestamp: '', date: todayStr, seconds: 1800, reps: 5), // Today's session
          HistoryEntry(timestamp: '', date: yesterdayStr, seconds: 3600, reps: 10), // Yesterday's session
        ],
      );

      // totalAccumulatedSecs should be today's total (1800) + yesterday's total (3600) = 5400,
      // NOT 1800 + 1800 + 3600 = 7200!
      expect(section.totalAccumulatedSecs, equals(5400));
    });

    test('TrackerProvider addTask/addReminder enqueues offline when BLE disconnected', () async {
      final provider = TrackerProvider(autoStartPolling: false);
      addTearDown(provider.dispose);
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.addTask('Build offline sync', 3);
      expect(provider.tasks.length, equals(1));
      expect(provider.tasks.first.text, equals('Build offline sync'));

      await provider.addReminder('Drink water');
      expect(provider.reminders.length, equals(1));
      expect(provider.reminders.first.text, equals('Drink water'));
    });

    test('TrackerProvider resetAllData zeroes all metrics and clears storage', () async {
      final provider = TrackerProvider(autoStartPolling: false);
      addTearDown(provider.dispose);
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.addTask('Temp task', 1);
      await provider.addReminder('Temp note');
      expect(provider.tasks.isNotEmpty, isTrue);
      expect(provider.reminders.isNotEmpty, isTrue);

      final ok = await provider.resetAllData();
      expect(ok, isTrue);
      expect(provider.tasks.isEmpty, isTrue);
      expect(provider.reminders.isEmpty, isTrue);
      expect(provider.status.totalDeepWorkToday, equals(0));
      expect(provider.status.totalWasteToday, equals(0));
      expect(provider.status.currentStreak, equals(0));
    });

    testWidgets('AnalyticsScreen renders clean zero-state without mock data after reset', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = TrackerProvider(autoStartPolling: false);
      addTearDown(provider.dispose);
      provider.updateStatusForTesting(
        const DeviceStatus(
          state: TrackerState.idle,
          activeClientId: 1,
          sessionSeconds: 0,
          totalDeepWorkToday: 0,
          totalWasteToday: 0,
          focusPurityPct: 100,
          currentStreak: 0,
          longestStreak: 0,
          clients: [
            ClientSection(id: 1, name: 'Deep Coding', totalSecondsToday: 0, reps: 0, history: []),
            ClientSection(id: 2, name: 'YouTube', totalSecondsToday: 0, reps: 0, history: [], isNegative: true),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackerProvider>.value(
            value: provider,
            child: const Scaffold(body: AnalyticsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Receipts zero state
      expect(find.text('MINUTES FOCUSED'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Minutes and Sessions
      expect(find.text('0%'), findsWidgets); // Focus score should be 0% when 0 time tracked
      expect(find.text('0.0h'), findsOneWidget); // Daily average
      expect(find.text('No data yet'), findsOneWidget); // Peak day
    });
  });
}

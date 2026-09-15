import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:titiksha_mobile/data/models/client_section.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';
import 'package:titiksha_mobile/ui/screens/analytics_screen.dart';

void main() {
  group('AnalyticsScreen Dynamic Calculation & Hard Reset Tests', () {
    testWidgets('Displays true zeros when fresh or after hard reset', (tester) async {
      final provider = TrackerProvider();
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
            ClientSection(id: 2, name: 'YouTube & Reels', totalSecondsToday: 0, reps: 0, history: [], isNegative: true),
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

      // "The receipts" grid metrics must show pure zeros, NOT fake benchmark numbers
      expect(find.text('MINUTES FOCUSED'), findsOneWidget);
      expect(find.text('SESSIONS'), findsOneWidget);
      expect(find.text('DEEP WORK DAYS'), findsOneWidget);
      expect(find.text('FOCUS SCORE'), findsOneWidget);
      expect(find.text('WEEKS & COUNTING'), findsOneWidget);
      expect(find.text('DAILY AVERAGE'), findsOneWidget);

      // Verify no mock numbers exist
      expect(find.text('161,015'), findsNothing);
      expect(find.text('4,346'), findsNothing);
      expect(find.text('253'), findsNothing);
      expect(find.text('6.2h'), findsNothing);
      expect(find.text('Tuesdays'), findsNothing);
      expect(find.text('68h 24m'), findsNothing);
      expect(find.text('The 9pm spike.'), findsNothing);
      expect(find.text('3,802'), findsNothing);

      // Verify clean zero states
      expect(find.text('0.0h'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);

      // Productive Day: zero state
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('Log sessions to see peak day'), findsOneWidget);

      // Histogram: zero state
      expect(find.text('0h 00m'), findsOneWidget);

      // Total this month & time sinks
      expect(find.text('0m'), findsWidgets);

      // Heatmap: zero state
      expect(find.text('Focus distribution.'), findsOneWidget);
      expect(find.text('Track focus sessions to reveal your rhythm.'), findsOneWidget);
      expect(find.text('BEST TIME'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('Displays dynamically computed stats when sessions exist', (tester) async {
      final provider = TrackerProvider();
      provider.updateStatusForTesting(
        const DeviceStatus(
          state: TrackerState.idle,
          activeClientId: 1,
          sessionSeconds: 0,
          totalDeepWorkToday: 3600,
          totalWasteToday: 0,
          focusPurityPct: 100,
          currentStreak: 3,
          longestStreak: 5,
          clients: [
            ClientSection(
              id: 1,
              name: 'Deep Coding',
              totalSecondsToday: 3600,
              reps: 1,
              history: [
                HistoryEntry(
                  timestamp: '2026-09-14 10:00:00',
                  date: '14 Sep 2026',
                  seconds: 7200,
                  reps: 2,
                ),
              ],
            ),
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

      // Total deep work = 3600 + 7200 = 10800s = 180 mins
      expect(find.text('180'), findsOneWidget); // MINUTES FOCUSED
      expect(find.text('2'), findsWidgets);     // SESSIONS & ALL TIME blocks
      expect(find.text('3'), findsOneWidget);   // DEEP WORK DAYS
    });
  });
}

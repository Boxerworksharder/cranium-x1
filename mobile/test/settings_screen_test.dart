import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:titiksha_mobile/data/models/client_section.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';
import 'package:titiksha_mobile/ui/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Wi-Fi Removal & Hardware Controls Tests', () {
    testWidgets('Verifies Wi-Fi options are completely removed and BLE is standard', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TrackerProvider>.value(
            value: provider,
            child: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Wi-Fi features are NOT present anywhere
      expect(find.text('WI-FI LOCAL LINK'), findsNothing);
      expect(find.text('DEVICE IP / HOSTNAME'), findsNothing);
      expect(find.text('AWAY HOTSPOT'), findsNothing);
      expect(find.text('SAVE & TEST'), findsNothing);

      // Verify BLE & RTC features ARE present
      expect(find.text('HARDWARE CONNECTION'), findsOneWidget);
      expect(find.text('BLE 5.0 GATT'), findsOneWidget);
      expect(find.text('SYNC PHONE TIME (RTC)'), findsOneWidget);
      expect(find.text('PORTABILITY & POWER BANK'), findsOneWidget);
      // Verify removed controls (Brightness, Buy Me A Coffee)
      expect(find.text('DESK OLED BRIGHTNESS'), findsNothing);
      expect(find.text('SUPPORT CRANIUM X1'), findsNothing);
      expect(find.text('FACTORY DATA RESET'), findsOneWidget);
    });
  });
}

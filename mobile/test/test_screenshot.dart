import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titiksha_mobile/core/theme/app_theme.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';
import 'package:titiksha_mobile/ui/screens/home_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppTheme.useSystemFonts = true;

    final fontDir = Platform.environment['FONT_DIR'] ?? '';
    if (fontDir.isNotEmpty && Directory(fontDir).existsSync()) {
      if (File('$fontDir/material_icons.otf').existsSync()) {
        final iconLoader = FontLoader('MaterialIcons');
        final iconBytes = File('$fontDir/material_icons.otf').readAsBytesSync();
        iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
        await iconLoader.load();
      }
      if (File('$fontDir/fraunces.ttf').existsSync()) {
        final serifLoader = FontLoader('serif');
        final serifBytes = File('$fontDir/fraunces.ttf').readAsBytesSync();
        serifLoader.addFont(Future.value(ByteData.sublistView(serifBytes)));
        await serifLoader.load();
      }
      if (File('$fontDir/manrope_bold.ttf').existsSync()) {
        final sansLoader = FontLoader('sans-serif');
        final sansBytes = File('$fontDir/manrope_bold.ttf').readAsBytesSync();
        sansLoader.addFont(Future.value(ByteData.sublistView(sansBytes)));
        await sansLoader.load();

        final robotoLoader = FontLoader('Roboto');
        robotoLoader.addFont(Future.value(ByteData.sublistView(sansBytes)));
        await robotoLoader.load();

        final ahemLoader = FontLoader('Ahem');
        ahemLoader.addFont(Future.value(ByteData.sublistView(sansBytes)));
        await ahemLoader.load();
      }
      if (File('$fontDir/mono_regular.ttf').existsSync()) {
        final monoLoader = FontLoader('monospace');
        final monoBytes = File('$fontDir/mono_regular.ttf').readAsBytesSync();
        monoLoader.addFont(Future.value(ByteData.sublistView(monoBytes)));
        await monoLoader.load();
      }
    }
  });

  Future<void> capturePng(GlobalKey key, String fileName) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final artifactDir = Platform.environment['ARTIFACT_DIR'] ?? Directory.systemTemp.path;
    final file = File('$artifactDir/$fileName');
    await file.writeAsBytes(pngBytes);
    debugPrint('SUCCESS: $fileName saved (${pngBytes.length} bytes)');
  }

  testWidgets('Render and save App UI screenshot', (WidgetTester tester) async {
    final GlobalKey boundaryKey = GlobalKey();
    final tracker = TrackerProvider(autoStartPolling: false);

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tracker.dispose);

    tracker.addTask('Ship ESP32 wellness reminders firmware', 3);
    tracker.addTask('Review deep work telemetry & stats', 2);
    tracker.addTask('Daily 2-min box breathing reset', 1);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: RepaintBoundary(
          key: boundaryKey,
          child: ChangeNotifierProvider<TrackerProvider>.value(
            value: tracker,
            child: const HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // View 1: Top Cockpit View
    await tester.runAsync(() async {
      await capturePng(boundaryKey, 'app_cockpit_screenshot.png');
    });

    // View 2: Scrolled Cockpit View (Radial Timer, Stepper, Wellness)
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -420));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await capturePng(boundaryKey, 'app_cockpit_scrolled.png');
    });

    // View 3: Stats / Analytics Screen
    await tester.tap(find.text('Stats'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await capturePng(boundaryKey, 'app_analytics_screen.png');
    });

    // View 4: Journal / Editable Tasks
    await tester.tap(find.text('Journal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await capturePng(boundaryKey, 'app_journal_tasks.png');
    });

    // View 5: System Tools / Settings
    await tester.tap(find.text('Tools'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await capturePng(boundaryKey, 'app_settings_screen.png');
    });
  });
}

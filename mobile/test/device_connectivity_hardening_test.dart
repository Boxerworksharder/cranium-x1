import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titiksha_mobile/data/models/device_status.dart';
import 'package:titiksha_mobile/data/services/ble_service.dart';
import 'package:titiksha_mobile/state/tracker_provider.dart';

/// Test implementation of BleService allowing controllable state and recording calls
class MockBleService extends BleService {
  bool mockConnected = false;
  bool mockConnecting = false;
  bool mockAutoReconnecting = false;
  String? mockConnectedAddress;
  String? mockConnectedName;
  String? mockTargetId;
  final List<Map<String, dynamic>> sentCommands = [];
  final List<String> connectWithIdCalls = [];
  int syncTimeCallCount = 0;

  final StreamController<bool> _mockConnectionController = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _mockTelemetryController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  bool get isConnected => mockConnected;

  @override
  bool get isConnecting => mockConnecting;

  @override
  bool get isAutoReconnecting => mockAutoReconnecting;

  @override
  String? get connectedDeviceAddress => mockConnectedAddress;

  @override
  String? get connectedDeviceName => mockConnectedName;

  @override
  String? get targetDeviceId => mockTargetId;

  @override
  Stream<bool> get connectionStateStream => _mockConnectionController.stream;

  @override
  Stream<Map<String, dynamic>> get telemetryStream => _mockTelemetryController.stream;

  void emitConnectionState(bool connected) {
    mockConnected = connected;
    _mockConnectionController.add(connected);
  }

  void emitTelemetry(Map<String, dynamic> data) {
    _mockTelemetryController.add(data);
  }

  @override
  Future<bool> connectWithId(String remoteId, {String? deviceName}) async {
    connectWithIdCalls.add(remoteId);
    mockTargetId = remoteId;
    mockConnected = true;
    mockConnectedAddress = remoteId;
    mockConnectedName = deviceName ?? 'CRANIUM-X1';
    _mockConnectionController.add(true);
    return true;
  }

  @override
  Future<bool> sendCommand(Map<String, dynamic> cmd) async {
    sentCommands.add(cmd);
    if (cmd['action'] == 'sync_time') {
      syncTimeCallCount++;
    }
    return true;
  }

  @override
  Future<void> disconnect({bool clearTarget = true}) async {
    mockConnected = false;
    mockConnectedAddress = null;
    mockConnectedName = null;
    if (clearTarget) {
      mockTargetId = null;
    }
    _mockConnectionController.add(false);
  }

  @override
  void dispose() {
    _mockConnectionController.close();
    _mockTelemetryController.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Device Connectivity & BLE Protocol Hardening Tests', () {
    test('BleService reassembles fragmented JSON streams arriving in micro-chunks', () async {
      final bleService = BleService();
      final received = <Map<String, dynamic>>[];
      final sub = bleService.telemetryStream.listen(received.add);

      const jsonPayload = '{"state":"TRACKING","dwSecs":1820,"wasteSecs":120,"sessionSecs":340,"client":"Deep Systems","clientId":1,"clients":[{"id":1,"name":"Deep Systems","todaySecs":1820,"isNegative":false}]}';
      final bytes = utf8.encode(jsonPayload);

      // Feed in 7-byte chunks to test tight MTU fragmentation
      const chunkSize = 7;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        bleService.parseTelemetryForTesting(bytes.sublist(i, end));
      }

      await pumpEventQueue();

      expect(received.length, equals(1));
      expect(received.first['state'], equals('TRACKING'));
      expect(received.first['dwSecs'], equals(1820));
      expect(received.first['sessionSecs'], equals(340));
      expect(received.first['clientId'], equals(1));

      await sub.cancel();
      bleService.dispose();
    });

    test('BleService telemetry parser survives garbage characters and brackets inside strings', () async {
      final bleService = BleService();
      final received = <Map<String, dynamic>>[];
      final sub = bleService.telemetryStream.listen(received.add);

      // Contains curly braces and quotes inside a string value, plus leading and trailing junk
      const complexJson = 'garbage prefix!@#{"state":"PAUSED","client":"Fix {bracket} in \\"string\\"","sessionSecs":500,"dwSecs":500,"clients":[]}trailing junk';
      final bytes = utf8.encode(complexJson);

      bleService.parseTelemetryForTesting(bytes);
      await pumpEventQueue();

      expect(received.length, equals(1));
      expect(received.first['state'], equals('PAUSED'));
      expect(received.first['client'], equals('Fix {bracket} in "string"'));
      expect(received.first['sessionSecs'], equals(500));

      await sub.cancel();
      bleService.dispose();
    });

    test('BleService sets and clears target device ID on explicit disconnect', () async {
      final bleService = BleService();
      bleService.setTargetDeviceId('44:BD:8D:20:AA:D2');
      expect(bleService.targetDeviceId, equals('44:BD:8D:20:AA:D2'));

      bleService.cancelAutoReconnect();
      expect(bleService.isAutoReconnecting, isFalse);

      await bleService.disconnect(clearTarget: true);
      expect(bleService.targetDeviceId, isNull);
      expect(bleService.isConnected, isFalse);

      bleService.dispose();
    });

    test('TrackerProvider restores saved BLE credentials from SharedPreferences on cold start', () async {
      SharedPreferences.setMockInitialValues({
        'pref_sync_protocol': 'bluetooth',
        'pref_last_ble_device_id': '44:BD:8D:20:AA:D2',
        'pref_last_ble_device_name': 'CRANIUM-X1',
      });

      final mockBle = MockBleService();
      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );

      // Wait for _init to process SharedPreferences
      await pumpEventQueue();

      expect(tracker.protocol, equals(SyncProtocol.bluetooth));
      expect(tracker.lastBleDeviceId, equals('44:BD:8D:20:AA:D2'));
      expect(tracker.lastBleDeviceName, equals('CRANIUM-X1'));
      // Cold start should trigger automatic connection to the saved device
      expect(mockBle.connectWithIdCalls, contains('44:BD:8D:20:AA:D2'));

      tracker.dispose();
      mockBle.dispose();
    });

    test('AppLifecycleState.resumed triggers RTC sync when BLE is already connected', () async {
      final mockBle = MockBleService();
      mockBle.mockConnected = true;
      mockBle.mockConnectedAddress = '44:BD:8D:20:AA:D2';

      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await tracker.setSyncProtocol(SyncProtocol.bluetooth);
      await pumpEventQueue();

      // Trigger lifecycle resume
      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // Verify RTC sync command was dispatched
      expect(mockBle.syncTimeCallCount, greaterThanOrEqualTo(1));
      expect(mockBle.sentCommands.any((c) => c['action'] == 'sync_time'), isTrue);

      tracker.dispose();
      mockBle.dispose();
    });

    test('AppLifecycleState.resumed triggers auto-reconnection when disconnected with saved device', () async {
      SharedPreferences.setMockInitialValues({
        'pref_sync_protocol': 'bluetooth',
        'pref_last_ble_device_id': '44:BD:8D:20:AA:D2',
        'pref_last_ble_device_name': 'CRANIUM-X1',
      });

      final mockBle = MockBleService();

      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await pumpEventQueue();

      // Simulate disconnection while app was in background
      mockBle.mockConnected = false;
      mockBle.connectWithIdCalls.clear();

      // Trigger app resumed
      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(mockBle.connectWithIdCalls, contains('44:BD:8D:20:AA:D2'));

      tracker.dispose();
      mockBle.dispose();
    });

    test('Command routing dispatches via BLE when connected', () async {
      final mockBle = MockBleService();
      mockBle.mockConnected = true;

      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await tracker.setSyncProtocol(SyncProtocol.bluetooth);
      await pumpEventQueue();

      // Add a client and start a session
      await tracker.addSection('Firmware Security');
      final clientId = tracker.status.clients.first.id;

      await tracker.startSession(clientId);
      await pumpEventQueue();

      expect(mockBle.sentCommands.any((c) => c['action'] == 'start' && c['id'] == clientId), isTrue);

      await tracker.pauseSession();
      await pumpEventQueue();
      expect(mockBle.sentCommands.any((c) => c['action'] == 'pause'), isTrue);

      await tracker.resumeSession();
      await pumpEventQueue();
      expect(mockBle.sentCommands.any((c) => c['action'] == 'resume'), isTrue);

      await tracker.stopSession();
      await pumpEventQueue();
      expect(mockBle.sentCommands.any((c) => c['action'] == 'stop'), isTrue);

      tracker.dispose();
      mockBle.dispose();
    });

    test('Command routing falls back safely when BLE is disconnected', () async {
      final mockBle = MockBleService();
      mockBle.mockConnected = false;

      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await tracker.setSyncProtocol(SyncProtocol.bluetooth);
      await pumpEventQueue();

      // Calling stopSession when offline shouldn't throw an unhandled exception
      await tracker.stopSession();
      expect(tracker.status.state, equals(TrackerState.idle));

      tracker.dispose();
      mockBle.dispose();
    });

    test('TrackerProvider updates active section, session timer and purity from live BLE telemetry', () async {
      final mockBle = MockBleService();
      mockBle.mockConnected = true;

      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await tracker.setSyncProtocol(SyncProtocol.bluetooth);
      await pumpEventQueue();

      // Emit live telemetry packet
      mockBle.emitTelemetry({
        'state': 'TRACKING',
        'sessionSecs': 125,
        'dwSecs': 7200,
        'wasteSecs': 1800,
        'focusPurityPct': 80,
        'clientId': 3,
        'client': 'Core Engine',
        'isNegative': false,
        'streak': 6,
        'goal': 28800,
        'brightness': 200,
        'powerbank': true,
        'clients': [
          {'id': 1, 'name': 'Admin', 'todaySecs': 3600, 'reps': 2, 'isNegative': false},
          {'id': 3, 'name': 'Core Engine', 'todaySecs': 3600, 'reps': 3, 'isNegative': false},
          {'id': 4, 'name': 'Social Feed', 'todaySecs': 1800, 'reps': 0, 'isNegative': true},
        ],
      });

      await pumpEventQueue();

      expect(tracker.status.state, equals(TrackerState.tracking));
      expect(tracker.status.activeClientId, equals(3));
      expect(tracker.status.sessionSeconds, equals(125));
      expect(tracker.status.totalDeepWorkToday, equals(7200));
      expect(tracker.status.totalWasteToday, equals(1800));
      expect(tracker.status.focusPurityPct, equals(80));
      expect(tracker.status.clients.length, equals(3));
      expect(tracker.status.clients.firstWhere((c) => c.id == 4).isNegative, isTrue);
      expect(tracker.isOnline, isTrue);

      tracker.dispose();
      mockBle.dispose();
    });

    test('TrackerProvider forgetBleDevice clears stored credentials and disconnects cleanly', () async {
      SharedPreferences.setMockInitialValues({
        'pref_last_ble_device_id': '44:BD:8D:20:AA:D2',
        'pref_last_ble_device_name': 'CRANIUM-X1',
      });

      final mockBle = MockBleService();
      final tracker = TrackerProvider(
        bleService: mockBle,
        autoStartPolling: false,
      );
      await tracker.setSyncProtocol(SyncProtocol.bluetooth);
      await pumpEventQueue();

      expect(tracker.lastBleDeviceId, equals('44:BD:8D:20:AA:D2'));

      await tracker.forgetBleDevice();
      await pumpEventQueue();

      expect(tracker.lastBleDeviceId, isNull);
      expect(tracker.lastBleDeviceName, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_last_ble_device_id'), isNull);
      expect(prefs.getString('pref_last_ble_device_name'), isNull);

      tracker.dispose();
      mockBle.dispose();
    });
  });
}

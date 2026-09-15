import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String charTelemetryUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String charCommandUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandChar;

  StreamSubscription? _notifySub;
  StreamSubscription? _connStateSub;

  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool _isConnecting = false;
  bool _isAutoReconnecting = false;
  bool _explicitDisconnect = false;
  String? _targetDeviceId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  bool get isConnected => _connectedDevice != null;
  bool get isConnecting => _isConnecting;
  bool get isAutoReconnecting => _isAutoReconnecting;
  String? get connectedDeviceName => _connectedDevice?.platformName;
  String? get connectedDeviceAddress => _connectedDevice?.remoteId.str;
  String? get targetDeviceId => _targetDeviceId;

  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  /// Stream of scan results matching Cranium / Titiksha / X1 devices or matching service UUID.
  /// Android hardware filters drop scan-response packets, so we filter safely in Dart.
  Stream<List<ScanResult>> get craniumScanResults => FlutterBluePlus.scanResults.map((results) {
        return results.where((r) {
          final name = (r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : r.device.platformName)
              .toUpperCase();
          final hasService = r.advertisementData.serviceUuids.any(
            (u) => u.toString().toLowerCase() == serviceUuid.toLowerCase(),
          );
          return name.contains('CRANIUM') ||
              name.contains('TITIKSHA') ||
              name.contains('X1') ||
              name.contains('DESKTRACKER') ||
              hasService;
        }).toList();
      });

  void setTargetDeviceId(String? id) {
    _targetDeviceId = id;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
      // Note: We do NOT pass withServices on Android because many BLE chipsets
      // only evaluate primary ADV_IND packets and drop SCAN_RSP packets containing the custom UUID.
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
      try {
        await FlutterBluePlus.startScan(timeout: timeout);
      } catch (e2) {
        debugPrint('[BLE] Fallback scan error: $e2');
      }
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<bool> connectWithId(String remoteId, {String? deviceName}) async {
    final device = BluetoothDevice.fromId(remoteId);
    return await connect(device);
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnecting) {
      debugPrint('[BLE] Connection already in progress, ignoring duplicate request.');
      return false;
    }
    _isConnecting = true;
    _explicitDisconnect = false;
    _targetDeviceId = device.remoteId.str;

    try {
      await stopScan();
      debugPrint('[BLE] Connecting to ${device.platformName} (${device.remoteId})...');

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 8),
      );

      try {
        await device.requestMtu(512);
      } catch (_) {}

      _connectedDevice = device;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _isAutoReconnecting = false;

      // Listen for connection drops
      _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Disconnected from device (explicit=$_explicitDisconnect)');
          _cleanUp();
          _connectionStateController.add(false);
          if (!_explicitDisconnect && _targetDeviceId != null) {
            _scheduleAutoReconnect();
          }
        } else if (state == BluetoothConnectionState.connected) {
          _connectionStateController.add(true);
        }
      });

      // Discover GATT services
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid == charTelemetryUuid.toLowerCase()) {
              await c.setNotifyValue(true);
              _notifySub?.cancel();
              _notifySub = c.onValueReceived.listen((bytes) {
                _parseTelemetry(bytes);
              });
            } else if (cUuid == charCommandUuid.toLowerCase()) {
              _commandChar = c;
            }
          }
        }
      }

      _connectionStateController.add(true);
      return true;
    } catch (e) {
      debugPrint('[BLE] Connection failed: $e');
      _cleanUp();
      if (!_explicitDisconnect && _targetDeviceId != null) {
        _scheduleAutoReconnect();
      }
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleAutoReconnect() {
    if (_explicitDisconnect || _targetDeviceId == null || _isConnecting) return;
    _reconnectTimer?.cancel();
    _isAutoReconnecting = true;

    // Exponential backoff: 1s, 2s, 5s, 10s, max 15s
    const delays = [1, 2, 5, 10, 15];
    final delaySec = delays[_reconnectAttempts.clamp(0, delays.length - 1)];
    _reconnectAttempts++;

    debugPrint('[BLE] Auto-reconnect #$_reconnectAttempts scheduled in ${delaySec}s to $_targetDeviceId');
    _reconnectTimer = Timer(Duration(seconds: delaySec), () async {
      if (_explicitDisconnect || _targetDeviceId == null || isConnected) return;
      debugPrint('[BLE] Executing auto-reconnect to $_targetDeviceId...');
      final ok = await connectWithId(_targetDeviceId!);
      if (!ok && !_explicitDisconnect && !isConnected) {
        _scheduleAutoReconnect();
      }
    });
  }

  void cancelAutoReconnect() {
    _reconnectTimer?.cancel();
    _isAutoReconnecting = false;
  }

  Future<void> disconnect({bool clearTarget = true}) async {
    _explicitDisconnect = true;
    cancelAutoReconnect();
    if (clearTarget) {
      _targetDeviceId = null;
    }
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (_) {}
    _cleanUp();
    _connectionStateController.add(false);
  }

  Future<bool> sendCommand(Map<String, dynamic> cmd) async {
    if (_commandChar == null) {
      debugPrint('[BLE] Cannot send command: Command characteristic not ready');
      return false;
    }
    try {
      final jsonStr = jsonEncode(cmd);
      final bytes = utf8.encode(jsonStr);
      try {
        await _commandChar!.write(bytes, withoutResponse: true);
        return true;
      } catch (e) {
        debugPrint('[BLE] Write without response failed, trying with response: $e');
        await _commandChar!.write(bytes, withoutResponse: false);
        return true;
      }
    } catch (e) {
      debugPrint('[BLE] Send command error: $e');
      return false;
    }
  }

  final List<int> _chunkBuffer = [];

  @visibleForTesting
  void parseTelemetryForTesting(List<int> bytes) => _parseTelemetry(bytes);

  void _parseTelemetry(List<int> bytes) {
    if (bytes.isEmpty) return;

    if (_chunkBuffer.length > 8192) {
      _chunkBuffer.clear();
    }
    _chunkBuffer.addAll(bytes);

    int startIdx = -1;
    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = 0; i < _chunkBuffer.length; i++) {
      final b = _chunkBuffer[i];
      if (startIdx == -1) {
        if (b == 0x7B) { // '{'
          startIdx = i;
          depth = 1;
          inString = false;
          escape = false;
        }
        continue;
      }

      if (escape) {
        escape = false;
        continue;
      }
      if (b == 0x5C) { // '\'
        escape = true;
        continue;
      }
      if (b == 0x22) { // '"'
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (b == 0x7B) {
          depth++;
        } else if (b == 0x7D) {
          depth--;
          if (depth == 0) {
            final jsonBytes = _chunkBuffer.sublist(startIdx, i + 1);
            try {
              final text = utf8.decode(jsonBytes);
              final map = jsonDecode(text) as Map<String, dynamic>;
              _telemetryController.add(map);
            } catch (e) {
              debugPrint('[BLE] Telemetry chunk decode error: $e');
            }
            _chunkBuffer.removeRange(0, i + 1);
            i = -1;
            startIdx = -1;
          }
        }
      }
    }

    if (startIdx > 0 && depth > 0) {
      _chunkBuffer.removeRange(0, startIdx);
    }
  }

  void _cleanUp() {
    _chunkBuffer.clear();
    _notifySub?.cancel();
    _notifySub = null;
    _connStateSub?.cancel();
    _connStateSub = null;
    _connectedDevice = null;
    _commandChar = null;
  }

  void dispose() {
    cancelAutoReconnect();
    _cleanUp();
    _telemetryController.close();
    _connectionStateController.close();
  }
}

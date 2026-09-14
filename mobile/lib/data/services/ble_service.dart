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

  bool get isConnected => _connectedDevice != null;
  String? get connectedDeviceName => _connectedDevice?.platformName;
  String? get connectedDeviceAddress => _connectedDevice?.remoteId.str;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<void> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [Guid(serviceUuid)],
      );
    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
      // Fallback: scan without service filter if device not in scan filter
      try {
        await FlutterBluePlus.startScan(timeout: timeout);
      } catch (e2) {
        debugPrint('[BLE] Unfiltered scan error: $e2');
      }
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<bool> connect(BluetoothDevice device) async {
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

      // Listen for connection drops
      _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Disconnected from device');
          _cleanUp();
          _connectionStateController.add(false);
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
      return false;
    }
  }

  Future<void> disconnect() async {
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
    _cleanUp();
    _telemetryController.close();
    _connectionStateController.close();
  }
}

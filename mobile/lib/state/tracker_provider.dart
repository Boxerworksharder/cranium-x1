import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/services/data_import_service.dart';
import '../data/models/device_status.dart';
import '../data/models/client_section.dart';
import '../data/models/task_item.dart';
import '../data/models/reminder_item.dart';
import '../data/models/checklist_item.dart';
import '../data/services/esp32_api_service.dart';
import '../data/services/ble_service.dart';

enum SyncProtocol { wifi, bluetooth }
enum TimerMode { countUp, countDown }

class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Esp32ApiService _apiService;
  final BleService _bleService;
  Timer? _pollTimer;
  Timer? _localTicker;
  Timer? _midnightTimer;

  bool _isOnline = false;
  bool _isLoading = false;
  DateTime? _lastSync;
  String _host = AppConstants.defaultEspIp;
  UiThemeStyle _themeStyle = UiThemeStyle.dark;
  SyncProtocol _protocol = SyncProtocol.wifi;
  TimerMode _timerMode = TimerMode.countUp;
  int _countdownTargetMinutes = 25;
  DateTime? _lastBackupDate;

  String? _lastBleDeviceId;
  String? _lastBleDeviceName;

  DeviceStatus _status = const DeviceStatus();
  List<TaskItem> _tasks = [];
  List<ReminderItem> _reminders = [];
  List<ChecklistItem> _checklist = [];

  List<Map<String, dynamic>> _pendingSyncQueue = [];
  bool _pendingResetOnConnect = false;
  bool _isFlushingQueue = false;

  StreamSubscription? _bleTelemetrySub;
  StreamSubscription? _bleConnSub;

  int _consecutiveWifiFailures = 0;
  bool _isAutoConnectingBle = false;
  bool _isPolling = false;
  bool _isDisposed = false;

  TrackerProvider({
    Esp32ApiService? apiService,
    BleService? bleService,
    bool autoStartPolling = true,
  })  : _apiService = apiService ?? Esp32ApiService(),
        _bleService = bleService ?? BleService() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    _init(autoStartPolling: autoStartPolling);
  }

  Future<void> _init({bool autoStartPolling = true}) async {
    await _loadSettings(autoStartPolling: autoStartPolling);
    if (_isDisposed) return;
    if (autoStartPolling) {
      startPolling();
    }
    // Auto-reconnect saved BLE device on cold launch
    if (_protocol == SyncProtocol.bluetooth && _lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
      debugPrint('[TrackerProvider] Cold start: Auto-connecting saved BLE device: $_lastBleDeviceId');
      unawaited(_bleService.connectWithId(_lastBleDeviceId!));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[TrackerProvider] App resumed from background. Synchronizing state...');
      _handleAppResume();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('[TrackerProvider] App paused into background.');
    }
  }

  void _handleAppResume() {
    if (_protocol == SyncProtocol.bluetooth) {
      if (_bleService.isConnected) {
        syncTimeToDevice();
      } else if (_lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
        debugPrint('[TrackerProvider] Resume: Reconnecting to $_lastBleDeviceId...');
        unawaited(_bleService.connectWithId(_lastBleDeviceId!));
      }
    } else if (_protocol == SyncProtocol.wifi) {
      refreshData();
    }
  }

  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  DateTime? get lastSync => _lastSync;
  String get host => _host;
  UiThemeStyle get themeStyle => _themeStyle;
  SyncProtocol get protocol => _protocol;
  BleService get bleService => _bleService;
  String? get lastBleDeviceId => _lastBleDeviceId;
  String? get lastBleDeviceName => _lastBleDeviceName;
  DeviceStatus get status => _status;
  List<TaskItem> get tasks => _tasks;
  List<ReminderItem> get reminders => _reminders;
  List<ChecklistItem> get checklist => _checklist;
  TimerMode get timerMode => _timerMode;
  int get countdownTargetMinutes => _countdownTargetMinutes;
  int get countdownTargetSeconds => _countdownTargetMinutes * 60;
  DateTime? get lastBackupDate => _lastBackupDate;
  String get lastBackupDateFormatted => _lastBackupDate != null
      ? DateFormat('dd MMM yyyy, HH:mm').format(_lastBackupDate!)
      : 'Never';

  String get activeTransportLabel {
    if (_protocol == SyncProtocol.bluetooth && _bleService.isConnected) {
      return 'BLUETOOTH (AWAY)';
    }
    if (_isOnline) {
      if (_host.contains('192.168.4.1') || _status.isAwayMode) {
        return 'HOTSPOT (AWAY)';
      }
      return 'HOME WI-FI';
    }
    return 'OFFLINE';
  }

  Map<String, dynamic> get dataSummaryMetrics {
    int totalSessions = 0;
    int totalDuration = 0;
    for (final c in _status.clients) {
      totalSessions += c.history.length;
      if (c.totalSecondsToday >= 60) {
        totalSessions += 1; // Count today's ongoing/stopped aggregate as a session if >= 1m
      }
      totalDuration += c.totalAccumulatedSecs;
    }
    return {
      'sectionsCount': _status.clients.length,
      'sessionsCount': totalSessions,
      'totalHours': (totalDuration / 3600.0).toStringAsFixed(1),
      'tasksCount': _tasks.length,
      'remindersCount': _reminders.length,
      'currentStreak': _status.currentStreak,
      'longestStreak': _status.longestStreak,
      'lastBackup': lastBackupDateFormatted,
    };
  }

  int get remainingSeconds {
    final target = _countdownTargetMinutes * 60;
    final elapsed = _status.sessionSeconds;
    final rem = target - elapsed;
    return rem > 0 ? rem : 0;
  }

  int get displaySeconds {
    if (_timerMode == TimerMode.countDown) {
      return remainingSeconds;
    }
    return _status.sessionSeconds;
  }

  bool get isCountdownCompleted =>
      _timerMode == TimerMode.countDown &&
      _status.state == TrackerState.tracking &&
      _status.sessionSeconds >= (_countdownTargetMinutes * 60);

  ClientSection? get activeClient {
    try {
      return _status.clients.firstWhere((c) => c.id == _status.activeClientId);
    } catch (_) {
      return _status.clients.isNotEmpty ? _status.clients.first : null;
    }
  }

  Future<void> _loadSettings({bool autoStartPolling = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(AppConstants.prefDeviceHost) ?? AppConstants.defaultEspIp;
    _apiService.host = _host;

    final savedTheme = prefs.getString('pref_ui_theme') ?? 'dark';
    _themeStyle = savedTheme == 'light' ? UiThemeStyle.light : UiThemeStyle.dark;
    AppTheme.currentStyle = _themeStyle;

    final savedProtocol = prefs.getString('pref_sync_protocol') ?? 'wifi';
    _protocol = savedProtocol == 'wifi' ? SyncProtocol.wifi : SyncProtocol.bluetooth;

    _lastBleDeviceId = prefs.getString('pref_last_ble_device_id');
    _lastBleDeviceName = prefs.getString('pref_last_ble_device_name');
    if (_lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
      _bleService.setTargetDeviceId(_lastBleDeviceId);
    }

    // Restore cached device status, tasks, and reminders for instantaneous offline render
    final cachedStatus = prefs.getString('pref_cached_status');
    if (cachedStatus != null && cachedStatus.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedStatus) as Map<String, dynamic>;
        _status = DeviceStatus.fromJson(decoded);
        if (decoded['tasks'] is List) {
          _tasks = (decoded['tasks'] as List)
              .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
              .toList();
        }
        if (decoded['reminders'] is List) {
          _reminders = (decoded['reminders'] as List)
              .map((r) => ReminderItem.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[TrackerProvider] Cache restore error: $e');
      }
    }

    final savedTimerMode = prefs.getString('pref_timer_mode') ?? 'countUp';
    _timerMode = savedTimerMode == 'countDown' ? TimerMode.countDown : TimerMode.countUp;
    _countdownTargetMinutes = prefs.getInt('pref_countdown_minutes') ?? 25;

    final lastBackupStr = prefs.getString('pref_last_backup_date');
    if (lastBackupStr != null && lastBackupStr.isNotEmpty) {
      _lastBackupDate = DateTime.tryParse(lastBackupStr);
    }

    _pendingResetOnConnect = prefs.getBool('pref_pending_reset') ?? false;
    final rawQueue = prefs.getString('pref_pending_sync_queue');
    if (rawQueue != null && rawQueue.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawQueue) as List<dynamic>;
        _pendingSyncQueue = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('[TrackerProvider] Error loading pending sync queue: $e');
      }
    }

    // If restored state was tracking, resume local ticker
    if (_status.state == TrackerState.tracking) {
      _startLocalTicker();
    }

    // Listen to BLE connection changes
    _bleConnSub = _bleService.connectionStateStream.listen((connected) async {
      if (connected) {
        _isOnline = true;
        _consecutiveWifiFailures = 0;
        _protocol = SyncProtocol.bluetooth;
        _stopLocalTicker();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pref_sync_protocol', 'bluetooth');
          if (_bleService.connectedDeviceAddress != null) {
            _lastBleDeviceId = _bleService.connectedDeviceAddress;
            await prefs.setString('pref_last_ble_device_id', _lastBleDeviceId!);
          }
          if (_bleService.connectedDeviceName != null) {
            _lastBleDeviceName = _bleService.connectedDeviceName;
            await prefs.setString('pref_last_ble_device_name', _lastBleDeviceName!);
          }
        } catch (_) {}
        stopPolling();
        syncTimeToDevice();
        unawaited(_flushPendingSyncQueue());
        notifyListeners();
      } else {
        if (_protocol == SyncProtocol.bluetooth) {
          _isOnline = false;
          if (_status.state == TrackerState.tracking) {
            _startLocalTicker();
          }
        }
        notifyListeners();
      }
    });

    // Listen to BLE telemetry stream
    _bleTelemetrySub = _bleService.telemetryStream.listen((data) {
      if (_protocol == SyncProtocol.bluetooth || _bleService.isConnected) {
        _handleBleTelemetry(data);
      }
    });

    if (_protocol == SyncProtocol.wifi) {
      await refreshData();
      if (autoStartPolling) {
        startPolling();
      }
    } else {
      notifyListeners();
    }
    
    // Set current active date if not set, and start midnight checking
    final currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    if (prefs.getString('pref_last_active_date') == null) {
      await prefs.setString('pref_last_active_date', currentDate);
    }
    _checkLocalMidnightRollover();
    _startMidnightTimer();
  }

  Future<void> _saveCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _status.toJson();
      data['tasks'] = _tasks.map((t) => t.toJson()).toList();
      data['reminders'] = _reminders.map((r) => r.toJson()).toList();
      data['checklist'] = _checklist.map((c) => c.toJson()).toList();
      await prefs.setString('pref_cached_status', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _savePendingSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_pending_sync_queue', jsonEncode(_pendingSyncQueue));
    } catch (_) {}
  }

  Future<void> _savePendingReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_pending_reset', _pendingResetOnConnect);
    } catch (_) {}
  }

  void _enqueueSyncCommand(Map<String, dynamic> cmd) {
    _pendingSyncQueue.add(cmd);
    _savePendingSyncQueue();
    if (_bleService.isConnected && !_isFlushingQueue) {
      unawaited(_flushPendingSyncQueue());
    }
  }

  Future<void> _flushPendingSyncQueue() async {
    if (_isFlushingQueue || !_bleService.isConnected) return;
    _isFlushingQueue = true;

    try {
      if (_pendingResetOnConnect) {
        debugPrint('[TrackerProvider] Flushing pending hard reset command to hardware...');
        final ok = await _bleService.sendCommand({'action': 'reset_all'});
        if (ok) {
          _pendingResetOnConnect = false;
          _pendingSyncQueue.clear();
          await _savePendingReset();
          await _savePendingSyncQueue();
          _isFlushingQueue = false;
          return;
        }
      }

      if (_pendingSyncQueue.isNotEmpty) {
        debugPrint('[TrackerProvider] Flushing ${_pendingSyncQueue.length} pending commands to hardware...');
        
        final queueCopy = List<Map<String, dynamic>>.from(_pendingSyncQueue);
        _pendingSyncQueue.clear();
        
        for (int i = 0; i < queueCopy.length; i++) {
          final cmd = queueCopy[i];
          if (!_bleService.isConnected) {
            _pendingSyncQueue.insertAll(0, queueCopy.sublist(i));
            await _savePendingSyncQueue();
            break;
          }
          
          try {
            final ok = await _bleService.sendCommand(cmd);
            if (ok) {
              await _savePendingSyncQueue();
              await Future.delayed(const Duration(milliseconds: 120));
            } else {
              _pendingSyncQueue.insertAll(0, queueCopy.sublist(i));
              await _savePendingSyncQueue();
              break;
            }
          } catch (e) {
            debugPrint('[TrackerProvider] Error flushing cmd $cmd: $e');
            _pendingSyncQueue.insertAll(0, queueCopy.sublist(i));
            await _savePendingSyncQueue();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[TrackerProvider] _flushPendingSyncQueue exception: $e');
    } finally {
      _isFlushingQueue = false;
    }
  }

  Future<void> _saveTimerPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_timer_mode', _timerMode == TimerMode.countDown ? 'countDown' : 'countUp');
      await prefs.setInt('pref_countdown_minutes', _countdownTargetMinutes);
    } catch (_) {}
  }

  void setTimerMode(TimerMode mode) {
    if (_timerMode != mode) {
      _timerMode = mode;
      notifyListeners();
      _saveTimerPreferences();
    }
  }

  void toggleTimerMode() {
    setTimerMode(_timerMode == TimerMode.countUp ? TimerMode.countDown : TimerMode.countUp);
  }

  void setCountdownDuration(int minutes) {
    if (minutes > 0) {
      _countdownTargetMinutes = minutes;
      notifyListeners();
      _saveTimerPreferences();
    }
  }

  void _startLocalTicker() {
    // If connected via BLE, hardware sends 1Hz telemetry. Do not run local ticker to avoid phase jitter.
    if (_protocol == SyncProtocol.bluetooth && _bleService.isConnected) {
      return;
    }
    _localTicker?.cancel();
    _localTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status.state != TrackerState.tracking) {
        _localTicker?.cancel();
        _localTicker = null;
        return;
      }

      final nextSessionSecs = _status.sessionSeconds + 1;
      final activeId = _status.activeClientId;
      final curClient = activeClient;
      final isNegative = curClient?.isNegative ?? false;

      final nextDwSecs = isNegative ? _status.totalDeepWorkToday : _status.totalDeepWorkToday + 1;
      final nextWasteSecs = isNegative ? _status.totalWasteToday + 1 : _status.totalWasteToday;
      final totalTracked = nextDwSecs + nextWasteSecs;
      final nextPurity = totalTracked > 0 ? ((nextDwSecs * 100) / totalTracked).round() : 100;

      // Update active client totalSecondsToday as well
      final updatedClients = _status.clients.map((c) {
        if (c.id == activeId) {
          return c.copyWith(totalSecondsToday: c.totalSecondsToday + 1);
        }
        return c;
      }).toList();

      _status = _status.copyWith(
        sessionSeconds: nextSessionSecs,
        totalDeepWorkToday: nextDwSecs,
        totalWasteToday: nextWasteSecs,
        focusPurityPct: nextPurity,
        clients: updatedClients,
      );

      // Alert upon countdown completion
      if (_timerMode == TimerMode.countDown && nextSessionSecs == (_countdownTargetMinutes * 60)) {
        AppTheme.hapticAction();
      }

      notifyListeners();
    });
  }

  void _stopLocalTicker() {
    _localTicker?.cancel();
    _localTicker = null;
  }

  Future<void> setThemeStyle(UiThemeStyle newStyle) async {
    _themeStyle = newStyle;
    AppTheme.currentStyle = newStyle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_ui_theme', newStyle == UiThemeStyle.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeStyle(_themeStyle == UiThemeStyle.dark ? UiThemeStyle.light : UiThemeStyle.dark);
  }

  Future<void> setSyncProtocol(SyncProtocol proto) async {
    _protocol = proto;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_sync_protocol', proto == SyncProtocol.bluetooth ? 'bluetooth' : 'wifi');

    if (proto == SyncProtocol.wifi) {
      await _bleService.disconnect();
      startPolling();
      await refreshData();
    } else {
      stopPolling();
      _isOnline = _bleService.isConnected;
      if (!_bleService.isConnected && _lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
        debugPrint('[TrackerProvider] Switched to Bluetooth mode: Auto-connecting $_lastBleDeviceId...');
        unawaited(_bleService.connectWithId(_lastBleDeviceId!));
      }
      notifyListeners();
    }
  }

  Future<bool> connectBle(BluetoothDevice device) async {
    final ok = await _bleService.connect(device);
    if (ok) {
      _lastBleDeviceId = device.remoteId.str;
      _lastBleDeviceName = device.platformName.isNotEmpty ? device.platformName : 'CRANIUM-X1';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_last_ble_device_id', _lastBleDeviceId!);
      await prefs.setString('pref_last_ble_device_name', _lastBleDeviceName!);
      await setSyncProtocol(SyncProtocol.bluetooth);
    }
    return ok;
  }

  Future<void> forgetBleDevice() async {
    await _bleService.disconnect(clearTarget: true);
    _lastBleDeviceId = null;
    _lastBleDeviceName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_last_ble_device_id');
    await prefs.remove('pref_last_ble_device_name');
    notifyListeners();
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_protocol == SyncProtocol.wifi && !_bleService.isConnected) {
        _pollStatus();
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _handleBleTelemetry(Map<String, dynamic> data) {
    final stateStr = data['state'] as String? ?? 'IDLE';
    final dwSecs = (data['dwSecs'] as num?)?.toInt() ?? 0;
    final streak = (data['streak'] as num?)?.toInt() ?? 0;
    final goal = (data['goal'] as num?)?.toInt() ?? 36000;
    final sessionSecs = (data['sessionSecs'] as num?)?.toInt() ?? 0;
    final clientId = (data['clientId'] as num?)?.toInt() ?? 0;
    final brightness = (data['brightness'] as num?)?.toInt() ?? 255;

    final newState = TrackerState.fromString(stateStr);

    List<ClientSection> updatedClients = List.from(_status.clients);
    if (data['clients'] is List && (data['clients'] as List).isNotEmpty) {
      updatedClients = (data['clients'] as List).map((c) {
        final m = c as Map<String, dynamic>;
        final id = (m['id'] as num?)?.toInt() ?? 0;
        final name = m['name'] as String? ?? 'Section';
        final todaySecs = (m['todaySecs'] as num?)?.toInt() ?? 0;
        final existingIdx = _status.clients.indexWhere((x) => x.id == id);
        final bool isNeg = (m['isNegative'] as bool?) ??
            (existingIdx != -1 ? _status.clients[existingIdx].isNegative : false);
        final existingHist = existingIdx != -1 ? _status.clients[existingIdx].history : <HistoryEntry>[];
        final existingReps = (m['reps'] as num?)?.toInt() ??
            (m['tally'] as num?)?.toInt() ??
            (m['tallyCount'] as num?)?.toInt() ??
            (existingIdx != -1 ? _status.clients[existingIdx].reps : 0);
        return ClientSection(
          id: id,
          name: name,
          totalSecondsToday: todaySecs,
          reps: existingReps,
          history: existingHist,
          isNegative: isNeg,
        );
      }).toList();
    } else if (data['client'] != null && (data['client'] as String).isNotEmpty && clientId > 0) {
      final activeName = data['client'] as String;
      final existingIdx = updatedClients.indexWhere((c) => c.id == clientId);
      final bool isNeg = (data['isNegative'] as bool?) ??
          (existingIdx != -1 ? updatedClients[existingIdx].isNegative : false);
      if (existingIdx == -1) {
        updatedClients.add(ClientSection(
          id: clientId,
          name: activeName,
          totalSecondsToday: (data['todaySecs'] as num?)?.toInt() ?? 0,
          reps: (data['reps'] as num?)?.toInt() ?? 0,
          isNegative: isNeg,
        ));
      } else {
        updatedClients[existingIdx] = updatedClients[existingIdx].copyWith(isNegative: isNeg);
      }
    }

    if (data['isNegative'] != null && clientId > 0) {
      final bool activeIsNeg = data['isNegative'] as bool;
      final actIdx = updatedClients.indexWhere((c) => c.id == clientId);
      if (actIdx != -1 && updatedClients[actIdx].isNegative != activeIsNeg) {
        updatedClients[actIdx] = updatedClients[actIdx].copyWith(isNegative: activeIsNeg);
      }
    }

    // Hardware BLE telemetry is authoritative at 1Hz; stop local ticker to prevent phase conflicts
    _stopLocalTicker();
    final int finalSessionSecs = sessionSecs;

    int computedWaste = 0;
    for (final c in updatedClients) {
      if (c.isNegative) {
        computedWaste += c.totalSecondsToday;
      }
    }
    if ((newState == TrackerState.tracking || newState == TrackerState.paused) && clientId > 0) {
      if (updatedClients.isNotEmpty) {
        final act = updatedClients.firstWhere((c) => c.id == clientId, orElse: () => updatedClients.first);
        if (act.isNegative) {
          computedWaste += finalSessionSecs;
        }
      }
    }
    final wasteSecs = (data['globalWasteSecondsToday'] as num?)?.toInt() ??
        (data['wasteSecs'] as num?)?.toInt() ??
        (data['totalWasteToday'] as num?)?.toInt() ??
        (computedWaste > 0 ? computedWaste : _status.totalWasteToday);
    final totalTracked = dwSecs + wasteSecs;
    final defaultPurity = totalTracked > 0 ? ((dwSecs * 100) / totalTracked).round() : 100;
    final purity = (data['focusPurityPct'] as num?)?.toInt() ?? defaultPurity;

    if (!_pendingResetOnConnect) {
      if (data['tasks'] is List) {
        final incomingTasks = (data['tasks'] as List)
            .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
            .toList();
        if (!_pendingSyncQueue.any((c) => c['action'].toString().contains('task')) && !_isFlushingQueue) {
          _tasks = incomingTasks;
        }
      }
      if (data['reminders'] is List) {
        final incomingReminders = (data['reminders'] as List)
            .map((r) => ReminderItem.fromJson(r as Map<String, dynamic>))
            .toList();
        if (!_pendingSyncQueue.any((c) => c['action'].toString().contains('reminder')) && !_isFlushingQueue) {
          _reminders = incomingReminders;
        }
      }
      
      if (data['checklist'] is List) {
        final incomingChecklist = (data['checklist'] as List)
            .map((c) => ChecklistItem.fromJson(c as Map<String, dynamic>))
            .toList();
        if (!_pendingSyncQueue.any((c) => c['action'] == 'save_checklist') && !_isFlushingQueue) {
          _checklist = incomingChecklist;
        }
      }
    }

    _status = DeviceStatus(
      state: newState,
      activeClientId: clientId > 0 ? clientId : _status.activeClientId,
      sessionSeconds: finalSessionSecs,
      totalDeepWorkToday: dwSecs,
      totalWasteToday: wasteSecs,
      focusPurityPct: purity,
      globalGoal: goal,
      brightness: brightness,
      currentStreak: streak,
      longestStreak: _status.longestStreak > streak ? _status.longestStreak : streak,
      wellnessEnabled: (data['wellnessEnabled'] as bool?) ?? _status.wellnessEnabled,
      wellnessIntervalMinutes: (data['wellnessIntervalMin'] as num?)?.toInt() ?? _status.wellnessIntervalMinutes,
      wellnessMode: (data['wellnessMode'] as num?)?.toInt() ?? _status.wellnessMode,
      powerbankKeepAlive: (data['powerbank'] as bool?) ?? _status.powerbankKeepAlive,
      isAwayMode: (data['awayMode'] as bool?) ?? true,
      clients: updatedClients.isNotEmpty ? updatedClients : _status.clients,
      tasks: _tasks,
      reminders: _reminders,
    );
    _isOnline = true;
    _lastSync = DateTime.now();
    notifyListeners();
    _saveCachedStatus();
  }

  Future<void> setHost(String newHost) async {
    _host = newHost;
    _apiService.host = newHost;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefDeviceHost, newHost);
    await refreshData();
  }

  Future<void> refreshData() async {
    if (_protocol == SyncProtocol.bluetooth) return;
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_protocol == SyncProtocol.wifi) {
        final results = await Future.wait([
          _apiService.fetchStatus(),
          _apiService.fetchTasks(),
          _apiService.fetchReminders(),
        ]);

        final newStatus = results[0] as DeviceStatus;
        _isOnline = true;

        if (newStatus.state == TrackerState.tracking) {
          if (_localTicker == null) {
            _startLocalTicker();
          }
          final delta = (newStatus.sessionSeconds - _status.sessionSeconds).abs();
          if (delta <= 2) {
            _status = newStatus.copyWith(sessionSeconds: _status.sessionSeconds);
          } else {
            _status = newStatus;
      _checklist = newStatus.checklist;
          }
        } else {
          _stopLocalTicker();
          _status = newStatus;
      _checklist = newStatus.checklist;
        }

        _tasks = results[1] as List<TaskItem>;
        _reminders = results[2] as List<ReminderItem>;
        _lastSync = DateTime.now();
        _saveCachedStatus();
      }
    } catch (e) {
      debugPrint('[TrackerProvider] Refresh error: $e');
      _isOnline = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _pollStatus() async {
    if (_protocol == SyncProtocol.bluetooth || _bleService.isConnected || _isPolling) return;
    _isPolling = true;
    try {
      final newStatus = await _apiService.fetchStatus();
      _isOnline = true;
      _consecutiveWifiFailures = 0;
      _lastSync = DateTime.now();

      if (newStatus.state == TrackerState.tracking) {
        if (_localTicker == null) {
          _startLocalTicker();
        }
        final delta = (newStatus.sessionSeconds - _status.sessionSeconds).abs();
        if (delta <= 2) {
          _status = newStatus.copyWith(sessionSeconds: _status.sessionSeconds);
        } else {
          _status = newStatus;
      _checklist = newStatus.checklist;
        }
      } else {
        _stopLocalTicker();
        _status = newStatus;
      _checklist = newStatus.checklist;
      }

      _saveCachedStatus();
      notifyListeners();
    } catch (_) {
      _consecutiveWifiFailures++;
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
      if (_consecutiveWifiFailures >= 3 && _protocol == SyncProtocol.wifi) {
        _attemptAwayFailover();
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _attemptAwayFailover() async {
    if (_isAutoConnectingBle || _bleService.isConnected) return;
    _isAutoConnectingBle = true;

    try {
      // 1. Try SoftAP IP 192.168.4.1 if not already using it
      if (!_host.contains('192.168.4.1')) {
        final originalHost = _apiService.host;
        _apiService.host = '192.168.4.1';
        try {
          final testStatus = await _apiService.fetchStatus().timeout(const Duration(milliseconds: 1200));
          _host = '192.168.4.1';
          _status = testStatus;
          _isOnline = true;
          _consecutiveWifiFailures = 0;
          notifyListeners();
          _isAutoConnectingBle = false;
          return;
        } catch (_) {
          _apiService.host = originalHost;
        }
      }

      // 2. Try BLE auto-connect
      if (_lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
        debugPrint('[TrackerProvider] Away from home: Trying direct connection to saved device $_lastBleDeviceId...');
        final ok = await _bleService.connectWithId(_lastBleDeviceId!);
        if (ok) {
          _protocol = SyncProtocol.bluetooth;
          _isOnline = true;
          _consecutiveWifiFailures = 0;
          await syncTimeToDevice();
          notifyListeners();
          return;
        }
      }

      debugPrint('[TrackerProvider] Away from home: Scanning for Cranium BLE...');
      await _bleService.startScan(timeout: const Duration(seconds: 4));
      StreamSubscription? scanSubscription;
      bool connected = false;
      scanSubscription = _bleService.craniumScanResults.listen((results) async {
        if (connected || _bleService.isConnected) return;
        if (results.isNotEmpty) {
          connected = true;
          await scanSubscription?.cancel();
          await _bleService.stopScan();
          final ok = await _bleService.connect(results.first.device);
          if (ok) {
            _protocol = SyncProtocol.bluetooth;
            _isOnline = true;
            _consecutiveWifiFailures = 0;
            await syncTimeToDevice();
            notifyListeners();
          }
        }
      });

      await Future.delayed(const Duration(seconds: 4));
      await scanSubscription.cancel();
      await _bleService.stopScan();
    } catch (e) {
      debugPrint('[TrackerProvider] Away failover error: $e');
    } finally {
      _isAutoConnectingBle = false;
    }
  }

  Future<bool> _dispatchDeviceCommand({
    required Map<String, dynamic> bleCommand,
    Future<dynamic> Function()? wifiFallback,
    bool queueIfOffline = false,
  }) async {
    if (_bleService.isConnected) {
      try {
        final ok = await _bleService.sendCommand(bleCommand);
        if (ok) return true;
      } catch (e) {
        debugPrint('[TrackerProvider] BLE sendCommand error: $e');
      }
    }

    if (_protocol == SyncProtocol.bluetooth && !_bleService.isConnected && _lastBleDeviceId != null && _lastBleDeviceId!.isNotEmpty) {
      unawaited(_bleService.connectWithId(_lastBleDeviceId!));
    }

    if (wifiFallback != null) {
      if (_protocol == SyncProtocol.wifi && _isOnline) {
        try {
          await wifiFallback();
          return true;
        } catch (e) {
          debugPrint('[TrackerProvider] Wi-Fi command error: $e');
        }
      }
    }

    if (queueIfOffline) {
      debugPrint('[TrackerProvider] Device offline. Enqueuing command into persistent sync queue: $bleCommand');
      _enqueueSyncCommand(bleCommand);
    }

    return false;
  }
  Future<bool> syncTimeToDevice() async {
    final now = DateTime.now();
    final utcEpoch = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final tzOffset = now.timeZoneOffset.inSeconds;
    
    return await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'sync_time',
        'epoch': utcEpoch,
        'tz_offset': tzOffset,
      },
      wifiFallback: () => _apiService.syncTime(utcEpoch, tzOffset),
    );
  }

  Future<bool> togglePowerBankKeepAlive([bool? targetState]) async {
    final newState = targetState ?? !_status.powerbankKeepAlive;
    _status = _status.copyWith(powerbankKeepAlive: newState);
    notifyListeners();

    return await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'powerbank',
        'enabled': newState,
      },
      wifiFallback: () => _apiService.setPowerBankKeepAlive(newState),
    );
  }

  // --- Task Operations ---

  Future<void> addTask(String text, int stars) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final maxId = _tasks.fold<int>(0, (prev, t) => t.id > prev ? t.id : prev);
    final tempId = maxId + 1;
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newTask = TaskItem(
      id: tempId,
      text: trimmed,
      stars: stars.clamp(1, 3),
      done: false,
      createdAt: nowStr,
    );
    _tasks.add(newTask);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'add_task',
        'text': trimmed,
        'stars': stars.clamp(1, 3),
      },
      queueIfOffline: true,
      wifiFallback: () async {
        final serverId = await _apiService.addTask(trimmed, stars);
        if (serverId != null && serverId != tempId) {
          final idx = _tasks.indexWhere((t) => t.id == tempId);
          if (idx != -1) {
            _tasks[idx] = TaskItem(
              id: serverId,
              text: trimmed,
              stars: stars,
              done: false,
              createdAt: nowStr,
            );
            notifyListeners();
            _saveCachedStatus();
          }
        }
      },
    );
  }

  Future<void> toggleTask(int id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final current = _tasks[idx];
    _tasks[idx] = TaskItem(
      id: current.id,
      text: current.text,
      stars: current.stars,
      done: !current.done,
      createdAt: current.createdAt,
    );
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'toggle_task',
        'id': id,
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.toggleTask(id),
    );
  }

  Future<void> deleteTask(int id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    _tasks.removeAt(idx);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'delete_task',
        'id': id,
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.deleteTask(id),
    );
  }

  Future<void> updateTask(int id, {String? text, int? stars, bool? done}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final current = _tasks[idx];
    final updatedText = (text != null && text.trim().isNotEmpty) ? text.trim() : current.text;
    final updatedStars = stars != null ? stars.clamp(1, 3) : current.stars;
    final updatedDone = done ?? current.done;

    _tasks[idx] = TaskItem(
      id: current.id,
      text: updatedText,
      stars: updatedStars,
      done: updatedDone,
      createdAt: current.createdAt,
    );
    notifyListeners();
    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'update_task',
        'id': id,
        'text': updatedText,
        'stars': updatedStars,
        'done': updatedDone,
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.updateTask(id, text: updatedText, stars: updatedStars, done: updatedDone),
    );
  }

  // --- Reminder Operations ---

  Future<void> addReminder(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final maxId = _reminders.fold<int>(0, (prev, r) => r.id > prev ? r.id : prev);
    final tempId = maxId + 1;
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newRem = ReminderItem(id: tempId, text: trimmed, createdAt: nowStr);
    _reminders.add(newRem);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'add_reminder',
        'text': trimmed,
      },
      queueIfOffline: true,
      wifiFallback: () async {
        final serverId = await _apiService.addReminder(trimmed);
        if (serverId != null && serverId != tempId) {
          final idx = _reminders.indexWhere((r) => r.id == tempId);
          if (idx != -1) {
            _reminders[idx] = ReminderItem(id: serverId, text: trimmed, createdAt: nowStr);
            notifyListeners();
            _saveCachedStatus();
          }
        }
      },
    );
  }

  Future<void> deleteReminder(int id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    _reminders.removeAt(idx);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'delete_reminder',
        'id': id,
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.deleteReminder(id),
    );
  }

  Future<void> updateReminder(int id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final current = _reminders[idx];
    _reminders[idx] = ReminderItem(
      id: current.id,
      text: trimmed,
      createdAt: current.createdAt,
    );
    notifyListeners();
    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'update_reminder',
        'id': id,
        'text': trimmed,
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.updateReminder(id, trimmed),
    );
  }

  // --- Section Operations ---

  Future<void> saveChecklist(List<ChecklistItem> newList) async {
    _checklist = newList;
    _saveCachedStatus();
    notifyListeners();
    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'save_checklist',
        'items': newList.map((e) => e.toJson()).toList(),
      },
      queueIfOffline: true,
      wifiFallback: () => _apiService.saveChecklist(newList),
    );
  }

  Future<bool> addSection(String name, {bool isNegative = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final maxId = _status.clients.fold<int>(0, (prev, c) => c.id > prev ? c.id : prev);
    final newId = maxId + 1;
    final newSection = ClientSection(
      id: newId,
      name: trimmed,
      totalSecondsToday: 0,
      reps: 0,
      history: [],
      isNegative: isNegative,
    );
    final updatedClients = [..._status.clients, newSection];
    _status = _status.copyWith(clients: updatedClients);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'add_section',
        'name': trimmed,
        'isNegative': isNegative,
      },
      queueIfOffline: true,
      wifiFallback: () async {
        await _apiService.addSection(trimmed, isNegative: isNegative);
        await refreshData();
      },
    );
    return true;
  }

  Future<bool> toggleSectionNegative(int id, bool isNegative) async {
    final updatedClients = _status.clients.map((c) {
      if (c.id == id) {
        return c.copyWith(isNegative: isNegative);
      }
      return c;
    }).toList();

    // Recompute DW and Waste
    int dw = 0;
    int waste = 0;
    for (final c in updatedClients) {
      if (c.isNegative) {
        waste += c.totalSecondsToday;
      } else {
        dw += c.totalSecondsToday;
      }
    }
    final totalTracked = dw + waste;
    final purity = totalTracked > 0 ? ((dw * 100) / totalTracked).round() : 100;

    _status = _status.copyWith(
      clients: updatedClients,
      totalDeepWorkToday: dw,
      totalWasteToday: waste,
      focusPurityPct: purity,
    );
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'toggle_negative',
        'id': id,
        'isNegative': isNegative,
      },
      queueIfOffline: true,
      wifiFallback: () async {
        await _apiService.updateSectionNegative(id, isNegative);
        await refreshData();
      },
    );
    return true;
  }

  Future<bool> deleteSection(int id) async {
    final updatedClients = _status.clients.where((c) => c.id != id).toList();
    if (updatedClients.isEmpty) return false;

    int newActiveId = _status.activeClientId;
    if (newActiveId == id) {
      newActiveId = updatedClients.first.id;
    }

    _status = _status.copyWith(
      clients: updatedClients,
      activeClientId: newActiveId,
    );
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'delete_section',
        'id': id,
      },
      queueIfOffline: true,
      wifiFallback: () async {
        await _apiService.deleteSection(id);
        await refreshData();
      },
    );
    return true;
  }

  // --- Session Controls ---

  Future<void> selectSection(int clientId) async {
    if (_status.activeClientId == clientId) return;

    final int clientIdx = _status.clients.indexWhere((c) => c.id == clientId);

    _status = _status.copyWith(activeClientId: clientId);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'select',
        'id': clientId,
        'index': clientIdx >= 0 ? clientIdx : 0,
      },
      wifiFallback: () async {
        await _apiService.selectSection(clientId);
        await Future.delayed(const Duration(milliseconds: 100));
        await _pollStatus();
      },
    );
  }

  Future<void> startSession(int clientId) async {
    final int clientIdx = _status.clients.indexWhere((c) => c.id == clientId);

    _status = _status.copyWith(
      state: TrackerState.tracking,
      activeClientId: clientId,
      sessionSeconds: 0,
    );
    _startLocalTicker();
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {
        'action': 'start',
        'id': clientId,
        'index': clientIdx >= 0 ? clientIdx : 0,
      },
      wifiFallback: () => _apiService.startSession(clientId),
    );
  }

  Future<void> pauseSession() async {
    _stopLocalTicker();
    _status = _status.copyWith(state: TrackerState.paused);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'pause'},
      wifiFallback: () => _apiService.pauseSession(),
    );
  }

  Future<void> resumeSession() async {
    _status = _status.copyWith(state: TrackerState.tracking);
    _startLocalTicker();
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'resume'},
      wifiFallback: () => _apiService.resumeSession(),
    );
  }

  Future<void> stopSession() async {
    _stopLocalTicker();
    final elapsed = _status.sessionSeconds;
    final activeClient = _status.activeClient;

    List<ClientSection> updatedClients = List.from(_status.clients);
    if (elapsed > 0 && activeClient != null) {
      final now = DateTime.now();
      final dateLabel = DateFormat('dd MMM yyyy').format(now);
      final timestampStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final newEntry = HistoryEntry(
        timestamp: timestampStr,
        date: dateLabel,
        seconds: elapsed,
        reps: activeClient.reps,
      );

      final idx = updatedClients.indexWhere((c) => c.id == activeClient.id);
      if (idx != -1) {
        final existing = updatedClients[idx];
        final newHist = [newEntry, ...existing.history];
        updatedClients[idx] = existing.copyWith(
          history: newHist.length > 50 ? newHist.sublist(0, 50) : newHist,
        );
      }
    }

    _status = _status.copyWith(
      state: TrackerState.idle,
      sessionSeconds: 0,
      clients: updatedClients,
    );
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'stop'},
      wifiFallback: () => _apiService.stopSession(),
    );
  }

  Future<void> triggerStressBuster() async {
    await _dispatchDeviceCommand(
      bleCommand: {'action': 'stress_buster'},
      wifiFallback: () async {
        await _apiService.triggerStressBuster();
        await _pollStatus();
      },
    );
  }

  Future<void> adjustRep({required bool increment}) async {
    final activeId = _status.activeClientId;
    final updatedClients = _status.clients.map((c) {
      if (c.id == activeId) {
        final newReps = increment ? c.reps + 1 : (c.reps > 0 ? c.reps - 1 : 0);
        return c.copyWith(reps: newReps);
      }
      return c;
    }).toList();

    _status = _status.copyWith(clients: updatedClients);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': increment ? 'rep_plus' : 'rep_minus'},
      wifiFallback: () => _apiService.adjustRep(increment: increment),
    );
  }

  Future<void> setBrightness(int val) async {
    _status = _status.copyWith(brightness: val);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'set_brightness', 'level': val},
      wifiFallback: () => _apiService.setBrightness(val),
    );
  }

  // --- Hydration & Stand/Stretch Wellness Reminders ---

  bool get wellnessEnabled => _status.wellnessEnabled;
  int get wellnessIntervalMinutes => _status.wellnessIntervalMinutes;
  int get wellnessMode => _status.wellnessMode;

  Future<void> toggleWellness() async {
    final nextState = !_status.wellnessEnabled;
    _status = _status.copyWith(wellnessEnabled: nextState);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'wellness', 'enabled': nextState},
      wifiFallback: () => _apiService.updateWellness(enabled: nextState),
    );
  }

  Future<void> setWellnessInterval(int minutes) async {
    final clamped = minutes.clamp(15, 180);
    _status = _status.copyWith(wellnessIntervalMinutes: clamped);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'wellness', 'interval': clamped},
      wifiFallback: () => _apiService.updateWellness(interval: clamped),
    );
  }

  Future<void> setWellnessMode(int mode) async {
    final clamped = mode.clamp(0, 2);
    _status = _status.copyWith(wellnessMode: clamped);
    notifyListeners();
    _saveCachedStatus();

    await _dispatchDeviceCommand(
      bleCommand: {'action': 'wellness', 'mode': clamped},
      wifiFallback: () => _apiService.updateWellness(mode: clamped),
    );
  }

  Future<void> testWellnessAlert({int kind = 0}) async {
    await _dispatchDeviceCommand(
      bleCommand: {'action': 'test_wellness', 'kind': kind},
      wifiFallback: () => _apiService.testWellnessAlert(kind: kind),
    );
  }

  // --- Factory Data Reset ---

  Future<bool> resetAllData() async {
    _pendingSyncQueue.clear();
    await _savePendingSyncQueue();

    bool sent = await _dispatchDeviceCommand(
      bleCommand: {'action': 'reset_all'},
      wifiFallback: () => _apiService.resetAll(),
    );

    if (!sent) {
      _pendingResetOnConnect = true;
      await _savePendingReset();
    } else {
      _pendingResetOnConnect = false;
      await _savePendingReset();
    }

    _status = const DeviceStatus();
    _tasks.clear();
    _reminders.clear();
    _lastBackupDate = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pref_last_backup_date');
    } catch (_) {}

    notifyListeners();
    await _saveCachedStatus();
    if (_protocol == SyncProtocol.wifi && _isOnline) {
      await refreshData();
    }
    return true;
  }

  Future<void> recordBackupCompleted() async {
    _lastBackupDate = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_last_backup_date', _lastBackupDate!.toIso8601String());
    } catch (e) {
      debugPrint('[TrackerProvider] recordBackupCompleted error: $e');
    }
    notifyListeners();
  }

  // --- Data Import & Restore ---

  Future<bool> importData({
    required ImportPreviewResult preview,
    required bool overwrite,
  }) async {
    // 1. Transactional safety snapshot for atomic rollback
    final previousStatus = _status;
    final previousTasks = List<TaskItem>.from(_tasks);
    final previousReminders = List<ReminderItem>.from(_reminders);

    try {
      String payloadToPush = preview.synthesizedJson;

      if (!overwrite && _status.clients.isNotEmpty) {
        final Map<String, ClientSection> mergedClients = {};
        for (final c in _status.clients) {
          mergedClients[c.name.trim().toLowerCase()] = c;
        }

        for (final imported in preview.clients) {
          final name = (imported['name'] ?? '').toString().trim();
          final key = name.toLowerCase();
          final rawToday = imported['totalSecsToday'] ?? imported['totalSecondsToday'];
          final impToday = rawToday is num ? rawToday.toInt() : (int.tryParse(rawToday?.toString() ?? '') ?? 0);
          final rawClientReps = imported['reps'] ?? imported['tallyCount'];
          final impReps = rawClientReps is num ? rawClientReps.toInt() : (int.tryParse(rawClientReps?.toString() ?? '') ?? 0);
          final impHistory = (imported['history'] as List<dynamic>?) ?? [];

          if (mergedClients.containsKey(key)) {
            final existing = mergedClients[key]!;
            final combinedHistory = List<HistoryEntry>.from(existing.history);
            for (final h in impHistory) {
              if (h is Map) {
                final date = (h['date'] ?? '').toString().trim();
                final timestamp = (h['timestamp'] ?? date).toString().trim();
                final rawSecs = h['secs'] ?? h['seconds'];
                final int secs = rawSecs is num ? rawSecs.toInt() : (int.tryParse(rawSecs?.toString() ?? '') ?? 0);
                final rawItemReps = h['reps'] ?? h['tallyCount'];
                final int reps = rawItemReps is num ? rawItemReps.toInt() : (int.tryParse(rawItemReps?.toString() ?? '') ?? 0);

                bool foundFuzzy = false;
                for (int i = 0; i < combinedHistory.length; i++) {
                  final eh = combinedHistory[i];
                  if (timestamp.isNotEmpty && eh.timestamp.isNotEmpty) {
                    final dt1 = DateTime.tryParse(timestamp.replaceAll(' ', 'T'));
                    final dt2 = DateTime.tryParse(eh.timestamp.replaceAll(' ', 'T'));
                    if (dt1 != null && dt2 != null && dt1.difference(dt2).inSeconds.abs() <= 60 && eh.seconds == secs) {
                      foundFuzzy = true;
                      break;
                    }
                  }
                  if (!foundFuzzy && eh.timestamp == timestamp) {
                    final prev = combinedHistory[i];
                    combinedHistory[i] = HistoryEntry(
                      timestamp: prev.timestamp.isNotEmpty ? prev.timestamp : timestamp,
                      date: date.isNotEmpty ? date : prev.date,
                      seconds: secs > prev.seconds ? secs : prev.seconds,
                      reps: reps > prev.reps ? reps : prev.reps,
                    );
                    foundFuzzy = true;
                    break;
                  }
                }
                
                if (!foundFuzzy) {
                  combinedHistory.add(HistoryEntry(
                    timestamp: timestamp,
                    date: date,
                    seconds: secs,
                    reps: reps,
                  ));
                }
              }
            }

            mergedClients[key] = ClientSection(
              id: existing.id,
              name: existing.name,
              totalSecondsToday: existing.totalSecondsToday + impToday,
              reps: existing.reps + impReps,
              history: combinedHistory,
            );
          } else {
            final newHist = impHistory.map((h) {
              final date = (h['date'] ?? '').toString().trim();
              final timestamp = (h['timestamp'] ?? date).toString().trim();
              final rawSecs = h['secs'] ?? h['seconds'];
              final int secs = rawSecs is num ? rawSecs.toInt() : (int.tryParse(rawSecs?.toString() ?? '') ?? 0);
              final rawItemReps = h['reps'] ?? h['tallyCount'];
              final int reps = rawItemReps is num ? rawItemReps.toInt() : (int.tryParse(rawItemReps?.toString() ?? '') ?? 0);
              return HistoryEntry(timestamp: timestamp, date: date, seconds: secs, reps: reps);
            }).toList();

            final maxId = mergedClients.values.fold<int>(0, (prev, c) => c.id > prev ? c.id : prev);
            mergedClients[key] = ClientSection(
              id: maxId + 1,
              name: name,
              totalSecondsToday: impToday,
              reps: impReps,
              history: newHist,
            );
          }
        }

        // Merge tasks
        final List<TaskItem> mergedTasks = List<TaskItem>.from(_tasks);
        for (final impTask in preview.tasks) {
          final text = (impTask['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            final existingTaskIdx = mergedTasks.indexWhere((t) => t.text.toLowerCase() == text.toLowerCase());
            if (existingTaskIdx == -1) {
              mergedTasks.add(TaskItem(
                id: mergedTasks.length + 1,
                text: text,
                stars: (impTask['stars'] as num?)?.toInt() ?? 1,
                done: impTask['done'] == true,
                createdAt: impTask['created'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
              ));
            } else {
              if (impTask['done'] == true && !mergedTasks[existingTaskIdx].done) {
                mergedTasks[existingTaskIdx] = mergedTasks[existingTaskIdx].copyWith(done: true);
              }
            }
          }
        }

        // Merge reminders
        final List<ReminderItem> mergedReminders = List<ReminderItem>.from(_reminders);
        for (final impRem in preview.reminders) {
          final text = (impRem['text'] ?? '').toString().trim();
          if (text.isNotEmpty && !mergedReminders.any((r) => r.text.toLowerCase() == text.toLowerCase())) {
            mergedReminders.add(ReminderItem(
              id: mergedReminders.length + 1,
              text: text,
              createdAt: impRem['created'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            ));
          }
        }

        final mergedJsonMap = {
          'globalGoal': preview.goalSeconds ?? _status.globalGoal,
          'brightness': _status.brightness,
          'savedAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'currentStreak': (preview.currentStreak != null && preview.currentStreak! > _status.currentStreak) ? preview.currentStreak : _status.currentStreak,
          'longestStreak': (preview.longestStreak != null && preview.longestStreak! > _status.longestStreak) ? preview.longestStreak : _status.longestStreak,
          'lastActiveDate': preview.lastActiveDate ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          'clients': mergedClients.values.map((c) => {
            'id': c.id,
            'name': c.name,
            'totalSecsToday': c.totalSecondsToday,
            'totalSecondsToday': c.totalSecondsToday,
            'reps': c.reps,
            'tallyCount': c.reps,
            'history': c.history.map((h) => {
              'timestamp': h.timestamp.isNotEmpty ? h.timestamp : h.date,
              'date': h.date,
              'secs': h.seconds,
              'seconds': h.seconds,
              'reps': h.reps,
            }).toList(),
          }).toList(),
          'tasks': mergedTasks.map((t) => {
            'id': t.id,
            'text': t.text,
            'stars': t.stars,
            'done': t.done,
            'created': t.createdAt,
          }).toList(),
          'reminders': mergedReminders.map((r) => {
            'id': r.id,
            'text': r.text,
            'created': r.createdAt,
          }).toList(),
        };
        payloadToPush = jsonEncode(mergedJsonMap);
      }

      // 1. If connected to ESP32 via Wi-Fi, push to hardware flash
      if (_protocol == SyncProtocol.wifi && _isOnline) {
        final pushed = await _apiService.restoreBackup(payloadToPush);
        if (pushed) {
          await recordBackupCompleted();
          await refreshData();
          return true;
        }
      }

      // 2. Local state update and offline cache (used when offline, on BLE, or if hardware sync is unavailable)
      final dynamic decoded = jsonDecode(payloadToPush);
      if (decoded is Map<String, dynamic>) {
        final rawClients = decoded['clients'] as List<dynamic>? ?? [];
        final updatedClients = rawClients.map((c) {
          final cMap = c as Map<String, dynamic>;
          final hist = (cMap['history'] as List<dynamic>? ?? []).map((h) {
            final hMap = h as Map<String, dynamic>;
            final secs = (hMap['secs'] as num?)?.toInt() ?? (hMap['seconds'] as num?)?.toInt() ?? 0;
            final reps = (hMap['reps'] as num?)?.toInt() ?? (hMap['tallyCount'] as num?)?.toInt() ?? 0;
            return HistoryEntry(
              timestamp: hMap['timestamp'] as String? ?? '',
              date: (hMap['date'] ?? '').toString(),
              seconds: secs,
              reps: reps,
            );
          }).toList();

          final todaySecs = (cMap['totalSecsToday'] as num?)?.toInt() ?? (cMap['totalSecondsToday'] as num?)?.toInt() ?? 0;
          final reps = (cMap['reps'] as num?)?.toInt() ?? (cMap['tallyCount'] as num?)?.toInt() ?? 0;

          final isNeg = (cMap['isNegative'] as bool?) ?? false;
          return ClientSection(
            id: (cMap['id'] as num?)?.toInt() ?? 0,
            name: (cMap['name'] ?? '').toString(),
            totalSecondsToday: todaySecs,
            reps: reps,
            history: hist,
            isNegative: isNeg,
          );
        }).toList();

        final rawTasks = decoded['tasks'] as List<dynamic>? ?? [];
        _tasks = rawTasks.map((t) {
          final tMap = t as Map<String, dynamic>;
          return TaskItem(
            id: (tMap['id'] as num?)?.toInt() ?? 0,
            text: (tMap['text'] ?? '').toString(),
            stars: (tMap['stars'] as num?)?.toInt() ?? 1,
            done: tMap['done'] == true,
            createdAt: (tMap['created'] ?? '').toString(),
          );
        }).toList();

        final rawReminders = decoded['reminders'] as List<dynamic>? ?? [];
        _reminders = rawReminders.map((r) {
          final rMap = r as Map<String, dynamic>;
          return ReminderItem(
            id: (rMap['id'] as num?)?.toInt() ?? 0,
            text: (rMap['text'] ?? '').toString(),
            createdAt: (rMap['created'] ?? '').toString(),
          );
        }).toList();

        int totalDw = 0;
        int totalWaste = 0;
        for (final c in updatedClients) {
          if (c.isNegative) {
            totalWaste += c.totalSecondsToday;
          } else {
            totalDw += c.totalSecondsToday;
          }
        }
        final totalTracked = totalDw + totalWaste;
        final purity = totalTracked > 0 ? ((totalDw * 100) / totalTracked).round() : 100;

        _status = DeviceStatus(
          state: _status.state,
          currentStreak: (decoded['currentStreak'] as num?)?.toInt() ?? _status.currentStreak,
          longestStreak: (decoded['longestStreak'] as num?)?.toInt() ?? _status.longestStreak,
          activeClientId: updatedClients.isNotEmpty ? updatedClients.first.id : 0,
          sessionSeconds: _status.sessionSeconds,
          totalDeepWorkToday: totalDw,
          totalWasteToday: totalWaste,
          focusPurityPct: purity,
          globalGoal: (decoded['globalGoal'] as num?)?.toInt() ?? _status.globalGoal,
          brightness: (decoded['brightness'] as num?)?.toInt() ?? _status.brightness,
          clients: updatedClients,
          tasks: _tasks,
          reminders: _reminders,
        );

        await _saveCachedStatus();
        await recordBackupCompleted();
        notifyListeners();
        return true;
      }

      // Rollback on invalid format
      _status = previousStatus;
      _tasks = previousTasks;
      _reminders = previousReminders;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[TrackerProvider] importData error: $e');
      _status = previousStatus;
      _tasks = previousTasks;
      _reminders = previousReminders;
      notifyListeners();
      return false;
    }
  }

  @visibleForTesting
  void updateStatusForTesting(DeviceStatus newStatus) {
    _status = newStatus;
      _checklist = newStatus.checklist;
    _tasks = List.from(newStatus.tasks);
    _reminders = List.from(newStatus.reminders);
    notifyListeners();
  }

  void _startMidnightTimer() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkLocalMidnightRollover();
    });
  }

  Future<void> _checkLocalMidnightRollover() async {
    // Local rollover logic. We do not perform local rollover if we are online via Wi-Fi or BLE,
    // because the firmware handles the rollover and we simply sync the state.
    if (_isOnline) return;

    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('pref_last_active_date') ?? '';
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());

    if (lastDate.isNotEmpty && lastDate != today) {
      debugPrint('[TrackerProvider] Local midnight rollover triggered. Rolling $lastDate to $today');

      // Straddling session handler
      if (_status.state == TrackerState.tracking || _status.state == TrackerState.paused) {
        final cIdx = _status.clients.indexWhere((c) => c.id == _status.activeClientId);
        if (cIdx != -1) {
          final c = _status.clients[cIdx];
          _status = _status.copyWith(
            clients: _status.clients.map((xc) => xc.id == c.id ? c.copyWith(totalSecondsToday: c.totalSecondsToday + _status.sessionSeconds) : xc).toList(),
            sessionSeconds: 0,
          );
        }
      }

      int newStreak = _status.currentStreak;
      int newLongest = _status.longestStreak;
      if (_status.totalDeepWorkToday >= _status.globalGoal) {
        newStreak++;
        if (newStreak > newLongest) {
          newLongest = newStreak;
        }
      } else {
        newStreak = 0;
      }

      final updatedClients = <ClientSection>[];
      for (final c in _status.clients) {
        if (c.totalSecondsToday > 0 || c.reps > 0) {
          int alreadyArchived = 0;
          for (final h in c.history) {
            if (h.date == lastDate) alreadyArchived += h.seconds;
          }
          final int unarchived = c.totalSecondsToday - alreadyArchived;

          final newHistory = List<HistoryEntry>.from(c.history);
          if (unarchived > 0 || c.reps > 0) {
            newHistory.insert(0, HistoryEntry(
              timestamp: '$lastDate 23:59:59',
              date: lastDate,
              seconds: unarchived > 0 ? unarchived : 0,
              reps: c.reps,
            ));
            if (newHistory.length > 50) newHistory.removeLast();
          }

          updatedClients.add(c.copyWith(
            totalSecondsToday: 0,
            reps: 0,
            history: newHistory,
          ));
        } else {
          updatedClients.add(c);
        }
      }

      _status = _status.copyWith(
        clients: updatedClients,
        totalDeepWorkToday: 0,
        totalWasteToday: 0,
        focusPurityPct: 100,
        currentStreak: newStreak,
        longestStreak: newLongest,
      );

      await prefs.setString('pref_last_active_date', today);
      _saveCachedStatus();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _localTicker?.cancel();
    _midnightTimer?.cancel();
    _bleTelemetrySub?.cancel();
    _bleConnSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}

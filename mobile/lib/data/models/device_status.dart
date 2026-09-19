import 'client_section.dart';
import 'task_item.dart';
import 'reminder_item.dart';
import 'checklist_item.dart';

enum TrackerState {
  idle,
  tracking,
  paused,
  selectClient,
  stressBuster,
  unknown;

  static TrackerState fromString(String str) {
    switch (str.toUpperCase()) {
      case 'IDLE':
        return TrackerState.idle;
      case 'TRACKING':
        return TrackerState.tracking;
      case 'PAUSED':
        return TrackerState.paused;
      case 'SELECT_CLIENT':
        return TrackerState.selectClient;
      case 'STRESS_BUSTER':
        return TrackerState.stressBuster;
      default:
        return TrackerState.unknown;
    }
  }

  String get label {
    switch (this) {
      case TrackerState.idle:
        return 'IDLE';
      case TrackerState.tracking:
        return 'FOCUSING';
      case TrackerState.paused:
        return 'PAUSED';
      case TrackerState.selectClient:
        return 'SELECT';
      case TrackerState.stressBuster:
        return 'ZEN RESET';
      default:
        return 'STANDBY';
    }
  }
}

class DeviceStatus {
  static const List<ClientSection> defaultClients = [
    ClientSection(id: 1, name: 'Deep Coding', totalSecondsToday: 0),
    ClientSection(id: 2, name: 'System Design', totalSecondsToday: 0),
    ClientSection(id: 3, name: 'DSA LeetCode', totalSecondsToday: 0),
    ClientSection(id: 4, name: 'Hardware Labs', totalSecondsToday: 0),
    ClientSection(id: 5, name: 'YouTube & Reels', totalSecondsToday: 0, isNegative: true),
  ];

  final TrackerState state;
  final int activeClientId;
  final int sessionSeconds;
  final int totalDeepWorkToday;
  final int totalWasteToday;
  final int focusPurityPct;
  final int globalGoal;
  final int brightness;
  final int currentStreak;
  final int longestStreak;
  final bool wellnessEnabled;
  final int wellnessIntervalMinutes;
  final int wellnessMode;
  final bool powerbankKeepAlive;
  final bool isAwayMode;
  final List<ClientSection> clients;
  final List<TaskItem> tasks;
  final List<ReminderItem> reminders;
  final List<ChecklistItem> checklist;

  const DeviceStatus({
    this.state = TrackerState.idle,
    this.activeClientId = 1,
    this.sessionSeconds = 0,
    this.totalDeepWorkToday = 0,
    this.totalWasteToday = 0,
    this.focusPurityPct = 100,
    this.globalGoal = 36000, // 10 hours default
    this.brightness = 255,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.wellnessEnabled = true,
    this.wellnessIntervalMinutes = 45,
    this.wellnessMode = 0,
    this.powerbankKeepAlive = true,
    this.isAwayMode = false,
    this.clients = defaultClients,
    this.tasks = const [],
    this.reminders = const [],
    this.checklist = const [],
  });

  DeviceStatus copyWith({
    TrackerState? state,
    int? activeClientId,
    int? sessionSeconds,
    int? totalDeepWorkToday,
    int? totalWasteToday,
    int? focusPurityPct,
    int? globalGoal,
    int? brightness,
    int? currentStreak,
    int? longestStreak,
    bool? wellnessEnabled,
    int? wellnessIntervalMinutes,
    int? wellnessMode,
    bool? powerbankKeepAlive,
    bool? isAwayMode,
    List<ClientSection>? clients,
    List<TaskItem>? tasks,
    List<ReminderItem>? reminders,
    List<ChecklistItem>? checklist,
  }) {
    return DeviceStatus(
      state: state ?? this.state,
      activeClientId: activeClientId ?? this.activeClientId,
      sessionSeconds: sessionSeconds ?? this.sessionSeconds,
      totalDeepWorkToday: totalDeepWorkToday ?? this.totalDeepWorkToday,
      totalWasteToday: totalWasteToday ?? this.totalWasteToday,
      focusPurityPct: focusPurityPct ?? this.focusPurityPct,
      globalGoal: globalGoal ?? this.globalGoal,
      brightness: brightness ?? this.brightness,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      wellnessEnabled: wellnessEnabled ?? this.wellnessEnabled,
      wellnessIntervalMinutes:
          wellnessIntervalMinutes ?? this.wellnessIntervalMinutes,
      wellnessMode: wellnessMode ?? this.wellnessMode,
      powerbankKeepAlive: powerbankKeepAlive ?? this.powerbankKeepAlive,
      isAwayMode: isAwayMode ?? this.isAwayMode,
      clients: clients ?? this.clients,
      tasks: tasks ?? this.tasks,
      reminders: reminders ?? this.reminders,
      checklist: checklist ?? this.checklist,
    );
  }

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    var rawClients = json['clients'] as List<dynamic>? ?? [];
    var rawTasks = json['tasks'] as List<dynamic>? ?? [];
    var rawReminders = json['reminders'] as List<dynamic>? ?? [];
    var rawChecklist = json['checklist'] as List<dynamic>? ?? [];

    final parsedClients = rawClients
        .map((c) => ClientSection.fromJson(c as Map<String, dynamic>))
        .toList();

    final effectiveClients =
        parsedClients.isNotEmpty ? parsedClients : defaultClients;

    int parsedActiveId = (json['activeClientId'] as num?)?.toInt() ??
        (json['clientId'] as num?)?.toInt() ??
        0;
    if (parsedActiveId <= 0 && effectiveClients.isNotEmpty) {
      parsedActiveId = effectiveClients.first.id;
    }

    final dw = (json['globalDeepWorkSecondsToday'] as num?)?.toInt() ??
        (json['totalDeepWorkToday'] as num?)?.toInt() ??
        (json['dwSecs'] as num?)?.toInt() ??
        0;
    final waste = (json['globalWasteSecondsToday'] as num?)?.toInt() ??
        (json['totalWasteToday'] as num?)?.toInt() ??
        (json['wasteSecs'] as num?)?.toInt() ??
        0;
    final defaultPurity = (dw + waste > 0) ? ((dw * 100) / (dw + waste)).round() : 100;
    final purity = (json['focusPurityPct'] as num?)?.toInt() ?? defaultPurity;

    final parsedTasks = rawTasks
        .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
        .toList();

    final parsedReminders = rawReminders
        .map((r) => ReminderItem.fromJson(r as Map<String, dynamic>))
        .toList();

    final parsedChecklist = rawChecklist
        .map((c) => ChecklistItem.fromJson(c as Map<String, dynamic>))
        .toList();

    return DeviceStatus(
      state: TrackerState.fromString(json['state'] as String? ?? 'IDLE'),
      activeClientId: parsedActiveId,
      sessionSeconds: (json['sessionSeconds'] as num?)?.toInt() ??
          (json['sessionSecs'] as num?)?.toInt() ??
          0,
      totalDeepWorkToday: dw,
      totalWasteToday: waste,
      focusPurityPct: purity,
      globalGoal: (json['globalGoal'] as num?)?.toInt() ??
          (json['goal'] as num?)?.toInt() ??
          14400,
      brightness: (json['brightness'] as num?)?.toInt() ?? 255,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ??
          (json['streak'] as num?)?.toInt() ??
          0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      wellnessEnabled: json['wellnessEnabled'] as bool? ?? true,
      wellnessIntervalMinutes:
          (json['wellnessIntervalMinutes'] as num?)?.toInt() ?? 45,
      wellnessMode: (json['wellnessMode'] as num?)?.toInt() ?? 0,
      powerbankKeepAlive: (json['powerbank'] as bool?) ??
          (json['powerbankKeepAlive'] as bool?) ??
          true,
      isAwayMode: (json['awayMode'] as bool?) ??
          (json['isAwayMode'] as bool?) ??
          false,
      clients: effectiveClients,
      tasks: parsedTasks,
      reminders: parsedReminders,
      checklist: parsedChecklist,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.name.toUpperCase(),
      'activeClientId': activeClientId,
      'sessionSeconds': sessionSeconds,
      'totalDeepWorkToday': totalDeepWorkToday,
      'globalDeepWorkSecondsToday': totalDeepWorkToday,
      'totalWasteToday': totalWasteToday,
      'globalWasteSecondsToday': totalWasteToday,
      'focusPurityPct': focusPurityPct,
      'globalGoal': globalGoal,
      'brightness': brightness,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'wellnessEnabled': wellnessEnabled,
      'wellnessIntervalMinutes': wellnessIntervalMinutes,
      'wellnessMode': wellnessMode,
      'powerbankKeepAlive': powerbankKeepAlive,
      'isAwayMode': isAwayMode,
      'clients': clients.map((c) => c.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'checklist': checklist.map((c) => c.toJson()).toList(),
    };
  }

  ClientSection? get activeClient {
    if (clients.isEmpty) return null;
    try {
      return clients.firstWhere((c) => c.id == activeClientId);
    } catch (_) {
      return clients.first;
    }
  }

  double get goalProgress {
    if (globalGoal <= 0) return 0.0;
    return (totalDeepWorkToday / globalGoal).clamp(0.0, 1.0);
  }
}

import 'package:intl/intl.dart';

class HistoryEntry {
  final String timestamp;
  final String date;
  final int seconds;
  final int reps;

  const HistoryEntry({
    required this.timestamp,
    required this.date,
    required this.seconds,
    required this.reps,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      timestamp: json['timestamp'] as String? ?? '',
      date: json['date'] as String? ?? '',
      seconds: (json['secs'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'date': date,
      'secs': seconds,
      'reps': reps,
    };
  }
}

class ClientSection {
  final int id;
  final String name;
  final int totalSecondsToday;
  final int reps;
  final List<HistoryEntry> history;
  final bool isNegative;

  const ClientSection({
    required this.id,
    required this.name,
    this.totalSecondsToday = 0,
    this.reps = 0,
    this.history = const [],
    this.isNegative = false,
  });

  ClientSection copyWith({
    int? id,
    String? name,
    int? totalSecondsToday,
    int? reps,
    List<HistoryEntry>? history,
    bool? isNegative,
  }) {
    return ClientSection(
      id: id ?? this.id,
      name: name ?? this.name,
      totalSecondsToday: totalSecondsToday ?? this.totalSecondsToday,
      reps: reps ?? this.reps,
      history: history ?? this.history,
      isNegative: isNegative ?? this.isNegative,
    );
  }

  factory ClientSection.fromJson(Map<String, dynamic> json) {
    var rawHist = json['history'] as List<dynamic>? ?? [];
    return ClientSection(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Section',
      totalSecondsToday: (json['totalSecsToday'] as num?)?.toInt() ??
          (json['todaySecs'] as num?)?.toInt() ??
          0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      history: rawHist
          .map((h) => HistoryEntry.fromJson(h as Map<String, dynamic>))
          .toList(),
      isNegative: (json['isNegative'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'totalSecsToday': totalSecondsToday,
      'reps': reps,
      'history': history.map((h) => h.toJson()).toList(),
      'isNegative': isNegative,
    };
  }

  int get totalAccumulatedSecs {
    final now = DateTime.now();
    final todayStr = DateFormat('dd MMM yyyy').format(now).toLowerCase();
    final todayStrAlt = DateFormat('d MMM yyyy').format(now).toLowerCase();
    final todayIso = DateFormat('yyyy-MM-dd').format(now).toLowerCase();

    int pastHistSecs = 0;
    for (final h in history) {
      final hDate = h.date.trim().toLowerCase();
      final hTs = h.timestamp.trim().toLowerCase();
      final bool isToday = (hDate == todayStr ||
          hDate == todayStrAlt ||
          hDate == todayIso ||
          (hTs.isNotEmpty && hTs.startsWith(todayIso)));
      if (!isToday) {
        pastHistSecs += h.seconds;
      }
    }
    return totalSecondsToday + pastHistSecs;
  }

  String get formattedTodayTime {
    final hrs = totalSecondsToday ~/ 3600;
    final mins = (totalSecondsToday % 3600) ~/ 60;
    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    }
    return '${mins}m';
  }
}

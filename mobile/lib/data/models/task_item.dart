class TaskItem {
  final int id;
  final String text;
  final int stars; // 1, 2, or 3
  final bool done;
  final String createdAt;

  const TaskItem({
    required this.id,
    required this.text,
    this.stars = 1,
    this.done = false,
    this.createdAt = '',
  });

  TaskItem copyWith({
    int? id,
    String? text,
    int? stars,
    bool? done,
    String? createdAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      text: text ?? this.text,
      stars: stars ?? this.stars,
      done: done ?? this.done,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? 'Untitled Task',
      stars: (json['stars'] as num?)?.toInt() ?? 1,
      done: json['done'] as bool? ?? false,
      createdAt: json['created'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'stars': stars,
      'done': done,
      'created': createdAt,
    };
  }

  String get starsDisplay => '★' * stars;
}

class ReminderItem {
  final int id;
  final String text;
  final String createdAt;

  const ReminderItem({
    required this.id,
    required this.text,
    this.createdAt = '',
  });

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      createdAt: json['created'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'created': createdAt,
    };
  }

  ReminderItem copyWith({
    int? id,
    String? text,
    String? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

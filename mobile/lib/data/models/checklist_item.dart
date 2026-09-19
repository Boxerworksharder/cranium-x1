class ChecklistItem {
  final int id;
  final String text;
  final bool done;

  ChecklistItem({
    required this.id,
    required this.text,
    this.done = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as int,
      text: json['text'] as String,
      done: json['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'done': done,
    };
  }

  ChecklistItem copyWith({
    int? id,
    String? text,
    bool? done,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }
}

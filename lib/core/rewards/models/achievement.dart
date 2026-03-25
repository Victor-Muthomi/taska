class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime unlockedAt;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  factory Achievement.fromMap(Map<String, Object?> map) {
    return Achievement(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      unlockedAt: DateTime.parse(map['unlocked_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }
}
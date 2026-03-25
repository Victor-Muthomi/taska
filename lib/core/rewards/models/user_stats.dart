class UserStats {
  const UserStats({
    required this.id,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
  });

  static const int singletonId = 1;

  final int id;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedDate;

  UserStats copyWith({
    int? id,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCompletedDate,
  }) {
    return UserStats(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  factory UserStats.fromMap(Map<String, Object?> map) {
    return UserStats(
      id: map['id'] as int,
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      lastCompletedDate: map['last_completed_date'] == null
          ? null
          : DateTime.parse(map['last_completed_date'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
    };
  }

  factory UserStats.initial() {
    return const UserStats(
      id: singletonId,
      currentStreak: 0,
      longestStreak: 0,
      lastCompletedDate: null,
    );
  }
}
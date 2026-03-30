enum ShoppingSessionStatus { active, completed }

class ShoppingSession {
  const ShoppingSession({
    required this.id,
    required this.date,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final DateTime date;
  final String title;
  final ShoppingSessionStatus status;
  final DateTime createdAt;

  ShoppingSession copyWith({
    String? id,
    DateTime? date,
    String? title,
    ShoppingSessionStatus? status,
    DateTime? createdAt,
  }) {
    return ShoppingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
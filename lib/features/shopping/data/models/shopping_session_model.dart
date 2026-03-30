import '../../domain/entities/shopping_session.dart';

class ShoppingSessionModel extends ShoppingSession {
  const ShoppingSessionModel({
    required super.id,
    required super.date,
    required super.title,
    required super.status,
    required super.createdAt,
  });

  factory ShoppingSessionModel.fromEntity(ShoppingSession session) {
    return ShoppingSessionModel(
      id: session.id,
      date: session.date,
      title: session.title,
      status: session.status,
      createdAt: session.createdAt,
    );
  }

  factory ShoppingSessionModel.fromMap(Map<String, Object?> map) {
    return ShoppingSessionModel(
      id: _readString(map, ['id']),
      date: _readDateTime(map, ['date', 'session_date']),
      title: _readString(map, ['title']),
      status: ShoppingSessionStatus.values.byName(
        _readString(map, ['status']),
      ),
      createdAt: _readDateTime(map, ['created_at', 'createdAt']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  ShoppingSessionModel copyWith({
    String? id,
    DateTime? date,
    String? title,
    ShoppingSessionStatus? status,
    DateTime? createdAt,
  }) {
    return ShoppingSessionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

String _readString(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String) {
      return value;
    }
    if (value != null) {
      return value.toString();
    }
  }
  throw ArgumentError('Missing required string value for ${keys.first}');
}

DateTime _readDateTime(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value);
    }
  }
  throw ArgumentError('Missing required DateTime value for ${keys.first}');
}
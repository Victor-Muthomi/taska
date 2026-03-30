import '../../domain/entities/shopping_item.dart';

class ShoppingItemModel extends ShoppingItem {
  const ShoppingItemModel({
    required super.id,
    required super.name,
    required super.category,
    required super.isCompleted,
    super.linkedTaskId,
    super.sessionId,
    required super.createdAt,
  });

  factory ShoppingItemModel.fromEntity(ShoppingItem item) {
    return ShoppingItemModel(
      id: item.id,
      name: item.name,
      category: item.category,
      isCompleted: item.isCompleted,
      linkedTaskId: item.linkedTaskId,
      sessionId: item.sessionId,
      createdAt: item.createdAt,
    );
  }

  factory ShoppingItemModel.fromMap(Map<String, Object?> map) {
    return ShoppingItemModel(
      id: _readString(map, ['id']),
      name: _readString(map, ['name']),
      category: _readString(map, ['category']),
      isCompleted: _readBool(map, ['is_completed', 'isCompleted']),
      linkedTaskId: _readNullableString(
        map,
        ['linked_task_id', 'linkedTaskId'],
      ),
      sessionId: _readNullableString(map, ['session_id', 'sessionId']),
      createdAt: _readDateTime(map, ['created_at', 'createdAt']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'is_completed': isCompleted ? 1 : 0,
      'linked_task_id': linkedTaskId,
      'session_id': sessionId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  ShoppingItemModel copyWith({
    String? id,
    String? name,
    String? category,
    bool? isCompleted,
    String? linkedTaskId,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      sessionId: sessionId ?? this.sessionId,
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

String? _readNullableString(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) {
      continue;
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }
  return null;
}

bool _readBool(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
  }
  throw ArgumentError('Missing required bool value for ${keys.first}');
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
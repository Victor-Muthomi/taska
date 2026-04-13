class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    this.quantity = 1,
    this.pricePerItem,
    required this.isCompleted,
    this.linkedTaskId,
    this.sessionId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final double? pricePerItem;
  final bool isCompleted;
  final String? linkedTaskId;
  final String? sessionId;
  final DateTime createdAt;

  ShoppingItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? pricePerItem,
    bool? isCompleted,
    String? linkedTaskId,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      pricePerItem: pricePerItem ?? this.pricePerItem,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
// budget_item.dart
// Model for budget items (trip-level or day-level)
import 'package:uuid/uuid.dart';

class BudgetItem {
  final String id;
  String category;
  double amount;
  String? description;

  BudgetItem({
    String? id,
    required this.category,
    required this.amount,
    this.description,
  }) : id = id ?? const Uuid().v4();

  /// Create BudgetItem from JSON
  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }

  /// Convert BudgetItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'description': description,
    };
  }

  /// Create a copy with updated fields
  BudgetItem copyWith({
    String? id,
    String? category,
    double? amount,
    String? description,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'BudgetItem(id: $id, category: $category, amount: \$$amount, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetItem &&
        other.id == id &&
        other.category == category &&
        other.amount == amount &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(id, category, amount, description);
  }
}

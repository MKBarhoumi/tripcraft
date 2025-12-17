// day.dart
// Model for a single day in a trip
import 'package:uuid/uuid.dart';
import 'activity.dart';
import 'note.dart';
import 'budget_item.dart';

class Day {
  final String id;
  int dayIndex; // 1-based index (Day 1, Day 2, etc.)
  DateTime? date;
  String? summary;
  List<Activity> activities;
  List<Note> notes;
  List<BudgetItem> budgetItems;
  double totalDayBudget;

  Day({
    String? id,
    required this.dayIndex,
    this.date,
    this.summary,
    List<Activity>? activities,
    List<Note>? notes,
    List<BudgetItem>? budgetItems,
    this.totalDayBudget = 0.0,
  })  : id = id ?? const Uuid().v4(),
        activities = activities ?? [],
        notes = notes ?? [],
        budgetItems = budgetItems ?? [];

  /// Create Day from JSON
  factory Day.fromJson(Map<String, dynamic> json) {
    return Day(
      id: json['id'] as String? ?? const Uuid().v4(),
      dayIndex: json['day_index'] as int,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      summary: json['summary'] as String?,
      activities: (json['activities'] as List<dynamic>?)
              ?.map((a) => Activity.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as List<dynamic>?)
              ?.map((n) => Note.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      budgetItems: (json['budget_items'] as List<dynamic>?)
              ?.map((b) => BudgetItem.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      totalDayBudget: (json['total_day_budget'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert Day to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_index': dayIndex,
      'date': date?.toIso8601String(),
      'summary': summary,
      'activities': activities.map((a) => a.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'budget_items': budgetItems.map((b) => b.toJson()).toList(),
      'total_day_budget': totalDayBudget,
    };
  }

  /// Calculate total cost from activities
  double calculateTotalCost() {
    return activities.fold(0.0, (sum, activity) => sum + activity.estimatedCost);
  }

  /// Create a copy with updated fields
  Day copyWith({
    String? id,
    int? dayIndex,
    DateTime? date,
    String? summary,
    List<Activity>? activities,
    List<Note>? notes,
    List<BudgetItem>? budgetItems,
    double? totalDayBudget,
  }) {
    return Day(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      date: date ?? this.date,
      summary: summary ?? this.summary,
      activities: activities ?? this.activities,
      notes: notes ?? this.notes,
      budgetItems: budgetItems ?? this.budgetItems,
      totalDayBudget: totalDayBudget ?? this.totalDayBudget,
    );
  }

  @override
  String toString() {
    return 'Day(id: $id, dayIndex: $dayIndex, date: $date, activities: ${activities.length}, budget: \$$totalDayBudget)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Day &&
        other.id == id &&
        other.dayIndex == dayIndex &&
        other.date == date &&
        other.summary == summary &&
        other.totalDayBudget == totalDayBudget;
  }

  @override
  int get hashCode {
    return Object.hash(id, dayIndex, date, summary, totalDayBudget);
  }
}

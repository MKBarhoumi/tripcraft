// trip.dart
// Model for a complete trip with offline sync support
import 'package:uuid/uuid.dart';
import 'day.dart';
import 'note.dart';
import 'budget_item.dart';

class Trip {
  final String id;
  final String userId; // User who owns this trip
  String? serverId; // Server-side UUID when synced
  String? title;
  String destination;
  DateTime? startDate;
  DateTime? endDate;
  String? travelStyle;
  String? budgetTier;
  String? preferences;
  List<Day> days;
  List<Note> notes;
  List<BudgetItem> budgetItems;
  double totalBudgetEstimate;
  List<String> localTips;
  
  // Sync fields
  bool isSynced;
  DateTime localUpdatedAt;
  DateTime createdAt;

  Trip({
    String? id,
    required this.userId,
    this.serverId,
    this.title,
    required this.destination,
    this.startDate,
    this.endDate,
    this.travelStyle,
    this.budgetTier,
    this.preferences,
    List<Day>? days,
    List<Note>? notes,
    List<BudgetItem>? budgetItems,
    this.totalBudgetEstimate = 0.0,
    List<String>? localTips,
    this.isSynced = false,
    DateTime? localUpdatedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        days = days ?? [],
        notes = notes ?? [],
        budgetItems = budgetItems ?? [],
        localTips = localTips ?? [],
        localUpdatedAt = localUpdatedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Create Trip from JSON
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String? ?? const Uuid().v4(),
      userId: json['user_id'] as String,
      serverId: json['server_id'] as String?,
      title: json['title'] as String?,
      destination: json['destination'] as String,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      travelStyle: json['travel_style'] as String?,
      budgetTier: json['budget_tier'] as String?,
      preferences: json['preferences'] as String?,
      days: (json['days'] as List<dynamic>?)
              ?.map((d) => Day.fromJson(d as Map<String, dynamic>))
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
      totalBudgetEstimate:
          (json['total_budget_estimate'] as num?)?.toDouble() ?? 0.0,
      localTips: (json['local_tips'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      isSynced: json['is_synced'] as bool? ?? false,
      localUpdatedAt: json['local_updated_at'] != null
          ? DateTime.parse(json['local_updated_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert Trip to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'server_id': serverId,
      'title': title,
      'destination': destination,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'travel_style': travelStyle,
      'budget_tier': budgetTier,
      'preferences': preferences,
      'days': days.map((d) => d.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
      'budget_items': budgetItems.map((b) => b.toJson()).toList(),
      'total_budget_estimate': totalBudgetEstimate,
      'local_tips': localTips,
      'is_synced': isSynced,
      'local_updated_at': localUpdatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Calculate total number of days
  int get numberOfDays => days.length;

  /// Calculate total cost from all days
  double calculateTotalCost() {
    return days.fold(0.0, (sum, day) => sum + day.calculateTotalCost());
  }

  /// Get duration in days
  int? get durationDays {
    if (startDate == null || endDate == null) return null;
    return endDate!.difference(startDate!).inDays + 1;
  }

  /// Mark as modified (for sync)
  Trip markAsModified() {
    return copyWith(
      isSynced: false,
      localUpdatedAt: DateTime.now(),
    );
  }

  /// Mark as synced with server
  Trip markAsSynced(String serverUuid) {
    return copyWith(
      serverId: serverUuid,
      isSynced: true,
    );
  }

  /// Create a copy with updated fields
  Trip copyWith({
    String? id,
    String? userId,
    String? serverId,
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? travelStyle,
    String? budgetTier,
    String? preferences,
    List<Day>? days,
    List<Note>? notes,
    List<BudgetItem>? budgetItems,
    double? totalBudgetEstimate,
    List<String>? localTips,
    bool? isSynced,
    DateTime? localUpdatedAt,
    DateTime? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      travelStyle: travelStyle ?? this.travelStyle,
      budgetTier: budgetTier ?? this.budgetTier,
      preferences: preferences ?? this.preferences,
      days: days ?? this.days,
      notes: notes ?? this.notes,
      budgetItems: budgetItems ?? this.budgetItems,
      totalBudgetEstimate: totalBudgetEstimate ?? this.totalBudgetEstimate,
      localTips: localTips ?? this.localTips,
      isSynced: isSynced ?? this.isSynced,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, userId: $userId, serverId: $serverId, destination: $destination, days: ${days.length}, synced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Trip &&
        other.id == id &&
        other.userId == userId &&
        other.serverId == serverId &&
        other.destination == destination &&
        other.isSynced == isSynced;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ serverId.hashCode ^ destination.hashCode ^ isSynced.hashCode;
  }
}

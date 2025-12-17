// activity.dart
// Model for a single activity within a day
import 'package:uuid/uuid.dart';

class Activity {
  final String id;
  String title;
  String? startTime; // 'HH:MM' format
  String? endTime; // 'HH:MM' format
  String? location;
  String? details;
  double estimatedCost;

  Activity({
    String? id,
    required this.title,
    this.startTime,
    this.endTime,
    this.location,
    this.details,
    this.estimatedCost = 0.0,
  }) : id = id ?? const Uuid().v4();

  /// Create Activity from JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      location: json['location'] as String?,
      details: json['details'] as String?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert Activity to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'details': details,
      'estimated_cost': estimatedCost,
    };
  }

  /// Create a copy with updated fields
  Activity copyWith({
    String? id,
    String? title,
    String? startTime,
    String? endTime,
    String? location,
    String? details,
    double? estimatedCost,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      details: details ?? this.details,
      estimatedCost: estimatedCost ?? this.estimatedCost,
    );
  }

  @override
  String toString() {
    return 'Activity(id: $id, title: $title, time: $startTime-$endTime, location: $location, cost: \$$estimatedCost)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Activity &&
        other.id == id &&
        other.title == title &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.location == location &&
        other.details == details &&
        other.estimatedCost == estimatedCost;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      startTime,
      endTime,
      location,
      details,
      estimatedCost,
    );
  }
}

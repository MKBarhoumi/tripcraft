// test/models/activity_test.dart
// Unit tests for Activity model
import 'package:flutter_test/flutter_test.dart';
import 'package:tripcraft_app/src/models/activity.dart';

void main() {
  group('Activity Model', () {
    test('creates Activity with required fields', () {
      final activity = Activity(
        title: 'Visit Eiffel Tower',
        location: 'Paris',
        estimatedCost: 25.0,
      );

      expect(activity.id, isNotEmpty);
      expect(activity.title, 'Visit Eiffel Tower');
      expect(activity.location, 'Paris');
      expect(activity.estimatedCost, 25.0);
      expect(activity.startTime, isNull);
      expect(activity.endTime, isNull);
    });

    test('creates Activity with all fields', () {
      final activity = Activity(
        id: 'test-id',
        title: 'Louvre Museum',
        startTime: '09:00',
        endTime: '12:00',
        location: 'Paris',
        details: 'See the Mona Lisa',
        estimatedCost: 15.0,
      );

      expect(activity.id, 'test-id');
      expect(activity.title, 'Louvre Museum');
      expect(activity.startTime, '09:00');
      expect(activity.endTime, '12:00');
      expect(activity.details, 'See the Mona Lisa');
    });

    test('serializes to JSON correctly', () {
      final activity = Activity(
        id: 'act-123',
        title: 'Seine River Cruise',
        startTime: '19:00',
        endTime: '21:00',
        location: 'Seine River',
        details: 'Evening cruise with dinner',
        estimatedCost: 75.0,
      );

      final json = activity.toJson();

      expect(json['id'], 'act-123');
      expect(json['title'], 'Seine River Cruise');
      expect(json['start_time'], '19:00');
      expect(json['end_time'], '21:00');
      expect(json['location'], 'Seine River');
      expect(json['details'], 'Evening cruise with dinner');
      expect(json['estimated_cost'], 75.0);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'act-456',
        'title': 'Versailles Palace',
        'start_time': '10:00',
        'end_time': '16:00',
        'location': 'Versailles',
        'details': 'Full day tour',
        'estimated_cost': 50.0,
      };

      final activity = Activity.fromJson(json);

      expect(activity.id, 'act-456');
      expect(activity.title, 'Versailles Palace');
      expect(activity.startTime, '10:00');
      expect(activity.endTime, '16:00');
      expect(activity.location, 'Versailles');
      expect(activity.details, 'Full day tour');
      expect(activity.estimatedCost, 50.0);
    });

    test('round-trip JSON serialization preserves data', () {
      final original = Activity(
        title: 'Arc de Triomphe',
        startTime: '14:00',
        location: 'Champs-Élysées',
        estimatedCost: 12.0,
      );

      final json = original.toJson();
      final deserialized = Activity.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.title, original.title);
      expect(deserialized.startTime, original.startTime);
      expect(deserialized.location, original.location);
      expect(deserialized.estimatedCost, original.estimatedCost);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Activity(
        title: 'Original Activity',
        estimatedCost: 10.0,
      );

      final updated = original.copyWith(
        title: 'Updated Activity',
        estimatedCost: 20.0,
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Updated Activity');
      expect(updated.estimatedCost, 20.0);
      expect(original.title, 'Original Activity'); // Original unchanged
    });

    test('equality operator works correctly', () {
      final activity1 = Activity(
        id: 'same-id',
        title: 'Activity',
        estimatedCost: 10.0,
      );

      final activity2 = Activity(
        id: 'same-id',
        title: 'Activity',
        estimatedCost: 10.0,
      );

      final activity3 = Activity(
        id: 'different-id',
        title: 'Activity',
        estimatedCost: 10.0,
      );

      expect(activity1, equals(activity2));
      expect(activity1, isNot(equals(activity3)));
    });

    test('handles null values in JSON', () {
      final json = {
        'title': 'Minimal Activity',
        'estimated_cost': 0,
      };

      final activity = Activity.fromJson(json);

      expect(activity.id, isNotEmpty); // Generated UUID
      expect(activity.title, 'Minimal Activity');
      expect(activity.startTime, isNull);
      expect(activity.endTime, isNull);
      expect(activity.location, isNull);
      expect(activity.details, isNull);
      expect(activity.estimatedCost, 0.0);
    });
  });
}

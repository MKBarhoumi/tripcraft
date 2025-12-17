// test/models/trip_test.dart
// Unit tests for Trip model
import 'package:flutter_test/flutter_test.dart';
import 'package:tripcraft_app/src/models/models.dart';

void main() {
  group('Trip Model', () {
    test('creates Trip with required fields', () {
      final trip = Trip(
        userId: 'user-123',
        destination: 'Paris, France',
      );

      expect(trip.id, isNotEmpty);
      expect(trip.userId, 'user-123');
      expect(trip.destination, 'Paris, France');
      expect(trip.serverId, isNull);
      expect(trip.isSynced, false);
      expect(trip.days, isEmpty);
      expect(trip.notes, isEmpty);
      expect(trip.budgetItems, isEmpty);
      expect(trip.localTips, isEmpty);
    });

    test('creates Trip with all fields', () {
      final startDate = DateTime(2025, 3, 15);
      final endDate = DateTime(2025, 3, 20);

      final trip = Trip(
        id: 'trip-123',
        userId: 'user-123',
        serverId: 'server-uuid',
        title: '5-day Paris Adventure',
        destination: 'Paris, France',
        startDate: startDate,
        endDate: endDate,
        travelStyle: 'relaxed',
        budgetTier: 'mid',
        preferences: 'history, food, museums',
        totalBudgetEstimate: 1500.0,
        localTips: ['Buy metro pass', 'Visit early morning'],
        isSynced: true,
      );

      expect(trip.id, 'trip-123');
      expect(trip.serverId, 'server-uuid');
      expect(trip.title, '5-day Paris Adventure');
      expect(trip.destination, 'Paris, France');
      expect(trip.startDate, startDate);
      expect(trip.endDate, endDate);
      expect(trip.travelStyle, 'relaxed');
      expect(trip.budgetTier, 'mid');
      expect(trip.preferences, 'history, food, museums');
      expect(trip.totalBudgetEstimate, 1500.0);
      expect(trip.localTips, ['Buy metro pass', 'Visit early morning']);
      expect(trip.isSynced, true);
    });

    test('serializes to JSON correctly with nested data', () {
      final activity = Activity(
        title: 'Eiffel Tower',
        estimatedCost: 25.0,
      );

      final day = Day(
        dayIndex: 1,
        date: DateTime(2025, 3, 15),
        summary: 'Exploring landmarks',
        activities: [activity],
      );

      final trip = Trip(
        id: 'trip-456',
        userId: 'user-456',
        destination: 'Paris',
        days: [day],
        totalBudgetEstimate: 500.0,
        isSynced: false,
      );

      final json = trip.toJson();

      expect(json['id'], 'trip-456');
      expect(json['user_id'], 'user-456');
      expect(json['destination'], 'Paris');
      expect(json['days'], isList);
      expect(json['days'].length, 1);
      expect(json['days'][0]['day_index'], 1);
      expect(json['days'][0]['activities'].length, 1);
      expect(json['total_budget_estimate'], 500.0);
      expect(json['is_synced'], false);
      expect(json['local_updated_at'], isNotNull);
      expect(json['created_at'], isNotNull);
    });

    test('deserializes from JSON correctly with nested data', () {
      final json = {
        'id': 'trip-789',
        'user_id': 'user-789',
        'server_id': 'server-abc',
        'title': 'Rome Trip',
        'destination': 'Rome, Italy',
        'start_date': '2025-04-01T00:00:00.000Z',
        'end_date': '2025-04-05T00:00:00.000Z',
        'travel_style': 'packed',
        'budget_tier': 'luxury',
        'preferences': 'ancient history, fine dining',
        'days': [
          {
            'id': 'day-1',
            'day_index': 1,
            'date': '2025-04-01T00:00:00.000Z',
            'summary': 'Colosseum and Roman Forum',
            'activities': [
              {
                'id': 'act-1',
                'title': 'Colosseum Tour',
                'start_time': '09:00',
                'estimated_cost': 30.0,
              }
            ],
            'notes': [],
            'budget_items': [],
            'total_day_budget': 100.0,
          }
        ],
        'notes': [],
        'budget_items': [],
        'total_budget_estimate': 2000.0,
        'local_tips': ['Book tickets online', 'Avoid August'],
        'is_synced': true,
        'local_updated_at': '2025-11-20T10:00:00.000Z',
        'created_at': '2025-11-15T08:00:00.000Z',
      };

      final trip = Trip.fromJson(json);

      expect(trip.id, 'trip-789');
      expect(trip.userId, 'user-789');
      expect(trip.serverId, 'server-abc');
      expect(trip.title, 'Rome Trip');
      expect(trip.destination, 'Rome, Italy');
      expect(trip.travelStyle, 'packed');
      expect(trip.budgetTier, 'luxury');

      expect(trip.days.length, 1);
      expect(trip.days[0].dayIndex, 1);
      expect(trip.days[0].activities.length, 1);
      expect(trip.days[0].activities[0].title, 'Colosseum Tour');
      expect(trip.totalBudgetEstimate, 2000.0);
      expect(trip.localTips.length, 2);
      expect(trip.isSynced, true);
    });

    test('round-trip JSON serialization preserves data', () {
      final original = Trip(
        userId: 'user-abc',
        destination: 'Barcelona, Spain',
        title: 'Barcelona Weekend',
        startDate: DateTime(2025, 5, 10),
        endDate: DateTime(2025, 5, 12),
        travelStyle: 'moderate',
        budgetTier: 'mid',
        totalBudgetEstimate: 800.0,
        localTips: ['Learn basic Spanish'],
        isSynced: false,
      );

      final json = original.toJson();
      final deserialized = Trip.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.userId, original.userId);
      expect(deserialized.destination, original.destination);
      expect(deserialized.title, original.title);
      expect(deserialized.travelStyle, original.travelStyle);
      expect(deserialized.budgetTier, original.budgetTier);
      expect(deserialized.totalBudgetEstimate, original.totalBudgetEstimate);
      expect(deserialized.localTips, original.localTips);
      expect(deserialized.isSynced, original.isSynced);
    });

    test('markAsModified sets isSynced to false and updates timestamp', () {
      final original = Trip(
        userId: 'user-def',
        destination: 'London',
        isSynced: true,
      );

      // Wait a tiny bit to ensure timestamp difference
      Future.delayed(Duration(milliseconds: 1));

      final modified = original.markAsModified();

      expect(modified.isSynced, false);
      expect(modified.localUpdatedAt.isAfter(original.localUpdatedAt) ||
             modified.localUpdatedAt.isAtSameMomentAs(original.localUpdatedAt), 
             true);
      expect(modified.destination, original.destination); // Other fields preserved
    });

    test('markAsSynced sets serverId and isSynced to true', () {
      final original = Trip(
        userId: 'user-ghi',
        destination: 'Tokyo',
        isSynced: false,
        serverId: null,
      );

      final synced = original.markAsSynced('server-xyz-123');

      expect(synced.serverId, 'server-xyz-123');
      expect(synced.isSynced, true);
      expect(synced.destination, original.destination);
    });

    test('calculateTotalCost sums all activities across days', () {
      final day1 = Day(
        dayIndex: 1,
        activities: [
          Activity(title: 'Activity 1', estimatedCost: 50.0),
          Activity(title: 'Activity 2', estimatedCost: 30.0),
        ],
      );

      final day2 = Day(
        dayIndex: 2,
        activities: [
          Activity(title: 'Activity 3', estimatedCost: 40.0),
        ],
      );

      final trip = Trip(
        userId: 'user-jkl',
        destination: 'Test',
        days: [day1, day2],
      );

      expect(trip.calculateTotalCost(), 120.0);
    });

    test('numberOfDays returns correct count', () {
      final trip = Trip(
        userId: 'test-user',
        destination: 'Test',
        days: [
          Day(dayIndex: 1),
          Day(dayIndex: 2),
          Day(dayIndex: 3),
        ],
      );

      expect(trip.numberOfDays, 3);
    });

    test('durationDays calculates correctly from dates', () {
      final trip = Trip(
        userId: 'test-user',
        destination: 'Test',
        startDate: DateTime(2025, 6, 1),
        endDate: DateTime(2025, 6, 5),
      );

      expect(trip.durationDays, 5); // Inclusive of both start and end
    });

    test('durationDays returns null when dates not set', () {
      final trip = Trip(userId: 'test-user', destination: 'Test');

      expect(trip.durationDays, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Trip(
        userId: 'test-user',
        destination: 'Original',
        isSynced: false,
      );

      final updated = original.copyWith(
        destination: 'Updated',
        isSynced: true,
      );

      expect(updated.id, original.id);
      expect(updated.destination, 'Updated');
      expect(updated.isSynced, true);
      expect(original.destination, 'Original'); // Original unchanged
    });

    test('equality operator works correctly', () {
      final trip1 = Trip(
        id: 'same-id',
        userId: 'test-user',
        destination: 'Paris',
        isSynced: false,
      );

      final trip2 = Trip(
        id: 'same-id',
        userId: 'test-user',
        destination: 'Paris',
        isSynced: false,
      );

      final trip3 = Trip(
        id: 'different-id',
        userId: 'test-user',
        destination: 'Paris',
        isSynced: false,
      );

      expect(trip1, equals(trip2));
      expect(trip1, isNot(equals(trip3)));
    });

    test('handles minimal JSON correctly', () {
      final json = {
        'destination': 'Minimal Trip',
      };

      final trip = Trip.fromJson(json);

      expect(trip.id, isNotEmpty); // Generated UUID
      expect(trip.destination, 'Minimal Trip');
      expect(trip.serverId, isNull);
      expect(trip.title, isNull);
      expect(trip.days, isEmpty);
      expect(trip.isSynced, false);
      expect(trip.totalBudgetEstimate, 0.0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/detail/activity_detail_screen.dart';
import 'package:tripcraft_app/src/models/trip.dart';
import 'package:tripcraft_app/src/models/day.dart';
import 'package:tripcraft_app/src/models/activity.dart';
import 'package:tripcraft_app/src/models/note.dart';
import 'package:tripcraft_app/src/services/local_storage_service.dart';
import 'package:tripcraft_app/src/providers/providers.dart';

/// Mock LocalStorageService for testing
class MockLocalStorageService implements LocalStorageService {
  final Map<String, Trip> _trips = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTrip(Trip trip) async {
    _trips[trip.id] = trip;
  }

  @override
  Future<Trip?> getTrip(String id) async {
    return _trips[id];
  }

  @override
  Future<List<Trip>> getAllTrips() async {
    return _trips.values.toList();
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.remove(id);
  }

  @override
  Future<List<Trip>> searchTrips(String query) async {
    return _trips.values
        .where((trip) =>
            trip.destination.toLowerCase().contains(query.toLowerCase()) ||
            (trip.title?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
  }

  @override
  Future<void> saveTrips(List<Trip> trips) async {
    for (var trip in trips) {
      _trips[trip.id] = trip;
    }
  }

  @override
  Future<void> deleteTrips(List<String> ids) async {
    for (var id in ids) {
      _trips.remove(id);
    }
  }

  @override
  Future<void> clearAll() async {
    _trips.clear();
  }

  @override
  int get tripCount => _trips.length;

  @override
  bool tripExists(String id) => _trips.containsKey(id);

  @override
  Future<List<Trip>> getTripsModifiedAfter(DateTime date) async {
    return _trips.values
        .where((trip) => trip.localUpdatedAt.isAfter(date))
        .toList();
  }

  @override
  Future<List<Trip>> searchByDestination(String query) async {
    return _trips.values
        .where((trip) =>
            trip.destination.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Map<String, dynamic> getStorageStats() {
    return {
      'total': _trips.length,
      'size': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllTripsJson() async {
    return _trips.values.map((trip) => trip.toJson()).toList();
  }

  @override
  Future<int> importTripsFromJson(List<Map<String, dynamic>> tripsJson) async {
    int count = 0;
    for (var json in tripsJson) {
      final trip = Trip.fromJson(json);
      _trips[trip.id] = trip;
      count++;
    }
    return count;
  }

  @override
  Future<void> compactStorage() async {}

  @override
  Future<void> close() async {}

  @override
  Future<List<Trip>> getUnsyncedTrips() async {
    return _trips.values.where((trip) => !trip.isSynced).toList();
  }

  @override
  Future<void> markAsSynced(String tripId, String serverId) async {
    final trip = _trips[tripId];
    if (trip != null) {
      _trips[tripId] = trip.copyWith(
        serverId: serverId,
        isSynced: true,
      );
    }
  }

  @override
  Future<Map<String, int>> getStats() async {
    return {
      'total': _trips.length,
      'unsynced': _trips.values.where((t) => !t.isSynced).length,
    };
  }

  @override
  Future<List<Trip>> getTripsByDateRange(DateTime start, DateTime end) async {
    return _trips.values
        .where((trip) =>
            trip.startDate != null &&
            trip.startDate!.isAfter(start.subtract(const Duration(days: 1))) &&
            trip.startDate!.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  @override
  Future<List<Trip>> sortTrips(List<Trip> trips, String sortBy) async {
    final sorted = List<Trip>.from(trips);
    switch (sortBy) {
      case 'date':
        sorted.sort((a, b) => (b.startDate ?? DateTime.now())
            .compareTo(a.startDate ?? DateTime.now()));
        break;
      case 'destination':
        sorted.sort((a, b) => a.destination.compareTo(b.destination));
        break;
      case 'name':
        sorted.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
        break;
    }
    return sorted;
  }
}

/// Helper function to create a test trip with activity
Trip createTestTrip({
  String? id,
  String destination = 'Paris',
  List<Day>? days,
}) {
  return Trip(
    id: id ?? 'test-trip-id',
    userId: 'test-user-id',
    title: 'Trip to $destination',
    destination: destination,
    startDate: DateTime(2025, 6, 1),
    endDate: DateTime(2025, 6, 5),
    days: days ?? [],
  );
}

/// Helper function to create a test activity
Activity createTestActivity({
  String? id,
  String title = 'Eiffel Tower Visit',
  String? startTime,
  String? endTime,
  String? location,
  String? details,
  double estimatedCost = 25.0,
}) {
  return Activity(
    id: id ?? 'test-activity-id',
    title: title,
    startTime: startTime,
    endTime: endTime,
    location: location,
    details: details,
    estimatedCost: estimatedCost,
  );
}

/// Helper to create widget for testing
Widget createTestWidget({
  required String tripId,
  required int dayIndex,
  required String activityId,
  required MockLocalStorageService mockStorage,
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(mockStorage),
    ],
    child: MaterialApp(
      home: ActivityDetailScreen(
        tripId: tripId,
        dayIndex: dayIndex,
        activityId: activityId,
      ),
    ),
  );
}

void main() {
  group('ActivityDetailScreen - Loading & Display', () {
    testWidgets('shows loading spinner initially', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays activity details after loading', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(
        title: 'Louvre Museum',
        location: '75001 Paris',
        details: 'World-famous art museum',
        startTime: '09:00',
        endTime: '17:00',
        estimatedCost: 15.0,
      );
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Check all fields are displayed
      expect(find.text('Louvre Museum'), findsOneWidget);
      expect(find.text('75001 Paris'), findsOneWidget);
      expect(find.text('World-famous art museum'), findsOneWidget);
      expect(find.text('15.00'), findsOneWidget);
    });

    testWidgets('displays time fields correctly', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(
        startTime: '09:30',
        endTime: '15:45',
      );
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Check time displays (format may vary by locale)
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
    });
  });

  group('ActivityDetailScreen - Edit Mode', () {
    testWidgets('can enter edit mode', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Save button should appear
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('can edit title field', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(title: 'Original Title');
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Find and edit title field
      final titleField = find.widgetWithText(TextFormField, 'Original Title');
      expect(titleField, findsOneWidget);

      await tester.enterText(titleField, 'Updated Title');
      await tester.pumpAndSettle();

      // Verify text changed
      expect(find.text('Updated Title'), findsOneWidget);
    });

    testWidgets('can save edited activity', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(title: 'Original');
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Edit title
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Original'),
        'Modified',
      );
      await tester.pumpAndSettle();

      // Ensure Save button is visible
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify success message
      expect(find.text('Activity saved successfully'), findsOneWidget);

      // Verify saved in storage
      final savedTrip = await mockStorage.getTrip(trip.id);
      final savedActivity =
          savedTrip!.days.first.activities.first;
      expect(savedActivity.title, 'Modified');
    });

    testWidgets('validates required title field', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(title: 'Original');
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Clear title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Original'),
        '',
      );
      await tester.pumpAndSettle();

      // Ensure Save button is visible
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Try to save
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Activity Title is required'), findsOneWidget);
    });

    testWidgets('can cancel edit mode', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(title: 'Original');
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Modify title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Original'),
        'Modified',
      );
      await tester.pumpAndSettle();

      // Cancel (close icon appears in edit mode)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should revert to original
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Modified'), findsNothing);
    });
  });

  group('ActivityDetailScreen - Notes', () {
    testWidgets('shows empty notes message', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity], notes: []);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No notes yet. Add one above!'), findsOneWidget);
    });

    testWidgets('displays existing notes', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final note = Note(content: 'Remember to bring tickets');
      final day = Day(dayIndex: 1, activities: [activity], notes: [note]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check that notes section exists and note widget is present
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('can add a new note', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity], notes: []);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Enter note text
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a note...'),
        'New note content',
      );
      await tester.pumpAndSettle();

      // Tap add button
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pumpAndSettle();

      // Note should appear
      expect(find.text('New note content'), findsOneWidget);
    });

    testWidgets('can delete a note', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final note = Note(content: 'Note to delete');
      final day = Day(dayIndex: 1, activities: [activity], notes: [note]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Ensure note text is visible
      expect(find.text('Note to delete'), findsOneWidget);

      // Tap delete button for this specific note
      await tester.tap(find.byKey(Key('delete_note_${note.id}')));
      await tester.pumpAndSettle();

      // Note should be gone
      expect(find.text('Note to delete'), findsNothing);
    });

    testWidgets('can edit a note', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final note = Note(content: 'Original note');
      final day = Day(dayIndex: 1, activities: [activity], notes: [note]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Tap edit button for this specific note
      await tester.tap(find.byKey(Key('edit_note_${note.id}')));
      await tester.pumpAndSettle();

      // Dialog should open
      expect(find.text('Edit Note'), findsOneWidget);

      // Edit text
      await tester.enterText(
        find.byType(TextField).last,
        'Modified note',
      );
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show modified note
      expect(find.text('Modified note'), findsOneWidget);
      expect(find.text('Original note'), findsNothing);
    });
  });

  group('ActivityDetailScreen - Actions', () {
    testWidgets('shows delete menu option', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Tap menu button
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Delete Activity'), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity();
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Delete Activity'));
      await tester.pumpAndSettle();

      // Confirmation dialog should show
      expect(find.text('Delete Activity'), findsWidgets);
      expect(
        find.text(
          'Are you sure you want to delete this activity? This action cannot be undone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('can cancel delete', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(title: 'Keep Me');
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Open delete dialog
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Activity'));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Activity should still be there
      expect(find.text('Keep Me'), findsOneWidget);
      
      // Verify in storage
      final savedTrip = await mockStorage.getTrip(trip.id);
      expect(savedTrip!.days.first.activities.length, 1);
    });
  });

  group('ActivityDetailScreen - Cost Validation', () {
    testWidgets('validates numeric cost input', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(estimatedCost: 20.0);
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Enter invalid cost
      await tester.enterText(
        find.widgetWithText(TextFormField, '20.00'),
        'not-a-number',
      );
      await tester.pumpAndSettle();

      // Ensure Save button is visible
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Try to save
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });

    testWidgets('rejects negative cost', (tester) async {
      final mockStorage = MockLocalStorageService();
      final activity = createTestActivity(estimatedCost: 20.0);
      final day = Day(dayIndex: 1, activities: [activity]);
      final trip = createTestTrip(days: [day]);
      await mockStorage.saveTrip(trip);

      await tester.pumpWidget(
        createTestWidget(
          tripId: trip.id,
          dayIndex: 1,
          activityId: activity.id,
          mockStorage: mockStorage,
        ),
      );

      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Enter negative cost
      await tester.enterText(
        find.widgetWithText(TextFormField, '20.00'),
        '-10',
      );
      await tester.pumpAndSettle();

      // Ensure Save button is visible
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Try to save
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });
  });
}

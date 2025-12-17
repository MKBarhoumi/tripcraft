import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/detail/trip_detail_screen.dart';
import 'package:tripcraft_app/src/models/models.dart';
import 'package:tripcraft_app/src/providers/providers.dart';
import 'package:tripcraft_app/src/services/local_storage_service.dart';

// Mock LocalStorageService for testing
class MockLocalStorageService extends LocalStorageService {
  final Map<String, Trip> _trips = {};

  void addTrip(Trip trip) {
    _trips[trip.id] = trip;
  }

  @override
  Future<Trip?> getTrip(String id) async {
    return _trips[id];
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.remove(id);
  }
}

void main() {
  late MockLocalStorageService mockStorage;

  setUp(() {
    mockStorage = MockLocalStorageService();
  });

  Widget createTestWidget(String tripId) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp(
        home: TripDetailScreen(tripId: tripId),
      ),
    );
  }

  Trip createTestTrip({
    String? id,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? travelStyle,
    String? budgetTier,
    String? preferences,
    List<Day>? days,
  }) {
    return Trip(
      id: id ?? 'test-trip-1',
      userId: 'test-user',
      destination: destination ?? 'Paris, France',
      startDate: startDate ?? DateTime(2025, 7, 1),
      endDate: endDate ?? DateTime(2025, 7, 7),
      travelStyle: travelStyle,
      budgetTier: budgetTier,
      preferences: preferences,
      days: days ?? [],
    );
  }

  Activity createTestActivity({
    String? title,
    String? location,
    String? startTime,
    String? details,
    double? estimatedCost,
  }) {
    return Activity(
      id: 'activity-${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Test Activity',
      location: location,
      startTime: startTime,
      details: details,
      estimatedCost: estimatedCost ?? 0.0,
    );
  }

  group('TripDetailScreen - Loading & Not Found', () {
    testWidgets('shows loading indicator while fetching trip', (tester) async {
      await tester.pumpWidget(createTestWidget('non-existent'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('shows not found message for non-existent trip', (tester) async {
      await tester.pumpWidget(createTestWidget('non-existent'));
      await tester.pumpAndSettle();

      expect(find.text('Trip not found'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('This trip may have been deleted'), findsOneWidget);
      expect(find.text('Go to Home'), findsOneWidget);
    });
  });

  group('TripDetailScreen - Trip Header', () {
    testWidgets('displays trip destination and basic info', (tester) async {
      final trip = createTestTrip(
        destination: 'Tokyo, Japan',
        startDate: DateTime(2025, 8, 15),
        endDate: DateTime(2025, 8, 22),
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Tokyo, Japan'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.place), findsWidgets);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('displays travel style and budget tier chips', (tester) async {
      final trip = createTestTrip(
        travelStyle: 'adventure',
        budgetTier: 'luxury',
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Adventure'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);
      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('displays preferences when provided', (tester) async {
      final trip = createTestTrip(
        preferences: 'Love museums and local cuisine',
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Love museums and local cuisine'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('shows activity count in header', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(title: 'Activity 1'),
              createTestActivity(title: 'Activity 2'),
            ],
          ),
          Day(
            dayIndex: 2,
            activities: [
              createTestActivity(title: 'Activity 3'),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 activities'), findsWidgets);
    });

    testWidgets('shows total budget when activities have costs', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(estimatedCost: 50.0),
              createTestActivity(estimatedCost: 75.50),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.textContaining('\$126'), findsOneWidget);
    });
  });

  group('TripDetailScreen - Day Tabs', () {
    testWidgets('displays day tabs for trip with multiple days', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(dayIndex: 1, activities: []),
          Day(dayIndex: 2, activities: []),
          Day(dayIndex: 3, activities: []),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Day 1'), findsWidgets);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('Day 3'), findsOneWidget);
    });

    testWidgets('can switch between days by tapping tabs', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [createTestActivity(title: 'Day 1 Activity')],
          ),
          Day(
            dayIndex: 2,
            activities: [createTestActivity(title: 'Day 2 Activity')],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      // Initially shows Day 1 content
      expect(find.text('Day 1 Activity'), findsOneWidget);
      expect(find.text('Day 2 Activity'), findsNothing);

      // Tap Day 2 tab
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();

      // Now shows Day 2 content
      expect(find.text('Day 1 Activity'), findsNothing);
      expect(find.text('Day 2 Activity'), findsOneWidget);
    });

    testWidgets('selected day tab shows check icon', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(dayIndex: 1, activities: []),
          Day(dayIndex: 2, activities: []),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      // Day 1 is selected by default, should have check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('TripDetailScreen - Activity Display', () {
    testWidgets('displays activity card with title and location', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(
                title: 'Eiffel Tower Visit',
                location: 'Champ de Mars, Paris',
              ),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Eiffel Tower Visit'), findsOneWidget);
      expect(find.text('Champ de Mars, Paris'), findsOneWidget);
    });

    testWidgets('displays activity with start time', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(
                title: 'Museum Tour',
                startTime: '09:00',
              ),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('displays activity details when provided', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(
                title: 'Louvre Museum',
                details: 'Explore the world\'s largest art museum',
              ),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.textContaining('Explore the world'), findsOneWidget);
    });

    testWidgets('displays activity cost', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(
                title: 'River Cruise',
                estimatedCost: 35.50,
              ),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('\$35.50'), findsOneWidget);
      expect(find.byIcon(Icons.attach_money), findsWidgets);
    });
  });

  group('TripDetailScreen - Empty States', () {
    testWidgets('shows empty state when trip has no days', (tester) async {
      final trip = createTestTrip(days: []);
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('No itinerary yet'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off), findsOneWidget);
      expect(find.text('Edit Trip'), findsOneWidget);
    });

    testWidgets('shows empty day state when day has no activities', (tester) async {
      final trip = createTestTrip(
        days: [Day(dayIndex: 1, activities: [])],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('No activities planned for this day'), findsOneWidget);
      expect(find.byIcon(Icons.event_available), findsOneWidget);
      expect(find.textContaining('Tap the + button'), findsOneWidget);
    });
  });

  group('TripDetailScreen - Actions', () {
    testWidgets('shows edit button in app bar', (tester) async {
      final trip = createTestTrip();
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsWidgets);
      expect(find.byTooltip('Edit Trip'), findsOneWidget);
    });

    testWidgets('shows menu button with options', (tester) async {
      final trip = createTestTrip();
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      // Tap menu button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Delete Trip'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
    });

    testWidgets('shows FAB to add activity when trip has days', (tester) async {
      final trip = createTestTrip(
        days: [Day(dayIndex: 1, activities: [])],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Activity'), findsOneWidget);
    });

    testWidgets('does not show FAB when trip has no days', (tester) async {
      final trip = createTestTrip(days: []);
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('TripDetailScreen - Multiple Activities', () {
    testWidgets('displays multiple activities in order', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(title: 'Morning Activity'),
              createTestActivity(title: 'Afternoon Activity'),
              createTestActivity(title: 'Evening Activity'),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('Morning Activity'), findsOneWidget);
      expect(find.text('Afternoon Activity'), findsOneWidget);
      expect(find.text('Evening Activity'), findsOneWidget);
    });

    testWidgets('shows activity count for the day', (tester) async {
      final trip = createTestTrip(
        days: [
          Day(
            dayIndex: 1,
            activities: [
              createTestActivity(),
              createTestActivity(),
              createTestActivity(),
              createTestActivity(),
            ],
          ),
        ],
      );
      mockStorage.addTrip(trip);

      await tester.pumpWidget(createTestWidget(trip.id));
      await tester.pumpAndSettle();

      expect(find.text('4 activities'), findsAtLeastNWidgets(1));
    });
  });
}

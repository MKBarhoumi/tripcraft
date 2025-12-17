// budget_tracker_screen_test.dart
// Tests for the Budget Tracker Screen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/detail/budget_tracker_screen.dart';
import 'package:tripcraft_app/src/models/trip.dart';
import 'package:tripcraft_app/src/models/day.dart';
import 'package:tripcraft_app/src/models/activity.dart';
import 'package:tripcraft_app/src/models/budget_item.dart';
import 'package:tripcraft_app/src/services/local_storage_service.dart';
import 'package:tripcraft_app/src/providers/providers.dart';

// Mock LocalStorageService
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
  Future<void> deleteTrip(String id) async {
    _trips.remove(id);
  }

  @override
  Future<List<Trip>> getAllTrips() async {
    return _trips.values.toList();
  }

  @override
  Future<List<Trip>> searchTrips(String query) async {
    return _trips.values
        .where((trip) =>
            (trip.title?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            trip.destination.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<List<Trip>> getUnsyncedTrips() async {
    return _trips.values.where((trip) => !trip.isSynced).toList();
  }

  @override
  Future<void> saveTrips(List<Trip> trips) async {
    for (final trip in trips) {
      _trips[trip.id] = trip;
    }
  }

  @override
  Future<void> deleteTrips(List<String> ids) async {
    for (final id in ids) {
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
  bool tripExists(String id) {
    return _trips.containsKey(id);
  }

  @override
  Future<List<Trip>> getTripsModifiedAfter(DateTime timestamp) async {
    return _trips.values
        .where((trip) => trip.localUpdatedAt.isAfter(timestamp))
        .toList();
  }

  @override
  Future<List<Trip>> searchByDestination(String destination) async {
    return _trips.values
        .where((trip) =>
            trip.destination.toLowerCase().contains(destination.toLowerCase()))
        .toList();
  }

  @override
  Map<String, dynamic> getStorageStats() {
    return {
      'totalTrips': _trips.length,
      'syncedTrips': _trips.values.where((t) => t.isSynced).length,
      'unsyncedTrips': _trips.values.where((t) => !t.isSynced).length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllTripsJson() async {
    return _trips.values.map((t) => t.toJson()).toList();
  }

  @override
  Future<int> importTripsFromJson(List<Map<String, dynamic>> tripsJson) async {
    for (final json in tripsJson) {
      final trip = Trip.fromJson(json);
      _trips[trip.id] = trip;
    }
    return tripsJson.length;
  }

  @override
  Future<void> compactStorage() async {}

  @override
  Future<void> close() async {}
}

// Helper function to create test trip
Trip createTestTrip({List<BudgetItem>? budgetItems, List<Day>? days}) {
  return Trip(
    id: 'test-trip-1',
    userId: 'test-user-id',
    destination: 'Paris',
    title: 'Paris Adventure',
    startDate: DateTime(2024, 6, 1),
    endDate: DateTime(2024, 6, 7),
    budgetItems: budgetItems ?? [],
    days: days ?? [],
  );
}

// Helper function to create test widget
Widget createTestWidget(String tripId, MockLocalStorageService mockService) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(mockService),
    ],
    child: MaterialApp(
      home: BudgetTrackerScreen(tripId: tripId),
    ),
  );
}

void main() {
  group('BudgetTrackerScreen - Loading & Display', () {
    testWidgets('shows loading spinner initially', (tester) async {
      final mockService = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays trip not found when trip does not exist',
        (tester) async {
      final mockService = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget('nonexistent', mockService));
      await tester.pumpAndSettle();

      expect(find.text('Trip not found'), findsOneWidget);
    });

    testWidgets('displays budget overview with zero values', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.text('Budget Overview'), findsOneWidget);
      expect(find.text('Total Budget'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('\$0.00'), findsAtLeastNWidgets(3));
    });

    testWidgets('displays budget items when available', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(
            id: 'item-1',
            category: 'Accommodation',
            amount: 500.0,
            description: 'Hotel stay',
          ),
          BudgetItem(
            id: 'item-2',
            category: 'Food & Dining',
            amount: 300.0,
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.text('Accommodation'), findsOneWidget);
      expect(find.text('Hotel stay'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget);
      expect(find.text('\$300.00'), findsOneWidget);
    });

    testWidgets('shows empty state when no budget items', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_budget_items')), findsOneWidget);
      expect(
        find.text('No budget items yet. Tap the + button to add one.'),
        findsOneWidget,
      );
    });
  });

  group('BudgetTrackerScreen - Budget Calculations', () {
    testWidgets('calculates total budget correctly', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(category: 'Accommodation', amount: 500.0),
          BudgetItem(category: 'Food & Dining', amount: 300.0),
          BudgetItem(category: 'Transportation', amount: 200.0),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.text('\$1,000.00'), findsOneWidget);
    });

    testWidgets('calculates spent amount from activities', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(category: 'Accommodation', amount: 500.0),
        ],
        days: [
          Day(
            dayIndex: 1,
            date: DateTime(2024, 6, 1),
            activities: [
              Activity(
                title: 'Hotel Check-in',
                estimatedCost: 150.0,
              ),
              Activity(
                title: 'Dinner',
                estimatedCost: 50.0,
              ),
            ],
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.text('\$200.00'), findsOneWidget); // Spent amount
    });

    testWidgets('displays budget progress indicator', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(category: 'Accommodation', amount: 1000.0),
        ],
        days: [
          Day(
            dayIndex: 1,
            date: DateTime(2024, 6, 1),
            activities: [
              Activity(title: 'Hotel', estimatedCost: 500.0),
            ],
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_progress')), findsOneWidget);
      expect(find.byKey(const Key('budget_percentage')), findsOneWidget);
      expect(find.textContaining('50.0% of budget used'), findsOneWidget);
    });

    testWidgets('shows over-budget warning when spent exceeds budget',
        (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(category: 'Accommodation', amount: 500.0),
        ],
        days: [
          Day(
            dayIndex: 1,
            date: DateTime(2024, 6, 1),
            activities: [
              Activity(title: 'Hotel', estimatedCost: 600.0),
            ],
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Remaining should be negative
      expect(find.text('-\$100.00'), findsOneWidget);
      // Progress should show over 100%
      expect(find.textContaining('120.0% of budget used'), findsOneWidget);
    });
  });

  group('BudgetTrackerScreen - Add Budget Item', () {
    testWidgets('can open add budget item form', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      expect(find.text('Add Budget Item'), findsOneWidget);
      expect(find.byKey(const Key('category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('amount_field')), findsOneWidget);
      expect(find.byKey(const Key('description_field')), findsOneWidget);
    });

    testWidgets('can add a new budget item', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Open form
      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      // Select category
      await tester.tap(find.byKey(const Key('category_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & Dining').last);
      await tester.pumpAndSettle();

      // Enter amount
      await tester.enterText(find.byKey(const Key('amount_field')), '250');
      await tester.pumpAndSettle();

      // Enter description
      await tester.enterText(
          find.byKey(const Key('description_field')), 'Restaurant meals');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Verify item was added
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Restaurant meals'), findsOneWidget);
      expect(find.text('\$250.00'), findsOneWidget);
      expect(find.text('Budget item added'), findsOneWidget);
    });

    testWidgets('validates required amount field', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Open form
      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      // Try to save without amount
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('validates numeric amount', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Open form
      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      // Enter invalid amount
      await tester.enterText(find.byKey(const Key('amount_field')), 'abc');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid number'), findsOneWidget);
    });

    testWidgets('validates positive amount', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Open form
      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      // Enter negative amount
      await tester.enterText(find.byKey(const Key('amount_field')), '-100');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be positive'), findsOneWidget);
    });

    testWidgets('can cancel adding budget item', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Open form
      await tester.tap(find.byKey(const Key('add_budget_item')));
      await tester.pumpAndSettle();

      // Enter data
      await tester.enterText(find.byKey(const Key('amount_field')), '100');
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pumpAndSettle();

      // Form should be closed
      expect(find.text('Add Budget Item'), findsNothing);
      expect(find.byKey(const Key('save_button')), findsNothing);
    });
  });

  group('BudgetTrackerScreen - Edit Budget Item', () {
    testWidgets('can edit existing budget item', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(
            id: 'item-1',
            category: 'Accommodation',
            amount: 500.0,
            description: 'Hotel',
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byKey(const Key('edit_item_item-1')));
      await tester.pumpAndSettle();

      // Verify form is populated
      expect(find.text('Edit Budget Item'), findsOneWidget);
      expect(find.text('500.0'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);

      // Change amount
      await tester.enterText(find.byKey(const Key('amount_field')), '600');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Verify update
      expect(find.text('\$600.00'), findsOneWidget);
      expect(find.text('Budget item updated'), findsOneWidget);
    });
  });

  group('BudgetTrackerScreen - Delete Budget Item', () {
    testWidgets('can delete budget item', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(
            id: 'item-1',
            category: 'Accommodation',
            amount: 500.0,
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byKey(const Key('delete_item_item-1')));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('Delete Budget Item'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete this budget item?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify deletion
      expect(find.text('Accommodation'), findsNothing);
      expect(find.text('\$500.00'), findsNothing);
      expect(find.text('Budget item deleted'), findsOneWidget);
    });

    testWidgets('can cancel delete budget item', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(
            id: 'item-1',
            category: 'Accommodation',
            amount: 500.0,
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byKey(const Key('delete_item_item-1')));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Item should still exist
      expect(find.text('Accommodation'), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget);
    });
  });

  group('BudgetTrackerScreen - Category Breakdown', () {
    testWidgets('displays category breakdown', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip(
        budgetItems: [
          BudgetItem(category: 'Accommodation', amount: 1000.0),
          BudgetItem(category: 'Food & Dining', amount: 500.0),
        ],
        days: [
          Day(
            dayIndex: 1,
            date: DateTime(2024, 6, 1),
            activities: [
              Activity(title: 'Hotel', estimatedCost: 300.0),
              Activity(title: 'Restaurant', estimatedCost: 100.0),
            ],
          ),
        ],
      );
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.text('Budget by Category'), findsOneWidget);
      expect(find.byKey(const Key('category_Accommodation')), findsOneWidget);
      expect(find.byKey(const Key('category_Food & Dining')), findsOneWidget);
    });

    testWidgets('shows empty state for categories', (tester) async {
      final mockService = MockLocalStorageService();
      final trip = createTestTrip();
      await mockService.saveTrip(trip);

      await tester.pumpWidget(createTestWidget('test-trip-1', mockService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_categories')), findsOneWidget);
      expect(
        find.text(
            'No budget items yet. Add items to track spending by category.'),
        findsOneWidget,
      );
    });
  });
}

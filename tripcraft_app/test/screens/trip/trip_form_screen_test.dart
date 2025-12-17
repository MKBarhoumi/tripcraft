import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/constants.dart';
import 'package:tripcraft_app/src/screens/trip/trip_form_screen.dart';
import 'package:tripcraft_app/src/models/models.dart';
import 'package:tripcraft_app/src/services/local_storage_service.dart';

class FakeLocalStorageService implements LocalStorageService {
  final Map<String, Trip> _trips = {};
  bool throwOnSave = false;
  bool throwOnDelete = false;

  Future<void> init() async {}

  @override
  Future<List<Trip>> getAllTrips() async => _trips.values.toList();

  @override
  Future<List<Trip>> getTripsByUserId(String userId) async {
    return _trips.values.where((t) => t.userId == userId).toList();
  }

  @override
  Future<Trip?> getTrip(String id) async => _trips[id];

  @override
  Future<void> saveTrip(Trip trip) async {
    if (throwOnSave) throw Exception('Save failed');
    final id = trip.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _trips[id] = trip.copyWith(id: id);
  }

  @override
  Future<void> saveTrips(List<Trip> trips) async {
    for (final trip in trips) {
      await saveTrip(trip);
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    if (throwOnDelete) throw Exception('Delete failed');
    _trips.remove(id);
  }

  @override
  Future<void> deleteTrips(List<String> ids) async {
    for (final id in ids) {
      _trips.remove(id);
    }
  }

  @override
  Future<void> clearAll() async => _trips.clear();

  @override
  int get tripCount => _trips.length;

  @override
  bool tripExists(String id) => _trips.containsKey(id);

  @override
  Future<List<Trip>> getUnsyncedTrips() async {
    return _trips.values.where((t) => !t.isSynced).toList();
  }

  @override
  Future<List<Trip>> getTripsModifiedAfter(DateTime date) async {
    return _trips.values
        .where((t) => t.createdAt != null && t.createdAt!.isAfter(date))
        .toList();
  }

  @override
  Future<List<Trip>> searchByDestination(String query) async {
    return _trips.values
        .where((t) =>
            t.destination.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Map<String, dynamic> getStorageStats() => {
        'tripCount': _trips.length,
        'boxSize': 0,
      };

  @override
  Future<List<Map<String, dynamic>>> exportAllTripsJson() async {
    return _trips.values.map((t) => t.toJson()).toList();
  }

  @override
  Future<int> importTripsFromJson(List<Map<String, dynamic>> tripsJson) async {
    int count = 0;
    for (final json in tripsJson) {
      final trip = Trip.fromJson(json);
      await saveTrip(trip);
      count++;
    }
    return count;
  }

  @override
  Future<void> compactStorage() async {}

  @override
  Future<void> close() async {}
}

void main() {
  Widget createTestWidget({String? tripId}) {
    return const ProviderScope(
      child: MaterialApp(
        home: TripFormScreen(),
      ),
    );
  }

  group('TripFormScreen - UI Rendering', () {
    testWidgets('renders create mode correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Create Trip'), findsOneWidget);
      expect(find.text('Plan your next adventure'), findsOneWidget);
      expect(find.text('Destination *'), findsOneWidget);
      expect(find.text('Trip Title (Optional)'), findsOneWidget);
      expect(find.text('Travel Dates *'), findsOneWidget);
      expect(find.text('Travel Style'), findsOneWidget);
      expect(find.text('Budget Tier'), findsOneWidget);
      expect(find.text('Preferences (Optional)'), findsOneWidget);
      expect(find.text('Create Trip'), findsNWidgets(2)); // Title + button
      expect(find.widgetWithIcon(IconButton, Icons.delete), findsNothing);
    });

    testWidgets('displays all travel style chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      for (final style in travelStyles) {
        final capitalized = style[0].toUpperCase() + style.substring(1);
        expect(find.text(capitalized), findsOneWidget);
      }
    });

    testWidgets('displays all budget tier chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      for (final tier in budgetTiers) {
        final capitalized = tier[0].toUpperCase() + tier.substring(1);
        expect(find.text(capitalized), findsOneWidget);
      }
    });
  });

  group('TripFormScreen - Date Selection', () {
    testWidgets('shows date picker when tapping start date button',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final startDateButton = find.widgetWithText(OutlinedButton, 'Start Date');
      expect(startDateButton, findsOneWidget);

      await tester.tap(startDateButton);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('displays duration when both dates are selected',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select start date
      await tester.tap(find.widgetWithText(OutlinedButton, 'Start Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Select end date (1 week later)
      await tester.tap(find.widgetWithText(OutlinedButton, 'End Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Check for duration display (should show some duration)
      expect(find.textContaining('Duration:'), findsOneWidget);
    });
  });

  group('TripFormScreen - Travel Style Selection', () {
    testWidgets('selects travel style when tapping chip', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final relaxedChip = find.widgetWithText(FilterChip, 'Relaxed');
      expect(relaxedChip, findsOneWidget);

      await tester.tap(relaxedChip);
      await tester.pumpAndSettle();

      // Chip should be selected
      final chipWidget = tester.widget<FilterChip>(relaxedChip);
      expect(chipWidget.selected, isTrue);
    });

    testWidgets('deselects travel style when tapping selected chip',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final relaxedChip = find.widgetWithText(FilterChip, 'Relaxed');

      // Select
      await tester.tap(relaxedChip);
      await tester.pumpAndSettle();

      // Deselect
      await tester.tap(relaxedChip);
      await tester.pumpAndSettle();

      // Chip should not be selected
      final chipWidget = tester.widget<FilterChip>(relaxedChip);
      expect(chipWidget.selected, isFalse);
    });
  });

  group('TripFormScreen - Budget Tier Selection', () {
    testWidgets('selects budget tier when tapping chip', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final budgetChip = find.widgetWithText(FilterChip, 'Budget');
      expect(budgetChip, findsOneWidget);

      await tester.tap(budgetChip);
      await tester.pumpAndSettle();

      // Chip should be selected
      final chipWidget = tester.widget<FilterChip>(budgetChip);
      expect(chipWidget.selected, isTrue);
    });
  });

  group('TripFormScreen - Form Validation', () {
    testWidgets('shows error when submitting empty destination',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(FilledButton, 'Create Trip');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Destination is required'), findsOneWidget);
    });

    testWidgets('shows error when submitting without dates', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter destination
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g., Paris, France'),
        'Paris',
      );

      final createButton = find.widgetWithText(FilledButton, 'Create Trip');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Start date is required'), findsOneWidget);
    });
  });

  group('TripFormScreen - Cancel Button', () {
    testWidgets('has cancel button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });
  });
}

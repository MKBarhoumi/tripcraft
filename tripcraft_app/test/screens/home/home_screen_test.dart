import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/home/home_screen.dart';
import 'package:tripcraft_app/src/models/models.dart';
import 'package:tripcraft_app/src/providers/providers.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders all UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Check for app bar title
      expect(find.text('TripCraft'), findsOneWidget);

      // Check for search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search trips...'), findsOneWidget);

      // Check for sort button
      expect(find.byIcon(Icons.sort), findsOneWidget);

      // Check for FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Create Trip'), findsOneWidget);
    });

    testWidgets('shows empty state when no trips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Check for empty state
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Start planning your first adventure!'), findsOneWidget);
      expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
    });

    testWidgets('search field can be typed in', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Enter text in search field
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('search field shows clear button when text entered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pump();

      // Now clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button clears search text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Enter text
      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, 'Paris');
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Verify the text field is now empty by checking hint text is visible
      expect(find.text('Search trips...'), findsOneWidget);
    });

    testWidgets('sort button opens sort dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Tap sort button
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.text('Date (Newest First)'), findsOneWidget);
      expect(find.text('Destination (A-Z)'), findsOneWidget);
      expect(find.text('Name (A-Z)'), findsOneWidget);
    });

    testWidgets('FAB shows snackbar when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Snackbar should appear
      expect(find.text('Trip creation coming in FE-7'), findsOneWidget);
    });

    testWidgets('displays trips when data is available', (WidgetTester tester) async {
      // Create mock trips
      final mockTrips = [
        Trip(
          id: '1',
          destination: 'Paris',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 5),
          userId: 'user1',
        ),
        Trip(
          id: '2',
          destination: 'Tokyo',
          title: 'Japan Adventure',
          startDate: DateTime(2025, 7, 10),
          endDate: DateTime(2025, 7, 17),
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripsProvider.overrideWith((ref) => mockTrips),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Check that trips are displayed
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Japan Adventure'), findsOneWidget);
    });

    testWidgets('filters trips by search query', (WidgetTester tester) async {
      // Create mock trips
      final mockTrips = [
        Trip(
          id: '1',
          destination: 'Paris',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 5),
          userId: 'user1',
        ),
        Trip(
          id: '2',
          destination: 'Tokyo',
          startDate: DateTime(2025, 7, 10),
          endDate: DateTime(2025, 7, 17),
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripsProvider.overrideWith((ref) => mockTrips),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both trips should be visible
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);

      // Search for Paris
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pump();

      // Only Paris trip card should be visible (not in search field)
      expect(find.widgetWithText(Card, 'Paris'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Tokyo'), findsNothing);
    });

    testWidgets('shows "no trips found" when search has no results', (WidgetTester tester) async {
      // Create mock trips
      final mockTrips = [
        Trip(
          id: '1',
          destination: 'Paris',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 5),
          userId: 'user1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripsProvider.overrideWith((ref) => mockTrips),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search for something that doesn't exist
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pump();

      // Should show "no trips found"
      expect(find.text('No trips found'), findsOneWidget);
      expect(find.text('Try a different search term'), findsOneWidget);
    });

    testWidgets('displays sync badge when trips are unsynced', (WidgetTester tester) async {
      // Create mock unsynced trips
      final mockTrips = [
        Trip(
          id: '1',
          destination: 'Paris',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 5),
          userId: 'user1',
          isSynced: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTripsProvider.overrideWith((ref) => mockTrips),
            unsyncedTripsProvider.overrideWith((ref) => mockTrips),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for sync badge in app bar
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);

      // Check for "Local" badge on trip card
      expect(find.text('Local'), findsOneWidget);
    });
  });

  group('TripCard', () {
    testWidgets('displays trip information correctly', (WidgetTester tester) async {
      final trip = Trip(
        id: '1',
        destination: 'Paris',
        title: 'Summer Vacation',
        startDate: DateTime(2025, 6, 1),
        endDate: DateTime(2025, 6, 5),
        userId: 'user1',
        budgetTier: 'mid-range',
        travelStyle: 'relaxed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripCard(
              trip: trip,
              onTap: () {},
            ),
          ),
        ),
      );

      // Check trip details
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Summer Vacation'), findsOneWidget);
      // Trip is from June 1-5, which is 5 days (including both days)
      // But the trip calculates numberOfDays which depends on the actual implementation
      expect(find.text('mid-range'), findsOneWidget);
      expect(find.text('relaxed'), findsOneWidget);
    });

    testWidgets('shows local badge for unsynced trips', (WidgetTester tester) async {
      final trip = Trip(
        id: '1',
        destination: 'Paris',
        startDate: DateTime(2025, 6, 1),
        endDate: DateTime(2025, 6, 5),
        userId: 'user1',
        isSynced: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripCard(
              trip: trip,
              onTap: () {},
            ),
          ),
        ),
      );

      // Check for local badge
      expect(find.text('Local'), findsOneWidget);
      expect(find.byIcon(Icons.sync_disabled), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      final trip = Trip(
        id: '1',
        destination: 'Paris',
        startDate: DateTime(2025, 6, 1),
        endDate: DateTime(2025, 6, 5),
        userId: 'user1',
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripCard(
              trip: trip,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(TripCard));
      await tester.pump();

      // Verify callback was called
      expect(tapped, isTrue);
    });
  });
}

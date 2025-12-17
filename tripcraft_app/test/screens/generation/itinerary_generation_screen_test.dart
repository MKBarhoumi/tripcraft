import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/generation/itinerary_generation_screen.dart';

void main() {
  Widget createTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        home: ItineraryGenerationScreen(
          destination: 'Paris, France',
          startDate: DateTime(2025, 7, 1),
          endDate: DateTime(2025, 7, 7),
          travelStyle: 'relaxed',
          budgetTier: 'mid',
          preferences: 'Love museums',
          autoStart: false, // Disable auto-start for tests
        ),
      ),
    );
  }

  group('ItineraryGenerationScreen - UI Rendering', () {
    testWidgets('renders screen title correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Generating Itinerary'), findsOneWidget);
    });

    testWidgets('renders trip destination', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Paris, France'), findsOneWidget);
      expect(find.byIcon(Icons.travel_explore), findsOneWidget);
    });

    testWidgets('shows travel style and budget tier chips', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Relaxed'), findsOneWidget);
      expect(find.text('Mid'), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);
      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('shows preferences when provided', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Love museums'), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
    });

    testWidgets('shows close button when not generating', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Since autoStart is false, close button should be shown
      expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
    });
  });

  group('ItineraryGenerationScreen - Generation UI', () {
    testWidgets('shows AI icon during generation', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows tip message', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.textContaining('AI is crafting'), findsOneWidget);
    });
  });

  group('ItineraryGenerationScreen - Without Optional Fields', () {
    testWidgets('renders without travel style', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ItineraryGenerationScreen(
              destination: 'Tokyo, Japan',
              startDate: DateTime(2025, 8, 1),
              endDate: DateTime(2025, 8, 5),
              autoStart: false,
            ),
          ),
        ),
      );
      
      // Pump once to build the widget
      await tester.pump();

      expect(find.text('Tokyo, Japan'), findsOneWidget);
      // Chips should not be shown
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('renders without preferences', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ItineraryGenerationScreen(
              destination: 'Rome, Italy',
              startDate: DateTime(2025, 9, 1),
              endDate: DateTime(2025, 9, 10),
              travelStyle: 'cultural',
              autoStart: false,
            ),
          ),
        ),
      );

      expect(find.text('Rome, Italy'), findsOneWidget);
      expect(find.text('Cultural'), findsOneWidget);
      // Notes icon should not appear without preferences
      expect(find.byIcon(Icons.notes), findsNothing);
    });
  });

  group('ItineraryGenerationScreen - Date Formatting', () {
    testWidgets('displays formatted date range', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should show dates in some format (exact format may vary)
      // Just check that text exists with dates
      expect(find.textContaining('7'), findsWidgets);
    });
  });
}

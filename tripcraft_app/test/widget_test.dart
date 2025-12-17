// Basic widget test for TripCraft app
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:tripcraft_app/src/app.dart';
import 'package:tripcraft_app/src/constants.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for testing
    await Hive.initFlutter();
    await Hive.openBox(hiveBoxTrips);
  });

  testWidgets('TripCraft app loads and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: TripCraftApp(),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that TripCraft title is shown
    expect(find.text('TripCraft'), findsWidgets);
    
    // Verify the placeholder buttons exist
    expect(find.text('Create Trip'), findsOneWidget);
    expect(find.text('View Trips'), findsOneWidget);
  });
}

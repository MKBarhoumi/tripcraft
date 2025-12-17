import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'src/app.dart';
import 'src/constants.dart';
import 'src/services/local_storage_service.dart';
import 'src/utils/sample_trips.dart';

/// Main entry point for TripCraft app
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();
    
    // Open the trips box for storing trip data as JSON
    await Hive.openBox(hiveBoxTrips);

    // Initialize LocalStorageService
    final localStorageService = LocalStorageService();
    await localStorageService.init();
    
    // Check if this is first run (no trips) and add sample trips
    final existingTrips = await localStorageService.getAllTrips();
    if (existingTrips.isEmpty) {
      debugPrint('🎉 First run detected - adding 5 sample trips');
      final sampleTrips = generateSampleTrips('demo-user');
      for (final trip in sampleTrips) {
        await localStorageService.saveTrip(trip);
      }
      debugPrint('✅ Sample trips added successfully');
    } else {
      debugPrint('📚 Found ${existingTrips.length} existing trips');
    }
    
    debugPrint('✅ Initialization complete');
  } catch (e, stackTrace) {
    debugPrint('⚠️ Initialization error: $e');
    debugPrint('Stack: $stackTrace');
  }

  // Run the app wrapped in ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: TripCraftApp(),
    ),
  );
}

/// ProviderObserver for debugging Riverpod state changes
class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Log provider changes in debug mode
    debugPrint('Provider updated: ${provider.name ?? provider.runtimeType}');
  }
}

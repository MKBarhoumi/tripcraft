// local_storage_service.dart
// Service for managing local trip data using Hive (JSON storage)

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants.dart';
import '../models/models.dart';

/// LocalStorageService handles all local storage operations for trips
/// Uses Hive with JSON serialization (no binary adapters)
class LocalStorageService {
  // Singleton pattern
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Box? _tripsBox;

  /// Initialize the service (box should already be opened in main.dart)
  Future<void> init() async {
    _tripsBox = Hive.box(hiveBoxTrips);
  }

  /// Get the trips box (throws if not initialized)
  Box get _box {
    if (_tripsBox == null) {
      throw StateError('LocalStorageService not initialized. Call init() first.');
    }
    return _tripsBox!;
  }

  /// Get all trips from local storage
  /// Returns list sorted by localUpdatedAt (newest first)
  Future<List<Trip>> getAllTrips() async {
    try {
      final tripsMap = _box.toMap();
      final trips = <Trip>[];

      for (final entry in tripsMap.entries) {
        try {
          final tripJson = entry.value as Map<dynamic, dynamic>;
          // Convert dynamic map to Map<String, dynamic>
          final jsonMap = Map<String, dynamic>.from(tripJson);
          trips.add(Trip.fromJson(jsonMap));
        } catch (e) {
          // Log error but continue processing other trips
          print('Error parsing trip ${entry.key}: $e');
        }
      }

      // Sort by localUpdatedAt (newest first)
      trips.sort((a, b) => b.localUpdatedAt.compareTo(a.localUpdatedAt));

      return trips;
    } catch (e) {
      print('Error getting all trips: $e');
      return [];
    }
  }

  /// Get a single trip by ID
  Future<Trip?> getTrip(String id) async {
    try {
      final tripJson = _box.get(id);
      if (tripJson == null) {
        debugPrint('📭 Trip $id not found in storage');
        return null;
      }

      final jsonMap = Map<String, dynamic>.from(tripJson as Map<dynamic, dynamic>);
      final trip = Trip.fromJson(jsonMap);
      debugPrint('📖 Loaded trip $id with ${trip.days.fold(0, (sum, day) => sum + day.activities.length)} total activities');
      return trip;
    } catch (e) {
      debugPrint('❌ Error getting trip $id: $e');
      return null;
    }
  }

  /// Save a single trip to local storage
  /// Updates localUpdatedAt automatically
  Future<void> saveTrip(Trip trip) async {
    try {
      final updatedTrip = trip.copyWith(
        localUpdatedAt: DateTime.now(),
      );
      
      debugPrint('💾 Saving trip ${trip.id} with ${trip.days.fold(0, (sum, day) => sum + day.activities.length)} total activities');
      await _box.put(updatedTrip.id, updatedTrip.toJson());
      debugPrint('✅ Trip saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving trip ${trip.id}: $e');
      rethrow;
    }
  }

  /// Save multiple trips to local storage (bulk operation)
  /// Useful for syncing from server
  Future<void> saveTrips(List<Trip> trips) async {
    try {
      final Map<String, dynamic> tripsToSave = {};
      
      for (final trip in trips) {
        tripsToSave[trip.id] = trip.toJson();
      }
      
      await _box.putAll(tripsToSave);
    } catch (e) {
      print('Error saving trips: $e');
      rethrow;
    }
  }

  /// Delete a trip from local storage
  Future<void> deleteTrip(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      print('Error deleting trip $id: $e');
      rethrow;
    }
  }

  /// Delete multiple trips (bulk operation)
  Future<void> deleteTrips(List<String> ids) async {
    try {
      await _box.deleteAll(ids);
    } catch (e) {
      print('Error deleting trips: $e');
      rethrow;
    }
  }

  /// Clear all trips from local storage
  /// Use with caution!
  Future<void> clearAll() async {
    try {
      await _box.clear();
    } catch (e) {
      print('Error clearing all trips: $e');
      rethrow;
    }
  }

  /// Get count of trips in local storage
  int get tripCount => _box.length;

  /// Check if a trip exists locally
  bool tripExists(String id) => _box.containsKey(id);

  /// Get all unsynced trips (for offline sync)
  Future<List<Trip>> getUnsyncedTrips() async {
    try {
      final allTrips = await getAllTrips();
      return allTrips.where((trip) => !trip.isSynced).toList();
    } catch (e) {
      print('Error getting unsynced trips: $e');
      return [];
    }
  }

  /// Get trips modified after a certain date
  Future<List<Trip>> getTripsModifiedAfter(DateTime date) async {
    try {
      final allTrips = await getAllTrips();
      return allTrips
          .where((trip) => trip.localUpdatedAt.isAfter(date))
          .toList();
    } catch (e) {
      print('Error getting modified trips: $e');
      return [];
    }
  }

  /// Search trips by destination
  Future<List<Trip>> searchByDestination(String query) async {
    try {
      final allTrips = await getAllTrips();
      final lowerQuery = query.toLowerCase();
      
      return allTrips
          .where((trip) => 
              trip.destination.toLowerCase().contains(lowerQuery) ||
              (trip.title?.toLowerCase().contains(lowerQuery) ?? false))
          .toList();
    } catch (e) {
      print('Error searching trips: $e');
      return [];
    }
  }

  /// Get storage statistics
  Map<String, dynamic> getStorageStats() {
    try {
      return {
        'total_trips': _box.length,
        'box_name': hiveBoxTrips,
        'is_open': _box.isOpen,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Export all trips as JSON (for backup)
  Future<List<Map<String, dynamic>>> exportAllTripsJson() async {
    try {
      final trips = await getAllTrips();
      return trips.map((trip) => trip.toJson()).toList();
    } catch (e) {
      print('Error exporting trips: $e');
      return [];
    }
  }

  /// Import trips from JSON (for restore)
  Future<int> importTripsFromJson(List<Map<String, dynamic>> tripsJson) async {
    try {
      int imported = 0;
      
      for (final json in tripsJson) {
        try {
          final trip = Trip.fromJson(json);
          await saveTrip(trip);
          imported++;
        } catch (e) {
          print('Error importing trip: $e');
        }
      }
      
      return imported;
    } catch (e) {
      print('Error importing trips: $e');
      return 0;
    }
  }

  /// Compact the Hive box (optimize storage)
  Future<void> compactStorage() async {
    try {
      await _box.compact();
    } catch (e) {
      print('Error compacting storage: $e');
    }
  }

  /// Close the storage (call on app shutdown)
  Future<void> close() async {
    try {
      await _box.close();
      _tripsBox = null;
    } catch (e) {
      print('Error closing storage: $e');
    }
  }
}

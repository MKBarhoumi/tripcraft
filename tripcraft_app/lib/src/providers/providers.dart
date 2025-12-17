// providers.dart
// Global Riverpod providers for services

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/local_storage_service.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import 'auth_state.dart';

/// Provider for LocalStorageService (singleton)
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService(); // Returns singleton instance
});

/// Provider for FlutterSecureStorage (singleton)
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for ApiClient (singleton)
final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(secureStorage: secureStorage);
});

/// Provider for SyncService (singleton)
final syncServiceProvider = Provider<SyncService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return SyncService(
    localStorage: localStorage,
    apiClient: apiClient,
  );
});

/// Provider for authentication state
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

/// Provider for getting all trips from local storage
/// This is a FutureProvider that automatically updates when trips change
final allTripsProvider = FutureProvider.autoDispose((ref) async {
  final storageService = ref.watch(localStorageServiceProvider);
  return await storageService.getAllTrips();
});

/// Provider for getting unsynced trips
final unsyncedTripsProvider = FutureProvider.autoDispose((ref) async {
  final storageService = ref.watch(localStorageServiceProvider);
  return await storageService.getUnsyncedTrips();
});

/// Provider for getting a single trip by ID
/// Pass the trip ID as a parameter
final tripProvider = FutureProvider.family<Trip?, String>((ref, id) async {
  final storageService = ref.watch(localStorageServiceProvider);
  return await storageService.getTrip(id);
});

/// Provider for storage statistics
final storageStatsProvider = Provider.autoDispose((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return storageService.getStorageStats();
});

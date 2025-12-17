// sync_service.dart
// Service for synchronizing local trips with the server

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'local_storage_service.dart';

/// Sync status enumeration
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Sync result with statistics
class SyncResult {
  final SyncStatus status;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final String? errorMessage;
  final DateTime timestamp;

  SyncResult({
    required this.status,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess => status == SyncStatus.success;
  bool get hasError => status == SyncStatus.error;
  bool get hasConflicts => conflicts > 0;

  @override
  String toString() {
    return 'SyncResult(status: $status, up: $uploaded, down: $downloaded, conflicts: $conflicts)';
  }
}

/// Conflict resolution strategy
enum ConflictResolution {
  serverWins,  // Server version takes precedence
  clientWins,  // Local version takes precedence
  newestWins,  // Most recently updated version wins
  manual,      // User must resolve manually
}

/// SyncService handles synchronization between local and remote data
class SyncService {
  final LocalStorageService _localStorage;
  final ApiClient _apiClient;
  
  SyncStatus _status = SyncStatus.idle;
  SyncResult? _lastSyncResult;
  DateTime? _lastSyncTime;

  // Callbacks for sync events
  final List<Function(SyncStatus)> _statusListeners = [];
  final List<Function(SyncResult)> _resultListeners = [];

  SyncService({
    required LocalStorageService localStorage,
    required ApiClient apiClient,
  })  : _localStorage = localStorage,
        _apiClient = apiClient;

  // ============================================================================
  // GETTERS
  // ============================================================================

  SyncStatus get status => _status;
  SyncResult? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _status == SyncStatus.syncing;

  // ============================================================================
  // LISTENERS
  // ============================================================================

  void addStatusListener(Function(SyncStatus) listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(Function(SyncStatus) listener) {
    _statusListeners.remove(listener);
  }

  void addResultListener(Function(SyncResult) listener) {
    _resultListeners.add(listener);
  }

  void removeResultListener(Function(SyncResult) listener) {
    _resultListeners.remove(listener);
  }

  void _notifyStatusChange(SyncStatus newStatus) {
    _status = newStatus;
    for (final listener in _statusListeners) {
      listener(newStatus);
    }
  }

  void _notifyResult(SyncResult result) {
    _lastSyncResult = result;
    _lastSyncTime = result.timestamp;
    for (final listener in _resultListeners) {
      listener(result);
    }
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Perform full synchronization
  /// 1. Upload unsynced local trips
  /// 2. Download all trips from server
  /// 3. Resolve conflicts
  /// 4. Update local storage
  Future<SyncResult> sync({
    ConflictResolution conflictResolution = ConflictResolution.newestWins,
  }) async {
    if (_status == SyncStatus.syncing) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: 'Sync already in progress',
      );
    }

    _notifyStatusChange(SyncStatus.syncing);

    try {
      int uploaded = 0;
      int downloaded = 0;
      int conflicts = 0;

      // Step 1: Check authentication
      final isAuthenticated = await _apiClient.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Step 2: Get unsynced local trips
      final unsyncedTrips = await _localStorage.getUnsyncedTrips();
      debugPrint('Found ${unsyncedTrips.length} unsynced trips');

      // Step 3: Upload unsynced trips
      if (unsyncedTrips.isNotEmpty) {
        try {
          final uploadedTrips = await _uploadTrips(unsyncedTrips);
          uploaded = uploadedTrips.length;
          
          // Mark as synced locally
          for (final trip in uploadedTrips) {
            await _localStorage.saveTrip(trip);
          }
        } catch (e) {
          debugPrint('Error uploading trips: $e');
          // Continue with download even if upload fails
        }
      }

      // Step 4: Download all trips from server
      try {
        final serverTrips = await _apiClient.getTrips();
        debugPrint('Downloaded ${serverTrips.length} trips from server');

        // Step 5: Merge with local storage
        final mergeResult = await _mergeTrips(
          serverTrips,
          conflictResolution: conflictResolution,
        );
        
        downloaded = mergeResult.downloaded;
        conflicts = mergeResult.conflicts;
      } catch (e) {
        debugPrint('Error downloading trips: $e');
        throw Exception('Failed to download trips: $e');
      }

      // Step 6: Success
      _notifyStatusChange(SyncStatus.success);
      final result = SyncResult(
        status: SyncStatus.success,
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
      );
      _notifyResult(result);
      
      return result;
    } catch (e) {
      debugPrint('Sync error: $e');
      _notifyStatusChange(SyncStatus.error);
      
      final result = SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      _notifyResult(result);
      
      return result;
    } finally {
      if (_status == SyncStatus.syncing) {
        _notifyStatusChange(SyncStatus.idle);
      }
    }
  }

  /// Upload trips to server
  Future<List<Trip>> _uploadTrips(List<Trip> trips) async {
    final uploadedTrips = <Trip>[];

    for (final trip in trips) {
      try {
        Trip serverTrip;
        
        if (trip.serverId != null) {
          // Update existing trip on server
          serverTrip = await _apiClient.updateTrip(trip.serverId!, trip);
        } else {
          // Create new trip on server
          serverTrip = await _apiClient.createTrip(trip);
        }
        
        // Mark as synced with server ID
        final syncedTrip = trip.markAsSynced(serverTrip.id);
        uploadedTrips.add(syncedTrip);
        
        debugPrint('Uploaded trip: ${trip.id} -> ${serverTrip.id}');
      } catch (e) {
        debugPrint('Failed to upload trip ${trip.id}: $e');
        // Continue with other trips
      }
    }

    return uploadedTrips;
  }

  /// Merge server trips with local storage
  Future<_MergeResult> _mergeTrips(
    List<Trip> serverTrips, {
    required ConflictResolution conflictResolution,
  }) async {
    int downloaded = 0;
    int conflicts = 0;

    final localTrips = await _localStorage.getAllTrips();
    final localTripsMap = {for (var t in localTrips) t.serverId ?? t.id: t};

    for (final serverTrip in serverTrips) {
      final localTrip = localTripsMap[serverTrip.id];

      if (localTrip == null) {
        // New trip from server - just save it
        await _localStorage.saveTrip(serverTrip.markAsSynced(serverTrip.id));
        downloaded++;
      } else {
        // Trip exists locally - check for conflicts
        if (_hasConflict(localTrip, serverTrip)) {
          conflicts++;
          final resolved = await _resolveConflict(
            localTrip,
            serverTrip,
            conflictResolution,
          );
          await _localStorage.saveTrip(resolved);
        } else if (serverTrip.localUpdatedAt.isAfter(localTrip.localUpdatedAt)) {
          // Server version is newer - update local
          await _localStorage.saveTrip(serverTrip.markAsSynced(serverTrip.id));
          downloaded++;
        }
        // If local is newer and synced, keep local version
      }
    }

    return _MergeResult(downloaded: downloaded, conflicts: conflicts);
  }

  /// Check if there's a conflict between local and server versions
  bool _hasConflict(Trip local, Trip server) {
    // Conflict exists if:
    // 1. Both have been modified after last sync
    // 2. Local is not synced (has pending changes)
    // 3. Server version is different
    
    if (local.isSynced) {
      return false; // Local hasn't changed since last sync
    }

    // Compare key fields to detect actual differences
    return local.destination != server.destination ||
           local.title != server.title ||
           local.startDate != server.startDate ||
           local.endDate != server.endDate ||
           local.days.length != server.days.length;
  }

  /// Resolve conflict between local and server versions
  Future<Trip> _resolveConflict(
    Trip local,
    Trip server,
    ConflictResolution strategy,
  ) async {
    debugPrint('Resolving conflict for trip ${local.id} using $strategy');

    switch (strategy) {
      case ConflictResolution.serverWins:
        return server.markAsSynced(server.id);

      case ConflictResolution.clientWins:
        return local.copyWith(isSynced: false); // Keep local, mark for upload

      case ConflictResolution.newestWins:
        if (server.localUpdatedAt.isAfter(local.localUpdatedAt)) {
          return server.markAsSynced(server.id);
        } else {
          return local.copyWith(isSynced: false);
        }

      case ConflictResolution.manual:
        // For now, default to newest wins
        // In a real app, this would trigger a UI dialog
        return _resolveConflict(local, server, ConflictResolution.newestWins);
    }
  }

  // ============================================================================
  // SINGLE TRIP OPERATIONS
  // ============================================================================

  /// Upload a single trip to the server
  Future<Trip> uploadTrip(Trip trip) async {
    try {
      Trip serverTrip;
      
      if (trip.serverId != null) {
        serverTrip = await _apiClient.updateTrip(trip.serverId!, trip);
      } else {
        serverTrip = await _apiClient.createTrip(trip);
      }
      
      final syncedTrip = trip.markAsSynced(serverTrip.id);
      await _localStorage.saveTrip(syncedTrip);
      
      return syncedTrip;
    } catch (e) {
      debugPrint('Failed to upload trip: $e');
      rethrow;
    }
  }

  /// Download a single trip from the server
  Future<Trip> downloadTrip(String serverId) async {
    try {
      final serverTrip = await _apiClient.getTrip(serverId);
      await _localStorage.saveTrip(serverTrip.markAsSynced(serverTrip.id));
      return serverTrip;
    } catch (e) {
      debugPrint('Failed to download trip: $e');
      rethrow;
    }
  }

  /// Delete trip from both local and server
  Future<void> deleteTrip(Trip trip) async {
    try {
      // Delete from server if it exists there
      if (trip.serverId != null) {
        await _apiClient.deleteTrip(trip.serverId!);
      }
    } catch (e) {
      debugPrint('Failed to delete trip from server: $e');
      // Continue to delete locally even if server delete fails
    }

    // Delete from local storage
    await _localStorage.deleteTrip(trip.id);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if sync is needed (has unsynced trips)
  Future<bool> needsSync() async {
    final unsyncedTrips = await _localStorage.getUnsyncedTrips();
    return unsyncedTrips.isNotEmpty;
  }

  /// Get count of unsynced trips
  Future<int> getUnsyncedCount() async {
    final unsyncedTrips = await _localStorage.getUnsyncedTrips();
    return unsyncedTrips.length;
  }

  /// Force re-download all trips from server
  Future<void> pullFromServer() async {
    try {
      final serverTrips = await _apiClient.getTrips();
      await _localStorage.saveTrips(serverTrips);
    } catch (e) {
      debugPrint('Failed to pull from server: $e');
      rethrow;
    }
  }

  /// Force upload all local trips to server
  Future<void> pushToServer() async {
    try {
      final localTrips = await _localStorage.getAllTrips();
      await _uploadTrips(localTrips);
    } catch (e) {
      debugPrint('Failed to push to server: $e');
      rethrow;
    }
  }

  /// Clear all listeners
  void dispose() {
    _statusListeners.clear();
    _resultListeners.clear();
  }
}

/// Internal class for merge results
class _MergeResult {
  final int downloaded;
  final int conflicts;

  _MergeResult({required this.downloaded, required this.conflicts});
}

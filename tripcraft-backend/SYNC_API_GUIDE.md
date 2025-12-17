# Sync API Guide

This guide covers the bidirectional synchronization feature of TripCraft, enabling offline-first functionality with automatic conflict resolution.

## Overview

The sync endpoint allows:
- **Offline-first operations**: Work without internet, sync later
- **Multi-device support**: Keep data consistent across devices
- **Conflict resolution**: Handle concurrent modifications
- **Batch operations**: Efficient sync of multiple entities
- **Incremental sync**: Only transfer changed data

## Endpoint

### POST /api/sync

Bidirectional synchronization with conflict resolution.

**Authentication:** Required (Bearer token)

**Request Body:**

```json
{
  "last_sync_at": "2024-01-15T10:30:00Z",
  "conflict_resolution": "newer_wins",
  "trips": [
    {
      "id": "uuid",
      "title": "Paris Adventure",
      "destination": "Paris, France",
      "start_date": "2024-06-15",
      "end_date": "2024-06-17",
      "budget": 2000.0,
      "preferences": {},
      "is_generated": true,
      "local_updated_at": "2024-01-15T11:00:00Z",
      "is_deleted": false
    }
  ],
  "days": [...],
  "activities": [...],
  "budget_items": [...],
  "notes": [...]
}
```

**Fields:**

- `last_sync_at` (string, optional): Last successful sync timestamp (ISO 8601)
  - Omit or null for first sync
  - Server returns changes since this time
  
- `conflict_resolution` (string): Strategy for conflicts
  - `newer_wins` (default): Most recent modification wins
  - `client_wins`: Client always overwrites server
  - `server_wins`: Server always takes precedence
  - `merge`: Intelligent merge (currently uses newer_wins)

- `trips`, `days`, `activities`, `budget_items`, `notes` (arrays): Entities to sync
  - Each entity has `id`, `local_updated_at`, `is_deleted`
  - Include all changed entities since last sync

**Entity Schemas:**

Trip:
```json
{
  "id": "uuid",
  "title": "string",
  "destination": "string",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "budget": 0.0,
  "preferences": {},
  "is_generated": false,
  "local_updated_at": "ISO timestamp",
  "is_deleted": false
}
```

Day:
```json
{
  "id": "uuid",
  "trip_id": "uuid",
  "day_number": 1,
  "date": "YYYY-MM-DD",
  "title": "string",
  "local_updated_at": "ISO timestamp",
  "is_deleted": false
}
```

Activity:
```json
{
  "id": "uuid",
  "day_id": "uuid",
  "time": "HH:MM AM/PM",
  "title": "string",
  "description": "string",
  "location": "string",
  "estimated_cost": 0.0,
  "notes": "string",
  "is_completed": false,
  "local_updated_at": "ISO timestamp",
  "is_deleted": false
}
```

Budget Item:
```json
{
  "id": "uuid",
  "trip_id": "uuid",
  "category": "string",
  "amount": 0.0,
  "note": "string",
  "local_updated_at": "ISO timestamp",
  "is_deleted": false
}
```

Note:
```json
{
  "id": "uuid",
  "trip_id": "uuid",
  "content": "string",
  "local_updated_at": "ISO timestamp",
  "is_deleted": false
}
```

**Success Response (200 OK):**

```json
{
  "sync_timestamp": "2024-01-15T11:05:00Z",
  "trips_uploaded": 2,
  "trips_downloaded": 1,
  "days_uploaded": 3,
  "days_downloaded": 2,
  "activities_uploaded": 10,
  "activities_downloaded": 5,
  "budget_items_uploaded": 2,
  "budget_items_downloaded": 0,
  "notes_uploaded": 1,
  "notes_downloaded": 0,
  "conflicts_resolved": 2,
  "conflicts": [
    {
      "entity_type": "trip",
      "entity_id": "uuid",
      "client_updated_at": "2024-01-15T10:45:00Z",
      "server_updated_at": "2024-01-15T10:50:00Z",
      "resolution": "server_wins"
    }
  ],
  "server_data": {
    "trips": [...],
    "days": [...],
    "activities": [...],
    "budget_items": [...],
    "notes": [...]
  }
}
```

**Response Fields:**

- `sync_timestamp`: Use this for next sync's `last_sync_at`
- `*_uploaded`: Count of entities uploaded to server
- `*_downloaded`: Count of entities downloaded from server
- `conflicts_resolved`: Number of conflicts encountered
- `conflicts`: Details of each conflict
- `server_data`: Entities to apply locally (changed since last_sync_at)

## How It Works

### Sync Flow

```
Client Side:
1. Collect local changes since last sync
2. Build sync request with all changes
3. Send to server

Server Side:
4. For each entity:
   - Check if exists
   - Compare timestamps
   - Apply conflict resolution
   - Update or create
5. Query entities changed since last_sync_at
6. Return server changes

Client Side:
7. Apply server changes locally
8. Resolve any remaining conflicts
9. Save new sync_timestamp
```

### Conflict Resolution Strategies

**newer_wins** (Recommended):
- Compares `local_updated_at` timestamps
- Most recent change wins
- Best for single-user, multi-device scenarios

**client_wins**:
- Client data always overwrites server
- Use when client is authoritative
- Good for force-push scenarios

**server_wins**:
- Server data always takes precedence
- Client changes ignored if conflict
- Use for server-authoritative data

**merge**:
- Attempts intelligent merge
- Currently uses newer_wins logic
- Future: field-level merging

### Deletion Handling

Mark entities as deleted instead of removing:
```json
{
  "id": "entity-uuid",
  "is_deleted": true,
  "local_updated_at": "2024-01-15T11:00:00Z"
}
```

This ensures deletions sync across devices.

## Usage Examples

### Python (requests)

```python
import requests
from datetime import datetime

url = "http://localhost:8000/api/sync"
headers = {
    "Authorization": "Bearer YOUR_JWT_TOKEN",
    "Content-Type": "application/json"
}

# Collect local changes
local_changes = {
    "last_sync_at": get_last_sync_timestamp(),  # From local storage
    "conflict_resolution": "newer_wins",
    "trips": get_modified_trips(),
    "days": get_modified_days(),
    "activities": get_modified_activities(),
    "budget_items": get_modified_budget_items(),
    "notes": get_modified_notes()
}

# Sync
response = requests.post(url, json=local_changes, headers=headers)
sync_result = response.json()

# Apply server changes
for trip in sync_result['server_data']['trips']:
    apply_trip_locally(trip)

for day in sync_result['server_data']['days']:
    apply_day_locally(day)

# Continue for all entity types...

# Save new sync timestamp
save_sync_timestamp(sync_result['sync_timestamp'])

print(f"Uploaded: {sync_result['trips_uploaded']} trips")
print(f"Downloaded: {sync_result['trips_downloaded']} trips")
print(f"Conflicts: {sync_result['conflicts_resolved']}")
```

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class SyncService {
  final Dio dio;
  final Box localBox;
  
  Future<void> sync() async {
    // Get last sync time
    final lastSync = localBox.get('last_sync_at');
    
    // Collect changes
    final changes = {
      'last_sync_at': lastSync,
      'conflict_resolution': 'newer_wins',
      'trips': _getModifiedTrips(),
      'days': _getModifiedDays(),
      'activities': _getModifiedActivities(),
      'budget_items': _getModifiedBudgetItems(),
      'notes': _getModifiedNotes(),
    };
    
    try {
      final response = await dio.post('/api/sync', data: changes);
      final result = response.data;
      
      // Apply server changes
      await _applyServerChanges(result['server_data']);
      
      // Save new sync timestamp
      await localBox.put('last_sync_at', result['sync_timestamp']);
      
      print('Sync complete!');
      print('Uploaded: ${result['trips_uploaded']} trips');
      print('Downloaded: ${result['trips_downloaded']} trips');
      
    } on DioException catch (e) {
      print('Sync failed: ${e.message}');
      // Handle error (retry later)
    }
  }
  
  List<Map<String, dynamic>> _getModifiedTrips() {
    // Query local Hive database for trips with is_synced = false
    // or local_updated_at > last_sync_at
    return [];  // Implementation
  }
  
  Future<void> _applyServerChanges(Map<String, dynamic> serverData) async {
    // Apply trips
    for (var trip in serverData['trips']) {
      await _applyTrip(trip);
    }
    
    // Apply days, activities, etc.
    // ...
  }
}
```

### cURL

```bash
# Initial sync (no last_sync_at)
curl -X POST http://localhost:8000/api/sync \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conflict_resolution": "newer_wins",
    "trips": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "New Trip",
        "destination": "Tokyo, Japan",
        "start_date": "2024-06-15",
        "end_date": "2024-06-20",
        "local_updated_at": "2024-01-15T11:00:00Z",
        "is_deleted": false
      }
    ],
    "days": [],
    "activities": [],
    "budget_items": [],
    "notes": []
  }'

# Subsequent sync with last_sync_at
curl -X POST http://localhost:8000/api/sync \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "last_sync_at": "2024-01-15T11:05:00Z",
    "conflict_resolution": "newer_wins",
    "trips": [],
    "days": [],
    "activities": [],
    "budget_items": [],
    "notes": []
  }'
```

## Best Practices

### 1. Track Local Changes

Maintain a "dirty" flag or timestamp:

```dart
class Trip {
  String id;
  String title;
  DateTime localUpdatedAt;
  bool isSynced;
  bool isDeleted;
  
  void markModified() {
    localUpdatedAt = DateTime.now();
    isSynced = false;
  }
}
```

### 2. Sync on App Launch

```dart
@override
void initState() {
  super.initState();
  _syncOnStartup();
}

Future<void> _syncOnStartup() async {
  if (await hasInternetConnection()) {
    await syncService.sync();
  }
}
```

### 3. Periodic Background Sync

```dart
Timer.periodic(Duration(minutes: 5), (timer) async {
  if (await hasInternetConnection()) {
    await syncService.sync();
  }
});
```

### 4. Sync Before Important Actions

```dart
Future<void> generateItinerary() async {
  // Sync first to avoid conflicts
  await syncService.sync();
  
  // Then generate
  final trip = await api.generateItinerary(params);
  
  // Sync result
  await syncService.sync();
}
```

### 5. Handle Sync Errors

```dart
try {
  await syncService.sync();
} catch (e) {
  if (e is NetworkException) {
    // Queue for retry
    await queueSyncForLater();
  } else if (e is ConflictException) {
    // Show conflict resolution UI
    await showConflictDialog();
  }
}
```

### 6. Batch Related Changes

```dart
// Don't sync after each change
trip.title = "New Title";  // Mark dirty
trip.budget = 2000.0;      // Mark dirty
day.title = "Updated";     // Mark dirty

// Sync once at the end
await syncService.sync();  // Batch sync all changes
```

### 7. Use Optimistic UI Updates

```dart
// Update UI immediately
setState(() {
  trip.title = newTitle;
});

// Sync in background
syncService.sync().catchError((e) {
  // Revert if sync fails
  setState(() {
    trip.title = oldTitle;
  });
  showError(e);
});
```

### 8. Validate Before Sync

```dart
List<Map> _getModifiedTrips() {
  return localTrips
    .where((t) => !t.isSynced)
    .where((t) => _isValidTrip(t))  // Validate
    .map((t) => t.toJson())
    .toList();
}
```

## Common Scenarios

### First Sync (New Device)

```json
{
  "last_sync_at": null,
  "trips": [],
  "days": [],
  "activities": [],
  "budget_items": [],
  "notes": []
}
```

Server returns all user data.

### Incremental Sync

```json
{
  "last_sync_at": "2024-01-15T11:05:00Z",
  "trips": [/* Only modified trips */],
  "days": [/* Only modified days */],
  ...
}
```

Server returns only changes since timestamp.

### Conflict Scenario

Device A and Device B both modify the same trip offline:

```
Device A: trip.title = "Paris Trip"  @ 11:00
Device B: trip.title = "France Trip" @ 11:05

Device A syncs first:
- Server has "Paris Trip" @ 11:00

Device B syncs:
- Server has "Paris Trip" @ 11:00
- Client has "France Trip" @ 11:05
- Resolution: newer_wins
- Result: "France Trip" wins
```

### Deletion Sync

```json
{
  "trips": [
    {
      "id": "trip-to-delete",
      "is_deleted": true,
      "local_updated_at": "2024-01-15T11:10:00Z"
    }
  ]
}
```

Server deletes the trip and syncs deletion to other devices.

## Conflict Resolution Examples

### Example 1: newer_wins (Default)

```
Client: title="Updated Trip" @ 11:05
Server: title="Old Trip" @ 11:00
Result: Client wins (newer timestamp)
```

### Example 2: client_wins

```
Client: title="Force Update" @ 10:00
Server: title="Current" @ 11:00
Result: Client wins (regardless of timestamp)
```

### Example 3: server_wins

```
Client: title="Try Update" @ 12:00
Server: title="Server Master" @ 11:00
Result: Server wins (client ignored)
```

## Performance

- **Payload Size**: Depends on changes (typically < 100KB)
- **Sync Time**: 200-500ms for typical batch
- **Frequency**: Every 5 minutes or on app resume
- **Bandwidth**: ~50KB average per sync

## Limitations

1. **No Real-time**: Changes not pushed instantly
2. **Conflict Complexity**: Only timestamp-based resolution
3. **Large Batches**: May timeout (keep under 1000 entities)
4. **Network Required**: Cannot sync without internet
5. **User Isolation**: Cannot sync across different users

## Troubleshooting

### Sync keeps failing

- Check authentication token validity
- Verify internet connection
- Reduce batch size
- Check for malformed UUIDs

### Conflicts not resolving

- Ensure local_updated_at is ISO format
- Verify timestamps are UTC
- Check conflict_resolution strategy

### Data not syncing

- Confirm is_synced flag is false
- Verify entity relationships (trip_id, day_id)
- Check user ownership

### Duplicate data

- Use consistent UUIDs (don't generate new on sync)
- Check is_synced flag updates
- Verify last_sync_at is saved

## Testing

Test sync scenarios:

```python
# Test new entity sync
def test_sync_new_trip():
    response = client.post("/api/sync", json={
        "trips": [{"id": new_uuid(), ...}]
    })
    assert response.json()["trips_uploaded"] == 1

# Test conflict resolution
def test_sync_conflict():
    # Create server trip
    # Sync older client version
    # Assert server wins
```

## Next Steps

- **Task BE-7**: PDF Export for synced trips

## Support

For sync issues:
- Enable debug logging
- Check server logs for errors
- Verify timestamp formats
- Test with small batches first
- Use Swagger UI to test manually

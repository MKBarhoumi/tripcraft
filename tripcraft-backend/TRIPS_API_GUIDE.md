# TripCraft API - Trip CRUD Guide

## Overview

The Trip CRUD endpoints allow authenticated users to manage their travel trips with full support for nested data including days, activities, budget items, and notes.

## Authentication Required

All trip endpoints require JWT authentication. Include the Bearer token in the Authorization header:

```
Authorization: Bearer <your-access-token>
```

---

## Endpoints

### 1. Create Trip

**Endpoint:** `POST /api/trips`

**Request:**
```json
{
  "title": "Paris Adventure",
  "destination": "Paris, France",
  "start_date": "2024-06-01",
  "end_date": "2024-06-07",
  "budget": 2000.0,
  "budget_tier": "moderate",
  "travel_style": "cultural",
  "interests": ["museums", "food", "history"],
  "special_requirements": "Vegetarian meals"
}
```

**Required Fields:**
- `title` (string)
- `destination` (string)
- `start_date` (string, YYYY-MM-DD format)
- `end_date` (string, YYYY-MM-DD format)

**Optional Fields:**
- `budget` (number)
- `budget_tier` (string: "budget", "moderate", "luxury")
- `travel_style` (string: "relaxation", "adventure", "cultural", "foodie")
- `interests` (array of strings)
- `special_requirements` (string)

**Response (201 Created):**
```json
{
  "id": "uuid",
  "title": "Paris Adventure",
  "destination": "Paris, France",
  "start_date": "2024-06-01",
  "end_date": "2024-06-07",
  "budget": 2000.0,
  "budget_tier": "moderate",
  "travel_style": "cultural",
  "interests": ["museums", "food", "history"],
  "special_requirements": "Vegetarian meals",
  "is_generated": false,
  "created_at": "2024-01-01T12:00:00",
  "updated_at": "2024-01-01T12:00:00",
  "days": [],
  "budget_items": [],
  "notes": [],
  "server_id": null,
  "is_synced": false,
  "local_updated_at": "2024-01-01T12:00:00"
}
```

---

### 2. List Trips

**Endpoint:** `GET /api/trips`

**Query Parameters:**
- `search` (optional): Search in title and destination
- `destination` (optional): Filter by destination
- `is_generated` (optional): Filter by generation status (true/false)
- `skip` (optional): Pagination offset (default: 0)
- `limit` (optional): Max results (default: 100, max: 100)

**Examples:**

```bash
# Get all trips
GET /api/trips

# Search for "Paris"
GET /api/trips?search=Paris

# Filter by destination
GET /api/trips?destination=France

# Pagination
GET /api/trips?skip=0&limit=10

# AI-generated trips only
GET /api/trips?is_generated=true
```

**Response (200 OK):**
```json
[
  {
    "id": "uuid",
    "title": "Paris Adventure",
    "destination": "Paris, France",
    "start_date": "2024-06-01",
    "end_date": "2024-06-07",
    "budget": 2000.0,
    "is_generated": false,
    "created_at": "2024-01-01T12:00:00",
    "days": [...],
    "budget_items": [...],
    "notes": [...]
  }
]
```

---

### 3. Get Single Trip

**Endpoint:** `GET /api/trips/{trip_id}`

**Path Parameters:**
- `trip_id` (UUID): Trip identifier

**Response (200 OK):**
```json
{
  "id": "uuid",
  "title": "Paris Adventure",
  "destination": "Paris, France",
  "start_date": "2024-06-01",
  "end_date": "2024-06-07",
  "budget": 2000.0,
  "budget_tier": "moderate",
  "travel_style": "cultural",
  "interests": ["museums", "food", "history"],
  "special_requirements": "Vegetarian meals",
  "is_generated": false,
  "created_at": "2024-01-01T12:00:00",
  "updated_at": "2024-01-01T12:00:00",
  "days": [
    {
      "id": "uuid",
      "day_number": 1,
      "date": "2024-06-01",
      "title": "Arrival Day",
      "activities": [
        {
          "id": "uuid",
          "time": "09:00 AM",
          "title": "Arrive at Charles de Gaulle",
          "description": "Land at CDG airport",
          "location": "Paris CDG Airport",
          "estimated_cost": 0.0,
          "notes": null,
          "is_completed": false,
          "server_id": null,
          "is_synced": false,
          "local_updated_at": "2024-01-01T12:00:00"
        }
      ],
      "server_id": null,
      "is_synced": false,
      "local_updated_at": "2024-01-01T12:00:00"
    }
  ],
  "budget_items": [
    {
      "id": "uuid",
      "category": "accommodation",
      "amount": 800.0,
      "note": "Hotel booking",
      "server_id": null,
      "is_synced": false,
      "local_updated_at": "2024-01-01T12:00:00"
    }
  ],
  "notes": [
    {
      "id": "uuid",
      "content": "Remember to book Eiffel Tower tickets in advance!",
      "created_at": "2024-01-01T12:00:00",
      "server_id": null,
      "is_synced": false,
      "local_updated_at": "2024-01-01T12:00:00"
    }
  ],
  "server_id": null,
  "is_synced": false,
  "local_updated_at": "2024-01-01T12:00:00"
}
```

**Errors:**
- `404 Not Found`: Trip doesn't exist or doesn't belong to user

---

### 4. Update Trip

**Endpoint:** `PUT /api/trips/{trip_id}`

**Path Parameters:**
- `trip_id` (UUID): Trip identifier

**Request (all fields optional):**
```json
{
  "title": "Updated Paris Adventure",
  "budget": 2500.0,
  "travel_style": "luxury"
}
```

**Response (200 OK):**
Returns full updated trip with nested data.

**Errors:**
- `404 Not Found`: Trip doesn't exist or doesn't belong to user

---

### 5. Delete Trip

**Endpoint:** `DELETE /api/trips/{trip_id}`

**Path Parameters:**
- `trip_id` (UUID): Trip identifier

**Response:** `204 No Content`

**Errors:**
- `404 Not Found`: Trip doesn't exist or doesn't belong to user

**Note:** Deleting a trip will CASCADE delete all associated:
- Days
- Activities
- Budget Items
- Notes

---

## Security & Isolation

- **User Isolation**: Users can only access their own trips
- **JWT Required**: All endpoints require valid authentication token
- **Automatic Ownership**: Trips are automatically associated with the authenticated user

---

## Code Examples

### Python (requests)

```python
import requests

# Login first
login_response = requests.post(
    "http://localhost:8000/api/auth/login",
    json={"email": "user@example.com", "password": "password123"}
)
token = login_response.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# Create trip
trip_response = requests.post(
    "http://localhost:8000/api/trips",
    headers=headers,
    json={
        "title": "Weekend in Rome",
        "destination": "Rome, Italy",
        "start_date": "2024-07-15",
        "end_date": "2024-07-17",
        "budget": 1500.0
    }
)
trip_id = trip_response.json()["id"]

# List trips
trips = requests.get(
    "http://localhost:8000/api/trips?search=Rome",
    headers=headers
).json()

# Get specific trip
trip = requests.get(
    f"http://localhost:8000/api/trips/{trip_id}",
    headers=headers
).json()

# Update trip
requests.put(
    f"http://localhost:8000/api/trips/{trip_id}",
    headers=headers,
    json={"budget": 1800.0}
)

# Delete trip
requests.delete(
    f"http://localhost:8000/api/trips/{trip_id}",
    headers=headers
)
```

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';

final dio = Dio();
final token = 'your-access-token';
dio.options.headers['Authorization'] = 'Bearer $token';

// Create trip
final createResponse = await dio.post(
  'http://localhost:8000/api/trips',
  data: {
    'title': 'Weekend in Rome',
    'destination': 'Rome, Italy',
    'start_date': '2024-07-15',
    'end_date': '2024-07-17',
    'budget': 1500.0,
  },
);
final tripId = createResponse.data['id'];

// List trips with search
final listResponse = await dio.get(
  'http://localhost:8000/api/trips',
  queryParameters: {'search': 'Rome'},
);
final trips = listResponse.data;

// Get specific trip
final tripResponse = await dio.get(
  'http://localhost:8000/api/trips/$tripId',
);
final trip = tripResponse.data;

// Update trip
await dio.put(
  'http://localhost:8000/api/trips/$tripId',
  data: {'budget': 1800.0},
);

// Delete trip
await dio.delete(
  'http://localhost:8000/api/trips/$tripId',
);
```

### JavaScript (fetch)

```javascript
const token = 'your-access-token';
const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${token}`
};

// Create trip
const createResponse = await fetch('http://localhost:8000/api/trips', {
  method: 'POST',
  headers,
  body: JSON.stringify({
    title: 'Weekend in Rome',
    destination: 'Rome, Italy',
    start_date: '2024-07-15',
    end_date: '2024-07-17',
    budget: 1500.0
  })
});
const trip = await createResponse.json();

// List trips
const listResponse = await fetch(
  'http://localhost:8000/api/trips?search=Rome',
  { headers }
);
const trips = await listResponse.json();

// Get specific trip
const tripResponse = await fetch(
  `http://localhost:8000/api/trips/${trip.id}`,
  { headers }
);
const fullTrip = await tripResponse.json();

// Update trip
await fetch(`http://localhost:8000/api/trips/${trip.id}`, {
  method: 'PUT',
  headers,
  body: JSON.stringify({ budget: 1800.0 })
});

// Delete trip
await fetch(`http://localhost:8000/api/trips/${trip.id}`, {
  method: 'DELETE',
  headers
});
```

---

## Testing with Swagger UI

1. Open http://localhost:8000/docs
2. Authenticate:
   - Login via `/api/auth/login`
   - Copy the `access_token`
   - Click "Authorize" button
   - Enter: `Bearer <token>`
3. Test trip endpoints:
   - Create a trip with POST `/api/trips`
   - List your trips with GET `/api/trips`
   - Try search/filter parameters
   - Get single trip details
   - Update a trip
   - Delete a trip

---

## Best Practices

1. **Always authenticate** before accessing trip endpoints
2. **Use pagination** for large trip lists
3. **Search/filter** to improve performance
4. **Handle 404 errors** gracefully
5. **Validate dates** on client side before submission
6. **Store trip IDs** for future operations
7. **Check is_synced** field for offline sync status

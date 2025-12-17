# Chat Refinement API Guide

This guide covers the chat-based itinerary refinement feature of TripCraft, allowing users to iteratively improve their AI-generated trips through natural conversation.

## Overview

The chat refinement endpoint enables users to:
- Modify existing itineraries with natural language
- Add, remove, or change activities
- Adjust pacing and budget
- Get contextual suggestions
- Refine multiple aspects in one request

## Endpoints

### POST /api/chat

Refine an existing itinerary using conversational AI.

**Authentication:** Required (Bearer token)

**Request Body:**

```json
{
  "trip_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Add a visit to the Eiffel Tower on Day 2"
}
```

**Required Fields:**
- `trip_id` (string, UUID): ID of the trip to refine
- `message` (string, 1-2000 chars): Natural language refinement request

**Example Messages:**

Simple additions:
- "Add a visit to the Eiffel Tower on Day 2"
- "Include a cooking class somewhere in the trip"

Replacements:
- "Replace the morning activity on Day 1 with something cultural"
- "Change Day 3 to focus on outdoor activities instead of museums"

Style changes:
- "Make Day 2 more budget-friendly"
- "Add more food experiences throughout the trip"
- "Make the itinerary more relaxed with fewer activities per day"

Removals:
- "Remove the expensive activities from Day 3"
- "Take out the museum visit on Day 1"

Complex multi-part requests:
- "I want to make several changes: First, add the Eiffel Tower to Day 1. Second, replace the Louvre with a food tour on Day 2. Third, add more budget-friendly options throughout."

**Success Response (200 OK):**

```json
{
  "trip": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "title": "Paris Adventure",
    "destination": "Paris, France",
    "start_date": "2024-06-15",
    "end_date": "2024-06-17",
    "budget": 2000.0,
    "is_generated": true,
    "days": [
      {
        "day_number": 1,
        "date": "2024-06-15",
        "title": "Day 1: Arrival and Exploration",
        "activities": [
          {
            "time": "09:00 AM",
            "title": "Arrive in Paris",
            "description": "Land at Charles de Gaulle Airport",
            "location": "CDG Airport",
            "estimated_cost": 0.0,
            "is_completed": false
          },
          {
            "time": "05:00 PM",
            "title": "Visit Eiffel Tower",
            "description": "See iconic landmark at sunset",
            "location": "Eiffel Tower",
            "estimated_cost": 30.0,
            "notes": "Book tickets in advance",
            "is_completed": false
          }
        ]
      }
    ],
    "budget_items": [],
    "notes": []
  },
  "message": "Itinerary refined based on your request",
  "ai_response": "I've updated your Paris, France itinerary based on: 'Add a visit to the Eiffel Tower on Day 2'"
}
```

**Error Responses:**

400 Bad Request - Invalid request or AI error:
```json
{
  "detail": "Cannot refine trip with no days. Generate an itinerary first."
}
```

401 Unauthorized:
```json
{
  "detail": "Not authenticated"
}
```

403 Forbidden - Trip doesn't belong to user:
```json
{
  "detail": "Not authorized to modify this trip"
}
```

404 Not Found:
```json
{
  "detail": "Trip not found"
}
```

422 Validation Error:
```json
{
  "detail": [
    {
      "loc": ["body", "message"],
      "msg": "ensure this value has at least 1 characters",
      "type": "value_error.any_str.min_length"
    }
  ]
}
```

### GET /api/chat/suggestions/{trip_id}

Get AI-suggested refinement ideas for a trip.

**Authentication:** Required (Bearer token)

**Path Parameters:**
- `trip_id` (UUID): Trip identifier

**Success Response (200 OK):**

```json
{
  "trip_id": "123e4567-e89b-12d3-a456-426614174000",
  "destination": "Paris, France",
  "suggestions": [
    "Include a local cooking class or cultural workshop",
    "Add sunset or sunrise viewing spots for memorable moments",
    "Include time for spontaneous exploration and local discoveries",
    "Consider the best photo opportunities for each location",
    "Add backup indoor activities in case of bad weather",
    "Find free walking tours in your destination",
    "Add more street food experiences for authentic local cuisine",
    "Consider adding a rest day or half-day in the middle of the trip"
  ]
}
```

**Contextual Suggestions:**

The endpoint returns tailored suggestions based on:
- **Budget Tier**: 
  - Budget: Free tours, street food
  - Luxury: Spa days, private tours
- **Trip Duration**: 
  - 5+ days: Suggest rest days
  - 7+ days: Suggest day trips
- **Travel Style**:
  - Adventure: Outdoor activities
  - Cultural: Cooking classes, workshops
  - Foodie: Market tours, wine tasting

## How It Works

### Refinement Flow

```
1. User Request
   ↓
2. Validate Authentication & Ownership
   ↓
3. Load Current Itinerary
   - Fetch trip, days, activities
   - Serialize for AI context
   ↓
4. Build Trip Context
   - Destination, dates, budget
   - Travel style, preferences
   - Current itinerary structure
   ↓
5. Call AI Service
   - Pass current itinerary
   - Pass refinement request
   - Pass trip context
   ↓
6. Parse AI Response
   - Validate refined structure
   - Check consistency
   ↓
7. Update Database
   - Delete old days/activities
   - Create new refined structure
   - Preserve trip metadata
   ↓
8. Return Refined Trip
   - Full nested structure
   - Success message
   - AI explanation
```

## Usage Examples

### Python (requests)

```python
import requests

url = "http://localhost:8000/api/chat"
headers = {
    "Authorization": "Bearer YOUR_JWT_TOKEN",
    "Content-Type": "application/json"
}

# Simple refinement
payload = {
    "trip_id": "trip-uuid-here",
    "message": "Add a sunset cruise on Day 3"
}

response = requests.post(url, json=payload, headers=headers)
refined_trip = response.json()

print(f"Refined: {refined_trip['message']}")
print(f"Days: {len(refined_trip['trip']['days'])}")

# Get suggestions
suggestions_url = f"http://localhost:8000/api/chat/suggestions/{trip_id}"
suggestions_response = requests.get(suggestions_url, headers=headers)
suggestions = suggestions_response.json()

print("Suggestions:")
for s in suggestions['suggestions']:
    print(f"  - {s}")
```

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://localhost:8000',
  headers: {'Authorization': 'Bearer $token'},
));

// Refine itinerary
Future<void> refineTrip(String tripId, String message) async {
  try {
    final response = await dio.post(
      '/api/chat',
      data: {
        'trip_id': tripId,
        'message': message,
      },
    );
    
    final trip = response.data['trip'];
    final aiResponse = response.data['ai_response'];
    
    print('Refined: $aiResponse');
    print('Total days: ${trip['days'].length}');
  } on DioException catch (e) {
    if (e.response?.statusCode == 400) {
      print('Error: ${e.response?.data['detail']}');
    }
  }
}

// Get suggestions
Future<List<String>> getSuggestions(String tripId) async {
  final response = await dio.get('/api/chat/suggestions/$tripId');
  return List<String>.from(response.data['suggestions']);
}
```

### cURL

```bash
# Refine itinerary
curl -X POST http://localhost:8000/api/chat \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_id": "123e4567-e89b-12d3-a456-426614174000",
    "message": "Make Day 2 focus more on local food experiences"
  }'

# Get suggestions
curl -X GET http://localhost:8000/api/chat/suggestions/123e4567-e89b-12d3-a456-426614174000 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### JavaScript (fetch)

```javascript
const refineTrip = async (tripId, message) => {
  const response = await fetch('http://localhost:8000/api/chat', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      trip_id: tripId,
      message: message,
    }),
  });
  
  const data = await response.json();
  console.log('Refined:', data.ai_response);
  return data.trip;
};

const getSuggestions = async (tripId) => {
  const response = await fetch(
    `http://localhost:8000/api/chat/suggestions/${tripId}`,
    {
      headers: { 'Authorization': `Bearer ${token}` },
    }
  );
  
  const data = await response.json();
  return data.suggestions;
};
```

## Best Practices

### 1. Be Specific in Requests

Good:
```json
{"message": "Add a visit to the Colosseum on Day 2 around 2 PM"}
```

Less effective:
```json
{"message": "Add something to Day 2"}
```

### 2. Reference Days and Times

```json
{"message": "Replace the morning activity on Day 1 with a museum visit"}
{"message": "Move the dinner reservation from Day 2 to Day 3"}
{"message": "Add a sunset activity on the last day"}
```

### 3. Combine Related Changes

```json
{
  "message": "I want a more relaxed pace: reduce activities on Day 2 to just 3-4, add a free afternoon on Day 3, and include more breaks throughout"
}
```

### 4. Use Suggestions for Ideas

```javascript
// Get suggestions first
const suggestions = await getSuggestions(tripId);
console.log(suggestions);
// ["Add more local food experiences", ...]

// Use a suggestion
await refineTrip(tripId, "Add more local food experiences");
```

### 5. Iterate Gradually

```javascript
// Refinement 1
await refineTrip(tripId, "Add Eiffel Tower to Day 2");

// Check result, then refinement 2
await refineTrip(tripId, "Make the Eiffel Tower visit at sunset");

// Further refinement
await refineTrip(tripId, "Add a dinner cruise after the Eiffel Tower");
```

### 6. Handle Errors Gracefully

```python
try:
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    trip = response.json()['trip']
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 400:
        print(f"Invalid request: {e.response.json()['detail']}")
    elif e.response.status_code == 403:
        print("Cannot modify this trip")
    elif e.response.status_code == 404:
        print("Trip not found")
```

## Common Use Cases

### Adding Activities

```json
{"message": "Add a Seine river cruise on Day 2"}
{"message": "Include a visit to Versailles"}
{"message": "Add a wine tasting experience somewhere"}
```

### Replacing Activities

```json
{"message": "Replace the Louvre visit with Musée d'Orsay"}
{"message": "Change the lunch spot on Day 1 to a local market"}
{"message": "Swap Day 2 and Day 3 activities"}
```

### Adjusting Pacing

```json
{"message": "Make the itinerary more relaxed with fewer activities"}
{"message": "Add a rest afternoon on Day 3"}
{"message": "Space out the activities more throughout each day"}
```

### Budget Adjustments

```json
{"message": "Replace expensive activities with free or budget options"}
{"message": "Add more luxury experiences"}
{"message": "Find budget-friendly alternatives for Day 2"}
```

### Theme Changes

```json
{"message": "Make Day 2 focus more on art and museums"}
{"message": "Add more outdoor and adventure activities"}
{"message": "Include more authentic local food experiences"}
```

## Performance

- **Refinement Time**: 5-10 seconds (varies by complexity)
- **Token Usage**: ~1500-2500 tokens per request
- **Database Operations**: ~20-60 operations (DELETE old + INSERT new)

## Limitations

1. **Existing Trip Required**: Can only refine trips with existing days
2. **Context Limitations**: AI may not remember previous refinements in separate requests
3. **Structure Preservation**: Major date/duration changes should use trip update endpoint
4. **Language**: Currently supports English messages only
5. **Real-time Data**: No live availability or booking

## Troubleshooting

### "Cannot refine trip with no days"
- Trip must have at least one day with activities
- Generate an itinerary first using POST /api/generate

### "Trip not found"
- Verify trip_id is correct UUID format
- Check trip exists and belongs to your account

### "Not authorized to modify this trip"
- Trip belongs to a different user
- Verify you're using the correct authentication token

### Refinement doesn't match request
- Be more specific in your message
- Reference specific days, times, or activities
- Try breaking complex requests into smaller steps

### Changes seem minor
- AI may interpret requests conservatively
- Try rephrasing or adding more context
- Use multiple refinement requests for major changes

## Testing in Swagger UI

1. Navigate to `http://localhost:8000/docs`
2. Expand `POST /api/chat`
3. Click "Try it out"
4. Enter authentication token
5. Fill in request body with trip_id and message
6. Click "Execute"
7. View refined itinerary in response

## Integration Tips

### Frontend Flow

```dart
// 1. Generate initial trip
final trip = await generateTrip(params);

// 2. Show trip to user
displayTrip(trip);

// 3. Get suggestions
final suggestions = await getSuggestions(trip.id);
showSuggestions(suggestions);

// 4. User selects suggestion or enters custom message
final message = userInput;

// 5. Refine trip
final refinedTrip = await refineTrip(trip.id, message);

// 6. Update UI with refined trip
displayTrip(refinedTrip);
```

### Chat Interface

```dart
class ChatRefinementScreen extends StatefulWidget {
  final Trip trip;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show current trip
        TripPreview(trip: trip),
        
        // Chat interface
        ChatMessages(messages: chatHistory),
        
        // Input
        TextField(
          onSubmitted: (message) async {
            final refined = await refineTrip(trip.id, message);
            setState(() {
              chatHistory.add({
                'user': message,
                'ai': refined.aiResponse,
              });
              currentTrip = refined.trip;
            });
          },
        ),
        
        // Quick suggestions
        SuggestionChips(
          suggestions: suggestions,
          onTap: (suggestion) => sendMessage(suggestion),
        ),
      ],
    );
  }
}
```

## Next Steps

- **Task BE-6**: Sync refined itineraries across devices
- **Task BE-7**: Export refined trips to PDF

## Support

For issues:
- Verify trip exists and has days/activities
- Check message length (1-2000 characters)
- Ensure valid authentication
- Review FastAPI logs for AI service errors
- Try simpler refinement requests first

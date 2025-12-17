# AI Itinerary Generation API Guide

This guide covers the AI-powered itinerary generation feature of TripCraft, which uses Groq's Mixtral model to create personalized travel itineraries.

## Overview

The generation endpoint allows users to create complete travel itineraries with:
- Day-by-day planning
- 4-6 activities per day with times
- Specific locations and descriptions
- Estimated costs for budgeting
- Personalization based on preferences

## Endpoint

### POST /api/generate

Generate an AI-powered travel itinerary based on user preferences.

**Authentication:** Required (Bearer token)

**Request Body:**

```json
{
  "destination": "Tokyo, Japan",
  "start_date": "2024-06-15",
  "end_date": "2024-06-20",
  "budget": 3000.0,
  "budget_tier": "moderate",
  "travel_style": "cultural",
  "interests": ["anime", "food", "temples"],
  "special_requirements": "Vegetarian meals preferred",
  "title": "Amazing Tokyo Adventure"
}
```

**Required Fields:**
- `destination` (string, 1-200 chars): Travel destination
- `start_date` (string, YYYY-MM-DD): Trip start date
- `end_date` (string, YYYY-MM-DD): Trip end date (max 14 days from start)

**Optional Fields:**
- `budget` (float, >= 0): Total budget in USD
- `budget_tier` (string): Budget category
  - `budget`: Cost-conscious travel
  - `moderate`: Balanced spending
  - `luxury`: Premium experiences
- `travel_style` (string): Travel preference
  - `relaxation`: Laid-back, slow-paced
  - `adventure`: Active, outdoor activities
  - `cultural`: Museums, history, local culture
  - `foodie`: Culinary experiences, restaurants
  - `mixed`: Balanced mix of activities
- `interests` (array, max 10): List of interest keywords
  - Examples: "art", "food", "history", "nature", "shopping", "nightlife"
- `special_requirements` (string, max 1000 chars): Special needs or preferences
  - Examples: "Wheelchair accessible", "No seafood", "Child-friendly"
- `title` (string, max 200 chars): Custom trip title (auto-generated if omitted)

**Success Response (201 Created):**

```json
{
  "trip": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "user-uuid",
    "title": "Amazing Tokyo Adventure",
    "destination": "Tokyo, Japan",
    "start_date": "2024-06-15",
    "end_date": "2024-06-20",
    "budget": 3000.0,
    "preferences": {
      "budget_tier": "moderate",
      "travel_style": "cultural",
      "interests": ["anime", "food", "temples"],
      "special_requirements": "Vegetarian meals preferred"
    },
    "is_generated": true,
    "days": [
      {
        "id": "day-uuid",
        "trip_id": "trip-uuid",
        "day_number": 1,
        "date": "2024-06-15",
        "title": "Day 1: Arrival in Tokyo",
        "activities": [
          {
            "id": "activity-uuid",
            "day_id": "day-uuid",
            "time": "09:00 AM",
            "title": "Arrive at Narita Airport",
            "description": "Land at Narita International Airport and clear customs",
            "location": "Narita International Airport",
            "estimated_cost": 0.0,
            "notes": "Exchange currency at airport",
            "is_completed": false
          },
          {
            "id": "activity-uuid-2",
            "day_id": "day-uuid",
            "time": "11:30 AM",
            "title": "Transfer to Hotel",
            "description": "Take Narita Express train to central Tokyo",
            "location": "Tokyo Station",
            "estimated_cost": 35.0,
            "notes": "Buy JR Pass if planning multiple train trips",
            "is_completed": false
          }
          // ... more activities
        ]
      }
      // ... more days
    ],
    "budget_items": [],
    "notes": [],
    "created_at": "2024-01-15T10:30:00Z"
  },
  "message": "Generated 6-day itinerary for Tokyo, Japan"
}
```

**Error Responses:**

400 Bad Request - Invalid request data:
```json
{
  "detail": "End date must be after start date"
}
```

401 Unauthorized - Missing or invalid token:
```json
{
  "detail": "Not authenticated"
}
```

422 Validation Error - Invalid field format:
```json
{
  "detail": [
    {
      "loc": ["body", "budget_tier"],
      "msg": "string does not match regex",
      "type": "value_error.str.regex"
    }
  ]
}
```

500 Internal Server Error - AI service failure:
```json
{
  "detail": "Failed to generate itinerary: API error"
}
```

## How It Works

1. **Validation**: System validates dates, duration (max 14 days), and preferences
2. **Prompt Construction**: Builds detailed prompt with all trip parameters
3. **AI Generation**: Calls Groq API (Mixtral-8x7b-32768 model) to generate itinerary
4. **Response Parsing**: Extracts and validates JSON structure from AI response
5. **Database Creation**: Creates Trip, Day, and Activity records
6. **Return Data**: Returns complete nested trip structure

## AI Model

- **Provider**: Groq
- **Model**: mixtral-8x7b-32768
- **Temperature**: 0.7 (balanced creativity and consistency)
- **Max Tokens**: 4096 (sufficient for detailed itineraries)

## Usage Examples

### Python (requests)

```python
import requests

url = "http://localhost:8000/api/generate"
headers = {
    "Authorization": "Bearer YOUR_JWT_TOKEN",
    "Content-Type": "application/json"
}

payload = {
    "destination": "Barcelona, Spain",
    "start_date": "2024-07-01",
    "end_date": "2024-07-05",
    "budget": 2500.0,
    "budget_tier": "moderate",
    "travel_style": "cultural",
    "interests": ["architecture", "food", "art"],
    "title": "Barcelona Cultural Tour"
}

response = requests.post(url, json=payload, headers=headers)
trip = response.json()

print(f"Generated {len(trip['trip']['days'])} days")
for day in trip['trip']['days']:
    print(f"  {day['title']}: {len(day['activities'])} activities")
```

### Flutter (Dio)

```dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'http://localhost:8000',
  headers: {'Authorization': 'Bearer $token'},
));

try {
  final response = await dio.post(
    '/api/generate',
    data: {
      'destination': 'Paris, France',
      'start_date': '2024-08-10',
      'end_date': '2024-08-15',
      'budget': 3500.0,
      'budget_tier': 'luxury',
      'travel_style': 'foodie',
      'interests': ['wine', 'pastries', 'fine dining'],
    },
  );
  
  final trip = response.data['trip'];
  print('Created trip: ${trip['title']}');
  print('Days: ${trip['days'].length}');
} on DioException catch (e) {
  print('Error: ${e.response?.data['detail']}');
}
```

### cURL

```bash
curl -X POST http://localhost:8000/api/generate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "destination": "New York City, USA",
    "start_date": "2024-09-01",
    "end_date": "2024-09-04",
    "budget": 2000.0,
    "budget_tier": "moderate",
    "travel_style": "mixed",
    "interests": ["broadway", "museums", "food"],
    "title": "NYC Long Weekend"
  }'
```

### JavaScript (fetch)

```javascript
const generateTrip = async () => {
  const response = await fetch('http://localhost:8000/api/generate', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      destination: 'Rome, Italy',
      start_date: '2024-10-15',
      end_date: '2024-10-20',
      budget_tier: 'moderate',
      travel_style: 'cultural',
      interests: ['history', 'art', 'cuisine'],
    }),
  });
  
  const data = await response.json();
  console.log('Trip:', data.trip);
  console.log('Days:', data.trip.days.length);
};
```

## Best Practices

### 1. Provide Detailed Preferences

More context = better itineraries:

```json
{
  "destination": "Kyoto, Japan",
  "start_date": "2024-11-01",
  "end_date": "2024-11-05",
  "budget": 2000.0,
  "budget_tier": "moderate",
  "travel_style": "cultural",
  "interests": [
    "zen gardens",
    "traditional tea ceremony",
    "temples",
    "bamboo forests"
  ],
  "special_requirements": "Early riser, prefer morning activities. No seafood due to allergy."
}
```

### 2. Choose Appropriate Budget Tier

- **Budget**: Hostels, street food, free attractions, public transport
- **Moderate**: 3-star hotels, mix of restaurants, popular attractions, some taxis
- **Luxury**: 4-5 star hotels, fine dining, private tours, premium experiences

### 3. Match Travel Style to Destination

- **Relaxation**: Beach destinations, spa resorts, peaceful areas
- **Adventure**: Mountains, outdoor activities, hiking, water sports
- **Cultural**: Cities with museums, historical sites, local traditions
- **Foodie**: Culinary destinations, food tours, cooking classes
- **Mixed**: Versatile destinations with variety

### 4. Limit Trip Duration

- Maximum 14 days per generation
- For longer trips, generate multiple segments
- Break complex trips into regions

### 5. Handle Generation Errors

```python
try:
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    trip = response.json()['trip']
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 400:
        print(f"Invalid request: {e.response.json()['detail']}")
    elif e.response.status_code == 500:
        print("AI service unavailable, please try again")
except Exception as e:
    print(f"Unexpected error: {e}")
```

## Customizing Generated Itineraries

After generation, you can:

1. **Edit Activities**: Use PUT /api/trips/{id} to modify trip details
2. **Add/Remove Activities**: Manually create or delete activities
3. **Refine with AI**: Use the chat refinement endpoint (coming in BE-5)
4. **Mark Completed**: Update activities as you complete them

## Performance

- **Generation Time**: 5-15 seconds (depends on trip complexity)
- **Rate Limits**: Follow Groq API rate limits (configured in backend)
- **Caching**: Consider caching common destinations/preferences

## Limitations

1. **Maximum Duration**: 14 days per generation
2. **Location Coverage**: AI may have limited info for very remote locations
3. **Cost Estimates**: Approximate, actual costs may vary
4. **Real-time Data**: Doesn't check current opening hours, availability
5. **Language**: Responses in English (multilingual support planned)

## Troubleshooting

### "Trip duration cannot exceed 14 days"
- Split your trip into multiple segments
- Generate week 1, then week 2 separately

### "Failed to generate itinerary: API error"
- Check GROQ_API_KEY is valid
- Verify internet connectivity
- Wait and retry (rate limit may be hit)

### Activities seem unrealistic
- Provide more specific interests
- Include special requirements for pace
- Use budget_tier to match expectations

### Missing specific attraction
- Edit itinerary after generation
- Use chat refinement: "Add Eiffel Tower visit on Day 2"

## Testing in Swagger UI

1. Navigate to `http://localhost:8000/docs`
2. Click on `POST /api/generate`
3. Click "Try it out"
4. Enter authentication token
5. Modify request body
6. Click "Execute"
7. View generated itinerary in response

## Configuration

Backend settings (in `.env`):

```env
# Groq API Configuration
GROQ_API_KEY=your_groq_api_key_here
GROQ_MODEL=mixtral-8x7b-32768

# Optional: Adjust generation parameters
# (currently hardcoded in ai_service.py)
```

## Next Steps

- **Task BE-5**: Chat refinement for iterative improvements
- **Task BE-6**: Sync generated itineraries across devices
- **Task BE-7**: Export generated itineraries to PDF

## Support

For issues or questions:
- Check FastAPI logs for error details
- Verify Groq API key is active
- Ensure valid date formats (YYYY-MM-DD)
- Review request validation errors (422 responses)

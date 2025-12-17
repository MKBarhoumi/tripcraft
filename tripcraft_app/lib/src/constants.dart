// constants.dart
// Application-wide constants and configuration

/// API Configuration
const String apiBaseUrl = 'http://localhost:8000/api/v1'; // Development
// const String apiBaseUrl = 'https://your-api.railway.app/api/v1'; // Production

/// Local Storage Keys
const String hiveBoxTrips = 'trips_box';
const String jwtKey = 'jwt_token';
const String userKey = 'user_data';

/// API Configuration
const int apiTimeoutSeconds = 15;
const int maxRetryAttempts = 3;
const int retryDelayMs = 1000;

/// Trip Limits
const int maxTripDays = 14;
const int minTripDays = 1;

/// Cache Configuration
const int cacheDurationMinutes = 30;

/// Travel Styles
const List<String> travelStyles = [
  'relaxed',
  'moderate',
  'packed',
  'adventure',
  'cultural',
  'foodie',
];

/// Budget Tiers
const List<String> budgetTiers = [
  'budget',
  'mid',
  'luxury',
];

/// App Info
const String appName = 'TripCraft';
const String appVersion = '1.0.0';
const String appDescription = 'AI-Powered Travel Itinerary Planner';

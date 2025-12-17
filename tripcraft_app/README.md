# TripCraft App

An AI-powered travel itinerary planner built with Flutter.

## Features

- ✅ **Authentication**: Login and registration with JWT tokens
- ✅ **Trip Management**: Create, edit, and delete trips with details like destination, dates, budget, and travel style
- ✅ **Home Screen**: View all trips with search, sort, and sync functionality
- ✅ **Offline-First**: Local storage with Hive for offline access
- ✅ **Sync**: Bidirectional synchronization with backend server
- 🚧 **AI Generation**: Coming soon - AI-powered itinerary generation
- 🚧 **Detail Views**: Trip details with day-by-day breakdown

## Progress

**Completed Tasks (8/20):**
- Task 20: Supabase & Environment Variables ✅
- Task FE-1: Frontend Scaffold ✅
- Task FE-2: Data Models ✅
- Task FE-3: Local Storage Service ✅
- Task FE-4: API Client + Sync ✅
- Task FE-5: Auth Screens ✅
- Task FE-6: Home & Trip List Screen ✅
- Task FE-7: Trip Form Screen ✅

**Next Up:**
- Task FE-8: Itinerary Generation Screen
- Task FE-9: Trip Detail Screen

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK 3.0+

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up environment variables:
   - Create `.env` file in project root
   - Add your API keys and configuration

4. Run the app:
   ```bash
   flutter run
   ```

### Testing

Run all tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/screens/auth/login_screen_test.dart
```

## Project Structure

```
lib/
├── src/
│   ├── models/          # Data models
│   ├── providers/       # Riverpod providers
│   ├── screens/         # UI screens
│   │   ├── auth/        # Login & Register
│   │   ├── home/        # Home screen with trip list
│   │   └── trip/        # Trip form
│   ├── services/        # API client, local storage, sync
│   ├── utils/           # Validators, formatters
│   ├── constants.dart   # App constants
│   └── app.dart         # Main app widget
└── main.dart
```

## Technologies

- **Flutter**: Cross-platform UI framework
- **Riverpod**: State management
- **Hive**: Local database
- **go_router**: Navigation
- **Dio**: HTTP client
- **freezed**: Code generation for models

## License

This project is licensed under the MIT License.


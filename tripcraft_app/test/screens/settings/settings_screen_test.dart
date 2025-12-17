// settings_screen_test.dart
// Tests for the Settings Screen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripcraft_app/src/screens/settings/settings_screen.dart';
import 'package:tripcraft_app/src/models/user.dart';
import 'package:tripcraft_app/src/services/local_storage_service.dart';
import 'package:tripcraft_app/src/services/api_client.dart';
import 'package:tripcraft_app/src/providers/auth_state.dart';
import 'package:tripcraft_app/src/providers/providers.dart';
import 'package:tripcraft_app/src/models/trip.dart';

// Mock LocalStorageService
class MockLocalStorageService implements LocalStorageService {
  final Map<String, Trip> _trips = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTrip(Trip trip) async {
    _trips[trip.id] = trip;
  }

  @override
  Future<Trip?> getTrip(String id) async {
    return _trips[id];
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.remove(id);
  }

  @override
  Future<List<Trip>> getAllTrips() async {
    return _trips.values.toList();
  }

  @override
  Future<List<Trip>> searchTrips(String query) async {
    return _trips.values
        .where((trip) =>
            (trip.title?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            trip.destination.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<List<Trip>> getUnsyncedTrips() async {
    return _trips.values.where((trip) => !trip.isSynced).toList();
  }

  @override
  Future<void> saveTrips(List<Trip> trips) async {
    for (final trip in trips) {
      _trips[trip.id] = trip;
    }
  }

  @override
  Future<void> deleteTrips(List<String> ids) async {
    for (final id in ids) {
      _trips.remove(id);
    }
  }

  @override
  Future<void> clearAll() async {
    _trips.clear();
  }

  @override
  int get tripCount => _trips.length;

  @override
  bool tripExists(String id) {
    return _trips.containsKey(id);
  }

  @override
  Future<List<Trip>> getTripsModifiedAfter(DateTime timestamp) async {
    return _trips.values
        .where((trip) => trip.localUpdatedAt.isAfter(timestamp))
        .toList();
  }

  @override
  Future<List<Trip>> searchByDestination(String destination) async {
    return _trips.values
        .where((trip) =>
            trip.destination.toLowerCase().contains(destination.toLowerCase()))
        .toList();
  }

  @override
  Map<String, dynamic> getStorageStats() {
    return {
      'totalTrips': _trips.length,
      'syncedTrips': _trips.values.where((t) => t.isSynced).length,
      'unsyncedTrips': _trips.values.where((t) => !t.isSynced).length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllTripsJson() async {
    return _trips.values.map((t) => t.toJson()).toList();
  }

  @override
  Future<int> importTripsFromJson(List<Map<String, dynamic>> tripsJson) async {
    for (final json in tripsJson) {
      final trip = Trip.fromJson(json);
      _trips[trip.id] = trip;
    }
    return tripsJson.length;
  }

  @override
  Future<void> compactStorage() async {}

  @override
  Future<void> close() async {}
}

// Mock AuthNotifier
class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier() : super(MockApiClient()) {
    state = AuthState(
      isAuthenticated: true,
      user: User(
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
      ),
    );
  }

  @override
  Future<void> logout() async {
    state = const AuthState(isAuthenticated: false);
  }
}

// Mock ApiClient
class MockApiClient extends ApiClient {
  MockApiClient() : super(baseUrl: 'http://test');

  @override
  Future<bool> isAuthenticated() async => true;
}

// Helper function to create test widget
Widget createTestWidget(MockLocalStorageService mockStorage) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(mockStorage),
      authStateProvider.overrideWith((ref) => MockAuthNotifier()),
    ],
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

void main() {
  group('SettingsScreen - Display', () {
    testWidgets('shows settings title', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('displays user profile section', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('displays all section headers', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Data & Storage'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('displays theme option', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme_tile')), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);
    });

    testWidgets('displays notification switch', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_switch')), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('displays default budget tier', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget_tier_tile')), findsOneWidget);
      expect(find.text('Default Budget Tier'), findsOneWidget);
    });

    testWidgets('displays default travel style', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('travel_style_tile')), findsOneWidget);
      expect(find.text('Default Travel Style'), findsOneWidget);
    });
  });

  group('SettingsScreen - Theme Selection', () {
    testWidgets('can open theme dialog', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('can select light theme', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Theme'), findsNothing);
      expect(find.text('Settings saved'), findsOneWidget);
    });

    testWidgets('can select dark theme', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Theme'), findsNothing);
      expect(find.text('Settings saved'), findsOneWidget);
    });
  });

  group('SettingsScreen - Notifications', () {
    testWidgets('notifications toggle starts enabled', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      final switchWidget =
          tester.widget<SwitchListTile>(find.byKey(const Key('notifications_switch')));
      expect(switchWidget.value, true);
    });

    testWidgets('can toggle notifications off', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notifications_switch')));
      await tester.pumpAndSettle();

      expect(find.text('Settings saved'), findsOneWidget);
    });

    testWidgets('can toggle notifications back on', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      // Toggle off
      await tester.tap(find.byKey(const Key('notifications_switch')));
      await tester.pumpAndSettle();

      // Toggle on
      await tester.tap(find.byKey(const Key('notifications_switch')));
      await tester.pumpAndSettle();

      expect(find.text('Settings saved'), findsWidgets);
    });
  });

  group('SettingsScreen - Budget Tier', () {
    testWidgets('can open budget tier dialog', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('budget_tier_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Default Budget Tier'), findsWidgets);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);
    });

    testWidgets('can select moderate budget tier', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('budget_tier_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moderate'));
      await tester.pumpAndSettle();

      expect(find.text('Settings saved'), findsOneWidget);
    });
  });

  group('SettingsScreen - Travel Style', () {
    testWidgets('can open travel style dialog', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('travel_style_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Default Travel Style'), findsWidgets);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Fast-paced'), findsOneWidget);
    });

    testWidgets('can select fast-paced style', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('travel_style_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fast-paced'));
      await tester.pumpAndSettle();

      expect(find.text('Settings saved'), findsOneWidget);
    });
  });

  group('SettingsScreen - Clear Data', () {
    testWidgets('can open clear data confirmation', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clear_data_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Clear Local Data'), findsWidgets);
      expect(
        find.text(
            'Are you sure you want to clear all local data? This will delete all offline trips that haven\'t been synced.'),
        findsOneWidget,
      );
    });

    testWidgets('can cancel clear data', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clear_data_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Local Data'), findsOneWidget); // Back to settings
    });

    testWidgets('can confirm clear data', (tester) async {
      final mockStorage = MockLocalStorageService();
      // Add some test data
      await mockStorage.saveTrip(Trip(
        id: 'test-1',
        userId: 'user-1',
        destination: 'Paris',
      ));

      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(mockStorage.tripCount, 1);

      await tester.tap(find.byKey(const Key('clear_data_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear Data'));
      await tester.pumpAndSettle();

      expect(find.text('Local data cleared'), findsOneWidget);
      expect(mockStorage.tripCount, 0);
    });
  });

  group('SettingsScreen - Logout', () {
    testWidgets('can open logout confirmation', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsWidgets);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
    });

    testWidgets('can cancel logout', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still on settings screen
      expect(find.text('Test User'), findsOneWidget);
    });
  });

  group('SettingsScreen - Delete Account', () {
    testWidgets('can open delete account confirmation', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsWidgets);
      expect(
        find.text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.'),
        findsOneWidget,
      );
    });

    testWidgets('can cancel delete account', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_account_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still on settings screen
      expect(find.text('Test User'), findsOneWidget);
    });
  });

  group('SettingsScreen - About', () {
    testWidgets('displays about option', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('about_tile')), findsOneWidget);
      expect(find.textContaining('About'), findsOneWidget);
    });

    testWidgets('displays privacy policy option', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy_tile')), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('displays terms of service option', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terms_tile')), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('can tap privacy policy', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('privacy_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy would open here'), findsOneWidget);
    });

    testWidgets('can tap terms of service', (tester) async {
      final mockStorage = MockLocalStorageService();
      await tester.pumpWidget(createTestWidget(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terms_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Terms of service would open here'), findsOneWidget);
    });
  });
}

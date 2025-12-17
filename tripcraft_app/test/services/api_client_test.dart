// api_client_test.dart
// Unit tests for ApiClient

import 'package:flutter_test/flutter_test.dart';
import 'package:tripcraft_app/src/services/api_client.dart';

void main() {
  late ApiClient apiClient;

  setUp(() {
    apiClient = ApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
    );
  });

  tearDown(() {
    apiClient.dispose();
  });

  group('ApiClient - Configuration', () {
    test('should initialize with correct base URL', () {
      expect(apiClient.baseUrl, 'http://localhost:8000/api/v1');
      expect(apiClient.isConfigured, true);
    });

    test('should use default base URL if none provided', () {
      final client = ApiClient();
      expect(client.baseUrl, isNotEmpty);
      client.dispose();
    });
  });

  group('ApiClient - Token Management', () {
    test('should save and retrieve token', () async {
      const testToken = 'test-jwt-token';
      
      await apiClient.saveToken(testToken);
      final retrievedToken = await apiClient.getToken();
      
      expect(retrievedToken, testToken);
    });

    test('should clear token', () async {
      const testToken = 'test-jwt-token';
      
      await apiClient.saveToken(testToken);
      await apiClient.clearToken();
      final retrievedToken = await apiClient.getToken();
      
      expect(retrievedToken, isNull);
    });

    test('should return null if no token exists initially', () async {
      final client = ApiClient(baseUrl: 'http://test.com');
      final token = await client.getToken();
      expect(token, isNull);
      await client.clearToken(); // Cleanup
      client.dispose();
    });

    test('should check authentication status', () async {
      final client = ApiClient(baseUrl: 'http://test.com');
      
      // Not authenticated initially
      expect(await client.isAuthenticated(), false);
      
      // Authenticated after saving token
      await client.saveToken('test-token');
      expect(await client.isAuthenticated(), true);
      
      // Not authenticated after clearing token
      await client.clearToken();
      expect(await client.isAuthenticated(), false);
      
      client.dispose();
    });
  });

  group('ApiClient - Endpoint Methods', () {
    test('should have all required authentication methods', () {
      expect(apiClient.register, isA<Function>());
      expect(apiClient.login, isA<Function>());
      expect(apiClient.logout, isA<Function>());
      expect(apiClient.getCurrentUser, isA<Function>());
    });

    test('should have all required trip CRUD methods', () {
      expect(apiClient.getTrips, isA<Function>());
      expect(apiClient.getTrip, isA<Function>());
      expect(apiClient.createTrip, isA<Function>());
      expect(apiClient.updateTrip, isA<Function>());
      expect(apiClient.deleteTrip, isA<Function>());
    });

    test('should have AI generation methods', () {
      expect(apiClient.generateItinerary, isA<Function>());
      expect(apiClient.refineItinerary, isA<Function>());
    });

    test('should have export methods', () {
      expect(apiClient.exportTripPdf, isA<Function>());
      expect(apiClient.downloadPdf, isA<Function>());
    });

    test('should have sync methods', () {
      expect(apiClient.syncTrips, isA<Function>());
      expect(apiClient.getServerTimestamp, isA<Function>());
    });
  });

  group('ApiClient - Method Signatures', () {
    test('register method has correct parameters', () async {
      // Verify method exists and can be called
      // (will fail in test without server, but verifies signature)
      expect(
        () => apiClient.register(email: 'test@test.com', password: 'pass'),
        throwsA(anything), // Expects to throw (no server)
      );
    });

    test('login method has correct parameters', () async {
      expect(
        () => apiClient.login(email: 'test@test.com', password: 'pass'),
        throwsA(anything),
      );
    });

    test('generateItinerary method has correct parameters', () async {
      expect(
        () => apiClient.generateItinerary(
          destination: 'Paris',
          startDate: DateTime(2025, 6, 1),
          endDate: DateTime(2025, 6, 7),
        ),
        throwsA(anything),
      );
    });
  });
}

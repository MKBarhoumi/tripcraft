// api_client.dart
// HTTP client for TripCraft API with JWT authentication

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../models/models.dart';

/// ApiClient handles all HTTP communication with the backend
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  
  String? _cachedToken;

  ApiClient({
    String? baseUrl,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add JWT interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add JWT token to all requests
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Retry on 429 (rate limit) with exponential backoff
          if (error.response?.statusCode == 429) {
            final retryAfter = error.response?.headers.value('retry-after');
            final delay = retryAfter != null 
                ? int.tryParse(retryAfter) ?? 5 
                : 5;
            
            print('Rate limited. Retrying after $delay seconds...');
            await Future.delayed(Duration(seconds: delay));
            
            // Retry the request
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
          
          // Handle 401 (unauthorized) - token expired
          if (error.response?.statusCode == 401) {
            await clearToken();
            _cachedToken = null;
          }
          
          return handler.next(error);
        },
      ),
    );
  }

  // ============================================================================
  // TOKEN MANAGEMENT
  // ============================================================================

  /// Get JWT token from secure storage
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    
    try {
      _cachedToken = await _secureStorage.read(key: jwtKey);
      return _cachedToken;
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  /// Save JWT token to secure storage
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: jwtKey, value: token);
      _cachedToken = token;
    } catch (e) {
      print('Error saving token: $e');
      rethrow;
    }
  }

  /// Clear JWT token
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: jwtKey);
      _cachedToken = null;
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================================================
  // AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Register a new user
  /// POST /api/v1/auth/register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (fullName != null) 'full_name': fullName,
        },
      );

      // Save token
      final token = response.data['access_token'] as String?;
      if (token != null) {
        await saveToken(token);
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e, 'Registration failed');
    }
  }

  /// Login user
  /// POST /api/v1/auth/login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      // Save token
      final token = response.data['access_token'] as String?;
      if (token != null) {
        await saveToken(token);
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e, 'Login failed');
    }
  }

  /// Logout user
  Future<void> logout() async {
    await clearToken();
  }

  /// Get current user profile
  /// GET /api/v1/auth/me
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to get user profile');
    }
  }

  // ============================================================================
  // TRIP CRUD ENDPOINTS
  // ============================================================================

  /// Get all trips for current user
  /// GET /api/v1/trips
  Future<List<Trip>> getTrips() async {
    try {
      final response = await _dio.get('/trips');
      final tripsData = response.data as List<dynamic>;
      return tripsData
          .map((json) => Trip.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to fetch trips');
    }
  }

  /// Get a single trip by ID
  /// GET /api/v1/trips/{id}
  Future<Trip> getTrip(String id) async {
    try {
      final response = await _dio.get('/trips/$id');
      return Trip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to fetch trip');
    }
  }

  /// Create a new trip
  /// POST /api/v1/trips
  Future<Trip> createTrip(Trip trip) async {
    try {
      final response = await _dio.post(
        '/trips',
        data: trip.toJson(),
      );
      return Trip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to create trip');
    }
  }

  /// Update an existing trip
  /// PUT /api/v1/trips/{id}
  Future<Trip> updateTrip(String id, Trip trip) async {
    try {
      final response = await _dio.put(
        '/trips/$id',
        data: trip.toJson(),
      );
      return Trip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to update trip');
    }
  }

  /// Delete a trip
  /// DELETE /api/v1/trips/{id}
  Future<void> deleteTrip(String id) async {
    try {
      await _dio.delete('/trips/$id');
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to delete trip');
    }
  }

  // ============================================================================
  // ITINERARY GENERATION ENDPOINTS
  // ============================================================================

  /// Generate a new itinerary using AI
  /// POST /api/v1/generate
  Future<Trip> generateItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String? travelStyle,
    String? budgetTier,
    String? preferences,
  }) async {
    try {
      final response = await _dio.post(
        '/generate',
        data: {
          'destination': destination,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          if (travelStyle != null) 'travel_style': travelStyle,
          if (budgetTier != null) 'budget_tier': budgetTier,
          if (preferences != null) 'preferences': preferences,
        },
      );
      
      return Trip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to generate itinerary');
    }
  }

  /// Refine an existing itinerary
  /// POST /api/v1/generate/refine
  Future<Trip> refineItinerary({
    required String tripId,
    required String refinementPrompt,
  }) async {
    try {
      final response = await _dio.post(
        '/generate/refine',
        data: {
          'trip_id': tripId,
          'refinement_prompt': refinementPrompt,
        },
      );
      
      return Trip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to refine itinerary');
    }
  }

  // ============================================================================
  // EXPORT ENDPOINTS
  // ============================================================================

  /// Export trip as PDF
  /// POST /api/v1/export/{trip_id}
  Future<String> exportTripPdf(String tripId) async {
    try {
      final response = await _dio.post('/export/$tripId');
      
      // Returns URL to the PDF in Supabase storage
      final pdfUrl = response.data['pdf_url'] as String;
      return pdfUrl;
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to export PDF');
    }
  }

  /// Download PDF from URL
  Future<void> downloadPdf(String url, String savePath) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to download PDF');
    }
  }

  // ============================================================================
  // SYNC ENDPOINTS
  // ============================================================================

  /// Sync local trips to server (bulk upload)
  /// POST /api/v1/trips/sync
  Future<List<Trip>> syncTrips(List<Trip> trips) async {
    try {
      final response = await _dio.post(
        '/trips/sync',
        data: {
          'trips': trips.map((t) => t.toJson()).toList(),
        },
      );
      
      final syncedData = response.data as List<dynamic>;
      return syncedData
          .map((json) => Trip.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to sync trips');
    }
  }

  /// Get server timestamp (for sync conflict resolution)
  /// GET /api/v1/sync/timestamp
  Future<DateTime> getServerTimestamp() async {
    try {
      final response = await _dio.get('/sync/timestamp');
      final timestamp = response.data['timestamp'] as String;
      return DateTime.parse(timestamp);
    } on DioException catch (e) {
      throw _handleError(e, 'Failed to get server timestamp');
    }
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

  /// Handle Dio errors and convert to readable messages
  Exception _handleError(DioException error, String defaultMessage) {
    String message = defaultMessage;
    
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      
      // Try to extract error message from response
      if (data is Map<String, dynamic>) {
        message = data['detail'] ?? data['message'] ?? message;
      } else if (data is String) {
        message = data;
      }
      
      // Add status code context
      message = '[$statusCode] $message';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet connection.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      message = 'Server is taking too long to respond.';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Unable to connect to server. Please check your internet connection.';
    }
    
    return Exception(message);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Close the client and clean up resources
  void dispose() {
    _dio.close();
  }

  /// Get base URL
  String get baseUrl => _dio.options.baseUrl;

  /// Check if client has valid configuration
  bool get isConfigured => _dio.options.baseUrl.isNotEmpty;
}

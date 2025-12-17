// auth_state.dart
// Authentication state management with Riverpod

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_client.dart';

export 'package:flutter_riverpod/flutter_riverpod.dart' show StateNotifier;

/// Authentication state
class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  String toString() {
    return 'AuthState(user: ${user?.email}, isAuthenticated: $isAuthenticated, isLoading: $isLoading, error: $error)';
  }
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState()) {
    // Check if user is already authenticated on initialization
    _checkAuthStatus();
  }

  /// Check if user is authenticated (has valid token)
  Future<void> _checkAuthStatus() async {
    try {
      final isAuthenticated = await _apiClient.isAuthenticated();
      
      if (isAuthenticated) {
        // Try to get current user
        try {
          final user = await _apiClient.getCurrentUser();
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
        } catch (e) {
          // Token is invalid or expired
          await _apiClient.clearToken();
          state = state.copyWith(
            isAuthenticated: false,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  /// Register a new user
  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.register(
        email: email,
        password: password,
        fullName: fullName,
      );

      // Get user data from response
      final userData = response['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = User.fromJson(userData);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        // Fetch user profile if not included in response
        await getCurrentUser();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Login user
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.login(
        email: email,
        password: password,
      );

      // Get user data from response
      final userData = response['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = User.fromJson(userData);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        // Fetch user profile if not included in response
        await getCurrentUser();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _apiClient.logout();
      state = const AuthState(
        isAuthenticated: false,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Clear state anyway
      state = const AuthState(
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  /// Get current user profile
  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true);

    try {
      final user = await _apiClient.getCurrentUser();
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

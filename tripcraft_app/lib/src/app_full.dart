// app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/trip/trip_form_screen.dart';
import 'screens/generation/itinerary_generation_screen.dart';
import 'screens/detail/trip_detail_screen.dart';
import 'screens/detail/activity_detail_screen.dart';
import 'screens/detail/budget_tracker_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Main App Widget with Riverpod ProviderScope
class TripCraftApp extends ConsumerWidget {
  const TripCraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🔵 Building TripCraftApp');
    
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          tertiary: const Color(0xFFEC4899),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF818CF8),
          secondary: const Color(0xFFA78BFA),
          tertiary: const Color(0xFFF472B6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: _buildRouter(ref),
    );
  }

  GoRouter _buildRouter(WidgetRef ref) {
    debugPrint('🔵 Building router');
    return GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) {
            debugPrint('🔵 Building LoginScreen');
            return const LoginScreen();
          },
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/trip/new',
          name: 'trip-new',
          builder: (context, state) => const TripFormScreen(),
        ),
        GoRoute(
          path: '/trip/:id/edit',
          name: 'trip-edit',
          builder: (context, state) {
            final tripId = state.pathParameters['id'];
            return TripFormScreen(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/trip/:id',
          name: 'trip-detail',
          builder: (context, state) {
            final tripId = state.pathParameters['id']!;
            return TripDetailScreen(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/trip/:tripId/day/:dayIndex/activity/:activityId',
          name: 'activity-detail',
          builder: (context, state) {
            final tripId = state.pathParameters['tripId']!;
            final dayIndex = int.parse(state.pathParameters['dayIndex']!);
            final activityId = state.pathParameters['activityId']!;
            return ActivityDetailScreen(
              tripId: tripId,
              dayIndex: dayIndex,
              activityId: activityId,
            );
          },
        ),
        GoRoute(
          path: '/trip/:id/budget',
          name: 'budget-tracker',
          builder: (context, state) {
            final tripId = state.pathParameters['id']!;
            return BudgetTrackerScreen(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/generate',
          name: 'generate',
          builder: (context, state) => const ItineraryGenerationScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }
}

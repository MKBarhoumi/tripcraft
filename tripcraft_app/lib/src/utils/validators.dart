// validators.dart
// Input validation utilities

/// Validates email format
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email';
  }
  
  return null;
}

/// Validates password strength
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  
  return null;
}

/// Validates required field
String? validateRequired(String? value, String fieldName) {
  if (value == null || value.isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

/// Validates destination field
String? validateDestination(String? value) {
  return validateRequired(value, 'Destination');
}

/// Validates number of days
String? validateDays(String? value) {
  if (value == null || value.isEmpty) {
    return 'Number of days is required';
  }
  
  final days = int.tryParse(value);
  if (days == null) {
    return 'Please enter a valid number';
  }
  
  if (days < 1) {
    return 'Trip must be at least 1 day';
  }
  
  if (days > 14) {
    return 'Trip cannot exceed 14 days';
  }
  
  return null;
}

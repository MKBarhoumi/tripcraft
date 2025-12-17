// formatters.dart
// Formatting utilities for dates, currency, etc.

import 'package:intl/intl.dart';

/// Formats date to 'MMM dd, yyyy' (e.g., Jan 15, 2025)
String formatDate(DateTime date) {
  return DateFormat('MMM dd, yyyy').format(date);
}

/// Formats date to 'yyyy-MM-dd' for API
String formatDateForApi(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Formats time to 'HH:mm' (e.g., 09:30)
String formatTime(DateTime time) {
  return DateFormat('HH:mm').format(time);
}

/// Formats currency amount (e.g., $123.45)
String formatCurrency(double amount, {String symbol = '\$'}) {
  return '$symbol${amount.toStringAsFixed(2)}';
}

/// Formats date range (e.g., Jan 15 - Jan 20, 2025)
String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat('MMM dd').format(start)} - ${DateFormat('dd, yyyy').format(end)}';
  } else if (start.year == end.year) {
    return '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}';
  } else {
    return '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}';
  }
}

/// Parses date string from API ('yyyy-MM-dd')
DateTime? parseDateFromApi(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    return DateTime.parse(dateStr);
  } catch (e) {
    return null;
  }
}

/// Formats duration in days (e.g., "3 days", "1 day")
String formatDuration(int days) {
  return days == 1 ? '1 day' : '$days days';
}

/// Truncates text with ellipsis
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

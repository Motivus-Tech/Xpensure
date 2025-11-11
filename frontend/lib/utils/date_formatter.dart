// utils/date_formatter.dart
import 'package:intl/intl.dart';

class DateFormatter {
  // Backend se aane wali date ko format karein
  static String formatBackendDate(String? backendDate) {
    if (backendDate == null || backendDate.isEmpty) {
      return 'N/A';
    }

    try {
      // Pehle backend date ko parse karein
      DateTime parsedDate;

      // Multiple possible formats handle karein
      if (backendDate.contains('T')) {
        // ISO format (2024-01-15T10:30:00Z)
        parsedDate = DateTime.parse(backendDate);
      } else if (backendDate.contains('-')) {
        // Simple date format (2024-01-15)
        parsedDate = DateTime.parse(backendDate);
      } else {
        // Try other formats
        parsedDate = DateTime.parse(backendDate);
      }

      // User-friendly format mein convert karein
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate.toLocal());
    } catch (e) {
      print('Date parsing error: $e for date: $backendDate');
      return backendDate; // Original string return karein agar parse na ho sake
    }
  }

  // Sirf date dikhane ke liye (time ke bina)
  static String formatDateOnly(String? backendDate) {
    if (backendDate == null || backendDate.isEmpty) {
      return 'N/A';
    }

    try {
      DateTime parsedDate = DateTime.parse(backendDate);
      return DateFormat('dd MMM yyyy').format(parsedDate.toLocal());
    } catch (e) {
      return backendDate;
    }
  }

  // Relative time dikhane ke liye (e.g., "2 days ago")
  static String formatRelativeTime(String? backendDate) {
    if (backendDate == null || backendDate.isEmpty) {
      return 'N/A';
    }

    try {
      final parsedDate = DateTime.parse(backendDate);
      final now = DateTime.now();
      final difference = now.difference(parsedDate);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} years ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return formatBackendDate(backendDate);
    }
  }
}

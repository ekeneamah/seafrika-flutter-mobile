/// Utility functions for date formatting and safe string operations
class AppDateUtils {
  /// Safely extract date part from DateTime string
  /// Handles cases where toString().split(' ')[0] might fail
  static String getDateOnly(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    try {
      final dateString = dateTime.toString();
      if (dateString.isEmpty) return 'N/A';

      final parts = dateString.split(' ');
      return parts.isNotEmpty ? parts[0] : 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Safely extract date part from string representation
  static String getDateOnlyFromString(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';

    try {
      final parts = dateString.split(' ');
      return parts.isNotEmpty ? parts[0] : 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Format connected date for integration screens
  static String formatConnectedDate(DateTime? createdAt) {
    return getDateOnly(createdAt);
  }
}

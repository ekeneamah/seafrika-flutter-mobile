/// Constants for SharedPreferences keys used across the application
class SharedPreferencesKeys {
  // Private constructor to prevent instantiation
  SharedPreferencesKeys._();

  // Business Selection Keys
  static const String selectedBusinessId = 'selected_business_id';
  static const String selectedBusinessName = 'selected_business_name';
  static const String selectedBusinessPhone = 'selected_business_phone';
  static const String selectedBusinessAddress = 'selected_business_address';
  static const String selectedBusinessOwnerId = 'selected_business_owner_id';
  static const String selectedBusinessCategory = 'selected_business_category';
  static const String selectedBusinessDescription = 'selected_business_description';
  static const String selectedBusinessImageUrl = 'selected_business_image_url';
  
  // User Session Keys
  static const String userRole = 'user_role';
  static const String isLoggedIn = 'is_logged_in';
  static const String currentUserId = 'current_user_id';
  
  // Onboarding Keys
  static const String onboardingCompleted = 'onboarding_completed';
  
  // App Settings Keys
  static const String isDarkMode = 'is_dark_mode';
  static const String selectedLanguage = 'selected_language';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String analyticsEnabled = 'analytics_enabled';
  static const String darkMode = 'dark_mode';
  static const String language = 'language';
  
  // Legacy/Additional Keys
  static const String selectedStoreId = 'selectedStoreId';
  static const String hasSeededPermissions = 'hasSeededPermissions';
  static const String lastSearchCriteria = 'last_search_criteria';
  
  // Auth Service Keys
  static const String loginAttemptsPrefix = 'login_attempts_';
  static const String lastAttemptPrefix = 'last_attempt_';
}

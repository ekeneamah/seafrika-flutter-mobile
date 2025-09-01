class AppConstants {
  static const String apiUrl = 'https://api.vendor-app.com/v1';

  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String signupEndpoint = '/auth/signup';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  static const String changePasswordEndpoint = '/auth/change-password';
  static const String logoutEndpoint = '/auth/logout';
  static const String meEndpoint = '/auth/me';

  static const String productsEndpoint = '/products';
  static const String mediaEndpoint = '/media';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Error Messages
  static const String networkError =
      'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String authError = 'Authentication error. Please login again.';
  static const String validationError = 'Please check your input.';

  // Success Messages
  static const String loginSuccess = 'Login successful.';
  static const String signupSuccess = 'Account created successfully.';
  static const String passwordResetSuccess =
      'Password reset instructions sent.';
  static const String passwordChangeSuccess = 'Password changed successfully.';
  static const String logoutSuccess = 'Logged out successfully.';

  static const String defaultBusinessLocation =
      '123 Business Street, City, Country';
}

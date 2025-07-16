import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/models/business.dart';

/// Utility class for managing business-related SharedPreferences operations
class BusinessPreferencesHelper {
  // Private constructor to prevent instantiation
  BusinessPreferencesHelper._();

  /// Save complete business details to SharedPreferences
  static Future<void> saveSelectedBusiness(Business business) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(SharedPreferencesKeys.selectedBusinessId, business.id);
    await prefs.setString(SharedPreferencesKeys.selectedBusinessName, business.name);
    await prefs.setString(SharedPreferencesKeys.selectedBusinessPhone, business.phone ?? '');
    await prefs.setString(SharedPreferencesKeys.selectedBusinessAddress, business.address);
    await prefs.setString(SharedPreferencesKeys.selectedBusinessOwnerId, business.ownerId);
    await prefs.setString(SharedPreferencesKeys.selectedBusinessCategory, business.industry ?? '');
    await prefs.setString(SharedPreferencesKeys.selectedBusinessDescription, business.description ?? '');
    
    // Save country and state
    await prefs.setString('selected_business_country', business.country);
    await prefs.setString('selected_business_state', business.state);
    
    if (business.logoUrl != null) {
      await prefs.setString(SharedPreferencesKeys.selectedBusinessImageUrl, business.logoUrl!);
    }
  }

  /// Get selected business ID from SharedPreferences
  static Future<String?> getSelectedBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessId);
  }

  /// Get selected business name from SharedPreferences
  static Future<String?> getSelectedBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessName);
  }

  /// Get selected business phone from SharedPreferences
  static Future<String?> getSelectedBusinessPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessPhone);
  }

  /// Get selected business address from SharedPreferences
  static Future<String?> getSelectedBusinessAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessAddress);
  }

  /// Get selected business owner ID from SharedPreferences
  static Future<String?> getSelectedBusinessOwnerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessOwnerId);
  }

  /// Get selected business category from SharedPreferences
  static Future<String?> getSelectedBusinessCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessCategory);
  }

  /// Get selected business description from SharedPreferences
  static Future<String?> getSelectedBusinessDescription() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessDescription);
  }

  /// Get selected business image URL from SharedPreferences
  static Future<String?> getSelectedBusinessImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesKeys.selectedBusinessImageUrl);
  }

  /// Get selected business country from SharedPreferences
  static Future<String?> getSelectedBusinessCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_business_country') ?? '';
  }

  /// Get selected business state from SharedPreferences
  static Future<String?> getSelectedBusinessState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_business_state') ?? '';
  }

  /// Get all selected business details as a map
  static Future<Map<String, String>> getSelectedBusinessDetails() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'id': prefs.getString(SharedPreferencesKeys.selectedBusinessId) ?? '',
      'name': prefs.getString(SharedPreferencesKeys.selectedBusinessName) ?? '',
      'phone': prefs.getString(SharedPreferencesKeys.selectedBusinessPhone) ?? '',
      'address': prefs.getString(SharedPreferencesKeys.selectedBusinessAddress) ?? '',
      'ownerId': prefs.getString(SharedPreferencesKeys.selectedBusinessOwnerId) ?? '',
      'category': prefs.getString(SharedPreferencesKeys.selectedBusinessCategory) ?? '',
      'description': prefs.getString(SharedPreferencesKeys.selectedBusinessDescription) ?? '',
      'imageUrl': prefs.getString(SharedPreferencesKeys.selectedBusinessImageUrl) ?? '',
      'country': prefs.getString('selected_business_country') ?? '',
      'state': prefs.getString('selected_business_state') ?? '',
    };
  }

  /// Clear all selected business data from SharedPreferences
  static Future<void> clearSelectedBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(SharedPreferencesKeys.selectedBusinessId);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessName);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessPhone);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessAddress);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessOwnerId);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessCategory);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessDescription);
    await prefs.remove(SharedPreferencesKeys.selectedBusinessImageUrl);
  }

  /// Check if a business is currently selected
  static Future<bool> hasSelectedBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final businessId = prefs.getString(SharedPreferencesKeys.selectedBusinessId);
    return businessId != null && businessId.isNotEmpty;
  }
}

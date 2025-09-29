import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/services/business_service.dart';
import 'package:vendor_app/providers/service_providers.dart';

/// Provider for managing the currently selected business context
class BusinessContextNotifier extends StateNotifier<Business?> {
  final BusinessService _businessService;
  final SharedPreferences _prefs;

  BusinessContextNotifier(this._businessService, this._prefs) : super(null) {
    _loadSelectedBusiness();
  }

  /// Load the selected business from SharedPreferences
  Future<void> _loadSelectedBusiness() async {
    final businessId =
        _prefs.getString(SharedPreferencesKeys.selectedBusinessId);
    if (businessId != null) {
      try {
        final business = await _businessService.getBusiness(businessId);
        if (business != null) {
          state = business;
        } else {
          // Business not found, clear selection
          await clearSelectedBusiness();
        }
      } catch (e) {
        // Business not found or error, clear selection
        await clearSelectedBusiness();
      }
    }
  }

  /// Set the selected business and persist to SharedPreferences
  Future<void> setSelectedBusiness(Business business) async {
    await _prefs.setString(
        SharedPreferencesKeys.selectedBusinessId, business.id);
    await _prefs.setString(
        SharedPreferencesKeys.selectedBusinessName, business.name);
    await _prefs.setString(
        SharedPreferencesKeys.selectedBusinessPhone, business.phone ?? '');
    await _prefs.setString(
        SharedPreferencesKeys.selectedBusinessAddress, business.address);
    await _prefs.setString(
        SharedPreferencesKeys.selectedBusinessOwnerId, business.ownerId);
    await _prefs.setString(SharedPreferencesKeys.selectedBusinessCategory,
        business.industry ?? '');
    await _prefs.setString(SharedPreferencesKeys.selectedBusinessDescription,
        business.description ?? '');
    if (business.logoUrl != null) {
      await _prefs.setString(
          SharedPreferencesKeys.selectedBusinessImageUrl, business.logoUrl!);
    }
    state = business;
  }

  /// Clear the selected business
  Future<void> clearSelectedBusiness() async {
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessId);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessName);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessPhone);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessAddress);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessOwnerId);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessCategory);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessDescription);
    await _prefs.remove(SharedPreferencesKeys.selectedBusinessImageUrl);
    state = null;
  }

  /// Refresh the current business data
  Future<void> refreshCurrentBusiness() async {
    if (state != null) {
      try {
        final refreshedBusiness = await _businessService.getBusiness(state!.id);
        if (refreshedBusiness != null) {
          state = refreshedBusiness;
        } else {
          // Business no longer exists, clear selection
          await clearSelectedBusiness();
        }
      } catch (e) {
        // Business no longer exists, clear selection
        await clearSelectedBusiness();
      }
    }
  }

  /// Check if user has access to the current business
  Future<bool> hasAccessToCurrentBusiness(String userId) async {
    if (state == null) return false;
    return _businessService.isUserBusinessMember(state!.id, userId);
  }
}

/// Provider for the business context notifier
final businessContextProvider =
    StateNotifierProvider<BusinessContextNotifier, Business?>((ref) {
  throw UnimplementedError('BusinessContextProvider must be overridden');
});

/// Provider for the currently selected business ID (convenience)
final selectedBusinessIdProvider = Provider<String?>((ref) {
  final business = ref.watch(businessContextProvider);
  return business?.id;
});

/// Provider for the currently selected business name (convenience)
final selectedBusinessNameProvider = Provider<String?>((ref) {
  final business = ref.watch(businessContextProvider);
  return business?.name;
});

/// Provider for checking if a business is selected
final hasSelectedBusinessProvider = Provider<bool>((ref) {
  final business = ref.watch(businessContextProvider);
  return business != null;
});

/// Initialize the business context provider
Future<Override> createBusinessContextProvider() async {
  final prefs = await SharedPreferences.getInstance();
  return businessContextProvider.overrideWith((ref) {
    final businessService = ref.watch(businessServiceProvider);
    return BusinessContextNotifier(businessService, prefs);
  });
}

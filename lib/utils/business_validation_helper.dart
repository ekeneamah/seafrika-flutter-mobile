import 'package:flutter/material.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'package:vendor_app/config/routes.dart';

/// Helper class for validating business selection and redirecting users if necessary
class BusinessValidationHelper {
  /// Checks if business ID and name are present, redirects to business selection if not
  /// Returns true if business data is valid, false if user was redirected
  static Future<bool> validateBusinessSelection(BuildContext context) async {
    final businessId = await BusinessPreferencesHelper.getSelectedBusinessId();
    final businessName =
        await BusinessPreferencesHelper.getSelectedBusinessName();

    // Check if either businessId or businessName is missing or empty
    if (businessId == null ||
        businessId.isEmpty ||
        businessName == null ||
        businessName.isEmpty) {
      // Navigate to business selection screen
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.selectBusiness,
          (route) => false, // Remove all previous routes
        );
      }
      return false;
    }

    return true;
  }

  /// Checks business selection without navigation (for conditional UI)
  static Future<bool> hasValidBusinessSelection() async {
    final businessId = await BusinessPreferencesHelper.getSelectedBusinessId();
    final businessName =
        await BusinessPreferencesHelper.getSelectedBusinessName();

    return businessId != null &&
        businessId.isNotEmpty &&
        businessName != null &&
        businessName.isNotEmpty;
  }

  /// Gets current business info for display
  static Future<Map<String, String?>> getCurrentBusinessInfo() async {
    final businessId = await BusinessPreferencesHelper.getSelectedBusinessId();
    final businessName =
        await BusinessPreferencesHelper.getSelectedBusinessName();

    return {
      'businessId': businessId,
      'businessName': businessName,
    };
  }
}

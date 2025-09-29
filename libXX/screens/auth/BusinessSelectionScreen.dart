import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/models/SelectBusinessInfo.dart';
import 'package:vendor_app/services/navigation_service.dart';

class BusinessSelectionScreen extends StatelessWidget {
  final List<BusinessInfo> businesses;

  const BusinessSelectionScreen({super.key, required this.businesses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Business')),
      body: ListView.builder(
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          final business = businesses[index];
          return ListTile(
            title: Text(business.businessName),
            subtitle: Text('Vendor ID: ${business.vendorId}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(SharedPreferencesKeys.selectedBusinessName,
                  business.businessName);
              await prefs.setString(
                  SharedPreferencesKeys.selectedBusinessOwnerId,
                  business.vendorId);
              NavigationService.navigateToStaffNavigation();
            },
          );
        },
      ),
    );
  }
}

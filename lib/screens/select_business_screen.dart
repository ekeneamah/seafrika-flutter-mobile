import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/models/SelectBusinessInfo.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/services/navigation_service.dart';

class SelectBusinessScreen extends StatelessWidget {
  final List<BusinessInfo> businesses;
  const SelectBusinessScreen({Key? key, required this.businesses})
      : super(key: key);

  Future<void> _onBusinessSelected(
      BuildContext context, BusinessInfo business) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBusinessName', business.businessName);
    await prefs.setString('selectedVendorId', business.vendorId);
    // Navigate to staff navigation screen (replace with your main screen route)
    NavigationService.navigateToReplacement(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Business'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          final business = businesses[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 12),
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.business,
                  size: 32, color: Colors.blueAccent),
              title: Text(business.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Vendor ID: ${business.vendorId}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _onBusinessSelected(context, business),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/widgets/error_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/config/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _language = 'English';
  bool _analyticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled =
            prefs.getBool(SharedPreferencesKeys.notificationsEnabled) ?? true;
        _darkMode = prefs.getBool(SharedPreferencesKeys.darkMode) ?? false;
        _language =
            prefs.getString(SharedPreferencesKeys.language) ?? 'English';
        _analyticsEnabled =
            prefs.getBool(SharedPreferencesKeys.analyticsEnabled) ?? true;
      });
    } catch (e) {
      debugPrint('Load settings error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          SharedPreferencesKeys.notificationsEnabled, _notificationsEnabled);
      await prefs.setBool(SharedPreferencesKeys.darkMode, _darkMode);
      await prefs.setString(SharedPreferencesKeys.language, _language);
      await prefs.setBool(
          SharedPreferencesKeys.analyticsEnabled, _analyticsEnabled);

      // Update services
      if (_notificationsEnabled) {
        await context
            .read<NotificationService>()
            .subscribeToTopic('vendor_updates', vendorId);
      } else {
        await context
            .read<NotificationService>()
            .unsubscribeFromTopic('vendor_updates', vendorId);
      }

      // Log analytics event
      await context.read<AnalyticsService>().logEvent(
        name: 'settings_update',
        parameters: {
          'notifications': _notificationsEnabled,
          'dark_mode': _darkMode,
          'language': _language,
          'analytics': _analyticsEnabled,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      debugPrint('Save settings error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving settings')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(message: 'Loading settings...');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSection(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle:
                    const Text('Receive updates about orders and messages'),
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
              ),
            ],
          ),
          _buildSection(
            title: 'Appearance',
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: _darkMode,
                onChanged: (value) => setState(() => _darkMode = value),
              ),
              ListTile(
                title: const Text('Language'),
                subtitle: Text(_language),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showLanguageDialog,
              ),
            ],
          ),
          _buildSection(
            title: 'Business Management',
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Manage Products'),
                subtitle: const Text('View and manage your product catalog'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.productList);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business_center),
                title: const Text('Business Inventory Management'),
                subtitle: const Text(
                    'Manage all business inventory with bulk operations'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(
                      context, AppRoutes.businessInventoryManagement);
                },
              ),
              ListTile(
                leading: const Icon(Icons.room_service),
                title: const Text('Manage Services'),
                subtitle: const Text('View and manage your service offerings'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.serviceList);
                },
              ),
              ListTile(
                leading: const Icon(Icons.integration_instructions),
                title: const Text('Integrations'),
                subtitle:
                    const Text('Connect with external platforms and services'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.integrationManagement);
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Privacy',
            children: [
              SwitchListTile(
                title: const Text('Analytics'),
                subtitle:
                    const Text('Help improve the app by sharing usage data'),
                value: _analyticsEnabled,
                onChanged: (value) => setState(() => _analyticsEnabled = value),
              ),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to privacy policy
                },
              ),
              ListTile(
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to terms of service
                },
              ),
            ],
          ),
          _buildSection(
            title: 'About',
            children: [
              ListTile(
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to help screen
                },
              ),
              ListTile(
                title: const Text('Rate the App'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Open app store rating
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Admin',
            children: [
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Manage Permissions'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.permissions);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Future<void> _showLanguageDialog() async {
    final languages = ['English', 'Spanish', 'French', 'German'];
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: languages
            .map(
              (language) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, language),
                child: Text(language),
              ),
            )
            .toList(),
      ),
    );

    if (selectedLanguage != null) {
      setState(() => _language = selectedLanguage);
    }
  }
}

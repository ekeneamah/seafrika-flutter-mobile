import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class AddIntegrationScreen extends StatefulWidget {
  const AddIntegrationScreen({super.key});

  @override
  State<AddIntegrationScreen> createState() => _AddIntegrationScreenState();
}

class _AddIntegrationScreenState extends State<AddIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  String? _selectedPlatform;
  final Map<String, TextEditingController> _controllers = {};

  final List<Map<String, dynamic>> _platforms = [
    {
      'id': 'shopify',
      'name': 'Shopify',
      'icon': 'assets/icons/shopify.png',
      'fields': ['apiKey', 'apiSecret', 'storeUrl'],
    },
    {
      'id': 'woocommerce',
      'name': 'WooCommerce',
      'icon': 'assets/icons/woocommerce.png',
      'fields': ['consumerKey', 'consumerSecret', 'storeUrl'],
    },
    {
      'id': 'magento',
      'name': 'Magento',
      'icon': 'assets/icons/magento.png',
      'fields': ['accessToken', 'storeUrl'],
    },
  ];

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(String platformId) {
    final platform = _platforms.firstWhere((p) => p['id'] == platformId);
    for (final field in platform['fields']) {
      _controllers[field] = TextEditingController();
    }
  }

  Future<void> _connectPlatform() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = context.read<IntegrationService>();
      final credentials = {
        for (var entry in _controllers.entries) entry.key: entry.value.text,
      };

      await integrationService.connectPlatform(
        platformId: _selectedPlatform!,
        credentials: credentials,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform connected successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to connect platform: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Integration'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Platform',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedPlatform,
                                decoration: const InputDecoration(
                                  labelText: 'Platform',
                                  border: OutlineInputBorder(),
                                ),
                                items: _platforms.map((platform) {
                                  return DropdownMenuItem<String>(
                                    value: platform['id'] as String,
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          platform['icon'],
                                          width: 24,
                                          height: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(platform['name']),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlatform = value;
                                    if (value != null) {
                                      _initializeControllers(value);
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a platform';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedPlatform != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform Credentials',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                ..._platforms
                                    .firstWhere((p) =>
                                        p['id'] == _selectedPlatform)['fields']
                                    .map<Widget>((field) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: TextFormField(
                                      controller: _controllers[field],
                                      decoration: InputDecoration(
                                        labelText: field
                                            .toString()
                                            .split(RegExp(r'(?=[A-Z])'))
                                            .join(' ')
                                            .toLowerCase()
                                            .replaceFirst(
                                                RegExp(r'^.'),
                                                field
                                                    .toString()[0]
                                                    .toUpperCase()),
                                        border: const OutlineInputBorder(),
                                      ),
                                      obscureText: field.contains('secret') ||
                                          field.contains('key'),
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return 'This field is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _connectPlatform,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: const Text('Connect Platform'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

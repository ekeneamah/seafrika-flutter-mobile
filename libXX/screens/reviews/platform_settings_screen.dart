import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/review.dart';
import 'package:vendor_app/services/review_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class PlatformSettingsScreen extends StatefulWidget {
  final String platformId;

  const PlatformSettingsScreen({
    super.key,
    required this.platformId,
  });

  @override
  State<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends State<PlatformSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  ReviewPlatform? _platform;

  @override
  void initState() {
    super.initState();
    _loadPlatform();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatform() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviewService = context.read<ReviewService>();
      final platform = await reviewService.fetchPlatform(widget.platformId);
      setState(() {
        _platform = platform;
        _nameController.text = platform.name;
        _apiKeyController.text = platform.credentials['apiKey'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load platform settings';
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePlatform() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final reviewService = context.read<ReviewService>();
      await reviewService.updatePlatform(
        platformId: widget.platformId,
        name: _nameController.text,
        credentials: {'apiKey': _apiKeyController.text},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update platform')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Settings'),
      ),
      body: _isLoading
          ? const loading.LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadPlatform,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Platform Name',
                          hintText: 'e.g., Google Business',
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter platform name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'Enter platform API key',
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter API key';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updatePlatform,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Update Platform'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

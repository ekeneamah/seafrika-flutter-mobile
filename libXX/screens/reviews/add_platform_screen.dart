import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/services/review_service.dart';
import 'package:vendor_app/services/navigation_service.dart';

class AddPlatformScreen extends StatefulWidget {
  const AddPlatformScreen({Key? key}) : super(key: key);

  @override
  State<AddPlatformScreen> createState() => _AddPlatformScreenState();
}

class _AddPlatformScreenState extends State<AddPlatformScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _addPlatform() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final reviewService = context.read<ReviewService>();
      await reviewService.connectPlatform(
        name: _nameController.text,
        icon: '0xe87d', // Default platform icon
        credentials: {'apiKey': _apiKeyController.text},
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add platform')),
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
        title: const Text('Add Review Platform'),
      ),
      body: Form(
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
              onPressed: _isLoading ? null : _addPlatform,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Add Platform'),
            ),
          ],
        ),
      ),
    );
  }
}

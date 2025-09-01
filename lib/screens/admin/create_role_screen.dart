import 'package:flutter/material.dart';

class CreateRoleScreen extends StatefulWidget {
  const CreateRoleScreen({Key? key}) : super(key: key);

  @override
  State<CreateRoleScreen> createState() => _CreateRoleScreenState();
}

class _CreateRoleScreenState extends State<CreateRoleScreen> {
  final TextEditingController _roleNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _roleNameController.dispose();
    super.dispose();
  }

  void _saveRole() async {
    if (_roleNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role name cannot be empty.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    // TODO: Save role to backend or Firestore
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role created successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _roleNameController,
              decoration: const InputDecoration(
                labelText: 'Role Name',
                hintText: 'Enter role name',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRole,
                child: Text(_isSaving ? 'Saving...' : 'Create Role'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

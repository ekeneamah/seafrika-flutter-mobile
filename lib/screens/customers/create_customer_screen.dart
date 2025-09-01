import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/responsive_contact_form.dart';

class CreateCustomerScreen extends StatefulWidget {
  final String? customerId;
  final String? initialName;

  const CreateCustomerScreen({super.key, this.customerId, this.initialName});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  Customer? _existingCustomer;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.customerId != null;
    
    // Set initial name if provided
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    
    if (_isEditing) {
      _loadExistingCustomer();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCustomer() async {
    setState(() => _isLoading = true);
    try {
      final customerService = context.read<CustomerService>();
      _existingCustomer =
          await customerService.fetchCustomer(widget.customerId!);

      setState(() {
        _nameController.text = _existingCustomer!.name;
        _emailController.text = _existingCustomer!.email;
        _phoneController.text = _existingCustomer!.phone;
        _addressController.text = _existingCustomer!.address ?? '';
        _notesController.text = _existingCustomer!.notes ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load customer details')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customerService = context.read<CustomerService>();
      Customer? createdOrUpdatedCustomer;

      if (_isEditing) {
        await customerService.updateCustomer(
          widget.customerId!,
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          notes: _notesController.text,
        );
        createdOrUpdatedCustomer = await customerService.fetchCustomer(widget.customerId!);
      } else {
        createdOrUpdatedCustomer = await customerService.createCustomer(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          notes: _notesController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Customer ${_isEditing ? 'updated' : 'created'} successfully'),
          ),
        );
        Navigator.pop(context, createdOrUpdatedCustomer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${_isEditing ? 'update' : 'create'} customer'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ResponsiveContactForm(
              emailController: _emailController,
              phoneController: _phoneController,
              addressController: _addressController,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveCustomer,
                  child: Text(_isEditing ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

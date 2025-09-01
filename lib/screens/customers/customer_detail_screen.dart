import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  bool _isLoading = false;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    try {
      final customerService = context.read<CustomerService>();
      _customer = await customerService.fetchCustomer(widget.customerId);
      setState(() {});
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

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final customerService = context.read<CustomerService>();
      await customerService.deleteCustomer(widget.customerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete customer')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvoice() async {
    NavigationService.navigateToCreateInvoice(customerId: widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (_customer == null) {
      return Scaffold(
        body: error.ErrorView(
          message: 'Customer not found',
          onRetry: _loadCustomer,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                NavigationService.navigateToEditCustomer(widget.customerId),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteCustomer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Name', _customer!.name),
                  _buildInfoRow('Email', _customer!.email),
                  _buildInfoRow('Phone', _customer!.phone),
                  if (_customer!.address != null &&
                      _customer!.address!.isNotEmpty)
                    _buildInfoRow('Address', _customer!.address!),
                  if (_customer!.notes != null && _customer!.notes!.isNotEmpty)
                    _buildInfoRow('Notes', _customer!.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    'Total Purchases',
                    _customer!.analytics['totalPurchases'].toString(),
                  ),
                  _buildMetricRow(
                    'Total Spent',
                    '\$${_customer!.analytics['totalSpent'].toStringAsFixed(2)}',
                  ),
                  _buildMetricRow(
                    'Average Order Value',
                    '\$${_customer!.analytics['averageOrderValue'].toStringAsFixed(2)}',
                  ),
                  _buildMetricRow(
                    'Purchase Frequency',
                    '${_customer!.analytics['purchaseFrequency'].toStringAsFixed(1)} per year',
                  ),
                  _buildMetricRow(
                    'Customer Lifetime',
                    '${_customer!.analytics['customerLifetime'].toStringAsFixed(1)} years',
                  ),
                  _buildMetricRow(
                    'Engagement Score',
                    '${(_customer!.analytics['engagementScore'] * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

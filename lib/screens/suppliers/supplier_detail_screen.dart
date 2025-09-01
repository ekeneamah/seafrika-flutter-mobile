import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/supplier.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/supplier_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  bool _isLoading = false;
  Supplier? _supplier;

  @override
  void initState() {
    super.initState();
    _loadSupplier();
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    try {
      final supplierService = context.read<SupplierService>();
      _supplier = await supplierService.fetchSupplier(widget.supplierId);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load supplier details')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSupplier() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text('Are you sure you want to delete this supplier?'),
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
      final supplierService = context.read<SupplierService>();
      await supplierService.deleteSupplier(widget.supplierId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete supplier')),
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
        body: error.LoadingView(),
      );
    }

    if (_supplier == null) {
      return Scaffold(
        body: error.ErrorView(
          message: 'Supplier not found',
          onRetry: _loadSupplier,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_supplier!.companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                NavigationService.navigateToEditSupplier(widget.supplierId),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSupplier,
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
                  _buildInfoRow('Company', _supplier!.companyName),
                  _buildInfoRow('Contact Person', _supplier!.contactPerson),
                  _buildInfoRow('Email', _supplier!.email),
                  _buildInfoRow('Phone', _supplier!.contactPhone),
                  if (_supplier!.notes != null && _supplier!.notes!.isNotEmpty)
                    _buildInfoRow('Notes', _supplier!.notes!),
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
                    'Performance Metrics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    'Total Orders',
                    _supplier!.performanceMetrics.totalOrders.toString(),
                  ),
                  _buildMetricRow(
                    'On-Time Delivery',
                    '${(_supplier!.performanceMetrics.onTimeDeliveryRate * 100).toStringAsFixed(1)}%',
                  ),
                  _buildMetricRow(
                    'Average Rating',
                    _supplier!.performanceMetrics.averageRating
                        .toStringAsFixed(1),
                  ),
                  _buildMetricRow(
                    'Total Spent',
                    '\$${_supplier!.performanceMetrics.totalSpent.toStringAsFixed(2)}',
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

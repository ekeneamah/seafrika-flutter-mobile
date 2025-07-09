import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/supplier.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/supplier_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class SupplierAnalyticsScreen extends StatefulWidget {
  const SupplierAnalyticsScreen({super.key});

  @override
  State<SupplierAnalyticsScreen> createState() =>
      _SupplierAnalyticsScreenState();
}

class _SupplierAnalyticsScreenState extends State<SupplierAnalyticsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final supplierService = context.read<SupplierService>();
      _analytics = await supplierService.getSupplierAnalytics();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load supplier analytics')),
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

    if (_analytics == null) {
      return Scaffold(
        body: error.ErrorView(
          message: 'Failed to load analytics',
          onRetry: _loadAnalytics,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildPerformanceCard(),
            const SizedBox(height: 16),
            _buildTopSuppliersCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Suppliers',
              _analytics!['totalSuppliers'].toString(),
            ),
            _buildMetricRow(
              'Total Spent',
              '\$${_analytics!['totalSpent'].toStringAsFixed(2)}',
            ),
            _buildMetricRow(
              'Average Rating',
              _analytics!['averageRating'].toStringAsFixed(1),
            ),
            _buildMetricRow(
              'On-Time Delivery',
              '${(_analytics!['onTimeDeliveryRate'] * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final performance = _analytics!['performance'] as Map<String, dynamic>;
    return Card(
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
              'Quality Score',
              '${(performance['qualityScore'] * 100).toStringAsFixed(1)}%',
            ),
            _buildMetricRow(
              'Cost Effectiveness',
              '${(performance['costEffectiveness'] * 100).toStringAsFixed(1)}%',
            ),
            _buildMetricRow(
              'Reliability Score',
              '${(performance['reliabilityScore'] * 100).toStringAsFixed(1)}%',
            ),
            _buildMetricRow(
              'Communication Score',
              '${(performance['communicationScore'] * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSuppliersCard() {
    final topSuppliers = _analytics!['topSuppliers'] as List<dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Suppliers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topSuppliers.map((supplier) => _buildSupplierRow(supplier)),
          ],
        ),
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

  Widget _buildSupplierRow(Map<String, dynamic> supplier) {
    return ListTile(
      title: Text(supplier['companyName']),
      subtitle: Text(
        'Rating: ${supplier['rating'].toStringAsFixed(1)} • Orders: ${supplier['totalOrders']}',
      ),
      trailing: Text(
        '\$${supplier['totalSpent'].toStringAsFixed(2)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => NavigationService.navigateToSupplierDetail(supplier['id']),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class CustomerAnalyticsScreen extends StatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  State<CustomerAnalyticsScreen> createState() =>
      _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState extends State<CustomerAnalyticsScreen> {
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
      final customerService = context.read<CustomerService>();
      _analytics = await customerService.getCustomerAnalytics();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load customer analytics')),
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
        title: const Text('Customer Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildMetricsCard(),
            const SizedBox(height: 16),
            _buildTopCustomersCard(),
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
              'Total Customers',
              _analytics!['totalCustomers'].toString(),
            ),
            _buildMetricRow(
              'Total Spent',
              '\$${_analytics!['totalSpent'].toStringAsFixed(2)}',
            ),
            _buildMetricRow(
              'Total Purchases',
              _analytics!['totalPurchases'].toString(),
            ),
            _buildMetricRow(
              'Average Order Value',
              '\$${_analytics!['averageOrderValue'].toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Average Purchase Frequency',
              '${_analytics!['averagePurchaseFrequency'].toStringAsFixed(1)} per year',
            ),
            _buildMetricRow(
              'Average Customer Lifetime',
              '${_analytics!['averageCustomerLifetime'].toStringAsFixed(1)} years',
            ),
            _buildMetricRow(
              'Average Engagement Score',
              '${(_analytics!['averageEngagementScore'] * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomersCard() {
    final topCustomers = _analytics!['topCustomers'] as List<dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Customers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topCustomers.map((customer) => _buildCustomerRow(customer)),
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

  Widget _buildCustomerRow(Map<String, dynamic> customer) {
    return ListTile(
      title: Text(customer['name']),
      subtitle: Text(
        'Orders: ${customer['totalPurchases']} • Engagement: ${(customer['engagementScore'] * 100).toStringAsFixed(1)}%',
      ),
      trailing: Text(
        '\$${customer['totalSpent'].toStringAsFixed(2)}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => NavigationService.navigateToCustomerDetail(customer['id']),
    );
  }
}

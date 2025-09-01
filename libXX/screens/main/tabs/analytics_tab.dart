import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/analytics_data.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _selectedPeriod = '7d';
  String _selectedMetric = 'sales';
  bool _isLoading = true;
  String? _error;
  AnalyticsData? _analyticsData;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final analyticsService = context.read<AnalyticsService>();
      final data = await analyticsService.fetchAnalyticsData(_selectedPeriod);
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalyticsData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalyticsData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricCards(),
                        const SizedBox(height: 24),
                        _buildPeriodSelector(),
                        const SizedBox(height: 24),
                        _buildChart(),
                        const SizedBox(height: 24),
                        _buildProductPerformance(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricCards() {
    if (_analyticsData == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Sales',
          NumberFormat.currency(symbol: '\$').format(_analyticsData!.totalSales),
          Icons.attach_money,
          Colors.green,
        ),
        _buildMetricCard(
          'Orders',
          _analyticsData!.orderCount.toString(),
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildMetricCard(
          'Views',
          _analyticsData!.viewCount.toString(),
          Icons.visibility,
          Colors.orange,
        ),
        _buildMetricCard(
          'Conversion',
          '${_analyticsData!.conversionRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: '7d',
          label: Text('7D'),
        ),
        ButtonSegment(
          value: '30d',
          label: Text('30D'),
        ),
        ButtonSegment(
          value: '90d',
          label: Text('90D'),
        ),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<String> selection) {
        setState(() => _selectedPeriod = selection.first);
        _loadAnalyticsData();
      },
    );
  }

  Widget _buildChart() {
    if (_analyticsData == null) return const SizedBox.shrink();

    final spots = _analyticsData!.dailySales.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.amount,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Trend',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _analyticsData!.dailySales.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _analyticsData!.dailySales[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPerformance() {
    if (_analyticsData == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Products',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _analyticsData!.topProducts.length,
              itemBuilder: (context, index) {
                final product = _analyticsData!.topProducts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(product.name),
                  subtitle: Text('${product.sales} sales'),
                  trailing: Text(
                    NumberFormat.currency(symbol: '\$').format(product.revenue),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Analytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sales'),
              leading: Radio<String>(
                value: 'sales',
                groupValue: _selectedMetric,
                onChanged: (value) {
                  setState(() => _selectedMetric = value!);
                  Navigator.pop(context);
                  _loadAnalyticsData();
                },
              ),
            ),
            ListTile(
              title: const Text('Orders'),
              leading: Radio<String>(
                value: 'orders',
                groupValue: _selectedMetric,
                onChanged: (value) {
                  setState(() => _selectedMetric = value!);
                  Navigator.pop(context);
                  _loadAnalyticsData();
                },
              ),
            ),
            ListTile(
              title: const Text('Views'),
              leading: Radio<String>(
                value: 'views',
                groupValue: _selectedMetric,
                onChanged: (value) {
                  setState(() => _selectedMetric = value!);
                  Navigator.pop(context);
                  _loadAnalyticsData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
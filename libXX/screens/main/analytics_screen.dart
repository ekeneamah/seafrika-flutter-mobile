import 'package:flutter/material.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/widgets/analytics_card.dart';
import 'package:vendor_app/widgets/line_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _dummyData = [];
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  final Map<String, bool> _visibleMetrics = {
    'sales': true,
    'orders': true,
    'customers': true,
  };

  @override
  void initState() {
    super.initState();
    _updateData();
  }

  void _updateData() {
    final days = _dateRange.end.difference(_dateRange.start).inDays + 1;
    setState(() {
      _dummyData = List.generate(
        days,
        (index) => {
          'date': _dateRange.start.add(Duration(days: index)),
          'sales': (index + 1) * 100.0,
          'orders': (index + 1) * 10,
          'customers': (index + 1) * 5,
        },
      );
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Analytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Sales'),
              value: _visibleMetrics['sales'],
              onChanged: (value) {
                setState(() => _visibleMetrics['sales'] = value ?? true);
                Navigator.pop(context);
              },
            ),
            CheckboxListTile(
              title: const Text('Orders'),
              value: _visibleMetrics['orders'],
              onChanged: (value) {
                setState(() => _visibleMetrics['orders'] = value ?? true);
                Navigator.pop(context);
              },
            ),
            CheckboxListTile(
              title: const Text('Customers'),
              value: _visibleMetrics['customers'],
              onChanged: (value) {
                setState(() => _visibleMetrics['customers'] = value ?? true);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _updateData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_visibleMetrics['sales']!)
                  Expanded(
                    child: AnalyticsCard(
                      title: 'Total Sales',
                      value:
                          '\$${(_dummyData.last['sales'] * 7).toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                  ),
                const SizedBox(width: 16),
                if (_visibleMetrics['orders']!)
                  Expanded(
                    child: AnalyticsCard(
                      title: 'Total Orders',
                      value: (_dummyData.last['orders'] * 7).toString(),
                      icon: Icons.shopping_cart,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_visibleMetrics['customers']!)
                  Expanded(
                    child: AnalyticsCard(
                      title: 'Total Customers',
                      value: (_dummyData.last['customers'] * 7).toString(),
                      icon: Icons.people,
                      color: Colors.orange,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnalyticsCard(
                    title: 'Average Order',
                    value:
                        '\$${(_dummyData.last['sales'] / _dummyData.last['orders']).toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_visibleMetrics['sales']!) ...[
              const Text(
                'Sales Trend',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CustomLineChart(
                  data: _dummyData,
                  valueKey: 'sales',
                  color: AppTheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_visibleMetrics['orders']!) ...[
              const Text(
                'Orders Trend',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CustomLineChart(
                  data: _dummyData,
                  valueKey: 'orders',
                  color: Colors.blue,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_visibleMetrics['customers']!) ...[
              const Text(
                'Customer Growth',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CustomLineChart(
                  data: _dummyData,
                  valueKey: 'customers',
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

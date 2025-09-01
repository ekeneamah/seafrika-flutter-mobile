import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/cost_price_history.dart';
import 'package:vendor_app/providers/cost_price_history_provider.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class CostPriceHistoryScreen extends ConsumerStatefulWidget {
  final String? businessInventoryId;
  
  const CostPriceHistoryScreen({
    super.key,
    this.businessInventoryId,
  });

  @override
  ConsumerState<CostPriceHistoryScreen> createState() => _CostPriceHistoryScreenState();
}

class _CostPriceHistoryScreenState extends ConsumerState<CostPriceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.businessInventoryId != null ? 2 : 3, vsync: this);
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessContext = ref.watch(businessContextProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.businessInventoryId != null 
            ? 'Item Cost History' 
            : 'Cost Price Analytics'),
        backgroundColor: AppTheme.glass,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.earth,
          indicatorColor: AppTheme.primary,
          tabs: [
            const Tab(text: 'History', icon: Icon(Icons.history)),
            if (widget.businessInventoryId == null) ...[
              const Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
              const Tab(text: 'Chart', icon: Icon(Icons.show_chart)),
            ] else
              const Tab(text: 'Chart', icon: Icon(Icons.show_chart)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangePicker(),
          ),
        ],
      ),
      body: businessContext == null 
        ? const Center(
            child: Text('No business context available'),
          )
        : TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryTab(businessContext.id),
              if (widget.businessInventoryId == null) ...[
                _buildAnalyticsTab(businessContext.id),
                _buildChartTab(businessContext.id),
              ] else
                _buildItemChartTab(widget.businessInventoryId!),
            ],
          ),
    );
  }

  Widget _buildHistoryTab(String businessId) {
    final historyProvider = widget.businessInventoryId != null
        ? costPriceHistoryProvider(widget.businessInventoryId!)
        : businessCostPriceHistoryProvider(businessId);

    return ref.watch(historyProvider).when(
      data: (histories) {
        if (histories.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(historyProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: histories.length,
            itemBuilder: (context, index) {
              final history = histories[index];
              return _buildHistoryCard(history);
            },
          ),
        );
      },
      loading: () => const loading_view.LoadingView(
        message: 'Loading cost price history...',
      ),
      error: (error, stackTrace) => error_view.ErrorView(
        message: 'Error loading history: $error',
        onRetry: () => ref.invalidate(historyProvider),
      ),
    );
  }

  Widget _buildAnalyticsTab(String businessId) {
    final analyticsProvider = costPriceAnalyticsProvider({
      'businessId': businessId,
      'startDate': _startDate,
      'endDate': _endDate,
    });

    return ref.watch(analyticsProvider).when(
      data: (analytics) {
        if (analytics.isEmpty) {
          return _buildEmptyState();
        }

        final summary = analytics['summary'] as Map<String, dynamic>;
        final period = analytics['period'] as Map<String, dynamic>;
        final productAnalytics = analytics['productAnalytics'] as Map<String, dynamic>;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(analyticsProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodCard(period),
                const SizedBox(height: 16),
                _buildSummaryCard(summary),
                const SizedBox(height: 16),
                _buildTopProductChangesCard(productAnalytics),
              ],
            ),
          ),
        );
      },
      loading: () => const loading_view.LoadingView(
        message: 'Loading analytics...',
      ),
      error: (error, stackTrace) => error_view.ErrorView(
        message: 'Error loading analytics: $error',
        onRetry: () => ref.invalidate(analyticsProvider),
      ),
    );
  }

  Widget _buildChartTab(String businessId) {
    final historyProvider = businessCostPriceHistoryProvider(businessId);

    return ref.watch(historyProvider).when(
      data: (histories) {
        if (histories.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPriceChangeChart(histories),
              const SizedBox(height: 24),
              _buildCategoryBreakdownChart(histories),
            ],
          ),
        );
      },
      loading: () => const loading_view.LoadingView(
        message: 'Loading chart data...',
      ),
      error: (error, stackTrace) => error_view.ErrorView(
        message: 'Error loading chart data: $error',
        onRetry: () => ref.invalidate(historyProvider),
      ),
    );
  }

  Widget _buildItemChartTab(String businessInventoryId) {
    final historyProvider = costPriceHistoryProvider(businessInventoryId);

    return ref.watch(historyProvider).when(
      data: (histories) {
        if (histories.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildItemPriceChart(histories),
              const SizedBox(height: 24),
              _buildItemStatsCard(histories),
            ],
          ),
        );
      },
      loading: () => const loading_view.LoadingView(
        message: 'Loading item history...',
      ),
      error: (error, stackTrace) => error_view.ErrorView(
        message: 'Error loading item history: $error',
        onRetry: () => ref.invalidate(historyProvider),
      ),
    );
  }

  Widget _buildHistoryCard(CostPriceHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    history.productName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: history.isPriceIncrease 
                        ? Colors.green.withOpacity(0.1)
                        : history.isPriceDecrease 
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    history.formattedPercentageChange,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: history.isPriceIncrease 
                          ? Colors.green 
                          : history.isPriceDecrease 
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Previous Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.earth,
                        ),
                      ),
                      Text(
                        'NGN ${history.previousCostPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: AppTheme.earth,
                  size: 20,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'New Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.earth,
                        ),
                      ),
                      Text(
                        'NGN ${history.newCostPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Reason',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.earth,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    history.changeReason,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(history.changedAt),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.earth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.softGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.history,
              size: 64,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Cost Price History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cost price changes will appear here once you start updating inventory prices.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.earth,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> period) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.earth,
                  ),
                ),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(period['startDate'])} - ${DateFormat('MMM dd, yyyy').format(period['endDate'])}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildSummaryItem(
                'Total Changes',
                summary['totalChanges'].toString(),
                Icons.edit,
                AppTheme.primary,
              ),
              _buildSummaryItem(
                'Price Increases',
                summary['priceIncreases'].toString(),
                Icons.trending_up,
                Colors.green,
              ),
              _buildSummaryItem(
                'Price Decreases',
                summary['priceDecreases'].toString(),
                Icons.trending_down,
                Colors.red,
              ),
              _buildSummaryItem(
                'Significant Changes',
                summary['significantChanges'].toString(),
                Icons.warning,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.earth,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductChangesCard(Map<String, dynamic> productAnalytics) {
    final products = productAnalytics.entries.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Product Changes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...products.map((entry) {
            final productData = entry.value as Map<String, dynamic>;
            final changes = productData['changes'] as List<CostPriceHistory>;
            final lastChange = changes.isNotEmpty ? changes.first : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productData['productName'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${productData['totalChanges']} changes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lastChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lastChange.isPriceIncrease 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lastChange.formattedPercentageChange,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: lastChange.isPriceIncrease ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPriceChangeChart(List<CostPriceHistory> histories) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Changes Over Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                // Chart implementation here
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: histories.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.newCostPrice);
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownChart(List<CostPriceHistory> histories) {
    // Group by change type
    final increases = histories.where((h) => h.isPriceIncrease).length;
    final decreases = histories.where((h) => h.isPriceDecrease).length;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Change Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  if (increases > 0)
                    PieChartSectionData(
                      value: increases.toDouble(),
                      title: 'Increases\n$increases',
                      color: Colors.green,
                      radius: 100,
                    ),
                  if (decreases > 0)
                    PieChartSectionData(
                      value: decreases.toDouble(),
                      title: 'Decreases\n$decreases',
                      color: Colors.red,
                      radius: 100,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPriceChart(List<CostPriceHistory> histories) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Evolution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: histories.reversed.toList().asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.newCostPrice);
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemStatsCard(List<CostPriceHistory> histories) {
    final totalChanges = histories.length;
    final increases = histories.where((h) => h.isPriceIncrease).length;
    final decreases = histories.where((h) => h.isPriceDecrease).length;
    final avgChange = totalChanges > 0 
        ? histories.map((h) => h.priceChange).reduce((a, b) => a + b) / totalChanges
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Changes', totalChanges.toString(), Icons.edit),
              ),
              Expanded(
                child: _buildStatItem('Increases', increases.toString(), Icons.trending_up),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Decreases', decreases.toString(), Icons.trending_down),
              ),
              Expanded(
                child: _buildStatItem('Avg Change', 'NGN ${avgChange.toStringAsFixed(2)}', Icons.analytics),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.softGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.earth,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate!, end: _endDate!),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

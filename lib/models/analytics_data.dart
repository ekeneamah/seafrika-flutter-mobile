class AnalyticsData {
  final double totalSales;
  final int orderCount;
  final int viewCount;
  final double conversionRate;
  final List<DailySales> dailySales;
  final List<TopProduct> topProducts;

  AnalyticsData({
    required this.totalSales,
    required this.orderCount,
    required this.viewCount,
    required this.conversionRate,
    required this.dailySales,
    required this.topProducts,
  });
}

class DailySales {
  final DateTime date;
  final double amount;

  DailySales({
    required this.date,
    required this.amount,
  });
}

class TopProduct {
  final String id;
  final String name;
  final int sales;
  final double revenue;

  TopProduct({
    required this.id,
    required this.name,
    required this.sales,
    required this.revenue,
  });
}

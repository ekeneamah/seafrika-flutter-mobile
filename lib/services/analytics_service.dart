import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:vendor_app/models/analytics_data.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore;
  final FirebaseAnalytics _analytics;
  final String _userId;

  AnalyticsService({
    required FirebaseFirestore firestore,
    required FirebaseAnalytics analytics,
    required String userId,
  })  : _firestore = firestore,
        _analytics = analytics,
        _userId = userId;

  // Fetch analytics data for a specific period
  Future<AnalyticsData> fetchAnalyticsData(String period) async {
    try {
      final DateTime endDate = DateTime.now();
      final DateTime startDate = _getStartDate(period);

      // Fetch sales data
      final salesQuery = await _firestore
          .collection('orders')
          .where('vendorId', isEqualTo: _userId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      // Fetch product views
      final viewsQuery = await _firestore
          .collection('product_views')
          .where('vendorId', isEqualTo: _userId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      // Calculate metrics
      final totalSales = salesQuery.docs.fold<double>(
        0,
        (sum, doc) => sum + (doc.data()['totalAmount'] as num).toDouble(),
      );

      final orderCount = salesQuery.docs.length;
      final viewCount = viewsQuery.docs.length;
      final conversionRate =
          viewCount > 0 ? (orderCount / viewCount) * 100 : 0.0;

      // Get daily sales data for the chart
      final dailySales =
          _calculateDailySales(salesQuery.docs, startDate, endDate);

      // Get top performing products
      final topProducts = await _getTopProducts(startDate, endDate);

      return AnalyticsData(
        totalSales: totalSales,
        orderCount: orderCount,
        viewCount: viewCount,
        conversionRate: conversionRate,
        dailySales: dailySales,
        topProducts: topProducts,
      );
    } catch (e) {
      debugPrint('Error fetching analytics data: $e');
      rethrow;
    }
  }

  DateTime _getStartDate(String period) {
    final now = DateTime.now();
    switch (period) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  List<DailySales> _calculateDailySales(
    List<QueryDocumentSnapshot> salesDocs,
    DateTime startDate,
    DateTime endDate,
  ) {
    final dailySales = <DailySales>[];
    final salesByDay = <DateTime, double>{};

    // Initialize all days with zero sales
    for (var i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final date = startDate.add(Duration(days: i));
      salesByDay[date] = 0;
    }

    // Sum up sales for each day
    for (final doc in salesDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['createdAt'] as Timestamp).toDate();
      final day = DateTime(date.year, date.month, date.day);
      salesByDay[day] =
          (salesByDay[day] ?? 0) + (data['totalAmount'] as num).toDouble();
    }

    // Convert to list of DailySales
    salesByDay.forEach((date, amount) {
      dailySales.add(DailySales(date: date, amount: amount));
    });

    return dailySales;
  }

  Future<List<TopProduct>> _getTopProducts(
      DateTime startDate, DateTime endDate) async {
    try {
      final salesQuery = await _firestore
          .collection('orders')
          .where('vendorId', isEqualTo: _userId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      final productSales = <String, ProductSales>{};

      // Aggregate sales by product
      for (final doc in salesQuery.docs) {
        final items = doc.data()['items'] as List;
        for (final item in items) {
          final productId = item['productId'] as String;
          final quantity = item['quantity'] as int;
          final price = (item['price'] as num).toDouble();

          productSales.update(
            productId,
            (sales) => ProductSales(
              productId: productId,
              name: sales.name,
              totalSales: sales.totalSales + (quantity * price),
              quantity: sales.quantity + quantity,
            ),
            ifAbsent: () => ProductSales(
              productId: productId,
              name: item['name'] as String,
              totalSales: quantity * price,
              quantity: quantity,
            ),
          );
        }
      }

      // Convert to list and sort by total sales
      final topProducts = productSales.values.toList()
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

      return topProducts
          .take(5)
          .map((sales) => TopProduct(
                id: sales.productId,
                name: sales.name,
                sales: sales.quantity,
                revenue: sales.totalSales,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top products: $e');
      return [];
    }
  }

  // Log events
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters?.map((k, v) => MapEntry(k, v as Object)),
    );
  }

  Future<void> logProductView(String productId) async {
    await _analytics.logEvent(
      name: 'product_view',
      parameters: {
        'product_id': productId,
        'vendor_id': _userId,
      },
    );

    // Store in Firestore for analytics
    await _firestore.collection('product_views').add({
      'productId': productId,
      'vendorId': _userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logOrderCreated(String orderId, double amount) async {
    await _analytics.logEvent(
      name: 'order_created',
      parameters: {
        'order_id': orderId,
        'vendor_id': _userId,
        'amount': amount,
      },
    );
  }

  // User events
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics login error: $e');
    }
  }

  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('Analytics signup error: $e');
    }
  }

  Future<void> logProductAdd({
    required String productId,
    required String productName,
    required String category,
  }) async {
    try {
      await _analytics.logAddToCart(
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productName,
            itemCategory: category,
          ),
        ],
      );
    } catch (e) {
      debugPrint('Analytics product add error: $e');
    }
  }

  Future<void> logMediaUpload({
    required String type,
    required int fileSize,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'media_upload',
        parameters: {
          'type': type,
          'file_size': fileSize,
        },
      );
    } catch (e) {
      debugPrint('Analytics media upload error: $e');
    }
  }

  Future<void> logSearch({
    required String searchTerm,
    required int resultCount,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: searchTerm,
        parameters: {
          'result_count': resultCount,
        },
      );
    } catch (e) {
      debugPrint('Analytics search error: $e');
    }
  }

  Future<void> logError({
    required String errorCode,
    required String errorMessage,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_code': errorCode,
          'error_message': errorMessage,
        },
      );
    } catch (e) {
      debugPrint('Analytics error logging error: $e');
    }
  }

  // User properties
  Future<void> setUserProperties({
    required String userId,
    required String userRole,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      await _analytics.setUserProperty(name: 'user_role', value: userRole);
    } catch (e) {
      debugPrint('Analytics set user properties error: $e');
    }
  }
}

class ProductSales {
  final String productId;
  final String name;
  final double totalSales;
  final int quantity;

  ProductSales({
    required this.productId,
    required this.name,
    required this.totalSales,
    required this.quantity,
  });
}

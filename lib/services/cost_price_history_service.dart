import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/cost_price_history.dart';
import 'package:vendor_app/config/collection_references.dart';

class CostPriceHistoryService {
  /// Record a cost price change
  Future<void> recordCostPriceChange({
    required String businessInventoryId,
    required String businessId,
    required String productId,
    required String productName,
    required double previousCostPrice,
    required double newCostPrice,
    required String changeReason,
    required String changedBy,
    String? supplierId,
    String? invoiceId,
    String? purchaseOrderId,
    int quantityPurchased = 0,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Calculate price change and percentage
      final priceChange = newCostPrice - previousCostPrice;
      final percentageChange = previousCostPrice != 0
          ? (priceChange / previousCostPrice) * 100
          : 0.0;

      final historyRecord = CostPriceHistory(
        id: '', // Will be set by Firestore
        businessInventoryId: businessInventoryId,
        businessId: businessId,
        productId: productId,
        productName: productName,
        previousCostPrice: previousCostPrice,
        newCostPrice: newCostPrice,
        priceChange: priceChange,
        percentageChange: percentageChange,
        changeReason: changeReason,
        supplierId: supplierId,
        invoiceId: invoiceId,
        purchaseOrderId: purchaseOrderId,
        quantityPurchased: quantityPurchased,
        changedBy: changedBy,
        additionalData: additionalData,
        changedAt: DateTime.now(),
        status: 'active',
      );

      await CollectionReferences.costPriceHistory.add(historyRecord.toMap());

      print(
          '📊 [CostPriceHistory] Recorded price change: ${historyRecord.formattedPriceChange} (${historyRecord.formattedPercentageChange})');
    } catch (e) {
      print('❌ [CostPriceHistory] Error recording price change: $e');
      rethrow;
    }
  }

  /// Get cost price history for a specific inventory item
  Stream<List<CostPriceHistory>> getCostPriceHistory(
      String businessInventoryId) {
    return CollectionReferences.costPriceHistory
        .where('businessInventoryId', isEqualTo: businessInventoryId)
        .where('status', isEqualTo: 'active')
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CostPriceHistory.fromFirestore(doc))
            .toList());
  }

  /// Get cost price history for all items in a business
  Stream<List<CostPriceHistory>> getBusinessCostPriceHistory(
      String businessId) {
    return CollectionReferences.costPriceHistory
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'active')
        .orderBy('changedAt', descending: true)
        .limit(100) // Limit to recent 100 changes
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CostPriceHistory.fromFirestore(doc))
            .toList());
  }

  /// Get cost price history within a date range
  Stream<List<CostPriceHistory>> getCostPriceHistoryByDateRange({
    required String businessId,
    required DateTime startDate,
    required DateTime endDate,
    String? productId,
  }) {
    Query query = CollectionReferences.costPriceHistory
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'active')
        .where('changedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('changedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    if (productId != null) {
      query = query.where('productId', isEqualTo: productId);
    }

    return query.orderBy('changedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => CostPriceHistory.fromFirestore(doc))
            .toList());
  }

  /// Get analytics for cost price changes
  Future<Map<String, dynamic>> getCostPriceAnalytics({
    required String businessId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final snapshot = await CollectionReferences.costPriceHistory
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'active')
          .where('changedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('changedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final histories = snapshot.docs
          .map((doc) => CostPriceHistory.fromFirestore(doc))
          .toList();

      // Calculate analytics
      final totalChanges = histories.length;
      final increases = histories.where((h) => h.isPriceIncrease).length;
      final decreases = histories.where((h) => h.isPriceDecrease).length;
      final significantChanges =
          histories.where((h) => h.isSignificantChange).length;

      final averagePriceChange = totalChanges > 0
          ? histories.map((h) => h.priceChange).reduce((a, b) => a + b) /
              totalChanges
          : 0.0;

      final averagePercentageChange = totalChanges > 0
          ? histories.map((h) => h.percentageChange).reduce((a, b) => a + b) /
              totalChanges
          : 0.0;

      // Group by product for detailed analysis
      final productAnalytics = <String, Map<String, dynamic>>{};
      for (final history in histories) {
        if (!productAnalytics.containsKey(history.productId)) {
          productAnalytics[history.productId] = {
            'productName': history.productName,
            'changes': <CostPriceHistory>[],
            'totalChanges': 0,
            'averageChange': 0.0,
            'lastChange': null,
          };
        }
        productAnalytics[history.productId]!['changes'].add(history);
      }

      // Calculate per-product analytics
      for (final productId in productAnalytics.keys) {
        final changes =
            productAnalytics[productId]!['changes'] as List<CostPriceHistory>;
        productAnalytics[productId]!['totalChanges'] = changes.length;
        productAnalytics[productId]!['averageChange'] = changes.isNotEmpty
            ? changes.map((h) => h.priceChange).reduce((a, b) => a + b) /
                changes.length
            : 0.0;
        productAnalytics[productId]!['lastChange'] =
            changes.isNotEmpty ? changes.first : null;
      }

      return {
        'period': {
          'startDate': start,
          'endDate': end,
        },
        'summary': {
          'totalChanges': totalChanges,
          'priceIncreases': increases,
          'priceDecreases': decreases,
          'significantChanges': significantChanges,
          'averagePriceChange': averagePriceChange,
          'averagePercentageChange': averagePercentageChange,
        },
        'productAnalytics': productAnalytics,
        'recentChanges': histories.take(10).toList(),
      };
    } catch (e) {
      print('❌ [CostPriceHistory] Error getting analytics: $e');
      return {};
    }
  }

  /// Delete a cost price history record
  Future<void> deleteCostPriceHistory(String historyId) async {
    try {
      await CollectionReferences.costPriceHistory.doc(historyId).update({
        'status': 'deleted',
        'deletedAt': Timestamp.now(),
      });
    } catch (e) {
      print('❌ [CostPriceHistory] Error deleting history: $e');
      rethrow;
    }
  }

  /// Get most recent cost price for an inventory item
  Future<double?> getMostRecentCostPrice(String businessInventoryId) async {
    try {
      final snapshot = await CollectionReferences.costPriceHistory
          .where('businessInventoryId', isEqualTo: businessInventoryId)
          .where('status', isEqualTo: 'active')
          .orderBy('changedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final history = CostPriceHistory.fromFirestore(snapshot.docs.first);
        return history.newCostPrice;
      }
      return null;
    } catch (e) {
      print('❌ [CostPriceHistory] Error getting recent cost price: $e');
      return null;
    }
  }

  /// Check if there are any cost price changes for an item
  Future<bool> hasCostPriceHistory(String businessInventoryId) async {
    try {
      final snapshot = await CollectionReferences.costPriceHistory
          .where('businessInventoryId', isEqualTo: businessInventoryId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ [CostPriceHistory] Error checking history: $e');
      return false;
    }
  }
}

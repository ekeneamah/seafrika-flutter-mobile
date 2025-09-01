import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/cost_price_history.dart';
import 'package:vendor_app/services/cost_price_history_service.dart';

// Service provider
final costPriceHistoryServiceProvider = Provider<CostPriceHistoryService>((ref) {
  return CostPriceHistoryService();
});

// Cost price history for a specific inventory item
final costPriceHistoryProvider = StreamProvider.family<List<CostPriceHistory>, String>((ref, businessInventoryId) {
  final service = ref.watch(costPriceHistoryServiceProvider);
  return service.getCostPriceHistory(businessInventoryId);
});

// Cost price history for entire business
final businessCostPriceHistoryProvider = StreamProvider.family<List<CostPriceHistory>, String>((ref, businessId) {
  final service = ref.watch(costPriceHistoryServiceProvider);
  return service.getBusinessCostPriceHistory(businessId);
});

// Cost price analytics
final costPriceAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) {
  final service = ref.watch(costPriceHistoryServiceProvider);
  return service.getCostPriceAnalytics(
    businessId: params['businessId'] as String,
    startDate: params['startDate'] as DateTime?,
    endDate: params['endDate'] as DateTime?,
  );
});

// Notifier for managing cost price changes
class CostPriceHistoryNotifier extends StateNotifier<AsyncValue<void>> {
  CostPriceHistoryNotifier(this._service) : super(const AsyncValue.data(null));

  final CostPriceHistoryService _service;

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
    state = const AsyncValue.loading();
    
    try {
      await _service.recordCostPriceChange(
        businessInventoryId: businessInventoryId,
        businessId: businessId,
        productId: productId,
        productName: productName,
        previousCostPrice: previousCostPrice,
        newCostPrice: newCostPrice,
        changeReason: changeReason,
        changedBy: changedBy,
        supplierId: supplierId,
        invoiceId: invoiceId,
        purchaseOrderId: purchaseOrderId,
        quantityPurchased: quantityPurchased,
        additionalData: additionalData,
      );
      
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteCostPriceHistory(String historyId) async {
    state = const AsyncValue.loading();
    
    try {
      await _service.deleteCostPriceHistory(historyId);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

final costPriceHistoryNotifierProvider = StateNotifierProvider<CostPriceHistoryNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(costPriceHistoryServiceProvider);
  return CostPriceHistoryNotifier(service);
});

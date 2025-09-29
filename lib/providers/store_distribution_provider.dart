import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/services/store_inventory_service.dart';

/// Provider for store inventory service
final storeInventoryServiceProvider = Provider<StoreInventoryService>((ref) {
  return StoreInventoryService();
});

/// Provider for store distribution data
/// Returns the distribution of a business inventory item across stores
final storeDistributionProvider =
    FutureProvider.family<List<Map<String, dynamic>>, StoreDistributionParams>(
        (ref, params) async {
  final storeInventoryService = ref.read(storeInventoryServiceProvider);
  return storeInventoryService.getStoreDistribution(
    businessId: params.businessId,
    businessInventoryId: params.businessInventoryId,
  );
});

/// Parameters for store distribution provider
class StoreDistributionParams {
  final String businessId;
  final String businessInventoryId;

  const StoreDistributionParams({
    required this.businessId,
    required this.businessInventoryId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreDistributionParams &&
        other.businessId == businessId &&
        other.businessInventoryId == businessInventoryId;
  }

  @override
  int get hashCode => businessId.hashCode ^ businessInventoryId.hashCode;
}

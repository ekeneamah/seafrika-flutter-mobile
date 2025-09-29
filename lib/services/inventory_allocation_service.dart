import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/collection_references.dart';
import '../models/business_inventory.dart';
import '../models/store_inventory.dart';
import '../utils/logger.dart';

/// Service for handling inventory allocation from business to store with proper transaction support
class InventoryAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Allocate inventory items from business to store with atomic transaction
  Future<InventoryAllocationResult> allocateInventoryToStore({
    required String businessId,
    required String businessName,
    required String vendorId,
    required String storeId,
    required String storeName,
    required List<InventoryAllocationItem> items,
  }) async {
    try {
      final result = await _firestore.runTransaction<InventoryAllocationResult>(
        (transaction) async {
          final allocatedItems = <String, int>{};
          final failedItems = <String, String>{};

          // Validate and prepare all operations first
          for (final item in items) {
            try {
              // Get current business inventory
              final businessInventoryDoc = await transaction.get(
                  CollectionReferences.businessInventory
                      .doc(item.businessInventoryId));

              if (!businessInventoryDoc.exists) {
                failedItems[item.businessInventoryId] =
                    'Business inventory item not found';
                continue;
              }

              final businessInv =
                  BusinessInventory.fromFirestore(businessInventoryDoc);

              // Validate sufficient quantity
              if (businessInv.availableQuantity < item.quantity) {
                failedItems[item.businessInventoryId] =
                    'Insufficient quantity. Available: ${businessInv.availableQuantity}, Requested: ${item.quantity}';
                continue;
              }

              // Get current store distribution
              Map<String, dynamic> currentStoreDistribution = {};

              // Handle existing store distribution data
              if (businessInv.storeDistribution != null) {
                AppLogger.info(
                    'Existing store distribution: ${businessInv.storeDistribution}');
                currentStoreDistribution = businessInv.storeDistribution!
                    .map((key, value) => MapEntry(key, value.toMap()));
              } else {
                AppLogger.info(
                    'No existing store distribution, creating new one');
              }

              // Update or create store distribution entry
              final currentQuantity = currentStoreDistribution[storeId] != null
                  ? (currentStoreDistribution[storeId]['allocatedQuantity']
                          as int? ??
                      0)
                  : 0;

              AppLogger.info(
                  'Current quantity for store $storeId: $currentQuantity, adding: ${item.quantity}');

              currentStoreDistribution[storeId] = {
                'storeId': storeId,
                'storeName': storeName,
                'allocatedQuantity': currentQuantity + item.quantity,
                'lastAllocated': FieldValue.serverTimestamp(),
              };

              // Check if item already exists in store inventory collection
              final existingStoreQuery =
                  await CollectionReferences.inventoryForStore(
                          businessId, storeId)
                      .where('productId', isEqualTo: businessInv.productId)
                      .limit(1)
                      .get();

              if (existingStoreQuery.docs.isNotEmpty) {
                // Update existing store inventory
                final existingDoc = existingStoreQuery.docs.first;
                final existingStoreInv =
                    StoreInventory.fromFirestore(existingDoc);

                transaction.update(existingDoc.reference, {
                  'quantity': existingStoreInv.quantity + item.quantity,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'lastUpdatedBy': businessId,
                });
              } else {
                // Create new store inventory record
                final newStoreInventoryRef =
                    CollectionReferences.inventory.doc();
                transaction.set(newStoreInventoryRef, {
                  'id': newStoreInventoryRef.id,
                  'businessId': businessId,
                  'businessName': businessName, // Added missing field
                  'vendorId': vendorId, // Added missing field
                  'storeId': storeId,
                  'storeName': storeName,
                  'businessInventoryId': item.businessInventoryId,
                  'productId': businessInv.productId,
                  'productName': businessInv.productName,
                  'quantity': item.quantity,
                  'minimumQuantity': item.minimumQuantity ?? 1,
                  'unitPrice': businessInv.sellingPrice,
                  'location': null, // Store location - can be set later
                  'notes': businessInv.notes, // Copy from business inventory
                  'category': businessInv.category,
                  'displayImageUrl': businessInv.displayImageUrl,
                  'status': 'active',
                  'isLowStock': (item.quantity <=
                      (item.minimumQuantity ?? 1)), // Added computed field
                  'totalValue': (item.quantity *
                      businessInv.sellingPrice), // Added computed field
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'lastUpdatedBy': businessId,
                });
              }

              // Update business inventory (reduce available quantity and update store distribution)
              AppLogger.info(
                  'Updating business inventory with store distribution: $currentStoreDistribution');

              transaction.update(businessInventoryDoc.reference, {
                'availableQuantity':
                    businessInv.availableQuantity - item.quantity,
                'storeDistribution': currentStoreDistribution,
                'updatedAt': FieldValue.serverTimestamp(),
                'lastUpdatedBy': businessId,
              });

              allocatedItems[item.businessInventoryId] = item.quantity;
            } catch (e) {
              failedItems[item.businessInventoryId] = 'Allocation error: $e';
              AppLogger.error('Inventory allocation error', e);
            }
          }

          return InventoryAllocationResult(
            success: allocatedItems.isNotEmpty,
            allocatedItems: allocatedItems,
            failedItems: failedItems,
            totalRequested: items.length,
            totalAllocated: allocatedItems.length,
          );
        },
        timeout: const Duration(seconds: 30),
      );

      return result;
    } catch (e) {
      AppLogger.error('Transaction failed during inventory allocation', e);
      return InventoryAllocationResult(
        success: false,
        allocatedItems: {},
        failedItems: {
          for (final item in items)
            item.businessInventoryId: 'Transaction failed: $e'
        },
        totalRequested: items.length,
        totalAllocated: 0,
      );
    }
  }

  /// Validate inventory availability before allocation
  Future<InventoryValidationResult> validateInventoryAllocation({
    required String businessId,
    required List<InventoryAllocationItem> items,
  }) async {
    try {
      final validItems = <InventoryAllocationItem>[];
      final invalidItems = <String, String>{};

      for (final item in items) {
        final doc = await CollectionReferences.businessInventory
            .doc(item.businessInventoryId)
            .get();

        if (!doc.exists) {
          invalidItems[item.businessInventoryId] = 'Item not found';
          continue;
        }

        final businessInv = BusinessInventory.fromFirestore(doc);

        if (businessInv.businessId != businessId) {
          invalidItems[item.businessInventoryId] = 'Access denied';
          continue;
        }

        if (businessInv.availableQuantity < item.quantity) {
          invalidItems[item.businessInventoryId] =
              'Insufficient quantity. Available: ${businessInv.availableQuantity}';
          continue;
        }

        if (item.quantity <= 0) {
          invalidItems[item.businessInventoryId] = 'Invalid quantity';
          continue;
        }

        validItems.add(item);
      }

      return InventoryValidationResult(
        isValid: invalidItems.isEmpty,
        validItems: validItems,
        invalidItems: invalidItems,
      );
    } catch (e) {
      AppLogger.error('Inventory validation failed', e);
      return InventoryValidationResult(
        isValid: false,
        validItems: [],
        invalidItems: {
          for (final item in items)
            item.businessInventoryId: 'Validation error: $e'
        },
      );
    }
  }

  /// Get real-time inventory availability
  Stream<Map<String, int>> getInventoryAvailabilityStream({
    required String businessId,
    required List<String> businessInventoryIds,
  }) {
    return CollectionReferences.businessInventoryForBusiness(businessId)
        .where(FieldPath.documentId, whereIn: businessInventoryIds)
        .snapshots()
        .map((snapshot) {
      final availability = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        availability[doc.id] =
            (data['availableQuantity'] as num?)?.toInt() ?? 0;
      }
      return availability;
    });
  }
}

/// Data class for inventory allocation items
class InventoryAllocationItem {
  final String businessInventoryId;
  final int quantity;
  final int? minimumQuantity;

  const InventoryAllocationItem({
    required this.businessInventoryId,
    required this.quantity,
    this.minimumQuantity,
  });

  @override
  String toString() =>
      'InventoryAllocationItem(id: $businessInventoryId, qty: $quantity)';
}

/// Result of inventory allocation operation
class InventoryAllocationResult {
  final bool success;
  final Map<String, int> allocatedItems;
  final Map<String, String> failedItems;
  final int totalRequested;
  final int totalAllocated;

  const InventoryAllocationResult({
    required this.success,
    required this.allocatedItems,
    required this.failedItems,
    required this.totalRequested,
    required this.totalAllocated,
  });

  bool get hasFailures => failedItems.isNotEmpty;
  bool get isPartialSuccess =>
      totalAllocated > 0 && totalAllocated < totalRequested;

  String get summaryMessage {
    if (success && !hasFailures) {
      return 'Successfully allocated $totalAllocated items to store';
    } else if (isPartialSuccess) {
      return 'Allocated $totalAllocated of $totalRequested items. ${failedItems.length} items failed';
    } else {
      return 'Failed to allocate items to store';
    }
  }
}

/// Result of inventory validation
class InventoryValidationResult {
  final bool isValid;
  final List<InventoryAllocationItem> validItems;
  final Map<String, String> invalidItems;

  const InventoryValidationResult({
    required this.isValid,
    required this.validItems,
    required this.invalidItems,
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_inventory.dart';
import '../config/collection_references.dart';
import '../services/cost_price_history_service.dart';

class BusinessInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream business inventory items filtered by businessId
  Stream<QuerySnapshot> streamBusinessInventory({
    required String businessId,
    String? searchQuery,
    String? category,
    DocumentSnapshot? lastDocument,
    int limit = 50,
  }) {
    print('📦 [BusinessInventoryService] Streaming inventory for business: $businessId');
    print('📦 [BusinessInventoryService] Search query: $searchQuery, Category: $category, Limit: $limit');
    
    Query query;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Use centralized search reference
      print('📦 [BusinessInventoryService] Using search query');
      query = CollectionReferences.searchBusinessInventoryByName(businessId, searchQuery);
    } else if (category != null && category != 'All') {
      // Use centralized category reference
      print('📦 [BusinessInventoryService] Using category filter: $category');
      query = CollectionReferences.businessInventoryByCategory(businessId, category);
    } else {
      // Use centralized business inventory reference
      print('📦 [BusinessInventoryService] Using active business inventory');
      query = CollectionReferences.activeBusinessInventory(businessId)
          .orderBy('productName');
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    print('📦 [BusinessInventoryService] Final query setup complete');
    return query.limit(limit).snapshots();
  }

  /// Create or update business inventory from product
  /// If product already exists for this business, it will update the existing record
  Future<String> createBusinessInventory({
    required String businessId,
    required String productId,
    required String productName,
    required String category,
    required int totalQuantity,
    required double costPrice,
    required double sellingPrice,
    String? supplierId,
    String? purchaseOrderId,
    String? invoiceId,
    String? displayImageUrl,
    Map<String, dynamic>? purchaseDetails,
  }) async {
    // Check if product already exists for this business
    final existingQuery = await CollectionReferences.businessInventory
        .where('businessId', isEqualTo: businessId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    final now = DateTime.now();

    if (existingQuery.docs.isNotEmpty) {
      // Update existing business inventory
      final existingDoc = existingQuery.docs.first;
      final existingData = existingDoc.data();
      final currentTotal = existingData['totalQuantity'] as int;
      final currentAvailable = existingData['availableQuantity'] as int;
      final currentCostPrice = (existingData['costPrice'] as num?)?.toDouble() ?? 0.0;
      
      // Add new quantity to existing quantities
      final newTotalQuantity = currentTotal + totalQuantity;
      final newAvailableQuantity = currentAvailable + totalQuantity;
      
      // Record cost price history if cost price has changed
      if (costPrice != currentCostPrice) {
        final costPriceHistoryService = CostPriceHistoryService();
        await costPriceHistoryService.recordCostPriceChange(
          businessInventoryId: existingDoc.id,
          businessId: businessId,
          productId: productId,
          productName: productName,
          previousCostPrice: currentCostPrice,
          newCostPrice: costPrice,
          changeReason: 'Inventory restock - cost price updated',
          changedBy: 'system', // TODO: Use actual user ID when available
          quantityPurchased: totalQuantity,
          additionalData: {
            'source': 'add_inventory',
            'added_quantity': totalQuantity,
            'total_quantity_before': currentTotal,
            'total_quantity_after': newTotalQuantity,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
      
      await existingDoc.reference.update({
        'totalQuantity': newTotalQuantity,
        'availableQuantity': newAvailableQuantity,
        'costPrice': costPrice, // Update with latest cost price
        'sellingPrice': sellingPrice, // Update with latest selling price
        'totalValue': newTotalQuantity * costPrice,
        'category': category, // Update category if changed
        'productName': productName, // Update product name if changed
        'supplierId': supplierId,
        'purchaseOrderId': purchaseOrderId,
        'invoiceId': invoiceId,
        'displayImageUrl': displayImageUrl, // Update image URL
        'purchaseDetails': purchaseDetails,
        'updatedAt': Timestamp.fromDate(now),
        'status': 'active',
      });

      return existingDoc.id;
    } else {
      // Create new business inventory record
      final docRef = CollectionReferences.businessInventory.doc();

      await docRef.set({
        'businessId': businessId,
        'productId': productId,
        'productName': productName,
        'category': category,
        'totalQuantity': totalQuantity,
        'availableQuantity': totalQuantity, // For store allocation tracking
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'totalValue': totalQuantity * costPrice,
        'supplierId': supplierId,
        'purchaseOrderId': purchaseOrderId,
        'invoiceId': invoiceId,
        'displayImageUrl': displayImageUrl, // Add image URL
        'purchaseDetails': purchaseDetails,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'status': 'active',
      });

      // Record initial cost price history for new inventory
      final costPriceHistoryService = CostPriceHistoryService();
      await costPriceHistoryService.recordCostPriceChange(
        businessInventoryId: docRef.id,
        businessId: businessId,
        productId: productId,
        productName: productName,
        previousCostPrice: 0.0,
        newCostPrice: costPrice,
        changeReason: 'Initial inventory creation',
        changedBy: 'system', // TODO: Use actual user ID when available
        quantityPurchased: totalQuantity,
        additionalData: {
          'source': 'new_inventory',
          'initial_quantity': totalQuantity,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return docRef.id;
    }
  }

  /// Get business inventory item by ID
  Future<BusinessInventory?> getBusinessInventoryById(String id) async {
    final doc = await CollectionReferences.businessInventory.doc(id).get();
    if (!doc.exists) return null;
    return BusinessInventory.fromFirestore(doc);
  }

  /// Get business inventory item by productId and businessId
  Future<BusinessInventory?> getBusinessInventoryByProductId({
    required String businessId,
    required String productId,
  }) async {
    final query = await CollectionReferences.businessInventory
        .where('businessId', isEqualTo: businessId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return BusinessInventory.fromFirestore(query.docs.first);
  }

  /// Update available quantity when allocating to stores
  Future<void> updateAvailableQuantity({
    required String businessInventoryId,
    required int quantityChange, // Negative when allocating to store
  }) async {
    final docRef = CollectionReferences.businessInventory.doc(businessInventoryId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) throw Exception('Business inventory not found');
      
      final data = doc.data() as Map<String, dynamic>;
      final currentAvailable = data['availableQuantity'] as int;
      final newAvailable = currentAvailable + quantityChange;
      
      if (newAvailable < 0) {
        throw Exception('Insufficient inventory available');
      }
      
      transaction.update(docRef, {
        'availableQuantity': newAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Update business inventory item and record cost price history if changed
  Future<void> updateBusinessInventory({
    required String businessInventoryId,
    required Map<String, dynamic> updateData,
    String? changeReason,
  }) async {
    // Get current data to compare cost prices
    final currentDoc = await CollectionReferences.businessInventory
        .doc(businessInventoryId)
        .get();
    
    if (!currentDoc.exists) {
      throw Exception('Business inventory item not found');
    }
    
    final currentData = currentDoc.data()!;
    final currentCostPrice = (currentData['costPrice'] as num?)?.toDouble() ?? 0.0;
    final newCostPrice = (updateData['costPrice'] as num?)?.toDouble();
    
    // Record cost price history if cost price has changed
    if (newCostPrice != null && newCostPrice != currentCostPrice) {
      final businessId = currentData['businessId'] as String;
      final productId = currentData['productId'] as String;
      final productName = currentData['productName'] as String;
      
      final costPriceHistoryService = CostPriceHistoryService();
      await costPriceHistoryService.recordCostPriceChange(
        businessInventoryId: businessInventoryId,
        businessId: businessId,
        productId: productId,
        productName: productName,
        previousCostPrice: currentCostPrice,
        newCostPrice: newCostPrice,
        changeReason: changeReason ?? 'Inventory update',
        changedBy: 'system', // TODO: Use actual user ID when available
        additionalData: {
          'source': 'business_inventory_update',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
    
    // Update the business inventory
    await currentDoc.reference.update({
      ...updateData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get low stock items using centralized reference
  Future<List<BusinessInventory>> getLowStockItems({
    required String businessId,
    int threshold = 10,
  }) async {
    final snapshot = await CollectionReferences.lowStockBusinessInventory(businessId)
        .orderBy('availableQuantity')
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => BusinessInventory.fromFirestore(doc))
        .toList();
  }

  /// Add quantity to existing business inventory
  /// This method handles restocking operations with optional cost price updates
  Future<bool> addQuantityToInventory({
    required String businessInventoryId,
    required String businessId,
    required int quantityToAdd,
    required double costPrice,
    double? sellingPrice,
    String? supplierId,
    String? purchaseOrderId,
    String? invoiceId,
    String? notes,
    Map<String, dynamic>? purchaseDetails,
  }) async {
    try {
      final docRef = CollectionReferences.businessInventory.doc(businessInventoryId);
      
      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('Business inventory not found');
        }
        
        final currentData = doc.data() as Map<String, dynamic>;
        final currentTotalQuantity = (currentData['totalQuantity'] as int? ?? 0);
        final currentAvailableQuantity = (currentData['availableQuantity'] as int? ?? 0);
        
        // Calculate new quantities
        final newTotalQuantity = currentTotalQuantity + quantityToAdd;
        final newAvailableQuantity = currentAvailableQuantity + quantityToAdd;
        
        // Prepare update data
        final updateData = <String, dynamic>{
          'totalQuantity': newTotalQuantity,
          'availableQuantity': newAvailableQuantity,
          'costPrice': costPrice,
          'totalValue': newTotalQuantity * costPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // Update selling price if provided
        if (sellingPrice != null) {
          updateData['sellingPrice'] = sellingPrice;
        }
        
        // Update supplier information if provided
        if (supplierId != null) {
          updateData['supplierId'] = supplierId;
        }
        
        if (purchaseOrderId != null) {
          updateData['purchaseOrderId'] = purchaseOrderId;
        }
        
        if (invoiceId != null) {
          updateData['invoiceId'] = invoiceId;
        }
        
        if (purchaseDetails != null) {
          updateData['purchaseDetails'] = purchaseDetails;
        }
        
        // Update the inventory
        transaction.update(docRef, updateData);
        
        return true;
      });
    } catch (e) {
      print('Error adding quantity to inventory: $e');
      return false;
    } finally {
      // Record cost price history if cost price has changed or quantity added
      try {
        final doc = await CollectionReferences.businessInventory.doc(businessInventoryId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final productId = data['productId'] as String;
          final productName = data['productName'] as String;
          final currentCostPrice = (data['costPrice'] as num?)?.toDouble() ?? 0.0;
          
          final costPriceHistoryService = CostPriceHistoryService();
          await costPriceHistoryService.recordCostPriceChange(
            businessInventoryId: businessInventoryId,
            businessId: businessId,
            productId: productId,
            productName: productName,
            previousCostPrice: currentCostPrice != costPrice ? currentCostPrice : costPrice,
            newCostPrice: costPrice,
            changeReason: notes ?? 'Inventory restock - quantity added',
            changedBy: 'system', // TODO: Use actual user ID when available
            quantityPurchased: quantityToAdd,
            additionalData: {
              'source': 'add_quantity',
              'added_quantity': quantityToAdd,
              'supplier_id': supplierId,
              'purchase_order_id': purchaseOrderId,
              'invoice_id': invoiceId,
              'notes': notes,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      } catch (e) {
        print('Error recording cost price history: $e');
        // Don't fail the main operation if history recording fails
      }
    }
  }
}

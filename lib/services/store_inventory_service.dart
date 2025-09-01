import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store_inventory.dart';
import '../config/collection_references.dart';
import '../config/collection_names.dart';

final storeInventoryServiceProvider = Provider<StoreInventoryService>((ref) {
  return StoreInventoryService();
});

// Provider for store inventory stream
final storeInventoryStreamProvider = StreamProvider.family<List<StoreInventory>,
    ({String businessId, String storeId})>((ref, params) {
  final service = ref.watch(storeInventoryServiceProvider);
  return service
      .streamStoreInventory(
        businessId: params.businessId,
        storeId: params.storeId,
      )
      .map((snapshot) => snapshot.docs
          .map((doc) => StoreInventory.fromFirestore(doc))
          .toList());
});

class StoreInventoryService {
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Map<String, List<StoreInventory>> _cache = {};

  String _getCacheKey(String businessId, String storeId) {
    return '${businessId}_$storeId';
  }

  /// Create or update store inventory from business inventory
  /// If product already exists in this store, it will update the existing record
  Future<void> createStoreInventory({
    required String businessId,
    required String businessName,
    required String vendorId,
    required String storeId,
    required String businessInventoryId,
    required String productId,
    required String productName,
    required int quantity,
    required int minimumQuantity,
    required double unitPrice,
    String? location,
    String? notes,
    String? displayImageUrl,
    String category = 'Uncategorized',
  }) async {
    final now = DateTime.now();
    
    // Check if product already exists in this store
    final existingStoreInventory = await getStoreInventoryByProductId(
      businessId: businessId,
      storeId: storeId,
      productId: productId,
    );

    await _firestore.runTransaction((transaction) async {
      if (existingStoreInventory != null) {
        // Update existing store inventory
        final existingDoc = _firestore
            .collection(CollectionNames.inventory)
            .doc(existingStoreInventory.id);
        
        final newQuantity = existingStoreInventory.quantity + quantity;
        final isLowStock = newQuantity <= minimumQuantity;
        final totalValue = newQuantity * unitPrice;
        final status = newQuantity > 0 ? 'active' : 'outOfStock';
        
        transaction.update(existingDoc, {
          'quantity': newQuantity,
          'minimumQuantity': minimumQuantity, // Update minimum quantity
          'unitPrice': unitPrice, // Update with latest unit price
          'location': location,
          'notes': notes,
          'category': category, // Update category if changed
          'displayImageUrl': displayImageUrl,
          'updatedAt': Timestamp.fromDate(now),
          // Update pre-computed fields
          'isLowStock': isLowStock,
          'totalValue': totalValue,
          'status': status,
        });

        // Update cache if exists
        final cacheKey = _getCacheKey(businessId, storeId);
        if (_cache.containsKey(cacheKey)) {
          final updatedItems = _cache[cacheKey]!.map((item) {
            if (item.id == existingStoreInventory.id) {
              return item.copyWith(
                quantity: newQuantity,
                minimumQuantity: minimumQuantity,
                unitPrice: unitPrice,
                location: location,
                notes: notes,
                category: category,
                updatedAt: now,
                displayImageUrl: displayImageUrl,
                isLowStock: isLowStock,
                totalValue: totalValue,
                status: status,
              );
            }
            return item;
          }).toList();
          _cache[cacheKey] = updatedItems;
        }
      } else {
        // Create new store inventory record
        final docRef = CollectionReferences.inventory.doc();
        
        // Pre-compute values to avoid client-side calculations
        final isLowStock = quantity <= minimumQuantity;
        final totalValue = quantity * unitPrice;
        final status = quantity > 0 ? 'active' : 'outOfStock';

        transaction.set(docRef, {
          'businessId': businessId,
          'businessName': businessName,
          'vendorId': vendorId,
          'storeId': storeId,
          'businessInventoryId': businessInventoryId, // Link to business inventory
          'productId': productId,
          'productName': productName,
          'quantity': quantity,
          'minimumQuantity': minimumQuantity,
          'unitPrice': unitPrice,
          'location': location,
          'notes': notes,
          'category': category,
          'displayImageUrl': displayImageUrl,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          // Pre-computed fields for read cost optimization
          'isLowStock': isLowStock,
          'totalValue': totalValue,
          'status': status,
        });

        // Update cache if exists
        final cacheKey = _getCacheKey(businessId, storeId);
        if (_cache.containsKey(cacheKey)) {
          final newItem = StoreInventory(
            id: docRef.id,
            businessId: businessId,
            businessName: businessName,
            vendorId: vendorId,
            storeId: storeId,
            businessInventoryId: businessInventoryId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            minimumQuantity: minimumQuantity,
            unitPrice: unitPrice,
            location: location,
            notes: notes,
            category: category,
            createdAt: now,
            updatedAt: now,
            displayImageUrl: displayImageUrl,
            isLowStock: isLowStock,
            totalValue: totalValue,
            status: status,
          );
          _cache[cacheKey] = [..._cache[cacheKey]!, newItem];
        }
      }

      // Update business inventory available quantity and store distribution
      final businessInventoryRef = CollectionReferences.businessInventory
          .doc(businessInventoryId);
      
      // Get current business inventory to update store distribution
      final businessInventoryDoc = await transaction.get(businessInventoryRef);
      if (!businessInventoryDoc.exists) {
        throw Exception('Business inventory not found');
      }
      
      final businessData = businessInventoryDoc.data()!;
      final currentStoreDistribution = businessData['storeDistribution'] as Map<String, dynamic>? ?? {};
      
      // Calculate the quantity for store distribution
      final storeQuantity = existingStoreInventory != null 
          ? existingStoreInventory.quantity + quantity 
          : quantity;
      
      // Update store distribution with new allocation
      currentStoreDistribution[storeId] = {
        'storeId': storeId,
        'storeName': businessName, // Use businessName as placeholder for store name
        'allocatedQuantity': storeQuantity,
        'lastAllocated': FieldValue.serverTimestamp(),
      };
      
      transaction.update(businessInventoryRef, {
        'availableQuantity': FieldValue.increment(-quantity),
        'storeDistribution': currentStoreDistribution,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreInventory({
    required String businessId,
    required String storeId,
    String? searchQuery,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) {
    // Cancel existing subscription if any
    _subscription?.cancel();

    Query<Map<String, dynamic>> query;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Use centralized search reference with business and store context
      query = CollectionReferences.searchInventoryByName(businessId, storeId, searchQuery)
          .limit(25); // Reduce limit for search queries
    } else {
      // Use centralized active inventory reference for business and store
      query = CollectionReferences.activeInventoryForStore(businessId, storeId)
          .orderBy('productName') // Better for alphabetical sorting
          .limit(50); // Reasonable limit to control read costs
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    // Set up subscription and cache results
    _subscription = query.snapshots().listen((snapshot) {
      final cacheKey = _getCacheKey(businessId, storeId);
      _cache[cacheKey] = snapshot.docs
          .map((doc) => StoreInventory.fromFirestore(doc))
          .toList();
    });

    return query.snapshots();
  }

  Future<StoreInventory?> getStoreInventoryById({
    required String businessId,
    required String storeId,
    required String inventoryId,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(businessId, storeId);
    if (_cache.containsKey(cacheKey)) {
      final cachedItem = _cache[cacheKey]!.firstWhere(
        (item) => item.id == inventoryId,
        orElse: () => throw Exception('Item not found'),
      );
      return cachedItem;
    }

    // If not in cache, fetch from Firestore
    final doc = await _firestore
        .collection(CollectionNames.inventory)
        .doc(inventoryId)
        .get();

    if (!doc.exists) return null;
    return StoreInventory.fromFirestore(doc);
  }

  // Cost-efficient method to get low stock items using pre-computed field
  Future<List<StoreInventory>> getLowStockItems({
    required String businessId,
    required String storeId,
  }) async {
    final querySnapshot = await _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('storeId', isEqualTo: storeId)
        .where('isLowStock', isEqualTo: true) // Pre-computed field
        .where('status', isEqualTo: 'active')
        .orderBy('quantity') // Show lowest stock first
        .limit(20) // Control read costs
        .get();

    return querySnapshot.docs
        .map((doc) => StoreInventory.fromFirestore(doc))
        .toList();
  }

  // Business-wide inventory queries (efficient with flat structure)
  Future<List<StoreInventory>> getBusinessInventory({
    required String businessId,
    int limit = 100,
  }) async {
    final querySnapshot = await _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'active')
        .orderBy('productName')
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => StoreInventory.fromFirestore(doc))
        .toList();
  }

  // Get inventory by category across all stores in business
  Future<List<StoreInventory>> getInventoryByCategory({
    required String businessId,
    required String category,
  }) async {
    final querySnapshot = await _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: 'active')
        .orderBy('productName')
        .limit(50)
        .get();

    return querySnapshot.docs
        .map((doc) => StoreInventory.fromFirestore(doc))
        .toList();
  }

  // Search across all business inventory
  Future<List<StoreInventory>> searchBusinessInventory({
    required String businessId,
    required String searchTerm,
  }) async {
    final querySnapshot = await _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('productName', isGreaterThanOrEqualTo: searchTerm)
        .where('productName', isLessThanOrEqualTo: searchTerm + '\uf8ff')
        .where('status', isEqualTo: 'active')
        .limit(30)
        .get();

    return querySnapshot.docs
        .map((doc) => StoreInventory.fromFirestore(doc))
        .toList();
  }

  Future<void> updateStoreInventory({
    required String inventoryId,
    required Map<String, dynamic> data,
  }) async {
    // Pre-compute updated values
    final quantity = data['quantity'] as int?;
    final minimumQuantity = data['minimumQuantity'] as int?;
    final unitPrice = data['unitPrice'] as double?;
    
    Map<String, dynamic> updateData = {
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    // Update pre-computed fields if quantity or price changed
    if (quantity != null && minimumQuantity != null) {
      updateData['isLowStock'] = quantity <= minimumQuantity;
      updateData['status'] = quantity > 0 ? 'active' : 'outOfStock';
    }
    
    if (quantity != null && unitPrice != null) {
      updateData['totalValue'] = quantity * unitPrice;
    }

    await _firestore
        .collection(CollectionNames.inventory)
        .doc(inventoryId)
        .update(updateData);

    // Invalidate cache for affected business/store
    _cache.clear(); // Simple approach - clear all cache on update
  }

  Future<void> updateStoreInventoryQuantity({
    required String inventoryId,
    required int quantity,
  }) async {
    // Get current item to calculate pre-computed fields
    final doc = await _firestore
        .collection(CollectionNames.inventory)
        .doc(inventoryId)
        .get();

    if (!doc.exists) return;

    final currentData = doc.data()!;
    final minimumQuantity = currentData['minimumQuantity'] as int;
    final unitPrice = (currentData['unitPrice'] as num).toDouble();

    await _firestore
        .collection(CollectionNames.inventory)
        .doc(inventoryId)
        .update({
      'quantity': quantity,
      'isLowStock': quantity <= minimumQuantity,
      'totalValue': quantity * unitPrice,
      'status': quantity > 0 ? 'active' : 'outOfStock',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Clear cache to force refresh
    _cache.clear();
  }

  Future<void> deleteStoreInventory({
    required String inventoryId,
  }) async {
    await _firestore
        .collection(CollectionNames.inventory)
        .doc(inventoryId)
        .delete();

    // Clear cache to force refresh
    _cache.clear();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getStoreInventory({
    required String businessId,
    required String storeId,
    String? searchQuery,
  }) async {
  Query<Map<String, dynamic>> query = _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('storeId', isEqualTo: storeId)
        .where('status', isEqualTo: 'active')
        .orderBy('productName');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

  return await query.get().timeout(const Duration(seconds: 20));
  }

  Future<StoreInventory?> getStoreInventoryByProductId({
    required String businessId,
    required String storeId,
    required String productId,
  }) async {
    print('getStoreInventoryByProductId: $businessId, $storeId, $productId');
    final querySnapshot = await _firestore
        .collection(CollectionNames.inventory)
        .where('businessId', isEqualTo: businessId)
        .where('storeId', isEqualTo: storeId)
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return StoreInventory.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  }

  /// Fetch multiple store inventory records by a list of productIds for a store and business.
  /// Returns a map of productId -> StoreInventory.
  Future<Map<String, StoreInventory>> getStoreInventoriesByProductIds({
    required String businessId,
    required String storeId,
    required List<String> productIds,
  }) async {
    if (productIds.isEmpty) return {};
    // Firestore whereIn supports up to 10 values per query
    final Map<String, StoreInventory> result = {};
    for (var i = 0; i < productIds.length; i += 10) {
      final batch = productIds.skip(i).take(10).toList();
      final querySnapshot = await _firestore
          .collection(CollectionNames.inventory)
          .where('businessId', isEqualTo: businessId)
          .where('storeId', isEqualTo: storeId)
          .where('productId', whereIn: batch)
          .where('status', isEqualTo: 'active')
          .get();
      for (final doc in querySnapshot.docs) {
        final storeInventory = StoreInventory.fromFirestore(doc);
        result[storeInventory.productId] = storeInventory;
      }
    }
    return result;
  }

  /// Get store distribution for a business inventory item
  /// Returns list of stores with their quantities and last updated timestamps
  Future<List<Map<String, dynamic>>> getStoreDistribution({
    required String businessId,
    required String businessInventoryId,
  }) async {
    try {
      // Get store inventory records for this business inventory item
      final inventorySnapshot = await CollectionReferences.inventory
          .where('businessId', isEqualTo: businessId)
          .where('businessInventoryId', isEqualTo: businessInventoryId)
          .orderBy('updatedAt', descending: true)
          .get();

      if (inventorySnapshot.docs.isEmpty) {
        return [];
      }

      // Get all unique store IDs from the inventory records
      final storeIds = inventorySnapshot.docs
          .map((doc) => doc.data()['storeId'] as String?)
          .where((storeId) => storeId != null && storeId.isNotEmpty)
          .toSet()
          .toList();

      if (storeIds.isEmpty) {
        return [];
      }

      // Fetch actual store information for these store IDs
      final storeSnapshot = await CollectionReferences.stores
          .where('businessId', isEqualTo: businessId)
          .where(FieldPath.documentId, whereIn: storeIds)
          .get();

      // Create a map of store ID to store data for quick lookup
      final Map<String, Map<String, dynamic>> storeMap = {};
      for (final storeDoc in storeSnapshot.docs) {
        final storeData = storeDoc.data() as Map<String, dynamic>;
        storeMap[storeDoc.id] = {
          'id': storeDoc.id,
          'name': storeData['name'] ?? 'Unknown Store',
          'address': storeData['address'] ?? '',
          'contactPerson': storeData['contactPerson'] ?? '',
          'contactPhone': storeData['contactPhone'] ?? '',
          'description': storeData['description'] ?? '',
          'imageUrl': storeData['imageUrl'],
        };
      }

      // Combine inventory data with store information
      return inventorySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return <String, dynamic>{};
        
        final storeId = data['storeId'] as String? ?? '';
        final storeInfo = storeMap[storeId];
        
        return {
          'storeId': storeId,
          'storeName': storeInfo?['name'] ?? 'Unknown Store',
          'storeAddress': storeInfo?['address'] ?? '',
          'storeContactPerson': storeInfo?['contactPerson'] ?? '',
          'storeContactPhone': storeInfo?['contactPhone'] ?? '',
          'storeDescription': storeInfo?['description'] ?? '',
          'storeImageUrl': storeInfo?['imageUrl'],
          'quantity': data['quantity'] ?? 0,
          'availableQuantity': data['quantity'] ?? 0, // Current available quantity
          'minimumQuantity': data['minimumQuantity'] ?? 0,
          'status': data['status'] ?? 'active',
          'isLowStock': data['isLowStock'] ?? false,
          'lastUpdated': data['updatedAt'] as Timestamp?,
          'location': data['location'] ?? '',
          'unitPrice': data['unitPrice'] ?? 0.0,
        };
      }).where((item) => item.isNotEmpty && item['storeId'] != '').toList();
    } catch (e) {
      print('Error getting store distribution: $e');
      return [];
    }
  }

  void dispose() {
    _subscription?.cancel();
    _cache.clear();
  }
}

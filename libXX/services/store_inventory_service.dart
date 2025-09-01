import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store_inventory.dart';

final storeInventoryServiceProvider = Provider<StoreInventoryService>((ref) {
  return StoreInventoryService();
});

// Provider for store inventory stream
final storeInventoryStreamProvider = StreamProvider.family<List<StoreInventory>,
    ({String vendorId, String storeId})>((ref, params) {
  final service = ref.watch(storeInventoryServiceProvider);
  return service
      .streamStoreInventory(
        vendorId: params.vendorId,
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

  String _getStoreInventoryPath(String vendorId, String storeId) {
    return 'vendor/$vendorId/store/$storeId/inventory';
  }

  String _getCacheKey(String vendorId, String storeId) {
    return '$vendorId/$storeId';
  }

  Future<void> createStoreInventory({
    required String vendorId,
    required String storeId,
    required String productId,
    required String inventoryId,
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
    final docRef =
        _firestore.collection(_getStoreInventoryPath(vendorId, storeId)).doc();

    await docRef.set({
      'storeId': storeId,
      'productId': productId,
      'inventoryId': inventoryId,
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
    });

    // Update cache if exists
    final cacheKey = _getCacheKey(vendorId, storeId);
    if (_cache.containsKey(cacheKey)) {
      final newItem = StoreInventory(
        id: docRef.id,
        storeId: storeId,
        productId: productId,
        inventoryId: inventoryId,
        productName: productName,
        quantity: quantity,
        minimumQuantity: minimumQuantity,
        unitPrice: unitPrice,
        location: location,
        notes: notes,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
      _cache[cacheKey] = [..._cache[cacheKey]!, newItem];
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreInventory({
    required String vendorId,
    required String storeId,
    String? searchQuery,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) {
    // Cancel existing subscription if any
    _subscription?.cancel();

    Query<Map<String, dynamic>> query = _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .orderBy('createdAt', descending: true)
        .limit(10);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    // Set up subscription and cache results
    _subscription = query.snapshots().listen((snapshot) {
      final cacheKey = _getCacheKey(vendorId, storeId);
      _cache[cacheKey] = snapshot.docs
          .map((doc) => StoreInventory.fromFirestore(doc))
          .toList();
    });

    return query.snapshots();
  }

  Future<StoreInventory?> getStoreInventoryById({
    required String vendorId,
    required String storeId,
    required String inventoryId,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(vendorId, storeId);
    if (_cache.containsKey(cacheKey)) {
      final cachedItem = _cache[cacheKey]!.firstWhere(
        (item) => item.id == inventoryId,
        orElse: () => throw Exception('Item not found'),
      );
      return cachedItem;
    }

    // If not in cache, fetch from Firestore
    final doc = await _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .doc(inventoryId)
        .get();

    if (!doc.exists) return null;
    return StoreInventory.fromFirestore(doc);
  }

  Future<void> updateStoreInventory({
    required String vendorId,
    required String storeId,
    required String inventoryId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .doc(inventoryId)
        .update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update cache if exists
    final cacheKey = _getCacheKey(vendorId, storeId);
    if (_cache.containsKey(cacheKey)) {
      final index =
          _cache[cacheKey]!.indexWhere((item) => item.id == inventoryId);
      if (index != -1) {
        final updatedItem = _cache[cacheKey]![index].copyWith(
          productName: data['productName'],
          quantity: data['quantity'],
          minimumQuantity: data['minimumQuantity'],
          unitPrice: data['unitPrice'],
          location: data['location'],
          notes: data['notes'],
          updatedAt: DateTime.now(),
        );
        _cache[cacheKey]![index] = updatedItem;
      }
    }
  }

  Future<void> updateStoreInventoryQuantity({
    required String vendorId,
    required String storeId,
    required String storeInventoryId,
    required int quantity,
  }) async {
    final docRef =
        _firestore.collection('store_inventory').doc(storeInventoryId);

    await docRef.update({
      'quantity': quantity,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update cache if exists
    final cacheKey = _getCacheKey(vendorId, storeId);
    if (_cache.containsKey(cacheKey)) {
      final index =
          _cache[cacheKey]!.indexWhere((item) => item.id == storeInventoryId);
      if (index != -1) {
        final updatedItem = _cache[cacheKey]![index].copyWith(
          quantity: quantity,
          updatedAt: DateTime.now(),
        );
        _cache[cacheKey]![index] = updatedItem;
      }
    }
  }

  Future<void> deleteStoreInventory({
    required String vendorId,
    required String storeId,
    required String inventoryId,
  }) async {
    await _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .doc(inventoryId)
        .delete();

    // Update cache if exists
    final cacheKey = _getCacheKey(vendorId, storeId);
    if (_cache.containsKey(cacheKey)) {
      _cache[cacheKey] =
          _cache[cacheKey]!.where((item) => item.id != inventoryId).toList();
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getStoreInventory({
    required String vendorId,
    required String storeId,
    String? searchQuery,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .orderBy('createdAt', descending: true);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('productName', isGreaterThanOrEqualTo: searchQuery)
          .where('productName', isLessThanOrEqualTo: searchQuery + '\uf8ff');
    }

    return await query.get();
  }

  Future<StoreInventory?> getStoreInventoryByProductId({
    required String vendorId,
    required String storeId,
    required String productId,
  }) async {
    print('getStoreInventoryByProductId: $vendorId, $storeId, $productId');
    final querySnapshot = await _firestore
        .collection(_getStoreInventoryPath(vendorId, storeId))
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return StoreInventory.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  }

  /// Fetch multiple store inventory records by a list of productIds for a store and vendor.
  /// Returns a map of productId -> StoreInventory.
  Future<Map<String, StoreInventory>> getStoreInventoriesByProductIds({
    required String vendorId,
    required String storeId,
    required List<String> productIds,
  }) async {
    if (productIds.isEmpty) return {};
    // Firestore whereIn supports up to 10 values per query
    final Map<String, StoreInventory> result = {};
    for (var i = 0; i < productIds.length; i += 10) {
      final batch = productIds.skip(i).take(10).toList();
      final querySnapshot = await _firestore
          .collection(_getStoreInventoryPath(vendorId, storeId))
          .where('productId', whereIn: batch)
          .get();
      for (final doc in querySnapshot.docs) {
        final storeInventory = StoreInventory.fromFirestore(doc);
        result[storeInventory.productId] = storeInventory;
      }
    }
    return result;
  }

  void dispose() {
    _subscription?.cancel();
    _cache.clear();
  }
}

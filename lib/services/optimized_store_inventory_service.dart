import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/optimized_store_inventory.dart';

/// Firestore service optimized for read cost efficiency
/// Implements strategic caching, batching, and query optimization
class OptimizedStoreInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to avoid repeated reads (implement TTL in production)
  static final Map<String, List<OptimizedStoreInventory>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  /// Get inventory for a store with minimal reads
  /// Uses cache-first strategy to reduce Firestore reads
  Future<List<OptimizedStoreInventory>> getStoreInventory({
    required String businessId,
    required String storeId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${businessId}_$storeId';

    // Check cache first to avoid reads
    if (!forceRefresh && _isValidCache(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Single collection query - no nested reads
      final querySnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('stores')
          .doc(storeId)
          .collection('inventory')
          .where('status', isEqualTo: 'active') // Filter at database level
          .orderBy('productName') // Avoid client-side sorting
          .limit(100) // Prevent massive read costs
          .get();

      final inventory = querySnapshot.docs
          .map((doc) => OptimizedStoreInventory.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Cache results to avoid future reads
      _cache[cacheKey] = inventory;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return inventory;
    } catch (e) {
      throw Exception('Failed to fetch inventory: $e');
    }
  }

  /// Stream inventory with cost-efficient real-time updates
  /// Limits listener scope to active items only
  Stream<List<OptimizedStoreInventory>> streamStoreInventory({
    required String businessId,
    required String storeId,
  }) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .doc(storeId)
        .collection('inventory')
        .where('status', isEqualTo: 'active')
        .where('lastUpdated',
            isGreaterThan: Timestamp.fromDate(
                DateTime.now().subtract(Duration(days: 30)) // Only recent items
                ))
        .orderBy('lastUpdated', descending: true)
        .orderBy('productName')
        .limit(50) // Reasonable limit for real-time updates
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OptimizedStoreInventory.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  /// Get low stock items with pre-computed flag (no client calculation)
  Future<List<OptimizedStoreInventory>> getLowStockItems({
    required String businessId,
    required String storeId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('stores')
          .doc(storeId)
          .collection('inventory')
          .where('isLowStock', isEqualTo: true) // Pre-computed field
          .where('status', isEqualTo: 'active')
          .orderBy('daysUntilReorder') // Critical items first
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => OptimizedStoreInventory.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch low stock items: $e');
    }
  }

  /// Batch update to minimize write costs
  Future<void> batchUpdateInventory({
    required String businessId,
    required String storeId,
    required List<OptimizedStoreInventory> items,
  }) async {
    final batch = _firestore.batch();
    final collectionRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .doc(storeId)
        .collection('inventory');

    for (final item in items) {
      final docRef = collectionRef.doc(item.id);
      batch.set(docRef, item.toMap(), SetOptions(merge: true));
    }

    await batch.commit();

    // Invalidate cache after updates
    _invalidateCache('${businessId}_$storeId');
  }

  /// Search with compound index (avoid multiple queries)
  Future<List<OptimizedStoreInventory>> searchInventory({
    required String businessId,
    required String storeId,
    required String searchTerm,
    String? category,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .doc(storeId)
        .collection('inventory')
        .where('status', isEqualTo: 'active');

    // Use compound queries where possible
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    // For text search, use array-contains on keywords field
    // (requires adding keywords array to model)
    query = query
        .where('searchKeywords', arrayContains: searchTerm.toLowerCase())
        .limit(25);

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => OptimizedStoreInventory.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  /// Get inventory summary (use aggregated collection)
  Future<Map<String, dynamic>> getInventorySummary({
    required String businessId,
    required String storeId,
  }) async {
    try {
      // Read from pre-computed summary document
      final summaryDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('inventory_summaries')
          .doc(storeId)
          .get();

      if (summaryDoc.exists) {
        return summaryDoc.data()!;
      }

      // Fallback: compute on-the-fly (expensive)
      return await _computeInventorySummary(businessId, storeId);
    } catch (e) {
      throw Exception('Failed to get inventory summary: $e');
    }
  }

  /// Efficient pagination with cursor-based approach
  Future<List<OptimizedStoreInventory>> getInventoryPage({
    required String businessId,
    required String storeId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('stores')
        .doc(storeId)
        .collection('inventory')
        .where('status', isEqualTo: 'active')
        .orderBy('productName')
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => OptimizedStoreInventory.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  // Cache management methods
  bool _isValidCache(String cacheKey) {
    if (!_cache.containsKey(cacheKey) ||
        !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }

    final cacheTime = _cacheTimestamps[cacheKey]!;
    return DateTime.now().difference(cacheTime) < _cacheValidityDuration;
  }

  void _invalidateCache(String cacheKey) {
    _cache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
  }

  void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Fallback method for summary computation (expensive)
  Future<Map<String, dynamic>> _computeInventorySummary(
    String businessId,
    String storeId,
  ) async {
    final inventoryItems = await getStoreInventory(
      businessId: businessId,
      storeId: storeId,
    );

    return {
      'totalItems': inventoryItems.length,
      'lowStockCount': inventoryItems.where((item) => item.isLowStock).length,
      'totalValue': inventoryItems.fold<double>(
        0,
        (sum, item) => sum + item.totalValue,
      ),
      'categories': _groupByCategory(inventoryItems),
      'lastUpdated': Timestamp.now(),
    };
  }

  Map<String, int> _groupByCategory(List<OptimizedStoreInventory> items) {
    final categories = <String, int>{};
    for (final item in items) {
      categories[item.category] = (categories[item.category] ?? 0) + 1;
    }
    return categories;
  }
}

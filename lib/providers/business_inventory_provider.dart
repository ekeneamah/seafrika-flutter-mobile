import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/business_inventory_service.dart';
import '../models/business_inventory.dart';
import '../providers/business_context_provider.dart';

/// Business Inventory Provider with Cost Optimization
///
/// This provider implements several strategies to minimize Firestore reads:
/// 1. Pagination with configurable page sizes (default: 20 items)
/// 2. Debounced search queries (500ms delay) to prevent rapid-fire reads
/// 3. Cache validation (5-minute freshness window) to avoid redundant reads
/// 4. Single-read provider for one-time data fetching
/// 5. Efficient cursor-based pagination using lastDocument
/// 6. Smart category/search filtering to only fetch when needed

// Provider for business inventory service
final businessInventoryServiceProvider =
    Provider<BusinessInventoryService>((ref) {
  return BusinessInventoryService();
});

// Cost-optimized provider for one-time reads (no continuous streaming)
final businessInventoryOnceProvider = FutureProvider.family<
    List<BusinessInventory>,
    ({
      String businessId,
      String? searchQuery,
      String? category,
      int limit
    })>((ref, params) async {
  final service = ref.watch(businessInventoryServiceProvider);

  // Use a small limit for cost efficiency
  final effectiveLimit = params.limit > 0 ? params.limit : 10;

  final snapshot = await service
      .streamBusinessInventory(
        businessId: params.businessId,
        searchQuery: params.searchQuery,
        category: params.category,
        limit: effectiveLimit,
      )
      .first; // Get single snapshot, not continuous stream

  return snapshot.docs
      .map((doc) => BusinessInventory.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>))
      .toList();
});

// Provider for business inventory stream with cost optimization
final businessInventoryStreamProvider = StreamProvider.family<
    List<BusinessInventory>,
    ({
      String businessId,
      String? searchQuery,
      String? category,
      int limit
    })>((ref, params) {
  final service = ref.watch(businessInventoryServiceProvider);

  // Use a reasonable default limit to control read costs
  final effectiveLimit = params.limit > 0 ? params.limit : 20;

  return service
      .streamBusinessInventory(
        businessId: params.businessId,
        searchQuery: params.searchQuery,
        category: params.category,
        limit: effectiveLimit, // Limit reads per query
      )
      .map((snapshot) => snapshot.docs
          .map((doc) => BusinessInventory.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// Provider for business inventory state management
final businessInventoryProvider =
    StateNotifierProvider<BusinessInventoryNotifier, BusinessInventoryState>(
        (ref) {
  final service = ref.watch(businessInventoryServiceProvider);
  return BusinessInventoryNotifier(service);
});

class BusinessInventoryState {
  final List<BusinessInventory> items;
  final Set<String> selectedIds;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;
  final String searchQuery;
  final bool hasMore;
  final DocumentSnapshot? lastDocument; // For pagination
  final DateTime? lastFetch; // For cache invalidation
  final int pageSize; // Control read batch size

  BusinessInventoryState({
    this.items = const [],
    this.selectedIds = const {},
    this.isLoading = false,
    this.error,
    this.selectedCategory,
    this.searchQuery = '',
    this.hasMore = true,
    this.lastDocument,
    this.lastFetch,
    this.pageSize = 20, // Default reasonable page size
  });

  BusinessInventoryState copyWith({
    List<BusinessInventory>? items,
    Set<String>? selectedIds,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? searchQuery,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    DateTime? lastFetch,
    int? pageSize,
  }) {
    return BusinessInventoryState(
      items: items ?? this.items,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      lastFetch: lastFetch ?? this.lastFetch,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  // Check if cache is stale (older than 5 minutes)
  bool get isCacheStale {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch!) > Duration(minutes: 5);
  }
}

class BusinessInventoryNotifier extends StateNotifier<BusinessInventoryState> {
  final BusinessInventoryService _service;

  BusinessInventoryNotifier(this._service) : super(BusinessInventoryState());

  // Debounce timer for search to avoid excessive reads
  Timer? _searchDebounceTimer;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void setSearchQuery(String query) {
    // Cancel previous timer to avoid multiple rapid calls
    _searchDebounceTimer?.cancel();

    // Debounce search queries by 500ms to reduce reads
    _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
      if (query != state.searchQuery) {
        state = state.copyWith(
          searchQuery: query,
          items: [], // Clear items for new search
          lastDocument: null, // Reset pagination
          hasMore: true,
        );
        _loadInventory(
            businessId: '', refresh: true); // Need to pass business ID
      }
    });
  }

  void setSelectedCategory(String? category) {
    if (category != state.selectedCategory) {
      state = state.copyWith(
        selectedCategory: category,
        items: [], // Clear items for new category
        lastDocument: null, // Reset pagination
        hasMore: true,
      );
      _loadInventory(businessId: '', refresh: true); // Need to pass business ID
    }
  }

  // Load inventory with cost optimization
  Future<void> _loadInventory({
    required String businessId,
    bool refresh = false,
  }) async {
    if (state.isLoading || (!refresh && !state.hasMore)) return;

    // Skip if cache is fresh and not refreshing
    if (!refresh && !state.isCacheStale && state.items.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final snapshot = await _service
          .streamBusinessInventory(
            businessId: businessId,
            searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
            category: state.selectedCategory,
            lastDocument: refresh ? null : state.lastDocument,
            limit: state.pageSize,
          )
          .first; // Use .first to get single snapshot, not continuous stream

      final newItems = snapshot.docs
          .map((doc) => BusinessInventory.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      state = state.copyWith(
        items: refresh ? newItems : [...state.items, ...newItems],
        lastDocument:
            newItems.isNotEmpty ? snapshot.docs.last : state.lastDocument,
        hasMore: newItems.length >= state.pageSize,
        isLoading: false,
        lastFetch: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Load more items (pagination)
  Future<void> loadMore(String businessId) async {
    if (!state.hasMore || state.isLoading) return;
    await _loadInventory(businessId: businessId);
  }

  void toggleItemSelection(String itemId) {
    final selectedIds = Set<String>.from(state.selectedIds);
    if (selectedIds.contains(itemId)) {
      selectedIds.remove(itemId);
    } else {
      selectedIds.add(itemId);
    }
    state = state.copyWith(selectedIds: selectedIds);
  }

  void selectAll() {
    final allIds = state.items.map((item) => item.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: <String>{});
  }

  void refresh(String businessId) {
    state = state.copyWith(
      items: [],
      error: null,
      isLoading: true,
      hasMore: true,
      lastDocument: null,
      lastFetch: null,
    );
    _loadInventory(businessId: businessId, refresh: true);
  }
}

/// Business Inventory Detail Provider
/// Provides a single business inventory item by ID
final businessInventoryDetailProvider =
    FutureProvider.family<BusinessInventory?, String>(
        (ref, businessInventoryId) async {
  final service = ref.watch(businessInventoryServiceProvider);
  return service.getBusinessInventoryById(businessInventoryId);
});

/// Simple Business Inventory List Provider
/// Provides a list of all business inventory items for management screen
final businessInventoryListProvider =
    FutureProvider<List<BusinessInventory>>((ref) async {
  final service = ref.watch(businessInventoryServiceProvider);
  final businessContext = ref.watch(businessContextProvider);

  print(
      '🏢 [BusinessInventoryListProvider] Business context: ${businessContext?.id}');

  if (businessContext == null) {
    print('❌ [BusinessInventoryListProvider] No business context');
    throw Exception('No business selected');
  }

  print(
      '📦 [BusinessInventoryListProvider] Fetching inventory for business: ${businessContext.id}');

  final snapshot = await service
      .streamBusinessInventory(
        businessId: businessContext.id,
        limit: 100, // Get more items for management screen
      )
      .first; // Get single snapshot

  print(
      '📦 [BusinessInventoryListProvider] Snapshot received: ${snapshot.docs.length} documents');

  final items = snapshot.docs
      .map((doc) => BusinessInventory.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>))
      .toList();

  print('✅ [BusinessInventoryListProvider] Returning ${items.length} items');
  return items;
});

/// Business Inventory Update Notifier
/// Provides methods to update business inventory items with cost price history tracking
final businessInventoryUpdateProvider =
    Provider<BusinessInventoryUpdateNotifier>((ref) {
  return BusinessInventoryUpdateNotifier(ref);
});

class BusinessInventoryUpdateNotifier {
  final Ref _ref;

  BusinessInventoryUpdateNotifier(this._ref);

  /// Update business inventory item with cost price history tracking
  Future<void> updateBusinessInventory({
    required String businessInventoryId,
    required Map<String, dynamic> updateData,
    String? changeReason,
  }) async {
    final service = _ref.read(businessInventoryServiceProvider);
    await service.updateBusinessInventory(
      businessInventoryId: businessInventoryId,
      updateData: updateData,
      changeReason: changeReason,
    );

    // Refresh the business inventory list
    _ref.invalidate(businessInventoryListProvider);
  }

  /// Update cost price with reason tracking
  Future<void> updateCostPrice({
    required String businessInventoryId,
    required double newCostPrice,
    required String changeReason,
  }) async {
    await updateBusinessInventory(
      businessInventoryId: businessInventoryId,
      updateData: {'costPrice': newCostPrice},
      changeReason: changeReason,
    );
  }
}

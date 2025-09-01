import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/store_inventory.dart';
import 'package:vendor_app/providers/service_providers.dart' as services;
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/store_inventory_service.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'dart:async';

class StoreInventoryState {
  final List<StoreInventory> items;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedCategory;
  final String? selectedStoreId;

  const StoreInventoryState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.selectedStoreId,
  });

  StoreInventoryState copyWith({
    List<StoreInventory>? items,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCategory,
    String? selectedStoreId,
  }) {
    return StoreInventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStoreId: selectedStoreId ?? this.selectedStoreId,
    );
  }

  List<StoreInventory> get filteredItems {
    return items.where((item) {
      final matchesSearch =
          item.productName.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }
}

final storeInventoryProvider =
    StateNotifierProvider<StoreInventoryNotifier, StoreInventoryState>((ref) {
  final service = ref.watch(services.storeInventoryServiceProvider);
  final vendorId = ref.watch(services.vendorIdSyncProvider); // current user id
  final businessId = ref.watch(selectedBusinessIdProvider); // selected business
  return StoreInventoryNotifier(service, vendorId, businessId);
});

class StoreInventoryNotifier extends StateNotifier<StoreInventoryState> {
  final StoreInventoryService _service;
  final String _vendorId;
  final String? _businessId;

  StoreInventoryNotifier(this._service, this._vendorId, this._businessId)
      : super(const StoreInventoryState());

  void clearInventory() {
    state = state.copyWith(
      items: [],
      isLoading: false,
      error: null,
      selectedStoreId: null,
    );
  }

  Future<void> loadInventory() async {
    if (_businessId == null || _businessId?.isEmpty == true) {
      // No business selected; ensure UI isn't stuck in loading
      state = state.copyWith(
        isLoading: false,
        error: 'No business selected. Please select a business first.',
        items: [],
      );
      return;
    }
    if (state.selectedStoreId == null) {
      print(
          '[StoreInventoryNotifier] No store selected — skipping inventory load.');
      state = state.copyWith(
        isLoading: false,
        error: null,
        items: [],
      );
      return;
    }

    print(
        '[StoreInventoryNotifier] Loading inventory for storeId: ${state.selectedStoreId}, vendorId: $_vendorId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final snapshot = await _service.getStoreInventory(
        businessId: _businessId!,
        storeId: state.selectedStoreId!,
        searchQuery: state.searchQuery,
      );

      final items = snapshot.docs
          .map((doc) => StoreInventory.fromFirestore(doc))
          .toList();

      print(
          '[StoreInventoryNotifier] Inventory loaded successfully: ${items.length} items found');

      state = state.copyWith(
        items: items,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      print('[StoreInventoryNotifier] Error loading inventory: $error');

      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadInventory();
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSelectedStore(String storeId) {
    state = state.copyWith(selectedStoreId: storeId);
    loadInventory();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> deleteInventory(String inventoryId) async {
    try {
      await _service.deleteStoreInventory(
        inventoryId: inventoryId,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createInventory({
    required String productId,
    required String businessInventoryId,
    required String productName,
    required int quantity,
    required int minimumQuantity,
    required double unitPrice,
    String? location,
    String? notes,
    String? displayImageUrl,
  }) async {
    try {
      final businessId = await BusinessPreferencesHelper.getSelectedBusinessId();
      final businessName = await BusinessPreferencesHelper.getSelectedBusinessName();
      await _service.createStoreInventory(
        businessId: businessId!,
        businessName: businessName!,
        vendorId: _vendorId,
        storeId: state.selectedStoreId!,
        productId: productId,
        businessInventoryId: businessInventoryId,
        productName: productName,
        quantity: quantity,
        minimumQuantity: minimumQuantity,
        unitPrice: unitPrice,
        location: location,
        notes: notes,
        displayImageUrl: displayImageUrl,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateInventory({
    required String inventoryId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _service.updateStoreInventory(
        inventoryId: inventoryId,
        data: data,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

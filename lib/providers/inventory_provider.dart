import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import '../models/inventory.dart';
import '../services/inventory_service.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/models/booking.dart';

class InventoryState {
  final List<Inventory> items;
  final Set<String> selectedIds;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final String searchQuery;
  final bool showLowStockOnly;
  final String? error;

  const InventoryState({
    this.items = const [],
    this.selectedIds = const {},
    this.isLoading = false,
    this.hasMore = true,
    this.lastDocument,
    this.searchQuery = '',
    this.showLowStockOnly = false,
    this.error,
  });

  InventoryState copyWith({
    List<Inventory>? items,
    Set<String>? selectedIds,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    String? searchQuery,
    bool? showLowStockOnly,
    String? error,
  }) {
    return InventoryState(
      items: items ?? this.items,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      searchQuery: searchQuery ?? this.searchQuery,
      showLowStockOnly: showLowStockOnly ?? this.showLowStockOnly,
      error: error,
    );
  }

  List<Inventory> get filteredItems {
    return items.where((item) {
      if (showLowStockOnly && item.quantity > item.minimumQuantity) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Inventory> get selectedItems {
    return items.where((item) => selectedIds.contains(item.id)).toList();
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  return InventoryNotifier(inventoryService);
});

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryService _inventoryService;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  InventoryNotifier(this._inventoryService)
      : super(const InventoryState(isLoading: true)) {
    _setupStreamSubscription();
  }

  void _setupStreamSubscription() {
    _subscription?.cancel();
    _subscription = _inventoryService
        .streamInventory(
      searchQuery: state.searchQuery,
    )
        .listen(
      (snapshot) {
        final items =
            snapshot.docs.map((doc) => Inventory.fromFirestore(doc)).toList();
        state = state.copyWith(
          items: items,
          isLoading: false,
          error: null,
        );
      },
      onError: (error, stackTrace) {
        state = state.copyWith(
          isLoading: false,
          error: error.toString(),
        );
      },
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _setupStreamSubscription();
  }

  void toggleLowStockFilter() {
    state = state.copyWith(showLowStockOnly: !state.showLowStockOnly);
  }

  void toggleItemSelection(String itemId) {
    final newSelectedIds = Set<String>.from(state.selectedIds);
    if (newSelectedIds.contains(itemId)) {
      newSelectedIds.remove(itemId);
    } else {
      newSelectedIds.add(itemId);
    }
    state = state.copyWith(selectedIds: newSelectedIds);
  }

  void selectAll() {
    state = state.copyWith(
      selectedIds: state.items.map((item) => item.id).toSet(),
    );
  }

  void resetSelection() {
    state = state.copyWith(selectedIds: {});
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      lastDocument: null,
      hasMore: true,
    );
    _setupStreamSubscription();
  }

  void loadMore() async {
    if (!state.hasMore) return;

    try {
      final snapshot = await _inventoryService
          .streamInventory(
            searchQuery: state.searchQuery,
            lastDocument: state.lastDocument,
          )
          .first;

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(hasMore: false);
        return;
      }

      final newItems =
          snapshot.docs.map((doc) => Inventory.fromFirestore(doc)).toList();
      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class InventoryDetailState {
  final Inventory? inventory;
  final Product? product;
  final bool isLoading;
  final String? error;

  const InventoryDetailState({
    this.inventory,
    this.product,
    this.isLoading = false,
    this.error,
  });

  InventoryDetailState copyWith({
    Inventory? inventory,
    Product? product,
    bool? isLoading,
    String? error,
  }) {
    return InventoryDetailState(
      inventory: inventory ?? this.inventory,
      product: product ?? this.product,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InventoryDetailNotifier extends StateNotifier<InventoryDetailState> {
  final InventoryService _inventoryService;
  final ProductService _productService;
  final String _inventoryId;
  final Ref ref;

  InventoryDetailNotifier(
    this._inventoryService,
    this._productService,
    this._inventoryId,
    this.ref,
  ) : super(const InventoryDetailState()) {
    loadInventory();
  }

  Future<void> loadInventory() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final vendorId = _inventoryService.currentVendorId;
      if (vendorId.isEmpty) {
        throw Exception('Vendor ID is empty');
      }

      if (_inventoryId.isEmpty) {
        throw Exception('Inventory ID is empty');
      }

      final inventory = await _inventoryService.fetchInventory(_inventoryId);
      if (inventory.productId.isEmpty) {
        throw Exception('Product ID is empty in inventory');
      }

      final product = await _productService.getProduct(inventory.productId);
      if (product == null) {
        throw Exception('Product not found');
      }

      state = state.copyWith(
        inventory: inventory,
        product: product,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sellInventory({
    required int quantity,
    required double price,
    required String customerId,
  }) async {
    try {
      await _inventoryService.sellInventory(
        _inventoryId,
        quantity: quantity,
        price: price,
        customerId: customerId,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Booking> createBooking({
    required String customerId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime bookingDate,
    required List<BookingItem> items,
    String? notes,
  }) async {
    try {
      final bookingService = ref.read(bookingServiceProvider);
      final booking = await bookingService.createBooking(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        bookingDate: bookingDate,
        items: items,
        notes: notes,
      );
      await loadInventory();
      return booking;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> pushToStore({
    required String storeId,
    required int quantity,
  }) async {
    try {
      final inventory = state.inventory;
      if (inventory == null) {
        throw Exception('Inventory not found');
      }
      final storeService = ref.read(storeServiceProvider);
      await storeService.pushInventoryToStore(
        storeId: storeId,
        inventoryId: _inventoryId,
        quantity: quantity,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addQuantity({
    required int quantity,
    required double price,
  }) async {
    try {
      final inventory = state.inventory;
      if (inventory == null) {
        throw Exception('Inventory not found');
      }
      await _inventoryService.updateInventory(
        _inventoryId,
        quantity: inventory.quantity + quantity,
        costPrice: price,
      );
      await loadInventory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final inventoryDetailProvider = StateNotifierProvider.family<
    InventoryDetailNotifier, InventoryDetailState, String>((ref, inventoryId) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  final productService = ref.watch(productServiceProvider);
  return InventoryDetailNotifier(
    inventoryService,
    productService,
    inventoryId,
    ref,
  );
});

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/service_providers.dart' as service_providers
    hide vendorIdProvider;
import '../../providers/vendor_id_provider.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import '../../services/store_inventory_service.dart' as store_inventory;
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import '../../models/inventory.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  final String? storeId;

  const InventoryListScreen({super.key, this.storeId});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Set<String> _selectedInventoryIds = {};
  String? get _passedStoreId => widget.storeId;
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  List<Inventory> _allInventoryItems = [];
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _inventorySubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeAnimations();
    _initializeData();
  }

  void _initializeData() {
    try {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(inventoryProvider.notifier).refresh();
        print('Initializing inventory data...');
        _inventorySubscription?.cancel();
        _inventorySubscription = ref
            .read(service_providers.inventoryServiceProvider)
            .streamInventory(
              searchQuery: _searchController.text,
              limit: 20, // Limit to 20 items for cost efficiency
            )
            .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            debugPrint('Fetched ${snapshot.docs.length} inventory items');
            _allInventoryItems = snapshot.docs
                .map((doc) => Inventory.fromFirestore(doc))
                .toList();
            _lastDocument =
                snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            _hasMore = snapshot.docs.length >= 20;
          });
          if (_fadeController != null && _slideController != null) {
            _initializeAnimations();
          }
        });
      });
    } catch (e) {
      _handleError('Failed to initialize inventory: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
    });
    _showSnackBar(message, isError: true);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));

    _fadeController!.forward();
    _slideController!.forward();
    setState(() {});
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _inventorySubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    try {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(inventoryProvider.notifier).loadMore();
      }
    } catch (e) {
      _handleError('Error loading more items: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final lastDoc = _lastDocument;
      if (lastDoc != null) {
        final newItems = await ref
            .read(service_providers.inventoryServiceProvider)
            .streamInventory(
              searchQuery: _searchController.text,
              lastDocument: lastDoc,
            )
            .first;

        if (!mounted) return;

        setState(() {
          _allInventoryItems.addAll(
            newItems.docs.map((doc) => Inventory.fromFirestore(doc)).toList(),
          );
          _lastDocument = newItems.docs.isNotEmpty ? newItems.docs.last : null;
          _hasMore = newItems.docs.length >= 10;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _handleError('Failed to load more items: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _resetPagination() {
    setState(() {
      _lastDocument = null;
      _hasMore = true;
      _allInventoryItems.clear();
    });
    _loadMore();
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.secondary : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildModernCard(
      {required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.03),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSearchAndFilterSection() {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);
    return _buildModernCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppTheme.softGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.earthLight.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search inventory items...',
                      hintStyle: TextStyle(
                        color: AppTheme.earth,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppTheme.earth,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _resetPagination();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      notifier.setSearchQuery(value);
                    },
                  ),
                ),
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  child: VerticalDivider(
                    color: AppTheme.earthLight.withOpacity(0.5),
                    thickness: 1,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    state.showLowStockOnly
                        ? Icons.filter_list
                        : Icons.filter_list_outlined,
                    color: state.showLowStockOnly
                        ? AppTheme.primary
                        : AppTheme.earth,
                    size: 24,
                  ),
                  onPressed: () {
                    notifier.toggleLowStockFilter();
                  },
                  tooltip: 'Filter Low Stock',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectAll() {
    final inventoryService =
        ref.read(service_providers.inventoryServiceProvider);
    inventoryService.streamInventory().first.then((snapshot) {
      ref.read(inventoryProvider.notifier).selectAll();
    });
  }

  void _resetSelection() {
    setState(() {
      _selectedInventoryIds.clear();
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedInventoryIds.contains(itemId)) {
        _selectedInventoryIds.remove(itemId);
      } else {
        _selectedInventoryIds.add(itemId);
      }
    });
  }

  List<Inventory> get _displayedInventoryItems {
    // Return all items without filtering out selected ones
    return _allInventoryItems.toList();
  }

  Widget _buildInventoryItem(Inventory item) {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);
    final isSelected = state.selectedIds.contains(item.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.glass : AppTheme.glass.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.earthLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => notifier.toggleItemSelection(item.id),
        onLongPress: () => _showItemOptions(item), // Show modal on long press
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.earthLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: isSelected ? AppTheme.primary : AppTheme.earth,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${item.quantity}',
                      style: TextStyle(
                        color: AppTheme.earth,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemOptions(Inventory item) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => FractionallySizedBox(
              widthFactor: 0.95, // Increase width of the bottom modal
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.earthLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildOptionTile(
                                icon: Icons.edit_outlined,
                                title: 'Edit Item',
                                color: AppTheme.primary,
                                onTap: () {
                                  // Navigate to edit inventory
                                },
                              ),
                              _buildOptionTile(
                                icon: Icons.store_outlined,
                                title: 'Add to Store',
                                color: AppTheme.accent,
                                onTap: () {},
                              ),
                              _buildOptionTile(
                                icon: Icons.delete_outline,
                                title: 'Delete',
                                color: AppTheme.secondary,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ));
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.earth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accent
                    .withOpacity(0.1), // Match Store tab icon card
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _searchController.text.isNotEmpty
                    ? Icons.search_off_outlined
                    : Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No items found'
                  : 'No inventory items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try adjusting your search terms or filters'
                  : 'Add your first inventory item to start building your inventory and showcase your offerings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.earth,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_outlined, size: 20),
                label: const Text(
                  'Add Inventory Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.createInventory);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedList(List<Inventory> items) {
    if (_fadeAnimation == null || _slideAnimation == null) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _buildInventoryItem(items[index]);
        },
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            return _buildInventoryItem(items[index]);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    final state = ref.watch(inventoryProvider);
    if (!state.isLoading || !state.hasMore) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);

    if (_error != null) {
      return error.ErrorView(
        message: _error!,
        onRetry: () {
          setState(() => _error = null);
          _initializeData();
        },
      );
    }

    if (state.error != null) {
      return error.ErrorView(
        message: state.error!,
        onRetry: () {
          notifier.refresh();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.glass,
        elevation: 0,
        title: Text(
          'Inventory',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (state.selectedIds.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.select_all, color: AppTheme.accent),
                onPressed: () {
                  _selectAll();
                },
                tooltip: 'Select All',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.clear_all, color: AppTheme.accent),
                onPressed: () {
                  _resetSelection();
                },
                tooltip: 'Reset Selection',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.store_mall_directory_outlined,
                    color: AppTheme.accent),
                onPressed: () {
                  try {
                    _onAddToStore();
                  } catch (e) {
                    _handleError('Failed to add items to store: $e');
                  }
                },
                tooltip: 'Add to Store',
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          try {
            Navigator.pushNamed(context, AppRoutes.createInventory);
          } catch (e) {
            _handleError('Failed to navigate to add inventory: $e');
          }
        },
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterSection(),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => notifier.refresh(),
                        child: _buildAnimatedList(state.items),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddToStore() async {
    final state = ref.read(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);
    final inventoryService =
        ref.read(service_providers.inventoryServiceProvider);
    final storeInventoryService =
        ref.read(store_inventory.storeInventoryServiceProvider);
    final storeService = ref.read(service_providers.storeServiceProvider);
    final vendorId = ref.read(vendorIdProvider);

    await storeService.fetchStores();
    final stores = storeService.stores;

    if (stores.isEmpty) {
      _showSnackBar('No stores available', isError: true);
      return;
    }

    // Get selected items from the state
    final selectedItems = state.items
        .where((item) => state.selectedIds.contains(item.id))
        .toList();

    // Build a map of inventory for quick lookup
    final Map<String, Inventory?> invMap = {};
    for (var inv in selectedItems) {
      invMap[inv.id] = await inventoryService.getInventoryById(inv.id);
    }

    // Controllers for each quantity field
    final Map<String, TextEditingController> qtyControllers = {
      for (var inv in selectedItems)
        inv.id: TextEditingController(
            text: invMap[inv.id]?.quantity.toString() ?? '1')
    };
    // Track the previous valid value for each quantity field
    final Map<String, String> previousValidQty = {
      for (var inv in selectedItems) inv.id: qtyControllers[inv.id]!.text
    };

    // Auto-select store if passed
    String? selectedStoreId =
        (_passedStoreId != null && stores.any((s) => s.id == _passedStoreId))
            ? _passedStoreId
            : (stores.isNotEmpty ? stores.first.id : null);

    final result = await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => FractionallySizedBox(
              widthFactor: 0.95,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.earthLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Items to Store',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedStoreId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Store',
                                  border: OutlineInputBorder(),
                                ),
                                items: stores.map((store) {
                                  return DropdownMenuItem(
                                    value: store.id,
                                    child: Text(store.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  selectedStoreId = value;
                                },
                              ),
                              const SizedBox(height: 16),
                              ...selectedItems.map((item) {
                                final inv = invMap[item.id];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv?.productName ?? 'Unknown Product',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Current Quantity: ${inv?.quantity ?? 0}',
                                            style: TextStyle(
                                              color: AppTheme.earth,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: qtyControllers[item.id],
                                            decoration: const InputDecoration(
                                              labelText: 'Quantity to Add',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              if (value.isEmpty) {
                                                // Allow empty value so user can edit freely
                                                return;
                                              }
                                              final qty =
                                                  int.tryParse(value) ?? 0;
                                              final availableQty =
                                                  inv?.quantity ?? 0;
                                              if (qty <= 0 ||
                                                  qty > availableQty) {
                                                // Revert to previous valid value
                                                qtyControllers[item.id]!.text =
                                                    previousValidQty[item.id]!;
                                                qtyControllers[item.id]!
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: previousValidQty[
                                                              item.id]!
                                                          .length),
                                                );
                                                // Show snackbar after the text field update and widget rebuild
                                                Future.microtask(() {
                                                  _showSnackBar(
                                                    'Invalid quantity for ${inv?.productName ?? 'item'} (max: $availableQty)',
                                                    isError: true,
                                                  );
                                                });
                                              } else {
                                                // Update previous valid value
                                                previousValidQty[item.id] =
                                                    value;
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.earth,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                // Validate all quantities
                                bool valid = true;
                                for (final inv in selectedItems) {
                                  final qty = int.tryParse(
                                          qtyControllers[inv.id]!.text) ??
                                      0;
                                  if (qty <= 0 ||
                                      (inv != null && qty > inv.quantity)) {
                                    valid = false;
                                    break;
                                  }
                                }
                                if (!valid) {
                                  _showSnackBar(
                                      'Please enter valid quantities for all items.',
                                      isError: true);
                                  return;
                                }

                                // Check if inventory items exist in the store and update/add accordingly
                                final Map<String, int> quantities = {
                                  for (final inv in selectedItems)
                                    inv.id: int.tryParse(
                                            qtyControllers[inv.id]!.text) ??
                                        0
                                };

                                // Batch fetch all store inventory records for selected product IDs
                                final selectedProductIds = [
                                  for (final inv in selectedItems) inv.productId
                                ];
                                final storeInventoryMap =
                                    await storeInventoryService
                                        .getStoreInventoriesByProductIds(
                                  vendorId: vendorId,
                                  storeId: selectedStoreId!,
                                  productIds: selectedProductIds,
                                );

                                for (final entry in quantities.entries) {
                                  final inventoryId = entry.key;
                                  final quantity = entry.value;
                                  final inventory = invMap[inventoryId];

                                  if (inventory != null) {
                                    final existingStoreInventory =
                                        storeInventoryMap[inventory.productId];

                                    if (existingStoreInventory != null) {
                                      // Update the quantity if the item exists in the store
                                      await storeInventoryService
                                          .updateStoreInventory(
                                        vendorId: vendorId,
                                        storeId: selectedStoreId!,
                                        inventoryId: existingStoreInventory.id,
                                        data: {
                                          'quantity':
                                              existingStoreInventory.quantity +
                                                  quantity,
                                          'updatedAt': DateTime.now(),
                                        },
                                      );
                                    } else {
                                      // Add the item to the store if it does not exist
                                      await storeInventoryService
                                          .createStoreInventory(
                                        vendorId: vendorId,
                                        storeId: selectedStoreId!,
                                        productId: inventory.productId,
                                        inventoryId: inventory.id,
                                        productName: inventory.productName,
                                        quantity: quantity,
                                        minimumQuantity:
                                            inventory.minimumQuantity,
                                        unitPrice: inventory.unitPrice,
                                        location: inventory.location,
                                        notes: inventory.notes,
                                        displayImageUrl:
                                            inventory.displayImageUrl,
                                      );
                                    }

                                    // Subtract from main inventory
                                    if (inventory.quantity >= quantity) {
                                      await inventoryService.updateInventory(
                                        inventory.id,
                                        quantity: inventory.quantity - quantity,
                                      );
                                    }
                                  }
                                }

                                Navigator.pop(context, {
                                  'storeId': selectedStoreId,
                                  'quantities': quantities,
                                });
                                // After closing the modal, show success, reset selection, and navigate
                                _showSnackBar(
                                    'Items added to store successfully',
                                    isError: false);
                                notifier.resetSelection();
                                Navigator.pushReplacementNamed(
                                    context, AppRoutes.home,
                                    arguments: {'initialTab': 1});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add to Store',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ));
  }
}

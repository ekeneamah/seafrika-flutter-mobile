import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/service_providers.dart' as service_providers;
import '../../providers/business_context_provider.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import '../../services/business_inventory_service.dart';
import '../../services/inventory_allocation_service.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import '../../models/business_inventory.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'package:vendor_app/utils/business_validation_helper.dart';
import 'package:vendor_app/utils/logger.dart';

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

  // Enhanced state management
  Set<String> _selectedInventoryIds = {};
  String? get _passedStoreId => widget.storeId;

  // Animation controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // Data state
  List<BusinessInventory> _allInventoryItems = [];
  Map<String, int> _realTimeAvailability = {};
  Map<String, int> _availabilityMap =
      {}; // Added for real-time availability tracking
  String? _error;
  bool _isLoading = true;
  bool _hasInitialized = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Business logic services - using dependency injection pattern
  late final BusinessInventoryService _businessInventoryService;
  late final InventoryAllocationService
      _inventoryAllocationService; // Fixed name

  // Subscriptions
  StreamSubscription<QuerySnapshot>? _inventorySubscription;
  StreamSubscription<Map<String, int>>? _availabilitySubscription;
  Map<String, StreamSubscription> _availabilitySubscriptions =
      {}; // Added for individual item tracking

  String? _currentBusinessId;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();

    // Initialize services with dependency injection
    _businessInventoryService = BusinessInventoryService();
    _inventoryAllocationService = InventoryAllocationService();

    _scrollController.addListener(_onScroll);
    _initializeAnimations();
    _validateBusinessSelection();

    // Set initial loading state
    _isLoading = true;
    _hasInitialized = false;

    _initializeData();
  }

  /// Validates that business is selected, redirects if not
  Future<void> _validateBusinessSelection() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BusinessValidationHelper.validateBusinessSelection(context);
    });
  }

  Future<void> _initializeData() async {
    try {
      Future.microtask(() async {
        if (!mounted) return;
        ref.read(inventoryProvider.notifier).refresh();
        print('Initializing inventory data...');
        _inventorySubscription?.cancel();
        final businessInventoryService = BusinessInventoryService();

        // Get business ID from business context provider
        final business = ref.read(businessContextProvider);
        if (business == null) {
          _handleError('No business selected');
          return;
        }
        final businessId = business.id;

        _inventorySubscription = businessInventoryService
            .streamBusinessInventory(
          businessId: businessId,
          searchQuery: _searchController.text,
          limit: 20, // Limit to 20 items for cost efficiency
        )
            .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            debugPrint('Fetched ${snapshot.docs.length} inventory items');
            _allInventoryItems = snapshot.docs
                .map((doc) => BusinessInventory.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>))
                .toList();
            _lastDocument =
                snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            _hasMore = snapshot.docs.length >= 20;
            _isLoading = false;
            _hasInitialized = true;
          });
          if (_fadeController != null && _slideController != null) {
            _initializeAnimations();
          }
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasInitialized = true;
      });
      _handleError('Failed to initialize inventory: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isLoading = false;
      _hasInitialized = true;
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
        final businessInventoryService = BusinessInventoryService();
        final businessId =
            await BusinessPreferencesHelper.getSelectedBusinessId();
        if (businessId == null) {
          _handleError('No business selected');
          return;
        }

        final newItems = await businessInventoryService
            .streamBusinessInventory(
              businessId: businessId,
              searchQuery: _searchController.text,
              lastDocument: lastDoc,
            )
            .first;

        if (!mounted) return;

        setState(() {
          _allInventoryItems.addAll(
            newItems.docs
                .map((doc) => BusinessInventory.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>))
                .toList(),
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

  void _selectAllLocalItems() {
    setState(() {
      _selectedInventoryIds = _allInventoryItems.map((item) => item.id).toSet();
    });
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

  List<BusinessInventory> get _displayedInventoryItems {
    // Return all items without filtering out selected ones
    return _allInventoryItems.toList();
  }

  Widget _buildInventoryItem(BusinessInventory item) {
    final isSelected = _selectedInventoryIds.contains(item.id);
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
        onTap: () => _toggleItemSelection(item.id),
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
                      'Total Qty: ${item.totalQuantity}, Available: ${item.availableQuantity}',
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

  void _showItemOptions(BusinessInventory item) {
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
    // Check if we had a network error or timeout
    final bool isNetworkError = _error != null &&
        (_error!.toLowerCase().contains('network') ||
            _error!.toLowerCase().contains('connection') ||
            _error!.toLowerCase().contains('resolve') ||
            _error!.toLowerCase().contains('host') ||
            _error!.toLowerCase().contains('unavailable') ||
            _error!.toLowerCase().contains('timeout'));

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
                isNetworkError
                    ? Icons.cloud_off_outlined
                    : _searchController.text.isNotEmpty
                        ? Icons.search_off_outlined
                        : Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNetworkError
                  ? _error!.toLowerCase().contains('timeout')
                      ? 'Connection Timeout'
                      : 'Connection Problem'
                  : _searchController.text.isNotEmpty
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
              isNetworkError
                  ? _error!.toLowerCase().contains('timeout')
                      ? 'The request took too long. Please check your connection and try again.'
                      : 'Please check your internet connection and try again.'
                  : _searchController.text.isNotEmpty
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
            if (isNetworkError) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_outlined, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                  _initializeData();
                },
              ),
            ] else ...[
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedList(List<BusinessInventory> items) {
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
          if (_selectedInventoryIds.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.select_all, color: AppTheme.accent),
                onPressed: () {
                  _selectAllLocalItems();
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
            child: _isLoading && !_hasInitialized
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading inventory items...'),
                        SizedBox(height: 8),
                        Text(
                          'This may take a moment if you have a slow connection',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _allInventoryItems.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _initializeData(),
                        child: _buildAnimatedList(_allInventoryItems),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddToStore() async {
    try {
      AppLogger.info('Starting inventory allocation to store process');

      // Get business context
      final business = ref.read(businessContextProvider);
      if (business == null) {
        AppLogger.error('No business context available for store allocation');
        _showSnackBar('No business selected', isError: true);
        return;
      }

      final businessId = business.id;
      final storeService = ref.read(service_providers.storeServiceProvider);

      // Fetch available stores
      await storeService.fetchStores();
      final stores = storeService.stores;

      if (stores.isEmpty) {
        AppLogger.warning('No stores available for allocation');
        _showSnackBar('No stores available', isError: true);
        return;
      }

      // Get selected items from local state
      final selectedItems = _allInventoryItems
          .where((item) => _selectedInventoryIds.contains(item.id))
          .toList();

      if (selectedItems.isEmpty) {
        AppLogger.warning('No items selected for store allocation');
        _showSnackBar('No items selected', isError: true);
        return;
      }

      AppLogger.info(
          'Processing allocation for ${selectedItems.length} items to ${stores.length} stores');

      // Build a map of inventory for quick lookup with availability validation
      final Map<String, BusinessInventory?> invMap = {};
      for (var inv in selectedItems) {
        final businessInventory =
            await _businessInventoryService.getBusinessInventoryById(inv.id);
        if (businessInventory != null &&
            businessInventory.availableQuantity > 0) {
          invMap[inv.id] = businessInventory;
        } else {
          AppLogger.warning('Inventory ${inv.id} has no available quantity');
        }
      }

      if (invMap.isEmpty) {
        _showSnackBar('No items have available quantity for allocation',
            isError: true);
        return;
      }

      // Controllers for each quantity field with real-time availability
      final Map<String, TextEditingController> qtyControllers = {
        for (var inv in selectedItems)
          if (invMap.containsKey(inv.id))
            inv.id: TextEditingController(text: '1') // Default to 1 for safety
      };

      // Track the previous valid value for each quantity field
      final Map<String, String> previousValidQty = {
        for (var inv in selectedItems)
          if (invMap.containsKey(inv.id)) inv.id: qtyControllers[inv.id]!.text
      };

      // Auto-select store if passed
      String? selectedStoreId =
          (_passedStoreId != null && stores.any((s) => s.id == _passedStoreId))
              ? _passedStoreId
              : (stores.isNotEmpty ? stores.first.id : null);

      await showModalBottomSheet(
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
                                ...selectedItems
                                    .where(
                                        (item) => invMap.containsKey(item.id))
                                    .map((item) {
                                  final inv = invMap[item.id]!;
                                  final availability =
                                      _availabilityMap[item.id] ??
                                          inv.availableQuantity;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inv.productName,
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
                                              'Available: $availability (Real-time)',
                                              style: TextStyle(
                                                color: availability > 0
                                                    ? AppTheme.earth
                                                    : Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  qtyControllers[item.id],
                                              decoration: InputDecoration(
                                                labelText: 'Quantity to Add',
                                                border:
                                                    const OutlineInputBorder(),
                                                errorText: availability <= 0
                                                    ? 'No stock available'
                                                    : null,
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              enabled: availability > 0,
                                              onChanged: (value) {
                                                if (value.isEmpty) {
                                                  return;
                                                }
                                                final qty =
                                                    int.tryParse(value) ?? 0;
                                                if (qty <= 0 ||
                                                    qty > availability) {
                                                  // Revert to previous valid value
                                                  qtyControllers[item.id]!
                                                          .text =
                                                      previousValidQty[
                                                          item.id]!;
                                                  qtyControllers[item.id]!
                                                          .selection =
                                                      TextSelection
                                                          .fromPosition(
                                                    TextPosition(
                                                        offset:
                                                            previousValidQty[
                                                                    item.id]!
                                                                .length),
                                                  );
                                                  // Show snackbar after the text field update
                                                  Future.microtask(() {
                                                    _showSnackBar(
                                                      'Invalid quantity for ${inv.productName} (max: $availability)',
                                                      isError: true,
                                                    );
                                                  });
                                                } else {
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
                                onPressed: selectedStoreId == null
                                    ? null
                                    : () async {
                                        try {
                                          AppLogger.info(
                                              'Processing store allocation transaction');

                                          // Validate all quantities against real-time availability
                                          final allocations =
                                              <Map<String, dynamic>>[];
                                          bool allValid = true;

                                          for (final item in selectedItems
                                              .where((item) => invMap
                                                  .containsKey(item.id))) {
                                            final qty = int.tryParse(
                                                    qtyControllers[item.id]!
                                                        .text) ??
                                                0;
                                            final availability =
                                                _availabilityMap[item.id] ??
                                                    invMap[item.id]!
                                                        .availableQuantity;

                                            if (qty <= 0 ||
                                                qty > availability) {
                                              allValid = false;
                                              _showSnackBar(
                                                'Invalid quantity for ${invMap[item.id]!.productName} (available: $availability)',
                                                isError: true,
                                              );
                                              break;
                                            }

                                            allocations.add({
                                              'businessInventoryId': item.id,
                                              'quantity': qty,
                                              'productId':
                                                  invMap[item.id]!.productId,
                                              'productName':
                                                  invMap[item.id]!.productName,
                                              'category':
                                                  invMap[item.id]!.category,
                                              'unitPrice':
                                                  invMap[item.id]!.sellingPrice,
                                            });
                                          }

                                          if (!allValid) {
                                            AppLogger.warning(
                                                'Allocation validation failed');
                                            return;
                                          }

                                          // Show loading indicator
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );

                                          // Convert allocations to InventoryAllocationItem format
                                          final allocationItems = allocations
                                              .map(
                                                (allocation) =>
                                                    InventoryAllocationItem(
                                                  businessInventoryId:
                                                      allocation[
                                                          'businessInventoryId'],
                                                  quantity:
                                                      allocation['quantity'],
                                                  minimumQuantity: 1,
                                                ),
                                              )
                                              .toList();

                                          // Get store name from stores list
                                          final selectedStore =
                                              stores.firstWhere((s) =>
                                                  s.id == selectedStoreId);

                                          // Use InventoryAllocationService for atomic transaction
                                          final result =
                                              await _inventoryAllocationService
                                                  .allocateInventoryToStore(
                                            businessId: businessId,
                                            businessName: business.name,
                                            vendorId: business.ownerId,
                                            storeId: selectedStoreId!,
                                            storeName: selectedStore.name,
                                            items: allocationItems,
                                          );

                                          // Close loading indicator
                                          Navigator.pop(context);

                                          if (result.success) {
                                            Navigator.pop(context, {
                                              'storeId': selectedStoreId,
                                              'quantities':
                                                  result.allocatedItems,
                                            });

                                            AppLogger.info(
                                                'Store allocation completed successfully');
                                            _showSnackBar(result.summaryMessage,
                                                isError: false);
                                            _resetSelection();

                                            // Navigate back to home with store tab selected
                                            Navigator.pushReplacementNamed(
                                                context, AppRoutes.home,
                                                arguments: {'initialTab': 1});
                                          } else {
                                            AppLogger.error(
                                                'Store allocation failed: ${result.summaryMessage}');
                                            _showSnackBar(
                                              result.summaryMessage,
                                              isError: true,
                                            );
                                          }
                                        } catch (e) {
                                          // Close loading indicator if still showing
                                          Navigator.pop(context);
                                          AppLogger.error(
                                              'Exception during store allocation: $e');
                                          _showSnackBar('An error occurred: $e',
                                              isError: true);
                                        }
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
                                  'Allocate to Store',
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
    } catch (e) {
      AppLogger.error('Failed to initiate store allocation: $e');
      _showSnackBar('Failed to open store allocation: $e', isError: true);
    }
  }
}

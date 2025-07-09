import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/store_inventory.dart';
import 'package:vendor_app/providers/store_inventory_provider.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:vendor_app/services/share_service.dart';
import 'package:vendor_app/widgets/product_card.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/empty_view.dart' as empty;
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/screens/stores/store_edit_screen.dart';

class InventoryTab extends ConsumerStatefulWidget {
  const InventoryTab({super.key});

  @override
  ConsumerState<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<InventoryTab>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadStoresAndProducts();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStoresAndProducts() async {
    print('🔄 [StoreTab] Loading stores and products...');
    final storeService = ref.read(storeServiceProvider);
    await storeService.fetchStores();
    final stores = storeService.stores;
    print('📦 [StoreTab] Found ${stores.length} stores');

    if (stores.isNotEmpty) {
      print('🏪 [StoreTab] Setting selected store to: ${stores.first.id}');
      ref
          .read(storeInventoryProvider.notifier)
          .setSelectedStore(stores.first.id);
    } else {
      print('⚠️ [StoreTab] No stores found');
      // Clear the store inventory when no stores are found
      ref.read(storeInventoryProvider.notifier).clearInventory();
    }

    // Always trigger the fade animation regardless of store count
    print('🎭 [StoreTab] Triggering fade animation');
    _fadeController.forward();
  }

  Future<void> _deleteInventory(StoreInventory inventory) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: AppTheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Inventory',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${inventory.productName}"? This action cannot be undone.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(storeInventoryProvider.notifier)
            .deleteInventory(inventory.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Inventory deleted successfully'),
                ],
              ),
              backgroundColor: AppTheme.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Failed to delete inventory'),
              ],
            ),
            backgroundColor: AppTheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _showInventoryOptions(StoreInventory inventory) async {
    final shareService = ref.read(shareServiceProvider);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.earthLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Inventory Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOptionTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Inventory',
                      color: AppTheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        NavigationService.navigateToEditInventory(inventory.id);
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.share_outlined,
                      title: 'Share Inventory',
                      color: AppTheme.accent,
                      onTap: () async {
                        Navigator.pop(context);
                        await shareService.shareProduct(
                          productId: inventory.id,
                          productName: inventory.productName,
                          description: inventory.notes ?? '',
                        );
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.analytics_outlined,
                      title: 'View Analytics',
                      color: AppTheme.earth,
                      onTap: () {
                        Navigator.pop(context);
                        NavigationService.navigateToAnalytics();
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.delete_outline,
                      title: 'Delete Inventory',
                      color: AppTheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteInventory(inventory);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  Widget _buildCategoryChip(String category) {
    final state = ref.watch(storeInventoryProvider);
    final isSelected = category == state.selectedCategory;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          ref
              .read(storeInventoryProvider.notifier)
              .setSelectedCategory(category);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.whiteSmoke,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.earthLight,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            category,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.earth,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeService = ref.watch(storeServiceProvider);
    final stores = storeService.stores;
    final isLoadingStores = storeService.isLoading;
    final state = ref.watch(storeInventoryProvider);

    print(
        '🔄 [StoreTab] Building - isLoading: $isLoadingStores, stores: ${stores.length}, selectedStoreId: ${state.selectedStoreId}');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Store',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                if (state.selectedStoreId == null) {
                  print('➕ [StoreTab] Opening store creation screen');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreEditScreen()),
                  ).then((created) async {
                    if (created == true) {
                      print('✅ [StoreTab] Store created, refreshing...');
                      await storeService.fetchStores();
                      final stores = storeService.stores;
                      if (stores.isNotEmpty) {
                        print(
                            '🏪 [StoreTab] Setting selected store to: ${stores.first.id}');
                        ref
                            .read(storeInventoryProvider.notifier)
                            .setSelectedStore(stores.first.id);
                      }
                    } else {
                      print('❌ [StoreTab] Store creation cancelled');
                    }
                  });
                } else {
                  print(
                      '📦 [StoreTab] Opening inventory list for store: ${state.selectedStoreId}');
                  Navigator.pushNamed(
                    context,
                    AppRoutes.inventoryList,
                    arguments: {'storeId': state.selectedStoreId},
                  );
                }
              },
              tooltip:
                  state.selectedStoreId == null ? 'Add Store' : 'Add Inventory',
            ),
          ),
        ],
      ),
      body: isLoadingStores
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: stores.isEmpty
                  ? _NoStoreView(onAddStore: () async {
                      print(
                          '➕ [StoreTab] Opening store creation from empty state');
                      final created = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StoreEditScreen()),
                      );
                      if (created == true) {
                        print(
                            '✅ [StoreTab] Store created from empty state, refreshing...');
                        await storeService.fetchStores();
                        final stores = storeService.stores;
                        if (stores.isNotEmpty) {
                          print(
                              '🏪 [StoreTab] Setting selected store to: ${stores.first.id}');
                          ref
                              .read(storeInventoryProvider.notifier)
                              .setSelectedStore(stores.first.id);
                        }
                      } else {
                        print(
                            '❌ [StoreTab] Store creation cancelled from empty state');
                      }
                    })
                  : CustomScrollView(
                      slivers: [
                        // Store Selection Header
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.store_outlined,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.whiteSmoke,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.earthLight,
                                            width: 1,
                                          ),
                                        ),
                                        child: DropdownButton<Store>(
                                          isExpanded: true,
                                          value: stores.firstWhere(
                                            (s) =>
                                                s.id == state.selectedStoreId,
                                            orElse: () => stores.first,
                                          ),
                                          underline: const SizedBox.shrink(),
                                          icon: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: AppTheme.earth,
                                          ),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                          ),
                                          items: stores
                                              .map((store) =>
                                                  DropdownMenuItem<Store>(
                                                    value: store,
                                                    child: Text(store.name),
                                                  ))
                                              .toList(),
                                          onChanged: (store) {
                                            if (store != null) {
                                              print(
                                                  '🔄 [StoreTab] Store selected: ${store.id}');
                                              ref
                                                  .read(storeInventoryProvider
                                                      .notifier)
                                                  .setSelectedStore(store.id);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.add_business_outlined,
                                          color: AppTheme.accent,
                                          size: 20,
                                        ),
                                        tooltip: 'Add Store',
                                        onPressed: () async {
                                          print(
                                              '➕ [StoreTab] Opening store creation from dropdown');
                                          final created = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const StoreEditScreen()),
                                          );
                                          if (created == true) {
                                            print(
                                                '✅ [StoreTab] Store created from dropdown, refreshing...');
                                            await storeService.fetchStores();
                                            final stores = storeService.stores;
                                            if (stores.isNotEmpty) {
                                              print(
                                                  '🏪 [StoreTab] Setting selected store to: ${stores.first.id}');
                                              ref
                                                  .read(storeInventoryProvider
                                                      .notifier)
                                                  .setSelectedStore(
                                                      stores.first.id);
                                            }
                                          } else {
                                            print(
                                                '❌ [StoreTab] Store creation cancelled from dropdown');
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Search and Filter Section
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.whiteSmoke,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.earthLight,
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search inventory...',
                                      hintStyle: TextStyle(
                                        color: AppTheme.earth,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_outlined,
                                        color: AppTheme.earth,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppTheme.textPrimary,
                                    ),
                                    onChanged: (value) {
                                      print(
                                          '🔍 [StoreTab] Search query changed: $value');
                                      ref
                                          .read(storeInventoryProvider.notifier)
                                          .setSearchQuery(value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildCategoryChip('All'),
                                      _buildCategoryChip('Electronics'),
                                      _buildCategoryChip('Clothing'),
                                      _buildCategoryChip('Home'),
                                      _buildCategoryChip('Beauty'),
                                      _buildCategoryChip('Sports'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 16)),

                        // Inventory Content
                        if (state.isLoading)
                          const SliverFillRemaining(
                            child: LoadingView(),
                          )
                        else if (state.error != null)
                          SliverFillRemaining(
                            child: error.ErrorView(
                              message: state.error!,
                              onRetry: () {
                                print('🔄 [StoreTab] Retrying inventory load');
                                ref
                                    .read(storeInventoryProvider.notifier)
                                    .loadInventory();
                              },
                            ),
                          )
                        else if (state.filteredItems.isEmpty)
                          SliverFillRemaining(
                            child: state.selectedStoreId != null
                                ? _NoInventoryView(
                                    store: stores.firstWhere(
                                      (s) => s.id == state.selectedStoreId,
                                      orElse: () => stores.first,
                                    ),
                                    onAddInventory: () {
                                      print(
                                          '📦 [StoreTab] Opening inventory list for store: ${state.selectedStoreId}');
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.inventoryList,
                                        arguments: {
                                          'storeId': state.selectedStoreId
                                        },
                                      );
                                    },
                                  )
                                : const SizedBox.shrink(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final inventory = state.filteredItems[index];
                                  return _StoreInventoryCard(
                                    inventory: inventory,
                                    onTap: () {
                                      print(
                                          '📦 [StoreTab] Opening inventory detail: ${inventory.inventoryId}');
                                      NavigationService
                                          .navigateToInventoryDetail(
                                              inventory.inventoryId);
                                    },
                                    onLongPress: () {
                                      print(
                                          '⚙️ [StoreTab] Showing options for inventory: ${inventory.inventoryId}');
                                      _showInventoryOptions(inventory);
                                    },
                                  );
                                },
                                childCount: state.filteredItems.length,
                              ),
                            ),
                          ),

                        // Bottom padding for tab bar
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
            ),
    );
  }
}

class _NoStoreView extends StatelessWidget {
  final VoidCallback onAddStore;
  const _NoStoreView({required this.onAddStore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.store_outlined,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No stores found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first store to start adding inventory and managing your products.',
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
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_business_outlined, size: 20),
                label: const Text(
                  'Create Store',
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
                onPressed: onAddStore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoInventoryView extends StatelessWidget {
  final Store store;
  final VoidCallback onAddInventory;
  const _NoInventoryView({
    required this.store,
    required this.onAddInventory,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No inventory in ${store.name}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first inventory item to start building your inventory and showcase your offerings.',
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
                onPressed: onAddInventory,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreInventoryCard extends ConsumerWidget {
  final StoreInventory inventory;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StoreInventoryCard({
    required this.inventory,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeService = ref.watch(storeServiceProvider);
    final stores = storeService.stores;
    final isLoading = storeService.isLoading;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: inventory.displayImageUrl != null &&
                      inventory.displayImageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Image.network(
                        inventory.displayImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppTheme.whiteSmoke,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppTheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.whiteSmoke,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: AppTheme.primary.withOpacity(0.5),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppTheme.whiteSmoke,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: AppTheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inventory.productName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: inventory.quantity <= inventory.minimumQuantity
                              ? AppTheme.secondary.withOpacity(0.1)
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${inventory.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                inventory.quantity <= inventory.minimumQuantity
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'NGN ${inventory.unitPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

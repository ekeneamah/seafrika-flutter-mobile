import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/loading_view.dart' as loading;
import 'package:vendor_app/widgets/error_view.dart' as error_widget;
import 'package:vendor_app/widgets/empty_view.dart' as empty;
import 'package:vendor_app/widgets/product_list_card.dart';

enum ProductFilter { all, inStock, lowStock }

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  ProductFilter _selectedFilter = ProductFilter.all;
  String _searchQuery = '';
  List<Product> _filteredProducts = [];
  List<Product> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      _filterProducts();
    }
  }

  Future<void> _validateBusinessContext() async {
    final businessContext = ref.read(businessContextProvider);
    
    if (businessContext == null) {
      NavigationService.navigateToAndClearStack(AppRoutes.businessList);
      return;
    }
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
    await _validateBusinessContext();
    
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final productService = ref.read(productServiceProvider);
      final businessContext = ref.read(businessContextProvider);
      
      if (businessContext == null) return;

      // Fetch all products for the business (don't filter by status since Product model doesn't have it)
      await productService.fetchProducts(businessId: businessContext.id);
      
      setState(() {
        _allProducts = List.from(productService.products);
        _isLoading = false;
        _errorMessage = null;
      });

      _filterProducts();

      if (!_fadeController.isCompleted) {
        _fadeController.forward();
      }

    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _filterProducts() {
    List<Product> filtered = List.from(_allProducts);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply status filter
    switch (_selectedFilter) {
      case ProductFilter.inStock:
        filtered = filtered.where((product) => product.stock > 0 && !product.isLowStock).toList();
        break;
      case ProductFilter.lowStock:
        filtered = filtered.where((product) => product.stock > 0 && product.isLowStock).toList();
        break;
      case ProductFilter.all:
        // No additional filtering
        break;
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onFilterChanged(ProductFilter filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });
      _filterProducts();
    }
  }

  Future<void> _refreshProducts() async {
    await _loadProducts(isRefresh: true);
  }

  void _navigateToCreateProduct() {
    Navigator.pushNamed(context, AppRoutes.createProduct).then((_) {
      _refreshProducts();
    });
  }

  void _navigateToProductDetail(Product product) {
    Navigator.pushNamed(
      context, 
      AppRoutes.productDetail,
      arguments: {'productId': product.id},
    ).then((_) {
      _refreshProducts();
    });
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: ProductFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          String label;
          
          switch (filter) {
            case ProductFilter.all:
              label = 'All Products';
              break;
            case ProductFilter.inStock:
              label = 'In Stock';
              break;
            case ProductFilter.lowStock:
              label = 'Low Stock';
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => _onFilterChanged(filter),
              backgroundColor: Colors.grey[100],
              selectedColor: AppTheme.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_filteredProducts.isEmpty) {
      return empty.EmptyView(
        icon: Icons.inventory_2_outlined,
        title: _searchQuery.isNotEmpty ? 'No products found' : 'No products yet',
        message: _searchQuery.isNotEmpty 
            ? 'Try adjusting your search or filter criteria.'
            : 'Create your first product to get started with your catalog.',
        action: ElevatedButton(
          onPressed: _navigateToCreateProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Product'),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return ProductListCard(
          product: product,
          onTap: () => _navigateToProductDetail(product),
          onEdit: () => _navigateToProductDetail(product),
          onDelete: () => _showDeleteConfirmation(product),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteProduct(product);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      final productService = ref.read(productServiceProvider);
      await productService.deleteProduct(product.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _refreshProducts();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting product: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _filteredProducts.isEmpty) {
      return const loading.LoadingView();
    }

    if (_errorMessage != null) {
      return error_widget.ErrorView(
        message: _errorMessage!,
        onRetry: () => _loadProducts(isRefresh: true),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshProducts,
          child: Column(
            children: [
              _buildSearchBar(),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(child: _buildProductsList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateProduct,
        backgroundColor: AppTheme.primary,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}

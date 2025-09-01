import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/product_listing.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/business_inventory_provider.dart' as biz_inventory;
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/models/product.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:ui';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? storeId; // Made optional since it's not used

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.storeId, // Made optional
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

// --- Modern Metric Card Widget ---
class _ModernMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ModernMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- Modern Section Card Widget ---
class _ModernSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ModernSectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  Product? _product;
  List<ExternalListing> _externalListings = [];
  ProductAnalytics? _analytics;
  List<Map<String, dynamic>> _topReviews = [];
  List<Map<String, dynamic>> _topComplaints = [];
  List<Map<String, dynamic>> _tasks = [];
  int _currentImageIndex = 0;
  bool _isProductInInventoryState = false;
  final PageController _carouselController = PageController();
  bool _showAllReviews = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final productService = ref.read(productServiceProvider);
      final product = await productService.getProduct(widget.productId);
      if (product == null) {
        setState(() {
          _error = 'Product not found';
          _isLoading = false;
        });
        return;
      }
      final results = await Future.wait([
        productService.getExternalListings(widget.productId),
        productService.getProductAnalytics(widget.productId),
        productService.getTopReviews(widget.productId),
        productService.getTopComplaints(widget.productId),
        productService.getProductTasks(widget.productId),
      ]);

      setState(() {
                setState(() {
        _product = product;
        _externalListings = results[0] as List<ExternalListing>;
        _analytics = results[1] as ProductAnalytics;
        _topReviews = results[2] as List<Map<String, dynamic>>;
        _topComplaints = results[3] as List<Map<String, dynamic>>;
        _tasks = results[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
      
      // Check if product is in inventory asynchronously
      _checkProductInventoryStatus();
      
      _fadeController.forward();
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      debugPrint('Product detail load error: $e');
      setState(() {
        _error = 'Failed to load product details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      _showModernSnackBar('URL copied to clipboard', Icons.copy);
    }
  }

  void _showModernSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _visitStore(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        _showModernSnackBar('Could not open store URL', Icons.error);
      }
    }
  }

  Future<void> _shareProduct() async {
    final product =
        await context.read<ProductService>().getProduct(widget.productId);
    if (product != null) {
      await Share.share(
        'Check out ${product.name} on our store!',
        subject: product.name,
      );
    }
  }

  Future<void> _addToInventory() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    
    if (businessId == null || businessId.isEmpty) {
      _showModernSnackBar('No business selected. Please select a business first.', Icons.error_outline);
      return;
    }

    // Get the current product details to pass to inventory screen
    final productService = ref.read(productServiceProvider);
    final product = await productService.getProduct(widget.productId);
    
    if (product == null) {
      _showModernSnackBar('Product not found', Icons.error_outline);
      return;
    }

    // Navigate to create inventory screen with product details
    final result = await NavigationService.navigateToCreateInventory(
      arguments: {
        'product': product,
      },
    );
    
    // Show success message if inventory was created
    if (result == true) {
      _showModernSnackBar('Product added to inventory successfully!', Icons.check_circle_outline);
    }
  }

  Future<void> _createInvoice() async {
    NavigationService.navigateToCreateInvoice(productId: widget.productId);
  }

  Future<bool> _isProductInInventory() async {
    try {
      // Check if the product has any inventory records
      final businessId = ref.read(selectedBusinessIdProvider);
      if (businessId == null || businessId.isEmpty) {
        return false;
      }
      
      // Use the business inventory service to check if product exists in inventory
      final businessInventoryService = ref.read(biz_inventory.businessInventoryServiceProvider);
      final businessInventory = await businessInventoryService.getBusinessInventoryByProductId(
        businessId: businessId,
        productId: widget.productId,
      );
      
      // Return true if inventory exists and has available quantity > 0
      return businessInventory != null && businessInventory.availableQuantity > 0;
    } catch (e) {
      debugPrint('Error checking inventory: $e');
      return false;
    }
  }

  Future<void> _checkProductInventoryStatus() async {
    final isInInventory = await _isProductInInventory();
    setState(() {
      _isProductInInventoryState = isInInventory;
    });
  }

  Future<void> _navigateToInventoryDetails() async {
    try {
      // Get the business inventory ID for this product
      final businessId = ref.read(selectedBusinessIdProvider);
      if (businessId == null || businessId.isEmpty) {
        _showModernSnackBar('Business not selected', Icons.error_outline);
        return;
      }

      // Look up the business inventory for this product
      final businessInventoryService = ref.read(biz_inventory.businessInventoryServiceProvider);
      final businessInventory = await businessInventoryService.getBusinessInventoryByProductId(
        businessId: businessId,
        productId: widget.productId,
      );
      
      if (businessInventory == null) {
        _showModernSnackBar('Product not found in inventory', Icons.error_outline);
        return;
      }
      
      // Navigate to business inventory detail screen
      NavigationService.navigateToBusinessInventoryDetail(businessInventory.id);
    } catch (e) {
      debugPrint('Error navigating to inventory details: $e');
      _showModernSnackBar('Failed to open inventory details', Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _product?.name ?? 'Product Details',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              NavigationService.navigateToEditProduct(widget.productId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadData,
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_product != null)
                            _buildProductDetailSection(_product!),
                          const SizedBox(height: 16),
                          _buildAnalyticsSection(),
                          _buildExternalStoresSection(),
                          _buildReviewsAndComplaintsSection(),
                          _buildTaskManagementSection(),
                          const SizedBox(height: 20), // Reduced bottom padding
                        ],
                      ),
                    ),
                  ),
                ),
      
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomAction(Icons.edit_outlined, 'Edit', () {
                      NavigationService.navigateToEditProduct(widget.productId);
                    }),
                    _buildBottomAction(
                        _isProductInInventoryState 
                            ? Icons.inventory 
                            : Icons.inventory_outlined, 
                        _isProductInInventoryState 
                            ? 'View Inventory' 
                            : 'Add to Inventory', 
                        _isProductInInventoryState 
                            ? _navigateToInventoryDetails 
                            : _addToInventory),
                    _buildBottomAction(
                        Icons.receipt_long_outlined, 'Invoice', _createInvoice),
                    _buildBottomAction(Icons.analytics_outlined, 'Analytics',
                        () {
                      // Navigate to analytics
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBottomAction(
      IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF475569), size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailSection(Product product) {
    int imageCount = product.images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Modern Hero Image Carousel ---
        if (imageCount > 0)
          SizedBox(
            height: 400,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: imageCount,
                  controller: _carouselController,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openImageViewer(product.images, index),
                      child: Hero(
                        tag: 'product-image-${product.id}-$index',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              product.images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 48,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // --- Modern Carousel Indicator ---
                if (imageCount > 1)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AnimatedSmoothIndicator(
                            activeIndex: _currentImageIndex,
                            count: imageCount,
                            effect: const ExpandingDotsEffect(
                              dotHeight: 8,
                              dotWidth: 8,
                              activeDotColor: Colors.white,
                              dotColor: Colors.white54,
                              expansionFactor: 3,
                              spacing: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // --- Modern Product Info Card ---
        _ModernSectionCard(
          title: "Product Information",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _capitalizeWords(product.name),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: product.stock > 0
                          ? AppTheme.primary.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: product.stock > 0
                            ? AppTheme.primary.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      product.stock > 0 ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        color: product.stock > 0
                            ? AppTheme.primary
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'NGN ${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: product.rating,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                    ),
                    itemCount: 5,
                    itemSize: 20,
                    unratedColor: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${product.reviews} reviews)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              _buildModernDetailGrid(product),
              if (product.tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: product.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernDetailGrid(Product product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
              'Category', product.category, Icons.category_outlined),
          const SizedBox(height: 16),
          _buildDetailRow(
              'Stock', product.stock.toString(), Icons.inventory_2_outlined),
          const SizedBox(height: 16),
          _buildDetailRow('Created', product.createdAt.toString().split(' ')[0],
              Icons.calendar_today_outlined),
          const SizedBox(height: 16),
          _buildDetailRow(
              'Last Updated',
              product.updatedAt.toString().split(' ')[0],
              Icons.update_outlined),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    if (_analytics == null) return const SizedBox.shrink();
    return _ModernSectionCard(
      title: "Analytics Overview",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ModernMetricCard(
                  icon: Icons.visibility_outlined,
                  label: 'Views',
                  value: _analytics!.views.toString(),
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ModernMetricCard(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Sales',
                  value: _analytics!.sales.toString(),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ModernMetricCard(
                  icon: Icons.star_outline,
                  label: 'Rating',
                  value: _analytics!.rating.toStringAsFixed(1),
                  color: const Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Views Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _analytics!.viewsByDay.entries
                        .map((e) => FlSpot(
                              double.tryParse(e.key) ?? 0,
                              e.value.toDouble(),
                            ))
                        .toList(),
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.2),
                          const Color(0xFF3B82F6).withOpacity(0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalStoresSection() {
    return _ModernSectionCard(
      title: "External Stores",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_externalListings.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.store_outlined,
                        size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'No external store listings',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_externalListings.map((listing) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            listing.storeIcon,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.store,
                                    color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.storeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last updated: ${listing.lastUpdated?.toString().split(' ')[0] ?? 'Never'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert,
                            color: Color(0xFF6B7280)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'copy', child: Text('Copy URL')),
                          const PopupMenuItem(
                              value: 'visit', child: Text('Visit Store')),
                          const PopupMenuItem(
                              value: 'update', child: Text('Update Details')),
                          const PopupMenuItem(
                              value: 'remove', child: Text('Remove Listing')),
                        ],
                        onSelected: (value) =>
                            _handleStoreAction(value, listing),
                      ),
                    ],
                  ),
                ))),
        ],
      ),
    );
  }

  Widget _buildReviewsAndComplaintsSection() {
    final reviewsToShow = _showAllReviews
        ? _topReviews.length
        : (_topReviews.length > 2 ? 2 : _topReviews.length);

    return _ModernSectionCard(
      title: "Reviews & Feedback",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (_topReviews.isNotEmpty) ...[
            const Text(
              'Recent Reviews',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ...(_topReviews.take(reviewsToShow).map((review) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                const Color(0xFF3B82F6).withOpacity(0.1),
                            child: Text(
                              (review['user'] != null &&
                                      review['user'].isNotEmpty)
                                  ? review['user'][0].toUpperCase()
                                  : review['rating'].toString(),
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RatingBarIndicator(
                                  rating: (review['rating'] ?? 0).toDouble(),
                                  itemBuilder: (context, _) => const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  itemCount: 5,
                                  itemSize: 16,
                                  unratedColor: const Color(0xFFE5E7EB),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        review['comment'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ))),
            if (_topReviews.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllReviews = !_showAllReviews;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(_showAllReviews ? 'Show less' : 'Show more'),
              ),
          ],
          if (_topComplaints.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Recent Complaints',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ...(_topComplaints.map((complaint) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_outlined,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              complaint['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              complaint['description'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                NavigationService.navigateToReviews(
                    productId: widget.productId);
              },
              child: const Text('View All Reviews'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskManagementSection() {
    return _ModernSectionCard(
      title: "Task Management",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.task_outlined,
                        size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'No tasks found',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_tasks.map((task) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: task['completed']
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFF6B7280).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          task['completed']
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          color: task['completed']
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task['dueDate'].toString().split(' ')[0],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    NavigationService.navigateToTaskList(
                        arguments: {'productId': widget.productId});
                  },
                  icon: const Icon(Icons.list_outlined, size: 18),
                  label: const Text('View Tasks'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    NavigationService.navigateToCreateTask(
                      itemId: widget.productId,
                      itemType: TaskType.product,
                      title: 'Task for ${widget.productId}',
                      description:
                          'Product: ${widget.productId}\nPrice: \$${widget.productId}',
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleStoreAction(String action, ExternalListing listing) async {
    switch (action) {
      case 'copy':
        await _copyUrl(listing.productUrl);
        break;
      case 'visit':
        await _visitStore(listing.productUrl);
        break;
      case 'update':
        try {
          await context.read<ProductService>().updateExternalListing(
            productId: widget.productId,
            listingId: listing.id,
            updates: {
              'lastUpdated': DateTime.now(),
              'storeSpecificData': listing.storeSpecificData,
            },
          );
          _loadData();
          if (mounted) {
            _showModernSnackBar(
                'Listing updated successfully', Icons.check_circle);
          }
        } catch (e) {
          if (mounted) {
            _showModernSnackBar('Failed to update listing', Icons.error);
          }
        }
        break;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Remove Listing'),
            content: Text(
                'Are you sure you want to remove this listing from ${listing.storeName}?'),
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
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await context.read<ProductService>().removeExternalListing(
                  productId: widget.productId,
                  listingId: listing.id,
                );
            _loadData();
          } catch (e) {
            if (mounted) {
              _showModernSnackBar('Failed to remove listing', Icons.error);
            }
          }
        }
        break;
    }
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _openImageViewer(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.95),
            child: Stack(
              children: [
                Center(
                  child: PageView.builder(
                    controller: PageController(initialPage: initialIndex),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black,
                              child: const Icon(Icons.broken_image,
                                  size: 64, color: Colors.white),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

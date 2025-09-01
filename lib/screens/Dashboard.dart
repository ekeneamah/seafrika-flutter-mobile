import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/providers/service_providers.dart' as providers;
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'package:vendor_app/widgets/search_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  Store? _selectedStore;
  String _greeting = '';
  String _businessName = '';
  String _businessPhone = '';
  String _businessAddress = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setGreeting();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh business details when returning to dashboard
    _loadSelectedBusinessDetails();
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
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good morning';
    } else if (hour < 17) {
      _greeting = 'Good afternoon';
    } else {
      _greeting = 'Good evening';
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final businessId = ref.read(selectedBusinessIdProvider);
      if (businessId == null) {
        print('No business selected, skipping store loading');
        return;
      }
      
      final storeService = ref.read(providers.storeServiceProvider);
      await storeService.fetchStores();
      final stores = storeService.stores;
      if (stores.isNotEmpty && _selectedStore == null) {
        setState(() {
          _selectedStore = stores.first;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
    }
    
    // Load selected business details from SharedPreferences
    await _loadSelectedBusinessDetails();
  }

  Future<void> _loadSelectedBusinessDetails() async {
    try {
      final businessDetails = await BusinessPreferencesHelper.getSelectedBusinessDetails();
      setState(() {
        _businessName = businessDetails['name'] ?? '';
        _businessPhone = businessDetails['phone'] ?? '';
        _businessAddress = businessDetails['address'] ?? '';
      });
    } catch (e) {
      debugPrint('Error loading business details: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Show search widget in a modal overlay
  void _showSearchWidget() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.earthLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.earth,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Widget
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: VendorSearchWidget(
                    onSearchSubmitted: (query, criteria) {
                      Navigator.pop(context);
                      _handleSearchSubmitted(query, criteria);
                    },
                    onSuggestionSelected: (suggestion) {
                      Navigator.pop(context);
                      _handleSuggestionSelected(suggestion);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle search submission
  void _handleSearchSubmitted(String query, SearchCriteria criteria) {
    // TODO: Navigate to search results page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for "$query" in ${criteria.label}'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Handle suggestion selection
  void _handleSuggestionSelected(SearchSuggestion suggestion) {
    // TODO: Navigate to specific item
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${suggestion.title}'),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color? backgroundColor,
    List<Color>? gradientColors,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradientColors == null ? (backgroundColor ?? AppTheme.glass) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.03),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    return _buildModernCard(
      gradientColors: [
        AppTheme.primary.withOpacity(0.1),
        AppTheme.accent.withOpacity(0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First Row: Greeting on left, Search and Notification icons on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Greeting on the left
              Text(
                _greeting,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.earth,
                ),
              ),
              
              // Search and Notification icons on the right
              Row(
                children: [
                  // Search Button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      key: const Key('dashboard_search_button'),
                      icon: Icon(
                        Icons.search_outlined,
                        color: AppTheme.accent,
                        size: 24,
                      ),
                      onPressed: _showSearchWidget,
                      tooltip: 'Search across modules',
                    ),
                  ),
                  
                  // Notifications
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.secondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        // Navigate to notifications
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Second Row: Name with clap hand emoji and Avatar
          Row(
            children: [
              // User Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.2),
                      AppTheme.accent.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: user?.profileImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: user!.profileImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildAvatarFallback(user),
                          errorWidget: (context, url, error) => _buildAvatarFallback(user),
                        ),
                      )
                    : _buildAvatarFallback(user),
              ),
              
              const SizedBox(width: 16),
              
              // Name with clap hand emoji
              Expanded(
                child: Text(
                  '${user?.firstName ?? 'Vendor'} 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Business Details Section
          if (_businessName.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.earthLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Business Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        color: AppTheme.earth,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _businessName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_businessPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          color: AppTheme.earth,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _businessPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.earth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_businessAddress.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.earth,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _businessAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.earth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.2),
            AppTheme.accent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          user?.firstName?.isNotEmpty == true ? user!.firstName![0].toUpperCase() : 'V',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard(
            title: 'Products',
            value: '124',
            icon: Icons.inventory_2_outlined,
            color: AppTheme.primary,
            trend: '+12%',
            isPositive: true,
          ),
          _buildStatCard(
            title: 'Revenue',
            value: '₦2.4M',
            icon: Icons.trending_up_outlined,
            color: AppTheme.accent,
            trend: '+8.5%',
            isPositive: true,
          ),
          _buildStatCard(
            title: 'Bookings',
            value: '18',
            icon: Icons.event_outlined,
            color: AppTheme.secondary,
            trend: '+3',
            isPositive: true,
          ),
          _buildStatCard(
            title: 'Reviews',
            value: '5',
            icon: Icons.star_outline,
            color: AppTheme.earth,
            trend: '2 new',
            isPositive: false,
          ),
          _buildStatCard(
            title: 'Expenses',
            value: '₦450K',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF8B5CF6),
            trend: '-2.1%',
            isPositive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required bool isPositive,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppTheme.accent : AppTheme.secondary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: isPositive ? AppTheme.accent : AppTheme.secondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.earth,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionShortcuts() {
    final shortcuts = [
      {
        'title': 'Add Product',
        'icon': Icons.add_box_outlined,
        'color': AppTheme.primary,
        'onTap': () {},
      },
      {
        'title': 'Create Booking',
        'icon': Icons.event_available_outlined,
        'color': AppTheme.accent,
        'onTap': () {},
      },
      {
        'title': 'Share Store',
        'icon': Icons.share_outlined,
        'color': AppTheme.secondary,
        'onTap': () {},
      },
      {
        'title': 'Analytics',
        'icon': Icons.analytics_outlined,
        'color': AppTheme.earth,
        'onTap': () {},
      },
      {
        'title': 'Sync Store',
        'icon': Icons.sync_outlined,
        'color': const Color(0xFF8B5CF6),
        'onTap': () {},
      },
      {
        'title': 'Inventory',
        'icon': Icons.warehouse_outlined,
        'color': const Color(0xFF06B6D4),
        'onTap': () {},
      },
    ];

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flash_on_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: shortcuts.length,
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return GestureDetector(
                onTap: shortcut['onTap'] as VoidCallback,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (shortcut['color'] as Color).withOpacity(0.1),
                        (shortcut['color'] as Color).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (shortcut['color'] as Color).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (shortcut['color'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          shortcut['icon'] as IconData,
                          color: shortcut['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Center(
                          child: Text(
                            shortcut['title'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysBookings() {
    final bookings = _getMockBookings();
    
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.today_outlined,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${bookings.length} items',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: AppTheme.earth,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No bookings today',
                      style: TextStyle(
                        color: AppTheme.earth,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.earthLight.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getBookingTypeColor(booking.type).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getBookingTypeIcon(booking.type),
                          color: _getBookingTypeColor(booking.type),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.customerName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              booking.service,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.earth,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(booking.time),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStorePerformance() {
    if (_selectedStore == null) return const SizedBox.shrink();
    
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.store_outlined,
                  color: AppTheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStore!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Store Performance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.earth,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: AppTheme.accent,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  'Sales',
                  '₦1.2M',
                  Icons.attach_money_outlined,
                  AppTheme.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceMetric(
                  'Orders',
                  '89',
                  Icons.shopping_cart_outlined,
                  AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  'Inventory',
                  '124 items',
                  Icons.inventory_outlined,
                  AppTheme.earth,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceMetric(
                  'Rating',
                  '4.8 ⭐',
                  Icons.star_outline,
                  AppTheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.earth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    final activities = _getMockActivities();
    
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.earth.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timeline_outlined,
                  color: AppTheme.earth,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getActivityColor(activity.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getActivityIcon(activity.type),
                      color: _getActivityColor(activity.type),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          activity.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(activity.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.earth,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Mock data methods
  List<Booking> _getMockBookings() {
    return [
      Booking(
        id: '1',
        customerName: 'John Doe',
        service: 'Hair Cut & Styling',
        time: DateTime.now().add(const Duration(hours: 2)),
        type: BookingType.appointment,
      ),
      Booking(
        id: '2',
        customerName: 'Jane Smith',
        service: 'Product Delivery',
        time: DateTime.now().add(const Duration(hours: 4)),
        type: BookingType.delivery,
      ),
    ];
  }

  List<Activity> _getMockActivities() {
    return [
      Activity(
        id: '1',
        title: 'New Order Received',
        description: 'Order #1234 from Sarah Wilson',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        type: ActivityType.order,
      ),
      Activity(
        id: '2',
        title: 'Product Added',
        description: 'iPhone 15 Pro added to inventory',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        type: ActivityType.product,
      ),
      Activity(
        id: '3',
        title: 'Review Received',
        description: '5-star review from Michael Brown',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: ActivityType.review,
      ),
    ];
  }

  Color _getBookingTypeColor(BookingType type) {
    switch (type) {
      case BookingType.appointment:
        return AppTheme.primary;
      case BookingType.delivery:
        return AppTheme.accent;
      case BookingType.consultation:
        return AppTheme.secondary;
      default:
        return AppTheme.earth;
    }
  }

  IconData _getBookingTypeIcon(BookingType type) {
    switch (type) {
      case BookingType.appointment:
        return Icons.event_outlined;
      case BookingType.delivery:
        return Icons.local_shipping_outlined;
      case BookingType.consultation:
        return Icons.chat_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.order:
        return AppTheme.accent;
      case ActivityType.product:
        return AppTheme.primary;
      case ActivityType.review:
        return AppTheme.secondary;
      case ActivityType.complaint:
        return AppTheme.earth;
      default:
        return AppTheme.primary;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.order:
        return Icons.shopping_cart_outlined;
      case ActivityType.product:
        return Icons.inventory_2_outlined;
      case ActivityType.review:
        return Icons.star_outline;
      case ActivityType.complaint:
        return Icons.report_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              // Welcome Header
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildWelcomeHeader(),
                  ),
                ),
              ),
              
              // Quick Stats
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Quick Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    _buildQuickStats(),
                  ],
                ),
              ),
              
              // Action Shortcuts
              SliverToBoxAdapter(
                child: _buildActionShortcuts(),
              ),
              
              // Today's Bookings
              SliverToBoxAdapter(
                child: _buildTodaysBookings(),
              ),
              
              // Store Performance
              SliverToBoxAdapter(
                child: _buildStorePerformance(),
              ),
              
              // Activity Feed
              SliverToBoxAdapter(
                child: _buildActivityFeed(),
              ),
              
              // Bottom padding for tab bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mock Models
class Booking {
  final String id;
  final String customerName;
  final String service;
  final DateTime time;
  final BookingType type;

  Booking({
    required this.id,
    required this.customerName,
    required this.service,
    required this.time,
    required this.type,
  });
}

enum BookingType { appointment, delivery, consultation }

class Activity {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final ActivityType type;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
  });
}

enum ActivityType { order, product, review, complaint }
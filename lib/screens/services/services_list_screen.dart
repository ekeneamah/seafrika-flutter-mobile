import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/services/service_service.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/loading_view.dart' as loading;
import 'package:vendor_app/widgets/error_view.dart' as error_widget;
import 'package:vendor_app/widgets/empty_view.dart' as empty;

enum ServiceFilter { all, active, inactive }

class ServicesListScreen extends ConsumerStatefulWidget {
  const ServicesListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends ConsumerState<ServicesListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ServiceFilter _selectedFilter = ServiceFilter.all;
  String _searchQuery = '';
  List<Service> _filteredServices = [];
  List<Service> _allServices = [];
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
      _loadServices();
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
      _filterServices();
    }
  }

  Future<void> _validateBusinessContext() async {
    final businessContext = ref.read(businessContextProvider);

    if (businessContext == null) {
      NavigationService.navigateToAndClearStack(AppRoutes.businessList);
      return;
    }
  }

  Future<void> _loadServices({bool isRefresh = false}) async {
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
      final businessContext = ref.read(businessContextProvider);

      if (businessContext == null) return;

      // For now, we'll use a placeholder list since ServiceService is basic
      // In production, you would fetch from the service
      setState(() {
        _allServices = []; // Empty for now
        _isLoading = false;
        _errorMessage = null;
      });

      _filterServices();

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

  void _filterServices() {
    List<Service> filtered = List.from(_allServices);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((service) {
        return service.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // For now, we don't have active/inactive status on Service model
    // This would need to be added to the Service model later
    setState(() {
      _filteredServices = filtered;
    });
  }

  void _onFilterChanged(ServiceFilter filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });
      _filterServices();
    }
  }

  Future<void> _refreshServices() async {
    await _loadServices(isRefresh: true);
  }

  void _navigateToCreateService() {
    // Navigate to service creation screen when implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service creation coming soon!'),
      ),
    );
  }

  void _navigateToServiceDetail(Service service) {
    // Navigate to service detail screen when implemented
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${service.name} details - Coming soon!'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: ServiceFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          String label;

          switch (filter) {
            case ServiceFilter.all:
              label = 'All Services';
              break;
            case ServiceFilter.active:
              label = 'Active';
              break;
            case ServiceFilter.inactive:
              label = 'Inactive';
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => _onFilterChanged(filter),
              backgroundColor: Colors.grey[100],
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
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
          hintText: 'Search services...',
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

  Widget _buildServicesList() {
    if (_filteredServices.isEmpty) {
      return empty.EmptyView(
        icon: Icons.room_service_outlined,
        title:
            _searchQuery.isNotEmpty ? 'No services found' : 'No services yet',
        message: _searchQuery.isNotEmpty
            ? 'Try adjusting your search criteria.'
            : 'Create your first service to get started with your service catalog.',
        action: ElevatedButton(
          onPressed: _navigateToCreateService,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Service'),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) {
        final service = _filteredServices[index];
        return _buildServiceCard(service);
      },
    );
  }

  Widget _buildServiceCard(Service service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToServiceDetail(service),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Service Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.room_service,
                  color: AppTheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Service Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service Category', // Placeholder until Service model is expanded
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${service.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _navigateToServiceDetail(service);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(service);
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Service service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${service.name}"? This action cannot be undone.',
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
      await _deleteService(service);
    }
  }

  Future<void> _deleteService(Service service) async {
    try {
      // Service deletion implementation would go here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${service.name} deletion - Coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting service: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _filteredServices.isEmpty) {
      return const loading.LoadingView();
    }

    if (_errorMessage != null) {
      return error_widget.ErrorView(
        message: _errorMessage!,
        onRetry: () => _loadServices(isRefresh: true),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Services',
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
            onPressed: _refreshServices,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshServices,
          child: Column(
            children: [
              _buildSearchBar(),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(child: _buildServicesList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateService,
        backgroundColor: AppTheme.primary,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}

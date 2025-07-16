import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/services/business_service.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/screens/business/business_management_screen.dart';

class BusinessListScreen extends ConsumerStatefulWidget {
  const BusinessListScreen({super.key});

  @override
  ConsumerState<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends ConsumerState<BusinessListScreen> {
  List<Business> _businesses = [];
  bool _isLoading = true;
  final BusinessService _businessService = BusinessService();

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final businesses = await _businessService.getBusinessesByOwner(currentUser.id);
        setState(() {
          _businesses = businesses;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading businesses: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBusiness(Business business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Business'),
        content: Text('Are you sure you want to delete "${business.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _businessService.deleteBusiness(business.id);
        _showSnackBar('Business deleted successfully', isError: false);
        _loadBusinesses(); // Refresh the list
      } catch (e) {
        _showSnackBar('Error deleting business: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Select Business',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBusinesses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businesses.isEmpty
              ? _buildEmptyState()
              : _buildBusinessList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToBusinessManagement(),
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 80,
            color: AppTheme.earth,
          ),
          const SizedBox(height: 16),
          Text(
            'No Businesses Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first business to get started\nor join an existing business',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.earth,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToBusinessManagement(),
            icon: const Icon(Icons.add),
            label: const Text('Create Business'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _businesses.length,
      itemBuilder: (context, index) {
        final business = _businesses[index];
        return _buildBusinessCard(business);
      },
    );
  }

  Widget _buildBusinessCard(Business business) {
    final authService = ref.read(authServiceProvider);
    final currentUser = authService.currentUser;
    final isOwner = currentUser?.id == business.ownerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _selectBusiness(business),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${business.state}, ${business.country}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _navigateToBusinessManagement(businessId: business.id);
                            break;
                          case 'delete':
                            _deleteBusiness(business);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Address
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: AppTheme.earth),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      business.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earth,
                      ),
                    ),
                  ),
                ],
              ),

              // Phone
              if (business.phone != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: AppTheme.earth),
                    const SizedBox(width: 4),
                    Text(
                      business.phone!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earth,
                      ),
                    ),
                  ],
                ),
              ],

              // Email
              if (business.email != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: AppTheme.earth),
                    const SizedBox(width: 4),
                    Text(
                      business.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earth,
                      ),
                    ),
                  ],
                ),
              ],

              // Description
              if (business.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  business.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              
              // Status and role badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwner ? AppTheme.accent.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOwner ? 'Owner' : 'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOwner ? AppTheme.accent : AppTheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Created ${_formatDate(business.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.earth,
                    ),
                  ),
                ],
              ),
              
              // Tap to select hint
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Tap to select this business',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  Future<void> _navigateToBusinessManagement({String? businessId}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessManagementScreen(businessId: businessId),
      ),
    );

    if (result == true) {
      _loadBusinesses(); // Refresh the list if business was created/updated
    }
  }

  Future<void> _selectBusiness(Business business) async {
    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        _showSnackBar('User not authenticated', isError: true);
        return;
      }

      final isOwner = currentUser.id == business.ownerId;
      
      // Save selected business to SharedPreferences using helper
      await BusinessPreferencesHelper.saveSelectedBusiness(business);
      
      // Show success message
      _showSnackBar('Selected business: ${business.name}', isError: false);
      
      // Navigate based on user type
      if (isOwner) {
        // Business owner goes to main screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        // Staff member goes to staff navigation
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.staffNavigation);
        }
      }
    } catch (e) {
      _showSnackBar('Error selecting business: $e', isError: true);
    }
  }
}

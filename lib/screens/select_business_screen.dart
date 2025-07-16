import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/navigation_service.dart';

class SelectBusinessScreen extends ConsumerStatefulWidget {
  const SelectBusinessScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SelectBusinessScreen> createState() => _SelectBusinessScreenState();
}

class _SelectBusinessScreenState extends ConsumerState<SelectBusinessScreen> {
  List<Business> _businesses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh businesses when screen becomes visible
    if (mounted) {
      _loadBusinesses();
    }
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final businessService = ref.read(businessServiceProvider);
      final user = authService.currentUser;
      
      if (user != null) {
        final businesses = await businessService.getBusinessesByOwner(user.id);
        setState(() => _businesses = businesses);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading businesses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBusiness(Business business) async {
    try {
      final businessContext = ref.read(businessContextProvider.notifier);
      await businessContext.setSelectedBusiness(business);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected ${business.name}'),
            backgroundColor: AppTheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting business: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBusiness = ref.watch(businessContextProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await NavigationService.navigateTo(AppRoutes.businessManagement);
              if (result == true) {
                await _loadBusinesses();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businesses.isEmpty
              ? _buildEmptyState()
              : _buildBusinessList(selectedBusiness),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No businesses found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first business to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await NavigationService.navigateTo(AppRoutes.businessManagement);
              if (result == true) {
                await _loadBusinesses();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Business'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessList(Business? selectedBusiness) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _businesses.length,
      itemBuilder: (context, index) {
        final business = _businesses[index];
        final isSelected = selectedBusiness?.id == business.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected 
                ? BorderSide(color: AppTheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isSelected 
                  ? AppTheme.primary 
                  : AppTheme.primary.withOpacity(0.1),
              child: Text(
                business.name.isNotEmpty ? business.name[0].toUpperCase() : 'B',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            title: Text(
              business.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primary : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (business.industry?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(business.industry!),
                ],
                if (business.country.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    business.country,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            trailing: isSelected 
                ? Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 28,
                  )
                : Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                  ),
            onTap: () => _selectBusiness(business),
          ),
        );
      },
    );
  }
}

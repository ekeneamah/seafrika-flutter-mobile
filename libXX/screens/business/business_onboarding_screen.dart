import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/navigation_service.dart';

class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  const BusinessOnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends ConsumerState<BusinessOnboardingScreen> {
  int _currentStep = 0;
  List<Business> _userBusinesses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserBusinesses();
  }

  Future<void> _loadUserBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final businessService = ref.read(businessServiceProvider);
      final user = authService.currentUser;

      if (user != null) {
        final businesses = await businessService.getBusinessesByOwner(user.id);
        setState(() {
          _userBusinesses = businesses;
          _currentStep = businesses.isEmpty ? 0 : 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading user businesses: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewBusiness() async {
    final result =
        await NavigationService.navigateTo(AppRoutes.businessManagement);
    if (result == true) {
      // Business was created successfully, reload the list
      await _loadUserBusinesses();
    }
  }

  Future<void> _selectBusiness(Business business) async {
    setState(() => _isLoading = true);
    try {
      final businessContext = ref.read(businessContextProvider.notifier);
      await businessContext.setSelectedBusiness(business);

      // Navigate to main app
      NavigationService.navigateToAndClearStack(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting business: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _skipForNow() async {
    // User can skip business setup and use the app without a business context
    NavigationService.navigateToAndClearStack(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Welcome to Vendor App!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s set up your business to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / 2,
                backgroundColor: Colors.grey[300],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              const SizedBox(height: 24),

              // Content based on current step
              Expanded(
                child: _currentStep == 0
                    ? _buildCreateBusinessStep()
                    : _buildSelectBusinessStep(),
              ),

              // Bottom actions
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateBusinessStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business,
            size: 64,
            color: AppTheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            'Create Your Business',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start by creating your business profile. This will help you manage your products, orders, and customers effectively.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Features list
          _buildFeatureItem('Manage multiple stores and locations'),
          _buildFeatureItem('Track inventory and products'),
          _buildFeatureItem('Process orders and payments'),
          _buildFeatureItem('Analyze business performance'),

          const SizedBox(height: 32),

          // Create business button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createNewBusiness,
              icon: const Icon(Icons.add_business),
              label: const Text('Create Business'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectBusinessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Business',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose which business you want to work with.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),

        Expanded(
          child: ListView.builder(
            itemCount: _userBusinesses.length,
            itemBuilder: (context, index) {
              final business = _userBusinesses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      business.name.isNotEmpty
                          ? business.name[0].toUpperCase()
                          : 'B',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    business.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (business.industry?.isNotEmpty == true)
                        Text(business.industry!),
                      if (business.country.isNotEmpty) Text(business.country),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _selectBusiness(business),
                ),
              );
            },
          ),
        ),

        // Add another business button
        TextButton.icon(
          onPressed: _createNewBusiness,
          icon: const Icon(Icons.add),
          label: const Text('Create Another Business'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppTheme.primary.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        if (_currentStep == 1 && _userBusinesses.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _skipForNow,
              child: const Text('Skip for now'),
            ),
          ),
        ],
        if (_currentStep == 0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _skipForNow,
              child: const Text('Skip business setup'),
            ),
          ),
        ],
      ],
    );
  }
}

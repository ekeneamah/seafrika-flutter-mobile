import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/services/firestore_seeder.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/utils/routes.dart';

class NavigationDrawer extends ConsumerWidget {
  const NavigationDrawer({super.key});

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final User? user = authService.currentUser;
    final selectedBusiness = ref.watch(businessContextProvider);
    final String initials = (user?.firstName.isNotEmpty == true ||
            user?.lastName.isNotEmpty == true)
        ? (user?.firstName.isNotEmpty == true ? user!.firstName[0] : '') +
            (user?.lastName.isNotEmpty == true ? user!.lastName[0] : '')
        : '';
    final String fullName =
        user?.fullName.trim().isNotEmpty == true ? user!.fullName : 'User';
    final String email = user?.email ?? '';
    final String? profileImage = user?.profileImage;
    final currentRoute = NavigationService.currentRoute;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppTheme.accent,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile image/initials
                  profileImage != null && profileImage.isNotEmpty
                      ? CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(profileImage),
                          backgroundColor: AppTheme.glass,
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  // User info
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Business selection
                  GestureDetector(
                    onTap: () => NavigationService.navigateTo(AppRoutes.businessOnboarding),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              selectedBusiness?.name ?? 'Select Business',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            onTap: () => NavigationService.navigateToDashboard(),
            isSelected: currentRoute == Routes.dashboard,
          ),
          _buildDrawerItem(
            icon: Icons.business_center,
            title: 'Manage Businesses',
            onTap: () => NavigationService.navigateTo(AppRoutes.businessList),
            isSelected: currentRoute == AppRoutes.businessList,
          ),
          // Business Management Section
          _buildDrawerItem(
            icon: Icons.inventory_2,
            title: 'Products',
            onTap: () => NavigationService.navigateTo(AppRoutes.productList),
            isSelected: currentRoute == AppRoutes.productList,
          ),
          _buildDrawerItem(
            icon: Icons.room_service,
            title: 'Services',
            onTap: () => NavigationService.navigateTo(AppRoutes.serviceList),
            isSelected: currentRoute == AppRoutes.serviceList,
          ),
      
          
          const Divider(),
        
          _buildDrawerItem(
            icon: Icons.shopping_cart,
            title: 'Orders',
            onTap: () => NavigationService.navigateToOrders(),
            isSelected: currentRoute == Routes.orders,
          ),
          _buildDrawerItem(
            icon: Icons.people,
            title: 'Customers',
            onTap: () => NavigationService.navigateToCustomers(),
            isSelected: currentRoute == Routes.customers,
          ),
          _buildDrawerItem(
            icon: Icons.add_shopping_cart,
            title: 'Create Order',
            onTap: () => NavigationService.navigateToCreateOrder(),
            isSelected: currentRoute == AppRoutes.createOrder,
          ),
          _buildDrawerItem(
            icon: Icons.assignment,
            title: 'Order Management',
            onTap: () => NavigationService.navigateToOrderManagement(),
            isSelected: currentRoute == AppRoutes.orderManagement,
          ),
          _buildDrawerItem(
            icon: Icons.local_shipping,
            title: 'Delivery',
            onTap: () => NavigationService.navigateToDelivery(),
            isSelected: currentRoute == Routes.delivery,
          ),
          _buildDrawerItem(
            icon: Icons.analytics,
            title: 'Analytics',
            onTap: () => NavigationService.navigateToAnalytics(),
            isSelected: currentRoute == Routes.analytics,
          ),
         
          _buildDrawerItem(
            icon: Icons.shopping_bag,
            title: 'Purchase Orders',
            onTap: () => NavigationService.navigateToPurchaseOrders(),
            isSelected: currentRoute == Routes.purchaseOrders,
          ),
          _buildDrawerItem(
            icon: Icons.article,
            title: 'Knowledge Base',
            onTap: () => NavigationService.navigateToKnowledgeBase(),
            isSelected: currentRoute == Routes.knowledgeBase,
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => NavigationService.navigateToSettings(),
            isSelected: currentRoute == Routes.settings,
          ),
          _buildDrawerItem(
            icon: Icons.admin_panel_settings,
            title: 'Admin Panel',
            onTap: () => NavigationService.navigateTo(AppRoutes.adminPanel),
            isSelected: NavigationService.currentRoute == AppRoutes.adminPanel,
          ),
          const Divider(),
          // Developer-only: Run Seeder
          _buildDrawerItem(
            icon: Icons.refresh,
            title: 'Run Seeder',
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final firestore = ref.read(firebaseFirestoreProvider);
                final seeder = FirestoreSeeder(firestore: firestore);
                await seeder.seedPermissions();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('Permissions seeded successfully!')),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Seeder failed: \$e')),
                );
              }
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => NavigationService.logout(),
          ),
        ],
      ),
    );
  }
}

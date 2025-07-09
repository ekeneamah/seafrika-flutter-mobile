import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final User? user;
  const UserProfileScreen({Key? key, this.user}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedBusinessName;
  String? _selectedVendorId;
  String? _selectedStoreId;
  Map<String, int> _moduleCounts = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPreferences();
    _loadModuleCounts();
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBusinessName = prefs.getString('selectedBusinessName');
      _selectedVendorId = prefs.getString('selectedVendorId');
      _selectedStoreId = prefs.getString('selectedStoreId');
    });
  }

  Future<void> _loadModuleCounts() async {
    // Mock data - replace with actual API calls
    setState(() {
      _moduleCounts = {
        'tasks': 12,
        'inventory': 245,
        'enquiries': 8,
        'customers': 156,
        'bookings': 23,
        'orders': 45,
        'products': 89,
      };
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    List<Color>? gradientColors,
    Color? backgroundColor,
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
        color:
            gradientColors == null ? (backgroundColor ?? AppTheme.glass) : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.04),
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

  Widget _buildProfileHeader() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    return _buildModernCard(
      gradientColors: [
        AppTheme.primary.withOpacity(0.1),
        AppTheme.accent.withOpacity(0.05),
      ],
      child: Column(
        children: [
          Row(
            children: [
              // Profile Image
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.2),
                          AppTheme.accent.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: user?.profileImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: CachedNetworkImage(
                              imageUrl: user!.profileImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  _buildAvatarFallback(user),
                              errorWidget: (context, url, error) =>
                                  _buildAvatarFallback(user),
                            ),
                          )
                        : _buildAvatarFallback(user),
                  ),

                  // Edit Button
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 20),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earth,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (user?.roles ?? []).map((role) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getRoleColor(role).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatRole(role),
                            style: TextStyle(
                              color: _getRoleColor(role),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Settings Button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.earth.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: AppTheme.earth,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.3),
            AppTheme.accent.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Center(
        child: Text(
          user?.firstName?.isNotEmpty == true
              ? user!.firstName![0].toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSummary() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
              'Email', user?.email ?? 'Not provided', Icons.email_outlined),
          _buildInfoRow(
              'Phone', user?.phone ?? 'Not provided', Icons.phone_outlined),
          _buildInfoRow('Country', user?.country ?? 'Not specified',
              Icons.location_on_outlined),
          _buildInfoRow('Joined', _formatDate(user?.createdAt),
              Icons.calendar_today_outlined),
          _buildInfoRow('Last Login', _formatDate(user?.lastLoginAt),
              Icons.access_time_outlined),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 16),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.earth,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final permissions = user?.permissions ?? [];

    final actions = <Map<String, dynamic>>[];

    // Add actions based on permissions
    if (permissions.contains('view_tasks')) {
      actions.add({
        'title': 'My Tasks',
        'icon': Icons.task_outlined,
        'color': AppTheme.primary,
        'count': _moduleCounts['tasks'] ?? 0,
        'route': AppRoutes.taskList,
      });
    }

    if (permissions.contains('view_inventory')) {
      actions.add({
        'title': 'My Inventory',
        'icon': Icons.inventory_2_outlined,
        'color': AppTheme.accent,
        'count': _moduleCounts['inventory'] ?? 0,
        'route': AppRoutes.inventoryDashboard,
      });
    }

    if (permissions.contains('view_enquiries')) {
      actions.add({
        'title': 'My Enquiries',
        'icon': Icons.chat_outlined,
        'color': AppTheme.secondary,
        'count': _moduleCounts['enquiries'] ?? 0,
        'route': '/enquiries',
      });
    }

    if (permissions.contains('view_customers')) {
      actions.add({
        'title': 'My Customers',
        'icon': Icons.people_outline,
        'color': AppTheme.earth,
        'count': _moduleCounts['customers'] ?? 0,
        'route': AppRoutes.customers,
      });
    }

    if (permissions.contains('view_bookings')) {
      actions.add({
        'title': 'My Bookings',
        'icon': Icons.event_outlined,
        'color': const Color(0xFF8B5CF6),
        'count': _moduleCounts['bookings'] ?? 0,
        'route': '/bookings',
      });
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dashboard_outlined,
                  color: AppTheme.accent,
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
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return Container(
                  width: 140,
                  margin: EdgeInsets.only(
                      right: index < actions.length - 1 ? 16 : 0),
                  child: _buildActionCard(action),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, action['route']);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (action['color'] as Color).withOpacity(0.1),
              (action['color'] as Color).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (action['color'] as Color).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      action['icon'],
                      color: action['color'],
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (action['count'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: action['color'],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${action['count']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                action['title'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${action['count']} items',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.earth,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentBusinessInfo() {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business_outlined,
                  color: AppTheme.earth,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Current Business Context',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showBusinessSwitcher,
                child: Text(
                  'Switch',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildBusinessInfoRow(
            'Business',
            _selectedBusinessName ?? 'Not selected',
            Icons.business_center_outlined,
          ),
          _buildBusinessInfoRow(
            'Vendor ID',
            _selectedVendorId ?? 'Not set',
            Icons.badge_outlined,
          ),
          _buildBusinessInfoRow(
            'Store',
            _selectedStoreId ?? 'All stores',
            Icons.store_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.earth.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.earth, size: 16),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.earth,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBreakdown() {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final storeRoles = user?.storeRoles ?? {};

    if (storeRoles.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Role Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...storeRoles.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Role: ${entry.value.map(_formatRole).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(entry.value.isNotEmpty
                              ? entry.value.first
                              : UserRole.viewer)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.value.map(_formatRole).join(', '),
                      style: TextStyle(
                        color: _getRoleColor(entry.value.isNotEmpty
                            ? entry.value.first
                            : UserRole.viewer),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = _getMockRecentActivities();

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timeline_outlined,
                  color: const Color(0xFF06B6D4),
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
          ...activities.map((activity) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.whiteSmoke,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.earthLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: activity['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activity['icon'],
                      color: activity['color'],
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          activity['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['time'],
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.earth,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSettingsAndPreferences() {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Settings & Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingItem(
            'Profile Settings',
            'Update personal information',
            Icons.person_outline,
            () => Navigator.pushNamed(context, '/profile-edit'),
          ),
          _buildSettingItem(
            'Notification Preferences',
            'Manage alerts and notifications',
            Icons.notifications_outlined,
            () => Navigator.pushNamed(context, '/notification-settings'),
          ),
          _buildSettingItem(
            'Default Module',
            'Set startup screen preference',
            Icons.home_outlined,
            () => _showModuleSelector(),
          ),
          _buildSettingItem(
            'Logout',
            'Sign out of your account',
            Icons.logout_outlined,
            () => _showLogoutDialog(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppTheme.secondary.withOpacity(0.05)
              : AppTheme.whiteSmoke,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? AppTheme.secondary.withOpacity(0.2)
                : AppTheme.earthLight.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppTheme.secondary.withOpacity(0.1)
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppTheme.secondary : AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? AppTheme.secondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.earth,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.earth,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getRoleColor(UserRole role) {
    switch (role.toString().split('.').last.toLowerCase()) {
      case 'business_owner':
        return AppTheme.primary;
      case 'manager':
        return AppTheme.accent;
      case 'staff':
        return AppTheme.secondary;
      case 'editor':
        return AppTheme.earth;
      case 'viewer':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.primary;
    }
  }

  String _formatRole(UserRole role) {
    final name = role.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  List<Map<String, dynamic>> _getMockRecentActivities() {
    return [
      {
        'title': 'Task Completed',
        'description': 'Inventory Audit - Store A',
        'time': '2 hrs ago',
        'icon': Icons.task_alt_outlined,
        'color': AppTheme.accent,
      },
      {
        'title': 'New Customer Added',
        'description': 'John Doe - Premium Client',
        'time': '4 hrs ago',
        'icon': Icons.person_add_outlined,
        'color': AppTheme.primary,
      },
      {
        'title': 'Booking Created',
        'description': 'Hair Styling - Tomorrow 2PM',
        'time': '6 hrs ago',
        'icon': Icons.event_outlined,
        'color': AppTheme.secondary,
      },
    ];
  }

  void _showBusinessSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.earthLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Switch Business Context',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'This feature will be available when you have access to multiple businesses.',
                  style: TextStyle(
                    color: AppTheme.earth,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showModuleSelector() {
    // Implementation for module selector
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppTheme.earth),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.earth),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get user from arguments if provided
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final authService = ref.watch(authServiceProvider);
    final user = userArg ?? authService.currentUser;
    // Pass user to all relevant widgets
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profile',
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.edit_outlined, color: AppTheme.primary),
              onPressed: () {
                Navigator.pushNamed(context, '/profile-edit');
              },
              tooltip: 'Edit Profile',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              // Profile Header
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildProfileHeader(),
                  ),
                ),
              ),

              // User Info Summary
              SliverToBoxAdapter(
                child: _buildUserInfoSummary(),
              ),

              // Quick Actions Panel
              SliverToBoxAdapter(
                child: _buildQuickActionsPanel(),
              ),

              // Current Business Info
              SliverToBoxAdapter(
                child: _buildCurrentBusinessInfo(),
              ),

              // Role Breakdown
              SliverToBoxAdapter(
                child: _buildRoleBreakdown(),
              ),

              // Recent Activity
              SliverToBoxAdapter(
                child: _buildRecentActivity(),
              ),

              // Settings & Preferences
              SliverToBoxAdapter(
                child: _buildSettingsAndPreferences(),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

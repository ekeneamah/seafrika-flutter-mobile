import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/widgets/staff_credentials_modal.dart';
import 'package:vendor_app/screens/admin/create_edit_user_screen.dart';
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
      _selectedBusinessName =
          prefs.getString(SharedPreferencesKeys.selectedBusinessName);
      _selectedVendorId =
          prefs.getString(SharedPreferencesKeys.selectedBusinessOwnerId);
      _selectedStoreId = prefs.getString(SharedPreferencesKeys.selectedStoreId);
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

  // Responsive helper methods
  double _getHorizontalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 32.0; // Desktop
    if (screenWidth > 800) return 24.0; // Tablet
    return 16.0; // Mobile
  }

  double _getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 24.0; // Tablet/Desktop
    return 16.0; // Mobile
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  double _getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 18.0; // Mobile
    return 20.0; // Tablet/Desktop
  }

  double _getFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize - 2; // Mobile
    return baseSize; // Tablet/Desktop
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    List<Color>? gradientColors,
    Color? backgroundColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = _getHorizontalPadding(context);
        final cardPadding = _getCardPadding(context);

        return Container(
          margin: margin ??
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          decoration: BoxDecoration(
            gradient: gradientColors != null
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: gradientColors == null
                ? (backgroundColor ?? AppTheme.glass)
                : null,
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
            padding: padding ?? EdgeInsets.all(cardPadding),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    final authService = ref.watch(authServiceProvider);
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final user = userArg ?? widget.user ?? authService.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = _isSmallScreen(context);
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 24);

        return _buildModernCard(
          gradientColors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.accent.withOpacity(0.05),
          ],
          child: Column(
            children: [
              isSmallScreen
                  ? Column(
                      children: [
                        _buildProfileImageSection(user, iconSize),
                        const SizedBox(height: 16),
                        _buildUserInfoSection(user, fontSize, isSmallScreen),
                        const SizedBox(height: 16),
                        _buildActionButtonsSection(
                            user, iconSize, isSmallScreen),
                      ],
                    )
                  : Row(
                      children: [
                        _buildProfileImageSection(user, iconSize),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildUserInfoSection(
                              user, fontSize, isSmallScreen),
                        ),
                        const SizedBox(width: 16),
                        _buildActionButtonsSection(
                            user, iconSize, isSmallScreen),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileImageSection(User? user, double iconSize) {
    return Stack(
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
                    placeholder: (context, url) => _buildAvatarFallback(user),
                    errorWidget: (context, url, error) =>
                        _buildAvatarFallback(user),
                  ),
                )
              : _buildAvatarFallback(user),
        ),
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
              size: iconSize * 0.7,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection(
      User? user, double fontSize, bool isSmallScreen) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: isSmallScreen
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
                textAlign: isSmallScreen ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                user?.email ?? 'No email',
                style: TextStyle(
                  fontSize: _getFontSize(context, 14),
                  color: AppTheme.earth,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: isSmallScreen ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Role Badges
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment:
                    isSmallScreen ? WrapAlignment.center : WrapAlignment.start,
                children: (user?.roles ?? []).map((role) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        fontSize: _getFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtonsSection(
      User? user, double iconSize, bool isSmallScreen) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Flex(
          direction: isSmallScreen ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  size: iconSize,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.settings);
                },
                tooltip: 'Settings',
              ),
            ),
            SizedBox(
              width: isSmallScreen ? 12 : 0,
              height: isSmallScreen ? 0 : 8,
            ),
            // Re-invite Button
            if (user != null) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.send_outlined, color: AppTheme.accent),
                  onPressed: () => _showReInviteModal(user),
                  tooltip: 'Re-invite User',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showReInviteModal(User? user) {
    if (user == null) return;

    // Generate a temporary password for re-invite
    final tempPassword =
        'temp${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    showStaffCredentialsModal(
      context: context,
      staffEmail: user.email,
      staffPassword: tempPassword,
      staffName: '${user.firstName} ${user.lastName}',
      businessName: user.businessName ?? 'Your Business',
      onClose: () {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Re-invite sent successfully!'),
                ],
              ),
              backgroundColor: AppTheme.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  String _getInitial(User? user) {
    final firstName = user?.firstName;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    return 'U';
  }

  Widget _buildAvatarFallback(User? user) {
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
          _getInitial(user),
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
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final user = userArg ?? widget.user ?? authService.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = _isSmallScreen(context);
        final fontSize = _getFontSize(context, 14);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: AppTheme.earth,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 34),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth - 34),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
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
                          fontSize: fontSize,
                          color: AppTheme.earth,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildQuickActionsPanel() {
    final authService = ref.watch(authServiceProvider);
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final user = userArg ?? widget.user ?? authService.currentUser;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 120,
                  maxWidth: constraints.maxWidth,
                ),
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
      },
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _getFontSize(context, 14);

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
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Text(
                      action['title'],
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Text(
                      '${action['count']} items',
                      style: TextStyle(
                        fontSize: _getFontSize(context, 12),
                        color: AppTheme.earth,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalDetailsSection() {
    final authService = ref.watch(authServiceProvider);
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final user = userArg ?? widget.user ?? authService.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      Icons.person_outline,
                      color: AppTheme.earth,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.earth.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: _getFontSize(context, 11),
                        color: AppTheme.earth,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date of Birth
              _buildInfoRow(
                'Date of Birth',
                user?.dateOfBirth != null
                    ? _formatDate(user!.dateOfBirth!)
                    : 'Not provided',
                Icons.cake_outlined,
              ),

              // Wedding Anniversary
              _buildInfoRow(
                'Wedding Anniversary',
                user?.weddingAnniversary != null
                    ? _formatDate(user!.weddingAnniversary!)
                    : 'Not provided',
                Icons.favorite_outline,
              ),

              // Address
              _buildInfoRow(
                'Address',
                user?.address?.isNotEmpty == true
                    ? user!.address!
                    : 'Not provided',
                Icons.location_on_outlined,
              ),

              // Hobbies
              _buildInfoRow(
                'Hobbies & Interests',
                user?.hobbies?.isNotEmpty == true
                    ? user!.hobbies!
                    : 'Not provided',
                Icons.sports_esports_outlined,
              ),

              // Notes
              _buildInfoRow(
                'Additional Notes',
                user?.notes?.isNotEmpty == true
                    ? user!.notes!
                    : 'No notes added',
                Icons.note_outlined,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentBusinessInfo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Current Business Context',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                        fontSize: _getFontSize(context, 14),
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
      },
    );
  }

  Widget _buildBusinessInfoRow(String label, String value, IconData icon) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = _isSmallScreen(context);
        final fontSize = _getFontSize(context, 14);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: AppTheme.earth,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 34),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: constraints.maxWidth - 34),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
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
                          fontSize: fontSize,
                          color: AppTheme.earth,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRoleBreakdown() {
    final authService = ref.watch(authServiceProvider);
    final routeUser = ModalRoute.of(context)?.settings.arguments;
    final User? userArg = routeUser is User ? routeUser : null;
    final user = userArg ?? widget.user ?? authService.currentUser;
    final storeRoles = user?.storeRoles ?? {};

    if (storeRoles.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Role Breakdown',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.6),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: _getFontSize(context, 14),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.6),
                              child: Text(
                                'Role: ${entry.value.map(_formatRole).join(', ')}',
                                style: TextStyle(
                                  fontSize: _getFontSize(context, 12),
                                  color: AppTheme.earth,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                              fontSize: _getFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildRecentActivity() {
    final activities = _getMockRecentActivities();

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                        fontSize: _getFontSize(context, 12),
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
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.6),
                              child: Text(
                                activity['title'],
                                style: TextStyle(
                                  fontSize: _getFontSize(context, 14),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.6),
                              child: Text(
                                activity['description'],
                                style: TextStyle(
                                  fontSize: _getFontSize(context, 12),
                                  color: AppTheme.earth,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        activity['time'],
                        style: TextStyle(
                          fontSize: _getFontSize(context, 11),
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
      },
    );
  }

  Widget _buildSettingsAndPreferences() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final fontSize = _getFontSize(context, 18);

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
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Settings & Preferences',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getIconSize(context);
        final titleFontSize = _getFontSize(context, 16);
        final subtitleFontSize = _getFontSize(context, 13);

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
                    color:
                        isDestructive ? AppTheme.secondary : AppTheme.primary,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.7),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: isDestructive
                                ? AppTheme.secondary
                                : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.7),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: AppTheme.earth,
                          ),
                          overflow: TextOverflow.ellipsis,
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
      },
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: _getFontSize(context, 20),
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppTheme.textPrimary,
            size: _getIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final authService = ref.watch(authServiceProvider);
              final routeUser = ModalRoute.of(context)?.settings.arguments;
              final User? userArg = routeUser is User ? routeUser : null;
              final user = userArg ?? widget.user ?? authService.currentUser;

              return Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: user != null
                      ? AppTheme.primary.withOpacity(0.1)
                      : AppTheme.earth.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: user != null ? AppTheme.primary : AppTheme.earth,
                    size: _getIconSize(context),
                  ),
                  onPressed: user != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CreateEditUserScreen(user: user),
                            ),
                          );
                        }
                      : null,
                  tooltip: user != null ? 'Edit User' : 'No user to edit',
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomScrollView(
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

                  // Personal Details Section
                  SliverToBoxAdapter(
                    child: _buildPersonalDetailsSection(),
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

                  // Bottom padding with keyboard awareness
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 32,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

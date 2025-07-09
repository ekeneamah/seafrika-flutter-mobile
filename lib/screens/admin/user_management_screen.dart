import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/user.dart' as app_user;
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/services/team_service.dart';
import 'package:vendor_app/widgets/error_view.dart';
import 'package:vendor_app/widgets/loading_indicator.dart';
import 'package:vendor_app/config/theme.dart';
import 'create_edit_user_screen.dart';
import 'package:vendor_app/config/routes.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  app_user.UserRole? _roleFilter;
  bool? _activeFilter;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationsInitialized = false;
  String _sortBy = 'dateCreated';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationsInitialized) {
      _initializeAnimations();
    }
  }

  void _initializeAnimations() {
    if (_animationsInitialized) return;
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
    _animationsInitialized = true;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildModernCard(
      {required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSearchAndFilterSection() {
    return _buildModernCard(
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppTheme.whiteSmoke,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.earthLight,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                hintStyle: TextStyle(
                  color: AppTheme.earth,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_outlined,
                  color: AppTheme.earth,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.earth,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Filter Row
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  label: _roleFilter == null
                      ? 'All Roles'
                      : _roleFilter.toString().split('.').last,
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: _showFilterDialog,
                  isActive: _roleFilter != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterChip(
                  label: _activeFilter == null
                      ? 'All Status'
                      : (_activeFilter! ? 'Active' : 'Inactive'),
                  icon: Icons.toggle_on_outlined,
                  onTap: _showFilterDialog,
                  isActive: _activeFilter != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.softGreen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.earthLight.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primary : AppTheme.earth,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.primary : AppTheme.earth,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(app_user.User user, userService, teamService) {
    return _buildModernCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.userProfile,
              arguments: user,
            );
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8), // Reduced horizontal padding
                child: Column(
                  children: [
                    const SizedBox(height: 8), // space for top menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppTheme.primary.withOpacity(0.1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: user.profileImage != null
                                ? Image.network(
                                    user.profileImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildAvatarFallback(user);
                                    },
                                  )
                                : _buildAvatarFallback(user),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.earth,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Bottom Row: Roles, Teams, and Status
                    Row(
                      children: [
                        const SizedBox(width: 60), // match avatar width

                        // Roles
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined,
                                  color: AppTheme.primary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${user.roles.length} roles',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Teams
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_outlined,
                                  color: AppTheme.accent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${user.teamIds.length} teams',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppTheme.accent.withOpacity(0.1)
                                : AppTheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: user.isActive
                                  ? AppTheme.accent
                                  : AppTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ellipsis menu at top-right
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  icon:
                      Icon(Icons.more_horiz, color: AppTheme.primary, size: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) =>
                      _handleUserAction(user, value, userService, teamService),
                  itemBuilder: (context) => [
                    _buildPopupMenuItem(
                        value: 'edit',
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: AppTheme.primary),
                    _buildPopupMenuItem(
                        value: 'roles',
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Manage Roles',
                        color: AppTheme.accent),
                    _buildPopupMenuItem(
                        value: 'teams',
                        icon: Icons.groups_outlined,
                        label: 'Manage Teams',
                        color: AppTheme.earth),
                    _buildPopupMenuItem(
                      value: user.isActive ? 'deactivate' : 'activate',
                      icon: user.isActive
                          ? Icons.toggle_off_outlined
                          : Icons.toggle_on_outlined,
                      label: user.isActive ? 'Deactivate' : 'Activate',
                      color:
                          user.isActive ? AppTheme.secondary : AppTheme.accent,
                    ),
                    _buildPopupMenuItem(
                        value: 'delete',
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: AppTheme.secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(app_user.User user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.accent.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_outlined
                    : Icons.people_outline,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching users found'
                  : 'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms or filters'
                  : 'Add your first user to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.earth,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DropdownButton<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'dateCreated', child: Text('Date Created')),
            DropdownMenuItem(value: 'name', child: Text('Name')),
            DropdownMenuItem(value: 'email', child: Text('Email')),
            DropdownMenuItem(value: 'status', child: Text('Status')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sortBy = value);
          },
        ),
        IconButton(
          icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
          tooltip: _sortAsc ? 'Ascending' : 'Descending',
          onPressed: () => setState(() => _sortAsc = !_sortAsc),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userProvider);
    final userService = ref.read(userServiceProvider);
    final teamService = ref.read(teamServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'User Management',
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
              icon: Icon(Icons.filter_list, color: AppTheme.primary),
              onPressed: _showFilterDialog,
              tooltip: 'Filter Users',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildSearchAndFilterSection(),
              _buildSortSection(),
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    var filteredUsers = users.where((user) {
                      if (_roleFilter != null &&
                          !(user.roles.contains(_roleFilter))) return false;
                      if (_activeFilter != null &&
                          user.isActive != _activeFilter) return false;
                      if (_searchQuery.isEmpty) return true;
                      final fullName = user.fullName.toLowerCase();
                      final email = user.email.toLowerCase();
                      final query = _searchQuery.toLowerCase();
                      return fullName.contains(query) || email.contains(query);
                    }).toList();

                    // Sorting
                    filteredUsers.sort((a, b) {
                      int cmp;
                      switch (_sortBy) {
                        case 'dateCreated':
                          cmp = a.createdAt.compareTo(b.createdAt);
                          break;
                        case 'email':
                          cmp = a.email
                              .toLowerCase()
                              .compareTo(b.email.toLowerCase());
                          break;
                        case 'status':
                          cmp = a.isActive == b.isActive
                              ? 0
                              : (a.isActive ? -1 : 1);
                          break;
                        case 'name':
                        default:
                          cmp = a.fullName
                              .toLowerCase()
                              .compareTo(b.fullName.toLowerCase());
                      }
                      return _sortAsc ? cmp : -cmp;
                    });

                    if (filteredUsers.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return _buildUserCard(user, userService, teamService);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => ErrorView(
                    message: 'Error loading users',
                    onRetry: () => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateEditUserScreen(),
              ),
            );
          },
          backgroundColor: AppTheme.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add User',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.filter_list,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Filter Users',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Role',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterOption(
                title: 'All Roles',
                isSelected: _roleFilter == null,
                onTap: () {
                  setState(() => _roleFilter = null);
                  Navigator.pop(context);
                },
              ),
              ...app_user.UserRole.values.map(
                (role) => _buildFilterOption(
                  title: role.toString().split('.').last,
                  isSelected: _roleFilter == role,
                  onTap: () {
                    setState(() => _roleFilter = role as app_user.UserRole?);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filter by Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterOption(
                title: 'All Status',
                isSelected: _activeFilter == null,
                onTap: () {
                  setState(() => _activeFilter = null);
                  Navigator.pop(context);
                },
              ),
              _buildFilterOption(
                title: 'Active',
                isSelected: _activeFilter == true,
                onTap: () {
                  setState(() => _activeFilter = true);
                  Navigator.pop(context);
                },
              ),
              _buildFilterOption(
                title: 'Inactive',
                isSelected: _activeFilter == false,
                onTap: () {
                  setState(() => _activeFilter = false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.3)
                    : AppTheme.earthLight.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primary : AppTheme.earth,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleUserAction(
      app_user.User user, String action, userService, teamService) async {
    try {
      switch (action) {
        case 'edit':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateEditUserScreen(user: user),
            ),
          );
          return;
        case 'roles':
          await _showManageRolesDialog(user, userService);
          break;
        case 'teams':
          await _showManageTeamsDialog(user, userService, teamService);
          break;
        case 'activate':
          await userService.activateUser(user.id);
          break;
        case 'deactivate':
          await userService.deactivateUser(user.id);
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppTheme.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete User',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.earth,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await userService.deleteUser(user.id);
          }
          break;
      }
      if (mounted && action != 'edit') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('User ${action}d successfully'),
              ],
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error ${action}ing user: $e')),
              ],
            ),
            backgroundColor: AppTheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _showManageRolesDialog(app_user.User user, userService) async {
    final selectedRoles = Set<app_user.UserRole>.from(user.roles);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Manage Roles',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...app_user.UserRole.values.map(
                (role) => StatefulBuilder(
                  builder: (context, setStateDialog) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setStateDialog(() {
                            if (selectedRoles.contains(role)) {
                              selectedRoles.remove(role);
                            } else {
                              selectedRoles.add(role);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedRoles.contains(role)
                                ? AppTheme.accent.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedRoles.contains(role)
                                  ? AppTheme.accent.withOpacity(0.3)
                                  : AppTheme.earthLight.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedRoles.contains(role)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: selectedRoles.contains(role)
                                    ? AppTheme.accent
                                    : AppTheme.earth,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                role.toString().split('.').last,
                                style: TextStyle(
                                  color: selectedRoles.contains(role)
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  fontWeight: selectedRoles.contains(role)
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.earth,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      await userService.updateUserRoles(
        userId: user.id,
        roles: selectedRoles.toList(),
      );
    }
  }

  Future<void> _showManageTeamsDialog(
      app_user.User user, userService, teamService) async {
    final selectedTeamIds = Set<String>.from(user.teamIds);
    final teams = await teamService.streamTeams().first;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.earth.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.groups_outlined,
                color: AppTheme.earth,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Manage Teams',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...teams.map(
                  (team) => StatefulBuilder(
                    builder: (context, setStateDialog) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setStateDialog(() {
                              if (selectedTeamIds.contains(team.id)) {
                                selectedTeamIds.remove(team.id);
                              } else {
                                selectedTeamIds.add(team.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedTeamIds.contains(team.id)
                                  ? AppTheme.earth.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedTeamIds.contains(team.id)
                                    ? AppTheme.earth.withOpacity(0.3)
                                    : AppTheme.earthLight.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedTeamIds.contains(team.id)
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: selectedTeamIds.contains(team.id)
                                      ? AppTheme.earth
                                      : AppTheme.earth.withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        team.name,
                                        style: TextStyle(
                                          color:
                                              selectedTeamIds.contains(team.id)
                                                  ? AppTheme.earth
                                                  : AppTheme.textPrimary,
                                          fontWeight:
                                              selectedTeamIds.contains(team.id)
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                        ),
                                      ),
                                      if (team.description != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          team.description!,
                                          style: TextStyle(
                                            color:
                                                AppTheme.earth.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.earth,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.earth,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      await userService.updateUserTeams(
        userId: user.id,
        teamIds: selectedTeamIds.toList(),
      );
    }
  }
}

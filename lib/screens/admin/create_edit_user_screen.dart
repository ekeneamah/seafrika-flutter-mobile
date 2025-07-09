import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/business_id_modal.dart';
import 'package:vendor_app/widgets/staff_credentials_modal.dart';
import 'package:vendor_app/widgets/custom_text_field.dart';
import 'package:vendor_app/models/user.dart';

class CreateEditUserScreen extends ConsumerStatefulWidget {
  final User? user;
  const CreateEditUserScreen({super.key, this.user});

  @override
  ConsumerState<CreateEditUserScreen> createState() =>
      _CreateEditUserScreenState();
}

class _CreateEditUserScreenState extends ConsumerState<CreateEditUserScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _defaultPasswordController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _validationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _validationAnimation;
  
  final Set<UserRole> _selectedRoles = {UserRole.staff}; // Default role
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureDefaultPassword = true;

  // Real-time validation states
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  bool _isDefaultPasswordValid = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _addValidationListeners();
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
    _validationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _validationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _validationController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  void _addValidationListeners() {
    _firstNameController.addListener(_validateFirstNameRealTime);
    _lastNameController.addListener(_validateLastNameRealTime);
    _emailController.addListener(_validateEmailRealTime);
    _defaultPasswordController.addListener(_validateDefaultPasswordRealTime);
    _passwordController.addListener(_validatePasswordRealTime);
    _confirmPasswordController.addListener(_validateConfirmPasswordRealTime);
  }

  void _validateFirstNameRealTime() {
    final value = _firstNameController.text.trim();
    final isValid = value.isNotEmpty && 
        value.length >= 2 && 
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);
    
    if (_isFirstNameValid != isValid) {
      setState(() => _isFirstNameValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateLastNameRealTime() {
    final value = _lastNameController.text.trim();
    final isValid = value.isNotEmpty && 
        value.length >= 2 && 
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);
    
    if (_isLastNameValid != isValid) {
      setState(() => _isLastNameValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateEmailRealTime() {
    final value = _emailController.text.trim();
    final isValid = value.isNotEmpty && 
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
    
    if (_isEmailValid != isValid) {
      setState(() => _isEmailValid = isValid);
      _checkFormValidity();
    }
  }

  void _validateDefaultPasswordRealTime() {
    final value = _defaultPasswordController.text;
    final isValid = value.isNotEmpty && value.length >= 6;
    
    if (_isDefaultPasswordValid != isValid) {
      setState(() => _isDefaultPasswordValid = isValid);
      _checkFormValidity();
    }
  }

  void _validatePasswordRealTime() {
    final value = _passwordController.text;
    final isValid = value.isNotEmpty && value.length >= 6;
    
    if (_isPasswordValid != isValid) {
      setState(() => _isPasswordValid = isValid);
      _checkFormValidity();
    }
    
    _validateConfirmPasswordRealTime(); // Re-validate confirm password when password changes
  }

  void _validateConfirmPasswordRealTime() {
    final value = _confirmPasswordController.text;
    final isValid = value.isNotEmpty && 
        value == _passwordController.text;
    
    if (_isConfirmPasswordValid != isValid) {
      setState(() => _isConfirmPasswordValid = isValid);
      _checkFormValidity();
    }
  }

  void _checkFormValidity() {
    final isValid = _isFirstNameValid && 
                   _isLastNameValid && 
                   _isEmailValid && 
                   _isDefaultPasswordValid &&
                   _isPasswordValid &&
                   _isConfirmPasswordValid;
    
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
      if (isValid) {
        _validationController.forward();
      } else {
        _validationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _defaultPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _validationController.dispose();
    super.dispose();
  }

  String _generateBusinessId() {
    // Generate a 13-digit code starting with BIZ-
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = timestamp.substring(timestamp.length - 9);
    return 'BIZ-$randomPart';
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      // Generate Business ID
      final businessId = _generateBusinessId();
      final businessName =
          ref.read(authServiceProvider).currentUser?.businessName ??
              'Business Name';
      final businessAddress =
          ref.read(authServiceProvider).currentUser?.businessAddress ?? '';
      final country = ref.read(authServiceProvider).currentUser?.country ?? '';
      final state = ref.read(authServiceProvider).currentUser?.state ?? '';
      final vendorId =
          ref.read(authServiceProvider).currentUser?.vendorId ?? '';
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final password = _defaultPasswordController.text;
      
      final user = User(
        id: userId,
        businessId: businessId,
        vendorId: vendorId,
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        businessName: businessName,
        businessAddress: businessAddress,
        country: country,
        state: state,
        phone: null,
        profileImage: null,
        teamIds: [],
        roles: _selectedRoles
            .map((role) => UserRole.values.firstWhere(
                (e) => e.toString() == 'UserRole.${role.name}',
                orElse: () => UserRole.viewer))
            .toList(),
        isActive: true,
        createdAt: DateTime.now(),
        lastLoginAt: null,
        permissions: [],
        storeRoles: {},
        defaultPasswordChanged: false,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('User created successfully!'),
            ],
          ),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );

      // Show Staff Credentials Modal
      showStaffCredentialsModal(
        context: context,
        staffEmail: user.email,
        staffPassword: password,
        staffName: '${user.firstName} ${user.lastName}',
        businessName: businessName,
        onClose: () {
          // Navigate back or reset form
          Navigator.pop(context);
        },
      );

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildModernCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Container(
      width: double.infinity, // Full width
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 0, vertical: 8), // No horizontal margin for full width
      decoration: BoxDecoration(
        color: AppTheme.glass,
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

  Widget _buildValidationTick(bool isValid) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: isValid
          ? Container(
              key: const ValueKey('valid_tick'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                color: AppTheme.accent,
                size: 18,
              ),
            )
          : const SizedBox.shrink(
              key: ValueKey('no_tick'),
            ),
    );
  }

  Widget _buildSuffixIcon({
    required bool isValid,
    Widget? actionButton,
  }) {
    if (actionButton != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isValid) ...[
            _buildValidationTick(isValid),
            const SizedBox(width: 8),
          ],
          actionButton,
        ],
      );
    } else {
      return _buildValidationTick(isValid);
    }
  }

  Widget _buildUserForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Add padding around the card
      child: _buildModernCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_add_outlined,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Form Progress Indicator
                  AnimatedBuilder(
                    animation: _validationAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isFormValid 
                              ? AppTheme.accent.withOpacity(0.1)
                              : AppTheme.earth.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFormValid 
                                ? AppTheme.accent.withOpacity(0.3)
                                : AppTheme.earth.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFormValid ? Icons.check_circle : Icons.edit_outlined,
                              color: _isFormValid ? AppTheme.accent : AppTheme.earth,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isFormValid ? 'Ready' : 'Fill form',
                              style: TextStyle(
                                color: _isFormValid ? AppTheme.accent : AppTheme.earth,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name Fields Row
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      keyboardType: TextInputType.name,
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                      suffixIcon: _buildValidationTick(_isFirstNameValid),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (value.trim().length < 2) {
                          return 'Min 2 chars';
                        }
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                          return 'Letters only';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      keyboardType: TextInputType.name,
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                      suffixIcon: _buildValidationTick(_isLastNameValid),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (value.trim().length < 2) {
                          return 'Min 2 chars';
                        }
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                          return 'Letters only';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Email Field - Full Width
              SizedBox(
                width: double.infinity,
                child: CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                  suffixIcon: _buildValidationTick(_isEmailValid),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Default Password Field - Full Width
              SizedBox(
                width: double.infinity,
                child: CustomTextField(
                  controller: _defaultPasswordController,
                  label: 'Default Password',
                  obscureText: _obscureDefaultPassword,
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.secondary),
                  suffixIcon: _buildSuffixIcon(
                    isValid: _isDefaultPasswordValid,
                    actionButton: IconButton(
                      icon: Icon(
                        _obscureDefaultPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.earth,
                      ),
                      onPressed: () {
                        setState(() => _obscureDefaultPassword = !_obscureDefaultPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a default password';
                    }
                    if (value.length < 6) {
                      return 'Min 6 chars';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Password Fields Row
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent),
                      suffixIcon: _buildSuffixIcon(
                        isValid: _isPasswordValid,
                        actionButton: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.earth,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (value.length < 6) {
                          return 'Min 6 chars';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      prefixIcon: Icon(Icons.lock_outline, color: AppTheme.accent),
                      suffixIcon: _buildSuffixIcon(
                        isValid: _isConfirmPasswordValid,
                        actionButton: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.earth,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords don\'t match';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRoles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Add padding around the card
      child: _buildModernCard(
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
                    Icons.admin_panel_settings_outlined,
                    color: AppTheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'User Roles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select the roles this user will have',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.earth,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Roles Grid - Full Width
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: UserRole.values.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  final roleColor = _getRoleColor(role);
                  final isStaff = role == UserRole.staff;
                  return GestureDetector(
                    onTap: isStaff
                        ? null // Staff role cannot be deselected
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedRoles.remove(role);
                              } else {
                                _selectedRoles.add(role);
                              }
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? roleColor.withOpacity(0.1)
                            : AppTheme.softGreen,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? roleColor.withOpacity(0.3)
                              : AppTheme.earthLight.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: roleColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? roleColor : AppTheme.earth,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRoleName(role),
                            style: TextStyle(
                              color: isSelected ? roleColor : AppTheme.earth,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (isStaff)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('(default)',
                                  style:
                                      TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // Add padding around the card
      child: _buildModernCard(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _validationAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity, // Full width button
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isFormValid
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isFormValid) ? null : _saveUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid 
                          ? AppTheme.primary 
                          : AppTheme.earth.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFormValid ? Icons.save_outlined : Icons.edit_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isFormValid ? 'Create User' : 'Complete Form First',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
            if (!_isFormValid) ...[
              const SizedBox(height: 12),
              Text(
                'Please fill all required fields correctly',
                style: TextStyle(
                  color: AppTheme.earth,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.staff:
        return AppTheme.primary;
      case UserRole.manager:
        return AppTheme.accent;
      case UserRole.viewer:
        return AppTheme.earth;
      case UserRole.business_owner:
        return AppTheme.secondary;
      case UserRole.admin:
        return Colors.redAccent; // Choose an appropriate color for admin
    }
  }

  String _formatRoleName(UserRole role) {
    switch (role) {
      case UserRole.staff:
        return 'Staff Member';
      case UserRole.manager:
        return 'Manager';
      case UserRole.viewer:
        return 'Viewer';
      case UserRole.business_owner:
        return 'Business Owner';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Add New User',
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
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildUserForm(),
                _buildUserRoles(),
                _buildSaveButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
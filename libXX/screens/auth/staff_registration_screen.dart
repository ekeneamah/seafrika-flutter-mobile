import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/custom_text_field.dart';
import 'package:vendor_app/models/user.dart';

class StaffRegistrationScreen extends ConsumerStatefulWidget {
  final String? businessId;
  final String? email;

  const StaffRegistrationScreen({
    Key? key,
    this.businessId,
    this.email,
  }) : super(key: key);

  @override
  ConsumerState<StaffRegistrationScreen> createState() =>
      _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState
    extends ConsumerState<StaffRegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _businessIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // Real-time validation states
  bool _isBusinessIdValid = false;
  bool _isEmailValid = false;
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isPhoneValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _prefillData();
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

  void _prefillData() {
    if (widget.businessId != null) {
      _businessIdController.text = widget.businessId!;
    }
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  void _addValidationListeners() {
    _businessIdController.addListener(_validateBusinessIdRealTime);
    _emailController.addListener(_validateEmailRealTime);
    _firstNameController.addListener(_validateFirstNameRealTime);
    _lastNameController.addListener(_validateLastNameRealTime);
    _phoneController.addListener(_validatePhoneRealTime);
    _passwordController.addListener(_validatePasswordRealTime);
    _confirmPasswordController.addListener(_validateConfirmPasswordRealTime);
  }

  void _validateBusinessIdRealTime() {
    final value = _businessIdController.text.trim();
    final isValid =
        value.isNotEmpty && value.startsWith('BIZ-') && value.length == 13;

    if (_isBusinessIdValid != isValid) {
      setState(() => _isBusinessIdValid = isValid);
    }
  }

  void _validateEmailRealTime() {
    final value = _emailController.text.trim();
    final isValid = value.isNotEmpty &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);

    if (_isEmailValid != isValid) {
      setState(() => _isEmailValid = isValid);
    }
  }

  void _validateFirstNameRealTime() {
    final value = _firstNameController.text.trim();
    final isValid = value.isNotEmpty &&
        value.length >= 2 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);

    if (_isFirstNameValid != isValid) {
      setState(() => _isFirstNameValid = isValid);
    }
  }

  void _validateLastNameRealTime() {
    final value = _lastNameController.text.trim();
    final isValid = value.isNotEmpty &&
        value.length >= 2 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);

    if (_isLastNameValid != isValid) {
      setState(() => _isLastNameValid = isValid);
    }
  }

  void _validatePhoneRealTime() {
    final value = _phoneController.text.trim();
    final isValid = value.isNotEmpty &&
        value.length >= 10 &&
        RegExp(r'^[\+]?[0-9\s\-\(\)]+$').hasMatch(value);

    if (_isPhoneValid != isValid) {
      setState(() => _isPhoneValid = isValid);
    }
  }

  void _validatePasswordRealTime() {
    final value = _passwordController.text;
    final isValid = value.isNotEmpty &&
        value.length >= 8 &&
        value.contains(RegExp(r'[A-Z]')) &&
        value.contains(RegExp(r'[0-9]')) &&
        value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    if (_isPasswordValid != isValid) {
      setState(() => _isPasswordValid = isValid);
    }

    _checkPasswordStrength(value);
    _validateConfirmPasswordRealTime();
  }

  void _validateConfirmPasswordRealTime() {
    final value = _confirmPasswordController.text;
    final isValid = value.isNotEmpty && value == _passwordController.text;

    if (_isConfirmPasswordValid != isValid) {
      setState(() => _isConfirmPasswordValid = isValid);
    }
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      if (password.isEmpty) {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
      } else if (password.length < 6) {
        _passwordStrength = 'Too short';
        _passwordStrengthColor = Colors.red;
      } else if (!RegExp(r'(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%^&*])')
          .hasMatch(password)) {
        _passwordStrength = 'Weak';
        _passwordStrengthColor = Colors.orange;
      } else if (password.length >= 8) {
        _passwordStrength = 'Strong';
        _passwordStrengthColor = Colors.green;
      } else {
        _passwordStrength = 'Medium';
        _passwordStrengthColor = Colors.yellow[700]!;
      }
    });
  }

  @override
  void dispose() {
    _businessIdController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showSnackBar('Please accept the terms and conditions to continue.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      // Simulate staff registration API call
      await Future.delayed(const Duration(seconds: 2));

      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        businessId: _businessIdController.text.trim(),
        vendorId: '', // Set appropriately if you have vendorId
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        businessName: '', // Set if you have it
        businessAddress: '', // Set if you have it
        country: '', // Set if you have it
        state: '', // Set if you have it
        phone: _phoneController.text.trim(),
        profileImage: null,
        teamIds: [],
        roles: [UserRole.staff],
        isActive: true,
        createdAt: DateTime.now(),
        lastLoginAt: null,
        permissions: [],
        storeRoles: {},
      );

      await authService.registerStaff(user);

      if (!mounted) return;

      _showSnackBar('Registration successful! Welcome to the team.',
          isError: false);

      // Navigate to staff navigation screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.staffNavigation,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Registration failed';
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

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
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildModernCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
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

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Logo with animated background
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondary.withOpacity(0.1),
                  AppTheme.earth.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.secondary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 64,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          // Welcome text
          Text(
            'Join the Team',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your staff registration',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.earth,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return _buildModernCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    color: AppTheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Staff Registration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Business ID Field
            TextFormField(
              controller: _businessIdController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Business ID',
                hintText: 'BIZ-123456789',
                prefixIcon: Icon(
                  Icons.business_outlined,
                  color: AppTheme.secondary,
                ),
                suffixIcon: _buildSuffixIcon(isValid: _isBusinessIdValid),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the Business ID';
                }
                if (!value.startsWith('BIZ-')) {
                  return 'Business ID must start with BIZ-';
                }
                if (value.length != 13) {
                  return 'Business ID must be 13 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.secondary,
                ),
                suffixIcon: _buildSuffixIcon(isValid: _isEmailValid),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Name Fields Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      hintText: 'Enter first name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppTheme.secondary,
                      ),
                      suffixIcon: _buildSuffixIcon(isValid: _isFirstNameValid),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your first name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                        return 'Name can only contain letters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'Enter last name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppTheme.secondary,
                      ),
                      suffixIcon: _buildSuffixIcon(isValid: _isLastNameValid),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your last name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                        return 'Name can only contain letters';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Phone Field
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                  color: AppTheme.secondary,
                ),
                suffixIcon: _buildSuffixIcon(isValid: _isPhoneValid),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                if (!RegExp(r'^[\+]?[0-9\s\-\(\)]+$').hasMatch(value.trim())) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Create a strong password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.secondary,
                ),
                suffixIcon: _buildSuffixIcon(
                  isValid: _isPasswordValid,
                  actionButton: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.earth,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (!value.contains(RegExp(r'[A-Z]'))) {
                  return 'Password must contain at least one uppercase letter';
                }
                if (!value.contains(RegExp(r'[0-9]'))) {
                  return 'Password must contain at least one number';
                }
                if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                  return 'Password must contain at least one special character';
                }
                return null;
              },
            ),

            // Password strength indicator
            if (_passwordStrength.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      _passwordStrength,
                      style: TextStyle(
                        color: _passwordStrengthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_passwordStrength == 'Strong')
                      Icon(Icons.check_circle,
                          color: _passwordStrengthColor, size: 18)
                    else if (_passwordStrength == 'Medium')
                      Icon(Icons.check_circle_outline,
                          color: _passwordStrengthColor, size: 18)
                    else if (_passwordStrength == 'Weak' ||
                        _passwordStrength == 'Too short')
                      Icon(Icons.error_outline,
                          color: _passwordStrengthColor, size: 18),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.secondary,
                ),
                suffixIcon: _buildSuffixIcon(
                  isValid: _isConfirmPasswordValid,
                  actionButton: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.earth,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Terms and Conditions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() => _acceptTerms = value ?? false);
                      },
                      activeColor: AppTheme.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I agree to the Terms and Conditions',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By registering as a staff member, you agree to our terms of service and privacy policy.',
                          style: TextStyle(
                            color: AppTheme.earth,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Register Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
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
                          Icon(Icons.person_add_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Complete Registration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.mintGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.secondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already registered? ',
            style: TextStyle(
              color: AppTheme.earth,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: Text(
              'Sign In',
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        title: Text(
          'Staff Registration',
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Hero Section
                _buildHeroSection(),
                const SizedBox(height: 32),

                // Registration Form
                _buildRegistrationForm(),
                const SizedBox(height: 24),

                // Login Prompt
                _buildLoginPrompt(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

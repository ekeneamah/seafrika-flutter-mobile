import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasInternet = true;

  // Password strength indicator
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // Real-time validation states for tick marks
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildHeroSection(),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildSignupForm(),
                ),
                const SizedBox(height: 24),
                _buildPasswordRequirements(),
                const SizedBox(height: 24),
                _buildLoginPrompt(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });

    // Check internet connectivity
    _checkInternetConnection();

    // Add listeners for real-time validation as user types
    _firstNameController.addListener(_validateFirstNameRealTime);
    _lastNameController.addListener(_validateLastNameRealTime);
    _emailController.addListener(_validateEmailRealTime);
    _passwordController.addListener(_validatePasswordRealTime);
    _confirmPasswordController.addListener(_validateConfirmPasswordRealTime);
  }

  Future<void> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
    });

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _hasInternet = result != ConnectivityResult.none;
      });
      if (!_hasInternet) {
        _showSnackBar(
            'No internet connection. Please check your connection and try again.',
            isError: true);
      }
    });
  }

  /// Real-time validation methods that update as user types
  void _validateFirstNameRealTime() {
    final value = _firstNameController.text.trim();
    final isValid = value.isNotEmpty &&
        value.length >= 2 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);

    if (_isFirstNameValid != isValid) {
      setState(() {
        _isFirstNameValid = isValid;
      });
    }
  }

  void _validateLastNameRealTime() {
    final value = _lastNameController.text.trim();
    final isValid = value.isNotEmpty &&
        value.length >= 2 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(value);

    if (_isLastNameValid != isValid) {
      setState(() {
        _isLastNameValid = isValid;
      });
    }
  }

  void _validateEmailRealTime() {
    final value = _emailController.text.trim();
    final isValid = value.isNotEmpty &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);

    if (_isEmailValid != isValid) {
      setState(() {
        _isEmailValid = isValid;
      });
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
      setState(() {
        _isPasswordValid = isValid;
      });
    }

    _checkPasswordStrength(value);
    _validateConfirmPasswordRealTime(); // Re-validate confirm password when password changes
  }

  void _validateConfirmPasswordRealTime() {
    final value = _confirmPasswordController.text;
    final isValid = value.isNotEmpty && value == _passwordController.text;

    if (_isConfirmPasswordValid != isValid) {
      setState(() {
        _isConfirmPasswordValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _confirmPasswordController.removeListener(_validateConfirmPasswordRealTime);
    _passwordController.removeListener(_validatePasswordRealTime);
    _emailController.removeListener(_validateEmailRealTime);
    _firstNameController.removeListener(_validateFirstNameRealTime);
    _lastNameController.removeListener(_validateLastNameRealTime);
    _fadeController.dispose();
    _slideController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showSnackBar('Please accept the terms and conditions to continue.',
          isError: true);
      return;
    }

    if (!_hasInternet) {
      _showSnackBar(
          'No internet connection. Please check your connection and try again.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.watch(authServiceProvider);
      await authService.signup(
        _emailController.text.trim(),
        _passwordController.text,
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
      );

      if (!mounted) return;

      _showSnackBar('Account created successfully! Welcome aboard.',
          isError: false);
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('email already exists')) {
        _showSnackBar(
            'Signup error: Exception: Email already exists. Try logging in with your password.',
            isError: true);
      } else {
        _showSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  /// Build full-width modern card with responsive padding
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
                  AppTheme.accent.withOpacity(0.1),
                  AppTheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.accent.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.nature_people_outlined,
              size: 64,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 24),

          // Welcome text
          Text(
            'Create Account',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join us and start your selling journey',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.earth,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Build animated validation tick widget that appears when field is valid
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

  /// Build suffix icon with validation tick and optional action button
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

  Widget _buildSignupForm() {
    return _buildModernCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // First Name Field
            TextFormField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(
                labelText: 'First Name',
                hintText: 'Enter your first name',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppTheme.accent,
                ),
                suffixIcon: _buildSuffixIcon(isValid: _isFirstNameValid),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your first name';
                }
                if (value.trim().length < 2) {
                  return 'First name must be at least 2 characters';
                }
                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                  return 'Name can only contain letters and spaces';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Last Name Field
            TextFormField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(
                labelText: 'Last Name',
                hintText: 'Enter your last name',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppTheme.accent,
                ),
                suffixIcon: _buildSuffixIcon(isValid: _isLastNameValid),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your last name';
                }
                if (value.trim().length < 2) {
                  return 'Last name must be at least 2 characters';
                }
                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                  return 'Name can only contain letters and spaces';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.accent,
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

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Create a strong password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.accent,
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _signup(),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.accent,
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
                  color: AppTheme.primary.withOpacity(0.1),
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
                      activeColor: AppTheme.primary,
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
                          'By creating an account, you agree to our terms of service and privacy policy.',
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

            // Signup Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
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
                            'Create Account',
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

  Widget _buildPasswordRequirements() {
    return _buildModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: AppTheme.earth,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirement(
              'At least 8 characters', _passwordController.text.length >= 8),
          _buildRequirement('One uppercase letter',
              _passwordController.text.contains(RegExp(r'[A-Z]'))),
          _buildRequirement('One number',
              _passwordController.text.contains(RegExp(r'[0-9]'))),
          _buildRequirement(
              'One special character',
              _passwordController.text
                  .contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? AppTheme.accent : AppTheme.earth,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? AppTheme.accent : AppTheme.earth,
              fontSize: 13,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
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
          color: AppTheme.accent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
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
                color: AppTheme.accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
}

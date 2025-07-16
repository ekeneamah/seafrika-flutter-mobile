import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/custom_text_field.dart';

enum LoginType { businessOwner, staff }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _businessOwnerFormKey = GlobalKey<FormState>();
  final _staffFormKey = GlobalKey<FormState>();
  
  // Business Owner Controllers
  final _businessEmailController = TextEditingController();
  final _businessPasswordController = TextEditingController();
  
  // Staff Controllers
  final _staffEmailController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  final _businessIdController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureBusinessPassword = true;
  bool _obscureStaffPassword = true;
  LoginType _selectedLoginType = LoginType.businessOwner;
  
  late final AnimationController _slideController;
  late final AnimationController _fadeController;
  late final AnimationController _formSlideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _formSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Initialize the form slide animation with a default state
    _formSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formSlideController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _fadeController.forward();
    _formSlideController.value = 1.0; // Start at completed state
  }

  @override
  void dispose() {
    _businessEmailController.dispose();
    _businessPasswordController.dispose();
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    _businessIdController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _formSlideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final formKey = _selectedLoginType == LoginType.businessOwner 
        ? _businessOwnerFormKey 
        : _staffFormKey;
    
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      bool success;
      if (_selectedLoginType == LoginType.businessOwner) {
        success = await authService.login(
          _businessEmailController.text.trim(),
          _businessPasswordController.text,
        );
      } else {
        success = await authService.loginStaff(
          _staffEmailController.text.trim(),
          _staffPasswordController.text,
          _businessIdController.text.trim(),
        );
      }

      if (!mounted) return;

      if (success) {
        final userType = _selectedLoginType == LoginType.businessOwner 
            ? 'Business Owner' 
            : 'Staff Member';
        _showSnackBar('Welcome back, $userType! Login successful.', isError: false);
        
        // Navigate based on user type
        if (_selectedLoginType == LoginType.businessOwner) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.staffNavigation);
        }
      } else {
        _showSnackBar('Login failed. Please check your credentials.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'An error occurred during login';
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _showSnackBar(errorMessage, isError: true);
      debugPrint('Login error: $e');
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
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _switchLoginType(LoginType type) {
    if (_selectedLoginType != type) {
      // Determine slide direction
      final isMovingRight = type == LoginType.staff;
      
      // Reset controller to ensure clean state
      _formSlideController.reset();
      
      // Start slide out animation
      _formSlideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(isMovingRight ? -1.0 : 1.0, 0),
      ).animate(CurvedAnimation(
        parent: _formSlideController,
        curve: Curves.easeInOut,
      ));
      
      _formSlideController.forward().then((_) {
        // Update the login type
        setState(() {
          _selectedLoginType = type;
        });
        
        // Set up slide in animation
        _formSlideAnimation = Tween<Offset>(
          begin: Offset(isMovingRight ? 1.0 : -1.0, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _formSlideController,
          curve: Curves.easeInOut,
        ));
        
        // Reset and start slide in
        _formSlideController.reset();
        _formSlideController.forward();
      });
    }
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
                  AppTheme.primary.withOpacity(0.1),
                  AppTheme.accent.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.eco_outlined,
              size: 64,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Welcome text
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(_selectedLoginType),
              'Sign in to continue to your ${_selectedLoginType == LoginType.businessOwner ? 'business' : 'workspace'}',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.earth,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTypeSelector() {
    return _buildModernCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchLoginType(LoginType.businessOwner),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: _selectedLoginType == LoginType.businessOwner
                      ? LinearGradient(
                          colors: [
                            AppTheme.primary,
                            AppTheme.accent,
                          ],
                        )
                      : null,
                  color: _selectedLoginType != LoginType.businessOwner
                      ? Colors.transparent
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedLoginType == LoginType.businessOwner
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: _selectedLoginType == LoginType.businessOwner ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.business_center_outlined,
                        color: _selectedLoginType == LoginType.businessOwner
                            ? Colors.white
                            : AppTheme.earth,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Business Owner',
                      style: TextStyle(
                        color: _selectedLoginType == LoginType.businessOwner
                            ? Colors.white
                            : AppTheme.earth,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchLoginType(LoginType.staff),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: _selectedLoginType == LoginType.staff
                      ? LinearGradient(
                          colors: [
                            AppTheme.secondary,
                            AppTheme.earth,
                          ],
                        )
                      : null,
                  color: _selectedLoginType != LoginType.staff
                      ? Colors.transparent
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedLoginType == LoginType.staff
                      ? [
                          BoxShadow(
                            color: AppTheme.secondary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: _selectedLoginType == LoginType.staff ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.badge_outlined,
                        color: _selectedLoginType == LoginType.staff
                            ? Colors.white
                            : AppTheme.earth,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Staff Member',
                      style: TextStyle(
                        color: _selectedLoginType == LoginType.staff
                            ? Colors.white
                            : AppTheme.earth,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessOwnerForm() {
    return _buildModernCard(
      child: Form(
        key: _businessOwnerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.business_center_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Business Owner Login',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Email Field
            CustomTextField(
              controller: _businessEmailController,
              label: 'Business Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your business email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Field
            CustomTextField(
              controller: _businessPasswordController,
              label: 'Password',
              obscureText: _obscureBusinessPassword,
              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureBusinessPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.earth,
                ),
                onPressed: () {
                  setState(() {
                    _obscureBusinessPassword = !_obscureBusinessPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.forgotPassword);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Login Button
            Container(
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
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
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
                          Icon(Icons.login_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sign In as Owner',
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

  Widget _buildStaffForm() {
    return _buildModernCard(
      child: Form(
        key: _staffFormKey,
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
                    Icons.badge_outlined,
                    color: AppTheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Staff Member Login',
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
            CustomTextField(
              controller: _businessIdController,
              label: 'Business ID',
              keyboardType: TextInputType.text,
              prefixIcon: Icon(Icons.business_outlined, color: AppTheme.secondary),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the business ID';
                }
                if (value.length < 3) {
                  return 'Business ID must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Staff Email Field
            CustomTextField(
              controller: _staffEmailController,
              label: 'Staff Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.secondary),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your staff email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Field
            CustomTextField(
              controller: _staffPasswordController,
              label: 'Password',
              obscureText: _obscureStaffPassword,
              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.secondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureStaffPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.earth,
                ),
                onPressed: () {
                  setState(() {
                    _obscureStaffPassword = !_obscureStaffPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.secondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact your business owner for the Business ID',
                      style: TextStyle(
                        color: AppTheme.earth,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Login Button
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
                onPressed: _isLoading ? null : _login,
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
                          Icon(Icons.login_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sign In as Staff',
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

  Widget _buildSignUpPrompt() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.mintGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Don\'t have an account? ',
                style: TextStyle(
                  color: AppTheme.earth,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.signup);
                },
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Vendor Registration button (directs to signup)
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.signup);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Register as Vendor',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedLoginType == LoginType.staff) ...[
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: _selectedLoginType == LoginType.staff ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  Text(
                    'Staff accounts are created by business owners',
                    style: TextStyle(
                      color: AppTheme.earth,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context, 
                        AppRoutes.staffRegistration,
                        arguments: {
                          'businessId': _businessIdController.text.trim(),
                          'email': _staffEmailController.text.trim(),
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.secondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            color: AppTheme.secondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Complete Staff Registration',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
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

                  // Login Type Selector
                  _buildLoginTypeSelector(),
                  const SizedBox(height: 24),

                  // Login Form with Sliding Animation
                  ClipRect(
                    child: AnimatedBuilder(
                      animation: _formSlideAnimation,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _formSlideAnimation,
                          child: _selectedLoginType == LoginType.businessOwner
                              ? _buildBusinessOwnerForm()
                              : _buildStaffForm(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Up Prompt
                  _buildSignUpPrompt(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/shared_preferences_keys.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/navigation_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _checkInitialRoute();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
  }

  void _startAnimationSequence() async {
    if (!mounted) return;

    // Start fade in
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Start logo scale animation
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    // Start text slide animation
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    // Start pulse animation (repeating)
    _pulseController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Start loading animation (repeating)
    _loadingController.repeat();
  }

  Future<void> _checkInitialRoute() async {
    try {
      // Minimum splash duration for better UX
      await Future.delayed(const Duration(milliseconds: 2500));

      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool(SharedPreferencesKeys.onboardingCompleted) ?? false;
      final isLoggedIn = ref.read(authServiceProvider).currentUser != null;

      if (!mounted) return;

      if (!onboardingCompleted) {
        NavigationService.navigateToAndClearStack(AppRoutes.onboarding);
      } else if (!isLoggedIn) {
        NavigationService.navigateToAndClearStack(AppRoutes.login);
      } else {
        NavigationService.navigateToAndClearStack(AppRoutes.home);
      }
    } catch (e) {
      debugPrint('Initial route check error: $e');
      if (mounted) {
        NavigationService.navigateToAndClearStack(AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.stop();
    _scaleController.stop();
    _slideController.stop();
    _pulseController.stop();
    _loadingController.stop();
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF2D2D2D),
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    AppTheme.backgroundColor,
                    AppTheme.softGreen,
                    AppTheme.mintGreen,
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating background elements
            _buildFloatingElements(isDark),

            // Main content
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with glassy container
                    _buildLogoSection(isDark),

                    const SizedBox(height: 48),

                    // App name and tagline
                    _buildTextSection(isDark),

                    const SizedBox(height: 80),

                    // Loading indicator
                    _buildLoadingSection(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingElements(bool isDark) {
    return Stack(
      children: [
        // Top left floating circle
        Positioned(
          top: 100,
          left: -50,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value * 0.8,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppTheme.primary : AppTheme.accent)
                            .withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom right floating circle
        Positioned(
          bottom: 150,
          right: -80,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value * 0.6,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppTheme.secondary : AppTheme.primary)
                            .withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Center floating element
        Positioned(
          top: 200,
          right: 50,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value * 0.4,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppTheme.accent : AppTheme.secondary)
                            .withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.7),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : AppTheme.primary)
                        .withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: (isDark ? Colors.black : AppTheme.earth)
                        .withOpacity(0.08),
                    blurRadius: 50,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withOpacity(0.1),
                        AppTheme.accent.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.eco_outlined,
                    size: 80,
                    color: isDark ? AppTheme.primary : AppTheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextSection(bool isDark) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // App name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ]
                    : [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.3),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppTheme.primary)
                      .withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'VendorHub',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.textColor : AppTheme.textPrimary,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppTheme.primary.withOpacity(0.15),
                        AppTheme.accent.withOpacity(0.08),
                      ]
                    : [
                        AppTheme.primary.withOpacity(0.1),
                        AppTheme.accent.withOpacity(0.05),
                      ],
              ),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              'Multi-Vendor Marketplace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.primary : AppTheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tagline
          Text(
            'Connecting Vendors, Empowering Commerce',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color:
                  isDark ? AppTheme.textColor.withOpacity(0.8) : AppTheme.earth,
              letterSpacing: 0.2,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(bool isDark) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          // Loading text
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppTheme.textColor.withOpacity(0.6)
                  : AppTheme.earth.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 20),

          // Modern loading indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ]
                    : [
                        Colors.white.withOpacity(0.4),
                        Colors.white.withOpacity(0.2),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.earthLight.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    final delay = index * 0.3;
                    final animationValue =
                        (_loadingAnimation.value - delay).clamp(0.0, 1.0);
                    final scale = 0.5 + (animationValue * 0.5);
                    final opacity = 0.3 + (animationValue * 0.7);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppTheme.primary : AppTheme.primary)
                                    .withOpacity(opacity),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark
                                        ? AppTheme.primary
                                        : AppTheme.primary)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

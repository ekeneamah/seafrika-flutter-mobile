import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/firebase_options.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/services/firestore_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Notification setup (optional)
  final container = ProviderContainer();
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();
  await notificationService.requestPermission();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendor App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      navigatorKey: NavigationService.navigatorKey,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.splash,
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  Future<bool> _getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  void _handleNavigation(User? user) async {
    if (_navigated || !mounted) return;
    final onboardingCompleted = await _getOnboardingCompleted();
    debugPrint('onboardingCompleted: $onboardingCompleted');
    debugPrint('isLoggedIn: ${user != null}');
    if (!onboardingCompleted) {
      _navigated = true;
      NavigationService.navigateToAndClearStack(AppRoutes.onboarding);
    } else if (user == null) {
      _navigated = true;
      NavigationService.navigateToAndClearStack(AppRoutes.login);
    } else {
      _navigated = true;
      NavigationService.navigateToAndClearStack(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
      _runSeeder();
    final user = ref.watch(authServiceProvider).currentUser;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNavigation(user);
    });
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  void initState() {
  
    super.initState();
    
  }

  Future<void> _runSeeder() async {
    // Run Firestore seeder on first load
    debugPrint('Running Firestore seeder...');
    final prefs = await SharedPreferences.getInstance();
    final hasSeeded = prefs.getBool('hasSeededPermissions') ?? false;

    if (!hasSeeded) {
      final firestore = FirebaseFirestore.instance;
      final seeder = FirestoreSeeder(firestore: firestore);
      await seeder.seedPermissions();
      await prefs.setBool('hasSeededPermissions', true);
    }
  }
}

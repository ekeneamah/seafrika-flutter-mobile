import 'package:flutter/material.dart';
import 'package:vendor_app/screens/auth/login_screen.dart';
import 'package:vendor_app/screens/auth/signup_screen.dart';
import 'package:vendor_app/screens/auth/forgot_password_screen.dart';
import 'package:vendor_app/screens/auth/reset_password_screen.dart';
import 'package:vendor_app/screens/main/media_screen.dart';
import 'package:vendor_app/screens/stores/store_detail_screen.dart';
import 'package:vendor_app/screens/main/analytics_screen.dart';
import 'package:vendor_app/screens/main/main_screen.dart';
import 'package:vendor_app/screens/main/product_detail_screen.dart';
import 'package:vendor_app/screens/main/media_detail_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vendor_app/screens/products/product_detail_screen.dart';
import 'package:vendor_app/models/store.dart';

class AppRouter {
  static const String initialRoute = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String main = '/main';
  static const String media = '/media';
  static const String store = '/store';
  static const String analytics = '/analytics';
  static const String productDetail = '/product-detail';
  static const String mediaDetail = '/media-detail';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initialRoute:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case media:
        return MaterialPageRoute(builder: (_) => const MediaScreen());
      case store:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => StoreDetailScreen(
            store: args['store'] as Store,
          ),
        );
      case analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());

      case mediaDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => MediaDetailScreen(
            media: args['media'] as AssetEntity,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

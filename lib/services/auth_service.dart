import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/SelectBusinessInfo.dart';
import 'package:vendor_app/models/user.dart' as app_user;
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends StateNotifier<app_user.User?> {
  final firebase_auth.FirebaseAuth _auth;
  final FirestoreService _firestore;
  final AnalyticsService _analytics;
  bool _isInitialized = false;
  static const String _attemptsKeyPrefix = 'login_attempts_';
  static const String _lastAttemptKeyPrefix = 'last_attempt_';

  AuthService({
    firebase_auth.FirebaseAuth? auth,
    FirestoreService? firestore,
    required AnalyticsService analytics,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirestoreService(),
        _analytics = analytics,
        super(null) {
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null && !_isInitialized) {
        _initializeCurrentUser();
      } else if (user == null) {
        state = null;
        _isInitialized = false;
      }
    });
  }

  app_user.User? get currentUser => state;

  Future<void> _initializeCurrentUser() async {
    if (_isInitialized) return;

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.getUser(user.uid);
        state = app_user.User(
          id: userDoc.id,
          businessId: 'BIZ-${DateTime.now().microsecondsSinceEpoch}',
          vendorId: userDoc.vendorId,
          email: userDoc.email,
          firstName: userDoc.firstName,
          lastName: userDoc.lastName,
          businessName: userDoc.businessName,
          businessAddress: userDoc.businessAddress,
          country: userDoc.country,
          state: userDoc.state,
          phone: userDoc.phone,
          profileImage: userDoc.profileImage,
          teamIds: userDoc.teamIds,
          roles: userDoc.roles,
          isActive: userDoc.isActive,
          createdAt: userDoc.createdAt,
          lastLoginAt: userDoc.lastLoginAt,
          permissions: userDoc.permissions,
          storeRoles: userDoc.storeRoles,
        );
        _isInitialized = true;
        print('\nApp User Object:');
        print('  - ID: ${state?.id}');
        print('  - Vendor ID: ${state?.vendorId}');
        print('  - Email: ${state?.email}');
        print('  - Name: ${state?.firstName}');
        print('  - Roles: ${state?.roles}');
      } catch (e) {
        debugPrint('Error initializing current user: $e');
      }
    }
  }

  Future<bool> loginStaff(
      String phone, String password, String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final attemptsKey = '$_attemptsKeyPrefix$phone';
    final lastAttemptKey = '$_lastAttemptKeyPrefix$phone';

    int failedAttempts = prefs.getInt(attemptsKey) ?? 0;
    DateTime? lastAttempt;
    final lastAttemptMillis = prefs.getInt(lastAttemptKey);
    if (lastAttemptMillis != null) {
      lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptMillis);
    }

    // Check for lockout
    if (failedAttempts >= 3 &&
        lastAttempt != null &&
        now.difference(lastAttempt).inMinutes < 15) {
      throw Exception('Too many failed attempts. Try again after 15 minutes.');
    }

    try {
      // Attempt login
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: '$phone@smeafrika.com', // Adjust as needed for your auth logic
        password: password,
      );

      // Check if user exists in business
      final userDoc = await _firestore
          .collection('vendors')
          .doc(businessId)
          .collection('staff')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User does not exist in this business.');
      }

      // Reset failed attempts on success
      await prefs.setInt(attemptsKey, 0);
      await prefs.setInt(lastAttemptKey, now.millisecondsSinceEpoch);
      return true;

      // If login fails, check if user exists in business by phone
    } catch (e) {
      await _incrementFailedAttempts(prefs, attemptsKey, lastAttemptKey, now);
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> _incrementFailedAttempts(
    SharedPreferences prefs,
    String attemptsKey,
    String lastAttemptKey,
    DateTime now,
  ) async {
    int failedAttempts = prefs.getInt(attemptsKey) ?? 0;
    failedAttempts++;
    await prefs.setInt(attemptsKey, failedAttempts);
    await prefs.setInt(lastAttemptKey, now.millisecondsSinceEpoch);
  }

  Future<bool> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;

        final userSnapshot = await _firestore.usersCollection.doc(uid).get();
        final data = userSnapshot.data() as Map<String, dynamic>?;
        final roles = List<String>.from(data?['roles'] ?? []);

        final userDoc = await _firestore.getDocument(
          'users',
          uid,
        );
        state = app_user.User.fromMap(userDoc.data() as Map<String, dynamic>);

        await _firestore.updateDocument(
          'users',
          state!.id,
          {'lastLoginAt': DateTime.now().toIso8601String()},
        );

        await _analytics.logLogin(method: 'email');

        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<bool> signup(
      String email,
      String password,
      String name,
      String businessName,
      String businessAddress,
      String country,
      String c_state) async {
    try {
      // Check for duplicate business name in the same country
      final existing = await _firestore.usersCollection
          .where('businessName', isEqualTo: businessName)
          .where('country', isEqualTo: country)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception(
            'A business with this name already exists in the selected country.');
      }
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('userCredential: $userCredential');
      debugPrint('userCredential.user: ${userCredential.user}');
      if (userCredential.user != null) {
        debugPrint('Inside user creation block');
        final businessId =
            'BIZ-${DateTime.now().microsecondsSinceEpoch}'; // Generate unique business ID
        debugPrint('Generated businessId: $businessId');
        final newUser = app_user.User(
          id: userCredential.user!.uid,
          vendorId: userCredential.user!.uid, // Set vendorId to user's ID
          email: email,
          firstName: name,
          lastName: '',
          businessName: businessName,
          businessAddress: businessAddress,
          businessId: businessId,
          country: country,
          state: c_state,
          phone: null,
          profileImage: null,
          teamIds: [],
          roles: [UserRole.business_owner], // business_owner default
          isActive: true,
          createdAt: DateTime.now(),
          lastLoginAt: null,
          permissions: [],
          storeRoles: {},
        );

        await _firestore.usersCollection.doc(newUser.id).set(newUser.toMap());
        state = newUser;

        // Log analytics event
        await _analytics.logSignUp(method: 'email');

        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Signup error: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stack) {
      debugPrint('Signup error: $e');
      debugPrint('Stack: $stack');
      if (e is firebase_auth.FirebaseAuthException) {
        throw _handleAuthException(e);
      } else {
        rethrow;
      }
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Reset password error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reauthenticate user before changing password
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Change password error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      state = null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Logout error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<bool> checkAuth() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.getDocument('users', user.uid);
        state = app_user.User.fromMap(userDoc.data() as Map<String, dynamic>);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Check auth error: $e');
      return false;
    }
  }

  // Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Helper method to handle Firebase Auth exceptions
  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  Future<app_user.User?> getCurrentUser() async {
    final isAuthenticated = await checkAuth();
    return isAuthenticated ? state : null;
  }

  Future<void> signIn(String email, String password) async {
    await login(email, password);
  }

  Future<void> signOut() async {
    state = null;
  }

  Future<void> updateVendorId() async {
    if (state != null && state!.vendorId.isEmpty) {
      final updatedUser = state!.copyWith(
        vendorId: state!.id,
      );
      await _firestore.usersCollection
          .doc(state!.id)
          .update(updatedUser.toMap());
      state = updatedUser;
    }
  }

  Future<void> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    // Send welcome email via external API
    try {
      final dio = Dio();
      await dio.post(
        'https://your-api.com/send-welcome-email', // <-- Replace with your API endpoint
        data: {
          'email': email,
          // Add any other fields your API expects
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            // Add auth headers if needed
          },
        ),
      );
    } catch (e) {
      debugPrint('Failed to send welcome email: $e');
    }
  }

  Future<String> registerStaff(app_user.User user, {String? password}) async {
    // 1. Generate a random password if not provided
    final generatedPassword = password ?? _generateRandomPassword();

    // 2. Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: user.email,
      password: generatedPassword,
    );

    // 3. Send email verification
    await userCredential.user?.sendEmailVerification();

    // 4. Save user to Firestore
    final userWithId = user.copyWith(id: userCredential.user!.uid);
    await _firestore.usersCollection.doc(userWithId.id).set(userWithId.toMap());

    // 5. Return the password for next steps (if generated)
    return generatedPassword;
  }

  String _generateRandomPassword({int length = 10}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (i) => chars[(rand + i) % chars.length])
        .join();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/config/collection_names.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;
  final String _businessId;

  UserService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
    required String businessId
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _businessId = businessId,
        _notificationService = notificationService;

  Future<User> createUser({
    required String email,
    required String firstName,
    required String lastName,
    required String businessName,
    required String businessAddress,
    required String country,
    required String state,
    String? phone,
    String? profileImage,
    required List<String> teamIds,
    required List<UserRole> roles,
    Map<String, List<UserRole>> storeRoles = const {},
  }) async {
    // Prevent duplicate users with the same email for this vendor
    final existing = await _firestore
        .collection('users')
        .where('vendorId', isEqualTo: _vendorId)
        .where('email', isEqualTo: email)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(
          'A user with this email already exists for this business.');
    }

    final user = User(
      id: '',
      vendorId: _vendorId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      businessName: businessName,
      businessAddress: businessAddress,
      country: country,
      state: state,
      phone: phone,
      profileImage: profileImage,
      teamIds: teamIds,
      roles: roles,
      permissions: const [],
      storeRoles: storeRoles,
      isActive: true,
      createdAt: DateTime.now(),
      businessId: _businessId,
    );

    final docRef = await _firestore.collection('users').add(user.toMap());
    final createdUser = user.copyWith(id: docRef.id);

    // Send notification
    await _notificationService.sendNotification(
      title: 'New User Added',
      message: 'User ${user.fullName} has been added',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: createdUser.toMap(),
    );

    return user;
  }

  Stream<List<User>> streamUsers({
    String? teamId,
    UserRole? role,
    bool? isActive,
  }) {
    try {
      // Start with vendorId filter as the first filter (required by Firestore rules)
      Query query =
          _firestore.collection('users').where('vendorId', isEqualTo: _vendorId);

      // Add additional filters in order
      if (teamId != null) {
        query = query.where('teamIds', arrayContains: teamId);
      }

      if (role != null) {
        query =
            query.where('roles', arrayContains: role.toString().split('.').last);
      }

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return User.fromMap(data);
        }).toList();
      });
    } catch (e) {
      print('Error in streamUsers: $e');
      // Return empty stream in case of error
      return Stream.value(<User>[]);
    }
  }

  Future<User> fetchUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      throw Exception('User not found');
    }
    final data = doc.data();
    if (data == null) {
      throw Exception('User data is null');
    }
    data['id'] = doc.id;
    return User.fromMap(data);
  }

  Future<void> updateUser({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? profileImage,
    List<String>? teamIds,
    List<UserRole>? roles,
    Map<String, List<UserRole>>? storeRoles,
    bool? isActive,
    String? email,
    // Personal details
    DateTime? dateOfBirth,
    DateTime? weddingAnniversary,
    String? address,
    String? hobbies,
    String? notes,
  }) async {
    // Prevent duplicate users with the same email for this vendor (excluding this user)
    if (email != null) {
      final existing = await _firestore
          .collection('users')
          .where('vendorId', isEqualTo: _vendorId)
          .where('email', isEqualTo: email)
          .get();
      if (existing.docs.any((doc) => doc.id != userId)) {
        throw Exception(
            'A user with this email already exists for this business.');
      }
    }

    final updates = <String, dynamic>{};

    if (firstName != null) updates['firstName'] = firstName;
    if (lastName != null) updates['lastName'] = lastName;
    if (phone != null) updates['phone'] = phone;
    if (profileImage != null) updates['profileImage'] = profileImage;
    if (teamIds != null) updates['teamIds'] = teamIds;
    if (roles != null) {
      updates['roles'] =
          roles.map((role) => role.toString().split('.').last).toList();
    }
    if (storeRoles != null) {
      updates['storeRoles'] = storeRoles.map((key, value) => MapEntry(
          key, value.map((role) => role.toString().split('.').last).toList()));
    }
    if (isActive != null) updates['isActive'] = isActive;
    if (email != null) updates['email'] = email;
    
    // Personal details
    if (dateOfBirth != null) updates['dateOfBirth'] = dateOfBirth.toIso8601String();
    if (weddingAnniversary != null) updates['weddingAnniversary'] = weddingAnniversary.toIso8601String();
    if (address != null) updates['address'] = address;
    if (hobbies != null) updates['hobbies'] = hobbies;
    if (notes != null) updates['notes'] = notes;
    
    updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(userId).update(updates);

    // Send notification
    final user = await fetchUser(userId);
    await _notificationService.sendNotification(
      title: 'User Updated',
      message: 'User ${user.fullName} has been updated',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: user.toMap(),
    );
  }

  Future<void> deleteUser(String userId) async {
    final user = await fetchUser(userId);
    await _firestore.collection('users').doc(userId).delete();

    // Send notification
    await _notificationService.sendNotification(
      title: 'User Deleted',
      message: 'User ${user.fullName} has been deleted',
      type: NotificationType.system,
      priority: NotificationPriority.high,
      data: user.toMap(),
    );
  }

  Future<void> updateUserRoles({
    required String userId,
    required List<UserRole> roles,
  }) async {
    await updateUser(
      userId: userId,
      roles: roles,
    );
  }

  Future<void> updateUserTeams({
    required String userId,
    required List<String> teamIds,
  }) async {
    await updateUser(
      userId: userId,
      teamIds: teamIds,
    );
  }

  Future<void> deactivateUser(String userId) async {
    await updateUser(
      userId: userId,
      isActive: false,
    );
  }

  Future<void> activateUser(String userId) async {
    await updateUser(
      userId: userId,
      isActive: true,
    );
  }

  Future<List<User>> getBusinessesForUserEmail(String email) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .where('roles', arrayContains: 'staff')
        .get();
    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return User.fromMap(data);
    }).toList();
  }

  // Enhanced method for adding a user with improved integration
  Future<User> addBusinessUser({
    required String email,
    required String firstName,
    required String lastName,
    required String defaultPassword,
    required List<UserRole> roles,
    List<String>? teamIds,
    String? phone,
    String? profileImage,
    required FirebaseAuth auth,
    // Personal details
    DateTime? dateOfBirth,
    DateTime? weddingAnniversary,
    String? address,
    String? hobbies,
    String? notes,
  }) async {
    try {
      // Check for duplicate email in this business
      // Use vendorId as the primary filter which has more permissive rules
      // This matches the pattern used in streamUsers which works successfully
      final existingUsers = await _firestore
          .collection(CollectionNames.users)
          .where('vendorId', isEqualTo: _vendorId)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
          
      if (existingUsers.docs.isNotEmpty) {
        throw Exception('A user with this email already exists in this business.');
      }
      
      // Generate a unique ID for the user
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Retrieve business details from BusinessPreferencesHelper
      final businessDetails = await BusinessPreferencesHelper.getSelectedBusinessDetails();
      final businessName = businessDetails['name'] ?? '';
      final businessAddress = businessDetails['address'] ?? '';
      final country = businessDetails['country'] ?? '';
      final state = businessDetails['state'] ?? '';
      
      // Create the user object
      final user = User(
        id: userId,
        businessId: _businessId,
        vendorId: _vendorId,
        email: email.trim().toLowerCase(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        businessName: businessName,
        businessAddress: businessAddress,
        country: country,
        state: state,
        phone: phone,
        profileImage: profileImage,
        teamIds: teamIds ?? [],
        roles: roles,
        permissions: const [],
        storeRoles: {},
        isActive: true,
        createdAt: DateTime.now(),
        lastLoginAt: null,
        defaultPasswordChanged: false,
        // Personal details
        dateOfBirth: dateOfBirth,
        weddingAnniversary: weddingAnniversary,
        address: address,
        hobbies: hobbies,
        notes: notes,
      );
      
      // Create user in Firebase Authentication
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: defaultPassword,
      );
      
      // Link Firebase Auth UID with the Firestore document
      final firebaseUserId = userCredential.user!.uid;
      
      // Send email verification
      await userCredential.user!.sendEmailVerification();
      
      // Save the user to Firestore with Firebase Auth UID as document ID
      final userData = {
        ...user.toMap(),
        'id': firebaseUserId, // Use Firebase Auth UID as the document ID
        'authId': firebaseUserId, // Store Firebase Auth UID separately for reference
        'isActive': true, // Ensure this field is explicitly set as it's required in security rules
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp for consistency
        'businessId': _businessId, // Explicitly set businessId as it's required in security rules
        'roles': roles.map((role) => role.toString().split('.').last).toList(), // Ensure roles are correctly formatted
      };
      
      // Ensure all required fields are present
      if (!userData.containsKey('firstName') || userData['firstName'] == null) {
        userData['firstName'] = firstName.trim();
      }
      if (!userData.containsKey('lastName') || userData['lastName'] == null) {
        userData['lastName'] = lastName.trim();
      }
      if (!userData.containsKey('email') || userData['email'] == null) {
        userData['email'] = email.trim().toLowerCase();
      }
      
      try {
        // Set the user data in Firestore
        await _firestore.collection(CollectionNames.users).doc(firebaseUserId).set(userData);
      } catch (firestoreError) {
        // If there's an error with Firestore, log it but don't fail the whole process
        // since the Firebase Auth user has already been created
        print('Warning: Firestore document creation error: $firestoreError');
        // Could consider deleting the Auth user here to keep things in sync,
        // but that might cause other issues
      }
      
      // Update the user object with the Firebase Auth UID
      final createdUser = user.copyWith(id: firebaseUserId);
      
      // Send welcome email with login instructions
      // This would typically be done via a Cloud Function or a backend service
      
      try {
        // Send notification about new user - wrap in try/catch to prevent failure
        await _notificationService.sendNotification(
          title: 'New Team Member Added',
          message: '${user.firstName} ${user.lastName} has been added to your team',
          type: NotificationType.system,
          priority: NotificationPriority.medium,
          data: {
            'userId': firebaseUserId,
            'action': 'user_created',
            'businessId': _businessId,
            'verificationEmailSent': true
          },
        );
      } catch (notificationError) {
        // Log notification errors but don't fail the whole operation
        print('Warning: Could not send notification: $notificationError');
      }
      
      return createdUser;
    } catch (e) {
      print('Error adding business user: $e');
      
      // Handle specific Firebase Auth errors
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            throw Exception('This email address is already in use by another account.');
          case 'invalid-email':
            throw Exception('The email address is invalid.');
          case 'operation-not-allowed':
            throw Exception('Email/password accounts are not enabled. Contact support.');
          case 'weak-password':
            throw Exception('The password is too weak. Please use a stronger password.');
          default:
            throw Exception('Authentication error: ${e.message}');
        }
      }
      
      // Handle Firestore permission errors
      if (e.toString().contains('permission-denied')) {
        throw Exception('You do not have permission to add users to this business. Please check your account permissions or contact your administrator.');
      }
      
      // Handle other Firebase errors with a more user-friendly message
      if (e.toString().contains('firebase') || e.toString().contains('firestore')) {
        throw Exception('There was an issue connecting to the database. Please check your network connection and try again.');
      }
      
      rethrow;
    }
  }
}

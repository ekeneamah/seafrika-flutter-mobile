import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

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

    final docRef = await _firestore.collection('vendors').doc(_businessId).collection("staff").add(user.toMap());
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
    Query query =
        _firestore.collection('users').where('vendorId', isEqualTo: _vendorId);

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
  }

  Future<User> fetchUser(String userId) async {
    final doc = await _firestore.collection('vendors').doc(_vendorId).collection("staff").doc(userId).get();
    if (!doc.exists) {
      throw Exception('User not found');
    }
    final data = doc.data()!;
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
  }) async {
    // Prevent duplicate users with the same email for this vendor (excluding this user)
    if (email != null) {
      final existing = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('staff')
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
    updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('vendors').doc(_vendorId).collection("staff").doc(userId).update(updates);

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
    await _firestore.collection('vendors').doc(_vendorId).collection("staff").doc(userId).delete();

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
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return User.fromMap(data);
    }).toList();
  }
}

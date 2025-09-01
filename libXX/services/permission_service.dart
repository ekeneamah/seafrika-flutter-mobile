import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/permission.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

class PermissionService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  PermissionService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Future<Permission> createPermission({
    required String name,
    required String description,
    required PermissionCategory category,
  }) async {
    final permission = Permission(
      id: '',
      name: name,
      description: description,
      category: category,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final docRef =
        await _firestore.collection('permissions').add(permission.toMap());
    final createdPermission = permission.copyWith(id: docRef.id);

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Permission Created',
      message: 'Permission $name has been created',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: createdPermission.toMap(),
    );

    return createdPermission;
  }

  Stream<List<Permission>> streamPermissions({
    PermissionCategory? category,
    bool? isActive,
  }) {
    Query query = _firestore.collection('permissions');

    if (category != null) {
      query = query.where('category',
          isEqualTo: category.toString().split('.').last);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Permission.fromMap(data);
      }).toList();
    });
  }

  Future<Permission> fetchPermission(String permissionId) async {
    final doc =
        await _firestore.collection('permissions').doc(permissionId).get();
    if (!doc.exists) {
      throw Exception('Permission not found');
    }
    final data = doc.data()!;
    data['id'] = doc.id;
    return Permission.fromMap(data);
  }

  Future<void> updatePermission({
    required String permissionId,
    String? name,
    String? description,
    PermissionCategory? category,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (category != null) {
      updates['category'] = category.toString().split('.').last;
    }
    if (isActive != null) updates['isActive'] = isActive;
    updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('permissions')
        .doc(permissionId)
        .update(updates);

    // Send notification
    final permission = await fetchPermission(permissionId);
    await _notificationService.sendNotification(
      title: 'Permission Updated',
      message: 'Permission ${permission.name} has been updated',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: permission.toMap(),
    );
  }

  Future<void> deletePermission(String permissionId) async {
    final permission = await fetchPermission(permissionId);
    await _firestore.collection('permissions').doc(permissionId).delete();

    // Send notification
    await _notificationService.sendNotification(
      title: 'Permission Deleted',
      message: 'Permission ${permission.name} has been deleted',
      type: NotificationType.system,
      priority: NotificationPriority.high,
      data: permission.toMap(),
    );
  }

  Future<void> deactivatePermission(String permissionId) async {
    await updatePermission(
      permissionId: permissionId,
      isActive: false,
    );
  }

  Future<void> activatePermission(String permissionId) async {
    await updatePermission(
      permissionId: permissionId,
      isActive: true,
    );
  }

  Future<List<String>> getUserPermissions(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    final roles = (userData['roles'] as List<dynamic>?)?.cast<String>() ?? [];

    // Get permissions for each role
    final permissions = <String>{};
    for (final role in roles) {
      final roleDoc = await _firestore
          .collection('roles')
          .where('name', isEqualTo: role)
          .get();

      if (roleDoc.docs.isNotEmpty) {
        final roleData = roleDoc.docs.first.data();
        final rolePermissions =
            (roleData['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
        permissions.addAll(rolePermissions);
      }
    }

    return permissions.toList();
  }

  Future<bool> hasPermission(String userId, String permissionId) async {
    final userPermissions = await getUserPermissions(userId);
    return userPermissions.contains(permissionId);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/permission.dart';
import '../models/role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final permissionProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Permission>> fetchPermissions() async {
    final snapshot = await _firestore.collection('permissions').get();
    return snapshot.docs.map((doc) => Permission.fromMap(doc.data())).toList();
  }

  Future<List<Role>> fetchRoles() async {
    final snapshot = await _firestore.collection('roles').get();
    return snapshot.docs.map((doc) => Role.fromMap(doc.data())).toList();
  }

  Future<void> createPermission(Permission permission) async {
    await _firestore
        .collection('permissions')
        .doc(permission.id)
        .set(permission.toMap());
  }

  Future<void> createRole(Role role) async {
    await _firestore.collection('roles').doc(role.id).set(role.toMap());
  }

  Future<bool> hasPermission(String userId, String permissionId) async {
    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final roleIds = List<String>.from(userSnapshot.data()?['roleIds'] ?? []);

    for (final roleId in roleIds) {
      final roleSnapshot =
          await _firestore.collection('roles').doc(roleId).get();
      final role = Role.fromMap(roleSnapshot.data()!);
      if (role.permissionIds.contains(permissionId)) {
        return true;
      }
    }
    return false;
  }
}

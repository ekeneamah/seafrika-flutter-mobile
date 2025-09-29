import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/role.dart';
import '../../models/permission.dart';
import '../../providers/service_providers.dart';

class EditRolePermissionsScreen extends ConsumerWidget {
  final Role role;

  const EditRolePermissionsScreen({Key? key, required this.role})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsyncValue = ref.watch(permissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Permissions for ${role.name}'),
      ),
      body: permissionsAsyncValue.when(
        data: (permissions) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search permissions...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (query) {
                    // Implement search logic here
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    final permission = permissions[index];
                    final isAssigned =
                        role.permissions.contains(permission.name);

                    return CheckboxListTile(
                      title: Text(permission.name),
                      value: isAssigned,
                      onChanged: (value) async {
                        if (value == true) {
                          await _assignPermissionToRole(role, permission);
                        } else {
                          await _removePermissionFromRole(role, permission);
                        }
                      },
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _batchUpdatePermissions(context, role);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _assignPermissionToRole(Role role, Permission permission) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('roles').doc(role.id).update({
      'permissions': FieldValue.arrayUnion([permission.name]),
    });
  }

  Future<void> _removePermissionFromRole(
      Role role, Permission permission) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('roles').doc(role.id).update({
      'permissions': FieldValue.arrayRemove([permission.name]),
    });
  }

  Future<void> _batchUpdatePermissions(BuildContext context, Role role) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection('roles').doc(role.id).update({
        'permissions':
            role.permissions, // Update with the current permissions list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating permissions: $e')),
      );
    }
  }
}

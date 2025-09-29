import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../models/role.dart';
import '../../providers/service_providers.dart';

class EditUserRolesScreen extends ConsumerWidget {
  final User user;

  const EditUserRolesScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeRolesAsyncValue = ref.watch(storeRolesProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Store Roles for ${user.fullName}'),
      ),
      body: storeRolesAsyncValue.when(
        data: (storeRoles) {
          return ListView.builder(
            itemCount: storeRoles.keys.length,
            itemBuilder: (context, index) {
              final storeId = storeRoles.keys.elementAt(index);
              final roles = storeRoles[storeId]!;

              return ExpansionTile(
                title: Text('Store: $storeId'),
                children: roles.map((role) {
                  final isAssigned =
                      user.storeRoles[storeId]?.contains(role) ?? false;

                  return CheckboxListTile(
                    title: Text(role.name),
                    value: isAssigned,
                    onChanged: (value) async {
                      if (value == true) {
                        await _assignRoleToStore(user, storeId, role);
                      } else {
                        await _removeRoleFromStore(user, storeId, role);
                      }
                    },
                  );
                }).toList(),
              );
            },
          );
        },
        loading: () => CircularProgressIndicator(),
        error: (error, stack) => Text('Error: $error'),
      ),
    );
  }

  Future<void> _assignRoleToStore(User user, String storeId, Role role) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
    await userRef.update({
      'storeRoles.$storeId': FieldValue.arrayUnion([role.name]),
    });
  }

  Future<void> _removeRoleFromStore(
      User user, String storeId, Role role) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
    await userRef.update({
      'storeRoles.$storeId': FieldValue.arrayRemove([role.name]),
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/models/role.dart';
import 'package:vendor_app/screens/admin/create_edit_role_screen.dart';

class RoleManagementScreen extends ConsumerWidget {
  const RoleManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(roleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Role Management')),
      body: roles.when(
        data: (roles) => ListView.builder(
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return ListTile(
              title: Text(role.name),
              subtitle: Text('Permissions: ${role.permissionIds.join(', ')}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Navigate to edit role screen
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateEditRoleScreen(),
            ),
          );
          if (created == true) {
            // Optionally refresh roles if needed
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

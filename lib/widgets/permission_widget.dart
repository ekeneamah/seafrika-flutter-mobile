import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';

class PermissionWidget extends ConsumerWidget {
  final String permissionId;
  final Widget child;
  final String? storeId;

  const PermissionWidget({
    required this.permissionId,
    required this.child,
    this.storeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (storeId != null) {
      final roles = ref.watch(storeRolesProvider(user!.id)).maybeWhen(
            data: (storeRoles) => storeRoles[storeId] ?? [],
            orElse: () => [],
          );
      final hasPermission = roles.any((role) => role.permissionIds.contains(permissionId));

      if (hasPermission) {
        return child;
      } else {
        return SizedBox.shrink();
      }
    } else {
      if (user?.permissions.contains(permissionId) ?? false) {
        return child;
      } else {
        return SizedBox.shrink();
      }
    }
  }
}

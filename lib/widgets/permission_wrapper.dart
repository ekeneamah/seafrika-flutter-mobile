import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/permission_provider.dart' as perm_prov;
import '../providers/service_providers.dart';

class PermissionWrapper extends ConsumerWidget {
  final String permissionId;
  final Widget child;

  const PermissionWrapper({
    required this.permissionId,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionService = ref.read(perm_prov.permissionProvider);
    final authService = ref.read(authServiceProvider);
    final userId = authService.currentUser?.id ?? '';

    return FutureBuilder<bool>(
      future: permissionService.hasPermission(userId, permissionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasData && snapshot.data == true) {
          return child;
        }

        return const SizedBox.shrink();
      },
    );
  }
}

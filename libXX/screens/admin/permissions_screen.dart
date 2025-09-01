import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/permission.dart';
import 'package:vendor_app/services/permission_service.dart';
import 'package:vendor_app/widgets/loading_indicator.dart';
import 'package:vendor_app/widgets/error_view.dart';
import 'package:vendor_app/providers/service_providers.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  PermissionCategory? _categoryFilter;
  bool? _activeFilter;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissionService = ref.watch(permissionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search permissions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Permission>>(
              stream: permissionService.streamPermissions(
                category: _categoryFilter,
                isActive: _activeFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Error loading permissions',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingIndicator();
                }

                final permissions = snapshot.data!;
                final filteredPermissions = permissions.where((permission) {
                  if (_searchQuery.isEmpty) return true;
                  final name = permission.name.toLowerCase();
                  final description = permission.description.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || description.contains(query);
                }).toList();

                if (filteredPermissions.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No permissions found'
                          : 'No matching permissions found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredPermissions.length,
                  itemBuilder: (context, index) {
                    final permission = filteredPermissions[index];
                    return _buildPermissionCard(permission);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePermissionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPermissionCard(Permission permission) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(permission.name[0].toUpperCase()),
        ),
        title: Text(permission.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(permission.description),
            Text('Category: ${permission.category.toString().split('.').last}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handlePermissionAction(permission, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            PopupMenuItem(
              value: permission.isActive ? 'deactivate' : 'activate',
              child: Text(permission.isActive ? 'Deactivate' : 'Activate'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Permissions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Category:'),
            ...PermissionCategory.values.map(
              (category) => ListTile(
                title: Text(category.toString().split('.').last),
                selected: _categoryFilter == category,
                onTap: () {
                  setState(() {
                    _categoryFilter = category;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            const Divider(),
            const Text('Status:'),
            ListTile(
              title: const Text('All Status'),
              selected: _activeFilter == null,
              onTap: () {
                setState(() {
                  _activeFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Active'),
              selected: _activeFilter == true,
              onTap: () {
                setState(() {
                  _activeFilter = true;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Inactive'),
              selected: _activeFilter == false,
              onTap: () {
                setState(() {
                  _activeFilter = false;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePermissionDialog(BuildContext context) {
    final permissionService = ref.watch(permissionServiceProvider);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    PermissionCategory? selectedCategory;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Permission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter permission name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter permission description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PermissionCategory>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: PermissionCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  descriptionController.text.isEmpty ||
                  selectedCategory == null) {
                return;
              }

              try {
                debugPrint(
                    'Creating permission: name=${nameController.text}, description=${descriptionController.text}, category=${selectedCategory.toString()}');
                await permissionService.createPermission(
                  name: nameController.text,
                  description: descriptionController.text,
                  category: selectedCategory!,
                );
                debugPrint('Permission created successfully');
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permission created successfully'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error creating permission: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating permission: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handlePermissionAction(Permission permission, String action) async {
    final permissionService = ref.watch(permissionServiceProvider);

    try {
      switch (action) {
        case 'edit':
          await _showEditPermissionDialog(permission);
          break;
        case 'activate':
          await permissionService.activatePermission(permission.id);
          break;
        case 'deactivate':
          await permissionService.deactivatePermission(permission.id);
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Permission'),
              content: Text('Are you sure you rmission.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await permissionService.deletePermission(permission.id);
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission ${action}d successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${action}ing permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditPermissionDialog(Permission permission) async {
    final permissionService = ref.watch(permissionServiceProvider);
    final nameController = TextEditingController(text: permission.name);
    final descriptionController =
        TextEditingController(text: permission.description);
    var selectedCategory = permission.category;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Permission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter permission name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter permission description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PermissionCategory>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: PermissionCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await permissionService.updatePermission(
        permissionId: permission.id,
        name: nameController.text,
        description: descriptionController.text,
        category: selectedCategory,
      );
    }
  }
}

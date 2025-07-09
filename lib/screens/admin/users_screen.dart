import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/services/team_service.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/widgets/loading_indicator.dart';
import 'package:vendor_app/widgets/error_view.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  UserRole? _roleFilter;
  bool? _activeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
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
                hintText: 'Search users...',
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
            child: StreamBuilder<List<User>>(
              stream: userService.streamUsers(
                role: _roleFilter,
                isActive: _activeFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Error loading users',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingIndicator();
                }

                final users = snapshot.data!;
                final filteredUsers = users.where((user) {
                  if (_searchQuery.isEmpty) return true;
                  final fullName = user.fullName.toLowerCase();
                  final email = user.email.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return fullName.contains(query) || email.contains(query);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No users found'
                          : 'No matching users found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _buildUserCard(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateUserDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profileImage != null
              ? NetworkImage(user.profileImage!)
              : null,
          child: user.profileImage == null
              ? Text(user.firstName[0].toUpperCase())
              : null,
        ),
        title: Text(user.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text('Roles: ${user.roles.map((r) => r.toString().split('.').last).join(', ')}'),
            Text('Teams: ${user.teamIds.length}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(user, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'roles',
              child: Text('Manage Roles'),
            ),
            const PopupMenuItem(
              value: 'teams',
              child: Text('Manage Teams'),
            ),
            PopupMenuItem(
              value: user.isActive ? 'deactivate' : 'activate',
              child: Text(user.isActive ? 'Deactivate' : 'Activate'),
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
        title: const Text('Filter Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Roles'),
              selected: _roleFilter == null,
              onTap: () {
                setState(() {
                  _roleFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ...UserRole.values.map(
              (role) => ListTile(
                title: Text(role.toString().split('.').last),
                selected: _roleFilter == role,
                onTap: () {
                  setState(() {
                    _roleFilter = role;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            const Divider(),
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

  void _showCreateUserDialog(BuildContext context) {
    final userService = Provider.of<UserService>(context, listen: false);
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final businessNameController = TextEditingController();
    final businessAddressController = TextEditingController();
    final countryController = TextEditingController();
    final stateController = TextEditingController();
    final selectedRoles = <UserRole>{};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email address',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter first name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter last name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text('Select Roles:'),
              ...UserRole.values.map(
                (role) => CheckboxListTile(
                  title: Text(role.toString().split('.').last),
                  value: selectedRoles.contains(role),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedRoles.add(role);
                      } else {
                        selectedRoles.remove(role);
                      }
                    });
                  },
                ),
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
              if (emailController.text.isEmpty ||
                  firstNameController.text.isEmpty ||
                  lastNameController.text.isEmpty ||
                  selectedRoles.isEmpty) {
                return;
              }

              try {
                await userService.createUser(
                  email: emailController.text,
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  businessName: businessNameController.text,
                  businessAddress: businessAddressController.text,
                  country: countryController.text,
                  state: stateController.text,
                  phone: phoneController.text.isEmpty ? null : phoneController.text,
                  teamIds: [],
                  roles: selectedRoles.toList(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User created successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating user: $e'),
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

  void _handleUserAction(User user, String action) async {
    final userService = Provider.of<UserService>(context, listen: false);

    try {
      switch (action) {
        case 'edit':
          await _showEditUserDialog(user);
          break;
        case 'roles':
          await _showManageRolesDialog(user);
          break;
        case 'teams':
          await _showManageTeamsDialog(user);
          break;
        case 'activate':
          await userService.activateUser(user.id);
          break;
        case 'deactivate':
          await userService.deactivateUser(user.id);
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete User'),
              content: Text('Are you sure you want to delete ${user.fullName}?'),
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
            await userService.deleteUser(user.id);
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${action}d successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${action}ing user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditUserDialog(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final phoneController = TextEditingController(text: user.phone);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter first name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter last name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
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
      await userService.updateUser(
        userId: user.id,
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        phone: phoneController.text.isEmpty ? null : phoneController.text,
      );
    }
  }

  Future<void> _showManageRolesDialog(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final selectedRoles = Set<UserRole>.from(user.roles);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Roles'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...UserRole.values.map(
                (role) => CheckboxListTile(
                  title: Text(role.toString().split('.').last),
                  value: selectedRoles.contains(role),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedRoles.add(role);
                      } else {
                        selectedRoles.remove(role);
                      }
                    });
                  },
                ),
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
      await userService.updateUserRoles(
        userId: user.id,
        roles: selectedRoles.toList(),
      );
    }
  }

  Future<void> _showManageTeamsDialog(User user) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final teamService = Provider.of<TeamService>(context, listen: false);
    final selectedTeamIds = Set<String>.from(user.teamIds);

    final teams = await teamService.streamTeams().first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Teams'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...teams.map(
                  (team) => CheckboxListTile(
                    title: Text(team.name),
                    subtitle: team.description != null ? Text(team.description!) : null,
                    value: selectedTeamIds.contains(team.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTeamIds.add(team.id);
                        } else {
                          selectedTeamIds.remove(team.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
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
      await userService.updateUserTeams(
        userId: user.id,
        teamIds: selectedTeamIds.toList(),
      );
    }
  }
} 